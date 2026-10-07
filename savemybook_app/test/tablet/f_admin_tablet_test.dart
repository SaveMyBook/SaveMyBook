import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:savemybook_app/features/admin/admin_cabinet_device_screen.dart';
import 'package:savemybook_app/features/admin/admin_cabinet_edit_screen.dart';
import 'package:savemybook_app/features/admin/admin_content_screen.dart';
import 'package:savemybook_app/features/admin/admin_maintenance_log_screen.dart';
import 'package:savemybook_app/features/admin/admin_report_screen.dart';
import 'package:savemybook_app/features/admin/legal_editor/legal_editor_screen.dart';
import 'package:savemybook_app/features/admin/legal_editor/legal_preview.dart';
import 'package:savemybook_app/i18n/app_localizations.dart';
import 'package:savemybook_app/i18n/strings.dart';
import 'package:savemybook_app/models/support.dart';
import 'package:savemybook_app/services/api_service.dart';
import 'package:savemybook_app/services/locale_provider.dart';
import 'package:savemybook_app/services/theme_provider.dart';
import 'package:savemybook_app/utils/app_theme.dart';
import 'package:savemybook_app/widgets/state_views.dart';

import '../../tool/web_shots/covers.dart' show loadAppFonts;
import '../layout_overflow_test.dart' as fx;

// F_SHOTS=<資料夾> 時另存截圖（深色模式、實際字型）供目視檢查
final _shots = Platform.environment['F_SHOTS'];

const _landscape = Size(1180, 820);
const _portrait = Size(820, 1180);

final _legalDoc = LegalDoc.fromJson({
  'doc_id': 1,
  'doc_key': 'terms',
  'title': '服務條款',
  'content': '歡迎使用本系統，使用前請詳閱以下條款。\n\n'
      '1. 總則\n本條款規範會員使用本系統各項服務之權利與義務。\n\n'
      '2. 會員帳號\n會員應妥善保管帳號與密碼，不得轉讓或出借予他人使用。\n\n'
      '3. 書櫃使用\n會員應依畫面指示存取書籍，並於存放期限內完成取書。',
  'version': 3,
  'updated_at': fx.now,
});

Widget _host(Widget home) => MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      supportedLocales: LocaleProvider.supported,
      theme: AppTheme.build(_shots == null ? Brightness.light : Brightness.dark),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        S = AppLocalizations.of(context);
        return child ?? const SizedBox.shrink();
      },
      home: home,
    );

/// 以假資料開啟畫面，執行 [check] 後卸載；過程中的版面溢出與例外一律視為失敗。
Future<void> _run(
  WidgetTester tester,
  Size size,
  Widget Function() home,
  Future<void> Function() check, {
  String? shot,
}) async {
  tester.view
    ..physicalSize = size * 2
    ..devicePixelRatio = 2;
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
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      await check();
      if (_shots != null && shot != null) await _capture(tester, '${shot}_${size.width.toInt()}x${size.height.toInt()}');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 6));
    }, fx.fakeApi);
  } finally {
    FlutterError.onError = previous;
  }
  expect(errors, isEmpty, reason: '版面溢出或元件例外');
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _capture(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    final view = tester.binding.renderViews.first;
    final layer = view.debugLayer! as OffsetLayer;
    final image = await layer.toImage(view.paintBounds);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(_shots!).createSync(recursive: true);
    File('$_shots/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

Rect _rect(WidgetTester tester, Finder finder) => tester.getRect(finder.first);

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    themeProvider = await ThemeProvider.init();
    localeProvider = await LocaleProvider.init();
    if (_shots != null) await loadAppFonts();
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('書櫃裝置', () {
    testWidgets('橫向兩欄：左側裝置與櫃門，右側手動回報與作業紀錄', (tester) async {
      await _run(tester, _landscape, () => const AdminCabinetDeviceScreen(cabinetId: 3), () async {
        final device = _rect(tester, find.text(S.pairDevice));
        final reports = _rect(tester, find.text(S.manualReportsConfirm));
        expect(reports.left, greaterThan(device.right), reason: '手動回報在右欄');
        expect(reports.top, lessThan(400), reason: '右欄由頂端開始');
      }, shot: 'device');
    });

    testWidgets('直向單欄置中，內容寬度不超過閱讀寬度', (tester) async {
      await _run(tester, _portrait, () => const AdminCabinetDeviceScreen(cabinetId: 3), () async {
        final doors = _rect(tester, find.text(S.doors));
        final reports = _rect(tester, find.text(S.manualReportsConfirm));
        expect((reports.left - doors.left).abs(), lessThan(1), reason: '單欄上下排列');
        final card = tester.getRect(find.ancestor(of: find.text(S.manualReportsConfirm), matching: find.byType(AppCard)).first);
        expect(card.width, lessThanOrEqualTo(760));
      }, shot: 'device');
    });

    testWidgets('櫃門選單與遠端開櫃在平板以置中對話框呈現', (tester) async {
      await _run(tester, _landscape, () => const AdminCabinetDeviceScreen(cabinetId: 3), () async {
        await tester.tap(find.byTooltip(S.moreActions).first);
        await _settle(tester);
        expect(find.byType(Dialog), findsOneWidget);
        expect(find.text(S.openDoorRemotely), findsOneWidget);
        if (_shots != null) await _capture(tester, 'device_menu');
        Navigator.of(tester.element(find.text(S.openDoorRemotely))).pop();
        await _settle(tester);
        expect(find.byType(Dialog), findsNothing);
      });
    });

    for (final name in ['AdminCabinetOpenMatch', 'AdminCabinetOpenSheet', 'AdminCabinetSessionSheet']) {
      testWidgets('$name 以對話框呈現且無溢出', (tester) async {
        await _run(tester, _landscape, fx.screens[name]!, () async {
          expect(find.byType(Dialog), findsOneWidget);
          final panel = tester.getRect(find.descendant(of: find.byType(Dialog), matching: find.byType(Material)).first);
          expect(panel.width, lessThanOrEqualTo(600));
          expect(panel.height, lessThanOrEqualTo(_landscape.height * 0.85 + 1));
        }, shot: name);
      });
    }
  });

  group('新增書櫃', () {
    testWidgets('橫向兩欄：左側名稱與座標，右側交通預覽與開放時間；按鈕不拉滿', (tester) async {
      await _run(tester, _landscape, AdminCabinetEditScreen.new, () async {
        final name = _rect(tester, find.text(S.lockerName));
        final preview = _rect(tester, find.text(S.nearbyPreview));
        final hours = _rect(tester, find.text(S.openingHours));
        expect(preview.left, greaterThan(name.right + 200), reason: '交通預覽在右欄');
        expect(preview.top, lessThan(name.bottom + 40), reason: '兩欄頂端對齊');
        expect(hours.left, greaterThan(name.right + 200));
        expect(tester.getSize(find.widgetWithText(ElevatedButton, S.createLocker)).width, lessThanOrEqualTo(480));
      }, shot: 'cabinet_edit');
    });

    testWidgets('直向單欄置中於表單寬度', (tester) async {
      await _run(tester, _portrait, AdminCabinetEditScreen.new, () async {
        final name = _rect(tester, find.text(S.lockerName));
        final preview = _rect(tester, find.text(S.nearbyPreview));
        expect((preview.left - name.left).abs(), lessThan(24), reason: '單欄上下排列');
        expect(preview.top, greaterThan(name.bottom));
        final field = tester.getRect(find.byType(TextField).first);
        expect(field.right - name.left, lessThan(640));
        expect(tester.getSize(find.widgetWithText(ElevatedButton, S.createLocker)).width, lessThanOrEqualTo(480));
      }, shot: 'cabinet_edit');
    });
  });

  group('內容審核', () {
    Widget review() => const AdminReportScreen(initialTab: AdminReportScreen.listingReviewTab);

    testWidgets('上架審核橫向：左側清單、右側詳情，操作按鈕固定於詳情底部', (tester) async {
      await _run(tester, _landscape, review, () async {
        expect(find.text(S.showPhotosFullDetails), findsOneWidget, reason: '只有右側詳情可展開');
        expect(find.text(S.approve), findsOneWidget);
        final approve = _rect(tester, find.text(S.approve));
        expect(approve.left, greaterThan(360));
        expect(approve.bottom, greaterThan(_landscape.height - 80), reason: '操作列固定於底部');
        await tester.tap(find.text(S.showPhotosFullDetails));
        await _settle(tester);
        expect(find.text(S.collapse), findsOneWidget);
        await tester.tap(find.text(S.likelyViolation).first);
        await _settle(tester);
        expect(find.text(S.showPhotosFullDetails), findsOneWidget, reason: '切換項目後顯示該項目的詳情');
      }, shot: 'listing_review');
    });

    testWidgets('上架審核直向：單欄卡片置中', (tester) async {
      await _run(tester, _portrait, review, () async {
        final first = tester.getRect(find.ancestor(of: find.text(S.showPhotosFullDetails).first, matching: find.byType(AppCard)).first);
        expect(first.width, lessThanOrEqualTo(760));
        expect((first.center.dx - _portrait.width / 2).abs(), lessThan(1));
        expect(find.text(S.approve), findsWidgets);
      }, shot: 'listing_review');
    });

    testWidgets('防詐警示橫向兩欄、直向單欄', (tester) async {
      Widget risk() => const AdminReportScreen(initialTab: AdminReportScreen.riskAlertTab);
      await _run(tester, _landscape, risk, () async {
        final buttons = find.text(S.falseAlarm);
        final a = _rect(tester, buttons.at(0));
        final b = _rect(tester, buttons.at(1));
        expect(b.left, greaterThan(a.right), reason: '同一列兩張卡片');
        expect((a.top - b.top).abs(), lessThan(1), reason: '同列卡片等高，按鈕對齊');
      }, shot: 'risk');
      await _run(tester, _portrait, risk, () async {
        final buttons = find.text(S.falseAlarm);
        expect((_rect(tester, buttons.at(0)).left - _rect(tester, buttons.at(1)).left).abs(), lessThan(1));
      }, shot: 'risk');
    });
  });

  group('法律文件與常見問題', () {
    Widget editor() => LegalEditorScreen(docKey: 'terms', fallbackTitle: '服務條款', doc: _legalDoc, requiresConsent: true);

    testWidgets('法律文件編輯器橫向左編輯右預覽，不另設預覽分頁', (tester) async {
      await _run(tester, _landscape, editor, () async {
        expect(find.byType(LegalPreview), findsOneWidget);
        expect(find.text(S.preview), findsNothing);
        expect(_rect(tester, find.byType(LegalPreview)).left, greaterThan(_landscape.width / 2 - 1));
        await tester.tap(find.text(S.plainText));
        await _settle(tester);
        await tester.enterText(find.byType(TextField).last, '1. 總則\n即時預覽內容');
        await _settle(tester);
        expect(find.descendant(of: find.byType(LegalPreview), matching: find.textContaining('即時預覽內容')), findsOneWidget);
      }, shot: 'legal_editor');
    });

    testWidgets('法律文件編輯器直向維持三種模式並置中', (tester) async {
      await _run(tester, _portrait, editor, () async {
        expect(find.byType(LegalPreview), findsNothing);
        expect(find.text(S.preview), findsOneWidget);
        final title = tester.getRect(find.byType(TextField).first);
        expect(title.width, lessThanOrEqualTo(760));
      }, shot: 'legal_editor');
    });

    for (final size in [_landscape, _portrait]) {
      testWidgets('法律文件列表、常見問題與維修紀錄 ${size.width.toInt()}', (tester) async {
        await _run(tester, size, AdminLegalScreen.new, () async {}, shot: 'legal_list');
        await _run(tester, size, AdminFaqScreen.new, () async {
          await tester.tap(find.byType(AppCard).first);
          await _settle(tester);
          expect(find.byType(Dialog), findsOneWidget);
          if (_shots != null) await _capture(tester, 'faq_edit_${size.width.toInt()}');
        }, shot: 'faq');
        await _run(tester, size, AdminMaintenanceLogScreen.new, () async {
          final card = tester.getRect(find.byType(AppCard).first);
          expect(card.width, lessThanOrEqualTo(760));
          await tester.tap(find.byType(AppCard).first);
          await _settle(tester);
          expect(find.byType(Dialog), findsOneWidget);
        }, shot: 'maintenance');
      });
    }
  });

  group('其他畫面無溢出', () {
    for (final size in [_landscape, _portrait]) {
      for (final name in ['AdminCabinets', 'AdminCabinetDeposits', 'AdminCabinetDeviceUnpaired', 'AdminAiUsage', 'AdminAiSettings', 'AdminAiDecisions']) {
        testWidgets('$name ${size.width.toInt()}', (tester) async {
          await _run(tester, size, fx.screens[name]!, () async {}, shot: name);
        });
      }
    }

    testWidgets('書櫃監控與存書列表在橫向以多欄卡片排列', (tester) async {
      await _run(tester, _landscape, fx.screens['AdminCabinets']!, () async {
        final names = find.byTooltip(S.lockerDevice);
        expect(_rect(tester, names.at(1)).left, greaterThan(_rect(tester, names.at(0)).right));
      });
      await _run(tester, _landscape, fx.screens['AdminCabinetDeposits']!, () async {
        final buttons = find.text(S.recordRemoval);
        expect(_rect(tester, buttons.at(1)).left, greaterThan(_rect(tester, buttons.at(0)).right));
      });
    });
  });
}
