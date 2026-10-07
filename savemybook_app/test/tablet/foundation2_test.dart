import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:savemybook_app/features/account/settings_screen.dart';
import 'package:savemybook_app/features/home/home_screen.dart';
import 'package:savemybook_app/features/orders/order_history_screen.dart';
import 'package:savemybook_app/i18n/app_localizations.dart';
import 'package:savemybook_app/i18n/strings.dart';
import 'package:savemybook_app/services/api_service.dart';
import 'package:savemybook_app/services/locale_provider.dart';
import 'package:savemybook_app/services/theme_provider.dart';
import 'package:savemybook_app/utils/app_theme.dart';
import 'package:savemybook_app/widgets/adaptive_sheet.dart';
import 'package:savemybook_app/widgets/app_dialogs.dart';
import 'package:savemybook_app/widgets/app_header.dart';
import 'package:savemybook_app/widgets/app_side_nav.dart';

import '../layout_overflow_test.dart' as lt;

const _portrait = Size(820, 1180);
const _landscape = Size(1180, 820);
const _phone = Size(390, 844);

Widget _app(Widget home) => MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      supportedLocales: LocaleProvider.supported,
      theme: AppTheme.build(Brightness.light),
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

Future<void> _run(WidgetTester tester, Size size, Widget home, Future<void> Function() body) async {
  _size(tester, size);
  await http.runWithClient(() async {
    await tester.pumpWidget(_app(home));
    await _settle(tester, 12);
    await body();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  }, lt.fakeApi);
}

Finder _sideNavText(String label) => find.descendant(of: find.byType(AppSideNav), matching: find.text(label));

class _MenuHost extends StatelessWidget {
  const _MenuHost();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const AppHeader(title: '測試'),
          Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: TextButton(
                onPressed: () => showOptionSheet<String>(
                  context,
                  title: '選項',
                  options: const [SheetOption(value: 'a', label: '項目甲'), SheetOption(value: 'b', label: '項目乙')],
                ),
                child: const Text('開啟選單'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    themeProvider = await ThemeProvider.init();
    localeProvider = await LocaleProvider.init();
    ApiService.authToken = 'test-token';
    ApiService.currentUser = lt.testUser;
  });

  testWidgets('平板 1180x820：側邊欄的訂單紀錄與設定為分頁第一頁，頁首為工具列且沒有返回鍵', (tester) async {
    await _run(tester, _landscape, const HomeScreen(), () async {
      await tester.tap(_sideNavText(S.orderHistory));
      await _settle(tester, 10);
      expect(find.byType(OrderHistoryScreen), findsOneWidget);
      expect(find.byType(TabletToolbar), findsWidgets);
      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsNothing);
      expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);

      await tester.tap(find.byTooltip(S.settings));
      await _settle(tester, 10);
      expect(find.byType(SettingsScreen), findsOneWidget);
    });
  });

  testWidgets('平板 820x1180：圖示列可展開浮層側邊欄，選取後收合', (tester) async {
    await _run(tester, _portrait, const HomeScreen(), () async {
      expect(tester.getSize(find.byType(AppSideNav)).width, AppSideNav.railWidth);
      await tester.tap(find.byTooltip(S.showSidebar));
      await _settle(tester, 6);
      expect(find.byType(AppSideNav), findsNWidgets(2));
      await tester.tap(_sideNavText(S.myReservations));
      await _settle(tester, 10);
      expect(find.byType(AppSideNav), findsOneWidget, reason: '選取後浮層側邊欄收合');
      expect(find.text(S.myReservations), findsWidgets);
    });
  });

  testWidgets('平板：⌘2 切換到通知分頁', (tester) async {
    await _run(tester, _landscape, const HomeScreen(), () async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await _settle(tester, 6);
      final alerts = find.descendant(of: find.byType(AppSideNav), matching: find.byIcon(Icons.notifications_rounded));
      expect(alerts, findsOneWidget, reason: '通知分頁為選取狀態');
    });
  });

  testWidgets('平板：選單在按下的位置旁彈出，不是置中對話框', (tester) async {
    await _run(tester, _landscape, const _MenuHost(), () async {
      final button = tester.getRect(find.text('開啟選單'));
      await tester.tap(find.text('開啟選單'));
      await _settle(tester, 4);
      expect(find.byType(Dialog), findsNothing);
      final item = tester.getRect(find.text('項目甲'));
      expect(item.top, greaterThan(button.top), reason: '彈出框在按鈕下方');
      expect((item.center.dx - button.center.dx).abs(), lessThan(200), reason: '彈出框靠近按鈕');
      await tester.tap(find.text('項目乙'));
      await _settle(tester, 4);
      expect(find.text('項目甲'), findsNothing);
    });
  });

  testWidgets('手機：選單維持底部面板，頁首維持品牌色塊', (tester) async {
    await _run(tester, _phone, const _MenuHost(), () async {
      expect(find.byType(TabletToolbar), findsNothing);
      await tester.tap(find.text('開啟選單'));
      await _settle(tester, 4);
      expect(find.byType(BottomSheet), findsOneWidget);
    });
  });
}
