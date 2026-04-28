import 'package:flutter/material.dart';
import 'profile_screen.dart';
import 'sell_book_screen.dart';
import 'pickup_book_screen.dart';
import '../models/category.dart';
import '../models/book.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../widgets/book_card.dart';
import '../widgets/custom_bottom_nav.dart';
import '../widgets/search_bar_widget.dart';

class HomeScreen extends StatefulWidget {
  final String initialKeyword;
  const HomeScreen({super.key, this.initialKeyword = ''});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
  bool _isNavVisible = true;
  bool _isGridView = true;

  @override
  void initState() {
    super.initState();
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
    _scrollController.dispose();
    _categoryScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoadingInitial = true);
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
              const Scaffold(body: Center(child: Text('通知'))),
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
              onItemSelected: (i) => setState(() { _selectedIndex = i; }),
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
            color: AppColors.primary,
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
                        decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(1)),
                        child: Stack(children: [
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 100),
                            left: _categoryScrollProgress * (tw - iw), top: 0, bottom: 0,
                            child: Container(width: iw, decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.4), borderRadius: BorderRadius.circular(1))),
                          ),
                        ]),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0), child: _buildSortAndLayoutRow()),
                  const SizedBox(height: 16),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0), child: _buildBookGrid()),
                  if (_isLoadingMore)
                    const Padding(padding: EdgeInsets.symmetric(vertical: 24.0), child: Center(child: CircularProgressIndicator(color: AppColors.primary))),
                  if (!_hasMoreData && _books.isNotEmpty && !_isLoadingInitial)
                    Padding(padding: const EdgeInsets.symmetric(vertical: 24.0), child: Center(child: Text('您已滑到底部', style: TextStyle(color: c.textHint, fontSize: 13)))),
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
    return Container(
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
                const Row(children: [
                  Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 26),
                  SizedBox(width: 16),
                  Icon(Icons.chat_bubble_outline, color: Colors.white, size: 24),
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
                  border: Border.all(color: sel ? AppColors.primary : Colors.transparent, width: 1.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(child: Text(cat.categoryName, style: TextStyle(color: AppColors.primary, fontWeight: sel ? FontWeight.bold : FontWeight.w500, fontSize: 14))),
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
        Container(
          decoration: BoxDecoration(
            color: c.categoryChip,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () { if (!_isGridView) setState(() => _isGridView = true); },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _isGridView ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(Icons.grid_view_rounded, size: 20, color: _isGridView ? Colors.white : c.iconInactive),
                ),
              ),
              GestureDetector(
                onTap: () { if (_isGridView) setState(() => _isGridView = false); },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: !_isGridView ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
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
          child: Text(ch, style: TextStyle(color: _currentSort == ch ? AppColors.primary : c.textPrimary, fontWeight: _currentSort == ch ? FontWeight.bold : FontWeight.normal)))).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
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
        itemBuilder: (_, i) => BookCard(book: _books[i]),
      );
    } else {
      content = ListView.builder(
        key: const ValueKey('list'), padding: EdgeInsets.zero, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        itemCount: _books.length,
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: BookCard(book: _books[i], isListMode: true),
        ),
      );
    }
    return AnimatedSwitcher(duration: const Duration(milliseconds: 300), child: content);
  }
}