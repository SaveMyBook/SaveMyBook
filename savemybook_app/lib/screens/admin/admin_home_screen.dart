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
                        _buildSection(c, '交易管理', [
                          AppMenuItem(
                            icon: Icons.receipt_long_outlined,
                            title: '訂單管理',
                            subtitle: '查詢訂單、人工調整狀態',
                            onTap: () => _open(const AdminOrderScreen()),
                          ),
                          AppMenuItem(
                            icon: Icons.gavel_rounded,
                            title: '仲裁交易',
                            subtitle: '申訴列表與裁決',
                            badge: _overview.pendingDisputeCount,
                            isLast: true,
                            onTap: () => _open(const AdminDisputeScreen()),
                          ),
                        ]),
                        const SizedBox(height: 20),
                        _buildSection(c, '商品管理', [
                          AppMenuItem(
                            icon: Icons.menu_book_rounded,
                            title: S.myBooks,
                            subtitle: '全站書籍、強制下架',
                            onTap: () => _open(const AdminBookScreen()),
                          ),
                          AppMenuItem(
                            icon: Icons.report_gmailerrorred_outlined,
                            title: '內容審核',
                            subtitle: '商品檢舉處理',
                            badge: _overview.pendingReportCount,
                            onTap: () => _open(const AdminReportScreen()),
                          ),
                          AppMenuItem(
                            icon: Icons.category_outlined,
                            title: '分類管理',
                            subtitle: '新增、排序與刪除書籍分類',
                            isLast: true,
                            onTap: () => _open(const AdminCategoryScreen()),
                          ),
                        ]),
                        const SizedBox(height: 20),
                        _buildSection(c, '會員管理', [
                          AppMenuItem(
                            icon: Icons.people_alt_outlined,
                            title: '會員管控',
                            subtitle: '會員列表、停權與黑名單',
                            onTap: () => _open(const AdminMemberScreen()),
                          ),
                          AppMenuItem(
                            icon: Icons.workspace_premium_outlined,
                            title: '會員等級管理',
                            subtitle: '等級門檻與權益設定',
                            onTap: () => _open(const AdminLevelScreen()),
                          ),
                          AppMenuItem(
                            icon: Icons.account_balance_wallet_outlined,
                            title: '錢包管理',
                            subtitle: '查詢餘額、人工增減代幣',
                            isLast: true,
                            onTap: () => _open(const AdminWalletScreen()),
                          ),
                        ]),
                        const SizedBox(height: 20),
                        _buildSection(c, '硬體與營運', [
                          AppMenuItem(
                            icon: Icons.storage_rounded,
                            title: '書櫃監控',
                            subtitle: '書櫃與櫃位狀態',
                            onTap: () => _open(const AdminCabinetScreen()),
                          ),
                          AppMenuItem(
                            icon: Icons.history_rounded,
                            title: '維修紀錄',
                            subtitle: '書櫃相關操作紀錄',
                            onTap: () => _open(const AdminMaintenanceLogScreen()),
                          ),
                          AppMenuItem(
                            icon: Icons.insights_rounded,
                            title: '營運報表',
                            subtitle: '訂單、營收與會員成長',
                            onTap: () => _open(const AdminStatsScreen()),
                          ),
                          AppMenuItem(
                            icon: Icons.campaign_outlined,
                            title: '系統公告',
                            subtitle: '推播管理',
                            onTap: () => _open(const AdminAnnouncementScreen()),
                          ),
                          AppMenuItem(
                            icon: Icons.support_agent_rounded,
                            title: '客服工單',
                            subtitle: '回覆使用者提出的問題',
                            badge: _overview.openTicketCount,
                            onTap: () => _open(const AdminTicketScreen()),
                          ),
                          AppMenuItem(
                            icon: Icons.quiz_outlined,
                            title: '常見問題',
                            subtitle: '幫助中心的常見問題',
                            onTap: () => _open(const AdminFaqScreen()),
                          ),
                          AppMenuItem(
                            icon: Icons.gavel_outlined,
                            title: '法律文件',
                            subtitle: '服務條款、隱私權政策、關於我們',
                            onTap: () => _open(const AdminLegalScreen()),
                          ),
                          AppMenuItem(
                            icon: Icons.fact_check_outlined,
                            title: '管理操作紀錄',
                            subtitle: '管理員異動的稽核軌跡',
                            isLast: true,
                            onTap: () => _open(const AdminOperationLogScreen()),
                          ),
                        ]),
                        const SizedBox(height: 24),
                        _buildSection(c, '系統維運', [
                          AppMenuItem(
                            icon: Icons.backup_outlined,
                            title: '資料庫備份',
                            subtitle: '每日自動備份、手動觸發與下載',
                            onTap: () => _open(const AdminBackupScreen()),
                          ),
                          AppMenuItem(
                            icon: Icons.person_remove_outlined,
                            title: '待刪除帳號',
                            subtitle: '緩衝期內的刪除申請，可代為取消或立即執行',
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
