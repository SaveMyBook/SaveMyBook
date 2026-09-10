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
