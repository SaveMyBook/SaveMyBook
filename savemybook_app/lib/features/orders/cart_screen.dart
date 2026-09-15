import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/verification_service.dart';
import '../../models/cart_item.dart';
import '../../models/member_level.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_tiles.dart';
import '../../widgets/responsive.dart';
import '../../widgets/state_views.dart';
import '../../widgets/swipe_action.dart';
import '../../widgets/buyer/undo_snackbar.dart';
import '../books/book_detail_screen.dart';
import 'purchase_history_screen.dart';
import 'widgets/sticky_pane.dart';
import '../books/seller_screen.dart';
import '../account/wallet_screen.dart';
import '../../utils/motion.dart';
import '../../i18n/strings.dart';

sealed class _Row {
  const _Row();
}

class _SellerRow extends _Row {
  final int sellerId;
  final String name;
  final String? avatarUrl;
  final List<CartItem> items;
  const _SellerRow(this.sellerId, this.name, this.avatarUrl, this.items);
}

class _UnavailableRow extends _Row {
  final List<CartItem> items;
  const _UnavailableRow(this.items);
}

class _ItemRow extends _Row {
  final CartItem item;
  final bool available;
  const _ItemRow(this.item, this.available);
}

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final ApiService _api = ApiService();
  final ScrollController _wideScrollController = ScrollController();
  List<CartItem> _items = [];
  final Set<int> _pendingRemoval = {};
  bool _isLoading = true;
  bool _loadFailed = false;
  bool _isCheckingOut = false;
  double _balance = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _wideScrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final previousSelection = {for (final item in _items) item.cartId: item.isSelected};
    final results = await Future.wait([_api.fetchCart(), _api.fetchUserStats()]);
    if (!mounted) return;
    final items = results[0] as List<CartItem>;
    final stats = results[1] as UserStats;
    for (final item in items) {
      item.isSelected = _isAvailable(item) && (previousSelection[item.cartId] ?? true);
    }
    setState(() {
      _items = items;
      _balance = stats.balance;
      _loadFailed = items.isEmpty && ApiService.cartCount.value > 0;
      _isLoading = false;
    });
  }

  bool _isAvailable(CartItem item) {
    final myId = ApiService.currentUser?.userId;
    return item.book.status == 'on_sale' && (myId == null || item.book.sellerId != myId);
  }

  String _unavailableReason(CartItem item) {
    if (item.book.status != 'on_sale') return item.book.statusText;
    return S.listing;
  }

  List<CartItem> get _visibleItems => _items.where((i) => !_pendingRemoval.contains(i.cartId)).toList();

  List<CartItem> get _availableItems => _visibleItems.where(_isAvailable).toList();

  List<CartItem> get _unavailableItems => _visibleItems.where((i) => !_isAvailable(i)).toList();

  List<CartItem> get _selectedItems => _availableItems.where((i) => i.isSelected).toList();

  double get _total => _selectedItems.fold(0, (sum, i) => sum + i.subtotal);

  bool get _canAfford => _balance >= _total;

  bool get _allSelected {
    final available = _availableItems;
    return available.isNotEmpty && available.every((i) => i.isSelected);
  }

  void _setSelected(Iterable<CartItem> items, bool value) {
    HapticFeedback.selectionClick();
    setState(() {
      for (final item in items) {
        if (_isAvailable(item)) item.isSelected = value;
      }
    });
  }

  List<_Row> _buildRows() {
    final rows = <_Row>[];
    final groups = <int, List<CartItem>>{};
    for (final item in _availableItems) {
      groups.putIfAbsent(item.book.sellerId, () => []).add(item);
    }
    for (final entry in groups.entries) {
      final first = entry.value.first.book;
      rows.add(_SellerRow(entry.key, first.sellerName, first.sellerAvatarUrl, entry.value));
      for (final item in entry.value) {
        rows.add(_ItemRow(item, true));
      }
    }
    final unavailable = _unavailableItems;
    if (unavailable.isNotEmpty) {
      rows.add(_UnavailableRow(unavailable));
      for (final item in unavailable) {
        rows.add(_ItemRow(item, false));
      }
    }
    return rows;
  }

  Future<void> _removeWithUndo(List<CartItem> items) async {
    if (items.isEmpty) return;
    HapticFeedback.mediumImpact();
    // 滑動刪除的項目必須在 await 之前移出清單，否則 Dismissible 會因為已 dismiss 的 widget 還在樹上而丟例外。
    setState(() => _pendingRemoval.addAll(items.map((i) => i.cartId)));

    final message = items.length == 1 ? S.removedP0(items.first.book.title) : S.removedP0Items(items.length);
    final undo = await showUndoSnackBar(context, message);
    if (undo) {
      if (mounted) setState(() => _pendingRemoval.removeAll(items.map((i) => i.cartId)));
      return;
    }

    final results = await Future.wait(items.map((i) => _api.removeCartItem(i.cartId, bookId: i.book.bookId)));
    if (!mounted) return;
    final failed = <int>{for (var i = 0; i < items.length; i++) if (!results[i]) items[i].cartId};
    setState(() {
      _pendingRemoval.removeAll(items.map((i) => i.cartId));
      _items.removeWhere((i) => items.any((r) => r.cartId == i.cartId) && !failed.contains(i.cartId));
    });
    if (failed.isNotEmpty) showAppSnackBar(context, S.couldNotRemoveRestored, isError: true);
  }

  Future<void> _openWallet() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen()));
    if (mounted) _load();
  }

  Future<void> _checkout() async {
    if (_isCheckingOut) return;
    final selected = _selectedItems;
    if (selected.isEmpty) {
      showAppSnackBar(context, S.selectBooksWantCheckOut, isError: true);
      return;
    }

    final total = _total;
    if (_balance < total) {
      showAppSnackBar(
        context,
        S.notEnoughCoinsOrderNeedsBut(total.toStringAsFixed(0), _balance.toStringAsFixed(0)),
        isError: true,
      );
      return;
    }

    HapticFeedback.lightImpact();
    setState(() => _isCheckingOut = true);
    VerificationService.paymentSummary = PaymentSummary(
      amount: total,
      detail: S.booksTotal(selected.length, total.toStringAsFixed(0)) +
          S.balanceAfterPaymentCoins((_balance - total).toStringAsFixed(0)),
    );
    String? error;
    try {
      error = await _api.checkout(selected.map((i) => i.cartId).toList());
    } finally {
      VerificationService.paymentSummary = null;
    }
    if (!mounted) return;
    setState(() => _isCheckingOut = false);

    if (error != null) {
      if (error.isNotEmpty) {
        showAppSnackBar(context, error, isError: true);
        _load();
      }
      return;
    }

    HapticFeedback.heavyImpact();
    final sellerCount = selected.map((i) => i.book.sellerId).toSet().length;
    _load();
    final viewOrders = await _showPaymentSuccess(total: total, count: selected.length, sellerCount: sellerCount);
    if (!mounted) return;
    if (viewOrders == true) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const PurchaseHistoryScreen()));
    }
  }

  Future<bool?> _showPaymentSuccess({required double total, required int count, required int sellerCount}) {
    final c = AppColors.of(context);
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: c.scrim,
      transitionDuration: Motion.enter,
      transitionBuilder: (_, animation, _, child) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween(begin: 0.9, end: 1.0).animate(CurvedAnimation(parent: animation, curve: Motion.emphasized)),
          child: child,
        ),
      ),
      pageBuilder: (ctx, _, _) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Material(
            color: c.card,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DrawnCheck(color: c.success, size: 88),
                  const SizedBox(height: 18),
                  FadeSlideIn(
                    index: 3,
                    child: Text(
                      S.paymentSuccessful,
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: c.textPrimary),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FadeSlideIn(
                    index: 4,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: AnimatedCount(
                        value: total,
                        prefix: '-',
                        style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: c.accent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FadeSlideIn(
                    index: 5,
                    child: Text(
                      sellerCount > 1
                          ? S.p0BooksSplitIntoP1Orders(count, sellerCount)
                          : S.orderPlacedSellerDropBookOff,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, height: 1.5, color: c.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 22),
                  PrimaryButton(
                    label: S.viewOrder,
                    icon: Icons.receipt_long_rounded,
                    onPressed: () => Navigator.pop(ctx, true),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: TextButton.styleFrom(foregroundColor: c.textSecondary),
                    child: Text(S.keepBrowsing),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final visible = _visibleItems;
    final unavailable = _unavailableItems;
    final expanded = context.screenSize == ScreenSize.expanded;

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          AppHeader(
            title: S.cart,
            icon: Icons.shopping_cart_outlined,
            actions: [
              if (unavailable.isNotEmpty)
                HeaderIconButton(
                  icon: Icons.cleaning_services_outlined,
                  onTap: () => _removeWithUndo(unavailable),
                ),
            ],
          ),
          if (!expanded)
            LayoutBuilder(
              builder: (context, constraints) {
                final side = responsiveListPadding(constraints, maxWidth: Breakpoints.readingMaxWidth).left;
                return Reveal(
                  visible: _availableItems.isNotEmpty,
                  child: _buildSelectAllRow(c, padding: EdgeInsets.fromLTRB(side, 10, side, 2)),
                );
              },
            ),
          Expanded(
            child: SwitchIn(
              child: _isLoading
                  ? const LoadingView.list()
                  : RefreshIndicator(
                      color: c.accent,
                      onRefresh: _load,
                      child: SwitchIn(
                        child: visible.isEmpty
                            ? ListView(
                                key: ValueKey(_loadFailed ? 'failed' : 'empty'),
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  const SizedBox(height: 80),
                                  _loadFailed
                                      ? EmptyView(
                                          icon: Icons.cloud_off_rounded,
                                          message: S.loadFailed,
                                          actionLabel: S.reload,
                                          onAction: () {
                                            setState(() => _isLoading = true);
                                            _load();
                                          },
                                        )
                                      : EmptyView(
                                          icon: Icons.remove_shopping_cart_outlined,
                                          message: S.cartEmpty,
                                          actionLabel: S.browseBooks,
                                          onAction: () => Navigator.maybePop(context),
                                        ),
                                ],
                              )
                            : expanded
                                ? _buildWideLayout(c)
                                : _buildList(c),
                      ),
                    ),
            ),
          ),
          if (visible.isNotEmpty && !expanded) _buildCheckoutBar(c),
        ],
      ),
    );
  }

  Widget _buildList(AppColors c) {
    final rows = _buildRows();
    return LayoutBuilder(
      key: const ValueKey('items'),
      builder: (context, constraints) => ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: responsiveListPadding(constraints, maxWidth: Breakpoints.readingMaxWidth, top: 4),
        itemCount: rows.length,
        itemBuilder: (_, i) => _buildRow(c, rows[i], i),
      ),
    );
  }

  Widget _buildRow(AppColors c, _Row row, int index) {
    return RevealOnScroll(
      key: ValueKey(switch (row) {
        _SellerRow(:final sellerId) => 'seller_$sellerId',
        _UnavailableRow() => 'unavailable',
        _ItemRow(:final item) => 'item_${item.cartId}',
      }),
      index: index,
      child: switch (row) {
        _SellerRow() => _buildSellerHeader(c, row),
        _UnavailableRow() => _buildUnavailableHeader(c, row),
        _ItemRow() => _buildItem(row, c),
      },
    );
  }

  Widget _buildWideLayout(AppColors c) {
    const panelWidth = 360.0;
    const gap = 24.0;
    final rows = _buildRows();

    return LayoutBuilder(
      key: const ValueKey('items_wide'),
      builder: (context, constraints) {
        final padding = responsiveListPadding(constraints, maxWidth: 1120, horizontal: 32, top: 16, bottom: 24);
        return SingleChildScrollView(
          controller: _wideScrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: padding,
          child: Stack(
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - padding.vertical),
                child: Padding(
                  padding: const EdgeInsets.only(right: panelWidth + gap),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Reveal(
                        visible: _availableItems.isNotEmpty,
                        child: _buildSelectAllRow(c, padding: const EdgeInsets.only(bottom: 2)),
                      ),
                      for (var i = 0; i < rows.length; i++) _buildRow(c, rows[i], i),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 0,
                bottom: 0,
                right: 0,
                width: panelWidth,
                child: StickyPane(
                  controller: _wideScrollController,
                  child: _buildCheckoutBar(c, panel: true),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSelectAllRow(AppColors c, {required EdgeInsets padding}) {
    final available = _availableItems;
    final sellers = available.map((i) => i.book.sellerId).toSet().length;
    final sellersLabel = S.p0Sellers(sellers);

    return Padding(
      padding: padding,
      child: Row(
        children: [
          _buildCheckbox(
            value: _allSelected,
            c: c,
            onChanged: (value) => _setSelected(available, value),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _setSelected(available, !_allSelected),
            child: Text(
              S.selectAll,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              sellers > 1 ? '${S.items(available.length)} · $sellersLabel' : S.items(available.length),
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: c.textHint),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckbox({
    required bool value,
    required AppColors c,
    required ValueChanged<bool>? onChanged,
  }) {
    final enabled = onChanged != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? () => onChanged(!value) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: AnimatedContainer(
          duration: Motion.micro,
          curve: Motion.standard,
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: value ? c.accent : (enabled ? Colors.transparent : c.inputFill),
            shape: BoxShape.circle,
            border: Border.all(color: value ? c.accent : (enabled ? c.iconInactive : c.divider), width: 1.6),
          ),
          child: AnimatedSwitcher(
            duration: Motion.micro,
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: CurvedAnimation(parent: animation, curve: Motion.pop),
              child: child,
            ),
            child: value
                ? const Icon(Icons.check_rounded, key: ValueKey(true), size: 15, color: Colors.white)
                : const SizedBox(key: ValueKey(false)),
          ),
        ),
      ),
    );
  }

  Widget _buildSellerHeader(AppColors c, _SellerRow row) {
    final selected = row.items.where((i) => i.isSelected).toList();
    final allSelected = selected.length == row.items.length;
    final subtotal = selected.fold<double>(0, (sum, i) => sum + i.subtotal);
    final name = row.name.isEmpty ? S.unknownUser : row.name;

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
      child: Row(
        children: [
          _buildCheckbox(value: allSelected, c: c, onChanged: (value) => _setSelected(row.items, value)),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: row.sellerId == 0
                  ? null
                  : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SellerScreen(sellerId: row.sellerId, sellerName: name, sellerAvatarUrl: row.avatarUrl),
                        ),
                      ),
              child: Row(
                children: [
                  UserAvatar(imageUrl: row.avatarUrl, radius: 11),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c.textPrimary),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 18, color: c.iconInactive),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          SwitchIn(
            duration: Motion.micro,
            child: Text(
              selected.isEmpty ? '' : '\$${subtotal.toStringAsFixed(0)}',
              key: ValueKey(subtotal),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnavailableHeader(AppColors c, _UnavailableRow row) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 0, 4),
      child: Row(
        children: [
          Icon(Icons.block_rounded, size: 16, color: c.textHint),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              S.unavailableP0(row.items.length),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => _removeWithUndo(row.items),
            style: TextButton.styleFrom(
              foregroundColor: c.danger,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Text(S.removeAll),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(_ItemRow row, AppColors c) {
    final item = row.item;
    return SwipeActionTile(
      itemKey: ValueKey('cart_${item.cartId}'),
      startToEnd: row.available
          ? SwipeAction(
              icon: item.isSelected ? Icons.remove_done_rounded : Icons.done_rounded,
              label: item.isSelected ? S.deselect : S.select,
              color: c.accent,
              onTrigger: () async {
                setState(() => item.isSelected = !item.isSelected);
                return true;
              },
            )
          : null,
      endToStart: SwipeAction(
        icon: Icons.delete_outline_rounded,
        label: S.remove,
        color: c.danger,
        dismisses: true,
        onTrigger: () async => true,
        onDismissed: () => _removeWithUndo([item]),
      ),
      child: _buildItemCard(row, c),
    );
  }

  Widget _buildItemCard(_ItemRow row, AppColors c) {
    final item = row.item;
    final book = item.book;
    final available = row.available;

    return AnimatedContainer(
      duration: Motion.micro,
      curve: Motion.standard,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: available && item.isSelected ? c.accent : Colors.transparent,
          width: 1.6,
        ),
      ),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => BookDetailScreen(book: book, heroTag: 'cart_${item.cartId}')),
        ).then((_) {
          if (mounted) _load();
        }),
        child: Opacity(
          opacity: available ? 1 : 0.55,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildCheckbox(
                value: available && item.isSelected,
                c: c,
                onChanged: available
                    ? (value) {
                        HapticFeedback.selectionClick();
                        setState(() => item.isSelected = value);
                      }
                    : null,
              ),
              const SizedBox(width: 10),
              Hero(
                tag: 'cart_${item.cartId}',
                child: BookThumbnail(imageUrl: book.hasImage ? book.imageUrl : null, width: 64, height: 86),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c.textPrimary, height: 1.3),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (!available)
                          StatusBadge(label: _unavailableReason(item), color: c.danger)
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: c.conditionColor(book.conditionLevel).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              book.conditionText,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: c.conditionColor(book.conditionLevel),
                              ),
                            ),
                          ),
                        if (book.cabinetName.isNotEmpty)
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 150),
                            child: Text(
                              book.cabinetName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, color: c.textHint),
                            ),
                          ),
                      ],
                    ),
                    if (book.cabinetAddress.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.location_on_outlined, size: 12, color: c.iconInactive),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              book.cabinetAddress,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, color: c.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      '\$${book.price.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: available ? c.accent : c.textHint,
                        decoration: available ? null : TextDecoration.lineThrough,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                icon: Icon(Icons.delete_outline_rounded, size: 20, color: c.iconInactive),
                onPressed: () => _removeWithUndo([item]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckoutBar(AppColors c, {bool panel = false}) {
    final selected = _selectedItems;
    final shortfall = _total - _balance;
    final sellerCount = selected.map((i) => i.book.sellerId).toSet().length;
    final canPay = !_isCheckingOut && selected.isNotEmpty && _canAfford;

    final totals = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(S.total, style: TextStyle(fontSize: 12, color: c.textHint)),
            const SizedBox(width: 6),
            Flexible(
              child: PopIn(
                triggerKey: selected.length,
                child: Text(
                  S.selected(selected.length),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: c.textHint),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: AnimatedCount(
                  value: _total,
                  duration: const Duration(milliseconds: 320),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: c.textPrimary,
                    height: 1.1,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Text(S.faqCatWallet, style: TextStyle(fontSize: 12, color: c.textSecondary)),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          S.balance2(_balance.toStringAsFixed(0)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: _canAfford ? c.textHint : c.danger,
          ),
        ),
      ],
    );

    final payButton = SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: canPay ? _checkout : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: c.accent.withValues(alpha: 0.3),
          disabledForegroundColor: Colors.white70,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: SwitchIn(
          duration: const Duration(milliseconds: 200),
          child: _isCheckingOut
              ? const SizedBox(
                  key: ValueKey('busy'),
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : FittedBox(
                  key: ValueKey('label_${selected.isEmpty}_$_canAfford'),
                  fit: BoxFit.scaleDown,
                  child: Text(
                    selected.isEmpty ? S.selectBookFirst : (_canAfford ? S.checkOut : S.notEnoughCoins),
                    maxLines: 1,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
        ),
      ),
    );

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Reveal(
          visible: !_canAfford && selected.isNotEmpty,
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
            decoration: BoxDecoration(
              color: c.danger.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.account_balance_wallet_outlined, size: 16, color: c.danger),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    S.coinsShort(shortfall.toStringAsFixed(0)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.danger),
                  ),
                ),
                TextButton(
                  onPressed: _openWallet,
                  style: TextButton.styleFrom(
                    foregroundColor: c.danger,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(S.goWallet, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const Icon(Icons.chevron_right_rounded, size: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Reveal(
          visible: sellerCount > 1,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(Icons.call_split_rounded, size: 14, color: c.textHint),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    S.fromP0SellersCheckoutCreatesP1(sellerCount, sellerCount),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: c.textHint),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (panel) ...[
          totals,
          const SizedBox(height: 16),
          payButton,
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: totals),
              const SizedBox(width: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 120, maxWidth: 170),
                child: payButton,
              ),
            ],
          ),
      ],
    );

    if (panel) {
      return AppCard(padding: const EdgeInsets.all(20), child: content);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final side = responsiveListPadding(constraints, maxWidth: Breakpoints.readingMaxWidth, horizontal: 20).left;
        return Container(
          padding: EdgeInsets.only(
            left: side,
            right: side,
            top: 12,
            bottom: MediaQuery.of(context).padding.bottom + 12,
          ),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            boxShadow: [BoxShadow(color: c.shadow, blurRadius: 24, offset: const Offset(0, -6))],
          ),
          child: content,
        );
      },
    );
  }
}
