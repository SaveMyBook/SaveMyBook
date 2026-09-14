import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:savemybook_app/i18n/app_localizations.dart';
import 'package:savemybook_app/i18n/strings.dart';
import 'package:savemybook_app/models/security.dart';
import 'package:savemybook_app/models/user.dart';
import 'package:savemybook_app/services/api_service.dart';
import 'package:savemybook_app/services/locale_provider.dart';
import 'package:savemybook_app/services/verification_service.dart';
import 'package:savemybook_app/utils/app_theme.dart';

void main() {
  testWidgets('付款時尚未設定交易密碼 → 立即設定 → 不會卡在確認身分', (tester) async {
    SharedPreferences.setMockInitialValues({});
    ApiService.authToken = 't';
    ApiService.currentUser = User.fromJson({'user_id': 1, 'nickname': 'A', 'email': 'a@x.com', 'role': 'buyer_seller'});
    final navKey = GlobalKey<NavigatorState>();
    VerificationService.navigatorKey = navKey;

    final client = MockClient((req) async {
      final path = req.url.path.replaceFirst('/api', '');
      Object? data;
      if (path == '/security') data = {'available': true, 'has_payment_pin': false, 'biometric_pay_enabled': false};
      return http.Response(jsonEncode({'success': true, 'data': data}), 200, headers: {'content-type': 'application/json'});
    });

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
        home: const Scaffold(body: SizedBox()),
      ));
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
        await tester.pump(const Duration(milliseconds: 100));
      }

      late Future<String?> pending;
      await tester.runAsync(() async {
        pending = VerificationService.handle(const VerificationRequest(scope: 'payment', methods: ['pin', 'biometric'], message: ''));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      Future<void> settle() async {
        for (var i = 0; i < 10; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
          await tester.pump(const Duration(milliseconds: 100));
        }
      }
      await settle();
      expect(find.text(S.setUpNow), findsOneWidget);
      await tester.tap(find.text(S.setUpNow));
      await settle();
      await settle();
      expect(find.byType(TextField), findsOneWidget, reason: '應該跳出輸入登入密碼的對話框，而不是停在「正在確認身分」');
      expect(pending, isA<Future<String?>>());
    }, () => client);
  });
}
