import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:passkeys/types.dart' as pk;
import 'package:passkeys_platform_interface/passkeys_platform_interface.dart';

import 'package:savemybook_app/i18n/strings.dart';
import 'package:savemybook_app/models/passkey.dart';
import 'package:savemybook_app/services/api_service.dart';
import 'package:savemybook_app/services/passkey_service.dart';

// 與 API 實際輸出相同：iOS 註冊的憑證沒有 transports，@simplewebauthn/server 直接省略這個鍵。
Map<String, dynamic> _registrationOptions() => jsonDecode('''
{
  "challenge": "${'c' * 43}",
  "rp": {"name": "救「舊」我的書", "id": "savemybook.today"},
  "user": {"id": "dXNlci1oYW5kbGU", "name": "a@example.com", "displayName": "A"},
  "pubKeyCredParams": [{"alg": -8, "type": "public-key"}, {"alg": -7, "type": "public-key"}, {"alg": -257, "type": "public-key"}],
  "timeout": 300000,
  "attestation": "none",
  "excludeCredentials": [
    {"id": "aW9zLWNyZWQ", "type": "public-key"},
    {"id": "YW5kcm9pZC1jcmVk", "type": "public-key", "transports": ["internal", "hybrid"]}
  ],
  "authenticatorSelection": {"residentKey": "required", "requireResidentKey": true, "userVerification": "required"},
  "extensions": {"credProps": true},
  "hints": []
}
''') as Map<String, dynamic>;

Map<String, dynamic> _verifyOptions() => jsonDecode('''
{
  "rpId": "savemybook.today",
  "challenge": "${'c' * 43}",
  "timeout": 300000,
  "userVerification": "required",
  "allowCredentials": [{"id": "aW9zLWNyZWQ", "type": "public-key"}]
}
''') as Map<String, dynamic>;

class _FakePlatform extends PasskeysPlatform {
  Object? error;
  pk.RegisterRequestType? registered;
  pk.AuthenticateRequestType? authenticated;
  final signals = <(String, String)>[];
  var cancels = 0;

  @override
  Future<pk.RegisterResponseType> register(pk.RegisterRequestType request) async {
    registered = request;
    if (error != null) throw error!;
    return const pk.RegisterResponseType(
      id: 'bmV3',
      rawId: 'bmV3',
      clientDataJSON: 'e30',
      attestationObject: 'o2M',
      transports: ['internal', 'hybrid'],
    );
  }

  @override
  Future<pk.AuthenticateResponseType> authenticate(pk.AuthenticateRequestType request) async {
    authenticated = request;
    if (error != null) throw error!;
    return const pk.AuthenticateResponseType(
      id: 'aW9zLWNyZWQ',
      rawId: 'aW9zLWNyZWQ',
      clientDataJSON: 'e30',
      authenticatorData: 'AAAA',
      signature: 'MEUC',
      userHandle: 'dXNlci1oYW5kbGU',
    );
  }

  @override
  Future<void> cancelCurrentAuthenticatorOperation() async => cancels++;

  @override
  Future<pk.AvailabilityType> getAvailability() async =>
      pk.AvailabilityTypeAndroid(hasPasskeySupport: true, isNative: true, isUserVerifyingPlatformAuthenticatorAvailable: true);

  @override
  Future<void> signalUnknownCredential(pk.SignalUnknownCredentialRequestType request) async {
    signals.add((request.relyingPartyId, request.credentialId));
    if (error != null) throw error!;
  }
}

class _FlakyClient implements PasskeyClient {
  final List<Object> results;
  var calls = 0;

  _FlakyClient(this.results);

  @override
  Future<bool> isSupported() async {
    final next = results[calls < results.length ? calls : results.length - 1];
    calls++;
    if (next is bool) return next;
    throw next;
  }

  @override
  Future<Map<String, dynamic>> create(Map<String, dynamic> options) => throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> get(Map<String, dynamic> options, {bool immediate = true}) => throw UnimplementedError();

  @override
  Future<void> forget({required String rpId, required String credentialId}) async {}
}

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

void main() {
  late _FakePlatform platform;
  late PasskeysPlatform original;

  setUpAll(() => original = PasskeysPlatform.instance);

  setUp(() {
    platform = _FakePlatform();
    PasskeysPlatform.instance = platform;
    PasskeyService.resetCache();
  });

  tearDownAll(() => PasskeysPlatform.instance = original);

  group('D1：伺服器省略 transports 時仍能解析', () {
    test('補齊 excludeCredentials 的 transports 後可交給套件的 RegisterRequestType.fromJson', () {
      final request = pk.RegisterRequestType.fromJson(NativePasskeyClient.withTransports(_registrationOptions()));

      expect(request.excludeCredentials.map((c) => c.id), ['aW9zLWNyZWQ', 'YW5kcm9pZC1jcmVk']);
      expect(request.excludeCredentials.first.transports, isEmpty);
      expect(request.excludeCredentials.last.transports, ['internal', 'hybrid'], reason: '既有的 transports 保持原樣');
    });

    test('補齊 allowCredentials 的 transports 後可交給套件的 AuthenticateRequestType.fromJson', () {
      final request = pk.AuthenticateRequestType.fromJson(
        NativePasskeyClient.withTransports(_verifyOptions()),
        preferImmediatelyAvailableCredentials: false,
      );

      expect(request.allowCredentials, hasLength(1));
      expect(request.allowCredentials!.single.transports, isEmpty);
      expect(request.allowCredentials!.single.type, 'public-key');
    });

    test('transports 不是字串陣列或缺少 type 時一併修正，其他欄位不動', () {
      final options = {
        'rpId': 'savemybook.today',
        'challenge': 'c' * 43,
        'allowCredentials': [
          {'id': 'YQ', 'transports': null},
          {'id': 'Yg', 'type': 'public-key', 'transports': ['usb', 3, null]},
          'invalid',
        ],
      };
      final normalized = NativePasskeyClient.withTransports(options);
      final request = pk.AuthenticateRequestType.fromJson(normalized);

      expect(request.allowCredentials!.map((c) => c.transports), [isEmpty, ['usb']]);
      expect(request.allowCredentials!.first.type, 'public-key');
      expect(normalized['rpId'], 'savemybook.today');
      expect(options['allowCredentials'], hasLength(3), reason: '不可改動呼叫端的資料');
    });

    test('沒有 excludeCredentials 或 allowCredentials 時不新增欄位', () {
      final normalized = NativePasskeyClient.withTransports({'rpId': 'savemybook.today', 'challenge': 'c' * 43});
      expect(normalized.containsKey('allowCredentials'), isFalse);
      expect(normalized.containsKey('excludeCredentials'), isFalse);
    });

    test('create 以伺服器原始 options 呼叫平台層，憑證的 transports 為空陣列', () async {
      final attestation = await NativePasskeyClient().create(_registrationOptions());

      expect(platform.cancels, 1);
      expect(platform.registered!.excludeCredentials.first.transports, isEmpty);
      expect(platform.registered!.relyingParty.id, 'savemybook.today');
      expect(attestation['id'], 'bmV3');
      expect(attestation['response']['transports'], ['internal', 'hybrid']);
    });

    test('get 以伺服器原始 options 呼叫平台層，保留 immediate 設定', () async {
      final assertion = await NativePasskeyClient().get(_verifyOptions(), immediate: false);

      expect(platform.authenticated!.allowCredentials!.single.transports, isEmpty);
      expect(platform.authenticated!.preferImmediatelyAvailableCredentials, isFalse);
      expect(assertion['id'], 'aW9zLWNyZWQ');
      expect(assertion['response']['signature'], 'MEUC');
    });
  });

  group('D6：依平台錯誤碼區分失敗原因', () {
    Future<PasskeyClientException> failure(Object error, {bool create = false}) async {
      platform.error = error;
      try {
        create
            ? await NativePasskeyClient().create(_registrationOptions())
            : await NativePasskeyClient().get(_verifyOptions(), immediate: false);
      } on PasskeyClientException catch (e) {
        return e;
      }
      fail('應拋出 PasskeyClientException');
    }

    test('使用者取消不顯示訊息', () async {
      final e = await failure(PlatformException(code: 'cancelled', message: 'activity is cancelled by the user.'));
      expect(e.cancelled, isTrue);
      expect(e.message, isEmpty);
    });

    test('Android 裝置上沒有 allowCredentials 內的憑證時不當成取消', () async {
      final e = await failure(PlatformException(code: 'cancelled', message: 'None of the allowed credentials can be authenticated'));
      expect(e.kind, PasskeyFailure.noCredentials);
      expect(e.message, S.couldNotVerifyWithPasskeyDevice);
    });

    test('探索式登入未帶 allowCredentials 時，同一訊息來自使用者略過驗證，視為取消', () async {
      platform.error = PlatformException(code: 'cancelled', message: 'None of the allowed credentials can be authenticated');
      for (final options in [
        {..._verifyOptions(), 'allowCredentials': <Object>[]},
        {..._verifyOptions()}..remove('allowCredentials'),
      ]) {
        await expectLater(
          NativePasskeyClient().get(options),
          throwsA(isA<PasskeyClientException>().having((e) => e.kind, 'kind', PasskeyFailure.cancelled)),
        );
      }

      PasskeyService.client = NativePasskeyClient();
      final step = await http.runWithClient(
        () => PasskeyService.loginAssertion(immediate: false),
        () => MockClient((_) async => _json({
              'success': true,
              'data': {
                'options': {'rpId': 'savemybook.today', 'challenge': 'c' * 43, 'allowCredentials': <Object>[], 'userVerification': 'required'},
              },
            })),
      );
      expect(step.assertion, isNull);
      expect(step.failure!.isCancelled, isTrue);
    });

    test('此裝置沒有可用的通行密鑰', () async {
      for (final code in ['no-credentials-available', 'android-no-credential']) {
        final e = await failure(PlatformException(code: code));
        expect(e.kind, PasskeyFailure.noCredentials, reason: code);
        expect(e.message, S.noPasskeyAvailableDeviceUsePassword, reason: code);
      }
    });

    test('App 與網域的關聯失敗：iOS 的 domain-not-associated 與 Android 的 SecurityError', () async {
      for (final code in [
        'domain-not-associated',
        'android-unhandled: androidx.credentials.TYPE_GET_PUBLIC_KEY_CREDENTIAL_DOM_EXCEPTION/androidx.credentials.TYPE_SECURITY_ERROR',
      ]) {
        final e = await failure(PlatformException(code: code, message: 'The incoming request cannot be validated'));
        expect(e.message, S.passkeysTemporarilyUnavailableBecauseAppWebsite, reason: code);
        expect(e.kind, PasskeyFailure.other);
      }
      final created = await failure(
        PlatformException(code: 'android-unhandled: androidx.credentials.TYPE_CREATE_PUBLIC_KEY_CREDENTIAL_DOM_EXCEPTION/androidx.credentials.TYPE_SECURITY_ERROR'),
        create: true,
      );
      expect(created.message, S.passkeysTemporarilyUnavailableBecauseAppWebsite);
    });

    test('Android 中斷時請使用者重試，不要求改用密碼', () async {
      for (final code in [
        'android-unhandled: android.credentials.GetCredentialException.TYPE_INTERRUPTED',
        'android-unhandledandroid.credentials.CreateCredentialException.TYPE_INTERRUPTED',
      ]) {
        final e = await failure(PlatformException(code: code));
        expect(e.message, S.passkeyRequestWasInterruptedPleaseTry, reason: code);
      }
    });

    test('逾時', () async {
      for (final code in [
        'android-timeout',
        'ios-security-key-timeout',
        'android-unhandled: androidx.credentials.TYPE_GET_PUBLIC_KEY_CREDENTIAL_DOM_EXCEPTION/androidx.credentials.TYPE_TIMEOUT_ERROR',
      ]) {
        final e = await failure(PlatformException(code: code));
        expect(e.message, S.requestTimedOutPleaseTryAgain, reason: code);
      }
    });

    test('Google 帳號、螢幕鎖定、裝置不支援與已註冊', () async {
      expect((await failure(PlatformException(code: 'android-sync-account-not-available'))).message,
          S.signGoogleAccountTurnPasswordManager);
      expect((await failure(PlatformException(code: 'android-missing-google-sign-in'), create: true)).message,
          S.signGoogleAccountTurnPasswordManager);
      expect((await failure(PlatformException(code: 'android-no-create-option'), create: true)).message,
          S.setUpScreenLockPasswordManager);
      expect((await failure(PlatformException(code: 'android-passkey-unsupported'))).message, S.deviceDoesNotSupportPasskeysUse);
      expect((await failure(MissingPluginException())).message, S.deviceDoesNotSupportPasskeysUse);
      final excluded = await failure(PlatformException(code: 'exclude-credentials-match'), create: true);
      expect(excluded.kind, PasskeyFailure.excluded);
    });

    test('系統未分類的錯誤與解析失敗顯示通用訊息，不當成取消', () async {
      for (final error in <Object>[
        PlatformException(code: 'failed', message: 'The operation couldn’t be completed.'),
        PlatformException(code: 'unknown'),
        PlatformException(code: 'android-unhandled: android.credentials.GetCredentialException.TYPE_UNKNOWN'),
        TypeError(),
      ]) {
        final e = await failure(error);
        expect(e.cancelled, isFalse, reason: '$error');
        expect(e.message, S.passkeyRequestFailedUsePasswordInstead, reason: '$error');
      }
    });

    test('options 格式錯誤時不呼叫系統視窗', () async {
      platform.error = null;
      await expectLater(NativePasskeyClient().create({'challenge': 'c'}), throwsA(isA<PasskeyClientException>()));
      expect(platform.registered, isNull);
    });
  });

  group('D5：可用性偵測不把暫時性失敗當成結論', () {
    tearDown(() => PasskeyService.client = NativePasskeyClient());

    test('平台檢查拋出例外時不快取，下次重新檢查；成功後才快取', () async {
      final client = _FlakyClient([StateError('channel not ready'), true]);
      PasskeyService.client = client;

      expect(await PasskeyService.isSupported(), isFalse);
      expect(await PasskeyService.isSupported(), isTrue);
      expect(await PasskeyService.isSupported(), isTrue);
      expect(client.calls, 2);
    });

    test('伺服器狀態：只有明確停用才回 false，無法取得時回 null', () async {
      Future<bool?> enabledWith(http.Response Function() respond) =>
          http.runWithClient(() => ApiService().fetchPasskeyServerEnabled(), () => MockClient((_) async => respond()));

      expect(await enabledWith(() => _json({'success': true, 'data': {'enabled': true}})), isTrue);
      expect(await enabledWith(() => _json({'success': true, 'data': {'enabled': false}})), isFalse);
      expect(await enabledWith(() => _json({'success': false, 'code': 'MAINTENANCE', 'message': '系統維護中'}, 503)), isNull);
      expect(await enabledWith(() => _json({'success': false, 'code': 'RATE_LIMITED', 'message': '操作過於頻繁'}, 429)), isNull);
      expect(await enabledWith(() => http.Response('<html>502</html>', 502)), isNull);
      expect(
        await http.runWithClient(
          () => ApiService().fetchPasskeyServerEnabled(),
          () => MockClient((_) async => throw http.ClientException('offline')),
        ),
        isNull,
      );
    });

    test('isUsable：伺服器狀態未知時仍顯示入口，明確停用時隱藏', () async {
      PasskeyService.client = _FlakyClient([true]);
      final unknown = await http.runWithClient(
        PasskeyService.isUsable,
        () => MockClient((_) async => _json({'success': false, 'code': 'MAINTENANCE', 'message': '系統維護中'}, 503)),
      );
      final disabled = await http.runWithClient(
        PasskeyService.isUsable,
        () => MockClient((_) async => _json({'success': true, 'data': {'enabled': false, 'rp_id': null}})),
      );
      expect(unknown, isTrue);
      expect(disabled, isFalse);
    });
  });

  group('D11：依平台判斷伺服器是否可用', () {
    test('解析 platforms，缺少時視為可用', () {
      final legacy = PasskeyServerStatus.fromJson({'enabled': true});
      final noAndroid = PasskeyServerStatus.fromJson({
        'enabled': true,
        'rp_id': 'savemybook.today',
        'platforms': {'ios': true, 'android': false},
      });
      final disabled = PasskeyServerStatus.fromJson({
        'enabled': false,
        'rp_id': null,
        'platforms': {'ios': false, 'android': false},
      });

      for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
        expect(legacy.usableOn(platform), isTrue);
        expect(disabled.usableOn(platform), isFalse);
      }
      expect(noAndroid.usableOn(TargetPlatform.iOS), isTrue);
      expect(noAndroid.usableOn(TargetPlatform.android), isFalse);
      expect(noAndroid.rpId, 'savemybook.today');
      expect(legacy.rpId, isNull);
      expect(PasskeyServerStatus.fromJson({'enabled': true, 'platforms': {'android': 'no'}}).usableOn(TargetPlatform.android), isTrue);
    });

    test('fetchPasskeyServerEnabled 依目前平台取值', () async {
      final api = MockClient((_) async => _json({
            'success': true,
            'data': {'enabled': true, 'rp_id': 'savemybook.today', 'platforms': {'ios': true, 'android': false}},
          }));
      try {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        expect(await http.runWithClient(() => ApiService().fetchPasskeyServerEnabled(), () => api), isFalse);
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        expect(await http.runWithClient(() => ApiService().fetchPasskeyServerEnabled(), () => api), isTrue);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  group('D12：刪除後通知系統移除憑證', () {
    test('forget 以 RP ID 與憑證編號呼叫平台層的 signalUnknownCredential，失敗不往外拋', () async {
      await NativePasskeyClient().forget(rpId: 'savemybook.today', credentialId: 'aW9zLWNyZWQ');
      platform.error = PlatformException(code: 'android-unhandled: androidx.credentials.TYPE_UNKNOWN');
      await NativePasskeyClient().forget(rpId: 'savemybook.today', credentialId: 'YW5kcm9pZC1jcmVk');

      expect(platform.signals, [('savemybook.today', 'aW9zLWNyZWQ'), ('savemybook.today', 'YW5kcm9pZC1jcmVk')]);
    });

    test('清單項目帶有 credential_id', () {
      final item = PasskeyItem.fromJson({'passkey_id': 'PK1', 'credential_id': 'aW9zLWNyZWQ'});
      expect(item.credentialId, 'aW9zLWNyZWQ');
      expect(PasskeyItem.fromJson({'passkey_id': 'PK1'}).credentialId, isNull);
    });
  });

  group('D20：iOS 17.4 以下重新新增前須確認', () {
    final defaultVersion = PasskeyService.iosVersion;
    tearDown(() => PasskeyService.iosVersion = defaultVersion);

    PasskeyItem item(String? authenticator) => PasskeyItem(passkeyId: 'PK1', authenticator: authenticator);

    test('依 iOS 版本與既有通行密鑰的來源判斷', () async {
      Future<bool> check((int, int)? version, List<PasskeyItem> existing) {
        PasskeyService.iosVersion = () async => version;
        return PasskeyService.replacesSyncedPasskey(existing);
      }

      expect(await check((17, 3), [item('icloud_keychain')]), isTrue);
      expect(await check((16, 7), [item(null)]), isTrue, reason: 'iOS 18 以前 Apple 通行密鑰的 AAGUID 全為零');
      expect(await check((17, 4), [item('icloud_keychain')]), isFalse);
      expect(await check((18, 0), [item(null)]), isFalse);
      expect(await check((17, 3), [item('google_password_manager')]), isFalse);
      expect(await check((17, 3), const []), isFalse);
      expect(await check(null, [item('icloud_keychain')]), isFalse, reason: '非 iOS');
    });

    test('在 Apple Silicon Mac 上執行時，systemVersion 為 macOS 版本，換算為對應的 iOS 版本再判斷', () async {
      expect(PasskeyService.iosEquivalentVersion('17.3'), (17, 3));
      expect(PasskeyService.iosEquivalentVersion('18'), (18, 0));
      expect(PasskeyService.iosEquivalentVersion('14.5', onMac: true), (17, 5));
      expect(PasskeyService.iosEquivalentVersion('14.3.1', onMac: true), (17, 3));
      expect(PasskeyService.iosEquivalentVersion('15.2', onMac: true), (18, 2));
      expect(PasskeyService.iosEquivalentVersion('26.0', onMac: true), (26, 0));
      expect(PasskeyService.iosEquivalentVersion(''), isNull);

      final synced = [item('icloud_keychain'), item(null)];
      PasskeyService.iosVersion = () async => PasskeyService.iosEquivalentVersion('14.5', onMac: true);
      expect(await PasskeyService.replacesSyncedPasskey(synced), isFalse, reason: 'macOS 14.4 以上會傳入 excludeCredentials');
      PasskeyService.iosVersion = () async => PasskeyService.iosEquivalentVersion('15.2', onMac: true);
      expect(await PasskeyService.replacesSyncedPasskey(synced), isFalse);
      PasskeyService.iosVersion = () async => PasskeyService.iosEquivalentVersion('14.3', onMac: true);
      expect(await PasskeyService.replacesSyncedPasskey(synced), isTrue);
    });
  });
}
