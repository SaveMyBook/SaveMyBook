// 複評簡報 GIF：聊天防詐。買家 es 與賣家 Gary 洽談 Gary 上架的真實書籍《洗腦，被設計的真相》（book_id 148），
// es 詢問能否用書櫃交易，對方回覆站外聯絡方式並要求私下轉帳 → 聊天室頂端出現高風險提醒橫幅 → 點「防詐須知」看說明。
// 主線賣家雪喵之後要與 es 完成正常交易，不可當詐騙者；LINE 帳號為虛構字串。
// 訊息時間比照狀態列的 11:22。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:savemybook_app/features/chat/chat_room_screen.dart';
import 'package:savemybook_app/i18n/strings.dart';

import '../manual_shots/manual_api.dart';
import '../manual_shots/manual_host.dart';
import 'd1_rec.dart';

final _ios = TargetPlatformVariant.only(TargetPlatform.iOS);

const _room = 1;
const _bookId = 148;
const _seller = 11;
const _question = '可以用書櫃交易嗎？';
const _scam = '書櫃要等比較久，加我 LINE：gary_books_2026，直接轉帳給我就好';
const _risk = {'level': 'high', 'categories': ['payment', 'contact']};

Map<String, dynamic> _sender(int id) => {'user_id': id, 'nickname': realUsers[id]!.nickname, 'avatar_url': realUsers[id]!.avatar};

Map<String, dynamic> _msg(int id, int sender, String kind, String at, {String? text, Map<String, dynamic>? payload, Object? risk}) => {
  'message_id': id,
  'room_id': _room,
  'sender_id': sender,
  'content': text ?? '',
  'message_type': kind == 'text' ? 'text' : 'system',
  'kind': kind,
  'body': text,
  'mentions': <Object>[],
  'payload': payload,
  'is_read': true,
  'created_at': at,
  'edited_at': null,
  'reply_to': null,
  'users': _sender(sender),
  'risk': risk,
};

List<Map<String, dynamic>> _conversation() {
  final book = bookJson(_bookId);
  return [
    _msg(1, meId, 'book', todayAt(11, 16), payload: {'book_id': _bookId, 'title': book['title'], 'price': 400, 'image_url': coverOf(_bookId)}),
    _msg(2, meId, 'text', todayAt(11, 16), text: '您好，請問這本書還在嗎？'),
    _msg(3, _seller, 'text', todayAt(11, 18), text: '還在喔，書況近全新～'),
    _msg(4, meId, 'text', todayAt(11, 21), text: _question),
    _msg(5, _seller, 'text', todayAt(11, 22), text: _scam, risk: _risk),
  ];
}

var _count = 3;
var _typing = false;

void _routes() {
  _count = 3;
  _typing = false;
  ManualApi.on('GET', '/chat/rooms/$_room/messages', (r) {
    final all = _conversation().take(_count).toList();
    final after = int.tryParse(r.query['after_id'] ?? '');
    final before = int.tryParse(r.query['before_id'] ?? '');
    final list = [
      for (final m in all)
        if ((after == null || (m['message_id'] as int) > after) && (before == null || (m['message_id'] as int) < before)) m,
    ];
    final p = userJson(_seller);
    return {
      'success': true,
      'message': 'OK',
      'data': list,
      'partner': {'user_id': _seller, 'nickname': p['nickname'], 'avatar_url': p['avatar_url'], 'alias': null},
      'meta': {
        'read_upto': _count >= 4 ? 4 : 2,
        'partner_typing': _typing,
        'recalled_ids': <int>[],
        'has_more': false,
        'reservations': <Object>[],
        'transfers': <Object>[],
        'members_read': [
          {'user_id': _seller, 'last_read_message_id': _count >= 4 ? 4 : 2},
        ],
        'aliases': <String, String>{},
        'edited': <Object>[],
        'room': {'type': 'direct', 'title': p['nickname'], 'avatar_url': p['avatar_url'], 'member_count': 2},
        'risk_banner': _count >= 5 ? _risk : null,
      },
    };
  });
  ManualApi.on('POST', '/chat/rooms/$_room/messages', (_) {
    _count = 4;
    return _conversation()[3];
  });
  ManualApi.on('GET', '/wallet', (_) => {'balance': 9600, 'frozen_amount': 0, 'total_income': 0, 'total_expense': 0, 'pending_income': 0});
}

/// 讓聊天室立即輪詢一次（切到非作用中再回到前景時會強制輪詢）。
Future<void> _pollNow(WidgetTester tester) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
}

/// 注音輸入：每次送出一個詞，候選字列顯示下一個詞的聯想。
const _words = [
  ('可以', ['用', '嗎', '的', '先', '幫', '再']),
  ('用', ['書櫃', '什麼', '這個', '面交', '哪個']),
  ('書櫃', ['交易', '取書', '嗎', '的', '寄放']),
  ('交易', ['嗎', '的', '了', '方式', '時間']),
  ('嗎', ['？', '，', '。', '呢', '吧']),
  ('？', ['好', '謝謝', '請問', '我', '可以']),
];

final _failures = <String>[];

void main() {
  setUpAll(setUpManual);

  testWidgets('chat_risk', variant: _ios, (tester) async {
    final rec = Rec('chat_risk');
    await shoot(
      tester,
      folder: '_d1',
      routes: _routes,
      home: () => const ChatRoomScreen(roomId: _room),
      act: (tester, _) async {
        try {
          EditableText.debugDeterministicCursor = true;
          addTearDown(() => EditableText.debugDeterministicCursor = false);
          await settleReal(tester, const Duration(seconds: 1));
          await waitForImages(tester);

          final input = find.byType(TextField);
          await rec.hold(tester, 640);
          await rec.tap(tester, input);
          await slideKeyboard(tester, rec, keyboard: const IosKeyboard(candidates: ['我', '你好', '請問', '可以', '謝謝', '好的']), height: keyboardHeight, show: true);
          await rec.play(tester, 120);

          var text = '';
          for (final (word, next) in _words) {
            text += word;
            setKeyboard(tester, keyboard: IosKeyboard(candidates: next), height: keyboardHeight, visible: 1);
            await tester.enterText(input, text);
            await rec.play(tester, 200);
          }
          await rec.play(tester, 160);

          await rec.tap(tester, find.byIcon(Icons.send_rounded));
          await rec.play(tester, 640);

          _typing = true;
          await _pollNow(tester);
          await rec.play(tester, 1100);

          _typing = false;
          _count = 5;
          await _pollNow(tester);
          await rec.play(tester, 900);
          await rec.hold(tester, 900);

          await rec.tap(tester, find.text(S.scamSafetyTips).first);
          await slideKeyboard(tester, rec, keyboard: const IosKeyboard(candidates: ['好', '謝謝', '請問', '我', '可以']), height: keyboardHeight, show: false);
          await rec.play(tester, 400);
          await rec.hold(tester, 1900);
          rec.save();
        } catch (e, st) {
          _failures.add('$e');
          debugPrint('ACT FAILED: $e\n$st');
        }
      },
    );
    expect(_failures, isEmpty);
  });
}
