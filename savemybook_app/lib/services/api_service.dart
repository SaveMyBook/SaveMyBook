import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/category.dart';
import '../models/book.dart';
import '../models/user.dart';

class ApiService {
  static const String baseUrl = 'https://api.savemybook.today/api';
  static String? authToken;
  static User? currentUser;

  static void Function()? onUnauthorized;

  static List<String> searchHistory = [];

  static void addSearchHistory(String keyword) {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) return;
    searchHistory.remove(trimmed);
    searchHistory.insert(0, trimmed);
    if (searchHistory.length > 10) {
      searchHistory.removeLast();
    }
  }

  static void removeSearchHistory(String keyword) {
    searchHistory.remove(keyword);
  }

  static Future<void> _handleUnauthorized() async {
    if (authToken == null) return;
    authToken = null;
    currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    onUnauthorized?.call();
  }

  Future<bool> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        authToken = data['data']['token'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', authToken!);

        await fetchCurrentUser();
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> register(String email, String password, String nickname) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password, 'nickname': nickname}),
      );

      if (response.statusCode == 201) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> logout() async {
    authToken = null;
    currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  Future<void> fetchCurrentUser() async {
    if (authToken == null) return;
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/me'),
        headers: {'Authorization': 'Bearer $authToken', 'Accept': 'application/json'},
      );

      if (response.statusCode == 401) {
        await _handleUnauthorized();
        return;
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        currentUser = User.fromJson(data['data']);
      }
    } catch (_) {}
  }

  Future<List<Category>> fetchCategories() async {
    try {
      final uri = Uri.parse('$baseUrl/categories').replace(queryParameters: {'flat': 'true'});
      final headers = <String, String>{'Accept': 'application/json'};
      if (authToken != null) {
        headers['Authorization'] = 'Bearer $authToken';
      }

      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));

      if (response.statusCode == 401) {
        await _handleUnauthorized();
        return [];
      }

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
        String sortParam = 'newest';
        switch (sort) {
          case '最新上架': sortParam = 'newest'; break;
          case '熱門推薦': sortParam = 'popular'; break;
          case '價格由低到高': sortParam = 'price_asc'; break;
          case '價格由高到低': sortParam = 'price_desc'; break;
        }
        queryParams['sort'] = sortParam;
      }

      uri = uri.replace(queryParameters: queryParams);

      final headers = <String, String>{'Accept': 'application/json'};
      if (authToken != null) {
        headers['Authorization'] = 'Bearer $authToken';
      }

      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));

      if (response.statusCode == 401) {
        await _handleUnauthorized();
        return [];
      }

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

  Future<Map<String, dynamic>?> fetchBookByIsbn(String isbn) async {
    if (authToken == null) return null;
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/books/isbn/$isbn'),
        headers: {'Authorization': 'Bearer $authToken', 'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 401) {
        await _handleUnauthorized();
        return null;
      }

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return data['data']; // 回傳 { title, author, publisher, publish_date, description }
      }
    } catch (e) {
      print('Fetch ISBN error: $e');
    }
    return null;
  }
}