import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:savemybook_app/models/book.dart';
import 'package:savemybook_app/services/api_service.dart';
import 'package:savemybook_app/services/recently_viewed.dart';

Book _book(int id, {String title = '書', double price = 100}) =>
    Book.fromJson({'book_id': id, 'title': title, 'price': price, 'status': 'on_sale'});

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ApiService.resetGlobalState();
    ApiService.authToken = null;
    RecentlyViewed.resetRefreshThrottle();
    await RecentlyViewed.clear();
  });

  test('書籍已刪除時自收藏、購物車與最近瀏覽移除', () async {
    await RecentlyViewed.add(_book(1));
    await RecentlyViewed.add(_book(2));
    ApiService.favoriteBookIds.value = {1, 2};
    ApiService.cartBookIds.value = {1};
    ApiService.cartCount.value = 1;

    final result = await http.runWithClient(
      () => ApiService().fetchBookDetailState(1),
      () => MockClient((_) async => _json({'success': false, 'code': 'BOOK_NOT_FOUND', 'message': '找不到該書籍'}, 404)),
    );
    await Future<void>.delayed(Duration.zero);

    expect(result.gone, isTrue);
    expect(result.book, isNull);
    expect(ApiService.favoriteBookIds.value, {2});
    expect(ApiService.cartBookIds.value, isEmpty);
    expect(ApiService.cartCount.value, 0);
    expect(RecentlyViewed.books.value.map((b) => b.bookId), [2]);
  });

  test('網路錯誤不視為書籍已刪除', () async {
    await RecentlyViewed.add(_book(1));
    final result = await http.runWithClient(
      () => ApiService().fetchBookDetailState(1),
      () => MockClient((_) async => throw http.ClientException('offline')),
    );
    expect(result.gone, isFalse);
    expect(RecentlyViewed.books.value.map((b) => b.bookId), [1]);
  });

  test('最近瀏覽以伺服器現況更新，移除已不存在的書並保留原順序', () async {
    await RecentlyViewed.add(_book(3, title: '舊書名'));
    await RecentlyViewed.add(_book(2));
    await RecentlyViewed.add(_book(1));

    String? query;
    await http.runWithClient(
      () => RecentlyViewed.refresh(force: true),
      () => MockClient((request) async {
        query = request.url.queryParameters['ids'];
        return _json({
          'success': true,
          'data': [
            {'book_id': 3, 'title': '新書名', 'price': 80, 'status': 'sold'},
            {'book_id': 1, 'title': '書', 'price': 100, 'status': 'on_sale'},
          ],
        });
      }),
    );

    expect(query, '1,2,3');
    final books = RecentlyViewed.books.value;
    expect(books.map((b) => b.bookId), [1, 3]);
    expect(books.last.title, '新書名');
    expect(books.last.status, 'sold');
  });

  test('更新失敗時保留原本的最近瀏覽', () async {
    await RecentlyViewed.add(_book(1));
    await http.runWithClient(
      () => RecentlyViewed.refresh(force: true),
      () => MockClient((_) async => _json({'success': false, 'message': 'error'}, 500)),
    );
    expect(RecentlyViewed.books.value.map((b) => b.bookId), [1]);
  });
}
