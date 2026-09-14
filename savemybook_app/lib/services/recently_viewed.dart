import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/book.dart';
import '../i18n/strings.dart';
import 'api_service.dart';

class RecentlyViewed {
  const RecentlyViewed._();

  static const int _max = 20;

  static final ValueNotifier<List<Book>> books = ValueNotifier<List<Book>>(const []);
  static String? _loadedKey;

  static String get _key => 'recently_viewed_v1_${ApiService.currentUser?.userId ?? 0}';

  static Future<void> load() async {
    final key = _key;
    if (_loadedKey == key) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(key) ?? const <String>[];
      final parsed = <Book>[];
      for (final entry in raw) {
        try {
          final decoded = jsonDecode(entry);
          if (decoded is Map) parsed.add(Book.fromJson(Map<String, dynamic>.from(decoded)));
        } catch (_) {}
      }
      books.value = List.unmodifiable(parsed.where((b) => b.bookId > 0));
      _loadedKey = key;
    } catch (_) {}
  }

  static Future<void> add(Book book) async {
    if (book.bookId <= 0) return;
    await load();
    final next = [book, ...books.value.where((b) => b.bookId != book.bookId)].take(_max).toList();
    await _write(next);
  }

  static Future<void> remove(int bookId) async {
    await load();
    await _write(books.value.where((b) => b.bookId != bookId).toList());
  }

  static Future<void> clear() => _write(const []);

  static Future<void> restore(List<Book> previous) => _write(previous.take(_max).toList());

  static Future<void> _write(List<Book> next) async {
    final key = _key;
    books.value = List.unmodifiable(next);
    _loadedKey = key;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(key, next.map((b) => jsonEncode(_snapshot(b))).toList());
    } catch (_) {}
  }

  static Map<String, dynamic> _snapshot(Book b) => {
        'book_id': b.bookId,
        'title': b.title,
        if (b.author != S.unknownAuthor) 'author': b.author,
        if (b.publisher != S.unknownPublisher) 'publisher': b.publisher,
        if (b.isbn != S.noIsbn) 'isbn': b.isbn,
        if (b.description != S.noDescriptionYet) 'description': b.description,
        'price': b.price,
        'condition_level': b.conditionLevel,
        'status': b.status,
        'seller_id': b.sellerId,
        'category_id': b.categoryId,
        'cabinet_id': b.cabinetId,
        'book_images': [
          for (final image in b.images.isNotEmpty ? b.images : const <BookImage>[])
            {'image_id': image.imageId, 'image_url': image.url, 'image_type': image.type},
          if (b.images.isEmpty)
            for (final url in b.imageUrls) {'image_url': url},
        ],
        'book_categories': {'category_name': b.categoryName},
        'users': {
          'user_id': b.sellerId,
          'nickname': b.sellerName,
          'avatar_url': b.sellerAvatarUrl,
        },
      };
}
