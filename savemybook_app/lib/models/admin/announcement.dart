import '../../utils/api_helpers.dart';
import '../../i18n/strings.dart';

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
