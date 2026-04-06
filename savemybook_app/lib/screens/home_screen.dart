import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/category.dart';
import '../models/book.dart';
import '../services/api_service.dart';
import '../widgets/book_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

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
  final List<String> _sortOptions = ['最新上架', '熱門推薦', '價格由低到高', '價格由高到低'];
  double _categoryScrollProgress = 0.0;
  String _currentKeyword = '';
  final TextEditingController _searchController = TextEditingController();
  List<Category> _categories = [];
  List<Book> _books = [];
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _categoryScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
          !_isLoadingMore &&
          _hasMoreData) {
        _loadMoreData();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _categoryScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoadingInitial = true);
    try {
      final results = await Future.wait([
        _apiService.fetchCategories(),
        _apiService.fetchBooks(page: 1, categoryIds: _selectedCategoryIds, sort: _currentSort),
      ]);
      if (!mounted) return;
      setState(() {
        _categories = results[0] as List<Category>;
        _books = results[1] as List<Book>;
        _currentPage = 1;
        _hasMoreData = (_books.length >= 20);
        _isLoadingInitial = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingInitial = false);
    }
  }

  Future<void> _onRefresh() async {
    _currentPage = 1;
    _hasMoreData = true;
    final newBooks = await _apiService.fetchBooks(
      page: 1,
      categoryIds: _selectedCategoryIds,
      sort: _currentSort,
      keyword: _currentKeyword.isEmpty ? null : _currentKeyword,
    );
    setState(() {
      _books = newBooks;
      _hasMoreData = (newBooks.length >= 20);
    });
  }

  Future<void> _loadMoreData() async {
    setState(() => _isLoadingMore = true);
    try {
      _currentPage++;
      final moreBooks = await _apiService.fetchBooks(
        page: _currentPage,
        categoryIds: _selectedCategoryIds,
        sort: _currentSort,
        keyword: _currentKeyword.isEmpty ? null : _currentKeyword,
      );
      if (!mounted) return;
      setState(() {
        if (moreBooks.isEmpty) {
          _hasMoreData = false;
        } else {
          _books.addAll(moreBooks);
          _hasMoreData = (moreBooks.length >= 20);
        }
        _isLoadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _onCategoryTapped(int categoryId) {
    setState(() {
      if (_selectedCategoryIds.contains(categoryId)) {
        _selectedCategoryIds.remove(categoryId);
      } else {
        _selectedCategoryIds.add(categoryId);
      }
      _isLoadingInitial = true;
    });
    _onRefresh().then((_) {
      if (mounted) setState(() => _isLoadingInitial = false);
    });
  }

  void _onSearch(String keyword) {
    setState(() {
      _currentKeyword = keyword.trim();
      _isLoadingInitial = true;
    });
    _onRefresh().then((_) {
      if (mounted) setState(() => _isLoadingInitial = false);
    });
  }

  void _onSortChanged(String newSort) {
    setState(() {
      _currentSort = newSort;
      _isLoadingInitial = true;
    });
    _onRefresh().then((_) {
      if (mounted) setState(() => _isLoadingInitial = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Column(
        children: [
          _buildCustomHeader(),
          Expanded(
            child: RefreshIndicator(
              color: const Color(0xFF627D8D),
              onRefresh: _onRefresh,
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSortDropdown(),
                    const SizedBox(height: 16),
                    _buildBookGrid(),
                    if (_isLoadingMore)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24.0),
                        child: Center(child: CircularProgressIndicator(color: Color(0xFF627D8D))),
                      ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildCustomHeader() {
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10, bottom: 12),
      decoration: const BoxDecoration(color: Color(0xFF627D8D)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(fontSize: 14),
                      textInputAction: TextInputAction.search,
                      onSubmitted: _onSearch,
                      decoration: InputDecoration(
                        hintText: '搜尋書名、作者、出版社...',
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        suffixIcon: GestureDetector(
                          onTap: () => _onSearch(_searchController.text),
                          child: const Icon(Icons.search, color: Colors.grey, size: 20),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.shopping_cart_outlined, color: Colors.white),
                const SizedBox(width: 16),
                const Icon(Icons.chat_bubble_outline, color: Colors.white),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 32,
            child: NotificationListener<ScrollNotification>(
              onNotification: (ScrollNotification notification) {
                if (notification.metrics.maxScrollExtent > 0) {
                  setState(() {
                    _categoryScrollProgress = (notification.metrics.pixels / notification.metrics.maxScrollExtent).clamp(0.0, 1.0);
                  });
                }
                return false;
              },
              child: ListView.builder(
                controller: _categoryScrollController,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final isSelected = _selectedCategoryIds.contains(category.categoryId);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: GestureDetector(
                      onTap: () => _onCategoryTapped(category.categoryId),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF83A982) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            category.categoryName,
                            style: TextStyle(
                              color: isSelected ? Colors.white : const Color(0xFF333333),
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
              height: 2,
              width: double.infinity,
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.2), borderRadius: BorderRadius.circular(2)),
              alignment: Alignment(-1.0 + (_categoryScrollProgress * 2.0), 0),
              child: FractionallySizedBox(
                widthFactor: 0.3,
                child: Container(height: 2, decoration: BoxDecoration(color: const Color(0xFF83A982), borderRadius: BorderRadius.circular(2))),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSortDropdown() {
    return PopupMenuButton<String>(
      initialValue: _currentSort,
      onSelected: _onSortChanged,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      offset: const Offset(0, 36),
      itemBuilder: (BuildContext context) {
        return _sortOptions.map((String choice) {
          return PopupMenuItem<String>(
            value: choice,
            child: Text(choice, style: TextStyle(
                color: _currentSort == choice ? const Color(0xFF627D8D) : Colors.black87,
                fontWeight: _currentSort == choice ? FontWeight.bold : FontWeight.normal
            )),
          );
        }).toList();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: const Color(0xFF627D8D), borderRadius: BorderRadius.circular(8)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_currentSort, style: const TextStyle(color: Colors.white, fontSize: 14)),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildBookGrid() {
    Widget content;
    if (_isLoadingInitial) {
      content = const Center(
        key: ValueKey('loading'),
        child: Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator(color: Color(0xFF627D8D))),
      );
    } else if (_books.isEmpty) {
      content = const Center(
        key: ValueKey('empty'),
        child: Padding(padding: EdgeInsets.all(32.0), child: Text('目前沒有符合條件的書籍', style: TextStyle(color: Colors.grey))),
      );
    } else {
      content = GridView.builder(
        key: const ValueKey('grid_sorted_or_filtered'),
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.52,
        ),
        itemCount: _books.length,
        itemBuilder: (context, index) => BookCard(
          book: _books[index],
          onSearchFromDetail: (keyword) {
            _searchController.text = keyword;
            _onSearch(keyword);
          },
        ),
      );
    }
    return AnimatedSwitcher(duration: const Duration(milliseconds: 300), child: content);
  }

  Widget _buildFloatingActionButton() {
    return Container(
      height: 64, width: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF627D8D),
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: FloatingActionButton(
        onPressed: () {},
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: const Icon(Icons.add, color: Colors.white, size: 32),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, -3))],
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
          child: BottomAppBar(
            elevation: 0,
            color: Colors.white.withOpacity(0.8),
            shape: const CircularNotchedRectangle(),
            notchMargin: 8.0,
            child: SizedBox(
              height: 60,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(Icons.home_filled, 0),
                  _buildNavItem(Icons.notifications_none, 1),
                  const SizedBox(width: 48),
                  _buildNavItem(Icons.bookmark_border, 2),
                  _buildNavItem(Icons.person_outline, 3),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, int index) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Icon(icon, size: 28, color: isSelected ? const Color(0xFF627D8D) : Colors.grey),
    );
  }
}