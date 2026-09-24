import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/book.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/app_forms.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_tiles.dart';
import '../../widgets/responsive.dart';
import '../../widgets/state_views.dart';
import '../../widgets/swipe_action.dart';
import '../books/book_detail_screen.dart';
import 'edit_book_screen.dart';
import 'sell_book_screen.dart';
import '../../utils/motion.dart';
import '../../i18n/strings.dart';
import '../../utils/app_labels.dart';

class BookManageScreen extends StatefulWidget {
  const BookManageScreen({super.key});

  @override
  State<BookManageScreen> createState() => _BookManageScreenState();
}

class _BookManageScreenState extends State<BookManageScreen> {
  List<({String key, String label})> get _filters => [
    (key: 'all', label: S.actionAll),
    for (final key in const ['on_sale', 'held', 'reserved', 'sold', 'removed'])
      (key: key, label: AppLabels.ownerBook(key)),
  ];

  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();
  List<Book> _books = [];
  Map<int, String> _reportStatus = {};
  final Map<int, String> _statusOverride = {};
  final Set<int> _busyIds = {};
  bool _isLoading = true;
  String _filter = 'all';
  String _keyword = '';

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
    final results = await Future.wait([_api.fetchMyBooks(), _api.fetchReportStatusForMyBooks()]);
    if (!mounted) return;
    setState(() {
      _books = results[0] as List<Book>;
      _reportStatus = results[1] as Map<int, String>;
      _statusOverride.removeWhere((id, _) => !_busyIds.contains(id));
      _isLoading = false;
    });
  }

  // held（預約保留中）、reserved（訂單已成立）、sold（訂單已完成）都不能編輯或下架。
  String _statusOf(Book book) => _statusOverride[book.bookId] ?? book.ownerStatus;

  bool _violationLocked(Book book) =>
      (!book.isApproved && !book.isPendingReview) || _reportStatus[book.bookId] == 'resolved';

  ({String label, Color color, String detail})? _reportBadge(Book book, AppColors c) {
    if (book.isPendingReview) {
      return (label: S.reportReviewing, color: c.warning, detail: S.bookUnderReviewGoSaleOnce);
    }
    if (book.isReviewRejected) {
      return (label: S.notApproved, color: c.danger, detail: S.bookDidNotPassListingReview);
    }
    switch (book.isApproved ? _reportStatus[book.bookId] : 'resolved') {
      case 'pending':
      case 'reviewing':
        return (label: S.reportReviewing, color: c.warning, detail: S.bookBeenReportedUnderReviewStays);
      case 'resolved':
        return (label: S.violationConfirmed, color: c.danger, detail: S.violationWasConfirmedBookPleaseCheck);
      default:
        return null;
    }
  }

  bool _matchesKeyword(Book b) {
    if (_keyword.isEmpty) return true;
    final key = _keyword.toLowerCase();
    return b.title.toLowerCase().contains(key) || b.author.toLowerCase().contains(key) || b.isbn.contains(key);
  }

  List<Book> get _visible =>
      _books.where((b) => (_filter == 'all' || _statusOf(b) == _filter) && _matchesKeyword(b)).toList();

  int _countOf(String key) => _books.where((b) => (key == 'all' || _statusOf(b) == key) && _matchesKeyword(b)).length;

  Future<void> _openSell() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const SellBookScreen()));
    if (mounted) _load();
  }

  Future<void> _openEdit(Book book) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => EditBookScreen(book: book)));
    if (mounted) _load();
  }

  Future<void> _delist(Book book, {required bool askFirst}) async {
    if (_busyIds.contains(book.bookId)) return;
    final status = _statusOf(book);
    final canUndo = status == 'on_sale' && !_violationLocked(book);
    if (askFirst) {
      final confirmed = await showConfirmDialog(
        context,
        title: S.delist,
        message: S.removedFromShopBuyersNoLonger(book.title),
        confirmLabel: S.delist2,
        isDestructive: true,
      );
      if (!confirmed || !mounted) return;
    }

    setState(() {
      _busyIds.add(book.bookId);
      _statusOverride[book.bookId] = 'removed';
    });
    final ok = await _api.removeBook(book.bookId);
    if (!mounted) return;
    setState(() {
      _busyIds.remove(book.bookId);
      if (!ok) _statusOverride.remove(book.bookId);
    });

    if (!ok) {
      showAppSnackBar(context, S.couldNotDelistPleaseTryAgain, isError: true);
      return;
    }
    HapticFeedback.lightImpact();
    showAppSnackBar(
      context,
      S.p0Delisted(book.title),
      actionLabel: canUndo ? S.undo : null,
      onAction: canUndo ? () => _relist(book, undo: true) : null,
    );
    _load();
  }

  Future<void> _relist(Book book, {bool undo = false}) async {
    if (_busyIds.contains(book.bookId)) return;
    setState(() {
      _busyIds.add(book.bookId);
      _statusOverride[book.bookId] = 'on_sale';
    });
    final error = await _api.relistBook(book.bookId);
    if (!mounted) return;
    setState(() {
      _busyIds.remove(book.bookId);
      if (error != null) _statusOverride.remove(book.bookId);
    });

    if (error != null) {
      showAppSnackBar(context, error, isError: true);
      _load();
      return;
    }
    HapticFeedback.lightImpact();
    showAppSnackBar(
      context,
      S.listedAgain(book.title),
      actionLabel: undo ? null : S.undo,
      onAction: undo ? null : () => _delist(book, askFirst: false),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          AppHeader(
            title: S.myBooks,
            icon: Icons.library_books_outlined,
            actions: [HeaderIconButton(icon: Icons.add_rounded, onTap: _openSell)],
            bottom: _buildFilterBar(c),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusScope.of(context).unfocus(),
              child: SwitchIn(child: _isLoading ? const LoadingView.list(key: ValueKey('loading')) : _buildBody(c)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(AppColors c) {
    final visible = _visible;

    if (visible.isEmpty) {
      final noBooks = _books.isEmpty;
      final searching = _keyword.isNotEmpty;
      return RefreshableCenter(
        key: ValueKey('empty_${_filter}_$searching'),
        onRefresh: _load,
        child: EmptyView(
          icon: searching ? Icons.search_off_rounded : Icons.library_add_outlined,
          message: searching
              ? S.noBooksMatchP0(_keyword)
              : noBooks
              ? S.notListedAnyBooksYet
              : S.noBooksCategory,
          actionLabel: searching || !noBooks ? null : S.sellBook,
          actionIcon: Icons.add_rounded,
          onAction: searching || !noBooks ? null : _openSell,
        ),
      );
    }

    final totalViews = visible.fold<int>(0, (sum, b) => sum + b.viewCount);

    return RefreshIndicator(
      key: const ValueKey('list'),
      color: c.accent,
      onRefresh: _load,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final padding = responsiveListPadding(constraints, maxWidth: Breakpoints.pageMaxWidth, top: 12, bottom: 32);
          final columns = context.isWide
              ? ((constraints.maxWidth - padding.horizontal + 12) / 372).floor().clamp(1, 4)
              : 1;
          final rowCount = (visible.length / columns).ceil();
          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: padding,
            itemCount: rowCount + 1,
            itemBuilder: (_, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          S.p0BooksP1Views(visible.length, totalViews),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.textSecondary),
                        ),
                      ),
                    ],
                  ),
                );
              }
              if (columns == 1) {
                final book = visible[i - 1];
                return RevealOnScroll(key: ValueKey(book.bookId), index: i - 1, child: _buildSwipeable(book, c));
              }
              final first = (i - 1) * columns;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var j = first; j < first + columns; j++) ...[
                    if (j > first) const SizedBox(width: 12),
                    Expanded(
                      child: j < visible.length
                          ? RevealOnScroll(
                              key: ValueKey(visible[j].bookId),
                              index: j,
                              child: _buildSwipeable(visible[j], c),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSwipeable(Book book, AppColors c) {
    final status = _statusOf(book);
    final busy = _busyIds.contains(book.bookId);
    final canEdit = status == 'on_sale' || status == 'removed';

    SwipeAction? statusAction;
    if (!busy && status == 'removed' && !_violationLocked(book)) {
      statusAction = SwipeAction(
        icon: Icons.publish_rounded,
        label: S.relist,
        color: c.success,
        onTrigger: () async {
          _relist(book);
          return false;
        },
      );
    } else if (!busy && status == 'on_sale') {
      statusAction = SwipeAction(
        icon: Icons.visibility_off_rounded,
        label: S.delist2,
        color: c.danger,
        onTrigger: () async {
          _delist(book, askFirst: false);
          return false;
        },
      );
    }

    return SwipeActionTile(
      itemKey: ValueKey('swipe_${book.bookId}'),
      endToStart: statusAction,
      startToEnd: canEdit && !busy
          ? SwipeAction(
              icon: Icons.edit_rounded,
              label: S.actionEdit,
              color: c.accent,
              onTrigger: () async {
                _openEdit(book);
                return false;
              },
            )
          : null,
      child: Padding(padding: const EdgeInsets.only(bottom: 12), child: _buildCard(book, c)),
    );
  }

  Widget _buildFilterBar(AppColors c) {
    return LayoutBuilder(
      builder: (context, constraints) =>
          _buildFilterContent(c, responsiveListPadding(constraints, maxWidth: Breakpoints.pageMaxWidth).left),
    );
  }

  Widget _buildFilterContent(AppColors c, double side) {
    return AnimatedContainer(
      duration: Motion.base,
      curve: Motion.standard,
      color: c.card,
      padding: const EdgeInsets.only(top: 10, bottom: 10),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: side),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.divider),
              ),
              child: AppSearchField(
                controller: _searchController,
                hint: S.searchTitleAuthorIsbn2,
                onChanged: (value) => setState(() => _keyword = value.trim()),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: side),
              itemCount: _filters.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final f = _filters[i];
                final selected = _filter == f.key;
                final count = _isLoading ? 0 : _countOf(f.key);

                return PressableScale(
                  scale: 0.95,
                  onTap: () {
                    if (selected) return;
                    HapticFeedback.selectionClick();
                    setState(() => _filter = f.key);
                  },
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
        ],
      ),
    );
  }

  Color _statusColor(String status, AppColors c) => switch (status) {
    'on_sale' => c.success,
    'held' => c.warning,
    'reserved' => c.accent,
    'sold' => c.neutral,
    _ => c.textHint,
  };

  Widget _buildCard(Book book, AppColors c) {
    final status = _statusOf(book);
    final isRemoved = status == 'removed';
    final isBusy = _busyIds.contains(book.bookId);
    final badge = _reportBadge(book, c);
    final statusLabel = AppLabels.ownerBook(status);
    final heldUntil = status == 'held' ? book.reservedUntil : null;
    final heldText = heldUntil == null ? '' : _formatDeadline(heldUntil);

    return AppCard(
      padding: const EdgeInsets.all(12),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookDetailScreen(book: book))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              BookThumbnail(imageUrl: book.hasImage ? book.imageUrl : null, width: 76, height: 102),
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: isRemoved ? 1 : 0,
                    duration: Motion.base,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.45),
                        alignment: Alignment.center,
                        child: const Icon(Icons.visibility_off_rounded, color: Colors.white, size: 22),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        book.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14, height: 1.35, fontWeight: FontWeight.w600, color: c.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 6),
                    SwitchIn(
                      duration: Motion.micro,
                      child: StatusBadge(
                        key: ValueKey(status),
                        label: statusLabel,
                        color: _statusColor(status, c),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '\$${book.price.toStringAsFixed(0)}',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.accent),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(Icons.visibility_outlined, size: 13, color: c.textHint),
                    const SizedBox(width: 3),
                    Text(
                      '${book.viewCount}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.textSecondary),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => showAppSnackBar(context, badge.detail),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: badge.color.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  book.reviewStatus != null ? Icons.policy_outlined : Icons.flag_rounded,
                                  size: 11,
                                  color: badge.color,
                                ),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    badge.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badge.color),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (book.cabinetAddress.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  InfoLine(icon: Icons.location_on_outlined, value: book.cabinetAddress, maxLines: 1, fontSize: 11),
                ],
                if (heldUntil != null) ...[
                  const SizedBox(height: 4),
                  InfoLine(icon: Icons.lock_clock_rounded, value: S.heldUntilP03(heldText), maxLines: 1, fontSize: 11),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: isRemoved
                          ? SmallActionButton(
                              label: S.relist,
                              filled: true,
                              isLoading: isBusy,
                              onTap: _violationLocked(book) ? null : () => _relist(book),
                            )
                          : SmallActionButton(
                              label: S.delist2,
                              isLoading: isBusy,
                              onTap: status == 'on_sale' ? () => _delist(book, askFirst: true) : null,
                            ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SmallActionButton(
                        label: S.actionEdit,
                        filled: !isRemoved,
                        onTap: status == 'on_sale' && !isBusy ? () => _openEdit(book) : null,
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

  String _formatDeadline(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.month)}/${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }
}
