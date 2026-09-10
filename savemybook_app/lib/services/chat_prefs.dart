import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:shared_preferences/shared_preferences.dart';

/// 靜音只影響這台裝置要不要跳提示，資料庫沒有這個欄位，
/// 所以存在本機就好，不用為了它動 schema。
class ChatPrefs {
  static const _key = 'muted_chat_rooms';

  static final ValueNotifier<Set<int>> mutedRoomIds = ValueNotifier<Set<int>>(<int>{});

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const [];
    mutedRoomIds.value = raw.map(int.tryParse).whereType<int>().toSet();
  }

  static bool isMuted(int roomId) => mutedRoomIds.value.contains(roomId);

  /// 回傳切換後的狀態（true = 現在是靜音）。
  static Future<bool> toggle(int roomId) async {
    final next = Set<int>.from(mutedRoomIds.value);
    final muted = !next.contains(roomId);
    muted ? next.add(roomId) : next.remove(roomId);
    mutedRoomIds.value = next;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, next.map((e) => '$e').toList());
    return muted;
  }

  static Future<void> forget(int roomId) async {
    if (!mutedRoomIds.value.contains(roomId)) return;
    final next = Set<int>.from(mutedRoomIds.value)..remove(roomId);
    mutedRoomIds.value = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, next.map((e) => '$e').toList());
  }
}
