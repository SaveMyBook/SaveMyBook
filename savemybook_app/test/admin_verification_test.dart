import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:savemybook_app/features/security/identity_verification_sheet.dart';
import 'package:savemybook_app/i18n/app_localizations.dart';
import 'package:savemybook_app/i18n/strings.dart';
import 'package:savemybook_app/models/user.dart';
import 'package:savemybook_app/services/api_service.dart';
import 'package:savemybook_app/services/locale_provider.dart';
import 'package:savemybook_app/services/verification_service.dart';
import 'package:savemybook_app/utils/app_theme.dart';
import 'package:savemybook_app/widgets/pin_pad.dart';

const _password = 'Passw0rd123';

/// 模擬伺服器：後台範圍只接受 scope=admin + method=password。
MockClient fakeApi(List<Map<String, dynamic>> verifyCalls, {bool hasPassword = true}) {
  return MockClient((req) async {
    final path = req.url.path.replaceFirst('/api', '');
    Map<String, dynamic> body = {'success': true};

    if (path == '/security') {
      body = {
        'success': true,
        'data': {
          'available': true,
          'has_password': hasPassword,
          'has_payment_pin': true,
          'biometric_pay_enabled': false,
        }
      };
    } else if (path == '/security/verify') {
      final sent = jsonDecode(req.body) as Map<String, dynamic>;
      verifyCalls.add(sent);
      if (sent['scope'] != 'admin' || sent['method'] != 'password') {
        return http.Response(
          jsonEncode({'success': false, 'code': 'VERIFICATION_REQUIRED', 'message': '請輸入您的登入密碼以執行此後台操作'}),
          403,
          headers: {'content-type': 'application/json'},
        );
      }
      if (sent['password'] != _password) {
        return http.Response(
          jsonEncode({'success': false, 'code': 'INVALID_PASSWORD', 'message': '密碼錯誤'}),
          400,
          headers: {'content-type': 'application/json'},
        );
      }
      body = {
        'success': true,
        'data': {'verify_token': 'admin-token', 'scope': 'admin', 'expires_in': 300}
      };
    }
    return http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json'});
  });
}

Future<void> pumpHost(WidgetTester tester, GlobalKey<NavigatorState> navKey) async {
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
    home: const Scaffold(body: SizedBox()),
  ));
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// 測試主體在假時鐘的區域裡，直接 await 服務回傳的 Future 會卡死；
/// 改由回呼記錄結果，再於 runAsync 的空檔讀取。
class _Result {
  String? value;

  void watch(Future<String?> future) => future.then((token) => value = token);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    VerificationService.clearCache();
    ApiService.authToken = 'token';
    ApiService.currentUser = User.fromJson({'user_id': 9, 'nickname': 'A', 'email': 'a@x.com', 'role': 'admin'});
  });

  testWidgets('後台驗證只出現登入密碼，錯誤訊息留在欄位下方', (tester) async {
    final navKey = GlobalKey<NavigatorState>();
    VerificationService.navigatorKey = navKey;
    final calls = <Map<String, dynamic>>[];

    await http.runWithClient(() async {
      await pumpHost(tester, navKey);
      await settle(tester);

      final result = _Result();
      await tester.runAsync(() async {
        result.watch(VerificationService.requireAdminPassword(
          navKey.currentContext!,
          reason: '調整管理員權限前，請先驗證身分',
        ));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await settle(tester);

      // 已設定交易密碼也不該出現 PIN 面板或「改用登入密碼」的切換。
      expect(find.byType(IdentityVerificationSheet), findsOneWidget);
      expect(find.byType(PinEntryPanel), findsNothing);
      expect(find.text(S.usePasswordInstead), findsNothing);
      expect(find.text('調整管理員權限前，請先驗證身分'), findsOneWidget);
      expect(find.text(S.appNeverStoresPasswordUsedOnly), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'wrong-password');
      await tester.tap(find.widgetWithText(ElevatedButton, S.verifyS));
      await settle(tester);

      expect(find.text('密碼錯誤'), findsOneWidget, reason: '錯誤訊息應顯示在欄位下方，面板不關閉');
      expect(find.byType(IdentityVerificationSheet), findsOneWidget);

      await tester.enterText(find.byType(TextField), _password);
      await tester.tap(find.widgetWithText(ElevatedButton, S.verifyS));
      await settle(tester);

      expect(result.value, 'admin-token');
      expect(calls.map((c) => '${c['scope']}/${c['method']}').toSet(), {'admin/password'});
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => fakeApi(calls));
  });

  testWidgets('後台權杖與一般敏感操作的權杖分開存放', (tester) async {
    final navKey = GlobalKey<NavigatorState>();
    VerificationService.navigatorKey = navKey;
    final calls = <Map<String, dynamic>>[];

    await http.runWithClient(() async {
      await pumpHost(tester, navKey);
      await settle(tester);

      final first = _Result();
      await tester.runAsync(() async {
        first.watch(VerificationService.requireAdminPassword(navKey.currentContext!));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await settle(tester);

      await tester.enterText(find.byType(TextField), _password);
      await tester.tap(find.widgetWithText(ElevatedButton, S.verifyS));
      await settle(tester);
      expect(first.value, 'admin-token');

      // 後台驗證過不代表一般敏感操作也驗過。
      expect(VerificationService.cachedSensitiveToken, isNull);

      // 同一範圍在效期內直接沿用快取，不再打一次驗證。
      final again = _Result();
      await tester.runAsync(() async {
        again.watch(VerificationService.requireAdminPassword(navKey.currentContext!));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await settle(tester);
      expect(again.value, 'admin-token');
      expect(calls.length, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => fakeApi(calls));
  });

  testWidgets('沒有登入密碼的管理員會被引導去設定密碼', (tester) async {
    final navKey = GlobalKey<NavigatorState>();
    VerificationService.navigatorKey = navKey;
    final calls = <Map<String, dynamic>>[];

    await http.runWithClient(() async {
      await pumpHost(tester, navKey);
      await settle(tester);

      await tester.runAsync(() async {
        VerificationService.requireAdminPassword(navKey.currentContext!);
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await settle(tester);

      expect(find.byType(TextField), findsNothing, reason: '沒有密碼可輸入時不該顯示密碼欄位');
      expect(find.text(S.setSignPassword), findsOneWidget);
      expect(calls, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => fakeApi(calls, hasPassword: false));
  });
}
