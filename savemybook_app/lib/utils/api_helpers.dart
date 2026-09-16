import '../i18n/strings.dart';

const String kApiHost = 'https://api.savemybook.today';

// API 回傳的檔案路徑可能是絕對網址，也可能是 /uploads/... 相對路徑，
// 而歷史資料還有缺前導斜線、夾帶空白、或被序列化成 "null" 的情況；
// 直接字串相接會拼出 https://api.savemybook.todayuploads/... 這種必然 404 的網址。
String? resolveAssetUrl(dynamic raw) {
  if (raw == null || raw is Map || raw is Iterable) return null;
  final url = raw.toString().trim();
  if (url.isEmpty || url == 'null' || url == 'undefined') return null;
  if (url.startsWith('http://') || url.startsWith('https://') || url.startsWith('data:')) return url;
  if (url.startsWith('//')) return 'https:$url';
  return '$kApiHost/${url.replaceFirst(RegExp(r'^/+'), '')}';
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

// API 回傳的時間是 UTC，顯示前一律轉成裝置時區。
String formatDate(DateTime? value) {
  if (value == null) return '';
  final dt = value.toLocal();
  return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
}

String formatDateTime(DateTime? value) {
  if (value == null) return '';
  final dt = value.toLocal();
  return '${formatDate(dt)} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

String formatRelative(DateTime? dt) {
  if (dt == null) return '';
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return S.justNow;
  if (diff.inMinutes < 60) return S.minAgo(diff.inMinutes);
  if (diff.inHours < 24) return S.hAgo(diff.inHours);
  if (diff.inDays < 7) return S.dAgo(diff.inDays);
  return formatDate(dt);
}

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
