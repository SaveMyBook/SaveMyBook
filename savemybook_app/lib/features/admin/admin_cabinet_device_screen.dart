import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../i18n/strings.dart';
import '../../models/admin_models.dart';
import '../../models/cabinet.dart';
import '../../services/api_service.dart';
import '../../services/verification_service.dart';
import '../../utils/api_helpers.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_labels.dart';
import '../../utils/app_radius.dart';
import '../../utils/cabinet_labels.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_tiles.dart';
import '../../widgets/responsive.dart';
import '../../widgets/state_views.dart';
import '../cabinet/cabinet_messages.dart';
import 'admin_cabinet_open_sheet.dart';
import 'admin_cabinet_pairing_dialog.dart';
import 'admin_cabinet_session_sheet.dart';
import 'admin_layout.dart';

enum _History { sessions, events }

class _MenuEntry<T> {
  final T value;
  final String label;
  final IconData icon;
  final Color? color;
  final bool enabled;

  const _MenuEntry(this.value, this.label, this.icon, {this.color, this.enabled = true});
}

enum _DoorAction { open, confirm, place, clear, maintenance, endMaintenance, clearFault }

class AdminCabinetDeviceScreen extends StatefulWidget {
  static const refreshInterval = Duration(seconds: 5);

  final int cabinetId;
  final String? cabinetName;
  final bool focusPending;

  const AdminCabinetDeviceScreen({super.key, required this.cabinetId, this.cabinetName, this.focusPending = false});

  @override
  State<AdminCabinetDeviceScreen> createState() => _AdminCabinetDeviceScreenState();
}

class _AdminCabinetDeviceScreenState extends State<AdminCabinetDeviceScreen> {
  final ApiService _api = ApiService();
  final ScrollController _scroll = ScrollController();
  final GlobalKey _reportsKey = GlobalKey();
  final GlobalKey _reviewsKey = GlobalKey();
  final Map<int, GlobalKey> _doorKeys = {};

  AdminCabinetDeviceSummary? _summary;
  List<AdminCabinetManualReport> _reports = [];
  List<AdminCabinetSessionRow> _reviews = [];
  List<AdminCabinetSessionRow> _sessions = [];
  List<AdminCabinetEventRow> _events = [];
  int _sessionPage = 1;
  int _eventPage = 1;
  bool _sessionsMore = false;
  bool _eventsMore = false;
  bool _loadingMore = false;
  _History _history = _History.sessions;
  bool _isLoading = true;
  bool _busy = false;
  bool _focused = false;
  Future<void>? _inflight;
  Timer? _timer;

  int get _cabinetId => widget.cabinetId;

  String get _cabinetName {
    final name = _summary?.cabinetName ?? '';
    return name.isNotEmpty ? name : (widget.cabinetName ?? '');
  }

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(AdminCabinetDeviceScreen.refreshInterval, (_) => _autoRefresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _autoRefresh() {
    if (!mounted || _busy || _inflight != null) return;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    _load();
  }

  Future<void> _load() async {
    while (_inflight != null) {
      await _inflight;
    }
    if (!mounted) return;
    final future = _fetch();
    _inflight = future;
    try {
      await future;
    } finally {
      if (identical(_inflight, future)) _inflight = null;
    }
    if (mounted && widget.focusPending && !_focused && _summary != null) _focusPending();
  }

  Future<void> _fetch() async {
    final firstSessions = _sessionPage == 1;
    final firstEvents = _eventPage == 1;
    final summaryRequest = _api.fetchCabinetDevice(_cabinetId);
    final reportsRequest = _api.fetchCabinetManualReports(_cabinetId);
    final reviewsRequest = _api.fetchCabinetSessions(_cabinetId, status: 'review');
    final sessionsRequest = firstSessions ? _api.fetchCabinetSessions(_cabinetId) : null;
    final eventsRequest = firstEvents ? _api.fetchCabinetEvents(_cabinetId) : null;
    final summary = await summaryRequest;
    final reports = await reportsRequest;
    final reviews = await reviewsRequest;
    final sessions = await sessionsRequest;
    final events = await eventsRequest;
    if (!mounted) return;
    setState(() {
      if (summary != null) _summary = summary;
      if (reports.ok) _reports = reports.items;
      if (reviews.ok) _reviews = reviews.items;
      if (sessions != null && sessions.ok && _sessionPage == 1) {
        _sessions = sessions.items;
        _sessionsMore = sessions.hasMore;
      }
      if (events != null && events.ok && _eventPage == 1) {
        _events = events.items;
        _eventsMore = events.hasMore;
      }
      _isLoading = false;
    });
  }

  Future<void> _reload() {
    _sessionPage = 1;
    _eventPage = 1;
    return _load();
  }

  Future<void> _retry() async {
    setState(() => _isLoading = true);
    await _reload();
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    final history = _history;
    if (history == _History.sessions ? !_sessionsMore : !_eventsMore) return;
    setState(() => _loadingMore = true);
    if (history == _History.sessions) {
      final next = _sessionPage + 1;
      final page = await _api.fetchCabinetSessions(_cabinetId, page: next);
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
        if (!page.ok) {
          _sessionsMore = false;
          return;
        }
        final known = {for (final row in _sessions) row.sessionNo};
        _sessions = [..._sessions, ...page.items.where((row) => !known.contains(row.sessionNo))];
        _sessionPage = next;
        _sessionsMore = page.hasMore;
      });
    } else {
      final next = _eventPage + 1;
      final page = await _api.fetchCabinetEvents(_cabinetId, page: next);
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
        if (!page.ok) {
          _eventsMore = false;
          return;
        }
        String keyOf(AdminCabinetEventRow e) => '${e.type}|${e.occurredAt?.toIso8601String()}|${e.channel}|${e.sessionNo}';
        final known = {for (final row in _events) keyOf(row)};
        _events = [..._events, ...page.items.where((row) => !known.contains(keyOf(row)))];
        _eventPage = next;
        _eventsMore = page.hasMore;
      });
    }
  }

  GlobalKey _doorKey(int slotId) => _doorKeys.putIfAbsent(slotId, GlobalKey.new);

  void _scrollTo(GlobalKey? key) {
    if (key == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = key.currentContext;
      if (target == null || !target.mounted) return;
      Scrollable.ensureVisible(target, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic, alignment: 0.05);
    });
  }

  void _focusPending() {
    _focused = true;
    final checked = _summary?.doors.where((d) => d.needsCheck || d.hasFault).firstOrNull;
    _scrollTo(_reports.isNotEmpty
        ? _reportsKey
        : _reviews.isNotEmpty
            ? _reviewsKey
            : checked == null
                ? null
                : _doorKey(checked.slotId));
  }

  Future<bool> _run(Future<String?> Function() task, String success) async {
    if (_busy) return false;
    setState(() => _busy = true);
    final error = await runBusy(context, task);
    if (!mounted) return false;
    setState(() => _busy = false);
    if (error != null) {
      if (error.isNotEmpty && error != S.verificationCancelled) showAppSnackBar(context, error, isError: true);
      await _load();
      return false;
    }
    HapticFeedback.mediumImpact();
    showAppSnackBar(context, success);
    await _load();
    return true;
  }

  Future<T?> _menu<T>({required String title, String? subtitle, required List<_MenuEntry<T>> entries}) {
    final c = AppColors.of(context);
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: c.sheetBg,
      isScrollControlled: true,
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75, maxWidth: 640),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(width: 36, height: 4, decoration: BoxDecoration(color: c.divider, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(title,
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary)),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(subtitle,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: c.textSecondary)),
              ),
            ],
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  for (final entry in entries)
                    ListTile(
                      enabled: entry.enabled,
                      leading: Icon(entry.icon, color: entry.enabled ? (entry.color ?? c.textPrimary) : c.textHint),
                      title: Text(entry.label,
                          style: TextStyle(color: entry.enabled ? (entry.color ?? c.textPrimary) : c.textHint)),
                      onTap: () => Navigator.pop(ctx, entry.value),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  static bool _doorTaken(AdminCabinetDoor door) => door.hasContents || door.status == 'occupied' || door.status == 'reserved';

  List<AdminCabinetDoor> get _freeDoors => [for (final door in _summary?.doors ?? const <AdminCabinetDoor>[]) if (!_doorTaken(door)) door];

  Future<AdminCabinetDoor?> _pickDoor(String subtitle, {Set<int> chosen = const {}}) async {
    final doors = _summary?.doors ?? const <AdminCabinetDoor>[];
    final slotId = await _menu<int>(
      title: S.selectDoorWhereBooksActuallyStored,
      subtitle: subtitle,
      entries: [
        for (final door in doors)
          _MenuEntry(
            door.slotId,
            '${S.doorP0(door.label)}・${chosen.contains(door.slotId) ? S.alreadySelected : AppLabels.slot(door.status)}',
            Icons.sensor_door_outlined,
            enabled: !_doorTaken(door) && !chosen.contains(door.slotId),
          ),
      ],
    );
    return doors.where((d) => d.slotId == slotId).firstOrNull;
  }

  Future<Map<int, int>?> _pickDoors(List<AdminCabinetDoorBook> books) async {
    if (_freeDoors.length < books.length) {
      showAppSnackBar(context, books.length > 1 ? S.notEnoughAvailableDoorsChooseDifferent : S.noEmptyDoorCurrentlyAvailableRecord, isError: true);
      return null;
    }
    final picked = <int, int>{};
    for (final book in books) {
      final door = await _pickDoor(book.title, chosen: picked.values.toSet());
      if (door == null || !mounted) return null;
      picked[book.bookId] = door.slotId;
    }
    return picked;
  }

  Future<void> _pair() async {
    if (_busy) return;
    final token = await VerificationService.requireAdminPassword(context);
    if (token == null || !mounted) return;
    final raw = await showTextInputDialog(
      context,
      title: S.pairDevice,
      message: S.enterPairingCodeShownLockerScreen,
      hint: '12345678',
      maxLength: 9,
      showCounter: false,
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 -]'))],
      confirmLabel: S.pairDevice,
      keyboardType: TextInputType.number,
      validator: (value) => AdminCabinetPairing.codeOf(value) == null ? S.enter8DigitPairingCode : null,
    );
    final code = raw == null ? null : AdminCabinetPairing.codeOf(raw);
    if (code == null || !mounted) return;
    final previous = _summary?.device?.deviceNo;
    setState(() => _busy = true);
    final result = await runBusy(context, () => _api.pairCabinetDevice(_cabinetId, code, verifyToken: token));
    if (!mounted) return;
    setState(() => _busy = false);
    final paired = result?.paired;
    if (paired == null) {
      final error = result?.error;
      if (error != null && !error.isVerificationCancelled) showAppSnackBar(context, CabinetMessages.pairError(error), isError: true);
      return;
    }
    HapticFeedback.mediumImpact();
    final summary = paired.summary;
    if (summary != null) setState(() => _summary = summary);
    final retry = await showAdminCabinetPairingDialog(context, cabinetId: _cabinetId, paired: paired, previousDeviceNo: previous);
    if (!mounted) return;
    await _load();
    if (retry && mounted) await _pair();
  }

  static const _brightnessLevels = [100, 80, 60, 40, 20];

  Future<void> _setBrightness(int current) async {
    final percent = await _menu<int>(
      title: S.screenBrightness,
      subtitle: S.screenBrightnessApplyNextSync,
      entries: [
        for (final level in _brightnessLevels)
          _MenuEntry(
            level,
            '$level%',
            level >= 80 ? Icons.brightness_high_rounded : (level >= 40 ? Icons.brightness_medium_rounded : Icons.brightness_low_rounded),
            enabled: level != current,
          ),
      ],
    );
    if (percent == null || !mounted) return;
    await _run(() => _api.setCabinetScreenBrightness(_cabinetId, percent), S.screenBrightnessUpdated);
  }

  Future<void> _revoke() async {
    final confirmed = await showConfirmDialog(
      context,
      title: S.revokeDevice,
      message: S.onceRevokedDeviceCanNoLonger(_cabinetName),
      confirmLabel: S.revokeDevice,
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    await _run(() => _api.revokeCabinetDevice(_cabinetId), S.deviceRevoked);
  }

  Future<void> _openDoor(AdminCabinetDoor door, {String? reason}) => _remoteOpen(
    door.slotId,
    door.label,
    allowForce: !door.hasContents && !door.needsCheck && door.status != 'reserved',
    reason: reason,
  );

  Future<void> _remoteOpen(int slotId, String label, {bool allowForce = false, String? reason, AdminCabinetRemoteOpen? resume}) async {
    final result = await showAdminCabinetOpenSheet(
      context,
      cabinetId: _cabinetId,
      slotId: slotId,
      label: label,
      cabinetName: _cabinetName,
      allowForce: allowForce,
      initialReason: reason,
      resume: resume,
    );
    if (!mounted || !result.created) return;
    await _load();
    final finished = result.finished;
    if (!mounted || finished == null) return;
    final current = _summary?.doors.where((d) => d.slotId == slotId).firstOrNull;
    if (current?.needsCheck ?? false) {
      _scrollTo(_doorKey(slotId));
      showAppSnackBar(context, S.checkContentsDoorP0(label));
      return;
    }
    final text = CabinetMessages.result(finished.result);
    if (text.isNotEmpty) showAppSnackBar(context, text, isError: finished.status != CabinetSession.completed);
  }

  Future<void> _doorMenu(AdminCabinetDoor door) async {
    final summary = _summary;
    if (summary == null || _busy) return;
    final c = AppColors.of(context);
    final placeable = _placeOptions(summary, door);
    final action = await _menu<_DoorAction>(
      title: S.doorP0(door.label),
      subtitle: AppLabels.slot(door.status),
      entries: [
        _MenuEntry(_DoorAction.open, S.openDoorRemotely, Icons.lock_open_rounded, enabled: summary.device?.online ?? false),
        if (door.needsCheck) _MenuEntry(_DoorAction.confirm, S.confirmContents, Icons.fact_check_outlined),
        _MenuEntry(_DoorAction.place, S.recordContents, Icons.playlist_add_rounded, enabled: placeable.isNotEmpty && !_doorTaken(door)),
        if (door.hasContents) _MenuEntry(_DoorAction.clear, S.clearContentsRecord, Icons.delete_sweep_outlined, color: c.danger),
        if (door.isUnderMaintenance)
          _MenuEntry(_DoorAction.endMaintenance, S.endLockerMaintenance, Icons.build_circle_outlined)
        else
          _MenuEntry(_DoorAction.maintenance, S.markLockerMaintenance, Icons.build_outlined, color: c.danger),
        if (door.hasFault) _MenuEntry(_DoorAction.clearFault, S.clearFault, Icons.healing_outlined),
      ],
    );
    if (action == null || !mounted) return;
    switch (action) {
      case _DoorAction.open:
        await _openDoor(door);
      case _DoorAction.confirm:
        await _confirmDoor(door);
      case _DoorAction.place:
        await _placeInto(door);
      case _DoorAction.clear:
        await _clearDoor(door);
      case _DoorAction.maintenance:
        await _setMaintenance(door, on: true);
      case _DoorAction.endMaintenance:
        await _setMaintenance(door, on: false);
      case _DoorAction.clearFault:
        await _run(() => _api.clearCabinetFault(_cabinetId, slotId: door.slotId), S.faultCleared);
    }
  }

  Future<void> _confirmDoor(AdminCabinetDoor door) async {
    final note = await showTextInputDialog(
      context,
      title: S.confirmContents,
      message: S.checkContentsDoorP0(door.label),
      hint: S.resolutionNote,
      maxLength: 255,
      confirmLabel: S.confirmContents,
    );
    if (note == null || !mounted) return;
    await _run(() => _api.confirmCabinetDoor(_cabinetId, door.slotId, note: note), S.contentsConfirmed);
  }

  Future<void> _placeInto(AdminCabinetDoor door) async {
    final summary = _summary;
    if (summary == null) return;
    final options = _placeOptions(summary, door);
    if (options.isEmpty) return;
    final c = AppColors.of(context);
    final picked = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: c.sheetBg,
      constraints: const BoxConstraints(maxWidth: 640),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _PlaceSheet(label: door.label, options: options),
    );
    if (picked == null || !mounted) return;
    await _run(() => _api.placeCabinetDoorItems(_cabinetId, door.slotId, bookIds: [picked]), S.contentsRecorded);
  }

  static List<_PlaceOption> _placeOptions(AdminCabinetDeviceSummary summary, AdminCabinetDoor door) {
    final seen = <int>{};
    return [
      for (final item in summary.unplaced)
        if (seen.add(item.bookId))
          (bookId: item.bookId, title: item.title, note: item.orderNo != null ? S.order(item.orderNo!) : S.preSaleDropOff),
      for (final candidate in door.check?.candidates ?? const <AdminCabinetCheckCandidate>[])
        if (seen.add(candidate.bookId)) (bookId: candidate.bookId, title: candidate.title, note: CabinetLabels.kind(candidate.kind)),
    ];
  }

  Future<void> _placeUnplaced(AdminCabinetUnplacedItem item) async {
    if (_busy) return;
    final picked = await _pickDoors([(bookId: item.bookId, title: item.title)]);
    final slotId = picked?[item.bookId];
    if (slotId == null || !mounted) return;
    await _run(() => _api.placeCabinetDoorItems(_cabinetId, slotId, bookIds: [item.bookId]), S.contentsRecorded);
  }

  Future<void> _clearDoor(AdminCabinetDoor door) async {
    final c = AppColors.of(context);
    final removed = await _menu<bool>(
      title: S.clearContentsRecord,
      subtitle: S.doorP0(door.label),
      entries: [
        _MenuEntry(true, S.booksRemoved, Icons.outbox_outlined, color: c.danger),
        _MenuEntry(false, S.correctRecordOnly, Icons.edit_note_rounded),
      ],
    );
    if (removed == null || !mounted) return;
    final reason = await showTextInputDialog(
      context,
      title: removed ? S.booksRemoved : S.correctRecordOnly,
      message: removed ? S.confirmStaffRemovedBooksFromDoor(door.label) : S.confirmTheseBooksNotActuallyDoor(door.label),
      hint: S.describeReasonClearing,
      maxLength: 255,
      confirmLabel: S.clearContentsRecord,
      isDestructive: true,
      validator: (value) => value.isEmpty ? S.describeReasonClearing : null,
    );
    if (reason == null || !mounted) return;
    await _run(() => _api.clearCabinetDoor(_cabinetId, door.slotId, removed: removed, reason: reason), S.contentsRecordCleared);
  }

  Future<void> _setMaintenance(AdminCabinetDoor door, {required bool on}) async {
    if (on) {
      final confirmed = await showConfirmDialog(
        context,
        title: S.markLockerMaintenance,
        message: S.doorP0(door.label),
        confirmLabel: S.markLockerMaintenance,
        isDestructive: true,
      );
      if (!confirmed || !mounted) return;
    }
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await runBusy(context, () => _api.updateSlotStatus(_cabinetId, door.slotId, on ? 'maintenance' : 'empty'));
    if (!mounted) return;
    setState(() => _busy = false);
    showAppSnackBar(context, ok == true ? S.slotStatusUpdated : AppLabels.updateFailed, isError: ok != true);
    await _load();
  }

  Future<void> _confirmReport(AdminCabinetManualReport report) async {
    if (_busy) return;
    int? slotId;
    Map<int, int>? doors;
    if (report.requiresDoor && report.doorBooks.isNotEmpty) {
      doors = await _pickDoors(report.doorBooks);
      if (doors == null || !mounted) return;
    } else if (report.requiresDoor) {
      final door = await _pickDoor(_reportSubject(report));
      if (door == null || !mounted) return;
      slotId = door.slotId;
    }
    final note = await showTextInputDialog(
      context,
      title: S.confirmReport,
      message: S.ordersDropOffsUpdatedAsReported,
      hint: S.resolutionNote,
      maxLines: 3,
      maxLength: 500,
      confirmLabel: S.confirmReport,
    );
    if (note == null || !mounted) return;
    await _run(() => _api.confirmCabinetManualReport(report.reportNo, note: note, slotId: slotId, doors: doors), S.manualReportConfirmed);
  }

  Future<void> _rejectReport(AdminCabinetManualReport report) async {
    if (_busy) return;
    final note = await showTextInputDialog(
      context,
      title: S.rejectReport,
      message: S.statusStaysUnchangedReporterNotified,
      hint: S.resolutionNote,
      maxLines: 3,
      maxLength: 500,
      confirmLabel: S.rejectReport,
      isDestructive: true,
      validator: (value) => value.isEmpty ? S.actionRequired : null,
    );
    if (note == null || !mounted) return;
    await _run(() => _api.rejectCabinetManualReport(report.reportNo, note: note), S.manualReportRejected);
  }

  Future<void> _openSession(String sessionNo) async {
    if (_busy) return;
    if (AdminCabinetOpenSheet.owns(sessionNo)) {
      setState(() => _busy = true);
      final detail = await _api.fetchCabinetSessionDetail(sessionNo);
      if (!mounted) return;
      setState(() => _busy = false);
      final owned = AdminCabinetOpenSheet.resumeOf(detail);
      if (owned != null) return _remoteOpen(owned.slotId, owned.label, resume: owned.open);
    }
    final resolved = await showAdminCabinetSessionSheet(context, sessionNo);
    if (mounted) await (resolved ? _reload() : _load());
  }

  static String _reportSubject(AdminCabinetManualReport report) {
    if (report.orderNo != null) return S.order(report.orderNo!);
    return report.bookTitle ?? (report.titles.isEmpty ? '' : report.titles.join('、'));
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final summary = _summary;

    return Scaffold(
      backgroundColor: c.scaffold,
      body: AdminLayout(
        builder: (context, frame) => Column(
          children: [
            AppHeader(title: S.lockerDevice, icon: Icons.router_outlined),
            Expanded(
              child: SwitchIn(
                child: _isLoading
                    ? const LoadingView.list()
                    : summary == null
                        ? ListView(
                            key: const ValueKey('failed'),
                            children: [
                              const SizedBox(height: 80),
                              EmptyView(icon: Icons.router_outlined, message: S.loadFailed, actionLabel: S.retry, onAction: _retry),
                            ],
                          )
                        : RefreshIndicator(
                            key: const ValueKey('content'),
                            color: c.accent,
                            onRefresh: _reload,
                            child: NotificationListener<ScrollNotification>(
                              onNotification: (notification) {
                                if (notification.metrics.axis == Axis.vertical && notification.metrics.extentAfter < 400) _loadMore();
                                return false;
                              },
                              child: SingleChildScrollView(
                                controller: _scroll,
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: frame.inset(
                                  const EdgeInsets.fromLTRB(16, 16, 16, 32),
                                  maxWidth: frame.isExpanded ? 1120 : Breakpoints.readingMaxWidth,
                                ),
                                child: _buildBody(summary, frame, c),
                              ),
                            ),
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(AdminCabinetDeviceSummary summary, AdminFrame frame, AppColors c) {
    final primary = <Widget>[
      _buildDevice(summary, c),
      if (summary.doors.isNotEmpty) _buildDoors(summary, c),
      if (summary.unplaced.isNotEmpty) _buildUnplaced(summary, c),
    ];
    final secondary = <Widget>[
      _buildReports(c),
      if (_reviews.isNotEmpty) _buildReviews(c),
      _buildHistory(c),
    ];
    if (frame.isExpanded) {
      return AdminColumns(spacing: 12, columns: [primary, secondary]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, section) in [...primary, ...secondary].indexed)
          Padding(padding: EdgeInsets.only(top: i == 0 ? 0 : 12), child: section),
      ],
    );
  }

  Widget _kv(String label, String value, AppColors c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 88, child: Text(label, maxLines: 2, style: TextStyle(fontSize: 12, color: c.textHint))),
          Expanded(child: Text(value, style: TextStyle(fontSize: 13, color: c.textPrimary))),
        ],
      ),
    );
  }

  Widget _notice(String text, Color tint, AppColors c, {IconData icon = Icons.warning_amber_rounded, Widget? trailing}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: tint.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(AppRadius.control)),
      child: Row(
        children: [
          Icon(icon, size: 16, color: tint),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontSize: 12.5, height: 1.4, fontWeight: FontWeight.w600, color: tint))),
          if (trailing != null) ...[const SizedBox(width: 8), trailing],
        ],
      ),
    );
  }

  Widget _kioskUrl(String url, AppColors c) {
    return Row(
      children: [
        SizedBox(width: 88, child: Text(S.simulatorUrl, maxLines: 2, style: TextStyle(fontSize: 12, color: c.textHint))),
        Expanded(child: SelectableText(url, maxLines: 2, style: TextStyle(fontSize: 13, color: c.textPrimary))),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: S.copyLink2,
          icon: Icon(Icons.copy_rounded, size: 18, color: c.accent),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: url));
            showAppSnackBar(context, S.copied2);
          },
        ),
      ],
    );
  }

  Widget _buildDevice(AdminCabinetDeviceSummary summary, AppColors c) {
    final device = summary.device;
    final pairing = summary.pairing;
    final state = CabinetLabels.deviceState(
      status: device?.status ?? (pairing != null ? 'pending' : null),
      online: device?.online ?? false,
    );
    final stateColor = device != null ? (device.online ? c.success : c.danger) : (pairing != null ? c.warning : c.neutral);
    final active = summary.activeSessionNo;
    final faultCode = device?.faultCode;
    final kioskUrl = device == null || device.isSimulator ? summary.kioskUrl : null;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _cabinetName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary),
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(label: state, color: stateColor),
            ],
          ),
          const SizedBox(height: 6),
          InfoLine(
            icon: Icons.verified_user_outlined,
            value: CabinetLabels.access(summary.access.mode, summary.access.reason),
            fontSize: 12,
          ),
          if (summary.openHours.isNotEmpty) ...[
            const SizedBox(height: 2),
            InfoLine(icon: Icons.schedule_rounded, value: summary.openHours, fontSize: 12),
          ],
          if (device != null) ...[
            Divider(color: c.divider, height: 20),
            _kv(S.deviceType, CabinetLabels.deviceKind(device.kind), c),
            _kv(S.deviceId, device.deviceNo, c),
            if (device.firmware != null) _kv(S.firmware, device.firmware!, c),
            _kv(S.lastSeen, device.lastSeenAt == null ? '—' : formatRelative(device.lastSeenAt), c),
            if (device.pairedAt != null) _kv(S.pairingTime, formatDateTime(device.pairedAt), c),
            _kv(S.doorSensors, device.hasDoorSensor ? S.installed : S.notInstalled, c),
            _kv(S.numberDoors, '${device.doorCount}', c),
          ],
          if (device == null) Divider(color: c.divider, height: 20),
          Row(
            children: [
              SizedBox(width: 88, child: Text(S.screenBrightness, maxLines: 2, style: TextStyle(fontSize: 12, color: c.textHint))),
              Expanded(child: Text('${summary.screenBrightness}%', style: TextStyle(fontSize: 13, color: c.textPrimary))),
              SmallActionButton(label: S.change, onTap: _busy ? null : () => _setBrightness(summary.screenBrightness)),
            ],
          ),
          if (pairing != null) ...[
            const SizedBox(height: 4),
            _kv(S.awaitingPairing, '${CabinetLabels.deviceKind(pairing.kind)}・${S.numberDoors} ${pairing.doorCount}', c),
          ],
          if (kioskUrl != null) ...[
            if (device == null && pairing == null) Divider(color: c.divider, height: 20),
            _kioskUrl(kioskUrl, c),
          ],
          if (faultCode != null) ...[
            const SizedBox(height: 8),
            _notice(
              S.faultP0(CabinetLabels.fault(faultCode)),
              c.danger,
              c,
              trailing: SmallActionButton(
                label: S.clearFault,
                onTap: _busy ? null : () => _run(() => _api.clearCabinetFault(_cabinetId), S.faultCleared),
              ),
            ),
          ],
          if (active != null) ...[
            const SizedBox(height: 8),
            PressableScale(
              onTap: () => _openSession(active),
              child: _notice(S.taskProgressP0(active), c.accent, c, icon: Icons.sync_rounded,
                  trailing: Icon(Icons.chevron_right_rounded, size: 18, color: c.accent)),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (device != null || pairing != null) ...[
                Expanded(child: SmallActionButton(label: S.revokeDevice, color: c.danger, onTap: _busy ? null : _revoke)),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: SmallActionButton(label: S.pairDevice, filled: true, onTap: _busy ? null : _pair),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDoors(AdminCabinetDeviceSummary summary, AppColors c) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(title: S.doors, trailing: Text('${summary.doors.length}', style: TextStyle(fontSize: 12, color: c.textHint))),
          for (final (i, door) in summary.doors.indexed) ...[
            if (i > 0) Divider(color: c.divider, height: 24),
            KeyedSubtree(key: _doorKey(door.slotId), child: _buildDoor(summary, door, c)),
          ],
        ],
      ),
    );
  }

  Widget _buildDoor(AdminCabinetDeviceSummary summary, AdminCabinetDoor door, AppColors c) {
    final check = door.check;
    final active = summary.activeSessionNo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(door.label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c.textPrimary)),
            const SizedBox(width: 8),
            Expanded(
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  StatusBadge(label: AppLabels.slot(door.status), color: c.slotStatusColor(door.status), fontSize: 10),
                  if (door.faultCode != null)
                    StatusBadge(label: S.faultP0(CabinetLabels.fault(door.faultCode!)), color: c.danger, fontSize: 10),
                ],
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: S.moreActions,
              icon: Icon(Icons.more_horiz_rounded, color: c.iconInactive),
              onPressed: _busy ? null : () => _doorMenu(door),
            ),
          ],
        ),
        if (check != null) ...[
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: c.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.control),
              border: Border.all(color: c.warning.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 16, color: c.warning),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(S.contentsNeedChecking,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: c.warning)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  [CabinetLabels.checkReason(check.reason), if (check.at != null) formatDateTime(check.at)].join('・'),
                  style: TextStyle(fontSize: 12, color: c.textSecondary),
                ),
                if (check.candidates.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(S.booksMayInside, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.textPrimary)),
                  for (final book in check.candidates)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text('・${book.title}', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                    ),
                ],
              ],
            ),
          ),
        ],
        if (door.status == 'reserved' && active != null) ...[
          const SizedBox(height: 6),
          PressableScale(
            onTap: () => _openSession(active),
            child: Text(S.taskProgressP0(active), style: TextStyle(fontSize: 12, color: c.accent)),
          ),
        ],
        const SizedBox(height: 6),
        if (door.items.isEmpty)
          Text(S.noContentsRecorded, style: TextStyle(fontSize: 12, color: c.textHint))
        else
          for (final item in door.items)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: c.textPrimary)),
                  const SizedBox(height: 2),
                  Text(
                    [
                      CabinetLabels.doorItem(item),
                      if (item.sellerNickname != null) S.seller3(item.sellerNickname!),
                      if (item.placedAt != null) formatDateTime(item.placedAt),
                    ].join('・'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: c.textHint),
                  ),
                ],
              ),
            ),
      ],
    );
  }

  Widget _buildUnplaced(AdminCabinetDeviceSummary summary, AppColors c) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(
            title: S.itemsWithoutDoorRecord,
            trailing: Text('${summary.unplaced.length}', style: TextStyle(fontSize: 12, color: c.textHint)),
          ),
          for (final (i, item) in summary.unplaced.indexed) ...[
            if (i > 0) Divider(color: c.divider, height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: c.textPrimary)),
                      const SizedBox(height: 2),
                      Text(
                        item.orderNo != null ? S.order(item.orderNo!) : S.preSaleDropOff,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: c.textHint),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SmallActionButton(
                  label: S.recordContents,
                  onTap: _busy || summary.doors.isEmpty ? null : () => _placeUnplaced(item),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReports(AppColors c) {
    return AppCard(
      key: _reportsKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(
            title: S.manualReportsConfirm,
            trailing: _reports.isEmpty ? null : Text('${_reports.length}', style: TextStyle(fontSize: 12, color: c.textHint)),
          ),
          if (_reports.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(S.noManualReportsConfirm, style: TextStyle(fontSize: 13, color: c.textHint)),
            ),
          for (final (i, report) in _reports.indexed) ...[
            if (i > 0) Divider(color: c.divider, height: 20),
            _buildReport(report, c),
          ],
        ],
      ),
    );
  }

  Widget _buildReport(AdminCabinetManualReport report, AppColors c) {
    final subject = _reportSubject(report);
    final titles = report.orderNo != null ? report.titles.where((t) => t.isNotEmpty).join('、') : '';
    final meta = [
      if (report.user != null) '${S.reporter}：${report.user!.nickname}',
      if (report.reason != null) CabinetLabels.accessReason(report.reason),
      if (report.createdAt != null) formatDateTime(report.createdAt),
    ].join('・');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            StatusBadge(label: CabinetLabels.manualReportKind(report.kind), color: c.warning, fontSize: 10),
            const SizedBox(width: 8),
            Expanded(
              child: Text(subject,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary)),
            ),
          ],
        ),
        if (titles.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(titles, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.textSecondary)),
        ],
        const SizedBox(height: 3),
        Text(meta, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: c.textHint)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Flexible(
              child: SmallActionButton(label: S.rejectReport, color: c.danger, onTap: _busy ? null : () => _rejectReport(report)),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: SmallActionButton(label: S.confirmReport, filled: true, onTap: _busy ? null : () => _confirmReport(report)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReviews(AppColors c) {
    return AppCard(
      key: _reviewsKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(title: S.tasksConfirm, trailing: Text('${_reviews.length}', style: TextStyle(fontSize: 12, color: c.textHint))),
          for (final (i, row) in _reviews.indexed) ...[
            if (i > 0) Divider(color: c.divider, height: 16),
            _sessionRow(row, c, showNumber: true),
          ],
        ],
      ),
    );
  }

  Widget _sessionRow(AdminCabinetSessionRow row, AppColors c, {bool showNumber = false}) {
    final kinds = row.isAdmin ? CabinetLabels.kind('admin') : row.itemKinds.map(CabinetLabels.kind).join('、');
    final meta = [
      if (showNumber) row.sessionNo,
      if (row.user != null) row.user!.nickname,
      if (row.doors.isNotEmpty) S.doorP0(row.doors.join('、')),
    ].join('・');

    return PressableScale(
      scale: 0.98,
      onTap: () => _openSession(row.sessionNo),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StatusBadge(label: CabinetLabels.status(row.status), color: adminCabinetSessionColor(c, row.status), fontSize: 10),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(kinds.isEmpty ? '—' : kinds,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary)),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                Expanded(
                  child: Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.textSecondary)),
                ),
                const SizedBox(width: 8),
                Text(formatDateTime(row.createdAt), style: TextStyle(fontSize: 11, color: c.textHint)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _historyChip(String label, _History value, AppColors c) {
    final selected = _history == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: PressableScale(
        scale: 0.94,
        onTap: () {
          if (_history == value) return;
          HapticFeedback.selectionClick();
          setState(() => _history = value);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: selected ? c.accent : c.categoryChip, borderRadius: BorderRadius.circular(16)),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.bold : FontWeight.w500, color: selected ? Colors.white : c.accent),
          ),
        ),
      ),
    );
  }

  Widget _buildHistory(AppColors c) {
    final sessions = _history == _History.sessions;
    final empty = sessions ? _sessions.isEmpty : _events.isEmpty;
    final more = sessions ? _sessionsMore : _eventsMore;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _historyChip(S.recentTasks, _History.sessions, c),
                _historyChip(S.eventLog, _History.events, c),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (empty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(sessions ? S.noTasksYet : S.noEventsYet, style: TextStyle(fontSize: 13, color: c.textHint)),
              ),
            )
          else if (sessions)
            for (final (i, row) in _sessions.indexed) ...[
              if (i > 0) Divider(color: c.divider, height: 12),
              _sessionRow(row, c),
            ]
          else
            for (final (i, event) in _events.indexed) ...[
              if (i > 0) Divider(color: c.divider, height: 12),
              _eventRow(event, c),
            ],
          if (more)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: c.accent)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _eventRow(AdminCabinetEventRow event, AppColors c) {
    final meta = [
      ?event.label,
      ?_eventSummary(event),
      if (event.orderNo != null) S.order(event.orderNo!),
      ?event.sessionNo,
      if (event.actor != null) event.actor!.nickname,
    ].where((s) => s.isNotEmpty).join('・');
    final tappable = event.sessionNo != null;

    return PressableScale(
      scale: 0.98,
      onTap: tappable ? () => _openSession(event.sessionNo!) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(CabinetLabels.event(event.type),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary)),
                ),
                const SizedBox(width: 8),
                Text(formatDateTime(event.occurredAt), style: TextStyle(fontSize: 11, color: c.textHint)),
              ],
            ),
            if (meta.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(meta, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.textSecondary)),
            ],
          ],
        ),
      ),
    );
  }

  static String _duration(int ms) {
    final total = ms ~/ 1000;
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    String two(int v) => v.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  static String? _eventSummary(AdminCabinetEventRow event) {
    final detail = event.detail ?? const <String, dynamic>{};
    String? text(String key) {
      final value = detail[key];
      return value is String && value.trim().isNotEmpty ? value.trim() : null;
    }

    final parts = <String?>[];
    switch (event.type) {
      case 'fault' || 'fault_cleared':
        final code = text('code');
        if (code != null) parts.add(CabinetLabels.fault(code));
      case 'connection_restored':
        final ms = detail['offline_ms'];
        if (ms is num) {
          final duration = _duration(ms.toInt());
          parts.add(S.offlineP0(duration));
        }
      case 'match_entered':
        final matched = detail['matched'];
        if (matched is bool) parts.add(CabinetLabels.matchResult(matched));
      case 'paired':
        final kind = text('kind');
        if (kind != null) parts.add(CabinetLabels.deviceKind(kind));
      case 'door_check_required':
        final reason = text('reason');
        if (reason != null) parts.add(CabinetLabels.checkReason(reason));
      case 'item_blocked':
        final code = text('code');
        if (code != null) parts.add(CabinetMessages.blocked(CabinetNotice(code: code)));
      case 'manual_report':
        final kind = text('kind');
        if (kind != null) parts.add(CabinetLabels.manualReportKind(kind));
        final reason = text('reason');
        if (reason != null) parts.add(CabinetLabels.accessReason(reason));
      case 'manual_report_reviewed':
        final status = text('status');
        if (status != null) parts.add(CabinetLabels.manualReportStatus(status));
        parts.add(text('note'));
      case 'review_resolved':
        final action = text('action');
        if (action != null) parts.add(action == 'commit' ? S.markAsCompleted : S.markAsNotCompleted);
        parts.add(text('note'));
      case 'door_cleared':
        final mode = text('mode');
        if (mode != null) parts.add(mode == 'removed' ? S.booksRemoved : S.correctRecordOnly);
        parts.add(text('reason'));
      case 'admin_open':
        if (detail['force'] == true) parts.add(S.openWithoutNumberConfirmation);
        parts.add(text('reason'));
      case 'revoked':
        final reason = text('reason');
        if (reason != null) parts.add(CabinetLabels.revokeReason(reason));
        parts.add(text('note'));
      case 'door_check_cleared':
        parts.add(text('note'));
    }
    final summary = parts.whereType<String>().where((s) => s.isNotEmpty).join('・');
    return summary.isEmpty ? null : summary;
  }
}

typedef _PlaceOption = ({int bookId, String title, String note});

class _PlaceSheet extends StatefulWidget {
  final String label;
  final List<_PlaceOption> options;

  const _PlaceSheet({required this.label, required this.options});

  @override
  State<_PlaceSheet> createState() => _PlaceSheetState();
}

class _PlaceSheetState extends State<_PlaceSheet> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final height = MediaQuery.sizeOf(context).height;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: height * 0.8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 14),
              decoration: BoxDecoration(color: c.iconInactive.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${S.recordContents}・${widget.label}',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.textPrimary)),
                const SizedBox(height: 4),
                Text(S.selectItemsActuallyStoredDoor, style: TextStyle(fontSize: 12, color: c.textHint)),
                Text(S.eachDoorCanHoldOnlyOne, style: TextStyle(fontSize: 12, color: c.textHint)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                for (final option in widget.options)
                  ListTile(
                    selected: _selected == option.bookId,
                    selectedColor: c.accent,
                    leading: Icon(
                      _selected == option.bookId ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                      color: _selected == option.bookId ? c.accent : c.iconInactive,
                    ),
                    onTap: () => setState(() => _selected = option.bookId),
                    title: Text(option.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: c.textPrimary)),
                    subtitle: option.note.isEmpty ? null : Text(option.note, style: TextStyle(fontSize: 12, color: c.textHint)),
                  ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + MediaQuery.of(context).padding.bottom),
            child: PrimaryButton(
              label: S.recordContents,
              onPressed: _selected == null ? null : () => Navigator.pop(context, _selected),
            ),
          ),
        ],
      ),
    );
  }
}
