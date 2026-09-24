import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:savemybook_app/features/admin/dispute_ai_panel.dart';
import 'package:savemybook_app/i18n/app_localizations.dart';
import 'package:savemybook_app/i18n/strings.dart';
import 'package:savemybook_app/services/api_service.dart';
import 'package:savemybook_app/services/locale_provider.dart';
import 'package:savemybook_app/utils/app_theme.dart';

Widget _host(Widget child) => MaterialApp(
  locale: const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  supportedLocales: LocaleProvider.supported,
  theme: AppTheme.build(Brightness.light),
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  builder: (context, inner) {
    S = AppLocalizations.of(context);
    return inner ?? const SizedBox.shrink();
  },
  home: Scaffold(
    body: Padding(padding: const EdgeInsets.all(16), child: child),
  ),
);

void main() {
  setUp(() => ApiService.authToken = 'token');

  testWidgets('按下分析後顯示建議、信心與觀察重點，不會自動裁決', (tester) async {
    final requests = <String>[];
    await http.runWithClient(
      () async {
        await tester.pumpWidget(_host(const DisputeAiPanel(disputeId: 3)));
        await tester.pump();
        expect(find.text('開始分析'), findsOneWidget);
        await tester.tap(find.text('開始分析'));
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      },
      () => MockClient((request) async {
        requests.add('${request.method} ${request.url.path}');
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'summary': '買家表示內頁有大量劃記。',
              'findings': ['佐證照片可見螢光筆劃記'],
              'suggestion': 'refund',
              'confidence': 0.78,
              'rationale': '與近全新的標示不符。',
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    expect(requests, ['POST /api/admin/disputes/3/ai-analysis']);
    expect(find.textContaining('建議退款'), findsOneWidget);
    expect(find.textContaining('78%'), findsOneWidget);
    expect(find.text('佐證照片可見螢光筆劃記'), findsOneWidget);
    expect(find.text('重新分析'), findsOneWidget);
    expect(find.text('AI 分析僅供參考，請依實際證據裁決。'), findsOneWidget);
  });
}
