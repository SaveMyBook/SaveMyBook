import 'package:flutter/material.dart';

import '../../utils/app_colors.dart';
import '../../i18n/strings.dart';

String _two(int v) => v.toString().padLeft(2, '0');

// created_at 解析出來是 UTC，分日與顯示時刻前一定要先轉成本地時間。
DateTime? chatLocal(DateTime? dt) => dt?.toLocal();

String chatClock(DateTime? dt) {
  final local = chatLocal(dt);
  if (local == null) return '';
  return '${_two(local.hour)}:${_two(local.minute)}';
}

bool chatSameDay(DateTime? a, DateTime? b) {
  final x = chatLocal(a);
  final y = chatLocal(b);
  if (x == null || y == null) return x == y;
  return x.year == y.year && x.month == y.month && x.day == y.day;
}

String chatDayLabel(DateTime dt) {
  final local = dt.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return S.today;
  if (diff == 1) return S.yesterday;
  final month = local.month;
  final date = local.day;
  if (local.year == now.year) return S.p0P12(month, date);
  final year = local.year;
  return S.p1P2P0(year, month, date);
}

String chatDeadline(DateTime dt) {
  final local = dt.toLocal();
  return '${_two(local.month)}/${_two(local.day)} ${_two(local.hour)}:${_two(local.minute)}';
}

String chatDuration(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  return '${s ~/ 60}:${_two(s % 60)}';
}

Color chatMineBubble(AppColors c) => c.isDark ? const Color(0xFF3F5B6A) : AppColors.primary;

Color chatTheirsBubble(AppColors c) => c.isDark ? const Color(0xFF242628) : Colors.white;
