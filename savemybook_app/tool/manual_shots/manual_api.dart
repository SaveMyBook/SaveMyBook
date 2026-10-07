// 第 12 章使用手冊截圖的資料：書籍、照片、分類、常見問題、公告、法律文件取自正式 API 的公開端點（real_data.g.dart），
// 需要登入才看得到的資料（訂單、聊天、錢包、通知、後台等）由各節測試以 [ManualApi.on] 用這些真實書籍與使用者組合。

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'real_data.g.dart';

final Map<String, dynamic> _real = jsonDecode(realDataJson) as Map<String, dynamic>;

/// 截圖中的登入者：原實機截圖的帳號暱稱。
const meId = 30;
const meName = 'es';
const meEmail = 'es@savemybook.today';

/// 管理員（後台截圖使用）。
const adminId = 7;

final List<Map<String, dynamic>> realBooks = [for (final b in _real['books'] as List) Map<String, dynamic>.from(b as Map)];
final List<Map<String, dynamic>> realCategories = [for (final c in _real['categories'] as List) Map<String, dynamic>.from(c as Map)];
final List<Map<String, dynamic>> realFaqs = [for (final f in _real['faqs'] as List) Map<String, dynamic>.from(f as Map)];
final List<Map<String, dynamic>> realAnnouncements = [
  for (final a in _real['announcements'] as List) Map<String, dynamic>.from(a as Map),
];
final List<Map<String, dynamic>> realLegalDocs = [for (final d in _real['legal'] as List) Map<String, dynamic>.from(d as Map)];

/// 使用者：書籍賣家（KJ、Gary、Shelly、yx、雪喵）加上登入者。頭像為賣家在正式站上傳的照片。
final Map<int, ({String nickname, String? avatar})> realUsers = () {
  final map = <int, ({String nickname, String? avatar})>{};
  for (final b in realBooks) {
    final u = b['users'] as Map;
    map[u['user_id'] as int] = (nickname: u['nickname'] as String, avatar: u['avatar_url'] as String?);
  }
  map[meId] = (nickname: meName, avatar: null);
  return map;
}();

Map<String, dynamic> userJson(int id, {Map<String, dynamic> extra = const {}}) => {
  'user_id': id,
  'nickname': realUsers[id]?.nickname ?? meName,
  'email': id == meId ? meEmail : '${(realUsers[id]?.nickname ?? 'member').toLowerCase()}@savemybook.today',
  'avatar_url': realUsers[id]?.avatar,
  'role': id == adminId ? 'admin' : 'buyer_seller',
  'bio': '',
  'phone': '',
  'created_at': ago(days: 180),
  ...extra,
};

Map<String, dynamic> bookJson(int id, {Map<String, dynamic> extra = const {}}) {
  final b = realBooks.firstWhere((b) => b['book_id'] == id, orElse: () => throw ArgumentError('找不到書籍 $id'));
  return {...b, ...extra};
}

List<int> get bookIds => [for (final b in realBooks) b['book_id'] as int];

List<int> booksOfSeller(int sellerId) => [
  for (final b in realBooks)
    if (b['seller_id'] == sellerId) b['book_id'] as int,
];

/// 書籍的封面照片路徑（/uploads/books/...）。
String coverOf(int bookId) {
  final images = (bookJson(bookId)['book_images'] as List).cast<Map>();
  final cover = images.firstWhere((i) => i['image_type'] == 'cover', orElse: () => images.first);
  return cover['image_url'] as String;
}

/// 真實書櫃據點（取自書籍所在書櫃）。
final List<Map<String, dynamic>> realCabinets = () {
  final seen = <int, Map<String, dynamic>>{};
  for (final b in realBooks) {
    final c = b['smart_cabinets'];
    if (c is Map) seen.putIfAbsent(c['cabinet_id'] as int, () => Map<String, dynamic>.from(c));
  }
  return seen.values.toList();
}();

Map<String, dynamic> cabinetJson(int id, {Map<String, dynamic> extra = const {}}) =>
    {...realCabinets.firstWhere((c) => c['cabinet_id'] == id), ...extra};

/// 所有要預先放進圖片快取的照片路徑（書籍照片與頭像）。
List<String> get realImagePaths => [
  for (final b in realBooks)
    for (final i in (b['book_images'] as List).cast<Map>()) i['image_url'] as String,
  for (final u in realUsers.values)
    if (u.avatar != null) u.avatar!,
];

final _now = DateTime.now();

String ago({int days = 0, int hours = 0, int minutes = 0}) =>
    _now.subtract(Duration(days: days, hours: hours, minutes: minutes)).toUtc().toIso8601String();

String todayAt(int hour, int minute, {int daysAgo = 0}) {
  final d = _now.subtract(Duration(days: daysAgo));
  return DateTime(d.year, d.month, d.day, hour, minute).toUtc().toIso8601String();
}

Map<String, dynamic> ok(Object? data, {Map<String, dynamic>? pagination}) => {
  'success': true,
  'message': 'OK',
  'data': data,
  if (data is List) 'pagination': pagination ?? {'total': data.length, 'page': 1, 'limit': 20, 'total_pages': 1},
};

typedef ApiRequest = ({String method, String path, Map<String, String> query, String body});

/// 回傳 null 表示不處理，交給下一個；回傳完整的回應本體（含 success）或以 [ok] 包裝的資料。
typedef ApiHandler = Map<String, dynamic>? Function(ApiRequest request);

class ManualApi {
  static final List<ApiHandler> _handlers = [];

  /// 加入本張截圖專用的回應（後加入的優先）；每張截圖開始前會清空。
  static void on(String method, String pathPattern, Object? Function(ApiRequest request) data) {
    final pattern = RegExp('^${pathPattern.replaceAllMapped(RegExp(r':\w+'), (_) => r'[^/]+')}\$');
    _handlers.insert(0, (r) => r.method == method && pattern.hasMatch(r.path) ? _wrap(data(r)) : null);
  }

  /// 直接加入處理函式（需要自行比對路徑時使用）。
  static void handle(ApiHandler handler) => _handlers.insert(0, handler);

  static void reset() => _handlers.clear();

  static final List<ApiRequest> log = [];

  static Map<String, dynamic>? _wrap(Object? data) =>
      data is Map<String, dynamic> && data.containsKey('success') ? data : ok(data);

  static MockClient client() => MockClient((request) async {
    final r = (
      method: request.method,
      path: request.url.path.replaceFirst('/api', ''),
      query: request.url.queryParameters,
      body: utf8.decode(request.bodyBytes, allowMalformed: true),
    );
    log.add(r);
    Map<String, dynamic>? body;
    for (final h in _handlers) {
      body = h(r);
      if (body != null) break;
    }
    body ??= _base(r);
    return http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json; charset=utf-8'});
  });

  static Map<String, dynamic> _base(ApiRequest r) {
    final p = r.path;
    Object? data;
    switch ('${r.method} $p') {
      case 'GET /status':
        data = {'api_revision': 99, 'commit': 'manual'};
      case 'GET /auth/me':
        data = userJson(meId);
      case 'GET /users/me/stats':
        data = {'balance': 1280, 'book_count': 0, 'favorite_count': 3, 'unread_notification_count': 0, 'cart_count': 0};
      case 'GET /users/me/legal-consents/pending':
        data = <Object>[];
      case 'GET /ai/status':
        data = {
          'support': true,
          'listing_assist': true,
          'recommend': true,
          'book_chat': true,
          'web_search': true,
          'consented': true,
          'providers_in_use': ['OpenAI'],
          'embedding_provider': 'OpenAI',
        };
      case 'GET /categories':
        data = realCategories;
      case 'GET /books':
        data = _searchBooks(r.query);
      case 'GET /support/faqs':
        data = realFaqs;
      case 'GET /support/legal':
        data = realLegalDocs;
      case 'GET /announcements':
        data = realAnnouncements;
      case 'GET /cabinets':
        data = realCabinets;
      case 'GET /chat/unread-count':
        data = {'unread_count': 0};
      case 'GET /notifications/unread-count':
        data = {'unread_count': 0, 'by_category': {'trade': 0, 'chat': 0, 'account': 0, 'service': 0, 'promotion': 0}};
      default:
        final detail = RegExp(r'^/books/(\d+)$').firstMatch(p);
        final similar = RegExp(r'^/books/(\d+)/similar$').firstMatch(p);
        if (r.method == 'GET' && detail != null) {
          data = bookJson(int.parse(detail.group(1)!));
        } else if (r.method == 'GET' && similar != null) {
          final id = int.parse(similar.group(1)!);
          final category = bookJson(id)['category_id'];
          data = [
            for (final b in realBooks)
              if (b['book_id'] != id && b['category_id'] == category) b,
          ].take(6).toList();
        } else {
          data = r.method == 'GET' ? <Object>[] : <String, Object>{};
        }
    }
    return ok(data);
  }

  static List<Map<String, dynamic>> _searchBooks(Map<String, String> q) {
    var list = [...realBooks];
    final categories = q['category_ids']?.split(',').where((s) => s.isNotEmpty).map(int.parse).toSet();
    if (categories != null && categories.isNotEmpty) list = list.where((b) => categories.contains(b['category_id'])).toList();
    final keyword = q['keyword']?.trim().toLowerCase();
    if (keyword != null && keyword.isNotEmpty) {
      list = list
          .where((b) => '${b['title']} ${b['author']} ${b['isbn']} ${b['publisher']}'.toLowerCase().contains(keyword))
          .toList();
    }
    double price(Map b) => double.tryParse('${b['price']}') ?? 0;
    switch (q['sort']) {
      case 'price_asc':
        list.sort((a, b) => price(a).compareTo(price(b)));
      case 'price_desc':
        list.sort((a, b) => price(b).compareTo(price(a)));
      case 'popular':
        list.sort((a, b) => (b['view_count'] as int).compareTo(a['view_count'] as int));
      default:
        list.sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));
    }
    return list;
  }
}
