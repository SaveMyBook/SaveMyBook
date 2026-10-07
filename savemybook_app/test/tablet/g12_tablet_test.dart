import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:savemybook_app/features/home/announcement_screen.dart';
import 'package:savemybook_app/features/home/home_discovery.dart';
import 'package:savemybook_app/features/home/home_screen.dart';
import 'package:savemybook_app/features/home/search_screen.dart';
import 'package:savemybook_app/i18n/app_localizations.dart';
import 'package:savemybook_app/i18n/strings.dart';
import 'package:savemybook_app/models/user.dart';
import 'package:savemybook_app/services/api_service.dart';
import 'package:savemybook_app/services/locale_provider.dart';
import 'package:savemybook_app/services/recently_viewed.dart';
import 'package:savemybook_app/services/theme_provider.dart';
import 'package:savemybook_app/utils/app_colors.dart';
import 'package:savemybook_app/utils/app_theme.dart';
import 'package:savemybook_app/widgets/adaptive_sheet.dart';
import 'package:savemybook_app/widgets/app_header.dart';
import 'package:savemybook_app/widgets/book_card.dart';
import 'package:savemybook_app/widgets/buyer/book_strip.dart';
import 'package:savemybook_app/widgets/search_bar_widget.dart';

import '../../tool/web_shots/covers.dart';
import '../../tool/web_shots/demo_data.dart';

const _landscape = Size(1180, 820);
const _portrait = Size(820, 1180);
const _phone = Size(390, 844);

// 目視檢查用：G1_SHOTS=<資料夾> 輸出截圖，G1_THEME=dark 改深色模式
final _shotDir = Platform.environment['G1_SHOTS'];
final _dark = Platform.environment['G1_THEME'] == 'dark';

final _demo = demoApi();

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

const _announcements = [
  (1, 'maintenance', '智慧書櫃韌體更新', '本週六凌晨 2 時至 4 時進行書櫃韌體更新，期間暫停存取書服務。'),
  (2, 'promotion', '新學期二手書上架活動', '活動期間上架書籍可獲得代幣回饋，詳情請見活動說明。'),
  (3, 'policy', '使用條款修訂說明', '配合交易流程調整，本系統修訂使用條款第五條與第八條。'),
];

MockClient _api() => MockClient((request) async {
      final path = request.url.path.replaceFirst('/api', '');
      if ('${request.method} $path' == 'GET /announcements') {
        return _json([
          for (final (id, type, title, content) in _announcements)
            {
              'announcement_id': id,
              'title': title,
              'content': content,
              'type': type,
              'is_published': true,
              'published_at': ago(days: id),
              'created_at': ago(days: id),
            },
        ]);
      }
      final copy = http.Request(request.method, request.url)
        ..headers.addAll(request.headers)
        ..bodyBytes = request.bodyBytes;
      return http.Response.fromStream(await _demo.send(copy));
    });

Widget _app(Widget home) => MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      supportedLocales: LocaleProvider.supported,
      theme: AppTheme.build(_dark ? Brightness.dark : Brightness.light),
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
      home: home,
    );

Future<void> _settle(WidgetTester tester, [int n = 10]) async {
  for (var i = 0; i < n; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// 在模擬 API 下執行並收集版面溢出與例外（圖片載入失敗不計）。
Future<void> _run(WidgetTester tester, Size size, Widget home, Future<void> Function() body) async {
  tester.view
    ..physicalSize = size * 2
    ..devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final errors = <String>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.exceptionAsString();
    if (text.contains('NetworkImageLoadException') || text.contains('HTTP request failed')) return;
    errors.add(text.split('\n').first);
  };
  try {
    if (_shotDir != null && !_fontsLoaded) {
      // 封面圖在載入字型後繪製才看得到書名
      await tester.runAsync(loadAppFonts);
      _fontsLoaded = true;
    }
    await http.runWithClient(() async {
      seedCoverCache();
      await tester.pumpWidget(_app(home));
      await _settle(tester, 15);
      await body();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    }, _api);
  } finally {
    FlutterError.onError = previous;
  }
  expect(errors, isEmpty, reason: '版面溢出或元件例外');
}

bool _fontsLoaded = false;

Future<void> _shot(WidgetTester tester, String name) async {
  final dir = _shotDir;
  if (dir == null) return;
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate().toList()) {
      await precacheImage((element.widget as Image).image, element, onError: (_, _) {});
    }
  });
  await _settle(tester, 4);
  await tester.runAsync(() async {
    final view = tester.binding.renderViews.first;
    final layer = view.debugLayer! as OffsetLayer;
    final image = await layer.toImage(view.paintBounds);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(dir).createSync(recursive: true);
    File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

Finder get _homeToolbar => find.ancestor(of: find.byType(SearchBarWidget), matching: find.byType(TabletToolbar));

Finder _chip(String label) => find.ancestor(of: find.text(label).first, matching: find.byType(Material)).first;

ScrollableState _shelfScrollable(WidgetTester tester) => tester.state<ScrollableState>(
      find.descendant(of: find.byType(WideDiscoveryPanel), matching: find.byType(Scrollable)).first,
    );

Future<void> _rightClick(WidgetTester tester, Finder target) async {
  await tester.tapAt(tester.getCenter(target), buttons: kSecondaryMouseButton, kind: PointerDeviceKind.mouse);
  await _settle(tester, 4);
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    themeProvider = await ThemeProvider.init();
    localeProvider = await LocaleProvider.init();
  });

  setUp(() async {
    ApiService.authToken = 'demo-token';
    ApiService.currentUser = User.fromJson(user(meId));
    await RecentlyViewed.clear();
  });

  for (final size in [_landscape, _portrait]) {
    final label = '${size.width.toInt()}x${size.height.toInt()}';
    final portrait = size.height > size.width;

    testWidgets('平板 $label：首頁頁首為工具列（問候語＋搜尋框），分類換行排列且選取狀態清楚', (tester) async {
      await _run(tester, size, const HomeScreen(), () async {
        expect(_homeToolbar, findsOneWidget);
        expect(find.descendant(of: _homeToolbar, matching: find.text(S.hi(users[meId]!))), findsOneWidget);
        expect(tester.getSize(_homeToolbar).height, TabletToolbar.height + 1, reason: '工具列無圓角色塊，下方 1px 分隔線');
        final searchWidth = tester.getSize(find.byType(SearchBarWidget)).width;
        expect(searchWidth, inInclusiveRange(260, 400));
        await _shot(tester, 'home_$label');

        final c = AppColors.of(tester.element(find.byType(WideDiscoveryPanel)));
        expect(find.ancestor(of: find.text(S.actionAll), matching: find.byType(Wrap)), findsOneWidget, reason: '分類以換行排列，不需橫向捲動');
        expect(tester.widget<Material>(_chip(S.actionAll)).color, c.accent, reason: '未篩選時「全部」為選取狀態');
        final category = categories.values.elementAt(1);
        await tester.tap(find.text(category).first);
        await _settle(tester);
        expect(tester.widget<Material>(_chip(category)).color, c.accent);
        expect(tester.widget<Material>(_chip(S.actionAll)).color, isNot(c.accent));
        expect(find.text(S.results), findsOneWidget);
        expect(find.byType(WideDiscoveryPanel), findsNothing, reason: '篩選時不顯示推薦');
        await _shot(tester, 'home_filtered_$label');
        await tester.tap(find.text(S.actionAll));
        await _settle(tester);
        expect(find.text(S.allBooks), findsOneWidget);
        expect(find.byType(WideDiscoveryPanel), findsOneWidget);
      });
    });

    testWidgets('平板 $label：推薦為水平捲動書架，卡片固定寬，右鍵與長按開啟快捷選單', (tester) async {
      await _run(tester, size, const HomeScreen(), () async {
        final tiles = find.byType(ShelfBookTile);
        expect(tiles, findsWidgets);
        final widths = tiles.evaluate().map((e) => tester.getSize(find.byWidget(e.widget)).width).toSet();
        expect(widths, hasLength(1), reason: '所有書架的卡片同寬');
        final shelf = _shelfScrollable(tester);
        expect(shelf.position.axis, Axis.horizontal);
        final first = tester.getRect(tiles.first);
        final viewport = tester.getRect(find.byWidget(shelf.widget));
        if (portrait) {
          expect(shelf.position.maxScrollExtent, greaterThan(0), reason: '直向時下一張卡片露出一部分，可捲動');
          expect(viewport.width - (first.left - viewport.left), lessThan(first.width * 3 + ShelfBookTile.gap * 2), reason: '第三張只露出一部分');
        } else {
          expect(first.width * 3 + ShelfBookTile.gap * 2, lessThan(viewport.width), reason: '橫向一列放得下三張卡片');
        }

        await _rightClick(tester, tiles.first);
        expect(find.text(S.viewDetails), findsOneWidget);
        expect(find.text(S.addFavorite).evaluate().length + find.text(S.removeFavorite).evaluate().length, 1);
        expect(find.text(S.notInterested), findsOneWidget);
        expect(find.byType(BottomSheet), findsNothing, reason: '平板以彈出選單呈現');
        await _shot(tester, 'shelf_menu_$label');
        await tester.tapAt(const Offset(4, 4));
        await _settle(tester, 4);
        expect(find.text(S.viewDetails), findsNothing);

        final before = tiles.evaluate().length;
        await tester.longPress(tiles.first);
        await _settle(tester, 4);
        await tester.tap(find.text(S.notInterested));
        await _settle(tester, 6);
        expect(tiles.evaluate().length, before - 1, reason: '不感興趣的書從書架移除');
        await tester.pump(const Duration(seconds: 5));
        await _settle(tester);
      });
    });

    testWidgets('平板 $label：全部書籍排序為彈出選單，書卡右鍵開啟選單，列表檢視為兩欄', (tester) async {
      await _run(tester, size, const HomeScreen(), () async {
        await tester.ensureVisible(find.text(S.newest));
        await _settle(tester);
        await tester.tap(find.text(S.newest));
        await _settle(tester, 4);
        expect(find.text(S.priceLowHigh), findsOneWidget);
        expect(find.byType(BottomSheet), findsNothing);
        await _shot(tester, 'sort_popover_$label');
        await tester.tap(find.text(S.priceLowHigh));
        await _settle(tester);
        expect(find.text(S.priceLowHigh), findsOneWidget, reason: '排序按鈕顯示目前的排序');

        final card = find.byType(BookCard).first;
        await _rightClick(tester, card);
        expect(find.text(S.viewDetails), findsOneWidget);
        expect(find.text(S.notInterested), findsNothing);
        await tester.tap(find.text(S.viewDetails));
        await _settle(tester);
        expect(find.byType(BookCard), findsNothing, reason: '開啟書籍詳情');
        await tester.binding.handlePopRoute();
        await _settle(tester);

        await tester.tap(find.byIcon(Icons.view_agenda_rounded));
        await _settle(tester);
        final tops = find.byType(BookCard).evaluate().map((e) => tester.getTopLeft(find.byWidget(e.widget)).dy).toList();
        final firstRow = tops.reduce((a, b) => a < b ? a : b);
        expect(tops.where((y) => (y - firstRow).abs() < 1), hasLength(2), reason: '列表檢視在平板為兩欄');
        await _shot(tester, 'home_list_$label');
      });
    });

    testWidgets('平板 $label：搜尋頁為工具列內嵌搜尋框，Enter 搜尋、Esc 返回，熱門書籍兩欄', (tester) async {
      await _run(tester, size, const HomeScreen(), () async {
        await tester.tap(find.byType(SearchBarWidget));
        await _settle(tester);
        expect(find.byType(SearchScreen), findsOneWidget);
        final toolbar = find.ancestor(of: find.byType(TextField), matching: find.byType(TabletToolbar));
        expect(toolbar, findsOneWidget);
        final first = find.descendant(of: find.byType(SearchScreen), matching: find.text('1'));
        final fifth = find.descendant(of: find.byType(SearchScreen), matching: find.text('5'));
        expect(first, findsOneWidget);
        expect(tester.getTopLeft(fifth).dx, greaterThan(tester.getTopLeft(first).dx + 200), reason: '熱門書籍分左右兩欄');
        expect(tester.getTopLeft(fifth).dy, moreOrLessEquals(tester.getTopLeft(first).dy, epsilon: 1));
        await _shot(tester, 'search_$label');

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await _settle(tester);
        expect(find.byType(SearchScreen), findsNothing, reason: 'Esc 返回');

        await tester.tap(find.byType(SearchBarWidget));
        await _settle(tester);
        await tester.enterText(find.byType(TextField), '統計');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await _settle(tester);
        expect(find.byType(SearchScreen), findsNothing);
        expect(find.descendant(of: find.byType(SearchBarWidget), matching: find.text('統計')), findsOneWidget);
        expect(find.text(S.results), findsOneWidget);
        await _shot(tester, 'search_results_$label');

        await tester.tap(find.byType(SearchBarWidget));
        await _settle(tester);
        expect(find.text(S.recentSearches), findsOneWidget);
        expect(find.descendant(of: find.byType(Wrap), matching: find.text('統計')), findsOneWidget, reason: '最近搜尋');
        await _shot(tester, 'search_history_$label');
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await _settle(tester);

        await tester.tap(find.byTooltip(MaterialLocalizations.of(tester.element(find.byType(SearchBarWidget))).clearButtonTooltip));
        await _settle(tester);
        expect(find.text(S.allBooks), findsOneWidget);
      });
    });
  }

  testWidgets('平板 820x1180：書架可用滑鼠拖曳，游標移入時顯示翻頁鈕', (tester) async {
    await _run(tester, _portrait, const HomeScreen(), () async {
      final shelf = _shelfScrollable(tester);
      final rect = tester.getRect(find.byWidget(shelf.widget));
      final drag = await tester.startGesture(rect.center, kind: PointerDeviceKind.mouse);
      for (var i = 0; i < 6; i++) {
        await drag.moveBy(const Offset(-30, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await drag.up();
      await drag.removePointer();
      await _settle(tester);
      expect(shelf.position.pixels, greaterThan(0), reason: '滑鼠拖曳可捲動書架');
      shelf.position.jumpTo(0);
      await _settle(tester, 3);

      final l = MaterialLocalizations.of(tester.element(find.byType(WideDiscoveryPanel)));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset(rect.center.dx, rect.top + 40));
      await mouse.moveTo(Offset(rect.center.dx + 10, rect.top + 40));
      await _settle(tester, 4);
      final next = find.byTooltip(l.nextPageTooltip).first;
      await _shot(tester, 'shelf_hover_820x1180');
      await tester.tap(next);
      await _settle(tester, 8);
      expect(shelf.position.pixels, greaterThan(0), reason: '按下一頁捲動書架');
      await mouse.removePointer();
    });
  });

  for (final size in [_landscape, _portrait]) {
    final label = '${size.width.toInt()}x${size.height.toInt()}';
    testWidgets('平板 $label：公告列表寬度足夠時與內容並排', (tester) async {
      await _run(tester, size, const Scaffold(body: AnnouncementList()), () async {
        await tester.tap(find.text(_announcements.first.$3));
        await _settle(tester);
        expect(find.byType(AnnouncementDetailScreen), findsOneWidget);
        if (size.width >= 840) {
          expect(find.text(_announcements[1].$3), findsOneWidget, reason: '列表仍顯示在左側');
          expect(tester.getTopLeft(find.byType(AnnouncementDetailScreen)).dx, greaterThan(300));
        } else {
          expect(tester.getSize(find.byType(AnnouncementDetailScreen)).width, size.width);
        }
        await _shot(tester, 'announcements_$label');
      });
    });
  }

  testWidgets('手機：首頁頁首、推薦面板與長按選單維持原樣', (tester) async {
    await _run(tester, _phone, const HomeScreen(), () async {
      expect(find.byType(TabletToolbar), findsNothing);
      expect(find.byType(DiscoveryPanel), findsOneWidget);
      expect(find.byType(ShelfBookTile), findsNothing);
      expect(find.byType(CartIconButton), findsOneWidget);
      final strip = find.descendant(of: find.byType(BookStrip), matching: find.byType(Hero)).first;
      await tester.longPress(strip);
      await _settle(tester, 4);
      expect(find.text(S.notInterested), findsOneWidget);
      expect(find.text(S.viewDetails), findsNothing, reason: '手機長按維持只有「不感興趣」');
      expect(find.byType(BottomSheet), findsOneWidget);
    });
  });
}
