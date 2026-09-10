/// 後端回傳的圖片路徑可能是相對路徑（例：/uploads/books/xxx.jpg），
/// 統一在這裡補上網域，避免每個 model 各寫一份。
const String kApiHost = 'https://api.savemybook.today';

String? resolveAssetUrl(dynamic raw) {
  if (raw == null) return null;
  final url = raw.toString();
  if (url.isEmpty) return null;
  if (url.startsWith('http')) return url;
  return '$kApiHost$url';
}

double parseDouble(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}

int parseInt(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? 0;
}

DateTime? parseDate(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

/// 2026/03/30
String formatDate(DateTime? dt) {
  if (dt == null) return '';
  return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
}

/// 2026/03/30 14:05
String formatDateTime(DateTime? dt) {
  if (dt == null) return '';
  return '${formatDate(dt)} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

/// 聊天列表用的相對時間
String formatRelative(DateTime? dt) {
  if (dt == null) return '';
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return '剛剛';
  if (diff.inMinutes < 60) return '${diff.inMinutes} 分鐘前';
  if (diff.inHours < 24) return '${diff.inHours} 小時前';
  if (diff.inDays < 7) return '${diff.inDays} 天前';
  return formatDate(dt);
}

/// 09:00~21:00
String formatTimeRange(dynamic open, dynamic close) {
  String pick(dynamic v) {
    if (v == null) return '';
    final dt = DateTime.tryParse(v.toString());
    if (dt != null) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    final text = v.toString();
    return text.length >= 5 ? text.substring(0, 5) : text;
  }

  final o = pick(open);
  final c = pick(close);
  if (o.isEmpty || c.isEmpty) return '';
  return '$o~$c';
}
