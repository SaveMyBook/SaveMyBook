import '../../utils/api_helpers.dart';
import '../../utils/app_labels.dart';
import '../../i18n/strings.dart';

class OrderStep {
  final String label;
  final DateTime? at;
  const OrderStep(this.label, this.at);

  bool get done => at != null;
}

class OrderRefund {
  final int refundId;
  final String type;
  final double amount;
  final String status;
  final String? reason;
  final DateTime? createdAt;
  final DateTime? processedAt;

  OrderRefund({
    required this.refundId,
    required this.type,
    required this.amount,
    required this.status,
    this.reason,
    this.createdAt,
    this.processedAt,
  });

  factory OrderRefund.fromJson(Map<String, dynamic> json) => OrderRefund(
        refundId: parseInt(json['refund_id']),
        type: json['refund_type'] as String? ?? '',
        amount: parseDouble(json['amount']),
        status: json['status'] as String? ?? '',
        reason: json['reason'] as String?,
        createdAt: parseDate(json['created_at']),
        processedAt: parseDate(json['processed_at']),
      );
}

class OrderDispute {
  final int disputeId;
  final String reason;
  final String status;
  final String? result;
  final String? adminNote;
  final DateTime? createdAt;
  final DateTime? resolvedAt;

  OrderDispute({
    required this.disputeId,
    required this.reason,
    required this.status,
    this.result,
    this.adminNote,
    this.createdAt,
    this.resolvedAt,
  });

  factory OrderDispute.fromJson(Map<String, dynamic> json) => OrderDispute(
        disputeId: parseInt(json['dispute_id']),
        reason: json['reason'] as String? ?? '',
        status: json['status'] as String? ?? '',
        result: json['result'] as String?,
        adminNote: json['admin_note'] as String?,
        createdAt: parseDate(json['created_at']),
        resolvedAt: parseDate(json['resolved_at']),
      );
}

class OrderWalletTxn {
  final int txnId;
  final String type;
  final double amount;
  final double balanceAfter;
  final String? description;
  final DateTime? createdAt;

  OrderWalletTxn({
    required this.txnId,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    this.description,
    this.createdAt,
  });

  factory OrderWalletTxn.fromJson(Map<String, dynamic> json) => OrderWalletTxn(
        txnId: parseInt(json['txn_id']),
        type: json['type'] as String? ?? '',
        amount: parseDouble(json['amount']),
        balanceAfter: parseDouble(json['balance_after']),
        description: json['description'] as String?,
        createdAt: parseDate(json['created_at']),
      );
}

class AdminOrderDetail {
  final AdminOrder order;
  final String? paymentMethod;
  final String? note;
  final String? slotNumber;
  final String buyerAvatarUrl;
  final String sellerAvatarUrl;
  final String cabinetAddress;
  final Map<String, DateTime?> timeline;
  final List<OrderRefund> refunds;
  final List<OrderDispute> disputes;
  final List<OrderWalletTxn> walletTxns;

  AdminOrderDetail({
    required this.order,
    required this.timeline,
    required this.refunds,
    required this.disputes,
    required this.walletTxns,
    required this.buyerAvatarUrl,
    required this.sellerAvatarUrl,
    required this.cabinetAddress,
    this.paymentMethod,
    this.note,
    this.slotNumber,
  });

  factory AdminOrderDetail.fromJson(Map<String, dynamic> json) {
    final time = (json['timeline'] as Map?)?.cast<String, dynamic>() ?? const {};
    final slot = json['slot'] as Map<String, dynamic>?;
    final buyer = json['buyer'] as Map<String, dynamic>?;
    final seller = json['seller'] as Map<String, dynamic>?;
    final cabinet = json['cabinet'] as Map<String, dynamic>?;

    List<T> list<T>(String key, T Function(Map<String, dynamic>) build) =>
        ((json[key] as List?) ?? const [])
            .map((e) => build(Map<String, dynamic>.from(e)))
            .toList();

    return AdminOrderDetail(
      order: AdminOrder.fromJson(json),
      paymentMethod: json['payment_method'] as String?,
      note: json['note'] as String?,
      slotNumber: slot?['slot_number'] as String?,
      buyerAvatarUrl: resolveAssetUrl(buyer?['avatar_url']) ?? '',
      sellerAvatarUrl: resolveAssetUrl(seller?['avatar_url']) ?? '',
      cabinetAddress: cabinet?['address'] as String? ?? '',
      timeline: {
        for (final key in const [
          'created_at', 'payment_at', 'deposited_at',
          'picked_up_at', 'completed_at', 'cancelled_at',
        ])
          key: parseDate(time[key]),
      },
      refunds: list('refunds', OrderRefund.fromJson),
      disputes: list('disputes', OrderDispute.fromJson),
      walletTxns: list('wallet_transactions', OrderWalletTxn.fromJson),
    );
  }

  List<OrderStep> get steps {
    final cancelled = timeline['cancelled_at'];
    return [
      OrderStep(S.orderPlaced, timeline['created_at']),
      OrderStep(S.paid, timeline['payment_at']),
      OrderStep(S.sellerDroppedOff, timeline['deposited_at']),
      OrderStep(S.buyerCollected, timeline['picked_up_at']),
      if (cancelled == null) OrderStep(S.completed, timeline['completed_at'])
      else OrderStep(S.actionCancel, cancelled),
    ];
  }
}

class AdminOrderItem {
  final int bookId;
  final String title;
  final double unitPrice;
  final int quantity;
  final String? imageUrl;

  AdminOrderItem({
    required this.bookId,
    required this.title,
    required this.unitPrice,
    required this.quantity,
    this.imageUrl,
  });

  factory AdminOrderItem.fromJson(Map<String, dynamic> json) {
    return AdminOrderItem(
      bookId: parseInt(json['book_id']),
      title: json['title'] as String? ?? '',
      unitPrice: parseDouble(json['unit_price']),
      quantity: parseInt(json['quantity']),
      imageUrl: resolveAssetUrl(json['image_url']),
    );
  }
}

class AdminOrder {
  final int orderId;
  final String orderNo;
  final String status;
  final double totalAmount;
  final String buyerName;
  final String sellerName;
  final String cabinetName;
  final String? pickupCode;
  final String? cancelReason;
  final DateTime? createdAt;
  final List<AdminOrderItem> items;

  AdminOrder({
    required this.orderId,
    required this.orderNo,
    required this.status,
    required this.totalAmount,
    required this.buyerName,
    required this.sellerName,
    required this.cabinetName,
    required this.items,
    this.pickupCode,
    this.cancelReason,
    this.createdAt,
  });

  String get statusText => AppLabels.order(status);

  factory AdminOrder.fromJson(Map<String, dynamic> json) {
    final buyer = json['buyer'] as Map<String, dynamic>?;
    final seller = json['seller'] as Map<String, dynamic>?;
    final cabinet = json['cabinet'] as Map<String, dynamic>?;

    return AdminOrder(
      orderId: parseInt(json['order_id']),
      orderNo: json['order_no'] as String? ?? '',
      status: json['status'] as String? ?? '',
      totalAmount: parseDouble(json['total_amount']),
      buyerName: buyer?['nickname'] as String? ?? '—',
      sellerName: seller?['nickname'] as String? ?? '—',
      cabinetName: cabinet?['cabinet_name'] as String? ?? '',
      pickupCode: json['pickup_code'] as String?,
      cancelReason: json['cancel_reason'] as String?,
      createdAt: parseDate(json['created_at']),
      items: ((json['items'] as List?) ?? const [])
          .map((e) => AdminOrderItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}
