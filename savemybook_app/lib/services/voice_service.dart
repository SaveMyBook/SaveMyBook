import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

enum VoiceStartResult { started, permissionGranted, denied, failed }

class VoiceClip {
  final String path;
  final Duration duration;

  const VoiceClip(this.path, this.duration);

  int get seconds => (duration.inMilliseconds / 1000).round().clamp(1, VoiceRecorder.maxDuration.inSeconds);
}

class VoiceRecorder {
  static const maxDuration = Duration(seconds: 120);
  static const minDuration = Duration(seconds: 1);

  @visibleForTesting
  static VoiceRecorder Function()? debugFactory;

  factory VoiceRecorder() => debugFactory?.call() ?? VoiceRecorder.device();

  VoiceRecorder.device();

  final ValueNotifier<double> level = ValueNotifier<double>(0);
  final Stopwatch _watch = Stopwatch();

  VoidCallback? onInterrupted;

  AudioRecorder? _recorder;
  StreamSubscription<Amplitude>? _amplitude;
  StreamSubscription<RecordState>? _state;
  Future<VoiceStartResult>? _starting;
  String? _path;
  bool _disposed = false;

  bool get isRecording => _path != null;

  Duration get elapsed => _watch.elapsed;

  Future<bool> ensurePermission() async {
    final recorder = _recorder ??= AudioRecorder();
    try {
      if (await recorder.hasPermission(request: false)) return true;
      return await recorder.hasPermission();
    } catch (_) {
      return false;
    }
  }

  Future<bool> checkPermission() async {
    try {
      return await (_recorder ??= AudioRecorder()).hasPermission(request: false);
    } catch (_) {
      return false;
    }
  }

  Future<VoiceStartResult> start() {
    return _starting ??= _start().whenComplete(() => _starting = null);
  }

  Future<VoiceStartResult> _start() async {
    if (_path != null) return VoiceStartResult.started;
    await VoicePlayback.instance.stop();
    final recorder = _recorder ??= AudioRecorder();

    try {
      if (!await recorder.hasPermission(request: false)) {
        return await recorder.hasPermission() ? VoiceStartResult.permissionGranted : VoiceStartResult.denied;
      }

      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000, sampleRate: 44100, numChannels: 1),
        path: path,
      );
      if (_disposed) {
        await recorder.cancel();
        return VoiceStartResult.failed;
      }

      _path = path;
      _watch
        ..reset()
        ..start();
      _amplitude = recorder.onAmplitudeChanged(const Duration(milliseconds: 80)).listen((amp) {
        final db = amp.current.isFinite ? amp.current : -60.0;
        level.value = ((db + 48) / 48).clamp(0.0, 1.0);
      });
      // iOS 來電或其他 App 搶走音訊時，原生端會自行暫停錄音，只會從狀態串流得知。
      _state = recorder.onStateChanged().listen((state) {
        if (_path != path || state == RecordState.record) return;
        _watch.stop();
        onInterrupted?.call();
      });
      return VoiceStartResult.started;
    } catch (_) {
      _path = null;
      return VoiceStartResult.failed;
    }
  }

  Future<VoiceClip?> stop() async {
    if (_starting != null) await _starting;
    final path = _path;
    if (path == null) return null;

    final elapsed = _watch.elapsed;
    await _reset();

    String? output;
    try {
      output = await _recorder?.stop();
    } catch (_) {}

    final file = output ?? path;
    if (elapsed < minDuration) {
      _delete(file);
      return null;
    }
    return VoiceClip(file, elapsed > maxDuration ? maxDuration : elapsed);
  }

  Future<void> cancel() async {
    if (_starting != null) await _starting;
    if (_path == null) return;
    await _reset();
    try {
      await _recorder?.cancel();
    } catch (_) {}
  }

  Future<void> _reset() async {
    _watch.stop();
    _path = null;
    await _amplitude?.cancel();
    _amplitude = null;
    await _state?.cancel();
    _state = null;
    if (!_disposed) level.value = 0;
  }

  Future<void> dispose() async {
    onInterrupted = null;
    await cancel();
    _disposed = true;
    level.dispose();
    final recorder = _recorder;
    _recorder = null;
    await recorder?.dispose();
  }

  static void _delete(String path) {
    File(path).delete().catchError((_) => File(path));
  }

  static void deleteFile(String? path) {
    if (path != null) _delete(path);
  }
}

@immutable
class VoicePlaybackState {
  final String? url;
  final bool playing;
  final bool loading;
  final Duration position;
  final Duration duration;

  const VoicePlaybackState({
    this.url,
    this.playing = false,
    this.loading = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
  });

  VoicePlaybackState copyWith({bool? playing, bool? loading, Duration? position, Duration? duration}) =>
      VoicePlaybackState(
        url: url,
        playing: playing ?? this.playing,
        loading: loading ?? this.loading,
        position: position ?? this.position,
        duration: duration ?? this.duration,
      );

  double get progress {
    if (duration.inMilliseconds <= 0) return 0;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }
}

class VoicePlayback {
  VoicePlayback._();

  static final VoicePlayback instance = VoicePlayback._();

  final ValueNotifier<VoicePlaybackState> state = ValueNotifier(const VoicePlaybackState());

  AudioPlayer? _player;

  AudioPlayer _ensurePlayer() {
    final existing = _player;
    if (existing != null) return existing;

    final player = AudioPlayer();
    player.onPositionChanged.listen((position) {
      if (state.value.url == null) return;
      state.value = state.value.copyWith(position: position);
    });
    player.onDurationChanged.listen((duration) {
      if (state.value.url == null || duration <= Duration.zero) return;
      state.value = state.value.copyWith(duration: duration);
    });
    player.onPlayerStateChanged.listen((playerState) {
      if (state.value.url == null) return;
      switch (playerState) {
        case PlayerState.playing:
          state.value = state.value.copyWith(playing: true, loading: false);
        case PlayerState.paused:
          state.value = state.value.copyWith(playing: false, loading: false);
        case PlayerState.stopped:
          // stop() 的事件是非同步送達，會晚於切換到下一段語音時寫入的新狀態，不能據此清空。
          break;
        case PlayerState.completed:
        case PlayerState.disposed:
          state.value = const VoicePlaybackState();
      }
    });
    player.onPlayerComplete.listen((_) => state.value = const VoicePlaybackState());
    return _player = player;
  }

  bool isActive(String url) => state.value.url == url;

  Future<void> toggle(String url, {Duration expected = Duration.zero}) async {
    final current = state.value;
    final player = _ensurePlayer();

    try {
      if (current.url == url) {
        if (current.playing) {
          await player.pause();
        } else if (!current.loading) {
          state.value = current.copyWith(playing: true);
          await player.resume();
        }
        return;
      }

      if (current.url != null) await player.stop();
      state.value = VoicePlaybackState(url: url, loading: true, duration: expected);
      final local = !url.contains('://') && File(url).existsSync();
      await player.play(local ? DeviceFileSource(url) : UrlSource(url));
    } catch (_) {
      state.value = const VoicePlaybackState();
    }
  }

  Future<void> stop() async {
    if (state.value.url == null) return;
    state.value = const VoicePlaybackState();
    try {
      await _player?.stop();
    } catch (_) {}
  }
}
