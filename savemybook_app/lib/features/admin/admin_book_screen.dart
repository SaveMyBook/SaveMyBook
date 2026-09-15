import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/admin_models.dart';
import '../../models/category.dart';
import '../../services/api_service.dart';
import '../../utils/api_helpers.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_labels.dart';
import '../../utils/motion.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/app_forms.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_select.dart';
import '../../widgets/app_tiles.dart';
import '../../widgets/state_views.dart';
import '../../i18n/strings.dart';
import 'admin_layout.dart';

Future<String?> showAdminDeleteBookDialog(BuildContext context, AdminBook book) {
  return showTextInputDialog(
    context,
    title: S.deleteBook,
    message: S.p0PermanentlyDeletedCannotRestoredSeller(book.title),
    hint: S.reasonDeletionOptional,
    maxLines: 3,
    maxLength: 200,
    confirmLabel: S.actionDelete,
    isDestructive: true,
  );
}

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
  int? _deletingBookId;
  final Set<int> _removingIds = {};
  List<Category>? _categories;

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

  Future<void> _deleteBook(AdminBook book) async {
    if (_deletingBookId != null || _removingIds.contains(book.bookId)) return;
    final reason = await showAdminDeleteBookDialog(context, book);
    if (reason == null || !mounted) return;

    setState(() => _deletingBookId = book.bookId);
    final error = await _api.deleteBookAsAdmin(book.bookId, reason: reason);
    if (!mounted) return;
    setState(() => _deletingBookId = null);

    if (error != null) {
      HapticFeedback.heavyImpact();
      showAppSnackBar(context, error, isError: true);
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() => _removingIds.add(book.bookId));
    showAppSnackBar(context, S.bookDeleted2);
  }

  void _finishRemoval(int bookId) {
    if (!mounted) return;
    setState(() {
      _removingIds.remove(bookId);
      _books = _books.where((b) => b.bookId != bookId).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.scaffold,
      body: AdminLayout(
        builder: (context, frame) => Column(
          children: [
            AppHeader(title: S.myBooks, icon: Icons.menu_book_rounded),
            Padding(
              padding: frame.inset(const EdgeInsets.fromLTRB(16, 16, 16, 8)),
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
                padding: frame.inset(const EdgeInsets.symmetric(horizontal: 16)),
                itemCount: _filters.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final f = _filters[i];
                  final selected = _filter == f.key;
                  return GestureDetector(
                    onTap: () {
                      if (_filter == f.key) return;
                      HapticFeedback.selectionClick();
                      setState(() => _filter = f.key);
                      _load();
                    },
                    child: AnimatedContainer(
                      duration: Motion.micro,
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
                            ? ListView(
                                key: const ValueKey('empty'),
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  SizedBox(height: 60),
                                  EmptyView(
                                    icon: Icons.menu_book_outlined,
                                    message: S.noBooksMatch,
                                  ),
                                ],
                              )
                            : ListView.builder(
                                key: const ValueKey('items'),
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: frame.inset(const EdgeInsets.fromLTRB(16, 12, 16, 24)),
                                itemCount: _books.length,
                                itemBuilder: (_, i) {
                                  final book = _books[i];
                                  return _CollapseOnRemove(
                                    key: ValueKey(book.bookId),
                                    removing: _removingIds.contains(book.bookId),
                                    onRemoved: () => _finishRemoval(book.bookId),
                                    child: RevealOnScroll(
                                      index: i,
                                      child: _buildCard(book, c, wide: frame.isWide),
                                    ),
                                  );
                                },
                              )),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editBook(AdminBook book) async {
    final categories = _categories ?? await runBusy(context, _api.fetchCategories);
    if (!mounted) return;
    if (categories == null) {
      showAppSnackBar(context, AppLabels.loadFailed, isError: true);
      return;
    }
    _categories = categories;

    final title = TextEditingController(text: book.title);
    final author = TextEditingController(text: book.author ?? '');
    final publisher = TextEditingController(text: book.publisher ?? '');
    final isbn = TextEditingController(text: book.isbn ?? '');
    final price = TextEditingController(text: book.price > 0 ? book.price.toStringAsFixed(0) : '');
    final description = TextEditingController(text: book.description ?? '');
    final controllers = [title, author, publisher, isbn, price, description];
    var condition = book.conditionLevel;
    var categoryId = book.categoryId ?? 0;
    String? titleError;
    String? isbnError;

    final c = AppColors.of(context);
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: c.sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(ctx).unfocus(),
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(20, 10, 20, 24 + MediaQuery.of(ctx).padding.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: c.iconInactive.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    S.editBookDetails,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    S.sellerP0TheyNotifiedSave(book.sellerName),
                    style: TextStyle(fontSize: 12, color: c.textHint),
                  ),
                  const SizedBox(height: 16),
                  _sheetLabel(S.title, c),
                  AppTextField(
                    controller: title,
                    hint: S.title,
                    maxLength: 255,
                    errorText: titleError,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) {
                      if (titleError != null) setSheetState(() => titleError = null);
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sheetLabel(S.author2, c),
                            AppTextField(
                              controller: author,
                              hint: S.author2,
                              maxLength: 255,
                              textInputAction: TextInputAction.next,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sheetLabel(S.publisher2, c),
                            AppTextField(
                              controller: publisher,
                              hint: S.publisher2,
                              maxLength: 255,
                              textInputAction: TextInputAction.next,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sheetLabel(S.priceCoins, c),
                            AppTextField(
                              controller: price,
                              hint: '0',
                              keyboardType: TextInputType.number,
                              inputFormatters: const [PriceInputFormatter(max: 999999)],
                              textInputAction: TextInputAction.next,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sheetLabel('ISBN', c),
                            AppTextField(
                              controller: isbn,
                              hint: S.k1013Digits2,
                              keyboardType: TextInputType.number,
                              errorText: isbnError,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'[0-9Xx]')),
                                TextInputFormatter.withFunction(
                                  (_, value) => value.copyWith(text: value.text.toUpperCase()),
                                ),
                              ],
                              maxLength: 13,
                              textInputAction: TextInputAction.done,
                              onChanged: (_) {
                                if (isbnError != null) setSheetState(() => isbnError = null);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _sheetLabel(S.category, c),
                  AppSelect<int>(
                    value: categoryId,
                    title: S.category,
                    leadingIcon: Icons.category_outlined,
                    options: [
                      AppSelectOption(value: 0, label: S.uncategorised),
                      for (final cat in categories) AppSelectOption(value: cat.categoryId, label: cat.categoryName),
                    ],
                    onChanged: (value) => setSheetState(() => categoryId = value),
                  ),
                  const SizedBox(height: 12),
                  _sheetLabel(S.condition, c),
                  AppSelect<String>(
                    value: condition,
                    title: S.condition,
                    options: [
                      for (final e in AppLabels.condition.entries)
                        AppSelectOption(
                          value: e.key,
                          label: e.value,
                          icon: Icons.menu_book_rounded,
                          iconColor: c.conditionColor(e.key),
                        ),
                    ],
                    onChanged: (value) => setSheetState(() => condition = value),
                  ),
                  const SizedBox(height: 12),
                  _sheetLabel(S.description2, c),
                  AppTextField(
                    controller: description,
                    hint: S.description2,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 2000,
                    keyboardType: TextInputType.multiline,
                  ),
                  const SizedBox(height: 18),
                  PrimaryButton(
                    label: S.actionSave,
                    height: 46,
                    onPressed: () {
                      final isbnText = isbn.text.trim();
                      setSheetState(() {
                        titleError = title.text.trim().isEmpty ? S.titleRequired : null;
                        isbnError = isbnText.isNotEmpty &&
                                isbnText != (book.isbn ?? '').trim() &&
                                normalizeIsbn(isbnText) == null
                            ? S.isbn1013Digits
                            : null;
                      });
                      if (titleError != null || isbnError != null) {
                        HapticFeedback.heavyImpact();
                        return;
                      }
                      Navigator.pop(ctx, true);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final fields = <String, dynamic>{};
    if (saved == true) {
      void put(String key, String value, String? original) {
        if (value.trim() != (original ?? '').trim()) fields[key] = value.trim();
      }

      put('title', title.text, book.title);
      put('author', author.text, book.author);
      put('publisher', publisher.text, book.publisher);
      put('isbn', isbn.text, book.isbn);
      put('description', description.text, book.description);

      final newPrice = double.tryParse(price.text.trim());
      if (newPrice != null && newPrice != book.price) fields['price'] = newPrice;
      if (condition != book.conditionLevel) fields['condition_level'] = condition;
      if (categoryId != (book.categoryId ?? 0)) {
        fields['category_id'] = categoryId == 0 ? null : categoryId;
      }
    }

    // 底部面板關閉動畫期間 TextField 仍握著 controller，立刻 dispose 會觸發 used-after-dispose。
    Future.delayed(const Duration(milliseconds: 800), () {
      for (final ctl in controllers) {
        ctl.dispose();
      }
    });

    if (saved != true || !mounted) return;

    if (fields.isEmpty) {
      showAppSnackBar(context, S.nothingChanged);
      return;
    }

    final error = await runBusy(context, () => _api.updateAdminBook(book.bookId, fields));
    if (!mounted) return;

    if (error != null) {
      showAppSnackBar(context, error, isError: true);
    } else {
      HapticFeedback.mediumImpact();
      showAppSnackBar(context, S.updated);
      _load();
    }
  }

  Widget _sheetLabel(String text, AppColors c) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.textSecondary),
        ),
      );

  Widget _deleteButton(AdminBook book, AppColors c) => SmallActionButton(
        label: S.deleteBook,
        color: c.danger,
        isLoading: _deletingBookId == book.bookId,
        onTap: _removingIds.contains(book.bookId) ? null : () => _deleteBook(book),
      );

  Widget _buildCard(AdminBook book, AppColors c, {bool wide = false}) {
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
                      S.isbnP0P1Views(book.isbn?.isNotEmpty == true ? book.isbn! : S.notProvided, book.viewCount),
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
                  Flexible(
                    child: Text(
                    S.p0ReportsAwaitingReview(book.pendingReportCount),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: c.danger,
                    ),
                  ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          if (wide)
            Row(
              children: [
                Expanded(
                  child: Text(
                    formatDateTime(book.createdAt),
                    style: TextStyle(fontSize: 11, color: c.textHint),
                  ),
                ),
                IntrinsicWidth(
                  child: SmallActionButton(
                    label: S.actionEdit,
                    color: c.accent,
                    onTap: () => _editBook(book),
                  ),
                ),
                const SizedBox(width: 8),
                IntrinsicWidth(child: _deleteButton(book, c)),
                const SizedBox(width: 8),
                IntrinsicWidth(
                  child: SmallActionButton(
                    label: removed ? S.relist2 : S.forceDelist,
                    filled: true,
                    color: removed ? c.success : c.danger,
                    isLoading: _busyBookId == book.bookId,
                    onTap: () => _toggleStatus(book),
                  ),
                ),
              ],
            )
          else
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    formatDateTime(book.createdAt),
                    style: TextStyle(fontSize: 11, color: c.textHint),
                  ),
                ),
                IntrinsicWidth(
                  child: SmallActionButton(
                    label: S.actionEdit,
                    color: c.accent,
                    onTap: () => _editBook(book),
                  ),
                ),
                IntrinsicWidth(child: _deleteButton(book, c)),
                IntrinsicWidth(
                  child: SmallActionButton(
                    label: removed ? S.relist2 : S.forceDelist,
                    filled: true,
                    color: removed ? c.success : c.danger,
                    isLoading: _busyBookId == book.bookId,
                    onTap: () => _toggleStatus(book),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _CollapseOnRemove extends StatefulWidget {
  final bool removing;
  final VoidCallback onRemoved;
  final Widget child;

  const _CollapseOnRemove({super.key, required this.removing, required this.onRemoved, required this.child});

  @override
  State<_CollapseOnRemove> createState() => _CollapseOnRemoveState();
}

class _CollapseOnRemoveState extends State<_CollapseOnRemove> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Motion.enter,
    value: 1,
  );
  late final Animation<double> _size = CurvedAnimation(parent: _controller, curve: const Interval(0, 0.6, curve: Motion.standard));
  late final Animation<double> _fade = CurvedAnimation(parent: _controller, curve: const Interval(0.5, 1, curve: Curves.easeOut));
  late final Animation<Offset> _slide = Tween(begin: const Offset(0.08, 0), end: Offset.zero)
      .animate(CurvedAnimation(parent: _controller, curve: const Interval(0.4, 1, curve: Motion.exitCurve)));

  @override
  void initState() {
    super.initState();
    if (widget.removing) _collapse();
  }

  @override
  void didUpdateWidget(covariant _CollapseOnRemove oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.removing && !oldWidget.removing) _collapse();
  }

  void _collapse() {
    _controller.reverse().whenComplete(() {
      if (mounted) widget.onRemoved();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: _size,
      axisAlignment: -1,
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(position: _slide, child: widget.child),
      ),
    );
  }
}
