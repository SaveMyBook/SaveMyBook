import 'package:flutter/material.dart';
import '../models/cart_item.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../widgets/app_header.dart';
import '../widgets/state_views.dart';
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

  Future<void> _removeItem(CartItem item) async {
    final ok = await _api.removeCartItem(item.cartId);
    if (!mounted) return;
    if (ok) {
      setState(() => _items.removeWhere((i) => i.cartId == item.cartId));
    } else {
      showAppSnackBar(context, '移除失敗，請稍後再試', isError: true);
    }
  }

  Future<void> _checkout() async {
    final selected = _selectedItems;
    if (selected.isEmpty) {
      showAppSnackBar(context, '請先選擇要結帳的書籍', isError: true);
      return;
    }

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
          AppHeader(title: '購物車', icon: Icons.shopping_cart_outlined),
          if (_items.isNotEmpty) _buildSelectAllRow(c),
          Expanded(
            child: _isLoading
                ? const LoadingView()
                : RefreshIndicator(
                    color: AppColors.primary,
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
                            itemBuilder: (_, i) => _buildItem(_items[i], c),
                          ),
                  ),
          ),
          if (_items.isNotEmpty) _buildCheckoutBar(c),
        ],
      ),
    );
  }

  Widget _buildSelectAllRow(AppColors c) {
    return Padding(
      padding: const EdgeInsets.only(right: 16, top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text('全部選取', style: TextStyle(fontSize: 14, color: c.textSecondary)),
          Checkbox(
            value: _allSelected,
            activeColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            onChanged: (value) {
              setState(() {
                for (final item in _items) {
                  item.isSelected = value ?? false;
                }
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildItem(CartItem item, AppColors c) {
    final book = item.book;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Checkbox(
          value: item.isSelected,
          activeColor: AppColors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          onChanged: (value) => setState(() => item.isSelected = value ?? false),
        ),
        Expanded(
          child: AppCard(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => BookDetailScreen(book: book)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BookThumbnail(imageUrl: book.imageUrl, width: 68, height: 90),
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
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: c.textPrimary,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _removeItem(item),
                            child: Icon(Icons.delete_outline_rounded, size: 20, color: c.iconInactive),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: book.conditionColor.withOpacity(0.15),
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
                      const SizedBox(height: 8),
                      if (book.cabinetAddress.isNotEmpty)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.location_on_outlined, size: 13, color: c.iconInactive),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                book.cabinetAddress,
                                maxLines: 2,
                                style: TextStyle(fontSize: 11, color: c.textSecondary, height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            book.cabinetName.isEmpty ? '' : '書櫃：${book.cabinetName}',
                            style: TextStyle(fontSize: 11, color: c.textHint),
                          ),
                          Text(
                            '\$${book.price.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
              Text('已選 ${_selectedItems.length} 件', style: TextStyle(fontSize: 11, color: c.textHint)),
              const SizedBox(height: 2),
              Text(
                '\$${_total.toStringAsFixed(0)}',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: c.textPrimary),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isCheckingOut ? null : _checkout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
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
        ],
      ),
    );
  }
}
