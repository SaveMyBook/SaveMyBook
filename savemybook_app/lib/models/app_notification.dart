import 'package:flutter/material.dart';
import '../utils/api_helpers.dart';
import 'notification_category.dart';

class AppNotification {
  final int notificationId;
  final String type;
  final String title;
  final String content;
  final int? relatedId;
  final String? relatedType;
  final bool isRead;
  final DateTime? createdAt;
  final NotificationCategory category;

  AppNotification({
    required this.notificationId,
    required this.type,
    required this.title,
    required this.content,
    required this.isRead,
    this.relatedId,
    this.relatedType,
    this.createdAt,
    NotificationCategory? category,
  }) : category = category ?? NotificationCategory.of(type, relatedType);

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      category: NotificationCategory.fromKey(json['category'] as String?),
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

  IconData get icon => category.icon;

  AppNotification asRead() => isRead
      ? this
      : AppNotification(
          notificationId: notificationId,
          type: type,
          title: title,
          content: content,
          relatedId: relatedId,
          relatedType: relatedType,
          isRead: true,
          createdAt: createdAt,
          category: category,
        );
}
