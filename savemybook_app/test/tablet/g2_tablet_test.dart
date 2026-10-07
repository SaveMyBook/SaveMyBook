import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:savemybook_app/features/books/book_detail_screen.dart';
import 'package:savemybook_app/features/books/favorites_screen.dart';
import 'package:savemybook_app/features/books/seller_screen.dart';
import 'package:savemybook_app/features/cabinet/cabinet_flow_screen.dart';
import 'package:savemybook_app/features/orders/pickup_book_screen.dart';
import 'package:savemybook_app/features/orders/pickup_success_screen.dart';
import 'package:savemybook_app/features/selling/book_manage_screen.dart';
import 'package:savemybook_app/features/selling/edit_book_detail_screen.dart';
import 'package:savemybook_app/features/selling/edit_book_screen.dart';
import 'package:savemybook_app/features/selling/listing_form_layout.dart';
import 'package:savemybook_app/features/selling/sell_book_detail_screen.dart';
import 'package:savemybook_app/features/selling/sell_book_screen.dart';
import 'package:savemybook_app/features/orders/widgets/sticky_pane.dart';
import 'package:savemybook_app/i18n/app_localizations.dart';
import 'package:savemybook_app/i18n/strings.dart';
import 'package:savemybook_app/models/book.dart';
import 'package:savemybook_app/models/cabinet.dart';
import 'package:savemybook_app/models/order.dart';
import 'package:savemybook_app/models/user.dart';
import 'package:savemybook_app/services/api_service.dart';
import 'package:savemybook_app/services/locale_provider.dart';
import 'package:savemybook_app/services/theme_provider.dart';
import 'package:savemybook_app/utils/app_labels.dart';
import 'package:savemybook_app/utils/app_theme.dart';
import 'package:savemybook_app/widgets/adaptive_sheet.dart';
import 'package:savemybook_app/widgets/animations.dart';
import 'package:savemybook_app/widgets/app_buttons.dart';
import 'package:savemybook_app/widgets/app_header.dart';

import '../../tool/web_shots/covers.dart' show loadAppFonts, seedCoverCache;
import '../../tool/web_shots/demo_data.dart';

const _landscape = Size(1180, 820);
const _portrait = Size(820, 1180);
const _sizes = [_landscape, _portrait];

// G2_SHOTS=<資料夾> 時另存截圖（實際字型）供目視檢查；G2_THEME=light 改淺色模式
final _shots = Platform.environment['G2_SHOTS'];
final _brightness = Platform.environment['G2_THEME'] == 'light' ? Brightness.light : Brightness.dark;

http.Response _json(Object? data) => http.Response(
  jsonEncode({
    'success': true,
    'message': 'OK',
    'data': data,
    if (data is List) 'pagination': {'total': data.length, 'page': 1, 'limit': 20, 'total_pages': 1},
  }),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _mine(int id, {String status = 'on_sale', Map<String, dynamic> extra = const {}}) => bookOf(id).toJson(
  extra: {
    'seller_id': meId,
    'users': {'user_id': meId, 'nickname': users[meId], 'avatar_url': null},
    'status': status,
    'deposit': null,
    ...extra,
  },
);

Map<String, dynamic> _access() => {
  'mode': 'scan',
  'reason': null,
  'open_now': true,
  'open_time': '08:00',
  'close_time': '22:00',
  'available_doors': 4,
  'pre_deposit_doors': 2,
};

const _myIds = [12, 2, 3, 5, 7, 9];

Map<String, dynamic> _myBook(int id) => switch (id) {
  12 => _mine(12, extra: {'cabinet_access': _access()}),
  2 => _mine(2, extra: {'deposit': {'deposited_at': ago(days: 3), 'paused': false, 'days_stored': 3, 'door': 'A02'}, 'in_cabinet': true}),
  3 => _mine(3, status: 'reserved'),
  5 => _mine(5, extra: {'reservation': {'reserved_until': DateTime.now().add(const Duration(hours: 30)).toIso8601String()}}),
  7 => _mine(7, status: 'removed'),
  _ => _mine(id, status: 'sold'),
};

final _demo = demoApi();

MockClient _api() => MockClient((request) async {
  final path = request.url.path.replaceFirst('/api', '');
  final query = request.url.queryParameters;
  switch ('${request.method} $path') {
    case 'GET /books' when query['seller_id'] == '$meId':
      return _json([for (final id in _myIds) _myBook(id)]);
    case 'GET /favorites':
      return _json([for (final id in [1, 5, 2, 10, 7, 9, 3]) bookOf(id).toJson()]);
    case 'GET /orders' when query['tab'] == 'pending_pickup':
      return _json([for (final o in ordersByTab['awaiting_pickup']!) o]);
  }
  final detail = RegExp(r'^/books/(\d+)$').firstMatch(path);
  if (request.method == 'GET' && detail != null && _myIds.contains(int.parse(detail.group(1)!))) {
    return _json(_myBook(int.parse(detail.group(1)!)));
  }
  final copy = http.Request(request.method, request.url)
    ..headers.addAll(request.headers)
    ..bodyBytes = request.bodyBytes;
  return http.Response.fromStream(await _demo.send(copy));
});

String _label(Size size) => '${size.width.toInt()}x${size.height.toInt()}';

Future<void> _settle(WidgetTester tester, {int steps = 12}) async {
  for (var i = 0; i < steps; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _shot(WidgetTester tester, String name) async {
  final dir = _shots;
  if (dir == null) return;
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate().toList()) {
      await precacheImage((element.widget as Image).image, element, onError: (_, _) {});
    }
  });
  await _settle(tester, steps: 6);
  await tester.runAsync(() async {
    final view = tester.binding.renderViews.first;
    final layer = view.debugLayer! as OffsetLayer;
    final image = await layer.toImage(view.paintBounds);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File('$dir/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

/// 以平板尺寸開啟畫面（下方墊一頁空白，與 App 內推入頁面相同會顯示返回鍵），檢查版面後截圖。
Future<void> _check(
  WidgetTester tester,
  String name,
  Size size,
  Widget Function() screen,
  Future<void> Function(WidgetTester tester, Size size) verify, {
  bool pushed = true,
}) async {
  final errors = <String>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.exceptionAsString();
    if (text.contains('NetworkImageLoadException') || text.contains('HTTP request failed')) return;
    errors.add(text.split('\n').first);
  };
  tester.view
    ..physicalSize = size * 2
    ..devicePixelRatio = 2
    ..padding = const FakeViewPadding(top: 48, bottom: 40)
    ..viewPadding = const FakeViewPadding(top: 48, bottom: 40);
  addTearDown(tester.view.reset);
  seedCoverCache();

  Object? failure;
  await http.runWithClient(() async {
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      supportedLocales: LocaleProvider.supported,
      theme: AppTheme.build(_brightness),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        S = AppLocalizations.of(context);
        return PointerAnchor(child: child!);
      },
      onGenerateInitialRoutes: (_) => [
        if (pushed) PageRouteBuilder<void>(pageBuilder: (_, _, _) => const SizedBox.shrink()),
        MaterialPageRoute<void>(builder: (_) => screen()),
      ],
      onGenerateRoute: (_) => null,
    ));
    await _settle(tester);
    try {
      await verify(tester, size);
    } catch (e) {
      failure = e;
    }
    await _shot(tester, '${name}_${_label(size)}');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  }, _api);

  FlutterError.onError = previous;
  if (failure != null) fail('$failure');
  expect(errors.toSet(), isEmpty, reason: '版面溢出或元件例外');
}

Rect _rect(WidgetTester tester, Finder finder) => tester.getRect(finder.first);

/// 平板不應出現手機的品牌色頁首（深色色塊）。
void _expectToolbar(WidgetTester tester) {
  expect(find.byType(TabletToolbar), findsWidgets);
  expect(find.byType(LightStatusBar), findsNothing, reason: '平板應為工具列，不是品牌色頁首');
}

Book _book(int id) => Book.fromJson(bookOf(id).toJson());

CabinetSession _session(String status, {int? remainingMs, Map<String, dynamic>? result, bool done = false}) {
  currentCabinetSession = () => cabinetSessionJson(status, remainingMs: remainingMs, result: result, done: done);
  return CabinetSession.fromJson(currentCabinetSession());
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    themeProvider = await ThemeProvider.init();
    localeProvider = await LocaleProvider.init();
    if (_shots != null) await loadAppFonts();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiService.authToken = 'demo-token';
    ApiService.currentUser = User.fromJson(user(meId));
  });

  for (final size in _sizes) {
    final label = _label(size);
    final landscape = size == _landscape;

    testWidgets('商品詳情 $label：工具列、購買按鈕在價格下方且寬度依內容', (tester) async {
      await _check(tester, 'book_detail', size, () => BookDetailScreen(book: _book(statsBookId)), (tester, size) async {
        _expectToolbar(tester);
        final buy = _rect(tester, find.widgetWithText(FilledButton, S.buyNow2));
        final price = _rect(tester, find.text('\$${bookOf(statsBookId).price}'));
        expect(buy.top, greaterThan(price.bottom), reason: '購買按鈕在價格下方');
        expect(buy.top - price.bottom, lessThan(60));
        expect(buy.width, lessThan(220), reason: '按鈕寬度依內容');
        expect(buy.bottom, lessThan(size.height * 0.75), reason: '不是貼齊底部的操作列');
        expect(find.widgetWithText(OutlinedButton, S.messageSeller), findsOneWidget);
        final gallery = _rect(tester, find.byType(PageView));
        final title = _rect(tester, find.descendant(of: find.byType(SingleChildScrollView), matching: find.text(bookOf(statsBookId).title)));
        expect(title.left, greaterThan(gallery.right), reason: '封面與標題左右並排');
        expect(title.top, lessThan(gallery.bottom));
        if (landscape) {
          expect(find.byType(StickyPane), findsOneWidget);
          final scrollable = tester.state<ScrollableState>(find.byType(Scrollable).first);
          scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
          await tester.pump();
          expect(_rect(tester, find.byType(PageView)).top, closeTo(gallery.top, 1), reason: '橫向時封面固定不隨右欄捲動');
          await tester.pump(const Duration(milliseconds: 400));
          final buys = find.widgetWithText(FilledButton, S.buyNow2);
          expect(buys, findsNWidgets(2), reason: '購買按鈕捲出畫面後工具列顯示直接購買');
          expect(_rect(tester, buys).top, lessThan(110));
          await _shot(tester, 'book_detail_scrolled_$label');
          scrollable.position.jumpTo(0);
          await tester.pump();
        } else {
          final scrollable = tester.state<ScrollableState>(find.byType(Scrollable).first);
          scrollable.position.jumpTo(318);
          await _settle(tester, steps: 20);
          expect(find.widgetWithText(FilledButton, S.buyNow2), findsOneWidget, reason: '購買按鈕仍在畫面內時工具列不重複顯示');
          scrollable.position.jumpTo(0);
          await _settle(tester, steps: 6);
          expect(_rect(tester, find.text('ISBN')).left, greaterThan(gallery.right), reason: '封面旁的空間放書籍資料');
          final about = _rect(tester, find.text(S.aboutBook));
          expect(about.top, greaterThan(gallery.bottom), reason: '直向時下方內容全寬');
          expect(about.left, lessThan(gallery.left + 40));
        }
      });
    });

    testWidgets('商品詳情（自己的書） $label：編輯按鈕在價格下方', (tester) async {
      await _check(
        tester,
        'book_detail_own',
        size,
        () => BookDetailScreen(book: Book.fromJson(_myBook(12))),
        (tester, size) async {
          _expectToolbar(tester);
          final edit = _rect(tester, find.widgetWithText(FilledButton, S.editBook));
          expect(edit.width, lessThan(260));
          expect(edit.bottom, lessThan(size.height * 0.75));
        },
      );
    });

    testWidgets('收藏 $label：多欄書卡，工具列不重複放購物車與聊天', (tester) async {
      await _check(tester, 'favorites', size, () => const FavoritesScreen(), (tester, size) async {
        _expectToolbar(tester);
        expect(find.byType(CartIconButton), findsNothing);
        expect(find.byType(ChatIconButton), findsNothing);
        final grid = tester.widget<GridView>(find.byType(GridView));
        expect(grid.gridDelegate, isNotNull);
        final titles = find.text(bookOf(1).title);
        expect(titles, findsWidgets);
      }, pushed: false);
    });

    testWidgets('賣家頁 $label', (tester) async {
      await _check(
        tester,
        'seller',
        size,
        () => SellerScreen(sellerId: 2, sellerName: users[2]!),
        (tester, size) async => _expectToolbar(tester),
      );
    });

    testWidgets('上架第 1 步 $label：工具列含步驟，下一步按鈕不撐滿', (tester) async {
      await _check(tester, 'sell_step1', size, () => const SellBookScreen(), (tester, size) async {
        _expectToolbar(tester);
        expect(find.byType(ListingStepIndicator), findsOneWidget);
        final next = _rect(tester, find.widgetWithText(PrimaryButton, S.next));
        expect(next.width, lessThan(320));
        final title = _rect(tester, find.text('${S.title} *'));
        expect(next.right, greaterThan(title.right), reason: '按鈕靠欄位右側');
      }, pushed: false);
    });

    testWidgets('上架第 2 步 $label', (tester) async {
      await _check(
        tester,
        'sell_step2',
        size,
        () => SellBookDetailScreen(
          isbn: bookOf(listingBookId).isbn,
          title: bookOf(listingBookId).title,
          author: bookOf(listingBookId).author,
          publisher: bookOf(listingBookId).publisher,
          publishDate: '',
          description: '',
          categoryId: bookOf(listingBookId).categoryId,
        ),
        (tester, size) async {
          _expectToolbar(tester);
          expect(find.byType(ListingStepIndicator), findsOneWidget);
          final submit = _rect(tester, find.widgetWithText(PrimaryButton, S.listBook));
          expect(submit.width, lessThan(320));
        },
      );
    });

    testWidgets('編輯書籍 $label', (tester) async {
      await _check(tester, 'edit_book', size, () => EditBookScreen(book: Book.fromJson(_myBook(12))), (tester, size) async {
        _expectToolbar(tester);
        expect(_rect(tester, find.widgetWithText(PrimaryButton, S.next)).width, lessThan(320));
      });
    });

    testWidgets('編輯書籍第 2 步 $label', (tester) async {
      await _check(
        tester,
        'edit_book_detail',
        size,
        () => EditBookDetailScreen(
          book: Book.fromJson(_myBook(12)),
          title: bookOf(12).title,
          author: bookOf(12).author,
          publisher: bookOf(12).publisher,
          isbn: bookOf(12).isbn,
          publishDate: '',
          categoryId: bookOf(12).categoryId,
        ),
        (tester, size) async {
          _expectToolbar(tester);
          expect(_rect(tester, find.widgetWithText(PrimaryButton, S.saveChanges)).width, lessThan(320));
        },
      );
    });

    testWidgets('書籍管理 $label：一列一筆、篩選以彈出選單切換', (tester) async {
      await _check(tester, 'book_manage', size, () => const BookManageScreen(), (tester, size) async {
        _expectToolbar(tester);
        expect(find.text(bookOf(12).title), findsOneWidget);
        final first = _rect(tester, find.text(bookOf(12).title));
        final second = _rect(tester, find.text(bookOf(2).title));
        expect(second.top, greaterThan(first.bottom), reason: '一列一筆');

        if (landscape) {
          expect(find.text(S.selectItemToView), findsOneWidget, reason: '橫向左右並排');
          await tester.tap(find.text(bookOf(12).title));
          await _settle(tester);
          expect(find.byType(BookDetailScreen), findsOneWidget);
          expect(_rect(tester, find.byType(BookDetailScreen)).left, greaterThan(first.right));
          expect(find.widgetWithText(FilledButton, S.editBook), findsOneWidget, reason: '右側為自己的書，可直接編輯');
          await _shot(tester, 'book_manage_selected_$label');
        } else {
          expect(find.text(S.selectItemToView), findsNothing);
          expect(find.widgetWithText(OutlinedButton, S.actionEdit), findsWidgets, reason: '直向一列寬度足夠時操作按鈕直接列出');
        }

        await tester.tap(find.byIcon(Icons.filter_list_rounded));
        await _settle(tester, steps: 4);
        expect(find.byType(BottomSheet), findsNothing, reason: '平板不從底部滑出');
        await _shot(tester, 'book_manage_filter_$label');
        await tester.tap(find.text(AppLabels.ownerBook('removed')).last);
        await _settle(tester, steps: 4);
        Finder row(int id) => find.descendant(of: find.byType(RevealOnScroll), matching: find.text(bookOf(id).title));
        expect(row(12), findsNothing);
        expect(row(7), findsOneWidget);
      }, pushed: false);
    });

    testWidgets('書籍管理 $label：右鍵開啟操作選單', (tester) async {
      await _check(tester, 'book_manage_menu', size, () => const BookManageScreen(), (tester, size) async {
        await tester.tap(find.text(bookOf(12).title), buttons: 2);
        await _settle(tester, steps: 4);
        expect(find.text(S.delist), findsWidgets);
        expect(find.byType(BottomSheet), findsNothing);
        expect(find.byType(Dialog), findsNothing, reason: '在按下的位置旁彈出，不是置中對話框');
      }, pushed: false);
    });

    testWidgets('取書 $label：工具列，可取書訂單不蓋在相機畫面上', (tester) async {
      await _check(
        tester,
        'pickup',
        size,
        () => const PickupBookScreen(isActive: true, scanInput: Stream.empty()),
        (tester, size) async {
          _expectToolbar(tester);
          expect(find.text(S.p0ReadyPickup(2)), findsOneWidget);
          final scan = _rect(tester, find.text(S.pointQrCodeLockerScreen));
          final card = _rect(tester, find.text(bookOf(statsBookId).title));
          if (landscape) {
            expect(card.left, greaterThan(scan.right), reason: '橫向清單在右側');
          } else {
            expect(card.top, greaterThan(scan.bottom), reason: '直向清單在下方');
          }
        },
        pushed: false,
      );
    });

    testWidgets('取書完成 $label：按鈕不撐滿', (tester) async {
      await _check(
        tester,
        'pickup_success',
        size,
        () => PickupSuccessScreen(order: Order.fromJson(pickupOrder())),
        (tester, size) async {
          expect(_rect(tester, find.widgetWithText(ElevatedButton, S.actionBack)).width, lessThan(320));
        },
      );
    });

    for (final (name, screen) in [
      ('cabinet_match', () => CabinetFlowScreen(resume: _session('matching', remainingMs: 52000))),
      ('cabinet_open', () => CabinetFlowScreen(resume: _session('open', remainingMs: 29000))),
      (
        'cabinet_done',
        () => CabinetFlowScreen(
          resume: _session('completed', result: {'outcome': 'completed', 'code': 'COMPLETED', 'message': ''}, done: true),
        ),
      ),
    ]) {
      testWidgets('書櫃作業 $name $label：工具列', (tester) async {
        await _check(tester, name, size, screen, (tester, size) async {
          _expectToolbar(tester);
          final button = _rect(tester, find.byType(PrimaryButton));
          expect(button.width, lessThanOrEqualTo(492));
        });
      });
    }
  }

  testWidgets('書籍管理：平板按「＋」改切換到上架分頁（無外框時照原本推入）', (tester) async {
    await _check(tester, 'book_manage_add', _landscape, () => const BookManageScreen(), (tester, size) async {
      await tester.tap(find.byTooltip(S.sellBook));
      await _settle(tester);
      expect(find.byType(SellBookScreen), findsOneWidget);
    }, pushed: false);
  });
}
