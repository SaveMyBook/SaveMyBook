import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:savemybook_app/features/admin/admin_book_screen.dart';
import 'package:savemybook_app/features/admin/admin_cabinet_screen.dart';
import 'package:savemybook_app/features/admin/admin_content_screen.dart';
import 'package:savemybook_app/features/admin/admin_dispute_screen.dart';
import 'package:savemybook_app/features/admin/admin_home_screen.dart';
import 'package:savemybook_app/features/admin/admin_member_screen.dart';
import 'package:savemybook_app/features/admin/admin_order_screen.dart';
import 'package:savemybook_app/features/admin/admin_report_screen.dart';
import 'package:savemybook_app/features/admin/admin_ticket_screen.dart';
import 'package:savemybook_app/features/admin/admin_wallet_screen.dart';
import 'package:savemybook_app/features/admin/ai/admin_ai_screen.dart';
import 'package:savemybook_app/features/admin/legal_editor/legal_editor_screen.dart';
import 'package:savemybook_app/i18n/app_localizations.dart';
import 'package:savemybook_app/i18n/strings.dart';
import 'package:savemybook_app/models/support.dart';
import 'package:savemybook_app/services/api_service.dart';
import 'package:savemybook_app/services/locale_provider.dart';
import 'package:savemybook_app/services/theme_provider.dart';
import 'package:savemybook_app/utils/app_theme.dart';

import '../../tool/web_shots/covers.dart' show loadAppFonts;
import '../layout_overflow_test.dart' as fx;

// 平板改版不得影響手機：G5_PHONE_SHOTS=<資料夾> 時輸出手機截圖，供改版前後逐位元組比對
final _shots = Platform.environment['G5_PHONE_SHOTS'];

const _phone = Size(390, 844);

final _legalDoc = LegalDoc.fromJson({
  'doc_id': 1,
  'doc_key': 'terms',
  'title': '服務條款',
  'content': '歡迎使用本系統，使用前請詳閱以下條款。\n\n'
      '1. 總則\n本條款規範會員使用本系統各項服務之權利與義務。\n\n'
      '2. 會員帳號\n會員應妥善保管帳號與密碼，不得轉讓或出借予他人使用。',
  'version': 3,
  'updated_at': fx.now,
});

Map<String, Widget Function()> get _screens => {
      'home': AdminHomeScreen.new,
      'orders': AdminOrderScreen.new,
      'members': AdminMemberScreen.new,
      'disputes': AdminDisputeScreen.new,
      'wallets': AdminWalletScreen.new,
      'tickets': AdminTicketScreen.new,
      'reports': AdminReportScreen.new,
      'books': AdminBookScreen.new,
      'cabinets': AdminCabinetScreen.new,
      'legal': AdminLegalScreen.new,
      'ai': AdminAiScreen.new,
      'legal_editor': () => LegalEditorScreen(docKey: 'terms', fallbackTitle: '服務條款', doc: _legalDoc, requiresConsent: true),
    };

Widget _host(Widget home, Brightness brightness) => MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      supportedLocales: LocaleProvider.supported,
      theme: AppTheme.build(brightness),
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

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _capture(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    final view = tester.binding.renderViews.first;
    final layer = view.debugLayer! as OffsetLayer;
    final image = await layer.toImage(view.paintBounds);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    Directory(_shots!).createSync(recursive: true);
    File('$_shots/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    themeProvider = await ThemeProvider.init();
    localeProvider = await LocaleProvider.init();
    if (_shots != null) await loadAppFonts();
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final brightness in Brightness.values) {
    for (final MapEntry(key: name, value: build) in _screens.entries) {
      testWidgets('手機 $name ${brightness.name} 無溢出', (tester) async {
        tester.view
          ..physicalSize = _phone * 3
          ..devicePixelRatio = 3;
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
            await tester.pumpWidget(_host(build(), brightness));
            await _settle(tester);
            if (_shots != null) await _capture(tester, '${name}_${brightness.name}');
            if (name == 'legal_editor') {
              await tester.tap(find.text(S.preview));
              await _settle(tester);
              if (_shots != null) await _capture(tester, '${name}_preview_${brightness.name}');
            }
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump(const Duration(seconds: 6));
          }, fx.fakeApi);
        } finally {
          FlutterError.onError = previous;
        }
        expect(errors, isEmpty, reason: '版面溢出或元件例外');
      });
    }
  }
}
