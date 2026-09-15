import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:savemybook_app/i18n/app_localizations.dart';
import 'package:savemybook_app/i18n/strings.dart';
import 'package:savemybook_app/models/user.dart';
import 'package:savemybook_app/features/security/security_center_screen.dart';
import 'package:savemybook_app/services/api_service.dart';
import 'package:savemybook_app/services/locale_provider.dart';
import 'package:savemybook_app/services/verification_service.dart';
import 'package:savemybook_app/utils/app_theme.dart';

void main() {
  testWidgets('帳號安全 → 設定交易密碼（尚未設定）→ 驗證後進入設定畫面', variant: TargetPlatformVariant.only(TargetPlatform.iOS), (tester) async {
    SharedPreferences.setMockInitialValues({});
    ApiService.authToken = 't';
    ApiService.currentUser = User.fromJson({'user_id': 1, 'nickname': 'A', 'email': 'a@x.com', 'role': 'buyer_seller'});
    final navKey = GlobalKey<NavigatorState>();
    VerificationService.navigatorKey = navKey;
    final log = <String>[];

    final client = MockClient((req) async {
      final path = req.url.path.replaceFirst('/api', '');
      log.add('${req.method} $path');
      Object? data;
      if (path == '/security') data = {'available': true, 'has_payment_pin': false, 'biometric_pay_enabled': false};
      if (path == '/security/sessions') data = [];
      if (path == '/security/verify') data = {'verify_token': 'vt', 'expires_in': 300};
      return http.Response(jsonEncode({'success': true, 'data': data}), 200, headers: {'content-type': 'application/json'});
    });

    Future<void> settle([int n = 10]) async {
      for (var i = 0; i < n; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navKey,
        locale: const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
        supportedLocales: LocaleProvider.supported,
        theme: AppTheme.build(Brightness.light),
        localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
        builder: (context, child) {
          S = AppLocalizations.of(context);
          return child!;
        },
        home: const SecurityCenterScreen(),
      ));
      await settle(20);
      await tester.tap(find.text(S.notSetRequiredBeforeCheckout));
      await settle(20);
      expect(find.byType(TextField), findsOneWidget, reason: '應直接在頁面內輸入登入密碼，而不是停在「正在確認身分」');
      await tester.enterText(find.byType(TextField), 'Passw0rd');
      await tester.tap(find.text(S.confirm));
      await settle(20);
      expect(log, contains('POST /security/verify'));
      expect(find.text(S.set6DigitPaymentPin), findsOneWidget, reason: '驗證後應進入設定交易密碼的數字鍵盤');
    }, () => client);
  });
}
