import '../utils/api_helpers.dart';
import '../utils/app_labels.dart';

class FaqItem {
  final int faqId;
  final String category;
  final String question;
  final String answer;
  final int sortOrder;
  final bool isVisible;

  FaqItem({
    required this.faqId,
    required this.category,
    required this.question,
    required this.answer,
    required this.sortOrder,
    required this.isVisible,
  });

  String get categoryText => AppLabels.faqCategory[category] ?? category;

  factory FaqItem.fromJson(Map<String, dynamic> json) {
    return FaqItem(
      faqId: parseInt(json['faq_id']),
      category: json['category'] as String? ?? 'general',
      question: json['question'] as String? ?? '',
      answer: json['answer'] as String? ?? '',
      sortOrder: parseInt(json['sort_order']),
      isVisible: json['is_visible'] != false,
    );
  }
}

class LegalDoc {
  final String key;
  final String title;
  final String content;
  final DateTime? updatedAt;

  LegalDoc({
    required this.key,
    required this.title,
    required this.content,
    this.updatedAt,
  });

  factory LegalDoc.fromJson(Map<String, dynamic> json) {
    return LegalDoc(
      key: json['doc_key'] as String? ?? '',
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      updatedAt: parseDate(json['updated_at']),
    );
  }
}

class TicketMessage {
  final int messageId;
  final String content;
  final bool isStaff;
  final String senderName;
  final String? senderAvatar;
  final DateTime? createdAt;

  TicketMessage({
    required this.messageId,
    required this.content,
    required this.isStaff,
    required this.senderName,
    this.senderAvatar,
    this.createdAt,
  });

  factory TicketMessage.fromJson(Map<String, dynamic> json) {
    final sender = json['sender'] as Map<String, dynamic>?;
    return TicketMessage(
      messageId: parseInt(json['message_id']),
      content: json['content'] as String? ?? '',
      isStaff: json['is_staff'] == true,
      senderName: sender?['nickname'] as String? ?? '',
      senderAvatar: resolveAssetUrl(sender?['avatar_url']),
      createdAt: parseDate(json['created_at']),
    );
  }
}

class SupportTicket {
  final int ticketId;
  final String subject;
  final String category;
  final String status;
  final int messageCount;
  final String? lastMessage;
  final String userName;
  final String? userAvatar;
  final DateTime? updatedAt;
  final List<TicketMessage> messages;

  SupportTicket({
    required this.ticketId,
    required this.subject,
    required this.category,
    required this.status,
    required this.messageCount,
    this.lastMessage,
    this.userName = '',
    this.userAvatar,
    this.updatedAt,
    this.messages = const [],
  });

  String get categoryText => AppLabels.ticketCategory[category] ?? category;
  String get statusText => AppLabels.ticket(status);
  bool get isClosed => status == 'closed';

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    return SupportTicket(
      ticketId: parseInt(json['ticket_id']),
      subject: json['subject'] as String? ?? '',
      category: json['category'] as String? ?? 'other',
      status: json['status'] as String? ?? 'open',
      messageCount: parseInt(json['message_count']),
      lastMessage: json['last_message'] as String?,
      userName: user?['nickname'] as String? ?? '',
      userAvatar: resolveAssetUrl(user?['avatar_url']),
      updatedAt: parseDate(json['updated_at']),
      messages: ((json['messages'] as List?) ?? const [])
          .map((e) => TicketMessage.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}
