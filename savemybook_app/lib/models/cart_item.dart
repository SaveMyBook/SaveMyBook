import '../utils/api_helpers.dart';
import 'book.dart';

class CartItem {
  final int cartId;
  final int quantity;
  final Book book;

  bool isSelected;

  CartItem({
    required this.cartId,
    required this.quantity,
    required this.book,
    this.isSelected = true,
  });

  double get subtotal => book.price * quantity;

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      cartId: parseInt(json['cart_id']),
      quantity: parseInt(json['quantity']) == 0 ? 1 : parseInt(json['quantity']),
      book: Book.fromJson(Map<String, dynamic>.from(json['books'] ?? {})),
    );
  }
}
