import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
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
  Future<Map<String, dynamic>> get(Map<String, dynamic> options, {bool immediate = true}) => _guard(() async {
        final request = pk.AuthenticateRequestType.fromJson(options, preferImmediatelyAvailableCredentials: immediate);
        final response = await _authenticator.authenticate(request);
        return response.toJson();
      });

  @override
  Future<void> forget({required String rpId, required String credentialId}) async {
    try {
      await _authenticator.signalUnknownCredential(
        pk.SignalUnknownCredentialRequestType(relyingPartyId: rpId, credentialId: credentialId),
      );
    } catch (_) {}
  }

  Future<Map<String, dynamic>> _guard(Future<Map<String, dynamic>> Function() run) async {
    try {
      // 套件的 toJson 帶有 Map<String?, Object?> 等型別，先經過一次 JSON 才能安全地放進請求本文。
      return Map<String, dynamic>.from(jsonDecode(jsonEncode(await run())) as Map);
    } on pk.PasskeyAuthCancelledException {
      throw const PasskeyClientException.cancelled();
    } on pk.NoCredentialsAvailableException {
      throw PasskeyClientException(S.noPasskeyAvailableDeviceUsePassword, kind: PasskeyFailure.noCredentials);
    } on pk.ExcludeCredentialsCanNotBeRegisteredException {
      throw PasskeyClientException(S.passkeyAlreadyRegisteredDevice, kind: PasskeyFailure.excluded);
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
    } on MissingPluginException {
      throw PasskeyClientException(S.deviceDoesNotSupportPasskeysUse);
    } catch (e) {
      // 其餘錯誤（系統未分類的錯誤、格式錯誤）不可往外拋：呼叫端的載入狀態會卡住。
      debugPrint('[passkey] $e');
      throw PasskeyClientException(S.passkeyRequestFailedUsePasswordInstead);
    }
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

  static Future<bool> isSupported() async => _supported ??= await client.isSupported();

  static Future<bool> isUsable() async => await isSupported() && await ApiService().fetchPasskeyServerEnabled();

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

  static Future<PasskeyOutcome<List<PasskeyItem>>> register(BuildContext context) async {
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
}
