import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:savemybook_app/features/books/book_detail_screen.dart';
import 'package:savemybook_app/features/chat/chat_list_screen.dart';
import 'package:savemybook_app/features/home/home_discovery.dart';
import 'package:savemybook_app/features/home/home_screen.dart';
import 'package:savemybook_app/features/orders/cart_screen.dart';
import 'package:savemybook_app/i18n/app_localizations.dart';
import 'package:savemybook_app/i18n/strings.dart';
import 'package:savemybook_app/services/api_service.dart';
import 'package:savemybook_app/services/locale_provider.dart';
import 'package:savemybook_app/services/theme_provider.dart';
import 'package:savemybook_app/utils/app_theme.dart';
import 'package:savemybook_app/widgets/app_header.dart';
import 'package:savemybook_app/widgets/app_side_nav.dart';
import 'package:savemybook_app/widgets/book_card.dart';
import 'package:savemybook_app/widgets/custom_bottom_nav.dart';

import '../layout_overflow_test.dart' as lt;

const _portrait = Size(820, 1180);
const _landscape = Size(1180, 820);
const _phone = Size(390, 844);

final _shotDir = Platform.environment['A_SHOTS'];

Widget _app() => MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      supportedLocales: LocaleProvider.supported,
      theme: AppTheme.build(Brightness.light),
      darkTheme: AppTheme.build(Brightness.dark),
      themeMode: _shotDir == null ? ThemeMode.light : ThemeMode.dark,
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
      home: const HomeScreen(),
    );

void _size(WidgetTester tester, Size size) {
  tester.view
    ..physicalSize = size * 2
    ..devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

Future<void> _settle(WidgetTester tester, [int n = 8]) async {
  for (var i = 0; i < n; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _run(WidgetTester tester, Size size, Future<void> Function() body) async {
  _size(tester, size);
  await http.runWithClient(() async {
    await tester.pumpWidget(_app());
    await _settle(tester, 12);
    await body();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  }, lt.fakeApi);
}

Finder _sideNavText(String label) => find.descendant(of: find.byType(AppSideNav), matching: find.text(label));

bool _fontsLoaded = false;

Future<void> _shot(WidgetTester tester, String name) async {
  final dir = _shotDir;
  if (dir == null) return;
  await tester.runAsync(() async {
    if (!_fontsLoaded) {
      final manifest = jsonDecode(await rootBundle.loadString('FontManifest.json')) as List<dynamic>;
      final noto = <Future<ByteData>>[];
      for (final family in manifest.cast<Map<String, dynamic>>()) {
        final loader = FontLoader(family['family'] as String);
        for (final font in (family['fonts'] as List).cast<Map<String, dynamic>>()) {
          final data = rootBundle.load(font['asset'] as String);
          loader.addFont(data);
          if (family['family'] == 'NotoSansTC') noto.add(data);
        }
        await loader.load();
      }
      for (final alias in ['Roboto', 'CupertinoSystemText', 'CupertinoSystemDisplay']) {
        final loader = FontLoader(alias);
        for (final data in noto) {
          loader.addFont(data);
        }
        await loader.load();
      }
      _fontsLoaded = true;
    }
  });
  await tester.pump(const Duration(milliseconds: 100));
  await tester.runAsync(() async {
    final view = tester.binding.renderViews.first;
    final layer = view.debugLayer! as OffsetLayer;
    final image = await layer.toImage(view.paintBounds);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(dir).createSync(recursive: true);
    File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

Future<void> _openBook(WidgetTester tester) async {
  final viewport = tester.view.physicalSize / tester.view.devicePixelRatio;
  for (var i = 0; i < 6; i++) {
    final visible = find.byType(BookCard).evaluate().where((e) {
      final center = tester.getCenter(find.byWidget(e.widget));
      return center.dy > 160 && center.dy < viewport.height - 40;
    });
    if (visible.isNotEmpty) {
      await tester.tap(find.byWidget(visible.first.widget));
      await _settle(tester, 10);
      return;
    }
    await tester.drag(find.byType(CustomScrollView).first, Offset(0, -viewport.height * 0.6));
    await _settle(tester, 4);
  }
  fail('找不到書籍卡片');
}

int _columnsInFirstRow(WidgetTester tester) {
  final cards = find.byType(BookCard);
  final tops = cards.evaluate().map((e) => tester.getTopLeft(find.byWidget(e.widget)).dy).toList();
  final first = tops.reduce((a, b) => a < b ? a : b);
  return tops.where((y) => (y - first).abs() < 1).length;
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    themeProvider = await ThemeProvider.init();
    localeProvider = await LocaleProvider.init();
    ApiService.authToken = 'test-token';
    ApiService.currentUser = lt.testUser;
  });

  for (final size in [_landscape, _portrait]) {
    final label = '${size.width.toInt()}x${size.height.toInt()}';

    testWidgets('平板 $label：側邊欄含聊天與購物車，頁首不顯示購物車與聊天圖示，推入的頁面保留側邊欄', (tester) async {
      await _run(tester, size, () async {
        final extended = size.width >= 1024;
        final navWidth = tester.getSize(find.byType(AppSideNav)).width;
        expect(navWidth, extended ? 232 : 88);
        expect(find.byType(CustomBottomNav), findsNothing);
        for (final label in [S.home, S.alerts, S.chat, S.cart, S.sellBook, S.collect, S.member]) {
          expect(_sideNavText(label), findsOneWidget, reason: label);
        }
        expect(find.byType(CartIconButton), findsNothing);
        expect(find.byType(ChatIconButton), findsNothing);
        expect(find.byType(WideDiscoveryPanel), findsOneWidget);
        await _shot(tester, 'home_$label');

        await tester.drag(find.byType(CustomScrollView).first, Offset(0, -size.height * 0.9));
        await _settle(tester);
        expect(_columnsInFirstRow(tester), extended ? 5 : 4);
        final gridWidth = tester.getSize(find.byType(BookCard).first).width;
        await _shot(tester, 'home_grid_$label');

        await tester.tap(find.byIcon(Icons.view_agenda_rounded));
        await _settle(tester);
        expect(_columnsInFirstRow(tester), 2, reason: '列表檢視在平板為兩欄');
        await _shot(tester, 'home_list_$label');
        await tester.tap(find.byIcon(Icons.grid_view_rounded));
        await _settle(tester);

        await _openBook(tester);
        expect(find.byType(BookDetailScreen), findsOneWidget);
        expect(find.byType(AppSideNav), findsOneWidget);
        expect(tester.getTopLeft(find.byType(BookDetailScreen)).dx, navWidth);
        await _shot(tester, 'detail_$label');

        await tester.tap(_sideNavText(S.home));
        await _settle(tester, 10);
        expect(find.byType(BookDetailScreen), findsNothing, reason: '點選目前所在的分頁回到第一頁');
        expect(find.byType(WideDiscoveryPanel), findsOneWidget);

        await _openBook(tester);
        expect(find.byType(BookDetailScreen), findsOneWidget);
        await tester.binding.handlePopRoute();
        await _settle(tester, 10);
        expect(find.byType(BookDetailScreen), findsNothing, reason: '返回鍵先返回分頁內的上一頁');
        expect(find.byType(HomeScreen), findsOneWidget);

        await tester.drag(find.byType(CustomScrollView).first, Offset(0, size.height * 2));
        await _settle(tester);
        final tile = find.descendant(of: find.byType(WideDiscoveryPanel), matching: find.byType(Hero)).first;
        expect(tester.getSize(tile).width, moreOrLessEquals(gridWidth, epsilon: 0.5), reason: '推薦卡片寬度與下方格狀一致');
      });
    });

    testWidgets('平板 $label：聊天與購物車分頁，根頁面不顯示返回鍵，清空堆疊交給最上層', (tester) async {
      await _run(tester, size, () async {
        await tester.tap(_sideNavText(S.chat));
        await _settle(tester, 10);
        expect(find.byType(ChatListScreen), findsOneWidget);
        expect(find.byType(AppSideNav), findsOneWidget);
        await _shot(tester, 'chat_$label');

        await tester.tap(_sideNavText(S.cart));
        await _settle(tester, 10);
        expect(find.byType(CartScreen), findsOneWidget);
        expect(Navigator.of(tester.element(find.byType(CartScreen))).canPop(), isFalse);
        await _shot(tester, 'cart_$label');

        final cart = tester.element(find.byType(CartScreen));
        Navigator.pushReplacement(cart, MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('replaced'))));
        await _settle(tester, 10);
        expect(find.text('replaced'), findsOneWidget);
        expect(find.byType(AppSideNav), findsOneWidget);
        await tester.binding.handlePopRoute();
        await _settle(tester, 10);
        expect(find.byType(CartScreen), findsOneWidget, reason: '分頁根頁面被取代時改為推入，返回後仍是購物車');

        await tester.tap(_sideNavText(S.home));
        await _settle(tester, 6);
        await _openBook(tester);
        Navigator.of(tester.element(find.byType(BookDetailScreen))).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('signed out'))),
          (_) => false,
        );
        await _settle(tester, 10);
        expect(find.text('signed out'), findsOneWidget);
        expect(find.byType(HomeScreen), findsNothing, reason: '清空堆疊（登出、回首頁）由最上層 Navigator 執行');
        expect(find.byType(AppSideNav), findsNothing);
      });
    });
  }

  testWidgets('平板與手機切換（分割畫面）：堆疊重置但不產生例外', (tester) async {
    await _run(tester, _landscape, () async {
      await _openBook(tester);
      await tester.tap(_sideNavText(S.cart));
      await _settle(tester, 10);

      _size(tester, _phone);
      await _settle(tester, 10);
      expect(find.byType(CustomBottomNav), findsOneWidget);
      expect(find.byType(AppSideNav), findsNothing);

      _size(tester, _portrait);
      await _settle(tester, 10);
      expect(find.byType(AppSideNav), findsOneWidget);
      await tester.tap(_sideNavText(S.chat));
      await _settle(tester, 10);
      expect(find.byType(ChatListScreen), findsOneWidget);
    });
  });

  testWidgets('手機：底部導覽列與原本相同，頁首有購物車與聊天，不建立分頁 Navigator', (tester) async {
    await _run(tester, _phone, () async {
      expect(find.byType(CustomBottomNav), findsOneWidget);
      expect(find.byType(AppSideNav), findsNothing);
      for (final label in [S.home, S.alerts, S.collect, S.member]) {
        expect(find.descendant(of: find.byType(CustomBottomNav), matching: find.text(label)), findsOneWidget, reason: label);
      }
      expect(find.descendant(of: find.byType(CustomBottomNav), matching: find.text(S.chat)), findsNothing);
      expect(find.descendant(of: find.byType(CustomBottomNav), matching: find.text(S.cart)), findsNothing);
      expect(find.byType(CartIconButton), findsOneWidget);
      expect(find.byType(ChatIconButton), findsOneWidget);
      expect(find.byType(WideDiscoveryPanel), findsNothing);
      expect(find.byType(Navigator, skipOffstage: false), findsOneWidget);

      await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -700));
      await _settle(tester);
      expect(_columnsInFirstRow(tester), 2);
      await _openBook(tester);
      expect(find.byType(BookDetailScreen), findsOneWidget);
      expect(tester.getTopLeft(find.byType(BookDetailScreen)).dx, 0);
      expect(find.byType(CustomBottomNav), findsNothing);
    });
  });
}
