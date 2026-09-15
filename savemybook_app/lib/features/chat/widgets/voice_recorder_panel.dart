import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../../../i18n/strings.dart';
import '../../../services/voice_service.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/motion.dart';
import 'chat_format.dart';

enum VoicePanelPhase { preparing, idle, holding, locked, review, denied }

class VoiceRecorderPanel extends StatefulWidget {
  final VoiceRecorder recorder;
  final double height;
  final double bottomInset;
  final ValueChanged<VoiceClip> onSend;
  final ValueChanged<VoiceStartResult> onUnavailable;
  final ValueChanged<bool> onBusyChanged;
  final VoidCallback onClose;

  const VoiceRecorderPanel({
    super.key,
    required this.recorder,
    required this.height,
    required this.onSend,
    required this.onUnavailable,
    required this.onBusyChanged,
    required this.onClose,
    this.bottomInset = 0,
  });

  @override
  State<VoiceRecorderPanel> createState() => _VoiceRecorderPanelState();
}

class _VoiceRecorderPanelState extends State<VoiceRecorderPanel> with WidgetsBindingObserver {
  static const _tapSlop = 18.0;
  static const _dragReach = 104.0;
  static const _dragTrigger = 64.0;
  static const _quickTap = Duration(milliseconds: 300);
  static const _tick = Duration(milliseconds: 90);
  static const _warnAt = Duration(seconds: 10);

  VoicePanelPhase _phase = VoicePanelPhase.preparing;
  final List<double> _samples = [];
  Duration _downAt = Duration.zero;
  Timer? _ticker;
  Timer? _noticeTimer;
  Duration _elapsed = Duration.zero;
  VoiceClip? _clip;
  String? _notice;
  bool _starting = false;
  bool _stopping = false;
  bool _pointerDown = false;
  VoicePanelPhase? _downPhase;
  Offset _origin = Offset.zero;
  double _drag = 0;
  double _travel = 0;
  bool _cancelZone = false;
  bool _warned = false;

  VoiceRecorder get _recorder => widget.recorder;

  bool get _recording => _phase == VoicePanelPhase.holding || _phase == VoicePanelPhase.locked;

  bool get _busy => _recording || _phase == VoicePanelPhase.review;

  Duration get _remaining => VoiceRecorder.maxDuration - _elapsed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _recorder.onInterrupted = _onInterrupted;
    _prepare();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _noticeTimer?.cancel();
    if (_recorder.onInterrupted == _onInterrupted) _recorder.onInterrupted = null;
    if (_recording || _starting) _recorder.cancel();
    _dropClip();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // inactive 也會在系統權限對話框、控制中心出現時觸發，只能以 hidden/paused 判斷真正離開。
    if (state == AppLifecycleState.hidden || state == AppLifecycleState.paused) {
      if (_recording) _finish(send: false);
      final clip = _clip;
      if (clip != null && VoicePlayback.instance.isActive(clip.path)) VoicePlayback.instance.stop();
    } else if (state == AppLifecycleState.resumed && _phase == VoicePanelPhase.denied) {
      _recheckPermission();
    }
  }

  Future<void> _prepare() async {
    final granted = await _recorder.ensurePermission();
    if (!mounted || _phase != VoicePanelPhase.preparing) return;
    setState(() => _phase = granted ? VoicePanelPhase.idle : VoicePanelPhase.denied);
  }

  Future<void> _recheckPermission() async {
    final granted = await _recorder.checkPermission();
    if (!mounted || !granted || _phase != VoicePanelPhase.denied) return;
    setState(() => _phase = VoicePanelPhase.idle);
  }

  void _setPhase(VoicePanelPhase phase) {
    final wasBusy = _busy;
    setState(() => _phase = phase);
    if (wasBusy != _busy) widget.onBusyChanged(_busy);
  }

  void _showNotice(String text) {
    _noticeTimer?.cancel();
    setState(() => _notice = text);
    _noticeTimer = Timer(const Duration(milliseconds: 2400), () {
      if (mounted) setState(() => _notice = null);
    });
  }

  void _clearNotice() {
    _noticeTimer?.cancel();
    _notice = null;
  }

  Future<void> _begin() async {
    if (_starting || _phase != VoicePanelPhase.idle) return;
    _starting = true;
    setState(_clearNotice);
    final result = await _recorder.start();
    _starting = false;
    if (!mounted) {
      if (result == VoiceStartResult.started) _recorder.cancel();
      return;
    }

    switch (result) {
      case VoiceStartResult.started:
        HapticFeedback.mediumImpact();
        _samples.clear();
        _elapsed = Duration.zero;
        _warned = false;
        _cancelZone = false;
        _drag = 0;
        _ticker?.cancel();
        _ticker = Timer.periodic(_tick, (_) => _onTick());
        _setPhase(_pointerDown ? VoicePanelPhase.holding : VoicePanelPhase.locked);
      case VoiceStartResult.permissionGranted:
        _pointerDown = false;
        await _begin();
      case VoiceStartResult.denied:
        _pointerDown = false;
        _setPhase(VoicePanelPhase.denied);
      case VoiceStartResult.failed:
        _pointerDown = false;
        setState(() {});
        widget.onUnavailable(result);
    }
  }

  void _onTick() {
    if (!mounted || !_recording) return;
    final elapsed = _recorder.elapsed;
    if (elapsed >= VoiceRecorder.maxDuration) {
      HapticFeedback.heavyImpact();
      _finish(send: false, notice: S.maximumRecordingLengthReached);
      return;
    }
    if (!_warned && VoiceRecorder.maxDuration - elapsed <= _warnAt) {
      _warned = true;
      HapticFeedback.lightImpact();
    }
    setState(() {
      _elapsed = elapsed;
      _samples.add(_recorder.level.value);
    });
  }

  void _onInterrupted() {
    if (mounted && _recording) _finish(send: false);
  }

  Future<void> _finish({required bool send, String? notice}) async {
    if (_stopping || !_recording) return;
    _stopping = true;
    _ticker?.cancel();
    _ticker = null;
    _pointerDown = false;
    final clip = await _recorder.stop();
    _stopping = false;
    if (!mounted) {
      VoiceRecorder.deleteFile(clip?.path);
      return;
    }

    _cancelZone = false;
    _drag = 0;
    if (clip == null) {
      HapticFeedback.lightImpact();
      _setPhase(VoicePanelPhase.idle);
      _showNotice(S.recordingTooShort);
      return;
    }
    if (send) {
      HapticFeedback.lightImpact();
      _setPhase(VoicePanelPhase.idle);
      widget.onSend(clip);
      return;
    }
    _clip = clip;
    _elapsed = clip.duration;
    _setPhase(VoicePanelPhase.review);
    if (notice != null) _showNotice(notice);
  }

  Future<void> _cancelRecording() async {
    if (_stopping || !_recording) return;
    _stopping = true;
    _ticker?.cancel();
    _ticker = null;
    _pointerDown = false;
    await _recorder.cancel();
    _stopping = false;
    if (!mounted) return;
    HapticFeedback.lightImpact();
    _cancelZone = false;
    _drag = 0;
    _setPhase(VoicePanelPhase.idle);
  }

  void _dropClip() {
    final clip = _clip;
    if (clip == null) return;
    _clip = null;
    if (VoicePlayback.instance.isActive(clip.path)) VoicePlayback.instance.stop();
    VoiceRecorder.deleteFile(clip.path);
  }

  void _discardReview() {
    HapticFeedback.lightImpact();
    _dropClip();
    _clearNotice();
    _setPhase(VoicePanelPhase.idle);
  }

  void _sendReview() {
    final clip = _clip;
    if (clip == null) return;
    _clip = null;
    if (VoicePlayback.instance.isActive(clip.path)) VoicePlayback.instance.stop();
    HapticFeedback.lightImpact();
    _clearNotice();
    _setPhase(VoicePanelPhase.idle);
    widget.onSend(clip);
  }

  void _togglePreview() {
    final clip = _clip;
    if (clip == null) return;
    HapticFeedback.selectionClick();
    VoicePlayback.instance.toggle(clip.path, expected: clip.duration);
  }

  void _handleBack() {
    switch (_phase) {
      case VoicePanelPhase.holding:
      case VoicePanelPhase.locked:
        _finish(send: false);
      case VoicePanelPhase.review:
        _discardReview();
      case VoicePanelPhase.preparing:
      case VoicePanelPhase.idle:
      case VoicePanelPhase.denied:
        widget.onClose();
    }
  }

  void _onPointerDown(PointerDownEvent event) {
    if (event.kind == PointerDeviceKind.mouse && event.buttons != kPrimaryButton) return;
    if (_pointerDown) return;
    _downPhase = _phase;
    _origin = event.position;
    _travel = 0;
    if (_phase != VoicePanelPhase.idle) return;
    _pointerDown = true;
    _downAt = event.timeStamp;
    _begin();
  }

  void _onPointerMove(PointerMoveEvent event) {
    final delta = event.position - _origin;
    _travel = math.max(_travel, delta.distance);
    if (_phase != VoicePanelPhase.holding) return;

    final dx = delta.dx.clamp(-_dragReach, _dragReach);
    if (dx >= _dragTrigger) {
      HapticFeedback.mediumImpact();
      _pointerDown = false;
      _drag = 0;
      _cancelZone = false;
      _setPhase(VoicePanelPhase.locked);
      return;
    }
    final cancel = dx <= -_dragTrigger;
    if (cancel != _cancelZone) HapticFeedback.selectionClick();
    setState(() {
      _drag = dx;
      _cancelZone = cancel;
    });
  }

  void _onPointerUp(PointerUpEvent event) {
    final downPhase = _downPhase;
    _downPhase = null;
    final tapped = _travel < _tapSlop;

    if (downPhase == VoicePanelPhase.idle) {
      _pointerDown = false;
      if (_phase != VoicePanelPhase.holding) return;
      if (_cancelZone) {
        _cancelRecording();
      } else if (tapped && event.timeStamp - _downAt < _quickTap) {
        HapticFeedback.selectionClick();
        _setPhase(VoicePanelPhase.locked);
      } else {
        _finish(send: true);
      }
      return;
    }

    if (!tapped || downPhase != _phase) return;
    if (_phase == VoicePanelPhase.locked) {
      _finish(send: false);
    } else if (_phase == VoicePanelPhase.review) {
      _togglePreview();
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _downPhase = null;
    _pointerDown = false;
    if (_phase != VoicePanelPhase.holding) return;
    setState(() {
      _drag = 0;
      _cancelZone = false;
    });
    _setPhase(VoicePanelPhase.locked);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: SizedBox(
        height: widget.height,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, widget.bottomInset + 20),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: 360,
                child: AnimatedSwitcher(
                  duration: Motion.base,
                  switchInCurve: Motion.enterCurve,
                  switchOutCurve: Motion.exitCurve,
                  child: _phase == VoicePanelPhase.denied
                      ? _buildDenied(c)
                      : KeyedSubtree(key: const ValueKey('recorder'), child: _buildRecorder(c)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecorder(AppColors c) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: 40, child: Center(child: _buildClock(c))),
        const SizedBox(height: 6),
        SizedBox(height: 32, child: _buildWave(c)),
        const SizedBox(height: 8),
        SizedBox(height: 20, child: Center(child: _buildHint(c))),
        const SizedBox(height: 16),
        SizedBox(height: 88, child: _buildControls(c)),
      ],
    );
  }

  Widget _buildClock(AppColors c) {
    final warn = _recording && _remaining <= _warnAt;
    final clip = _phase == VoicePanelPhase.review ? _clip : null;
    final text = ValueListenableBuilder<VoicePlaybackState>(
      valueListenable: VoicePlayback.instance.state,
      builder: (context, state, _) {
        var seconds = _recording ? _elapsed.inSeconds : 0;
        if (clip != null) {
          seconds = state.url == clip.path && state.position > Duration.zero ? state.position.inSeconds : clip.seconds;
        }
        return Text(
          chatDuration(seconds),
          style: TextStyle(
            fontSize: 30,
            height: 1.1,
            fontWeight: FontWeight.w700,
            color: warn ? c.warning : (_phase == VoicePanelPhase.idle || _phase == VoicePanelPhase.preparing ? c.textHint : c.textPrimary),
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        );
      },
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: Motion.micro,
          child: _recording
              ? Padding(
                  key: const ValueKey('dot'),
                  padding: const EdgeInsets.only(right: 10),
                  child: _BlinkingDot(color: c.danger),
                )
              : const SizedBox(key: ValueKey('none')),
        ),
        text,
      ],
    );
  }

  Widget _buildWave(AppColors c) {
    final clip = _clip;
    if (_phase == VoicePanelPhase.review && clip != null) {
      return ValueListenableBuilder<VoicePlaybackState>(
        valueListenable: VoicePlayback.instance.state,
        builder: (context, state, _) {
          final progress = state.url == clip.path ? state.progress : 0.0;
          return CustomPaint(
            size: const Size(260, 32),
            painter: _ReviewWavePainter(
              samples: _samples,
              progress: progress,
              active: c.accent,
              idle: c.accent.withValues(alpha: 0.28),
            ),
          );
        },
      );
    }
    final tint = _cancelZone ? c.danger : (_recording ? c.accent : c.iconInactive);
    return CustomPaint(
      size: const Size(260, 32),
      painter: _LiveWavePainter(samples: List.of(_samples), color: tint, live: _recording),
    );
  }

  Widget _buildHint(AppColors c) {
    String text;
    Color color = c.textSecondary;

    final notice = _notice;
    if (_phase == VoicePanelPhase.holding && _cancelZone) {
      text = S.releaseCancel;
      color = c.danger;
    } else if (_recording && _remaining <= _warnAt) {
      final seconds = (math.max(0, _remaining.inMilliseconds) / 1000).ceil();
      text = S.p0SRemaining(seconds);
      color = c.warning;
    } else if (_phase == VoicePanelPhase.holding) {
      text = S.releaseSend;
    } else if (_phase == VoicePanelPhase.locked) {
      text = S.recording;
    } else if (notice != null) {
      text = notice;
      color = _phase == VoicePanelPhase.review ? c.warning : c.danger;
    } else if (_phase == VoicePanelPhase.review) {
      text = '';
    } else {
      text = S.tapHoldRecord;
    }

    return AnimatedSwitcher(
      duration: Motion.micro,
      child: Text(
        text,
        key: ValueKey(text),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  Widget _buildControls(AppColors c) {
    final holding = _phase == VoicePanelPhase.holding;
    final reach = (_drag.abs() / _dragTrigger).clamp(0.0, 1.0);

    Widget left;
    Widget right;
    switch (_phase) {
      case VoicePanelPhase.holding:
        left = _DropTarget(
          key: const ValueKey('cancel-target'),
          icon: _cancelZone ? Icons.delete_rounded : Icons.delete_outline_rounded,
          color: c.danger,
          background: c.inputFill,
          progress: _drag < 0 ? reach : 0,
          active: _cancelZone,
        );
        right = _DropTarget(
          key: const ValueKey('lock-target'),
          icon: Icons.lock_outline_rounded,
          color: c.accent,
          background: c.inputFill,
          progress: _drag > 0 ? reach : 0,
          active: false,
        );
      case VoicePanelPhase.locked:
        left = _SideButton(
          key: const ValueKey('cancel'),
          icon: Icons.delete_outline_rounded,
          tooltip: S.discard,
          color: c.textSecondary,
          background: c.inputFill,
          onTap: _cancelRecording,
        );
        right = _SideButton(
          key: const ValueKey('send'),
          icon: Icons.send_rounded,
          tooltip: S.send,
          color: Colors.white,
          background: chatMineBubble(c),
          onTap: () => _finish(send: true),
        );
      case VoicePanelPhase.review:
        left = _SideButton(
          key: const ValueKey('discard'),
          icon: Icons.delete_outline_rounded,
          tooltip: S.discard,
          color: c.textSecondary,
          background: c.inputFill,
          onTap: _discardReview,
        );
        right = _SideButton(
          key: const ValueKey('send'),
          icon: Icons.send_rounded,
          tooltip: S.send,
          color: Colors.white,
          background: chatMineBubble(c),
          onTap: _sendReview,
        );
      case VoicePanelPhase.preparing:
      case VoicePanelPhase.idle:
      case VoicePanelPhase.denied:
        left = const SizedBox(key: ValueKey('empty-left'), width: 52, height: 52);
        right = const SizedBox(key: ValueKey('empty-right'), width: 52, height: 52);
    }

    Widget side(Widget child) => SizedBox(
          width: 56,
          height: 56,
          child: Center(
            child: AnimatedSwitcher(
              duration: Motion.micro,
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: CurvedAnimation(parent: animation, curve: Motion.pop),
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: child,
            ),
          ),
        );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        side(left),
        const SizedBox(width: 40),
        Transform.translate(
          offset: Offset(holding ? _drag : 0, 0),
          child: _buildMainButton(c),
        ),
        const SizedBox(width: 40),
        side(right),
      ],
    );
  }

  Widget _buildMainButton(AppColors c) {
    final review = _phase == VoicePanelPhase.review;
    final ready = _phase != VoicePanelPhase.preparing;
    final base = chatMineBubble(c);
    final bg = _cancelZone
        ? c.danger
        : review
            ? c.accent.withValues(alpha: c.isDark ? 0.24 : 0.12)
            : ready
                ? base
                : base.withValues(alpha: 0.5);
    final fg = review ? c.accent : Colors.white;
    final pressed = _pointerDown || _phase == VoicePanelPhase.holding;

    final String label;
    switch (_phase) {
      case VoicePanelPhase.locked:
        label = S.stopRecording;
      case VoicePanelPhase.holding:
        label = S.releaseSend;
      case VoicePanelPhase.review:
        label = S.preview2;
      case VoicePanelPhase.preparing:
      case VoicePanelPhase.idle:
      case VoicePanelPhase.denied:
        label = S.startRecording;
    }

    Widget icon(bool playing) {
      final IconData data;
      final String key;
      if (review) {
        data = playing ? Icons.pause_rounded : Icons.play_arrow_rounded;
        key = playing ? 'pause' : 'play';
      } else if (_phase == VoicePanelPhase.locked) {
        data = Icons.stop_rounded;
        key = 'stop';
      } else if (_cancelZone) {
        data = Icons.delete_outline_rounded;
        key = 'trash';
      } else {
        data = Icons.mic_rounded;
        key = 'mic';
      }
      return AnimatedSwitcher(
        duration: Motion.micro,
        transitionBuilder: (child, animation) => ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Motion.pop),
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: Icon(data, key: ValueKey(key), color: fg, size: 36),
      );
    }

    return Semantics(
      button: true,
      label: label,
      child: MouseRegion(
        cursor: ready ? SystemMouseCursors.click : MouseCursor.defer,
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: ready ? _onPointerDown : null,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          onPointerCancel: _onPointerCancel,
          child: ValueListenableBuilder<double>(
            valueListenable: _recorder.level,
            builder: (context, level, _) {
              final glow = _recording ? level : 0.0;
              return ValueListenableBuilder<VoicePlaybackState>(
                valueListenable: VoicePlayback.instance.state,
                builder: (context, state, _) {
                  final clip = _clip;
                  final playing = review && clip != null && state.url == clip.path && state.playing;
                  return AnimatedScale(
                    scale: pressed ? 1.1 : 1,
                    duration: Motion.base,
                    curve: Motion.pop,
                    child: AnimatedContainer(
                      duration: Motion.micro,
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: bg,
                        shape: BoxShape.circle,
                        boxShadow: _recording
                            ? [
                                BoxShadow(
                                  color: bg.withValues(alpha: 0.32),
                                  blurRadius: 10 + 22 * glow,
                                  spreadRadius: 2 + 10 * glow,
                                ),
                              ]
                            : review
                                ? null
                                : [
                                    BoxShadow(
                                      color: base.withValues(alpha: 0.22),
                                      blurRadius: 14,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                      ),
                      alignment: Alignment.center,
                      child: icon(playing),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDenied(AppColors c) {
    final canOpenSettings =
        !kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android);

    return Column(
      key: const ValueKey('denied'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(color: c.danger.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: Icon(Icons.mic_off_rounded, color: c.danger, size: 28),
        ),
        const SizedBox(height: 14),
        Text(
          S.microphoneUnavailable,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.textPrimary),
        ),
        const SizedBox(height: 6),
        Text(
          S.microphoneAccessNeededRecordTurnSettings,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, height: 1.4, color: c.textSecondary),
        ),
        if (canOpenSettings) ...[
          const SizedBox(height: 18),
          SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              onPressed: () => Geolocator.openAppSettings(),
              style: ElevatedButton.styleFrom(
                backgroundColor: chatMineBubble(c),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              ),
              icon: const Icon(Icons.settings_outlined, size: 18),
              label: Text(S.openSettings, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ],
    );
  }
}

class _SideButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final Color background;
  final VoidCallback onTap;

  const _SideButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.background,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: background,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 52, height: 52, child: Icon(icon, color: color, size: 24)),
        ),
      ),
    );
  }
}

class _DropTarget extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color background;
  final double progress;
  final bool active;

  const _DropTarget({
    super.key,
    required this.icon,
    required this.color,
    required this.background,
    required this.progress,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Motion.instant,
      width: 52,
      height: 52,
      transform: Matrix4.diagonal3Values(1 + 0.12 * progress, 1 + 0.12 * progress, 1),
      transformAlignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? color : Color.lerp(background, color.withValues(alpha: 0.18), progress),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.2 + 0.5 * progress), width: 1.5),
      ),
      child: Icon(icon, size: 24, color: active ? Colors.white : color),
    );
  }
}

class _BlinkingDot extends StatefulWidget {
  final Color color;

  const _BlinkingDot({required this.color});

  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.25, end: 1.0).animate(_controller),
      child: Container(width: 10, height: 10, decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle)),
    );
  }
}

class _LiveWavePainter extends CustomPainter {
  final List<double> samples;
  final Color color;
  final bool live;

  _LiveWavePainter({required this.samples, required this.color, required this.live});

  @override
  void paint(Canvas canvas, Size size) {
    const step = 5.0;
    final count = (size.width / step).floor();
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.6;
    final visible = samples.length > count ? samples.sublist(samples.length - count) : samples;
    for (var i = 0; i < count; i++) {
      final sampleIndex = visible.length - count + i;
      final has = live && sampleIndex >= 0;
      final level = has ? visible[sampleIndex] : 0.0;
      final h = math.max(3.0, size.height * (0.12 + 0.88 * level));
      final x = i * step + step / 2;
      paint.color = has ? color : color.withValues(alpha: 0.3);
      canvas.drawLine(Offset(x, (size.height - h) / 2), Offset(x, (size.height + h) / 2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LiveWavePainter old) => true;
}

class _ReviewWavePainter extends CustomPainter {
  final List<double> samples;
  final double progress;
  final Color active;
  final Color idle;

  _ReviewWavePainter({required this.samples, required this.progress, required this.active, required this.idle});

  @override
  void paint(Canvas canvas, Size size) {
    const step = 5.0;
    final count = (size.width / step).floor();
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.6;
    for (var i = 0; i < count; i++) {
      var level = 0.0;
      if (samples.isNotEmpty) {
        final from = (i * samples.length / count).floor();
        final to = math.max(from + 1, ((i + 1) * samples.length / count).floor());
        for (var j = from; j < to && j < samples.length; j++) {
          level = math.max(level, samples[j]);
        }
      }
      final h = math.max(3.0, size.height * (0.12 + 0.88 * level));
      final x = i * step + step / 2;
      paint.color = (i + 0.5) / count <= progress ? active : idle;
      canvas.drawLine(Offset(x, (size.height - h) / 2), Offset(x, (size.height + h) / 2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ReviewWavePainter old) =>
      old.progress != progress || old.active != active || old.idle != idle || old.samples.length != samples.length;
}
