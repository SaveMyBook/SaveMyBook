import 'package:flutter/material.dart';
import '../../models/admin_models.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/app_header.dart';
import '../../widgets/state_views.dart';
import 'admin_announcement_screen.dart';
import 'admin_cabinet_screen.dart';
import 'admin_dispute_screen.dart';
import 'admin_maintenance_log_screen.dart';
import 'admin_member_screen.dart';
import 'admin_report_screen.dart';

/// 管理後台首頁：總覽數字 + 五大管理功能入口
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final ApiService _api = ApiService();
  AdminOverview _overview = AdminOverview.empty;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final overview = await _api.fetchAdminOverview();
    if (!mounted) return;
    setState(() {
      _overview = overview;
      _isLoading = false;
    });
  }

  Future<void> _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          const AppHeader(title: '管理後台', icon: Icons.admin_panel_settings_outlined),
          Expanded(
            child: _isLoading
                ? const LoadingView()
                : RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                      children: [
                        _buildOverviewCard(c),
                        const SizedBox(height: 20),
                        AppCard(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              _MenuItem(
                                icon: Icons.people_alt_outlined,
                                title: '會員管控',
                                subtitle: '會員列表、停權與黑名單',
                                onTap: () => _open(const AdminMemberScreen()),
                              ),
                              _MenuItem(
                                icon: Icons.report_gmailerrorred_outlined,
                                title: '內容審核',
                                subtitle: '商品檢舉處理',
                                badge: _overview.pendingReportCount,
                                onTap: () => _open(const AdminReportScreen()),
                              ),
                              _MenuItem(
                                icon: Icons.gavel_rounded,
                                title: '仲裁交易',
                                subtitle: '申訴列表與裁決',
                                badge: _overview.pendingDisputeCount,
                                onTap: () => _open(const AdminDisputeScreen()),
                              ),
                              _MenuItem(
                                icon: Icons.storage_rounded,
                                title: '硬體維護',
                                subtitle: '書櫃監控與櫃位狀態',
                                onTap: () => _open(const AdminCabinetScreen()),
                              ),
                              _MenuItem(
                                icon: Icons.history_rounded,
                                title: '維修紀錄',
                                subtitle: '書櫃相關操作紀錄',
                                onTap: () => _open(const AdminMaintenanceLogScreen()),
                              ),
                              _MenuItem(
                                icon: Icons.campaign_outlined,
                                title: '系統公告',
                                subtitle: '推播管理',
                                isLast: true,
                                onTap: () => _open(const AdminAnnouncementScreen()),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCard(AppColors c) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Stat(label: '會員數', value: '${_overview.memberCount}', c: c),
          _Divider(c: c),
          _Stat(label: '今日訂單', value: '${_overview.todayOrderCount}', c: c),
          _Divider(c: c),
          _Stat(label: '待處理案件', value: '${_overview.pendingReportCount + _overview.pendingDisputeCount}', c: c),
          _Divider(c: c),
          _Stat(label: '啟用書櫃', value: '${_overview.activeCabinetCount}', c: c),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final AppColors c;

  const _Stat({required this.label, required this.value, required this.c});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: c.textSecondary, fontSize: 12)),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(color: AppColors.primary, fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  final AppColors c;
  const _Divider({required this.c});

  @override
  Widget build(BuildContext context) => Container(height: 30, width: 1, color: c.divider);
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final int badge;
  final bool isLast;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge = 0,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      children: [
        ListTile(
          leading: Icon(icon, color: AppColors.primary),
          title: Text(
            title,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.textPrimary),
          ),
          subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: c.textSecondary)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (badge > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$badge',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios, size: 16, color: c.iconInactive),
            ],
          ),
          onTap: onTap,
        ),
        if (!isLast)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 1, color: c.divider),
          ),
      ],
    );
  }
}
