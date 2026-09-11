import 'package:flutter/material.dart';
import '../models/book.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../widgets/animations.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/app_header.dart';
import '../widgets/app_tiles.dart';
import '../widgets/state_views.dart';
import 'book_detail_screen.dart';
import 'edit_book_screen.dart';
import 'sell_book_screen.dart';
import '../utils/motion.dart';

class BookManageScreen extends StatefulWidget {
  const BookManageScreen({super.key});

  @override
  State<BookManageScreen> createState() => _BookManageScreenState();
}

class _BookManageScreenState extends State<BookManageScreen> {
  static const _filters = [
    (key: 'all', label: '全部'),
    (key: 'on_sale', label: '販售中'),
    (key: 'reserved', label: '已預訂'),
    (key: 'sold', label: '已售出'),
    (key: 'removed', label: '已下架'),
  ];

  final ApiService _api = ApiService();
  List<Book> _books = [];
  Map<int, String> _reportStatus = {};
  bool _isLoading = true;
  String _filter = 'all';
  int? _busyBookId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      _api.fetchMyBooks(),
      _api.fetchReportStatusForMyBooks(),
    ]);
    if (!mounted) return;
    setState(() {
      _books = results[0] as List<Book>;
      _reportStatus = results[1] as Map<int, String>;
      _isLoading = false;
    });
  }

  ({String label, Color color, String detail})? _reportBadge(int bookId, AppColors c) {
    switch (_reportStatus[bookId]) {
      case 'pending':
      case 'reviewing':
        return (label: '審核中', color: c.warning, detail: '這本書被檢舉，平台正在審核，期間仍可正常販售。');
      case 'resolved':
        return (label: '違規成立', color: c.danger, detail: '這本書經審核違規成立，請確認商品內容是否符合社群規範。');
      case 'dismissed':
        return (label: '檢舉已駁回', color: c.success, detail: '這本書曾被檢舉，經審核未違規，不影響上架。');
      default:
        return null;
    }
  }

  List<Book> get _visible =>
      _filter == 'all' ? _books : _books.where((b) => b.status == _filter).toList();

  int _countOf(String key) =>
      key == 'all' ? _books.length : _books.where((b) => b.status == key).length;

  Future<void> _removeBook(Book book) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '取消上架',
      message: '《${book.title}》將從商城下架，買家不會再看到它。',
      confirmLabel: '下架',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _busyBookId = book.bookId);
    final ok = await _api.removeBook(book.bookId);
    if (!mounted) return;
    setState(() => _busyBookId = null);

    if (ok) {
      showAppSnackBar(context, '已下架，可在「已下架」分頁重新上架');
      _load();
    } else {
      showAppSnackBar(context, '下架失敗，請稍後再試', isError: true);
    }
  }

  Future<void> _relistBook(Book book) async {
    setState(() => _busyBookId = book.bookId);
    final error = await _api.relistBook(book.bookId);
    if (!mounted) return;
    setState(() => _busyBookId = null);

    if (error == null) {
      showAppSnackBar(context, '《${book.title}》已重新上架');
      _load();
    } else {
      showAppSnackBar(context, error, isError: true);
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
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SellBookScreen()),
                  );
                  _load();
                },
              ),
            ],
            bottom: _buildFilterBar(c),
          ),
          Expanded(
            child: SwitchIn(
              child: _isLoading
                  ? const LoadingView.grid()
                  : RefreshIndicator(
                      color: c.accent,
                      onRefresh: _load,
                      child: SwitchIn(child: _visible.isEmpty
                          ? ListView(key: const ValueKey('empty'), 
                              children: [
                                const SizedBox(height: 60),
                                EmptyView(
                                  icon: Icons.library_add_outlined,
                                  message: _filter == 'all'
                                      ? '你還沒有上架任何書籍'
                                      : '這個分類目前沒有書籍',
                                  actionLabel: _filter == 'all' ? '去上架第一本書' : null,
                                  onAction: _filter == 'all'
                                      ? () async {
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => const SellBookScreen(),
                                            ),
                                          );
                                          _load();
                                        }
                                      : null,
                                ),
                              ],
                            )
                          : GridView.builder(key: const ValueKey('items'), 
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 0.52,
                              ),
                              itemCount: _visible.length,
                              itemBuilder: (_, i) => RevealOnScroll(
                                index: i,
                                child: _buildCard(_visible[i], c),
                              ),
                            )),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(AppColors c) {
    return AnimatedContainer(
        duration: Motion.base,
        curve: Motion.standard,

      color: c.card,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SizedBox(
        height: 32,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _filters.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final f = _filters[i];
            final selected = _filter == f.key;
            final count = _countOf(f.key);

            return GestureDetector(
              onTap: () => setState(() => _filter = f.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? c.accent : c.categoryChip,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  count > 0 ? '${f.label} $count' : f.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                    color: selected ? Colors.white : c.accent,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCard(Book book, AppColors c) {
    final isRemoved = book.status == 'removed';
    final isBusy = _busyBookId == book.bookId;
    final badge = _reportBadge(book.bookId, c);

    Color statusColor;
    switch (book.status) {
      case 'on_sale':
        statusColor = c.success;
        break;
      case 'reserved':
        statusColor = c.warning;
        break;
      case 'sold':
        statusColor = c.accent;
        break;
      default:
        statusColor = c.textHint;
    }

    return AppCard(
      padding: EdgeInsets.zero,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => BookDetailScreen(book: book)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: SizedBox(
                  width: double.infinity,
                  height: double.infinity,
                  child: AppNetworkImage(
                    url: book.hasImage ? book.imageUrl : null,
                    fallbackIconSize: 32,
                  ),
                ),
              ),
              if (badge != null)
                Positioned(
                  left: 8,
                  top: 8,
                  child: GestureDetector(
                    onTap: () => showAppSnackBar(context, badge.detail),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: badge.color,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.flag_rounded, size: 11, color: Colors.white),
                          const SizedBox(width: 3),
                          Text(
                            badge.label,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (isRemoved)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.45),
                      alignment: Alignment.center,
                      child: const Text(
                        '已下架',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.accent),
                    ),
                    const Spacer(),
                    StatusBadge(label: book.statusText, color: statusColor, fontSize: 10),
                  ],
                ),
                const SizedBox(height: 4),
                if (book.cabinetAddress.isNotEmpty)
                  InfoLine(icon: Icons.location_on_outlined, value: book.cabinetAddress, fontSize: 10),
                if (book.cabinetOpenHours.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  InfoLine(
                    icon: Icons.schedule_rounded,
                    value: book.cabinetOpenHours,
                    maxLines: 1,
                    fontSize: 10,
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: isRemoved
                          ? SmallActionButton(
                              label: '重新上架',
                              filled: true,
                              isLoading: isBusy,
                              onTap: () => _relistBook(book),
                            )
                          : SmallActionButton(
                              label: '取消上架',
                              isLoading: isBusy,
                              onTap: book.status == 'sold' ? null : () => _removeBook(book),
                            ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: SmallActionButton(
                        label: '編輯',
                        filled: !isRemoved,
                        onTap: book.status == 'sold'
                            ? null
                            : () async {
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
