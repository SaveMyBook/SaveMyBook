// 第 12 章使用手冊第 3 節（上架書籍）、第 4 節（編輯與下架商品）、第 6 節（加入購物車與結帳）的截圖。
// 上架的書與原實機截圖相同：《HTML & CSS：網站設計建置優化之道》，照片用正式站上這本書的封面、封底與條碼頁實拍照。

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:savemybook_app/features/home/home_screen.dart';
import 'package:savemybook_app/features/orders/cart_screen.dart';
import 'package:savemybook_app/features/orders/order_history_screen.dart';
import 'package:savemybook_app/features/selling/ai_listing_assist.dart';
import 'package:savemybook_app/features/selling/book_manage_screen.dart';
import 'package:savemybook_app/features/selling/edit_book_detail_screen.dart';
import 'package:savemybook_app/features/selling/sell_book_detail_screen.dart';
import 'package:savemybook_app/features/selling/sell_book_screen.dart';
import 'package:savemybook_app/i18n/strings.dart';
import 'package:savemybook_app/models/ai.dart';
import 'package:savemybook_app/models/security.dart';
import 'package:savemybook_app/services/ai_status.dart';
import 'package:savemybook_app/services/verification_service.dart';
import 'package:savemybook_app/widgets/app_buttons.dart';
import 'package:savemybook_app/widgets/app_dialogs.dart';

import 'manual_api.dart';
import 'manual_host.dart';

const _s3 = '3. 上架書籍（賣家）';
const _s4 = '4. 編輯與下架商品';
const _s6 = '6. 加入購物車與結帳';

final _ios = TargetPlatformVariant.only(TargetPlatform.iOS);

/// 原圖上架的書（正式站上由雪喵上架的同一本），截圖中改由登入者 es 上架。
const _sourceBookId = 150;

/// es 上架後的新書籍。
const _myBookId = 151;

/// 原圖購物車中 KJ 的「行銷學」已不在架上，比照第 5 節改用 KJ 同價位（$450）的《用MBTI學韓文》。
const _cartBookId = 102;

/// 原圖結帳前的錢包餘額。
const _balance = 9590;

final _source = bookJson(_sourceBookId);
String get _isbn => _source['isbn'] as String;
String get _title => _source['title'] as String;

List<Map> get _sourceImages => (_source['book_images'] as List).cast<Map>();

String _imageOf(String type) => _sourceImages.firstWhere((i) => i['image_type'] == type)['image_url'] as String;

/// 上架流程拍下的三張照片（封面、封底、條碼）的本機路徑。
List<String> get _photoPaths => [for (final t in ['cover', 'back', 'other']) photoFile(_imageOf(t))!.path];

// es 的書籍在各張截圖之間的狀態（上架 → 編輯 → 取消上架）。
var _myPrice = 130;
var _myCondition = 'fair';
var _myStatus = 'on_sale';

Map<String, dynamic> _myBook() => {
  ..._source,
  'book_id': _myBookId,
  'seller_id': meId,
  'users': {'user_id': meId, 'nickname': meName, 'avatar_url': null},
  'price': '$_myPrice',
  'condition_level': _myCondition,
  'status': _myStatus,
  'view_count': 0,
  'in_cabinet': false,
  'deposit': null,
  'cabinet_access': {
    'mode': 'scan',
    'reason': null,
    'open_now': true,
    'open_time': '00:00',
    'close_time': '23:59',
    'available_doors': 4,
    'pre_deposit_doors': 2,
  },
  'created_at': ago(minutes: 3),
  'updated_at': ago(minutes: 3),
};

void _myBookRoutes() {
  ManualApi.handle((r) {
    if (r.method == 'GET' && r.path == '/books' && r.query['seller_id'] == '$meId') {
      return ok([if (r.query['status'] == null || r.query['status'] == 'all' || r.query['status'] == _myStatus) _myBook()]);
    }
    return null;
  });
  ManualApi.on('GET', '/books/$_myBookId', (_) => _myBook());
  ManualApi.on('GET', '/reports/against-me', (_) => <Object>[]);
}

const _aiStatusJson = {
  'support': true,
  'listing_assist': true,
  'recommend': true,
  'book_chat': true,
  'web_search': true,
  'consented': true,
  'providers_in_use': ['OpenAI'],
  'embedding_provider': 'OpenAI',
};

void _setAiConsented(bool consented) {
  // ignore: invalid_use_of_visible_for_testing_member
  AiStatus.debugSet(AiStatusInfo.fromJson({..._aiStatusJson, 'consented': consented}));
}

/// 第一步「AI 帶入」：只有 ISBN、沒有照片，書目取自這本書在正式站的真實資料。
Map<String, dynamic> _bookAssist() => {
  'mode': 'full',
  'fields': {
    'title': _title,
    'author': _source['author'],
    'publisher': _source['publisher'],
    'publish_date': _source['publish_date'],
    'publish_date_precision': 'day',
    'isbn': _isbn,
    'description': _source['description'],
  },
  'description_source': 'mixed',
  'category': {'category_id': _source['category_id'], 'name': '專業資訊', 'confidence': 0.93},
  'sources': [
    {'title': 'HTML&CSS', 'url': 'https://www.gotop.com.tw/books/BookDetails.aspx?Types=v&bn=ACU061200', 'domain': 'gotop.com.tw'},
    {'title': _title, 'url': 'https://www.tenlong.com.tw/products/$_isbn', 'domain': 'tenlong.com.tw'},
  ],
  'warnings': ['未提供照片與書況說明，無法判定實際書況；請補拍封面、書背、書口及內頁。'],
  'provider': 'openai',
  'model': 'gpt-5-nano',
  'suggestion_token': 'AS7K2M9QX',
};

/// 第二步「AI 帶入」：依三張照片與定價判斷書況與售價（內容比照原圖的 AI 建議）。
Map<String, dynamic> _conditionAssist() => {
  'mode': 'condition',
  'fields': <String, Object>{},
  'condition': {
    'level': 'fair',
    'confidence': 0.82,
    'reasons': ['封面有多處明顯刮痕與磨損', '封底可見多處擦痕及小刮痕', '封面下緣與書角有磨損痕跡'],
  },
  'price': {
    'suggested': 130,
    'min': 120,
    'max': 200,
    'original_price': 580,
    'original_price_verified': true,
    'currency': 'TWD',
    'by_condition': {'like_new': 200, 'good': 160, 'fair': 130, 'poor': 80},
    'reasons': ['依定價 580 元與書況「良好」約 2 至 3.5 成的比例計算', '原定價為新臺幣 580 元'],
  },
  'sources': [
    {'title': 'HTML&CSS', 'url': 'https://www.gotop.com.tw/books/BookDetails.aspx?Types=v&bn=ACU061200', 'domain': 'gotop.com.tw'},
    {'title': _title, 'url': 'https://www.tenlong.com.tw/products/$_isbn', 'domain': 'tenlong.com.tw'},
  ],
  'warnings': ['照片看不到內頁、書口、內頁書背連接處，建議補拍後再確認書況'],
  'provider': 'openai',
  'model': 'gpt-5-nano',
  'suggestion_token': 'AS3P8W2RT',
};

/// 原圖上架時人在新北高工（存放區域顯示「附近」），書櫃距離以新北高工為起點計算。
void _cabinetRoutes() {
  final here = realCabinets.firstWhere((c) => c['cabinet_id'] == _source['cabinet_id']);
  double rad(Object? deg) => double.parse('$deg') * math.pi / 180;
  num distance(Map c) {
    final dLat = rad(c['latitude']) - rad(here['latitude']);
    final dLng = rad(c['longitude']) - rad(here['longitude']);
    final a = math.pow(math.sin(dLat / 2), 2) + math.cos(rad(here['latitude'])) * math.cos(rad(c['latitude'])) * math.pow(math.sin(dLng / 2), 2);
    return math.max(30, (6371000 * 2 * math.asin(math.sqrt(a))).round());
  }

  ManualApi.on('GET', '/cabinets', (_) => [for (final c in realCabinets) {...c, 'distance_m': distance(c)}]);
}

void _sellRoutes() {
  _cabinetRoutes();
  ManualApi.on('GET', '/notifications/unread-count', (_) => {
    'unread_count': 2,
    'by_category': {'trade': 2, 'chat': 0, 'account': 0, 'service': 0, 'promotion': 0},
  });
  ManualApi.on('PUT', '/ai/consent', (_) => _aiStatusJson);
  ManualApi.on('POST', '/ai/listing-assist', (r) => r.body.contains('condition') ? _conditionAssist() : _bookAssist());
}

/// 讓 AI 上架輔助的請求停在等待回應（拍「AI 分析中」），呼叫 [release] 後才回應；其他請求照常交給 ManualApi。
class _HeldAssist {
  final _gate = Completer<void>();

  http.Client client() => MockClient((request) async {
    if (request.url.path.endsWith('/ai/listing-assist')) await _gate.future;
    final copy = http.Request(request.method, request.url)
      ..headers.addAll(request.headers)
      ..bodyBytes = request.bodyBytes;
    return http.Response.fromStream(await ManualApi.client().send(copy));
  });

  void release() {
    if (!_gate.isCompleted) _gate.complete();
  }
}

/// 放行後等 AI 建議面板出現：附照片的請求要讀取實體檔案，需要多次讓出真實事件迴圈。
Future<void> _waitForSheet(WidgetTester tester) async {
  for (var i = 0; i < 40 && find.byType(AiListingResultSheet).evaluate().isEmpty; i++) {
    await settleReal(tester, const Duration(milliseconds: 500));
  }
  await settleReal(tester, const Duration(seconds: 1));
}

Future<void> _openSell(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.add_rounded).last);
  await settleReal(tester, const Duration(seconds: 2));
}

Future<void> _enterIsbn(WidgetTester tester) async {
  final sell = find.byType(SellBookScreen);
  await tester.enterText(find.descendant(of: sell, matching: find.byType(TextField)).first, _isbn);
  FocusManager.instance.primaryFocus?.unfocus();
  await settleReal(tester, const Duration(seconds: 1));
}

// ---- 相機畫面（掃描 ISBN 條碼）----

const _scannerMethod = MethodChannel('dev.steenbakker.mobile_scanner/scanner/method');
const _scannerEvents = EventChannel('dev.steenbakker.mobile_scanner/scanner/event');

void _mockScanner(WidgetTester tester, {required bool on}) {
  final messenger = tester.binding.defaultBinaryMessenger;
  if (!on) {
    messenger.setMockMethodCallHandler(_scannerMethod, null);
    messenger.setMockStreamHandler(_scannerEvents, null);
    return;
  }
  messenger.setMockMethodCallHandler(_scannerMethod, (call) async => switch (call.method) {
    'state' => 1,
    'request' => true,
    'start' => {
      'textureId': 1,
      'numberOfCameras': 2,
      'currentTorchState': 0,
      'size': {'width': 1080.0, 'height': 1920.0},
    },
    _ => null,
  });
  messenger.setMockStreamHandler(_scannerEvents, MockStreamHandler.inline(onListen: (_, _) {}));
}

/// 相機預覽：App 的掃描頁在相機區域是黑底，以「濾色」把實拍照片疊進黑底，白色的標題、提示與掃描框維持不變；
/// 掃描頁上下的漸層暗角先畫在照片上。
class _CameraFeed extends CustomPainter {
  final ui.Image photo;

  const _CameraFeed(this.photo);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final w = photo.width.toDouble();
    final h = photo.height.toDouble();
    final scale = math.max(size.width / w, size.height / h);
    final dst = Rect.fromCenter(center: rect.center, width: w * scale, height: h * scale);
    canvas.saveLayer(rect, Paint()..blendMode = BlendMode.screen);
    canvas.drawImageRect(photo, Rect.fromLTWH(0, 0, w, h), dst, Paint()..filterQuality = FilterQuality.high);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, size.height),
          [const Color(0x80000000), const Color(0x00000000), const Color(0x00000000), const Color(0x80000000)],
          [0, 0.3, 0.7, 1],
        ),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CameraFeed oldDelegate) => oldDelegate.photo != photo;
}

// ---- 購物車與訂單 ----

/// 訂單成立於原圖付款的時間（當天 11:23）。
String _orderNo() {
  final now = DateTime.now();
  final d = DateTime(now.year, now.month, now.day, 11, 23, 18);
  String two(int n) => n.toString().padLeft(2, '0');
  return 'SMB${d.year}${two(d.month)}${two(d.day)}${two(d.hour)}${two(d.minute)}${two(d.second)}604927';
}

Map<String, dynamic> _cartOrder() {
  final b = bookJson(_cartBookId);
  final seller = b['seller_id'] as int;
  final price = b['price'];
  return {
    'order_id': 281,
    'order_no': _orderNo(),
    'buyer_id': meId,
    'seller_id': seller,
    'total_amount': price,
    'status': 'pending_deposit',
    'pickup_code': null,
    'cabinet_id': b['cabinet_id'],
    'created_at': todayAt(11, 23),
    'picked_up_at': null,
    'completed_at': null,
    'order_items': [
      {'item_id': 2811, 'book_id': _cartBookId, 'quantity': 1, 'unit_price': price, 'subtotal': price, 'books': b},
    ],
    'smart_cabinets': b['smart_cabinets'],
    'cabinet_slots': null,
    'users_orders_buyer_idTousers': userJson(meId),
    'users_orders_seller_idTousers': userJson(seller),
    'transaction_disputes': <Object>[],
    'doors': <String>[],
  };
}

var _paid = false;

void _cartRoutes() {
  ManualApi.on('GET', '/cart', (_) => [
    if (!_paid) {'cart_id': 41, 'book_id': _cartBookId, 'added_at': ago(minutes: 20), 'books': bookJson(_cartBookId)},
  ]);
  ManualApi.on('GET', '/cart/book-ids', (_) => [if (!_paid) _cartBookId]);
  ManualApi.on('GET', '/users/me/stats', (_) => {
    'balance': _paid ? _balance - 450 : _balance,
    'book_count': 0,
    'favorite_count': 3,
    'unread_notification_count': 0,
    'cart_count': _paid ? 0 : 1,
  });
  ManualApi.on('POST', '/orders/checkout', (_) {
    _paid = true;
    return [_cartOrder()];
  });
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

final _failures = <String>[];

/// act 內的例外會讓 shoot 無法還原 FlutterError.onError 而卡住十分鐘；改為記錄後於 shoot 結束再判定失敗。
Future<void> Function(WidgetTester, Snap) _safe(Future<void> Function(WidgetTester, Snap) body) => (tester, snap) async {
  try {
    await body(tester, snap);
  } catch (e, st) {
    _failures.add('$e');
    debugPrint('ACT FAILED: $e\n$st');
  }
};

void main() {
  setUpAll(setUpManual);
  setUp(_failures.clear);

  group(_s3, () {
    testWidgets('掃描 ISBN 條碼', variant: _ios, (tester) async {
      await shoot(
        tester,
        folder: _s3,
        routes: _sellRoutes,
        home: HomeScreen.new,
        act: _safe((tester, snap) async {
          _mockScanner(tester, on: true);
          final photo = (await loadPhoto(tester, _imageOf('back')))!;
          await _openSell(tester);
          await tester.tap(find.descendant(of: find.byType(SellBookScreen), matching: find.byIcon(Icons.qr_code_scanner_rounded)));
          await settleReal(tester, const Duration(seconds: 2));
          systemOverlay.value = [Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _CameraFeed(photo))))];
          await tester.pump();
          await snap('表12-3-1 掃描 ISBN 條碼');
          systemOverlay.value = const [];
          await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
          await settleReal(tester, const Duration(seconds: 1));
          _mockScanner(tester, on: false);
        }),
      );
      expect(_failures, isEmpty);
    });

    testWidgets('查詢書籍資料', variant: _ios, (tester) async {
      await shoot(
        tester,
        folder: _s3,
        routes: _sellRoutes,
        home: HomeScreen.new,
        act: _safe((tester, snap) async {
          await _openSell(tester);
          await _enterIsbn(tester);
          final lookup = Completer<void>();
          unawaited(runBusy(tester.element(find.byType(SellBookScreen)), () => lookup.future, message: S.lookingUpBook));
          await settle(tester, const Duration(seconds: 1));
          await snap('表12-3-1 查詢書籍資料');
          lookup.complete();
          await settle(tester, const Duration(seconds: 1));
        }),
      );
      expect(_failures, isEmpty);
    });

    testWidgets('AI 帶入書籍資料', variant: _ios, (tester) async {
      await shoot(
        tester,
        folder: _s3,
        routes: _sellRoutes,
        home: HomeScreen.new,
        act: _safe((tester, snap) async {
          await _openSell(tester);
          await _enterIsbn(tester);
          _setAiConsented(false);
          await tester.tap(find.descendant(of: find.byType(SellBookScreen), matching: find.byType(AiAssistButton)));
          await settleReal(tester, const Duration(seconds: 1));
          await snap('表12-3-1 AI 資料處理說明');

          final held = _HeldAssist();
          await http.runWithClient(() async {
            await tester.tap(find.text(S.agreeContinue));
            await settle(tester, const Duration(milliseconds: 1000));
            await snap('表12-3-2 AI 分析中');
            held.release();
            await _waitForSheet(tester);
          }, held.client);
          await snap('表12-3-2 AI 建議書籍資料');

          await tester.tap(find.textContaining(S.apply).last);
          await settleReal(tester, const Duration(seconds: 4));
          await snap('表12-3-2 帶入書籍資料');
          _setAiConsented(true);
        }),
      );
      expect(_failures, isEmpty);
    });

    testWidgets('上傳照片與 AI 建議售價、確認上架', variant: _ios, (tester) async {
      _setAiConsented(true);
      await shoot(
        tester,
        folder: _s3,
        routes: _sellRoutes,
        prefs: {
          'sell_draft_v1': jsonEncode({
            'step2': {
              'price': '250',
              'condition': 'good',
              'condition_touched': true,
              'cabinet_id': _source['cabinet_id'],
              'slots': _photoPaths,
              'extra': <String>[],
            },
            'saved_at': DateTime.now().toIso8601String(),
          }),
        },
        home: () => SellBookDetailScreen(
          isbn: _isbn,
          title: _title,
          author: _source['author'] as String,
          publisher: _source['publisher'] as String,
          publishDate: _source['publish_date'] as String,
          description: _source['description'] as String,
          categoryId: _source['category_id'] as int,
        ),
        act: _safe((tester, snap) async {
          _setAiConsented(true);
          await settleReal(tester, const Duration(seconds: 1));
          await snap('表12-3-3 上傳書籍照片');

          final detail = find.byType(SellBookDetailScreen);
          final held = _HeldAssist();
          await http.runWithClient(() async {
            await tester.tap(find.descendant(of: detail, matching: find.byType(AiAssistButton)));
            await settle(tester, const Duration(milliseconds: 5500));
            await snap('表12-3-3 AI 分析照片');
            held.release();
            await _waitForSheet(tester);
          }, held.client);
          // 目前已填售價時 App 預設只勾書況，原圖兩項皆勾選
          final sheet = find.byType(AiListingResultSheet);
          await tester.tap(find.descendant(of: sheet, matching: find.text('\$130')));
          await settle(tester, const Duration(milliseconds: 600));
          await snap('表12-3-3 AI 建議書況與售價');

          await tester.tap(find.textContaining(S.apply).last);
          await settleReal(tester, const Duration(seconds: 4));
          await snap('表12-3-4 套用書況與售價');

          await tester.tap(find.descendant(of: detail, matching: find.text(S.listBook)));
          await settleReal(tester, const Duration(seconds: 1));
          await snap('表12-3-4 確認上架');
        }),
      );
      expect(_failures, isEmpty);
    });

    testWidgets('上架完成', variant: _ios, (tester) async {
      _myPrice = 130;
      _myCondition = 'fair';
      _myStatus = 'on_sale';
      await shoot(
        tester,
        folder: _s3,
        routes: _myBookRoutes,
        home: BookManageScreen.new,
        act: _safe((tester, snap) async {
          await settleReal(tester, const Duration(seconds: 1));
          await snap('表12-3-4 上架完成');
        }),
      );
      expect(_failures, isEmpty);
    });
  });

  group(_s4, () {
    testWidgets('書籍管理與篩選', variant: _ios, (tester) async {
      _myPrice = 130;
      _myCondition = 'fair';
      _myStatus = 'on_sale';
      await shoot(
        tester,
        folder: _s4,
        routes: _myBookRoutes,
        home: BookManageScreen.new,
        act: _safe((tester, snap) async {
          await settleReal(tester, const Duration(seconds: 1));
          await snap('表12-4-1 書籍管理');
          await tester.tap(find.text(S.reportReviewing));
          await settleReal(tester, const Duration(seconds: 1));
          await snap('表12-4-1 依狀態篩選');
        }),
      );
      expect(_failures, isEmpty);
    });

    testWidgets('編輯書籍', variant: _ios, (tester) async {
      _myPrice = 130;
      _myCondition = 'fair';
      _myStatus = 'on_sale';
      await shoot(
        tester,
        folder: _s4,
        routes: () {
          _myBookRoutes();
          _cabinetRoutes();
          ManualApi.on('PUT', '/books/$_myBookId', (r) {
            final body = jsonDecode(r.body) as Map<String, dynamic>;
            _myPrice = body['price'] as int;
            _myCondition = body['condition_level'] as String;
            return {'book_id': _myBookId};
          });
        },
        home: BookManageScreen.new,
        act: _safe((tester, snap) async {
          await settleReal(tester, const Duration(seconds: 1));
          await tester.tap(find.widgetWithText(SmallActionButton, S.actionEdit));
          await settleReal(tester, const Duration(seconds: 2));
          await tester.tap(find.text(S.next));
          await settleReal(tester, const Duration(seconds: 2));

          await tester.tap(find.text(S.conditionFair));
          await settleReal(tester, const Duration(seconds: 1));
          await tester.tap(find.text(S.conditionLikeNew).last);
          await settleReal(tester, const Duration(seconds: 1));
          await tester.enterText(find.descendant(of: find.byType(EditBookDetailScreen), matching: find.byType(TextField)).first, '200');
          FocusManager.instance.primaryFocus?.unfocus();
          await settleReal(tester, const Duration(seconds: 1));
          await snap('表12-4-2 編輯書籍');

          await tester.tap(find.text(S.saveChanges));
          await settleReal(tester, const Duration(seconds: 1));
          await snap('表12-4-2 書籍已更新');
        }),
      );
      expect(_failures, isEmpty);
    });

    testWidgets('取消上架', variant: _ios, (tester) async {
      _myPrice = 200;
      _myCondition = 'like_new';
      _myStatus = 'on_sale';
      await shoot(
        tester,
        folder: _s4,
        routes: () {
          _myBookRoutes();
          ManualApi.on('DELETE', '/books/$_myBookId', (_) {
            _myStatus = 'removed';
            return {'book_id': _myBookId};
          });
        },
        home: BookManageScreen.new,
        act: _safe((tester, snap) async {
          await settleReal(tester, const Duration(seconds: 1));
          await tester.tap(find.widgetWithText(SmallActionButton, S.delist));
          await settleReal(tester, const Duration(seconds: 1));
          await snap('表12-4-3 確認取消上架');
          await tester.tap(find.text(S.delist).last);
          await settleReal(tester, const Duration(milliseconds: 1500));
          await snap('表12-4-3 已取消上架');
        }),
      );
      expect(_failures, isEmpty);
    });
  });

  group(_s6, () {
    testWidgets('購物車與交易密碼', variant: _ios, (tester) async {
      _paid = false;
      await shoot(
        tester,
        folder: _s6,
        routes: _cartRoutes,
        home: CartScreen.new,
        act: _safe((tester, snap) async {
          await settleReal(tester, const Duration(seconds: 1));
          await snap('表12-6-1 購物車');
          VerificationService.navigatorKey = navigatorKey;
          VerificationService.paymentSummary = PaymentSummary(
            amount: 450,
            detail: S.booksTotal(1, '450') + S.balanceAfterPaymentCoins('${_balance - 450}'),
          );
          unawaited(VerificationService.handle(const VerificationRequest(scope: 'payment', methods: ['pin'], message: '')));
          await settleReal(tester, const Duration(seconds: 2));
          await snap('表12-6-1 輸入交易密碼');
          VerificationService.paymentSummary = null;
          navigatorKey.currentState!.pop();
          await settleReal(tester, const Duration(seconds: 1));
        }),
      );
      expect(_failures, isEmpty);
    });

    testWidgets('付款成功', variant: _ios, (tester) async {
      _paid = false;
      await shoot(
        tester,
        folder: _s6,
        routes: _cartRoutes,
        home: CartScreen.new,
        act: _safe((tester, snap) async {
          await settleReal(tester, const Duration(seconds: 1));
          await tester.tap(find.text(S.checkOut));
          await settleReal(tester, const Duration(seconds: 2));
          await snap('表12-6-2 付款成功');
        }),
      );
      expect(_failures, isEmpty);
    });

    testWidgets('訂單紀錄', variant: _ios, (tester) async {
      _paid = true;
      await shoot(
        tester,
        folder: _s6,
        routes: () {
          _cartRoutes();
          ManualApi.handle((r) {
            if (r.method != 'GET' || r.path != '/orders') return null;
            final mine = r.query['role'] == 'buyer' && r.query['tab'] == OrderHistoryScreen.awaitingDeposit;
            return ok([if (mine) _cartOrder()]);
          });
        },
        home: () => OrderHistoryScreen(filter: OrderHistoryScreen.purchaseFilterAfterPayment(false)),
        act: _safe((tester, snap) async {
          await settleReal(tester, const Duration(seconds: 1));
          await snap('表12-6-2 訂單紀錄');
        }),
      );
      expect(_failures, isEmpty);
    });
  });
}
