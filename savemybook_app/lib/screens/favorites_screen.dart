import 'package:flutter/material.dart';
import '../models/book.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../widgets/animations.dart';
import '../widgets/app_header.dart';
import '../widgets/book_card.dart';
import '../widgets/buyer/back_to_top_button.dart';
import '../widgets/buyer/undo_snackbar.dart';
import '../widgets/state_views.dart';
import 'cart_screen.dart';
import 'chat_list_screen.dart';
import '../i18n/strings.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final ApiService _api = ApiService();
  final ScrollController _scrollController = ScrollController();
  List<Book> _books = [];
  bool _isLoading = true;
  bool _reloadQueued = false;
  bool _fetching = false;
  late Set<int> _knownIds = ApiService.favoriteBookIds.value;

  @override
  void initState() {
    super.initState();
    ApiService.favoriteBookIds.addListener(_onFavoritesChanged);
    _load();
  }

  @override
  void dispose() {
    ApiService.favoriteBookIds.removeListener(_onFavoritesChanged);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    _fetching = true;
    final books = await _api.fetchFavorites();
    _fetching = false;
    if (!mounted) return;
    _knownIds = ApiService.favoriteBookIds.value;
    setState(() {
      _books = books;
      _isLoading = false;
    });
  }

  void _onFavoritesChanged() {
    if (!mounted || _isLoading || _fetching) return;
    final next = ApiService.favoriteBookIds.value;
    final removed = _books.where((b) => _knownIds.contains(b.bookId) && !next.contains(b.bookId)).toList();
    final added = next.any((id) => !_books.any((b) => b.bookId == id));
    _knownIds = next;
    setState(() {});

    if (added && !_reloadQueued) {
      _reloadQueued = true;
      Future.delayed(const Duration(milliseconds: 400), () {
        _reloadQueued = false;
        if (mounted) _load();
      });
    }

    if (removed.length == 1 && (ModalRoute.of(context)?.isCurrent ?? false)) {
      _offerUndo(removed.first);
    }
  }

  Future<void> _offerUndo(Book book) async {
    final undo = await showUndoSnackBar(context, S.removedP0FromSaved(book.title), icon: Icons.bookmark_remove_outlined);
    if (!undo) return;
    final ok = await _api.addFavorite(book.bookId);
    if (!ok && mounted) showAppSnackBar(context, S.couldNotSave, isError: true);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final ids = ApiService.favoriteBookIds.value;
    final books = _books.where((b) => ids.contains(b.bookId)).toList();

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          AppHeader(
            title: S.savedBooks,
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
            child: SwitchIn(
              child: _isLoading
                  ? const LoadingView.grid()
                  : Stack(
                      key: const ValueKey('content'),
                      children: [
                        RefreshIndicator(
                          color: c.accent,
                          onRefresh: _load,
                          child: SwitchIn(
                            child: books.isEmpty
                                ? ListView(
                                    key: const ValueKey('empty'),
                                    physics: const AlwaysScrollableScrollPhysics(),
                                    children: [
                                      const SizedBox(height: 80),
                                      EmptyView(
                                        icon: Icons.bookmark_outline_rounded,
                                        message: S.notSavedAnyBooksYet,
                                      ),
                                    ],
                                  )
                                : GridView.builder(
                                    key: const ValueKey('items'),
                                    controller: _scrollController,
                                    physics: const AlwaysScrollableScrollPhysics(),
                                    padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 24),
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12,
                                      mainAxisExtent: BookCard.gridHeight,
                                    ),
                                    itemCount: books.length,
                                    itemBuilder: (_, i) => RevealOnScroll(
                                      key: ValueKey(books[i].bookId),
                                      index: i,
                                      child: BookCard(book: books[i]),
                                    ),
                                  ),
                          ),
                        ),
                        if (books.isNotEmpty)
                          Positioned(
                            right: 16,
                            bottom: MediaQuery.of(context).padding.bottom + 16,
                            child: BackToTopButton(controller: _scrollController, threshold: 600),
                          ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
