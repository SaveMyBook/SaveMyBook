import 'package:flutter/material.dart';
import '../models/book.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../widgets/app_header.dart';
import '../widgets/state_views.dart';
import 'book_detail_screen.dart';
import 'edit_book_screen.dart';
import 'sell_book_screen.dart';

/// 賣家的「書籍管理」：自己上架過的書，可再編輯或下架。
class BookManageScreen extends StatefulWidget {
  const BookManageScreen({super.key});

  @override
  State<BookManageScreen> createState() => _BookManageScreenState();
}

class _BookManageScreenState extends State<BookManageScreen> {
  final ApiService _api = ApiService();
  List<Book> _books = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final books = await _api.fetchMyBooks();
    if (!mounted) return;
    setState(() {
      _books = books;
      _isLoading = false;
    });
  }

  Future<void> _removeBook(Book book) async {
    final c = AppColors.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('取消上架', style: TextStyle(fontWeight: FontWeight.bold, color: c.textPrimary)),
        content: Text('確定要將《${book.title}》下架嗎？', style: TextStyle(color: c.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('返回', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('下架', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final ok = await _api.removeBook(book.bookId);
    if (!mounted) return;
    if (ok) {
      showAppSnackBar(context, '書籍已下架');
      _load();
    } else {
      showAppSnackBar(context, '下架失敗，請稍後再試', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          AppHeader(
            title: '書籍管理',
            icon: Icons.library_books_outlined,
            actions: [
              HeaderIconButton(
                icon: Icons.add_rounded,
                onTap: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const SellBookScreen()));
                  _load();
                },
              ),
            ],
          ),
          Expanded(
            child: _isLoading
                ? const LoadingView()
                : RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: _load,
                    child: _books.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 80),
                              EmptyView(icon: Icons.library_add_outlined, message: '你還沒有上架任何書籍'),
                            ],
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.52,
                            ),
                            itemCount: _books.length,
                            itemBuilder: (_, i) => _buildCard(_books[i], c),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Book book, AppColors c) {
    return AppCard(
      padding: EdgeInsets.zero,
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookDetailScreen(book: book))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: SizedBox(
              height: 122,
              width: double.infinity,
              child: Image.network(
                book.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: c.inputFill,
                  child: Icon(Icons.menu_book_rounded, color: c.iconInactive),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '\$${book.price.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                    const Spacer(),
                    Text(book.statusText, style: TextStyle(fontSize: 10, color: c.textHint)),
                  ],
                ),
                const SizedBox(height: 4),
                if (book.cabinetAddress.isNotEmpty)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.location_on_outlined, size: 12, color: c.iconInactive),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          book.cabinetAddress,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 10, color: c.textSecondary, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                if (book.cabinetOpenHours.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded, size: 12, color: c.iconInactive),
                      const SizedBox(width: 3),
                      Text(book.cabinetOpenHours, style: TextStyle(fontSize: 10, color: c.textSecondary)),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _SmallButton(
                        label: '取消上架',
                        onTap: book.status == 'removed' ? null : () => _removeBook(book),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _SmallButton(
                        label: '編輯',
                        filled: true,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => EditBookScreen(book: book)),
                          );
                          _load();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool filled;

  const _SmallButton({required this.label, this.onTap, this.filled = false});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final enabled = onTap != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: filled ? AppColors.primary : c.categoryChip,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: filled
                ? Colors.white
                : (enabled ? AppColors.primary : c.textHint),
          ),
        ),
      ),
    );
  }
}
