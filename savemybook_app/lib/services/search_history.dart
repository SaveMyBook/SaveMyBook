import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class SearchHistory {
  const SearchHistory._();

  static const int _max = 15;

  static final ValueNotifier<List<String>> items = ValueNotifier<List<String>>(const []);
  static String? _loadedKey;

  static String get _key => 'search_history_v1_${ApiService.currentUser?.userId ?? 0}';

  static Future<void> load() async {
    final key = _key;
    if (_loadedKey == key) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      items.value = List.unmodifiable(prefs.getStringList(key) ?? const <String>[]);
      _loadedKey = key;
    } catch (_) {}
  }

  static Future<void> add(String keyword) async {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) return;
    await load();
    final next = [trimmed, ...items.value.where((k) => k.toLowerCase() != trimmed.toLowerCase())];
    await _write(next.take(_max).toList());
  }

  static Future<void> remove(String keyword) async {
    await load();
    await _write(items.value.where((k) => k != keyword).toList());
  }

  static Future<void> clear() => _write(const []);

  static Future<void> restore(List<String> keywords) => _write(keywords.take(_max).toList());

  static Future<void> _write(List<String> next) async {
    final key = _key;
    items.value = List.unmodifiable(next);
    _loadedKey = key;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(key, next);
    } catch (_) {}
  }
}
