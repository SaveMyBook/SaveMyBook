import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:savemybook_app/features/chat/chat_risk.dart';
import 'package:savemybook_app/features/chat/widgets/chat_input_bar.dart';
import 'package:savemybook_app/models/chat.dart';

ChatMessage _message(int id, {int sender = 2, Map<String, dynamic>? risk, String kind = 'text'}) => ChatMessage.fromJson({
      'message_id': id,
      'sender_id': sender,
      'content': 'm$id',
      'message_type': 'text',
      'kind': kind,
      'risk': risk,
    });

void main() {
  group('ChatRisk', () {
    test('依危險程度排序並忽略不認得的類別', () {
      final risk = ChatRisk.fromJson({'level': 'high', 'categories': ['contact', 'unknown', 'credential']})!;
      expect(risk.high, isTrue);
      expect(risk.categories, [ChatRiskCategory.credential, ChatRiskCategory.contact]);
      expect(risk.primary, ChatRiskCategory.credential);
    });

    test('沒有可辨識的類別時視為無風險', () {
      expect(ChatRisk.fromJson({'level': 'notice', 'categories': ['unknown']}), isNull);
      expect(ChatRisk.fromJson(null), isNull);
    });
  });

  group('chatRiskNotes', () {
    test('一般提醒每種類別只在最早出現的訊息下顯示一次', () {
      final notes = chatRiskNotes([
        _message(1, risk: {'level': 'notice', 'categories': ['contact']}),
        _message(2, risk: {'level': 'notice', 'categories': ['contact']}),
        _message(3, risk: {'level': 'notice', 'categories': ['contact', 'payment']}),
      ], 1);
      expect(notes.keys, [1, 3]);
      expect(notes[3]!.categories, [ChatRiskCategory.payment]);
    });

    test('高風險訊息每則都提醒，自己傳的與已收回的不提醒', () {
      final notes = chatRiskNotes([
        _message(1, risk: {'level': 'high', 'categories': ['credential']}),
        _message(2, risk: {'level': 'high', 'categories': ['credential']}),
        _message(3, sender: 1, risk: {'level': 'high', 'categories': ['scam']}),
        _message(4, kind: 'recalled', risk: {'level': 'high', 'categories': ['scam']}),
        _message(5, risk: {'level': 'notice', 'categories': ['credential']}),
      ], 1);
      expect(notes.keys, [1, 2]);
      expect(notes.values.every((r) => r.high), isTrue);
    });
  });

  testWidgets('輸入框有無文字時輸入列高度不變', (tester) async {
    final text = TextEditingController();
    final focus = FocusNode();
    addTearDown(text.dispose);
    addTearDown(focus.dispose);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            const Spacer(),
            ChatInputBar(
              controller: text,
              focusNode: focus,
              onSend: (_) {},
              onAttach: () {},
              onToggleQuickReplies: () {},
              onVoice: (_) {},
              onVoiceUnavailable: (_) {},
              onVoiceTooShort: () {},
            ),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final empty = tester.getSize(find.byType(ChatInputBar)).height;

    text.text = '請問這本書還在嗎';
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(ChatInputBar)).height, empty);

    text.clear();
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(ChatInputBar)).height, empty);
  });
}
