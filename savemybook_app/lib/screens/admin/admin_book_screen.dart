import 'package:flutter/material.dart';
import '../../models/admin_models.dart';
import '../../services/api_service.dart';
import '../../utils/api_helpers.dart';
import '../../utils/app_colors.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/app_forms.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_tiles.dart';
import '../../widgets/state_views.dart';
import '../../i18n/strings.dart';

class AdminBookScreen extends StatefulWidget {
  const AdminBookScreen({super.key});

  @override
  State<AdminBookScreen> createState() => _AdminBookScreenState();
}

class _AdminBookScreenState extends State<AdminBookScreen> {
  List<({String key, String label})> get _filters => [
    (key: 'all', label: S.actionAll),
    (key: 'on_sale', label: S.bookOnSale),
    (key: 'reserved', label: S.bookReserved),
    (key: 'sold', label: S.bookSold),
    (key: 'removed', label: S.bookRemoved),
  ];

  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();

  List<AdminBook> _books = [];
  String _filter = 'all';
  bool _isLoading = true;
  int? _busyBookId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final books = await _api.fetchAdminBooks(
      keyword: _searchController.text.trim(),
      status: _filter,
    );
    if (!mounted) return;
    setState(() {
      _books = books;
      _isLoading = false;
    });
  }

  Future<void> _toggleStatus(AdminBook book) async {
    final removing = book.status != 'removed';

    String? reason;
    if (removing) {
      reason = await showTextInputDialog(
        context,
        title: S.forceDelist,
        hint: S.reasonDelistingSellerNotified,
        maxLines: 3,
        confirmLabel: S.delist3,
      );
      if (reason == null || !mounted) return;
    } else {
      final ok = await showConfirmDialog(
        context,
        title: S.relist2,
        message: S.putP0BackStore(book.title),
        confirmLabel: S.relist2,
      );
      if (!ok || !mounted) return;
    }

    setState(() => _busyBookId = book.bookId);
    final error = await _api.setBookStatusAsAdmin(
      book.bookId,
      removing ? 'removed' : 'on_sale',
      reason: reason,
    );
    if (!mounted) return;
    setState(() => _busyBookId = null);

    if (error != null) {
      showAppSnackBar(context, error, isError: true);
    } else {
      showAppSnackBar(context, removing ? S.bookRemoved : S.relisted);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          AppHeader(title: S.myBooks, icon: Icons.menu_book_rounded),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: AppSearchField(
              controller: _searchController,
              hint: S.searchTitleIsbnSeller,
              onSubmitted: (_) => _load(),
            ),
          ),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filters.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final f = _filters[i];
                final selected = _filter == f.key;
                return GestureDetector(
                  onTap: () {
                    setState(() => _filter = f.key);
                    _load();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? c.accent : c.categoryChip,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      f.label,
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
          Expanded(
            child: SwitchIn(
              child: _isLoading
                  ? const LoadingView.list()
                  : RefreshIndicator(
                      color: c.accent,
                      onRefresh: _load,
                      child: SwitchIn(child: _books.isEmpty
                          ? ListView(key: const ValueKey('empty'), 
                              children: [
                                SizedBox(height: 60),
                                EmptyView(
                                  icon: Icons.menu_book_outlined,
                                  message: S.noBooksMatch,
                                ),
                              ],
                            )
                          : ListView.builder(key: const ValueKey('items'), 
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                              itemCount: _books.length,
                              itemBuilder: (_, i) => RevealOnScroll(
                                index: i,
                                child: _buildCard(_books[i], c),
                              ),
                            )),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(AdminBook book, AppColors c) {
    final removed = book.status == 'removed';
    final categoryText = book.categoryName.isEmpty ? S.uncategorised : book.categoryName;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BookThumbnail(imageUrl: book.imageUrl, width: 52, height: 68, radius: 8),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            book.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: c.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusBadge(
                          label: book.statusText,
                          color: removed ? c.danger : c.success,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      S.sellerP0P1(book.sellerName, categoryText),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: c.textSecondary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      S.isbnP0P1Views(book.isbn?.isNotEmpty == true ? book.isbn : S.notProvided, book.viewCount),
                      style: TextStyle(fontSize: 11, color: c.textHint),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '\$${book.price.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: c.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (book.pendingReportCount > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: c.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.flag_rounded, size: 14, color: c.danger),
                  const SizedBox(width: 6),
                  Text(
                    S.p0ReportsAwaitingReview(book.pendingReportCount),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: c.danger,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                formatDateTime(book.createdAt),
                style: TextStyle(fontSize: 11, color: c.textHint),
              ),
              const Spacer(),
              SmallActionButton(
                label: removed ? S.relist2 : S.forceDelist,
                filled: true,
                color: removed ? c.success : c.danger,
                isLoading: _busyBookId == book.bookId,
                onTap: () => _toggleStatus(book),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
