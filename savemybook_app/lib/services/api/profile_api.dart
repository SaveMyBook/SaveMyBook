part of '../api_service.dart';

extension ProfileApi on ApiService {
  Future<UserStats> fetchUserStats() async {
    final res = await _send('GET', '/users/me/stats');
    if (res == null || res['success'] != true || res['data'] is! Map) return UserStats.empty;
    final stats = UserStats.fromJson(Map<String, dynamic>.from(res['data']));
    ApiService._setCartCount(stats.cartCount);
    return stats;
  }

  Future<MemberLevelInfo> fetchMemberLevel() async {
    final res = await _send('GET', '/users/me/level');
    if (res == null || res['success'] != true || res['data'] is! Map) return MemberLevelInfo.empty;
    return MemberLevelInfo.fromJson(Map<String, dynamic>.from(res['data']));
  }

  Future<String?> updateProfile({
    String? nickname,
    String? bio,
    String? phone,
    String? birthday,
  }) async {
    final res = await _send('PUT', '/users/me', body: {
      'nickname': ?nickname,
      'bio': ?bio,
      'phone': ?phone,
      'birthday': ?birthday,
    });
    if (res == null) return S.pleaseSignFirst;
    if (res['success'] != true) return res['message'] as String? ?? S.updateFailed2;
    await fetchCurrentUser();
    return null;
  }

  Future<int?> resolveUserShareToken(String token) async {
    final res = await _send('GET', '/users/share/$token');
    if (res == null || res['success'] != true || res['data'] is! Map) return null;
    final id = parseInt(res['data']['user_id']);
    return id > 0 ? id : null;
  }

  Future<String?> fetchProfileQrData() async {
    final res = await _send('GET', '/users/me/qrcode');
    if (res == null || res['success'] != true) return null;
    return res['data']?['qr_data'] as String?;
  }

  Future<String?> rotateShareToken() async {
    final res = await _send('POST', '/users/me/share-token/rotate');
    if (res == null || res['success'] != true) return null;
    return res['data']?['qr_data'] as String?;
  }

  Future<bool> uploadAvatar(String filePath) async {
    final res = await _sendMultipart('/users/me/avatar', [('avatar', filePath)]);
    if (res == null || res['success'] != true) return false;
    await fetchCurrentUser();
    return true;
  }
}
