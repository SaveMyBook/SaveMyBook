import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/category.dart';
import '../models/book.dart';

class ApiService {
  // Android  'http://10.0.2.2:3000/api'
  // iOS  'http://localhost:3000/api'
  static const String baseUrl = 'http://10.0.2.2:3000/api';

  Future<List<Category>> fetchCategories() async {
    try {
      final uri = Uri.parse('$baseUrl/categories').replace(queryParameters: {'flat': 'true'});
      final response = await http.get(uri, headers: {'Accept': 'application/json'}).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final dynamic decoded = json.decode(utf8.decode(response.bodyBytes));
        List<dynamic> data = decoded is List ? decoded : decoded['data'] ?? [];
        List<Category> categories = [];
        for (var item in data) {
          try {
            categories.add(Category.fromJson(item));
          } catch (_) {}
        }
        return categories;
      }
    } catch (_) {}
    return [];
  }

  Future<List<Book>> fetchBooks({
    int page = 1,
    int limit = 20,
    Set<int>? categoryIds,
    String? keyword,
    String? sort
  }) async {
    try {
      Uri uri = Uri.parse('$baseUrl/books');
      Map<String, String> queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (categoryIds != null && categoryIds.isNotEmpty) {
        queryParams['category_ids'] = categoryIds.join(',');
      }

      if (keyword != null && keyword.isNotEmpty) {
        queryParams['keyword'] = keyword;
      }

      if (sort != null) {
        String sortParam = 'popular';
        switch (sort) {
          case '最新上架': sortParam = 'newest'; break;
          case '價格由低到高': sortParam = 'price_asc'; break;
          case '價格由高到低': sortParam = 'price_desc'; break;
        }
        queryParams['sort'] = sortParam;
      }

      uri = uri.replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: {'Accept': 'application/json'}).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final dynamic decoded = json.decode(utf8.decode(response.bodyBytes));
        List<dynamic> data = decoded['data'] ?? [];
        List<Book> books = [];
        for (var item in data) {
          try {
            books.add(Book.fromJson(item));
          } catch (_) {}
        }
        return books;
      }
    } catch (_) {}
    return [];
  }
}