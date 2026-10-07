import 'package:flutter/material.dart';
import '../../models/chat.dart';
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
import '../home/home_screen.dart';
import '../../services/app_permissions.dart';
import '../../widgets/app_side_nav.dart';
import '../../widgets/guards.dart';
import '../../widgets/master_detail.dart';
import 'account_privacy_screen.dart';
import 'app_permissions_screen.dart';
import 'tablet_list.dart';
import '../selling/book_manage_screen.dart';
import 'edit_profile_screen.dart';
import 'help_center_screen.dart';
import '../books/favorites_screen.dart';
import '../auth/login_screen.dart';
import 'member_level_screen.dart';
import '../orders/my_reservations_screen.dart';
import '../orders/order_history_screen.dart';
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
  int _heldReservations = 0;
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
      _api.fetchOrderCount(role: OrderRole.buyer.name, tab: OrderHistoryScreen.actionFilterOf(OrderRole.buyer)),
      _api.fetchOrderCount(role: OrderRole.seller.name, tab: OrderHistoryScreen.actionFilterOf(OrderRole.seller)),
      _api.fetchMyReservations(),
    ]);
    if (!mounted) return;
    setState(() {
      _stats = results[0] as UserStats;
      _level = results[2] as MemberLevelInfo;
      _pendingPickup = results[3] as int;
      _pendingDeposit = results[4] as int;
      final now = DateTime.now();
      _heldReservations = (results[5] as List<ChatReservation>).where((r) => isHeldReservation(r, now)).length;
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
    if (context.isWide) return _buildTablet(c);
    final user = ApiService.currentUser;

    return Scaffold(
      backgroundColor: c.scaffold,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final padding = responsiveListPadding(
            constraints,
            maxWidth: Breakpoints.formMaxWidth,
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
                    children: [
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

  static const _profileId = 'profile';
  final _editDirty = ValueNotifier<bool>(false);
  bool _defaultScheduled = false;

  @override
  void dispose() {
    _editDirty.dispose();
    super.dispose();
  }

  Widget _editProfilePage() => EditProfileScreen(
        dirty: _editDirty,
        onSaved: () {
          if (mounted) setState(() {});
        },
      );

  /// 平板：左欄為帳戶清單，右欄顯示選取的頁面；直向寬度不足並排時點選改為推入新頁面。
  Widget _buildTablet(AppColors c) {
    return Material(
      color: c.scaffold,
      child: MasterDetail(
        masterWidth: 360,
        placeholderIcon: Icons.person_outline_rounded,
        master: Builder(builder: (context) => _buildTabletMaster(context, c)),
      ),
    );
  }

  Future<void> _openDetail(BuildContext context, Object id, Widget page) async {
    if (!MasterDetail.isSplit(context)) {
      await _openAndRefresh(page);
      return;
    }
    final current = MasterDetail.selectedId(context);
    if (current == id) return;
    if (current == _profileId && _editDirty.value && !await UnsavedGuard.confirm(context)) return;
    _editDirty.value = false;
    if (!context.mounted) return;
    await MasterDetail.open<void>(context, page, id: id);
    if (mounted) _loadStats();
  }

  // 並排時右欄預設顯示個人資料（第一項）；內容頁自行關閉或旋轉後恢復並排時也一樣
  void _scheduleDefaultDetail(BuildContext context) {
    if (_defaultScheduled) return;
    _defaultScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _defaultScheduled = false;
      if (!mounted || !context.mounted) return;
      if (MasterDetail.isSplit(context) && MasterDetail.selectedId(context) == null) {
        _openDetail(context, _profileId, _editProfilePage());
      }
    });
  }

  /// 側邊欄已有的頁面：切換到該分頁；不在平板外框內時推入新頁面。
  void _openTab(int tab, Widget fallback) {
    if (!HomeScreen.showTab(tab)) _openAndRefresh(fallback);
  }

  // 平板切換到側邊欄的訂單紀錄分頁並套用篩選，不在會員中心分頁內另開一份；手機推入新頁面
  Future<void> _openOrders(OrderRole role, [String? filter]) async {
    await OrderHistoryScreen.open(context, role: role, filter: filter);
    if (mounted) _loadStats();
  }

  // 管理後台有自己的側邊欄，平板以全螢幕開啟、蓋住 App 的側邊欄
  void _openAdmin() {
    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(builder: (_) => const AdminHomeScreen()));
  }

  Widget _buildTabletMaster(BuildContext context, AppColors c) {
    final selected = MasterDetail.selectedId(context);
    if (MasterDetail.isSplit(context) && selected == null) _scheduleDefaultDetail(context);
    final isAdmin = ApiService.currentUser?.isAdmin == true;
    // 直向的側邊欄為圖示列，沒有列出訂單紀錄、收藏、書籍管理與設定，由帳戶頁提供捷徑（切換到該分頁，不另開一份）
    final railOnly = context.screenSize != ScreenSize.expanded;

    Widget detail(String id, IconData icon, String title, Widget Function() page, {String? value}) => TabletListRow(
          icon: icon,
          title: title,
          value: value,
          selected: selected == id,
          onTap: () => _openDetail(context, id, page()),
        );

    return TabletMasterColumn(
      title: S.myAccount,
      maxWidth: Breakpoints.formMaxWidth,
      onRefresh: _refresh,
      actions: [
        HeaderIconButton(
          key: const ValueKey('profile_qr_code'),
          icon: Icons.qr_code_2_rounded,
          tooltip: S.myQrCode,
          onTap: _openShareProfile,
        ),
      ],
      children: [
        _buildTabletIdentity(context, c, selected == _profileId),
        TabletListGroup(
          children: [
            _buildTabletLevelRow(context, c, selected == 'level'),
            TabletListRow(
              icon: Icons.monetization_on_outlined,
              title: S.coins,
              value: AnimatedCount.group(_stats.balance.toStringAsFixed(0)),
              onTap: () => _openTab(AppSideNav.coinsTab, const WalletScreen()),
            ),
          ],
        ),
        TabletListGroup(
          header: S.faqCatTrade,
          children: [
            if (railOnly)
              TabletListRow(icon: Icons.receipt_long_outlined, title: S.orderHistory, onTap: () => _openOrders(OrderRole.buyer)),
            TabletListRow(
              icon: Icons.shopping_bag_outlined,
              title: S.pickUp,
              badge: _pendingPickup,
              onTap: () => _openOrders(OrderRole.buyer, OrderHistoryScreen.awaitingPickup),
            ),
            TabletListRow(
              icon: Icons.move_to_inbox_outlined,
              title: S.orderPendingDeposit,
              badge: _pendingDeposit,
              onTap: () => _openOrders(OrderRole.seller, OrderHistoryScreen.awaitingDeposit),
            ),
            TabletListRow(
              icon: Icons.event_available_outlined,
              title: S.myReservations,
              badge: _heldReservations,
              onTap: () => _openTab(AppSideNav.reservationsTab, const MyReservationsScreen()),
            ),
            if (railOnly) ...[
              TabletListRow(
                icon: Icons.bookmark_outline_rounded,
                title: S.saved,
                value: _stats.favoriteCount > 0 ? '${_stats.favoriteCount}' : null,
                onTap: () => _openTab(AppSideNav.savedTab, const FavoritesScreen()),
              ),
              TabletListRow(icon: Icons.library_books_outlined, title: S.myBooks, onTap: () => _openTab(AppSideNav.myBooksTab, const BookManageScreen())),
            ],
          ],
        ),
        TabletListGroup(
          header: S.faqCatAccount,
          children: [
            detail('security', Icons.verified_user_outlined, S.accountSecurity, () => const SecurityCenterScreen()),
            detail('privacy', Icons.manage_accounts_outlined, S.account, () => const AccountPrivacyScreen()),
            if (AppPermissions.isSupportedPlatform)
              detail('permissions', Icons.app_settings_alt_outlined, S.appPermissions, () => const AppPermissionsScreen()),
          ],
        ),
        TabletListGroup(
          children: [
            detail('help', Icons.support_agent_rounded, S.helpCentre2, () => const HelpCenterScreen()),
            if (railOnly) TabletListRow(icon: Icons.settings_outlined, title: S.settings, onTap: () => _openTab(AppSideNav.settingsTab, const SettingsScreen())),
            if (isAdmin)
              TabletListRow(
                icon: Icons.admin_panel_settings_outlined,
                title: S.admin,
                trailing: Icon(Icons.open_in_new_rounded, size: 18, color: c.iconInactive),
                onTap: _openAdmin,
              ),
          ],
        ),
        TabletListGroup(
          children: [
            TabletListRow(title: S.signOut, color: c.danger, centered: true, chevron: false, onTap: _confirmLogout),
          ],
        ),
      ],
    );
  }

  Widget _buildTabletIdentity(BuildContext context, AppColors c, bool selected) {
    final user = ApiService.currentUser;
    final detail = [user?.bio, user?.email].firstWhere((s) => s != null && s.trim().isNotEmpty, orElse: () => null);

    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Material(
        color: selected ? Color.alphaBlend(c.accent.withValues(alpha: c.isDark ? 0.22 : 0.12), c.card) : c.card,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const ValueKey('profile_edit_area'),
          onTap: () => _openDetail(context, _profileId, _editProfilePage()),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
            child: Row(
              children: [
                UserAvatar(imageUrl: user?.avatarUrl, radius: 30),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        user?.nickname ?? S.user,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: selected ? c.accent : c.textPrimary),
                      ),
                      if (detail != null) ...[
                        const SizedBox(height: 2),
                        Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: c.textSecondary)),
                      ],
                      const SizedBox(height: 4),
                      Text(S.editProfile, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: c.textHint)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 22, color: c.iconInactive),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabletLevelRow(BuildContext context, AppColors c, bool selected) {
    final level = _level.currentLevel;
    final style = LevelStyle.at(levelIndexOf(_level, level));
    final hasLevels = _level.levels.isNotEmpty;
    final progress = LevelProgress.from(_level);

    return TabletListRow(
      leading: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(shape: BoxShape.circle, color: style.accent),
        child: Icon(style.icon, size: 14, color: Colors.white),
      ),
      title: S.membershipTier,
      value: level?.levelName ?? AppLabels.noLevel,
      selected: selected,
      subtitle: !hasLevels
          ? null
          : progress.isMax
              ? S.topTierReached
              : S.morePointsReach(progress.remaining, _level.nextLevel?.levelName ?? ''),
      bottom: !hasLevels
          ? null
          : ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: TweenAnimationBuilder<double>(
                key: ValueKey(_levelAnimationKey),
                tween: Tween(begin: 0, end: progress.ratio.clamp(0.0, 1.0)),
                duration: Motion.count,
                curve: Motion.emphasized,
                builder: (_, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 6,
                  color: style.accent,
                  backgroundColor: c.inputFill,
                ),
              ),
            ),
      onTap: () => _openDetail(context, 'level', const MemberLevelScreen()),
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
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: double.infinity, minHeight: 32),
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
              LayoutBuilder(
                builder: (context, constraints) {
                  final identity = Semantics(
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
                                  maxLines: _enlargedTextLines,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                if (bio.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    bio,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8)),
                                  ),
                                ],
                                const SizedBox(height: 7),
                                _buildLevelBadge(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                  final wallet = _buildWalletPill(constraints.maxWidth);
                  if (_walletFitsBeside(context, constraints.maxWidth)) {
                    return Row(
                      children: [
                        Expanded(child: identity),
                        const SizedBox(width: 8),
                        wallet,
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [identity, const SizedBox(height: 12), wallet],
                  );
                },
              ),
              _buildLevelProgress(),
            ],
          ),
        ),
      ),
      ),
    );
  }

  int get _enlargedTextLines => MediaQuery.textScalerOf(context).scale(1) > 1 ? 2 : 1;

  static const _balanceStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: Colors.white,
    height: 1,
    leadingDistribution: TextLeadingDistribution.even,
  );

  bool _walletFitsBeside(BuildContext context, double width) {
    final scaler = MediaQuery.textScalerOf(context);
    final painter = TextPainter(
      text: TextSpan(
        text: AnimatedCount.group(_stats.balance.toStringAsFixed(0)),
        style: DefaultTextStyle.of(context).style.merge(_balanceStyle),
      ),
      textDirection: Directionality.of(context),
      locale: Localizations.maybeLocaleOf(context),
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final walletWidth = painter.width + 10 + 20 + 6 + 14 + 2;
    painter.dispose();
    final identityMinWidth = 32 * 2 + 14 + scaler.scale(19) * 4;
    return width - 8 - walletWidth >= identityMinWidth;
  }

  Widget _buildWalletPill(double maxWidth) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: PressableScale(
        onTap: () => _openAndRefresh(const WalletScreen()),
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
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
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: AnimatedCount(value: _stats.balance, thousands: true, style: _balanceStyle),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLevelBadge() {
    return PressableScale(
      onTap: () => _openAndRefresh(const MemberLevelScreen()),
      child: _levelChip(),
    );
  }

  Widget _levelChip() {
    final level = _level.currentLevel;
    final style = LevelStyle.at(levelIndexOf(_level, level));

    return AnimatedContainer(
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
                    maxLines: _enlargedTextLines,
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
    final actions = [
      QuickActionButton(
        icon: Icons.shopping_bag_outlined,
        label: S.pickUp,
        badge: _pendingPickup,
        badgeColor: c.danger,
        onTap: () => _openOrders(OrderRole.buyer, OrderHistoryScreen.awaitingPickup),
      ),
      QuickActionButton(
        icon: Icons.move_to_inbox_outlined,
        label: S.orderPendingDeposit,
        badge: _pendingDeposit,
        badgeColor: c.danger,
        onTap: () => _openOrders(OrderRole.seller, OrderHistoryScreen.awaitingDeposit),
      ),
      QuickActionButton(
        icon: Icons.bookmark_outline_rounded,
        label: S.saved,
        badge: _stats.favoriteCount,
        onTap: () => _openAndRefresh(const FavoritesScreen()),
      ),
      QuickActionButton(
        icon: Icons.event_available_outlined,
        label: S.myReservations,
        badge: _heldReservations,
        badgeColor: c.danger,
        onTap: () => _openAndRefresh(const MyReservationsScreen()),
      ),
    ];

    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final labels = actions.map((a) => a.label);
          final columns = [actions.length, 2].firstWhere(
            (n) => QuickActionButton.labelsFit(context, labels, constraints.maxWidth / n),
            orElse: () => 1,
          );
          Widget row(Iterable<QuickActionButton> items) => Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [for (final item in items) Expanded(child: item)],
              );
          if (columns == actions.length) return row(actions);
          return Column(
            children: [
              for (var i = 0; i < actions.length; i += columns) ...[
                if (i > 0) const SizedBox(height: 14),
                row(actions.skip(i).take(columns)),
              ],
            ],
          );
        },
      ),
    );
  }

  List<Widget> _tradeMenuItems() => [
        AppMenuItem(
          icon: Icons.receipt_long_outlined,
          title: S.orderHistory,
          onTap: () => _openOrders(OrderRole.buyer),
        ),
        AppMenuItem(
          icon: Icons.library_books_outlined,
          title: S.myBooks,
          isLast: true,
          onTap: () => _openAndRefresh(const BookManageScreen()),
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

  Future<void> _confirmLogout() async {
    final confirmed = await showConfirmDialog(
      context,
      title: S.signOut2,
      confirmLabel: S.signOut,
      isDestructive: true,
    );
    if (confirmed) _handleLogout();
  }

  Widget _buildLogoutButton(AppColors c) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 15),
      onTap: _confirmLogout,
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
