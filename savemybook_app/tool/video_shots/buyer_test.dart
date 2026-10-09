// 系統簡介影片第二版「買家找書」段落（分鏡v2.md 第四節）：flutter test tool/video_shots/buyer_test.dart
// 買家 es 以「HTML」搜尋到《HTML & CSS》、瀏覽為您推薦、向 AI 書籍顧問提出需求與預算，並在聊天室與賣家雪喵往來；
// 另一個陌生帳號要求私下轉帳時，聊天室顯示防詐提醒。

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:savemybook_app/features/chat/ai/ai_book_chat_screen.dart';
import 'package:savemybook_app/features/chat/chat_risk.dart';
import 'package:savemybook_app/features/chat/chat_room_screen.dart';
import 'package:savemybook_app/features/chat/widgets/chat_bubbles.dart';
import 'package:savemybook_app/features/home/home_screen.dart';
import 'package:savemybook_app/features/home/search_screen.dart';
import 'package:savemybook_app/widgets/animations.dart';
import 'package:savemybook_app/widgets/book_card.dart';
import 'package:savemybook_app/widgets/search_bar_widget.dart';

import '../manual_shots/manual_api.dart';
import 'video_data.dart';
import 'video_host.dart';

final _ios = TargetPlatformVariant.only(TargetPlatform.iOS);

void _homeRoutes() {
  ManualApi.on('GET', '/ai/recommendations', (_) => {
    'success': true,
    'message': 'OK',
    'data': [
      for (final r in recommendations) {'book': bookJson(r.id), 'reason': r.reason},
    ],
    'groups': [
      {'kind': 'more', 'book_ids': [for (final r in recommendations) r.id]},
    ],
    'meta': {'source': 'ai', 'generated_at': ago(minutes: 30), 'refreshing': false},
  });
}

Finder _textIn(String text) => find.textContaining(text, findRichText: true);

void main() {
  setUpAll(setUpManual);
  setUp(failures.clear);
  tearDownAll(writeJson);

  testWidgets('首頁、搜尋與推薦', variant: _ios, (tester) async {
    await videoShoot(
      tester,
      routes: _homeRoutes,
      home: HomeScreen.new,
      act: (tester) async {
        await settleReal(tester, const Duration(seconds: 1));
        await snapScreen(tester, 'v_home');
        await cut(tester, 'cut_search_bar', screen: 'v_home', box: renderOf(tester, find.byType(SearchBarWidget), pick: isBoxDecoration));
        for (final (i, r) in recommendations.take(2).indexed) {
          final tile = ancestorWhere(find.text(r.reason, skipOffstage: false), (w) => w is PressableScale);
          await cut(tester, 'cut_home_rec_card_${i + 1}', screen: 'v_home', box: renderOf(tester, tile, pick: isBoxDecoration));
        }
        await restoreTree(tester);

        await tester.tap(find.byType(SearchBarWidget));
        await settleReal(tester, const Duration(seconds: 2));
        final field = find.descendant(of: find.byType(SearchScreen), matching: find.byType(TextField));
        await snapScreen(tester, 'v_search_typing_t00');
        final typed = await typeFrames(tester, field, searchKeyword, 'v_search_typing');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await settleReal(tester, const Duration(seconds: 3));
        FocusManager.instance.primaryFocus?.unfocus();
        await settleReal(tester, const Duration(seconds: 1));
        await snapScreen(tester, 'v_search_result');
        recordSequence('search_typing', ['v_home', 'v_search_typing_t00', ...typed, 'v_search_result']);
        final card = ancestorWhere(find.text(storyTitle, skipOffstage: false), (w) => w is BookCard);
        await cut(tester, 'cut_result_card', screen: 'v_search_result', box: renderOf(tester, card, pick: isBoxDecoration));
        await restoreTree(tester);

        // 清除搜尋回到首頁，往下捲到「為您推薦」
        await tester.tap(find.descendant(of: find.byType(SearchBarWidget), matching: find.byIcon(Icons.cancel)));
        await settleReal(tester, const Duration(seconds: 2));
        final first = find.text(recommendations.first.reason, skipOffstage: false);
        final tileTop = (ancestorWhere(first, (w) => w is PressableScale).renderObject! as RenderBox).localToGlobal(Offset.zero).dy;
        await scrollBy(tester, tileTop - 300);
        await settleReal(tester, const Duration(seconds: 1));
        await snapScreen(tester, 'v_home_rec');
        for (final (i, r) in recommendations.take(2).indexed) {
          final tile = ancestorWhere(find.text(r.reason, skipOffstage: false), (w) => w is PressableScale);
          await cut(tester, 'cut_rec_card_${i + 1}', screen: 'v_home_rec', box: renderOf(tester, tile, pick: isBoxDecoration));
        }
        await restoreTree(tester);
      },
    );
    expect(failures, isEmpty);
  });

  testWidgets('AI 書籍顧問', variant: _ios, (tester) async {
    await videoShoot(
      tester,
      routes: () {
        ManualApi.on('GET', '/ai/book-chat/session', (_) => {'session_id': 31, 'messages': <Object>[]});
        ManualApi.on('POST', '/ai/book-chat/messages', (r) {
          final id = RegExp(r'"client_id"\s*:\s*"([^"]+)"').firstMatch(r.body)?.group(1) ?? 'video';
          return advisorAnswer(id);
        });
      },
      home: AiBookChatScreen.new,
      act: (tester) async {
        await settleReal(tester, const Duration(seconds: 1));
        await snapScreen(tester, 'v_advisor_empty');
        final input = find.descendant(of: find.byType(AiBookChatScreen), matching: find.byType(TextField));
        final typed = await typeFrames(tester, input, advisorRequest, 'v_advisor', step: 3);
        final send = find.ancestor(of: find.byIcon(Icons.arrow_upward_rounded), matching: find.byType(PressableScale)).first;
        tapAt(tester, 'tap_advisor_send', screen: typed.last, finder: send);
        final decorator = find.descendant(of: input, matching: find.byType(InputDecorator));
        final decoration = tester.widget<InputDecorator>(decorator).decoration;
        final border = decoration.focusedBorder ?? decoration.enabledBorder ?? decoration.border;
        await cut(
          tester,
          'cut_advisor_input',
          screen: typed.last,
          box: renderOf(tester, decorator),
          shape: border is OutlineInputBorder ? CutShape.rect(border.borderRadius) : null,
          note: '輸入列中填好需求的文字框',
        );
        await restoreTree(tester);

        holdApi('POST /ai/book-chat/messages');
        await tester.tap(send);
        await tester.pump();
        await untilHeld(tester);
        await settle(tester, const Duration(milliseconds: 900));
        spinnerFocus = find.byType(AiBookChatScreen);
        await snapScreen(tester, 'v_advisor_wait');
        spinnerFocus = null;
        await restoreTree(tester);

        releaseApi();
        await settleReal(tester, const Duration(seconds: 2));
        await settle(tester, const Duration(seconds: 8));
        await snapScreen(tester, 'v_advisor_answer');
        recordSequence('advisor_type', ['v_advisor_empty', ...typed, 'v_advisor_wait', 'v_advisor_answer']);
        final ask = find.ancestor(of: _textIn(advisorRequest), matching: find.byType(Container)).first;
        await cut(tester, 'cut_advisor_ask', screen: 'v_advisor_answer', box: renderOf(tester, ask, pick: isBoxDecoration), note: '使用者送出的需求泡泡');
        final cards = find.byType(AiBookChatCard);
        for (var i = 0; i < 2; i++) {
          await cut(tester, 'cut_advisor_pick_${i + 1}', screen: 'v_advisor_answer', box: renderOf(tester, cards.at(i), pick: isBoxDecoration));
        }
        await restoreTree(tester);
      },
    );
    expect(failures, isEmpty);
  });

  testWidgets('與賣家聊天', variant: _ios, (tester) async {
    await videoShoot(
      tester,
      routes: () {
        ManualApi.on('GET', '/chat/rooms/$sellerRoomId', (_) => roomJson(sellerRoomId, sellerId));
        ManualApi.on('GET', '/chat/rooms/$sellerRoomId/messages', (_) {
          final list = sellerMessages();
          return {'success': true, 'message': 'OK', 'data': list, 'partner': {...userJson(sellerId), 'alias': null}, 'meta': roomMeta(partner: sellerId, count: list.length)};
        });
      },
      home: () => ChatRoomScreen(roomId: sellerRoomId, partnerName: sellerName),
      act: (tester) async {
        await settleReal(tester, const Duration(seconds: 2));
        await snapScreen(tester, 'v_chat_seller');
        final text = find.ancestor(of: _textIn(chatQuestion), matching: find.byType(ChatBubbleShell)).first;
        await cut(tester, 'cut_msg_text', screen: 'v_chat_seller', box: renderOf(tester, text, pick: isBoxDecoration));
        await cut(tester, 'cut_msg_image', screen: 'v_chat_seller', box: renderOf(tester, find.byType(ChatImageThumb), pick: (ro) => ro is RenderClipRRect));
        final voice = find.ancestor(of: find.byType(ChatVoiceBody), matching: find.byType(ChatBubbleShell)).first;
        await cut(tester, 'cut_msg_voice', screen: 'v_chat_seller', box: renderOf(tester, voice, pick: isBoxDecoration));
        await restoreTree(tester);
      },
    );
    expect(failures, isEmpty);
  });

  for (final stage in [0, 1]) {
    testWidgets('陌生帳號要求私下轉帳 $stage', variant: _ios, (tester) async {
      await videoShoot(
        tester,
        routes: () {
          ManualApi.on('GET', '/chat/rooms/$scamRoomId', (_) => roomJson(scamRoomId, strangerId));
          ManualApi.on('GET', '/chat/rooms/$scamRoomId/messages', (_) {
            final list = scamMessages(withScam: stage == 1);
            return {
              'success': true,
              'message': 'OK',
              'data': list,
              'partner': {'user_id': strangerId, 'nickname': strangerName, 'avatar_url': null, 'alias': null},
              'meta': roomMeta(partner: strangerId, count: list.length, riskBanner: stage == 1 ? scamRisk : null),
            };
          });
        },
        home: () => const ChatRoomScreen(roomId: scamRoomId, partnerName: strangerName),
        act: (tester) async {
          await settleReal(tester, const Duration(seconds: 2));
          final name = stage == 0 ? 'v_chat_scam_0' : 'v_chat_scam';
          await snapScreen(tester, name);
          if (stage == 0) return;
          recordSequence('chat_scam', ['v_chat_scam_0', 'v_chat_scam']);
          await cut(
            tester,
            'cut_warn_banner',
            screen: name,
            box: renderOf(tester, find.byType(ChatRiskBanner), pick: (ro) => ro is RenderPhysicalModel || ro is RenderPhysicalShape),
            note: '聊天室頂端的高風險訊息橫幅（App 原色為 8% 紅色疊在聊天背景上，已連同底色輸出）',
          );
          // 訊息下方的防詐提醒是否與泡泡同在一個不透明容器：往上找提醒的第一個不透明底色，再看它是不是泡泡本身
          final note = renderOf(tester, find.byType(ChatRiskNote));
          final bubble = renderOf(tester, find.ancestor(of: _textIn('直接轉帳'), matching: find.byType(ChatBubbleShell)).first, pick: isBoxDecoration);
          var shared = false;
          for (RenderObject? n = note.parent; n != null; n = n.parent) {
            if (n == bubble) shared = true;
          }
          debugPrint('SCAM NOTE IN BUBBLE: $shared, note backdrop: ${opaqueBackdropOf(note)}');
          await cut(tester, 'cut_warn_inline', screen: name, box: renderOf(tester, find.byType(ChatRiskNote)), note: '訊息下方的防詐提醒（文字元件，無底色）');
          await cut(
            tester,
            'cut_msg_scam',
            screen: name,
            box: renderOf(tester, find.ancestor(of: _textIn('直接轉帳'), matching: find.byType(ChatBubbleShell)).first, pick: isBoxDecoration),
            note: '陌生帳號要求私下轉帳的訊息',
          );
          await restoreTree(tester);
        },
      );
      expect(failures, isEmpty);
    });
  }
}
