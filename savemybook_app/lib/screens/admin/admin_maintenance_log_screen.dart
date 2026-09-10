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
                  ? const LoadingView()
                  : RefreshIndicator(
                      key: const ValueKey('logs'),
                      color: c.accent,
                      onRefresh: _load,
                      child: _logs.isEmpty
                          ? ListView(
                              children: const [
                                SizedBox(height: 80),
                                EmptyView(icon: Icons.build_outlined, message: '目前沒有維修紀錄'),
                              ],
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _logs.length,
                              itemBuilder: (_, i) => FadeSlideIn(
                                index: i,
                                child: _buildLogCard(_logs[i], c),
                              ),
                            ),
                    ),
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
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: c.accent.withOpacity(0.12),
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
