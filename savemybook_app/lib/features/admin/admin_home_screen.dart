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
import 'admin_cabinet_deposit_screen.dart';
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

typedef _Entry = ({IconData icon, String title, int badge, VoidCallback onTap});

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
                        if (frame.isWide) return _buildWide(c, frame);
                        final sections = [
                          for (final (i, s) in _sectionData().indexed)
                            _buildSection(c, i + 1, s.title, [
                              for (final (j, entry) in s.items.indexed)
                                AppMenuItem(
                                  icon: entry.icon,
                                  title: entry.title,
                                  badge: entry.badge,
                                  isLast: j == s.items.length - 1,
                                  onTap: entry.onTap,
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

  _Entry _entry(IconData icon, String title, Widget Function() screen, {int badge = 0}) =>
      (icon: icon, title: title, badge: badge, onTap: () => _open(screen()));

  List<({String title, List<_Entry> items})> _sectionData() => [
        (
          title: S.transactions2,
          items: [
            _entry(Icons.receipt_long_outlined, S.orders, () => const AdminOrderScreen()),
            _entry(Icons.gavel_rounded, S.resolveDispute, () => const AdminDisputeScreen(),
                badge: _overview.pendingDisputeCount),
          ],
        ),
        (
          title: S.listings,
          items: [
            _entry(Icons.menu_book_rounded, S.myBooks, () => const AdminBookScreen()),
            _entry(Icons.report_gmailerrorred_outlined, S.moderation,
                () => AdminReportScreen(initialTab: AdminReportScreen.initialTabFor(_overview)),
                badge: _overview.pendingModerationCount),
            _entry(Icons.category_outlined, S.categories, () => const AdminCategoryScreen()),
          ],
        ),
        (
          title: S.members,
          items: [
            _entry(Icons.people_alt_outlined, S.memberControls, () => const AdminMemberScreen()),
            _entry(Icons.workspace_premium_outlined, S.membershipTiers, () => const AdminLevelScreen()),
            _entry(Icons.account_balance_wallet_outlined, S.wallets, () => const AdminWalletScreen()),
          ],
        ),
        (
          title: S.hardwareOperations,
          items: [
            _entry(Icons.storage_rounded, S.lockerMonitor, () => const AdminCabinetScreen()),
            _entry(Icons.inventory_2_outlined, S.booksLockers, () => const AdminCabinetDepositScreen()),
            _entry(Icons.history_rounded, S.maintenanceLog, () => const AdminMaintenanceLogScreen()),
            _entry(Icons.insights_rounded, S.reports, () => const AdminStatsScreen()),
            _entry(Icons.campaign_outlined, S.announcements, () => const AdminAnnouncementScreen()),
            _entry(Icons.support_agent_rounded, S.supportEnquiries, () => const AdminTicketScreen(),
                badge: _overview.openTicketCount),
            _entry(Icons.quiz_outlined, S.faq, () => const AdminFaqScreen()),
            _entry(Icons.gavel_outlined, S.legalDocuments, () => const AdminLegalScreen()),
            _entry(Icons.fact_check_outlined, S.adminAuditLog, () => const AdminOperationLogScreen()),
          ],
        ),
        (
          title: S.systemOperations,
          items: [
            _entry(Icons.auto_awesome_rounded, S.aiFeatures, () => const AdminAiScreen()),
            _entry(Icons.login_rounded, S.signMethod, () => const AdminAuthScreen()),
            _entry(Icons.backup_outlined, S.databaseBackups, () => const AdminBackupScreen()),
            _entry(Icons.person_remove_outlined, S.pendingDeletions, () => const AdminDeletionScreen()),
          ],
        ),
      ];

  Widget _buildWide(AppColors c, AdminFrame frame) {
    return ListView(
      padding: frame.pad(const EdgeInsets.fromLTRB(24, 24, 24, 40)),
      children: [
        FadeSlideIn(
          child: _tileGrid(
            minTileWidth: 200,
            height: 84,
            avoidThreeColumns: true,
            children: [
              _statCard(c, Icons.people_alt_outlined, S.members2, _overview.memberCount,
                  onTap: () => _open(const AdminMemberScreen())),
              _statCard(c, Icons.receipt_long_outlined, S.todaySOrders, _overview.todayOrderCount,
                  onTap: () => _open(const AdminOrderScreen())),
              _statCard(
                c,
                Icons.gavel_rounded,
                S.openCases,
                _overview.pendingModerationCount + _overview.pendingDisputeCount,
                alert: true,
                onTap: _openCases,
              ),
              _statCard(c, Icons.storage_rounded, S.activeLockers, _overview.activeCabinetCount,
                  onTap: () => _open(const AdminCabinetScreen())),
            ],
          ),
        ),
        for (final (i, section) in _sectionData().indexed)
          FadeSlideIn(
            index: i + 1,
            child: Padding(
              padding: const EdgeInsets.only(top: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle(c, section.title),
                  _tileGrid(
                    minTileWidth: 220,
                    height: 68,
                    children: [for (final entry in section.items) _menuTile(c, entry)],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _tileGrid({
    required double minTileWidth,
    required double height,
    required List<Widget> children,
    bool avoidThreeColumns = false,
  }) {
    const gap = 12.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        var columns = ((constraints.maxWidth + gap) / (minTileWidth + gap)).floor().clamp(1, 4);
        if (avoidThreeColumns && columns == 3) columns = 2;
        final width = ((constraints.maxWidth - gap * (columns - 1)) / columns).floorToDouble();
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final child in children) SizedBox(width: width, height: height, child: child)],
        );
      },
    );
  }

  Widget _statCard(AppColors c, IconData icon, String label, int value, {required VoidCallback onTap, bool alert = false}) {
    final tint = alert && value > 0 ? c.danger : c.accent;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: tint.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: tint, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: AnimatedCount(
                    value: value.toDouble(),
                    style: TextStyle(color: tint, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: c.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuTile(AppColors c, _Entry entry) {
    return AppCard(
      onTap: entry.onTap,
      padding: const EdgeInsets.only(left: 14, right: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: c.accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(entry.icon, color: c.accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              entry.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14.5, height: 1.3, fontWeight: FontWeight.w600, color: c.textPrimary),
            ),
          ),
          if (entry.badge > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: c.danger, borderRadius: BorderRadius.circular(12)),
              child: Text(
                entry.badge > 99 ? '99+' : '${entry.badge}',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, size: 20, color: c.iconInactive),
        ],
      ),
    );
  }

  Widget _sectionTitle(AppColors c, String title) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 10),
        child: Text(
          title,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: c.textSecondary, letterSpacing: 0.5),
        ),
      );

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
