import 'package:flutter/material.dart';
import '../utils/api_helpers.dart';

class AppNotification {
  final int notificationId;
  final String type;
  final String title;
  final String content;
  final int? relatedId;
  final String? relatedType;
  final bool isRead;
  final DateTime? createdAt;

  AppNotification({
    required this.notificationId,
    required this.type,
    required this.title,
    required this.content,
    required this.isRead,
    this.relatedId,
    this.relatedType,
    this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      notificationId: parseInt(json['notification_id']),
      type: json['type'] as String? ?? 'system',
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      relatedId: json['related_id'] == null ? null : parseInt(json['related_id']),
      relatedType: json['related_type'] as String?,
      isRead: json['is_read'] == true,
      createdAt: parseDate(json['created_at']),
    );
  }

  IconData get icon {
    switch (type) {
      case 'order': return Icons.receipt_long_rounded;
      case 'message': return Icons.chat_bubble_outline_rounded;
      case 'promotion': return Icons.local_offer_outlined;
      case 'reservation': return Icons.event_available_outlined;
      case 'system':
      default: return Icons.campaign_outlined;
    }
  }
}
