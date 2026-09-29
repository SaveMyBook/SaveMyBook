import '../../utils/api_helpers.dart';
import '../chat.dart';
import '../../utils/app_labels.dart';
import '../../i18n/strings.dart';

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
  final ReportedMessage? message;

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
    this.message,
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
    final targetType = json['target_type'] as String? ?? 'book';
    final message = targetType == 'message' && target != null ? ReportedMessage.fromJson(target) : null;

    return ReportCase(
      reportId: parseInt(json['report_id']),
      targetType: targetType,
      targetId: parseInt(json['target_id']),
      reason: json['reason'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      adminNote: json['admin_note'] as String?,
      createdAt: parseDate(json['created_at']),
      resolvedAt: parseDate(json['resolved_at']),
      reporterName:
          (json['users_reports_reporter_idTousers'] as Map<String, dynamic>?)?['nickname'] as String? ?? '',
      targetTitle: message?.message.preview ?? (target?['title'] ?? target?['nickname']) as String? ?? S.noLongerExists,
      targetImageUrl: message != null
          ? message.message.imageUrls.firstOrNull
          : images.isEmpty ? null : resolveAssetUrl((images.first as Map)['image_url']),
      message: message,
    );
  }
}

class ReportedMessage {
  final ChatMessage message;
  final String senderNo;

  const ReportedMessage({required this.message, this.senderNo = ''});

  factory ReportedMessage.fromJson(Map<String, dynamic> json) => ReportedMessage(
        message: ChatMessage.fromJson(json),
        senderNo: json['sender_no'] as String? ?? '',
      );
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
  final List<String> evidenceImages;

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
    this.evidenceImages = const [],
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
      evidenceImages: [for (final url in json['evidence_images'] as List? ?? const []) ?resolveAssetUrl(url)],
    );
  }
}


/// AI 爭議分析的觀察重點；photos 為分析時送出的照片編號，對應 [DisputeAnalysisPhoto.no]。
class DisputeFinding {
  final String content;
  final String? basis;
  final List<int> photos;
  final String favors;

  const DisputeFinding({required this.content, this.basis, this.photos = const [], this.favors = 'neutral'});

  factory DisputeFinding.fromJson(Map<String, dynamic> json) => DisputeFinding(
        content: json['content'] as String? ?? '',
        basis: json['basis'] as String?,
        photos: [for (final n in (json['photos'] as List? ?? const [])) parseInt(n)],
        favors: json['favors'] as String? ?? 'neutral',
      );
}

class DisputeAnalysisPhoto {
  final int no;
  final String source;
  final String? type;
  final String title;

  const DisputeAnalysisPhoto({required this.no, required this.source, this.type, this.title = ''});

  bool get isListing => source == 'listing';

  factory DisputeAnalysisPhoto.fromJson(Map<String, dynamic> json) => DisputeAnalysisPhoto(
        no: parseInt(json['no']),
        source: json['source'] as String? ?? 'evidence',
        type: json['type'] as String?,
        title: json['title'] as String? ?? '',
      );
}

class DisputeAnalysis {
  /// 評價時帶回，確保評價記在畫面上這一次分析。
  final String analysisNo;
  final String summary;
  final List<DisputeFinding> findings;
  final String suggestion;
  final String confidenceLevel;
  final String rationale;
  final int listingPhotos;
  final int evidencePhotos;
  final int skippedPhotos;
  final List<DisputeAnalysisPhoto> photos;

  /// 管理員評價是否有幫助；尚未評價時為 null。
  final bool? helpful;
  final DateTime? createdAt;

  const DisputeAnalysis({
    this.analysisNo = '',
    required this.summary,
    required this.findings,
    required this.suggestion,
    required this.confidenceLevel,
    required this.rationale,
    this.listingPhotos = 0,
    this.evidencePhotos = 0,
    this.skippedPhotos = 0,
    this.photos = const [],
    this.helpful,
    this.createdAt,
  });

  DisputeAnalysisPhoto? photo(int no) {
    for (final p in photos) {
      if (p.no == no) return p;
    }
    return null;
  }

  DisputeAnalysis withHelpful(bool value) => DisputeAnalysis(
        analysisNo: analysisNo,
        summary: summary,
        findings: findings,
        suggestion: suggestion,
        confidenceLevel: confidenceLevel,
        rationale: rationale,
        listingPhotos: listingPhotos,
        evidencePhotos: evidencePhotos,
        skippedPhotos: skippedPhotos,
        photos: photos,
        helpful: value,
        createdAt: createdAt,
      );

  // 舊版伺服器只回傳字串陣列的 findings 與 0 到 1 的 confidence。
  static String _levelOf(Object? level, Object? legacy) {
    if (level is String && const ['low', 'medium', 'high'].contains(level)) return level;
    final n = parseDouble(legacy);
    return n >= 0.75 ? 'high' : (n >= 0.4 ? 'medium' : 'low');
  }

  factory DisputeAnalysis.fromJson(Map<String, dynamic> json) {
    final details = json['finding_details'];
    final images = json['images'] is Map ? Map<String, dynamic>.from(json['images']) : const <String, dynamic>{};
    return DisputeAnalysis(
      analysisNo: json['analysis_no'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      findings: details is List
          ? [for (final f in details) if (f is Map) DisputeFinding.fromJson(Map<String, dynamic>.from(f))]
          : [for (final f in (json['findings'] as List? ?? const [])) DisputeFinding(content: '$f')],
      suggestion: json['suggestion'] as String? ?? 'need_more_info',
      confidenceLevel: _levelOf(json['confidence_level'], json['confidence']),
      rationale: json['rationale'] as String? ?? '',
      listingPhotos: parseInt(images['listing']),
      evidencePhotos: parseInt(images['evidence']),
      skippedPhotos: parseInt(images['skipped']),
      photos: [
        for (final p in (json['photos'] as List? ?? const []))
          if (p is Map) DisputeAnalysisPhoto.fromJson(Map<String, dynamic>.from(p)),
      ],
      helpful: json['helpful'] is bool ? json['helpful'] as bool : null,
      createdAt: parseDate(json['created_at']),
    );
  }
}

class ChatRiskSample {
  final String content;
  final List<ChatRiskCategory> categories;
  final DateTime? createdAt;

  const ChatRiskSample({required this.content, required this.categories, this.createdAt});

  factory ChatRiskSample.fromJson(Map<String, dynamic> json) => ChatRiskSample(
        content: json['content'] as String? ?? '',
        categories: ChatRisk.fromJson({'categories': json['categories']})?.categories ?? const [],
        createdAt: parseDate(json['created_at']),
      );
}

class ChatRiskAlert {
  final int alertId;
  final String status;
  final int hitCount;
  final DateTime? firstAt;
  final DateTime? lastAt;
  final int userId;
  final String userNo;
  final String nickname;
  final String? avatarUrl;
  final bool isActive;
  final bool isBlacklisted;
  final List<ChatRiskSample> samples;

  const ChatRiskAlert({
    required this.alertId,
    required this.status,
    required this.hitCount,
    required this.userId,
    required this.userNo,
    required this.nickname,
    this.firstAt,
    this.lastAt,
    this.avatarUrl,
    this.isActive = true,
    this.isBlacklisted = false,
    this.samples = const [],
  });

  factory ChatRiskAlert.fromJson(Map<String, dynamic> json) {
    final user = json['user'] is Map ? Map<String, dynamic>.from(json['user']) : const <String, dynamic>{};
    return ChatRiskAlert(
      alertId: parseInt(json['alert_id']),
      status: json['status'] as String? ?? 'open',
      hitCount: parseInt(json['hit_count']),
      firstAt: parseDate(json['first_at']),
      lastAt: parseDate(json['last_at']),
      userId: parseInt(user['user_id']),
      userNo: user['user_no'] as String? ?? '',
      nickname: user['nickname'] as String? ?? '',
      avatarUrl: resolveAssetUrl(user['avatar_url']),
      isActive: user['is_active'] != false,
      isBlacklisted: user['is_blacklisted'] == true,
      samples: [
        for (final s in json['samples'] as List? ?? const [])
          if (s is Map) ChatRiskSample.fromJson(Map<String, dynamic>.from(s)),
      ],
    );
  }
}
