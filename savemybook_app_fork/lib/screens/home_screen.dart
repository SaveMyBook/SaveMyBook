import 'package:flutter/material.dart';
import '../models/category.dart';
import '../models/book.dart';
import '../services/api_service.dart';
import '../widgets/book_card.dart';
import '../widgets/custom_bottom_nav.dart';
import '../widgets/search_bar_widget.dart';

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
  String _currentKeyword = '';
  final List<String> _sortOptions = ['最新上架', '熱門推薦', '價格由低到高', '價格由高到低'];

  List<Category> _categories = [];
  List<Book> _books = [];

  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();

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
    final newBooks = await _apiService.fetchBooks(page: 1, categoryIds: _selectedCategoryIds, sort: _currentSort, keyword: _currentKeyword);
    setState(() {
      _books = newBooks;
      _hasMoreData = (newBooks.length >= 20);
    });
  }

  Future<void> _loadMoreData() async {
    setState(() => _isLoadingMore = true);
    try {
      _currentPage++;
      final moreBooks = await _apiService.fetchBooks(page: _currentPage, categoryIds: _selectedCategoryIds, sort: _currentSort, keyword: _currentKeyword);
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

  void _onSortChanged(String newSort) {
    setState(() {
      _currentSort = newSort;
      _isLoadingInitial = true;
    });
    _onRefresh().then((_) {
      if (mounted) setState(() => _isLoadingInitial = false);
    });
  }

  void _onSearchChanged(String keyword) {
    setState(() {
      _currentKeyword = keyword;
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    _buildCategories(),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                      child: Divider(color: Color(0xFFE0E0E0), thickness: 1),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: _buildSortDropdown(),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: _buildBookGrid(),
                    ),
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
      floatingActionButton: const CustomFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: CustomBottomNav(
        selectedIndex: _selectedIndex,
        onItemSelected: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }

  Widget _buildCustomHeader() {
    final userName = ApiService.currentUser?.nickname ?? '訪客';
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF627D8D),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.only(top: 8.0, bottom: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('哈囉, $userName', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                    const Row(
                      children: [
                        Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 26),
                        SizedBox(width: 16),
                        Icon(Icons.chat_bubble_outline, color: Colors.white, size: 24),
                      ],
                    )
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: SearchBarWidget(
                  currentKeyword: _currentKeyword,
                  onSearch: _onSearchChanged,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategories() {
    return SizedBox(
      height: 36,
      child: Scrollbar(
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _categories.length,
          itemBuilder: (context, index) {
            final category = _categories[index];
            final isSelected = _selectedCategoryIds.contains(category.categoryId);
            return Padding(
              padding: const EdgeInsets.only(right: 10.0),
              child: GestureDetector(
                onTap: () => _onCategoryTapped(category.categoryId),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8ECEF),
                    border: Border.all(
                        color: isSelected ? const Color(0xFF627D8D) : Colors.transparent,
                        width: 1.5
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      category.categoryName,
                      style: TextStyle(
                        color: const Color(0xFF627D8D),
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
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
          crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.58,
        ),
        itemCount: _books.length,
        itemBuilder: (context, index) => BookCard(book: _books[index]),
      );
    }
    return AnimatedSwitcher(duration: const Duration(milliseconds: 300), child: content);
  }
}