import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:savemybook_app/features/admin/admin_cabinet_device_screen.dart';
import 'package:savemybook_app/features/admin/admin_dashboard.dart';
import 'package:savemybook_app/features/admin/admin_dispute_screen.dart';
import 'package:savemybook_app/features/admin/admin_home_screen.dart';
import 'package:savemybook_app/features/admin/admin_layout.dart';
import 'package:savemybook_app/features/admin/admin_member_detail_screen.dart';
import 'package:savemybook_app/features/admin/admin_member_screen.dart';
import 'package:savemybook_app/features/admin/admin_order_detail_screen.dart';
import 'package:savemybook_app/features/admin/admin_order_screen.dart';
import 'package:savemybook_app/features/admin/admin_report_screen.dart';
import 'package:savemybook_app/features/admin/admin_ticket_screen.dart';
import 'package:savemybook_app/features/admin/admin_wallet_screen.dart';
import 'package:savemybook_app/features/admin/admin_workspace.dart';
import 'package:savemybook_app/features/admin/legal_editor/legal_editor_header.dart';
import 'package:savemybook_app/features/admin/legal_editor/legal_editor_screen.dart';
import 'package:savemybook_app/features/admin/legal_editor/legal_preview.dart';
import 'package:savemybook_app/i18n/app_localizations.dart';
import 'package:savemybook_app/i18n/strings.dart';
import 'package:savemybook_app/models/support.dart';
import 'package:savemybook_app/services/api_service.dart';
import 'package:savemybook_app/services/locale_provider.dart';
import 'package:savemybook_app/services/theme_provider.dart';
import 'package:savemybook_app/utils/app_info.dart';
import 'package:savemybook_app/utils/app_theme.dart';
import 'package:savemybook_app/widgets/adaptive_sheet.dart';
import 'package:savemybook_app/widgets/app_header.dart';
import 'package:savemybook_app/widgets/app_tiles.dart';
import 'package:savemybook_app/widgets/state_views.dart';

import '../../tool/web_shots/covers.dart' show loadAppFonts;
import '../layout_overflow_test.dart' as fx;

// G5_SHOTS=<資料夾> 時另存截圖供目視檢查；G5_THEME=dark 改深色模式
final _shots = Platform.environment['G5_SHOTS'];
final _dark = Platform.environment['G5_THEME'] == 'dark';

const _landscape = Size(1180, 820);
const _portrait = Size(820, 1180);

final _blank = GlobalKey<NavigatorState>();

// 後台首頁的待處理佇列與書櫃狀態用較接近實際的資料，其餘沿用版面測試的假資料
MockClient _api() {
  final base = fx.fakeApi();
  return MockClient((request) async {
    final path = request.url.path.replaceFirst('/api', '');
    final extra = switch ((request.method, path)) {
      ('GET', '/admin/overview') => {
          'member_count': 1286,
          'pending_report_count': 4,
          'pending_listing_review_count': 2,
          'open_risk_alert_count': 0,
          'pending_dispute_count': 3,
          'active_cabinet_count': 6,
          'today_order_count': 37,
          'open_ticket_count': 5,
        },
      ('GET', '/admin/orders/1') => fx.fakeData('GET', '/admin/orders/7'),
      ('GET', '/admin/members/1') => fx.fakeData('GET', '/admin/members/5'),
      _ => null,
    };
    if (extra != null) {
      return http.Response(jsonEncode({'success': true, 'message': 'OK', 'data': extra}), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }
    final copy = http.Request(request.method, request.url)
      ..headers.addAll(request.headers)
      ..bodyBytes = request.bodyBytes;
    return http.Response.fromStream(await base.send(copy));
  });
}

/// 後台由會員中心推入：底下墊一頁，離開後台按鈕才會出現。
Widget _host(Widget home) => MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: _blank,
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
        return PointerAnchor(child: child ?? const SizedBox.shrink());
      },
      onGenerateInitialRoutes: (_) => [
        MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Center(child: Text('app')))),
        MaterialPageRoute<void>(builder: (_) => home),
      ],
      onGenerateRoute: (_) => null,
    );

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _capture(WidgetTester tester, String name) async {
  if (_shots == null) return;
  await tester.runAsync(() async {
    final view = tester.binding.renderViews.first;
    final layer = view.debugLayer! as OffsetLayer;
    final image = await layer.toImage(view.paintBounds);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    Directory(_shots!).createSync(recursive: true);
    File('$_shots/$name${_dark ? '_dark' : ''}.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

/// 以假資料開啟畫面，執行 [check] 後卸載；過程中的版面溢出與例外一律視為失敗。
Future<void> _run(WidgetTester tester, Size size, Widget Function() home, Future<void> Function() check) async {
  tester.view
    ..physicalSize = size * 2
    ..devicePixelRatio = 2
    ..padding = const FakeViewPadding(top: 48, bottom: 40)
    ..viewPadding = const FakeViewPadding(top: 48, bottom: 40);
  addTearDown(tester.view.reset);
  ApiService.authToken = 'test-token';
  ApiService.currentUser = fx.testUser;

  final errors = <String>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.exceptionAsString();
    if (!text.contains('NetworkImageLoadException') && !text.contains('HTTP request failed')) {
      errors.add(text.split('\n').first);
    }
  };
  try {
    await http.runWithClient(() async {
      await tester.pumpWidget(_host(home()));
      await _settle(tester);
      await check();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 6));
    }, _api);
  } finally {
    FlutterError.onError = previous;
  }
  expect(errors, isEmpty, reason: '版面溢出或元件例外');
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  expect(finder, findsWidgets);
  await tester.tap(finder.first);
  await _settle(tester);
}

Finder _sideNav(String label) => find.descendant(of: find.byType(AdminSideNav).first, matching: find.text(label));

String _tag(Size size) => '${size.width.toInt()}x${size.height.toInt()}';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    themeProvider = await ThemeProvider.init();
    localeProvider = await LocaleProvider.init();
    if (_shots != null) await loadAppFonts();
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('後台工作區', () {
    testWidgets('橫向：完整側邊欄分組列出各分區並附待處理數，右側為首頁儀表板', (tester) async {
      await _run(tester, _landscape, AdminHomeScreen.new, () async {
        await _capture(tester, 'home_${_tag(_landscape)}');
        final nav = tester.getRect(find.byType(AdminSideNav));
        expect(nav.width, closeTo(AdminWorkspace.extendedWidth, 1));
        for (final label in [S.transactions2, S.listings, S.members, S.hardwareOperations, S.orders, S.wallets]) {
          expect(_sideNav(label), findsOneWidget, reason: '側邊欄列出 $label');
        }
        expect(find.byType(AdminDashboard), findsOneWidget);
        expect(tester.getRect(find.byType(AdminDashboard)).left, closeTo(nav.right, 1));
        expect(find.text(kAppName), findsOneWidget, reason: '頂端有回到 App 的按鈕');
        for (final title in [S.resolveDispute, S.moderation, S.supportEnquiries, S.lockerMonitor]) {
          expect(find.descendant(of: find.byType(AdminDashboard), matching: find.text(title)), findsOneWidget, reason: '待處理佇列：$title');
        }
        final members = tester.getRect(find.text(S.members2));
        final orders = tester.getRect(find.text(S.todaySOrders));
        expect(members.center.dy, closeTo(orders.center.dy, 1), reason: '統計卡同一列');
      });
    });

    testWidgets('橫向：切換分區保留各分區的頁面，再次點選回到分區第一頁', (tester) async {
      await _run(tester, _landscape, AdminHomeScreen.new, () async {
        await _tap(tester, _sideNav(S.orders));
        expect(find.byType(AdminOrderScreen), findsOneWidget);
        expect(tester.getRect(find.byType(AdminOrderScreen)).left, greaterThan(AdminWorkspace.extendedWidth - 1));
        expect(find.descendant(of: find.byType(AdminOrderScreen), matching: find.byIcon(Icons.arrow_back_ios_new_rounded)), findsNothing,
            reason: '分區第一頁沒有返回鍵');
        await _tap(tester, find.text('SMB20260914103000123456'));
        expect(find.byType(AdminOrderDetailScreen), findsOneWidget, reason: '訂單內容在右側並排');
        await _capture(tester, 'orders_${_tag(_landscape)}');

        await _tap(tester, _sideNav(S.memberControls));
        expect(find.byType(AdminMemberScreen), findsOneWidget);
        await _tap(tester, _sideNav(S.orders));
        expect(find.byType(AdminOrderDetailScreen), findsOneWidget, reason: '切換回來仍保留原本開啟的訂單');

      });
    });

    testWidgets('分區內推入的頁面留在右側，系統返回先返回分區內的上一頁', (tester) async {
      await _run(tester, _landscape, AdminHomeScreen.new, () async {
        await _tap(tester, _sideNav(S.lockerMonitor));
        await _tap(tester, find.byTooltip(S.lockerDevice));
        expect(find.byType(AdminCabinetDeviceScreen), findsOneWidget);
        expect(tester.getRect(find.byType(AdminCabinetDeviceScreen)).left, greaterThan(AdminWorkspace.extendedWidth - 1));
        expect(find.byType(AdminSideNav), findsOneWidget, reason: '側邊欄仍在');
        await tester.binding.handlePopRoute();
        await _settle(tester);
        expect(find.byType(AdminCabinetDeviceScreen), findsNothing);
        expect(find.byType(AdminHomeScreen), findsOneWidget, reason: '仍在後台');
        await tester.binding.handlePopRoute();
        await _settle(tester);
        expect(find.byType(AdminDashboard), findsOneWidget, reason: '分區第一頁返回後回到首頁');
        expect(find.byType(AdminHomeScreen), findsOneWidget);
      });
    });

    testWidgets('首頁的待處理佇列切換到對應分區與分頁', (tester) async {
      await _run(tester, _landscape, AdminHomeScreen.new, () async {
        await _tap(tester, find.descendant(of: find.byType(AdminDashboard), matching: find.text(S.listingReview)));
        expect(find.byType(AdminReportScreen), findsOneWidget);
        expect(find.text(S.showPhotosFullDetails), findsWidgets, reason: '開啟上架審核分頁');
        await _tap(tester, _sideNav(S.home));
        await _tap(tester, find.descendant(of: find.byType(AdminDashboard), matching: find.text(S.todaySOrders)));
        expect(find.byType(AdminOrderScreen), findsOneWidget);
      });
    });

    testWidgets('頁面內前往其他管理頁的入口改為切換分區，不在原分區再開一份', (tester) async {
      await _run(tester, _landscape, AdminHomeScreen.new, () async {
        await _tap(tester, _sideNav(S.lockerMonitor));
        await _tap(tester, find.byTooltip(S.booksLockers));
        final nav = tester.widget<AdminSideNav>(find.byType(AdminSideNav));
        expect(nav.selectedId, AdminSections.deposits, reason: '側邊欄改選存書列表');
        await _tap(tester, _sideNav(S.lockerMonitor));
        expect(find.byType(AdminCabinetDeviceScreen), findsNothing);
        expect(find.byTooltip(S.booksLockers), findsOneWidget, reason: '書櫃監控仍在第一頁');
      });
    });

    testWidgets('離開後台回到 App', (tester) async {
      await _run(tester, _landscape, AdminHomeScreen.new, () async {
        await _tap(tester, _sideNav(S.orders));
        await _tap(tester, find.text(kAppName));
        expect(find.byType(AdminHomeScreen), findsNothing);
        expect(find.text('app'), findsOneWidget);
      });
    });

    testWidgets('直向：圖示列，可展開成浮層側邊欄，選取後收合', (tester) async {
      await _run(tester, _portrait, AdminHomeScreen.new, () async {
        await _capture(tester, 'home_${_tag(_portrait)}');
        final nav = tester.getRect(find.byType(AdminSideNav).first);
        expect(nav.width, closeTo(AdminWorkspace.railWidth, 1));
        expect(find.byTooltip(S.memberControls), findsOneWidget, reason: '圖示列項目有提示文字');
        await _tap(tester, find.byTooltip(S.showSidebar));
        await _capture(tester, 'home_overlay_${_tag(_portrait)}');
        final overlay = find.byType(AdminSideNav).last;
        expect(tester.getRect(overlay).width, closeTo(AdminWorkspace.extendedWidth, 1));
        await _tap(tester, find.descendant(of: overlay, matching: find.text(S.wallets)));
        expect(tester.getRect(find.byType(AdminSideNav).last).right, lessThanOrEqualTo(0), reason: '選取後收合');
        expect(find.text(S.wallets), findsWidgets);
        await _capture(tester, 'wallets_${_tag(_portrait)}');
      });
    });
  });

  group('各分區在工作區內無溢出', () {
    List<String> titles() => [
          S.orders, S.resolveDispute, S.myBooks, S.moderation, S.categories, S.memberControls, S.membershipTiers, S.wallets,
          S.lockerMonitor, S.booksLockers, S.maintenanceLog, S.reports, S.announcements, S.supportEnquiries, S.faq,
          S.legalDocuments, S.adminAuditLog, S.aiFeatures, S.signMethod, S.databaseBackups, S.pendingDeletions,
        ];

    for (final size in [_landscape, _portrait]) {
      testWidgets('${_tag(size)} 逐一切換分區', (tester) async {
        await _run(tester, size, AdminHomeScreen.new, () async {
          for (final (i, title) in titles().indexed) {
            final item = size == _landscape ? _sideNav(title) : find.byTooltip(title);
            await tester.ensureVisible(item.first);
            await tester.pump();
            await _tap(tester, item);
            final body = tester.getRect(find.byType(IndexedStack).first);
            expect(body.left, greaterThan(size == _landscape ? AdminWorkspace.extendedWidth - 1 : AdminWorkspace.railWidth - 1),
                reason: '$title 顯示在側邊欄右側');
            await _capture(tester, 'section_${i.toString().padLeft(2, '0')}_${_tag(size)}');
          }
        });
      });
    }
  });

  group('其他平板尺寸', () {
    for (final size in [const Size(744, 1133), const Size(1366, 1024), const Size(1024, 768)]) {
      testWidgets('${_tag(size)} 首頁與訂單分區無溢出', (tester) async {
        await _run(tester, size, AdminHomeScreen.new, () async {
          final extended = size.width >= 1024;
          expect(tester.getRect(find.byType(AdminSideNav).first).width,
              closeTo(extended ? AdminWorkspace.extendedWidth : AdminWorkspace.railWidth, 1));
          await _tap(tester, extended ? _sideNav(S.orders) : find.byTooltip(S.orders));
          await _tap(tester, find.byType(AdminListRow).first);
          await _capture(tester, 'orders_${_tag(size)}');
        });
      });
    }
  });

  group('管理列表', () {
    testWidgets('訂單橫向：左側精簡列，選取的項目有底色；篩選以 popover 開啟', (tester) async {
      await _run(tester, _landscape, AdminOrderScreen.new, () async {
        expect(find.byType(AdminListRow), findsWidgets);
        expect(find.byType(AppCard), findsNothing, reason: '平板不使用手機的卡片');
        final row = tester.getRect(find.byType(AdminListRow).first);
        expect(row.height, lessThan(110), reason: '一列一筆的精簡列');
        await _tap(tester, find.byType(AdminListRow).first);
        expect(tester.widget<AdminListRow>(find.byType(AdminListRow).first).selected, isTrue);
        expect(tester.getRect(find.byType(AdminOrderDetailScreen)).left, greaterThan(row.right));
        await _capture(tester, 'orders_direct_${_tag(_landscape)}');

        final filter = tester.getRect(find.byIcon(Icons.filter_list_rounded));
        await _tap(tester, find.byIcon(Icons.filter_list_rounded));
        await _capture(tester, 'orders_filter_${_tag(_landscape)}');
        final option = tester.getRect(find.text(S.orderCompleted).last);
        expect(option.top, greaterThan(filter.top), reason: 'popover 在篩選按鈕旁彈出');
        expect(option.bottom, lessThan(_landscape.height - 200), reason: '不是從底部滑出的面板');
        await _tap(tester, find.text(S.orderCompleted).last);
        expect(find.descendant(of: find.byType(AdminOrderScreen), matching: find.text(S.orderCompleted)), findsWidgets,
            reason: '篩選按鈕顯示目前的條件');
      });
    });

    testWidgets('訂單列以滑鼠右鍵執行與長按相同的動作', (tester) async {
      await _run(tester, _landscape, AdminOrderScreen.new, () async {
        await tester.tap(find.byType(AdminListRow).first, buttons: kSecondaryButton);
        await tester.pump();
        expect(find.text(S.orderNumberCopied), findsOneWidget);
        await _settle(tester);
        await tester.pump(const Duration(seconds: 4));
      });
    });

    testWidgets('會員列以滑鼠右鍵在按下的位置旁彈出操作選單', (tester) async {
      await _run(tester, _landscape, AdminMemberScreen.new, () async {
        final row = tester.getRect(find.byType(AdminListRow).at(1));
        await tester.tapAt(row.center, buttons: kSecondaryButton);
        await _settle(tester);
        await _capture(tester, 'members_menu_${_tag(_landscape)}');
        expect(find.byType(Dialog), findsNothing, reason: '不是置中對話框');
        final item = tester.getRect(find.text(S.memberSettings));
        expect((item.center.dy - row.center.dy).abs(), lessThan(320), reason: '選單在按下的位置旁');
        await _tap(tester, find.text(S.memberSettings));
        expect(find.byType(AdminMemberDetailScreen), findsOneWidget);
      });
    });

    testWidgets('直向：列表各欄橫向排成表格', (tester) async {
      await _run(tester, _portrait, AdminOrderScreen.new, () async {
        await _capture(tester, 'orders_direct_${_tag(_portrait)}');
        final row = find.byType(AdminListRow).first;
        final title = tester.getRect(find.descendant(of: row, matching: find.text('SMB20260914103000123456')));
        final status = tester.getRect(find.descendant(of: row, matching: find.byType(StatusBadge)));
        final amount = tester.getRect(find.descendant(of: row, matching: find.textContaining(r'$')));
        expect(status.center.dy, closeTo(tester.getRect(row).center.dy, 2), reason: '狀態與列同高置中');
        expect(status.left, greaterThan(title.right), reason: '狀態在名稱右側');
        expect(amount.left, greaterThan(status.right), reason: '金額在狀態右側');
      });
    });

    for (final (name, build) in [
      ('members', AdminMemberScreen.new),
      ('wallets', AdminWalletScreen.new),
      ('tickets', AdminTicketScreen.new),
      ('disputes', AdminDisputeScreen.new),
      ('reports', AdminReportScreen.new),
    ]) {
      for (final size in [_landscape, _portrait]) {
        testWidgets('$name ${_tag(size)} 使用精簡列且無溢出', (tester) async {
          await _run(tester, size, build, () async {
            expect(find.byType(AdminListRow), findsWidgets);
            await _capture(tester, '${name}_${_tag(size)}');
          });
        });
      }
    }

    testWidgets('交易爭議橫向：選取的列有底色並保留處理按鈕', (tester) async {
      await _run(tester, _landscape, AdminDisputeScreen.new, () async {
        await _tap(tester, find.text(S.handle));
        expect(tester.widget<AdminListRow>(find.byType(AdminListRow).first).selected, isTrue);
        final submit = tester.getRect(find.text(S.submitDecision));
        expect(submit.width, lessThan(300), reason: '送出裁決按鈕依內容寬度，不撐滿');
        await _capture(tester, 'dispute_arbitrate_${_tag(_landscape)}');
      });
    });
  });

  group('法律文件編輯器', () {
    final doc = LegalDoc.fromJson({
      'doc_id': 1,
      'doc_key': 'terms',
      'title': '服務條款',
      'content': '歡迎使用本系統。\n\n1. 總則\n本條款規範會員使用本系統各項服務之權利與義務。',
      'version': 3,
      'updated_at': fx.now,
    });
    Widget editor() => LegalEditorScreen(docKey: 'terms', fallbackTitle: '服務條款', doc: doc, requiresConsent: true);

    for (final size in [_landscape, _portrait]) {
      testWidgets('${_tag(size)}：模式切換與儲存在工具列，預覽頁首為工具列樣式', (tester) async {
        await _run(tester, size, editor, () async {
          if (size == _portrait) {
            await _tap(tester, find.text(S.preview));
          }
          await _capture(tester, 'legal_editor_${_tag(size)}');
          final toolbar = find.byType(TabletToolbar).first;
          expect(find.descendant(of: toolbar, matching: find.byType(LegalEditorToolbarActions)), findsOneWidget);
          expect(find.byType(LegalEditorHeaderBar), findsNothing, reason: '平板不使用手機的色塊頁首列');
          final save = tester.widget<Text>(find.descendant(of: toolbar, matching: find.text(S.actionSave)));
          expect(save.style?.color, isNot(Colors.white), reason: '未修改時儲存鍵不是白字（淺色工具列上看不見）');
          final title = tester.widget<Text>(find.descendant(of: find.byType(LegalPreview), matching: find.text('服務條款')).first);
          expect(title.style?.color, isNot(Colors.white), reason: '預覽頁首改為工具列樣式');
        });
      });
    }
  });
}
