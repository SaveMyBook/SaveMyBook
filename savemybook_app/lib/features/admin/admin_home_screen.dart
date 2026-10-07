import 'package:flutter/material.dart';
import '../../models/admin_models.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_tiles.dart';
import '../../widgets/responsive.dart';
import '../../widgets/state_views.dart';
import 'admin_announcement_screen.dart';
import 'admin_book_screen.dart';
import 'admin_cabinet_deposit_screen.dart';
import 'admin_cabinet_screen.dart';
import 'admin_content_screen.dart';
import 'admin_category_screen.dart';
import 'admin_dashboard.dart';
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
import 'admin_workspace.dart';
import 'admin_auth_screen.dart';
import 'admin_backup_screen.dart';
import 'admin_deletion_screen.dart';
import 'ai/admin_ai_screen.dart';
import '../../i18n/strings.dart';

typedef _Entry = ({String id, IconData icon, String title, int badge, Widget Function() screen});

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
  final _workspace = GlobalKey<AdminWorkspaceState>();
  int _dashboardGeneration = 0;

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

  void _openSection(String id, {Widget? root, Widget? page}) => _workspace.currentState?.open(id, root: root, page: page);

  void _onSectionChanged(String id) {
    if (id == AdminSections.home) setState(() => _dashboardGeneration++);
    _load();
  }

  Widget _buildWorkspace() {
    return AdminWorkspace(
      key: _workspace,
      home: AdminSection(
        id: AdminSections.home,
        icon: Icons.space_dashboard_outlined,
        title: S.home,
        builder: (_) => AdminDashboard(
          overview: _overview,
          loading: _isLoading,
          generation: _dashboardGeneration,
          onRefresh: _load,
          onOpen: _openSection,
        ),
      ),
      groups: [
        for (final section in _sectionData())
          AdminSectionGroup(section.title, [
            for (final entry in section.items)
              AdminSection(id: entry.id, icon: entry.icon, title: entry.title, badge: entry.badge, builder: (_) => entry.screen()),
          ]),
      ],
      onSectionChanged: _onSectionChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    if (context.isWide) return _buildWorkspace();

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
                        final sections = [
                          for (final (i, s) in _sectionData().indexed)
                            _buildSection(c, i + 1, s.title, [
                              for (final (j, entry) in s.items.indexed)
                                AppMenuItem(
                                  icon: entry.icon,
                                  title: entry.title,
                                  badge: entry.badge,
                                  isLast: j == s.items.length - 1,
                                  onTap: () => _open(entry.screen()),
                                ),
                            ]),
                        ];
                        return ListView(
                          padding: frame.inset(const EdgeInsets.fromLTRB(20, 20, 20, 40), maxWidth: 1200),
                          children: [
                            FadeSlideIn(child: _buildOverviewCard(c)),
                            const SizedBox(height: 24),
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
                        );
                      },
                    ),
                  )),
          ),
        ],
      ),
    );
  }

  _Entry _entry(String id, IconData icon, String title, Widget Function() screen, {int badge = 0}) =>
      (id: id, icon: icon, title: title, badge: badge, screen: screen);

  List<({String title, List<_Entry> items})> _sectionData() => [
        (
          title: S.transactions2,
          items: [
            _entry(AdminSections.orders, Icons.receipt_long_outlined, S.orders, () => const AdminOrderScreen()),
            _entry(AdminSections.disputes, Icons.gavel_rounded, S.resolveDispute, () => const AdminDisputeScreen(),
                badge: _overview.pendingDisputeCount),
          ],
        ),
        (
          title: S.listings,
          items: [
            _entry(AdminSections.books, Icons.menu_book_rounded, S.myBooks, () => const AdminBookScreen()),
            _entry(AdminSections.moderation, Icons.report_gmailerrorred_outlined, S.moderation,
                () => AdminReportScreen(initialTab: AdminReportScreen.initialTabFor(_overview)),
                badge: _overview.pendingModerationCount),
            _entry(AdminSections.categories, Icons.category_outlined, S.categories, () => const AdminCategoryScreen()),
          ],
        ),
        (
          title: S.members,
          items: [
            _entry(AdminSections.members, Icons.people_alt_outlined, S.memberControls, () => const AdminMemberScreen()),
            _entry(AdminSections.tiers, Icons.workspace_premium_outlined, S.membershipTiers, () => const AdminLevelScreen()),
            _entry(AdminSections.wallets, Icons.account_balance_wallet_outlined, S.wallets, () => const AdminWalletScreen()),
          ],
        ),
        (
          title: S.hardwareOperations,
          items: [
            _entry(AdminSections.cabinets, Icons.storage_rounded, S.lockerMonitor, () => const AdminCabinetScreen()),
            _entry(AdminSections.deposits, Icons.inventory_2_outlined, S.booksLockers, () => const AdminCabinetDepositScreen()),
            _entry(AdminSections.maintenance, Icons.history_rounded, S.maintenanceLog, () => const AdminMaintenanceLogScreen()),
            _entry(AdminSections.stats, Icons.insights_rounded, S.reports, () => const AdminStatsScreen()),
            _entry(AdminSections.announcements, Icons.campaign_outlined, S.announcements, () => const AdminAnnouncementScreen()),
            _entry(AdminSections.tickets, Icons.support_agent_rounded, S.supportEnquiries, () => const AdminTicketScreen(),
                badge: _overview.openTicketCount),
            _entry(AdminSections.faq, Icons.quiz_outlined, S.faq, () => const AdminFaqScreen()),
            _entry(AdminSections.legal, Icons.gavel_outlined, S.legalDocuments, () => const AdminLegalScreen()),
            _entry(AdminSections.audit, Icons.fact_check_outlined, S.adminAuditLog, () => const AdminOperationLogScreen()),
          ],
        ),
        (
          title: S.systemOperations,
          items: [
            _entry(AdminSections.ai, Icons.auto_awesome_rounded, S.aiFeatures, () => const AdminAiScreen()),
            _entry(AdminSections.auth, Icons.login_rounded, S.signMethod, () => const AdminAuthScreen()),
            _entry(AdminSections.backups, Icons.backup_outlined, S.databaseBackups, () => const AdminBackupScreen()),
            _entry(AdminSections.deletions, Icons.person_remove_outlined, S.pendingDeletions, () => const AdminDeletionScreen()),
          ],
        ),
      ];

  void _openCases() => _open(_overview.pendingDisputeCount > 0 || _overview.pendingModerationCount == 0
      ? const AdminDisputeScreen()
      : AdminReportScreen(initialTab: AdminReportScreen.initialTabFor(_overview)));

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
              _overview.pendingModerationCount + _overview.pendingDisputeCount,
              c,
              alert: true,
              onTap: _openCases,
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
