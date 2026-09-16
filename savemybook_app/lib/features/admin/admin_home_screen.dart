import 'package:flutter/material.dart';
import '../../models/admin_models.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_tiles.dart';
import '../../widgets/state_views.dart';
import 'admin_announcement_screen.dart';
import 'admin_book_screen.dart';
import 'admin_cabinet_screen.dart';
import 'admin_content_screen.dart';
import 'admin_category_screen.dart';
import 'admin_dispute_screen.dart';
import 'admin_layout.dart';
import 'admin_level_screen.dart';
import 'admin_maintenance_log_screen.dart';
import 'admin_member_screen.dart';
import 'admin_operation_log_screen.dart';
import 'admin_order_screen.dart';
import 'admin_report_screen.dart';
import 'admin_stats_screen.dart';
import 'admin_ticket_screen.dart';
import 'admin_wallet_screen.dart';
import 'admin_auth_screen.dart';
import 'admin_backup_screen.dart';
import 'admin_deletion_screen.dart';
import 'ai/admin_ai_screen.dart';
import '../../i18n/strings.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final ApiService _api = ApiService();
  AdminOverview _overview = AdminOverview.empty;
  bool _isLoading = true;
  bool _navigating = false;

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
    if (_navigating) return;
    _navigating = true;
    try {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    } finally {
      _navigating = false;
    }
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          AppHeader(title: S.admin, icon: Icons.admin_panel_settings_outlined),
          Expanded(
            child: SwitchIn(child: _isLoading
                ? const LoadingView.menu()
                : RefreshIndicator(
                    color: c.accent,
                    onRefresh: _load,
                    child: AdminLayout(
                      builder: (context, frame) {
                        final sections = _sections(c);
                        return ListView(
                          padding: frame.inset(const EdgeInsets.fromLTRB(20, 20, 20, 40), maxWidth: 1200),
                          children: [
                            FadeSlideIn(child: _buildOverviewCard(c)),
                            const SizedBox(height: 24),
                            if (frame.isWide)
                              AdminColumns(
                                gap: 20,
                                spacing: 20,
                                columns: frame.isExpanded
                                    ? [
                                        [sections[0], sections[1]],
                                        [sections[3]],
                                        [sections[2], sections[4]],
                                      ]
                                    : [
                                        [sections[0], sections[1], sections[2]],
                                        [sections[3], sections[4]],
                                      ],
                              )
                            else ...[
                              sections[0],
                              const SizedBox(height: 20),
                              sections[1],
                              const SizedBox(height: 20),
                              sections[2],
                              const SizedBox(height: 20),
                              sections[3],
                              const SizedBox(height: 24),
                              sections[4],
                            ],
                          ],
                        );
                      },
                    ),
                  )),
          ),
        ],
      ),
    );
  }

  List<Widget> _sections(AppColors c) => [
        _buildSection(c, 1, S.transactions2, [
          AppMenuItem(
            icon: Icons.receipt_long_outlined,
            title: S.orders,
            onTap: () => _open(const AdminOrderScreen()),
          ),
          AppMenuItem(
            icon: Icons.gavel_rounded,
            title: S.resolveDispute,
            badge: _overview.pendingDisputeCount,
            isLast: true,
            onTap: () => _open(const AdminDisputeScreen()),
          ),
        ]),
        _buildSection(c, 2, S.listings, [
          AppMenuItem(
            icon: Icons.menu_book_rounded,
            title: S.myBooks,
            onTap: () => _open(const AdminBookScreen()),
          ),
          AppMenuItem(
            icon: Icons.report_gmailerrorred_outlined,
            title: S.moderation,
            badge: _overview.pendingReportCount,
            onTap: () => _open(const AdminReportScreen()),
          ),
          AppMenuItem(
            icon: Icons.category_outlined,
            title: S.categories,
            isLast: true,
            onTap: () => _open(const AdminCategoryScreen()),
          ),
        ]),
        _buildSection(c, 3, S.members, [
          AppMenuItem(
            icon: Icons.people_alt_outlined,
            title: S.memberControls,
            onTap: () => _open(const AdminMemberScreen()),
          ),
          AppMenuItem(
            icon: Icons.workspace_premium_outlined,
            title: S.membershipTiers,
            onTap: () => _open(const AdminLevelScreen()),
          ),
          AppMenuItem(
            icon: Icons.account_balance_wallet_outlined,
            title: S.wallets,
            isLast: true,
            onTap: () => _open(const AdminWalletScreen()),
          ),
        ]),
        _buildSection(c, 4, S.hardwareOperations, [
          AppMenuItem(
            icon: Icons.storage_rounded,
            title: S.lockerMonitor,
            onTap: () => _open(const AdminCabinetScreen()),
          ),
          AppMenuItem(
            icon: Icons.history_rounded,
            title: S.maintenanceLog,
            onTap: () => _open(const AdminMaintenanceLogScreen()),
          ),
          AppMenuItem(
            icon: Icons.insights_rounded,
            title: S.reports,
            onTap: () => _open(const AdminStatsScreen()),
          ),
          AppMenuItem(
            icon: Icons.campaign_outlined,
            title: S.announcements,
            onTap: () => _open(const AdminAnnouncementScreen()),
          ),
          AppMenuItem(
            icon: Icons.support_agent_rounded,
            title: S.supportEnquiries,
            badge: _overview.openTicketCount,
            onTap: () => _open(const AdminTicketScreen()),
          ),
          AppMenuItem(
            icon: Icons.quiz_outlined,
            title: S.faq,
            onTap: () => _open(const AdminFaqScreen()),
          ),
          AppMenuItem(
            icon: Icons.gavel_outlined,
            title: S.legalDocuments,
            onTap: () => _open(const AdminLegalScreen()),
          ),
          AppMenuItem(
            icon: Icons.fact_check_outlined,
            title: S.adminAuditLog,
            isLast: true,
            onTap: () => _open(const AdminOperationLogScreen()),
          ),
        ]),
        _buildSection(c, 5, S.systemOperations, [
          AppMenuItem(
            icon: Icons.auto_awesome_rounded,
            title: S.aiFeatures,
            onTap: () => _open(const AdminAiScreen()),
          ),
          AppMenuItem(
            icon: Icons.login_rounded,
            title: S.signMethod,
            onTap: () => _open(const AdminAuthScreen()),
          ),
          AppMenuItem(
            icon: Icons.backup_outlined,
            title: S.databaseBackups,
            onTap: () => _open(const AdminBackupScreen()),
          ),
          AppMenuItem(
            icon: Icons.person_remove_outlined,
            title: S.pendingDeletions,
            isLast: true,
            onTap: () => _open(const AdminDeletionScreen()),
          ),
        ]),
      ];

  Widget _buildSection(AppColors c, int index, String title, List<Widget> items) {
    return FadeSlideIn(
      index: index,
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: c.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
        ),
        AppCard(padding: EdgeInsets.zero, child: Column(children: items)),
      ],
      ),
    );
  }

  Widget _stat(String label, int value, AppColors c, {VoidCallback? onTap, bool alert = false}) {
    return PressableScale(
      onTap: onTap,
      child: StatTile(
        label: label,
        value: AnimatedCount(
          value: value.toDouble(),
          style: TextStyle(
            color: alert && value > 0 ? c.danger : c.accent,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewCard(AppColors c) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: _stat(S.members2, _overview.memberCount, c,
                onTap: () => _open(const AdminMemberScreen())),
          ),
          const VerticalDivider1(),
          Expanded(
            child: _stat(S.todaySOrders, _overview.todayOrderCount, c,
                onTap: () => _open(const AdminOrderScreen())),
          ),
          const VerticalDivider1(),
          Expanded(
            child: _stat(
              S.openCases,
              _overview.pendingReportCount + _overview.pendingDisputeCount,
              c,
              alert: true,
              onTap: () => _open(_overview.pendingDisputeCount > 0 || _overview.pendingReportCount == 0
                  ? const AdminDisputeScreen()
                  : const AdminReportScreen()),
            ),
          ),
          const VerticalDivider1(),
          Expanded(
            child: _stat(S.activeLockers, _overview.activeCabinetCount, c,
                onTap: () => _open(const AdminCabinetScreen())),
          ),
        ],
      ),
    );
  }
}
