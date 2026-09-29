import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:savemybook_app/features/admin/ai/ai_quality_card.dart';
import 'package:savemybook_app/features/admin/ai/ai_review_tab.dart';
import 'package:savemybook_app/features/chat/ai/ai_feedback_bar.dart';
import 'package:savemybook_app/i18n/app_localizations.dart';
import 'package:savemybook_app/i18n/strings.dart';
import 'package:savemybook_app/models/admin_models.dart';
import 'package:savemybook_app/models/ai.dart';
import 'package:savemybook_app/models/ai_quality.dart';
import 'package:savemybook_app/models/book.dart';
import 'package:savemybook_app/models/support.dart';
import 'package:savemybook_app/services/api_service.dart';
import 'package:savemybook_app/services/locale_provider.dart';
import 'package:savemybook_app/utils/app_theme.dart';
import 'package:savemybook_app/widgets/buyer/book_strip.dart';

const _now = '2026-09-28T10:30:00.000Z';

Widget _host(Widget child, {Locale locale = const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')}) => MaterialApp(
      locale: locale,
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
      home: Scaffold(body: child),
    );

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json; charset=utf-8'});

Future<void> _pumps(WidgetTester tester, [int n = 6]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 780) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() => ApiService.authToken = 'token');

  group('回饋欄位解析', () {
    test('助理訊息帶加密編號與評價，使用者訊息不帶', () {
      final reply = AiSupportReply.fromJson({
        'user_message': {'message_id': 1, 'content': 'q', 'message_no': 'AS0000001'},
        'reply': {'message_id': 2, 'content': 'a', 'message_no': 'AS0000002', 'feedback': {'rating': 'unhelpful', 'reason': 'inaccurate'}},
      });
      expect(reply.userMessage!.messageNo, isNull);
      expect(reply.reply.messageNo, 'AS0000002');
      expect(reply.reply.feedback!.rating, 'unhelpful');
      expect(reply.reply.feedback!.reason, 'inaccurate');

      final chat = AiBookChatMessage.fromJson({'message_id': 5, 'role': 'assistant', 'content': 'x', 'message_no': 'AC0000005', 'feedback': {'rating': 'bogus'}});
      expect(chat.messageNo, 'AC0000005');
      expect(chat.feedback, isNull);
    });

    test('上架輔助權杖、審核照片與可信度、爭議評價、工單來源與常見問題草稿', () {
      expect(AiListingAssist.fromJson({'suggestion_token': 'abc'}).suggestionToken, 'abc');
      expect(AiListingAssist.fromJson({'suggestion_token': null}).suggestionToken, isNull);

      final review = AiReviewItem.fromJson({
        'book_id': 3,
        'book': {
          'title': '小王子',
          'description': '描述',
          'condition_note': '書角折痕',
          'condition_level': 'good',
          'book_images': [
            {'image_url': '/uploads/a.jpg'},
            {'image_url': '/uploads/b.jpg'},
          ],
        },
        'origin': 'rules',
        'confidence': null,
        'ai_opinion': {'verdict': 'review', 'confidence': 0.64, 'categories': ['source'], 'reasons': []},
      });
      expect(review.imageUrls.length, 2);
      expect(review.imageUrl, review.imageUrls.first);
      expect(review.byRules, isTrue);
      expect(review.confidence, isNull);
      expect(review.aiOpinion!.confidence, 0.64);
      expect(review.conditionNote, '書角折痕');

      final analysis = DisputeAnalysis.fromJson(
          {'analysis_no': 'DA0MS7ZES', 'summary': 's', 'findings': [], 'suggestion': 'refund', 'confidence': 0.5, 'rationale': '', 'helpful': true, 'created_at': _now});
      expect(analysis.helpful, isTrue);
      expect(analysis.withHelpful(false).helpful, isFalse);
      expect(analysis.withHelpful(false).analysisNo, 'DA0MS7ZES');

      expect(SupportTicket.fromJson({'ticket_id': 1, 'from_ai_support': true}).fromAiSupport, isTrue);
      expect(SupportTicket.fromJson({'ticket_id': 1}).fromAiSupport, isFalse);
      final draft = FaqDraft.fromJson({'category': 'trade', 'question': 'q', 'answer': 'a', 'source_ticket_id': 7});
      expect(draft.sourceTicketId, 7);
    });

    test('品質報表沒有樣本的比例維持 null', () {
      final report = AiQualityReport.fromJson({
        'moderation': {'decisions': 2, 'overturned': 1, 'rate': 0.5, 'by_category': [{'category': 'source', 'decisions': 2, 'overturned': 1, 'rate': 0.5}]},
        'support': {'sessions': 0, 'escalated': 0, 'handoff_rate': null, 'rated': 0, 'unhelpful': 0, 'negative_rate': null, 'reasons': {}},
        'recommendations': {'ai': {'impressions': 10, 'clicks': 1, 'ctr': 0.1}, 'not_interested': 2},
        'listing_assist': {'listings': 1, 'fields': [{'field': 'title', 'suggested': 1, 'adopted': 1, 'rate': 1}]},
        'faqs_from_tickets': 3,
      });
      expect(report.moderation.rate, 0.5);
      expect(report.moderationByCategory.single.key, 'source');
      expect(report.handoffRate, isNull);
      expect(report.aiRecommendations.ctr, 0.1);
      expect(report.ruleRecommendations.ctr, isNull);
      expect(report.adoption.single.rate, 1);
      expect(report.faqsFromTickets, 3);
    });
  });

  testWidgets('評價按鈕：有幫助直接送出，再按一次取消；沒有幫助須先選原因', (tester) async {
    final bodies = <Map<String, dynamic>>[];
    final paths = <String>[];
    AiMessageFeedback? latest;
    await http.runWithClient(
      () async {
        await tester.pumpWidget(_host(Center(
          child: AiFeedbackBar(feature: 'book_chat', messageNo: 'AC0000009', initial: null, onChanged: (v) => latest = v),
        )));
        await tester.pump();
        await tester.tap(find.byIcon(Icons.thumb_up_alt_outlined));
        await _pumps(tester, 3);
        expect(latest?.rating, 'helpful');
        expect(find.byIcon(Icons.thumb_up_alt_rounded), findsOneWidget);

        await tester.tap(find.byIcon(Icons.thumb_up_alt_rounded));
        await _pumps(tester, 3);
        expect(latest, isNull);

        await tester.tap(find.byIcon(Icons.thumb_down_alt_outlined));
        await _pumps(tester, 4);
        expect(find.text('請選擇原因'), findsOneWidget);
        expect(find.text('推薦書籍不符合需求'), findsOneWidget);
        expect(find.text('資訊不足'), findsNothing, reason: '資訊不足只用於 AI 客服');
        await tester.tap(find.text('推薦書籍不符合需求'));
        await _pumps(tester, 4);
        expect(latest?.reason, 'books_mismatch');
      },
      () => MockClient((request) async {
        paths.add('${request.method} ${request.url.path}');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        bodies.add(body);
        return _json({'success': true, 'data': {'message_no': 'AC0000009', 'feedback': body['rating'] == null ? null : body}});
      }),
    );
    expect(paths.toSet(), {'PUT /api/ai/book-chat/messages/AC0000009/feedback'});
    expect(bodies, [
      {'rating': 'helpful', 'reason': null},
      {'rating': null, 'reason': null},
      {'rating': 'unhelpful', 'reason': 'books_mismatch'},
    ]);
  });

  testWidgets('評價失敗時恢復原本的選擇並顯示錯誤', (tester) async {
    await http.runWithClient(
      () async {
        await tester.pumpWidget(_host(Center(
          child: AiFeedbackBar(
            feature: 'support',
            messageNo: 'AS0000002',
            initial: const AiMessageFeedback(rating: 'helpful'),
            onChanged: (_) {},
          ),
        )));
        await tester.pump();
        await tester.tap(find.byIcon(Icons.thumb_down_alt_outlined));
        await _pumps(tester, 4);
        await tester.tap(find.text('資訊不足'));
        await _pumps(tester, 4);
        expect(find.text('找不到此訊息'), findsOneWidget);
        expect(find.byIcon(Icons.thumb_up_alt_rounded), findsOneWidget);
        await tester.pump(const Duration(seconds: 5));
      },
      () => MockClient((request) async => _json({'success': false, 'message': '找不到此訊息'}, 404)),
    );
  });

  testWidgets('品質區塊在手機寬度不跑版，沒有樣本時顯示無資料', (tester) async {
    _phone(tester);
    final report = AiQualityReport.fromJson({
      'moderation': {
        'decisions': 123456, 'overturned': 12345, 'rate': 0.1,
        'by_category': [{'category': 'source', 'decisions': 99999, 'overturned': 9999, 'rate': 0.1}],
        'by_origin': [{'origin': 'rules', 'decisions': 0, 'overturned': 0, 'rate': null}],
      },
      'support': {'sessions': 1234567, 'escalated': 123456, 'handoff_rate': 0.1, 'rated': 10, 'unhelpful': 4, 'negative_rate': 0.4, 'reasons': {'inaccurate': 3, 'other': 1}},
      'listing_assist': {'listings': 2, 'fields': [{'field': 'publish_date', 'suggested': 2, 'adopted': 1, 'rate': 0.5}]},
    });
    await tester.pumpWidget(_host(SingleChildScrollView(child: Padding(padding: const EdgeInsets.all(16), child: AiQualityCard(report: report)))));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('管理員推翻比例'), findsOneWidget);
    expect(find.text('即時規則送審'), findsOneWidget);
    expect(find.text('無資料'), findsWidgets);
    expect(find.text('內容不正確 3、其他 1'), findsOneWidget);
    expect(find.text('出版日期'), findsOneWidget);
    expect(find.text('12345/123456'), findsOneWidget);

    await tester.pumpWidget(_host(SingleChildScrollView(child: AiQualityCard(report: report)), locale: const Locale('en')));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Inaccurate information 3, Other 1'), findsOneWidget);
    expect(find.text('12345/123456'), findsOneWidget);
  });

  testWidgets('審核卡可展開全部照片與描述；駁回先選類別，核准可標示送審原因不成立', (tester) async {
    _phone(tester);
    final patches = <Map<String, dynamic>>[];
    Map<String, dynamic> row(int id) => {
          'book_id': id,
          'book': {
            'book_id': id,
            'title': '書 $id',
            'price': 200,
            'description': '附贈講義 PDF 檔',
            'condition_note': '封底有貼紙',
            'condition_level': 'good',
            'book_images': [for (var i = 0; i < 4; i++) {'image_url': '/uploads/$id-$i.jpg'}],
          },
          'verdict': 'review',
          'reasons': ['疑似非正規來源'],
          'categories': ['source'],
          'status': 'pending',
          'origin': 'ai',
          'confidence': 0.64,
          'model': 'gemini',
          'created_at': _now,
        };
    await http.runWithClient(
      () async {
        await tester.pumpWidget(_host(const AiReviewTab()));
        await _pumps(tester);
        expect(find.text('附贈講義 PDF 檔'), findsNothing);

        await tester.tap(find.text('顯示照片與完整內容').first);
        await _pumps(tester, 4);
        expect(tester.takeException(), isNull);
        expect(find.text('附贈講義 PDF 檔'), findsOneWidget);
        expect(find.textContaining('可信度 64%'), findsOneWidget);
        expect(find.textContaining('來源：AI 判定'), findsOneWidget);

        await tester.tap(find.text('核准時標示送審原因不成立'));
        await tester.pump();
        await tester.tap(find.text(S.approve).first);
        await _pumps(tester, 12);
        expect(patches.first, {'decision': 'approve', 'unfounded': true});

        await tester.tap(find.text(S.reject).first);
        await _pumps(tester, 4);
        expect(find.text('拒絕原因類別'), findsOneWidget);
        await tester.tap(find.text(S.offPlatformDealContactInfo));
        await _pumps(tester, 4);
        await tester.enterText(find.byType(TextField).last, '描述留有電話');
        await tester.tap(find.text(S.reject).last);
        await _pumps(tester, 12);
        await tester.pump(const Duration(seconds: 5));
      },
      () => MockClient((request) async {
        if (request.method == 'PATCH') {
          patches.add(jsonDecode(request.body) as Map<String, dynamic>);
          return _json({'success': true, 'data': {}});
        }
        return _json({'success': true, 'data': [row(1), row(2)]});
      }),
    );
    expect(patches[1], {'decision': 'reject', 'note': '描述留有電話', 'category': 'contact'});
  });

  testWidgets('推薦書磚：點擊先通知再開啟詳情，長按交給呼叫端', (tester) async {
    final opened = <int>[];
    final pressed = <int>[];
    final books = [for (var i = 1; i <= 2; i++) Book.fromJson({'book_id': i, 'title': '書 $i', 'price': 100, 'status': 'on_sale'})];
    await tester.pumpWidget(_host(DiscoveryPanel(tabs: [
      DiscoveryTab(
        id: 'picked',
        title: '精選',
        icon: Icons.auto_awesome_rounded,
        books: books,
        onOpen: (b) => opened.add(b.bookId),
        onLongPress: (b) => pressed.add(b.bookId),
      ),
    ])));
    await tester.pump();
    await tester.longPress(find.text('書 2'));
    await tester.pump();
    expect(pressed, [2]);
    await tester.tap(find.text('書 1'));
    await tester.pump();
    expect(opened, [1]);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
