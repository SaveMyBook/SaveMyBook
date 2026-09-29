import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:savemybook_app/features/admin/admin_book_screen.dart';
import 'package:savemybook_app/features/selling/book_manage_screen.dart';
import 'package:savemybook_app/i18n/app_localizations.dart';
import 'package:savemybook_app/i18n/strings.dart';
import 'package:savemybook_app/models/user.dart';
import 'package:savemybook_app/services/api_service.dart';
import 'package:savemybook_app/services/locale_provider.dart';
import 'package:savemybook_app/utils/app_theme.dart';
import 'package:savemybook_app/widgets/app_buttons.dart';

const _now = '2026-09-29T10:00:00.000Z';

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

Future<void> _frames(WidgetTester tester, [int n = 12]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

http.Response _json(Object? data, {String? message}) => http.Response(
      jsonEncode({'success': true, 'message': ?message, 'data': data}),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void _tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 1400) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Map<String, dynamic> _adminBook(String status, {bool approved = true}) => {
      'book_id': 1, 'title': '小王子', 'isbn': '9789573317241', 'price': 180, 'status': status, 'is_approved': approved,
      'condition_level': 'good', 'category_id': 1, 'category_name': '文學小說', 'seller': {'user_id': 2, 'nickname': '賣家'},
      'view_count': 3, 'pending_report_count': 0, 'image_url': null, 'created_at': _now,
    };

Map<String, dynamic> _myBook(int id, String status, {bool approved = true, String? review}) => {
      'book_id': id, 'seller_id': 1, 'title': '書 $id', 'price': 180, 'status': status, 'is_approved': approved,
      'review_status': review, 'book_images': <Object>[], 'users': {'user_id': 1, 'nickname': '我'}, 'in_cabinet': false, 'deposit': null,
    };

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiService.resetGlobalState();
    ApiService.authToken = 'token';
    ApiService.currentUser = User.fromJson({'user_id': 1, 'nickname': '我', 'email': 'me@example.com', 'role': 'buyer_seller'});
  });

  testWidgets('後台書籍管理：強制下架結果為停止公開顯示時，提示與列表立即顯示停止公開顯示', (tester) async {
    _tallView(tester);
    var book = _adminBook('reserved');
    final patched = <Map<String, dynamic>>[];
    final client = MockClient((req) async {
      final path = req.url.path.replaceFirst('/api', '');
      if (req.method == 'PATCH' && path == '/admin/books/1') {
        patched.add(Map<String, dynamic>.from(jsonDecode(req.body) as Map));
        book = _adminBook('reserved', approved: false);
        return _json({'book_id': 1, 'hidden': true, 'status': 'reserved', 'is_approved': false}, message: '已停止公開顯示');
      }
      if (path == '/admin/books') return _json([book]);
      return _json(<Object>[]);
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(_host(const AdminBookScreen()));
      await _frames(tester);
      expect(find.text(S.hiddenFromPublic), findsNothing);

      await tester.tap(find.text(S.forceDelist));
      await _frames(tester);
      await tester.enterText(find.byType(TextField).last, '內容不實');
      await tester.tap(find.text(S.delist3).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(patched, [{'status': 'removed', 'reason': '內容不實'}]);
      expect(find.text(S.removedFromPublicView), findsOneWidget);
      expect(find.text(S.hiddenFromPublic), findsOneWidget, reason: '列表不必重新整理即顯示停止公開顯示');
      await _frames(tester);
      expect(find.text(S.hiddenFromPublic), findsOneWidget);
      final button = tester.widget<SmallActionButton>(find.widgetWithText(SmallActionButton, S.forceDelist));
      expect(button.onTap, isNull, reason: '已停止公開顯示的書不再提供強制下架');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 4));
    }, () => client);
  });

  group('我的商品：違規說明依書籍狀態', () {
    Future<void> expectDetail(
      WidgetTester tester,
      Map<String, dynamic> book,
      String label,
      String detail, {
      List<Object> reports = const [],
    }) async {
      final client = MockClient((req) async {
        final path = req.url.path.replaceFirst('/api', '');
        if (path == '/books') return _json([book]);
        if (path == '/reports/against-me') return _json(reports);
        return _json(<Object>[]);
      });
      await http.runWithClient(() async {
        await tester.pumpWidget(_host(const BookManageScreen()));
        await _frames(tester);
        expect(find.text(detail), findsNothing);
        await tester.tap(find.text(label));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.text(detail), findsOneWidget, reason: '${book['status']}：$label');
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 4));
      }, () => client);
    }

    testWidgets('已售出或已完成而停止公開顯示的書不提示修改商品內容', (tester) async {
      _tallView(tester);
      await expectDetail(tester, _myBook(1, 'reserved', approved: false), S.violationConfirmed, S.afterReviewBookNoLongerShown);
      await expectDetail(tester, _myBook(2, 'sold', approved: false, review: 'rejected'), S.notApproved, S.afterReviewBookNoLongerShown);
      await expectDetail(tester, _myBook(3, 'sold'), S.violationConfirmed, S.bookWasConfirmedViolateRulesAfter, reports: [
        {'target_type': 'book', 'target_id': 3, 'status': 'resolved'},
      ]);
    });

    testWidgets('販售中或已下架的違規書籍仍提示修改商品內容', (tester) async {
      _tallView(tester);
      await expectDetail(tester, _myBook(4, 'removed', approved: false), S.violationConfirmed, S.violationWasConfirmedBookPleaseCheck);
      await expectDetail(tester, _myBook(5, 'removed', approved: false, review: 'rejected'), S.notApproved, S.bookDidNotPassListingReview);
      await expectDetail(tester, _myBook(6, 'on_sale'), S.violationConfirmed, S.violationWasConfirmedBookPleaseCheck, reports: [
        {'target_type': 'book', 'target_id': 6, 'status': 'resolved'},
      ]);
    });
  });
}
