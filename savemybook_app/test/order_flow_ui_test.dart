import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:savemybook_app/features/orders/order_detail_screen.dart';
import 'package:savemybook_app/features/orders/order_history_screen.dart';
import 'package:savemybook_app/features/orders/widgets/order_record_card.dart';
import 'package:savemybook_app/features/selling/book_manage_screen.dart';
import 'package:savemybook_app/i18n/app_localizations.dart';
import 'package:savemybook_app/i18n/strings.dart';
import 'package:savemybook_app/models/user.dart';
import 'package:savemybook_app/services/api_service.dart';
import 'package:savemybook_app/services/locale_provider.dart';
import 'package:savemybook_app/utils/app_theme.dart';
import 'package:savemybook_app/widgets/app_header.dart';

final _now = DateTime.now();

Map<String, dynamic> _book(int id, String title, {String status = 'on_sale', Map<String, dynamic>? reservation}) => {
  'book_id': id,
  'seller_id': 1,
  'title': title,
  'price': 200,
  'status': status,
  'is_approved': true,
  'book_images': <Object>[],
  'reservation': ?reservation,
};

Map<String, dynamic> _order(int id, String status, {DateTime? pickedUpAt, int books = 1}) => {
  'order_id': id,
  'order_no': 'SMB$id',
  'buyer_id': 1,
  'seller_id': 2,
  'total_amount': 200 * books,
  'status': status,
  'picked_up_at': pickedUpAt?.toIso8601String(),
  'smart_cabinets': {'cabinet_id': 3, 'cabinet_name': '台大書櫃', 'address': '臺北市大安區羅斯福路四段1號'},
  'users_orders_buyer_idTousers': {'user_id': 1, 'nickname': '買家小華'},
  'users_orders_seller_idTousers': {'user_id': 2, 'nickname': '賣家小明'},
  'order_items': [
    for (var k = 0; k < books; k++)
      {'item_id': id * 10 + k, 'book_id': id * 10 + k, 'quantity': 1, 'unit_price': 200, 'subtotal': 200, 'books': _book(id * 10 + k, '書 ${id * 10 + k}')},
  ],
  'transaction_disputes': <Object>[],
};

Finder _inHeader(String text) => find.descendant(of: find.byType(AppHeader), matching: find.text(text));

Finder _card(String text) => find.ancestor(of: find.text(text), matching: find.byType(OrderRecordCard));

Widget _host(Widget child) => MaterialApp(
  locale: const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
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
  home: child,
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

http.Response _json(Object data) => http.Response(
  jsonEncode({'success': true, 'data': data}),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiService.authToken = 'token';
    ApiService.currentUser = User.fromJson({
      'user_id': 1,
      'nickname': '我',
      'email': 'me@example.com',
      'role': 'buyer_seller',
    });
  });

  testWidgets('訂單紀錄：購買訂單的待取書含已取書待完成的訂單，可完成訂單或申請爭議；完成需確認', (tester) async {
    tester.view.physicalSize = const Size(390, 1200) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final sent = <String>[];
    final tabs = <String?>[];

    await http.runWithClient(
      () async {
        await tester.pumpWidget(_host(const OrderHistoryScreen()));
        await _settle(tester);
        expect(tabs.first, 'awaiting_pickup');

        final collected = _card('書 70');
        expect(find.descendant(of: collected, matching: find.text('待完成訂單')), findsOneWidget);
        expect(find.descendant(of: collected, matching: find.text('完成訂單')), findsOneWidget);
        expect(find.descendant(of: collected, matching: find.text(S.openDispute)), findsOneWidget);
        final ready = _card('書 80');
        expect(find.descendant(of: ready, matching: find.text(S.iCollected)), findsOneWidget);
        expect(find.descendant(of: ready, matching: find.text(S.openDispute)), findsNothing);
        expect(find.descendant(of: ready, matching: find.text(S.cancelOrder)), findsNothing);

        await tester.tap(find.text('完成訂單'));
        await _settle(tester);
        expect(find.text('完成訂單後，款項將撥給賣家，且無法再申請爭議。'), findsOneWidget);
        await tester.tap(find.text('完成訂單').last);
        await _settle(tester);
        expect(sent, contains('PATCH /api/orders/7/status {"status":"completed"}'));
        await tester.pump(const Duration(seconds: 4));
      },
      () => MockClient((request) async {
        if (request.method != 'GET') {
          sent.add('${request.method} ${request.url.path} ${request.body}');
          return _json(_order(7, 'completed'));
        }
        final tab = request.url.queryParameters['tab'];
        if (request.url.queryParameters['limit'] != '1') tabs.add(tab);
        return _json(
          tab == 'awaiting_pickup' && request.url.queryParameters['role'] == 'buyer'
              ? [_order(7, 'deposited', pickedUpAt: _now), _order(8, 'deposited')]
              : <Object>[],
        );
      }),
    );
  });

  testWidgets('訂單紀錄：卡片顯示訂單編號、賣家、最多兩本書、書櫃與金額；待賣家存書可取消訂單', (tester) async {
    tester.view.physicalSize = const Size(390, 1200) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final sent = <String>[];

    await http.runWithClient(
      () async {
        await tester.pumpWidget(_host(const OrderHistoryScreen(filter: OrderHistoryScreen.awaitingDeposit)));
        await _settle(tester);
        final card = _card('書 50');
        for (final text in ['訂單編號 SMB5', '賣家  賣家小明', '書 51', '台大書櫃', r'$400', '待賣家存書']) {
          expect(find.descendant(of: card, matching: find.text(text)), findsOneWidget, reason: text);
        }
        expect(find.descendant(of: card, matching: find.text(S.markAsDroppedOff)), findsNothing);

        await tester.tap(find.descendant(of: card, matching: find.text(S.cancelOrder)));
        await _settle(tester);
        await tester.tap(find.text(S.cancelOrder).last);
        await _settle(tester);
        expect(sent, ['PATCH /api/orders/5/cancel']);

        await tester.tap(card);
        await _settle(tester);
        expect(find.byType(OrderDetailScreen), findsOneWidget);
        expect(tester.widget<OrderDetailScreen>(find.byType(OrderDetailScreen)).asSeller, isFalse);
        await tester.pump(const Duration(seconds: 4));
      },
      () => MockClient((request) async {
        if (request.method != 'GET') {
          sent.add('${request.method} ${request.url.path}');
          return _json(_order(5, 'cancelled', books: 2));
        }
        if (request.url.path.endsWith('/orders/5')) return _json(_order(5, 'pending_deposit', books: 2));
        final tab = request.url.queryParameters['tab'];
        return _json(tab == 'awaiting_deposit' ? [_order(5, 'pending_deposit', books: 2)] : <Object>[]);
      }),
    );
  });

  testWidgets('訂單紀錄：主頁籤顯示待處理數量，切換頁籤與狀態篩選時查詢對應的訂單', (tester) async {
    tester.view.physicalSize = const Size(390, 900) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final queries = <String>[];

    await http.runWithClient(
      () async {
        await tester.pumpWidget(_host(const OrderHistoryScreen()));
        await _settle(tester);
        expect(_inHeader(S.orderHistory), findsOneWidget);
        expect(find.descendant(of: find.byType(Tab), matching: find.text(S.purchaseOrders)), findsOneWidget);
        expect(find.descendant(of: find.byType(Tab), matching: find.text(S.salesOrders)), findsOneWidget);
        expect(find.descendant(of: find.byType(CountBadge), matching: find.text('3')), findsOneWidget);
        expect(find.descendant(of: find.byType(CountBadge), matching: find.text('12')), findsOneWidget);
        for (final label in ['待取書', '待賣家存書', '爭議處理中', '已完成', '已取消']) {
          expect(_inHeader(label), findsOneWidget, reason: label);
        }
        expect(queries, ['buyer/awaiting_pickup']);

        await tester.tap(_inHeader('待賣家存書'));
        await _settle(tester);
        expect(queries.last, 'buyer/awaiting_deposit');

        await tester.tap(find.text(S.salesOrders));
        await _settle(tester);
        expect(queries.last, 'seller/awaiting_deposit');
        for (final label in ['待存書', '待買家取書', '爭議處理中', '已完成', '已取消']) {
          expect(_inHeader(label), findsOneWidget, reason: label);
        }
        await tester.tap(_inHeader('已完成'));
        await _settle(tester);
        expect(queries.last, 'seller/finished');

        await tester.tap(find.text(S.purchaseOrders));
        await _settle(tester);
        expect(queries.last, 'buyer/awaiting_deposit', reason: '各頁籤保留各自的篩選');
        await tester.pump(const Duration(seconds: 4));
      },
      () => MockClient((request) async {
        final q = request.url.queryParameters;
        if (q['limit'] == '1') {
          final total = q['role'] == 'buyer' && q['tab'] == 'awaiting_pickup'
              ? 3
              : q['role'] == 'seller' && q['tab'] == 'awaiting_deposit'
              ? 12
              : 0;
          return http.Response(
            jsonEncode({'success': true, 'data': <Object>[], 'pagination': {'total': total, 'page': 1, 'limit': 1}}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        queries.add('${q['role']}/${q['tab']}');
        return _json(<Object>[]);
      }),
    );
  });
  testWidgets('書籍管理：已被預約、已售出、已完成分頁，這些書不能編輯或取消上架', (tester) async {
    tester.view.physicalSize = const Size(390, 1400) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await http.runWithClient(
      () async {
        await tester.pumpWidget(_host(const BookManageScreen()));
        await _settle(tester);
        for (final label in [S.bookHeldForBuyer, S.bookSold, S.orderCompleted]) {
          expect(find.textContaining(label), findsWidgets, reason: label);
        }
        await tester.tap(find.textContaining(S.bookHeldForBuyer).first);
        await _settle(tester);
        expect(find.text('預約中'), findsOneWidget);
        expect(find.textContaining('保留至'), findsOneWidget);
        final edit = tester.widget<Widget>(
          find
              .ancestor(
                of: find.text(S.actionEdit),
                matching: find.byWidgetPredicate((w) => w.runtimeType.toString() == 'SmallActionButton'),
              )
              .first,
        );
        expect((edit as dynamic).onTap, isNull);
        await tester.pump(const Duration(seconds: 4));
      },
      () => MockClient((request) async {
        if (request.url.path.endsWith('/books')) {
          return _json([
            _book(1, '販售中的書'),
            _book(2, '預約中', reservation: {'reserved_until': _now.add(const Duration(hours: 5)).toIso8601String()}),
            _book(3, '訂單成立', status: 'reserved'),
            _book(4, '已完成交易', status: 'sold'),
          ]);
        }
        return _json(<Object>[]);
      }),
    );
  });

  testWidgets('訂單紀錄：銷售訂單的待買家取書在買家取書後標示待買家確認；待存書可完成存書或取消訂單', (tester) async {
    tester.view.physicalSize = const Size(390, 1200) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final tabs = <String?>[];
    final sent = <String>[];

    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          _host(const OrderHistoryScreen(role: OrderRole.seller, filter: OrderHistoryScreen.awaitingPickup)),
        );
        await _settle(tester);
        expect(tabs, ['awaiting_pickup']);
        final card = _card('書 90');
        expect(find.descendant(of: card, matching: find.text('待買家確認')), findsOneWidget);
        expect(find.descendant(of: card, matching: find.text('買家  買家小華')), findsOneWidget);
        expect(find.descendant(of: card, matching: find.byType(FilledButton)), findsNothing);

        await tester.tap(_inHeader('待存書'));
        await _settle(tester);
        final pending = _card('書 40');
        expect(find.descendant(of: pending, matching: find.text(S.markAsDroppedOff)), findsOneWidget);
        await tester.tap(find.descendant(of: pending, matching: find.text(S.cancelOrder)));
        await _settle(tester);
        expect(find.text(S.buyerNotifiedBookReturnsShop), findsOneWidget);
        await tester.tap(find.text(S.cancelOrder).last);
        await _settle(tester);
        expect(sent, ['PATCH /api/orders/4/cancel {"reason":"${S.cancelledBySeller}"}']);
        await tester.pump(const Duration(seconds: 4));
      },
      () => MockClient((request) async {
        if (request.method != 'GET') {
          sent.add('${request.method} ${request.url.path} ${request.body}');
          return _json(_order(4, 'cancelled'));
        }
        if (request.url.queryParameters['role'] != 'seller' || request.url.queryParameters['limit'] == '1') {
          return _json(<Object>[]);
        }
        final tab = request.url.queryParameters['tab'];
        tabs.add(tab);
        return _json(switch (tab) {
          'awaiting_pickup' => [_order(9, 'deposited', pickedUpAt: _now)],
          'awaiting_deposit' => [_order(4, 'pending_deposit')],
          _ => <Object>[],
        });
      }),
    );
  });
}
