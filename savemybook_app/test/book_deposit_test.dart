import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:savemybook_app/features/admin/admin_cabinet_deposit_screen.dart';
import 'package:savemybook_app/features/books/book_detail_screen.dart';
import 'package:savemybook_app/features/orders/cart_screen.dart';
import 'package:savemybook_app/features/orders/order_detail_screen.dart';
import 'package:savemybook_app/features/orders/purchase_history_screen.dart';
import 'package:savemybook_app/features/orders/widgets/order_card.dart';
import 'package:savemybook_app/features/selling/book_manage_screen.dart';
import 'package:savemybook_app/features/selling/edit_book_detail_screen.dart';
import 'package:savemybook_app/features/selling/edit_book_screen.dart';
import 'package:savemybook_app/features/selling/sales_history_screen.dart';
import 'package:savemybook_app/i18n/app_localizations.dart';
import 'package:savemybook_app/i18n/strings.dart';
import 'package:savemybook_app/models/admin_models.dart';
import 'package:savemybook_app/models/book.dart';
import 'package:savemybook_app/models/cart_item.dart';
import 'package:savemybook_app/models/notification_category.dart';
import 'package:savemybook_app/models/order.dart';
import 'package:savemybook_app/models/user.dart';
import 'package:savemybook_app/services/api_service.dart';
import 'package:savemybook_app/services/locale_provider.dart';
import 'package:savemybook_app/services/notification_router.dart';
import 'package:savemybook_app/utils/app_colors.dart';
import 'package:savemybook_app/utils/app_theme.dart';
import 'package:savemybook_app/widgets/app_buttons.dart';
import 'package:savemybook_app/widgets/app_header.dart';
import 'package:savemybook_app/widgets/app_select.dart';
import 'package:savemybook_app/widgets/state_views.dart';
import 'package:savemybook_app/widgets/swipe_action.dart';

const _cabinet = {'cabinet_id': 3, 'cabinet_name': '台大書櫃', 'address': '臺北市大安區羅斯福路四段1號'};

Map<String, dynamic> _deposit(int days, {bool paused = false}) => {
  'deposited_at': DateTime.now().subtract(Duration(days: days)).toUtc().toIso8601String(),
  'paused': paused,
  'days_stored': days,
};

Map<String, dynamic> _book(
  int id,
  String title, {
  int sellerId = 1,
  String status = 'on_sale',
  Map<String, dynamic>? deposit,
  bool inCabinet = false,
  int cabinetId = 3,
}) => {
  'book_id': id,
  'seller_id': sellerId,
  'title': title,
  'price': 180,
  'status': status,
  'is_approved': true,
  'cabinet_id': cabinetId,
  'smart_cabinets': {..._cabinet, 'cabinet_id': cabinetId},
  'book_images': <Object>[],
  'users': {'user_id': sellerId, 'nickname': '賣家'},
  'in_cabinet': inCabinet,
  'deposit': deposit,
};

const _zhHant = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');

Widget _host(Widget child, {GlobalKey<NavigatorState>? navigatorKey, Locale locale = _zhHant, double textScale = 1}) => MaterialApp(
  navigatorKey: navigatorKey,
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
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
      child: inner ?? const SizedBox.shrink(),
    );
  },
  home: child,
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

http.Response _json(Object? data, {int status = 200, Map<String, Object?> extra = const {}}) => http.Response(
  jsonEncode({'success': status < 300, 'data': data, ...extra}),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void _setUser({int id = 1, String role = 'buyer_seller'}) {
  ApiService.currentUser = User.fromJson({'user_id': id, 'nickname': '我', 'email': 'me@example.com', 'role': role});
}

Future<void> _pumpScreen(
  WidgetTester tester,
  Widget screen, {
  Size size = const Size(390, 900),
  Locale locale = _zhHant,
  double textScale = 1,
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_host(screen, locale: locale, textScale: textScale));
  await _settle(tester);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiService.resetGlobalState();
    ApiService.authToken = 'token';
    _setUser();
  });

  group('模型', () {
    test('書籍解析 in_cabinet 與本人的存書資訊', () {
      final book = Book.fromJson(_book(1, '小王子', deposit: _deposit(8, paused: true), inCabinet: true));
      expect(book.inCabinet, isTrue);
      expect(book.isDeposited, isTrue);
      expect(book.isDepositPaused, isTrue);
      expect(book.deposit!.daysStored, 8);
      expect(book.deposit!.depositedAt, isNotNull);
      expect(book.canRegisterDeposit, isFalse);

      final plain = Book.fromJson({'book_id': 2, 'title': '夜間飛行', 'status': 'on_sale', 'cabinet_id': 3, 'deposit': null});
      expect(plain.inCabinet, isFalse);
      expect(plain.deposit, isNull);
      expect(plain.depositKnown, isTrue);
      expect(plain.canRegisterDeposit, isTrue);
      final owned = {'status': 'on_sale', 'cabinet_id': 3, 'deposit': null};
      expect(Book.fromJson({'book_id': 3, 'status': 'on_sale', 'deposit': null}).canRegisterDeposit, isFalse, reason: '未指定書櫃');
      expect(Book.fromJson({...owned, 'book_id': 4, 'is_approved': false}).canRegisterDeposit, isFalse);
      expect(Book.fromJson({...owned, 'book_id': 5, 'status': 'removed'}).canRegisterDeposit, isFalse);
    });

    test('公開列表未提供 deposit 時不視為未存書，in_cabinet 仍視為已存書', () {
      final public = Book.fromJson({'book_id': 2, 'status': 'on_sale', 'cabinet_id': 3});
      expect(public.depositKnown, isFalse);
      expect(public.isDeposited, isFalse);
      expect(public.canRegisterDeposit, isFalse, reason: '公開列表不含存書資訊，須待賣家本人的詳情載入');

      final stored = Book.fromJson({'book_id': 3, 'status': 'on_sale', 'cabinet_id': 3, 'in_cabinet': true});
      expect(stored.depositKnown, isFalse);
      expect(stored.isDeposited, isTrue);
      expect(stored.canRegisterDeposit, isFalse);
    });

    test('訂單項目解析結帳前已存書，並區分是否存放於訂單書櫃', () {
      final order = Order.fromJson({
        'order_id': 9,
        'status': 'pending_deposit',
        'cabinet_id': 3,
        'order_items': [
          {'item_id': 1, 'book_id': 5, 'pre_deposited': true, 'books': _book(5, '小王子')},
          {'item_id': 2, 'book_id': 6, 'pre_deposited': true, 'books': _book(6, '夜間飛行', cabinetId: 4)},
          {'item_id': 3, 'book_id': 7, 'pre_deposited': false, 'books': _book(7, '異鄉人')},
        ],
      });
      expect(order.cabinetId, 3);
      expect(order.items.map((i) => i.preDeposited), [true, true, false]);
      expect(order.items.map(order.storedElsewhere), [false, true, false]);
    });

    test('英文與韓文的存書用語', () async {
      final en = await AppLocalizations.delegate.load(const Locale('en'));
      expect(en.lockerP0Days(1), '1d in locker');
      expect(en.lockerP0Days(12), startsWith('12'));
      expect(en.placedLockerToday, 'Stored today');
      expect(en.dropOff, 'Register drop-off');
      expect(en.retrieve, 'Report retrieval');
      final ko = await AppLocalizations.delegate.load(const Locale('ko'));
      expect(ko.adminsNotified, '관리자 알림 완료');
    });

    test('購物車項目沿用書籍的 in_cabinet', () {
      final item = CartItem.fromJson({'cart_id': 1, 'quantity': 1, 'books': _book(1, '小王子', sellerId: 2, inCabinet: true)});
      expect(item.book.inCabinet, isTrue);
    });

    test('後台存書列表項目', () {
      final row = CabinetDeposit.fromJson({
        'book_id': 101,
        'book_no': 'BK3KER74B',
        'title': '挪威的森林',
        'book_status': 'removed',
        'image_url': null,
        'seller': {'user_id': 12, 'user_no': 'MB7Q2XK9D', 'nickname': '小明', 'avatar_url': null, 'deleted': true},
        'cabinet': _cabinet,
        'deposited_at': '2026-09-01T08:00:00.000Z',
        'days_stored': 15,
        'paused': true,
        'escalated': true,
        'overdue': true,
      });
      expect(row.bookId, 101);
      expect(row.title, '挪威的森林');
      expect(row.bookStatus, 'removed');
      expect(row.sellerName, '小明');
      expect(row.sellerDeleted, isTrue);
      expect(row.cabinetId, 3);
      expect(row.cabinetName, '台大書櫃');
      expect(row.daysStored, 15);
      expect(row.paused && row.escalated && row.overdue, isTrue);
    });

    test('確認訊息在各語系的書名與書櫃位置正確', () async {
      final expected = {
        const Locale('en'): ['"T" has been placed in C', 'retrieved "T" from C', 'removed "T" from C'],
        const Locale('ja'): ['「T」を「C」に', '「C」から「T」を回収', '「C」から「T」を取り出した'],
        const Locale('ko'): ['“T”을(를) 「C」에', '「C」에서 “T”을(를) 회수', '「C」에서 “T”을(를) 꺼냈'],
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'): ['《T》放入“C”', '自“C”取回《T》', '自“C”取出《T》'],
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'): ['《T》放入「C」', '自「C」取回《T》', '自「C」取出《T》'],
      };
      for (final entry in expected.entries) {
        final l = await AppLocalizations.delegate.load(entry.key);
        final messages = [
          l.confirmP0BeenPlacedP1('T', 'C'),
          l.confirmRetrievedP1FromP0('C', 'T'),
          l.confirmStaffRemovedP1FromP0('C', 'T'),
        ];
        for (var i = 0; i < messages.length; i++) {
          expect(messages[i], contains(entry.value[i]), reason: '${entry.key}');
        }
      }
    });
  });

  group('API', () {
    test('結帳與直接購買依伺服器回傳的訂單狀態判斷是否已可取書', () async {
      await http.runWithClient(() async {
        final api = ApiService();
        expect(await api.checkout([1]), (error: null, readyForPickup: true));
        expect(await api.checkout([2]), (error: null, readyForPickup: false));
        expect(await api.buyNow(5), (error: null, readyForPickup: true));
        expect(await api.buyNow(6), (error: null, readyForPickup: false));
        expect(await api.buyNow(7), (error: '代幣不足', readyForPickup: false));
      }, () => MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (request.url.path.endsWith('/orders/checkout')) {
          final ready = (body['cart_ids'] as List).first == 1;
          return _json([
            {'order_id': 1, 'status': 'deposited'},
            {'order_id': 2, 'status': ready ? 'deposited' : 'pending_deposit'},
          ], status: 201);
        }
        final id = body['book_id'];
        if (id == 7) return _json(null, status: 400, extra: {'message': '代幣不足'});
        return _json({'order_id': 3, 'status': id == 5 ? 'deposited' : 'pending_deposit'}, status: 201);
      }));
    });

    test('後台存書列表分頁、篩選與登記取出', () async {
      final sent = <String>[];
      await http.runWithClient(() async {
        final api = ApiService();
        final first = await api.fetchCabinetDeposits(overdue: true, cabinetId: 3);
        expect(first.ok, isTrue);
        expect(first.items.single.title, '小王子');
        expect(first.hasMore, isTrue);
        final second = await api.fetchCabinetDeposits(page: 2);
        expect(second.hasMore, isFalse);
        final failed = await api.fetchCabinetDeposits(page: 3);
        expect(failed.ok, isFalse);
        expect(failed.items, isEmpty);
        expect(await api.clearCabinetDeposit(7), isNull);
      }, () => MockClient((request) async {
        sent.add('${request.method} ${request.url.path}${request.url.hasQuery ? '?${request.url.query}' : ''}');
        final page = int.tryParse(request.url.queryParameters['page'] ?? '') ?? 1;
        if (request.method == 'GET' && page == 3) return _json(null, status: 500, extra: {'message': '伺服器錯誤'});
        if (request.method == 'GET') {
          return _json([
            {'book_id': 7, 'title': '小王子', 'cabinet': _cabinet, 'days_stored': 15},
          ], extra: {'pagination': {'total': 21, 'page': page, 'limit': 20, 'total_pages': 2}});
        }
        return _json({'book_id': 7, 'book_status': 'removed'});
      }));
      expect(sent, [
        'GET /api/admin/cabinets/deposits?overdue=true&cabinet_id=3&page=1&limit=20',
        'GET /api/admin/cabinets/deposits?page=2&limit=20',
        'GET /api/admin/cabinets/deposits?page=3&limit=20',
        'POST /api/admin/cabinets/deposits/7/clear',
      ]);
    });
  });

  group('賣家', () {
    late List<Map<String, dynamic>> books;
    late List<Map<String, dynamic>> orders;
    late List<String> sent;
    late List<String> loads;

    Map<String, dynamic> pendingReport(String kind) => {
      'report_no': 'MR4K2Q8ZT',
      'kind': kind,
      'status': 'pending',
      'target_status': null,
      'reason': 'no_device',
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'reviewed_at': null,
      'review_note': null,
    };

    MockClient server() => MockClient((request) async {
      final path = request.url.path;
      if (const ['POST', 'DELETE', 'PATCH'].contains(request.method)) sent.add('${request.method} $path');
      final orderStatus = RegExp(r'/orders/(\d+)/status$').firstMatch(path);
      if (orderStatus != null) {
        final id = int.parse(orderStatus.group(1)!);
        final i = orders.indexWhere((o) => o['order_id'] == id);
        orders[i] = {...orders[i], 'status': (jsonDecode(request.body) as Map)['status']};
        return _json(orders[i]);
      }
      if (path.endsWith('/orders')) {
        loads.add('orders:${request.url.queryParameters['tab']}');
        final pending = request.url.queryParameters['tab'] == 'pending_deposit';
        return _json(orders.where((o) => !pending || const ['pending_payment', 'pending_deposit'].contains(o['status'])).toList());
      }
      if (request.method == 'DELETE') {
        final id = int.parse(path.split('/').last);
        final i = books.indexWhere((b) => b['book_id'] == id);
        books[i] = {...books[i], 'status': 'removed', 'in_cabinet': false};
        return _json({'book_id': id, 'status': 'removed'});
      }
      final deposit = RegExp(r'/books/(\d+)/deposit$').firstMatch(path);
      if (deposit != null) {
        final id = int.parse(deposit.group(1)!);
        final i = books.indexWhere((b) => b['book_id'] == id);
        books[i] = {...books[i], 'manual_report': pendingReport('deposit')};
        return _json(
          {'book_id': id, 'in_cabinet': false, 'deposit': null, 'manual_report': pendingReport('deposit')},
          status: 202,
          extra: {'message': '已送出手動回報，待客服確認後生效'},
        );
      }
      final retrieve = RegExp(r'/books/(\d+)/retrieve$').firstMatch(path);
      if (retrieve != null) {
        final id = int.parse(retrieve.group(1)!);
        final i = books.indexWhere((b) => b['book_id'] == id);
        books[i] = {...books[i], 'manual_report': pendingReport('retrieve'), if (books[i]['status'] == 'on_sale') 'status': 'removed'};
        return _json(
          {'book_id': id, 'status': books[i]['status'], 'restored': false, 'manual_report': pendingReport('retrieve')},
          status: 202,
          extra: {'message': '已送出手動回報，待客服確認後生效'},
        );
      }
      final detail = RegExp(r'/books/(\d+)$').firstMatch(path);
      if (detail != null) return _json(books.firstWhere((b) => b['book_id'] == int.parse(detail.group(1)!)));
      if (path.endsWith('/books')) {
        loads.add('books');
        return _json(books);
      }
      return _json(<Object>[]);
    });

    setUp(() {
      sent = [];
      loads = [];
      orders = [];
      books = [
        _book(1, '小王子'),
        _book(2, '夜間飛行', status: 'removed', deposit: _deposit(9, paused: true)),
        _book(3, '異鄉人', deposit: _deposit(3), inCabinet: true),
        _book(4, '已售出的書', status: 'reserved'),
      ];
    });

    testWidgets('銷售紀錄：販售中可回報存書，確認視窗指明書櫃，送出後待客服確認並停用同一動作', (tester) async {
      await http.runWithClient(() async {
        await _pumpScreen(tester, const SalesHistoryScreen(initialTab: 'on_sale'));
        expect(find.text('已售出的書'), findsNothing);
        expect(find.text('夜間飛行'), findsOneWidget, reason: '逾期暫停販售的書仍列在販售中');
        expect(find.text(S.salesPaused), findsOneWidget);
        expect(find.text('已存放 3 天'), findsOneWidget);

        await tester.tap(find.text(S.dropOff).first);
        await _settle(tester);
        expect(find.text('請確認已將《小王子》放入「台大書櫃」。'), findsOneWidget);
        await tester.tap(find.text(S.dropOff).last);
        await _settle(tester);

        expect(sent, ['POST /api/books/1/deposit']);
        expect(find.text(S.reportSubmittedTakesEffectAfterSupport), findsOneWidget);
        final card = find.ancestor(of: find.text('小王子'), matching: find.byType(SaleCardFrame));
        expect(find.descendant(of: card, matching: find.text(S.manualReportAwaitingConfirmation)), findsOneWidget);
        expect(tester.widget<FilledButton>(find.descendant(of: card, matching: find.byType(FilledButton))).onPressed, isNull);
        await tester.pump(const Duration(seconds: 4));
      }, server);
    });

    testWidgets('銷售紀錄：逾期暫停販售的書回報取回後待客服確認', (tester) async {
      await http.runWithClient(() async {
        await _pumpScreen(tester, const SalesHistoryScreen(initialTab: 'on_sale'));
        final card = find.ancestor(of: find.text('夜間飛行'), matching: find.byType(SaleCardFrame));
        expect(find.descendant(of: card, matching: find.text(S.delist)), findsNothing);

        await tester.tap(find.descendant(of: card, matching: find.text(S.retrieve)));
        await _settle(tester);
        expect(find.text('請確認已自「台大書櫃」取回《夜間飛行》。'), findsOneWidget);
        await tester.tap(find.text(S.retrieve).last);
        await _settle(tester);

        expect(sent, ['POST /api/books/2/retrieve']);
        expect(find.text(S.reportSubmittedTakesEffectAfterSupport), findsOneWidget);
        expect(find.descendant(of: card, matching: find.text(S.manualReportAwaitingConfirmation)), findsOneWidget);
        await tester.pump(const Duration(seconds: 4));
      }, server);
    });

    testWidgets('銷售紀錄：取消確認不送出請求', (tester) async {
      await http.runWithClient(() async {
        await _pumpScreen(tester, const SalesHistoryScreen(initialTab: 'on_sale'));
        await tester.tap(find.text(S.dropOff).first);
        await _settle(tester);
        await tester.tap(find.text(S.actionCancel));
        await _settle(tester);
        expect(sent, isEmpty);
        await tester.pump(const Duration(seconds: 4));
      }, server);
    });

    testWidgets('我的商品：暫停販售的書標示狀態並以回報取回取代重新上架', (tester) async {
      await http.runWithClient(() async {
        await _pumpScreen(tester, const BookManageScreen(), size: const Size(390, 1400));
        expect(find.text(S.salesPaused), findsOneWidget);
        expect(find.text('已存放 9 天'), findsOneWidget);
        expect(find.text('已存放 3 天'), findsOneWidget);
        expect(find.text(S.relist), findsNothing, reason: '仍在書櫃的書須先回報取回才能重新上架');
        expect(find.text(S.retrieve), findsNWidgets(2));
        expect(find.text(S.dropOff), findsOneWidget);

        await tester.tap(find.text(S.retrieve).first);
        await _settle(tester);
        await tester.tap(find.text(S.retrieve).last);
        await _settle(tester);
        expect(sent, ['POST /api/books/2/retrieve']);
        await tester.pump(const Duration(seconds: 4));
      }, server);
    });

    testWidgets('我的商品：回報取回後待客服確認，不提供重新上架', (tester) async {
      await http.runWithClient(() async {
        await _pumpScreen(tester, const BookManageScreen(), size: const Size(390, 1400));
        await tester.tap(find.text(S.retrieve).first);
        await _settle(tester);
        await tester.tap(find.text(S.retrieve).last);
        await _settle(tester);
        expect(find.text(S.reportSubmittedTakesEffectAfterSupport), findsOneWidget);
        expect(find.text(S.manualReportAwaitingConfirmation), findsOneWidget);
        expect(find.text(S.relist), findsNothing);
        await tester.pump(const Duration(seconds: 4));
      }, server);
    });

    testWidgets('書籍頁（賣家）：暫停販售顯示提示並可回報取回', (tester) async {
      await http.runWithClient(() async {
        await _pumpScreen(tester, BookDetailScreen(book: Book.fromJson(books[1])), size: const Size(390, 1600));
        expect(find.text(S.salesPausedPleaseRetrieveBookFrom), findsOneWidget);
        expect(find.text('已存放 9 天'), findsOneWidget);
        await tester.tap(find.text(S.retrieve));
        await _settle(tester);
        await tester.tap(find.text(S.retrieve).last);
        await _settle(tester);
        expect(sent, ['POST /api/books/2/retrieve']);
        expect(find.text(S.manualReportAwaitingConfirmation), findsOneWidget);
        expect(tester.widget<SmallActionButton>(find.widgetWithText(SmallActionButton, S.retrieve)).onTap, isNull);
        await tester.pump(const Duration(seconds: 4));
      }, server);
    });

    Widget editScreen(Map<String, dynamic> json) => EditBookDetailScreen(
      book: Book.fromJson(json),
      isbn: '',
      title: json['title'] as String,
      author: '',
      publisher: '',
      publishDate: '',
      categoryId: null,
    );

    MockClient cabinets(List<Map<String, dynamic>> list) =>
        MockClient((request) async => _json(request.url.path.endsWith('/cabinets') ? list : <Object>[]));

    testWidgets('編輯書籍：存書期間書櫃欄位鎖定並顯示原因，書櫃不在可選清單時仍保留原書櫃', (tester) async {
      await http.runWithClient(() async {
        await _pumpScreen(tester, editScreen(books[2]), size: const Size(390, 1400));
        expect(find.text(S.lockerCannotChangedWhileBookStored), findsOneWidget);
        final select = tester.widget<AppSelect<int>>(find.byType(AppSelect<int>));
        expect(select.onChanged, isNull);
        expect(select.value, 3);
        expect(find.text('台大書櫃'), findsOneWidget);
        final field = find.byType(AppSelect<int>);
        expect(find.descendant(of: field, matching: find.byIcon(Icons.lock_outline_rounded)), findsOneWidget);
        expect(find.descendant(of: field, matching: find.byIcon(Icons.keyboard_arrow_down_rounded)), findsNothing);

        await tester.tap(find.text('台大書櫃'));
        await _settle(tester);
        expect(find.byType(BottomSheet), findsNothing);
        expect(tester.widget<AppSelect<int>>(find.byType(AppSelect<int>)).value, 3);
        await tester.pump(const Duration(seconds: 4));
      }, () => cabinets([
        {'cabinet_id': 4, 'cabinet_name': '師大書櫃', 'address': '臺北市大安區和平東路一段162號', 'available_slots': 5},
      ]));
    });

    testWidgets('編輯書籍：未存書時可變更書櫃', (tester) async {
      await http.runWithClient(() async {
        await _pumpScreen(tester, editScreen(books[0]), size: const Size(390, 1400));
        expect(find.text(S.lockerCannotChangedWhileBookStored), findsNothing);
        expect(tester.widget<AppSelect<int>>(find.byType(AppSelect<int>)).onChanged, isNotNull);
        final field = find.byType(AppSelect<int>);
        expect(find.descendant(of: field, matching: find.byIcon(Icons.keyboard_arrow_down_rounded)), findsOneWidget);
        expect(find.descendant(of: field, matching: find.byIcon(Icons.lock_outline_rounded)), findsNothing);

        await tester.tap(find.text('台大書櫃'));
        await _settle(tester);
        await tester.tap(find.text('師大書櫃'));
        await _settle(tester);
        expect(tester.widget<AppSelect<int>>(find.byType(AppSelect<int>)).value, 4);
        await tester.pump(const Duration(seconds: 4));
      }, () => cabinets([
        {..._cabinet, 'available_slots': 5},
        {'cabinet_id': 4, 'cabinet_name': '師大書櫃', 'address': '臺北市大安區和平東路一段162號', 'available_slots': 5},
      ]));
    });

    testWidgets('書籍頁（賣家）：未存書的上架書籍可回報存書，送出後待客服確認', (tester) async {
      await http.runWithClient(() async {
        await _pumpScreen(tester, BookDetailScreen(book: Book.fromJson(books[0])), size: const Size(390, 1600));
        expect(find.text(S.notYetLocker), findsOneWidget);
        expect(find.text(S.bookLockerCanCollectedRightAfter), findsNothing);
        await tester.tap(find.text(S.dropOff));
        await _settle(tester);
        await tester.tap(find.text(S.dropOff).last);
        await _settle(tester);
        expect(sent, ['POST /api/books/1/deposit']);
        expect(find.text(S.manualReportAwaitingConfirmation), findsOneWidget);
        expect(tester.widget<SmallActionButton>(find.widgetWithText(SmallActionButton, S.dropOff)).onTap, isNull);
        await tester.pump(const Duration(seconds: 4));
      }, server);
    });

    for (final locale in const [_zhHant, Locale('ja')]) {
      for (final scale in const [1.0, 1.3]) {
        testWidgets('銷售紀錄販售中：寬 360、${locale.languageCode}、字級 $scale 時動作按鈕文字不截斷', (tester) async {
          await http.runWithClient(() async {
            await _pumpScreen(
              tester,
              const SalesHistoryScreen(initialTab: 'on_sale'),
              size: const Size(360, 1600),
              locale: locale,
              textScale: scale,
            );
            final buttons = find.descendant(
              of: find.byType(SaleCardFrame),
              matching: find.byWidgetPredicate((w) => w is FilledButton || w is OutlinedButton),
            );
            final labels = find.descendant(of: buttons, matching: find.byType(RichText));
            expect(labels, findsNWidgets(5));
            for (final element in labels.evaluate()) {
              final paragraph = element.renderObject! as RenderParagraph;
              expect(paragraph.didExceedMaxLines, isFalse, reason: paragraph.text.toPlainText());
            }
            await tester.pump(const Duration(seconds: 4));
          }, server);
        });
      }
    }

    SwipeAction delistSwipe(WidgetTester tester, int bookId) => tester
        .widget<SwipeActionTile>(
          find.byWidgetPredicate((w) => w is SwipeActionTile && w.itemKey == ValueKey('swipe_$bookId')),
        )
        .endToStart!;

    testWidgets('我的商品：存書中的上架書籍左滑取消上架須先確認，並說明須取回後才能重新上架', (tester) async {
      await http.runWithClient(() async {
        await _pumpScreen(tester, const BookManageScreen(), size: const Size(390, 1400));
        final swipe = delistSwipe(tester, 3);
        expect(swipe.label, S.delist);
        expect(swipe.label, '取消上架');
        await swipe.onTrigger();
        await _settle(tester);
        expect(find.text(S.onceDelistedP0NoLongerAppear2('異鄉人')), findsOneWidget);
        expect(find.textContaining('須先取回書籍，方可重新上架'), findsOneWidget);
        await tester.tap(find.text(S.actionCancel));
        await _settle(tester);
        expect(sent, isEmpty);

        await delistSwipe(tester, 1).onTrigger();
        await _settle(tester);
        expect(find.text(S.removedFromShopBuyersNoLonger('小王子')), findsNothing, reason: '未存書的書維持左滑直接取消上架並可復原');
        expect(sent, ['DELETE /api/books/1']);
        expect(find.text(S.undo), findsOneWidget);
        await tester.pump(const Duration(seconds: 4));
      }, server);
    });

    testWidgets('我的商品：以按鈕取消上架存書中的書時，確認視窗說明後果，確認後取消上架且不提供復原', (tester) async {
      await http.runWithClient(() async {
        await _pumpScreen(tester, const BookManageScreen(), size: const Size(390, 1400));
        final card = find.ancestor(of: find.text('異鄉人'), matching: find.byType(SwipeActionTile));
        await tester.tap(find.descendant(of: card, matching: find.text(S.delist)));
        await _settle(tester);
        final dialog = find.byType(AlertDialog);
        expect(find.descendant(of: dialog, matching: find.text('取消上架')), findsNWidgets(2), reason: '標題與確認按鈕皆為取消上架');
        expect(find.text(S.onceDelistedP0NoLongerAppear2('異鄉人')), findsOneWidget);
        await tester.tap(find.descendant(of: dialog, matching: find.byType(ElevatedButton)));
        await _settle(tester);
        expect(sent, ['DELETE /api/books/3']);
        expect(find.text('《異鄉人》已取消上架'), findsOneWidget);
        expect(find.text(S.undo), findsNothing);
        await tester.pump(const Duration(seconds: 4));
      }, server);
    });

    testWidgets('我的商品：自書籍頁回報存書後返回，列表重新載入', (tester) async {
      await http.runWithClient(() async {
        await _pumpScreen(tester, const BookManageScreen(), size: const Size(390, 1400));
        expect(find.text(S.dropOff), findsOneWidget);
        await tester.tap(find.text('小王子'));
        await _settle(tester);
        expect(find.byType(BookDetailScreen), findsOneWidget);

        await tester.tap(find.text(S.dropOff));
        await _settle(tester);
        await tester.tap(find.text(S.dropOff).last);
        await _settle(tester);
        expect(sent, ['POST /api/books/1/deposit']);

        Navigator.of(tester.element(find.byType(BookDetailScreen))).pop();
        await _settle(tester);
        expect(find.byType(BookDetailScreen), findsNothing);
        expect(find.text(S.manualReportAwaitingConfirmation), findsOneWidget, reason: '返回後重新載入，顯示待客服確認');
        await tester.pump(const Duration(seconds: 4));
      }, server);
    });

    Map<String, dynamic> held(int id, String title) => {
      ..._book(id, title),
      'reservation': {
        'reserved_until': DateTime.now().add(const Duration(hours: 20)).toUtc().toIso8601String(),
        'reserved_for_me': false,
      },
    };

    Map<String, dynamic> sellerOrder(int id, List<Map<String, dynamic>> items, {String status = 'pending_deposit'}) => {
      'order_id': id,
      'order_no': 'SMB$id',
      'buyer_id': 2,
      'seller_id': 1,
      'total_amount': 180 * items.length,
      'status': status,
      'cabinet_id': 3,
      'smart_cabinets': _cabinet,
      'order_items': [
        for (final (i, book) in items.indexed)
          {
            'item_id': i + 1,
            'book_id': book['book_id'],
            'quantity': 1,
            'unit_price': 180,
            'subtotal': 180,
            'books': book,
          },
      ],
      'transaction_disputes': <Object>[],
    };

    Finder filterChip(String label) => find.descendant(
      of: find.byType(AppHeader),
      matching: find.byWidgetPredicate(
        (w) => w is Text && (w.data == label || (w.data?.startsWith('$label ') ?? false)),
      ),
    );

    Future<void> selectFilter(WidgetTester tester, String label, {double delta = 80}) async {
      final bar = find.descendant(of: find.byType(AppHeader), matching: find.byType(ListView));
      await tester.scrollUntilVisible(
        filterChip(label),
        delta,
        scrollable: find.descendant(of: bar, matching: find.byType(Scrollable)),
      );
      await _settle(tester);
      await tester.tap(filterChip(label));
      await _settle(tester);
    }

    Finder manageCard(String title) => find.ancestor(of: find.text(title), matching: find.byType(SwipeActionTile));

    testWidgets('我的商品：已預訂且未存書的書可回報存書', (tester) async {
      books.add(held(5, '預約保留的書'));
      await http.runWithClient(() async {
        await _pumpScreen(tester, const BookManageScreen(), size: const Size(390, 1400));
        await selectFilter(tester, S.bookReserved);
        expect(find.text('預約保留的書'), findsOneWidget);
        expect(find.text('小王子'), findsNothing);

        final card = manageCard('預約保留的書');
        await tester.tap(find.descendant(of: card, matching: find.text(S.dropOff)));
        await _settle(tester);
        expect(find.text('請確認已將《預約保留的書》放入「台大書櫃」。'), findsOneWidget);
        await tester.tap(find.text(S.dropOff).last);
        await _settle(tester);

        expect(sent, ['POST /api/books/5/deposit']);
        expect(find.descendant(of: card, matching: find.text(S.manualReportAwaitingConfirmation)), findsOneWidget);
        await tester.pump(const Duration(seconds: 4));
      }, server);
    });

    testWidgets('銷售紀錄：預約保留中的上架書籍同樣可回報存書', (tester) async {
      books.add(held(5, '預約保留的書'));
      await http.runWithClient(() async {
        await _pumpScreen(tester, const SalesHistoryScreen(initialTab: 'on_sale'), size: const Size(390, 1600));
        final card = find.ancestor(of: find.text('預約保留的書'), matching: find.byType(SaleCardFrame));
        expect(find.descendant(of: card, matching: find.text(S.delist)), findsNothing);
        await tester.tap(find.descendant(of: card, matching: find.text(S.dropOff)));
        await _settle(tester);
        await tester.tap(find.text(S.dropOff).last);
        await _settle(tester);
        expect(sent, ['POST /api/books/5/deposit']);
        expect(find.descendant(of: card, matching: find.text(S.manualReportAwaitingConfirmation)), findsOneWidget);
        await tester.pump(const Duration(seconds: 4));
      }, server);
    });

    testWidgets('我的商品：已售出且訂單待存書的書可完成存書，確認整筆訂單後重新載入書籍與訂單', (tester) async {
      books.addAll([_book(6, '同訂單的書', status: 'reserved'), _book(7, '已存書訂單的書', status: 'reserved')]);
      orders.addAll([
        sellerOrder(9, [books[3], books[4]]),
        sellerOrder(10, [books[5]], status: 'deposited'),
      ]);
      await http.runWithClient(() async {
        await _pumpScreen(tester, const BookManageScreen(), size: const Size(390, 1400));
        expect(loads, containsAll(['books', 'orders:pending_deposit']));
        await selectFilter(tester, S.bookSold);
        expect(find.text('已售出的書'), findsOneWidget);
        expect(find.text('已存書訂單的書'), findsOneWidget);
        expect(find.text(S.markAsDroppedOff), findsNWidgets(2));
        expect(find.descendant(of: manageCard('已存書訂單的書'), matching: find.text(S.markAsDroppedOff)), findsNothing);
        expect(find.text(S.dropOff), findsNothing);

        loads.clear();
        await tester.tap(find.descendant(of: manageCard('已售出的書'), matching: find.text(S.markAsDroppedOff)));
        await _settle(tester);
        final dialog = find.byType(AlertDialog);
        expect(find.descendant(of: dialog, matching: find.text(S.confirmPutAllP0BooksOrder(2))), findsOneWidget);
        expect(find.descendant(of: dialog, matching: find.text('已售出的書')), findsOneWidget);
        expect(find.descendant(of: dialog, matching: find.text('同訂單的書')), findsOneWidget);
        expect(find.descendant(of: dialog, matching: find.byIcon(Icons.inventory_2_outlined)), findsOneWidget);
        final haptics = <Object?>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') haptics.add(call.arguments);
          return null;
        });
        addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
        await tester.tap(find.text(S.droppedOff));
        await _settle(tester);

        expect(sent, ['PATCH /api/orders/9/status']);
        expect(haptics, contains('HapticFeedbackType.lightImpact'));
        expect(orders.first['status'], 'deposited');
        expect(loads, containsAll(['books', 'orders:pending_deposit']));
        expect(find.text(S.markedAsDroppedOff), findsOneWidget);
        expect(find.text(S.markAsDroppedOff), findsNothing);
        await tester.pump(const Duration(seconds: 4));
      }, server);
    });

    for (final locale in const [_zhHant, Locale('ja')]) {
      for (final scale in const [1.0, 1.3]) {
        testWidgets('我的商品：寬 360、${locale.languageCode}、字級 $scale 時書櫃列的按鈕依文字寬度排版且不截斷', (tester) async {
          orders.add(sellerOrder(9, [books[3]]));
          await http.runWithClient(() async {
            await _pumpScreen(tester, const BookManageScreen(), size: const Size(360, 1800), locale: locale, textScale: scale);
            final lineButtons = find.descendant(
              of: find.descendant(of: find.byType(SwipeActionTile), matching: find.byType(IntrinsicWidth)),
              matching: find.byType(SmallActionButton),
            );
            expect(
              tester.widgetList<SmallActionButton>(lineButtons).map((b) => b.label),
              unorderedEquals([S.dropOff, S.retrieve, S.markAsDroppedOff]),
            );
            for (final label in [S.dropOff, S.retrieve, S.markAsDroppedOff]) {
              final text = find.descendant(of: lineButtons, matching: find.text(label));
              final paragraph = tester.renderObject<RenderParagraph>(find.descendant(of: text, matching: find.byType(RichText)));
              expect(paragraph.didExceedMaxLines, isFalse, reason: label);
              final width = tester.getSize(find.ancestor(of: text, matching: find.byType(SmallActionButton))).width;
              expect(width, closeTo(paragraph.size.width + 24, 0.5), reason: label);
              expect(width, lessThan(140), reason: label);
            }
            await tester.pump(const Duration(seconds: 4));
          }, server);
        });
      }
    }

    testWidgets('銷售紀錄待存書：單本訂單沿用原確認文字，多本訂單列出全部書名，書名清單靠左而確認文字維持置中', (tester) async {
      orders.addAll([
        sellerOrder(9, [books[3]]),
        sellerOrder(10, [_book(6, '甲書', status: 'reserved'), _book(7, '乙書', status: 'reserved')]),
      ]);
      await http.runWithClient(() async {
        await _pumpScreen(tester, const SalesHistoryScreen(), size: const Size(390, 1600));
        await tester.tap(find.text(S.markAsDroppedOff).first);
        await _settle(tester);
        final dialog = find.byType(AlertDialog);
        final single = find.descendant(of: dialog, matching: find.text(S.confirmPutLocker('已售出的書')));
        expect(single, findsOneWidget);
        expect(tester.widget<Text>(single).textAlign, TextAlign.center);
        expect(find.descendant(of: dialog, matching: find.text('・')), findsNothing);
        await tester.tap(find.text(S.actionCancel));
        await _settle(tester);
        expect(sent, isEmpty);

        await tester.tap(find.text(S.markAsDroppedOff).last);
        await _settle(tester);
        final message = find.descendant(of: dialog, matching: find.text(S.confirmPutAllP0BooksOrder(2)));
        expect(message, findsOneWidget);
        expect(find.descendant(of: dialog, matching: find.textContaining('\n')), findsNothing);
        final content = tester.getRect(find.ancestor(of: message, matching: find.byType(Column)).first);
        expect(tester.widget<Text>(message).textAlign, TextAlign.center);
        expect(tester.getCenter(message).dx, closeTo(content.center.dx, 0.5));

        final bullets = find.descendant(of: dialog, matching: find.text('・'));
        expect(bullets, findsNWidgets(2));
        final titles = [
          for (final title in ['甲書', '乙書']) find.descendant(of: dialog, matching: find.text(title)),
        ];
        for (var i = 0; i < 2; i++) {
          expect(tester.getTopLeft(bullets.at(i)).dx, closeTo(content.left, 0.5));
          expect(tester.getTopLeft(titles[i]).dx, closeTo(tester.getTopRight(bullets.at(i)).dx, 0.5));
          expect(tester.widget<Text>(titles[i]).textAlign, isNot(TextAlign.center));
        }
        expect(tester.getTopLeft(titles[1]).dy, greaterThan(tester.getTopLeft(titles[0]).dy));
        expect(tester.getTopLeft(titles[0]).dy, greaterThan(tester.getBottomLeft(message).dy));
        await tester.tap(find.text(S.droppedOff));
        await _settle(tester);
        expect(sent, ['PATCH /api/orders/10/status']);
        expect(find.text('甲書'), findsNothing);
        await tester.pump(const Duration(seconds: 4));
      }, server);
    });

    testWidgets('我的商品：待取回分頁列出存書逾期暫停販售的書並可回報取回，全部分頁仍保留', (tester) async {
      books.addAll([
        _book(8, '自行下架的書', status: 'removed', deposit: _deposit(8, paused: true)),
        _book(9, '一般下架的書', status: 'removed'),
      ]);
      await http.runWithClient(() async {
        await _pumpScreen(tester, const BookManageScreen(), size: const Size(390, 1400));
        await selectFilter(tester, S.awaitingRetrieval);
        expect(filterChip('${S.awaitingRetrieval} 2'), findsOneWidget);
        expect(find.text('夜間飛行'), findsOneWidget);
        expect(find.text('自行下架的書'), findsOneWidget);
        expect(find.text('異鄉人'), findsNothing, reason: '存書未滿期限的書不列入');
        expect(find.text('一般下架的書'), findsNothing);
        expect(find.text('小王子'), findsNothing);
        expect(find.text(S.salesPaused), findsNWidgets(2));
        expect(find.text(S.retrieve), findsNWidgets(2));

        await tester.tap(find.descendant(of: manageCard('夜間飛行'), matching: find.text(S.retrieve)));
        await _settle(tester);
        await tester.tap(find.text(S.retrieve).last);
        await _settle(tester);
        expect(sent, ['POST /api/books/2/retrieve']);
        expect(find.descendant(of: manageCard('夜間飛行'), matching: find.text(S.manualReportAwaitingConfirmation)), findsOneWidget);
        expect(filterChip('${S.awaitingRetrieval} 2'), findsOneWidget, reason: '待客服確認前仍列於待取回');

        await selectFilter(tester, S.actionAll, delta: -80);
        expect(find.text('自行下架的書'), findsOneWidget);
        expect(find.text('夜間飛行'), findsOneWidget);
        await tester.pump(const Duration(seconds: 4));
      }, server);
    });

    testWidgets('銷售紀錄：存書中以回報取回、可登記存書時以登記存書為主要動作，取消上架為次要動作並上下排列，確認視窗說明後果', (tester) async {
      books.add({..._book(5, '未指定書櫃的書'), 'cabinet_id': null});
      await http.runWithClient(() async {
        await _pumpScreen(tester, const SalesHistoryScreen(initialTab: 'on_sale'), size: const Size(390, 1800));
        Finder card(String title) => find.ancestor(of: find.text(title), matching: find.byType(SaleCardFrame));
        Finder filled(String title) => find.descendant(of: card(title), matching: find.byType(FilledButton));
        Finder outlined(String title) => find.descendant(of: card(title), matching: find.byType(OutlinedButton));

        final primary = filled('異鄉人');
        final secondary = outlined('異鄉人');
        expect(find.descendant(of: primary, matching: find.text(S.retrieve)), findsOneWidget);
        expect(find.descendant(of: secondary, matching: find.text(S.delist)), findsOneWidget);
        expect(tester.getSize(primary).width, tester.getSize(secondary).width);
        expect(tester.getTopLeft(secondary).dy, greaterThan(tester.getBottomLeft(primary).dy));

        expect(find.descendant(of: filled('小王子'), matching: find.text(S.dropOff)), findsOneWidget);
        expect(find.descendant(of: outlined('小王子'), matching: find.text(S.delist)), findsOneWidget);
        expect(find.descendant(of: outlined('小王子'), matching: find.text('取消上架')), findsOneWidget);
        expect(tester.getTopLeft(outlined('小王子')).dy, greaterThan(tester.getBottomLeft(filled('小王子')).dy));

        expect(find.descendant(of: filled('未指定書櫃的書'), matching: find.text(S.delist)), findsOneWidget);
        expect(outlined('未指定書櫃的書'), findsNothing);

        await tester.tap(find.descendant(of: secondary, matching: find.text(S.delist)));
        await _settle(tester);
        final dialog = find.byType(AlertDialog);
        expect(find.descendant(of: dialog, matching: find.text('取消上架')), findsNWidgets(2), reason: '標題與確認按鈕皆為取消上架');
        expect(find.text(S.onceDelistedP0NoLongerAppear2('異鄉人')), findsOneWidget);
        await tester.tap(find.descendant(of: dialog, matching: find.byType(ElevatedButton)));
        await _settle(tester);
        expect(sent, ['DELETE /api/books/3']);
        expect(find.text('《異鄉人》已取消上架'), findsOneWidget);
        await tester.pump(const Duration(seconds: 4));
      }, server);
    });

    testWidgets('銷售紀錄：暫停販售以警示色標示，並另列已存放天數', (tester) async {
      await http.runWithClient(() async {
        await _pumpScreen(tester, const SalesHistoryScreen(initialTab: 'on_sale'), size: const Size(390, 1400));
        final context = tester.element(find.byType(SalesHistoryScreen));
        final paused = tester.widget<Text>(find.text(S.salesPaused));
        expect(paused.style?.color, AppColors.of(context).warning);
        final card = find.ancestor(of: find.text('夜間飛行'), matching: find.byType(SaleCardFrame));
        expect(find.descendant(of: card, matching: find.text('已存放 9 天')), findsOneWidget);
        expect(find.descendant(of: card, matching: find.byIcon(Icons.inventory_2_outlined)), findsOneWidget);

        final onSale = find.ancestor(of: find.text('異鄉人'), matching: find.byType(SaleCardFrame));
        expect(find.descendant(of: onSale, matching: find.text(S.bookOnSale)), findsOneWidget);
        expect(find.descendant(of: onSale, matching: find.text('已存放 3 天')), findsOneWidget);
        await tester.pump(const Duration(seconds: 4));
      }, server);
    });

    Map<String, dynamic> publicJson(Map<String, dynamic> json) => Map.of(json)..remove('deposit');

    testWidgets('書籍頁（賣家）：自公開列表進入且詳情載入失敗時，不顯示登記存書', (tester) async {
      final requests = <String>[];
      await http.runWithClient(() async {
        await _pumpScreen(
          tester,
          BookDetailScreen(book: Book.fromJson(publicJson(_book(3, '異鄉人', inCabinet: true)))),
          size: const Size(390, 1600),
        );
        expect(requests, contains('GET /api/books/3'));
        expect(find.text(S.notYetLocker), findsNothing);
        expect(find.text(S.dropOff), findsNothing);
        await tester.pump(const Duration(seconds: 4));
      }, () => MockClient((request) async {
        requests.add('${request.method} ${request.url.path}');
        if (request.url.path.endsWith('/books/3')) return _json(null, status: 500, extra: {'message': '伺服器錯誤'});
        return _json(<Object>[]);
      }));
    });

    testWidgets('書籍頁（賣家）：存書資訊未知時，進入編輯前先重新載入詳情', (tester) async {
      var detailCalls = 0;
      await http.runWithClient(() async {
        await _pumpScreen(
          tester,
          BookDetailScreen(book: Book.fromJson(publicJson(_book(1, '小王子')))),
          size: const Size(390, 1600),
        );
        expect(detailCalls, 1);
        expect(find.text(S.dropOff), findsNothing);
        await tester.tap(find.text(S.editBook));
        await _settle(tester);
        expect(detailCalls, 2);
        final edit = tester.widget<EditBookScreen>(find.byType(EditBookScreen));
        expect(edit.book.depositKnown, isTrue);
        expect(edit.book.isDeposited, isTrue);
        await tester.pump(const Duration(seconds: 4));
      }, () => MockClient((request) async {
        if (request.url.path.endsWith('/books/1')) {
          detailCalls++;
          if (detailCalls == 1) return _json(null, status: 500, extra: {'message': '伺服器錯誤'});
          return _json(_book(1, '小王子', deposit: _deposit(2), inCabinet: true));
        }
        return _json(<Object>[]);
      }));
    });

    testWidgets('編輯書籍：公開列表標示在書櫃中的書，書櫃欄位同樣鎖定', (tester) async {
      await http.runWithClient(() async {
        await _pumpScreen(tester, editScreen(publicJson(_book(3, '異鄉人', inCabinet: true))), size: const Size(390, 1400));
        expect(find.text(S.lockerCannotChangedWhileBookStored), findsOneWidget);
        expect(tester.widget<AppSelect<int>>(find.byType(AppSelect<int>)).onChanged, isNull);
        await tester.pump(const Duration(seconds: 4));
      }, () => cabinets([
        {..._cabinet, 'available_slots': 5},
      ]));
    });

    Widget orderDetail(Map<String, dynamic> json, {required bool asSeller}) =>
        OrderDetailScreen(order: Order.fromJson(json), asSeller: asSeller);

    Map<String, dynamic> partialOrder() => {
      'order_id': 9,
      'order_no': 'SMB9',
      'buyer_id': 2,
      'seller_id': 1,
      'total_amount': 540,
      'status': 'pending_deposit',
      'cabinet_id': 3,
      'smart_cabinets': _cabinet,
      'order_items': [
        {'item_id': 1, 'book_id': 5, 'quantity': 1, 'unit_price': 180, 'subtotal': 180, 'pre_deposited': true, 'books': _book(5, '小王子')},
        {'item_id': 2, 'book_id': 6, 'quantity': 1, 'unit_price': 180, 'subtotal': 180, 'pre_deposited': true, 'books': _book(6, '夜間飛行', cabinetId: 4)},
        {'item_id': 3, 'book_id': 7, 'quantity': 1, 'unit_price': 180, 'subtotal': 180, 'pre_deposited': false, 'books': _book(7, '異鄉人')},
      ],
      'transaction_disputes': <Object>[],
    };

    testWidgets('訂單詳情（賣家）：待存書訂單標示已在書櫃與存放於其他書櫃的書', (tester) async {
      final json = partialOrder();
      await http.runWithClient(() async {
        await _pumpScreen(tester, orderDetail(json, asSeller: true), size: const Size(390, 1600));
        Finder row(String title) => find.ancestor(of: find.text(title), matching: find.byType(Row)).first;
        expect(find.descendant(of: row('小王子'), matching: find.text(S.inLocker)), findsOneWidget);
        expect(find.descendant(of: row('夜間飛行'), matching: find.text(S.inAnotherLocker)), findsOneWidget);
        expect(find.descendant(of: row('異鄉人'), matching: find.text(S.inLocker)), findsNothing);
        expect(find.text(S.inLocker), findsOneWidget);
        expect(find.text(S.inAnotherLocker), findsOneWidget);
        await tester.pump(const Duration(seconds: 4));
      }, () => MockClient((request) async => _json(request.url.path.endsWith('/orders/9') ? json : <Object>[])));
    });

    testWidgets('訂單詳情：買家與已存書的訂單不顯示存放標示', (tester) async {
      final json = partialOrder();
      await http.runWithClient(() async {
        await _pumpScreen(tester, orderDetail(json, asSeller: false), size: const Size(390, 1600));
        expect(find.text(S.inLocker), findsNothing);
        expect(find.text(S.inAnotherLocker), findsNothing);
        await tester.pump(const Duration(seconds: 4));
      }, () => MockClient((request) async => _json(request.url.path.endsWith('/orders/9') ? json : <Object>[])));

      final deposited = {...partialOrder(), 'status': 'deposited'};
      await tester.pumpWidget(const SizedBox.shrink());
      await http.runWithClient(() async {
        await _pumpScreen(tester, orderDetail(deposited, asSeller: true), size: const Size(390, 1600));
        expect(find.text(S.inLocker), findsNothing);
        expect(find.text(S.inAnotherLocker), findsNothing);
        await tester.pump(const Duration(seconds: 4));
      }, () => MockClient((request) async => _json(request.url.path.endsWith('/orders/9') ? deposited : <Object>[])));
    });
  });

  group('買家', () {
    Map<String, dynamic> buyerBook({bool inCabinet = true}) => _book(5, '小王子', sellerId: 2, inCabinet: inCabinet);

    MockClient client(Map<String, dynamic> book, List<String> requests) => MockClient((request) async {
      requests.add('${request.method} ${request.url.path}');
      if (request.url.path.endsWith('/wallet')) return _json({'balance': 500});
      if (request.url.path.endsWith('/orders/buy-now')) {
        return _json({'order_id': 1, 'status': book['in_cabinet'] == true ? 'deposited' : 'pending_deposit'}, status: 201);
      }
      return _json(request.url.path.endsWith('/books/5') ? book : <Object>[]);
    });

    testWidgets('書籍頁：書已在書櫃時取書資訊顯示一行說明', (tester) async {
      await http.runWithClient(() async {
        await _pumpScreen(tester, BookDetailScreen(book: Book.fromJson(buyerBook())), size: const Size(390, 1600));
        expect(find.text(S.bookLockerCanCollectedRightAfter), findsOneWidget);
        expect(find.text(S.dropOff), findsNothing);
        await tester.pump(const Duration(seconds: 4));
      }, () => client(buyerBook(), []));
    });

    testWidgets('書籍頁：一般書籍不顯示書櫃說明，直接購買不另外確認', (tester) async {
      final requests = <String>[];
      final json = buyerBook(inCabinet: false);
      await http.runWithClient(() async {
        await _pumpScreen(tester, BookDetailScreen(book: Book.fromJson(json)));
        expect(find.text(S.bookLockerCanCollectedRightAfter), findsNothing);
        await tester.tap(find.text(S.buyNow2));
        await _settle(tester);
        expect(find.text(S.bookAlreadyLockerOrderReadyPickup), findsNothing);
        expect(requests, contains('POST /api/orders/buy-now'));
        expect(find.text(S.orderPlacedSellerDropBookOff), findsOneWidget);
        expect(find.text(S.orderPlacedBookLockerReadyPickup), findsNothing);
        await tester.tap(find.text(S.keepBrowsing));
        await _settle(tester);
        await tester.pump(const Duration(seconds: 4));
      }, () => client(json, requests));
    });

    testWidgets('直接購買：書已在書櫃時先確認即可取書且無法取消', (tester) async {
      final requests = <String>[];
      final json = buyerBook();
      await http.runWithClient(() async {
        await _pumpScreen(tester, BookDetailScreen(book: Book.fromJson(json)));
        await tester.tap(find.text(S.buyNow2));
        await _settle(tester);
        expect(find.text(S.confirmPurchase), findsOneWidget);
        expect(find.text('此書已存放於書櫃，訂單成立後即可取書，且無法取消訂單。'), findsOneWidget);
        await tester.tap(find.text(S.actionBack));
        await _settle(tester);
        expect(requests, isNot(contains('POST /api/orders/buy-now')));

        await tester.tap(find.text(S.buyNow2));
        await _settle(tester);
        await tester.tap(find.text(S.payNow));
        await _settle(tester);
        expect(requests, contains('POST /api/orders/buy-now'));
        expect(find.text(S.paymentSuccessful), findsOneWidget);
        expect(find.text(S.orderPlacedBookLockerReadyPickup), findsOneWidget);
        expect(find.text(S.orderPlacedSellerDropBookOff), findsNothing);
        await tester.tap(find.text(S.keepBrowsing));
        await _settle(tester);
        await tester.pump(const Duration(seconds: 4));
      }, () => client(json, requests));
    });

    Future<List<String>> checkout(
      WidgetTester tester,
      List<Map<String, dynamic>> cart, {
      bool expectDialog = true,
      bool backFirst = false,
      bool pay = false,
      List<String> statuses = const ['pending_deposit'],
      String? expectSuccess,
    }) async {
      final requests = <String>[];
      await http.runWithClient(() async {
        await _pumpScreen(tester, const CartScreen());
        await tester.tap(find.text(S.checkOut));
        await _settle(tester);
        if (expectDialog && backFirst) {
          await tester.tap(find.text(S.actionBack));
          await _settle(tester);
          expect(requests, isNot(contains('POST /api/orders/checkout')));
          await tester.tap(find.text(S.checkOut));
          await _settle(tester);
        }
        if (expectDialog) {
          expect(find.text('已存放於書櫃的書籍，訂單成立後即可取書，且無法取消訂單。'), findsOneWidget);
          await tester.tap(find.text(pay ? S.payNow : S.actionBack));
          await _settle(tester);
        } else {
          expect(find.text(S.ordersBooksAlreadyLockerReadyPickup), findsNothing);
        }
        if (expectSuccess != null) {
          expect(find.text(S.paymentSuccessful), findsOneWidget);
          expect(find.text(expectSuccess), findsOneWidget);
          await tester.tap(find.text(S.keepBrowsing));
          await _settle(tester);
        }
        await tester.pump(const Duration(seconds: 4));
      }, () => MockClient((request) async {
        requests.add('${request.method} ${request.url.path}');
        if (request.url.path.endsWith('/users/me/stats')) return _json({'balance': 5000, 'cart_count': cart.length});
        if (request.url.path.endsWith('/cart')) return _json(cart);
        if (request.url.path.endsWith('/orders/checkout')) {
          return _json([
            for (var i = 0; i < statuses.length; i++) {'order_id': i + 1, 'status': statuses[i]},
          ], status: 201);
        }
        return _json(<Object>[]);
      }));
      return requests;
    }

    testWidgets('購物車：同一賣家的書都已在同一書櫃時，結帳前確認且可返回', (tester) async {
      final requests = await checkout(tester, [
        {'cart_id': 1, 'quantity': 1, 'books': _book(5, '小王子', sellerId: 2, inCabinet: true)},
        {'cart_id': 2, 'quantity': 1, 'books': _book(6, '夜間飛行', sellerId: 2, inCabinet: true)},
      ]);
      expect(requests, isNot(contains('POST /api/orders/checkout')));
    });

    testWidgets('購物車：同一筆訂單有書不在書櫃時不會直接成立，不需確認', (tester) async {
      final requests = await checkout(tester, [
        {'cart_id': 1, 'quantity': 1, 'books': _book(5, '小王子', sellerId: 2, inCabinet: true)},
        {'cart_id': 2, 'quantity': 1, 'books': _book(6, '夜間飛行', sellerId: 2)},
      ], expectDialog: false, expectSuccess: S.orderPlacedSellerDropBookOff);
      expect(requests, contains('POST /api/orders/checkout'));
    });

    testWidgets('購物車：返回後可再次結帳，確認後立即付款即送出結帳，成功訊息說明可立即取書', (tester) async {
      final requests = await checkout(
        tester,
        [
          {'cart_id': 1, 'quantity': 1, 'books': _book(5, '小王子', sellerId: 2, inCabinet: true)},
          {'cart_id': 2, 'quantity': 1, 'books': _book(6, '夜間飛行', sellerId: 2, inCabinet: true)},
        ],
        backFirst: true,
        pay: true,
        statuses: ['deposited'],
        expectSuccess: S.orderPlacedBookLockerReadyPickup,
      );
      expect(requests.where((r) => r == 'POST /api/orders/checkout'), hasLength(1));
    });

    testWidgets('購物車：多位賣家時只要其中一筆訂單可直接取書就先確認', (tester) async {
      final requests = await checkout(
        tester,
        [
          {'cart_id': 1, 'quantity': 1, 'books': _book(5, '小王子', sellerId: 2, inCabinet: true)},
          {'cart_id': 2, 'quantity': 1, 'books': _book(6, '夜間飛行', sellerId: 3)},
        ],
        pay: true,
        statuses: ['deposited', 'pending_deposit'],
        expectSuccess: S.p0BooksSplitIntoP1Orders(2, 2),
      );
      expect(requests, contains('POST /api/orders/checkout'));
    });

    testWidgets('購物車：同一賣家的書分放不同書櫃時不會直接成立，不需確認', (tester) async {
      final requests = await checkout(
        tester,
        [
          {'cart_id': 1, 'quantity': 1, 'books': _book(5, '小王子', sellerId: 2, inCabinet: true)},
          {'cart_id': 2, 'quantity': 1, 'books': _book(6, '夜間飛行', sellerId: 2, inCabinet: true, cabinetId: 4)},
        ],
        expectDialog: false,
        expectSuccess: S.orderPlacedSellerDropBookOff,
      );
      expect(requests, contains('POST /api/orders/checkout'));
    });

    testWidgets('訂單直接成立為已存書時可立即取書，不提供取消', (tester) async {
      await http.runWithClient(() async {
        await _pumpScreen(tester, const PurchaseHistoryScreen());
        expect(find.text('小王子'), findsOneWidget);
        expect(find.text(S.iCollected), findsOneWidget);
        expect(find.text(S.cancelOrder), findsNothing);
        await tester.pump(const Duration(seconds: 4));
      }, () => MockClient((request) async {
        if (request.url.path.endsWith('/orders') && request.url.queryParameters['tab'] == 'pending_pickup') {
          return _json([
            {
              'order_id': 9,
              'order_no': 'SMB9',
              'buyer_id': 1,
              'seller_id': 2,
              'total_amount': 180,
              'status': 'deposited',
              'deposited_at': DateTime.now().toUtc().toIso8601String(),
              'picked_up_at': null,
              'smart_cabinets': _cabinet,
              'order_items': [
                {'item_id': 1, 'book_id': 5, 'quantity': 1, 'unit_price': 180, 'subtotal': 180, 'pre_deposited': true, 'books': _book(5, '小王子', sellerId: 2)},
              ],
              'transaction_disputes': <Object>[],
            },
          ]);
        }
        return _json(<Object>[]);
      }));
    });
  });

  group('後台', () {
    setUp(() => _setUser(id: 9, role: 'admin'));

    final adminCabinets = [
      {..._cabinet, 'latitude': 25.0173, 'longitude': 121.5398, 'total_slots': 20, 'available_slots': 5, 'is_active': true},
      {'cabinet_id': 4, 'cabinet_name': '師大書櫃', 'address': '臺北市大安區和平東路一段162號', 'latitude': 25.026, 'longitude': 121.527, 'total_slots': 20, 'available_slots': 5, 'is_active': true},
    ];

    List<Map<String, dynamic>> rows() => [
      {
        'book_id': 7,
        'title': '小王子',
        'book_status': 'removed',
        'seller': {'user_id': 2, 'nickname': '小明', 'deleted': false},
        'cabinet': _cabinet,
        'deposited_at': '2026-09-01T08:00:00.000Z',
        'days_stored': 15,
        'paused': true,
        'escalated': true,
        'overdue': true,
      },
      {
        'book_id': 8,
        'title': '夜間飛行',
        'book_status': 'on_sale',
        'seller': {'user_id': 3, 'nickname': '已刪除的使用者', 'deleted': true},
        'cabinet': _cabinet,
        'deposited_at': '2026-09-20T08:00:00.000Z',
        'days_stored': 2,
        'paused': false,
        'escalated': false,
        'overdue': false,
      },
    ];

    testWidgets('存書列表顯示書名、賣家、書櫃、天數與標記，可篩選逾期並登記取出', (tester) async {
      final requests = <String>[];
      var cleared = false;
      await http.runWithClient(() async {
        await _pumpScreen(tester, const AdminCabinetDepositScreen(), size: const Size(390, 1000));
        expect(find.text('小王子'), findsOneWidget);
        expect(find.text(S.seller3('小明')), findsOneWidget);
        expect(find.text(S.seller3(S.deletedUser)), findsOneWidget);
        expect(find.text('台大書櫃'), findsNWidgets(2));
        expect(find.text('已存放 15 天'), findsOneWidget);
        expect(find.text(S.salesPaused), findsOneWidget);
        expect(find.text(S.adminsNotified), findsOneWidget);

        await tester.tap(find.text(S.recordRemoval).last);
        await _settle(tester);
        expect(find.text('請確認人員已自「台大書櫃」取出《夜間飛行》。登記後書籍將下架。'), findsOneWidget, reason: '上架中的書登記取出後會下架');
        await tester.tap(find.text(S.actionCancel));
        await _settle(tester);

        await tester.tap(find.text(S.overdue));
        await _settle(tester);
        expect(requests.last, 'GET /api/admin/cabinets/deposits?overdue=true&page=1&limit=20');
        expect(find.text('夜間飛行'), findsNothing);

        await tester.tap(find.text(S.recordRemoval));
        await _settle(tester);
        expect(find.text('請確認人員已自「台大書櫃」取出《小王子》。'), findsOneWidget, reason: '暫停販售的書已下架，不再提示將下架');
        await tester.tap(find.text(S.recordRemoval).last);
        await _settle(tester);
        expect(requests, contains('POST /api/admin/cabinets/deposits/7/clear'));
        expect(requests.last, 'POST /api/admin/cabinets/deposits/7/clear', reason: '登記取出成功後不重新載入整個列表');
        expect(requests.where((r) => r.startsWith('POST')), hasLength(1), reason: '後台登記取出不需身分驗證');
        expect(find.text(S.removalRecorded), findsOneWidget);
        expect(find.text(S.noOverdueBooks), findsOneWidget);
        await tester.pump(const Duration(seconds: 4));
      }, () => MockClient((request) async {
        if (request.url.path.endsWith('/admin/cabinets')) return _json(adminCabinets);
        requests.add('${request.method} ${request.url.path}${request.url.hasQuery ? '?${request.url.query}' : ''}');
        if (request.method == 'POST') {
          cleared = true;
          return _json({'book_id': 7, 'book_status': 'removed'});
        }
        final overdue = request.url.queryParameters['overdue'] == 'true';
        final list = rows().where((r) => !overdue || r['overdue'] == true).where((r) => !cleared || r['book_id'] != 7);
        return _json(list.toList());
      }));
    });

    testWidgets('登記取出失敗時顯示伺服器訊息', (tester) async {
      await http.runWithClient(() async {
        await _pumpScreen(tester, const AdminCabinetDepositScreen(initialOverdue: true), size: const Size(390, 1000));
        await tester.tap(find.text(S.recordRemoval));
        await _settle(tester);
        await tester.tap(find.text(S.recordRemoval).last);
        await _settle(tester);
        expect(find.text('存書紀錄已變更，請重新整理後再試'), findsOneWidget);
        await tester.pump(const Duration(seconds: 4));
      }, () => MockClient((request) async {
        if (request.url.path.endsWith('/admin/cabinets')) return _json(adminCabinets);
        if (request.method == 'POST') {
          return _json(null, status: 409, extra: {'message': '存書紀錄已變更，請重新整理後再試'});
        }
        return _json(rows().take(1).toList());
      }));
    });

    testWidgets('已載入多頁時登記取出只移除該筆，後續分頁依移除筆數回推且不漏掉遞補的書', (tester) async {
      final requests = <String>[];
      final stored = [
        for (var i = 1; i <= 45; i++)
          {...rows().last, 'book_id': 100 + i, 'title': '書$i', 'days_stored': 2},
      ];
      Finder list() => find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).last;

      await http.runWithClient(() async {
        await _pumpScreen(tester, const AdminCabinetDepositScreen(), size: const Size(390, 1000));
        await tester.scrollUntilVisible(find.text('書25'), 400, scrollable: list());
        await _settle(tester);
        expect(requests.where((r) => r.startsWith('GET')), hasLength(2));

        final card = find.ancestor(of: find.text('書25'), matching: find.byType(AppCard));
        await tester.tap(find.descendant(of: card, matching: find.text(S.recordRemoval)));
        await _settle(tester);
        await tester.tap(find.text(S.recordRemoval).last);
        await _settle(tester);
        expect(requests.last, 'POST /api/admin/cabinets/deposits/125/clear');
        expect(find.text('書25'), findsNothing);
        expect(find.text('書24', skipOffstage: false), findsOneWidget, reason: '不重新載入第一頁，已載入的書維持在列表中');
        expect(find.text('書26', skipOffstage: false), findsOneWidget);

        await tester.scrollUntilVisible(find.text('書45'), 400, scrollable: list());
        await _settle(tester);
        expect(requests.where((r) => r.startsWith('GET')).skip(2).toList(), [
          'GET /api/admin/cabinets/deposits?page=2&limit=20',
          'GET /api/admin/cabinets/deposits?page=3&limit=20',
        ]);
        await tester.scrollUntilVisible(find.text('書41'), -300, scrollable: list());
        expect(find.text('書41'), findsOneWidget, reason: '移除後往前遞補的書仍會載入');
        await tester.pump(const Duration(seconds: 4));
      }, () => MockClient((request) async {
        if (request.url.path.endsWith('/admin/cabinets')) return _json(adminCabinets);
        requests.add('${request.method} ${request.url.path}${request.url.hasQuery ? '?${request.url.query}' : ''}');
        if (request.method == 'POST') {
          final id = int.parse(request.url.pathSegments[request.url.pathSegments.length - 2]);
          stored.removeWhere((r) => r['book_id'] == id);
          return _json({'book_id': id, 'book_status': 'removed'});
        }
        final page = int.parse(request.url.queryParameters['page'] ?? '1');
        final slice = stored.skip((page - 1) * 20).take(20).toList();
        final pages = (stored.length / 20).ceil();
        return _json(slice, extra: {'pagination': {'total': stored.length, 'page': page, 'limit': 20, 'total_pages': pages}});
      }));
    });

    testWidgets('依書櫃篩選、自行下架的書顯示書籍狀態，列表底部自動載入下一頁', (tester) async {
      final requests = <String>[];
      await http.runWithClient(() async {
        await _pumpScreen(tester, const AdminCabinetDepositScreen(), size: const Size(390, 1000));
        expect(requests, [
          'GET /api/admin/cabinets/deposits?page=1&limit=20',
          'GET /api/admin/cabinets/deposits?page=2&limit=20',
        ]);
        expect(find.text('小王子'), findsOneWidget);
        expect(find.text('夜間飛行'), findsOneWidget);
        expect(find.text('異鄉人'), findsOneWidget, reason: '第二頁接在第一頁之後');
        expect(find.text(S.bookRemoved), findsOneWidget, reason: '賣家自行下架但未暫停販售');
        expect(find.text(S.salesPaused), findsOneWidget);

        await tester.tap(find.text(S.allLockers));
        await _settle(tester);
        await tester.tap(find.text('師大書櫃'));
        await _settle(tester);
        expect(requests.last, 'GET /api/admin/cabinets/deposits?cabinet_id=4&page=1&limit=20');
        expect(find.text('師大書櫃'), findsOneWidget, reason: '篩選鈕顯示所選書櫃');
        expect(find.text(S.noBooksCurrentlyStoredLockers), findsOneWidget);

        final before = requests.length;
        await tester.tap(find.text(S.clearFilters));
        await _settle(tester);
        expect(requests.sublist(before), [
          'GET /api/admin/cabinets/deposits?page=1&limit=20',
          'GET /api/admin/cabinets/deposits?page=2&limit=20',
        ]);
        expect(find.text(S.allLockers), findsOneWidget);
        expect(find.text('異鄉人'), findsOneWidget);
        await tester.pump(const Duration(seconds: 4));
      }, () => MockClient((request) async {
        if (request.url.path.endsWith('/admin/cabinets')) return _json(adminCabinets);
        requests.add('${request.method} ${request.url.path}?${request.url.query}');
        final query = request.url.queryParameters;
        if (query['cabinet_id'] == '4') {
          return _json(<Object>[], extra: {'pagination': {'total': 0, 'page': 1, 'limit': 20, 'total_pages': 0}});
        }
        final page = int.parse(query['page'] ?? '1');
        final list = page == 1
            ? [
                rows().first,
                {...rows().last, 'book_status': 'removed'},
              ]
            : [
                {...rows().last, 'book_id': 10, 'title': '異鄉人'},
              ];
        return _json(list, extra: {'pagination': {'total': 3, 'page': page, 'limit': 20, 'total_pages': 2}});
      }));
    });
  });

  group('通知', () {
    test('書櫃存書通知歸客服，賣家取回提醒歸交易', () {
      expect(NotificationCategory.of('system', 'cabinet_deposit'), NotificationCategory.service);
      expect(NotificationCategory.of('order', 'book'), NotificationCategory.trade);
      expect(NotificationRouter.hasTarget('cabinet_deposit', 7), isTrue);
      expect(NotificationRouter.hasTarget('book', 7), isTrue);
    });

    Future<bool> open(WidgetTester tester, String type, int id, MockClient client) async {
      tester.view.physicalSize = const Size(390, 1600) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final key = GlobalKey<NavigatorState>();
      late bool opened;
      await http.runWithClient(() async {
        await tester.pumpWidget(_host(const Scaffold(body: SizedBox.expand()), navigatorKey: key));
        await _settle(tester);
        opened = await NotificationRouter.open(key.currentState!, relatedType: type, relatedId: id);
        await _settle(tester);
      }, () => client);
      return opened;
    }

    testWidgets('管理員點逾期通知開啟存書列表的逾期篩選', (tester) async {
      _setUser(id: 9, role: 'admin');
      final opened = await open(tester, 'cabinet_deposit', 7, MockClient((_) async => _json(<Object>[])));
      expect(opened, isTrue);
      final screen = tester.widget<AdminCabinetDepositScreen>(find.byType(AdminCabinetDepositScreen));
      expect(screen.initialOverdue, isTrue);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('非管理員不開啟後台存書列表', (tester) async {
      final opened = await open(tester, 'cabinet_deposit', 7, MockClient((_) async => _json(<Object>[])));
      expect(opened, isFalse);
      expect(find.byType(AdminCabinetDepositScreen), findsNothing);
    });

    testWidgets('賣家點取回提醒開啟自己的書籍並顯示暫停販售', (tester) async {
      final book = _book(2, '夜間飛行', status: 'removed', deposit: _deposit(9, paused: true));
      final opened = await open(
        tester,
        'book',
        2,
        MockClient((request) async => _json(request.url.path.endsWith('/books/2') ? book : <Object>[])),
      );
      expect(opened, isTrue);
      expect(find.byType(BookDetailScreen), findsOneWidget);
      expect(find.text(S.salesPausedPleaseRetrieveBookFrom), findsOneWidget);
      expect(find.text(S.retrieve), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
    });
  });
}
