// 第 12 章使用手冊第 7（智慧書櫃存書與取書）、8（前往書櫃）、9（訂單爭議）、11（客服與常見問題）節截圖：
// flutter test tool/manual_shots/s07_08_09_11_test.dart（只跑單張可加 --plain-name）。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

import 'package:savemybook_app/features/account/ai_support_screen.dart';
import 'package:savemybook_app/features/account/help_center_screen.dart';
import 'package:savemybook_app/features/account/support_ticket_screen.dart';
import 'package:savemybook_app/features/cabinet/cabinet_flow_screen.dart';
import 'package:savemybook_app/features/cabinet/cabinet_guide_screen.dart';
import 'package:savemybook_app/features/cabinet/cabinet_match_code_field.dart';
import 'package:savemybook_app/features/cabinet/cabinet_scanner_view.dart';
import 'package:savemybook_app/features/home/notification_screen.dart';
import 'package:savemybook_app/features/orders/dispute_screen.dart';
import 'package:savemybook_app/features/orders/order_detail_screen.dart';
import 'package:savemybook_app/features/orders/pickup_book_screen.dart';
import 'package:savemybook_app/features/orders/pickup_success_screen.dart';
import 'package:savemybook_app/features/orders/widgets/pickup_ready_card.dart';
import 'package:savemybook_app/models/cabinet.dart';
import 'package:savemybook_app/models/order.dart';
import 'package:savemybook_app/models/user.dart';

import '../web_shots/covers.dart' show paintCameraScene;
import 'manual_api.dart';
import 'manual_host.dart';
import 's07_08_09_11_data.dart';
import 's07_08_09_11_ui.dart';

const _s7 = '7. 智慧書櫃存書與取書';
const _s8 = '8. 前往書櫃（交通資訊）';
const _s9 = '9. 訂單爭議';
const _s11 = '11. 客服與常見問題';

final _ios = TargetPlatformVariant.only(TargetPlatform.iOS);

Map<String, dynamic> Function() _currentSession = () => cabinetSessionJson('order_deposit', 'matching', remainingMs: 52000);

CabinetSession _session(String kind, String status, {int? remainingMs, Map<String, dynamic>? result, bool done = false}) {
  _currentSession = () => cabinetSessionJson(kind, status, remainingMs: remainingMs, result: result, done: done);
  return CabinetSession.fromJson(_currentSession());
}

void _cabinetRoutes() {
  ManualApi.on('GET', '/cabinet-sessions/active', (_) => null);
  ManualApi.on('GET', '/cabinet-sessions/:no', (_) => _currentSession());
  ManualApi.on('GET', '/orders', (r) => r.query['tab'] == 'pending_pickup' ? [cabOrder('deposited')] : <Object>[]);
  ManualApi.on('GET', '/orders/:id', (_) => cabOrder('deposited'));
}

final _seller = User.fromJson(userJson(cabSellerId));

String get _cabinetName => cabinetJson(cabCabinetId)['cabinet_name'] as String;

Future<void> _scanCamera(WidgetTester tester) async {
  final scanner = tester.getRect(find.byType(CabinetScannerView));
  final frame = tester.getRect(find.byWidgetPredicate((w) => w is CustomPaint && w.painter is ScanFramePainter));
  final paste = find.byType(CabinetPasteButton);
  final camera = paintCameraScene(scanner.size, frame.center - scanner.topLeft, frame.width, name: _cabinetName);
  systemOverlay.value = [
    Positioned.fill(
      child: CameraLayer(image: camera, rect: scanner, blackouts: [if (paste.evaluate().isNotEmpty) tester.getRect(paste).inflate(6)]),
    ),
  ];
  await tester.pump();
}

Future<void> _pickupCamera(WidgetTester tester) async {
  final frame = tester.getRect(find.byWidgetPredicate((w) => w is CustomPaint && w.painter.runtimeType.toString() == '_CornerFramePainter'));
  final area = Rect.fromLTRB(0, topInset + 56, logicalSize.width, logicalSize.height);
  final paste = find.byType(CabinetPasteButton);
  final panel = find.byType(PickupReadyCard);
  final camera = paintCameraScene(area.size, frame.center - area.topLeft, frame.width, name: _cabinetName, bookInA01: true);
  systemOverlay.value = [
    Positioned.fill(
      child: CameraLayer(
        image: camera,
        rect: area,
        blackouts: [if (paste.evaluate().isNotEmpty) tester.getRect(paste).inflate(6)],
        exclude: [if (panel.evaluate().isNotEmpty) RRect.fromRectAndRadius(tester.getRect(panel), const Radius.circular(18))],
      ),
    ),
  ];
  await tester.pump();
}

Future<void> _match(WidgetTester tester, Snap snap, String file) async {
  await tester.enterText(find.descendant(of: find.byType(CabinetFlowScreen), matching: find.byType(TextField)), '25');
  FocusManager.instance.primaryFocus?.unfocus();
  await settle(tester, const Duration(milliseconds: 800));
  await snap(file);
  expect(find.byType(CabinetMatchCodeField), findsOneWidget);
}

Map<String, dynamic> _disOrder(String status, {List<Map<String, dynamic>> disputes = const []}) => orderJson(
  id: disOrderId,
  no: disOrderNo,
  bookId: disBookId,
  cabinetId: disCabinetId,
  status: status,
  createdAt: todayAt(23, 22, daysAgo: 1),
  disputes: disputes,
);

void _transitRoutes() {
  ManualApi.on('GET', '/orders/:id', (_) => _disOrder('deposited'));
  ManualApi.on('GET', '/cabinets/:id/nearby', (_) => cabinetNearby());
  ManualApi.on('GET', '/cabinets/mrt-stations', (_) => {'stations': mrtStations});
  ManualApi.on('GET', '/cabinets/mrt-fares', (r) => mrtFares(r.query['from'] ?? departureStation));
}

// 複製地址等操作會呼叫系統剪貼簿，測試環境沒有對應的平台實作。
void _mockPlatform(WidgetTester tester) =>
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => null);

Widget _guide() {
  final c = cabinetJson(disCabinetId);
  return CabinetGuideScreen(cabinetId: disCabinetId, name: c['cabinet_name'] as String, address: c['address'] as String, openHours: '');
}

Future<void> _scrollToTop(WidgetTester tester, Finder title, {double offset = 0}) async {
  for (var i = 0; i < 20 && title.evaluate().isEmpty; i++) {
    await scrollBy(tester, 300);
  }
  await Scrollable.ensureVisible(tester.element(title), alignment: 0);
  await scrollBy(tester, offset);
}

// ---- 第 9 節 ----

const _disputeReason = '書內頁有多本缺頁，未如實告知';

Map<String, dynamic> _pendingDispute() => {
  'dispute_id': 57,
  'order_id': disOrderId,
  'applicant_id': meId,
  'reason': _disputeReason,
  'status': 'pending',
  'result': null,
  'created_at': agoNow(minutes: 1),
};

void _disputeRoutes() {
  ManualApi.on('GET', '/orders/:id', (_) => _disOrder('deposited'));
  ManualApi.on('GET', '/orders/by-no/:no', (_) => _disOrder('deposited'));
}

/// 相簿選取：直接回傳書籍的實拍照片（略過 iOS 相片選取畫面）。
class _FakePicker extends ImagePickerPlatform {
  final String path;

  _FakePicker(this.path);

  @override
  bool supportsImageSource(ImageSource source) => source == ImageSource.gallery;

  @override
  Future<List<XFile>> getMultiImageWithOptions({MultiImagePickerOptions options = const MultiImagePickerOptions()}) async => [XFile(path)];

  @override
  Future<XFile?> getImageFromSource({required ImageSource source, ImagePickerOptions options = const ImagePickerOptions()}) async =>
      XFile(path);
}

Future<void> _fillDispute(WidgetTester tester) async {
  final images = (bookJson(disBookId)['book_images'] as List).cast<Map>();
  final back = images.firstWhere((i) => i['image_type'] == 'back')['image_url'] as String;
  ImagePickerPlatform.instance = _FakePicker(photoFile(back)!.path);
  await tester.enterText(find.byType(TextField).at(1), _disputeReason);
  FocusManager.instance.primaryFocus?.unfocus();
  await settle(tester, const Duration(milliseconds: 500));
  await tester.tap(find.byIcon(Icons.add_photo_alternate_outlined));
  await settleReal(tester, const Duration(seconds: 2));
  for (var i = 0; i < 30; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.tap(find.text('完成').last);
  for (var i = 0; i < 30; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(milliseconds: 100));
  }
  await settle(tester, const Duration(seconds: 1));
}

List<Map<String, dynamic>> _notifications() => [
  {
    'notification_id': 913,
    'category': 'trade',
    'type': 'order',
    'title': '爭議案件已裁決',
    'content': '訂單 $disOrderNo 裁決退款，${bookJson(disBookId)['price']} 代幣已退回您的錢包。',
    'related_id': disOrderId,
    'related_type': 'order',
    'is_read': false,
    'created_at': agoNow(minutes: 0),
  },
  {
    'notification_id': 905,
    'category': 'trade',
    'type': 'order',
    'title': '書籍已存入書櫃',
    'content': '訂單 $otherOrderNo 的書籍已存入「${cabinetJson(3)['cabinet_name']}」書櫃，請於營業時間內至書櫃以 App 掃描 QR Code 取書。',
    'related_id': 401,
    'related_type': 'order',
    'is_read': false,
    'created_at': agoNow(minutes: 6),
  },
  {
    'notification_id': 902,
    'category': 'service',
    'type': 'system',
    'title': '書櫃手動回報待確認',
    'content': '「${cabinetJson(3)['cabinet_name']}」於裝置離線期間收到存書的手動回報（訂單 $otherOrderNo），請確認後於後台處理。',
    'related_id': null,
    'related_type': null,
    'is_read': false,
    'created_at': agoNow(minutes: 7),
  },
  {
    'notification_id': 897,
    'category': 'account',
    'type': 'system',
    'title': '已新增通行密鑰',
    'content': '您的帳號已新增一組通行密鑰，若非本人操作請立即至帳號安全移除並變更密碼。',
    'related_id': null,
    'related_type': null,
    'is_read': false,
    'created_at': agoNow(minutes: 40),
  },
];

void _notificationRoutes() {
  ManualApi.on('GET', '/notifications', (r) {
    final category = r.query['category'];
    final list = [for (final n in _notifications()) if (category == null || n['category'] == category) n];
    return {...ok(list, pagination: {'total': list.length, 'page': 1, 'limit': 20, 'total_pages': 1}), 'unread_count': 18};
  });
  ManualApi.on('GET', '/notifications/unread-count', (_) => {
    'unread_count': 18,
    'by_category': {'trade': 8, 'chat': 0, 'account': 2, 'service': 8, 'promotion': 0},
  });
}

// ---- 第 11 節 ----

const _listingAnswer =
    '在 App 填寫書名、售價與書況，並上傳書籍照片即可上架；每本最多 10 張，售價須大於 0 且不超過 99,999 代幣。也可輸入或掃描 ISBN 自動帶入書目資料。'
    '上架後系統會自動檢查內容；部分書籍可能送交人工審核，審核期間不會公開販售。';

Map<String, dynamic> _aiSession() => {
  'session_id': 21,
  'status': 'open',
  'messages': [
    {'message_id': 301, 'role': 'user', 'content': '如何上架書籍？', 'created_at': agoNow(minutes: 1)},
    {
      'message_id': 302,
      'role': 'assistant',
      'content': _listingAnswer,
      'message_no': 'AS7KD2M9Q',
      'suggestions': ['上架後多久會公開？', '書籍審核中代表什麼？'],
      'created_at': agoNow(minutes: 1),
    },
  ],
};

const _ticketId = 64;

Map<String, dynamic> _ticket({required String status, required List<Map<String, dynamic>> messages}) => {
  'ticket_id': _ticketId,
  'subject': 'AI 客服轉接：如何上架書籍？',
  'category': 'trade',
  'status': status,
  'message_count': messages.length,
  'last_message': messages.last['content'],
  'user': {'nickname': meName, 'avatar_url': null},
  'updated_at': messages.last['created_at'],
  'messages': messages,
};

Map<String, dynamic> _ticketMessage(int id, String content, {required int minutesAgo, bool staff = false}) => {
  'message_id': id,
  'content': content,
  'is_staff': staff,
  'sender': {'nickname': staff ? '客服' : meName, 'avatar_url': null},
  'created_at': agoNow(minutes: minutesAgo),
  'attachments': <Object>[],
};

String get _transcript => '以下為 AI 客服對話紀錄：\n使用者：如何上架書籍？\nAI 客服：$_listingAnswer';

void _ticketRoutes(Map<String, dynamic> ticket) => ManualApi.on('GET', '/support/tickets/:id', (_) => ticket);

void main() {
  setUpAll(setUpManual);

  group(_s7, () {
    testWidgets('表12-7-1 掃描書櫃 QR Code', variant: _ios, (tester) async {
      await shoot(
        tester,
        folder: _s7,
        me: _seller,
        routes: _cabinetRoutes,
        home: () => const CabinetFlowScreen(scanInput: Stream.empty()),
        act: (tester, snap) async {
          await _scanCamera(tester);
          await snap('表12-7-1 掃描書櫃 QR Code');
        },
      );
    });

    testWidgets('表12-7-1 確認存書項目', variant: _ios, (tester) async {
      await shoot(
        tester,
        folder: _s7,
        me: _seller,
        routes: _cabinetRoutes,
        home: () => CabinetFlowScreen(resume: _session('order_deposit', 'selecting', remainingMs: 56000)),
        act: (tester, snap) => snap('表12-7-1 確認存書項目'),
      );
    });

    testWidgets('表12-7-1 輸入書櫃螢幕數字', variant: _ios, (tester) async {
      await shoot(
        tester,
        folder: _s7,
        me: _seller,
        routes: _cabinetRoutes,
        home: () => CabinetFlowScreen(resume: _session('order_deposit', 'matching', remainingMs: 52000)),
        act: (tester, snap) => _match(tester, snap, '表12-7-1 輸入書櫃螢幕數字'),
      );
    });

    testWidgets('表12-7-2 櫃門已開啟', variant: _ios, (tester) async {
      await shoot(
        tester,
        folder: _s7,
        me: _seller,
        routes: _cabinetRoutes,
        home: () => CabinetFlowScreen(resume: _session('order_deposit', 'open', remainingMs: 29000)),
        act: (tester, snap) => snap('表12-7-2 櫃門已開啟'),
      );
    });

    testWidgets('表12-7-2 存書完成', variant: _ios, (tester) async {
      await shoot(
        tester,
        folder: _s7,
        me: _seller,
        routes: _cabinetRoutes,
        home: () => CabinetFlowScreen(
          resume: _session('order_deposit', 'completed', result: {'outcome': 'completed', 'code': 'COMPLETED', 'message': ''}, done: true),
        ),
        act: (tester, snap) => snap('表12-7-2 存書完成'),
      );
    });

    testWidgets('表12-7-3 掃描書櫃取書', variant: _ios, (tester) async {
      await shoot(
        tester,
        folder: _s7,
        routes: _cabinetRoutes,
        home: () => const PickupBookScreen(isActive: true, scanInput: Stream.empty()),
        act: (tester, snap) async {
          await settleReal(tester, const Duration(seconds: 1));
          await _pickupCamera(tester);
          await snap('表12-7-3 掃描書櫃取書');
        },
      );
    });

    testWidgets('表12-7-3 確認取書項目', variant: _ios, (tester) async {
      await shoot(
        tester,
        folder: _s7,
        routes: _cabinetRoutes,
        home: () => CabinetFlowScreen(resume: _session('pickup', 'selecting', remainingMs: 56000)),
        act: (tester, snap) => snap('表12-7-3 確認取書項目'),
      );
    });

    testWidgets('表12-7-3 輸入書櫃螢幕數字', variant: _ios, (tester) async {
      await shoot(
        tester,
        folder: _s7,
        routes: _cabinetRoutes,
        home: () => CabinetFlowScreen(resume: _session('pickup', 'matching', remainingMs: 52000)),
        act: (tester, snap) => _match(tester, snap, '表12-7-3 輸入書櫃螢幕數字'),
      );
    });

    testWidgets('表12-7-4 櫃門已開啟', variant: _ios, (tester) async {
      await shoot(
        tester,
        folder: _s7,
        routes: _cabinetRoutes,
        home: () => CabinetFlowScreen(resume: _session('pickup', 'open', remainingMs: 25000)),
        act: (tester, snap) => snap('表12-7-4 櫃門已開啟'),
      );
    });

    testWidgets('表12-7-4 取書完成', variant: _ios, (tester) async {
      await shoot(
        tester,
        folder: _s7,
        routes: _cabinetRoutes,
        home: () => PickupSuccessScreen(order: Order.fromJson(cabOrder('deposited', pickedUpAt: agoNow(minutes: 0)))),
        act: (tester, snap) => snap('表12-7-4 取書完成'),
      );
    });
  });

  group(_s8, () {
    testWidgets('表12-8-1 訂單取書資訊', variant: _ios, (tester) async {
      await shoot(
        tester,
        folder: _s8,
        routes: _transitRoutes,
        home: () => OrderDetailScreen(order: Order.fromJson(_disOrder('deposited'))),
        act: (tester, snap) async {
          await scrollBy(tester, 5000);
          await snap('表12-8-1 訂單取書資訊');
        },
      );
    });

    testWidgets('表12-8-1 捷運與票價', variant: _ios, (tester) async {
      await shoot(
        tester,
        folder: _s8,
        routes: _transitRoutes,
        prefs: const {'transit.departure_station': departureStation},
        home: _guide,
        act: (tester, snap) => snap('表12-8-1 捷運與票價'),
      );
    });

    testWidgets('表12-8-1 導航至書櫃', variant: _ios, (tester) async {
      await shoot(
        tester,
        folder: _s8,
        routes: _transitRoutes,
        prefs: const {'transit.departure_station': departureStation},
        home: _guide,
        act: (tester, snap) async {
          systemOverlay.value = [const Positioned.fill(child: MapsTransitScreen())];
          await tester.pump();
          await snap('表12-8-1 導航至書櫃');
        },
      );
    });

    testWidgets('表12-8-2 複製地址', variant: _ios, (tester) async {
      await shoot(
        tester,
        folder: _s8,
        routes: _transitRoutes,
        prefs: const {'transit.departure_station': departureStation},
        home: _guide,
        act: (tester, snap) async {
          _mockPlatform(tester);
          await tester.tap(find.text('複製地址'));
          await settle(tester, const Duration(milliseconds: 700));
          await snap('表12-8-2 複製地址');
        },
      );
    });

    testWidgets('表12-8-2 公車到站資訊', variant: _ios, (tester) async {
      await shoot(
        tester,
        folder: _s8,
        routes: _transitRoutes,
        prefs: const {'transit.departure_station': departureStation},
        home: _guide,
        act: (tester, snap) async {
          await _scrollToTop(tester, find.text('公車'), offset: -20);
          await snap('表12-8-2 公車到站資訊');
        },
      );
    });

    testWidgets('表12-8-2 YouBike 與開車資訊', variant: _ios, (tester) async {
      await shoot(
        tester,
        folder: _s8,
        routes: _transitRoutes,
        prefs: const {'transit.departure_station': departureStation},
        home: _guide,
        act: (tester, snap) async {
          await _scrollToTop(tester, find.text('YouBike 2.0'), offset: -20);
          await snap('表12-8-2 YouBike 與開車資訊');
        },
      );
    });
  });

  group(_s9, () {
    testWidgets('表12-9-1 訂單詳情', variant: _ios, (tester) async {
      await shoot(
        tester,
        folder: _s9,
        routes: _disputeRoutes,
        home: () => OrderDetailScreen(order: Order.fromJson(_disOrder('deposited'))),
        act: (tester, snap) async {
          await scrollBy(tester, 5000);
          await snap('表12-9-1 訂單詳情');
        },
      );
    });

    testWidgets('表12-9-1 填寫爭議說明', variant: _ios, (tester) async {
      await shoot(
        tester,
        folder: _s9,
        routes: _disputeRoutes,
        home: () => const DisputeScreen(orderNo: disOrderNo),
        act: (tester, snap) async {
          await _fillDispute(tester);
          await snap('表12-9-1 填寫爭議說明');
        },
      );
    });

    testWidgets('表12-9-1 送出爭議申請', variant: _ios, (tester) async {
      await shoot(
        tester,
        folder: _s9,
        routes: _disputeRoutes,
        home: () => const DisputeScreen(orderNo: disOrderNo),
        act: (tester, snap) async {
          await _fillDispute(tester);
          await tester.tap(find.text('送出申請'));
          await settle(tester, const Duration(seconds: 1));
          await snap('表12-9-1 送出爭議申請');
        },
      );
    });

    testWidgets('表12-9-2 爭議處理中', variant: _ios, (tester) async {
      final order = _disOrder('refunding', disputes: [_pendingDispute()]);
      await shoot(
        tester,
        folder: _s9,
        routes: () => ManualApi.on('GET', '/orders/:id', (_) => order),
        home: () => OrderDetailScreen(order: Order.fromJson(order)),
        act: (tester, snap) => snap('表12-9-2 爭議處理中'),
      );
    });

    testWidgets('表12-9-2 裁決結果通知', variant: _ios, (tester) async {
      await shoot(
        tester,
        folder: _s9,
        routes: _notificationRoutes,
        home: NotificationScreen.new,
        act: (tester, snap) async {
          await tester.tap(find.text('爭議案件已裁決'));
          await settle(tester, const Duration(seconds: 1));
          await snap('表12-9-2 裁決結果通知');
        },
      );
    });
  });

  group(_s11, () {
    testWidgets('表12-11-1 客服中心', variant: _ios, (tester) async {
      await shoot(tester, folder: _s11, home: HelpCenterScreen.new, act: (tester, snap) => snap('表12-11-1 客服中心'));
    });

    testWidgets('表12-11-1 AI 客服', variant: _ios, (tester) async {
      await shoot(
        tester,
        folder: _s11,
        routes: () => ManualApi.on('GET', '/ai/support/session', (_) => _aiSession()),
        home: AiSupportScreen.new,
        act: (tester, snap) => snap('表12-11-1 AI 客服'),
      );
    });

    testWidgets('表12-11-2 轉接客服人員', variant: _ios, (tester) async {
      await shoot(
        tester,
        folder: _s11,
        routes: () => _ticketRoutes(_ticket(status: 'open', messages: [_ticketMessage(1, _transcript, minutesAgo: 0)])),
        home: () => const TicketDetailScreen(ticketId: _ticketId),
        act: (tester, snap) => snap('表12-11-2 轉接客服人員'),
      );
    });

    testWidgets('表12-11-2 補充說明', variant: _ios, (tester) async {
      await shoot(
        tester,
        folder: _s11,
        routes: () => _ticketRoutes(
          _ticket(
            status: 'open',
            messages: [_ticketMessage(1, _transcript, minutesAgo: 1), _ticketMessage(2, '麻煩詳細講解操作流程', minutesAgo: 1)],
          ),
        ),
        home: () => const TicketDetailScreen(ticketId: _ticketId),
        act: (tester, snap) => snap('表12-11-2 補充說明'),
      );
    });

    testWidgets('表12-11-2 客服人員回覆', variant: _ios, (tester) async {
      await shoot(
        tester,
        folder: _s11,
        routes: () => _ticketRoutes(
          _ticket(
            status: 'pending',
            messages: [
              _ticketMessage(1, _transcript, minutesAgo: 3),
              _ticketMessage(2, '麻煩詳細講解操作流程', minutesAgo: 2),
              _ticketMessage(3, '下方+號點選即可進行上架動作。', minutesAgo: 0, staff: true),
            ],
          ),
        ),
        home: () => const TicketDetailScreen(ticketId: _ticketId),
        act: (tester, snap) => snap('表12-11-2 客服人員回覆'),
      );
    });
  });
}
