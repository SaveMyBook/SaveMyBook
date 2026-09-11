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
import 'admin_level_screen.dart';
import 'admin_maintenance_log_screen.dart';
import 'admin_member_screen.dart';
import 'admin_operation_log_screen.dart';
import 'admin_order_screen.dart';
import 'admin_report_screen.dart';
import 'admin_stats_screen.dart';
import 'admin_ticket_screen.dart';
import 'admin_wallet_screen.dart';
import 'admin_backup_screen.dart';
import 'admin_deletion_screen.dart';
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
          AppHeader(title: S.admin, icon: Icons.admin_panel_settings_outlined),
          Expanded(
            child: SwitchIn(child: _isLoading
                ? const LoadingView.menu()
                : RefreshIndicator(
                    color: c.accent,
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                      children: [
                        _buildOverviewCard(c),
                        const SizedBox(height: 24),
                        _buildSection(c, S.transactions2, [
                          AppMenuItem(
                            icon: Icons.receipt_long_outlined,
                            title: S.orders,
                            subtitle: S.lookUpOrdersAdjustStatusBy,
                            onTap: () => _open(const AdminOrderScreen()),
                          ),
                          AppMenuItem(
                            icon: Icons.gavel_rounded,
                            title: S.resolveDispute,
                            subtitle: S.disputeListDecisions,
                            badge: _overview.pendingDisputeCount,
                            isLast: true,
                            onTap: () => _open(const AdminDisputeScreen()),
                          ),
                        ]),
                        const SizedBox(height: 20),
                        _buildSection(c, S.listings, [
                          AppMenuItem(
                            icon: Icons.menu_book_rounded,
                            title: S.myBooks,
                            subtitle: S.allBooksForceDelisting,
                            onTap: () => _open(const AdminBookScreen()),
                          ),
                          AppMenuItem(
                            icon: Icons.report_gmailerrorred_outlined,
                            title: S.moderation,
                            subtitle: S.handleListingReports,
                            badge: _overview.pendingReportCount,
                            onTap: () => _open(const AdminReportScreen()),
                          ),
                          AppMenuItem(
                            icon: Icons.category_outlined,
                            title: S.categories,
                            subtitle: S.addReorderDeleteBookCategories,
                            isLast: true,
                            onTap: () => _open(const AdminCategoryScreen()),
                          ),
                        ]),
                        const SizedBox(height: 20),
                        _buildSection(c, S.members, [
                          AppMenuItem(
                            icon: Icons.people_alt_outlined,
                            title: S.memberControls,
                            subtitle: S.memberListSuspensionBlocklist,
                            onTap: () => _open(const AdminMemberScreen()),
                          ),
                          AppMenuItem(
                            icon: Icons.workspace_premium_outlined,
                            title: S.membershipTiers,
                            subtitle: S.tierThresholdsBenefits,
                            onTap: () => _open(const AdminLevelScreen()),
                          ),
                          AppMenuItem(
                            icon: Icons.account_balance_wallet_outlined,
                            title: S.wallets,
                            subtitle: S.checkBalancesAddDeductCoinsBy,
                            isLast: true,
                            onTap: () => _open(const AdminWalletScreen()),
                          ),
                        ]),
                        const SizedBox(height: 20),
                        _buildSection(c, S.hardwareOperations, [
                          AppMenuItem(
                            icon: Icons.storage_rounded,
                            title: S.lockerMonitor,
                            subtitle: S.lockerSlotStatus,
                            onTap: () => _open(const AdminCabinetScreen()),
                          ),
                          AppMenuItem(
                            icon: Icons.history_rounded,
                            title: S.maintenanceLog,
                            subtitle: S.lockerOperationHistory,
                            onTap: () => _open(const AdminMaintenanceLogScreen()),
                          ),
                          AppMenuItem(
                            icon: Icons.insights_rounded,
                            title: S.reports,
                            subtitle: S.ordersRevenueMemberGrowth,
                            onTap: () => _open(const AdminStatsScreen()),
                          ),
                          AppMenuItem(
                            icon: Icons.campaign_outlined,
                            title: S.announcements,
                            subtitle: S.announcements2,
                            onTap: () => _open(const AdminAnnouncementScreen()),
                          ),
                          AppMenuItem(
                            icon: Icons.support_agent_rounded,
                            title: S.supportEnquiries,
                            subtitle: S.replyQuestionsFromUsers,
                            badge: _overview.openTicketCount,
                            onTap: () => _open(const AdminTicketScreen()),
                          ),
                          AppMenuItem(
                            icon: Icons.quiz_outlined,
                            title: S.faq,
                            subtitle: S.faqShownHelpCentre,
                            onTap: () => _open(const AdminFaqScreen()),
                          ),
                          AppMenuItem(
                            icon: Icons.gavel_outlined,
                            title: S.legalDocuments,
                            subtitle: S.termsPrivacyPolicyAbout,
                            onTap: () => _open(const AdminLegalScreen()),
                          ),
                          AppMenuItem(
                            icon: Icons.fact_check_outlined,
                            title: S.adminAuditLog,
                            subtitle: S.auditTrailAdminChanges,
                            isLast: true,
                            onTap: () => _open(const AdminOperationLogScreen()),
                          ),
                        ]),
                        const SizedBox(height: 24),
                        _buildSection(c, S.systemOperations, [
                          AppMenuItem(
                            icon: Icons.backup_outlined,
                            title: S.databaseBackups,
                            subtitle: S.dailyBackupsManualRunsDownloads,
                            onTap: () => _open(const AdminBackupScreen()),
                          ),
                          AppMenuItem(
                            icon: Icons.person_remove_outlined,
                            title: S.pendingDeletions,
                            subtitle: S.deletionRequestsInsideGracePeriodCancel,
                            isLast: true,
                            onTap: () => _open(const AdminDeletionScreen()),
                          ),
                        ]),
                      ],
                    ),
                  )),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(AppColors c, String title, List<Widget> items) {
    return Column(
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
          _stat(S.members2, _overview.memberCount, c),
          const VerticalDivider1(),
          _stat(S.todaySOrders, _overview.todayOrderCount, c),
          const VerticalDivider1(),
          _stat(S.openCases, _overview.pendingReportCount + _overview.pendingDisputeCount, c),
          const VerticalDivider1(),
          _stat(S.activeLockers, _overview.activeCabinetCount, c),
        ],
      ),
    );
  }
}
