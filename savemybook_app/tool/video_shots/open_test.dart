// 系統簡介影片第二版「開場」與「系統總覽」段落：flutter test tool/video_shots/open_test.dart
// 開場：買家與另一位賣家約好面交卻被放鳥（模擬的 iOS 訊息畫面，不是本系統 App）；賣家雪喵與買家 es 在新北高工書櫃 A01 各自存書、取書。
// 系統總覽：es 看《HTML & CSS》的書況、付款，書存入書櫃後取書，最後完成訂單（款項撥給賣家）。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:savemybook_app/features/books/book_detail_screen.dart';
import 'package:savemybook_app/features/cabinet/cabinet_flow_screen.dart';
import 'package:savemybook_app/features/orders/order_detail_screen.dart';
import 'package:savemybook_app/features/orders/widgets/payment_success_dialog.dart';
import 'package:savemybook_app/i18n/strings.dart';
import 'package:savemybook_app/models/book.dart';
import 'package:savemybook_app/models/cabinet.dart';
import 'package:savemybook_app/models/order.dart';
import 'package:savemybook_app/models/user.dart';
import 'package:savemybook_app/widgets/app_dialogs.dart';
import 'package:savemybook_app/widgets/state_views.dart';

import '../manual_shots/manual_api.dart';
import '../manual_shots/s07_08_09_11_data.dart' show orderJson, scanAccess;
import 'video_data.dart';
import 'video_host.dart';

final _ios = TargetPlatformVariant.only(TargetPlatform.iOS);

User get _seller => User.fromJson(userJson(sellerId));

// ───────────── 面交被放鳥：模擬的 iOS 訊息 App ─────────────

/// 約面交的對話：四天前晚上約好，隔天（三天前）買家依序傳出三則訊息都已讀未回；之後 es 才改用本系統，兩天前付款（video_data.dart 的劇情時間線）。
const _meetPlace = '土城站 1 號出口';
const _meetHistory = [
  (mine: true, text: '請問《HTML & CSS》還在嗎？'),
  (mine: false, text: '在，明天下午 3 點在$_meetPlace面交可以嗎？'),
  (mine: true, text: '可以，明天見！'),
];
const _waits = [
  (time: '15:02', text: '我到$_meetPlace了'),
  (time: '15:20', text: '請問快到了嗎？'),
  (time: '15:41', text: '？'),
];

/// iOS 訊息一週內的時間戳記：「星期一 21:10」。
String _weekday(int daysAgo) => '星期${'一二三四五六日'[DateTime.now().subtract(Duration(days: daysAgo)).weekday - 1]}';

const _iosBlue = Color(0xFF0A7CFF);
const _iosGray = Color(0xFFE9E9EB);
const _iosLabel = Color(0xFF8E8E93);

class _MeetChat extends StatelessWidget {
  final int step;

  const _MeetChat({required this.step});

  Widget _stamp(String text) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 8),
    child: Center(child: Text(text, style: const TextStyle(fontSize: 13, color: _iosLabel, fontWeight: FontWeight.w500))),
  );

  Widget _bubble(String text, {required bool mine, Key? key}) => Align(
    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 290),
        child: DecoratedBox(
          key: key,
          decoration: BoxDecoration(color: mine ? _iosBlue : _iosGray, borderRadius: BorderRadius.circular(19)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            child: Text(text, style: TextStyle(fontSize: 20, height: 1.3, color: mine ? Colors.white : Colors.black)),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final bottom = MediaQuery.of(context).padding.bottom;
    return Material(
      color: Colors.white,
      child: Column(
        children: [
          // 導覽列：返回、置中的頭像與名稱
          Container(
            padding: EdgeInsets.only(top: top),
            decoration: const BoxDecoration(
              color: Color(0xFFF7F7F8),
              border: Border(bottom: BorderSide(color: Color(0xFFD8D8DC), width: 0.5)),
            ),
            child: SizedBox(
              height: 92,
              child: Stack(
                children: [
                  const Positioned(left: 6, top: 14, child: Icon(Icons.chevron_left_rounded, size: 40, color: _iosBlue)),
                  Align(
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFA5A9B3), Color(0xFF858A94)]),
                          ),
                          child: const Icon(Icons.person_rounded, size: 34, color: Colors.white),
                        ),
                        const SizedBox(height: 5),
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('二手書賣家', style: TextStyle(fontSize: 13, color: Colors.black)),
                            Icon(Icons.chevron_right_rounded, size: 14, color: _iosLabel),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ClipRect(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: SingleChildScrollView(
                  reverse: true,
                  physics: const NeverScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _stamp('${_weekday(4)} 21:10'),
                      for (final m in _meetHistory) _bubble(m.text, mine: m.mine),
                      for (final (i, w) in _waits.take(step).indexed) ...[
                        _stamp('${_weekday(3)} ${w.time}'),
                        _bubble(w.text, mine: true, key: ValueKey('wait$i')),
                      ],
                      Padding(
                        padding: const EdgeInsets.only(right: 18, top: 3, bottom: 12),
                        child: Text(
                          step == 0 ? '已讀' : '已讀 ${_waits[step - 1].time}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 13, color: _iosLabel, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // 輸入列
          Padding(
            padding: EdgeInsets.fromLTRB(10, 6, 10, bottom + 8),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFEDEDF0)),
                  child: const Icon(Icons.add_rounded, color: _iosLabel, size: 24),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(19),
                      border: Border.all(color: const Color(0xFFD1D1D6)),
                    ),
                    alignment: Alignment.centerLeft,
                    child: const Row(
                      children: [
                        Expanded(child: Text('訊息', style: TextStyle(fontSize: 17, color: Color(0xFFC4C4C7)))),
                        Icon(Icons.mic_none_rounded, color: _iosLabel, size: 22),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────── 訂單、書櫃作業 ─────────────

const _orderId = storyOrderId;
final _orderNo = storyOrderNo;
const _door = 'A01';

Map<String, dynamic> _order(String status, {String? pickedUpAt}) => orderJson(
  id: _orderId,
  no: _orderNo,
  bookId: storyBookId,
  cabinetId: cabinetId,
  status: status,
  createdAt: storyPaidAt.toUtc().toIso8601String(),
  pickedUpAt: pickedUpAt,
  doors: status == 'pending_deposit' ? const [] : const [_door],
  access: scanAccess(),
);

/// 書櫃作業（GET /cabinet-sessions/:no）：[kind] 為 order_deposit（賣家存書）或 pickup（買家取書），櫃門已開啟。
Map<String, dynamic> _session(String kind, String status, {int? remainingMs}) {
  return {
    'session_no': kind == 'pickup' ? 'CS8QW3M5T' : 'CS5R9K2PV',
    'status': status,
    'version': 3,
    'cabinet': {...cabinetJson(cabinetId), 'available_doors': 3},
    'location_status': 'granted',
    'distance_m': 9,
    'items': [
      {
        'key': 'order:$_orderId',
        'kind': kind,
        'order_id': _orderId,
        'order_no': _orderNo,
        'books': [
          {'book_id': storyBookId, 'title': storyTitle, 'image_url': coverOf(storyBookId), 'door': _door},
        ],
        'doors': [_door],
        'paused': false,
        'note': null,
        'selected': true,
        'blocked': null,
        'result': 'pending',
        'error': null,
      },
    ],
    'doors': [
      {'label': _door, 'state': 'open'},
    ],
    'remaining_ms': remainingMs,
    'open_ms': 60000,
    'notice': null,
    'result': null,
    'created_at': (kind == 'pickup' ? storyPickedAt : storyDepositedAt).subtract(const Duration(minutes: 1)).toUtc().toIso8601String(),
  };
}

void _cabinetRoutes(String kind) {
  ManualApi.on('GET', '/cabinet-sessions/active', (_) => null);
  ManualApi.on('GET', '/cabinet-sessions/:no', (_) => _session(kind, 'open', remainingMs: 29000));
  ManualApi.on('GET', '/orders/:id', (_) => _order('deposited'));
}

/// 浮出用：書櫃作業畫面中「請將下列書籍放入櫃門 A01」／「請取出櫃門 A01 內的書籍」整張卡片。
RenderBox _instructionCard(WidgetTester tester) {
  final title = find.textContaining(_door, findRichText: true).first;
  return renderOf(tester, ancestorWhere(title, (w) => w is AppCard), pick: isBoxDecoration);
}

// ───────────── 書籍詳情 ─────────────

Map<String, dynamic> _detailJson({String status = 'on_sale'}) => bookJson(storyBookId, extra: {'status': status});

void _detailRoutes({String status = 'on_sale'}) {
  ManualApi.on('GET', '/books/$storyBookId', (_) => _detailJson(status: status));
  ManualApi.on('GET', '/books/$storyBookId/similar', (_) => [for (final id in [78, 125, 96, 97]) bookJson(id)]);
  ManualApi.on('GET', '/favorites/ids', (_) => <int>[]);
  ManualApi.on('GET', '/cart/book-ids', (_) => <int>[]);
  ManualApi.on('GET', '/wallet', (_) => {'balance': 1280, 'frozen_amount': 0, 'total_income': 0, 'total_expense': 0, 'pending_income': 0});
}

void main() {
  setUpAll(setUpManual);
  setUp(failures.clear);
  tearDownAll(writeJson);

  testWidgets('面交被放鳥', variant: _ios, (tester) async {
    final step = ValueNotifier(0);
    await videoShoot(
      tester,
      home: () => ValueListenableBuilder<int>(valueListenable: step, builder: (_, s, _) => _MeetChat(step: s)),
      act: (tester) async {
        for (var i = 0; i <= _waits.length; i++) {
          step.value = i;
          await tester.pump();
          await snapScreen(tester, 'v_open_meet_$i');
        }
        recordSequence('open_meet', [for (var i = 0; i <= _waits.length; i++) 'v_open_meet_$i']);
      },
    );
    expect(failures, isEmpty);
  });

  testWidgets('賣家存書（櫃門已開啟）', variant: _ios, (tester) async {
    await videoShoot(
      tester,
      me: _seller,
      routes: () => _cabinetRoutes('order_deposit'),
      home: () => CabinetFlowScreen(resume: CabinetSession.fromJson(_session('order_deposit', 'open', remainingMs: 29000))),
      act: (tester) async {
        await snapScreen(tester, 'v_open_deposit');
        await cut(tester, 'cut_open_put', screen: 'v_open_deposit', box: _instructionCard(tester), note: '賣家：請將下列書籍放入櫃門 A01');
        await restoreTree(tester);
      },
    );
    expect(failures, isEmpty);
  });

  testWidgets('買家取書（櫃門已開啟）', variant: _ios, (tester) async {
    await videoShoot(
      tester,
      routes: () => _cabinetRoutes('pickup'),
      home: () => CabinetFlowScreen(resume: CabinetSession.fromJson(_session('pickup', 'open', remainingMs: 29000))),
      act: (tester) async {
        await snapScreen(tester, 'v_open_pickup');
        await cut(tester, 'cut_open_take', screen: 'v_open_pickup', box: _instructionCard(tester), note: '買家：請取出櫃門 A01 內的書籍');
        await restoreTree(tester);
      },
    );
    expect(failures, isEmpty);
  });

  testWidgets('看書況與付款', variant: _ios, (tester) async {
    await videoShoot(
      tester,
      routes: _detailRoutes,
      home: () => BookDetailScreen(book: Book.fromJson(_detailJson())),
      act: (tester) async {
        await settleReal(tester, const Duration(seconds: 1));
        await snapScreen(tester, 'v_ov_detail');
        unawaited(showPaymentSuccess(tester.element(find.byType(BookDetailScreen)), total: double.parse('${storyBook['price']}')));
        await settleReal(tester, const Duration(seconds: 2));
        await snapScreen(tester, 'v_ov_paid');
      },
    );
    expect(failures, isEmpty);
  });

  // 訂單進度：付款後（待賣家存書）→ 存書後（已存入書櫃）→ 取書後（買家已取書）。三張畫面的版面相同，只有進度卡片內容不同。
  final states = [
    (name: 'v_ov_order_0', json: () => _order('pending_deposit')),
    (name: 'v_ov_order_1', json: () => _order('deposited')),
    (name: 'v_ov_order_2', json: () => _order('deposited', pickedUpAt: storyPickedAt.toUtc().toIso8601String())),
  ];
  for (final (i, st) in states.indexed) {
    testWidgets('訂單進度 $i', variant: _ios, (tester) async {
      final json = st.json();
      await videoShoot(
        tester,
        routes: () => ManualApi.on('GET', '/orders/:id', (_) => json),
        home: () => OrderDetailScreen(order: Order.fromJson(json)),
        act: (tester) async {
          await settleReal(tester, const Duration(seconds: 1));
          // 目前步驟的圓點有呼吸動畫，固定在同一相位，三張畫面的圓點大小才一致
          await settle(tester, const Duration(milliseconds: 1800));
          await snapScreen(tester, st.name);
          final card = ancestorWhere(find.text(S.orderProgress), (w) => w is AppCard);
          await cut(tester, 'cut_ov_flow_$i', screen: st.name, box: renderOf(tester, card, pick: isBoxDecoration), note: '訂單進度卡片');
          await restoreTree(tester);
          if (i < 2) return;
          // 完成訂單的確認對話框：與 OrderDetailScreen._completeOrder 相同的呼叫（按鈕在畫面下方，直接開啟對話框，畫面不捲動）
          unawaited(showConfirmDialog(
            tester.element(find.byType(OrderDetailScreen)),
            title: S.completeOrder,
            message: S.onceCompleteOrderPaymentReleasedSeller,
            confirmLabel: S.completeOrder,
            cancelLabel: S.actionBack,
            icon: Icons.task_alt_rounded,
          ));
          await settleReal(tester, const Duration(seconds: 1));
          await snapScreen(tester, 'v_ov_confirm');
        },
      );
      expect(failures, isEmpty);
    });
  }
}
