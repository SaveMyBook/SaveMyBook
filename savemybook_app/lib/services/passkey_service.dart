import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show BuildContext;
import 'package:passkeys/authenticator.dart';
import 'package:passkeys/availability.dart';
import 'package:passkeys/types.dart' as pk;
import 'package:passkeys_platform_interface/passkeys_platform_interface.dart';

import '../models/passkey.dart';
import 'api_service.dart';
import 'device_identity.dart';
import 'verification_service.dart';
import '../i18n/strings.dart';

/// 系統通行密鑰介面的轉接層；測試以 [PasskeyService.client] 替換。
abstract class PasskeyClient {
  Future<bool> isSupported();

  /// 回傳 WebAuthn `RegistrationResponseJSON`。
  Future<Map<String, dynamic>> create(Map<String, dynamic> options);

  /// 回傳 WebAuthn `AuthenticationResponseJSON`。
  Future<Map<String, dynamic>> get(Map<String, dynamic> options);
}

/// 系統端的錯誤一律轉成這個例外；[cancelled] 為使用者自行關閉系統對話框。
class PasskeyClientException implements Exception {
  final bool cancelled;
  final String message;

  const PasskeyClientException(this.message, {this.cancelled = false});

  const PasskeyClientException.cancelled()
      : cancelled = true,
        message = '';
}

class NativePasskeyClient implements PasskeyClient {
  final PasskeyAuthenticator _authenticator = PasskeyAuthenticator();

  @override
  Future<bool> isSupported() async {
    try {
      if (!Platform.isIOS && !Platform.isAndroid) return false;
      final availability = GetAvailability(platform: PasskeysPlatform.instance);
      final result = Platform.isIOS ? await availability.iOS() : await availability.android();
      return result.hasPasskeySupport;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>> create(Map<String, dynamic> options) => _guard(() async {
        final response = await _authenticator.register(pk.RegisterRequestType.fromJson(options));
        return response.toJson();
      });

  @override
  Future<Map<String, dynamic>> get(Map<String, dynamic> options) => _guard(() async {
        final response = await _authenticator.authenticate(pk.AuthenticateRequestType.fromJson(options));
        return response.toJson();
      });

  Future<Map<String, dynamic>> _guard(Future<Map<String, dynamic>> Function() run) async {
    try {
      // 套件的 toJson 帶有 Map<String?, Object?> 等型別，先經過一次 JSON 才能安全地放進請求本文。
      return Map<String, dynamic>.from(jsonDecode(jsonEncode(await run())) as Map);
    } on pk.PasskeyAuthCancelledException {
      throw const PasskeyClientException.cancelled();
    } on pk.NoCredentialsAvailableException {
      throw PasskeyClientException(S.noPasskeyAvailableDeviceUsePassword);
    } on pk.ExcludeCredentialsCanNotBeRegisteredException {
      throw PasskeyClientException(S.passkeyAlreadyRegisteredDevice);
    } on pk.SyncAccountNotAvailableException {
      throw PasskeyClientException(S.signGoogleAccountTurnPasswordManager);
    } on pk.MissingGoogleSignInException {
      throw PasskeyClientException(S.signGoogleAccountTurnPasswordManager);
    } on pk.NoCreateOptionException {
      throw PasskeyClientException(S.setUpScreenLockPasswordManager);
    } on pk.DeviceNotSupportedException {
      throw PasskeyClientException(S.deviceDoesNotSupportPasskeysUse);
    } on pk.PasskeyUnsupportedException {
      throw PasskeyClientException(S.deviceDoesNotSupportPasskeysUse);
    } on pk.DomainNotAssociatedException {
      throw PasskeyClientException(S.passkeysTemporarilyUnavailableBecauseAppWebsite);
    } on pk.TimeoutException {
      throw PasskeyClientException(S.requestTimedOutPleaseTryAgain);
    } on pk.AuthenticatorException {
      throw PasskeyClientException(S.passkeyRequestFailedUsePasswordInstead);
    } on PlatformException {
      throw PasskeyClientException(S.passkeyRequestFailedUsePasswordInstead);
    } on MissingPluginException {
      throw PasskeyClientException(S.deviceDoesNotSupportPasskeysUse);
    }
  }
}

class PasskeyService {
  static PasskeyClient client = NativePasskeyClient();

  static bool? _supported;

  static void resetCache() => _supported = null;

  static Future<bool> isSupported() async => _supported ??= await client.isSupported();

  static PasskeyOutcome<T> _clientFailure<T>(PasskeyClientException e) =>
      e.cancelled ? PasskeyOutcome<T>.cancelled() : PasskeyOutcome<T>.fail('PASSKEY_CLIENT', e.message);

  /// 探索式登入：由系統列出此裝置可用的通行密鑰，不需要先輸入 Email。
  static Future<PasskeyOutcome<void>> signIn() async {
    final api = ApiService();
    final options = await api.passkeyLoginOptions();
    if (!options.isOk) return PasskeyOutcome.fail(options.code, options.message);

    final Map<String, dynamic> assertion;
    try {
      assertion = await client.get(options.data!);
    } on PasskeyClientException catch (e) {
      return _clientFailure(e);
    }
    if (ApiService.currentUser == null) ApiService.authToken = null;
    return api.passkeyLogin(assertion);
  }

  /// 驗證身分並取得指定範圍的驗證權杖。
  static Future<({String? token, String? message})> verify(String scope) async {
    final api = ApiService();
    final options = await api.passkeyVerifyOptions(scope);
    if (!options.isOk) return (token: null, message: options.message);

    final Map<String, dynamic> assertion;
    try {
      assertion = await client.get(options.data!);
    } on PasskeyClientException catch (e) {
      return (token: null, message: e.cancelled ? null : e.message);
    }
    final outcome = await api.verifyIdentityWithPasskey(scope: scope, assertion: assertion);
    return outcome.isSuccess ? (token: outcome.token, message: null) : (token: null, message: outcome.message);
  }

  /// 新增通行密鑰：先完成 sensitive 身分驗證，再請系統建立憑證。
  static Future<PasskeyOutcome<List<PasskeyItem>>> register(BuildContext context) async {
    final verifyToken = await VerificationService.requireSensitive(context, reason: S.verifyIdentityBeforeAddingPasskey);
    if (verifyToken == null) return const PasskeyOutcome.cancelled();

    final api = ApiService();
    final options = await api.passkeyRegistrationOptions();
    if (!options.isOk) return PasskeyOutcome.fail(options.code, options.message);

    final Map<String, dynamic> attestation;
    try {
      attestation = await client.create(options.data!);
    } on PasskeyClientException catch (e) {
      return _clientFailure(e);
    }
    final name = (await DeviceIdentity.name()).trim();
    final label = name.length > 50 ? name.substring(0, 50) : name;
    return api.registerPasskey(attestation, deviceLabel: label.isEmpty ? null : label, verifyToken: verifyToken);
  }
}
