import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:savemybook_app/features/books/book_detail_screen.dart';
import 'package:savemybook_app/i18n/app_localizations.dart';
import 'package:savemybook_app/i18n/strings.dart';
import 'package:savemybook_app/models/book.dart';
import 'package:savemybook_app/models/user.dart';
import 'package:savemybook_app/services/api_service.dart';
import 'package:savemybook_app/services/locale_provider.dart';
import 'package:savemybook_app/utils/app_theme.dart';

Map<String, dynamic> _book({int sellerId = 2, String status = 'on_sale', Map<String, dynamic>? reservation}) => {
  'book_id': 5,
  'seller_id': sellerId,
  'title': '小王子',
  'price': 180,
  'status': status,
  'is_approved': true,
  'book_images': <Object>[],
  'users': {'user_id': sellerId, 'nickname': '賣家'},
  'reservation': ?reservation,
};

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
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

http.Response _json(Object? data) => http.Response(
  jsonEncode({'success': true, 'data': data}),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

FilledButton _filledWith(WidgetTester tester, String text) => tester.widget<FilledButton>(
  find.ancestor(of: find.text(text), matching: find.byWidgetPredicate((w) => w is FilledButton)).first,
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiService.resetGlobalState();
    ApiService.authToken = 'token';
    ApiService.currentUser = User.fromJson({
      'user_id': 1,
      'nickname': '我',
      'email': 'me@example.com',
      'role': 'buyer_seller',
    });
  });

  Future<void> pumpDetail(WidgetTester tester, Map<String, dynamic> json, MockClient client) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await http.runWithClient(() async {
      await tester.pumpWidget(_host(BookDetailScreen(book: Book.fromJson(json))));
      await _settle(tester);
    }, () => client);
  }

  for (final (status, reservation, label) in [
    ('reserved', null, '已售出・無法編輯'),
    ('sold', null, '已完成・無法編輯'),
    ('on_sale', {'reserved_until': DateTime.now().add(const Duration(hours: 3)).toIso8601String()}, '已預訂・無法編輯'),
  ]) {
    testWidgets('自己的書狀態為 $status 時不能編輯', (tester) async {
      final json = _book(sellerId: 1, status: status, reservation: reservation);
      await pumpDetail(tester, json, MockClient((_) async => _json(json)));
      expect(find.text(label), findsOneWidget);
      expect(_filledWith(tester, label).onPressed, isNull);
      expect(find.text(S.editBook), findsNothing);
      await tester.pump(const Duration(seconds: 4));
    });
  }

  testWidgets('自己販售中或已下架的書可以編輯', (tester) async {
    final json = _book(sellerId: 1, status: 'removed');
    await pumpDetail(tester, json, MockClient((_) async => _json(json)));
    expect(_filledWith(tester, S.editBook).onPressed, isNotNull);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('直接購買：不經購物車送出購買並顯示付款成功', (tester) async {
    final requests = <String>[];
    final json = _book();
    await pumpDetail(
      tester,
      json,
      MockClient((request) async {
        requests.add('${request.method} ${request.url.path} ${request.body}');
        if (request.url.path.endsWith('/wallet')) return _json({'balance': 500});
        if (request.url.path.endsWith('/orders/buy-now')) return _json({'order_id': 1});
        if (request.url.path.endsWith('/cart/book-ids')) return _json(<int>[]);
        if (request.url.path.endsWith('/favorites/ids')) return _json(<int>[]);
        return _json(json);
      }),
    );

    expect(find.text('直接購買'), findsOneWidget);
    await http.runWithClient(
      () async {
        await tester.tap(find.text('直接購買'));
        await _settle(tester);
      },
      () => MockClient((request) async {
        requests.add('${request.method} ${request.url.path} ${request.body}');
        if (request.url.path.endsWith('/wallet')) return _json({'balance': 500});
        if (request.url.path.endsWith('/orders/buy-now')) return _json({'order_id': 1});
        return _json(request.url.path.endsWith('/books/5') ? json : <Object>[]);
      }),
    );

    expect(requests, contains('POST /api/orders/buy-now {"book_id":5}'));
    expect(requests.where((r) => r.startsWith('POST /api/cart')), isEmpty);
    expect(find.text(S.paymentSuccessful), findsOneWidget);
    await tester.tap(find.text(S.keepBrowsing));
    await _settle(tester);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('直接購買：餘額不足時不送出購買', (tester) async {
    final requests = <String>[];
    final json = _book();
    final client = MockClient((request) async {
      requests.add('${request.method} ${request.url.path}');
      if (request.url.path.endsWith('/wallet')) return _json({'balance': 50});
      return _json(request.url.path.endsWith('/books/5') ? json : <Object>[]);
    });
    await pumpDetail(tester, json, client);
    await http.runWithClient(() async {
      await tester.tap(find.text('直接購買'));
      await _settle(tester);
    }, () => client);
    expect(requests.where((r) => r.contains('buy-now')), isEmpty);
    expect(find.text(S.notEnoughCoinsOrderNeedsBut('180', '50')), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('別人預約保留中或已售出的書不顯示直接購買', (tester) async {
    final held = _book(
      reservation: {
        'reserved_until': DateTime.now().add(const Duration(hours: 3)).toIso8601String(),
        'reserved_for_me': false,
      },
    );
    await pumpDetail(tester, held, MockClient((_) async => _json(held)));
    expect(find.text('直接購買'), findsNothing);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('書籍頁顯示相似的書與自動補齊標示', (tester) async {
    final json = {
      ..._book(),
      'description': '依書目整理的簡介',
      'publisher': '高點文化',
      'enrichment': {
        'fields': ['description', 'publisher'],
        'ai_written': true,
      },
    };
    final similar = [
      {..._book(), 'book_id': 8, 'title': '行政法解題書'},
      {..._book(), 'book_id': 9, 'title': '民法總則'},
    ];
    await pumpDetail(
      tester,
      json,
      MockClient((request) async {
        if (request.url.path.endsWith('/books/5/similar')) return _json(similar);
        return _json(request.url.path.endsWith('/books/5') ? json : <Object>[]);
      }),
    );
    expect(find.text('內容簡介'), findsOneWidget);
    expect(find.text('由 AI 依書目整理'), findsOneWidget);
    expect(find.text('部分資料依 ISBN 書目自動補齊'), findsOneWidget);
    expect(find.text('AI 整理'), findsNothing, reason: '來源標示不再夾在欄位文字中');
    await tester.scrollUntilVisible(find.text('相似的書'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('行政法解題書'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });
}
