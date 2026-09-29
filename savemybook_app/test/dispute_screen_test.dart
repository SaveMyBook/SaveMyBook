import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:savemybook_app/features/orders/dispute_screen.dart';
import 'package:savemybook_app/i18n/app_localizations.dart';
import 'package:savemybook_app/i18n/strings.dart';
import 'package:savemybook_app/services/locale_provider.dart';
import 'package:savemybook_app/utils/app_theme.dart';

Widget _host(Widget child) => MaterialApp(
  locale: const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
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
    return inner ?? const SizedBox.shrink();
  },
  home: child,
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

TextField _orderField(WidgetTester tester) => tester.widget<TextField>(find.byType(TextField).first);

void main() {
  testWidgets('由訂單進入時顯示訂單編號並鎖定，且不再提供凍結款項開關', (tester) async {
    await tester.pumpWidget(_host(const DisputeScreen(orderNo: 'SMB20260928143015123456')));
    await _settle(tester);

    expect(_orderField(tester).controller!.text, 'SMB20260928143015123456');
    expect(_orderField(tester).enabled, isFalse);
    expect(find.byType(SwitchListTile), findsNothing);
  });

  testWidgets('手動輸入訂單編號時轉為大寫並濾除符號，未填時提示', (tester) async {
    await tester.pumpWidget(_host(const DisputeScreen()));
    await _settle(tester);

    expect(_orderField(tester).enabled, isTrue);
    await tester.tap(find.text(S.submit));
    await _settle(tester);
    expect(find.text(S.enterOrderNumberDisputing), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'smb-2026 0928');
    await tester.pump();
    expect(_orderField(tester).controller!.text, 'SMB20260928');
  });
}
