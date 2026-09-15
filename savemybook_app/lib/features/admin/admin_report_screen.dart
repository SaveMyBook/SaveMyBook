import 'package:flutter/material.dart';
import '../../models/admin_models.dart';
import '../../services/api_service.dart';
import '../../utils/api_helpers.dart';
import '../../utils/app_colors.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/app_forms.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_tiles.dart';
import '../../widgets/state_views.dart';
import '../../i18n/strings.dart';
import 'admin_layout.dart';

class AdminReportScreen extends StatefulWidget {
  const AdminReportScreen({super.key});

  @override
  State<AdminReportScreen> createState() => _AdminReportScreenState();
}

class _AdminReportScreenState extends State<AdminReportScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  List<ReportCase> _all = [];
  bool _isLoading = true;
  bool _isBusy = false;
  int _loadSeq = 0;
  String _type = 'all';

  bool get _isPendingTab => _tabController.index == 0;

  static bool _isOpen(ReportCase r) => r.status == 'pending' || r.status == 'reviewing';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && mounted) setState(() {});
    });
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool showLoading = true}) async {
    final seq = ++_loadSeq;
    if (showLoading) setState(() => _isLoading = true);
    final all = await _api.fetchAdminReports();
    if (!mounted || seq != _loadSeq) return;
    setState(() {
      _all = all;
      _isLoading = false;
    });
  }

  List<ReportCase> _visible({required bool pending}) {
    final keyword = _searchController.text.trim().toLowerCase();
    return _all.where((r) {
      if (_isOpen(r) != pending) return false;
      if (_type != 'all' && r.targetType != _type) return false;
      if (keyword.isEmpty) return true;
      return r.targetTitle.toLowerCase().contains(keyword) ||
          r.reporterName.toLowerCase().contains(keyword) ||
          r.reason.toLowerCase().contains(keyword);
    }).toList();
  }

  Future<void> _review(ReportCase report) async {
    if (_isBusy) return;
    final c = AppColors.of(context);
    final noteController = TextEditingController();
    bool removeTarget = report.targetType == 'book';

    setState(() => _isBusy = true);
    try {
      final result = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: c.card,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setSheetState) => SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(S.reviewReport,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.textPrimary)),
                  const SizedBox(height: 6),
                  Text(S.reportedP0P1(report.targetTypeText, report.targetTitle),
                      style: TextStyle(fontSize: 13, color: c.textSecondary)),
                  const SizedBox(height: 4),
                  Text(S.reasonP02(report.reason),
                      style: TextStyle(fontSize: 13, color: c.textSecondary)),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: noteController,
                    maxLines: 3,
                    maxLength: 500,
                    hint: S.handlingNoteOptional,
                  ),
                  if (report.targetType == 'book')
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: removeTarget,
                      activeColor: c.accent,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(S.delistListingAsWell,
                          style: TextStyle(fontSize: 14, color: c.textPrimary)),
                      onChanged: (value) => setSheetState(() => removeTarget = value ?? false),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx, 'dismissed'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: c.textSecondary,
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(S.dismissReport, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, 'resolved'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: c.accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(S.violationConfirmed, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      if (result == null || !mounted) return;
      final note = noteController.text.trim();
      final delist = result == 'resolved' && removeTarget;

      if (delist) {
        final ok = await showConfirmDialog(
          context,
          title: S.delistListingAsWell,
          message: S.p0TakenDownRightAwayOther(report.targetTitle),
          confirmLabel: S.violationConfirmed,
          isDestructive: true,
        );
        if (!ok || !mounted) return;
      }

      final error = await runBusy(
        context,
        () => _api.resolveReport(
          report.reportId,
          status: result,
          adminNote: note.isEmpty ? null : note,
          removeTarget: delist,
        ),
      );
      if (!mounted) return;

      if (error != null) {
        if (error.isNotEmpty && error != S.verificationCancelled) showAppSnackBar(context, error, isError: true);
      } else {
        showAppSnackBar(context, S.reportHandled);
        await _load(showLoading: false);
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final pendingCount = _all.where(_isOpen).length;
    final types = <String, String>{
      for (final r in _all) r.targetType: r.targetTypeText,
    };

    return Scaffold(
      backgroundColor: c.scaffold,
      body: AdminLayout(
        builder: (context, frame) => Column(
          children: [
            AppHeader(
              title: S.handleListingReports,
              icon: Icons.report_gmailerrorred_outlined,
              bottom: AppTabBar(
                controller: _tabController,
                tabs: [
                  pendingCount > 0 ? '${S.ticketOpen} $pendingCount' : S.ticketOpen,
                  S.reportResolved,
                ],
              ),
            ),
            Padding(
              padding: frame.inset(const EdgeInsets.fromLTRB(16, 12, 16, 0)),
              child: AppSearchField(
                controller: _searchController,
                hint: S.searchReportedItemReporterReason,
                onChanged: (_) => setState(() {}),
              ),
            ),
            if (types.length > 1)
              SizedBox(
                height: 42,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: frame.inset(const EdgeInsets.fromLTRB(16, 8, 16, 0)),
                  children: [
                    _chip(S.actionAll, 'all', c),
                    for (final entry in types.entries) _chip(entry.value, entry.key, c),
                  ],
                ),
              ),
            Expanded(
              child: SwipeTabs(
                controller: _tabController,
                child: SwitchIn(
                  child: _isLoading
                      ? const LoadingView.list()
                      : _buildList(c, frame),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, String value, AppColors c) {
    final selected = _type == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: PressableScale(
        scale: 0.94,
        onTap: () => setState(() => _type = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? c.accent : c.categoryChip,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              color: selected ? Colors.white : c.accent,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildList(AppColors c, AdminFrame frame) {
    final pending = _isPendingTab;
    final reports = _visible(pending: pending);
    final filtered = _searchController.text.trim().isNotEmpty || _type != 'all';

    return RefreshIndicator(
      key: ValueKey('tab_$pending'),
      color: c.accent,
      onRefresh: () => _load(showLoading: false),
      child: SwitchIn(
        child: reports.isEmpty
            ? ListView(
                key: const ValueKey('empty'),
                children: [
                  const SizedBox(height: 60),
                  EmptyView(
                    icon: Icons.verified_outlined,
                    message: S.noReportsKind,
                    actionLabel: filtered ? S.clearFilters : S.refresh,
                    onAction: () {
                      if (filtered) {
                        _searchController.clear();
                        setState(() => _type = 'all');
                      } else {
                        _load();
                      }
                    },
                  ),
                ],
              )
            : ListView.builder(
                key: ValueKey('items_${pending}_$_type'),
                padding: frame.inset(const EdgeInsets.all(16)),
                itemCount: reports.length,
                itemBuilder: (_, i) => RevealOnScroll(
                  index: i,
                  child: _buildCard(reports[i], c, pending: pending),
                ),
              ),
      ),
    );
  }

  Widget _buildCard(ReportCase report, AppColors c, {required bool pending}) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: pending ? () => _review(report) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BookThumbnail(imageUrl: report.targetImageUrl, width: 52, height: 66, radius: 8),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            report.targetTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c.textPrimary),
                          ),
                        ),
                        const SizedBox(width: 6),
                        StatusBadge(label: report.targetTypeText, color: c.neutral, fontSize: 10),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(S.reportedByP0(report.reporterName),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: c.textSecondary)),
                    const SizedBox(height: 2),
                    Text(S.reasonP02(report.reason),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: c.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  _when(report.createdAt),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: c.textHint),
                ),
              ),
              const SizedBox(width: 8),
              pending
                  ? SmallActionButton(
                      label: S.review,
                      filled: true,
                      onTap: _isBusy ? null : () => _review(report),
                    )
                  : StatusBadge(label: report.statusText, color: c.reportStatusColor(report.status)),
            ],
          ),
          if (!pending && (report.adminNote?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 8),
            Text(S.noteP0(report.adminNote!), style: TextStyle(fontSize: 12, color: c.textSecondary)),
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
}
