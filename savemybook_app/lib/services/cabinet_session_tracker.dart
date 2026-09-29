import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/cabinet.dart';
import 'api_service.dart';
import 'realtime_service.dart';

typedef CabinetSessionFetcher = Future<CabinetResult> Function(String sessionNo);

class CabinetSessionTracker extends ChangeNotifier {
  CabinetSessionTracker(
    CabinetSession session, {
    CabinetSessionFetcher? fetch,
    Stream<Map<String, dynamic>>? changes,
    Stopwatch? stopwatch,
    this.selectingInterval = const Duration(seconds: 2),
    this.openingInterval = const Duration(seconds: 1),
  })  : _session = session,
        _fetch = fetch ?? ApiService().fetchCabinetSession,
        _clock = stopwatch ?? Stopwatch() {
    _clock
      ..reset()
      ..start();
    _subscription = (changes ?? RealtimeService.instance.cabinetSessionChanges).listen(_onPush);
    _schedule();
  }

  final Duration selectingInterval;
  final Duration openingInterval;
  final CabinetSessionFetcher _fetch;
  final Stopwatch _clock;
  StreamSubscription<Map<String, dynamic>>? _subscription;
  Timer? _poll;
  CabinetSession _session;
  CabinetApiError? _lastError;
  bool _paused = false;
  bool _fetching = false;
  bool _disposed = false;

  CabinetSession get session => _session;

  CabinetApiError? get lastError => _lastError;

  bool get isPaused => _paused;

  // 倒數以收到回應後經過的時間計算，不看手機時鐘；歸零後仍等伺服器回報下一個狀態。
  Duration get remaining {
    final total = _session.remainingMs;
    if (total == null) return Duration.zero;
    final left = total - _clock.elapsedMilliseconds;
    return Duration(milliseconds: left < 0 ? 0 : left);
  }

  Duration? get pollInterval => switch (_session.status) {
    CabinetSession.selecting || CabinetSession.matching => selectingInterval,
    CabinetSession.opening || CabinetSession.open => openingInterval,
    _ => null,
  };

  bool accept(CabinetSession next) {
    if (_disposed || next.sessionNo != _session.sessionNo || next.version < _session.version) return false;
    final statusChanged = next.status != _session.status;
    _session = next;
    _lastError = null;
    _clock
      ..reset()
      ..start();
    if (statusChanged) _schedule();
    notifyListeners();
    return true;
  }

  Future<void> refresh() async {
    if (_disposed || _fetching) return;
    _fetching = true;
    try {
      final result = await _fetch(_session.sessionNo);
      if (_disposed) return;
      final next = result.session;
      if (next != null) {
        accept(next);
      } else {
        _lastError = result.error;
        notifyListeners();
      }
    } finally {
      _fetching = false;
    }
  }

  void pause() {
    _paused = true;
    _poll?.cancel();
    _poll = null;
  }

  void resume() {
    if (_disposed || !_paused) return;
    _paused = false;
    _schedule();
    unawaited(refresh());
  }

  void _onPush(Map<String, dynamic> json) {
    if (json['session_no'] != _session.sessionNo) return;
    final next = CabinetSession.tryParse(json);
    if (next == null || next.version <= _session.version) return;
    accept(next);
  }

  void _schedule() {
    _poll?.cancel();
    _poll = null;
    final interval = pollInterval;
    if (_disposed || _paused || interval == null) return;
    _poll = Timer.periodic(interval, (_) => unawaited(refresh()));
  }

  @override
  void dispose() {
    _disposed = true;
    _poll?.cancel();
    _poll = null;
    unawaited(_subscription?.cancel());
    _clock.stop();
    super.dispose();
  }
}
