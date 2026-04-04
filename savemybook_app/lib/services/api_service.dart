import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/category.dart';
import '../models/book.dart';

class ApiService {
  // Android  'http://10.0.2.2:3000/api'
  // iOS  'http://localhost:3000/api'
  static const String baseUrl = 'http://192.168.100.142:3000/api';

  Future<List<Category>> fetchCategories() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/categories?flat=true'));
      if (response.statusCode == 200) {
        final dynamic decoded = json.decode(utf8.decode(response.bodyBytes));
        List<dynamic> data = decoded is List ? decoded : decoded['data'] ?? [];
        return data.map((json) => Category.fromJson(json)).toList();
      }
      throw Exception('載入分類失敗');
    } catch (e) {
      print('取得分類發生錯誤: $e');
      return [];
    }
  }

  Future<List<Book>> fetchBooks({int page = 1, int limit = 20, int? categoryId}) async {
    try {
      String url = '$baseUrl/books?page=$page&limit=$limit';
      if (categoryId != null) {
        url += '&category_id=$categoryId';
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final dynamic decoded = json.decode(utf8.decode(response.bodyBytes));
        List<dynamic> data = decoded is List ? decoded : decoded['data'] ?? [];
        return data.map((json) => Book.fromJson(json)).toList();
      }
      throw Exception('載入書籍失敗');
    } catch (e) {
      print('取得書籍發生錯誤: $e');
      return [];
    }
  }
}