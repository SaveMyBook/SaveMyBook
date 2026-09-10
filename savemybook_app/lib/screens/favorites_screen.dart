import 'package:flutter/material.dart';
import '../models/book.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../widgets/animations.dart';
import '../widgets/app_header.dart';
import '../widgets/book_card.dart';
import '../widgets/state_views.dart';
import 'cart_screen.dart';
import 'chat_list_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final ApiService _api = ApiService();
  List<Book> _books = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final books = await _api.fetchFavorites();
    if (!mounted) return;
    setState(() {
      _books = books;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          AppHeader(
            title: '收藏書籍',
            icon: Icons.bookmark_outline_rounded,
            actions: [
              CartIconButton(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen())),
              ),
              ChatIconButton(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatListScreen())),
              ),
            ],
          ),
          Expanded(
            child: SwitchIn(child: _isLoading
                ? const LoadingView()
                : RefreshIndicator(
                    color: c.accent,
                    onRefresh: _load,
                    child: _books.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 80),
                              EmptyView(
                                icon: Icons.bookmark_outline_rounded,
                                message: '還沒有收藏任何書籍\n點書籍卡片上的書籤就能收藏',
                              ),
                            ],
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.58,
                            ),
                            itemCount: _books.length,
                            itemBuilder: (_, i) => FadeSlideIn(index: i, child: BookCard(book: _books[i])),
                          ),
                  )),
          ),
        ],
      ),
    );
  }
}
