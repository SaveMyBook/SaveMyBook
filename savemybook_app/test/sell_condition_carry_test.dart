import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:savemybook_app/features/selling/sell_book_detail_screen.dart';
import 'package:savemybook_app/i18n/app_localizations.dart';
import 'package:savemybook_app/i18n/strings.dart';
import 'package:savemybook_app/services/api_service.dart';
import 'package:savemybook_app/services/locale_provider.dart';
import 'package:savemybook_app/utils/app_labels.dart';
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

Future<void> _pumpScreen(WidgetTester tester, {required Map<String, dynamic> draft}) async {
  SharedPreferences.setMockInitialValues({'sell_draft_v1': jsonEncode(draft)});
  tester.view.physicalSize = const Size(390, 1600) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await http.runWithClient(
    () async {
      await tester.pumpWidget(
        _host(
          const SellBookDetailScreen(
            isbn: '9789573317241',
            title: '挪威的森林',
            author: '村上春樹',
            publisher: '時報出版',
            publishDate: '',
            description: '',
            categoryId: 1,
            aiCondition: 'poor',
          ),
        ),
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    },
    () => MockClient(
      (_) async => http.Response(
        jsonEncode({'success': true, 'data': []}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    ),
  );
}

void main() {
  setUp(() => ApiService.authToken = 'token');

  testWidgets('草稿只存了預設書況時，仍套用上一步 AI 判斷的書況', (tester) async {
    await _pumpScreen(
      tester,
      draft: {
        'step2': {
          'price': '',
          'condition': 'good',
          'slots': [null, null, null],
          'extra': [],
        },
      },
    );
    expect(find.text(AppLabels.conditionOf('poor')), findsWidgets);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('使用者已手動選過書況時不被 AI 覆蓋', (tester) async {
    await _pumpScreen(
      tester,
      draft: {
        'step2': {
          'price': '',
          'condition': 'like_new',
          'condition_touched': true,
          'slots': [null, null, null],
          'extra': [],
        },
      },
    );
    expect(find.text(AppLabels.conditionOf('like_new')), findsWidgets);
    expect(find.text(AppLabels.conditionOf('poor')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  });
}
