part of '../api_service.dart';

extension PrivacyApi on ApiService {
  Future<(bool, DateTime?)> fetchDeletionStatus() async {
    final res = await _send('GET', '/users/me/deletion');
    if (res == null || res['success'] != true) return (false, null);
    final data = res['data'] as Map<String, dynamic>? ?? {};
    final purge = data['purge_at'] as String?;
    return (data['pending'] == true, purge == null ? null : DateTime.tryParse(purge));
  }

  Future<AuthResult<void>> requestAccountDeletion(String password) async {
    final res = await _send('POST', '/users/me/deletion', body: {'password': password});
    if (res == null) return AuthResult<void>.fail('SIGNED_OUT', S.pleaseSignFirst);
    if (res['success'] == true) return const AuthResult.ok();
    return AuthResult<void>.fail(
      res['code'] as String? ?? 'UNKNOWN',
      res['message'] as String? ?? S.requestFailed,
    );
  }

  Future<String?> cancelAccountDeletion() async {
    final res = await _send('DELETE', '/users/me/deletion');
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.couldNotCancel);
  }

  Future<String?> exportMyData({Map<String, String>? extraHeaders, Set<String> handled = const {}}) async {
    try {
      final sentWithToken = ApiService.authToken != null;
      final response = await http.get(Uri.parse('${ApiService.baseUrl}/users/me/export'), headers: ApiService._headers(extra: extraHeaders));
      if (response.statusCode == 200) return utf8.decode(response.bodyBytes);
      final res = await _interpret(
        response.statusCode,
        response.bodyBytes,
        sentWithToken: sentWithToken,
        handled: handled,
        retry: (extra, next) async {
          final content = await exportMyData(extraHeaders: {...?extraHeaders, ...extra}, handled: next);
          return content == null ? null : {'success': true, 'content': content};
        },
      );
      return res?['content'] as String?;
    } catch (_) {
      return null;
    }
  }
}
