import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:savemybook_app/features/account/profile_screen.dart';
import 'package:savemybook_app/features/chat/chat_room_screen.dart';
import 'package:savemybook_app/features/orders/my_reservations_screen.dart';
import 'package:savemybook_app/features/selling/book_manage_screen.dart';
import 'package:savemybook_app/i18n/app_localizations.dart';
import 'package:savemybook_app/i18n/strings.dart';
import 'package:savemybook_app/models/user.dart';
import 'package:savemybook_app/services/api_service.dart';
import 'package:savemybook_app/services/locale_provider.dart';
import 'package:savemybook_app/utils/app_theme.dart';
import 'package:savemybook_app/widgets/app_buttons.dart';
import 'package:savemybook_app/widgets/state_views.dart';

final _now = DateTime.now();

Map<String, dynamic> _reservation(
  int id,
  String title, {
  String status = 'pending',
  Duration? holdLeft,
  DateTime? createdAt,
}) => {
  'reservation_id': id,
  'book': {'book_id': id, 'title': title, 'price': 180, 'status': 'on_sale', 'image_url': null},
  'buyer_id': 1,
  'seller_id': 2,
  'status': status,
  'hours': 24,
  'pickup_deadline': holdLeft == null ? null : _now.add(holdLeft).toUtc().toIso8601String(),
  'is_holding': status == 'confirmed',
  'created_at': (createdAt ?? _now).toUtc().toIso8601String(),
  'seller': {'user_id': 2, 'nickname': '舊書攤'},
  'room_id': 21,
};

Map<String, dynamic> _book(int id, String title, {String status = 'on_sale', String? review, Map<String, dynamic>? reservation}) => {
  'book_id': id,
  'seller_id': 1,
  'title': title,
  'price': 180,
  'status': status,
  'is_approved': review == null,
  'review_status': review,
  'book_images': <Object>[],
  'users': {'user_id': 1, 'nickname': '我'},
  'reservation': ?reservation,
};

Widget _host(Widget child, {Locale locale = const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')}) => MaterialApp(
  locale: locale,
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
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

http.Response _json(Object? data) => http.Response(
  jsonEncode({'success': true, 'data': data}),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Finder _cardOf(String title) => find.ancestor(of: find.text(title), matching: find.byType(AppCard)).first;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiService.resetGlobalState();
    ApiService.authToken = 'token';
    ApiService.currentUser = User.fromJson({
      'user_id': 1,
      'nickname': '我',
      'email': 'me@example.com',
      'role': 'buyer_seller',
    });
  });

  Future<List<String>> run(WidgetTester tester, Widget screen, Future<void> Function(List<String> requests) body,
      {required Future<http.Response> Function(http.Request request) handler}) async {
    tester.view.physicalSize = const Size(390, 1200) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final requests = <String>[];
    await http.runWithClient(
      () async {
        await tester.pumpWidget(_host(screen));
        await _settle(tester);
        await body(requests);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 4));
      },
      () => MockClient((request) async {
        requests.add('${request.method} ${request.url.path}${request.body.isEmpty ? '' : ' ${request.body}'}');
        return handler(request);
      }),
    );
    return requests;
  }

  final mine = [
    _reservation(1, '夜間飛行', status: 'confirmed', holdLeft: const Duration(hours: 30, seconds: 30)),
    _reservation(2, '小王子', status: 'confirmed', holdLeft: const Duration(hours: 5, minutes: 20, seconds: 30)),
    _reservation(3, '人間失格', createdAt: DateTime(2026, 9, 30, 14, 5)),
    _reservation(4, '已到期的書', status: 'confirmed', holdLeft: const Duration(minutes: -5)),
  ];

  testWidgets('我的預約：已保留依期限排序並顯示賣家與剩餘時間，待賣家回覆顯示送出時間', (tester) async {
    await run(tester, const MyReservationsScreen(), (_) async {
      expect(find.text(S.reservationHeld), findsOneWidget);
      expect(find.text(S.awaitingSellerReply), findsOneWidget);
      expect(find.text('小王子'), findsOneWidget);
      expect(find.text('夜間飛行'), findsOneWidget);
      expect(find.text('人間失格'), findsNothing);
      expect(find.text('已到期的書'), findsNothing);
      expect(tester.getTopLeft(find.text('小王子')).dy, lessThan(tester.getTopLeft(find.text('夜間飛行')).dy));
      expect(find.text(S.seller3('舊書攤')), findsNWidgets(2));
      expect(find.text(S.reservationTimeLeftHoursMinutes(5, 20)), findsOneWidget);
      expect(find.text(S.reservationTimeLeftHoursMinutes(30, 0)), findsOneWidget);
      expect(find.text(S.buyNow), findsNWidgets(2));
      expect(find.text(S.cancelReservation2), findsNWidgets(2));

      await tester.tap(find.text(S.awaitingSellerReply));
      await _settle(tester);
      expect(find.text('人間失格'), findsOneWidget);
      expect(find.text('小王子'), findsNothing);
      expect(find.text(S.reservationSentAtP0('09/30 14:05')), findsOneWidget);
      expect(find.text(S.buyNow), findsNothing);
      expect(find.text(S.cancelReservation2), findsOneWidget);
    }, handler: (request) async => _json(request.url.path.endsWith('/chat/reservations/mine') ? mine : <Object>[]));
  });

  testWidgets('我的預約：沒有預約時各分頁顯示對應的空白訊息', (tester) async {
    await run(tester, const MyReservationsScreen(), (_) async {
      expect(find.text(S.noHeldReservations), findsOneWidget);
      await tester.tap(find.text(S.awaitingSellerReply));
      await _settle(tester);
      expect(find.text(S.noPendingReservations), findsOneWidget);
    }, handler: (_) async => _json(<Object>[]));
  });

  testWidgets('我的預約：取消預約需確認，送出後重新載入', (tester) async {
    var cancelled = false;
    final requests = await run(tester, const MyReservationsScreen(), (_) async {
      await tester.tap(find.descendant(of: _cardOf('小王子'), matching: find.text(S.cancelReservation2)));
      await _settle(tester);
      expect(find.text(S.p0NoLongerHeld('小王子')), findsOneWidget);
      await tester.tap(find.text(S.cancelReservation2).last);
      await _settle(tester);
      expect(find.text(S.reservationCanceled), findsOneWidget);
      expect(find.text('小王子'), findsNothing);
    }, handler: (request) async {
      if (request.method == 'PATCH') {
        cancelled = true;
        return _json({..._reservation(2, '小王子'), 'status': 'cancelled'});
      }
      if (request.url.path.endsWith('/chat/reservations/mine')) {
        return _json(cancelled ? mine.where((r) => r['reservation_id'] != 2).toList() : mine);
      }
      return _json(<Object>[]);
    });
    expect(requests, contains('PATCH /api/chat/reservations/2 {"action":"cancel"}'));
    expect(requests.where((r) => r == 'GET /api/chat/reservations/mine').length, 2);
  });

  testWidgets('我的預約：購買沿用直接購買流程，不經購物車', (tester) async {
    final requests = await run(tester, const MyReservationsScreen(), (_) async {
      await tester.tap(find.descendant(of: _cardOf('小王子'), matching: find.text(S.buyNow)));
      await _settle(tester);
      expect(find.text(S.paymentSuccessful), findsOneWidget);
      await tester.tap(find.text(S.keepBrowsing));
      await _settle(tester);
    }, handler: (request) async {
      final path = request.url.path;
      if (path.endsWith('/chat/reservations/mine')) return _json(mine);
      if (path.endsWith('/books/2')) {
        return _json({
          ..._book(2, '小王子'),
          'seller_id': 2,
          'reservation': {'reserved_until': _now.add(const Duration(hours: 5)).toUtc().toIso8601String(), 'reserved_for_me': true},
        });
      }
      if (path.endsWith('/wallet')) return _json({'balance': 500});
      if (path.endsWith('/orders/buy-now')) return _json({'order_id': 9});
      return _json(<Object>[]);
    });
    expect(requests, contains('POST /api/orders/buy-now {"book_id":2}'));
    expect(requests.where((r) => r.startsWith('POST /api/cart')), isEmpty);
  });

  testWidgets('我的預約：聊天按鈕開啟與賣家的聊天室', (tester) async {
    await run(tester, const MyReservationsScreen(), (_) async {
      await tester.tap(find.descendant(of: _cardOf('小王子'), matching: find.byTooltip(S.messageSeller)));
      await _settle(tester);
      final room = tester.widget<ChatRoomScreen>(find.byType(ChatRoomScreen));
      expect(room.roomId, 21);
      expect(room.partnerName, '舊書攤');
    }, handler: (request) async {
      final path = request.url.path;
      if (path.endsWith('/chat/reservations/mine')) return _json(mine);
      if (path.endsWith('/chat/unread-count')) return _json({'unread_count': 0});
      return _json(<Object>[]);
    });
  });

  for (final locale in LocaleProvider.supported) {
    for (final width in [320.0, 390.0]) {
      testWidgets('我的預約：${locale.toLanguageTag()} 寬 ${width.toInt()} 兩個分頁不跑版', (tester) async {
        const longName = 'Alexandria Montgomery-Wellington';
        const longTitle = 'The Extraordinarily Long Title of a Second-hand Book About Everything';
        final data = [
          for (final r in mine)
            {
              ...r,
              'book': {...r['book'] as Map<String, dynamic>, 'title': longTitle, 'price': 1234567},
              'seller': {'user_id': 2, 'nickname': longName},
            },
        ];
        tester.view.physicalSize = Size(width, 800) * 3;
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        await http.runWithClient(
          () async {
            await tester.pumpWidget(_host(const MyReservationsScreen(), locale: locale));
            await _settle(tester);
            expect(find.text(longTitle), findsNWidgets(2));
            await tester.tap(find.text(S.awaitingSellerReply));
            await _settle(tester);
            expect(find.text(longTitle), findsOneWidget);
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump(const Duration(seconds: 4));
          },
          () => MockClient((request) async => _json(request.url.path.endsWith('/chat/reservations/mine') ? data : <Object>[])),
        );
      });
    }
  }

  testWidgets('會員中心：快捷列的我的預約顯示已保留筆數並開啟我的預約', (tester) async {
    await run(tester, const ProfileScreen(), (_) async {
      final button = find.ancestor(of: find.text(S.myReservations), matching: find.byType(QuickActionButton));
      expect(button, findsOneWidget);
      expect(find.descendant(of: button, matching: find.text('2')), findsOneWidget);
      expect(find.ancestor(of: find.text(S.myBooks), matching: find.byType(QuickActionButton)), findsNothing);
      await tester.tap(find.text(S.myReservations));
      await _settle(tester);
      expect(find.byType(MyReservationsScreen), findsOneWidget);
    }, handler: (request) async {
      final path = request.url.path;
      if (path.endsWith('/chat/reservations/mine')) return _json(mine);
      if (path.endsWith('/auth/me')) return _json({'user_id': 1, 'nickname': '我', 'email': 'me@example.com', 'role': 'buyer_seller'});
      if (path.endsWith('/users/me/stats') || path.endsWith('/users/me/level')) return _json(<String, Object>{});
      return _json(<Object>[]);
    });
  });

  testWidgets('書籍管理：篩選依序為全部、販售中、審核中、已被預約、已售出、已完成、已下架、待取回，審核中的書不列在販售中', (tester) async {
    final books = [
      _book(1, '販售中的書'),
      _book(2, '待審核的書', review: 'pending'),
      _book(3, '被預約的書', reservation: {'reserved_until': _now.add(const Duration(hours: 5)).toUtc().toIso8601String()}),
      _book(4, '訂單成立的書', status: 'reserved'),
    ];
    await run(tester, const BookManageScreen(), (_) async {
      final labels = [
        S.actionAll,
        S.bookOnSale,
        S.reportReviewing,
        S.bookHeldForBuyer,
        S.bookSold,
        S.orderCompleted,
        S.bookRemoved,
        S.awaitingRetrieval,
      ];
      final bar = find.byWidgetPredicate((w) => w is ListView && w.scrollDirection == Axis.horizontal);
      final chips = tester
          .widgetList<Text>(find.descendant(of: bar, matching: find.byType(Text)))
          .map((t) => t.data!.replaceAll(RegExp(r' \d+$'), ''))
          .toList();
      expect(chips, labels.take(chips.length).toList());

      Future<void> select(String label) async {
        await tester.scrollUntilVisible(find.descendant(of: bar, matching: find.textContaining(label)), 80,
            scrollable: find.descendant(of: bar, matching: find.byType(Scrollable)));
        await tester.tap(find.descendant(of: bar, matching: find.textContaining(label)).first);
        await _settle(tester);
      }

      await select(S.bookOnSale);
      expect(find.text('販售中的書'), findsOneWidget);
      expect(find.text('待審核的書'), findsNothing);

      await select(S.reportReviewing);
      expect(find.text('待審核的書'), findsOneWidget);
      expect(find.text('販售中的書'), findsNothing);

      await select(S.bookHeldForBuyer);
      expect(find.text('被預約的書'), findsOneWidget);
      expect(find.text('販售中的書'), findsNothing);
    }, handler: (request) async => _json(request.url.path.endsWith('/books') ? books : <Object>[]));
  });
}
