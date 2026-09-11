import 'package:flutter/material.dart';
import '../../models/admin_models.dart';
import '../../services/api_service.dart';
import '../../utils/api_helpers.dart';
import '../../utils/app_colors.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_header.dart';
import '../../widgets/state_views.dart';

class AdminMaintenanceLogScreen extends StatefulWidget {
  const AdminMaintenanceLogScreen({super.key});

  @override
  State<AdminMaintenanceLogScreen> createState() => _AdminMaintenanceLogScreenState();
}

class _AdminMaintenanceLogScreenState extends State<AdminMaintenanceLogScreen> {
  final ApiService _api = ApiService();
  List<MaintenanceLog> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final logs = await _api.fetchMaintenanceLogs();
    if (!mounted) return;
    setState(() {
      _logs = logs;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          const AppHeader(title: '維修紀錄', icon: Icons.history_rounded),
          Expanded(
            child: SwitchIn(
              child: _isLoading
                  ? const LoadingView.list()
                  : RefreshIndicator(
                      key: const ValueKey('logs'),
                      color: c.accent,
                      onRefresh: _load,
                      child: SwitchIn(child: _logs.isEmpty
                          ? ListView(key: const ValueKey('empty'), 
                              children: const [
                                SizedBox(height: 80),
                                EmptyView(icon: Icons.build_outlined, message: '目前沒有維修紀錄'),
                              ],
                            )
                          : ListView.builder(key: const ValueKey('items'), 
                              padding: const EdgeInsets.all(16),
                              itemCount: _logs.length,
                              itemBuilder: (_, i) => RevealOnScroll(
                                index: i,
                                child: _buildLogCard(_logs[i], c),
                              ),
                            )),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDetail(MaintenanceLog log, AppColors c) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                log.action,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: c.textPrimary),
              ),
              const SizedBox(height: 14),
              _detailRow('內容', log.detail?.isNotEmpty == true ? log.detail! : '（無額外說明）', c),
              _detailRow('操作人', log.adminName.isEmpty ? '（未知）' : log.adminName, c),
              _detailRow('時間', formatDateTime(log.createdAt), c),
              _detailRow('紀錄編號', '#${log.logId}', c),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, AppColors c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(label, style: TextStyle(fontSize: 13, color: c.textHint)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 14, height: 1.5, color: c.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard(MaintenanceLog log, AppColors c) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      onTap: () => _showDetail(log, c),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: c.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.build_rounded, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.action,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary),
                ),
                if (log.detail?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 3),
                  Text(log.detail!, style: TextStyle(fontSize: 12, color: c.textSecondary)),
                ],
                const SizedBox(height: 3),
                Text('操作人：${log.adminName}', style: TextStyle(fontSize: 11, color: c.textHint)),
              ],
            ),
          ),
          Text(formatDateTime(log.createdAt), style: TextStyle(fontSize: 11, color: c.textHint)),
        ],
      ),
    );
  }
}
