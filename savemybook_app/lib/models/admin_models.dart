import '../utils/api_helpers.dart';
import '../utils/app_labels.dart';
import '../i18n/strings.dart';

class Announcement {
  final int announcementId;
  final String title;
  final String content;
  final String type;
  final bool isPublished;
  final DateTime? publishedAt;
  final DateTime? expiresAt;
  final DateTime? createdAt;
  final String authorName;

  Announcement({
    required this.announcementId,
    required this.title,
    required this.content,
    required this.type,
    required this.isPublished,
    this.publishedAt,
    this.expiresAt,
    this.createdAt,
    this.authorName = '',
  });

  String get typeText {
    switch (type) {
      case 'maintenance': return S.maintenance;
      case 'promotion': return S.promotions;
      case 'policy': return S.policyUpdate;
      case 'general':
      default: return S.announcement;
    }
  }

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      announcementId: parseInt(json['announcement_id']),
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      type: json['type'] as String? ?? 'general',
      isPublished: json['is_published'] == true,
      publishedAt: parseDate(json['published_at']),
      expiresAt: parseDate(json['expires_at']),
      createdAt: parseDate(json['created_at']),
      authorName: (json['users'] as Map<String, dynamic>?)?['nickname'] as String? ?? '',
    );
  }
}

class AdminMember {
  final int userId;
  final String email;
  final String nickname;
  final String? avatarUrl;
  final String phone;
  final String role;
  final bool isActive;
  final bool isBlacklisted;
  final DateTime? createdAt;
  final int bookCount;
  final int buyOrderCount;
  final int sellOrderCount;

  AdminMember({
    required this.userId,
    required this.email,
    required this.nickname,
    required this.role,
    required this.isActive,
    required this.isBlacklisted,
    this.avatarUrl,
    this.phone = '',
    this.createdAt,
    this.bookCount = 0,
    this.buyOrderCount = 0,
    this.sellOrderCount = 0,
  });

  String get statusText =>
      AppLabels.member(isActive: isActive, isBlacklisted: isBlacklisted);

  factory AdminMember.fromJson(Map<String, dynamic> json) {
    final counts = json['_count'] as Map<String, dynamic>?;
    return AdminMember(
      userId: parseInt(json['user_id']),
      email: json['email'] as String? ?? '',
      nickname: json['nickname'] as String? ?? '',
      avatarUrl: resolveAssetUrl(json['avatar_url']),
      phone: json['phone'] as String? ?? '',
      role: json['role'] as String? ?? 'buyer_seller',
      isActive: json['is_active'] != false,
      isBlacklisted: json['is_blacklisted'] == true,
      createdAt: parseDate(json['created_at']),
      bookCount: parseInt(counts?['books']),
      buyOrderCount: parseInt(counts?['orders_orders_buyer_idTousers']),
      sellOrderCount: parseInt(counts?['orders_orders_seller_idTousers']),
    );
  }
}

class ReportCase {
  final int reportId;
  final String targetType;
  final int targetId;
  final String reason;
  final String status;
  final String? adminNote;
  final DateTime? createdAt;
  final DateTime? resolvedAt;
  final String reporterName;
  final String targetTitle;
  final String? targetImageUrl;

  ReportCase({
    required this.reportId,
    required this.targetType,
    required this.targetId,
    required this.reason,
    required this.status,
    this.adminNote,
    this.createdAt,
    this.resolvedAt,
    this.reporterName = '',
    this.targetTitle = '',
    this.targetImageUrl,
  });

  String get targetTypeText {
    switch (targetType) {
      case 'book': return S.item;
      case 'user': return S.member;
      case 'message': return S.message;
      default: return targetType;
    }
  }

  String get statusText => AppLabels.report(status);

  factory ReportCase.fromJson(Map<String, dynamic> json) {
    final target = json['target'] as Map<String, dynamic>?;
    final images = (target?['book_images'] as List?) ?? const [];

    return ReportCase(
      reportId: parseInt(json['report_id']),
      targetType: json['target_type'] as String? ?? 'book',
      targetId: parseInt(json['target_id']),
      reason: json['reason'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      adminNote: json['admin_note'] as String?,
      createdAt: parseDate(json['created_at']),
      resolvedAt: parseDate(json['resolved_at']),
      reporterName:
          (json['users_reports_reporter_idTousers'] as Map<String, dynamic>?)?['nickname'] as String? ?? '',
      targetTitle: (target?['title'] ?? target?['nickname']) as String? ?? S.noLongerExists,
      targetImageUrl: images.isEmpty ? null : resolveAssetUrl((images.first as Map)['image_url']),
    );
  }
}

class DisputeCase {
  final int disputeId;
  final int orderId;
  final String orderNo;
  final double totalAmount;
  final String reason;
  final String status;
  final String? result;
  final String? adminNote;
  final DateTime? createdAt;
  final String applicantName;
  final String buyerName;
  final String sellerName;
  final String bookTitle;
  final String? bookImageUrl;

  DisputeCase({
    required this.disputeId,
    required this.orderId,
    required this.orderNo,
    required this.totalAmount,
    required this.reason,
    required this.status,
    this.result,
    this.adminNote,
    this.createdAt,
    this.applicantName = '',
    this.buyerName = '',
    this.sellerName = '',
    this.bookTitle = '',
    this.bookImageUrl,
  });

  String get statusText => AppLabels.dispute(status);

  String get resultText => AppLabels.disputeResult[result] ?? '';

  factory DisputeCase.fromJson(Map<String, dynamic> json) {
    final order = json['orders'] as Map<String, dynamic>?;
    final items = (order?['order_items'] as List?) ?? const [];
    final book = items.isEmpty ? null : (items.first as Map)['books'] as Map?;
    final images = (book?['book_images'] as List?) ?? const [];

    return DisputeCase(
      disputeId: parseInt(json['dispute_id']),
      orderId: parseInt(json['order_id'] ?? order?['order_id']),
      orderNo: order?['order_no'] as String? ?? '',
      totalAmount: parseDouble(order?['total_amount']),
      reason: json['reason'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      result: json['result'] as String?,
      adminNote: json['admin_note'] as String?,
      createdAt: parseDate(json['created_at']),
      applicantName: (json['users_transaction_disputes_applicant_idTousers']
          as Map<String, dynamic>?)?['nickname'] as String? ?? '',
      buyerName: (order?['users_orders_buyer_idTousers'] as Map?)?['nickname'] as String? ?? '',
      sellerName: (order?['users_orders_seller_idTousers'] as Map?)?['nickname'] as String? ?? '',
      bookTitle: book?['title'] as String? ?? '',
      bookImageUrl: images.isEmpty ? null : resolveAssetUrl((images.first as Map)['image_url']),
    );
  }
}

class CabinetSlot {
  final int slotId;
  final String slotNumber;
  final String status;
  final DateTime? updatedAt;

  CabinetSlot({
    required this.slotId,
    required this.slotNumber,
    required this.status,
    this.updatedAt,
  });

  String get statusText => AppLabels.slot(status);

  factory CabinetSlot.fromJson(Map<String, dynamic> json) {
    return CabinetSlot(
      slotId: parseInt(json['slot_id']),
      slotNumber: json['slot_number'] as String? ?? '',
      status: json['status'] as String? ?? 'empty',
      updatedAt: parseDate(json['updated_at']),
    );
  }
}

class Cabinet {
  final int cabinetId;
  final String cabinetName;
  final String address;
  final double latitude;
  final double longitude;
  final int totalSlots;
  final int availableSlots;
  final bool isActive;
  final String openHours;
  final List<CabinetSlot> slots;
  final Map<String, int> slotSummary;

  Cabinet({
    required this.cabinetId,
    required this.cabinetName,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.totalSlots,
    required this.availableSlots,
    required this.isActive,
    this.openHours = '',
    this.slots = const [],
    this.slotSummary = const {},
  });

  factory Cabinet.fromJson(Map<String, dynamic> json) {
    final summary = (json['slot_summary'] as Map<String, dynamic>?) ?? const {};
    return Cabinet(
      cabinetId: parseInt(json['cabinet_id']),
      cabinetName: json['cabinet_name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      latitude: parseDouble(json['latitude']),
      longitude: parseDouble(json['longitude']),
      totalSlots: parseInt(json['total_slots']),
      availableSlots: parseInt(json['available_slots']),
      isActive: json['is_active'] != false,
      openHours: formatTimeRange(json['open_time'], json['close_time']),
      slots: ((json['cabinet_slots'] as List?) ?? const [])
          .map((e) => CabinetSlot.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      slotSummary: summary.map((k, v) => MapEntry(k, parseInt(v))),
    );
  }
}

class MaintenanceLog {
  final int logId;
  final String action;
  final String? detail;
  final String adminName;
  final DateTime? createdAt;

  MaintenanceLog({
    required this.logId,
    required this.action,
    required this.adminName,
    this.detail,
    this.createdAt,
  });

  factory MaintenanceLog.fromJson(Map<String, dynamic> json) {
    return MaintenanceLog(
      logId: parseInt(json['log_id']),
      action: json['action'] as String? ?? '',
      detail: json['detail'] as String?,
      adminName: (json['users'] as Map<String, dynamic>?)?['nickname'] as String? ?? '',
      createdAt: parseDate(json['created_at']),
    );
  }
}

class AdminOverview {
  final int memberCount;
  final int pendingReportCount;
  final int pendingDisputeCount;
  final int activeCabinetCount;
  final int todayOrderCount;
  final int openTicketCount;

  AdminOverview({
    required this.memberCount,
    required this.pendingReportCount,
    required this.pendingDisputeCount,
    required this.activeCabinetCount,
    required this.todayOrderCount,
    this.openTicketCount = 0,
  });

  factory AdminOverview.fromJson(Map<String, dynamic> json) {
    return AdminOverview(
      memberCount: parseInt(json['member_count']),
      pendingReportCount: parseInt(json['pending_report_count']),
      pendingDisputeCount: parseInt(json['pending_dispute_count']),
      activeCabinetCount: parseInt(json['active_cabinet_count']),
      todayOrderCount: parseInt(json['today_order_count']),
      openTicketCount: parseInt(json['open_ticket_count']),
    );
  }

  static AdminOverview get empty => AdminOverview(
        memberCount: 0,
        pendingReportCount: 0,
        pendingDisputeCount: 0,
        activeCabinetCount: 0,
        todayOrderCount: 0,
      );
}

/// 訂單流程的一個節點。null 代表還沒走到，用來看訂單卡在哪一步。
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

/// 列表用的 AdminOrder 只有摘要，處理爭議時要看的細節都在這裡。
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

  /// 依實際流程排出的節點。取消的訂單不顯示後面沒走到的步驟。
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

class AdminBook {
  final int bookId;
  final String title;
  final String? isbn;
  final double price;
  final String status;
  final String conditionLevel;
  final int? categoryId;
  final String categoryName;
  final String sellerName;
  final int viewCount;
  final int pendingReportCount;
  final String? imageUrl;
  final DateTime? createdAt;

  // 編輯表單的現值。列表就帶回來，開編輯畫面才不用再打一次 API。
  final String? author;
  final String? publisher;
  final String? publishDate;
  final String? conditionNote;
  final String? description;

  AdminBook({
    required this.bookId,
    required this.title,
    required this.price,
    required this.status,
    required this.conditionLevel,
    required this.categoryName,
    required this.sellerName,
    required this.viewCount,
    required this.pendingReportCount,
    this.categoryId,
    this.isbn,
    this.imageUrl,
    this.createdAt,
    this.author,
    this.publisher,
    this.publishDate,
    this.conditionNote,
    this.description,
  });

  String get statusText => AppLabels.book(status);

  factory AdminBook.fromJson(Map<String, dynamic> json) {
    final seller = json['seller'] as Map<String, dynamic>?;

    return AdminBook(
      bookId: parseInt(json['book_id']),
      title: json['title'] as String? ?? '',
      isbn: json['isbn'] as String?,
      price: parseDouble(json['price']),
      status: json['status'] as String? ?? '',
      conditionLevel: json['condition_level'] as String? ?? 'good',
      categoryId: json['category_id'] == null ? null : parseInt(json['category_id']),
      categoryName: json['category_name'] as String? ?? '',
      sellerName: seller?['nickname'] as String? ?? '—',
      viewCount: parseInt(json['view_count']),
      pendingReportCount: parseInt(json['pending_report_count']),
      imageUrl: resolveAssetUrl(json['image_url']),
      createdAt: parseDate(json['created_at']),
      author: json['author'] as String?,
      publisher: json['publisher'] as String?,
      publishDate: json['publish_date'] as String?,
      conditionNote: json['condition_note'] as String?,
      description: json['description'] as String?,
    );
  }
}

class AdminCategory {
  final int categoryId;
  final String name;
  final int sortOrder;
  final int bookCount;

  AdminCategory({
    required this.categoryId,
    required this.name,
    required this.sortOrder,
    required this.bookCount,
  });

  factory AdminCategory.fromJson(Map<String, dynamic> json) {
    return AdminCategory(
      categoryId: parseInt(json['category_id']),
      name: json['category_name'] as String? ?? '',
      sortOrder: parseInt(json['sort_order']),
      bookCount: parseInt(json['book_count']),
    );
  }
}

class AdminLevel {
  final int levelId;
  final String name;
  final int minPoints;
  final int? maxPoints;
  final String benefits;

  AdminLevel({
    required this.levelId,
    required this.name,
    required this.minPoints,
    required this.benefits,
    this.maxPoints,
  });

  factory AdminLevel.fromJson(Map<String, dynamic> json) {
    return AdminLevel(
      levelId: parseInt(json['level_id']),
      name: json['level_name'] as String? ?? '',
      minPoints: parseInt(json['min_points']),
      maxPoints: json['max_points'] == null ? null : parseInt(json['max_points']),
      benefits: json['benefits'] as String? ?? '',
    );
  }
}

class AdminStatPoint {
  final String date;
  final int orders;
  final double revenue;
  final int newUsers;
  final int newBooks;

  AdminStatPoint({
    required this.date,
    required this.orders,
    required this.revenue,
    required this.newUsers,
    required this.newBooks,
  });

  factory AdminStatPoint.fromJson(Map<String, dynamic> json) {
    return AdminStatPoint(
      date: json['date'] as String? ?? '',
      orders: parseInt(json['orders']),
      revenue: parseDouble(json['revenue']),
      newUsers: parseInt(json['new_users']),
      newBooks: parseInt(json['new_books']),
    );
  }
}

class AdminStats {
  final int days;
  final List<AdminStatPoint> series;
  final int completedOrderCount;
  final double completedRevenue;
  final List<({String name, int count})> topCategories;

  AdminStats({
    required this.days,
    required this.series,
    required this.completedOrderCount,
    required this.completedRevenue,
    required this.topCategories,
  });

  factory AdminStats.fromJson(Map<String, dynamic> json) {
    return AdminStats(
      days: parseInt(json['days']),
      series: ((json['series'] as List?) ?? const [])
          .map((e) => AdminStatPoint.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      completedOrderCount: parseInt(json['completed_order_count']),
      completedRevenue: parseDouble(json['completed_revenue']),
      topCategories: ((json['top_categories'] as List?) ?? const [])
          .map((e) => (
                name: (e as Map)['category_name'] as String? ?? S.uncategorised,
                count: parseInt(e['book_count']),
              ))
          .toList(),
    );
  }

  static AdminStats get empty => AdminStats(
        days: 7,
        series: const [],
        completedOrderCount: 0,
        completedRevenue: 0,
        topCategories: const [],
      );
}

class AdminOperationLog {
  final int logId;
  final String action;
  final String? targetType;
  final int? targetId;
  final String? detail;
  final String adminName;
  final DateTime? createdAt;

  AdminOperationLog({
    required this.logId,
    required this.action,
    required this.adminName,
    this.targetType,
    this.targetId,
    this.detail,
    this.createdAt,
  });

  factory AdminOperationLog.fromJson(Map<String, dynamic> json) {
    final admin = json['admin'] as Map<String, dynamic>?;

    return AdminOperationLog(
      logId: parseInt(json['log_id']),
      action: json['action'] as String? ?? '',
      targetType: json['target_type'] as String?,
      targetId: json['target_id'] == null ? null : parseInt(json['target_id']),
      detail: json['detail'] as String?,
      adminName: admin?['nickname'] as String? ?? S.roleAdmin,
      createdAt: parseDate(json['created_at']),
    );
  }
}

class AdminWallet {
  final int userId;
  final String nickname;
  final String email;
  final String? avatarUrl;
  final double balance;
  final double frozenAmount;
  final double totalIncome;
  final double totalExpense;

  AdminWallet({
    required this.userId,
    required this.nickname,
    required this.email,
    required this.balance,
    required this.frozenAmount,
    required this.totalIncome,
    required this.totalExpense,
    this.avatarUrl,
  });

  factory AdminWallet.fromJson(Map<String, dynamic> json) {
    return AdminWallet(
      userId: parseInt(json['user_id']),
      nickname: json['nickname'] as String? ?? '',
      email: json['email'] as String? ?? '',
      avatarUrl: resolveAssetUrl(json['avatar_url']),
      balance: parseDouble(json['balance']),
      frozenAmount: parseDouble(json['frozen_amount']),
      totalIncome: parseDouble(json['total_income']),
      totalExpense: parseDouble(json['total_expense']),
    );
  }
}

class AdminWalletTxn {
  final int txnId;
  final String type;
  final double amount;
  final double balanceAfter;
  final String description;
  final DateTime? createdAt;

  AdminWalletTxn({
    required this.txnId,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    required this.description,
    this.createdAt,
  });

  String get typeText => AppLabels.walletTxnType[type] ?? type;

  factory AdminWalletTxn.fromJson(Map<String, dynamic> json) {
    return AdminWalletTxn(
      txnId: parseInt(json['txn_id']),
      type: json['type'] as String? ?? '',
      amount: parseDouble(json['amount']),
      balanceAfter: parseDouble(json['balance_after']),
      description: json['description'] as String? ?? '',
      createdAt: parseDate(json['created_at']),
    );
  }
}

class AdminWalletDetail {
  final AdminWallet wallet;
  final List<AdminWalletTxn> transactions;

  AdminWalletDetail({required this.wallet, required this.transactions});

  factory AdminWalletDetail.fromJson(Map<String, dynamic> json) {
    return AdminWalletDetail(
      wallet: AdminWallet.fromJson(json),
      transactions: ((json['transactions'] as List?) ?? const [])
          .map((e) => AdminWalletTxn.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class AdminMemberDetail {
  final int userId;
  final String nickname;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final String role;
  final bool isActive;
  final bool isBlacklisted;
  final int bookCount;
  final int completedOrders;
  final int basePoints;
  final int bonusPoints;
  final int points;
  final AdminLevel? currentLevel;
  final List<AdminLevel> levels;
  final Map<String, bool> permissions;
  final DateTime? createdAt;

  AdminMemberDetail({
    required this.userId,
    required this.nickname,
    required this.email,
    required this.role,
    required this.isActive,
    required this.isBlacklisted,
    required this.bookCount,
    required this.completedOrders,
    required this.basePoints,
    required this.bonusPoints,
    required this.points,
    required this.levels,
    required this.permissions,
    this.phone,
    this.avatarUrl,
    this.currentLevel,
    this.createdAt,
  });

  bool get isAdmin => role == 'admin';

  /// 權限鍵值 -> (名稱, 說明)，順序即畫面上的顯示順序。

  factory AdminMemberDetail.fromJson(Map<String, dynamic> json) {
    final perms = <String, bool>{};
    final raw = json['permissions'];
    if (raw is Map) {
      for (final entry in raw.entries) {
        perms['${entry.key}'] = entry.value == true;
      }
    }

    return AdminMemberDetail(
      userId: parseInt(json['user_id']),
      nickname: json['nickname'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String?,
      avatarUrl: resolveAssetUrl(json['avatar_url']),
      role: json['role'] as String? ?? 'buyer_seller',
      isActive: json['is_active'] == true,
      isBlacklisted: json['is_blacklisted'] == true,
      bookCount: parseInt(json['book_count']),
      completedOrders: parseInt(json['completed_orders']),
      basePoints: parseInt(json['base_points']),
      bonusPoints: parseInt(json['bonus_points']),
      points: parseInt(json['points']),
      currentLevel: json['current_level'] == null
          ? null
          : AdminLevel.fromJson(Map<String, dynamic>.from(json['current_level'])),
      levels: ((json['levels'] as List?) ?? const [])
          .map((e) => AdminLevel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      permissions: perms,
      createdAt: parseDate(json['created_at']),
    );
  }
}

class BackupRecord {
  final int backupId;
  final String fileName;
  final int sizeBytes;
  final String triggerBy;
  final String status;
  final String? detail;
  final DateTime? createdAt;
  final String adminName;

  /// 檔案可能因保留份數輪替或人工刪除而不在磁碟上，用來決定能否下載。
  final bool available;

  const BackupRecord({
    required this.backupId,
    required this.fileName,
    required this.sizeBytes,
    required this.triggerBy,
    required this.status,
    required this.available,
    this.detail,
    this.createdAt,
    this.adminName = '',
  });

  bool get isSuccess => status == 'success';
  bool get isManual => triggerBy == 'manual';

  String get sizeText {
    if (sizeBytes <= 0) return '—';
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = sizeBytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit += 1;
    }
    return '${value.toStringAsFixed(unit == 0 ? 0 : 1)} ${units[unit]}';
  }

  factory BackupRecord.fromJson(Map<String, dynamic> json) {
    final admin = json['admin'] as Map<String, dynamic>?;
    return BackupRecord(
      backupId: parseInt(json['backup_id']),
      fileName: json['file_name'] as String? ?? '',
      sizeBytes: parseInt(json['size_bytes']),
      triggerBy: json['trigger_by'] as String? ?? 'schedule',
      status: json['status'] as String? ?? 'success',
      detail: json['detail'] as String?,
      createdAt: parseDate(json['created_at']),
      adminName: admin?['nickname'] as String? ?? '',
      available: json['available'] == true,
    );
  }
}

class PendingDeletion {
  final int userId;
  final String nickname;
  final String email;
  final String? avatarUrl;
  final DateTime? requestedAt;
  final DateTime? purgeAt;

  const PendingDeletion({
    required this.userId,
    required this.nickname,
    required this.email,
    this.avatarUrl,
    this.requestedAt,
    this.purgeAt,
  });

  int get daysLeft {
    if (purgeAt == null) return 0;
    return purgeAt!.difference(DateTime.now()).inDays.clamp(0, 3650);
  }

  factory PendingDeletion.fromJson(Map<String, dynamic> json) => PendingDeletion(
        userId: parseInt(json['user_id']),
        nickname: json['nickname'] as String? ?? '',
        email: json['email'] as String? ?? '',
        avatarUrl: resolveAssetUrl(json['avatar_url']),
        requestedAt: parseDate(json['deletion_requested_at']),
        purgeAt: parseDate(json['purge_at']),
      );
}
