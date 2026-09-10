import 'package:flutter/material.dart';
import '../../models/admin_models.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_tiles.dart';
import '../../widgets/state_views.dart';
import 'admin_announcement_screen.dart';
import 'admin_cabinet_screen.dart';
import 'admin_dispute_screen.dart';
import 'admin_maintenance_log_screen.dart';
import 'admin_member_screen.dart';
import 'admin_report_screen.dart';

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
            child: SwitchIn(child: _isLoading
                ? const LoadingView()
                : RefreshIndicator(
                    color: c.accent,
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
                              AppMenuItem(
                                icon: Icons.people_alt_outlined,
                                title: '會員管控',
                                subtitle: '會員列表、停權與黑名單',
                                onTap: () => _open(const AdminMemberScreen()),
                              ),
                              AppMenuItem(
                                icon: Icons.report_gmailerrorred_outlined,
                                title: '內容審核',
                                subtitle: '商品檢舉處理',
                                badge: _overview.pendingReportCount,
                                onTap: () => _open(const AdminReportScreen()),
                              ),
                              AppMenuItem(
                                icon: Icons.gavel_rounded,
                                title: '仲裁交易',
                                subtitle: '申訴列表與裁決',
                                badge: _overview.pendingDisputeCount,
                                onTap: () => _open(const AdminDisputeScreen()),
                              ),
                              AppMenuItem(
                                icon: Icons.storage_rounded,
                                title: '硬體維護',
                                subtitle: '書櫃監控與櫃位狀態',
                                onTap: () => _open(const AdminCabinetScreen()),
                              ),
                              AppMenuItem(
                                icon: Icons.history_rounded,
                                title: '維修紀錄',
                                subtitle: '書櫃相關操作紀錄',
                                onTap: () => _open(const AdminMaintenanceLogScreen()),
                              ),
                              AppMenuItem(
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
                  )),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, int value, AppColors c) {
    return StatTile(
      label: label,
      value: AnimatedCount(
        value: value.toDouble(),
        style: TextStyle(color: c.accent, fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildOverviewCard(AppColors c) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _stat('會員數', _overview.memberCount, c),
          const VerticalDivider1(),
          _stat('今日訂單', _overview.todayOrderCount, c),
          const VerticalDivider1(),
          _stat('待處理案件', _overview.pendingReportCount + _overview.pendingDisputeCount, c),
          const VerticalDivider1(),
          _stat('啟用書櫃', _overview.activeCabinetCount, c),
        ],
      ),
    );
  }
}
