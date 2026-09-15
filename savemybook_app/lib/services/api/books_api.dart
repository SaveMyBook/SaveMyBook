part of '../api_service.dart';

extension BooksApi on ApiService {
  Future<List<Category>> fetchCategories() async {
    final res = await _send('GET', '/categories', query: {'flat': 'true'});
    return _mapList(res, Category.fromJson);
  }

  Future<List<Book>> fetchBooks({
    int page = 1,
    int limit = 20,
    Set<int>? categoryIds,
    String? keyword,
    String? sort,
  }) async {
    final query = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (categoryIds != null && categoryIds.isNotEmpty) {
      query['category_ids'] = categoryIds.join(',');
    }
    if (keyword != null && keyword.isNotEmpty) {
      query['keyword'] = keyword;
    }
    if (sort != null) {
      const allowed = {'popular', 'price_asc', 'price_desc', 'newest'};
      query['sort'] = allowed.contains(sort) ? sort : 'newest';
    }

    final res = await _send('GET', '/books', query: query);
    return _mapList(res, Book.fromJson);
  }

  Future<List<Book>> fetchRecommendedBooks({int limit = 12, Iterable<int> viewedIds = const []}) async {
    final query = <String, String>{'limit': limit.toString()};
    final ids = viewedIds.where((id) => id > 0).take(20);
    if (ids.isNotEmpty) query['viewed_ids'] = ids.join(',');
    final res = await _send('GET', '/books/recommended', query: query);
    return _mapList(res, Book.fromJson);
  }

  Future<List<Book>> fetchSellerBooks(int sellerId) async {
    final res = await _send('GET', '/books',
        query: {'seller_id': sellerId.toString(), 'status': 'on_sale', 'limit': '100'});
    return _mapList(res, Book.fromJson);
  }

  Future<Book?> fetchBookDetail(int bookId) async {
    final res = await _send('GET', '/books/$bookId');
    if (res == null || res['success'] != true || res['data'] is! Map) return null;
    return Book.fromJson(Map<String, dynamic>.from(res['data']));
  }

  Future<List<Book>> fetchMyBooks({String status = 'all'}) async {
    final userId = ApiService.currentUser?.userId;
    if (userId == null) return [];
    final res = await _send('GET', '/books',
        query: {'seller_id': userId.toString(), 'status': status, 'limit': '100'});
    final books = _mapList(res, Book.fromJson);

    return books.where((b) => b.sellerId == userId).toList();
  }

  Future<Map<String, dynamic>?> fetchBookByIsbn(String isbn) async {
    if (ApiService.authToken == null) return null;
    final res = await _send('GET', '/books/isbn/$isbn');
    if (res == null || res['success'] != true) return null;
    return res['data'] as Map<String, dynamic>?;
  }

  Future<String?> updateBook(int bookId, Map<String, dynamic> data) async {
    final res = await _send('PUT', '/books/$bookId', body: data);
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.updateFailed);
  }

  Future<bool> uploadBookImages(int bookId, List<String> filePaths, {List<String>? types}) async {
    if (filePaths.isEmpty) return true;
    final res = await _sendMultipart(
      '/books/$bookId/images',
      [for (final path in filePaths) ('images', path)],
      fields: types == null ? null : {'image_types': types.join(',')},
    );
    return res != null && res['success'] == true;
  }

  Future<String?> createBook(Map<String, String> fields, List<(String field, String filePath)> files) async {
    final res = await _sendMultipart('/books', files, fields: fields);
    if (res == null) return S.pleaseSignFirst;
    if (res['success'] == true) return null;
    return res['message'] as String? ?? S.unknownError;
  }

  Future<bool> deleteBookImage(int bookId, int imageId) async {
    final res = await _send('DELETE', '/books/$bookId/images/$imageId');
    return res != null && res['success'] == true;
  }

  Future<bool> removeBook(int bookId) async {
    final res = await _send('DELETE', '/books/$bookId');
    return res != null && res['success'] == true;
  }

  Future<String?> relistBook(int bookId) async {
    final res = await _send('PUT', '/books/$bookId', body: {'status': 'on_sale'});
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.couldNotRelist);
  }

  Future<(String? url, String? error)> fetchBookShareLink(int bookId) async {
    final res = await _send('GET', '/books/$bookId/share-link');
    if (res == null) return (null, S.couldNotReachServer);
    if (res['success'] != true) {
      return (null, res['message'] as String? ?? S.loadFailed);
    }
    return (res['data']?['url'] as String?, null);
  }

  Future<Book?> fetchBookByShareToken(String token) async {
    final res = await _send('GET', '/books/share/$token');
    if (res == null || res['success'] != true || res['data'] is! Map) return null;
    return Book.fromJson(Map<String, dynamic>.from(res['data']));
  }
}
