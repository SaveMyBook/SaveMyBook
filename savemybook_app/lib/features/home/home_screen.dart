import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../orders/cart_screen.dart';
import '../chat/chat_list_screen.dart';
import 'home_discovery.dart';
import 'notification_screen.dart';
import '../account/profile_screen.dart';
import '../selling/sell_book_screen.dart';
import '../orders/pickup_book_screen.dart';
import '../orders/order_history_screen.dart';
import '../orders/my_reservations_screen.dart';
import '../books/favorites_screen.dart';
import '../selling/book_manage_screen.dart';
import '../account/wallet_screen.dart';
import '../account/settings_screen.dart';
import 'search_screen.dart';
import '../../models/category.dart';
import '../../models/ai.dart';
import '../../models/book.dart';
import '../../services/ai_status.dart';
import '../../services/api_service.dart';
import '../../services/home_preferences.dart';
import '../../services/home_widget_service.dart';
import '../../services/server_compat.dart';
import '../../widgets/adaptive_sheet.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/app_select.dart';
import '../../services/push_service.dart';
import '../../services/realtime_service.dart';
import '../../services/recently_viewed.dart';
import '../../services/search_history.dart';
import '../auth/legal_consent_screen.dart';
import '../../utils/app_colors.dart';
import '../../utils/motion.dart';
import '../../widgets/app_header.dart';
import '../../widgets/animations.dart';
import '../../widgets/book_card.dart';
import '../../widgets/buyer/back_to_top_button.dart';
import '../../widgets/buyer/book_strip.dart';
import '../../widgets/buyer/undo_snackbar.dart';
import '../../widgets/custom_bottom_nav.dart';
import '../../widgets/app_side_nav.dart';
import '../../widgets/responsive.dart';
import '../../widgets/search_bar_widget.dart';
import '../../widgets/state_views.dart';
import '../../i18n/strings.dart';

class HomeScreen extends StatefulWidget {
  final String initialKeyword;
  const HomeScreen({super.key, this.initialKeyword = ''});

  static NavigatorState? get tabNavigator => _HomeScreenState._active?._visibleTabNavigator();

  static bool showNotifications() => _HomeScreenState._active?._showTab(_alertsTab) ?? false;
  /// 平板：切換到側邊欄的分頁（[AppSideNav] 的分頁編號）並回到該分頁的第一頁；手機或首頁不在最上層時回傳 false。
  static bool showTab(int index) => _HomeScreenState._active?._showTab(index) ?? false;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

const int _alertsTab = 1;
const int _phoneTabCount = 5;

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const int _pageSize = 20;
  static _HomeScreenState? _active;

  int _selectedIndex = 0;
  bool _sideNav = false;
  final List<_TabSlot> _tabs = List.generate(AppSideNav.tabCount, (_) => _TabSlot());
  bool _sidebarOverlay = false;
  final Set<int> _openedTabs = {0, 1, 2, 3, 4};
  // 其他分頁會改動內容的分頁（購物車、代幣、收藏、預約）：從別的分頁切回且停在第一頁時重新建立以取得最新資料
  static const _reloadOnEnter = {
    AppSideNav.cartTab,
    AppSideNav.coinsTab,
    AppSideNav.savedTab,
    AppSideNav.reservationsTab,
  };
  final Map<int, int> _generations = {};
  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  int _currentPage = 1;
  int _requestId = 0;
  final Set<int> _selectedCategoryIds = {};
  late String _currentKeyword = widget.initialKeyword;
  late String _currentSort = widget.initialKeyword.isEmpty ? 'newest' : 'relevance';

  List<({String code, String label})> get _sortOptions => [
        if (_currentKeyword.isNotEmpty) (code: 'relevance', label: S.mostRelevant),
        (code: 'newest', label: S.newest),
        (code: 'popular', label: S.popular),
        (code: 'price_asc', label: S.priceLowHigh),
        (code: 'price_desc', label: S.priceHighLow),
      ];

  String get _currentSortLabel =>
      _sortOptions.firstWhere((o) => o.code == _currentSort, orElse: () => _sortOptions.first).label;

  List<Category> _categories = [];
  List<Book> _books = [];
  List<RecommendationGroup> _recommendGroups = const [];
  // 標示不感興趣的書在畫面上隱藏；伺服器在復原期限結束後才得知，期間重新讀取的推薦仍可能含這本書。
  final Set<int> _hiddenRecommendations = {};

  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _categoryScrollController = ScrollController();
  final ValueNotifier<double> _categoryScrollProgress = ValueNotifier<double>(0);
  final GlobalKey<RefreshIndicatorState> _refreshKey = GlobalKey<RefreshIndicatorState>();
  bool _isGridView = true;

  Timer? _badgeTimer;
  Timer? _chatBadgeDebounce;
  Timer? _recommendRefresh;
  int _recommendRefreshes = 0;
  StreamSubscription<int>? _roomChanges;

  bool get _isBrowsingAll => _currentKeyword.isEmpty && _selectedCategoryIds.isEmpty;

  @override
  void initState() {
    super.initState();
    _active = this;
    WidgetsBinding.instance.addObserver(this);
    kBottomNavVisible = true;
    ToastRouteTracker.notifyNavVisibility();
    _badgeTimer = Timer.periodic(const Duration(seconds: 20), (_) => _loadBadges());
    PushService.onSignedIn();
    RealtimeService.instance.start();
    _roomChanges = RealtimeService.instance.roomChanges.listen((_) => _scheduleChatBadge());
    RecentlyViewed.load();
    SearchHistory.load();
    HomePreferences.showDiscovery.addListener(_onDiscoveryPreferenceChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) LegalConsentGate.check(context);
      if (mounted) ServerCompat.check(context);
    });
    _loadInitialData();
    _scrollController.addListener(_onScroll);
    _categoryScrollController.addListener(_onCategoryScroll);
  }

  @override
  void dispose() {
    if (_active == this) _active = null;
    for (final tab in _tabs) {
      tab.dispose();
    }
    kBottomNavVisible = false;
    ToastRouteTracker.notifyNavVisibility();
    _badgeTimer?.cancel();
    _chatBadgeDebounce?.cancel();
    _recommendRefresh?.cancel();
    _roomChanges?.cancel();
    HomePreferences.showDiscovery.removeListener(_onDiscoveryPreferenceChanged);
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _categoryScrollController.dispose();
    _categoryScrollProgress.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      RealtimeService.instance.start();
      _loadBadges();
      AiStatus.refresh();
      LegalConsentGate.check(context);
    } else if (state == AppLifecycleState.paused) {
      RealtimeService.instance.stop();
      unawaited(HomeWidgetService.sync());
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 600) _loadMoreData();
  }

  void _onCategoryScroll() {
    if (!_categoryScrollController.hasClients) return;
    final maxScroll = _categoryScrollController.position.maxScrollExtent;
    _categoryScrollProgress.value =
        maxScroll > 0 ? (_categoryScrollController.offset / maxScroll).clamp(0.0, 1.0) : 0;
  }

  void _scheduleChatBadge() {
    _chatBadgeDebounce?.cancel();
    _chatBadgeDebounce = Timer(const Duration(milliseconds: 600), () {
      if (mounted) _apiService.fetchUnreadChatCount();
    });
  }

  Future<void> _loadBadges() {
    unawaited(HomeWidgetService.sync());
    return _apiService.refreshBadges();
  }

  Future<void> _loadInitialData() async {
    _loadBadges();
    _loadDiscovery();
    final categoriesFuture = _apiService.fetchCategories();
    await _reloadBooks(showSkeleton: true);
    final categories = await categoriesFuture;
    if (!mounted) return;
    setState(() => _categories = categories);
  }

  Future<void> _loadDiscovery() async {
    final statusFuture = AiStatus.refresh();
    if (!HomePreferences.showDiscovery.value) return;
    await RecentlyViewed.load();
    await RecentlyViewed.refresh();
    final status = await statusFuture;
    if (!mounted) return;
    final viewedIds = RecentlyViewed.books.value.map((b) => b.bookId);
    if (status.recommend && status.consented) {
      _recommendRefreshes = 0;
      final ai = await _apiService.fetchAiRecommendations(limit: 30, viewedIds: viewedIds);
      if (!mounted) return;
      _scheduleRecommendRefresh(ai?.refreshing ?? false);
      if (ai != null && ai.books.isNotEmpty) {
        setState(() => _recommendGroups = ai.groups);
        return;
      }
    }
    final recommended = await _apiService.fetchRecommendedBooks(viewedIds: viewedIds);
    if (!mounted) return;
    setState(() => _recommendGroups = [if (recommended.isNotEmpty) RecommendationGroup(kind: 'more', books: recommended)]);
  }

  // 伺服器在背景產生 AI 推薦時先回傳舊推薦或一般推薦；稍後重新讀取，第一次使用的人當次就能看到 AI 推薦。
  static const _recommendRefreshDelays = [Duration(seconds: 8), Duration(seconds: 20)];

  void _scheduleRecommendRefresh(bool refreshing) {
    _recommendRefresh?.cancel();
    if (!refreshing || _recommendRefreshes >= _recommendRefreshDelays.length) return;
    _recommendRefresh = Timer(_recommendRefreshDelays[_recommendRefreshes++], _refreshRecommendations);
  }

  Future<void> _refreshRecommendations() async {
    if (!mounted || !HomePreferences.showDiscovery.value) return;
    final viewedIds = RecentlyViewed.books.value.map((b) => b.bookId);
    final ai = await _apiService.fetchAiRecommendations(limit: 30, viewedIds: viewedIds);
    if (!mounted || ai == null) return;
    if (ai.books.isNotEmpty) setState(() => _recommendGroups = ai.groups);
    _scheduleRecommendRefresh(ai.refreshing);
  }

  void _onDiscoveryPreferenceChanged() {
    if (HomePreferences.showDiscovery.value && mounted) _loadDiscovery();
  }

  Future<void> _reloadBooks({bool showSkeleton = false}) async {
    final request = ++_requestId;
    if (showSkeleton) {
      setState(() {
        _isLoadingInitial = true;
        _isLoadingMore = false;
      });
    }
    final books = await _apiService.fetchBooks(
      page: 1,
      limit: _pageSize,
      categoryIds: _selectedCategoryIds,
      sort: _currentSort,
      keyword: _currentKeyword,
    );
    if (!mounted || request != _requestId) return;
    final seen = <int>{};
    setState(() {
      _books = books.where((b) => seen.add(b.bookId)).toList();
      _currentPage = 1;
      _hasMoreData = books.length >= _pageSize;
      _isLoadingInitial = false;
      _isLoadingMore = false;
    });
  }

  Future<void> _onRefresh() async {
    HapticFeedback.lightImpact();
    await Future.wait([
      _reloadBooks(),
      _loadDiscovery(),
      _loadBadges(),
      if (_categories.isEmpty)
        _apiService.fetchCategories().then((list) {
          if (mounted && list.isNotEmpty) setState(() => _categories = list);
        }),
    ]);
  }

  Future<void> _loadMoreData() async {
    if (_isLoadingMore || !_hasMoreData || _isLoadingInitial) return;
    final request = _requestId;
    final nextPage = _currentPage + 1;
    setState(() => _isLoadingMore = true);

    final more = await _apiService.fetchBooks(
      page: nextPage,
      limit: _pageSize,
      categoryIds: _selectedCategoryIds,
      sort: _currentSort,
      keyword: _currentKeyword,
    );
    if (!mounted || request != _requestId) return;

    setState(() {
      final seen = _books.map((b) => b.bookId).toSet();
      _books = [..._books, ...more.where((b) => seen.add(b.bookId))];
      if (more.isNotEmpty) _currentPage = nextPage;
      _hasMoreData = more.length >= _pageSize;
      _isLoadingMore = false;
    });
  }

  void _onCategoryTapped(int categoryId) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedCategoryIds.contains(categoryId)
          ? _selectedCategoryIds.remove(categoryId)
          : _selectedCategoryIds.add(categoryId);
    });
    _reloadBooks(showSkeleton: true);
  }

  void _clearFilters() {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedCategoryIds.clear();
      _currentKeyword = '';
      if (_currentSort == 'relevance') _currentSort = 'newest';
    });
    _reloadBooks(showSkeleton: true);
  }

  void _onSortChanged(String s) {
    if (s == _currentSort) return;
    HapticFeedback.selectionClick();
    setState(() => _currentSort = s);
    _reloadBooks(showSkeleton: true);
  }

  void _onSearchChanged(String k) {
    setState(() {
      if (k.isNotEmpty && _currentKeyword.isEmpty) _currentSort = 'relevance';
      if (k.isEmpty && _currentSort == 'relevance') _currentSort = 'newest';
      _currentKeyword = k;
    });
    _reloadBooks(showSkeleton: true);
    if (_scrollController.hasClients && _scrollController.offset > 0) {
      _scrollController.jumpTo(0);
    }
  }

  Future<void> _clearRecentlyViewed() async {
    final previous = RecentlyViewed.books.value;
    if (previous.isEmpty) return;
    await RecentlyViewed.clear();
    if (!mounted) return;
    final undo = await showUndoSnackBar(context, S.recentlyViewedCleared, icon: Icons.history_rounded);
    if (undo) await RecentlyViewed.restore(previous);
  }

  Future<void> _onRecommendationLongPress(Book book) async {
    if (ApiService.authToken == null) return;
    HapticFeedback.mediumImpact();
    final action = await showOptionSheet<String>(
      context,
      title: book.title,
      options: [SheetOption(value: 'dismiss', label: S.notInterested, icon: Icons.visibility_off_outlined)],
    );
    if (action != 'dismiss' || !mounted) return;
    await _dismissRecommendation(book);
  }

  Future<void> _dismissRecommendation(Book book) async {
    setState(() => _hiddenRecommendations.add(book.bookId));
    final undo = await showUndoSnackBar(context, S.bookNoLongerRecommended, icon: Icons.visibility_off_outlined);
    if (undo) {
      if (mounted) setState(() => _hiddenRecommendations.remove(book.bookId));
      return;
    }
    final error = await _apiService.dismissRecommendation(book.bookId);
    if (error == null || !mounted) return;
    setState(() => _hiddenRecommendations.remove(book.bookId));
    showAppSnackBar(context, error, isError: true);
  }

  void _onNavSelected(int i) {
    if (i == _selectedIndex) {
      final navigator = _sideNav ? _tabs[i].key.currentState : null;
      if (navigator != null && navigator.canPop()) {
        navigator.popUntil((route) => route.isFirst);
        return;
      }
      if (i == 0) _onHomeReselected();
      return;
    }
    setState(() {
      if (_reloadOnEnter.contains(i) && _openedTabs.contains(i) && !_tabs[i].canPop) {
        _generations[i] = (_generations[i] ?? 0) + 1;
      }
      _openedTabs.add(i);
      _selectedIndex = i;
    });
    _loadBadges();
  }

  NavigatorState? _visibleTabNavigator() {
    if (!mounted || !_sideNav || ModalRoute.isCurrentOf(context) == false) return null;
    return _tabs[_selectedIndex].key.currentState;
  }

  bool _showTab(int index) {
    if (_visibleTabNavigator() == null) return false;
    _onNavSelected(index);
    final navigator = _tabs[index].key.currentState;
    if (navigator != null && navigator.canPop()) navigator.popUntil((route) => route.isFirst);
    return true;
  }

  void _leaveTabRoot() {
    if (mounted && _selectedIndex != 0) _onNavSelected(0);
  }

  Future<void> _popCurrentTab() async {
    final navigator = _tabs[_selectedIndex].key.currentState;
    if (navigator is _TabNavigatorState && await navigator.systemBack()) return;
    if (!mounted) return;
    if (_selectedIndex != 0) {
      _onNavSelected(0);
    } else {
      await SystemNavigator.pop();
    }
  }

  void _onHomeReselected() {
    if (_scrollController.hasClients && _scrollController.offset > 8) {
      BackToTopButton.scrollToTop(_scrollController);
    } else {
      _refreshKey.currentState?.show();
    }
  }

  void _syncNavVisibility(bool floating) {
    if (kBottomNavVisible == floating) return;
    kBottomNavVisible = floating;
    WidgetsBinding.instance.addPostFrameCallback((_) => ToastRouteTracker.notifyNavVisibility());
  }

  @override
  Widget build(BuildContext context) {
    final bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final sideNav = context.usesSideNavigation;
    _syncNavVisibility(!sideNav);
    if (sideNav != _sideNav) {
      _sideNav = sideNav;
      for (final tab in _tabs) {
        tab.canPop = false;
      }
    }
    if (!sideNav && _selectedIndex >= _phoneTabCount) _selectedIndex = 0;

    final children = [
      _buildHomeContent(),
      const NotificationScreen(embedded: true),
      const SellBookScreen(),
      PickupBookScreen(isActive: _selectedIndex == 3),
      const ProfileScreen(),
    ];

    if (sideNav) return _buildSideNavShell(children);

    final pages = IndexedStack(index: _selectedIndex, children: children);

    return Scaffold(
      body: Stack(
        children: [
          pages,
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            left: 0,
            right: 0,
            bottom: isKeyboardOpen ? -120 : 0,
            child: CustomBottomNav(
              selectedIndex: _selectedIndex,
              isVisible: !isKeyboardOpen,
              onItemSelected: _onNavSelected,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSideNavShell(List<Widget> children) {
    final pages = [
      ...children,
      const ChatListScreen(),
      const CartScreen(),
      const OrderHistoryScreen(),
      const MyReservationsScreen(),
      const FavoritesScreen(),
      const BookManageScreen(),
      const WalletScreen(),
      const SettingsScreen(),
    ];
    for (final i in _reloadOnEnter) {
      pages[i] = KeyedSubtree(key: ValueKey(_generations[i] ?? 0), child: pages[i]);
    }
    final extended = context.screenSize == ScreenSize.expanded;
    if (extended) _sidebarOverlay = false;

    void selectFromOverlay(int index) {
      setState(() => _sidebarOverlay = false);
      _onNavSelected(index);
    }

    return PopScope(
      canPop: !_tabs[_selectedIndex].canPop && !_sidebarOverlay,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_sidebarOverlay) {
          setState(() => _sidebarOverlay = false);
        } else {
          _popCurrentTab();
        }
      },
      child: CallbackShortcuts(
        bindings: _shortcuts(),
        child: Focus(
          autofocus: true,
          child: Scaffold(
            body: Stack(
              children: [
                Row(
                  children: [
                    AppSideNav(
                      selectedIndex: _selectedIndex,
                      onItemSelected: _onNavSelected,
                      extended: extended,
                      onSearch: _openSearch,
                      onToggle: extended ? null : () => setState(() => _sidebarOverlay = true),
                    ),
                    Expanded(
                      child: MediaQuery.removePadding(
                        context: context,
                        removeLeft: true,
                        child: _TabPages(
                          pages: pages,
                          child: IndexedStack(
                            index: _selectedIndex,
                            children: [
                              // 隱藏的分頁仍在畫面樹中，最上層推入頁面時 Hero 會掃到它們，同一本書在兩個分頁會造成標籤重複
                              for (var i = 0; i < pages.length; i++)
                                _openedTabs.contains(i)
                                    ? HeroMode(enabled: i == _selectedIndex, child: _buildTabNavigator(i))
                                    : const SizedBox.shrink(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                // 直向時完整側邊欄以浮層展開，選取後收合；收合時不留在畫面樹中，避免螢幕閱讀器讀到隱藏的側邊欄
                if (!extended) ...[
                  Positioned.fill(
                    child: IgnorePointer(
                      ignoring: !_sidebarOverlay,
                      child: AnimatedOpacity(
                        duration: Motion.base,
                        opacity: _sidebarOverlay ? 1 : 0,
                        child: GestureDetector(
                          onTap: () => setState(() => _sidebarOverlay = false),
                          child: ColoredBox(color: AppColors.of(context).scrim),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    bottom: 0,
                    left: 0,
                    child: AnimatedSwitcher(
                      duration: Motion.base,
                      switchInCurve: Motion.standard,
                      switchOutCurve: Motion.standard,
                      transitionBuilder: (child, animation) => SlideTransition(
                        position: Tween(begin: const Offset(-1, 0), end: Offset.zero).animate(animation),
                        child: child,
                      ),
                      child: _sidebarOverlay
                          ? Material(
                              key: const ValueKey('sidebar-overlay'),
                              elevation: 16,
                              child: AppSideNav(
                                selectedIndex: _selectedIndex,
                                onItemSelected: selectFromOverlay,
                                extended: true,
                                onSearch: () {
                                  setState(() => _sidebarOverlay = false);
                                  _openSearch();
                                },
                                onToggle: () => setState(() => _sidebarOverlay = false),
                              ),
                            )
                          : const SizedBox.shrink(key: ValueKey('sidebar-closed')),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Map<ShortcutActivator, VoidCallback> _shortcuts() {
    final tabs = [
      AppSideNav.homeTab,
      AppSideNav.alertsTab,
      AppSideNav.chatTab,
      AppSideNav.cartTab,
      AppSideNav.ordersTab,
      AppSideNav.collectTab,
      AppSideNav.memberTab,
    ];
    const digits = [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit6,
      LogicalKeyboardKey.digit7,
    ];
    final bindings = <ShortcutActivator, VoidCallback>{};
    // iPad 的實體鍵盤用 Command，Android 平板用 Ctrl
    for (final meta in [true, false]) {
      SingleActivator key(LogicalKeyboardKey k) => SingleActivator(k, meta: meta, control: !meta);
      for (var i = 0; i < tabs.length; i++) {
        bindings[key(digits[i])] = () => _showTab(tabs[i]);
      }
      bindings[key(LogicalKeyboardKey.keyF)] = _openSearch;
      bindings[key(LogicalKeyboardKey.keyN)] = () => _showTab(AppSideNav.sellTab);
    }
    return bindings;
  }

  Future<void> _openSearch() async {
    if (!_showTab(AppSideNav.homeTab)) return;
    final navigator = _tabs[AppSideNav.homeTab].key.currentState;
    if (navigator == null) return;
    final result = await navigator.push<String>(
      MaterialPageRoute(builder: (_) => SearchScreen(initialKeyword: _currentKeyword)),
    );
    if (result != null && mounted) _onSearchChanged(result);
  }

  Widget _buildTabNavigator(int index) {
    final tab = _tabs[index];
    return NotificationListener<NavigationNotification>(
      onNotification: (notification) {
        if (tab.canPop != notification.canHandlePop) {
          tab.canPop = notification.canHandlePop;
          if (index == _selectedIndex && mounted) setState(() {});
        }
        return true;
      },
      child: HeroControllerScope(
        controller: tab.heroController,
        child: tab.navigator ??= _TabNavigator(
          key: tab.key,
          routes: tab.routes,
          onLeaveRoot: _leaveTabRoot,
          rootBuilder: (_) => _TabRoot(index: index),
        ),
      ),
    );
  }

  double get _inset => context.isWide ? 24 : 16;

  Widget _buildHomeContent() {
    final c = AppColors.of(context);
    final wide = context.isWide;

    return Column(
      children: [
        _buildCustomHeader(),
        Expanded(
          child: Stack(
            children: [
              RefreshIndicator(
                key: _refreshKey,
                color: c.accent,
                onRefresh: _onRefresh,
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),
                    if (wide)
                      SliverToBoxAdapter(child: _buildCategoryWrap(c))
                    else ...[
                      SliverToBoxAdapter(child: _buildCategories()),
                      SliverToBoxAdapter(child: _categoryProgressBar(c)),
                    ],
                    SliverToBoxAdapter(child: _buildDiscoverySections()),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(_inset, wide ? 28 : 24, _inset, wide ? 14 : 12),
                        child: wide ? _buildWideSortRow(c) : _buildSortAndLayoutRow(),
                      ),
                    ),
                    _buildBookSliver(c),
                    SliverToBoxAdapter(
                      child: Reveal(
                        visible: _isLoadingMore,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24.0),
                          child: Center(child: CircularProgressIndicator(color: c.accent)),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(child: SizedBox(height: floatingNavClearance(context, 100))),
                  ],
                ),
              ),
              Positioned(
                right: _inset,
                bottom: floatingNavClearance(context, 76),
                child: BackToTopButton(controller: _scrollController),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCustomHeader() {
    final c = AppColors.of(context);
    final userName = ApiService.currentUser?.nickname ?? S.guest;
    final greeting = Text(
      S.hi(userName),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
    );
    final searchBar = SearchBarWidget(currentKeyword: _currentKeyword, onSearch: _onSearchChanged);

    // 直向時側邊欄收成圖示列、沒有搜尋框，平板頁首要保留搜尋框
    if (context.isWide) {
      return LayoutBuilder(
        builder: (context, constraints) => TabletToolbar(
          titleWidget: Text(
            S.hi(userName),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c.textPrimary),
          ),
          actions: [
            SizedBox(width: (constraints.maxWidth * 0.4).clamp(260.0, 400.0), child: searchBar),
            const SizedBox(width: 12),
          ],
        ),
      );
    }

    return LightStatusBar(
      child: Container(
        decoration: BoxDecoration(
          color: c.headerBg,
          borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.only(top: 8.0, bottom: 20.0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(children: [
                  Expanded(child: greeting),
                  const SizedBox(width: 8),
                  CartIconButton(
                    size: 26,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen()))
                        .then((_) => _loadBadges()),
                  ),
                  ChatIconButton(
                    size: 24,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ChatListScreen()),
                    ).then((_) => _loadBadges()),
                  ),
                ]),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: Breakpoints.readingMaxWidth),
                  child: searchBar,
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildCategories() {
    final c = AppColors.of(context);
    final hasFilter = _selectedCategoryIds.isNotEmpty;

    if (_categories.isEmpty) {
      return SizedBox(
        height: 36,
        child: Shimmer(
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: _inset),
            itemCount: 5,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) => SkeletonBox(width: 64.0 + (i % 3) * 14, height: 36, radius: 20),
          ),
        ),
      );
    }

    return SizedBox(
      height: 36,
      child: ListView.builder(
        controller: _categoryScrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: _inset),
        itemCount: _categories.length + (hasFilter ? 1 : 0),
        itemBuilder: (context, index) {
          if (hasFilter && index == 0) {
            return Padding(
              padding: const EdgeInsets.only(right: 10.0),
              child: FadeSlideIn(
                offsetY: 0,
                child: PressableScale(
                  scale: 0.94,
                  onTap: _clearFilters,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(20)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.close_rounded, size: 16, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        S.clearP0(_selectedCategoryIds.length),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ]),
                  ),
                ),
              ),
            );
          }
          final cat = _categories[index - (hasFilter ? 1 : 0)];
          final sel = _selectedCategoryIds.contains(cat.categoryId);
          return Padding(
            padding: const EdgeInsets.only(right: 10.0),
            child: PressableScale(
              scale: 0.95,
              onTap: () => _onCategoryTapped(cat.categoryId),
              child: AnimatedContainer(
                duration: Motion.micro,
                curve: Motion.standard,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: sel ? c.accent.withValues(alpha: c.isDark ? 0.28 : 0.16) : c.categoryChip,
                  border: Border.all(color: sel ? c.accent : Colors.transparent, width: 1.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    AnimatedSize(
                      duration: Motion.micro,
                      child: sel
                          ? Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Icon(Icons.check_rounded, size: 15, color: c.accent),
                            )
                          : const SizedBox.shrink(),
                    ),
                    Text(
                      cat.categoryName,
                      style: TextStyle(color: c.accent, fontWeight: sel ? FontWeight.bold : FontWeight.w500, fontSize: 14),
                    ),
                  ]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
  Widget _buildCategoryWrap(AppColors c) {
    final padding = EdgeInsets.symmetric(horizontal: _inset);
    if (_categories.isEmpty) {
      return Padding(
        padding: padding,
        child: Shimmer(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (var i = 0; i < 6; i++) SkeletonBox(width: 72.0 + (i % 3) * 14, height: 34, radius: 17)],
          ),
        ),
      );
    }
    return Padding(
      padding: padding,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _categoryChip(
            c,
            label: S.actionAll,
            selected: _selectedCategoryIds.isEmpty,
            onTap: _selectedCategoryIds.isEmpty ? null : _clearCategories,
          ),
          for (final cat in _categories)
            _categoryChip(
              c,
              label: cat.categoryName,
              selected: _selectedCategoryIds.contains(cat.categoryId),
              onTap: () => _onCategoryTapped(cat.categoryId),
            ),
        ],
      ),
    );
  }

  Widget _categoryChip(AppColors c, {required String label, required bool selected, VoidCallback? onTap}) {
    const shape = StadiumBorder();
    return Material(
      color: selected ? c.accent : c.card,
      shape: StadiumBorder(side: BorderSide(color: selected ? c.accent : c.border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: shape,
        child: AnimatedContainer(
          duration: Motion.micro,
          constraints: const BoxConstraints(minHeight: 34),
          padding: EdgeInsets.fromLTRB(selected ? 10 : 16, 6, 16, 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? Colors.white : c.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _clearCategories() {
    HapticFeedback.selectionClick();
    setState(_selectedCategoryIds.clear);
    _reloadBooks(showSkeleton: true);
  }

  Widget _categoryProgressBar(AppColors c) {
    return Padding(
      padding: EdgeInsets.fromLTRB(_inset, 8, _inset, 0),
      child: LayoutBuilder(builder: (context, constraints) {
        final tw = constraints.maxWidth;
        const iw = 60.0;
        return Container(
          height: 2,
          width: tw,
          decoration: BoxDecoration(color: c.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
          child: ValueListenableBuilder<double>(
            valueListenable: _categoryScrollProgress,
            builder: (context, progress, _) => Stack(children: [
              Positioned(
                left: progress * (tw - iw),
                top: 0,
                bottom: 0,
                child: Container(
                  width: iw,
                  decoration: BoxDecoration(color: c.accent.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ]),
          ),
        );
      }),
    );
  }

  static String _shortTitle(String title) {
    final main = title.split(RegExp(r'[:：]')).first.trim();
    return main.length > 14 ? '${main.substring(0, 13)}…' : main;
  }

  String? _groupTitle(RecommendationGroup group, {required bool single}) {
    final title = _shortTitle(group.title ?? '');
    final category = group.category ?? '';
    return switch ((group.kind, group.relation)) {
      ('book', 'purchase') => S.becauseBoughtP0(title),
      ('book', 'favorite') => S.becauseSavedP0(title),
      ('book', 'cart') => S.relatedP0Cart(title),
      ('book', _) => S.becauseViewedP0(title),
      ('category', _) => S.moreP0CategoryBrowseOften(category),
      _ => single ? null : S.morePicks,
    };
  }

  Widget _buildDiscoverySections() {
    return AnimatedSize(
      duration: Motion.enter,
      curve: Motion.standard,
      alignment: Alignment.topCenter,
      child: ListenableBuilder(
        listenable: Listenable.merge([HomePreferences.showDiscovery, RecentlyViewed.books]),
        builder: (context, _) {
          if (!HomePreferences.showDiscovery.value) return const SizedBox(width: double.infinity);
          final recent = RecentlyViewed.books.value;
          final recentIds = recent.map((b) => b.bookId).toSet();
          final hidden = {...recentIds, ..._hiddenRecommendations};
          final groups = [
            for (final g in _recommendGroups)
              (group: g, books: g.books.where((b) => !hidden.contains(b.bookId)).toList()),
          ].where((g) => g.books.isNotEmpty).toList();
          final tabs = [
            if (_isBrowsingAll && groups.isNotEmpty)
              DiscoveryTab(
                id: 'picked',
                title: S.picked,
                icon: Icons.auto_awesome_rounded,
                books: [for (final g in groups) ...g.books],
                onOpen: (book) => unawaited(_apiService.logRecommendationClick(book.bookId)),
                onLongPress: _onRecommendationLongPress,
                onDismiss: _dismissRecommendation,
                groups: [
                  for (final g in groups)
                    DiscoveryGroup(title: _groupTitle(g.group, single: groups.length == 1), books: g.books, reasons: g.group.reasons),
                ],
              ),
            if (_isBrowsingAll && recent.isNotEmpty)
              DiscoveryTab(
                id: 'recent',
                title: S.recentlyViewed,
                icon: Icons.history_rounded,
                books: recent,
                actionLabel: S.clear,
                onAction: _clearRecentlyViewed,
              ),
          ];
          if (tabs.isEmpty) return const SizedBox(width: double.infinity);
          return Padding(
            padding: const EdgeInsets.only(top: 20),
            child: context.isWide ? WideDiscoveryPanel(tabs: tabs, inset: _inset) : DiscoveryPanel(tabs: tabs),
          );
        },
      ),
    );
  }

  Widget _buildSortAndLayoutRow() {
    final c = AppColors.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            _isBrowsingAll ? S.allBooks : S.results,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: c.textPrimary),
          ),
        ),
        const SizedBox(width: 8),
        ConstrainedBox(constraints: const BoxConstraints(maxWidth: 150), child: _buildSortDropdown()),
        const SizedBox(width: 8),
        Container(
          decoration: BoxDecoration(color: c.categoryChip, borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.all(2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _layoutToggle(c, Icons.grid_view_rounded, true),
              _layoutToggle(c, Icons.view_agenda_rounded, false),
            ],
          ),
        ),
      ],
    );
  }
  Widget _buildWideSortRow(AppColors c) {
    final radius = BorderRadius.circular(10);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 36),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _isBrowsingAll ? S.allBooks : S.results,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: c.textPrimary),
            ),
          ),
          const SizedBox(width: 12),
          Material(
            color: c.card,
            shape: RoundedRectangleBorder(
              borderRadius: radius,
              side: BorderSide(color: c.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Builder(
              builder: (buttonContext) => InkWell(
                onTap: () => _pickSortFrom(buttonContext),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 34),
                  padding: const EdgeInsets.fromLTRB(10, 0, 6, 0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.swap_vert_rounded, size: 18, color: c.accent),
                      const SizedBox(width: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 160),
                        child: Text(
                          _currentSortLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Icon(Icons.expand_more_rounded, size: 20, color: c.textSecondary),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Material(
            color: c.card,
            shape: RoundedRectangleBorder(
              borderRadius: radius,
              side: BorderSide(color: c.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _wideLayoutToggle(c, Icons.grid_view_rounded, true),
                  _wideLayoutToggle(c, Icons.view_agenda_rounded, false),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _wideLayoutToggle(AppColors c, IconData icon, bool grid) {
    final active = _isGridView == grid;
    final radius = BorderRadius.circular(8);
    return Tooltip(
      message: grid ? S.gridView : S.listView,
      child: Material(
        color: active ? c.accent : Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: active
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  setState(() => _isGridView = grid);
                },
          child: SizedBox(
            width: 38,
            height: 30,
            child: Icon(icon, size: 18, color: active ? Colors.white : c.textSecondary),
          ),
        ),
      ),
    );
  }

  Widget _layoutToggle(AppColors c, IconData icon, bool grid) {
    final active = _isGridView == grid;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (active) return;
        HapticFeedback.selectionClick();
        setState(() => _isGridView = grid);
      },
      child: AnimatedContainer(
        duration: Motion.base,
        curve: Motion.standard,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: active ? c.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: active ? Colors.white : c.iconInactive),
      ),
    );
  }

  Future<void> _pickSortFrom(BuildContext buttonContext) async {
    final c = AppColors.of(context);
    final picked = await showAppPopoverSheet<String>(
      context: context,
      anchor: PointerAnchor.of(buttonContext),
      popoverWidth: 240,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
              child: Text(
                S.sortBy,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textSecondary),
              ),
            ),
            for (final o in _sortOptions)
              InkWell(
                onTap: () => Navigator.pop(ctx, o.code),
                child: SizedBox(
                  height: 44,
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 24,
                        child: o.code == _currentSort ? Icon(Icons.check_rounded, size: 18, color: c.accent) : null,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          o.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: o.code == _currentSort ? FontWeight.w600 : FontWeight.w400,
                            color: o.code == _currentSort ? c.accent : c.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (picked != null && picked != _currentSort) _onSortChanged(picked);
  }

  Future<void> _pickSort() async {
    final picked = await showAppPicker<String>(
      context,
      title: S.sortBy,
      selected: _currentSort,
      options: [
        for (final o in _sortOptions) AppSelectOption(value: o.code, label: o.label),
      ],
    );
    if (picked != null && picked != _currentSort) _onSortChanged(picked);
  }

  Widget _buildSortDropdown() {
    final c = AppColors.of(context);
    return PressableScale(
      scale: 0.96,
      onTap: _pickSort,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.swap_vert_rounded, size: 18, color: c.accent),
          const SizedBox(width: 4),
          Flexible(
            child: SwitchIn(
              duration: Motion.micro,
              child: Text(
                _currentSortLabel,
                key: ValueKey(_currentSort),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: c.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildBookSliver(AppColors c) {
    final padding = EdgeInsets.symmetric(horizontal: _inset);

    if (_isLoadingInitial) {
      return SliverPadding(
        padding: padding,
        sliver: _isGridView
            ? SliverGrid(
                gridDelegate: BookCard.gridDelegateOf(context),
                delegate: SliverChildBuilderDelegate((_, _) => _skeletonCard(c, true), childCount: 4),
              )
            : SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, _) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _skeletonCard(c, false)),
                  childCount: 4,
                ),
              ),
      );
    }

    if (_books.isEmpty) {
      return SliverToBoxAdapter(
        child: EmptyView(
          icon: Icons.menu_book_outlined,
          message: S.noBooksMatchFilters,
          actionLabel: _isBrowsingAll ? null : S.clearFilters,
          onAction: _isBrowsingAll ? null : _clearFilters,
        ),
      );
    }

    if (_isGridView) {
      return SliverPadding(
        padding: padding,
        sliver: SliverGrid(
          gridDelegate: BookCard.gridDelegateOf(context),
          delegate: SliverChildBuilderDelegate(
            (_, i) => RevealOnScroll(
              key: ValueKey('grid_${_books[i].bookId}'),
              index: i,
              child: BookCard(book: _books[i]),
            ),
            childCount: _books.length,
            findChildIndexCallback: (key) => _indexForKey(key, 'grid_'),
          ),
        ),
      );
    }

    if (context.isWide) {
      return SliverPadding(
        padding: padding,
        sliver: SliverGrid(
          gridDelegate: BookCard.listDelegateOf(context),
          delegate: SliverChildBuilderDelegate(
            (_, i) => RevealOnScroll(
              key: ValueKey('list_${_books[i].bookId}'),
              index: i,
              child: BookCard(book: _books[i], isListMode: true),
            ),
            childCount: _books.length,
            findChildIndexCallback: (key) => _indexForKey(key, 'list_'),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: padding,
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (_, i) => RevealOnScroll(
            key: ValueKey('list_${_books[i].bookId}'),
            index: i,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: BookCard(book: _books[i], isListMode: true),
            ),
          ),
          childCount: _books.length,
          findChildIndexCallback: (key) => _indexForKey(key, 'list_'),
        ),
      ),
    );
  }

  int? _indexForKey(Key key, String prefix) {
    if (key is! ValueKey<String> || !key.value.startsWith(prefix)) return null;
    final id = int.tryParse(key.value.substring(prefix.length));
    final index = _books.indexWhere((b) => b.bookId == id);
    return index < 0 ? null : index;
  }

  Widget _skeletonCard(AppColors c, bool grid) {
    return Shimmer(
      child: Container(
        height: grid ? BookCard.gridHeightOf(context) : BookCard.listHeightOf(context),
        decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(16)),
        child: grid
            ? const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(height: 140, radius: 16),
                  Padding(
                    padding: EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(height: 14),
                        SizedBox(height: 10),
                        SkeletonBox(width: 90, height: 12),
                        SizedBox(height: 12),
                        SkeletonBox(width: 60, height: 18, radius: 8),
                      ],
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  SkeletonBox(width: 110, height: BookCard.listHeightOf(context), radius: 16),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(height: 14),
                        SizedBox(height: 10),
                        SkeletonBox(width: 90, height: 12),
                        SizedBox(height: 24),
                        SkeletonBox(width: 60, height: 18, radius: 8),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                ],
              ),
      ),
    );
  }
}

class _TabSlot {
  final key = GlobalKey<NavigatorState>();
  final routes = _TabRoutes();
  final heroController = MaterialApp.createMaterialHeroController();
  _TabNavigator? navigator;
  bool canPop = false;

  void dispose() => heroController.dispose();
}

class _TabPages extends InheritedWidget {
  final List<Widget> pages;

  const _TabPages({required this.pages, required super.child});

  @override
  bool updateShouldNotify(_TabPages oldWidget) => true;
}

class _TabRoot extends StatelessWidget {
  final int index;

  const _TabRoot({required this.index});

  @override
  Widget build(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_TabPages>()!.pages[index];
}

class _TabRoutes extends NavigatorObserver {
  final List<Route<dynamic>> routes = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute == null) routes.clear();
    routes.add(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => routes.remove(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => routes.remove(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute == null) return;
    final index = oldRoute == null ? -1 : routes.indexOf(oldRoute);
    if (index >= 0) {
      routes[index] = newRoute;
    } else {
      routes.add(newRoute);
    }
  }
}

class _TabNavigator extends Navigator {
  final _TabRoutes routes;
  final VoidCallback onLeaveRoot;

  _TabNavigator({super.key, required this.routes, required this.onLeaveRoot, required WidgetBuilder rootBuilder})
      : super(
          observers: [routes],
          onGenerateRoute: (settings) => MaterialPageRoute<void>(settings: settings, builder: rootBuilder),
        );

  @override
  NavigatorState createState() => _TabNavigatorState();
}

// 頁面以 Navigator.of(context) 清空堆疊（登出、回首頁）時改由最上層 Navigator 執行；分頁根頁面被 pop 或取代會留下空白分頁。
class _TabNavigatorState extends NavigatorState {
  _TabNavigator get _tab => widget as _TabNavigator;

  Future<bool> systemBack() => super.maybePop();

  @override
  Future<T?> pushAndRemoveUntil<T extends Object?>(Route<T> newRoute, RoutePredicate predicate) {
    if (_tab.routes.routes.any(predicate)) return super.pushAndRemoveUntil<T>(newRoute, predicate);
    return Navigator.of(context, rootNavigator: true).pushAndRemoveUntil<T>(newRoute, predicate);
  }

  @override
  Future<T?> pushReplacement<T extends Object?, TO extends Object?>(Route<T> newRoute, {TO? result}) {
    if (!canPop()) return push<T>(newRoute);
    return super.pushReplacement<T, TO>(newRoute, result: result);
  }

  @override
  void pop<T extends Object?>([T? result]) {
    if (!canPop()) {
      _tab.onLeaveRoot();
      return;
    }
    super.pop<T>(result);
  }

  @override
  Future<bool> maybePop<T extends Object?>([T? result]) async {
    if (canPop()) return super.maybePop<T>(result);
    if (await super.maybePop<T>(result)) return true;
    if (mounted) _tab.onLeaveRoot();
    return true;
  }

  @override
  void popUntil(RoutePredicate predicate) => super.popUntil((route) => route.isFirst || predicate(route));
}
