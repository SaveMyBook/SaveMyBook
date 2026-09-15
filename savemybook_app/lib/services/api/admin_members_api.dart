part of '../api_service.dart';

extension AdminMembersApi on ApiService {
  Future<List<AdminMember>> fetchAdminMembers({String keyword = '', String? status}) async {
    final res = await _send('GET', '/admin/members', query: {
      if (keyword.isNotEmpty) 'keyword': keyword,
      'status': ?status,
      'limit': '50',
    });
    return _mapList(res, AdminMember.fromJson);
  }

  Future<bool> updateMemberStatus(int userId, {bool? isActive, bool? isBlacklisted}) async {
    final res = await _send('PATCH', '/admin/members/$userId', body: {
      'is_active': ?isActive,
      'is_blacklisted': ?isBlacklisted,
    });
    return res != null && res['success'] == true;
  }

  Future<AdminMemberDetail?> fetchAdminMemberDetail(int userId) async {
    final res = await _send('GET', '/admin/members/$userId');
    if (res == null || res['success'] != true || res['data'] is! Map) return null;
    return AdminMemberDetail.fromJson(Map<String, dynamic>.from(res['data']));
  }

  Future<String?> updateMemberRole(int userId, String role) async {
    final res = await _send('PATCH', '/admin/members/$userId', body: {'role': role});
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.updateFailed2);
  }

  Future<String?> adjustMemberLevel(
    int userId, {
    int? levelId,
    int? delta,
    bool reset = false,
  }) async {
    final res = await _send('PATCH', '/admin/members/$userId/level', body: {
      if (reset) 'reset': true,
      if (!reset && delta != null) 'delta': delta,
      if (!reset && delta == null && levelId != null) 'level_id': levelId,
    });
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.couldNotAdjust);
  }

  Future<String?> updateAdminPermissions(int userId, Map<String, bool> permissions) async {
    final res = await _send('PUT', '/admin/members/$userId/permissions', body: permissions);
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.updateFailed2);
  }

  Future<(String? password, String? error)> resetMemberPassword(int userId) async {
    final res = await _send('POST', '/admin/members/$userId/reset-password');
    if (res == null) return (null, S.pleaseSignFirst);
    if (res['success'] != true) {
      return (null, res['message'] as String? ?? S.updateFailed);
    }
    return (res['data']?['temp_password'] as String?, null);
  }

  Future<List<AdminLevel>> fetchAdminLevels() async {
    final res = await _send('GET', '/admin/levels');
    return _mapList(res, AdminLevel.fromJson);
  }

  Future<String?> saveLevel({
    int? levelId,
    required String name,
    required int minPoints,
    int? maxPoints,
    String benefits = '',
  }) async {
    final body = {
      'level_name': name,
      'min_points': minPoints,
      'max_points': maxPoints,
      'benefits': benefits,
    };
    final res = levelId == null
        ? await _send('POST', '/admin/levels', body: body)
        : await _send('PUT', '/admin/levels/$levelId', body: body);
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.couldNotSave2);
  }

  Future<String?> deleteLevel(int levelId) async {
    final res = await _send('DELETE', '/admin/levels/$levelId');
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.couldNotDelete);
  }

  Future<List<AdminWallet>> fetchAdminWallets({String keyword = ''}) async {
    final res = await _send('GET', '/admin/wallets', query: {
      if (keyword.isNotEmpty) 'keyword': keyword,
      'limit': '50',
    });
    return _mapList(res, AdminWallet.fromJson);
  }

  Future<AdminWalletDetail?> fetchAdminWalletDetail(int userId) async {
    final res = await _send('GET', '/admin/wallets/$userId');
    if (res == null || res['success'] != true || res['data'] is! Map) return null;
    return AdminWalletDetail.fromJson(Map<String, dynamic>.from(res['data']));
  }

  Future<String?> adjustWallet(int userId, {required double amount, required String description}) async {
    final res = await _send('POST', '/admin/wallets/$userId/adjust', body: {
      'amount': amount,
      'description': description,
    });
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.couldNotAdjust);
  }
}
