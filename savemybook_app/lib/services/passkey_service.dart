import 'dart:convert';
import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show BuildContext;
import 'package:passkeys/availability.dart';
import 'package:passkeys/types.dart' as pk;
import 'package:passkeys_platform_interface/passkeys_platform_interface.dart';

import '../models/passkey.dart';
import 'api_service.dart';
import 'device_identity.dart';
import 'verification_service.dart';
import '../i18n/strings.dart';

abstract class PasskeyClient {
  Future<bool> isSupported();

  Future<Map<String, dynamic>> create(Map<String, dynamic> options);

  Future<Map<String, dynamic>> get(Map<String, dynamic> options, {bool immediate = true});

  Future<void> forget({required String rpId, required String credentialId});
}

enum PasskeyFailure { cancelled, excluded, noCredentials, other }

class PasskeyClientException implements Exception {
  final PasskeyFailure kind;
  final String message;

  const PasskeyClientException(this.message, {this.kind = PasskeyFailure.other});

  const PasskeyClientException.cancelled()
      : kind = PasskeyFailure.cancelled,
        message = '';

  bool get cancelled => kind == PasskeyFailure.cancelled;
}

class NativePasskeyClient implements PasskeyClient {
  // 直接呼叫平台層而不經過 PasskeyAuthenticator：後者把 PlatformException 換成不帶錯誤碼與訊息的例外，錯誤就無從分辨。
  PasskeysPlatform get _platform => PasskeysPlatform.instance;

  @override
  Future<bool> isSupported() async {
    if (!Platform.isIOS && !Platform.isAndroid) return false;
    final availability = GetAvailability(platform: _platform);
    final result = Platform.isIOS ? await availability.iOS() : await availability.android();
    return result.hasPasskeySupport;
  }

  /// iOS 建立的憑證沒有 transports，伺服器輸出時可能省略這個鍵；套件的 CredentialType.fromJson 卻把它當成必填而拋出 TypeError。
  @visibleForTesting
  static Map<String, dynamic> withTransports(Map<String, dynamic> options) => {
        ...options,
        for (final key in const ['excludeCredentials', 'allowCredentials'])
          if (options[key] is List)
            key: [
              for (final entry in options[key] as List)
                if (entry is Map)
                  <String, dynamic>{
                    ...Map<String, dynamic>.from(entry),
                    'type': entry['type'] is String ? entry['type'] : 'public-key',
                    'transports': [
                      if (entry['transports'] is List)
                        for (final transport in entry['transports'] as List)
                          if (transport is String) transport,
                    ],
                  },
            ],
      };

  @override
  Future<Map<String, dynamic>> create(Map<String, dynamic> options) => _guard(() async {
        final request = pk.RegisterRequestType.fromJson(withTransports(options));
        await _platform.cancelCurrentAuthenticatorOperation();
        return (await _platform.register(request)).toJson();
      });

  @override
  Future<Map<String, dynamic>> get(Map<String, dynamic> options, {bool immediate = true}) => _guard(
        () async {
          final request = pk.AuthenticateRequestType.fromJson(
            withTransports(options),
            preferImmediatelyAvailableCredentials: immediate,
          );
          await _platform.cancelCurrentAuthenticatorOperation();
          return (await _platform.authenticate(request)).toJson();
        },
        allowList: options['allowCredentials'] is List && (options['allowCredentials'] as List).isNotEmpty,
      );

  @override
  Future<void> forget({required String rpId, required String credentialId}) async {
    try {
      await _platform.signalUnknownCredential(
        pk.SignalUnknownCredentialRequestType(relyingPartyId: rpId, credentialId: credentialId),
      );
    } catch (e) {
      debugPrint('[passkey] $e');
    }
  }

  Future<Map<String, dynamic>> _guard(Future<Map<String, dynamic>> Function() run, {bool allowList = false}) async {
    try {
      // 套件的 toJson 帶有 Map<String?, Object?> 等型別，先經過一次 JSON 才能安全地放進請求本文。
      return Map<String, dynamic>.from(jsonDecode(jsonEncode(await run())) as Map);
    } catch (e) {
      // 任何例外都要轉成 PasskeyClientException：呼叫端只處理這一種，其餘例外會讓載入狀態卡住。
      throw describe(e, allowList: allowList);
    }
  }

  // passkeys_android 把 allowCredentials 內沒有可用憑證回報成 cancelled，只能以訊息分辨；
  // 未帶 allowCredentials 時同一訊息來自使用者略過驗證，仍屬取消。
  static const _noAllowedCredential = 'None of the allowed credentials can be authenticated';

  @visibleForTesting
  static PasskeyClientException describe(Object error, {bool allowList = false}) {
    debugPrint('[passkey] ${error is PlatformException ? '${error.code} ${error.message}' : error}');
    if (error is MissingPluginException) return PasskeyClientException(S.deviceDoesNotSupportPasskeysUse);
    if (error is! PlatformException) return PasskeyClientException(S.passkeyRequestFailedUsePasswordInstead);
    final code = error.code;
    return switch (code) {
      'cancelled' when allowList && error.message == _noAllowedCredential =>
        PasskeyClientException(S.couldNotVerifyWithPasskeyDevice, kind: PasskeyFailure.noCredentials),
      'cancelled' => const PasskeyClientException.cancelled(),
      'no-credentials-available' || 'android-no-credential' =>
        PasskeyClientException(S.noPasskeyAvailableDeviceUsePassword, kind: PasskeyFailure.noCredentials),
      'exclude-credentials-match' => PasskeyClientException(S.passkeyAlreadyRegisteredDevice, kind: PasskeyFailure.excluded),
      'android-missing-google-sign-in' || 'android-sync-account-not-available' =>
        PasskeyClientException(S.signGoogleAccountTurnPasswordManager),
      'android-no-create-option' => PasskeyClientException(S.setUpScreenLockPasswordManager),
      'deviceNotSupported' || 'android-passkey-unsupported' => PasskeyClientException(S.deviceDoesNotSupportPasskeysUse),
      'domain-not-associated' => PasskeyClientException(S.passkeysTemporarilyUnavailableBecauseAppWebsite),
      'android-timeout' || 'ios-security-key-timeout' => PasskeyClientException(S.requestTimedOutPleaseTryAgain),
      _ when code.startsWith('android-unhandled') => _describeAndroid(code),
      _ => PasskeyClientException(S.passkeyRequestFailedUsePasswordInstead),
    };
  }

  static PasskeyClientException _describeAndroid(String code) {
    if (code.endsWith('TYPE_SECURITY_ERROR')) return PasskeyClientException(S.passkeysTemporarilyUnavailableBecauseAppWebsite);
    if (code.endsWith('TYPE_INTERRUPTED') || code.endsWith('TYPE_ABORT_ERROR')) {
      return PasskeyClientException(S.passkeyRequestWasInterruptedPleaseTry);
    }
    if (code.endsWith('TYPE_TIMEOUT_ERROR')) return PasskeyClientException(S.requestTimedOutPleaseTryAgain);
    return PasskeyClientException(S.passkeyRequestFailedUsePasswordInstead);
  }
}

typedef PasskeyAssertion = ({Map<String, dynamic>? assertion, String rpId, PasskeyOutcome<void>? failure});

class PasskeyService {
  static PasskeyClient client = NativePasskeyClient();

  /// 身分驗證面板關閉後才叫出系統的建立視窗；兩個系統視窗緊接著出現時，iOS 會把第二個直接當成取消。
  static Duration handoffDelay = const Duration(milliseconds: 500);

  static const _minTokenValidity = Duration(minutes: 2);

  static bool? _supported;

  static void resetCache() => _supported = null;

  static Future<bool> isSupported() async {
    final cached = _supported;
    if (cached != null) return cached;
    try {
      return _supported = await client.isSupported();
    } catch (e) {
      debugPrint('[passkey] $e');
      return false;
    }
  }

  /// 伺服器狀態無法取得時仍視為可用：停用時每個通行密鑰端點都會回 PASSKEY_UNAVAILABLE 與說明。
  static Future<bool> isUsable() async =>
      await isSupported() && await ApiService().fetchPasskeyServerEnabled() != false;

  static Future<(int, int)?> Function() iosVersion = _iosVersion;

  static Future<(int, int)?> _iosVersion() async {
    if (!Platform.isIOS) return null;
    try {
      final info = await DeviceInfoPlugin().iosInfo;
      return iosEquivalentVersion(info.systemVersion, onMac: info.isiOSAppOnMac);
    } catch (_) {
      return null;
    }
  }

  // iOS App 在 Apple Silicon Mac 上執行時 systemVersion 是 macOS 版本；macOS 11～15 對應 iOS 14～18，26 起版本號相同。
  @visibleForTesting
  static (int, int)? iosEquivalentVersion(String systemVersion, {bool onMac = false}) {
    final parts = systemVersion.split('.');
    final major = int.tryParse(parts.first);
    if (major == null) return null;
    final minor = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return (onMac && major >= 11 && major <= 15 ? major + 3 : major, minor);
  }

  // iOS 17.4 以前套件不傳 excludeCredentials，同一 user.id 再次建立會直接覆蓋 iCloud 鑰匙圈中的舊通行密鑰。
  // 18 以前 Apple 通行密鑰的 AAGUID 全為零，authenticator 為 null 也要算進去。
  static Future<bool> replacesSyncedPasskey(List<PasskeyItem> existing) async {
    if (!existing.any((p) => p.authenticator == null || p.authenticator == 'icloud_keychain')) return false;
    final version = await iosVersion();
    if (version == null) return false;
    final (major, minor) = version;
    return major < 17 || (major == 17 && minor < 4);
  }

  static PasskeyOutcome<T> _clientFailure<T>(PasskeyClientException e) => switch (e.kind) {
        PasskeyFailure.cancelled => PasskeyOutcome<T>.cancelled(),
        PasskeyFailure.excluded => PasskeyOutcome<T>.fail(PasskeyOutcome.excludedCode, e.message),
        PasskeyFailure.noCredentials => PasskeyOutcome<T>.fail(PasskeyOutcome.noCredentialsCode, e.message),
        PasskeyFailure.other => PasskeyOutcome<T>.fail('PASSKEY_CLIENT', e.message),
      };

  static Future<PasskeyAssertion> loginAssertion({bool immediate = true}) async {
    final options = await ApiService().passkeyLoginOptions();
    if (!options.isOk) {
      return (assertion: null, rpId: '', failure: PasskeyOutcome<void>.fail(options.code, options.message));
    }
    final rpId = options.data!['rpId'] as String? ?? '';
    try {
      return (assertion: await client.get(options.data!, immediate: immediate), rpId: rpId, failure: null);
    } on PasskeyClientException catch (e) {
      return (assertion: null, rpId: rpId, failure: _clientFailure<void>(e));
    }
  }

  static Future<void> forgetIfUnknown(PasskeyOutcome<void> outcome, PasskeyAssertion step) async {
    if (outcome.code != 'PASSKEY_NOT_RECOGNIZED' || step.rpId.isEmpty) return;
    final id = step.assertion?['id'];
    if (id is String && id.isNotEmpty) await client.forget(rpId: step.rpId, credentialId: id);
  }

  static Future<PasskeyOutcome<void>> signIn({bool immediate = true}) async {
    final step = await loginAssertion(immediate: immediate);
    final assertion = step.assertion;
    if (assertion == null) return step.failure!;
    if (ApiService.currentUser == null) ApiService.authToken = null;
    final outcome = await ApiService().passkeyLogin(assertion);
    await forgetIfUnknown(outcome, step);
    return outcome;
  }

  static Future<({String? token, String? message})> verify(String scope) async {
    final api = ApiService();
    final options = await api.passkeyVerifyOptions(scope);
    if (!options.isOk) return (token: null, message: options.message);

    final Map<String, dynamic> assertion;
    try {
      assertion = await client.get(options.data!, immediate: false);
    } on PasskeyClientException catch (e) {
      return (token: null, message: e.cancelled ? null : e.message);
    }
    final outcome = await api.verifyIdentityWithPasskey(scope: scope, assertion: assertion);
    return outcome.isSuccess ? (token: outcome.token, message: null) : (token: null, message: outcome.message);
  }

  static Future<PasskeyOutcome<List<PasskeyItem>>> register(
    BuildContext context, {
    List<PasskeyItem> existing = const [],
    bool replaceConfirmed = false,
  }) async {
    if (!replaceConfirmed && await replacesSyncedPasskey(existing)) {
      return PasskeyOutcome.fail(PasskeyOutcome.replaceCode, S.passkeyAlreadyRegisteredDevice);
    }
    if (!context.mounted) return const PasskeyOutcome.cancelled();
    final prompted = VerificationService.cachedSensitiveTokenValidFor(_minTokenValidity) == null;
    final verifyToken = await VerificationService.requireSensitive(
      context,
      reason: S.verifyIdentityBeforeAddingPasskey,
      minValidity: _minTokenValidity,
    );
    if (verifyToken == null) return const PasskeyOutcome.cancelled();

    final api = ApiService();
    final options = await api.passkeyRegistrationOptions();
    if (!options.isOk) return PasskeyOutcome.fail(options.code, options.message);
    if (prompted && handoffDelay > Duration.zero) await Future<void>.delayed(handoffDelay);

    final Map<String, dynamic> attestation;
    try {
      attestation = await client.create(options.data!);
    } on PasskeyClientException catch (e) {
      return _clientFailure(e);
    }
    final label = await defaultLabel();
    return api.registerPasskey(attestation, deviceLabel: label, verifyToken: verifyToken);
  }

  static Future<String?> defaultLabel() async {
    final name = (await DeviceIdentity.name()).trim();
    if (name.isEmpty || name == DeviceIdentity.platform) return null;
    return name.length > 50 ? name.substring(0, 50) : name;
  }

  static Future<PasskeyOutcome<List<PasskeyItem>>> rename(String passkeyId, String label) =>
      ApiService().renamePasskey(passkeyId, label);

  /// 須在伺服器刪除成功後才呼叫。
  static Future<void> forgetDeleted(String? credentialId) async {
    if (credentialId == null || credentialId.isEmpty) return;
    final rpId = (await ApiService().fetchPasskeyStatus())?.rpId;
    if (rpId != null) await client.forget(rpId: rpId, credentialId: credentialId);
  }
}
