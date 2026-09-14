import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'cart_screen.dart';
import 'chat_list_screen.dart';
import 'notification_screen.dart';
import 'profile_screen.dart';
import 'sell_book_screen.dart';
import 'pickup_book_screen.dart';
import '../models/category.dart';
import '../models/book.dart';
import '../services/api_service.dart';
import '../services/home_widget_service.dart';
import '../services/push_service.dart';
import '../services/recently_viewed.dart';
import '../services/search_history.dart';
import 'legal_consent_screen.dart';
import '../utils/app_colors.dart';
import '../utils/motion.dart';
import '../widgets/app_header.dart';
import '../widgets/animations.dart';
import '../widgets/book_card.dart';
import '../widgets/buyer/back_to_top_button.dart';
import '../widgets/buyer/book_strip.dart';
import '../widgets/buyer/undo_snackbar.dart';
import '../widgets/custom_bottom_nav.dart';
import '../widgets/search_bar_widget.dart';
import '../widgets/state_views.dart';
import '../i18n/strings.dart';

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
  List<Book> _popular = [];
  bool _popularLoading = true;

  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _categoryScrollController = ScrollController();
  final ValueNotifier<double> _categoryScrollProgress = ValueNotifier<double>(0);
  final GlobalKey<RefreshIndicatorState> _refreshKey = GlobalKey<RefreshIndicatorState>();
  final GlobalKey _sortRowKey = GlobalKey();
  bool _isGridView = true;

  Timer? _badgeTimer;

  bool get _isBrowsingAll => _currentKeyword.isEmpty && _selectedCategoryIds.isEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    kBottomNavVisible = true;
    _badgeTimer = Timer.periodic(const Duration(seconds: 20), (_) => _loadBadges());
    PushService.onSignedIn();
    RecentlyViewed.load();
    SearchHistory.load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) LegalConsentGate.check(context);
    });
    _loadInitialData();
    _scrollController.addListener(_onScroll);
    _categoryScrollController.addListener(_onCategoryScroll);
  }

  @override
  void dispose() {
    kBottomNavVisible = false;
    _badgeTimer?.cancel();
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
    _loadPopular();
    final categoriesFuture = _apiService.fetchCategories();
    await _reloadBooks(showSkeleton: true);
    final categories = await categoriesFuture;
    if (!mounted) return;
    setState(() => _categories = categories);
  }

  Future<void> _loadPopular() async {
    final books = await _apiService.fetchBooks(page: 1, limit: 12, sort: 'popular');
    if (!mounted) return;
    setState(() {
      _popular = books;
      _popularLoading = false;
    });
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
      _loadPopular(),
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

  void _showAllPopular() {
    _onSortChanged('popular');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _sortRowKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx, duration: Motion.large, curve: Motion.standard, alignment: 0.02);
      }
    });
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

  @override
  Widget build(BuildContext context) {
    final bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _selectedIndex,
            children: [
              _buildHomeContent(),
              const NotificationScreen(embedded: true),
              const SellBookScreen(),
              PickupBookScreen(isActive: _selectedIndex == 3),
              const ProfileScreen(),
            ],
          ),
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
    final bottomInset = MediaQuery.of(context).padding.bottom;

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
                        key: _sortRowKey,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                        child: _buildSortAndLayoutRow(),
                      ),
                    ),
                    _buildBookSliver(c),
                    SliverToBoxAdapter(
                      child: Reveal(
                        visible: _isLoadingMore,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24.0),
                          child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
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
                    SliverToBoxAdapter(child: SizedBox(height: bottomInset + 100)),
                  ],
                ),
              ),
              Positioned(
                right: 16,
                bottom: bottomInset + 76,
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
                child: SearchBarWidget(currentKeyword: _currentKeyword, onSearch: _onSearchChanged),
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
    final showPopular = _isBrowsingAll && _currentSort != 'popular' && (_popularLoading || _popular.isNotEmpty);

    return AnimatedSize(
      duration: Motion.enter,
      curve: Motion.standard,
      alignment: Alignment.topCenter,
      child: ValueListenableBuilder<List<Book>>(
        valueListenable: RecentlyViewed.books,
        builder: (context, recent, _) {
          final showRecent = _isBrowsingAll && recent.isNotEmpty;
          if (!showRecent && !showPopular) return const SizedBox(width: double.infinity);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showPopular) ...[
                const SizedBox(height: 20),
                BookStrip(
                  title: ApiService.authToken == null ? S.popular : S.picked,
                  icon: Icons.local_fire_department_rounded,
                  books: _popular,
                  loading: _popularLoading,
                  heroPrefix: 'popular',
                  actionLabel: S.seeMore,
                  onAction: _showAllPopular,
                ),
              ],
              if (showRecent) ...[
                const SizedBox(height: 16),
                BookStrip(
                  title: S.recentlyViewed,
                  icon: Icons.history_rounded,
                  books: recent,
                  heroPrefix: 'recent',
                  actionLabel: S.clear,
                  onAction: _clearRecentlyViewed,
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildSortAndLayoutRow() {
    final c = AppColors.of(context);
    return Row(
      children: [
        Flexible(child: _buildSortDropdown()),
        const SizedBox(width: 12),
        const Spacer(),
        Container(
          decoration: BoxDecoration(color: c.categoryChip, borderRadius: BorderRadius.circular(8)),
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
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: active ? c.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20, color: active ? Colors.white : c.iconInactive),
      ),
    );
  }

  Widget _buildSortDropdown() {
    final c = AppColors.of(context);
    return PopupMenuButton<String>(
      initialValue: _currentSort,
      onSelected: _onSortChanged,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      color: c.card,
      offset: const Offset(0, 36),
      itemBuilder: (_) => _sortOptions
          .map((o) => PopupMenuItem(
                value: o.code,
                child: Text(
                  o.label,
                  style: TextStyle(
                    color: _currentSort == o.code ? c.accent : c.textPrimary,
                    fontWeight: _currentSort == o.code ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ))
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Flexible(
            child: SwitchIn(
              duration: Motion.micro,
              child: Text(
                _currentSortLabel,
                key: ValueKey(_currentSort),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 18),
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
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent: BookCard.gridHeight,
                ),
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
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: BookCard.gridHeight,
          ),
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
