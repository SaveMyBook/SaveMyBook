part of '../api_service.dart';

extension PasskeysApi on ApiService {
  Future<bool> fetchPasskeyServerEnabled() async {
    final res = await _send('GET', '/auth/passkeys/status');
    return res != null && res['success'] == true && res['data'] is Map && res['data']['enabled'] == true;
  }

  PasskeyOutcome<Map<String, dynamic>> _optionsOf(Map<String, dynamic>? res) {
    if (res == null) return PasskeyOutcome.fail('SIGNED_OUT', S.pleaseSignFirst);
    final options = res['data'] is Map ? res['data']['options'] : null;
    if (res['success'] != true || options is! Map) return _passkeyFailure(res);
    return PasskeyOutcome.ok(Map<String, dynamic>.from(options));
  }

  PasskeyOutcome<T> _passkeyFailure<T>(Map<String, dynamic>? res) => PasskeyOutcome.fail(
        res?['code'] as String? ?? 'UNKNOWN',
        res?['message'] as String? ?? S.somethingWentWrongPleaseTryAgain,
      );

  Future<PasskeyOutcome<Map<String, dynamic>>> passkeyLoginOptions({String? email}) async {
    final res = await _send('POST', '/auth/passkeys/login/options', body: {'email': ?email});
    return _optionsOf(res);
  }

  /// 成功時與密碼登入相同：存下 Token 並載入使用者資料。
  Future<PasskeyOutcome<void>> passkeyLogin(Map<String, dynamic> assertion) async {
    final device = await DeviceIdentity.describe();
    final res = await _send('POST', '/auth/passkeys/login', body: {'assertion': assertion, ...device});
    if (res == null || res['success'] != true) return _passkeyFailure(res);

    final token = res['data'] is Map ? res['data']['token'] as String? : null;
    if (token == null) return PasskeyOutcome.fail('UNKNOWN', S.signFailedPleaseTryAgain);

    await PaymentKeyStore.clear();
    await ApiService._storeToken(token);
    await fetchCurrentUser();
    return const PasskeyOutcome.ok(null);
  }

  Future<PasskeyOutcome<List<PasskeyItem>>> fetchPasskeys() async {
    final res = await _send('GET', '/users/me/passkeys');
    if (res == null) return PasskeyOutcome.fail('SIGNED_OUT', S.pleaseSignFirst);
    if (res['success'] != true) return _passkeyFailure(res);
    return PasskeyOutcome.ok(_mapList(res, PasskeyItem.fromJson));
  }

  Future<PasskeyOutcome<Map<String, dynamic>>> passkeyRegistrationOptions() async =>
      _optionsOf(await _send('POST', '/users/me/passkeys/options'));

  Future<PasskeyOutcome<List<PasskeyItem>>> registerPasskey(
    Map<String, dynamic> attestation, {
    String? deviceLabel,
    required String verifyToken,
  }) async {
    final res = await _send(
      'POST',
      '/users/me/passkeys',
      body: {'attestation': attestation, 'device_label': ?deviceLabel},
      extraHeaders: {'X-Verify-Token': verifyToken},
    );
    if (res == null) return PasskeyOutcome.fail('SIGNED_OUT', S.pleaseSignFirst);
    if (res['success'] != true) return _passkeyFailure(res);
    return PasskeyOutcome.ok(_mapList(res, PasskeyItem.fromJson));
  }

  Future<PasskeyOutcome<List<PasskeyItem>>> renamePasskey(String passkeyId, String label) async {
    final res = await _send('PATCH', '/users/me/passkeys/${Uri.encodeComponent(passkeyId)}', body: {'device_label': label});
    if (res == null) return PasskeyOutcome.fail('SIGNED_OUT', S.pleaseSignFirst);
    if (res['success'] != true) return _passkeyFailure(res);
    return PasskeyOutcome.ok(_mapList(res, PasskeyItem.fromJson));
  }

  Future<PasskeyOutcome<List<PasskeyItem>>> deletePasskey(String passkeyId) async {
    final res = await _send('DELETE', '/users/me/passkeys/${Uri.encodeComponent(passkeyId)}');
    if (res == null) return PasskeyOutcome.fail('SIGNED_OUT', S.pleaseSignFirst);
    if (res['success'] != true) return _passkeyFailure(res);
    return PasskeyOutcome.ok(_mapList(res, PasskeyItem.fromJson));
  }

  Future<PasskeyOutcome<Map<String, dynamic>>> passkeyVerifyOptions(String scope) async =>
      _optionsOf(await _send('POST', '/security/verify/passkey/options', body: {'scope': scope}));

  Future<VerifyOutcome> verifyIdentityWithPasskey({required String scope, required Map<String, dynamic> assertion}) async {
    final res = await _send('POST', '/security/verify', body: {'scope': scope, 'method': 'passkey', 'assertion': assertion});
    if (res == null) return VerifyOutcome(code: 'SIGNED_OUT', message: S.pleaseSignFirst);
    if (res['success'] == true) return VerifyOutcome.success(res['data']?['verify_token'] as String? ?? '');
    return VerifyOutcome(
      code: res['code'] as String? ?? 'UNKNOWN',
      message: res['message'] as String? ?? S.somethingWentWrongPleaseTryAgain,
    );
  }
}
