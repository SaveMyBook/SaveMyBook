import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:savemybook_app/features/account/profile_screen.dart';
import 'package:savemybook_app/features/account/support_ticket_screen.dart';
import 'package:savemybook_app/features/auth/auth_wide_card.dart';
import 'package:savemybook_app/features/auth/register_screen.dart';
import 'package:savemybook_app/features/home/notification_screen.dart';
import 'package:savemybook_app/features/orders/cart_screen.dart';
import 'package:savemybook_app/features/orders/my_reservations_screen.dart';
import 'package:savemybook_app/features/orders/order_detail_screen.dart';
import 'package:savemybook_app/features/orders/order_history_screen.dart';
import 'package:savemybook_app/features/orders/widgets/order_record_card.dart';
import 'package:savemybook_app/i18n/app_localizations.dart';
import 'package:savemybook_app/i18n/strings.dart';
import 'package:savemybook_app/models/security.dart';
import 'package:savemybook_app/models/user.dart';
import 'package:savemybook_app/services/api_service.dart';
import 'package:savemybook_app/services/locale_provider.dart';
import 'package:savemybook_app/services/theme_provider.dart';
import 'package:savemybook_app/services/verification_service.dart';
import 'package:savemybook_app/utils/app_theme.dart';
import 'package:savemybook_app/widgets/pin_pad.dart';

import '../../tool/web_shots/demo_data.dart';

const _landscape = Size(1180, 820);
const _portrait = Size(820, 1180);
const _phone = Size(390, 844);

final _navigatorKey = GlobalKey<NavigatorState>();

Map<String, dynamic> _ticket(int id, String subject, {List<Map<String, dynamic>> messages = const []}) => {
  'ticket_id': id,
  'subject': subject,
  'category': 'cabinet',
  'status': 'open',
  'message_count': messages.length,
  'last_message': '請協助確認櫃門狀態。',
  'created_at': ago(days: id),
  'updated_at': ago(hours: id),
  'messages': messages,
};

http.Response _json(Object? data, {int? total}) => http.Response(
  jsonEncode({
    'success': true,
    'message': 'OK',
    'data': data,
    if (data is List) 'pagination': {'total': total ?? data.length, 'page': 1, 'limit': 20, 'total_pages': 1},
  }),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

final _demo = demoApi();

MockClient _api() => MockClient((request) async {
  final path = request.url.path.replaceFirst('/api', '');
  switch ('${request.method} $path') {
    case 'GET /support/tickets':
      return _json([_ticket(1, '櫃門無法開啟'), _ticket(2, '代幣儲值未入帳')]);
    case 'GET /support/tickets/1':
      return _json(
        _ticket(1, '櫃門無法開啟', messages: [
          {'message_id': 1, 'content': '掃描後櫃門沒有打開。', 'is_staff': false, 'created_at': ago(hours: 2), 'sender': {'nickname': '海嫄'}},
        ]),
      );
    case 'GET /security':
      return _json({'available': true, 'has_payment_pin': true, 'biometric_pay_enabled': false, 'has_password': true});
    case 'GET /users/me/level':
      return _json(<String, Object>{});
    case 'GET /cart':
      return _json([
        for (final (i, id) in [1, 10].indexed) {'cart_id': i + 1, 'books': bookOf(id).toJson()},
      ]);
  }
  final copy = http.Request(request.method, request.url)
    ..headers.addAll(request.headers)
    ..bodyBytes = request.bodyBytes;
  return http.Response.fromStream(await _demo.send(copy));
});

Future<void> _pump(WidgetTester tester, Size size, Widget home) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: _navigatorKey,
      locale: const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      supportedLocales: LocaleProvider.supported,
      theme: AppTheme.build(Brightness.dark),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        S = AppLocalizations.of(context);
        return child!;
      },
      home: home,
    ),
  );
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// 在模擬 API 下執行並收集版面溢出與例外（圖片載入失敗不計）。
Future<void> _run(WidgetTester tester, Future<void> Function() body) async {
  final errors = <String>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.exceptionAsString();
    if (text.contains('NetworkImageLoadException') || text.contains('HTTP request failed')) return;
    errors.add(text.split('\n').first);
  };
  try {
    await http.runWithClient(() async {
      await body();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    }, _api);
  } finally {
    FlutterError.onError = previous;
  }
  expect(errors, isEmpty, reason: '版面溢出或元件例外');
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    themeProvider = await ThemeProvider.init();
    localeProvider = await LocaleProvider.init();
  });

  setUp(() {
    ApiService.authToken = 'demo-token';
    ApiService.currentUser = User.fromJson(user(meId));
  });

  group('訂單紀錄', () {
    testWidgets('平板橫向：列表與訂單詳情左右並排，選取的訂單有標示', (tester) async {
      await _run(tester, () async {
        await _pump(tester, _landscape, const OrderHistoryScreen());
        expect(find.text(S.selectItemToView), findsOneWidget);
        await tester.tap(find.text('統計學概論').first);
        await _settle(tester);
        expect(find.byType(OrderDetailScreen), findsOneWidget);
        expect(find.byType(OrderRecordCard), findsNWidgets(2), reason: '列表仍顯示在左側');
        final selected = tester.widgetList<OrderRecordCard>(find.byType(OrderRecordCard)).where((c) => c.selected);
        expect(selected, hasLength(1));
        expect(tester.getTopLeft(find.byType(OrderDetailScreen)).dx, greaterThan(tester.getTopRight(find.byType(OrderRecordCard).first).dx));
      });
    });

    testWidgets('平板直向：單欄，點訂單推入詳情頁', (tester) async {
      await _run(tester, () async {
        await _pump(tester, _portrait, const OrderHistoryScreen());
        expect(find.text(S.selectItemToView), findsNothing);
        await tester.tap(find.text('統計學概論').first);
        await _settle(tester);
        expect(find.byType(OrderDetailScreen), findsOneWidget);
        expect(find.byType(OrderRecordCard), findsNothing);
        expect(tester.getSize(find.byType(OrderDetailScreen)).width, _portrait.width);
      });
    });
  });

  group('客服工單', () {
    testWidgets('平板橫向：工單列表與內容並排；直向：推入內容頁', (tester) async {
      await _run(tester, () async {
        await _pump(tester, _landscape, const SupportTicketScreen());
        await tester.tap(find.text('櫃門無法開啟').first);
        await _settle(tester);
        expect(find.byType(TicketDetailScreen), findsOneWidget);
        expect(find.text('代幣儲值未入帳'), findsOneWidget, reason: '列表仍顯示在左側');
        expect(find.text('掃描後櫃門沒有打開。'), findsOneWidget);
      });
      await _run(tester, () async {
        await _pump(tester, _portrait, const SupportTicketScreen());
        await tester.tap(find.text('櫃門無法開啟').first);
        await _settle(tester);
        expect(find.byType(TicketDetailScreen), findsOneWidget);
        expect(find.text('代幣儲值未入帳'), findsNothing);
      });
    });
  });

  group('交易密碼', () {
    Future<void> open(WidgetTester tester, Size size) async {
      await _pump(tester, size, const Scaffold(body: SizedBox()));
      VerificationService.navigatorKey = _navigatorKey;
      VerificationService.paymentSummary = const PaymentSummary(amount: 280, detail: '');
      addTearDown(() => VerificationService.paymentSummary = null);
      unawaited(VerificationService.handle(const VerificationRequest(scope: 'payment', methods: ['pin'], message: '')));
      await _settle(tester);
      expect(find.byType(NumberPad), findsOneWidget);
    }

    testWidgets('平板以置中對話框呈現，數字鍵盤寬度合宜', (tester) async {
      await _run(tester, () async {
        await open(tester, _landscape);
        expect(find.byType(Dialog), findsOneWidget);
        expect(find.byType(BottomSheet), findsNothing);
        final pad = tester.getRect(find.byType(NumberPad));
        expect(pad.width, lessThanOrEqualTo(400));
        expect(pad.center.dx, closeTo(_landscape.width / 2, 1));
        _navigatorKey.currentState!.pop();
        await _settle(tester);
      });
    });

    testWidgets('手機維持底部面板', (tester) async {
      await _run(tester, () async {
        await open(tester, _phone);
        expect(find.byType(Dialog), findsNothing);
        expect(find.byType(BottomSheet), findsOneWidget);
        _navigatorKey.currentState!.pop();
        await _settle(tester);
      });
    });
  });

  testWidgets('通知中心：平板橫向兩欄、直向單欄置中', (tester) async {
    await _run(tester, () async {
      await _pump(tester, _landscape, const NotificationScreen(embedded: true));
      final first = tester.getRect(find.text('書籍已存入書櫃'));
      final second = tester.getRect(find.text('款項已撥入錢包'));
      expect(second.top, closeTo(first.top, 1), reason: '同一列');
      expect(second.left, greaterThan(first.right));
    });
    await _run(tester, () async {
      await _pump(tester, _portrait, const NotificationScreen(embedded: true));
      final first = tester.getRect(find.text('書籍已存入書櫃'));
      final second = tester.getRect(find.text('款項已撥入錢包'));
      expect(second.left, closeTo(first.left, 1));
      expect(second.top, greaterThan(first.bottom));
    });
  });

  testWidgets('我的預約：平板依寬度多欄，同列卡片等高', (tester) async {
    await _run(tester, () async {
      await _pump(tester, _portrait, const MyReservationsScreen());
      expect(find.text(S.buyNow), findsNWidgets(2));
      final a = tester.getRect(find.text(S.buyNow).first);
      final b = tester.getRect(find.text(S.buyNow).last);
      expect(b.top, closeTo(a.top, 1), reason: '兩張卡片在同一列且按鈕對齊');
      expect(b.left, greaterThan(a.right));
    });
  });

  testWidgets('會員中心：平板直向功能分組兩欄並排', (tester) async {
    await _run(tester, () async {
      await _pump(tester, _portrait, const ProfileScreen());
      final orders = tester.getRect(find.text(S.orderHistory));
      final security = tester.getRect(find.text(S.accountSecurity));
      expect(security.top, closeTo(orders.top, 1));
      expect(security.left, greaterThan(orders.right));
    });
  });

  testWidgets('購物車：平板直向的結帳列不拉滿整個寬度', (tester) async {
    await _run(tester, () async {
      await _pump(tester, _portrait, const CartScreen());
      final bar = find.ancestor(
        of: find.text(S.checkOut),
        matching: find.byWidgetPredicate((w) => w is Container && w.decoration is BoxDecoration && (w.decoration! as BoxDecoration).borderRadius == BorderRadius.circular(20)),
      );
      expect(bar, findsOneWidget);
      final rect = tester.getRect(bar);
      expect(rect.width, lessThanOrEqualTo(760));
      expect(rect.bottom, lessThan(_portrait.height), reason: '浮動於底部而非貼齊邊緣');
    });
  });

  testWidgets('註冊：平板以置中卡片呈現，手機維持原樣', (tester) async {
    await _run(tester, () async {
      await _pump(tester, _landscape, const RegisterScreen());
      final card = tester.getRect(find.byType(AuthWideCard));
      expect(card.width, _landscape.width);
      final form = tester.getRect(
        find.descendant(
          of: find.byType(AuthWideCard),
          matching: find.byWidgetPredicate((w) => w is Container && w.decoration is BoxDecoration && (w.decoration! as BoxDecoration).borderRadius == BorderRadius.circular(24)),
        ),
      );
      expect(form.width, lessThanOrEqualTo(500));
      expect(form.center.dx, closeTo(_landscape.width / 2, 1));
    });
    await _run(tester, () async {
      await _pump(tester, _phone, const RegisterScreen());
      expect(find.byType(AuthWideCard), findsNothing);
    });
  });
}
