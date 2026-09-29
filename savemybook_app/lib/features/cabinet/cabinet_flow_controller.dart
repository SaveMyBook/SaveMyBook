import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/cabinet.dart';
import '../../services/api_service.dart';
import '../../services/cabinet_code.dart';
import '../../services/cabinet_session_tracker.dart';
import '../../services/location_service.dart';
import 'cabinet_messages.dart';

enum CabinetFlowStep { prepare, scan, checking, confirm, match, opening, open, result, error }

enum CabinetFlowOutcome { completed, started, cancelled, manualRequested, dismissed }

enum CabinetFlowAction { rescan, close, reportManually, openMap, viewPurchases, viewSales, contactSupport, resume, retry, openSettings }

class CabinetFlowError {
  final String code;
  final String message;
  final String? detail;
  final List<CabinetFlowAction> actions;
  final CabinetBrief? cabinet;
  final String? sessionNo;
  final Set<CabinetItemKind> kinds;

  const CabinetFlowError({
    required this.code,
    required this.message,
    this.detail,
    this.actions = const [CabinetFlowAction.close],
    this.cabinet,
    this.sessionNo,
    this.kinds = const {},
  });

  static CabinetFlowError of(CabinetApiError error, {bool hasContext = false}) {
    final message = CabinetMessages.error(error);
    switch (error.code) {
      case 'CABINET_CODE_INVALID':
      case 'CABINET_CODE_EXPIRED':
      case 'CABINET_BUSY':
      case 'CABINET_TOO_FAR':
        return CabinetFlowError(code: error.code, message: message, actions: const [CabinetFlowAction.rescan, CabinetFlowAction.close]);
      case 'CABINET_OFFLINE':
        return CabinetFlowError(
          code: error.code,
          message: message,
          actions: [
            CabinetFlowAction.rescan,
            if (error.manualAllowed && hasContext) CabinetFlowAction.reportManually,
            CabinetFlowAction.close,
          ],
        );
      case 'CABINET_WRONG_CABINET':
        final cabinet = error.cabinet;
        final address = cabinet?.address ?? '';
        return CabinetFlowError(
          code: error.code,
          message: message,
          detail: address.isEmpty ? null : address,
          cabinet: cabinet,
          actions: [
            if (cabinet != null && cabinet.hasCoordinates) CabinetFlowAction.openMap,
            CabinetFlowAction.rescan,
            CabinetFlowAction.close,
          ],
        );
      case 'CABINET_NOTHING_TO_DO':
        final kinds = {
          for (final cabinet in error.otherCabinets)
            for (final code in cabinet.kinds) ?CabinetItemKind.of(code),
        };
        return CabinetFlowError(
          code: error.code,
          message: message,
          detail: CabinetMessages.otherCabinets(error),
          kinds: kinds,
          actions: [
            if (kinds.contains(CabinetItemKind.pickup)) CabinetFlowAction.viewPurchases,
            if (kinds.any((kind) => kind != CabinetItemKind.pickup)) CabinetFlowAction.viewSales,
            CabinetFlowAction.rescan,
            CabinetFlowAction.close,
          ],
        );
      case 'CABINET_ITEM_BLOCKED':
        final blocked = error.items.map((item) => item.blocked).nonNulls.firstOrNull;
        final capacity = blocked != null && CabinetMessages.capacityCodes.contains(blocked.code);
        return CabinetFlowError(
          code: error.code,
          message: message,
          actions: capacity
              ? const [CabinetFlowAction.rescan, CabinetFlowAction.close]
              : const [CabinetFlowAction.contactSupport, CabinetFlowAction.close],
        );
      case 'CABINET_ACTIVE_SESSION':
        final sessionNo = error.sessionNo;
        return CabinetFlowError(
          code: error.code,
          message: message,
          sessionNo: sessionNo,
          actions: [if (sessionNo != null) CabinetFlowAction.resume, CabinetFlowAction.close],
        );
      case CabinetApiError.locationRequired:
      case CabinetApiError.locationImprecise:
        return CabinetFlowError(
          code: error.code,
          message: message,
          actions: const [CabinetFlowAction.openSettings, CabinetFlowAction.retry, CabinetFlowAction.close],
        );
      case CabinetApiError.network:
      case CabinetApiError.locationUnavailable:
        return CabinetFlowError(code: error.code, message: message, actions: const [CabinetFlowAction.retry, CabinetFlowAction.close]);
      default:
        return CabinetFlowError(code: error.code, message: message);
    }
  }
}

typedef CabinetLocator = Future<FreshLocation> Function();

typedef CabinetLocationCheck = Future<LocationAccess?> Function();

class CabinetFlowController extends ChangeNotifier {
  CabinetFlowController({
    this.cabinetContext,
    ApiService? api,
    CabinetLocator? locate,
    CabinetLocationCheck? checkLocation,
    Stream<Map<String, dynamic>>? changes,
    DateTime Function()? clock,
    this.tick = const Duration(seconds: 1),
  })  : _api = api ?? ApiService(),
        _locate = locate ?? LocationService.fresh,
        _checkLocation = checkLocation ?? LocationService.access,
        _clock = clock ?? DateTime.now,
        _changes = changes;

  // 書櫃 QR Code 每 30 秒更新、45 秒失效，掃描後至少還有 15 秒可用；超過就改為重新掃描。
  static const codeReuseWindow = Duration(seconds: 15);

  final CabinetContext? cabinetContext;
  final Duration tick;
  final ApiService _api;
  final CabinetLocator _locate;
  final CabinetLocationCheck _checkLocation;
  final DateTime Function() _clock;
  final Stream<Map<String, dynamic>>? _changes;

  CabinetFlowStep _step = CabinetFlowStep.scan;
  CabinetSessionTracker? _tracker;
  CabinetFlowError? _error;
  String? _notice;
  Set<String> _selected = {};
  String? _selectionFor;
  int _selectionVersion = -1;
  String? _lastCode;
  DateTime? _scannedAt;
  bool _busy = false;
  bool _cancelling = false;
  CabinetCloseOutcome? _closing;
  bool _manualRequested = false;
  bool _cancelledByUser = false;
  bool _paused = false;
  bool _disposed = false;
  Timer? _ticker;

  CabinetFlowStep get step => _step;

  CabinetSession? get session => _tracker?.session;

  CabinetFlowError? get error => _error;

  String? get notice => _notice;

  Set<String> get selectedKeys => Set.unmodifiable(_selected);

  bool get busy => _busy;

  bool get cancelling => _cancelling;

  CabinetCloseOutcome? get closing => session?.status == CabinetSession.open ? _closing : null;

  bool get hasContext => cabinetContext != null;

  Duration get remaining => _tracker?.remaining ?? Duration.zero;

  bool get pickupSucceeded {
    final s = session;
    if (s == null || s.status != CabinetSession.completed) return false;
    final items = s.selectedItems;
    return items.isNotEmpty && items.every((item) => item.kind == CabinetItemKind.pickup && item.isDone);
  }

  CabinetFlowOutcome get outcome {
    if (_manualRequested) return CabinetFlowOutcome.manualRequested;
    if (_cancelledByUser) return CabinetFlowOutcome.cancelled;
    return switch (session?.status) {
      CabinetSession.completed || CabinetSession.partial => CabinetFlowOutcome.completed,
      CabinetSession.opening || CabinetSession.open || CabinetSession.needsReviewStatus => CabinetFlowOutcome.started,
      CabinetSession.cancelled => CabinetFlowOutcome.cancelled,
      _ => CabinetFlowOutcome.dismissed,
    };
  }

  static CabinetFlowStep stepFor(String status) => switch (status) {
    CabinetSession.selecting => CabinetFlowStep.confirm,
    CabinetSession.matching => CabinetFlowStep.match,
    CabinetSession.opening => CabinetFlowStep.opening,
    CabinetSession.open => CabinetFlowStep.open,
    _ => CabinetFlowStep.result,
  };

  Future<void> submitCode(String raw) async {
    if (_disposed || _busy) return;
    if (parseCabinetCode(raw) == null) {
      fail(const CabinetApiError(code: 'CABINET_CODE_INVALID'));
      return;
    }
    _lastCode = raw;
    _scannedAt = _clock();
    _error = null;
    _notice = null;
    _busy = true;
    _setStep(CabinetFlowStep.checking);
    final location = await _locate();
    if (_disposed) return;
    if (!location.isGranted) {
      _busy = false;
      fail(CabinetApiError(code: switch (location.status) {
        FreshLocation.denied => CabinetApiError.locationRequired,
        FreshLocation.imprecise => CabinetApiError.locationImprecise,
        _ => CabinetApiError.locationUnavailable,
      }));
      return;
    }
    final result = await _api.createCabinetSession(code: raw, context: cabinetContext, location: location);
    final created = result.session;
    if (_disposed) {
      if (created != null && created.status == CabinetSession.selecting) unawaited(_api.cancelCabinetSession(created.sessionNo));
      return;
    }
    if (created != null) {
      _busy = false;
      _track(created);
      return;
    }
    final error = result.error!;
    if (error.isNetwork || error.code == 'CABINET_CODE_EXPIRED') {
      final active = await _api.fetchActiveCabinetSession();
      if (_disposed) return;
      if (active != null && active.isActive) {
        _busy = false;
        _track(active);
        return;
      }
    }
    _busy = false;
    fail(error);
  }

  void resume(CabinetSession session) {
    if (_disposed) return;
    _error = null;
    _notice = null;
    _track(session);
  }

  Future<void> resumeSession(String sessionNo) async {
    if (_disposed || _busy) return;
    _busy = true;
    _error = null;
    _setStep(CabinetFlowStep.checking);
    final result = await _api.fetchCabinetSession(sessionNo);
    if (_disposed) return;
    _busy = false;
    final found = result.session;
    if (found != null) {
      _track(found);
    } else {
      fail(result.error!);
    }
  }

  void fail(CabinetApiError error) {
    if (_disposed) return;
    _error = CabinetFlowError.of(error, hasContext: hasContext);
    _setStep(CabinetFlowStep.error);
  }

  void rescan() => unawaited(prepareScan());

  Future<void> prepareScan() async {
    if (_disposed) return;
    _dropTracker();
    _error = null;
    _notice = null;
    _busy = false;
    _cancelledByUser = false;
    _lastCode = null;
    _scannedAt = null;
    _setStep(CabinetFlowStep.prepare);
    final access = await _checkLocation();
    if (_disposed || _step != CabinetFlowStep.prepare) return;
    if (access == null || access == LocationAccess.granted) {
      _setStep(CabinetFlowStep.scan);
    } else {
      fail(CabinetApiError(code: switch (access) {
        LocationAccess.denied => CabinetApiError.locationRequired,
        LocationAccess.imprecise => CabinetApiError.locationImprecise,
        _ => CabinetApiError.locationUnavailable,
      }));
    }
  }

  Future<void> retry() async {
    final code = _lastCode;
    final scannedAt = _scannedAt;
    final location = _error?.code == CabinetApiError.locationRequired || _error?.code == CabinetApiError.locationImprecise;
    if (code == null || scannedAt == null || location || _clock().difference(scannedAt) > codeReuseWindow) {
      await prepareScan();
      return;
    }
    await submitCode(code);
  }

  void requestManual() => _manualRequested = true;

  bool isSelected(String key) => _selected.contains(key);

  String? selectedOf(CabinetItemKind kind) =>
      session?.items.where((item) => item.kind == kind && _selected.contains(item.key)).firstOrNull?.key;

  void toggle(String key) {
    final s = session;
    if (s == null || _step != CabinetFlowStep.confirm || _busy) return;
    final item = s.items.where((i) => i.key == key).firstOrNull;
    if (item == null || item.isBlocked) return;
    final select = !_selected.contains(key);
    final keys = {key};
    if (item.kind == CabinetItemKind.retrieval && item.doors.isNotEmpty) {
      for (final other in s.items) {
        if (other.kind == CabinetItemKind.retrieval && !other.isBlocked && other.doors.any(item.doors.contains)) keys.add(other.key);
      }
    }
    if (select) {
      final kind = item.kind;
      if (kind != null && kind.isSingleChoice) _selected.removeAll([for (final other in s.items) if (other.kind == kind) other.key]);
      _selected.addAll(keys);
    } else {
      _selected.removeAll(keys);
    }
    _notice = null;
    notifyListeners();
  }

  Future<void> start() async {
    final s = session;
    if (_disposed || s == null || _busy || _selected.isEmpty || _step != CabinetFlowStep.confirm) return;
    _busy = true;
    _notice = null;
    notifyListeners();
    final keys = [for (final item in s.items) if (_selected.contains(item.key)) item.key];
    final result = await _api.startCabinetSession(s.sessionNo, keys);
    if (_disposed) return;
    _busy = false;
    final started = result.session;
    if (started != null) {
      _accept(started);
      return;
    }
    final error = result.error!;
    final attached = error.session;
    switch (error.code) {
      case 'CABINET_SESSION_NOT_FOUND':
      case CabinetApiError.signedOut:
        fail(error);
        return;
      case 'CABINET_SESSION_STATE':
        if (attached != null) _accept(attached);
        if (_step == CabinetFlowStep.confirm) _notice = CabinetMessages.error(error);
      case CabinetApiError.network:
        _notice = CabinetMessages.error(error);
        unawaited(_tracker?.refresh());
      default:
        if (attached != null) _accept(attached);
        _notice = CabinetMessages.error(error);
    }
    notifyListeners();
  }

  Future<bool> cancel() async {
    final s = session;
    if (_disposed) return true;
    if (s == null || (_step != CabinetFlowStep.confirm && _step != CabinetFlowStep.match)) return true;
    if (_busy) return false;
    _busy = true;
    _cancelling = true;
    _notice = null;
    notifyListeners();
    final result = await _api.cancelCabinetSession(s.sessionNo);
    if (_disposed) return true;
    _busy = false;
    _cancelling = false;
    final next = result.session ?? result.error?.session;
    if (next != null) _accept(next);
    if (result.ok && next?.status == CabinetSession.cancelled) {
      _cancelledByUser = true;
      notifyListeners();
      return true;
    }
    if (!result.ok) _notice = CabinetMessages.error(result.error!);
    notifyListeners();
    return false;
  }

  Future<String?> submitMatch(String code) async {
    final s = session;
    if (_disposed || s == null || _busy || _step != CabinetFlowStep.match) return null;
    _busy = true;
    _notice = null;
    notifyListeners();
    final result = await _api.matchCabinetSession(s.sessionNo, code);
    if (_disposed) return null;
    _busy = false;
    final matched = result.session;
    if (matched != null) {
      _accept(matched);
      return null;
    }
    final error = result.error!;
    _requestFailed(error, CabinetFlowStep.match, CabinetMessages.error);
    return error.code;
  }

  Future<void> close(CabinetCloseOutcome outcome) async {
    final s = session;
    if (_disposed || s == null || _busy || _step != CabinetFlowStep.open) return;
    _busy = true;
    _closing = outcome;
    _notice = null;
    notifyListeners();
    final result = await _api.closeCabinetSession(s.sessionNo, outcome);
    if (_disposed) return;
    _busy = false;
    final next = result.session;
    if (next != null) {
      _accept(next);
      return;
    }
    _closing = null;
    _requestFailed(result.error!, CabinetFlowStep.open, CabinetMessages.closeError);
  }

  void _requestFailed(CabinetApiError error, CabinetFlowStep step, String Function(CabinetApiError) message) {
    switch (error.code) {
      case 'CABINET_SESSION_NOT_FOUND':
      case CabinetApiError.signedOut:
        fail(error);
        return;
      case CabinetApiError.network:
        _notice = message(error);
        unawaited(_tracker?.refresh());
      default:
        final attached = error.session;
        if (attached != null) _accept(attached);
        if (_step == step) _notice = message(error);
    }
    notifyListeners();
  }

  void abandon() {
    final s = session;
    if (_disposed || s == null || (s.status != CabinetSession.selecting && s.status != CabinetSession.matching)) return;
    _cancelledByUser = true;
    notifyListeners();
    unawaited(_api.cancelCabinetSession(s.sessionNo));
  }

  Future<void> refresh() async => _tracker?.refresh();

  void pause() {
    _paused = true;
    _tracker?.pause();
    _ticker?.cancel();
    _ticker = null;
  }

  void resumePolling() {
    if (!_paused) return;
    _paused = false;
    _tracker?.resume();
    _syncTicker();
  }

  void _track(CabinetSession session) {
    _dropTracker();
    final tracker = CabinetSessionTracker(session, fetch: _api.fetchCabinetSession, changes: _changes);
    _tracker = tracker;
    tracker.addListener(_onTracker);
    if (_paused) tracker.pause();
    _apply(tracker.session);
  }

  void _accept(CabinetSession next) {
    final tracker = _tracker;
    if (tracker == null || tracker.session.sessionNo != next.sessionNo) {
      _track(next);
    } else if (!tracker.accept(next)) {
      _apply(tracker.session);
    }
  }

  void _onTracker() {
    final tracker = _tracker;
    if (tracker == null || _disposed) return;
    _apply(tracker.session);
  }

  void _apply(CabinetSession s) {
    if (s.status == CabinetSession.selecting) _syncSelection(s);
    final next = stepFor(s.status);
    if (next != _step) _notice = null;
    if (s.status != CabinetSession.open || (s.closeDoorFirst && !_busy)) _closing = null;
    _setStep(next);
  }

  void _syncSelection(CabinetSession s) {
    if (_selectionFor == s.sessionNo && _selectionVersion == s.version) return;
    final allowed = {for (final item in s.items) if (!item.isBlocked) item.key};
    if (_selectionFor != s.sessionNo) {
      _selected = {...s.selectedKeys};
    } else {
      _selected = _selected.where(allowed.contains).toSet();
    }
    final kept = <CabinetItemKind>{};
    for (final item in s.items) {
      final kind = item.kind;
      if (kind != null && kind.isSingleChoice && _selected.contains(item.key) && !kept.add(kind)) _selected.remove(item.key);
    }
    _selectionFor = s.sessionNo;
    _selectionVersion = s.version;
  }

  void _setStep(CabinetFlowStep next) {
    if (_disposed) return;
    _step = next;
    _syncTicker();
    notifyListeners();
  }

  void _syncTicker() {
    final ticking = !_paused &&
        _tracker != null &&
        const {CabinetFlowStep.confirm, CabinetFlowStep.match, CabinetFlowStep.opening, CabinetFlowStep.open}.contains(_step);
    if (!ticking) {
      _ticker?.cancel();
      _ticker = null;
      return;
    }
    _ticker ??= Timer.periodic(tick, (_) {
      if (!_disposed) notifyListeners();
    });
  }

  void _dropTracker() {
    final tracker = _tracker;
    _tracker = null;
    tracker?.removeListener(_onTracker);
    tracker?.dispose();
    _selectionFor = null;
    _selectionVersion = -1;
    _selected = {};
    _closing = null;
    _syncTicker();
  }

  static String formatClock(Duration value) {
    final seconds = (value.inMilliseconds / 1000).ceil();
    final minutes = seconds ~/ 60;
    return '$minutes:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  static int secondsOf(Duration value) => (value.inMilliseconds / 1000).ceil();

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    _ticker = null;
    final tracker = _tracker;
    _tracker = null;
    tracker?.removeListener(_onTracker);
    tracker?.dispose();
    super.dispose();
  }
}
