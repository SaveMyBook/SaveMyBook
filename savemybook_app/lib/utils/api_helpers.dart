import '../i18n/strings.dart';

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

String formatDate(DateTime? dt) {
  if (dt == null) return '';
  return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
}

String formatDateTime(DateTime? dt) {
  if (dt == null) return '';
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
