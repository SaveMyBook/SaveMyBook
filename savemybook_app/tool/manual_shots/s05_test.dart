// 第 12 章第 5 節「聊天協商、預約與轉帳」截圖：買家 es 與賣家 KJ 就 KJ 上架的真實書籍洽談。
// 原實機截圖詢問的「行銷學」已不在架上，改用 KJ 同價位（$450）的《用MBTI學韓文》。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:savemybook_app/features/chat/ai/ai_book_chat_screen.dart';
import 'package:savemybook_app/features/chat/chat_room_screen.dart';
import 'package:savemybook_app/features/home/notification_screen.dart';
import 'package:savemybook_app/features/orders/my_reservations_screen.dart';
import 'package:savemybook_app/i18n/strings.dart';
import 'package:savemybook_app/models/security.dart';
import 'package:savemybook_app/models/user.dart';
import 'package:savemybook_app/services/verification_service.dart';

import 'manual_api.dart';
import 'manual_host.dart';

const _folder = '5. 聊天協商、預約與轉帳';
const _room = 1;
const _bookId = 102;
const _kj = 7;
const _reservationId = 5;
const _vueBookId = 78;

final _ios = TargetPlatformVariant.only(TargetPlatform.iOS);

String get _title => bookJson(_bookId)['title'] as String;

String _plus(String iso, Duration d) => DateTime.parse(iso).add(d).toUtc().toIso8601String();

Map<String, dynamic> _sender(int id) => {'user_id': id, 'nickname': realUsers[id]!.nickname, 'avatar_url': realUsers[id]!.avatar};

Map<String, dynamic> _msg(
  int id,
  int sender,
  String kind,
  String at, {
  String? text,
  Map<String, dynamic>? payload,
  Map<String, dynamic>? risk,
  bool read = true,
}) => {
  'message_id': id,
  'room_id': _room,
  'sender_id': sender,
  'content': text ?? '',
  'message_type': switch (kind) {
    'text' => 'text',
    'image' => 'image',
    'voice' => 'voice',
    _ => 'system',
  },
  'kind': kind,
  'body': text,
  'mentions': <Object>[],
  'payload': payload,
  'is_read': read,
  'created_at': at,
  'edited_at': null,
  'reply_to': null,
  'users': _sender(sender),
  'risk': risk,
};

/// 預約狀態：pending（待回覆）、confirmed（已保留）、cancelled（賣家取消）。
Map<String, dynamic> _reservation(String status) => {
  'reservation_id': _reservationId,
  'book': {'book_id': _bookId, 'title': _title, 'price': 450, 'status': 'on_sale', 'image_url': coverOf(_bookId)},
  'buyer_id': meId,
  'seller_id': _kj,
  'status': status,
  'hours': 24,
  'message': null,
  'closed_by': status == 'cancelled' ? 'seller' : null,
  'closed_action': status == 'cancelled' ? 'cancel' : null,
  'pickup_deadline': status == 'pending' ? null : _plus(todayAt(23, 14), const Duration(hours: 24)),
  'is_holding': status == 'confirmed',
  'created_at': todayAt(23, 11),
  'seller': {'user_id': _kj, 'nickname': realUsers[_kj]!.nickname},
  'room_id': _room,
};

/// es 向 KJ 請款 10 代幣（KJ 為付款人）。
Map<String, dynamic> _request() => {
  'transfer_id': 1,
  'transfer_no': 'TF${_stamp(todayAt(23, 15))}482913',
  'kind': 'request',
  'room_id': _room,
  'message_id': 7,
  'from_user_id': _kj,
  'to_user_id': meId,
  'amount': 10,
  'note': null,
  'status': 'pending',
  'created_at': todayAt(23, 15),
  'responded_at': null,
  'expires_at': _plus(todayAt(23, 15), const Duration(days: 2)),
};

/// es 轉帳 10 代幣給 KJ。
Map<String, dynamic> _transfer() => {
  'transfer_id': 2,
  'transfer_no': 'TF${_stamp(todayAt(23, 16))}530174',
  'kind': 'transfer',
  'room_id': _room,
  'message_id': 8,
  'from_user_id': meId,
  'to_user_id': _kj,
  'amount': 10,
  'note': null,
  'status': 'completed',
  'created_at': todayAt(23, 16),
  'responded_at': todayAt(23, 16),
  'expires_at': null,
};

String _stamp(String iso) {
  final d = DateTime.parse(iso).toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${d.year}${two(d.month)}${two(d.day)}${two(d.hour)}${two(d.minute)}${two(d.second)}';
}

const _photo = '/uploads/books/1789625677504-3ca4b85b2f99ad17.png';
const _voice = '/uploads/voice/1791386940518-7c2e9a41d0b35f86.m4a';
const _lineText = '我的line id是：ss12345，請加我討論';

/// 依時間順序的完整對話（第 1 則為詢問書籍卡片）。[viewer] 為登入者；自己送出的訊息依 [readUpto] 判斷對方是否已讀，
/// 賣家 KJ 的畫面於 [unreadBySeller] 時 es 的訊息（詢問書籍卡片除外）尚未讀取。
List<Map<String, dynamic>> _conversation({
  required int viewer,
  required String reservation,
  required int readUpto,
  bool unreadBySeller = false,
}) {
  bool read(int id, int sender) {
    if (sender == viewer) return id <= readUpto;
    return id == 1 || !unreadBySeller;
  }

  Map<String, dynamic> es(int id, String kind, String at, {String? text, Map<String, dynamic>? payload}) =>
      _msg(id, meId, kind, at, text: text, payload: payload, read: read(id, meId));
  return [
    es(1, 'book', todayAt(23, 8), payload: {'book_id': _bookId, 'title': _title, 'price': 450, 'image_url': coverOf(_bookId)}),
    es(2, 'text', todayAt(23, 8), text: '您好'),
    es(3, 'image', todayAt(23, 9), text: _photo),
    es(4, 'voice', todayAt(23, 9), payload: {'url': _voice, 'duration': 3}),
    es(5, 'text', todayAt(23, 9), text: '請問是否可議價？'),
    es(6, 'reservation', todayAt(23, 11), payload: _reservation(reservation)),
    es(7, 'transfer', todayAt(23, 15), payload: _request()),
    es(8, 'transfer', todayAt(23, 16), payload: _transfer()),
    _msg(9, _kj, 'text', todayAt(23, 18), text: _lineText, risk: {'level': 'medium', 'categories': ['contact']}, read: read(9, _kj)),
  ];
}

/// 聊天室的 API 回應。[viewer] 為登入者（es 或 KJ），[count] 為截至目前的訊息數。
/// [reservation] 以函式提供，讓接受預約後輪詢取得的狀態跟著改變。
void _chatRoutes({
  int viewer = meId,
  required int count,
  String Function()? reservation,
  bool unreadBySeller = false,
  int readUpto = 0,
  bool typing = false,
}) {
  final partner = viewer == meId ? _kj : meId;
  final status = reservation ?? () => 'pending';
  ManualApi.on('GET', '/chat/rooms/$_room/messages', (r) {
    final all = _conversation(viewer: viewer, reservation: status(), readUpto: readUpto, unreadBySeller: unreadBySeller).take(count).toList();
    final after = int.tryParse(r.query['after_id'] ?? '');
    final before = int.tryParse(r.query['before_id'] ?? '');
    final list = [
      for (final m in all)
        if ((after == null || (m['message_id'] as int) > after) && (before == null || (m['message_id'] as int) < before)) m,
    ];
    final p = userJson(partner);
    return {
      'success': true,
      'message': 'OK',
      'data': list,
      'partner': {'user_id': partner, 'nickname': p['nickname'], 'avatar_url': p['avatar_url'], 'alias': null},
      'meta': {
        'read_upto': readUpto,
        'partner_typing': typing,
        'recalled_ids': <int>[],
        'has_more': false,
        'reservations': [if (count >= 6) _reservation(status())],
        'transfers': [if (count >= 7) _request(), if (count >= 8) _transfer()],
        'members_read': [
          {'user_id': partner, 'last_read_message_id': readUpto},
        ],
        'aliases': <String, String>{},
        'edited': <Object>[],
        'room': {'type': 'direct', 'title': p['nickname'], 'avatar_url': p['avatar_url'], 'member_count': 2},
        'risk_banner': null,
      },
    };
  });
  ManualApi.on('GET', '/wallet', (_) => {'balance': 9600, 'frozen_amount': 0, 'total_income': 0, 'total_expense': 0, 'pending_income': 0});
  ManualApi.on('GET', '/security', (_) => {
    'available': true,
    'has_payment_pin': true,
    'pin_locked_until': null,
    'biometric_pay_enabled': false,
    'passkey_available': true,
    'has_passkey': false,
    'has_password': true,
  });
}

Widget _chatRoom() => const ChatRoomScreen(roomId: _room);

final User _kjUser = User.fromJson(userJson(_kj));

Finder get _input => find.byType(TextField);

Future<void> _openAttach(WidgetTester tester) => tapAndSettle(tester, find.byIcon(Icons.add_rounded));

Future<void> _toggleQuickReplies(WidgetTester tester) => tapAndSettle(tester, find.byIcon(Icons.bolt_rounded));

Future<void> _scrollStrip(WidgetTester tester, double pixels) async {
  final strip = find.descendant(
    of: find.byWidgetPredicate((w) => w is ListView && w.scrollDirection == Axis.horizontal),
    matching: find.byType(Scrollable),
  );
  await scrollBy(tester, pixels, scrollable: strip.first);
}

void main() {
  setUpAll(setUpManual);

  // 5-1 傳送文字訊息
  testWidgets('表12-5-1 輸入訊息', variant: _ios, (tester) async {
    await shoot(tester, folder: _folder, home: _chatRoom, routes: () => _chatRoutes(count: 1), act: (tester, snap) async {
      // 測試環境的游標會閃爍，截圖時固定顯示
      EditableText.debugDeterministicCursor = true;
      addTearDown(() => EditableText.debugDeterministicCursor = false);
      await tester.enterText(_input, '您好');
      showKeyboard(tester, candidates: ['可愛', '我', '喜歡', '的', '有', '開心', '了']);
      await settleReal(tester, const Duration(seconds: 1));
      await snap('表12-5-1 輸入訊息');
    });
  });

  testWidgets('表12-5-1 傳送文字訊息', variant: _ios, (tester) async {
    await shoot(tester, folder: _folder, home: _chatRoom, routes: () => _chatRoutes(count: 2), act: (tester, snap) async {
      await snap('表12-5-1 傳送文字訊息');
    });
  });

  testWidgets('表12-5-1 對方輸入中提示', variant: _ios, (tester) async {
    await shoot(
      tester,
      folder: _folder,
      home: _chatRoom,
      routes: () => _chatRoutes(count: 8, reservation: () => 'cancelled', readUpto: 8, typing: true),
      act: (tester, snap) async {
        await settleReal(tester, const Duration(seconds: 1));
        await snap('表12-5-1 對方輸入中提示');
      },
    );
  });

  // 5-2 傳送圖片與語音
  testWidgets('表12-5-2 附加功能選單', variant: _ios, (tester) async {
    await shoot(tester, folder: _folder, home: _chatRoom, routes: () => _chatRoutes(count: 1), act: (tester, snap) async {
      await _openAttach(tester);
      await snap('表12-5-2 附加功能選單');
    });
  });

  testWidgets('表12-5-2 傳送圖片', variant: _ios, (tester) async {
    await shoot(tester, folder: _folder, home: _chatRoom, routes: () => _chatRoutes(count: 3), act: (tester, snap) async {
      await snap('表12-5-2 傳送圖片');
    });
  });

  testWidgets('表12-5-2 傳送語音訊息', variant: _ios, (tester) async {
    await shoot(tester, folder: _folder, home: _chatRoom, routes: () => _chatRoutes(count: 4), act: (tester, snap) async {
      await snap('表12-5-2 傳送語音訊息');
    });
  });

  // 5-3 快速回覆與預約書籍（買家）
  testWidgets('表12-5-3 傳送快速回覆', variant: _ios, (tester) async {
    await shoot(tester, folder: _folder, home: _chatRoom, routes: () => _chatRoutes(count: 5), act: (tester, snap) async {
      await _toggleQuickReplies(tester);
      await snap('表12-5-3 傳送快速回覆');
      // 原資料夾另有一張捲動快速回覆列的畫面（未列入手冊）
      await _scrollStrip(tester, 150);
      await snap('IMG_7162');
    });
  });

  testWidgets('表12-5-3 送出預約請求', variant: _ios, (tester) async {
    await shoot(tester, folder: _folder, home: _chatRoom, routes: () => _chatRoutes(count: 6), act: (tester, snap) async {
      await _toggleQuickReplies(tester);
      await _scrollStrip(tester, 110);
      await snap('表12-5-3 送出預約請求');
    });
  });

  testWidgets('表12-5-3 我的預約', variant: _ios, (tester) async {
    await shoot(
      tester,
      folder: _folder,
      home: MyReservationsScreen.new,
      routes: () => ManualApi.on('GET', '/chat/reservations/mine', (_) => [_reservation('pending')]),
      act: (tester, snap) async {
        await tapAndSettle(tester, find.text('待賣家回覆'));
        await snap('表12-5-3 我的預約');
      },
    );
  });

  // 5-4、5-5 處理預約（賣家 KJ 的畫面）
  testWidgets('表12-5-4 收到預約請求、接受預約、已接受預約', variant: _ios, (tester) async {
    var status = 'pending';
    await shoot(
      tester,
      folder: _folder,
      me: _kjUser,
      home: _chatRoom,
      routes: () {
        _chatRoutes(viewer: _kj, count: 6, reservation: () => status, unreadBySeller: true);
        ManualApi.on('PATCH', '/chat/reservations/$_reservationId', (_) {
          status = 'confirmed';
          return _reservation(status);
        });
      },
      act: (tester, snap) async {
        await snap('表12-5-4 收到預約請求');
        await tapAndSettle(tester, find.text('接受'));
        await snap('表12-5-4 接受預約');
        await tapAndSettle(tester, find.text('接受').last);
        await snap('表12-5-4 已接受預約');
      },
    );
  });

  testWidgets('表12-5-5 婉拒預約', variant: _ios, (tester) async {
    await shoot(
      tester,
      folder: _folder,
      me: _kjUser,
      home: _chatRoom,
      routes: () => _chatRoutes(viewer: _kj, count: 6, unreadBySeller: true),
      act: (tester, snap) async {
        await tapAndSettle(tester, find.text('婉拒'));
        await snap('表12-5-5 婉拒預約');
      },
    );
  });

  testWidgets('表12-5-5 取消預約', variant: _ios, (tester) async {
    await shoot(
      tester,
      folder: _folder,
      me: _kjUser,
      home: _chatRoom,
      routes: () => _chatRoutes(viewer: _kj, count: 6, reservation: () => 'confirmed', unreadBySeller: true),
      act: (tester, snap) async {
        await tapAndSettle(tester, find.text('取消預約'));
        await snap('表12-5-5 取消預約');
      },
    );
  });

  testWidgets('表12-5-5 書籍售出通知', variant: _ios, (tester) async {
    final soldAt = ago(minutes: 1);
    final orderNo = 'SMB${_stamp(soldAt)}888428';
    Map<String, dynamic> n(int id, String category, String type, String title, String content, String at, {
      bool read = false,
      String? relatedType,
      int? relatedId,
    }) => {
      'notification_id': id,
      'type': type,
      'category': category,
      'title': title,
      'content': content,
      'related_id': relatedId,
      'related_type': relatedType,
      'is_read': read,
      'created_at': at,
    };
    final cabinet = realCabinets.firstWhere((c) => c['cabinet_name'] == '新北高工');
    final items = [
      n(412, 'service', 'system', '書櫃裝置已配對', '「${cabinet['cabinet_name']}」已完成實體書櫃裝置配對（來源 IP：163.20.230.201）。', ago(),
          relatedType: 'cabinet', relatedId: cabinet['cabinet_id'] as int),
      n(411, 'trade', 'order', '書籍已售出', '訂單 $orderNo 已成立，請於七天內至書櫃存書。', soldAt,
          read: true, relatedType: 'order', relatedId: 286),
      n(409, 'account', 'security', '新裝置登入', '您的帳號已於「iPhone 15 Pro（iOS）」登入。若非本人操作，請立即變更密碼並至「登入裝置」登出該裝置。', ago(minutes: 26),
          relatedType: 'security'),
      n(402, 'trade', 'order', '買家已取書', '《${bookJson(141)['title']}》已由買家取書，款項已撥入您的錢包。', ago(hours: 5), read: true, relatedType: 'order', relatedId: 271),
      n(398, 'service', 'ticket', '客服工單已回覆', '您的客服工單已有新的回覆，請至「客服中心」查看。', ago(hours: 9), relatedType: 'ticket', relatedId: 57),
    ];
    await shoot(
      tester,
      folder: _folder,
      me: _kjUser,
      home: () => const NotificationScreen(embedded: true),
      routes: () {
        ManualApi.on('GET', '/notifications', (_) => ok(items, pagination: {'total': items.length, 'page': 1, 'limit': 20, 'total_pages': 1}));
        ManualApi.on('GET', '/notifications/unread-count', (_) => {
          'unread_count': 35,
          'by_category': {'trade': 2, 'chat': 0, 'account': 1, 'service': 32, 'promotion': 0},
        });
      },
      act: (tester, snap) async {
        await tapAndSettle(tester, find.text('書籍已售出'));
        await snap('表12-5-5 書籍售出通知');
      },
    );
  });

  // 5-6 請款與轉帳
  testWidgets('表12-5-6 請款', variant: _ios, (tester) async {
    await shoot(
      tester,
      folder: _folder,
      home: _chatRoom,
      routes: () => _chatRoutes(count: 6, reservation: () => 'cancelled', readUpto: 6),
      act: (tester, snap) async {
        await _openAttach(tester);
        await tapAndSettle(tester, find.text('請款'));
        await snap('表12-5-6 請款');
      },
    );
  });

  testWidgets('表12-5-6 轉帳', variant: _ios, (tester) async {
    await shoot(
      tester,
      folder: _folder,
      home: _chatRoom,
      routes: () => _chatRoutes(count: 6, reservation: () => 'cancelled', readUpto: 6),
      act: (tester, snap) async {
        await _openAttach(tester);
        await tapAndSettle(tester, find.text('轉帳'));
        await snap('表12-5-6 轉帳');
      },
    );
  });

  testWidgets('表12-5-6 送出請款', variant: _ios, (tester) async {
    await shoot(
      tester,
      folder: _folder,
      home: _chatRoom,
      routes: () => _chatRoutes(count: 7, reservation: () => 'cancelled', readUpto: 6),
      act: (tester, snap) async {
        await snap('表12-5-6 送出請款');
      },
    );
  });

  // 5-7 完成轉帳
  testWidgets('表12-5-7 輸入交易密碼', variant: _ios, (tester) async {
    await shoot(
      tester,
      folder: _folder,
      home: _chatRoom,
      routes: () => _chatRoutes(count: 7, reservation: () => 'cancelled', readUpto: 7),
      act: (tester, snap) async {
        // 確認轉帳後伺服器要求付款驗證，由 VerificationService 開啟交易密碼面板
        VerificationService.navigatorKey = navigatorKey;
        VerificationService.paymentSummary = PaymentSummary(amount: 10, detail: S.transferP0(realUsers[_kj]!.nickname));
        unawaited(VerificationService.handle(const VerificationRequest(scope: 'payment', methods: ['pin', 'biometric'], message: '')));
        await settleReal(tester, const Duration(seconds: 2));
        await snap('表12-5-7 輸入交易密碼');
        VerificationService.paymentSummary = null;
      },
    );
  });

  testWidgets('表12-5-7 轉帳完成', variant: _ios, (tester) async {
    await shoot(
      tester,
      folder: _folder,
      home: _chatRoom,
      routes: () => _chatRoutes(count: 8, reservation: () => 'cancelled', readUpto: 8),
      act: (tester, snap) async {
        await snap('表12-5-7 轉帳完成');
      },
    );
  });

  // 5-8 AI 書籍顧問
  testWidgets('表12-5-8 AI 書籍顧問', variant: _ios, (tester) async {
    await shoot(
      tester,
      folder: _folder,
      home: AiBookChatScreen.new,
      routes: () => ManualApi.on('GET', '/ai/book-chat/session', (_) => {'session_id': 0, 'messages': <Object>[]}),
      act: (tester, snap) async {
        await snap('表12-5-8 AI 書籍顧問');
      },
    );
  });

  testWidgets('表12-5-8 AI 推薦書籍', variant: _ios, (tester) async {
    final book = bookJson(_vueBookId);
    await shoot(
      tester,
      folder: _folder,
      home: AiBookChatScreen.new,
      routes: () => ManualApi.on('GET', '/ai/book-chat/session', (_) => {
        'session_id': 31,
        'messages': [
          {'message_id': 61, 'role': 'user', 'content': '適合入門的程式設計書', 'books': <Object>[], 'created_at': todayAt(23, 16)},
          {
            'message_id': 62,
            'role': 'assistant',
            'content': '若您想從實作中學習程式設計，《${book['title']}》較符合需求，從 Vue 核心概念到前端專案逐步練習。'
                '不過它聚焦前端框架，並非通用程式入門教材。',
            'books': [
              {'book': book, 'reason': '以 Vue 基礎概念與實例帶領讀者完成前端專案'},
            ],
            'suggestions': ['適合零基礎的 Python 入門書', '想學網頁前端的入門書籍', '程式設計基礎教材推薦'],
            'created_at': todayAt(23, 16),
            'message_no': 'AC${_stamp(todayAt(23, 16))}0062',
            'feedback': null,
          },
        ],
      }),
      act: (tester, snap) async {
        await snap('表12-5-8 AI 推薦書籍');
      },
    );
  });

  // 5-9 防詐提醒
  testWidgets('表12-5-9 傳送聯絡方式前確認', variant: _ios, (tester) async {
    await shoot(
      tester,
      folder: _folder,
      me: _kjUser,
      home: _chatRoom,
      routes: () {
        _chatRoutes(viewer: _kj, count: 8, reservation: () => 'cancelled', readUpto: 8);
        ManualApi.on('POST', '/chat/rooms/$_room/messages', (_) => {
          'success': false,
          'code': 'RISK_CONFIRM_REQUIRED',
          'message': '訊息包含聯絡方式或付款資訊，請確認後再傳送',
        });
      },
      act: (tester, snap) async {
        await tester.enterText(_input, _lineText);
        await settleReal(tester, const Duration(milliseconds: 500));
        await tapAndSettle(tester, find.byIcon(Icons.send_rounded));
        await snap('表12-5-9 傳送聯絡方式前確認');
      },
    );
  });

  testWidgets('表12-5-9 防詐提醒、防詐須知', variant: _ios, (tester) async {
    await shoot(
      tester,
      folder: _folder,
      home: _chatRoom,
      routes: () => _chatRoutes(count: 9, reservation: () => 'cancelled', readUpto: 8),
      act: (tester, snap) async {
        await snap('表12-5-9 防詐提醒');
        await tapAndSettle(tester, find.text('防詐須知'));
        await snap('表12-5-9 防詐須知');
      },
    );
  });
}
