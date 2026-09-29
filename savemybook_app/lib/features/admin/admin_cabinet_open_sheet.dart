import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../i18n/strings.dart';
import '../../models/admin_models.dart';
import '../../models/cabinet.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_radius.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_forms.dart';
import '../../widgets/state_views.dart';
import '../cabinet/cabinet_messages.dart';

typedef AdminCabinetOpenResult = ({bool created, AdminCabinetSessionDetail? finished});

typedef AdminCabinetOwnedOpen = ({int slotId, String label, AdminCabinetRemoteOpen open});

Future<AdminCabinetOpenResult> showAdminCabinetOpenSheet(
  BuildContext context, {
  required int cabinetId,
  required int slotId,
  required String label,
  String? cabinetName,
  bool allowForce = false,
  String? initialReason,
  AdminCabinetRemoteOpen? resume,
}) async {
  final c = AppColors.of(context);
  var created = false;
  final result = await showModalBottomSheet<AdminCabinetOpenResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: c.sheetBg,
    constraints: const BoxConstraints(maxWidth: 640),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => AdminCabinetOpenSheet(
      cabinetId: cabinetId,
      slotId: slotId,
      label: label,
      cabinetName: cabinetName,
      allowForce: allowForce,
      initialReason: initialReason,
      resume: resume,
      onCreated: () => created = true,
    ),
  );
  return (created: created || (result?.created ?? false), finished: result?.finished);
}

class AdminCabinetOpenSheet extends StatefulWidget {
  static const pollInterval = Duration(seconds: 1);

  // 作業詳情不含發起人資訊，而輸入數字與結束作業只限發起人，須記下本機發起的作業才能重新開啟面板。
  static final Map<String, ({int? ownerId, int slotId, String label})> _owned = {};

  static bool owns(String sessionNo) {
    final owned = _owned[sessionNo];
    return owned != null && owned.ownerId == ApiService.currentUser?.userId;
  }

  static AdminCabinetOwnedOpen? resumeOf(AdminCabinetSessionDetail? detail) {
    if (detail == null || !owns(detail.sessionNo)) return null;
    if (detail.isSettled) _owned.remove(detail.sessionNo);
    if (!const {CabinetSession.matching, CabinetSession.opening, CabinetSession.open}.contains(detail.status)) return null;
    final owned = _owned[detail.sessionNo]!;
    return (
      slotId: owned.slotId,
      label: owned.label,
      open: AdminCabinetRemoteOpen(sessionNo: detail.sessionNo, status: detail.status, remainingMs: detail.remainingMs),
    );
  }

  final int cabinetId;
  final int slotId;
  final String label;
  final String? cabinetName;
  final bool allowForce;
  final String? initialReason;
  final AdminCabinetRemoteOpen? resume;
  final VoidCallback? onCreated;

  const AdminCabinetOpenSheet({
    super.key,
    required this.cabinetId,
    required this.slotId,
    required this.label,
    this.cabinetName,
    this.allowForce = false,
    this.initialReason,
    this.resume,
    this.onCreated,
  });

  @override
  State<AdminCabinetOpenSheet> createState() => _AdminCabinetOpenSheetState();
}

class _AdminCabinetOpenSheetState extends State<AdminCabinetOpenSheet> {
  final ApiService _api = ApiService();
  late final TextEditingController _reason = TextEditingController(text: widget.initialReason ?? '');
  final TextEditingController _code = TextEditingController();
  final Stopwatch _clock = Stopwatch();
  final Stopwatch _cooldownClock = Stopwatch();

  bool _force = false;
  bool _submitting = false;
  bool _matching = false;
  bool _ending = false;
  String? _codeError;
  String? _sessionNo;
  String _status = CabinetSession.matching;
  String? _notice;
  int _version = -1;
  int? _remainingMs;
  int _cooldownSeconds = 0;
  Timer? _ticker;
  Timer? _cooldownTicker;
  bool _polling = false;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    final resume = widget.resume;
    if (resume != null) _begin(resume);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _cooldownTicker?.cancel();
    _reason.dispose();
    _code.dispose();
    super.dispose();
  }

  // 剩餘時間以收到回應後經過的時間推算，不依賴手機時鐘。
  void _setRemaining(int? ms) {
    _remainingMs = ms;
    _clock
      ..reset()
      ..start();
  }

  int? get _remainingSeconds {
    final ms = _remainingMs;
    if (ms == null) return null;
    final left = ms - _clock.elapsedMilliseconds;
    return left <= 0 ? 0 : (left / 1000).ceil();
  }

  int get _cooldownLeft {
    final left = _cooldownSeconds - _cooldownClock.elapsed.inSeconds;
    return left > 0 ? left : 0;
  }

  bool get _coolingDown => !_force && _cooldownLeft > 0;

  void _startCooldown(int seconds) {
    _cooldownSeconds = seconds;
    _cooldownClock
      ..reset()
      ..start();
    _cooldownTicker?.cancel();
    _cooldownTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_cooldownLeft == 0) timer.cancel();
      setState(() {});
    });
  }

  void _begin(AdminCabinetRemoteOpen opened) {
    _sessionNo = opened.sessionNo;
    _status = opened.status;
    _setRemaining(opened.remainingMs);
    _ticker = Timer.periodic(AdminCabinetOpenSheet.pollInterval, (_) => _poll());
  }

  Future<void> _submit() async {
    final reason = _reason.text.trim();
    if (reason.isEmpty || _submitting || _coolingDown) return;
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    final result = await _api.openCabinetDoor(widget.cabinetId, widget.slotId, reason, force: _force);
    if (!mounted) return;
    setState(() => _submitting = false);
    final opened = result.opened;
    final error = result.error;
    if (opened == null) {
      if (error?.code == 'CABINET_COOLDOWN') {
        setState(() => _startCooldown(error?.retryAfterS ?? 60));
        return;
      }
      if (error == null || !error.isVerificationCancelled) {
        showAppSnackBar(context, error == null ? S.somethingWentWrongPleaseTryAgain : CabinetMessages.admin(error), isError: true);
      }
      return;
    }
    AdminCabinetOpenSheet._owned[opened.sessionNo] = (ownerId: ApiService.currentUser?.userId, slotId: widget.slotId, label: widget.label);
    widget.onCreated?.call();
    HapticFeedback.mediumImpact();
    if (!opened.needsMatch) showAppSnackBar(context, S.openCommandSent);
    setState(() => _begin(opened));
  }

  Future<void> _match() async {
    final sessionNo = _sessionNo;
    if (sessionNo == null || _matching || _status != CabinetSession.matching) return;
    final code = _code.text;
    if (!CabinetSession.isMatchCode(code)) {
      setState(() => _codeError = S.enterTwoDigits);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _matching = true);
    final result = await _api.matchRemoteCabinetSession(sessionNo, code);
    if (!mounted || _closed) return;
    setState(() => _matching = false);
    final detail = result.detail;
    final error = result.error;
    if (detail != null) {
      _code.clear();
      _apply(detail);
      return;
    }
    if (error == null) return;
    if (error.code == CabinetApiError.matchCodeInvalid) {
      setState(() => _codeError = CabinetMessages.admin(error));
      return;
    }
    showAppSnackBar(context, CabinetMessages.admin(error), isError: true);
    _poll();
  }

  Future<void> _end() async {
    final sessionNo = _sessionNo;
    if (sessionNo == null || _ending) return;
    setState(() => _ending = true);
    final result = await _api.closeRemoteCabinetSession(sessionNo);
    if (!mounted || _closed) return;
    setState(() => _ending = false);
    final detail = result.detail;
    final error = result.error;
    if (detail == null) {
      if (error != null) showAppSnackBar(context, CabinetMessages.admin(error, closing: true), isError: true);
      _poll();
      return;
    }
    if (!detail.isSettled) showAppSnackBar(context, S.lockerBeenAskedEndTask);
    _apply(detail);
  }

  Future<void> _poll() async {
    if (!mounted || _closed) return;
    setState(() {});
    final sessionNo = _sessionNo;
    if (_polling || sessionNo == null) return;
    _polling = true;
    final detail = await _api.fetchCabinetSessionDetail(sessionNo);
    _polling = false;
    if (!mounted || _closed || detail == null) return;
    _apply(detail);
  }

  void _apply(AdminCabinetSessionDetail detail) {
    if (detail.version < _version) return;
    if (detail.isSettled) {
      _close(detail);
      return;
    }
    setState(() {
      _version = detail.version;
      _status = detail.status;
      _notice = detail.notice;
      _setRemaining(detail.remainingMs);
    });
  }

  void _close([AdminCabinetSessionDetail? finished]) {
    if (_closed) return;
    _closed = true;
    _ticker?.cancel();
    if (finished != null) AdminCabinetOpenSheet._owned.remove(finished.sessionNo);
    Navigator.of(context).pop((created: _sessionNo != null, finished: finished));
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final door = S.doorP0(widget.label);
    final name = widget.cabinetName;

    return PopScope(
      canPop: _sessionNo == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 10, 20, 24 + MediaQuery.of(context).padding.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: c.iconInactive.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(S.openDoorRemotely, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.textPrimary)),
              const SizedBox(height: 4),
              Text(
                name == null || name.isEmpty ? door : '$name・$door',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: c.textHint),
              ),
              const SizedBox(height: 16),
              if (_sessionNo == null) ..._buildForm(c) else ..._buildProgress(c),
            ],
          ),
        ),
      ),
    );
  }

  Widget _warning(AppColors c, String title, {String? detail}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: c.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(AppRadius.control)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 1), child: Icon(Icons.warning_amber_rounded, size: 16, color: c.warning)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 13, height: 1.4, fontWeight: FontWeight.w600, color: c.warning)),
                if (detail != null) ...[
                  const SizedBox(height: 2),
                  Text(detail, style: TextStyle(fontSize: 12, height: 1.4, color: c.textSecondary)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildForm(AppColors c) {
    final ready = _reason.text.trim().isNotEmpty && !_coolingDown;
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(S.openingReason, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.textSecondary)),
      ),
      AppTextField(
        controller: _reason,
        hint: S.describeReasonRecordedOperationLog,
        maxLength: 255,
        maxLines: 3,
        minLines: 1,
        textInputAction: TextInputAction.done,
        onChanged: (_) => setState(() {}),
      ),
      if (widget.allowForce) ...[
        const SizedBox(height: 4),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _force,
          activeTrackColor: c.danger,
          onChanged: _submitting ? null : (value) => setState(() => _force = value),
          title: Text(S.openWithoutNumberConfirmation,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary)),
          subtitle: Text(S.onlyDoorsWithNoRecordedContents,
              style: TextStyle(fontSize: 12, height: 1.4, color: c.textSecondary)),
        ),
      ],
      if (_coolingDown) ...[
        const SizedBox(height: 12),
        _warning(c, CabinetMessages.adminCooldown((_cooldownLeft / 60).ceil())),
      ],
      const SizedBox(height: 16),
      PrimaryButton(
        label: S.openDoor,
        icon: Icons.lock_open_rounded,
        color: _force ? c.danger : null,
        isLoading: _submitting,
        onPressed: ready ? _submit : null,
      ),
    ];
  }

  Widget _codeField(AppColors c) {
    return SizedBox(
      width: 150,
      child: TextField(
        controller: _code,
        autofocus: true,
        enabled: !_matching,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 2,
        enableSuggestions: false,
        autocorrect: false,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textInputAction: TextInputAction.done,
        onChanged: (_) => setState(() => _codeError = null),
        onSubmitted: (_) => _match(),
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          letterSpacing: 6,
          fontFeatures: const [FontFeature.tabularFigures()],
          color: c.textPrimary,
        ),
        decoration: InputDecoration(
          counterText: '',
          errorText: _codeError,
          errorMaxLines: 2,
          filled: true,
          fillColor: c.card,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.control), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.control),
            borderSide: BorderSide(color: c.accent, width: 1.4),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildProgress(AppColors c) {
    final seconds = _remainingSeconds;
    final matching = _status == CabinetSession.matching;
    final opened = _status == CabinetSession.open;

    return [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(color: c.inputFill, borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            if (matching) ...[
              Text(
                S.enterNumberShownLockerScreen,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary),
              ),
              const SizedBox(height: 14),
              _codeField(c),
            ] else ...[
              if (opened)
                Icon(Icons.lock_open_rounded, size: 40, color: c.success)
              else
                SizedBox(width: 36, height: 36, child: CircularProgressIndicator(strokeWidth: 3, color: c.accent)),
              const SizedBox(height: 12),
              Text(
                opened ? S.doorOpened : S.openingDoor,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary),
              ),
            ],
            if (seconds != null && (matching || opened)) ...[
              const SizedBox(height: 8),
              Text(S.p0SRemaining(seconds), style: TextStyle(fontSize: 13, color: c.textSecondary)),
            ],
          ],
        ),
      ),
      if (opened && _notice == CabinetSession.noticeCloseDoorFirst) ...[
        const SizedBox(height: 12),
        _warning(c, S.closeDoorFirst, detail: S.taskCompleteAutomaticallyOnceDoorClosed),
      ],
      const SizedBox(height: 16),
      if (matching)
        PrimaryButton(label: S.confirm, isLoading: _matching, onPressed: _code.text.length == 2 ? _match : null)
      else if (opened)
        PrimaryButton(label: S.endTask, isLoading: _ending, onPressed: _end),
      if (matching || opened) const SizedBox(height: 10),
      SizedBox(width: double.infinity, child: SecondaryButton(label: S.actionClose, onPressed: () => _close())),
    ];
  }
}
