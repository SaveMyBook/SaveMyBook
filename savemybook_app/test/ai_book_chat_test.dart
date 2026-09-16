import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:savemybook_app/features/chat/ai/ai_book_chat_screen.dart';
import 'package:savemybook_app/features/chat/chat_list_screen.dart';
import 'package:savemybook_app/i18n/app_localizations.dart';
import 'package:savemybook_app/i18n/strings.dart';
import 'package:savemybook_app/models/ai.dart';
import 'package:savemybook_app/services/ai_status.dart';
import 'package:savemybook_app/services/api_service.dart';
import 'package:savemybook_app/services/locale_provider.dart';
import 'package:savemybook_app/utils/app_theme.dart';

import 'layout_overflow_test.dart' as lt;

void main() {
  group('AI 書籍顧問資料模型', () {
    test('回覆帶入書卡、推薦理由與追問建議', () {
      final reply = AiBookChatReply.fromJson({
        'session_id': 8,
        'user_message': {'message_id': 1, 'content': '想找推理小說', 'created_at': lt.now},
        'reply': {
          'message_id': 2,
          'content': '以下是適合通勤的推理小說。',
          'books': [
            {'book': lt.book(1), 'reason': '節奏明快，適合通勤'},
            {'book': lt.book(2), 'reason': '   '},
            {'reason': '沒有書就不算一張卡'},
          ],
          'suggestions': ['換成日系作家呢', '', '有沒有更便宜的'],
          'created_at': lt.now,
        },
      });
      expect(reply.sessionId, 8);
      expect(reply.userMessage!.isUser, isTrue);
      expect(reply.reply.isUser, isFalse);
      expect(reply.reply.books.length, 2);
      expect(reply.reply.books.first.reason, '節奏明快，適合通勤');
      expect(reply.reply.books[1].reason, isNull);
      expect(reply.reply.suggestions, ['換成日系作家呢', '有沒有更便宜的']);
    });

    test('對話內容為空時不會丟出例外', () {
      final session = AiBookChatSession.fromJson(const {});
      expect(session.sessionId, 0);
      expect(session.messages, isEmpty);
      expect(AiBookChatMessage.fromJson(const {}).books, isEmpty);
    });

    test('狀態新增書籍顧問旗標', () {
      final status = AiStatusInfo.fromJson({'book_chat': true});
      expect(status.bookChat, isTrue);
      expect(status.any, isTrue);
      expect(status.copyWith(consented: true).bookChat, isTrue);
      expect(AiStatusInfo.fromJson(const {}).bookChat, isFalse);
    });

    test('後台設定包含書籍顧問開關與每日上限', () {
      final s = AiSettings.fromJson(const {});
      expect(s.features[AiFeatures.bookChat]!.enabled, isTrue);
      expect(s.dailyPerUser[AiFeatures.bookChat], 30);
      expect((s.toJson()['features'] as Map)[AiFeatures.bookChat], {'enabled': true, 'provider': null});
      expect(((s.toJson()['limits'] as Map)['daily_per_user'] as Map)[AiFeatures.bookChat], 30);
    });
  });

  group('上架輔助新增欄位', () {
    test('出版日期精度與簡介來源會被解析', () {
      final r = AiListingAssist.fromJson({
        'fields': {'title': '書名', 'publish_date': '2003-08', 'publish_date_precision': 'month', 'page_count': 384, 'language': 'zh-Hant'},
        'description_source': 'mixed',
      });
      expect(r.publishDatePrecision, 'month');
      expect(r.publishDateIsApproximate, isTrue);
      expect(r.descriptionSource, 'mixed');
      expect(r.fields['page_count'], '384');
      expect(r.fields['language'], 'zh-Hant');
    });

    test('精度為日或未提供時不標示', () {
      expect(AiListingAssist.fromJson({'fields': {'publish_date_precision': 'day'}}).publishDateIsApproximate, isFalse);
      expect(AiListingAssist.fromJson(const {}).publishDateIsApproximate, isFalse);
      expect(AiListingAssist.fromJson(const {}).descriptionSource, '');
    });

    test('空值欄位不會進入 fields', () {
      final r = AiListingAssist.fromJson({
        'fields': {'title': '書名', 'subtitle': '', 'page_count': null, 'language': '  '},
      });
      expect(r.fields.keys, ['title']);
    });
  });

  group('書籍顧問畫面', () {
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

    ({MockClient client, List<String> requests}) chatApi() {
      final requests = <String>[];
      final client = MockClient((req) async {
        final path = req.url.path.replaceFirst('/api', '');
        requests.add('${req.method} $path');
        Object? data;
        if (path == '/ai/book-chat/session') data = null;
        if (path == '/ai/book-chat/messages') {
          data = {
            'session_id': 8,
            'user_message': {'message_id': 1, 'role': 'user', 'content': jsonDecode(req.body)['content'], 'created_at': lt.now},
            'reply': {
              'message_id': 2,
              'role': 'assistant',
              'content': '以下是適合通勤閱讀的推理小說。',
              'books': [
                {'book': lt.book(1), 'reason': '節奏明快，適合通勤'},
              ],
              'suggestions': const ['換成日系作家呢'],
              'created_at': lt.now,
            },
          };
        }
        return http.Response(jsonEncode({'success': true, 'data': data}), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      });
      return (client: client, requests: requests);
    }

    Future<void> settle(WidgetTester tester, [int n = 8]) async {
      for (var i = 0; i < n; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('點擊起始提示會送出訊息並呈現書卡與追問建議', (tester) async {
      SharedPreferences.setMockInitialValues({});
      ApiService.authToken = 't';
      tester.view.physicalSize = const Size(390, 844) * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final api = chatApi();

      await http.runWithClient(() async {
        await tester.pumpWidget(app(const AiBookChatScreen()));
        AiStatus.debugSet(const AiStatusInfo(bookChat: true, consented: true, providersInUse: ['DeepSeek']));
        await settle(tester);

        expect(find.text('想找適合通勤看的推理小說'), findsOneWidget);
        await tester.tap(find.text('想找適合通勤看的推理小說'));
        await settle(tester, 12);

        expect(api.requests.where((r) => r == 'POST /ai/book-chat/messages').length, 1);
        expect(find.text('以下是適合通勤閱讀的推理小說。'), findsOneWidget);
        expect(find.byType(AiBookChatCard), findsOneWidget);
        expect(find.text('節奏明快，適合通勤'), findsOneWidget);
        expect(find.text('換成日系作家呢'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 3));
      }, () => api.client);
      AiStatus.debugSet(AiStatusInfo.none);
    });

    testWidgets('未同意 AI 資料處理時先跳同意畫面，不送出訊息', (tester) async {
      SharedPreferences.setMockInitialValues({});
      ApiService.authToken = 't';
      tester.view.physicalSize = const Size(390, 844) * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final api = chatApi();

      await http.runWithClient(() async {
        await tester.pumpWidget(app(const AiBookChatScreen()));
        AiStatus.debugSet(const AiStatusInfo(bookChat: true, providersInUse: ['DeepSeek']));
        await settle(tester);

        await tester.tap(find.text('想找適合通勤看的推理小說'));
        await settle(tester);
        expect(api.requests.where((r) => r.contains('/ai/book-chat/messages')), isEmpty);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 3));
      }, () => api.client);
      AiStatus.debugSet(AiStatusInfo.none);
    });

    testWidgets('聊天室列表僅在功能開啟時顯示書籍顧問', (tester) async {
      SharedPreferences.setMockInitialValues({});
      ApiService.authToken = 't';
      ApiService.currentUser = lt.testUser;
      tester.view.physicalSize = const Size(390, 844) * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await http.runWithClient(() async {
        await tester.pumpWidget(app(const ChatListScreen()));
        AiStatus.debugSet(AiStatusInfo.none);
        await settle(tester);
        expect(find.byKey(const ValueKey('ai_book_advisor')), findsNothing);

        AiStatus.debugSet(const AiStatusInfo(bookChat: true, consented: true));
        await settle(tester);
        expect(find.byKey(const ValueKey('ai_book_advisor')), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 3));
      }, () => lt.fakeApi());
      AiStatus.debugSet(AiStatusInfo.none);
    });
  });
}
