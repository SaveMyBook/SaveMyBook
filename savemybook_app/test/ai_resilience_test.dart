import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:savemybook_app/features/account/ai_support_screen.dart';
import 'package:savemybook_app/features/chat/ai/ai_book_chat_screen.dart';
import 'package:savemybook_app/features/home/home_screen.dart';
import 'package:savemybook_app/i18n/app_localizations.dart';
import 'package:savemybook_app/i18n/strings.dart';
import 'package:savemybook_app/models/ai.dart';
import 'package:savemybook_app/services/ai_status.dart';
import 'package:savemybook_app/services/api_service.dart';
import 'package:savemybook_app/services/locale_provider.dart';
import 'package:savemybook_app/services/theme_provider.dart';
import 'package:savemybook_app/utils/app_theme.dart';

import 'layout_overflow_test.dart' as lt;

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  group('AI 防止重複與背景推薦：資料模型', () {
    test('訊息識別碼為 32 碼十六進位，每次產生都不同', () {
      final a = newAiClientId();
      expect(RegExp(r'^[0-9a-f]{32}$').hasMatch(a), isTrue);
      expect(newAiClientId(), isNot(a));
    });

    test('讀取對話時解析使用者訊息的識別碼', () {
      expect(AiSupportMessage.fromJson({'message_id': 1, 'role': 'user', 'content': '問', 'client_id': 'abc12345'}).clientId, 'abc12345');
      expect(AiSupportMessage.fromJson({'message_id': 2, 'role': 'assistant', 'content': '答'}).clientId, isNull);
      expect(AiBookChatMessage.fromJson({'message_id': 3, 'role': 'user', 'content': '問', 'client_id': ''}).clientId, isNull);
      expect(AiBookChatMessage.fromJson({'message_id': 4, 'role': 'user', 'content': '問', 'client_id': 'xyz98765'}).clientId, 'xyz98765');
    });

    test('區分逾時與伺服器仍在處理中', () {
      expect(const AiResult<int>.fail('逾時', code: 'NETWORK', timedOut: true).inProgress, isFalse);
      expect(const AiResult<int>.fail('處理中', code: 'AI_REQUEST_IN_PROGRESS').inProgress, isTrue);
      expect(const AiResult<int>.fail('無法連線', code: 'NETWORK').timedOut, isFalse);
      expect(const AiResult<int>.fail('逾時', code: 'NETWORK', timedOut: true).canRetry, isTrue);
    });

    test('推薦回應標示背景是否正在產生', () {
      expect(AiRecommendations.fromJson({'data': const [], 'meta': {'source': 'fallback', 'refreshing': true}}).refreshing, isTrue);
      expect(AiRecommendations.fromJson({'data': const [], 'meta': {'source': 'ai'}}).refreshing, isFalse);
      expect(AiRecommendations.fromJson(const {}).refreshing, isFalse);
    });

    test('後台設定：備援服務商預設不使用，只接受已知的服務商', () {
      final s = AiSettings.fromJson(const {});
      expect(s.features[AiFeatures.support]!.fallbackProvider, isNull);
      expect((s.toJson()['features'] as Map)[AiFeatures.support], {'enabled': true, 'provider': null, 'fallback_provider': null});

      final parsed = AiSettings.fromJson({
        'features': {
          'support': {'fallback_provider': 'gemini'},
          'recommend': {'fallback_provider': 'claude'},
        },
      });
      expect(parsed.features[AiFeatures.support]!.fallbackProvider, AiProviders.gemini);
      expect(parsed.features[AiFeatures.recommend]!.fallbackProvider, isNull);

      final config = parsed.features[AiFeatures.support]!;
      expect(config.copyWith(fallbackProvider: () => null).fallbackProvider, isNull);
      expect(config.copyWith(enabled: false).fallbackProvider, AiProviders.gemini);
      final changed = s.withFeature(AiFeatures.support, config);
      expect(changed.changedSections(s), ['features.${AiFeatures.support}']);
    });
  });

  group('AI 對話逾時後以同一個識別碼重送', () {
    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      themeProvider = await ThemeProvider.init();
      localeProvider = await LocaleProvider.init();
    });

    Widget app(Widget home) => MaterialApp(
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

    Future<void> settle(WidgetTester tester, [int n = 8]) async {
      for (var i = 0; i < n; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    void prepare(WidgetTester tester) {
      SharedPreferences.setMockInitialValues({});
      ApiService.authToken = 't';
      tester.view.physicalSize = const Size(390, 844) * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
    }

    testWidgets('客服：請求逾時後以同一個識別碼重送，取得第一次的完整回應與轉接建議', (tester) async {
      prepare(tester);
      final requests = <String>[];
      final sentIds = <String>[];
      final client = MockClient((req) async {
        final path = req.url.path.replaceFirst('/api', '');
        requests.add('${req.method} $path');
        if (path == '/ai/support/messages') {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          sentIds.add(body['client_id'] as String);
          if (sentIds.length == 1) return Completer<http.Response>().future;
          return _json({
            'success': true,
            'data': {
              'session_id': 3,
              'user_message': {'message_id': 10, 'role': 'user', 'content': body['content'], 'client_id': body['client_id'], 'created_at': lt.now},
              'reply': {'message_id': 11, 'role': 'assistant', 'content': '以下是相關說明：取書步驟。', 'created_at': lt.now},
              'suggest_handoff': true,
              'degraded': true,
            },
          }, 201);
        }
        return _json({'success': true, 'data': null});
      });

      await http.runWithClient(() async {
        await tester.pumpWidget(app(const AiSupportScreen()));
        AiStatus.debugSet(const AiStatusInfo(support: true, consented: true, providersInUse: ['DeepSeek']));
        await settle(tester);

        await tester.enterText(find.byType(TextField), '怎麼取書');
        await tester.testTextInput.receiveAction(TextInputAction.send);
        await settle(tester, 4);
        await tester.pump(const Duration(seconds: 31));
        await settle(tester, 8);

        expect(sentIds.length, 2);
        expect(RegExp(r'^[0-9a-f]{32}$').hasMatch(sentIds[0]), isTrue);
        expect(sentIds[1], sentIds[0]);
        expect(requests.where((r) => r == 'GET /ai/support/session').length, 1);
        expect(find.text('以下是相關說明：取書步驟。'), findsOneWidget);
        expect(find.text(S.ourSupportTeamCanHelpWith), findsOneWidget);
        expect(find.byTooltip(S.resend), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 3));
      }, () => client);
      AiStatus.debugSet(AiStatusInfo.none);
    });

    testWidgets('書籍顧問：請求逾時後以同一個識別碼重送，保留推薦理由與追問建議', (tester) async {
      prepare(tester);
      final sentIds = <String>[];
      final client = MockClient((req) async {
        final path = req.url.path.replaceFirst('/api', '');
        if (path == '/ai/book-chat/messages') {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          sentIds.add(body['client_id'] as String);
          if (sentIds.length == 1) return Completer<http.Response>().future;
          return _json({
            'success': true,
            'data': {
              'session_id': 8,
              'user_message': {'message_id': 1, 'role': 'user', 'content': body['content'], 'client_id': body['client_id'], 'created_at': lt.now},
              'reply': {
                'message_id': 2,
                'role': 'assistant',
                'content': '推薦以下這本。',
                'books': [
                  {'book': lt.book(1), 'reason': '同為東野圭吾的推理作品'},
                ],
                'suggestions': ['有沒有更便宜的'],
                'degraded': false,
                'created_at': lt.now,
              },
            },
          }, 201);
        }
        return _json({'success': true, 'data': null});
      });

      await http.runWithClient(() async {
        await tester.pumpWidget(app(const AiBookChatScreen()));
        AiStatus.debugSet(const AiStatusInfo(bookChat: true, consented: true, providersInUse: ['DeepSeek']));
        await settle(tester);

        await tester.enterText(find.byType(TextField), '推薦推理小說');
        await tester.testTextInput.receiveAction(TextInputAction.send);
        await settle(tester, 4);
        await tester.pump(const Duration(seconds: 31));
        await settle(tester, 8);

        expect(sentIds.length, 2);
        expect(sentIds[1], sentIds[0]);
        expect(find.text('推薦以下這本。'), findsOneWidget);
        expect(find.text('同為東野圭吾的推理作品'), findsOneWidget);
        expect(find.text('有沒有更便宜的'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 3));
      }, () => client);
      AiStatus.debugSet(AiStatusInfo.none);
    });

    testWidgets('書籍顧問：訊息仍在處理中且對話中還沒有這則訊息時可重送，重送沿用同一個識別碼', (tester) async {
      prepare(tester);
      final sentIds = <String>[];
      var inProgress = true;
      final client = MockClient((req) async {
        final path = req.url.path.replaceFirst('/api', '');
        if (path == '/ai/book-chat/messages') {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          sentIds.add(body['client_id'] as String);
          if (inProgress) {
            return _json({'success': false, 'code': 'AI_REQUEST_IN_PROGRESS', 'message': '這則訊息仍在處理中，請稍後再試'}, 409);
          }
          return _json({
            'success': true,
            'data': {
              'session_id': 8,
              'user_message': {'message_id': 1, 'role': 'user', 'content': body['content'], 'client_id': body['client_id'], 'created_at': lt.now},
              'reply': {'message_id': 2, 'role': 'assistant', 'content': '以下是站上的推理小說。', 'books': const [], 'suggestions': const [], 'created_at': lt.now},
            },
          }, 201);
        }
        return _json({'success': true, 'data': null});
      });

      await http.runWithClient(() async {
        await tester.pumpWidget(app(const AiBookChatScreen()));
        AiStatus.debugSet(const AiStatusInfo(bookChat: true, consented: true, providersInUse: ['DeepSeek']));
        await settle(tester);

        await tester.enterText(find.byType(TextField), '推薦推理小說');
        await tester.testTextInput.receiveAction(TextInputAction.send);
        await settle(tester, 12);
        expect(find.text('這則訊息仍在處理中，請稍後再試'), findsOneWidget);
        expect(find.byTooltip(S.resend), findsOneWidget);

        inProgress = false;
        await tester.tap(find.byTooltip(S.resend));
        await settle(tester, 12);
        expect(sentIds.length, 2);
        expect(sentIds[1], sentIds[0]);
        expect(find.text('以下是站上的推理小說。'), findsOneWidget);
        expect(find.byTooltip(S.resend), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 3));
      }, () => client);
      AiStatus.debugSet(AiStatusInfo.none);
    });

    testWidgets('首頁：推薦仍在背景產生時稍後重新讀取，取得結果後不再重複讀取', (tester) async {
      prepare(tester);
      ApiService.currentUser = lt.testUser;
      final base = lt.fakeApi();
      var calls = 0;
      final client = MockClient((req) async {
        if (req.url.path.replaceFirst('/api', '') != '/ai/recommendations') return http.Response.fromStream(await base.send(req));
        calls += 1;
        final first = calls == 1;
        return _json({
          'success': true,
          'data': [
            {'book': lt.book(first ? 7 : 1), 'reason': first ? null : '同為東野圭吾的推理作品'},
          ],
          'groups': [
            {'kind': 'more', 'book_ids': [first ? 7 : 1]},
          ],
          'meta': {'source': first ? 'fallback' : 'ai', 'refreshing': first},
        });
      });

      AiStatus.debugSet(const AiStatusInfo(recommend: true, consented: true, providersInUse: ['DeepSeek']));
      await http.runWithClient(() async {
        await tester.pumpWidget(app(const HomeScreen()));
        await settle(tester, 12);
        expect(calls, 1);
        await tester.pump(const Duration(seconds: 9));
        await settle(tester, 8);
        expect(calls, 2);
        await tester.pump(const Duration(seconds: 30));
        await settle(tester, 4);
        expect(calls, 2);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 3));
      }, () => client);
      AiStatus.debugSet(AiStatusInfo.none);
    });

    Future<({List<String> dismissed, int calls})> dismissDuringRefresh(WidgetTester tester, {required bool undo}) async {
      prepare(tester);
      ApiService.currentUser = lt.testUser;
      final base = lt.fakeApi();
      final dismissed = <String>[];
      var calls = 0;
      Map<String, dynamic> titled(int id, String title) => {...lt.book(id), 'title': title};
      final client = MockClient((req) async {
        final path = req.url.path.replaceFirst('/api', '');
        if (path == '/ai/recommendations/dismissals') {
          dismissed.add(req.body);
          return _json({'success': true, 'data': {}});
        }
        if (path != '/ai/recommendations') return http.Response.fromStream(await base.send(req));
        calls += 1;
        return _json({
          'success': true,
          'data': [
            {'book': titled(7, '白夜行'), 'reason': null},
            {'book': titled(8, '解憂雜貨店'), 'reason': null},
          ],
          'groups': [
            {'kind': 'more', 'book_ids': [7, 8]},
          ],
          'meta': {'source': calls == 1 ? 'fallback' : 'ai', 'refreshing': calls == 1},
        });
      });

      AiStatus.debugSet(const AiStatusInfo(recommend: true, consented: true, providersInUse: ['DeepSeek']));
      await http.runWithClient(() async {
        await tester.pumpWidget(app(const HomeScreen()));
        await settle(tester, 12);
        expect(calls, 1);
        await tester.pump(const Duration(seconds: 5));
        await tester.longPress(find.text('白夜行'));
        await settle(tester, 4);
        await tester.tap(find.text(S.notInterested));
        await settle(tester, 4);
        expect(find.text('白夜行'), findsNothing);

        await tester.pump(const Duration(seconds: 2));
        await settle(tester, 6);
        expect(calls, 2, reason: '復原期限內完成重新讀取');
        expect(find.text('白夜行'), findsNothing, reason: '重新讀取的結果仍含這本書，照樣隱藏');
        expect(find.text('解憂雜貨店'), findsWidgets);
        if (undo) {
          await tester.tap(find.text(S.undo2));
          await settle(tester, 4);
        }
        await tester.pump(const Duration(seconds: 5));
        await settle(tester, 6);
        expect(find.text('白夜行'), undo ? findsWidgets : findsNothing);
        expect(find.text('解憂雜貨店'), findsWidgets, reason: '復原只加回該書，保留重新讀取的結果');

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 3));
      }, () => client);
      AiStatus.debugSet(AiStatusInfo.none);
      return (dismissed: dismissed, calls: calls);
    }

    testWidgets('首頁：不感興趣的書在復原期間重新讀取推薦後仍然隱藏，期滿才送出', (tester) async {
      final result = await dismissDuringRefresh(tester, undo: false);
      expect(result.dismissed.length, 1);
      expect(jsonDecode(result.dismissed.single), {'book_id': 7});
    });

    testWidgets('首頁：重新讀取推薦後按復原，只把該書加回目前的推薦', (tester) async {
      final result = await dismissDuringRefresh(tester, undo: true);
      expect(result.dismissed, isEmpty);
    });
  });
}
