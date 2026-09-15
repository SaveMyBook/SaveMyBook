part of '../api_service.dart';

extension AnnouncementsApi on ApiService {
  Future<List<Announcement>> fetchAnnouncements({bool includeDrafts = false}) async {
    final res = await _send('GET', includeDrafts ? '/announcements/all' : '/announcements');
    return _mapList(res, Announcement.fromJson);
  }

  Future<String?> saveAnnouncement({
    int? announcementId,
    required String title,
    required String content,
    required String type,
    required bool isPublished,
  }) async {
    final body = {
      'title': title,
      'content': content,
      'type': type,
      'is_published': isPublished,
    };
    final res = announcementId == null
        ? await _send('POST', '/announcements', body: body)
        : await _send('PUT', '/announcements/$announcementId', body: body);
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.couldNotSaveAnnouncement);
  }

  Future<bool> deleteAnnouncement(int announcementId) async {
    final res = await _send('DELETE', '/announcements/$announcementId');
    return res != null && res['success'] == true;
  }

  Future<Announcement?> fetchAnnouncement(int announcementId) async {
    final res = await _send('GET', '/announcements/$announcementId');
    if (res == null || res['success'] != true || res['data'] is! Map) return null;
    return Announcement.fromJson(Map<String, dynamic>.from(res['data']));
  }
}
