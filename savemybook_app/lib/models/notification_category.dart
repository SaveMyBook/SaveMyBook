import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../i18n/strings.dart';

enum NotificationCategory {
  trade('trade'),
  chat('chat'),
  account('account'),
  service('service'),
  promotion('promotion');

  final String key;
  const NotificationCategory(this.key);

  static const _byType = {
    'order': trade,
    'reservation': trade,
    'message': chat,
    'promotion': promotion,
  };

  static const _byRelatedType = {
    'order': trade,
    'wallet': trade,
    'book': trade,
    'reservation': trade,
    'chat_room': chat,
    'security': account,
    'password': account,
    'legal': account,
    'member_level': account,
    'user': account,
    'push_test': account,
    'ticket': service,
    'report': service,
    'admin_ticket': service,
    'book_review': service,
    'risk_alert': service,
    'announcement': promotion,
  };

  static NotificationCategory? fromKey(String? key) {
    for (final category in values) {
      if (category.key == key) return category;
    }
    return null;
  }

  // 須與 savemybook_api/services/notification-categories.js 一致：type 優先於 related_type。
  static NotificationCategory of(String type, String? relatedType) =>
      _byType[type] ?? _byRelatedType[relatedType] ?? account;

  String get label => switch (this) {
        trade => S.faqCatTrade,
        chat => S.chat,
        account => S.faqCatAccount,
        service => S.support,
        promotion => S.offers,
      };

  String get emptyMessage => switch (this) {
        trade => S.noTransactionNotifications,
        chat => S.noChatNotifications,
        account => S.noAccountNotifications,
        service => S.noSupportNotifications,
        promotion => S.noOfferNotifications,
      };

  IconData get icon => switch (this) {
        trade => Icons.receipt_long_rounded,
        chat => Icons.chat_bubble_outline_rounded,
        account => Icons.verified_user_outlined,
        service => Icons.support_agent_rounded,
        promotion => Icons.local_offer_outlined,
      };

  Color toneOf(AppColors c) => switch (this) {
        trade => c.isDark ? const Color(0xFFA592F0) : const Color(0xFF6A4FC8),
        chat => c.isDark ? const Color(0xFF6FA8F0) : const Color(0xFF2F6FD0),
        account => c.success,
        service => c.warning,
        promotion => c.isDark ? const Color(0xFFEF7FA8) : const Color(0xFFCC3F74),
      };
}
