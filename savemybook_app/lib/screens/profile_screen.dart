import 'package:flutter/material.dart';
import '../models/member_level.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../utils/level_style.dart';
import '../widgets/app_header.dart';
import '../widgets/animations.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/app_tiles.dart';
import '../widgets/state_views.dart';
import 'admin/admin_home_screen.dart';
import 'book_manage_screen.dart';
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
  MemberLevelInfo _level = MemberLevelInfo.empty;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final results = await Future.wait([_api.fetchUserStats(), _api.fetchMemberLevel()]);
    if (!mounted) return;
    setState(() {
      _stats = results[0] as UserStats;
      _level = results[1] as MemberLevelInfo;
    });
  }

  Future<void> _handleLogout() async {
    await runBusy(
      context,
      () async {
        await _api.logout();
        return true;
      },
      message: '登出中…',
    );
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
      body: Column(
        children: [
          _buildHeader(c, user?.nickname ?? '使用者', user?.bio ?? '', user?.avatarUrl),
          Expanded(
            child: RefreshIndicator(
              color: c.accent,
              onRefresh: _loadStats,
              child: ListView(
                padding: EdgeInsets.zero,
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 14),
                  _buildQuickActions(c),
                  const SizedBox(height: 14),
                  _buildMenu(c),
                  const SizedBox(height: 14),
                  _buildLogoutButton(c),
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 84),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(AppColors c, String nickname, String bio, String? avatarUrl) {
    return LightStatusBar(
      child: Container(
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
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 18),
          child: Column(
            children: [
              const Text(
                '會員中心',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  UserAvatar(
                    imageUrl: avatarUrl,
                    radius: 32,
                    background: Colors.white24,
                    enablePreview: true,
                    previewTitle: nickname,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          nickname,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          bio.isEmpty ? '這個人很懶，什麼都沒留下' : bio,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8)),
                        ),
                        const SizedBox(height: 7),
                        _buildLevelBadge(),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _openAndRefresh(const WalletScreen()),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 7, 14, 7),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.monetization_on_rounded, color: Colors.amber, size: 20),
                          const SizedBox(width: 6),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedCount(
                                value: _stats.balance,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  height: 1.1,
                                ),
                              ),
                              Text(
                                '代幣',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.white.withValues(alpha: 0.75),
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              _buildLevelProgress(),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildLevelBadge() {
    final level = _level.currentLevel;
    final style = LevelStyle.at(levelIndexOf(_level, level));

    return GestureDetector(
      onTap: () => _openAndRefresh(const MemberLevelScreen()),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.fromLTRB(9, 4, 12, 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: style.gradient,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(style.icon, color: Colors.white, size: 14),
            const SizedBox(width: 5),
            Text(
              level?.levelName ?? '尚未評級',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelProgress() {
    if (_level.levels.isEmpty) return const SizedBox.shrink();

    final progress = LevelProgress.from(_level);
    final nextName = _level.nextLevel?.levelName;

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openAndRefresh(const MemberLevelScreen()),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    progress.isMax
                        ? '已達到最高級別'
                        : '再 ${progress.remaining} 點升級為「$nextName」',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${progress.percent}%',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress.ratio),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (_, value, _) => Stack(
                  children: [
                    Container(height: 8, color: Colors.white.withValues(alpha: 0.22)),
                    FractionallySizedBox(
                      widthFactor: value,
                      child: Container(
                        height: 8,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFFFFE082), Color(0xFFFFC107)],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(AppColors c) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: AppCard(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            QuickActionButton(
              icon: Icons.monetization_on_outlined,
              label: '我的代幣',
              onTap: () => _openAndRefresh(const WalletScreen()),
            ),
            QuickActionButton(
              icon: Icons.library_books_outlined,
              label: '書籍管理',
              badge: _stats.bookCount,
              onTap: () => _openAndRefresh(const BookManageScreen()),
            ),
            QuickActionButton(
              icon: Icons.qr_code_2_rounded,
              label: '分享檔案',
              onTap: () => Navigator.push(
                context,
                PageRouteBuilder(
                  opaque: false,
                  barrierColor: Colors.transparent,
                  pageBuilder: (_, _, _) => const ShareProfileScreen(),
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
            AppMenuItem(
              icon: Icons.edit_outlined,
              title: '編輯個人檔案',
              onTap: () => _openAndRefresh(const EditProfileScreen()),
            ),
            AppMenuItem(
              icon: Icons.bookmark_outline_rounded,
              title: '收藏書籍',
              trailingText: _stats.favoriteCount > 0 ? '${_stats.favoriteCount}' : null,
              onTap: () => _openAndRefresh(const FavoritesScreen()),
            ),
            AppMenuItem(
              icon: Icons.shopping_bag_outlined,
              title: '購買紀錄',
              onTap: () => _openAndRefresh(const PurchaseHistoryScreen()),
            ),
            AppMenuItem(
              icon: Icons.inventory_2_outlined,
              title: '銷售紀錄',
              onTap: () => _openAndRefresh(const SalesHistoryScreen()),
            ),
            if (isAdmin)
              AppMenuItem(
                icon: Icons.admin_panel_settings_outlined,
                title: '管理後台',
                onTap: () => _openAndRefresh(const AdminHomeScreen()),
              ),
            AppMenuItem(
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
        padding: const EdgeInsets.symmetric(vertical: 15),
        onTap: () async {
          final confirmed = await showConfirmDialog(
            context,
            title: '確認登出',
            message: '登出後需要重新輸入帳號密碼才能繼續使用。',
            confirmLabel: '登出',
            isDestructive: true,
          );
          if (confirmed) _handleLogout();
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout, color: c.danger, size: 20),
            const SizedBox(width: 8),
            Text('登出', style: TextStyle(color: c.danger, fontSize: 16, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
