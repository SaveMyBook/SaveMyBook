import '../utils/api_helpers.dart';
import 'book.dart';

class OrderItem {
  final int itemId;
  final int quantity;
  final double unitPrice;
  final double subtotal;
  final Book book;

  OrderItem({
    required this.itemId,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    required this.book,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      itemId: parseInt(json['item_id']),
      quantity: parseInt(json['quantity']),
      unitPrice: parseDouble(json['unit_price']),
      subtotal: parseDouble(json['subtotal']),
      book: Book.fromJson(Map<String, dynamic>.from(json['books'] ?? {})),
    );
  }
}

class Order {
  final int orderId;
  final String orderNo;
  final double totalAmount;
  final String status;
  final String? pickupCode;
  final int buyerId;
  final int sellerId;
  final String buyerName;
  final String sellerName;
  final String cabinetName;
  final String cabinetAddress;
  final String cabinetOpenHours;
  final String slotNumber;
  final DateTime? createdAt;
  final List<OrderItem> items;
  final bool hasOpenDispute;

  Order({
    required this.orderId,
    required this.orderNo,
    required this.totalAmount,
    required this.status,
    required this.buyerId,
    required this.sellerId,
    this.pickupCode,
    this.buyerName = '',
    this.sellerName = '',
    this.cabinetName = '',
    this.cabinetAddress = '',
    this.cabinetOpenHours = '',
    this.slotNumber = '',
    this.createdAt,
    this.items = const [],
    this.hasOpenDispute = false,
  });

  Book? get firstBook => items.isEmpty ? null : items.first.book;

  String get statusText {
    switch (status) {
      case 'pending_payment': return '待付款';
      case 'pending_deposit': return '待賣家存書';
      case 'deposited': return '待取書';
      case 'pending_pickup': return '待取書';
      case 'completed': return '已完成';
      case 'cancelled': return '已取消';
      case 'refunding': return '申訴中';
      case 'refunded': return '已退款';
      default: return status;
    }
  }

  bool get isCancellable =>
      status == 'pending_payment' || status == 'pending_deposit' || status == 'deposited';

  factory Order.fromJson(Map<String, dynamic> json) {
    final cabinet = json['smart_cabinets'] as Map<String, dynamic>?;
    final slot = json['cabinet_slots'] as Map<String, dynamic>?;
    final buyer = json['users_orders_buyer_idTousers'] as Map<String, dynamic>?;
    final seller = json['users_orders_seller_idTousers'] as Map<String, dynamic>?;

    final disputes = (json['transaction_disputes'] as List?) ?? const [];

    return Order(
      orderId: parseInt(json['order_id']),
      orderNo: json['order_no'] as String? ?? '',
      totalAmount: parseDouble(json['total_amount']),
      status: json['status'] as String? ?? 'pending_payment',
      pickupCode: json['pickup_code'] as String?,
      buyerId: parseInt(json['buyer_id']),
      sellerId: parseInt(json['seller_id']),
      buyerName: buyer?['nickname'] as String? ?? '',
      sellerName: seller?['nickname'] as String? ?? '',
      cabinetName: cabinet?['cabinet_name'] as String? ?? '',
      cabinetAddress: cabinet?['address'] as String? ?? '',
      cabinetOpenHours: formatTimeRange(cabinet?['open_time'], cabinet?['close_time']),
      slotNumber: slot?['slot_number'] as String? ?? '',
      createdAt: parseDate(json['created_at']),
      items: ((json['order_items'] as List?) ?? const [])
          .map((e) => OrderItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      hasOpenDispute: disputes.any((d) => d is Map && d['status'] != 'resolved'),
    );
  }
}
