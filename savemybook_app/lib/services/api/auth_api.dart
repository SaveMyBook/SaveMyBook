part of '../api_service.dart';

class LoginOutcome {
  final bool isSuccess;
  final String code;
  final String message;

  const LoginOutcome({required this.code, required this.message}) : isSuccess = false;

  const LoginOutcome.success()
      : isSuccess = true,
        code = 'OK',
        message = '';

  bool get accountNotFound => code == 'ACCOUNT_NOT_FOUND';
}

extension AuthApi on ApiService {
  Future<LoginOutcome> login(String email, String password) async {
    final device = await DeviceIdentity.describe();
    final res = await _send('POST', '/auth/login', body: {'email': email, 'password': password, ...device});

    if (res == null) {
      return LoginOutcome(code: 'NETWORK', message: S.couldNotReachServerCheckConnection);
    }

    if (res['success'] != true) {
      return LoginOutcome(
        code: res['code'] as String? ?? 'UNKNOWN',
        message: res['message'] as String? ?? S.signFailed,
      );
    }

    final token = res['data']?['token'] as String?;
    if (token == null) {
      return LoginOutcome(code: 'UNKNOWN', message: S.signFailedPleaseTryAgain);
    }

    await PaymentKeyStore.clear();
    await ApiService._storeToken(token);

    await fetchCurrentUser();
    return const LoginOutcome.success();
  }

  Future<String?> register(String email, String password, String nickname) async {
    final res = await _send('POST', '/users',
        body: {'email': email, 'password': password, 'nickname': nickname, 'accept_legal': true});
    if (res == null) return S.couldNotReachServerCheckConnection;
    return res['success'] == true ? null : (res['message'] as String? ?? S.signUpFailed);
  }

  Future<void> logout() async {
    // 必須在清掉登入 Token 之前通知伺服器，否則無法取消這台的推播。
    await ApiService.onSigningOut?.call(canReachServer: true);
    if (ApiService.authToken != null) {
      await _send('POST', '/auth/logout').timeout(const Duration(seconds: 4), onTimeout: () => null);
    }
    await PaymentKeyStore.clear();
    ApiService.authToken = null;
    ApiService.currentUser = null;
    ApiService.resetGlobalState();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  Future<void> fetchCurrentUser() async {
    if (ApiService.authToken == null) return;
    final res = await _send('GET', '/auth/me');
    if (res != null && res['success'] == true && res['data'] is Map) {
      ApiService.currentUser = User.fromJson(Map<String, dynamic>.from(res['data']));
    }
  }

  Future<String?> changePassword(String currentPassword, String newPassword) async {
    final res = await _send('PUT', '/users/me/password', body: {
      'current_password': currentPassword,
      'new_password': newPassword,
    });
    if (res == null) return S.pleaseSignFirst;
    if (res['success'] != true) return res['message'] as String? ?? S.couldNotChangePassword;

    // 伺服器改密碼後換發新 token，不存下來下一個請求就會被登出。
    final token = res['data'] is Map ? res['data']['token'] : null;
    if (token is String && token.isNotEmpty) {
      ApiService.authToken = token;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
    }
    unawaited(ApiService.onPasswordChanged?.call());
    return null;
  }
}
