import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LegalDraft {
  final String title;
  final String content;
  final bool raw;
  final String? baseUpdatedAt;
  final DateTime savedAt;

  const LegalDraft({
    required this.title,
    required this.content,
    required this.raw,
    required this.baseUpdatedAt,
    required this.savedAt,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'content': content,
        'raw': raw,
        'base_updated_at': baseUpdatedAt,
        'saved_at': savedAt.toIso8601String(),
      };

  static LegalDraft? fromJson(Object? json) {
    if (json is! Map) return null;
    final savedAt = DateTime.tryParse(json['saved_at']?.toString() ?? '');
    if (savedAt == null) return null;
    return LegalDraft(
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      raw: json['raw'] == true,
      baseUpdatedAt: json['base_updated_at']?.toString(),
      savedAt: savedAt,
    );
  }
}

abstract final class LegalDraftStore {
  static String _key(String docKey) => 'admin_legal_draft_$docKey';

  static Future<LegalDraft?> load(String docKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(docKey));
      return raw == null ? null : LegalDraft.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(String docKey, LegalDraft draft) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key(docKey), jsonEncode(draft.toJson()));
    } catch (_) {}
  }

  static Future<void> clear(String docKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key(docKey));
    } catch (_) {}
  }

  static Future<Set<String>> keysWithDrafts(Iterable<String> docKeys) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {for (final key in docKeys) if (prefs.containsKey(_key(key))) key};
    } catch (_) {
      return {};
    }
  }
}
