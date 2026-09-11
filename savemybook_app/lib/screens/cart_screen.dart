import 'package:flutter/material.dart';
import '../models/cart_item.dart';
import '../models/member_level.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../widgets/animations.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/app_header.dart';
import '../widgets/state_views.dart';
import '../widgets/swipe_action.dart';
import 'book_detail_screen.dart';
import 'purchase_history_screen.dart';
import '../utils/motion.dart';
import '../i18n/strings.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final ApiService _api = ApiService();
  List<CartItem> _items = [];
  final Set<int> _removingCartIds = {};
  bool _isLoading = true;
  bool _isCheckingOut = false;
  double _balance = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([_api.fetchCart(), _api.fetchUserStats()]);
    if (!mounted) return;
    setState(() {
      _items = results[0] as List<CartItem>;
      _balance = (results[1] as UserStats).balance;
      _isLoading = false;
    });
  }

  bool get _canAfford => _balance >= _total;

  bool get _allSelected => _items.isNotEmpty && _items.every((i) => i.isSelected);

  List<CartItem> get _selectedItems => _items.where((i) => i.isSelected).toList();

  double get _total => _selectedItems.fold(0, (sum, i) => sum + i.subtotal);

  Future<bool> _confirmRemove(CartItem item) {
    return showConfirmDialog(
      context,
      title: S.removeFromCart,
      message: S.removeFromCart2(item.book.title),
      confirmLabel: S.remove,
      isDestructive: true,
    );
  }

  Future<void> _removeItem(CartItem item) async {
    if (!await _confirmRemove(item) || !mounted) return;
    await _deleteItem(item);
  }

  /// 右滑移除：widget 已經被 Dismissible 拿掉了，必須立刻同步移出清單，
  /// 否則 ListView 還握著一個「已 dismiss」的項目會直接丟例外。
  Future<void> _deleteDismissed(CartItem item) async {
    setState(() => _items.removeWhere((i) => i.cartId == item.cartId));

    final ok = await _api.removeCartItem(item.cartId);
    if (!mounted || ok) return;

    showAppSnackBar(context, S.couldNotRemoveRestored, isError: true);
    _load();
  }

  Future<void> _deleteItem(CartItem item) async {
    setState(() => _removingCartIds.add(item.cartId));
    final ok = await _api.removeCartItem(item.cartId);
    if (!mounted) return;

    setState(() {
      _removingCartIds.remove(item.cartId);
      if (ok) _items.removeWhere((i) => i.cartId == item.cartId);
    });

    if (!ok) showAppSnackBar(context, S.couldNotRemovePleaseTryAgain, isError: true);
  }

  Future<void> _checkout() async {
    final selected = _selectedItems;
    if (selected.isEmpty) {
      showAppSnackBar(context, S.selectBooksWantCheckOut, isError: true);
      return;
    }

    if (!_canAfford) {
      showAppSnackBar(
        context,
        S.notEnoughCoinsOrderNeedsBut(_total.toStringAsFixed(0), _balance.toStringAsFixed(0)),
        isError: true,
      );
      return;
    }

    final confirmed = await showConfirmDialog(
      context,
      title: S.confirmCheckout,
      message: S.booksTotal(selected.length, _total.toStringAsFixed(0)) +
          S.balanceAfterPaymentCoins((_balance - _total).toStringAsFixed(0)),
      confirmLabel: S.confirmCheckout,
    );
    if (!confirmed || !mounted) return;

    setState(() => _isCheckingOut = true);
    final error = await _api.checkout(selected.map((i) => i.cartId).toList());
    if (!mounted) return;
    setState(() => _isCheckingOut = false);

    if (error != null) {
      showAppSnackBar(context, error, isError: true);
      return;
    }

    showAppSnackBar(context, S.orderPlacedSellerDropBookOff);
    await _load();
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => const PurchaseHistoryScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          AppHeader(title: S.cart, icon: Icons.shopping_cart_outlined),
          if (_items.isNotEmpty) _buildSelectAllRow(c),
          Expanded(
            child: SwitchIn(child: _isLoading
                ? const LoadingView.list()
                : RefreshIndicator(
                    color: c.accent,
                    onRefresh: _load,
                    child: SwitchIn(child: _items.isEmpty
                        ? ListView(key: const ValueKey('empty'), 
                            children: [
                              SizedBox(height: 80),
                              EmptyView(icon: Icons.remove_shopping_cart_outlined, message: S.cartEmpty),
                            ],
                          )
                        : ListView.builder(key: const ValueKey('items'), 
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                            itemCount: _items.length,
                            itemBuilder: (_, i) => RevealOnScroll(index: i, child: _buildItem(_items[i], c)),
                          )),
                  )),
          ),
          if (_items.isNotEmpty) _buildCheckoutBar(c),
        ],
      ),
    );
  }

  Widget _buildSelectAllRow(AppColors c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      child: Row(
        children: [
          _buildCheckbox(
            value: _allSelected,
            c: c,
            onChanged: (value) => setState(() {
              for (final item in _items) {
                item.isSelected = value;
              }
            }),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() {
              final next = !_allSelected;
              for (final item in _items) {
                item.isSelected = next;
              }
            }),
            child: Text(
              S.selectAll,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary),
            ),
          ),
          const Spacer(),
          Text(
            S.items(_items.length),
            style: TextStyle(fontSize: 12, color: c.textHint),
          ),
        ],
      ),
    );
  }

  /// 用自畫的圓形勾選框，Material 預設 Checkbox 的 48x48 觸控框會在卡片裡撐出留白。
  Widget _buildCheckbox({
    required bool value,
    required AppColors c,
    required ValueChanged<bool> onChanged,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: value ? c.accent : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(color: value ? c.accent : c.iconInactive, width: 1.6),
          ),
          child: value
              ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
              : null,
        ),
      ),
    );
  }

  Widget _buildItem(CartItem item, AppColors c) {
    return SwipeActionTile(
      itemKey: ValueKey('cart_${item.cartId}'),
      startToEnd: SwipeAction(
        icon: item.isSelected ? Icons.remove_done_rounded : Icons.done_rounded,
        label: item.isSelected ? S.deselect : S.select,
        color: c.accent,
        onTrigger: () async {
          setState(() => item.isSelected = !item.isSelected);
          return true;
        },
      ),
      endToStart: SwipeAction(
        icon: Icons.delete_outline_rounded,
        label: S.remove,
        color: c.danger,
        dismisses: true,
        onTrigger: () => _confirmRemove(item),
        onDismissed: () => _deleteDismissed(item),
      ),
      child: _buildItemCard(item, c),
    );
  }

  Widget _buildItemCard(CartItem item, AppColors c) {
    final book = item.book;
    final isRemoving = _removingCartIds.contains(item.cartId);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.isSelected ? c.accent : Colors.transparent,
          width: 1.6,
        ),
      ),
      child: AppCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => BookDetailScreen(book: book)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildCheckbox(
            value: item.isSelected,
            c: c,
            onChanged: (value) => setState(() => item.isSelected = value),
          ),
          const SizedBox(width: 10),
          BookThumbnail(imageUrl: book.imageUrl, width: 64, height: 86),
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
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: c.textPrimary,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
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
                    if (book.cabinetName.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          book.cabinetName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: c.textHint),
                        ),
                      ),
                    ],
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
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.accent),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 36,
            child: isRemoving
                ? Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: c.iconInactive),
                    ),
                  )
                : IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    icon: Icon(Icons.delete_outline_rounded, size: 20, color: c.iconInactive),
                    onPressed: () => _removeItem(item),
                  ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildCheckoutBar(AppColors c) {
    final shortfall = _total - _balance;

    return AnimatedContainer(
        duration: Motion.base,
        curve: Motion.standard,

      padding: EdgeInsets.only(
        left: 20,
        right: 20,
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Reveal(
            visible: !_canAfford && _selectedItems.isNotEmpty,
            child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: c.danger,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(S.total, style: TextStyle(fontSize: 12, color: c.textHint)),
                        const SizedBox(width: 6),
                        PopIn(
                          triggerKey: _selectedItems.length,
                          child: Text(
                            S.selected(_selectedItems.length),
                            style: TextStyle(fontSize: 12, color: c.textHint),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        AnimatedCount(
                          value: _total,
                          duration: const Duration(milliseconds: 320),
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: c.textPrimary,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(S.faqCatWallet, style: TextStyle(fontSize: 12, color: c.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      S.balance2(_balance.toStringAsFixed(0)),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _canAfford ? c.textHint : c.danger,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 132,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isCheckingOut || _selectedItems.isEmpty || !_canAfford
                      ? null
                      : _checkout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.accent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: c.accent.withValues(alpha: 0.3),
                    disabledForegroundColor: Colors.white70,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: SwitchIn(
                    duration: const Duration(milliseconds: 200),
                    child: _isCheckingOut
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            _selectedItems.isEmpty
                                ? S.selectBookFirst
                                : (_canAfford ? S.checkOut : S.notEnoughCoins),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
