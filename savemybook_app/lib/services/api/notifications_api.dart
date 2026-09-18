part of '../api_service.dart';

class NotificationPage {
  final List<AppNotification> items;
  final int total;
  final bool hasMore;
  final bool ok;

  const NotificationPage({required this.items, required this.total, required this.hasMore, this.ok = true});

  static const failed = NotificationPage(items: [], total: 0, hasMore: false, ok: false);
}

extension NotificationsApi on ApiService {
  static const notificationPageSize = 20;

  Future<NotificationPage> fetchNotificationPage({NotificationCategory? category, int page = 1}) async {
    final res = await _send('GET', '/notifications', query: {
      'page': '$page',
      'limit': '$notificationPageSize',
      if (category != null) 'category': category.key,
    });
    if (res == null || res['success'] != true) return NotificationPage.failed;
    if (res['unread_count'] != null) {
      ApiService._setBadge(ApiService.unreadNotificationCount, int.tryParse('${res['unread_count']}') ?? 0);
    }
    final items = _mapList(res, AppNotification.fromJson);
    final pagination = res['pagination'];
    final total = pagination is Map ? parseInt(pagination['total']) : items.length;
    final totalPages = pagination is Map ? parseInt(pagination['total_pages']) : page;
    return NotificationPage(items: items, total: total, hasMore: page < totalPages);
  }

  Future<int> fetchUnreadNotificationCount() async {
    final res = await _send('GET', '/notifications/unread-count');
    if (res == null || res['success'] != true) return 0;
    final count = int.tryParse('${res['data']?['unread_count']}') ?? 0;
    final byCategory = res['data']?['by_category'];
    ApiService.unreadNotificationsByCategory.value = {
      for (final category in NotificationCategory.values)
        category: byCategory is Map ? parseInt(byCategory[category.key]) : 0,
    };
    ApiService._setBadge(ApiService.unreadNotificationCount, count);
    return count;
  }

  Future<void> refreshBadges() async {
    if (ApiService.authToken == null) {
      ApiService.resetGlobalState();
      return;
    }
    await Future.wait([
      fetchCartBookIds(),
      fetchUnreadNotificationCount(),
      fetchUnreadChatCount(),
      fetchFavoriteIds(),
    ]);
  }

  Future<bool> markNotificationRead(int notificationId, {NotificationCategory? category}) async {
    final res = await _send('PATCH', '/notifications/$notificationId/read');
    final ok = res != null && res['success'] == true;
    if (ok) {
      ApiService._setBadge(ApiService.unreadNotificationCount, ApiService.unreadNotificationCount.value - 1);
      if (category != null) _adjustCategoryUnread(category, -1);
    }
    return ok;
  }

  Future<bool> markAllNotificationsRead({NotificationCategory? category}) async {
    final res = await _send('PATCH', '/notifications/read-all', query: {if (category != null) 'category': category.key});
    final ok = res != null && res['success'] == true;
    if (ok) await _afterBulkChange(category);
    return ok;
  }

  Future<bool> clearAllNotifications({NotificationCategory? category}) async {
    final res = await _send('DELETE', '/notifications/all', query: {if (category != null) 'category': category.key});
    final ok = res != null && res['success'] == true;
    if (ok) await _afterBulkChange(category);
    return ok;
  }

  Future<bool> deleteNotification(int notificationId) async {
    final res = await _send('DELETE', '/notifications/$notificationId');
    return res != null && res['success'] == true;
  }

  Future<void> _afterBulkChange(NotificationCategory? category) async {
    if (category == null) {
      ApiService._setBadge(ApiService.unreadNotificationCount, 0);
      ApiService.unreadNotificationsByCategory.value = {for (final c in NotificationCategory.values) c: 0};
      return;
    }
    final cleared = ApiService.unreadNotificationsByCategory.value[category] ?? 0;
    _adjustCategoryUnread(category, -cleared);
    ApiService._setBadge(ApiService.unreadNotificationCount, ApiService.unreadNotificationCount.value - cleared);
    await fetchUnreadNotificationCount();
  }

  void _adjustCategoryUnread(NotificationCategory category, int delta) {
    final next = Map<NotificationCategory, int>.from(ApiService.unreadNotificationsByCategory.value);
    final value = (next[category] ?? 0) + delta;
    next[category] = value < 0 ? 0 : value;
    ApiService.unreadNotificationsByCategory.value = next;
  }

  Future<NotificationSettings?> fetchNotificationSettings() async {
    final res = await _send('GET', '/users/me/notification-settings');
    if (res == null || res['success'] != true || res['data'] is! Map) return null;
    return NotificationSettings.fromJson(Map<String, dynamic>.from(res['data']));
  }

  Future<NotificationSettings?> updateNotificationSettings(Map<String, bool> changes) async {
    final res = await _send('PUT', '/users/me/notification-settings', body: changes);
    if (res == null || res['success'] != true || res['data'] is! Map) return null;
    return NotificationSettings.fromJson(Map<String, dynamic>.from(res['data']));
  }
}
