import 'package:flutter/material.dart';
import '../../models/admin_models.dart';
import '../../services/api_service.dart';
import '../../utils/api_helpers.dart';
import '../../utils/app_colors.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_header.dart';
import '../../widgets/state_views.dart';

class AdminOperationLogScreen extends StatefulWidget {
  const AdminOperationLogScreen({super.key});

  @override
  State<AdminOperationLogScreen> createState() => _AdminOperationLogScreenState();
}

class _AdminOperationLogScreenState extends State<AdminOperationLogScreen> {
  final ApiService _api = ApiService();
  List<AdminOperationLog> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final logs = await _api.fetchAdminOperationLogs();
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
          const AppHeader(title: '管理操作紀錄', icon: Icons.fact_check_outlined),
          Expanded(
            child: SwitchIn(
              child: _isLoading
                  ? const LoadingView.list()
                  : RefreshIndicator(
                      color: c.accent,
                      onRefresh: _load,
                      child: SwitchIn(child: _logs.isEmpty
                          ? ListView(key: const ValueKey('empty'), 
                              children: const [
                                SizedBox(height: 60),
                                EmptyView(
                                  icon: Icons.fact_check_outlined,
                                  message: '尚無操作紀錄',
                                ),
                              ],
                            )
                          : ListView.builder(key: const ValueKey('items'), 
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                              itemCount: _logs.length,
                              itemBuilder: (_, i) => RevealOnScroll(
                                index: i,
                                child: _buildCard(_logs[i], c),
                              ),
                            )),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(AdminOperationLog log, AppColors c) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: c.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.bolt_rounded, size: 18, color: c.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.action,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${log.adminName}'
                  '${log.targetType == null ? '' : '｜${log.targetType} #${log.targetId}'}',
                  style: TextStyle(fontSize: 12, color: c.textSecondary),
                ),
                if (log.detail != null && log.detail!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    log.detail!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: c.textHint, height: 1.4),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatDateTime(log.createdAt),
            style: TextStyle(fontSize: 10, color: c.textHint),
          ),
        ],
      ),
    );
  }
}
