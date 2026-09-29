import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:savemybook_app/features/selling/edit_book_detail_screen.dart';
import 'package:savemybook_app/features/selling/edit_book_screen.dart';
import 'package:savemybook_app/i18n/app_localizations.dart';
import 'package:savemybook_app/i18n/strings.dart';
import 'package:savemybook_app/models/book.dart';
import 'package:savemybook_app/services/api_service.dart';
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

http.Response _json(Object data) => http.Response(
  jsonEncode({'success': true, 'data': data}),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

// 不改動任何欄位直接按「下一步」，回傳帶到下一頁、最後會送給伺服器的出版日期。
Future<String> _publishDateSent(WidgetTester tester, String stored) async {
  tester.view.physicalSize = const Size(390, 1600) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final book = Book.fromJson({
    'book_id': 1,
    'title': '挪威的森林',
    'isbn': '9789573317241',
    'author': '村上春樹',
    'publisher': '時報出版',
    'publish_date': stored,
    'category_id': 1,
    'price': 200,
    'status': 'on_sale',
  });
  late String sent;
  await http.runWithClient(
    () async {
      await tester.pumpWidget(_host(EditBookScreen(book: book)));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final next = find.text(S.next);
      await tester.ensureVisible(next);
      await tester.tap(next);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      sent = tester.widget<EditBookDetailScreen>(find.byType(EditBookDetailScreen)).publishDate;
    },
    () => MockClient((request) async => request.url.path.endsWith('/categories')
        ? _json([
            {'category_id': 1, 'category_name': '文學小說'},
          ])
        : _json({})),
  );
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 3));
  return sent;
}

void main() {
  setUp(() => ApiService.authToken = 'token');

  testWidgets('出版日期只到年或月時，沒有改動就送回原值，不會被清空', (tester) async {
    expect(await _publishDateSent(tester, '2003-08'), '2003-08');
  });

  testWidgets('沒有改動時保留原本的日期寫法', (tester) async {
    expect(await _publishDateSent(tester, '2003/08/15'), '2003/08/15');
  });
}
