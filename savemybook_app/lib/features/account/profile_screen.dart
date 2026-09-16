import 'package:flutter/material.dart';
import '../../models/member_level.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/level_style.dart';
import '../../widgets/app_header.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/app_tiles.dart';
import '../../widgets/responsive.dart';
import '../../widgets/state_views.dart';
import '../admin/admin_home_screen.dart';
import '../selling/book_manage_screen.dart';
import 'edit_profile_screen.dart';
import 'help_center_screen.dart';
import '../books/favorites_screen.dart';
import '../auth/login_screen.dart';
import 'member_level_screen.dart';
import '../orders/purchase_history_screen.dart';
import '../selling/sales_history_screen.dart';
import 'settings_screen.dart';
import 'share_profile_screen.dart';
import 'wallet_screen.dart';
import '../security/security_center_screen.dart';
import '../../utils/motion.dart';
import '../../utils/app_labels.dart';
import '../../i18n/strings.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService _api = ApiService();
  UserStats _stats = UserStats.empty;
  MemberLevelInfo _level = MemberLevelInfo.empty;
  int _pendingPickup = 0;
  int _pendingDeposit = 0;
  bool _signingOut = false;
  int _levelAnimationKey = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final results = await Future.wait([
      _api.fetchUserStats(),
      _api.fetchCurrentUser(),
      _api.fetchMemberLevel(),
      _api.fetchOrders(role: 'buyer', tab: 'pending_pickup'),
      _api.fetchOrders(role: 'seller', tab: 'pending_deposit'),
    ]);
    if (!mounted) return;
    setState(() {
      _stats = results[0] as UserStats;
      _level = results[2] as MemberLevelInfo;
      _pendingPickup = (results[3] as List).length;
      _pendingDeposit = (results[4] as List).length;
    });
  }

  Future<void> _refresh() async {
    setState(() => _levelAnimationKey++);
    await _loadStats();
  }

  Future<void> _handleLogout() async {
    if (_signingOut) return;
    _signingOut = true;
    await runBusy(
      context,
      () async {
        await _api.logout();
        return true;
      },
      message: S.signingOut,
    );
    _signingOut = false;
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  void _openShareProfile() {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        transitionDuration: Motion.base,
        reverseTransitionDuration: Motion.micro,
        pageBuilder: (_, _, _) => const ShareProfileScreen(),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
      ),
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          final twoColumn = context.screenSize == ScreenSize.expanded && constraints.maxWidth >= 840;
          final maxWidth = twoColumn ? Breakpoints.listMaxWidth : Breakpoints.formMaxWidth;
          final padding = responsiveListPadding(
            constraints,
            maxWidth: maxWidth,
            horizontal: 20,
            top: 14,
            bottom: floatingNavClearance(context, 84),
          );

          return Column(
            children: [
              _buildHeader(c, user?.nickname ?? S.user, user?.bio ?? '', user?.avatarUrl, padding.left),
              Expanded(
                child: RefreshIndicator(
                  color: c.accent,
                  onRefresh: _refresh,
                  child: ListView(
                    padding: padding,
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: twoColumn
                        ? [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    children: [
                                      FadeSlideIn(child: _buildQuickActions(c)),
                                      const SizedBox(height: 14),
                                      FadeSlideIn(index: 1, child: _buildMenuCard(_tradeMenuItems())),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    children: [
                                      FadeSlideIn(index: 1, child: _buildMenuCard(_accountMenuItems())),
                                      const SizedBox(height: 14),
                                      FadeSlideIn(index: 2, child: _buildLogoutButton(c)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ]
                        : [
                            FadeSlideIn(child: _buildQuickActions(c)),
                            const SizedBox(height: 14),
                            FadeSlideIn(index: 1, child: _buildMenuCard(_tradeMenuItems())),
                            const SizedBox(height: 14),
                            FadeSlideIn(index: 2, child: _buildMenuCard(_accountMenuItems())),
                            const SizedBox(height: 14),
                            FadeSlideIn(index: 3, child: _buildLogoutButton(c)),
                          ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(AppColors c, String nickname, String bio, String? avatarUrl, double sidePadding) {
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
          padding: EdgeInsets.fromLTRB(sidePadding, 6, sidePadding, 18),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: 32,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 44),
                      child: Text(
                        S.myAccount,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    Positioned(
                      right: -8,
                      top: -8,
                      bottom: -8,
                      child: IconButton(
                        key: const ValueKey('profile_qr_code'),
                        tooltip: S.myQrCode,
                        icon: const Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 24),
                        onPressed: _openShareProfile,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      button: true,
                      label: S.editProfile,
                      child: GestureDetector(
                        key: const ValueKey('profile_edit_area'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _openAndRefresh(const EditProfileScreen()),
                        child: Row(
                          children: [
                            UserAvatar(
                              imageUrl: avatarUrl,
                              radius: 32,
                              background: Colors.white24,
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
                                    bio.isEmpty ? S.personNotWrittenBioYet : bio,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8)),
                                  ),
                                  const SizedBox(height: 7),
                                  _buildLevelBadge(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PressableScale(
                    onTap: () => _openAndRefresh(const WalletScreen()),
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.fromLTRB(10, 0, 14, 0),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
                      ),
                      child: Semantics(
                        label: S.faqCatWallet,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Icon(Icons.monetization_on_rounded, color: Colors.amber, size: 20),
                            const SizedBox(width: 6),
                            AnimatedCount(
                              value: _stats.balance,
                              thousands: true,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                height: 1,
                                leadingDistribution: TextLeadingDistribution.even,
                              ),
                            ),
                          ],
                        ),
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

    return PressableScale(
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
            Flexible(
              child: Text(
                level?.levelName ?? AppLabels.noLevel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                ),
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
                        ? S.topTierReached
                        : S.morePointsReach(progress.remaining, nextName ?? ''),
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
                Icon(Icons.chevron_right_rounded,
                    size: 16, color: Colors.white.withValues(alpha: 0.75)),
              ],
            ),
            const SizedBox(height: 7),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: TweenAnimationBuilder<double>(
                key: ValueKey(_levelAnimationKey),
                tween: Tween(begin: 0, end: progress.ratio.clamp(0.0, 1.0)),
                duration: Motion.count,
                curve: Motion.emphasized,
                builder: (_, value, _) => Stack(
                  children: [
                    Container(height: 8, color: Colors.white.withValues(alpha: 0.22)),
                    FractionallySizedBox(
                      widthFactor: value,
                      alignment: Alignment.centerLeft,
                      child: Container(
                        height: 8,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: AppColors.valueGradient,
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
    Widget item(IconData icon, String label, int badge, Widget screen, {Color? badgeColor}) {
      return Expanded(
        child: QuickActionButton(
          icon: icon,
          label: label,
          badge: badge,
          badgeColor: badgeColor,
          onTap: () => _openAndRefresh(screen),
        ),
      );
    }

    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          item(Icons.shopping_bag_outlined, S.pickUp, _pendingPickup, const PurchaseHistoryScreen(), badgeColor: c.danger),
          item(
            Icons.move_to_inbox_outlined,
            S.orderPendingDeposit,
            _pendingDeposit,
            const SalesHistoryScreen(initialTab: 'pending_deposit'),
            badgeColor: c.danger,
          ),
          item(Icons.bookmark_outline_rounded, S.saved, _stats.favoriteCount, const FavoritesScreen()),
          item(Icons.library_books_outlined, S.myBooks, 0, const BookManageScreen()),
        ],
      ),
    );
  }

  List<Widget> _tradeMenuItems() => [
        AppMenuItem(
          icon: Icons.shopping_bag_outlined,
          title: S.purchases,
          onTap: () => _openAndRefresh(const PurchaseHistoryScreen()),
        ),
        AppMenuItem(
          icon: Icons.inventory_2_outlined,
          title: S.sales,
          isLast: true,
          onTap: () => _openAndRefresh(const SalesHistoryScreen()),
        ),
      ];

  List<Widget> _accountMenuItems() {
    final isAdmin = ApiService.currentUser?.isAdmin == true;

    return [
      AppMenuItem(
        icon: Icons.verified_user_outlined,
        title: S.accountSecurity,
        onTap: () => _openAndRefresh(const SecurityCenterScreen()),
      ),
      AppMenuItem(
        icon: Icons.support_agent_rounded,
        title: S.helpCentre2,
        onTap: () => _openAndRefresh(const HelpCenterScreen()),
      ),
      if (isAdmin)
        AppMenuItem(
          icon: Icons.admin_panel_settings_outlined,
          title: S.admin,
          onTap: () => _openAndRefresh(const AdminHomeScreen()),
        ),
      AppMenuItem(
        icon: Icons.settings_outlined,
        title: S.settings,
        isLast: true,
        onTap: () => _openAndRefresh(const SettingsScreen()),
      ),
    ];
  }

  Widget _buildMenuCard(List<Widget> items) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(children: items),
    );
  }

  Widget _buildLogoutButton(AppColors c) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 15),
      onTap: () async {
        final confirmed = await showConfirmDialog(
          context,
          title: S.signOut2,
          confirmLabel: S.signOut,
          isDestructive: true,
        );
        if (confirmed) _handleLogout();
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.logout, color: c.danger, size: 20),
          const SizedBox(width: 8),
          Text(S.signOut, style: TextStyle(color: c.danger, fontSize: 16, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
