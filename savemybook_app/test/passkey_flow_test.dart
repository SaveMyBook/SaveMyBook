import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:savemybook_app/features/security/identity_verification_sheet.dart';
import 'package:savemybook_app/features/security/passkey_sign_in_button.dart';
import 'package:savemybook_app/features/security/passkeys_card.dart';
import 'package:savemybook_app/i18n/app_localizations.dart';
import 'package:savemybook_app/i18n/strings.dart';
import 'package:savemybook_app/models/user.dart';
import 'package:savemybook_app/services/api_service.dart';
import 'package:savemybook_app/services/locale_provider.dart';
import 'package:savemybook_app/services/passkey_service.dart';
import 'package:savemybook_app/services/verification_service.dart';
import 'package:savemybook_app/utils/app_theme.dart';

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

MockClient _fakeApi(List<String> calls, {bool hasPasskey = true}) => MockClient((req) async {
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
    });

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
