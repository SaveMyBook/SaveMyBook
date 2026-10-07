import 'dart:async';

import 'package:flutter/material.dart';
import '../../i18n/strings.dart';
import '../../models/admin_models.dart';
import '../../services/api_service.dart';
import '../../utils/api_helpers.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_radius.dart';
import '../../utils/cabinet_labels.dart';
import '../../widgets/adaptive_sheet.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/app_tiles.dart';
import '../../widgets/state_views.dart';
import '../cabinet/cabinet_messages.dart';

Color adminCabinetSessionColor(AppColors c, String status) => switch (status) {
  'completed' => c.success,
  'partial' || 'needs_review' => c.warning,
  'failed' => c.danger,
  'cancelled' || 'expired' => c.neutral,
  _ => c.accent,
};

Future<bool> showAdminCabinetSessionSheet(BuildContext context, String sessionNo) async {
  final c = AppColors.of(context);
  var resolved = false;
  await showAppModalSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: c.sheetBg,
    constraints: const BoxConstraints(maxWidth: 640),
    dialogMaxWidth: 600,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => AdminCabinetSessionSheet(sessionNo: sessionNo, onResolved: () => resolved = true),
  );
  return resolved;
}

class AdminCabinetSessionSheet extends StatefulWidget {
  static const refreshInterval = Duration(seconds: 2);

  final String sessionNo;
  final VoidCallback? onResolved;

  const AdminCabinetSessionSheet({super.key, required this.sessionNo, this.onResolved});

  @override
  State<AdminCabinetSessionSheet> createState() => _AdminCabinetSessionSheetState();
}

class _AdminCabinetSessionSheetState extends State<AdminCabinetSessionSheet> {
  final ApiService _api = ApiService();

  AdminCabinetSessionDetail? _detail;
  bool _isLoading = true;
  bool _loading = false;
  bool _busy = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading) return;
    _loading = true;
    final detail = await _api.fetchCabinetSessionDetail(widget.sessionNo);
    _loading = false;
    if (!mounted) return;
    setState(() {
      final current = _detail;
      if (detail != null && (current == null || detail.version >= current.version)) _detail = detail;
      _isLoading = false;
    });
    final active = _detail?.isActive ?? false;
    if (active && _timer == null) {
      _timer = Timer.periodic(AdminCabinetSessionSheet.refreshInterval, (_) => _load());
    } else if (!active) {
      _timer?.cancel();
      _timer = null;
    }
  }

  Future<void> _resolve(AdminCabinetSessionDetail detail, {required bool commit}) async {
    if (_busy) return;
    final note = await showTextInputDialog(
      context,
      title: commit ? S.markAsCompleted : S.markAsNotCompleted,
      message: commit ? S.ordersDropOffsUpdatedAccordingTask : S.ordersDropOffsStayUnchanged,
      hint: S.resolutionNote,
      maxLines: 3,
      maxLength: 500,
      confirmLabel: commit ? S.markAsCompleted : S.markAsNotCompleted,
      isDestructive: !commit,
      validator: (value) => value.isEmpty ? S.actionRequired : null,
    );
    if (note == null || !mounted) return;
    setState(() => _busy = true);
    final error = await runBusy(context, () => _api.resolveCabinetSession(detail.sessionNo, commit: commit, note: note));
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      if (error.isNotEmpty && error != S.verificationCancelled) showAppSnackBar(context, error, isError: true);
      await _load();
      return;
    }
    widget.onResolved?.call();
    showAppSnackBar(context, S.reportResolved);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final detail = _detail;
    final height = MediaQuery.sizeOf(context).height;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: height * 0.88),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetHandle(margin: EdgeInsets.only(top: 10, bottom: 14)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(S.taskDetails, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.textPrimary)),
                      const SizedBox(height: 2),
                      Text(widget.sessionNo, style: TextStyle(fontSize: 12, color: c.textHint)),
                    ],
                  ),
                ),
                if (detail != null) ...[
                  const SizedBox(width: 8),
                  StatusBadge(label: CabinetLabels.status(detail.status), color: adminCabinetSessionColor(c, detail.status)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: _isLoading
                ? const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: LoadingView())
                : detail == null
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: EmptyView(icon: Icons.receipt_long_outlined, message: S.loadFailed, actionLabel: S.retry, onAction: _load),
                      )
                    : ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                        children: _sections(detail, c),
                      ),
          ),
          if (detail != null && (detail.canCommit || detail.canDiscard)) _buildActions(detail, c),
        ],
      ),
    );
  }

  List<Widget> _sections(AdminCabinetSessionDetail detail, AppColors c) {
    final kinds = detail.isAdmin
        ? [CabinetLabels.kind('admin')]
        : {for (final item in _shownItems(detail)) CabinetLabels.kind(item.kindCode)}.toList();
    final location = detail.isAdmin ? '' : CabinetLabels.location(detail.locationStatus, detail.distanceM);
    final result = CabinetMessages.result(detail.result);
    final steps = <(String, DateTime?)>[
      (S.taskCreated, detail.createdAt),
      (S.itemsConfirmed, detail.startedAt),
      if (!detail.adminForce) (S.matchCodeEntered, detail.matchedAt),
      (S.doorOpened, detail.openedAt),
      (S.doorClosed, detail.closedAt),
      (S.taskFinished, detail.finishedAt),
    ].where((step) => step.$2 != null).toList();

    return [
      if (result.isNotEmpty) _resultBox(result, adminCabinetSessionColor(c, detail.status), c),
      if (detail.isActive && detail.closeDoorFirst) _resultBox(S.closeDoorFirst, c.warning, c),
      _kv(S.user, detail.user?.nickname ?? '—', c),
      if (kinds.isNotEmpty) _kv(S.taskItems, kinds.join('、'), c),
      if (location.isNotEmpty) _kv(S.location, location, c),
      if (detail.closeReason != null) _kv(S.closedBy, CabinetLabels.closeReason(detail.closeReason), c),
      if (detail.adminReason != null) _kv(S.openingReason, detail.adminReason!, c),
      if (detail.adminForce)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: StatusBadge(label: S.openWithoutNumberConfirmation, color: c.danger, fontSize: 10),
          ),
        ),
      if (steps.isNotEmpty) ...[
        _heading(S.progress, c),
        for (final (label, at) in steps) _kv(label, formatDateTime(at), c),
      ],
      if (!detail.isAdmin && _shownItems(detail).isNotEmpty) ...[
        _heading(S.taskItems, c),
        for (final (i, item) in _shownItems(detail).indexed) ...[
          if (i > 0) Divider(color: c.divider, height: 16),
          _itemRow(item, c),
        ],
      ],
      if (detail.doorsTimeline.isNotEmpty) ...[
        _heading(S.doors, c),
        for (final door in detail.doorsTimeline) _doorRow(door, c),
      ],
      if (detail.review != null) ...[
        _heading(S.resolutionRecord, c),
        _reviewBox(detail.review!, c),
      ],
      if (detail.events.isNotEmpty) ...[
        _heading(S.eventLog, c),
        for (final event in detail.events)
          _kv(
            formatDateTime(event.occurredAt),
            [CabinetLabels.event(event.type), ?event.label, ?_matchResult(event)].join('・'),
            c,
            labelWidth: 112,
          ),
      ],
    ];
  }

  static String? _matchResult(AdminCabinetSessionEvent event) {
    final matched = event.detail?['matched'];
    return event.type == 'match_entered' && matched is bool ? CabinetLabels.matchResult(matched) : null;
  }

  List<AdminCabinetSessionItem> _shownItems(AdminCabinetSessionDetail detail) {
    final selected = [for (final item in detail.items) if (item.selected) item];
    return selected.isEmpty ? detail.items : selected;
  }

  Widget _heading(String title, AppColors c) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 4),
        child: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c.textPrimary)),
      );

  Widget _kv(String label, String value, AppColors c, {double labelWidth = 72}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(label, maxLines: 2, style: TextStyle(fontSize: 12, color: c.textHint)),
          ),
          Expanded(child: Text(value, style: TextStyle(fontSize: 13, color: c.textPrimary))),
        ],
      ),
    );
  }

  Widget _resultBox(String text, Color tint, AppColors c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: tint.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(AppRadius.control)),
      child: Text(text, style: TextStyle(fontSize: 13, height: 1.5, fontWeight: FontWeight.w600, color: c.textPrimary)),
    );
  }

  Widget _itemRow(AdminCabinetSessionItem item, AppColors c) {
    final titles = [for (final book in item.books) if (book.title.isNotEmpty) book.title];
    final people = switch ((item.buyerNickname, item.sellerNickname)) {
      (final String buyer, final String seller) => S.buyerP0SellerP1(buyer, seller),
      (null, final String seller) => S.seller3(seller),
      (final String buyer, null) => '${S.buyer}：$buyer',
      _ => null,
    };
    final (resultLabel, resultColor) = switch (item.result) {
      'done' => (S.completed, c.success),
      'failed' => (S.failed, c.danger),
      _ => (null, c.neutral),
    };
    final notice = item.error != null
        ? CabinetMessages.itemError(item.error!)
        : item.blocked != null
            ? CabinetMessages.blocked(item.blocked!)
            : item.note != null
                ? CabinetMessages.note(item.note!)
                : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            StatusBadge(label: CabinetLabels.kind(item.kindCode), color: c.accent, fontSize: 10),
            if (item.orderNo != null) ...[
              const SizedBox(width: 6),
              Expanded(
                child: Text(S.order(item.orderNo!),
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.textSecondary)),
              ),
            ] else
              const Spacer(),
            if (resultLabel != null) ...[
              const SizedBox(width: 6),
              StatusBadge(label: resultLabel, color: resultColor, fontSize: 10),
            ],
          ],
        ),
        if (titles.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(titles.join('、'), maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: c.textPrimary)),
        ],
        if (item.doors.isNotEmpty || people != null) ...[
          const SizedBox(height: 3),
          Text(
            [if (item.doors.isNotEmpty) S.doorP0(item.doors.join('、')), ?people].join('｜'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: c.textHint),
          ),
        ],
        if (notice != null && notice.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(notice, style: TextStyle(fontSize: 12, color: item.error != null ? c.danger : c.warning)),
        ],
      ],
    );
  }

  Widget _doorRow(AdminCabinetDoorTimeline door, AppColors c) {
    final state = switch (door.state) {
      'open' => S.doorOpened,
      'closed' => S.doorClosed,
      'failed' => S.doorDidNotOpen,
      _ => door.commandServedAt != null && door.openedAt == null ? S.doorOpeningNotReported : '',
    };
    final period = [
      if (door.openedAt != null) formatDateTime(door.openedAt),
      if (door.closedAt != null) formatDateTime(door.closedAt),
    ].join(' – ');
    final times = [
      if (period.isNotEmpty) period,
      if (door.closeReason != null) CabinetLabels.closeReason(door.closeReason),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(door.label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (state.isNotEmpty) Text(state, style: TextStyle(fontSize: 13, color: c.textPrimary)),
                if (times.isNotEmpty) Text(times.join('・'), style: TextStyle(fontSize: 11, color: c.textHint)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewBox(AdminCabinetReview review, AppColors c) {
    final meta = [?review.reviewerNickname, formatDateTime(review.reviewedAt)].where((s) => s.isNotEmpty).join('・');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (review.note != null) Text(review.note!, style: TextStyle(fontSize: 12, height: 1.5, color: c.textSecondary)),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(meta, style: TextStyle(fontSize: 11, color: c.textHint)),
          ],
        ],
      ),
    );
  }

  Widget _buildActions(AdminCabinetSessionDetail detail, AppColors c) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: c.sheetBg,
        border: Border(top: BorderSide(color: c.divider)),
      ),
      child: Row(
        children: [
          if (detail.canDiscard)
            Expanded(
              child: SecondaryButton(
                label: S.markAsNotCompleted,
                color: c.danger,
                height: 44,
                onPressed: _busy ? null : () => _resolve(detail, commit: false),
              ),
            ),
          if (detail.canDiscard && detail.canCommit) const SizedBox(width: 10),
          if (detail.canCommit)
            Expanded(
              child: PrimaryButton(
                label: S.markAsCompleted,
                height: 44,
                onPressed: _busy ? null : () => _resolve(detail, commit: true),
              ),
            ),
        ],
      ),
    );
  }
}
