import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:savemybook_app/features/account/ai_support_screen.dart';
import 'package:savemybook_app/features/admin/ai/ai_decisions_tab.dart';
import 'package:savemybook_app/features/chat/ai/ai_book_chat_screen.dart';
import 'package:savemybook_app/features/chat/widgets/chat_input_accessories.dart';
import 'package:savemybook_app/i18n/app_localizations.dart';
import 'package:savemybook_app/i18n/strings.dart';
import 'package:savemybook_app/models/ai.dart';
import 'package:savemybook_app/services/ai_status.dart';
import 'package:savemybook_app/services/api_service.dart';
import 'package:savemybook_app/services/locale_provider.dart';
import 'package:savemybook_app/utils/app_theme.dart';

import 'layout_overflow_test.dart' as lt;

Widget _app(Widget home) => MaterialApp(
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
      home: home,
    );

MockClient _api(Map<String, Object? Function()> routes, {List<String>? log}) => MockClient((req) async {
      final path = req.url.path.replaceFirst('/api', '');
      log?.add('${req.method} $path');
      final data = routes['${req.method} $path']?.call();
      return http.Response(jsonEncode({'success': true, 'data': data}), 200, headers: {'content-type': 'application/json; charset=utf-8'});
    });

Future<void> _settle(WidgetTester tester, [int n = 8]) async {
  for (var i = 0; i < n; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void _phone(WidgetTester tester) {
  SharedPreferences.setMockInitialValues({});
  ApiService.authToken = 't';
  tester.view.physicalSize = const Size(390, 844) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 3));
}

Map<String, dynamic> _decisions() => {
      'period': 'month',
      'features': [
        {
          'feature': 'support',
          'total': 200,
          'outcomes': {'ok': 150, 'degraded': 40, 'refused': 10},
          'paths': {'answer': 150, 'passage': 40, 'future_path_code': 3},
          'flags': {'handoff': 50, 'insufficient': 0, 'future_flag': 7},
          'averages': {'docs': 4.5},
        },
        {'feature': 'book_chat', 'total': 0, 'outcomes': {}, 'paths': {}, 'flags': {}, 'averages': {}},
      ],
      'prompt_versions': [
        {'feature': 'support', 'prompt_version': '3f9c2a7b41d8', 'requests': 190, 'errors': 19, 'degraded': 40, 'repaired': 0, 'first_at': lt.now, 'last_at': lt.now},
      ],
      'embedding_by_origin': [
        {'origin': 'index', 'requests': 12, 'cost_usd': 0.0123},
        {'origin': 'book_search', 'requests': 30, 'cost_usd': 0.004},
        {'origin': null, 'requests': 5, 'cost_usd': 0.001},
      ],
      'format_errors': [
        {'feature': 'book_chat', 'provider': 'deepseek', 'requests': 40, 'invalid_output': 3, 'incomplete': 1, 'repaired': 2, 'dropped': 5, 'defaulted': 1},
      ],
    };

void main() {
  group('AI 處理紀錄：資料模型', () {
    test('客服訊息帶轉接建議與降級狀態；舊回應缺欄位時為 false', () {
      final m = AiSupportMessage.fromJson({'message_id': 2, 'role': 'assistant', 'content': '好', 'suggest_handoff': true, 'degraded': true});
      expect(m.suggestHandoff, isTrue);
      expect(m.degraded, isTrue);
      expect(AiSupportMessage.fromJson(const {'role': 'assistant'}).suggestHandoff, isFalse);
      final reply = AiSupportReply.fromJson({
        'reply': {'message_id': 3, 'content': '好', 'suggest_handoff': true},
      });
      expect(reply.suggestHandoff, isTrue, reason: '只有訊息層級的欄位時也要讀到');
    });

    test('書籍顧問訊息帶降級狀態', () {
      expect(AiBookChatMessage.fromJson(const {'role': 'assistant', 'degraded': true}).degraded, isTrue);
      expect(AiBookChatMessage.fromJson(const {}).degraded, isFalse);
    });

    test('處理結果統計：解析各功能的結果、路徑、旗標、平均值、提示詞版本與向量費用歸屬', () {
      final report = AiDecisionReport.fromJson(_decisions());
      final support = report.features.first;
      expect(support.feature, 'support');
      expect(support.total, 200);
      expect(support.outcomes, {'ok': 150, 'degraded': 40, 'refused': 10});
      expect(support.rateOf(support.flags['handoff']!), 0.25);
      expect(support.flags['insufficient'], 0, reason: '旗標為 0 次時仍保留，畫面顯示 0%');
      expect(support.averages['docs'], 4.5);
      expect(report.features[1].outcomes, isEmpty);
      expect(report.promptVersions.single.errorRate, closeTo(0.1, 1e-9));
      expect(report.embeddingByOrigin.map((e) => e.origin), ['index', 'book_search', AiEmbeddingOrigin.unknown]);
      final format = report.formatErrors.single;
      expect([format.feature, format.provider, format.errors, format.repaired, format.dropped, format.defaulted], ['book_chat', 'deepseek', 4, 2, 5, 1]);
      expect(format.errorRate, closeTo(0.1, 1e-9));
      expect(AiDecisionReport.fromJson(const {}).features, isEmpty);
    });
  });

  group('重新開啟 AI 對話', () {
    testWidgets('書籍顧問：還原推薦理由，追問建議只出現在最後一則助理訊息', (tester) async {
      _phone(tester);
      final client = _api({
        'GET /ai/book-chat/session': () => {
              'session_id': 8,
              'messages': [
                {'message_id': 1, 'role': 'user', 'content': '推理小說', 'created_at': lt.now},
                {
                  'message_id': 2,
                  'role': 'assistant',
                  'content': '以下是推理小說。',
                  'books': [
                    {'book': lt.book(1), 'reason': '節奏明快，適合通勤'},
                  ],
                  'suggestions': ['舊的追問建議'],
                  'created_at': lt.now,
                },
                {'message_id': 3, 'role': 'user', 'content': '有沒有更便宜的', 'created_at': lt.now},
                {
                  'message_id': 4,
                  'role': 'assistant',
                  'content': '以下是較便宜的推理小說。',
                  'books': [
                    {'book': lt.book(2), 'reason': '價格較低的同類作品'},
                  ],
                  'suggestions': ['換成日系作家呢'],
                  'created_at': lt.now,
                },
              ],
            },
      });

      await http.runWithClient(() async {
        await tester.pumpWidget(_app(const AiBookChatScreen()));
        AiStatus.debugSet(const AiStatusInfo(bookChat: true, consented: true, providersInUse: ['DeepSeek']));
        await _settle(tester);

        expect(find.text('節奏明快，適合通勤'), findsOneWidget);
        expect(find.text('價格較低的同類作品'), findsOneWidget);
        expect(find.text('換成日系作家呢'), findsOneWidget);
        expect(find.text('舊的追問建議'), findsNothing);

        await _dispose(tester);
      }, () => client);
      AiStatus.debugSet(AiStatusInfo.none);
    });

    testWidgets('AI 客服：最後一則助理訊息建議轉接時還原轉接提示，較早的建議不顯示', (tester) async {
      _phone(tester);
      Map<String, dynamic> assistant(int id, bool handoff) =>
          {'message_id': id, 'role': 'assistant', 'content': '回覆 $id', 'suggest_handoff': handoff, 'degraded': false, 'created_at': lt.now};
      var messages = [
        {'message_id': 1, 'role': 'user', 'content': '錢包餘額不對', 'created_at': lt.now},
        assistant(2, true),
        {'message_id': 3, 'role': 'user', 'content': '那要怎麼取書', 'created_at': lt.now},
        assistant(4, false),
      ];
      final client = _api({'GET /ai/support/session': () => {'session_id': 1, 'status': 'open', 'messages': messages}});

      await http.runWithClient(() async {
        await tester.pumpWidget(_app(const AiSupportScreen()));
        AiStatus.debugSet(const AiStatusInfo(support: true, consented: true, providersInUse: ['DeepSeek']));
        await _settle(tester);
        expect(find.text('回覆 4'), findsOneWidget);
        expect(find.text(S.ourSupportTeamCanHelpWith), findsNothing);
        await _dispose(tester);

        messages = messages.take(2).toList();
        await tester.pumpWidget(_app(const AiSupportScreen()));
        await _settle(tester);
        expect(find.text('回覆 2'), findsOneWidget);
        expect(find.text(S.ourSupportTeamCanHelpWith), findsOneWidget);
        await _dispose(tester);
      }, () => client);
      AiStatus.debugSet(AiStatusInfo.none);
    });
  });

  group('AI 客服追問建議', () {
    test('助理訊息解析追問建議；舊回應沒有此欄位時為空', () {
      final m = AiSupportMessage.fromJson({'message_id': 2, 'role': 'assistant', 'content': '好', 'suggestions': ['取書期限是幾天？', '  ']});
      expect(m.suggestions, ['取書期限是幾天？']);
      expect(AiSupportMessage.fromJson(const {'role': 'assistant'}).suggestions, isEmpty);
    });

    testWidgets('以建議列顯示最後一則回覆的追問建議，點選後送出並清除', (tester) async {
      _phone(tester);
      final sent = <String>[];
      final client = MockClient((req) async {
        final path = req.url.path.replaceFirst('/api', '');
        Object? data;
        if (path == '/ai/support/session') {
          data = {
            'session_id': 1,
            'status': 'open',
            'messages': [
              {'message_id': 1, 'role': 'user', 'content': '怎麼取書', 'created_at': lt.now},
              {'message_id': 2, 'role': 'assistant', 'content': '請至書櫃掃描 QR Code 取書。', 'suggestions': ['取書期限是幾天？'], 'created_at': lt.now},
            ],
          };
        } else if (path == '/ai/support/messages') {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          sent.add(body['content'] as String);
          data = {
            'session_id': 1,
            'user_message': {'message_id': 3, 'role': 'user', 'content': body['content'], 'client_id': body['client_id'], 'created_at': lt.now},
            'reply': {'message_id': 4, 'role': 'assistant', 'content': '取書期限為 3 天。', 'suggestions': const [], 'created_at': lt.now},
            'suggest_handoff': false,
            'degraded': false,
          };
        }
        return http.Response(jsonEncode({'success': true, 'data': data}), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      });

      await http.runWithClient(() async {
        await tester.pumpWidget(_app(const AiSupportScreen()));
        AiStatus.debugSet(const AiStatusInfo(support: true, consented: true, providersInUse: ['DeepSeek']));
        await _settle(tester);

        final chip = find.widgetWithText(ChatSuggestionChip, '取書期限是幾天？');
        expect(chip, findsOneWidget);
        await tester.tap(chip);
        await _settle(tester);

        expect(sent, ['取書期限是幾天？']);
        expect(find.text('取書期限為 3 天。'), findsOneWidget);
        expect(find.byType(ChatSuggestionChip), findsNothing);
        await _dispose(tester);
      }, () => client);
      AiStatus.debugSet(AiStatusInfo.none);
    });
  });

  group('後台處理結果統計', () {
    testWidgets('顯示各功能的處理結果、路徑與指標，未知的代碼不顯示', (tester) async {
      _phone(tester);
      final log = <String>[];
      final client = _api({'GET /admin/ai/decisions': _decisions}, log: log);

      await http.runWithClient(() async {
        await tester.pumpWidget(_app(const Scaffold(body: AiDecisionsTab())));
        await _settle(tester);

        expect(log, contains('GET /admin/ai/decisions'));
        expect(find.text(S.modelAnswer), findsOneWidget);
        expect(find.text(S.fellBackReferencePassage), findsOneWidget);
        expect(find.text(S.handoffSuggested), findsOneWidget);
        expect(find.text('25%'), findsOneWidget);
        expect(find.text(S.insufficientGrounding), findsOneWidget);
        expect(find.text('0%'), findsOneWidget);
        expect(find.textContaining('future_'), findsNothing);
        expect(find.text(S.noDataYet), findsOneWidget, reason: '沒有紀錄的功能顯示尚無資料');

        await tester.scrollUntilVisible(find.text(S.sourceNotRecorded), 200);
        expect(find.textContaining('3f9c2a7b41d8'), findsOneWidget);
        expect(find.text('${S.aiBookAdvisor}・DeepSeek'), findsOneWidget);
        expect(find.textContaining('${S.invalidResponseFormat} 3'), findsOneWidget);
        expect(find.textContaining(S.someItemsMalformedP0('5')), findsOneWidget);
        expect(find.textContaining(S.fieldsDefaultedP0('1')), findsOneWidget);
        expect(find.text('10%'), findsOneWidget);
        expect(find.text(S.indexUpdates), findsOneWidget);
        expect(find.text(S.bookSearch), findsOneWidget);

        await _dispose(tester);
      }, () => client);
    });
  });
}
