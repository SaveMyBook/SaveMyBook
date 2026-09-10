import 'package:flutter/material.dart';
import '../models/member_level.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../widgets/state_views.dart';
import 'admin/admin_home_screen.dart';
import 'book_manage_screen.dart';
import 'change_password_screen.dart';
import 'edit_profile_screen.dart';
import 'favorites_screen.dart';
import 'login_screen.dart';
import 'member_level_screen.dart';
import 'purchase_history_screen.dart';
import 'sales_history_screen.dart';
import 'settings_screen.dart';
import 'share_profile_screen.dart';
import 'wallet_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService _api = ApiService();
  UserStats _stats = UserStats.empty;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final stats = await _api.fetchUserStats();
    if (!mounted) return;
    setState(() => _stats = stats);
  }

  Future<void> _handleLogout() async {
    await _api.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _openAndRefresh(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    _loadStats();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final user = ApiService.currentUser;

    return Scaffold(
      backgroundColor: c.scaffold,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadStats,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _buildHeader(c, user?.nickname ?? '使用者', user?.bio ?? '', user?.avatarUrl),
            const SizedBox(height: 20),
            _buildQuickActions(c),
            const SizedBox(height: 20),
            _buildMenu(c),
            const SizedBox(height: 20),
            _buildLogoutButton(c),
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppColors c, String nickname, String bio, String? avatarUrl) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: c.headerBg,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            children: [
              Row(
                children: [
                  const Spacer(),
                  const Text(
                    '會員中心',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: CircleAvatar(
                      radius: 35,
                      backgroundColor: c.inputFill,
                      backgroundImage: avatarUrl == null ? null : NetworkImage(avatarUrl),
                      child: avatarUrl == null
                          ? Icon(Icons.person, size: 35, color: c.iconInactive)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          nickname,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          bio.isEmpty ? '這個人很懶，什麼都沒留下' : bio,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8)),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => _openAndRefresh(const MemberLevelScreen()),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.workspace_premium_outlined, color: Colors.amber, size: 13),
                                SizedBox(width: 4),
                                Text(
                                  '會員等級',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          Text(
                            _stats.balance.toStringAsFixed(0),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.monetization_on_outlined, color: Colors.white, size: 20),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text('代幣', style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.8))),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions(AppColors c) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: AppCard(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _QuickAction(
              icon: Icons.monetization_on_outlined,
              label: '我的代幣',
              onTap: () => _openAndRefresh(const WalletScreen()),
            ),
            _QuickAction(
              icon: Icons.library_books_outlined,
              label: '書籍管理',
              badge: _stats.bookCount,
              onTap: () => _openAndRefresh(const BookManageScreen()),
            ),
            _QuickAction(
              icon: Icons.qr_code_2_rounded,
              label: '分享檔案',
              onTap: () => Navigator.push(
                context,
                PageRouteBuilder(
                  opaque: false,
                  barrierColor: Colors.transparent,
                  pageBuilder: (_, __, ___) => const ShareProfileScreen(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenu(AppColors c) {
    final isAdmin = ApiService.currentUser?.isAdmin == true;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            _MenuItem(
              icon: Icons.edit_outlined,
              title: '編輯個人檔案',
              onTap: () => _openAndRefresh(const EditProfileScreen()),
            ),
            _MenuItem(
              icon: Icons.bookmark_outline_rounded,
              title: '收藏書籍',
              trailingText: _stats.favoriteCount > 0 ? '${_stats.favoriteCount}' : null,
              onTap: () => _openAndRefresh(const FavoritesScreen()),
            ),
            _MenuItem(
              icon: Icons.shopping_bag_outlined,
              title: '購買紀錄',
              onTap: () => _openAndRefresh(const PurchaseHistoryScreen()),
            ),
            _MenuItem(
              icon: Icons.inventory_2_outlined,
              title: '銷售紀錄',
              onTap: () => _openAndRefresh(const SalesHistoryScreen()),
            ),
            _MenuItem(
              icon: Icons.key_outlined,
              title: '更改密碼',
              onTap: () => _openAndRefresh(const ChangePasswordScreen()),
            ),
            if (isAdmin)
              _MenuItem(
                icon: Icons.admin_panel_settings_outlined,
                title: '管理後台',
                onTap: () => _openAndRefresh(const AdminHomeScreen()),
              ),
            _MenuItem(
              icon: Icons.settings_outlined,
              title: '設定',
              isLast: true,
              onTap: () => _openAndRefresh(const SettingsScreen()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton(AppColors c) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: AppCard(
        padding: const EdgeInsets.symmetric(vertical: 20),
        onTap: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: c.card,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('確認登出', style: TextStyle(fontWeight: FontWeight.bold, color: c.textPrimary)),
              content: Text('確定要登出帳號嗎？', style: TextStyle(color: c.textSecondary)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('取消', style: TextStyle(color: Colors.grey)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('登出', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
          if (confirmed == true) _handleLogout();
        },
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout, color: Colors.red, size: 20),
            SizedBox(width: 8),
            Text('登出', style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final int badge;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 22, color: AppColors.primary),
              ),
              if (badge > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$badge',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 12, color: c.textPrimary)),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? trailingText;
  final bool isLast;
  final VoidCallback? onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    this.trailingText,
    this.isLast = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      children: [
        ListTile(
          leading: Icon(icon, color: c.iconInactive),
          title: Text(
            title,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: c.textPrimary),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (trailingText != null)
                Text(trailingText!, style: TextStyle(color: c.textSecondary, fontSize: 14)),
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
