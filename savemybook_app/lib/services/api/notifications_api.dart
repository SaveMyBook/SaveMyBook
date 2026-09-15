part of '../api_service.dart';

extension NotificationsApi on ApiService {
  Future<List<AppNotification>> fetchNotifications() async {
    final res = await _send('GET', '/notifications', query: {'limit': '50'});
    if (res != null && res['unread_count'] != null) {
      ApiService._setBadge(ApiService.unreadNotificationCount, int.tryParse('${res['unread_count']}') ?? 0);
    }
    return _mapList(res, AppNotification.fromJson);
  }

  Future<int> fetchUnreadNotificationCount() async {
    final res = await _send('GET', '/notifications/unread-count');
    if (res == null || res['success'] != true) return 0;
    final count = int.tryParse('${res['data']?['unread_count']}') ?? 0;
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

  Future<bool> markNotificationRead(int notificationId) async {
    final res = await _send('PATCH', '/notifications/$notificationId/read');
    final ok = res != null && res['success'] == true;
    if (ok) ApiService._setBadge(ApiService.unreadNotificationCount, ApiService.unreadNotificationCount.value - 1);
    return ok;
  }

  Future<bool> markAllNotificationsRead() async {
    final res = await _send('PATCH', '/notifications/read-all');
    final ok = res != null && res['success'] == true;
    if (ok) ApiService._setBadge(ApiService.unreadNotificationCount, 0);
    return ok;
  }

  Future<bool> clearAllNotifications() async {
    final res = await _send('DELETE', '/notifications/all');
    final ok = res != null && res['success'] == true;
    if (ok) ApiService._setBadge(ApiService.unreadNotificationCount, 0);
    return ok;
  }

  Future<bool> deleteNotification(int notificationId) async {
    final res = await _send('DELETE', '/notifications/$notificationId');
    return res != null && res['success'] == true;
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
