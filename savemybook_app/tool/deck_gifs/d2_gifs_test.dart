// 複評簡報 GIF（子任務 D2）：AI 推薦、AI 書籍顧問、AI 客服、AI 爭議分析四段操作，主線為雪喵上架的《HTML & CSS》（book 150）。
// 執行：tool/deck_gifs/d2_run.sh（設定時區讓畫面時間與狀態列的 11:22 一致，再以 d2_build.py 合成 GIF）。

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:savemybook_app/features/account/ai_support_screen.dart';
import 'package:savemybook_app/features/admin/admin_dispute_screen.dart';
import 'package:savemybook_app/features/chat/ai/ai_book_chat_screen.dart';
import 'package:savemybook_app/features/chat/chat_list_screen.dart';
import 'package:savemybook_app/features/home/home_screen.dart';
import 'package:savemybook_app/i18n/strings.dart';
import 'package:savemybook_app/models/book.dart';
import 'package:savemybook_app/models/user.dart';
import 'package:savemybook_app/services/ai_status.dart';
import 'package:savemybook_app/services/recently_viewed.dart';
import 'package:savemybook_app/widgets/buyer/book_strip.dart';

import '../manual_shots/manual_api.dart';
import '../manual_shots/manual_host.dart';
import 'd2_rec.dart';

final _ios = TargetPlatformVariant.only(TargetPlatform.iOS);

const _bookId = 150;
const _sellerId = 21;
const _cabinetId = 2; // 國立臺北商業大學
const _vueId = 78;
const _orderId = 512;
const _orderNo = 'SMB20261007183412358016';
const _disputeId = 61;
const _evidenceUrl = '/uploads/disputes/1791399125530-4f1c9a7e2b6d8053.jpg';

String get _title => bookJson(_bookId)['title'] as String;

Map<String, dynamic> _book(int id) => id == _bookId
    ? bookJson(_bookId, extra: {'cabinet_id': _cabinetId, 'smart_cabinets': cabinetJson(_cabinetId), 'in_cabinet': true})
    : bookJson(id);

String _hm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String _iso(DateTime d) => d.toUtc().toIso8601String();

void _detailRoutes() {
  ManualApi.on('GET', '/books/$_bookId', (_) => _book(_bookId));
  ManualApi.on('GET', '/books/$_bookId/similar', (_) => [for (final id in [_vueId, 119, 125, 96, 127, 82]) bookJson(id)]);
  ManualApi.on('GET', '/favorites/ids', (_) => <int>[]);
  ManualApi.on('GET', '/cart/book-ids', (_) => <int>[]);
  ManualApi.on('GET', '/wallet', (_) => {'balance': 1280, 'frozen_amount': 0, 'total_income': 0, 'total_expense': 0, 'pending_income': 0});
}

/// 指定的 API 延遲回應（以測試的假時間計算），模擬 AI 產生回覆所需的時間。
Future<void> _withDelays(Map<String, Duration> delays, Future<void> Function() body) {
  final base = ManualApi.client();
  return http.runWithClient(
    body,
    () => MockClient((request) async {
      final delay = delays['${request.method} ${request.url.path.replaceFirst('/api', '')}'];
      if (delay != null) await Future<void>.delayed(delay);
      final copy = http.Request(request.method, request.url)
        ..headers.addAll(request.headers)
        ..bodyBytes = request.bodyBytes;
      return http.Response.fromStream(await base.send(copy));
    }),
  );
}

Future<void> _ready(WidgetTester tester) async {
  await settleReal(tester, const Duration(seconds: 2));
  await waitForImages(tester);
  await settleReal(tester, const Duration(seconds: 1));
}

void main() {
  setUpAll(setUpManual);

  // 1. 首頁「為您推薦」→ 捲動書架 → 點《HTML & CSS》看商品詳情
  testWidgets('ai_recommend', variant: _ios, (tester) async {
    Map<String, dynamic> item(int id, String reason) => {'book': _book(id), 'reason': reason};
    final picks = [
      item(_vueId, '以 Vue 實作介面，延伸 UX 設計到前端開發'),
      item(125, '延伸 AI 工具應用，打造自動化工作流程'),
      item(_bookId, '從 UX 設計延伸到網頁版面與樣式實作'),
      item(96, '深入 AI 背後的自然語言處理技術'),
      item(127, '屬於您常看的「專業資訊」分類'),
      item(82, '屬於您常看的「專業資訊」分類'),
      item(129, '屬於您常看的「專業資訊」分類'),
    ];
    await shoot(
      tester,
      folder: 'd2',
      routes: () {
        ManualApi.on('GET', '/ai/recommendations', (_) => {
          'success': true,
          'message': 'OK',
          'data': picks,
          'groups': [
            {'kind': 'book', 'relation': 'favorite', 'book_id': 119, 'title': 'AI for UX', 'book_ids': [_vueId, 125, _bookId, 96]},
            {'kind': 'category', 'category': '專業資訊', 'book_ids': [127, 82, 129]},
          ],
          'meta': {'source': 'ai', 'refreshing': false},
        });
        ManualApi.on('GET', '/books/briefs', (r) => [for (final id in r.query['ids']!.split(',')) bookJson(int.parse(id))]);
        _detailRoutes();
        RecentlyViewed.restore([for (final id in [119, 145]) Book.fromJson(bookJson(id))]);
      },
      home: HomeScreen.new,
      act: (tester, snap) async {
        await _ready(tester);
        final rec = GifRecorder(tester, 'ai_recommend');
        await rec.play(const Duration(milliseconds: 1400));

        final strip = find.descendant(of: find.byType(BookStrip).first, matching: find.byType(Scrollable)).first;
        final stripRect = tester.getRect(strip);
        await rec.scroll(tester.state<ScrollableState>(strip).position, 150,
            finger: Offset(300, stripRect.top + 70), duration: const Duration(milliseconds: 800));
        await rec.play(const Duration(milliseconds: 500));

        final tile = find.descendant(of: find.byType(BookStrip).first, matching: find.text(_title));
        await rec.tap(tile, shift: const Offset(0, -80));
        await rec.play(const Duration(milliseconds: 900));
        await waitForImages(tester);
        await rec.play(const Duration(milliseconds: 800));

        final pages = find.descendant(of: find.byType(PageView).first, matching: find.byType(Scrollable)).first;
        await rec.scroll(tester.state<ScrollableState>(pages).position, logicalSize.width,
            finger: const Offset(320, 300), duration: const Duration(milliseconds: 480));
        await rec.play(const Duration(milliseconds: 800));

        final main = tester.state<ScrollableState>(find.ancestor(of: find.byType(PageView).first, matching: find.byType(Scrollable)).first);
        final card = tester.getRect(find.text(cabinetJson(_cabinetId)['cabinet_name'] as String).first);
        final delta = (card.top - 330).clamp(0.0, main.position.maxScrollExtent - main.position.pixels);
        await rec.scroll(main.position, delta, finger: const Offset(210, 720), duration: const Duration(milliseconds: 880));
        await rec.play(const Duration(milliseconds: 1800));
        rec.save();
      },
    );
  });

  // 2. 聊天頁開啟 AI 書籍顧問 → 輸入需求 → AI 推薦站內書籍 → 點書卡看商品詳情
  testWidgets('ai_advisor', variant: _ios, (tester) async {
    final now = DateTime.now();
    Map<String, dynamic> room(int id, int partner, int sender, String text, DateTime at, {int unread = 0}) => {
      'room_id': id,
      'type': 'direct',
      'title': null,
      'avatar_url': null,
      'partner': {'user_id': partner, 'nickname': realUsers[partner]!.nickname, 'avatar_url': realUsers[partner]!.avatar, 'alias': null},
      'member_count': 2,
      'last_message': {
        'sender_id': sender,
        'content': text,
        'message_type': 'text',
        'kind': 'text',
        'body': text,
        'is_read': sender == meId || unread == 0,
        'created_at': _iso(at),
        'users': {'user_id': sender, 'nickname': realUsers[sender]!.nickname, 'avatar_url': realUsers[sender]!.avatar},
        'mentions': <Object>[],
      },
      'unread_count': unread,
      'muted': false,
      'blocked': false,
      'pinned': false,
      'pinned_at': null,
      'updated_at': _iso(at),
    };
    final replyAt = _iso(now);
    await shoot(
      tester,
      folder: 'd2',
      routes: () {
        ManualApi.on('GET', '/chat/rooms', (_) => [
          room(3, 7, 7, '可以的，書況與照片相同，明天會存入書櫃。', now.subtract(const Duration(minutes: 12)), unread: 1),
          room(2, 11, meId, '好的，謝謝您', now.subtract(const Duration(days: 1, hours: 2))),
          room(1, 16, 16, '已存入北商大臺北校區的書櫃，再麻煩取書。', now.subtract(const Duration(days: 2, hours: 5))),
        ]);
        ManualApi.on('GET', '/ai/book-chat/session', (_) => {'session_id': 0, 'messages': <Object>[]});
        ManualApi.on('POST', '/ai/book-chat/messages', (r) => {
          'session_id': 31,
          'user_message': {'message_id': 61, 'role': 'user', 'content': '想學網頁設計，預算 300 以內', 'created_at': replyAt},
          'reply': {
            'message_id': 62,
            'role': 'assistant',
            'content': '若您想從零開始學習網頁設計，建議先閱讀《$_title》，書中以簡短範例循序介紹網頁結構與樣式設計，適合初學者建立基礎。'
                '熟悉基礎後，可再搭配《${bookJson(_vueId)['title']}》練習互動式前端開發。兩本書皆在您的預算內。',
            'books': [
              {'book': _book(_bookId), 'reason': '以簡短範例循序學習網頁結構與樣式'},
              {'book': _book(_vueId), 'reason': '銜接前端框架，練習互動式網頁開發'},
            ],
            'suggestions': ['網頁版面與配色設計的書', '適合初學者的 JavaScript 書'],
            'message_no': 'AC7Q2M9KD',
            'created_at': replyAt,
          },
        });
        _detailRoutes();
      },
      home: ChatListScreen.new,
      act: (tester, snap) async {
        await _withDelays({'POST /ai/book-chat/messages': const Duration(milliseconds: 1500)}, () async {
          unawaited(AiStatus.refresh(force: true));
          await _ready(tester);
          final rec = GifRecorder(tester, 'ai_advisor');
          await rec.play(const Duration(milliseconds: 1000));

          await rec.tap(find.text(S.aiBookAdvisor).first);
          await rec.play(const Duration(milliseconds: 1100));

          final field = find.descendant(of: find.byType(AiBookChatScreen), matching: find.byType(TextField));
          await rec.tap(field);
          await rec.keyboard(true, candidates: ['我', '你', '想', '請問', '有', '推薦', '好']);
          await rec.type(
            field,
            ['想學', '網頁', '設計', '，', '預算', ' ', '3', '0', '0', ' ', '以內'],
            candidates: [
              ['網頁', '程式', '英文', '做菜', '的', '畫畫'],
              ['設計', '製作', '前端', '版面', '的'],
              ['，', '的', '書', '入門', '課程'],
              ['預算', '請問', '但是', '想', '有'],
              ['大概', '有限', '不多', '是', '在'],
              ['以內', '左右', '元', '以下'],
              ['以內', '左右', '元', '以下'],
              ['以內', '左右', '元', '以下'],
              ['以內', '左右', '元', '以下'],
              ['以內', '左右', '元', '以下'],
              ['。', '，', '的', '書', '謝謝'],
            ],
          );
          await rec.play(const Duration(milliseconds: 400));

          await rec.tap(find.byIcon(Icons.arrow_upward_rounded).last);
          FocusManager.instance.primaryFocus?.unfocus();
          await rec.keyboard(false);
          await rec.until(() => find.byType(AiBookChatCard).evaluate().isNotEmpty);
          await rec.play(const Duration(milliseconds: 2000));

          await rec.tap(find.byType(AiBookChatCard).first);
          await rec.play(const Duration(milliseconds: 900));
          await waitForImages(tester);
          await rec.play(const Duration(milliseconds: 1300));
          rec.save();
        });
      },
    );
  });

  // 3. AI 客服：依平台規則與使用者的訂單回答缺頁退款問題，並提供轉接客服人員
  testWidgets('ai_support', variant: _ios, (tester) async {
    final now = DateTime.now();
    final pickedUp = now.subtract(const Duration(minutes: 76));
    final deadline = pickedUp.add(const Duration(hours: 24));
    final at = _iso(now);
    final answer = '可以申請交易爭議。您的訂單 $_orderNo（《$_title》）於今天 ${_hm(pickedUp)} 取書，'
        '可在明天 ${_hm(deadline)} 前、且訂單完成前提出申請。\n'
        '- 至訂單頁按下「申請爭議」，說明缺頁的位置並附上照片。\n'
        '- 申請前請勿按下「完成訂單」，完成後即無法申請爭議。\n'
        '- 管理員將裁決退款、駁回或協調結案；裁決退款時，代幣會退回您的錢包。';
    await shoot(
      tester,
      folder: 'd2',
      routes: () {
        ManualApi.on('GET', '/ai/support/session', (_) => {'session_id': 21, 'status': 'open', 'messages': <Object>[]});
        ManualApi.on('POST', '/ai/support/messages', (_) => {
          'user_message': {'message_id': 301, 'content': '取書後發現有缺頁可以退款嗎？', 'created_at': at},
          'reply': {
            'message_id': 302,
            'content': answer,
            'suggestions': ['爭議申請後多久會有結果？', '如何上傳缺頁的照片？'],
            'order_nos': [_orderNo],
            'message_no': 'AS7KD2M9Q',
            'suggest_handoff': true,
            'created_at': at,
          },
          'suggest_handoff': true,
        });
      },
      home: AiSupportScreen.new,
      act: (tester, snap) async {
        await _withDelays({'POST /ai/support/messages': const Duration(milliseconds: 1500)}, () async {
          unawaited(AiStatus.refresh(force: true));
          await _ready(tester);
          final rec = GifRecorder(tester, 'ai_support');
          await rec.play(const Duration(milliseconds: 1000));

          final field = find.byType(TextField);
          await rec.tap(field);
          await rec.keyboard(true, candidates: ['我', '請問', '你', '想', '有', '可以', '取書']);
          await rec.type(
            field,
            ['取書', '後', '發現', '有', '缺頁', '可以', '退款', '嗎', '？'],
            step: const Duration(milliseconds: 200),
            candidates: [
              ['後', '時', '的', '了', '流程'],
              ['發現', '才', '要', '可以', '的'],
              ['有', '書', '少', '是', '好像'],
              ['缺頁', '問題', '破損', '劃記', '一些'],
              ['可以', '怎麼', '的', '要', '是'],
              ['退款', '申請', '退貨', '換', '嗎'],
              ['嗎', '怎麼', '流程', '的', '嗎？'],
              ['？', '，', '。', '謝謝'],
              ['謝謝', '請問', '我', '麻煩'],
            ],
          );
          await rec.play(const Duration(milliseconds: 400));

          await rec.tap(find.byIcon(Icons.arrow_upward_rounded).last);
          FocusManager.instance.primaryFocus?.unfocus();
          await rec.keyboard(false);
          await rec.until(() => find.text(S.ourSupportTeamCanHelpWith).evaluate().isNotEmpty);
          await rec.play(const Duration(milliseconds: 900));
          // 轉接卡片展開後才多出高度，清單停在卡片下緣被建議問題遮住的位置，往上滑到底
          final list = tester.state<ScrollableState>(find.ancestor(of: find.text(S.ourSupportTeamCanHelpWith), matching: find.byType(Scrollable)).first);
          final rest = list.position.maxScrollExtent - list.position.pixels;
          if (rest > 1) await rec.scroll(list.position, rest, finger: const Offset(310, 600), duration: const Duration(milliseconds: 480));
          await rec.play(const Duration(milliseconds: 1500));

          await rec.tap(find.text(S.talkPerson).last);
          await rec.play(const Duration(milliseconds: 1600));
          rec.save();
        });
      },
    );
  });

  // 4. 管理員處理交易爭議：AI 比對上架照片與佐證照片並提出建議（僅供參考）→ 管理員選擇裁決方式
  testWidgets('ai_dispute', variant: _ios, (tester) async {
    final now = DateTime.now();
    final admin = User.fromJson(userJson(adminId));
    Map<String, dynamic> order(String no, int bookId, int buyer, int seller) => {
      'order_id': no == _orderNo ? _orderId : 497,
      'order_no': no,
      'total_amount': bookJson(bookId)['price'],
      'order_items': [
        {'book_id': bookId, 'books': _book(bookId)},
      ],
      'users_orders_buyer_idTousers': {'user_id': buyer, 'nickname': realUsers[buyer]!.nickname},
      'users_orders_seller_idTousers': {'user_id': seller, 'nickname': realUsers[seller]!.nickname},
    };
    final disputes = [
      {
        'dispute_id': _disputeId,
        'order_id': _orderId,
        'applicant_id': meId,
        'reason': '封面右上角有明顯刮痕與白色磨損，上架時書況標示「良好」且未說明，與描述不符。',
        'status': 'pending',
        'result': null,
        'created_at': _iso(now.subtract(const Duration(minutes: 18))),
        'users_transaction_disputes_applicant_idTousers': {'user_id': meId, 'nickname': meName},
        'orders': order(_orderNo, _bookId, meId, _sellerId),
        'evidence_images': [_evidenceUrl],
      },
      {
        'dispute_id': 58,
        'order_id': 497,
        'applicant_id': 11,
        'reason': '收到的版本與上架照片不同，封面設計不一致。',
        'status': 'pending',
        'result': null,
        'created_at': _iso(now.subtract(const Duration(hours: 2, minutes: 40))),
        'users_transaction_disputes_applicant_idTousers': {'user_id': 11, 'nickname': realUsers[11]!.nickname},
        'orders': order('SMB20261006204718552903', 135, 11, 10),
        'evidence_images': <String>[],
      },
    ];
    final analysis = {
      'analysis_no': 'DA7K3M9QX',
      'summary': '買家於取書後約 1 小時申請爭議，主張封面右上角的刮痕與磨損未於上架時說明；賣家標示書況為「良好」，未填寫書況說明。',
      'finding_details': [
        {'content': '佐證照片可見封面右上角有刮痕與白色磨損', 'basis': 'evidence_photo', 'photos': [4], 'favors': 'buyer'},
        {'content': '上架的封面照片右上角已可辨識相同位置的刮痕', 'basis': 'listing_photo', 'photos': [1], 'favors': 'seller'},
        {'content': '封底與 ISBN 特寫照片未見其他破損', 'basis': 'listing_photo', 'photos': [2, 3], 'favors': 'seller'},
        {'content': '書況標示為良好，未以文字說明封面刮痕', 'basis': 'listing_text', 'photos': <int>[], 'favors': 'buyer'},
      ],
      'suggestion': 'mediate',
      'confidence': 0.6,
      'confidence_level': 'medium',
      'rationale': '刮痕在上架照片中已可辨識但未以文字說明，屬外觀瑕疵且不影響閱讀，建議由雙方協調處理。',
      'images': {'listing': 3, 'evidence': 1, 'skipped': 0},
      'photos': [
        {'no': 1, 'source': 'listing', 'type': 'cover', 'title': _title},
        {'no': 2, 'source': 'listing', 'type': 'back', 'title': _title},
        {'no': 3, 'source': 'listing', 'type': 'other', 'title': _title},
        {'no': 4, 'source': 'evidence'},
      ],
      'created_at': _iso(now),
    };
    await shoot(
      tester,
      folder: 'd2',
      me: admin,
      routes: () {
        ManualApi.on('GET', '/auth/me', (_) => userJson(adminId));
        ManualApi.on('GET', '/admin/disputes', (_) => disputes);
        ManualApi.on('GET', '/admin/disputes/$_disputeId/ai-analysis', (_) => null);
        ManualApi.on('POST', '/admin/disputes/$_disputeId/ai-analysis', (_) => analysis);
      },
      // 佐證照片不在共用的照片資料夾，先換上能提供它的圖片來源，再開啟爭議頁
      home: () => const SizedBox.shrink(),
      act: (tester, snap) async {
        debugNetworkImageHttpClientProvider = () => GifPhotoClient({_evidenceUrl: File('$gifRoot/evidence_scratch.jpg')});
        // 裁決面板在手機上以 useSafeArea: false 開啟，分析結果展開後面板長到螢幕頂端、內容壓在狀態列與動態島底下；
        // 錄製時限制面板高度不超過狀態列下緣（等同 useSafeArea: true 的效果）
        unawaited(navigatorKey.currentState!.pushReplacement(
          PageRouteBuilder<void>(
            transitionDuration: Duration.zero,
            pageBuilder: (context, _, _) => Theme(
              data: Theme.of(context).copyWith(
                bottomSheetTheme: Theme.of(context).bottomSheetTheme.copyWith(
                  constraints: BoxConstraints(maxHeight: logicalSize.height - topInset, maxWidth: logicalSize.width),
                ),
              ),
              child: const AdminDisputeScreen(),
            ),
          ),
        ));
        await _withDelays({'POST /admin/disputes/$_disputeId/ai-analysis': const Duration(milliseconds: 1700)}, () async {
          await _ready(tester);
          // 先開關一次裁決面板，讓面板內較大尺寸的佐證照片先解碼，錄製時滑入過程不會出現空白縮圖
          await tester.tap(find.text(S.handle).first);
          await settleReal(tester, const Duration(milliseconds: 1500));
          await waitForImages(tester);
          Navigator.of(tester.element(find.text(S.analyze))).pop();
          await settleReal(tester, const Duration(milliseconds: 1500));
          final rec = GifRecorder(tester, 'ai_dispute');
          await rec.play(const Duration(milliseconds: 1200));

          await rec.tap(find.text(S.handle).first);
          await rec.play(const Duration(milliseconds: 700));
          await waitForImages(tester);
          await rec.play(const Duration(milliseconds: 700));

          await rec.tap(find.text(S.analyze));
          await rec.until(() => find.textContaining('AI 參考').evaluate().isNotEmpty);
          await rec.play(const Duration(milliseconds: 1600));

          final sheet = tester.state<ScrollableState>(find.ancestor(of: find.text(S.aiAnalysis), matching: find.byType(Scrollable)).first);
          final radio = tester.getRect(find.text(S.disputeMediated));
          final delta = (radio.bottom - 640).clamp(0.0, sheet.position.maxScrollExtent - sheet.position.pixels);
          await rec.scroll(sheet.position, delta, finger: const Offset(200, 700), duration: const Duration(milliseconds: 900));
          await rec.play(const Duration(milliseconds: 900));

          await rec.tap(find.text(S.disputeMediated));
          await rec.play(const Duration(milliseconds: 1600));
          rec.save();
        });
      },
    );
  });
}
