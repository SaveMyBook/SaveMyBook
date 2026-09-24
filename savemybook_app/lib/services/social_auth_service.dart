import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener, WidgetsBinding;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/auth_social.dart';
import 'deep_link_service.dart';
import 'locale_provider.dart';
import '../i18n/strings.dart';

/// Android 需要 Firebase 專案的 Web 用戶端 ID 才拿得到 Google ID Token。
const _googleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

class SocialAuthFailure implements Exception {
  final String code;
  final String message;

  const SocialAuthFailure(this.code, this.message);

  bool get isCancelled => code == AuthCodes.cancelled;
}

/// 包住 firebase_auth 與各家 SDK，讓畫面與測試都只依賴這層介面。
abstract class FirebaseAuthGateway {
  bool get supportsGoogle;

  bool get supportsApple;

  /// 回傳 Firebase ID Token；使用者取消時丟出代碼 CANCELLED 的失敗。
  Future<String> googleIdToken();

  Future<String> appleIdToken();

  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    int? resendToken,
    required void Function(String idToken) onVerified,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(SocialAuthFailure failure) onFailed,
  });

  Future<String> smsCodeIdToken({required String verificationId, required String smsCode});

  Future<void> signOut();
}

String _firebaseFailureMessage(String code) {
  final message = switch (code) {
      'invalid-phone-number' => S.mobileNumberFormatNotValid,
      'invalid-verification-code' => S.codeIncorrectPleaseEnterAgain,
      'invalid-verification-id' => S.verificationTimedOutRequestNewCode,
      'session-expired' => S.codeExpiredRequestNewOne,
      'too-many-requests' => S.tooManyAttemptsPleaseTryAgain,
      'quota-exceeded' => S.smsSendingLimitBeenReachedPlease,
      'operation-not-allowed' => S.signMethodNotAvailableRightNow,
      'network-request-failed' => S.networkError,
      'missing-client-identifier' => S.smsVerificationNotSetUpDevice,
      _ => null,
    };
  if (message != null) return message;
  debugPrint('[SMS] Unmapped Firebase error code: $code');
  return S.couldNotCompleteSmsVerificationPlease;
}

String _smsLanguageCode() {
  final locale = localeProvider.value ?? WidgetsBinding.instance.platformDispatcher.locale;
  return switch (locale.languageCode) {
    'en' => 'en',
    'ja' => 'ja',
    'ko' => 'ko',
    'zh' => locale.scriptCode == 'Hans' || locale.countryCode == 'CN' ? 'zh-CN' : 'zh-TW',
    _ => 'zh-TW',
  };
}

class _PluginAuthGateway implements FirebaseAuthGateway {
  bool _googleReady = false;

  FirebaseAuth get _auth => FirebaseAuth.instance;

  @override
  bool get supportsGoogle => !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);

  @override
  bool get supportsApple => !kIsWeb && (Platform.isIOS || Platform.isMacOS);

  Future<String> _idTokenOf(UserCredential credential) async {
    final token = await credential.user?.getIdToken();
    if (token == null || token.isEmpty) throw SocialAuthFailure('UNKNOWN', AuthCodes.messageOf('UNKNOWN'));
    return token;
  }

  @override
  Future<String> googleIdToken() async {
    try {
      if (!_googleReady) {
        await GoogleSignIn.instance.initialize(
          serverClientId: _googleServerClientId.isEmpty ? null : _googleServerClientId,
        );
        _googleReady = true;
      }
      final account = await GoogleSignIn.instance.authenticate();
      final googleToken = account.authentication.idToken;
      if (googleToken == null || googleToken.isEmpty) {
        throw SocialAuthFailure(AuthCodes.invalidIdToken, AuthCodes.messageOf(AuthCodes.invalidIdToken));
      }
      final credential = await _auth.signInWithCredential(
        GoogleAuthProvider.credential(idToken: googleToken),
      );
      return await _idTokenOf(credential);
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled ||
          error.code == GoogleSignInExceptionCode.interrupted) {
        throw SocialAuthFailure(AuthCodes.cancelled, '');
      }
      throw SocialAuthFailure(AuthCodes.providerError, AuthCodes.messageOf(AuthCodes.providerError));
    } on FirebaseAuthException catch (error) {
      throw SocialAuthFailure(AuthCodes.providerError, _firebaseFailureMessage(error.code));
    }
  }

  @override
  Future<String> appleIdToken() async {
    // Apple 只在 identityToken 內回填 nonce，必須送出雜湊值、保留原字串給 Firebase 比對。
    final rawNonce = _randomNonce();
    try {
      final apple = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
        nonce: sha256.convert(utf8.encode(rawNonce)).toString(),
      );
      final identityToken = apple.identityToken;
      if (identityToken == null || identityToken.isEmpty) {
        throw SocialAuthFailure(AuthCodes.invalidIdToken, AuthCodes.messageOf(AuthCodes.invalidIdToken));
      }
      final credential = await _auth.signInWithCredential(
        OAuthProvider('apple.com').credential(idToken: identityToken, rawNonce: rawNonce),
      );
      final name = [apple.givenName, apple.familyName].whereType<String>().join(' ').trim();
      if (name.isNotEmpty && (credential.user?.displayName ?? '').isEmpty) {
        await credential.user?.updateDisplayName(name);
      }
      return await _idTokenOf(credential);
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) throw SocialAuthFailure(AuthCodes.cancelled, '');
      throw SocialAuthFailure(AuthCodes.providerError, AuthCodes.messageOf(AuthCodes.providerError));
    } on SignInWithAppleException {
      throw SocialAuthFailure(AuthCodes.providerError, AuthCodes.messageOf(AuthCodes.providerError));
    } on FirebaseAuthException catch (error) {
      throw SocialAuthFailure(AuthCodes.providerError, _firebaseFailureMessage(error.code));
    }
  }

  @override
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    int? resendToken,
    required void Function(String idToken) onVerified,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(SocialAuthFailure failure) onFailed,
  }) async {
    // Firebase 不開放自訂簡訊內容，只能指定範本語系；未設定時會依裝置語言，可能收到英文簡訊。
    await _auth.setLanguageCode(_smsLanguageCode()).catchError((_) {});
    return _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      forceResendingToken: resendToken,
      verificationCompleted: (credential) async {
        try {
          onVerified(await _idTokenOf(await _auth.signInWithCredential(credential)));
        } on FirebaseAuthException catch (error) {
          onFailed(SocialAuthFailure(error.code, _firebaseFailureMessage(error.code)));
        }
      },
      verificationFailed: (error) => onFailed(SocialAuthFailure(error.code, _firebaseFailureMessage(error.code))),
      codeSent: onCodeSent,
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  @override
  Future<String> smsCodeIdToken({required String verificationId, required String smsCode}) async {
    try {
      final credential = await _auth.signInWithCredential(
        PhoneAuthProvider.credential(verificationId: verificationId, smsCode: smsCode),
      );
      return await _idTokenOf(credential);
    } on FirebaseAuthException catch (error) {
      throw SocialAuthFailure(error.code, _firebaseFailureMessage(error.code));
    }
  }

  @override
  Future<void> signOut() => _auth.signOut().catchError((_) {});

  static String _randomNonce() {
    const chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(32, (_) => chars[random.nextInt(chars.length)]).join();
  }
}

class SocialAuth {
  const SocialAuth._();

  static FirebaseAuthGateway gateway = _PluginAuthGateway();

  /// 授權頁改開 App 內瀏覽器（iOS 的 SFSafariViewController、Android 的 Custom Tabs）：
  /// 系統瀏覽器是另一個 App，回跳後那個視窗會留著，每重試一次就多一個。
  static Future<bool> Function(Uri url) openAuthBrowser =
      (url) => launchUrl(url, mode: _inAppBrowserSupported ? LaunchMode.inAppBrowserView : LaunchMode.externalApplication);

  /// 回跳後 App 內瀏覽器不會自己關閉，必須主動收掉。
  static Future<void> Function() closeAuthBrowser = closeInAppWebView;

  static Duration oauthTimeout = const Duration(minutes: 5);

  static bool get _inAppBrowserSupported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// 回到 App 後等候回呼深層連結的時間；深層連結可能比「回到前景」晚一點送達。
  static Duration browserCloseGrace = const Duration(seconds: 3);

  static Completer<AuthResult<String>>? _oauthWait;
  static Timer? _oauthTimer;
  static Timer? _closeGrace;
  static AppLifecycleListener? _lifecycle;

  static bool isAvailableOn(String provider) => switch (provider) {
        AuthProviders.google => gateway.supportsGoogle,
        AuthProviders.apple => gateway.supportsApple,
        _ => true,
      };

  /// 取得可用於 /auth/social 與 /auth/link 的 Firebase ID Token。
  static Future<AuthResult<String>> firebaseIdToken(String provider) async {
    try {
      final token = switch (provider) {
        AuthProviders.google => await gateway.googleIdToken(),
        AuthProviders.apple => await gateway.appleIdToken(),
        _ => throw SocialAuthFailure(AuthCodes.providerMismatch, AuthCodes.messageOf(AuthCodes.providerMismatch)),
      };
      return AuthResult.ok(token);
    } on SocialAuthFailure catch (failure) {
      return AuthResult.fail(failure.code, failure.message);
    } catch (_) {
      return AuthResult<String>.of(AuthCodes.providerError);
    }
  }

  /// 開啟 LINE／Discord 授權頁，等回呼帶回一次性碼。
  /// 同一時間只允許一個等待中的流程，重複呼叫會先把前一個收乾淨。
  static Future<AuthResult<String>> awaitOAuthCode(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return AuthResult<String>.of(AuthCodes.oauthFailed);

    cancelOAuthWait();

    final completer = Completer<AuthResult<String>>();
    _oauthWait = completer;
    _oauthTimer = Timer(oauthTimeout, () => _finishOAuth(AuthResult<String>.of(AuthCodes.cancelled)));

    DeepLinkService.onOAuthResult = (result) {
      final code = result.code;
      if (code != null && code.isNotEmpty) {
        _finishOAuth(AuthResult.ok(code));
        return;
      }
      _finishOAuth(
        AuthResult<String>.of(result.error?.isNotEmpty == true ? result.error! : AuthCodes.oauthFailed),
      );
    };

    // Android 的 Custom Tabs 是另一個工作，關閉後 App 會經過 paused → resumed；
    // 只看 inactive → resumed 會把 Face ID、通知中心等系統視窗誤判成取消。
    if (!kIsWeb && Platform.isAndroid) {
      var paused = false;
      _lifecycle = AppLifecycleListener(
        onPause: () => paused = true,
        onResume: () {
          if (paused) handleBrowserClosed();
        },
      );
    }

    if (!await openAuthBrowser(uri)) {
      _finishOAuth(AuthResult<String>.of(AuthCodes.oauthFailed));
    }
    return completer.future;
  }

  /// 使用者關閉授權頁回到 App；寬限時間內仍沒收到回呼就視為取消。
  static void handleBrowserClosed() {
    if (_oauthWait == null) return;
    _closeGrace?.cancel();
    _closeGrace = Timer(browserCloseGrace, cancelOAuthWait);
  }

  /// 使用者離開登入畫面時呼叫，確保不留下計時器與深層連結處理器。
  static void cancelOAuthWait() => _finishOAuth(AuthResult<String>.of(AuthCodes.cancelled));

  static void _finishOAuth(AuthResult<String> result) {
    final completer = _oauthWait;
    if (completer == null || completer.isCompleted) return;

    _oauthWait = null;
    _oauthTimer?.cancel();
    _oauthTimer = null;
    _closeGrace?.cancel();
    _closeGrace = null;
    _lifecycle?.dispose();
    _lifecycle = null;
    DeepLinkService.onOAuthResult = null;
    unawaited(closeAuthBrowser());
    completer.complete(result);
  }
}

enum PhoneSignInStage { idle, sending, codeSent, verifying, verified }

/// 簡訊登入的狀態機：送出號碼 → 等驗證碼 → 驗證，含重送倒數。
class PhoneSignInController extends ChangeNotifier {
  final FirebaseAuthGateway gateway;
  final Duration resendCooldown;

  final Duration codeValidity;

  PhoneSignInController({
    FirebaseAuthGateway? gateway,
    this.resendCooldown = const Duration(seconds: 60),
    this.codeValidity = const Duration(minutes: 5),
    DateTime Function()? clock,
  })  : gateway = gateway ?? SocialAuth.gateway,
        _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  DateTime? _codeSentAt;

  PhoneSignInStage stage = PhoneSignInStage.idle;
  String phoneNumber = '';
  String? error;
  String? idToken;
  int resendSeconds = 0;

  String? _verificationId;
  int? _resendToken;
  Timer? _ticker;
  bool _disposed = false;

  bool get isBusy => stage == PhoneSignInStage.sending || stage == PhoneSignInStage.verifying;

  bool get canResend => stage == PhoneSignInStage.codeSent && (resendSeconds == 0 || codeExpired);

  /// 服務條款規範驗證碼 5 分鐘內有效。Firebase 無法設定簡訊驗證碼的效期，因此在 App 端強制執行。
  Duration get codeRemaining {
    final sentAt = _codeSentAt;
    if (sentAt == null) return Duration.zero;
    final left = codeValidity - _clock().difference(sentAt);
    return left.isNegative ? Duration.zero : left;
  }

  bool get codeExpired => _codeSentAt != null && codeRemaining == Duration.zero;

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    super.dispose();
  }

  void _emit() {
    if (_disposed) return;
    notifyListeners();
  }

  void _startCooldown() {
    _ticker?.cancel();
    resendSeconds = resendCooldown.inSeconds;
    // 持續計時到驗證碼失效為止，畫面上的剩餘時間與失效狀態才會即時更新。
    var ticksLeft = codeValidity.inSeconds;
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (resendSeconds > 0) resendSeconds--;
      ticksLeft--;
      if (resendSeconds == 0 && (codeExpired || ticksLeft <= 0)) timer.cancel();
      _emit();
    });
  }

  Future<void> send(String e164) async {
    if (isBusy) return;
    phoneNumber = e164;
    _verificationId = null;
    _resendToken = null;
    await _request();
  }

  Future<void> resend() async {
    if (isBusy || !canResend) return;
    await _request();
  }

  Future<void> _request() async {
    stage = PhoneSignInStage.sending;
    error = null;
    _emit();

    final done = Completer<void>();
    void settle() {
      if (!done.isCompleted) done.complete();
    }

    try {
      await gateway.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        resendToken: _resendToken,
        onVerified: (token) {
          idToken = token;
          stage = PhoneSignInStage.verified;
          _ticker?.cancel();
          _emit();
          settle();
        },
        onCodeSent: (verificationId, resendToken) {
          _verificationId = verificationId;
          _resendToken = resendToken;
          _codeSentAt = _clock();
          if (stage == PhoneSignInStage.verified) return;
          stage = PhoneSignInStage.codeSent;
          _startCooldown();
          _emit();
          settle();
        },
        onFailed: (failure) {
          error = failure.message;
          stage = _verificationId == null ? PhoneSignInStage.idle : PhoneSignInStage.codeSent;
          _emit();
          settle();
        },
      );
    } on SocialAuthFailure catch (failure) {
      error = failure.message;
      stage = PhoneSignInStage.idle;
      _emit();
      settle();
    } catch (_) {
      error = AuthCodes.messageOf(AuthCodes.providerError);
      stage = PhoneSignInStage.idle;
      _emit();
      settle();
    }
    await done.future;
  }

  Future<bool> submitCode(String code) async {
    final verificationId = _verificationId;
    if (verificationId == null || isBusy) return false;
    if (codeExpired) {
      error = S.codeExpiredRequestNewOne;
      _emit();
      return false;
    }

    stage = PhoneSignInStage.verifying;
    error = null;
    _emit();

    try {
      idToken = await gateway.smsCodeIdToken(verificationId: verificationId, smsCode: code);
      stage = PhoneSignInStage.verified;
      _ticker?.cancel();
      _emit();
      return true;
    } on SocialAuthFailure catch (failure) {
      error = failure.message;
      stage = PhoneSignInStage.codeSent;
      _emit();
      return false;
    } catch (_) {
      error = AuthCodes.messageOf(AuthCodes.providerError);
      stage = PhoneSignInStage.codeSent;
      _emit();
      return false;
    }
  }
}
