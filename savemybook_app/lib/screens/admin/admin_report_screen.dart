import 'package:flutter/material.dart';
import '../../models/admin_models.dart';
import '../../services/api_service.dart';
import '../../utils/api_helpers.dart';
import '../../utils/app_colors.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/app_forms.dart';
import '../../widgets/app_header.dart';
import '../../widgets/state_views.dart';

class AdminReportScreen extends StatefulWidget {
  const AdminReportScreen({super.key});

  @override
  State<AdminReportScreen> createState() => _AdminReportScreenState();
}

class _AdminReportScreenState extends State<AdminReportScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late final TabController _tabController;

  List<ReportCase> _reports = [];
  bool _isLoading = true;

  bool get _isPendingTab => _tabController.index == 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) _load();
    });
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final all = await _api.fetchAdminReports();
    if (!mounted) return;
    setState(() {
      _reports = all
          .where((r) => _isPendingTab
              ? (r.status == 'pending' || r.status == 'reviewing')
              : (r.status == 'resolved' || r.status == 'dismissed'))
          .toList();
      _isLoading = false;
    });
  }

  Future<void> _review(ReportCase report) async {
    final c = AppColors.of(context);
    final noteController = TextEditingController();
    bool removeTarget = report.targetType == 'book';

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
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
              Text('審核檢舉',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.textPrimary)),
              const SizedBox(height: 6),
              Text('被檢舉${report.targetTypeText}：${report.targetTitle}',
                  style: TextStyle(fontSize: 13, color: c.textSecondary)),
              const SizedBox(height: 4),
              Text('違規原因：${report.reason}',
                  style: TextStyle(fontSize: 13, color: c.textSecondary)),
              const SizedBox(height: 16),
              AppTextField(
                controller: noteController,
                maxLines: 3,
                maxLength: 500,
                hint: '處理備註（選填）',
              ),
              if (report.targetType == 'book')
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: removeTarget,
                  activeColor: c.accent,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text('同時將該商品下架',
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
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('駁回檢舉'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, 'resolved'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('違規成立'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (result == null || !mounted) return;

    final error = await runBusy(
      context,
      () => _api.resolveReport(
        report.reportId,
        status: result,
        adminNote: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
        removeTarget: result == 'resolved' && removeTarget,
      ),
    );
    if (!mounted) return;

    if (error != null) {
      showAppSnackBar(context, error, isError: true);
    } else {
      showAppSnackBar(context, '檢舉已處理');
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          AppHeader(
            title: '商品檢舉處理',
            icon: Icons.report_gmailerrorred_outlined,
            bottom: AppTabBar(controller: _tabController, tabs: const ['待處理', '已處理']),
          ),
          Expanded(
            child: SwipeTabs(
              controller: _tabController,
              child: SwitchIn(child: _isLoading
                ? const LoadingView.list()
                : RefreshIndicator(
                    color: c.accent,
                    onRefresh: _load,
                    child: _reports.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 80),
                              EmptyView(icon: Icons.verified_outlined, message: '目前沒有此類檢舉案件'),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _reports.length,
                            itemBuilder: (_, i) => RevealOnScroll(index: i, child: _buildCard(_reports[i], c)),
                          ),
                  )),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(ReportCase report, AppColors c) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
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
                    Text(
                      report.targetTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text('檢舉人：${report.reporterName}',
                        style: TextStyle(fontSize: 12, color: c.textSecondary)),
                    const SizedBox(height: 2),
                    Text('違規原因：${report.reason}',
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
              Text(formatDateTime(report.createdAt), style: TextStyle(fontSize: 11, color: c.textHint)),
              const Spacer(),
              if (_isPendingTab)
                GestureDetector(
                  onTap: () => _review(report),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: c.accent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('審核',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                )
              else
                Text(report.statusText,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
            ],
          ),
          if (!_isPendingTab && (report.adminNote?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 8),
            Text('備註：${report.adminNote}', style: TextStyle(fontSize: 12, color: c.textSecondary)),
          ],
        ],
      ),
    );
  }
}
