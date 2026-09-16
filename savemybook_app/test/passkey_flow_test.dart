import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:savemybook_app/features/security/identity_verification_sheet.dart';
import 'package:savemybook_app/features/security/passkey_sign_in_button.dart';
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
  Future<Map<String, dynamic>> get(Map<String, dynamic> options) async {
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
}
