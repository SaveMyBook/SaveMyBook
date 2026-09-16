import 'package:savemybook_app/models/auth_social.dart';
import 'package:savemybook_app/services/social_auth_service.dart';

/// 測試用的 Firebase 替身：所有回呼都同步觸發，狀態機的變化不必等待事件迴圈。
class FakeAuthGateway implements FirebaseAuthGateway {
  FakeAuthGateway({
    this.supportsGoogle = true,
    this.supportsApple = true,
    this.idToken = 'fake-id-token',
    this.verificationId = 'fake-verification-id',
  });

  @override
  final bool supportsGoogle;

  @override
  final bool supportsApple;

  final String idToken;
  final String verificationId;

  /// 下一次 verifyPhoneNumber 的結果：null 代表正常寄出驗證碼。
  SocialAuthFailure? sendFailure;

  /// 設為 true 時模擬 Android 自動完成驗證。
  bool autoVerify = false;

  /// 下一次輸入驗證碼的結果：null 代表通過。
  SocialAuthFailure? codeFailure;

  SocialAuthFailure? googleFailure;
  SocialAuthFailure? appleFailure;

  int sendCount = 0;
  int codeCount = 0;
  String? lastPhoneNumber;
  String? lastSmsCode;
  int? lastResendToken;

  @override
  Future<String> googleIdToken() async {
    final failure = googleFailure;
    if (failure != null) throw failure;
    return idToken;
  }

  @override
  Future<String> appleIdToken() async {
    final failure = appleFailure;
    if (failure != null) throw failure;
    return idToken;
  }

  @override
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    int? resendToken,
    required void Function(String idToken) onVerified,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(SocialAuthFailure failure) onFailed,
  }) {
    sendCount++;
    lastPhoneNumber = phoneNumber;
    lastResendToken = resendToken;

    final failure = sendFailure;
    if (failure != null) {
      onFailed(failure);
    } else if (autoVerify) {
      onVerified(idToken);
    } else {
      onCodeSent(verificationId, sendCount);
    }
    return Future<void>.value();
  }

  @override
  Future<String> smsCodeIdToken({required String verificationId, required String smsCode}) async {
    codeCount++;
    lastSmsCode = smsCode;
    final failure = codeFailure;
    if (failure != null) throw failure;
    return idToken;
  }

  @override
  Future<void> signOut() async {}
}

AuthProvidersInfo fakeProviders({
  bool socialEnabled = true,
  List<String> enabled = AuthProviders.ids,
  List<String> signup = AuthProviders.ids,
  List<String> configured = AuthProviders.ids,
}) {
  return AuthProvidersInfo(
    socialEnabled: socialEnabled,
    providers: [
      for (final id in AuthProviders.ids)
        AuthProviderOption(
          id: id,
          enabled: enabled.contains(id),
          signup: signup.contains(id),
          configured: configured.contains(id),
        ),
    ],
  );
}
