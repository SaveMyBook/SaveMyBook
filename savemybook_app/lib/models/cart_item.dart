import '../utils/api_helpers.dart';
import 'book.dart';

class CartItem {
  final int cartId;
  final Book book;

  bool isSelected;

  CartItem({
    required this.cartId,
    required this.book,
    this.isSelected = true,
  });

  // 二手書一筆商品即一本實體書，數量固定為 1。
  double get subtotal => book.price;

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      cartId: parseInt(json['cart_id']),
      book: Book.fromJson(Map<String, dynamic>.from(json['books'] ?? {})),
    );
  }
}
