import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:savemybook_app/features/admin/admin_announcement_screen.dart';
import 'package:savemybook_app/features/admin/admin_backup_screen.dart';
import 'package:savemybook_app/features/admin/admin_book_screen.dart';
import 'package:savemybook_app/features/admin/admin_category_screen.dart';
import 'package:savemybook_app/features/admin/admin_deletion_screen.dart';
import 'package:savemybook_app/features/admin/admin_dispute_screen.dart';
import 'package:savemybook_app/features/admin/admin_home_screen.dart';
import 'package:savemybook_app/features/admin/admin_layout.dart';
import 'package:savemybook_app/features/admin/admin_member_detail_screen.dart';
import 'package:savemybook_app/features/admin/admin_member_screen.dart';
import 'package:savemybook_app/features/admin/admin_operation_log_screen.dart';
import 'package:savemybook_app/features/admin/admin_order_detail_screen.dart';
import 'package:savemybook_app/features/admin/admin_order_screen.dart';
import 'package:savemybook_app/features/admin/admin_report_screen.dart';
import 'package:savemybook_app/features/admin/admin_ticket_screen.dart';
import 'package:savemybook_app/features/admin/admin_wallet_screen.dart';
import 'package:savemybook_app/features/admin/admin_workspace.dart';
import 'package:savemybook_app/features/admin/dispute_ai_panel.dart';
import 'package:savemybook_app/features/admin/reported_message_panel.dart';
import 'package:savemybook_app/i18n/app_localizations.dart';
import 'package:savemybook_app/i18n/strings.dart';
import 'package:savemybook_app/services/api_service.dart';
import 'package:savemybook_app/services/locale_provider.dart';
import 'package:savemybook_app/services/theme_provider.dart';
import 'package:savemybook_app/utils/app_theme.dart';
import 'package:savemybook_app/widgets/state_views.dart';
import 'package:savemybook_app/widgets/swipe_action.dart';

import '../layout_overflow_test.dart' show fakeApi, fakeData, testUser;

const _landscape = Size(1180, 820);
const _portrait = Size(820, 1180);
const _phone = Size(390, 844);

final _shotDir = Platform.environment['E_SHOTS'];

Future<void> _loadFonts() async {
  final manifest = jsonDecode(await rootBundle.loadString('FontManifest.json')) as List<dynamic>;
  final noto = <Future<ByteData>>[];
  for (final family in manifest.cast<Map<String, dynamic>>()) {
    final name = family['family'] as String;
    final loader = FontLoader(name);
    for (final font in (family['fonts'] as List).cast<Map<String, dynamic>>()) {
      final data = rootBundle.load(font['asset'] as String);
      loader.addFont(data);
      if (name == 'NotoSansTC') noto.add(data);
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
}

MockClient _api() {
  final base = fakeApi();
  return MockClient((request) async {
    final path = request.url.path.replaceFirst('/api', '');
    final extra = switch ((request.method, path)) {
      ('GET', '/admin/members/1') => fakeData('GET', '/admin/members/5'),
      ('GET', '/admin/wallets/1') => {
          'user_id': 1,
          'nickname': 'Alexandria Montgomery-Wellington',
          'email': 'alexandria.montgomery@example.com',
          'balance': 9876543.5,
          'frozen_amount': 1200,
          'total_income': 98765432,
          'total_expense': 12345678,
          'transactions': [
            for (var i = 1; i <= 3; i++)
              {'txn_id': i, 'type': 'refund', 'amount': -1234, 'balance_after': 9876543, 'description': 'Order refund', 'created_at': '2026-09-14T10:30:00.000Z'},
          ],
        },
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

// FlutterError.onError 須在每段操作後還原：測試失敗時若仍是自訂的處理器，測試會卡住直到逾時
Future<void> _guard(List<String> errors, Future<void> Function() body) async {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.exceptionAsString();
    if (text.contains('NetworkImageLoadException') || text.contains('HTTP request failed')) return;
    errors.add(text.split('\n').first);
  };
  try {
    await body();
  } finally {
    FlutterError.onError = previous;
  }
}

final _errors = <String>[];

Future<List<String>> _open(WidgetTester tester, Size size, Widget screen) async {
  ApiService.authToken = 'test-token';
  ApiService.currentUser = testUser;
  tester.view
    ..physicalSize = size * 2
    ..devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  _errors.clear();
  await _guard(_errors, () async {
    await tester.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.build(Brightness.dark),
    locale: const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    supportedLocales: LocaleProvider.supported,
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
    home: screen,
  ));
    await _settle(tester);
  });
  return _errors;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _snap(WidgetTester tester, String name) async {
  final dir = _shotDir;
  if (dir == null) return;
  await tester.runAsync(() async {
    final view = tester.binding.renderViews.first;
    final layer = view.debugLayer! as OffsetLayer;
    final image = await layer.toImage(view.paintBounds, pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$dir/$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  expect(finder, findsWidgets);
  await _guard(_errors, () async {
    await tester.ensureVisible(finder.first);
    await tester.pump();
    await tester.tap(finder.first);
    await _settle(tester);
  });
}

Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 3));
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    themeProvider = await ThemeProvider.init();
    localeProvider = await LocaleProvider.init();
    if (_shotDir != null) await _loadFonts();
  });

  Future<void> run(WidgetTester tester, Future<void> Function() body) =>
      http.runWithClient(body, _api);

  group('後台首頁', () {
    for (final size in [_landscape, _portrait]) {
      testWidgets('平板 ${size.width.toInt()}：後台側邊欄與總覽數字卡', (tester) => run(tester, () async {
            final errors = await _open(tester, size, const AdminHomeScreen());
            await _snap(tester, 'home_${size.width.toInt()}');

            expect(find.byType(ListTile), findsNothing, reason: '平板不使用手機的單欄選單列');
            final members = tester.getRect(find.text(S.members2));
            final orders = tester.getRect(find.text(S.todaySOrders));
            expect(members.center.dy, closeTo(orders.center.dy, 1), reason: '總覽數字卡排在同一列');
            final nav = tester.getRect(find.byType(AdminSideNav).first);
            expect(members.left, greaterThan(nav.right), reason: '功能入口移到側邊欄，右側為總覽');
            expect(find.byTooltip(S.moderation).evaluate().isNotEmpty || find.text(S.moderation).evaluate().isNotEmpty, isTrue);
            expect(errors, isEmpty);
            await _close(tester);
          }));
    }

    testWidgets('手機維持單欄選單', (tester) => run(tester, () async {
          final errors = await _open(tester, _phone, const AdminHomeScreen());
          expect(find.byType(ListTile), findsWidgets);
          expect(errors, isEmpty);
          await _close(tester);
        }));
  });

  group('主從並排', () {
    testWidgets('會員管控 1180×820：左側列表、右側會員設定，列表仍在', (tester) => run(tester, () async {
          final errors = await _open(tester, _landscape, const AdminMemberScreen());
          expect(find.text(S.selectItemToView), findsOneWidget);
          final rows = find.byType(AdminListRow);
          final count = rows.evaluate().length;
          await _tap(tester, rows.first);
          await _snap(tester, 'members_split');
          expect(find.byType(AdminMemberDetailScreen), findsOneWidget);
          expect(find.byType(AdminListRow), findsAtLeastNWidgets(count), reason: '列表仍在左側');
          expect(tester.widget<AdminListRow>(find.byType(AdminListRow).first).selected, isTrue, reason: '選取的項目有底色');
          final detail = tester.getRect(find.byType(AdminMemberDetailScreen));
          expect(detail.left, greaterThan(300));
          expect(errors, isEmpty);
          await _close(tester);
        }));

    testWidgets('會員管控 820×1180：單欄，點選推入會員設定', (tester) => run(tester, () async {
          final errors = await _open(tester, _portrait, const AdminMemberScreen());
          await _snap(tester, 'members_portrait');
          expect(find.text(S.selectItemToView), findsNothing);
          await _tap(tester, find.byType(AdminListRow).first);
          expect(find.byType(AdminMemberDetailScreen), findsOneWidget);
          expect(tester.getRect(find.byType(AdminMemberDetailScreen)).left, 0);
          expect(find.byType(AdminMemberScreen, skipOffstage: true), findsNothing);
          expect(errors, isEmpty);
          await _close(tester);
        }));

    testWidgets('訂單管理 1180×820 並排，820×1180 單欄', (tester) => run(tester, () async {
          var errors = await _open(tester, _landscape, const AdminOrderScreen());
          await _tap(tester, find.byType(AdminListRow).first);
          await _snap(tester, 'orders_split');
          expect(find.byType(AdminOrderDetailScreen), findsOneWidget);
          expect(find.byType(AdminOrderScreen), findsOneWidget);
          expect(tester.getRect(find.byType(AdminOrderDetailScreen)).left, greaterThan(300));
          expect(errors, isEmpty);
          await _close(tester);

          errors = await _open(tester, _portrait, const AdminOrderScreen());
          await _snap(tester, 'orders_portrait');
          await _tap(tester, find.byType(AdminListRow).first);
          expect(tester.getRect(find.byType(AdminOrderDetailScreen)).left, 0);
          expect(errors, isEmpty);
          await _close(tester);
        }));

    testWidgets('交易爭議 1180×820：處理時右側顯示 AI 分析與裁決；820×1180 改為置中對話框', (tester) => run(tester, () async {
          var errors = await _open(tester, _landscape, const AdminDisputeScreen());
          await _tap(tester, find.text(S.handle).first);
          await _snap(tester, 'dispute_split');
          expect(find.byType(DisputeAiPanel), findsOneWidget);
          expect(find.byType(Dialog), findsNothing);
          expect(tester.getRect(find.byType(DisputeAiPanel)).left, greaterThan(380));
          expect(find.text(S.viewOrder), findsOneWidget);
          await _tap(tester, find.text(S.viewOrder));
          expect(find.byType(AdminOrderDetailScreen), findsOneWidget, reason: '查看訂單留在右側');
          expect(find.byType(AdminDisputeScreen), findsOneWidget);
          expect(errors, isEmpty);
          await _close(tester);

          errors = await _open(tester, _portrait, const AdminDisputeScreen());
          await _tap(tester, find.text(S.handle).first);
          await _snap(tester, 'dispute_portrait');
          expect(find.byType(Dialog), findsOneWidget);
          expect(find.descendant(of: find.byType(Dialog), matching: find.byType(DisputeAiPanel)), findsOneWidget);
          expect(errors, isEmpty);
          await _close(tester);
        }));

    testWidgets('錢包管理 1180×820 並排；調整餘額為對話框', (tester) => run(tester, () async {
          final errors = await _open(tester, _landscape, const AdminWalletScreen());
          await _tap(tester, find.byType(AdminListRow).first);
          expect(find.byType(AdminWalletDetailScreen), findsOneWidget);
          await _snap(tester, 'wallets_split');
          await _tap(tester, find.text(S.addCoins));
          expect(find.byType(Dialog), findsOneWidget);
          expect(errors, isEmpty);
          await _close(tester);
        }));

    testWidgets('客服工單 1180×820 並排', (tester) => run(tester, () async {
          final errors = await _open(tester, _landscape, const AdminTicketScreen());
          expect(find.text(S.selectItemToView), findsOneWidget);
          await _snap(tester, 'tickets_split');
          expect(errors, isEmpty);
          await _close(tester);
        }));

    testWidgets('內容審核 1180×820：檢舉列表與內容並排並預設顯示第一筆；820×1180 審核為對話框', (tester) => run(tester, () async {
          var errors = await _open(tester, _landscape, const AdminReportScreen());
          await _snap(tester, 'reports_split');
          expect(find.text(S.dismissReport), findsOneWidget);
          expect(find.byType(ReportedMessagePanel), findsOneWidget);
          expect(tester.getRect(find.text(S.dismissReport)).left, greaterThan(380));
          expect(errors, isEmpty);
          await _close(tester);

          errors = await _open(tester, _portrait, const AdminReportScreen());
          await _snap(tester, 'reports_portrait');
          expect(find.text(S.dismissReport), findsNothing);
          await _tap(tester, find.text(S.review).first);
          expect(find.byType(Dialog), findsOneWidget);
          expect(find.descendant(of: find.byType(Dialog), matching: find.text(S.dismissReport)), findsOneWidget);
          expect(errors, isEmpty);
          await _close(tester);
        }));
  });

  group('其他列表在平板排成多欄', () {
    final screens = <String, (Widget Function(), Type)>{
      'books': (() => const AdminBookScreen(), AppCard),
      'deletions': (() => const AdminDeletionScreen(), AppCard),
      'announcements': (() => const AdminAnnouncementScreen(), AppCard),
      'logs': (() => const AdminOperationLogScreen(), AppCard),
      'backups': (() => const AdminBackupScreen(), SwipeActionTile),
    };
    for (final MapEntry(key: name, value: (build, tile)) in screens.entries) {
      testWidgets('$name 1180×820 多欄、820×1180 無溢出', (tester) => run(tester, () async {
            var errors = await _open(tester, _landscape, build());
            await _snap(tester, '${name}_landscape');
            final tops = <double>{};
            final lefts = <double>{};
            for (final element in find.byType(tile).evaluate()) {
              final box = element.renderObject! as RenderBox;
              if (!box.hasSize || box.size.width > 900) continue;
              final rect = box.localToGlobal(Offset.zero) & box.size;
              tops.add(rect.top.roundToDouble());
              lefts.add(rect.left.roundToDouble());
            }
            expect(lefts.length, greaterThan(1), reason: '卡片分成多欄');
            expect(errors, isEmpty);
            await _close(tester);

            errors = await _open(tester, _portrait, build());
            await _snap(tester, '${name}_portrait');
            expect(errors, isEmpty);
            await _close(tester);
          }));
    }

    testWidgets('分類管理置中於合理寬度', (tester) => run(tester, () async {
          final errors = await _open(tester, _landscape, const AdminCategoryScreen());
          await _snap(tester, 'categories_landscape');
          final card = tester.getRect(find.byType(AppCard).first);
          expect(card.width, lessThanOrEqualTo(760));
          expect(card.center.dx, closeTo(_landscape.width / 2, 1));
          expect(errors, isEmpty);
          await _close(tester);
        }));
  });
}
