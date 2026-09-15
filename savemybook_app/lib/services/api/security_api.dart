part of '../api_service.dart';

class VerifyOutcome {
  final String? token;
  final String code;
  final String message;
  final int? remainingAttempts;

  const VerifyOutcome({required this.code, required this.message, this.remainingAttempts}) : token = null;

  const VerifyOutcome.success(String this.token)
      : code = 'OK',
        message = '',
        remainingAttempts = null;

  bool get isSuccess => token != null;
}

extension SecurityApi on ApiService {
  Future<SecurityStatus> fetchSecurityStatus() async {
    final res = await _send('GET', '/security');
    if (res == null || res['success'] != true || res['data'] is! Map) return SecurityStatus.unknown;
    return SecurityStatus.fromJson(Map<String, dynamic>.from(res['data']));
  }

  Future<VerifyOutcome> verifyIdentity({
    required String scope,
    required String method,
    String? pin,
    String? password,
    String? key,
  }) async {
    final res = await _send('POST', '/security/verify', body: {
      'scope': scope,
      'method': method,
      'pin': ?pin,
      'password': ?password,
      'key': ?key,
    });
    if (res == null) return VerifyOutcome(code: 'SIGNED_OUT', message: S.pleaseSignFirst);
    if (res['success'] == true) {
      return VerifyOutcome.success(res['data']?['verify_token'] as String? ?? '');
    }
    return VerifyOutcome(
      code: res['code'] as String? ?? 'UNKNOWN',
      message: res['message'] as String? ?? S.somethingWentWrongPleaseTryAgain,
      remainingAttempts: res['remaining_attempts'] == null ? null : parseInt(res['remaining_attempts']),
    );
  }

  Future<String?> setPaymentPin(String pin, {required String verifyToken}) async {
    final res = await _send('PUT', '/security/payment-pin', body: {'pin': pin}, extraHeaders: {'X-Verify-Token': verifyToken});
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.somethingWentWrongPleaseTryAgain);
  }

  Future<(String?, String?)> enableBiometricPay({required String verifyToken}) async {
    final res = await _send('POST', '/security/biometric-key', extraHeaders: {'X-Verify-Token': verifyToken});
    if (res == null) return (null, S.pleaseSignFirst);
    final key = res['data'] is Map ? res['data']['key'] as String? : null;
    if (res['success'] != true || key == null) return (null, res['message'] as String? ?? S.somethingWentWrongPleaseTryAgain);
    final userId = ApiService.currentUser?.userId;
    if (userId != null) await PaymentKeyStore.save(userId, key);
    return (key, null);
  }

  Future<bool> disableBiometricPay() async {
    await PaymentKeyStore.clear();
    final res = await _send('DELETE', '/security/biometric-key');
    return res != null && res['success'] == true;
  }

  Future<List<LoginSession>?> fetchLoginSessions() async {
    final res = await _send('GET', '/security/sessions');
    if (res == null || res['success'] != true) return null;
    return _mapList(res, LoginSession.fromJson);
  }

  Future<(bool signedOutCurrent, String? error)> revokeLoginSession(int sessionId) async {
    final res = await _send('DELETE', '/security/sessions/$sessionId');
    if (res == null) return (false, S.pleaseSignFirst);
    if (res['success'] != true) return (false, res['message'] as String? ?? S.actionFailed);
    return (res['data']?['signed_out_current'] == true, null);
  }

  Future<(int revoked, String? error)> revokeAllLoginSessions({bool includeCurrent = false}) async {
    final res = await _send('POST', '/security/sessions/revoke-all', body: {'include_current': includeCurrent});
    if (res == null) return (0, S.pleaseSignFirst);
    if (res['success'] != true) return (0, res['message'] as String? ?? S.actionFailed);
    return (parseInt(res['data']?['revoked']), null);
  }
}
