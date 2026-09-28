import '../utils/api_helpers.dart';
import '../i18n/strings.dart';
import '../utils/app_labels.dart';
import 'book.dart';
import 'cabinet.dart';

class OrderItem {
  final int itemId;
  final int quantity;
  final double unitPrice;
  final double subtotal;
  final Book book;
  final bool preDeposited;

  OrderItem({
    required this.itemId,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    required this.book,
    this.preDeposited = false,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      itemId: parseInt(json['item_id']),
      quantity: parseInt(json['quantity']),
      unitPrice: parseDouble(json['unit_price']),
      subtotal: parseDouble(json['subtotal']),
      book: Book.fromJson(Map<String, dynamic>.from(json['books'] ?? {})),
      preDeposited: json['pre_deposited'] == true,
    );
  }
}

class Order {
  final int orderId;
  final String orderNo;
  final double totalAmount;
  final String status;
  final int buyerId;
  final int sellerId;
  final String buyerName;
  final String sellerName;
  final int? cabinetId;
  final String cabinetName;
  final String cabinetAddress;
  final String cabinetOpenHours;
  final String slotNumber;
  final DateTime? createdAt;
  final DateTime? pickedUpAt;
  final DateTime? completedAt;
  final List<OrderItem> items;
  final bool hasOpenDispute;
  final List<String> doors;
  final CabinetAccess? cabinetAccess;
  final CabinetManualReport? manualReport;

  /// 服務條款規定取書後 24 小時內可提出爭議；伺服器也會檢查，這裡只用來決定是否顯示入口。
  static const disputeWindow = Duration(hours: 24);

  Order({
    required this.orderId,
    required this.orderNo,
    required this.totalAmount,
    required this.status,
    required this.buyerId,
    required this.sellerId,
    this.buyerName = '',
    this.sellerName = '',
    this.cabinetId,
    this.cabinetName = '',
    this.cabinetAddress = '',
    this.cabinetOpenHours = '',
    this.slotNumber = '',
    this.createdAt,
    this.pickedUpAt,
    this.completedAt,
    this.items = const [],
    this.hasOpenDispute = false,
    this.doors = const [],
    this.cabinetAccess,
    this.manualReport,
  });

  Book? get firstBook => items.isEmpty ? null : items.first.book;

  String get doorLabel => doors.isNotEmpty ? doors.join('、') : slotNumber;

  bool get hasPendingManualReport => manualReport?.isPending == true;

  String get statusText => AppLabels.order(status, asBuyer: true);

  bool get isInCabinet => status == 'deposited' || status == 'pending_pickup';

  /// 買家已取書、尚未完成訂單：款項仍由平台保管，買家可完成訂單或申請爭議。
  bool get awaitingConfirmation => isInCabinet && pickedUpAt != null;

  bool get canCollect => isInCabinet && pickedUpAt == null;

  bool canOpenDispute({DateTime? now}) {
    if (hasOpenDispute) return false;
    if (const ['cancelled', 'refunded', 'refunding', 'completed'].contains(status)) return false;
    final pickedUp = pickedUpAt;
    if (pickedUp == null) return true;
    return (now ?? DateTime.now()).difference(pickedUp) <= disputeWindow;
  }

  bool storedElsewhere(OrderItem item) => item.preDeposited && item.book.cabinetId != cabinetId;

  /// 賣家存書後雙方都不能自行取消，只能提出申訴。
  bool get isCancellable => status == 'pending_payment' || status == 'pending_deposit';

  String statusLabel({required bool asSeller}) {
    if (awaitingConfirmation) return asSeller ? S.awaitingBuyerConfirmation : S.awaitingCompletion;
    return AppLabels.order(status, asBuyer: !asSeller);
  }

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
      buyerId: parseInt(json['buyer_id']),
      sellerId: parseInt(json['seller_id']),
      buyerName: buyer?['nickname'] as String? ?? '',
      sellerName: seller?['nickname'] as String? ?? '',
      cabinetId: json['cabinet_id'] == null ? null : parseInt(json['cabinet_id']),
      cabinetName: cabinet?['cabinet_name'] as String? ?? '',
      cabinetAddress: cabinet?['address'] as String? ?? '',
      cabinetOpenHours: formatTimeRange(cabinet?['open_time'], cabinet?['close_time']),
      slotNumber: slot?['slot_number'] as String? ?? '',
      createdAt: parseDate(json['created_at']),
      pickedUpAt: parseDate(json['picked_up_at']),
      completedAt: parseDate(json['completed_at']),
      items: ((json['order_items'] as List?) ?? const [])
          .map((e) => OrderItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      hasOpenDispute: disputes.any((d) => d is Map && d['status'] != 'resolved'),
      doors: [for (final d in (json['doors'] as List?) ?? const []) if (d != null) '$d'],
      cabinetAccess: CabinetAccess.fromJson(json['cabinet_access']),
      manualReport: CabinetManualReport.fromJson(json['manual_report']),
    );
  }
}
