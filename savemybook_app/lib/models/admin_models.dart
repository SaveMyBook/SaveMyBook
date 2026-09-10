import '../utils/api_helpers.dart';

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
      case 'maintenance': return '系統維護';
      case 'promotion': return '活動優惠';
      case 'policy': return '政策更新';
      case 'general':
      default: return '一般公告';
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

  String get statusText {
    if (isBlacklisted) return '黑名單';
    if (!isActive) return '已停權';
    return '正常';
  }

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
      case 'book': return '商品';
      case 'user': return '會員';
      case 'message': return '訊息';
      default: return targetType;
    }
  }

  String get statusText {
    switch (status) {
      case 'pending': return '待處理';
      case 'reviewing': return '審核中';
      case 'resolved': return '已處理';
      case 'dismissed': return '已駁回';
      default: return status;
    }
  }

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
      targetTitle: (target?['title'] ?? target?['nickname']) as String? ?? '(對象已不存在)',
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

  String get statusText {
    switch (status) {
      case 'pending': return '待受理';
      case 'processing': return '處理中';
      case 'resolved': return '已裁決';
      default: return status;
    }
  }

  String get resultText {
    switch (result) {
      case 'refund_manual': return '人工退款';
      case 'refund_auto': return '自動退款';
      case 'dismissed': return '駁回申訴';
      case 'mediated': return '協調結案';
      default: return '';
    }
  }

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

  String get statusText {
    switch (status) {
      case 'empty': return '空置';
      case 'occupied': return '使用中';
      case 'reserved': return '已預約';
      case 'maintenance': return '維修中';
      default: return status;
    }
  }

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

  AdminOverview({
    required this.memberCount,
    required this.pendingReportCount,
    required this.pendingDisputeCount,
    required this.activeCabinetCount,
    required this.todayOrderCount,
  });

  factory AdminOverview.fromJson(Map<String, dynamic> json) {
    return AdminOverview(
      memberCount: parseInt(json['member_count']),
      pendingReportCount: parseInt(json['pending_report_count']),
      pendingDisputeCount: parseInt(json['pending_dispute_count']),
      activeCabinetCount: parseInt(json['active_cabinet_count']),
      todayOrderCount: parseInt(json['today_order_count']),
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

  static const statusLabels = {
    'pending_payment': '待付款',
    'pending_deposit': '待存書',
    'deposited': '已存書',
    'pending_pickup': '待取書',
    'completed': '已完成',
    'cancelled': '已取消',
    'refunding': '退款中',
    'refunded': '已退款',
  };

  String get statusText => statusLabels[status] ?? status;

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
  final String categoryName;
  final String sellerName;
  final int viewCount;
  final int pendingReportCount;
  final String? imageUrl;
  final DateTime? createdAt;

  AdminBook({
    required this.bookId,
    required this.title,
    required this.price,
    required this.status,
    required this.categoryName,
    required this.sellerName,
    required this.viewCount,
    required this.pendingReportCount,
    this.isbn,
    this.imageUrl,
    this.createdAt,
  });

  static const statusLabels = {
    'on_sale': '販售中',
    'reserved': '已預訂',
    'sold': '已售出',
    'removed': '已下架',
  };

  String get statusText => statusLabels[status] ?? status;

  factory AdminBook.fromJson(Map<String, dynamic> json) {
    final seller = json['seller'] as Map<String, dynamic>?;

    return AdminBook(
      bookId: parseInt(json['book_id']),
      title: json['title'] as String? ?? '',
      isbn: json['isbn'] as String?,
      price: parseDouble(json['price']),
      status: json['status'] as String? ?? '',
      categoryName: json['category_name'] as String? ?? '',
      sellerName: seller?['nickname'] as String? ?? '—',
      viewCount: parseInt(json['view_count']),
      pendingReportCount: parseInt(json['pending_report_count']),
      imageUrl: resolveAssetUrl(json['image_url']),
      createdAt: parseDate(json['created_at']),
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
                name: (e as Map)['category_name'] as String? ?? '未分類',
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
      adminName: admin?['nickname'] as String? ?? '管理員',
      createdAt: parseDate(json['created_at']),
    );
  }
}

