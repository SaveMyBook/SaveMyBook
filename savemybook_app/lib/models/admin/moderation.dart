import '../../utils/api_helpers.dart';
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


/// 管理員裁決前的 AI 爭議分析，僅供參考。
class DisputeAnalysis {
  final String summary;
  final List<String> findings;
  final String suggestion;
  final double confidence;
  final String rationale;

  const DisputeAnalysis({
    required this.summary,
    required this.findings,
    required this.suggestion,
    required this.confidence,
    required this.rationale,
  });

  factory DisputeAnalysis.fromJson(Map<String, dynamic> json) => DisputeAnalysis(
        summary: json['summary'] as String? ?? '',
        findings: [for (final f in (json['findings'] as List? ?? const [])) '$f'],
        suggestion: json['suggestion'] as String? ?? 'need_more_info',
        confidence: parseDouble(json['confidence']).clamp(0.0, 1.0),
        rationale: json['rationale'] as String? ?? '',
      );
}
