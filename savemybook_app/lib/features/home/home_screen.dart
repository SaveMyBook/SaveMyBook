import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../orders/cart_screen.dart';
import '../chat/chat_list_screen.dart';
import 'notification_screen.dart';
import '../account/profile_screen.dart';
import '../selling/sell_book_screen.dart';
import '../orders/pickup_book_screen.dart';
import '../../models/category.dart';
import '../../models/book.dart';
import '../../services/api_service.dart';
import '../../services/home_preferences.dart';
import '../../services/home_widget_service.dart';
import '../../services/server_compat.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/app_select.dart';
import '../../services/push_service.dart';
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

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const int _pageSize = 20;

  int _selectedIndex = 0;
  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  int _currentPage = 1;
  int _requestId = 0;
  final Set<int> _selectedCategoryIds = {};
  String _currentSort = 'newest';
  late String _currentKeyword = widget.initialKeyword;

  List<({String code, String label})> get _sortOptions => [
        (code: 'newest', label: S.newest),
        (code: 'popular', label: S.popular),
        (code: 'price_asc', label: S.priceLowHigh),
        (code: 'price_desc', label: S.priceHighLow),
      ];

  String get _currentSortLabel =>
      _sortOptions.firstWhere((o) => o.code == _currentSort, orElse: () => _sortOptions.first).label;

  List<Category> _categories = [];
  List<Book> _books = [];
  List<Book> _recommended = [];

  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _categoryScrollController = ScrollController();
  final ValueNotifier<double> _categoryScrollProgress = ValueNotifier<double>(0);
  final GlobalKey<RefreshIndicatorState> _refreshKey = GlobalKey<RefreshIndicatorState>();
  bool _isGridView = true;

  Timer? _badgeTimer;

  bool get _isBrowsingAll => _currentKeyword.isEmpty && _selectedCategoryIds.isEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    kBottomNavVisible = true;
    ToastRouteTracker.notifyNavVisibility();
    _badgeTimer = Timer.periodic(const Duration(seconds: 20), (_) => _loadBadges());
    PushService.onSignedIn();
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
    kBottomNavVisible = false;
    ToastRouteTracker.notifyNavVisibility();
    _badgeTimer?.cancel();
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
      _loadBadges();
      LegalConsentGate.check(context);
    } else if (state == AppLifecycleState.paused) {
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
    if (!HomePreferences.showDiscovery.value) return;
    await RecentlyViewed.load();
    final viewedIds = RecentlyViewed.books.value.map((b) => b.bookId);
    final recommended = await _apiService.fetchRecommendedBooks(viewedIds: viewedIds);
    if (!mounted) return;
    setState(() => _recommended = recommended);
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
    setState(() => _currentKeyword = k);
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

  void _onNavSelected(int i) {
    if (i == _selectedIndex) {
      if (i == 0) _onHomeReselected();
      return;
    }
    setState(() => _selectedIndex = i);
    _loadBadges();
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

    final pages = IndexedStack(
      index: _selectedIndex,
      children: [
        _buildHomeContent(),
        const NotificationScreen(embedded: true),
        const SellBookScreen(),
        PickupBookScreen(isActive: _selectedIndex == 3),
        const ProfileScreen(),
      ],
    );

    if (sideNav) {
      return Scaffold(
        body: Row(
          children: [
            AppSideNav(
              selectedIndex: _selectedIndex,
              onItemSelected: _onNavSelected,
              extended: context.screenSize == ScreenSize.expanded,
            ),
            Expanded(
              child: MediaQuery.removePadding(context: context, removeLeft: true, child: pages),
            ),
          ],
        ),
      );
    }

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

  Widget _buildHomeContent() {
    final c = AppColors.of(context);

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
                    SliverToBoxAdapter(child: _buildCategories()),
                    SliverToBoxAdapter(child: _buildCategoryProgress(c)),
                    SliverToBoxAdapter(child: _buildDiscoverySections()),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                        child: _buildSortAndLayoutRow(),
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
                    SliverToBoxAdapter(
                      child: Reveal(
                        visible: !_hasMoreData && _books.isNotEmpty && !_isLoadingInitial,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24.0),
                          child: Center(
                            child: Text(S.reachedEnd, style: TextStyle(color: c.textHint, fontSize: 13)),
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(child: SizedBox(height: floatingNavClearance(context, 100))),
                  ],
                ),
              ),
              Positioned(
                right: 16,
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
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(children: [
                  Expanded(
                    child: Text(
                      S.hi(userName),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
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
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: Breakpoints.readingMaxWidth),
                  child: SearchBarWidget(currentKeyword: _currentKeyword, onSearch: _onSearchChanged),
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
            padding: const EdgeInsets.symmetric(horizontal: 16),
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
        padding: const EdgeInsets.symmetric(horizontal: 16),
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

  Widget _buildCategoryProgress(AppColors c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
          final recommended = _recommended.where((b) => !recentIds.contains(b.bookId)).toList();
          final tabs = [
            if (_isBrowsingAll && recommended.isNotEmpty)
              DiscoveryTab(
                id: 'picked',
                title: S.picked,
                icon: Icons.auto_awesome_rounded,
                books: recommended,
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
            child: DiscoveryPanel(tabs: tabs),
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
    const padding = EdgeInsets.symmetric(horizontal: 16);

    if (_isLoadingInitial) {
      return SliverPadding(
        padding: padding,
        sliver: _isGridView
            ? SliverGrid(
                gridDelegate: BookCard.gridDelegate,
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
          gridDelegate: BookCard.gridDelegate,
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
          gridDelegate: BookCard.listDelegate,
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
        height: grid ? BookCard.gridHeight : 140,
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
            : const Row(
                children: [
                  SkeletonBox(width: 110, height: 140, radius: 16),
                  SizedBox(width: 14),
                  Expanded(
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
                  SizedBox(width: 14),
                ],
              ),
      ),
    );
  }
}
