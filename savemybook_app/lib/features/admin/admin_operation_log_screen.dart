import 'dart:async';

import 'package:flutter/material.dart';
import '../../models/admin_models.dart';
import '../../services/api_service.dart';
import '../../utils/api_helpers.dart';
import '../../utils/app_colors.dart';
import '../../utils/motion.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/app_forms.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_tiles.dart';
import '../../widgets/state_views.dart';
import '../../i18n/strings.dart';
import 'admin_layout.dart';

class AdminOperationLogScreen extends StatefulWidget {
  const AdminOperationLogScreen({super.key});

  @override
  State<AdminOperationLogScreen> createState() => _AdminOperationLogScreenState();
}

class _AdminOperationLogScreenState extends State<AdminOperationLogScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _search = TextEditingController();
  List<AdminOperationLog> _logs = [];
  bool _isLoading = true;
  String? _targetType;
  final Set<int> _expanded = {};
  int? _undoing;
  int _loadSeq = 0;
  Timer? _debounce;

  static List<({String? value, String label})> get _filters => [
        (value: null, label: S.actionAll),
        (value: 'user', label: S.member),
        (value: 'book', label: S.books),
        (value: 'category', label: S.category),
        (value: 'order', label: S.orders2),
        (value: 'dispute', label: S.dispute2),
        (value: 'report', label: S.report),
        (value: 'wallet', label: S.wallets2),
        (value: 'announcement', label: S.announcements3),
        (value: 'legal', label: S.legal),
        (value: 'faq', label: S.faq),
        (value: 'level', label: S.membershipTier),
        (value: 'cabinet', label: S.faqCatCabinet),
        (value: 'ticket', label: S.enquiry),
        (value: 'backup', label: S.backups),
      ];

  static IconData _iconFor(String? type) => switch (type) {
        'user' => Icons.person_outline_rounded,
        'book' => Icons.menu_book_rounded,
        'category' => Icons.category_outlined,
        'order' => Icons.receipt_long_outlined,
        'dispute' => Icons.gavel_rounded,
        'report' => Icons.report_gmailerrorred_outlined,
        'wallet' => Icons.account_balance_wallet_outlined,
        'announcement' => Icons.campaign_outlined,
        'legal' => Icons.policy_outlined,
        'faq' => Icons.quiz_outlined,
        'level' => Icons.workspace_premium_outlined,
        'cabinet' => Icons.storage_rounded,
        'ticket' => Icons.support_agent_rounded,
        'backup' => Icons.backup_outlined,
        _ => Icons.bolt_rounded,
      };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool showLoading = false}) async {
    _debounce?.cancel();
    final seq = ++_loadSeq;
    if (showLoading) setState(() => _isLoading = true);
    final logs = await _api.fetchAdminOperationLogs(targetType: _targetType, keyword: _search.text.trim());
    if (!mounted || seq != _loadSeq) return;
    setState(() {
      _logs = logs;
      _isLoading = false;
    });
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () => _load(showLoading: true));
  }

  void _setFilter(String? value) {
    if (_targetType == value) return;
    setState(() => _targetType = value);
    _load(showLoading: true);
  }

  void _toggle(AdminOperationLog log) {
    setState(() {
      if (!_expanded.remove(log.logId)) _expanded.add(log.logId);
    });
  }

  Future<void> _undo(AdminOperationLog log) async {
    if (_undoing != null) return;
    final ok = await showConfirmDialog(
      context,
      title: S.undoAction,
      message: S.p0NNtheDataGoesBack(log.summary.isEmpty ? log.action : log.summary),
      confirmLabel: S.undo,
      isDestructive: true,
      icon: Icons.undo_rounded,
    );
    if (!ok || !mounted) return;

    setState(() => _undoing = log.logId);
    String? error;
    try {
      error = await _api.undoAdminOperation(log.logId);
    } finally {
      if (mounted) setState(() => _undoing = null);
    }
    if (!mounted) return;

    if (error != null) {
      if (error.isNotEmpty && error != S.verificationCancelled) showAppSnackBar(context, error, isError: true);
      return;
    }
    showAppSnackBar(context, S.undone);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final filtered = _targetType != null || _search.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: c.scaffold,
      body: AdminLayout(
        builder: (context, frame) => Column(
          children: [
            AppHeader(title: S.adminAuditLog, icon: Icons.fact_check_outlined),
            Padding(
              padding: frame.inset(const EdgeInsets.fromLTRB(16, 12, 16, 8)),
              child: AppSearchField(
                controller: _search,
                hint: S.searchActionsEGNicknameBook,
                onChanged: _onSearchChanged,
                onSubmitted: (_) => _load(showLoading: true),
              ),
            ),
            if (frame.isWide)
              Padding(
                padding: frame.inset(const EdgeInsets.symmetric(horizontal: 16)),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [for (final f in _filters) SizedBox(height: 34, child: IntrinsicWidth(child: _buildFilterChip(f, c)))],
                  ),
                ),
              )
            else
              SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filters.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => _buildFilterChip(_filters[i], c),
                ),
              ),
            Expanded(
              child: SwitchIn(
                child: _isLoading
                    ? const LoadingView.list()
                    : RefreshIndicator(
                        color: c.accent,
                        onRefresh: _load,
                        child: SwitchIn(
                          child: _logs.isEmpty
                              ? ListView(
                                  key: const ValueKey('empty'),
                                  children: [
                                    const SizedBox(height: 60),
                                    EmptyView(
                                      icon: Icons.fact_check_outlined,
                                      message: S.noActivityYet,
                                      actionLabel: filtered ? S.clearFilters : S.refresh,
                                      onAction: () {
                                        if (filtered) {
                                          _search.clear();
                                          _targetType = null;
                                        }
                                        _load(showLoading: true);
                                      },
                                    ),
                                  ],
                                )
                              : ListView.builder(
                                  key: ValueKey('items_$_targetType'),
                                  padding: frame.inset(const EdgeInsets.fromLTRB(16, 12, 16, 24)),
                                  itemCount: _logs.length,
                                  itemBuilder: (_, i) => RevealOnScroll(index: i, child: _buildCard(_logs[i], c)),
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

  Widget _buildFilterChip(({String? value, String label}) f, AppColors c) {
    final selected = _targetType == f.value;
    return PressableScale(
      scale: 0.94,
      onTap: () => _setFilter(f.value),
      child: AnimatedContainer(
        duration: Motion.micro,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? c.accent : c.categoryChip,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          f.label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            color: selected ? Colors.white : c.accent,
          ),
        ),
      ),
    );
  }

  String? _typeLabel(String? type) {
    if (type == null) return null;
    for (final f in _filters) {
      if (f.value == type) return f.label;
    }
    return type;
  }

  Widget _buildCard(AdminOperationLog log, AppColors c) {
    final expanded = _expanded.contains(log.logId);
    final hasDetail = log.changes.isNotEmpty || (log.ipAddress?.isNotEmpty ?? false);
    final reverted = log.isReverted;
    final tint = reverted ? c.iconInactive : c.accent;
    final typeLabel = _typeLabel(log.targetType);

    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      onTap: hasDetail ? () => _toggle(log) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  reverted ? Icons.undo_rounded : _iconFor(log.targetType),
                  size: 18,
                  color: tint,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          log.action,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: reverted ? c.textSecondary : c.textPrimary,
                            decoration: reverted ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        if (typeLabel != null)
                          StatusBadge(
                            label: log.targetNo == null ? typeLabel : '$typeLabel ${log.targetNo}',
                            color: c.neutral,
                            fontSize: 10,
                          ),
                        if (reverted) StatusBadge(label: S.undone, color: c.warning, fontSize: 10),
                      ],
                    ),
                    if (log.summary.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        log.summary,
                        style: TextStyle(fontSize: 13, height: 1.45, color: c.textPrimary.withValues(alpha: 0.85)),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.person_outline_rounded, size: 12, color: c.textHint),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            log.adminName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: c.textHint),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(Icons.schedule_rounded, size: 12, color: c.textHint),
                        const SizedBox(width: 3),
                        Flexible(
                          flex: 2,
                          child: Tooltip(
                            message: formatDateTime(log.createdAt),
                            child: Text(
                              _when(log.createdAt),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, color: c.textHint),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (reverted) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${S.undone}・${formatDateTime(log.revertedAt)}',
                        style: TextStyle(fontSize: 11, color: c.warning),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (hasDetail) ...[
            const SizedBox(height: 8),
            AnimatedSize(
              duration: Motion.base,
              curve: Motion.standard,
              alignment: Alignment.topCenter,
              child: expanded
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: c.inputFill,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final change in log.changes) _buildChange(change, c),
                          if (log.ipAddress?.isNotEmpty ?? false)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'IP ${log.ipAddress}・${log.logNo}',
                                style: TextStyle(fontSize: 11, color: c.textHint),
                              ),
                            ),
                        ],
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
          if (hasDetail || log.canUndo) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (hasDetail)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _toggle(log),
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              log.changes.isEmpty ? S.viewDetails : S.viewP0Changes(log.changes.length),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.accent),
                            ),
                          ),
                          AnimatedRotation(
                            turns: expanded ? 0.5 : 0,
                            duration: Motion.base,
                            curve: Motion.standard,
                            child: Icon(Icons.expand_more_rounded, size: 18, color: c.accent),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  const Spacer(),
                if (log.canUndo && !reverted) ...[
                  const SizedBox(width: 8),
                  SmallActionButton(
                    label: S.undoAction2,
                    color: c.danger,
                    isLoading: _undoing == log.logId,
                    onTap: _undoing == null ? () => _undo(log) : null,
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _when(DateTime? dt) {
    if (dt == null) return '';
    final relative = formatRelative(dt);
    final exact = formatDateTime(dt);
    return exact.startsWith(relative) ? exact : '$relative・$exact';
  }

  Widget _buildChange(LogChange change, AppColors c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(change.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.textSecondary)),
          const SizedBox(height: 2),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: change.from.isEmpty ? '—' : change.from,
                  style: TextStyle(color: c.danger, decoration: TextDecoration.lineThrough),
                ),
                const TextSpan(text: '  →  '),
                TextSpan(
                  text: change.to.isEmpty ? '—' : change.to,
                  style: TextStyle(color: c.success, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            style: TextStyle(fontSize: 13, height: 1.4, color: c.textPrimary),
          ),
        ],
      ),
    );
  }
}
