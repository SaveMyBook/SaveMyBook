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
import '../utils/app_colors.dart';
import '../utils/motion.dart';
import '../widgets/app_header.dart';
import '../widgets/animations.dart';
import '../widgets/book_card.dart';
import '../widgets/custom_bottom_nav.dart';
import '../widgets/search_bar_widget.dart';
import '../widgets/state_views.dart';

class HomeScreen extends StatefulWidget {
  final String initialKeyword;
  const HomeScreen({super.key, this.initialKeyword = ''});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  int _currentPage = 1;
  final Set<int> _selectedCategoryIds = {};
  String _currentSort = '最新上架';
  late String _currentKeyword = widget.initialKeyword;
  final List<String> _sortOptions = ['最新上架', '熱門推薦', '價格由低到高', '價格由高到低'];

  List<Category> _categories = [];
  List<Book> _books = [];

  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _categoryScrollController = ScrollController();
  double _categoryScrollProgress = 0.0;
  bool _isGridView = true;

  Timer? _badgeTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    kBottomNavVisible = true;
    // 沒有推播，所以固定輪詢讓通知／聊天的紅點自己跳出來。
    _badgeTimer = Timer.periodic(const Duration(seconds: 20), (_) => _loadBadges());
    _loadInitialData();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
          !_isLoadingMore && _hasMoreData) {
        _loadMoreData();
      }
    });
    _categoryScrollController.addListener(() {
      if (_categoryScrollController.hasClients) {
        setState(() {
          final maxScroll = _categoryScrollController.position.maxScrollExtent;
          _categoryScrollProgress = maxScroll > 0
              ? (_categoryScrollController.offset / maxScroll).clamp(0.0, 1.0)
              : 0;
        });
      }
    });
  }

  @override
  void dispose() {
    kBottomNavVisible = false;
    _badgeTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _categoryScrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadBadges();
  }

  Future<void> _loadBadges() => _apiService.refreshBadges();

  Future<void> _loadInitialData() async {
    setState(() => _isLoadingInitial = true);
    _loadBadges();
    try {
      final results = await Future.wait([
        _apiService.fetchCategories(),
        _apiService.fetchBooks(page: 1, categoryIds: _selectedCategoryIds, sort: _currentSort, keyword: _currentKeyword),
      ]);
      if (!mounted) return;
      setState(() {
        _categories = results[0] as List<Category>;
        _books = results[1] as List<Book>;
        _currentPage = 1;
        _hasMoreData = _books.length >= 20;
        _isLoadingInitial = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingInitial = false);
    }
  }

  Future<void> _onRefresh() async {
    _currentPage = 1;
    _hasMoreData = true;
    final newBooks = await _apiService.fetchBooks(page: 1, categoryIds: _selectedCategoryIds, sort: _currentSort, keyword: _currentKeyword);
    setState(() {
      _books = newBooks;
      _hasMoreData = newBooks.length >= 20;
    });
  }

  Future<void> _loadMoreData() async {
    setState(() => _isLoadingMore = true);
    try {
      _currentPage++;
      final moreBooks = await _apiService.fetchBooks(page: _currentPage, categoryIds: _selectedCategoryIds, sort: _currentSort, keyword: _currentKeyword);
      if (!mounted) return;
      setState(() {
        if (moreBooks.isEmpty) { _hasMoreData = false; }
        else { _books.addAll(moreBooks); _hasMoreData = moreBooks.length >= 20; }
        _isLoadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _onCategoryTapped(int categoryId) {
    setState(() {
      _selectedCategoryIds.contains(categoryId)
          ? _selectedCategoryIds.remove(categoryId)
          : _selectedCategoryIds.add(categoryId);
      _isLoadingInitial = true;
    });
    _onRefresh().then((_) { if (mounted) setState(() => _isLoadingInitial = false); });
  }

  void _onSortChanged(String s) {
    setState(() { _currentSort = s; _isLoadingInitial = true; });
    _onRefresh().then((_) { if (mounted) setState(() => _isLoadingInitial = false); });
  }

  void _onSearchChanged(String k) {
    setState(() { _currentKeyword = k; _isLoadingInitial = true; });
    _onRefresh().then((_) { if (mounted) setState(() => _isLoadingInitial = false); });
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
              onItemSelected: (i) {
                setState(() { _selectedIndex = i; });
                _loadBadges();
              },
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
          child: RefreshIndicator(
            color: c.accent,
            onRefresh: _onRefresh,
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  _buildCategories(),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: LayoutBuilder(builder: (context, constraints) {
                      final tw = constraints.maxWidth;
                      const iw = 60.0;
                      return Container(
                        height: 2, width: tw,
                        decoration: BoxDecoration(color: c.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                        child: Stack(children: [
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 100),
                            left: _categoryScrollProgress * (tw - iw), top: 0, bottom: 0,
                            child: Container(width: iw, decoration: BoxDecoration(color: c.accent.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(6))),
                          ),
                        ]),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0), child: _buildSortAndLayoutRow()),
                  const SizedBox(height: 16),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0), child: _buildBookGrid()),
                  Reveal(
                    visible: _isLoadingMore,
                    child: const Padding(padding: EdgeInsets.symmetric(vertical: 24.0), child: Center(child: CircularProgressIndicator(color: AppColors.primary))),
                  ),
                  Reveal(
                    visible: !_hasMoreData && _books.isNotEmpty && !_isLoadingInitial,
                    child: Padding(padding: const EdgeInsets.symmetric(vertical: 24.0), child: Center(child: Text('您已滑到底部', style: TextStyle(color: c.textHint, fontSize: 13)))),
                  ),
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 100),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomHeader() {
    final c = AppColors.of(context);
    final userName = ApiService.currentUser?.nickname ?? '訪客';
return LightStatusBar(
      child: Container(
      decoration: BoxDecoration(color: c.headerBg, borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24))),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.only(top: 8.0, bottom: 20.0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('哈囉, $userName', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                Row(children: [
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
                ])
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
    return SizedBox(
      height: 36,
      child: ListView.builder(
        controller: _categoryScrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final sel = _selectedCategoryIds.contains(cat.categoryId);
          return Padding(
            padding: const EdgeInsets.only(right: 10.0),
            child: GestureDetector(
              onTap: () => _onCategoryTapped(cat.categoryId),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: c.categoryChip,
                  border: Border.all(color: sel ? c.accent : Colors.transparent, width: 1.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(child: Text(cat.categoryName, style: TextStyle(color: c.accent, fontWeight: sel ? FontWeight.bold : FontWeight.w500, fontSize: 14))),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSortAndLayoutRow() {
    final c = AppColors.of(context);
    return Row(
      children: [
        _buildSortDropdown(),
        const Spacer(),
        AnimatedContainer(
        duration: Motion.base,
        curve: Motion.standard,

          decoration: BoxDecoration(
            color: c.categoryChip,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () {
                  if (_isGridView) return;
                  HapticFeedback.selectionClick();
                  setState(() => _isGridView = true);
                },
                child: AnimatedContainer(
        duration: Motion.base,
        curve: Motion.standard,

                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _isGridView ? c.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.grid_view_rounded, size: 20, color: _isGridView ? Colors.white : c.iconInactive),
                ),
              ),
              GestureDetector(
                onTap: () {
                  if (!_isGridView) return;
                  HapticFeedback.selectionClick();
                  setState(() => _isGridView = false);
                },
                child: AnimatedContainer(
        duration: Motion.base,
        curve: Motion.standard,

                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: !_isGridView ? c.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.view_agenda_rounded, size: 20, color: !_isGridView ? Colors.white : c.iconInactive),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSortDropdown() {
    final c = AppColors.of(context);
    return PopupMenuButton<String>(
      initialValue: _currentSort, onSelected: _onSortChanged,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      color: c.card, offset: const Offset(0, 36),
      itemBuilder: (_) => _sortOptions.map((ch) => PopupMenuItem(value: ch,
          child: Text(ch, style: TextStyle(color: _currentSort == ch ? c.accent : c.textPrimary, fontWeight: _currentSort == ch ? FontWeight.bold : FontWeight.normal)))).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(_currentSort, style: const TextStyle(color: Colors.white, fontSize: 14)),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 18),
        ]),
      ),
    );
  }

  Widget _buildBookGrid() {
    final c = AppColors.of(context);
    Widget content;
    if (_isLoadingInitial) {
      content = const Center(key: ValueKey('loading'), child: Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator(color: AppColors.primary)));
    } else if (_books.isEmpty) {
      content = Center(key: const ValueKey('empty'), child: Padding(padding: const EdgeInsets.all(32.0), child: Text('目前沒有符合條件的書籍', style: TextStyle(color: c.textHint))));
    } else if (_isGridView) {
      content = GridView.builder(
        key: const ValueKey('grid'), padding: EdgeInsets.zero, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.58),
        itemCount: _books.length,
        itemBuilder: (_, i) => RevealOnScroll(index: i, child: BookCard(book: _books[i])),
      );
    } else {
      content = ListView.builder(
        key: const ValueKey('list'), padding: EdgeInsets.zero, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        itemCount: _books.length,
        itemBuilder: (_, i) => RevealOnScroll(
          index: i,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: BookCard(book: _books[i], isListMode: true),
          ),
        ),
      );
    }
    // 網格與列表的高度差很多，只用 AnimatedSwitcher 會在切換瞬間跳一下。
    // 外面再包一層 AnimatedSize，讓容器高度跟著一起補間。
    return AnimatedSize(
      duration: Motion.enter,
      curve: Motion.emphasized,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: Motion.base,
        switchInCurve: Motion.emphasized,
        switchOutCurve: Motion.exitCurve,
        transitionBuilder: (child, animation) {
          final incoming = child.key == ValueKey(_isGridView ? 'grid' : 'list');
          final dx = (_isGridView ? 0.06 : -0.06) * (incoming ? 1 : -1);
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(begin: Offset(dx, 0), end: Offset.zero)
                  .animate(animation),
              child: ScaleTransition(
                scale: Tween(begin: 0.97, end: 1.0).animate(animation),
                child: child,
              ),
            ),
          );
        },
        // 預設會把新舊畫面疊在一起，兩份清單同時存在高度會爆掉；
        // 這裡讓舊的直接淡出、不參與版面計算。
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topCenter,
          children: [
            for (final child in previous) Positioned.fill(child: IgnorePointer(child: child)),
            ?current,
          ],
        ),
        child: content,
      ),
    );
  }
}