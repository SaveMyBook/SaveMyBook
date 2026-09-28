import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:savemybook_app/features/auth/login_screen.dart';
import 'package:savemybook_app/features/auth/social_sign_in.dart';
import 'package:savemybook_app/features/security/identity_verification_sheet.dart';
import 'package:savemybook_app/features/security/passkey_sign_in_button.dart';
import 'package:savemybook_app/features/security/passkeys_card.dart';
import 'package:savemybook_app/features/security/security_center_screen.dart';
import 'package:savemybook_app/i18n/app_localizations.dart';
import 'package:savemybook_app/i18n/strings.dart';
import 'package:savemybook_app/models/user.dart';
import 'package:savemybook_app/services/api_service.dart';
import 'package:savemybook_app/services/locale_provider.dart';
import 'package:savemybook_app/services/passkey_service.dart';
import 'package:savemybook_app/services/verification_service.dart';
import 'package:savemybook_app/utils/app_theme.dart';
import 'package:savemybook_app/widgets/app_buttons.dart';

const _assertion = {
  'id': 'cred-1',
  'rawId': 'cred-1',
  'type': 'public-key',
  'response': {'clientDataJSON': 'e30', 'authenticatorData': 'AAAA', 'signature': 'MEUC'},
};

class _FakeClient implements PasskeyClient {
  bool cancel = false;
  final requests = <Map<String, dynamic>>[];

  @override
  Future<bool> isSupported() async => true;

  @override
  Future<Map<String, dynamic>> create(Map<String, dynamic> options) async => throw UnimplementedError();

  @override
  Future<void> forget({required String rpId, required String credentialId}) async {}

  @override
  Future<Map<String, dynamic>> get(Map<String, dynamic> options, {bool immediate = true}) async {
    requests.add(options);
    if (cancel) throw const PasskeyClientException.cancelled();
    return Map<String, dynamic>.from(_assertion);
  }
}

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

MockClient _fakeApi(List<String> calls, {bool hasPasskey = true}) =>
    MockClient((req) async => _fakeResponse(req, calls, hasPasskey: hasPasskey));

http.Response _fakeResponse(http.Request req, List<String> calls, {bool hasPasskey = true}) {
  final path = req.url.path.replaceFirst('/api', '');
  final body = req.body.isEmpty ? <String, dynamic>{} : jsonDecode(req.body) as Map<String, dynamic>;
  calls.add('${req.method} $path${body['method'] != null ? ' ${body['scope']}/${body['method']}' : ''}');
  switch (path) {
    case '/security':
      return _json({
        'success': true,
        'data': {
          'available': true,
          'has_password': true,
          'has_payment_pin': true,
          'biometric_pay_enabled': false,
          'passkey_available': true,
          'has_passkey': hasPasskey,
        },
      });
    case '/security/verify/passkey/options':
    case '/auth/passkeys/login/options':
      return _json({
        'success': true,
        'data': {
          'options': {'challenge': 'c' * 64, 'rpId': 'savemybook.today', 'allowCredentials': <Object>[], 'userVerification': 'required'},
        },
      });
    case '/security/verify':
      if (body['method'] != 'passkey' || body['assertion']?['id'] != 'cred-1') {
        return _json({'success': false, 'code': 'INVALID_PASSWORD', 'message': '密碼錯誤'}, 400);
      }
      return _json({'success': true, 'data': {'verify_token': 'passkey-token', 'scope': body['scope'], 'expires_in': 300}});
    case '/auth/passkeys/status':
      return _json({'success': true, 'data': {'enabled': true}});
    case '/auth/passkeys/login':
      return _json({'success': true, 'message': '登入成功', 'data': {'token': 'session-token'}});
    case '/auth/me':
      return _json({'success': true, 'data': {'user_id': 3, 'nickname': 'B', 'email': 'b@example.com', 'role': 'buyer_seller'}});
  }
  return _json({'success': true});
}

Future<void> _pumpHost(WidgetTester tester, GlobalKey<NavigatorState> navKey, {Widget? home}) async {
  await tester.pumpWidget(MaterialApp(
    navigatorKey: navKey,
    locale: const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    supportedLocales: LocaleProvider.supported,
    theme: AppTheme.build(Brightness.light),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, child) {
      S = AppLocalizations.of(context);
      return child!;
    },
    home: home ?? const Scaffold(body: SizedBox()),
  ));
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

class _Result {
  String? value;
  bool done = false;

  void watch(Future<String?> future) => future.then((token) {
        value = token;
        done = true;
      });
}

void main() {
  late _FakeClient client;

  setUp(() {
    PasskeyService.handoffDelay = Duration.zero;
    SharedPreferences.setMockInitialValues({});
    VerificationService.clearCache();
    client = _FakeClient();
    PasskeyService.client = client;
    PasskeyService.resetCache();
    ApiService.authToken = 'token';
    ApiService.currentUser = User.fromJson({'user_id': 9, 'nickname': 'A', 'email': 'a@x.com', 'role': 'admin'});
  });

  testWidgets('已註冊通行密鑰時，後台驗證預設使用通行密鑰並取得權杖', (tester) async {
    final navKey = GlobalKey<NavigatorState>();
    VerificationService.navigatorKey = navKey;
    final calls = <String>[];

    await http.runWithClient(() async {
      await _pumpHost(tester, navKey);
      await _settle(tester);

      final result = _Result();
      await tester.runAsync(() async {
        result.watch(VerificationService.requireAdminPassword(navKey.currentContext!));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await _settle(tester);

      expect(find.byType(IdentityVerificationSheet), findsOneWidget);
      expect(find.byType(TextField), findsNothing, reason: '預設不顯示密碼欄位');
      expect(find.text(S.useSignPasswordInstead), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, S.verifyWithPasskey));
      await _settle(tester);

      expect(result.value, 'passkey-token');
      expect(calls, containsAllInOrder(['POST /security/verify/passkey/options', 'POST /security/verify admin/passkey']));
      expect(client.requests.single['rpId'], 'savemybook.today');
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => _fakeApi(calls));
  });

  testWidgets('取消通行密鑰不顯示錯誤，可改用登入密碼', (tester) async {
    final navKey = GlobalKey<NavigatorState>();
    VerificationService.navigatorKey = navKey;
    final calls = <String>[];
    client.cancel = true;

    await http.runWithClient(() async {
      await _pumpHost(tester, navKey);
      await _settle(tester);

      final result = _Result();
      await tester.runAsync(() async {
        result.watch(VerificationService.requireSensitive(navKey.currentContext!));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await _settle(tester);

      await tester.tap(find.widgetWithText(ElevatedButton, S.verifyWithPasskey));
      await _settle(tester);
      expect(find.byType(IdentityVerificationSheet), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsNothing);
      expect(result.done, isFalse);

      await tester.tap(find.text(S.useSignPasswordInstead));
      await _settle(tester);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text(S.verifyWithPasskeyInstead), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => _fakeApi(calls));
  });

  testWidgets('尚未註冊通行密鑰時維持原本的密碼驗證', (tester) async {
    final navKey = GlobalKey<NavigatorState>();
    VerificationService.navigatorKey = navKey;
    final calls = <String>[];

    await http.runWithClient(() async {
      await _pumpHost(tester, navKey);
      await _settle(tester);
      await tester.runAsync(() async {
        VerificationService.requireAdminPassword(navKey.currentContext!);
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await _settle(tester);

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text(S.verifyWithPasskeyInstead), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => _fakeApi(calls, hasPasskey: false));
  });

  testWidgets('登入頁的通行密鑰按鈕：伺服器啟用才顯示，登入成功後存下 Token', (tester) async {
    final navKey = GlobalKey<NavigatorState>();
    final calls = <String>[];
    ApiService.authToken = null;
    ApiService.currentUser = null;
    var signedIn = 0;

    await http.runWithClient(() async {
      await _pumpHost(
        tester,
        navKey,
        home: Scaffold(body: PasskeySignInButton(onSignedIn: () async => signedIn++)),
      );
      await _settle(tester);
      expect(find.text(S.signWithPasskey), findsNothing, reason: '伺服器未回報啟用');
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => MockClient((req) async => _json({'success': true, 'data': {'enabled': false}})));

    await http.runWithClient(() async {
      await _pumpHost(
        tester,
        navKey,
        home: Scaffold(body: PasskeySignInButton(onSignedIn: () async => signedIn++)),
      );
      await _settle(tester);
      await tester.tap(find.text(S.signWithPasskey));
      await _settle(tester);

      expect(signedIn, 1);
      expect(ApiService.authToken, 'session-token');
      expect(ApiService.currentUser?.email, 'b@example.com');
      expect(calls, containsAllInOrder(['POST /auth/passkeys/login/options', 'POST /auth/passkeys/login', 'GET /auth/me']));
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => _fakeApi(calls));
  });

  group('新增與管理通行密鑰', () {
    Map<String, dynamic> row(String id, String label, {String? authenticator, bool backedUp = true}) => {
          'passkey_id': id,
          'device_label': label,
          'authenticator': authenticator,
          'backed_up': backedUp,
          'created_at': '2026-09-01T08:00:00Z',
          'last_used_at': null,
        };

    MockClient cardApi(List<String> calls, {required List<Map<String, dynamic>> Function() items}) => MockClient((req) async {
          final path = req.url.path.replaceFirst('/api', '');
          final body = req.body.isEmpty ? <String, dynamic>{} : jsonDecode(req.body) as Map<String, dynamic>;
          calls.add('${req.method} $path${body['method'] != null ? ' ${body['scope']}/${body['method']}' : ''}');
          switch ('${req.method} $path') {
            case 'GET /security':
              return _json({
                'success': true,
                'data': {'available': true, 'has_password': true, 'has_payment_pin': false, 'passkey_available': true, 'has_passkey': false},
              });
            case 'POST /security/verify':
              return _json({'success': true, 'data': {'verify_token': 'sensitive-token', 'scope': 'sensitive', 'expires_in': 300}});
            case 'POST /users/me/passkeys/options':
              return _json({'success': true, 'data': {'options': {'challenge': 'c' * 64, 'rp': {'id': 'savemybook.today'}}}});
            case 'POST /users/me/passkeys':
              expect(req.headers['x-verify-token'], 'sensitive-token');
              return _json({'success': true, 'data': [...items(), row('PK2', 'iPhone 17 Pro', authenticator: 'icloud_keychain')]}, 201);
            case 'GET /users/me/passkeys':
              return _json({'success': true, 'data': items()});
          }
          if (req.method == 'PATCH' && path.startsWith('/users/me/passkeys/')) {
            return _json({'success': true, 'data': [row('PK1', body['device_label'] as String, authenticator: 'icloud_keychain')]});
          }
          return _json({'success': true});
        });

    Future<void> pumpCard(WidgetTester tester, GlobalKey<NavigatorState> navKey) async {
      VerificationService.navigatorKey = navKey;
      await _pumpHost(tester, navKey, home: const Scaffold(body: SingleChildScrollView(child: PasskeysCard())));
      await _settle(tester);
    }

    testWidgets('清單以使用者看得懂的方式標示同步狀態，可重新命名', (tester) async {
      final calls = <String>[];
      final navKey = GlobalKey<NavigatorState>();
      await http.runWithClient(() async {
        await pumpCard(tester, navKey);
        expect(find.text('${S.icloudKeychain}・${S.synced}'), findsOneWidget);
        expect(find.text(S.notSynced), findsOneWidget);

        await tester.tap(find.byTooltip(S.moreOptions).first);
        await _settle(tester);
        await tester.tap(find.text(S.rename));
        await _settle(tester);
        await tester.enterText(find.byType(TextField), '工作用 iPhone');
        await tester.tap(find.text(S.actionSave));
        await _settle(tester);

        expect(calls, contains('PATCH /users/me/passkeys/PK1'));
        expect(find.text('工作用 iPhone'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => cardApi(calls, items: () => [
            row('PK1', 'iPhone 16', authenticator: 'icloud_keychain'),
            row('PK3', 'YubiKey', backedUp: false),
          ]));
    });

    testWidgets('同一個密碼管理工具已有通行密鑰時說明原因，改存到其他位置不再重複驗證身分', (tester) async {
      final calls = <String>[];
      final navKey = GlobalKey<NavigatorState>();
      final scripted = _ScriptedClient([
        const PasskeyClientException('dup', kind: PasskeyFailure.excluded),
        {'id': 'bmV3', 'rawId': 'bmV3', 'type': 'public-key', 'response': {'clientDataJSON': 'e30', 'attestationObject': 'o2M'}},
      ]);
      PasskeyService.client = scripted;

      await http.runWithClient(() async {
        await pumpCard(tester, navKey);
        await tester.tap(find.text(S.addPasskey));
        await _settle(tester);

        expect(find.byType(IdentityVerificationSheet), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'Passw0rd123');
        await tester.tap(find.widgetWithText(ElevatedButton, S.verifyS));
        await _settle(tester);

        expect(scripted.creates, 1);
        expect(find.text(S.alreadyPasskey), findsOneWidget);
        expect(find.text(PasskeysCard.alreadyRegisteredMessage()), findsOneWidget);
        expect(find.byIcon(Icons.error_outline_rounded), findsNothing, reason: '不可顯示成錯誤');

        await tester.tap(find.text(S.addAgain));
        await _settle(tester);

        expect(scripted.creates, 2);
        expect(find.byType(IdentityVerificationSheet), findsNothing);
        expect(calls.where((c) => c.startsWith('POST /security/verify')).length, 1, reason: '沿用剛取得的驗證權杖');
        expect(find.text('iPhone 17 Pro'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => cardApi(calls, items: () => [row('PK1', 'iPhone 16', authenticator: 'icloud_keychain')]));
    });

    testWidgets('伺服器回報已註冊時同樣說明，不顯示錯誤', (tester) async {
      final calls = <String>[];
      final navKey = GlobalKey<NavigatorState>();
      PasskeyService.client = _ScriptedClient([
        {'id': 'b2xk', 'rawId': 'b2xk', 'type': 'public-key', 'response': {'clientDataJSON': 'e30', 'attestationObject': 'o2M'}},
      ]);
      VerificationService.rememberSensitive('sensitive-token');

      await http.runWithClient(() async {
        await pumpCard(tester, navKey);
        await tester.tap(find.text(S.addPasskey));
        await _settle(tester);
        expect(find.text(S.alreadyPasskey), findsOneWidget);
        await tester.tap(find.text(S.got));
        await _settle(tester);
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => MockClient((req) async {
            final path = req.url.path.replaceFirst('/api', '');
            calls.add('${req.method} $path');
            if (req.method == 'POST' && path == '/users/me/passkeys') {
              return _json({'success': false, 'code': 'PASSKEY_ALREADY_REGISTERED', 'message': '此通行密鑰已經註冊'}, 409);
            }
            if (path == '/users/me/passkeys/options') {
              return _json({'success': true, 'data': {'options': {'challenge': 'c' * 64}}});
            }
            return _json({'success': true, 'data': [row('PK1', 'iPhone 16')]});
          }));
      expect(calls.where((c) => c == 'GET /users/me/passkeys').length, 2, reason: '重新載入清單');
    });

    testWidgets('系統回傳未預期的錯誤時顯示訊息，按鈕不會停在載入中', (tester) async {
      final calls = <String>[];
      final navKey = GlobalKey<NavigatorState>();
      PasskeyService.client = _ScriptedClient([StateError('boom')]);
      VerificationService.rememberSensitive('sensitive-token');

      await http.runWithClient(() async {
        await pumpCard(tester, navKey);
        await tester.tap(find.text(S.addPasskey));
        await _settle(tester);
        expect(find.text(S.somethingWentWrongPleaseTryAgain), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => cardApi(calls, items: () => [row('PK1', 'iPhone 16')]));
    });
  });

  testWidgets('登入頁：此裝置沒有通行密鑰時可改用密碼，或改用其他裝置的通行密鑰', (tester) async {
    final navKey = GlobalKey<NavigatorState>();
    final calls = <String>[];
    ApiService.authToken = null;
    ApiService.currentUser = null;
    final scripted = _ScriptedClient(const []);
    PasskeyService.client = scripted;
    var usePassword = 0;
    var signedIn = 0;

    await http.runWithClient(() async {
      await _pumpHost(
        tester,
        navKey,
        home: Scaffold(
          body: PasskeySignInButton(
            initialVisible: true,
            onSignedIn: () async => signedIn++,
            onUsePassword: () => usePassword++,
          ),
        ),
      );
      await _settle(tester);

      await tester.tap(find.text(S.signWithPasskey));
      await _settle(tester);
      expect(find.text(S.noPasskeyDevice), findsOneWidget);
      await tester.tap(find.text(S.usePassword));
      await _settle(tester);
      expect(usePassword, 1);
      expect(signedIn, 0);

      await tester.tap(find.text(S.signWithPasskey));
      await _settle(tester);
      await tester.tap(find.text(S.useAnotherDevice));
      await _settle(tester);
      expect(signedIn, 1);
      expect(scripted.immediates, [true, true, false]);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => _fakeApi(calls));
  });

  group('稽核修正', () {
    final defaultIosVersion = PasskeyService.iosVersion;
    late _RecordingClient recording;

    setUp(() {
      recording = _RecordingClient();
      PasskeyService.client = recording;
    });

    tearDown(() => PasskeyService.iosVersion = defaultIosVersion);

    http.Response status({bool android = true}) => _json({
          'success': true,
          'data': {'enabled': true, 'rp_id': 'savemybook.today', 'platforms': {'ios': true, 'android': android}},
        });

    http.Response maintenance() => _json({'success': false, 'code': 'MAINTENANCE', 'message': '系統維護中'}, 503);

    MockClient overriding(List<String> calls, Map<String, http.Response Function()> routes) => MockClient((req) async {
          final route = routes['${req.method} ${req.url.path.replaceFirst('/api', '')}'];
          if (route != null) {
            calls.add('${req.method} ${req.url.path.replaceFirst('/api', '')}');
            return route();
          }
          return _fakeResponse(req, calls);
        });

    testWidgets('D5／D11：登入按鈕只在伺服器明確停用或本平台未設定時隱藏，回到前景時重新檢查', (tester) async {
      final navKey = GlobalKey<NavigatorState>();
      ApiService.authToken = null;
      ApiService.currentUser = null;

      await http.runWithClient(() async {
        await _pumpHost(tester, navKey, home: Scaffold(body: PasskeySignInButton(onSignedIn: () async {})));
        await _settle(tester);
        expect(find.text(S.signWithPasskey), findsOneWidget, reason: '狀態無法取得時照常顯示');
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => MockClient((_) async => maintenance()));

      var androidReady = false;
      await http.runWithClient(() async {
        await _pumpHost(tester, navKey, home: Scaffold(body: PasskeySignInButton(onSignedIn: () async {})));
        await _settle(tester);
        expect(find.text(S.signWithPasskey), findsNothing, reason: '伺服器未設定 Android 來源');

        androidReady = true;
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await _settle(tester);
        expect(find.text(S.signWithPasskey), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => MockClient((_) async => status(android: androidReady)));
    });

    testWidgets('D5：取得安全狀態失敗時顯示失敗原因，不開出只能輸入密碼的面板', (tester) async {
      final navKey = GlobalKey<NavigatorState>();
      VerificationService.navigatorKey = navKey;

      Future<void> expectFailure(MockClient api, {required bool offline}) => http.runWithClient(() async {
            await _pumpHost(tester, navKey);
            await _settle(tester);
            final result = _Result();
            await tester.runAsync(() async {
              result.watch(VerificationService.requireSensitive(tester.element(find.byType(Scaffold))));
              await Future<void>.delayed(const Duration(milliseconds: 100));
            });
            await _settle(tester);

            expect(find.byType(IdentityVerificationSheet), findsNothing);
            expect(find.text('系統維護中'), offline ? findsNothing : findsOneWidget);
            expect(find.text(S.networkError), offline ? findsOneWidget : findsNothing);
            expect(result.done, isTrue);
            expect(result.value, isNull);
            await tester.pumpWidget(const SizedBox.shrink());
          }, () => api);

      await expectFailure(MockClient((_) async => maintenance()), offline: false);
      await expectFailure(MockClient((_) async => throw http.ClientException('offline')), offline: true);
    });

    testWidgets('D11：伺服器未設定本平台的來源時，驗證面板不預設通行密鑰', (tester) async {
      final navKey = GlobalKey<NavigatorState>();
      VerificationService.navigatorKey = navKey;
      final calls = <String>[];

      await http.runWithClient(() async {
        await _pumpHost(tester, navKey);
        await _settle(tester);
        await tester.runAsync(() async {
          VerificationService.requireAdminPassword(navKey.currentContext!);
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await _settle(tester);

        expect(find.byType(IdentityVerificationSheet), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
        expect(find.text(S.verifyWithPasskeyInstead), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => overriding(calls, {'GET /auth/passkeys/status': () => status(android: false)}));
    });

    testWidgets('D6：伺服器拒絕時顯示伺服器訊息，裝置端失敗時顯示原因而非毫無反應', (tester) async {
      final navKey = GlobalKey<NavigatorState>();
      VerificationService.navigatorKey = navKey;
      final calls = <String>[];
      const serverMessage = '此裝置目前無法使用通行密鑰，請改用其他方式';

      Future<void> verifyOnce() async {
        await tester.runAsync(() async {
          VerificationService.requireAdminPassword(navKey.currentContext!);
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await _settle(tester);
        await tester.tap(find.widgetWithText(ElevatedButton, S.verifyWithPasskey));
        await _settle(tester);
      }

      await http.runWithClient(() async {
        await _pumpHost(tester, navKey);
        await _settle(tester);

        await verifyOnce();
        expect(find.text(serverMessage), findsOneWidget);
        expect(find.byType(IdentityVerificationSheet), findsOneWidget);

        Navigator.of(navKey.currentContext!).pop();
        await _settle(tester);
        recording.getError = PasskeyClientException(S.couldNotVerifyWithPasskeyDevice, kind: PasskeyFailure.noCredentials);
        await verifyOnce();
        expect(find.text(S.couldNotVerifyWithPasskeyDevice), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => overriding(calls, {
            'POST /security/verify': () =>
                _json({'success': false, 'code': 'PASSKEY_ORIGIN_NOT_ALLOWED', 'message': serverMessage}, 400),
          }));
    });

    test('D9：只有 PASSKEY_NOT_RECOGNIZED 才要求系統移除通行密鑰', () async {
      for (final code in ['PASSKEY_NOT_RECOGNIZED', 'PASSKEY_VERIFICATION_FAILED', 'PASSKEY_ORIGIN_NOT_ALLOWED', 'PASSKEY_COUNTER_REGRESSED']) {
        final client = _RecordingClient();
        PasskeyService.client = client;
        final calls = <String>[];
        final outcome = await http.runWithClient(
          () => PasskeyService.signIn(immediate: false),
          () => overriding(calls, {
            'POST /auth/passkeys/login': () => _json({'success': false, 'code': code, 'message': '伺服器訊息 $code'}, 400),
          }),
        );

        expect(outcome.code, code);
        expect(outcome.message, '伺服器訊息 $code');
        expect(client.forgets, code == 'PASSKEY_NOT_RECOGNIZED' ? [('savemybook.today', 'cred-1')] : isEmpty, reason: code);
      }
    });

    Map<String, dynamic> item(String id, String? credentialId, {String? authenticator = 'icloud_keychain'}) => {
          'passkey_id': id,
          'credential_id': ?credentialId,
          'device_label': 'iPhone $id',
          'authenticator': authenticator,
          'backed_up': true,
          'created_at': '2026-09-01T08:00:00Z',
          'last_used_at': null,
        };

    Future<void> pumpCard(WidgetTester tester, GlobalKey<NavigatorState> navKey) async {
      VerificationService.navigatorKey = navKey;
      await _pumpHost(tester, navKey, home: const Scaffold(body: SingleChildScrollView(child: PasskeysCard())));
      await _settle(tester);
    }

    Future<void> deleteFirst(WidgetTester tester) async {
      await tester.tap(find.descendant(of: find.byType(PasskeysCard), matching: find.byTooltip(S.moreOptions)).first);
      await _settle(tester);
      await tester.tap(find.text(S.deletePasskey));
      await _settle(tester);
      await tester.tap(find.text(S.actionDelete));
      await _settle(tester);
    }

    testWidgets('D12：伺服器刪除成功後以 credential_id 與 RP ID 通知系統，失敗時不通知', (tester) async {
      final navKey = GlobalKey<NavigatorState>();
      final calls = <String>[];
      var items = [item('PK1', 'aW9zLWNyZWQ'), item('PK2', null)];
      var deleteFails = false;

      await http.runWithClient(() async {
        await pumpCard(tester, navKey);
        await deleteFirst(tester);
        expect(recording.forgets, [('savemybook.today', 'aW9zLWNyZWQ')]);
        expect(find.text(S.passkeyDeleted), findsOneWidget);
        await tester.pump(const Duration(seconds: 3));
        await _settle(tester);

        await deleteFirst(tester);
        expect(recording.forgets, hasLength(1), reason: '舊版伺服器沒有 credential_id 時略過');

        await tester.pumpWidget(const SizedBox.shrink());
        items = [item('PK3', 'YW5kcm9pZC1jcmVk'), item('PK4', 'b3RoZXI')];
        deleteFails = true;
        await pumpCard(tester, navKey);
        await deleteFirst(tester);
        expect(recording.forgets, hasLength(1), reason: '伺服器未刪除時不可通知系統');
        expect(find.text('這是此帳號唯一的登入方式'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => overriding(calls, {
            'GET /users/me/passkeys': () => _json({'success': true, 'data': items}),
            'DELETE /users/me/passkeys/PK1': () {
              items = items.sublist(1);
              return _json({'success': true, 'data': items});
            },
            'DELETE /users/me/passkeys/PK2': () {
              items = [];
              return _json({'success': true, 'data': items});
            },
            'DELETE /users/me/passkeys/PK3': () => deleteFails
                ? _json({'success': false, 'code': 'LAST_SIGN_IN_METHOD', 'message': '這是此帳號唯一的登入方式'}, 400)
                : _json({'success': true, 'data': items}),
            'GET /auth/passkeys/status': () => status(),
          }));
    });

    testWidgets('D19：通行密鑰登入進行中，密碼、社群與註冊入口皆停用', (tester) async {
      ApiService.authToken = null;
      ApiService.currentUser = null;
      SocialSignInFlow.passkeyAvailableOverride = false;
      tester.view.physicalSize = const Size(390 * 3, 1600 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      recording.gate = Completer<void>();
      recording.getError = const PasskeyClientException.cancelled();
      final calls = <String>[];

      bool enabled(Finder finder) {
        final widget = tester.widget(finder);
        return switch (widget) {
          PrimaryButton(:final onPressed) || SecondaryButton(:final onPressed) || TextButton(:final onPressed) => onPressed != null,
          SocialSignInSection(:final disabled) => !disabled,
          _ => throw StateError('unexpected $widget'),
        };
      }

      final password = find.widgetWithText(PrimaryButton, S.sign);
      final register = find.widgetWithText(TextButton, S.noAccountYetSignUp);
      final social = find.byType(SocialSignInSection);

      await http.runWithClient(() async {
        await _pumpHost(tester, GlobalKey<NavigatorState>(), home: const LoginScreen());
        await _settle(tester);
        expect(social, findsOneWidget);
        expect([password, register, social].map(enabled), everyElement(isTrue));

        await tester.tap(find.text(S.signWithPasskey));
        await _settle(tester);
        expect(recording.gets, 1);
        expect([password, register, social].map(enabled), everyElement(isFalse));

        await tester.enterText(find.byType(TextField).first, 'b@example.com');
        await tester.enterText(find.byType(TextField).last, 'Passw0rd123');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await _settle(tester);
        expect(calls, isNot(contains('POST /auth/login')), reason: '密碼欄的鍵盤送出同樣不可繞過');

        recording.gate!.complete();
        await _settle(tester);
        expect([password, register, social].map(enabled), everyElement(isTrue));

        await tester.showKeyboard(find.byType(TextField).last);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await _settle(tester);
        expect(calls, contains('POST /auth/login'));
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => overriding(calls, {
            'POST /auth/login': () => _json({'success': false, 'code': 'INVALID_PASSWORD', 'message': '密碼錯誤'}, 400),
            'GET /auth/providers': () => _json({
                  'success': true,
                  'data': {
                    'social_enabled': true,
                    'providers': [
                      for (final id in ['google', 'apple', 'line', 'discord'])
                        {'id': id, 'enabled': true, 'signup': true, 'configured': true},
                    ],
                  },
                }),
          }));
    });

    testWidgets('D19：流程進行中切換寬窄版面，其他登入入口維持停用，流程結束後恢復', (tester) async {
      ApiService.authToken = null;
      ApiService.currentUser = null;
      SocialSignInFlow.passkeyAvailableOverride = false;
      tester.view.physicalSize = const Size(390 * 3, 1600 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      recording.gate = Completer<void>();
      recording.getError = const PasskeyClientException.cancelled();
      final calls = <String>[];

      bool passwordEnabled() => tester.widget<PrimaryButton>(find.widgetWithText(PrimaryButton, S.sign)).onPressed != null;

      await http.runWithClient(() async {
        await _pumpHost(tester, GlobalKey<NavigatorState>(), home: const LoginScreen());
        await _settle(tester);
        await tester.tap(find.text(S.signWithPasskey));
        await _settle(tester);
        expect(passwordEnabled(), isFalse);

        for (final width in [800.0, 1200.0, 390.0]) {
          tester.view.physicalSize = Size(width * 3, 1600 * 3);
          await _settle(tester);
          expect(passwordEnabled(), isFalse, reason: '寬度 $width');
        }

        recording.gate!.complete();
        await _settle(tester);
        expect(recording.gets, 1);
        expect(passwordEnabled(), isTrue);
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => _fakeApi(calls));
    });

    testWidgets('D19：按鈕在流程進行中被重建時，原流程照常完成並回報登入成功與忙碌狀態', (tester) async {
      ApiService.authToken = null;
      ApiService.currentUser = null;
      recording.gate = Completer<void>();
      final calls = <String>[];
      final busy = <bool>[];
      var signedIn = 0;
      var centered = false;
      late StateSetter relayout;

      await http.runWithClient(() async {
        await _pumpHost(
          tester,
          GlobalKey<NavigatorState>(),
          home: Scaffold(
            body: StatefulBuilder(builder: (context, setState) {
              relayout = setState;
              final button = PasskeySignInButton(initialVisible: true, onSignedIn: () async => signedIn++, onBusyChanged: busy.add);
              return centered ? Center(child: button) : Column(children: [button]);
            }),
          ),
        );
        await _settle(tester);
        await tester.tap(find.text(S.signWithPasskey));
        await _settle(tester);
        expect(busy, [true]);

        relayout(() => centered = true);
        await _settle(tester);
        recording.gate!.complete();
        await _settle(tester);

        expect(signedIn, 1);
        expect(busy, [true, false]);
        expect(ApiService.authToken, 'session-token');
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => _fakeApi(calls));
    });

    testWidgets('D11：伺服器未設定本平台的來源時，帳號安全頁仍可管理既有通行密鑰，只是不能新增', (tester) async {
      final navKey = GlobalKey<NavigatorState>();
      VerificationService.navigatorKey = navKey;
      tester.view.physicalSize = const Size(390 * 3, 2400 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final calls = <String>[];
      var items = [item('PK1', 'aW9zLWNyZWQ'), item('PK2', 'b3RoZXI')];
      var androidReady = false;

      await http.runWithClient(() async {
        await _pumpHost(tester, navKey, home: const SecurityCenterScreen());
        await _settle(tester);

        expect(find.byType(PasskeysCard), findsOneWidget);
        expect(find.text('iPhone PK1'), findsOneWidget);
        expect(find.text(S.addPasskey), findsNothing);
        expect(find.text(S.cannotAddPasskeyDevice), findsOneWidget);

        androidReady = true;
        await deleteFirst(tester);
        expect(calls, contains('DELETE /users/me/passkeys/PK1'));
        expect(recording.forgets, [('savemybook.today', 'aW9zLWNyZWQ')]);
        expect(find.text('iPhone PK1'), findsNothing);
        expect(find.text('iPhone PK2'), findsOneWidget);
        expect(find.text(S.addPasskey), findsOneWidget, reason: '重新載入後依伺服器最新設定顯示');
        expect(find.text(S.cannotAddPasskeyDevice), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => overriding(calls, {
            'GET /auth/passkeys/status': () => status(android: androidReady),
            'GET /users/me/passkeys': () => _json({'success': true, 'data': items}),
            'DELETE /users/me/passkeys/PK1': () {
              items = items.sublist(1);
              return _json({'success': true, 'data': items});
            },
          }));
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('D20：iOS 17.4 以下已有 iCloud 鑰匙圈的通行密鑰時，先說明覆蓋風險再新增', (tester) async {
      final navKey = GlobalKey<NavigatorState>();
      final calls = <String>[];
      VerificationService.rememberSensitive('sensitive-token');
      PasskeyService.iosVersion = () async => (17, 3);
      var items = [item('PK1', 'aW9zLWNyZWQ')];

      await http.runWithClient(() async {
        await pumpCard(tester, navKey);
        await tester.tap(find.text(S.addPasskey));
        await _settle(tester);

        expect(recording.creates, 0);
        expect(find.textContaining(S.iosVersionAddingPasskeyAgainReplaces), findsOneWidget);
        await tester.tap(find.text(S.got));
        await _settle(tester);
        expect(recording.creates, 0);

        await tester.tap(find.text(S.addPasskey));
        await _settle(tester);
        await tester.tap(find.text(S.addAgain));
        await _settle(tester);
        expect(recording.creates, 1);
        expect(find.text('iPhone PK2'), findsOneWidget);

        PasskeyService.iosVersion = () async => (17, 4);
        await tester.tap(find.text(S.addPasskey));
        await _settle(tester);
        expect(recording.creates, 2, reason: 'iOS 17.4 以上交由系統的 excludeCredentials 處理');
        expect(find.textContaining(S.iosVersionAddingPasskeyAgainReplaces), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => overriding(calls, {
            'GET /users/me/passkeys': () => _json({'success': true, 'data': items}),
            'POST /users/me/passkeys/options': () => _json({
                  'success': true,
                  'data': {'options': {'challenge': 'c' * 64, 'rp': {'id': 'savemybook.today'}}},
                }),
            'POST /users/me/passkeys': () {
              items = [...items, item('PK${items.length + 1}', 'bmV3${items.length}')];
              return _json({'success': true, 'data': items}, 201);
            },
          }));
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });
}

class _RecordingClient implements PasskeyClient {
  final forgets = <(String, String)>[];
  Object? getError;
  Completer<void>? gate;
  var creates = 0;
  var gets = 0;

  @override
  Future<bool> isSupported() async => true;

  @override
  Future<Map<String, dynamic>> create(Map<String, dynamic> options) async {
    creates++;
    return {'id': 'bmV3', 'rawId': 'bmV3', 'type': 'public-key', 'response': {'clientDataJSON': 'e30', 'attestationObject': 'o2M'}};
  }

  @override
  Future<Map<String, dynamic>> get(Map<String, dynamic> options, {bool immediate = true}) async {
    gets++;
    await gate?.future;
    final error = getError;
    if (error != null) throw error;
    return Map<String, dynamic>.from(_assertion);
  }

  @override
  Future<void> forget({required String rpId, required String credentialId}) async => forgets.add((rpId, credentialId));
}

class _ScriptedClient implements PasskeyClient {
  final List<Object> _creates;
  int creates = 0;
  final immediates = <bool>[];

  _ScriptedClient(List<Object> creates) : _creates = [...creates];

  @override
  Future<bool> isSupported() async => true;

  @override
  Future<Map<String, dynamic>> create(Map<String, dynamic> options) async {
    creates++;
    final next = _creates.removeAt(0);
    if (next is Map<String, dynamic>) return next;
    throw next;
  }

  @override
  Future<Map<String, dynamic>> get(Map<String, dynamic> options, {bool immediate = true}) async {
    immediates.add(immediate);
    if (immediate) throw const PasskeyClientException('none', kind: PasskeyFailure.noCredentials);
    return Map<String, dynamic>.from(_assertion);
  }

  @override
  Future<void> forget({required String rpId, required String credentialId}) async {}
}
