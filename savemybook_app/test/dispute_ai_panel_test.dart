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

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  setUp(() => ApiService.authToken = 'token');

  testWidgets('開啟時顯示最近一次保存的分析，不呼叫模型；評價時帶回這一次分析的編號並標示已選', (tester) async {
    final requests = <String>[];
    final bodies = <Object?>[];
    await http.runWithClient(
      () async {
        await tester.pumpWidget(_host(const DisputeAiPanel(disputeId: 3)));
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.text('買家表示內頁有大量劃記。'), findsOneWidget);
        expect(find.text('重新分析'), findsOneWidget);
        expect(find.text('此分析是否有幫助'), findsOneWidget);
        await tester.tap(find.text('有幫助'));
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      },
      () => MockClient((request) async {
        requests.add('${request.method} ${request.url.path}');
        if (request.method == 'PATCH') {
          bodies.add(jsonDecode(request.body));
          return _json({'success': true, 'data': {}});
        }
        return _json({
          'success': true,
          'data': {
            'analysis_no': 'DA0MS7ZES',
            'summary': '買家表示內頁有大量劃記。',
            'findings': <String>[],
            'suggestion': 'refund',
            'confidence': 0.7,
            'rationale': '',
            'helpful': null,
            'created_at': DateTime.now().toUtc().toIso8601String(),
          },
        });
      }),
    );

    expect(requests, ['GET /api/admin/disputes/3/ai-analysis', 'PATCH /api/admin/disputes/3/ai-analysis']);
    expect(bodies.single, {'analysis_no': 'DA0MS7ZES', 'helpful': true});
    expect(find.byIcon(Icons.thumb_up_alt_rounded), findsOneWidget);
  });

  testWidgets('按下分析後顯示建議、可信度與觀察重點，不會自動裁決', (tester) async {
    final requests = <String>[];
    await http.runWithClient(
      () async {
        await tester.pumpWidget(_host(const DisputeAiPanel(disputeId: 3)));
        for (var i = 0; i < 3; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.text('開始分析'), findsOneWidget);
        await tester.tap(find.text('開始分析'));
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      },
      () => MockClient((request) async {
        requests.add('${request.method} ${request.url.path}');
        if (request.method == 'GET') return _json({'success': true, 'data': null});
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

    expect(requests, ['GET /api/admin/disputes/3/ai-analysis', 'POST /api/admin/disputes/3/ai-analysis']);
    expect(find.textContaining('建議退款'), findsOneWidget);
    expect(find.text('建議退款・可信度：高'), findsOneWidget, reason: '舊版回應的數值可信度換算為三級');
    expect(find.text('佐證照片可見螢光筆劃記'), findsOneWidget);
    expect(find.text('重新分析'), findsOneWidget);
    expect(find.text('AI 分析僅供參考，請依實際證據裁決。'), findsOneWidget);
  });

  testWidgets('顯示協調建議、三級可信度、觀察重點的依據照片與實際送出的張數', (tester) async {
    await http.runWithClient(
      () async {
        await tester.pumpWidget(_host(const DisputeAiPanel(disputeId: 5)));
        for (var i = 0; i < 3; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.tap(find.text('開始分析'));
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      },
      () => MockClient((request) async {
        if (request.method == 'GET') return _json({'success': true, 'data': null});
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'summary': '賣家主張書況與上架照片相符。',
              'findings': ['上架內頁照片可見書況良好', '雙方對書況認知有落差'],
              'finding_details': [
                {'content': '上架內頁照片可見書況良好', 'basis': 'listing_photo', 'photos': [1], 'favors': 'seller'},
                {'content': '佐證照片可見輕微摺痕', 'basis': 'evidence_photo', 'photos': [3], 'favors': 'buyer'},
                {'content': '雙方對書況認知有落差', 'basis': 'complaint', 'photos': [], 'favors': 'neutral'},
              ],
              'suggestion': 'mediate',
              'confidence': 0.6,
              'confidence_level': 'medium',
              'rationale': '落差輕微，適合由雙方協調。',
              'images': {'listing': 2, 'evidence': 1, 'skipped': 1},
              'photos': [
                {'no': 1, 'source': 'listing', 'type': 'inside', 'title': '小王子'},
                {'no': 2, 'source': 'listing', 'type': 'cover', 'title': '夜間飛行'},
                {'no': 3, 'source': 'evidence'},
              ],
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    expect(find.text('建議協調處理・可信度：中'), findsOneWidget);
    expect(find.text('上架內頁照片可見書況良好'), findsOneWidget);
    expect(find.text('有利賣家・照片 1（《小王子》內頁）'), findsOneWidget);
    expect(find.text('有利買家・照片 3（佐證）'), findsOneWidget);
    expect(find.text('雙方對書況認知有落差'), findsOneWidget);
    expect(find.text('AI 參考：上架 2 張、佐證 1 張，另有 1 張未送出'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing, reason: '不再顯示百分比可信度');
  });

  testWidgets('案件內容遭服務商阻擋時顯示說明並停用分析按鈕，不再重送', (tester) async {
    final requests = <String>[];
    await http.runWithClient(
      () async {
        await tester.pumpWidget(_host(const DisputeAiPanel(disputeId: 3)));
        for (var i = 0; i < 3; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.tap(find.text('開始分析'));
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.tap(find.text('開始分析'));
        await tester.pump(const Duration(milliseconds: 300));
      },
      () => MockClient((request) async {
        requests.add('${request.method} ${request.url.path}');
        return http.Response(
          jsonEncode({'success': false, 'code': 'AI_CONTENT_BLOCKED', 'message': '此內容無法由 AI 處理，請調整內容後再試'}),
          422,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    expect(requests, ['GET /api/admin/disputes/3/ai-analysis', 'POST /api/admin/disputes/3/ai-analysis']);
    expect(find.text('此內容無法由 AI 處理，請調整內容後再試'), findsOneWidget);
    final button = tester.widget<TextButton>(find.ancestor(of: find.text('開始分析'), matching: find.byType(TextButton)));
    expect(button.onPressed, isNull);
  });
}
