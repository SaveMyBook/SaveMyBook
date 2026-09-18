part of '../api_service.dart';

extension AuthSocialApi on ApiService {
  AuthResult<T> _authFail<T>(Map<String, dynamic>? res) {
    if (res == null) return AuthResult<T>.of(AuthCodes.network);
    final code = res['code'] as String? ?? 'UNKNOWN';
    final email = res['provider_email'];
    return AuthResult<T>.fail(
      code,
      res['message'] as String? ?? AuthCodes.messageOf(code),
      providerEmail: email is String && email.isNotEmpty ? email : null,
    );
  }

  Map<String, dynamic>? _authData(Map<String, dynamic>? res) {
    final data = res?['data'];
    return data is Map ? Map<String, dynamic>.from(data) : null;
  }

  Future<AuthResult<void>> _finishSocialLogin(Map<String, dynamic>? res) async {
    if (res == null || res['success'] != true) return _authFail(res);
    final token = _authData(res)?['token'] as String?;
    if (token == null || token.isEmpty) return AuthResult<void>.of('UNKNOWN');

    await PaymentKeyStore.clear();
    await ApiService._storeToken(token);
    await fetchCurrentUser();
    return const AuthResult.ok();
  }

  Future<AuthProvidersInfo> fetchAuthProviders() async {
    final res = await _send('GET', '/auth/providers');
    final data = _authData(res);
    if (res == null || res['success'] != true || data == null) return AuthProvidersInfo.none;
    return AuthProvidersInfo.fromJson(data);
  }

  Future<AuthResult<void>> socialSignIn({
    required String provider,
    required String idToken,
    String? email,
    String? nickname,
    bool acceptLegal = false,
    bool create = false,
  }) async {
    final device = await DeviceIdentity.describe();
    if (ApiService.currentUser == null) ApiService.authToken = null;
    final res = await _send('POST', '/auth/social', body: {
      'provider': provider,
      'id_token': idToken,
      if (create) 'create': true,
      if (email != null && email.isNotEmpty) 'email': email,
      if (nickname != null && nickname.isNotEmpty) 'nickname': nickname,
      if (acceptLegal) 'accept_legal': true,
      ...device,
    });
    return _finishSocialLogin(res);
  }

  Future<AuthResult<AuthIdentityList>> fetchIdentities() async {
    final res = await _send('GET', '/users/me/identities');
    if (res == null || res['success'] != true) return _authFail(res);
    final data = _authData(res);
    if (data == null) return AuthResult<AuthIdentityList>.of('UNKNOWN');
    return AuthResult.ok(AuthIdentityList.fromJson(data));
  }

  Future<AuthResult<AuthIdentityList>> linkIdentity({
    required String provider,
    required String idToken,
  }) async {
    final res = await _send('POST', '/auth/link', body: {'provider': provider, 'id_token': idToken});
    if (res == null || res['success'] != true) return _authFail(res);
    final data = _authData(res);
    if (data == null) return AuthResult<AuthIdentityList>.of('UNKNOWN');
    return AuthResult.ok(AuthIdentityList.fromJson(data));
  }

  Future<AuthResult<AuthIdentityList>> unlinkIdentity(String provider) async {
    final res = await _send('DELETE', '/auth/link/$provider');
    if (res == null || res['success'] != true) {
      final result = _authFail<AuthIdentityList>(res);
      // 伺服器對「未綁定」只回 404 而沒有代碼，補上代碼讓畫面能分辨。
      if (res != null && res['status'] == 404 && res['code'] == null) {
        return AuthResult.fail(AuthCodes.notLinked, result.message);
      }
      return result;
    }
    final data = _authData(res);
    if (data == null) return AuthResult<AuthIdentityList>.of('UNKNOWN');
    return AuthResult.ok(AuthIdentityList.fromJson(data));
  }

  Future<AuthResult<void>> setLoginPassword(String password) async {
    final res = await _send('POST', '/auth/password/set', body: {'password': password});
    if (res == null || res['success'] != true) return _authFail(res);

    // 設定密碼後伺服器換發新 Token，沒存下來下一個請求就會被登出。
    final token = _authData(res)?['token'] as String?;
    if (token != null && token.isNotEmpty) await ApiService._storeToken(token);
    unawaited(ApiService.onPasswordChanged?.call());
    return const AuthResult.ok();
  }

  Future<AuthResult<String>> startOAuth(String provider, {bool link = false}) async {
    final res = await _send('POST', '/auth/oauth/$provider/start', body: {'mode': link ? 'link' : 'login'});
    if (res == null || res['success'] != true) return _authFail(res);
    final url = _authData(res)?['url'] as String?;
    if (url == null || url.isEmpty) return AuthResult<String>.of('UNKNOWN');
    return AuthResult.ok(url);
  }

  /// 綁定時回傳 provider 代號；登入時回傳 null 並已寫入登入 Token。
  /// 一次性碼在收到 NO_ACCOUNT_FOR_PROVIDER 與 EMAIL_REQUIRED 後仍可重用，
  /// 使用者決定要建立帳號時帶 create 重送即可，不必再開一次授權頁。
  Future<AuthResult<String?>> exchangeOAuthCode(
    String code, {
    bool create = false,
    String? email,
    String? nickname,
  }) async {
    final device = await DeviceIdentity.describe();
    final res = await _send('POST', '/auth/oauth/exchange', body: {
      'code': code,
      if (create) ...{'create': true, 'accept_legal': true},
      if (email != null && email.isNotEmpty) 'email': email,
      if (nickname != null && nickname.isNotEmpty) 'nickname': nickname,
      ...device,
    });
    if (res == null || res['success'] != true) return _authFail(res);

    final data = _authData(res);
    if (data?['linked'] == true) return AuthResult.ok(data?['provider'] as String?);

    final outcome = await _finishSocialLogin(res);
    return outcome.isOk
        ? const AuthResult.ok(null)
        : AuthResult.fail(outcome.code, outcome.error, providerEmail: outcome.providerEmail);
  }

  Future<AuthResult<void>> socialLinkLogin({
    required String provider,
    String? idToken,
    String? oauthCode,
    String? email,
    String? password,
    Map<String, dynamic>? assertion,
  }) async {
    final device = await DeviceIdentity.describe();
    if (ApiService.currentUser == null) ApiService.authToken = null;
    final res = await _send('POST', '/auth/social/link-login', body: {
      'provider': provider,
      'id_token': ?idToken,
      'code': ?oauthCode,
      if (assertion != null) 'assertion': assertion else ...{'email': ?email, 'password': ?password},
      ...device,
    });
    return _finishSocialLogin(res);
  }

  Future<AuthResult<AuthSettingsBundle>> fetchAuthSettings() async {
    final res = await _send('GET', '/admin/auth/settings');
    if (res == null || res['success'] != true) return _authFail(res);
    final data = _authData(res);
    if (data == null) return AuthResult<AuthSettingsBundle>.of('UNKNOWN');
    return AuthResult.ok(AuthSettingsBundle.fromJson(data));
  }

  Future<AuthResult<AuthSettingsBundle>> saveAuthSettings(AuthSettings settings) async {
    final res = await _send('PUT', '/admin/auth/settings', body: {'settings': settings.toJson()});
    if (res == null || res['success'] != true) return _authFail(res);
    final data = _authData(res);
    if (data == null) return AuthResult<AuthSettingsBundle>.of('UNKNOWN');
    return AuthResult.ok(AuthSettingsBundle.fromJson(data));
  }
}
