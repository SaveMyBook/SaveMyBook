// 系統簡介影片第二版「付款暫管」「驗收售後」段落：flutter test tool/video_shots/pay_after_test.dart
// 買家 es 以交易密碼或 Face ID 付款購買《HTML & CSS》，款項列為賣家雪喵的待撥款項；es 在新北高工書櫃取書，
// 滿 24 小時後撥入雪喵的錢包。另拍爭議申請與管理員的 AI 爭議分析、AI 客服與轉接，以及七項 AI 服務中「書籍資料補齊」的畫面。

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
// ignore: depend_on_referenced_packages
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

import 'package:savemybook_app/features/account/ai_support_screen.dart';
import 'package:savemybook_app/features/account/wallet_screen.dart';
import 'package:savemybook_app/features/admin/admin_dispute_screen.dart';
import 'package:savemybook_app/features/admin/dispute_ai_panel.dart';
import 'package:savemybook_app/features/books/book_detail_screen.dart';
import 'package:savemybook_app/features/cabinet/cabinet_flow_screen.dart';
import 'package:savemybook_app/features/chat/widgets/chat_bubbles.dart';
import 'package:savemybook_app/features/orders/dispute_screen.dart';
import 'package:savemybook_app/features/orders/pickup_success_screen.dart';
import 'package:savemybook_app/features/selling/pending_income_screen.dart';
import 'package:savemybook_app/i18n/strings.dart';
import 'package:savemybook_app/models/book.dart';
import 'package:savemybook_app/models/cabinet.dart';
import 'package:savemybook_app/models/order.dart';
import 'package:savemybook_app/models/user.dart';
import 'package:savemybook_app/services/api_service.dart';
import 'package:savemybook_app/services/verification_service.dart';
import 'package:savemybook_app/widgets/animations.dart';
import 'package:savemybook_app/widgets/app_forms.dart';
import 'package:savemybook_app/widgets/pin_pad.dart';
import 'package:savemybook_app/widgets/state_views.dart';

import '../manual_shots/manual_api.dart';
import '../manual_shots/manual_host.dart' show IosFaceIdHud, logicalSize, pixelRatio;
import 'video_data.dart';
import 'video_host.dart';

final _ios = TargetPlatformVariant.only(TargetPlatform.iOS);

User get _seller => User.fromJson(userJson(sellerId));
User get _admin => User.fromJson(userJson(meId, extra: {'role': 'admin'}));

// ───────────── 訂單 ─────────────

DateTime _at(int daysAgo, int hour, int minute, [int second = 0]) {
  final d = DateTime.now().subtract(Duration(days: daysAgo));
  return DateTime(d.year, d.month, d.day, hour, minute, second);
}

String _iso(DateTime local) => local.toUtc().toIso8601String();

String _two(int n) => n.toString().padLeft(2, '0');

/// 訂單編號格式比照伺服器：SMB + 年月日時分秒 + 6 位亂數。
String _orderNo(DateTime t, int tail) =>
    'SMB${t.year}${_two(t.month)}${_two(t.day)}${_two(t.hour)}${_two(t.minute)}${_two(t.second)}$tail';

/// 劇情訂單的時間與編號見 video_data.dart（各段共用）。
final _paidAt = storyPaidAt;
final _pickedAt = storyPickedAt;
const _orderId = storyOrderId;
final _storyOrderNo = storyOrderNo;
const _door = 'A01';
int get _price => int.parse('${storyBook['price']}');

Map<String, dynamic> _order(String status, {String? pickedUpAt, List<Map<String, dynamic>> disputes = const []}) => {
  'order_id': _orderId,
  'order_no': _storyOrderNo,
  'buyer_id': buyerId,
  'seller_id': sellerId,
  'total_amount': '$_price',
  'status': status,
  'pickup_code': null,
  'cabinet_id': cabinetId,
  'created_at': _iso(_paidAt),
  'deposited_at': status == 'pending_deposit' ? null : _iso(storyDepositedAt),
  'picked_up_at': pickedUpAt,
  'completed_at': null,
  'order_items': [
    {'item_id': _orderId * 10, 'book_id': storyBookId, 'quantity': 1, 'unit_price': '$_price', 'subtotal': '$_price', 'books': storyBook},
  ],
  'smart_cabinets': cabinetJson(cabinetId),
  'cabinet_slots': {'slot_id': _orderId, 'slot_number': _door},
  'users_orders_buyer_idTousers': userJson(buyerId),
  'users_orders_seller_idTousers': userJson(sellerId),
  'transaction_disputes': disputes,
  'doors': const [_door],
};

// ───────────── 付款 ─────────────

/// 買家 es 的錢包：付款前 1,280 代幣（與 manual_api 的會員統計一致）。
const _buyerBalance = 1280;

/// 付款當下（兩天前 14:30）雪喵尚未存書：書不在書櫃，付款後訂單為「待存書」，15:12 才存入 A01。
Map<String, dynamic> get _payBook => {...storyBook, 'in_cabinet': false};

void _payRoutes() {
  ManualApi.on('GET', '/wallet', (_) => {
    'balance': _buyerBalance,
    'frozen_amount': 0,
    'total_income': 0,
    'total_expense': 0,
    'pending_income': 0,
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
  ManualApi.on('POST', '/security/verify', (_) => {'verify_token': 'video-verify-token'});
  ManualApi.on('GET', '/books/$storyBookId', (_) => _payBook);
  ManualApi.on('POST', '/orders/buy-now', (_) => [_order('pending_deposit')]);
}

/// 停在等待回應的請求（不經 video_host 的 holdApi：結帳請求要另外回應 403，須用自己的連線）。
final _gates = <String, Completer<void>>{};

/// 結帳時正式伺服器先回應需要付款驗證（403 VERIFICATION_REQUIRED），App 驗證後帶 X-Verify-Token 重送。
http.Client _checkoutClient() => MockClient((request) async {
  final path = request.url.path.replaceFirst('/api', '');
  final key = '${request.method} $path';
  final verified = request.headers.keys.any((k) => k.toLowerCase() == 'x-verify-token');
  if (key == 'POST /orders/buy-now' && !verified) {
    return http.Response(
      jsonEncode({
        'success': false,
        'code': 'VERIFICATION_REQUIRED',
        'message': '請輸入交易密碼',
        'verification': {
          'scope': 'payment',
          'methods': ['pin', 'biometric'],
        },
      }),
      403,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }
  final gate = _gates[key];
  if (gate != null) await gate.future;
  final copy = http.Request(request.method, request.url)
    ..headers.addAll(request.headers)
    ..bodyBytes = request.bodyBytes;
  return http.Response.fromStream(await ManualApi.client().send(copy));
});

/// 書籍詳情按「直接購買」→ 書已在書櫃，確認購買 → 立即付款。
Future<void> _buyNow(WidgetTester tester) async {
  await http.runWithClient(() => tester.tap(find.text(S.buyNow2).hitTestable().first), _checkoutClient);
  await settleReal(tester, const Duration(seconds: 2));
  // 書已在書櫃時才會先確認購買；劇情中付款當下尚未存書，直接進入付款驗證
  if (find.text(S.payNow).evaluate().isNotEmpty) await tester.tap(find.text(S.payNow).last);
  await tester.pump();
}

Future<void> _tapDigit(WidgetTester tester, String d) async {
  await tester.tap(find.descendant(of: find.byType(NumberPad), matching: find.text(d)));
  await settle(tester, const Duration(milliseconds: 400));
}

// ───────────── 錢包 ─────────────

/// 雪喵的錢包紀錄：與第 12 章 10-1 代幣中心截圖相同（真實書籍的購買與退款），撥款後最上方多一筆「賣出」。
List<Map<String, dynamic>> _transactions({required bool paid}) {
  var id = 40;
  var balance = 0;
  final rows = <Map<String, dynamic>>[];
  void t(String type, int amount, String description, DateTime at, {int? bookId, String? orderNo, int? orderId}) {
    balance += amount;
    rows.add({
      'txn_id': ++id,
      'txn_no': 'TX${(id * 7919).toRadixString(36).toUpperCase()}Q${id}M',
      'type': type,
      'amount': amount,
      'balance_after': balance,
      'description': description,
      'created_at': _iso(at),
      'orders': orderNo == null
          ? null
          : {
              'order_id': orderId ?? id,
              'order_no': orderNo,
              'order_items': [
                {'books': bookJson(bookId!)},
              ],
            },
    });
  }

  final halfBlue = _orderNo(_at(6, 14, 6, 41), 528317);
  final powerPoint = _orderNo(_at(6, 20, 12, 8), 904265);
  final brainwash = _orderNo(_at(3, 10, 25, 37), 361904);
  final infoCancelled = _orderNo(_at(2, 23, 33, 11), 737248);
  final info = _orderNo(_at(2, 23, 34, 38), 118889);
  t('admin_adjust', 10000, '管理員調整：代幣儲值', _at(7, 9, 30));
  t('purchase', -140, '購買訂單 $halfBlue', _at(6, 14, 6, 41), bookId: 144, orderNo: halfBlue);
  t('purchase', -220, '購買訂單 $powerPoint', _at(6, 20, 12, 8), bookId: 145, orderNo: powerPoint);
  t('refund', 220, '訂單 $powerPoint 取消退款', _at(5, 9, 2), bookId: 145, orderNo: powerPoint);
  t('purchase', -400, '購買訂單 $brainwash', _at(3, 10, 25, 37), bookId: 148, orderNo: brainwash);
  t('purchase', -666, '購買訂單 $infoCancelled', _at(2, 23, 33, 11), bookId: 126, orderNo: infoCancelled);
  t('refund', 666, '訂單 $infoCancelled 取消退款', _at(2, 23, 33, 52), bookId: 126, orderNo: infoCancelled);
  t('purchase', -666, '購買訂單 $info', _at(2, 23, 34, 38), bookId: 126, orderNo: info);
  t('refund', 400, '訂單 $brainwash 退款', _at(2, 23, 41, 5), bookId: 148, orderNo: brainwash);
  // 取書滿 24 小時未申請爭議，排程自動完成訂單並撥款（settlement.js：type sale_income、說明「賣出」）
  if (paid) t('sale_income', _price, '賣出', storyPayoutAt, bookId: storyBookId, orderNo: _storyOrderNo, orderId: _orderId);
  return rows.reversed.toList();
}

Map<String, dynamic> _wallet({required bool paid}) {
  final rows = _transactions(paid: paid);
  final income = rows.where((r) => (r['amount'] as int) > 0).fold<int>(0, (s, r) => s + (r['amount'] as int));
  final expense = rows.where((r) => (r['amount'] as int) < 0).fold<int>(0, (s, r) => s - (r['amount'] as int));
  return {
    'balance': rows.first['balance_after'],
    'frozen_amount': 0,
    'total_income': income,
    'total_expense': expense,
    'pending_income': paid ? 0 : _price,
  };
}

/// 由 [of] 往上找第一個以不透明底色畫出外框、寬度至少 [minWidth] 的方塊（整張卡片）。
RenderBox _cardAround(WidgetTester tester, Finder of, {double minWidth = 200}) {
  RenderObject? n = renderOf(tester, of.first);
  while (n != null) {
    if (isBoxDecoration(n) && n is RenderBox && n.size.width >= minWidth) return n;
    n = n.parent;
  }
  throw StateError('找不到卡片：$of');
}

// ───────────── 書櫃取書 ─────────────

Map<String, dynamic> Function() _currentSession = () => _sessionJson('matching', remainingMs: 52000);

/// 取書作業（GET /cabinet-sessions/:no 的回應），格式同第 12 章 7-3、7-4 截圖。
Map<String, dynamic> _sessionJson(String status, {int? remainingMs, bool done = false}) {
  final doorState = switch (status) {
    'open' => 'open',
    'completed' => 'closed',
    _ => 'pending',
  };
  return {
    'session_no': 'CS8PK3W7N',
    'status': status,
    'version': 3,
    'cabinet': {...cabinetJson(cabinetId), 'available_doors': 3},
    'location_status': 'granted',
    'distance_m': 9,
    'items': [
      {
        'key': 'order:$_orderId',
        'kind': 'pickup',
        'order_id': _orderId,
        'order_no': _storyOrderNo,
        'books': [
          {'book_id': storyBookId, 'title': storyTitle, 'image_url': coverOf(storyBookId), 'door': _door},
        ],
        'doors': const [_door],
        'paused': false,
        'note': null,
        'selected': true,
        'blocked': null,
        'result': done ? 'done' : 'pending',
        'error': null,
      },
    ],
    'doors': [
      if (status != 'selecting') {'label': _door, 'state': doorState},
    ],
    'remaining_ms': remainingMs,
    'open_ms': 60000,
    'notice': null,
    'result': null,
    'created_at': _iso(_pickedAt.subtract(const Duration(minutes: 1))),
  };
}

CabinetSession _session(String status, {int? remainingMs}) {
  _currentSession = () => _sessionJson(status, remainingMs: remainingMs);
  return CabinetSession.fromJson(_currentSession());
}

void _cabinetRoutes() {
  ManualApi.on('GET', '/cabinet-sessions/active', (_) => null);
  ManualApi.on('GET', '/cabinet-sessions/:no', (_) => _currentSession());
  ManualApi.on('GET', '/orders', (_) => [_order('deposited')]);
  ManualApi.on('GET', '/orders/:id', (_) => _order('deposited'));
}

// ───────────── 爭議 ─────────────

/// 買家的爭議說明：實拍照片中封面右側確有細小刮痕（同一本書的封面、封底照片作為佐證）。
const _disputeReason = '封面有刮痕，與上架標示的書況不符';
const _disputeId = 61;

/// 另一種情況：取書當晚驗收發現書況不符，於取書後 40 分鐘申請爭議（24 小時爭議期內）。
final _disputedAt = storyPickedAt.add(const Duration(minutes: 40));

/// 相簿選取：回傳書籍的實拍照片（略過 iOS 相片選取畫面）。
class _FakePicker extends ImagePickerPlatform {
  final List<String> paths;

  _FakePicker(this.paths);

  @override
  bool supportsImageSource(ImageSource source) => source == ImageSource.gallery;

  @override
  Future<List<XFile>> getMultiImageWithOptions({MultiImagePickerOptions options = const MultiImagePickerOptions()}) async =>
      [for (final p in paths) XFile(p)];

  @override
  Future<XFile?> getImageFromSource({required ImageSource source, ImagePickerOptions options = const ImagePickerOptions()}) async =>
      XFile(paths.first);
}

Map<String, dynamic> _disputeCase() => {
  'dispute_id': _disputeId,
  'order_id': _orderId,
  'applicant_id': buyerId,
  'reason': _disputeReason,
  'status': 'pending',
  'result': null,
  'admin_note': null,
  'created_at': _iso(_disputedAt),
  'evidence_images': [storyPhoto('cover'), storyPhoto('back')],
  'orders': _order('refunding', pickedUpAt: _iso(_pickedAt)),
  'users_transaction_disputes_applicant_idTousers': {'nickname': realUsers[buyerId]?.nickname ?? meName},
};

/// AI 爭議分析（dispute-assist.js 的輸出格式）：上架照片 1–3 為封面、封底、條碼頁，佐證照片 4–5 為買家上傳的封面與封底。
/// 內容依實拍照片：封面右側的細小刮痕在上架照片即可見，封底與書角未見摺痕或缺角。
Map<String, dynamic> _analysis() => {
  'analysis_no': 'DA7K2M9QX',
  'summary': '佐證照片與上架照片為同一本書。買家指出的封面刮痕，在上架照片中已可見。',
  'finding_details': [
    {'content': '封面右側的細小刮痕在上架照片已可見，並非上架後新增', 'photos': [1, 4], 'favors': 'seller'},
    {'content': '封底與書角未見摺痕、缺角或污漬', 'photos': [2, 5], 'favors': 'seller'},
  ],
  'suggestion': 'dismiss',
  'confidence_level': 'medium',
  'rationale': '照片中的痕跡與上架時的書況一致；如買家另有其他損傷，可請其補充照片。',
  'images': {'listing': 3, 'evidence': 2, 'skipped': 0},
  'photos': [
    {'no': 1, 'source': 'listing', 'type': 'cover', 'title': storyTitle},
    {'no': 2, 'source': 'listing', 'type': 'back', 'title': storyTitle},
    {'no': 3, 'source': 'listing', 'type': 'other', 'title': storyTitle},
    {'no': 4, 'source': 'evidence'},
    {'no': 5, 'source': 'evidence'},
  ],
  'helpful': null,
  'created_at': _iso(_disputedAt.add(const Duration(minutes: 14))),
};

// ───────────── AI 客服 ─────────────

/// 問題與回答：取書時櫃門未開啟屬「書櫃故障」類，客服 AI 依規範建議轉接（support.js：handoff_category cabinet）。
/// 回答內容依手冊：200 公尺內、60 秒內輸入書櫃螢幕上的兩位數字。
const _supportQuestion = '櫃門沒有開啟，該怎麼辦？';
const _supportAnswer = '請確認您位於書櫃 200 公尺內，並在 60 秒內於 App 輸入書櫃螢幕上的兩位數字。若數字正確但櫃門仍未開啟，可能是書櫃異常，建議轉接客服人員協助處理。';

Map<String, dynamic> _supportReply(String clientId) => {
  'user_message': {'message_id': 901, 'role': 'user', 'content': _supportQuestion, 'client_id': clientId, 'created_at': ago(minutes: 0)},
  'reply': {
    'message_id': 902,
    'role': 'assistant',
    'content': _supportAnswer,
    'suggest_handoff': true,
    'suggestions': const <String>[],
    'message_no': 'AS4N8Q2KT',
    'created_at': ago(minutes: 0),
    'feedback': null,
  },
  'suggest_handoff': true,
};

void main() {
  setUpAll(() async {
    await setUpManual();
    VerificationService.navigatorKey = navigatorKey;
    ApiService.onVerificationRequired = VerificationService.handle;
  });
  setUp(() {
    failures.clear();
    _gates.clear();
    VerificationService.clearCache();
    VerificationService.paymentSummary = null;
  });
  tearDownAll(writeJson);

  // ───────────── 付款暫管 ─────────────

  testWidgets('交易密碼', variant: _ios, (tester) async {
    await videoShoot(
      tester,
      routes: _payRoutes,
      home: () => BookDetailScreen(book: Book.fromJson(_payBook)),
      act: (tester) async {
        await settleReal(tester, const Duration(seconds: 1));
        await _buyNow(tester);
        await settleReal(tester, const Duration(seconds: 2));
        expect(find.byType(NumberPad), findsOneWidget);
        await snapScreen(tester, 'v_pay_pin_0');
        const pin = '582036';
        for (var i = 0; i < 5; i++) {
          await _tapDigit(tester, pin[i]);
          await snapScreen(tester, 'v_pay_pin_${i + 1}');
        }
        // 第六碼送出驗證：停在等待回應，畫面為六個點全滿與驗證中的進度圈
        holdApi('POST /security/verify');
        await tester.tap(find.descendant(of: find.byType(NumberPad), matching: find.text(pin[5])));
        await tester.pump();
        await untilHeld(tester);
        await settle(tester, const Duration(milliseconds: 400));
        spinnerFocus = find.byType(PinEntryPanel);
        await snapScreen(tester, 'v_pay_pin_6');
        spinnerFocus = null;
        recordSequence('pay_pin', [for (var i = 0; i <= 6; i++) 'v_pay_pin_$i']);
        releaseApi();
        await settleReal(tester, const Duration(seconds: 2));
        await settle(tester, const Duration(seconds: 2));
        expect(find.text(S.paymentSuccessful), findsOneWidget);
        await snapScreen(tester, 'v_pay_done');
        final dialog = ancestorWhere(find.text(S.paymentSuccessful), (w) => w is Material && w.borderRadius != null);
        await cut(
          tester,
          'cut_pay_done',
          screen: 'v_pay_done',
          box: renderOf(tester, dialog, pick: (ro) => ro is RenderPhysicalShape || ro is RenderPhysicalModel),
          note: '付款成功對話框（整張）',
        );
        await restoreTree(tester);
      },
    );
    expect(failures, isEmpty);
  });

  testWidgets('Face ID', variant: _ios, (tester) async {
    await videoShoot(
      tester,
      routes: _payRoutes,
      home: () => BookDetailScreen(book: Book.fromJson(_payBook)),
      act: (tester) async {
        await settleReal(tester, const Duration(seconds: 1));
        // 系統的 Face ID 驗證期間 App 停在付款中（直接購買按鈕轉圈），驗證提示由工具模擬繪製（比照 manual_shots）
        _gates['GET /security'] = Completer<void>();
        await _buyNow(tester);
        await settle(tester, const Duration(milliseconds: 800));
        systemOverlay.value = [const Positioned.fill(child: IgnorePointer(child: IosFaceIdHud()))];
        await tester.pump();
        await snapScreen(tester, 'v_pay_faceid', settleFirst: false);
        systemOverlay.value = const [];
        _gates.remove('GET /security')!.complete();
        await settleReal(tester, const Duration(seconds: 1));
        // 本機未啟用生物辨識付款時改開交易密碼面板：關閉，結束付款流程
        final nav = navigatorKey.currentState!;
        if (nav.canPop()) nav.pop();
        await settleReal(tester, const Duration(seconds: 1));
      },
    );
    expect(failures, isEmpty);
  });

  testWidgets('賣家待撥款項', variant: _ios, (tester) async {
    await videoShoot(
      tester,
      me: _seller,
      routes: () {
        ManualApi.on('GET', '/auth/me', (_) => userJson(sellerId));
        ManualApi.on('GET', '/wallet/pending', (_) => {...ok([_order('pending_deposit')]), 'total_amount': _price});
      },
      home: PendingIncomeScreen.new,
      act: (tester) async {
        await settleReal(tester, const Duration(seconds: 2));
        await settle(tester, const Duration(seconds: 2));
        await snapScreen(tester, 'v_pay_pending');
        final card = ancestorWhere(find.text(S.pendingAmount), (w) => w is AppCard);
        await cut(tester, 'cut_pay_pending', screen: 'v_pay_pending', box: renderOf(tester, card, pick: isBoxDecoration), note: '待撥款金額卡片');
        await restoreTree(tester);
      },
    );
    expect(failures, isEmpty);
  });

  // ───────────── 驗收售後：取書 ─────────────

  testWidgets('取書：輸入書櫃螢幕數字', variant: _ios, (tester) async {
    await videoShoot(
      tester,
      routes: _cabinetRoutes,
      home: () => CabinetFlowScreen(resume: _session('matching', remainingMs: 52000)),
      act: (tester) async {
        await settleReal(tester, const Duration(seconds: 1));
        await tester.enterText(find.descendant(of: find.byType(CabinetFlowScreen), matching: find.byType(TextField)), '25');
        FocusManager.instance.primaryFocus?.unfocus();
        await settle(tester, const Duration(milliseconds: 800));
        await snapScreen(tester, 'v_after_pick_match');
        tapAt(tester, 'tap_after_pick_confirm', screen: 'v_after_pick_match', finder: find.text(S.confirm).last);
      },
    );
    expect(failures, isEmpty);
  });

  testWidgets('取書：櫃門已開啟', variant: _ios, (tester) async {
    await videoShoot(
      tester,
      routes: _cabinetRoutes,
      home: () => CabinetFlowScreen(resume: _session('open', remainingMs: 25000)),
      act: (tester) async {
        await settleReal(tester, const Duration(seconds: 1));
        await snapScreen(tester, 'v_after_pick_open');
        await cut(
          tester,
          'cut_after_pick_card',
          screen: 'v_after_pick_open',
          box: _cardAround(tester, find.text(storyTitle, findRichText: true)),
          note: '請取出櫃門 A01 內的書籍（書封與書名）',
        );
        await restoreTree(tester);
      },
    );
    expect(failures, isEmpty);
  });

  testWidgets('取書完成', variant: _ios, (tester) async {
    await videoShoot(
      tester,
      routes: _cabinetRoutes,
      home: () => PickupSuccessScreen(order: Order.fromJson(_order('deposited', pickedUpAt: _iso(_pickedAt)))),
      act: (tester) async {
        await settleReal(tester, const Duration(seconds: 1));
        await settle(tester, const Duration(seconds: 2));
        await snapScreen(tester, 'v_after_pick_done');
        await cut(
          tester,
          'cut_after_pick_book',
          screen: 'v_after_pick_done',
          box: renderOf(tester, find.byType(BookThumbnail), pick: (ro) => ro is RenderClipRRect),
          note: '取出的書（實拍封面）',
        );
        await restoreTree(tester);
      },
    );
    expect(failures, isEmpty);
  });

  // ───────────── 驗收售後：撥款 ─────────────

  for (final paid in [false, true]) {
    testWidgets('賣家錢包 ${paid ? '撥款後' : '撥款前'}', variant: _ios, (tester) async {
      final name = 'v_after_wallet_${paid ? 1 : 0}';
      await videoShoot(
        tester,
        me: _seller,
        routes: () {
          ManualApi.on('GET', '/auth/me', (_) => userJson(sellerId));
          ManualApi.on('GET', '/wallet', (_) => _wallet(paid: paid));
          ManualApi.on('GET', '/wallet/transactions', (_) => _transactions(paid: paid));
        },
        home: WalletScreen.new,
        act: (tester) async {
          await settleReal(tester, const Duration(seconds: 2));
          await settle(tester, const Duration(seconds: 2));
          await snapScreen(tester, name);
          final card = ancestorWhere(find.text(S.balance), (w) => w is AppCard);
          await cut(tester, 'cut_after_wallet_card${paid ? 1 : 0}', screen: name, box: renderOf(tester, card, pick: isBoxDecoration), note: '目前餘額卡片');
          if (paid) {
            await cut(
              tester,
              'cut_after_income',
              screen: name,
              box: _cardAround(tester, find.text('+\$$_price')),
              note: '撥款入帳的交易紀錄（賣出）',
            );
          }
          await restoreTree(tester);
        },
      );
      expect(failures, isEmpty);
    });
  }

  // ───────────── 驗收售後：爭議 ─────────────

  testWidgets('買家申請爭議', variant: _ios, (tester) async {
    await videoShoot(
      tester,
      routes: () {
        ManualApi.on('GET', '/orders/:id', (_) => _order('deposited', pickedUpAt: _iso(_pickedAt)));
        ManualApi.on('GET', '/orders/by-no/:no', (_) => _order('deposited', pickedUpAt: _iso(_pickedAt)));
      },
      home: () => DisputeScreen(orderNo: _storyOrderNo),
      act: (tester) async {
        await settleReal(tester, const Duration(seconds: 1));
        ImagePickerPlatform.instance = _FakePicker([for (final t in ['cover', 'back']) photoFile(storyPhoto(t))!.path]);
        await tester.enterText(find.byType(TextField).at(1), _disputeReason);
        FocusManager.instance.primaryFocus?.unfocus();
        await settle(tester, const Duration(milliseconds: 500));
        await tester.tap(find.byIcon(Icons.add_photo_alternate_outlined));
        // 每張照片各有一個裁切頁，依序按「完成」
        for (var round = 0; round < 6; round++) {
          for (var i = 0; i < 30; i++) {
            await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
            await tester.pump(const Duration(milliseconds: 100));
          }
          final done = find.text('完成');
          if (done.evaluate().isEmpty) break;
          await tester.tap(done.last);
        }
        await settleReal(tester, const Duration(seconds: 1));
        await settle(tester, const Duration(seconds: 1));
        await snapScreen(tester, 'v_after_dispute');
        Finder row(String label) => find.byWidgetPredicate((w) => w is FormRowCard && w.label == label);
        await cut(tester, 'cut_after_dispute_reason', screen: 'v_after_dispute', box: renderOf(tester, row(S.whatHappened), pick: isBoxDecoration), note: '爭議說明');
        await cut(tester, 'cut_after_dispute_photos', screen: 'v_after_dispute', box: renderOf(tester, row(S.uploadPhotos), pick: isBoxDecoration), note: '佐證照片（實拍封面與封底）');
        await restoreTree(tester);
      },
    );
    expect(failures, isEmpty);
  });

  testWidgets('管理員 AI 爭議分析', variant: _ios, (tester) async {
    var analyzed = false;
    await videoShoot(
      tester,
      me: _admin,
      routes: () {
        ManualApi.on('GET', '/auth/me', (_) => userJson(meId, extra: {'role': 'admin'}));
        ManualApi.on('GET', '/admin/disputes', (_) => [_disputeCase()]);
        ManualApi.on('GET', '/admin/disputes/:id/ai-analysis', (_) => analyzed ? _analysis() : null);
        ManualApi.on('POST', '/admin/disputes/:id/ai-analysis', (_) {
          analyzed = true;
          return _analysis();
        });
      },
      home: AdminDisputeScreen.new,
      act: (tester) async {
        await settleReal(tester, const Duration(seconds: 2));
        await snapScreen(tester, 'v_after_admin_list');
        tapAt(tester, 'tap_after_admin_handle', screen: 'v_after_admin_list', finder: find.text(S.handle).first);
        await tester.tap(find.text(S.handle).first);
        await settleReal(tester, const Duration(seconds: 2));
        await settle(tester, const Duration(seconds: 1));
        await snapScreen(tester, 'v_after_admin_sheet');
        final analyze = find.descendant(of: find.byType(DisputeAiPanel), matching: find.text(S.analyze));
        tapAt(tester, 'tap_after_admin_analyze', screen: 'v_after_admin_sheet', finder: analyze);

        holdApi('POST /admin/disputes/$_disputeId/ai-analysis');
        await tester.tap(analyze);
        await tester.pump();
        await untilHeld(tester);
        await settle(tester, const Duration(milliseconds: 600));
        spinnerFocus = find.byType(DisputeAiPanel);
        await snapScreen(tester, 'v_after_admin_wait');
        spinnerFocus = null;
        final waitSheetTop = tester.getTopLeft(find.ancestor(of: find.byType(DisputeAiPanel), matching: find.byType(BottomSheet)).first).dy;
        final waitPanelTop = tester.getTopLeft(find.byType(DisputeAiPanel)).dy;
        releaseApi();
        await settleReal(tester, const Duration(seconds: 2));
        await settle(tester, const Duration(seconds: 2));
        // 分析結果展開後，裁決面板高過螢幕，頂端會蓋到狀態列與動態島（看起來像程式錯誤）。改拍長截圖：
        // 把視窗加長到面板完整放得下、且面板頂端與「分析中」時同高，影片中只顯示長截圖最上方一個螢幕高（狀態列與標題正常），
        // 分析面板去背元件也在同一張長截圖上取得，位置與「分析中」畫面的面板頂端一致。
        final sheet = find.ancestor(of: find.byType(DisputeAiPanel), matching: find.byType(BottomSheet)).first;
        for (var i = 0; i < 4; i++) {
          final scroll = tester.state<ScrollableState>(find.ancestor(of: find.byType(DisputeAiPanel), matching: find.byType(Scrollable)).first).position;
          final extra = scroll.maxScrollExtent + (waitSheetTop - tester.getTopLeft(sheet).dy);
          if (extra.abs() < 0.5) break;
          tester.view.physicalSize = Size(logicalSize.width, tester.view.physicalSize.height / pixelRatio + extra) * pixelRatio;
          await settleReal(tester, const Duration(milliseconds: 600));
        }
        final panelOffset = tester.getTopLeft(find.byType(DisputeAiPanel)).dy - waitPanelTop;
        if (panelOffset.abs() > 0.5) failures.add('分析面板與分析中畫面的位置差 $panelOffset pt');
        await snapScreen(tester, 'v_after_admin_ai');
        await cut(
          tester,
          'cut_after_ai_panel',
          screen: 'v_after_admin_ai',
          box: renderOf(tester, find.byType(DisputeAiPanel), pick: isBoxDecoration),
          note: 'AI 分析面板（7% 強調色疊在面板底色上，已連同底色輸出；取自長截圖，位置同分析中畫面的面板）',
        );
        await restoreTree(tester);
        tester.view.physicalSize = logicalSize * pixelRatio;
        await settle(tester, const Duration(milliseconds: 300));
      },
    );
    expect(failures, isEmpty);
  });

  // ───────────── 驗收售後：AI 客服 ─────────────

  testWidgets('AI 客服與轉接', variant: _ios, (tester) async {
    await videoShoot(
      tester,
      routes: () {
        ManualApi.on('GET', '/ai/support/session', (_) => {'session_id': 41, 'status': 'open', 'messages': <Object>[]});
        ManualApi.on('POST', '/ai/support/messages', (r) {
          final id = RegExp(r'"client_id"\s*:\s*"([^"]+)"').firstMatch(r.body)?.group(1) ?? 'video';
          return _supportReply(id);
        });
      },
      home: AiSupportScreen.new,
      act: (tester) async {
        await settleReal(tester, const Duration(seconds: 1));
        await snapScreen(tester, 'v_after_sup_empty');
        final input = find.descendant(of: find.byType(AiSupportScreen), matching: find.byType(TextField));
        final typed = await typeFrames(tester, input, _supportQuestion, 'v_after_sup');
        final send = find.ancestor(of: find.byIcon(Icons.arrow_upward_rounded), matching: find.byType(PressableScale)).first;
        tapAt(tester, 'tap_after_sup_send', screen: typed.last, finder: send);

        holdApi('POST /ai/support/messages');
        await tester.tap(send);
        await tester.pump();
        await untilHeld(tester);
        await settle(tester, const Duration(milliseconds: 900));
        spinnerFocus = find.byType(AiSupportScreen);
        await snapScreen(tester, 'v_after_sup_wait');
        spinnerFocus = null;
        await restoreTree(tester);

        releaseApi();
        await settleReal(tester, const Duration(seconds: 2));
        await settle(tester, const Duration(seconds: 3));
        await snapScreen(tester, 'v_after_sup_answer');
        recordSequence('after_support', ['v_after_sup_empty', ...typed, 'v_after_sup_wait', 'v_after_sup_answer']);
        final answer = find.ancestor(of: find.textContaining('200 公尺', findRichText: true), matching: find.byType(ChatBubbleShell)).first;
        await cut(tester, 'cut_after_sup_answer', screen: 'v_after_sup_answer', box: renderOf(tester, answer, pick: isBoxDecoration), note: 'AI 客服的回答');
        await cut(
          tester,
          'cut_after_sup_handoff',
          screen: 'v_after_sup_answer',
          box: _cardAround(tester, find.text(S.ourSupportTeamCanHelpWith), minWidth: 150),
          note: '建議轉接客服人員的卡片（含「轉接客服人員」按鈕）',
        );
        tapAt(tester, 'tap_after_sup_handoff', screen: 'v_after_sup_answer', finder: find.text(S.talkPerson).last);
        await restoreTree(tester);
      },
    );
    expect(failures, isEmpty);
  });

  // ───────────── 七項 AI：書籍資料補齊 ─────────────

  testWidgets('書籍資料補齊', variant: _ios, (tester) async {
    // 正式站 book 96 的 enrichment：description 由 AI 依書目整理（GET /books/96 回傳 {fields: [description], ai_written: true}）
    final book = {...bookJson(96), 'enrichment': {'fields': ['description'], 'ai_written': true}};
    await videoShoot(
      tester,
      routes: () => ManualApi.on('GET', '/books/96', (_) => book),
      home: () => BookDetailScreen(book: Book.fromJson(book)),
      act: (tester) async {
        await settleReal(tester, const Duration(seconds: 2));
        final about = find.text(S.aboutBook, skipOffstage: false);
        for (var i = 0; i < 12 && about.evaluate().isEmpty; i++) {
          await scrollBy(tester, 300);
        }
        await Scrollable.ensureVisible(tester.element(about.first), alignment: 0.32);
        await settleReal(tester, const Duration(seconds: 1));
        expect(find.text(S.summarizedByAiFromBookRecords), findsOneWidget);
        await snapScreen(tester, 'v_after_ai_enrich');
      },
    );
    expect(failures, isEmpty);
  });
}
