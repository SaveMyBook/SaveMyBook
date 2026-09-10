import 'package:flutter/material.dart';
import '../models/cart_item.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../widgets/animations.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/app_header.dart';
import '../widgets/state_views.dart';
import '../widgets/swipe_action.dart';
import 'book_detail_screen.dart';
import 'purchase_history_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await _api.fetchCart();
    if (!mounted) return;
    setState(() {
      _items = items;
      _isLoading = false;
    });
  }

  bool get _allSelected => _items.isNotEmpty && _items.every((i) => i.isSelected);

  List<CartItem> get _selectedItems => _items.where((i) => i.isSelected).toList();

  double get _total => _selectedItems.fold(0, (sum, i) => sum + i.subtotal);

  Future<bool> _confirmRemove(CartItem item) {
    return showConfirmDialog(
      context,
      title: '移出購物車',
      message: '要把《${item.book.title}》從購物車移除嗎？',
      confirmLabel: '移除',
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

    showAppSnackBar(context, '移除失敗，已還原', isError: true);
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

    if (!ok) showAppSnackBar(context, '移除失敗，請稍後再試', isError: true);
  }

  Future<void> _checkout() async {
    final selected = _selectedItems;
    if (selected.isEmpty) {
      showAppSnackBar(context, '請先選擇要結帳的書籍', isError: true);
      return;
    }

    final confirmed = await showConfirmDialog(
      context,
      title: '確認結帳',
      message: '共 ${selected.length} 本書，總金額 \$${_total.toStringAsFixed(0)}。\n結帳後賣家會收到通知並將書放入書櫃。',
      confirmLabel: '確認結帳',
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

    showAppSnackBar(context, '結帳成功，請等待賣家存書');
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
          const AppHeader(title: '購物車', icon: Icons.shopping_cart_outlined),
          if (_items.isNotEmpty) _buildSelectAllRow(c),
          Expanded(
            child: SwitchIn(child: _isLoading
                ? const LoadingView.list()
                : RefreshIndicator(
                    color: c.accent,
                    onRefresh: _load,
                    child: _items.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 80),
                              EmptyView(icon: Icons.remove_shopping_cart_outlined, message: '購物車是空的'),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                            itemCount: _items.length,
                            itemBuilder: (_, i) => FadeSlideIn(index: i, child: _buildItem(_items[i], c)),
                          ),
                  )),
          ),
          if (_items.isNotEmpty) _buildCheckoutBar(c),
        ],
      ),
    );
  }

  Widget _buildSelectAllRow(AppColors c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
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
          Text(
            '全選',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary),
          ),
          const Spacer(),
          Text(
            '共 ${_items.length} 件',
            style: TextStyle(fontSize: 13, color: c.textSecondary),
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
        label: item.isSelected ? '取消選取' : '選取',
        color: c.accent,
        onTrigger: () async {
          setState(() => item.isSelected = !item.isSelected);
          return true;
        },
      ),
      endToStart: SwipeAction(
        icon: Icons.delete_outline_rounded,
        label: '移除',
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

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
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
                        color: book.conditionColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        book.conditionText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: book.conditionColor,
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
    );
  }

  Widget _buildCheckoutBar(AppColors c) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).padding.bottom + 14,
      ),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [BoxShadow(color: c.shadow, blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              PopIn(
                triggerKey: _selectedItems.length,
                child: Text('已選 ${_selectedItems.length} 件',
                    style: TextStyle(fontSize: 11, color: c.textHint)),
              ),
              const SizedBox(height: 2),
              AnimatedCount(
                value: _total,
                prefix: '\$',
                duration: const Duration(milliseconds: 320),
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: c.textPrimary),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isCheckingOut || _selectedItems.isEmpty ? null : _checkout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.accent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: c.accent.withValues(alpha: 0.35),
                  disabledForegroundColor: Colors.white70,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: SwitchIn(
                  duration: const Duration(milliseconds: 200),
                  child: _isCheckingOut
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('結帳', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
