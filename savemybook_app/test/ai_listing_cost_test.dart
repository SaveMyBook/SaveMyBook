import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:savemybook_app/features/admin/admin_book_screen.dart';
import 'package:savemybook_app/features/selling/ai_listing_assist.dart';
import 'package:savemybook_app/features/selling/sell_book_detail_screen.dart';
import 'package:savemybook_app/i18n/app_localizations.dart';
import 'package:savemybook_app/i18n/strings.dart';
import 'package:savemybook_app/models/ai.dart';
import 'package:savemybook_app/models/book.dart';
import 'package:savemybook_app/services/api_service.dart';
import 'package:savemybook_app/services/locale_provider.dart';
import 'package:savemybook_app/utils/app_labels.dart';
import 'package:savemybook_app/utils/app_theme.dart';
import 'package:savemybook_app/widgets/buyer/book_strip.dart';

import 'layout_overflow_test.dart' as lt;

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

http.Response _json(Object body) =>
    http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json; charset=utf-8'});

const _table = {'like_new': 230, 'good': 170, 'fair': 110, 'poor': 60};

Future<void> _frames(WidgetTester tester, [int n = 10]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _pumpStep2(WidgetTester tester, {Map<String, dynamic>? draft}) async {
  SharedPreferences.setMockInitialValues({if (draft != null) 'sell_draft_v1': jsonEncode(draft)});
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
            aiCondition: 'fair',
            aiPrice: 170,
            aiCarry: AiListingCarry(originalPrice: 400, priceTable: _table, followupToken: 'token'),
          ),
        ),
      );
      await _frames(tester);
    },
    () => MockClient((_) async => _json({'success': true, 'data': []})),
  );
}

String _priceText(WidgetTester tester) => tester.widget<EditableText>(find.byType(EditableText).first).controller.text;

Future<void> _chooseCondition(WidgetTester tester, String from, String to) async {
  await tester.tap(find.text(AppLabels.conditionOf(from)).first);
  await _frames(tester, 6);
  await tester.tap(find.text(AppLabels.conditionOf(to)).last);
  await _frames(tester, 6);
}

void main() {
  setUp(() => ApiService.authToken = 'token');

  group('listing assist responses', () {
    test('parses the mode, follow-up token and per-condition prices', () {
      final result = AiListingAssist.fromJson({
        'mode': 'condition',
        'followup_token': 'abc',
        'fields': {},
        'condition': {'level': 'good', 'confidence': 0.8},
        'price': {
          'suggested': 170,
          'min': 140,
          'max': 200,
          'original_price': 400,
          'by_condition': {
            for (final e in _table.entries) e.key: {'suggested': e.value, 'min': e.value - 30, 'max': e.value + 30},
            'unknown': {'suggested': 0},
          },
        },
      });
      expect(result.mode, 'condition');
      expect(result.followupToken, 'abc');
      expect(result.price!.byCondition, _table);
      expect(AiListingAssist.fromJson(const {'price': {'suggested': 100, 'by_condition': null}}).price!.byCondition, isEmpty);
      expect(AiListingAssist.fromJson(const {}).followupToken, isNull);
    });

    test('only a verified list price the seller applied is carried to the second step', () {
      AiListingAssist result({bool verified = true, bool mismatch = false}) => AiListingAssist.fromJson({
            'isbn_mismatch': mismatch,
            'followup_token': 'next',
            'price': {
              'suggested': 170,
              'original_price': 400,
              'original_price_verified': verified,
              'by_condition': {for (final e in _table.entries) e.key: {'suggested': e.value}},
            },
          });
      final applied = AiListingCarry.applied(result(), followupToken: 'tok');
      expect([applied.originalPrice, applied.priceTable, applied.followupToken], [400, _table, 'tok']);
      expect(AiListingCarry.applied(result(verified: false)).originalPrice, isNull);
      expect(AiListingCarry.applied(result(mismatch: true)).originalPrice, isNull);
      expect(result().price!.suggestedFor('fair'), 110);
      expect(result().price!.suggestedFor(null), 170);

      expect(applied.renewed(sameBook: true, followupToken: 'new').originalPrice, 400);
      final changed = applied.renewed(sameBook: false);
      expect([changed.originalPrice, changed.priceTable, changed.followupToken], [null, isEmpty, 'tok']);
    });

    testWidgets('the suggested price shown is the price for the condition that will be applied', (tester) async {
      tester.view.physicalSize = const Size(390, 1600) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final result = AiListingAssist.fromJson({
        'mode': 'condition',
        'fields': {},
        'condition': {'level': 'good', 'confidence': 0.8},
        'price': {
          'suggested': 170,
          'min': 140,
          'max': 200,
          'original_price': 400,
          'by_condition': {for (final e in _table.entries) e.key: {'suggested': e.value}},
        },
      });
      AiListingSelection? selection;
      await tester.pumpWidget(_host(Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              selection = await showAiListingResultSheet(
                context,
                result: result,
                targets: const AiListingTargets(supportsCondition: true, condition: 'fair', conditionTouched: true, supportsPrice: true),
              );
            },
            child: const Text('open'),
          ),
        ),
      )));
      await _frames(tester, 3);
      await tester.tap(find.text('open'));
      await _frames(tester);
      expect(find.text('\$170'), findsOneWidget);
      expect(find.textContaining(S.rangeP0P1(140, 200)), findsOneWidget);

      await tester.tap(find.text(AppLabels.conditionOf('good')));
      await _frames(tester, 4);
      expect(find.text('\$110'), findsOneWidget, reason: 'keeping the current condition shows the price for that condition');
      expect(find.text('\$170'), findsNothing);
      expect(find.textContaining(S.rangeP0P1(140, 200)), findsNothing);

      await tester.tap(find.byIcon(Icons.check_rounded));
      await _frames(tester);
      expect([selection!.condition, selection!.price], [false, true]);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 3));
    });

    test('keeps recommendation reasons per group', () {
      final rec = AiRecommendations.fromJson({
        'data': [
          {'book': lt.book(3), 'reason': '同為村上春樹的長篇小說'},
          {'book': lt.book(4), 'reason': null},
        ],
        'groups': [
          {'kind': 'more', 'book_ids': [3, 4]},
        ],
        'meta': {'source': 'ai'},
      });
      expect(rec.groups.single.reasons, {3: '同為村上春樹的長篇小說'});
    });
  });

  test('the second step sends only the confirmed book details, list price and token', () async {
    SharedPreferences.setMockInitialValues({});
    String? body;
    await http.runWithClient(
      () => ApiService().requestListingAssist(
        isbn: '9789573317241',
        title: '挪威的森林',
        conditionNote: '書況良好',
        condition: const AiConditionRequest(author: '村上春樹', publisher: ' ', categoryId: 3, originalPrice: 400, followupToken: 'tok'),
      ),
      () => MockClient((req) async {
        body = utf8.decode(req.bodyBytes);
        return _json({'success': true, 'data': {'mode': 'condition'}});
      }),
    );
    String? field(String name) => RegExp('name="$name"\r\n(?:[^\r]+\r\n)*\r\n([^\r]*)').firstMatch(body!)?.group(1);
    expect(field('mode'), 'condition');
    expect(field('author'), '村上春樹');
    expect(field('publisher'), isNull);
    expect(field('category_id'), '3');
    expect(field('original_price'), '400');
    expect(field('followup_token'), 'tok');
  });

  testWidgets('switching the condition swaps an AI price for that condition, but never a price the seller typed', (tester) async {
    await _pumpStep2(tester);
    expect(_priceText(tester), '110');

    await _chooseCondition(tester, 'fair', 'good');
    expect(_priceText(tester), '170');

    await tester.enterText(find.byType(EditableText).first, '250');
    await _frames(tester, 3);
    await _chooseCondition(tester, 'good', 'poor');
    expect(_priceText(tester), '250');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('a restored draft keeps repricing when the price is still the AI price', (tester) async {
    await _pumpStep2(tester, draft: {
      'step2': {
        'price': '60',
        'condition': 'poor',
        'condition_touched': true,
        'ai_prices': _table,
        'ai_auto_price': 60,
        'slots': [null, null, null],
        'extra': [],
      },
    });
    expect(_priceText(tester), '60');
    await _chooseCondition(tester, 'poor', 'like_new');
    expect(_priceText(tester), '230');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('admins can clear the shared bibliography cache of a listing ISBN after confirming', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 1600) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final deleted = <String>[];
    final client = MockClient((req) async {
      final path = req.url.path.replaceFirst('/api', '');
      if (req.method == 'DELETE') {
        deleted.add(path);
        return _json({'success': true, 'data': {'isbn': '9789573317241', 'removed': true}});
      }
      if (path == '/admin/books') {
        return _json({
          'success': true,
          'data': [
            {'book_id': 1, 'title': '挪威的森林', 'isbn': '9789573317241', 'price': 200, 'status': 'on_sale', 'condition_level': 'good', 'category_id': 1,
              'category_name': '文學小說', 'seller': lt.user(2), 'view_count': 3, 'pending_report_count': 0, 'image_url': null, 'created_at': lt.now},
          ],
        });
      }
      return _json({'success': true, 'data': []});
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(_host(const AdminBookScreen()));
      await _frames(tester);
      await tester.tap(find.text(S.actionEdit).first);
      await _frames(tester);
      await tester.ensureVisible(find.text(S.clearBibliographyCache));
      await tester.tap(find.text(S.clearBibliographyCache));
      await _frames(tester, 6);
      expect(deleted, isEmpty, reason: 'nothing is cleared before confirming');
      await tester.tap(find.text(S.clear).last);
      await _frames(tester);
      expect(deleted, ['/admin/ai/isbn-cache/9789573317241']);
      expect(find.text(S.bibliographyCacheIsbnCleared), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 3));
    }, () => client);
  });

  testWidgets('recommendation tiles show the reason and grow only when a reason is present', (tester) async {
    final books = [for (var i = 1; i <= 3; i++) Book.fromJson(lt.book(i))];
    Future<double> stripHeight(Map<int, String> reasons) async {
      await tester.pumpWidget(_host(Scaffold(
        body: BookStrip(title: 'x', icon: Icons.star, books: books, heroPrefix: 'p', showHeader: false, reasons: reasons),
      )));
      await tester.pump(const Duration(seconds: 1));
      return tester.getSize(find.byType(BookStrip)).height;
    }

    final plain = await stripHeight(const {});
    final withReason = await stripHeight(const {2: '延伸您收藏的機器學習實作主題'});
    expect(find.text('延伸您收藏的機器學習實作主題'), findsOneWidget);
    expect(withReason, greaterThan(plain));
    expect(tester.takeException(), isNull);
  });
}
