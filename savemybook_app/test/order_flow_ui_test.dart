import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:savemybook_app/features/orders/purchase_history_screen.dart';
import 'package:savemybook_app/features/selling/book_manage_screen.dart';
import 'package:savemybook_app/features/selling/sales_history_screen.dart';
import 'package:savemybook_app/i18n/app_localizations.dart';
import 'package:savemybook_app/i18n/strings.dart';
import 'package:savemybook_app/models/user.dart';
import 'package:savemybook_app/services/api_service.dart';
import 'package:savemybook_app/services/locale_provider.dart';
import 'package:savemybook_app/utils/app_theme.dart';

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

Map<String, dynamic> _order(int id, String status, {DateTime? pickedUpAt}) => {
  'order_id': id,
  'order_no': 'SMB$id',
  'buyer_id': 1,
  'seller_id': 2,
  'total_amount': 200,
  'status': status,
  'picked_up_at': pickedUpAt?.toIso8601String(),
  'order_items': [
    {'item_id': id, 'book_id': id, 'quantity': 1, 'unit_price': 200, 'subtotal': 200, 'books': _book(id, '書 $id')},
  ],
  'transaction_disputes': <Object>[],
};

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

  testWidgets('購買紀錄：已取書的訂單在已完成分頁，可完成訂單或申請爭議；完成需確認', (tester) async {
    tester.view.physicalSize = const Size(390, 900) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final sent = <String>[];

    await http.runWithClient(
      () async {
        await tester.pumpWidget(_host(const PurchaseHistoryScreen()));
        await _settle(tester);
        await tester.tap(find.text(S.orderCompleted).first);
        await _settle(tester);

        expect(find.text('待完成訂單'), findsOneWidget);
        expect(find.text('完成訂單'), findsOneWidget);
        expect(find.text(S.openDispute), findsOneWidget);

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
        return _json(tab == 'completed' ? [_order(7, 'deposited', pickedUpAt: _now)] : <Object>[]);
      }),
    );
  });

  testWidgets('購買紀錄：已預訂分頁列出保留中與等待回覆的預約', (tester) async {
    tester.view.physicalSize = const Size(360, 900) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await http.runWithClient(
      () async {
        await tester.pumpWidget(_host(const PurchaseHistoryScreen()));
        await _settle(tester);
        await tester.tap(find.text(S.bookReserved).first);
        await _settle(tester);
        expect(find.text('小王子'), findsOneWidget);
        expect(find.textContaining('保留至'), findsOneWidget);
        expect(find.text(S.buyNow), findsOneWidget);
        expect(find.text(S.awaitingReply), findsOneWidget);
        expect(find.text(S.cancelReservation2), findsNWidgets(2));
        await tester.pump(const Duration(seconds: 4));
      },
      () => MockClient((request) async {
        if (request.url.path.endsWith('/chat/reservations/mine')) {
          return _json([
            {
              'reservation_id': 1,
              'book': {'book_id': 1, 'title': '小王子', 'price': 150, 'status': 'on_sale'},
              'status': 'confirmed',
              'pickup_deadline': _now.add(const Duration(hours: 20)).toIso8601String(),
              'is_holding': true,
            },
            {
              'reservation_id': 2,
              'book': {'book_id': 2, 'title': '夜間飛行', 'price': 120, 'status': 'on_sale'},
              'status': 'pending',
              'is_holding': false,
            },
          ]);
        }
        return _json(<Object>[]);
      }),
    );
  });

  testWidgets('書籍管理：已預訂、已售出、已完成分頁，這些書不能編輯或下架', (tester) async {
    tester.view.physicalSize = const Size(390, 1400) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await http.runWithClient(
      () async {
        await tester.pumpWidget(_host(const BookManageScreen()));
        await _settle(tester);
        for (final label in [S.bookReserved, S.bookSold, S.orderCompleted]) {
          expect(find.textContaining(label), findsWidgets, reason: label);
        }
        await tester.tap(find.textContaining(S.bookReserved).first);
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

  testWidgets('銷售紀錄：新增已存書分頁，取書後標示待買家確認；販售中只放沒有訂單的書', (tester) async {
    tester.view.physicalSize = const Size(390, 900) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final tabs = <String?>[];

    await http.runWithClient(
      () async {
        await tester.pumpWidget(_host(const SalesHistoryScreen()));
        await _settle(tester);
        await tester.tap(find.text(S.orderDeposited).first);
        await _settle(tester);
        expect(find.text('待買家確認'), findsOneWidget);
        await tester.tap(find.text(S.bookOnSale).first);
        await _settle(tester);
        expect(find.text('販售中的書'), findsOneWidget);
        expect(find.text('訂單成立'), findsNothing);
        expect(tabs, contains('deposited'));
        expect(tabs, isNot(contains('on_sale')), reason: '販售中不再查詢訂單');
        await tester.pump(const Duration(seconds: 4));
      },
      () => MockClient((request) async {
        if (request.url.path.endsWith('/orders')) {
          tabs.add(request.url.queryParameters['tab']);
          return _json(
            request.url.queryParameters['tab'] == 'deposited' ? [_order(9, 'deposited', pickedUpAt: _now)] : <Object>[],
          );
        }
        if (request.url.path.endsWith('/books')) {
          return _json([_book(1, '販售中的書'), _book(3, '訂單成立', status: 'reserved')]);
        }
        return _json(<Object>[]);
      }),
    );
  });
}
