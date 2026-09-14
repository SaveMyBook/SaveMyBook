import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/category.dart';
import '../models/book.dart';
import '../models/user.dart';
import '../models/cart_item.dart';
import '../models/order.dart';
import '../models/app_notification.dart';
import '../models/chat.dart';
import '../models/support.dart';
import '../models/wallet.dart';
import '../models/member_level.dart';
import '../models/admin_models.dart';
import '../utils/api_helpers.dart';
import '../models/security.dart';
import '../i18n/strings.dart';
import 'device_identity.dart';
import 'payment_key_store.dart';

enum _RefreshResult { refreshed, failed, offline }

class VerifyOutcome {
  final String? token;
  final String code;
  final String message;
  final int? remainingAttempts;

  const VerifyOutcome({required this.code, required this.message, this.remainingAttempts}) : token = null;

  const VerifyOutcome.success(String this.token)
      : code = 'OK',
        message = '',
        remainingAttempts = null;

  bool get isSuccess => token != null;
}

class LoginOutcome {
  final bool isSuccess;
  final String code;
  final String message;

  const LoginOutcome({required this.code, required this.message}) : isSuccess = false;

  const LoginOutcome.success()
      : isSuccess = true,
        code = 'OK',
        message = '';

  bool get accountNotFound => code == 'ACCOUNT_NOT_FOUND';
}

class ApiService {
  static const String baseUrl = 'https://api.savemybook.today/api';
  static String? authToken;
  static User? currentUser;

  static void Function(String? reason)? onUnauthorized;

  static Future<void> Function({required bool canReachServer})? onSigningOut;
  static Future<void> Function()? onPasswordChanged;
  static Future<String?> Function(VerificationRequest request)? onVerificationRequired;

  static const String publicWebUrl = 'https://api.savemybook.today';

  static ({String kind, String token})? parseShareLink(String raw) {
    final value = raw.trim();
    final patterns = [
      RegExp(r'^https?://[^/\s]+/([ub])/([0-9a-fA-F]{32})/?(?:[?#].*)?$'),
      RegExp(r'^savemybook://([ub])/([0-9a-fA-F]{32})/?$'),
    ];
    for (final p in patterns) {
      final match = p.firstMatch(value);
      if (match != null) return (kind: match.group(1)!, token: match.group(2)!.toLowerCase());
    }
    return null;
  }

  static final ValueNotifier<int> cartCount = ValueNotifier<int>(0);
  static final ValueNotifier<int> unreadNotificationCount = ValueNotifier<int>(0);
  static final ValueNotifier<int> unreadChatCount = ValueNotifier<int>(0);
  static final ValueNotifier<Set<int>> favoriteBookIds = ValueNotifier<Set<int>>(<int>{});
  static final ValueNotifier<Set<int>> cartBookIds = ValueNotifier<Set<int>>(<int>{});

  static void _setCartCount(int value) {
    cartCount.value = value < 0 ? 0 : value;
  }

  static void _setBadge(ValueNotifier<int> notifier, int value) {
    notifier.value = value < 0 ? 0 : value;
  }

  static void resetGlobalState() {
    cartCount.value = 0;
    unreadNotificationCount.value = 0;
    unreadChatCount.value = 0;
    favoriteBookIds.value = <int>{};
    cartBookIds.value = <int>{};
  }

  static Future<void> _handleUnauthorized({String? reason}) async {
    if (authToken == null) return;
    authToken = null;
    unawaited(onSigningOut?.call(canReachServer: false));
    unawaited(PaymentKeyStore.clear());
    currentUser = null;
    resetGlobalState();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    onUnauthorized?.call(reason);
  }

  static Future<void> _storeToken(String token) async {
    authToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  static Map<String, String> _headers({bool json = false, Map<String, String>? extra}) {
    return {
      'Accept': 'application/json',
      if (json) 'Content-Type': 'application/json',
      if (authToken != null) 'Authorization': 'Bearer $authToken',
      ...?extra,
    };
  }

  static Future<_RefreshResult>? _refreshing;

  static Future<_RefreshResult> _refreshToken() {
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  static Future<_RefreshResult> _doRefresh() async {
    final token = authToken;
    if (token == null) return _RefreshResult.failed;
    try {
      final response = await http
          .post(Uri.parse('$baseUrl/auth/refresh'), headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return _RefreshResult.failed;
      final payload = jsonDecode(utf8.decode(response.bodyBytes));
      final data = payload is Map ? payload['data'] : null;
      final next = data is Map ? data['token'] : null;
      if (next is! String || next.isEmpty) return _RefreshResult.failed;
      if (authToken == token) await _storeToken(next);
      return _RefreshResult.refreshed;
    } catch (_) {
      return _RefreshResult.offline;
    }
  }

  static const _signOutCodes = {
    'ACCOUNT_BLACKLISTED',
    'ACCOUNT_INACTIVE',
    'TOKEN_REVOKED',
    'ACCOUNT_NOT_FOUND',
    'SESSION_REVOKED',
  };

  Future<Map<String, dynamic>?> _interpret(
    int status,
    List<int> bytes, {
    required bool sentWithToken,
    required Set<String> handled,
    required Future<Map<String, dynamic>?> Function(Map<String, String> extraHeaders, Set<String> handled) retry,
  }) async {
    Map<String, dynamic> payload = {};
    if (bytes.isNotEmpty) {
      try {
        final decoded = jsonDecode(utf8.decode(bytes));
        if (decoded is Map<String, dynamic>) {
          payload = decoded;
        } else if (status >= 200 && status < 300) {
          return null;
        }
      } catch (_) {
        if (status >= 200 && status < 300) return null;
      }
    }
    final code = payload['code'] as String?;

    if (status == 401 && sentWithToken) {
      await _handleUnauthorized(reason: _signOutCodes.contains(code) ? payload['message'] as String? : null);
      return null;
    }

    if (status == 403 && code == 'TOKEN_EXPIRED' && sentWithToken && !handled.contains('refresh')) {
      final result = await _refreshToken();
      if (result == _RefreshResult.refreshed) return retry(const {}, {...handled, 'refresh'});
      if (result == _RefreshResult.offline) return {'success': false, 'code': 'NETWORK', 'message': S.couldNotReachServer};
      await _handleUnauthorized(reason: S.sessionExpiredPleaseSignAgain);
      return null;
    }

    if (status == 403 && code == 'VERIFICATION_REQUIRED' && !handled.contains('verify')) {
      final handler = onVerificationRequired;
      final info = payload['verification'];
      if (handler != null && info is Map) {
        final request = VerificationRequest(
          scope: info['scope'] as String? ?? 'sensitive',
          methods: (info['methods'] as List?)?.map((e) => '$e').toList() ?? const ['password'],
          message: payload['message'] as String? ?? '',
        );
        final token = await handler(request);
        if (token == null) {
          return {'success': false, 'code': 'VERIFICATION_CANCELLED', 'message': S.verificationCancelled};
        }
        return retry({'X-Verify-Token': token}, {...handled, 'verify'});
      }
    }

    if (status >= 200 && status < 300) return payload;

    return {
      ...payload,
      'success': false,
      'status': status,
      'message': code == 'ROUTE_NOT_FOUND'
          ? S.serverNotBeenUpdatedSupportFeature
          : payload['message'] ?? (status == 503 ? S.serviceTemporarilyUnavailableTryAgainLater : S.requestFailed2(status)),
    };
  }

  Future<Map<String, dynamic>?> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
    Map<String, String>? extraHeaders,
    Set<String> handled = const {},
  }) async {
    try {
      var uri = Uri.parse('$baseUrl$path');
      if (query != null && query.isNotEmpty) {
        uri = uri.replace(queryParameters: query);
      }

      final sentWithToken = authToken != null;
      final headers = _headers(json: body != null, extra: extraHeaders);
      final encoded = body == null ? null : jsonEncode(body);

      late http.Response response;
      switch (method) {
        case 'POST':
          response = await http.post(uri, headers: headers, body: encoded);
          break;
        case 'PUT':
          response = await http.put(uri, headers: headers, body: encoded);
          break;
        case 'PATCH':
          response = await http.patch(uri, headers: headers, body: encoded);
          break;
        case 'DELETE':
          response = await http.delete(uri, headers: headers, body: encoded);
          break;
        case 'GET':
        default:
          response = await http.get(uri, headers: headers);
          break;
      }

      return await _interpret(
        response.statusCode,
        response.bodyBytes,
        sentWithToken: sentWithToken,
        handled: handled,
        retry: (extra, nextHandled) => _send(method, path,
            query: query, body: body, extraHeaders: {...?extraHeaders, ...extra}, handled: nextHandled),
      );
    } catch (e) {
      return {'success': false, 'code': 'NETWORK', 'message': S.couldNotReachServer};
    }
  }

  Future<Map<String, dynamic>?> _sendMultipart(
    String path,
    List<(String field, String filePath)> files, {
    Map<String, String>? fields,
    Set<String> handled = const {},
  }) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'));
      final sentWithToken = authToken != null;
      request.headers.addAll(_headers());
      if (fields != null) request.fields.addAll(fields);
      for (final (field, filePath) in files) {
        request.files.add(await http.MultipartFile.fromPath(field, filePath));
      }
      final streamed = await request.send();
      final bytes = await streamed.stream.toBytes();
      return await _interpret(
        streamed.statusCode,
        bytes,
        sentWithToken: sentWithToken,
        handled: handled,
        retry: (extra, nextHandled) => _sendMultipart(path, files, fields: fields, handled: nextHandled),
      );
    } catch (_) {
      return {'success': false, 'code': 'NETWORK', 'message': S.couldNotReachServer};
    }
  }

  List<T> _mapList<T>(Map<String, dynamic>? res, T Function(Map<String, dynamic>) build) {
    if (res == null || res['success'] != true) return [];
    final raw = res['data'];
    if (raw is! List) return [];
    final result = <T>[];
    for (final item in raw) {
      if (item is Map) {
        try {
          result.add(build(Map<String, dynamic>.from(item)));
        } catch (_) {}
      }
    }
    return result;
  }

  Future<LoginOutcome> login(String email, String password) async {
    final device = await DeviceIdentity.describe();
    final res = await _send('POST', '/auth/login', body: {'email': email, 'password': password, ...device});

    if (res == null) {
      return LoginOutcome(code: 'NETWORK', message: S.couldNotReachServerCheckConnection);
    }

    if (res['success'] != true) {
      return LoginOutcome(
        code: res['code'] as String? ?? 'UNKNOWN',
        message: res['message'] as String? ?? S.signFailed,
      );
    }

    final token = res['data']?['token'] as String?;
    if (token == null) {
      return LoginOutcome(code: 'UNKNOWN', message: S.signFailedPleaseTryAgain);
    }

    await PaymentKeyStore.clear();
    await _storeToken(token);

    await fetchCurrentUser();
    return const LoginOutcome.success();
  }

  Future<String?> register(String email, String password, String nickname) async {
    final res = await _send('POST', '/users',
        body: {'email': email, 'password': password, 'nickname': nickname, 'accept_legal': true});
    if (res == null) return S.couldNotReachServerCheckConnection;
    return res['success'] == true ? null : (res['message'] as String? ?? S.signUpFailed);
  }

  Future<void> logout() async {
    // 必須在清掉登入 Token 之前通知伺服器，否則無法取消這台的推播。
    await onSigningOut?.call(canReachServer: true);
    if (authToken != null) {
      await _send('POST', '/auth/logout').timeout(const Duration(seconds: 4), onTimeout: () => null);
    }
    await PaymentKeyStore.clear();
    authToken = null;
    currentUser = null;
    resetGlobalState();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  Future<void> fetchCurrentUser() async {
    if (authToken == null) return;
    final res = await _send('GET', '/auth/me');
    if (res != null && res['success'] == true && res['data'] is Map) {
      currentUser = User.fromJson(Map<String, dynamic>.from(res['data']));
    }
  }

  Future<List<Category>> fetchCategories() async {
    final res = await _send('GET', '/categories', query: {'flat': 'true'});
    return _mapList(res, Category.fromJson);
  }

  Future<List<Book>> fetchBooks({
    int page = 1,
    int limit = 20,
    Set<int>? categoryIds,
    String? keyword,
    String? sort,
  }) async {
    final query = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (categoryIds != null && categoryIds.isNotEmpty) {
      query['category_ids'] = categoryIds.join(',');
    }
    if (keyword != null && keyword.isNotEmpty) {
      query['keyword'] = keyword;
    }
    if (sort != null) {
      const allowed = {'popular', 'price_asc', 'price_desc', 'newest'};
      query['sort'] = allowed.contains(sort) ? sort : 'newest';
    }

    final res = await _send('GET', '/books', query: query);
    return _mapList(res, Book.fromJson);
  }

  Future<List<Book>> fetchSellerBooks(int sellerId) async {
    final res = await _send('GET', '/books',
        query: {'seller_id': sellerId.toString(), 'status': 'on_sale', 'limit': '100'});
    return _mapList(res, Book.fromJson);
  }

  Future<Book?> fetchBookDetail(int bookId) async {
    final res = await _send('GET', '/books/$bookId');
    if (res == null || res['success'] != true || res['data'] is! Map) return null;
    return Book.fromJson(Map<String, dynamic>.from(res['data']));
  }

  Future<List<Book>> fetchMyBooks({String status = 'all'}) async {
    final userId = currentUser?.userId;
    if (userId == null) return [];
    final res = await _send('GET', '/books',
        query: {'seller_id': userId.toString(), 'status': status, 'limit': '100'});
    final books = _mapList(res, Book.fromJson);

    return books.where((b) => b.sellerId == userId).toList();
  }

  Future<Map<String, dynamic>?> fetchBookByIsbn(String isbn) async {
    if (authToken == null) return null;
    final res = await _send('GET', '/books/isbn/$isbn');
    if (res == null || res['success'] != true) return null;
    return res['data'] as Map<String, dynamic>?;
  }

  Future<bool> updateBook(int bookId, Map<String, dynamic> data) async {
    final res = await _send('PUT', '/books/$bookId', body: data);
    return res != null && res['success'] == true;
  }

  Future<bool> uploadBookImages(int bookId, List<String> filePaths, {List<String>? types}) async {
    if (filePaths.isEmpty) return true;
    final res = await _sendMultipart(
      '/books/$bookId/images',
      [for (final path in filePaths) ('images', path)],
      fields: types == null ? null : {'image_types': types.join(',')},
    );
    return res != null && res['success'] == true;
  }

  Future<String?> createBook(Map<String, String> fields, List<(String field, String filePath)> files) async {
    final res = await _sendMultipart('/books', files, fields: fields);
    if (res == null) return S.pleaseSignFirst;
    if (res['success'] == true) return null;
    return res['message'] as String? ?? S.unknownError;
  }

  Future<bool> deleteBookImage(int bookId, int imageId) async {
    final res = await _send('DELETE', '/books/$bookId/images/$imageId');
    return res != null && res['success'] == true;
  }

  Future<bool> removeBook(int bookId) async {
    final res = await _send('DELETE', '/books/$bookId');
    return res != null && res['success'] == true;
  }

  Future<String?> relistBook(int bookId) async {
    final res = await _send('PUT', '/books/$bookId', body: {'status': 'on_sale'});
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.couldNotRelist);
  }

  Future<(String? url, String? error)> fetchBookShareLink(int bookId) async {
    final res = await _send('GET', '/books/$bookId/share-link');
    if (res == null) return (null, S.couldNotReachServer);
    if (res['success'] != true) {
      return (null, res['message'] as String? ?? S.loadFailed);
    }
    return (res['data']?['url'] as String?, null);
  }

  Future<List<Book>> fetchFavorites() async {
    final res = await _send('GET', '/favorites');
    final books = _mapList(res, Book.fromJson);
    favoriteBookIds.value = books.map((b) => b.bookId).toSet();
    return books;
  }

  Future<Set<int>> fetchFavoriteIds() async {
    final res = await _send('GET', '/favorites/ids');
    if (res == null || res['success'] != true || res['data'] is! List) return {};
    final ids = (res['data'] as List).map((e) => int.tryParse(e.toString()) ?? 0).toSet();
    favoriteBookIds.value = ids;
    return ids;
  }

  static void _setFavorite(int bookId, bool value) {
    final next = Set<int>.from(favoriteBookIds.value);
    value ? next.add(bookId) : next.remove(bookId);
    favoriteBookIds.value = next;
  }

  Future<bool> addFavorite(int bookId) async {
    final res = await _send('POST', '/favorites', body: {'book_id': bookId});
    final ok = res != null && res['success'] == true;
    if (ok) _setFavorite(bookId, true);
    return ok;
  }

  Future<bool> removeFavorite(int bookId) async {
    final res = await _send('DELETE', '/favorites/$bookId');
    final ok = res != null && res['success'] == true;
    if (ok) _setFavorite(bookId, false);
    return ok;
  }

  Future<String?> toggleFavorite(int bookId) async {
    if (authToken == null) return S.pleaseSignFirst;
    final wasFavorite = favoriteBookIds.value.contains(bookId);
    _setFavorite(bookId, !wasFavorite);

    final ok = wasFavorite ? await removeFavorite(bookId) : await addFavorite(bookId);
    if (!ok) {
      _setFavorite(bookId, wasFavorite);
      return wasFavorite ? S.couldNotRemoveFromSaved : S.couldNotSave;
    }
    return null;
  }

  Future<List<CartItem>> fetchCart() async {
    final res = await _send('GET', '/cart');
    final items = _mapList(res, CartItem.fromJson);
    if (res != null && res['success'] == true) {
      _setCartCount(items.length);
      cartBookIds.value = items.map((i) => i.book.bookId).toSet();
    }
    return items;
  }

  Future<void> refreshCartCount() async {
    if (authToken == null) {
      _setCartCount(0);
      return;
    }
    final stats = await fetchUserStats();
    _setCartCount(stats.cartCount);
  }

  Future<String?> addToCart(int bookId, {int quantity = 1}) async {
    final res = await _send('POST', '/cart', body: {'book_id': bookId, 'quantity': quantity});
    if (res == null) return S.pleaseSignFirst;
    if (res['success'] != true) return res['message'] as String? ?? S.couldNotAddCart;
    if (!cartBookIds.value.contains(bookId)) {
      cartBookIds.value = {...cartBookIds.value, bookId};
      if (res['already_in_cart'] != true) _setCartCount(cartCount.value + 1);
    }
    return null;
  }

  Future<Set<int>> fetchCartBookIds() async {
    final res = await _send('GET', '/cart/book-ids');
    if (res == null || res['success'] != true || res['data'] is! List) return cartBookIds.value;
    final ids = (res['data'] as List).map(parseInt).where((id) => id > 0).toSet();
    cartBookIds.value = ids;
    _setCartCount(ids.length);
    return ids;
  }

  Future<bool> updateCartQuantity(int cartId, int quantity) async {
    final res = await _send('PATCH', '/cart/$cartId', body: {'quantity': quantity});
    return res != null && res['success'] == true;
  }

  Future<bool> removeCartItem(int cartId, {int? bookId}) async {
    final res = await _send('DELETE', '/cart/$cartId');
    final ok = res != null && res['success'] == true;
    if (ok) {
      _setCartCount(cartCount.value - 1);
      if (bookId != null) cartBookIds.value = {...cartBookIds.value}..remove(bookId);
    }
    return ok;
  }

  Future<List<Order>> fetchOrders({required String role, required String tab}) async {
    final res = await _send('GET', '/orders', query: {'role': role, 'tab': tab, 'limit': '50'});
    return _mapList(res, Order.fromJson);
  }

  Future<Order?> fetchOrderDetail(int orderId) async {
    final res = await _send('GET', '/orders/$orderId');
    if (res == null || res['success'] != true || res['data'] is! Map) return null;
    return Order.fromJson(Map<String, dynamic>.from(res['data']));
  }

  Future<String?> checkout(List<int> cartIds) async {
    final res = await _send('POST', '/orders/checkout', body: {'cart_ids': cartIds});
    if (res == null) return S.pleaseSignFirst;
    if (res['success'] != true) {
      return res['code'] == 'VERIFICATION_CANCELLED' ? '' : (res['message'] as String? ?? S.checkoutFailed);
    }
    unawaited(fetchCartBookIds());
    return null;
  }

  Future<String?> cancelOrder(int orderId, {String? reason}) async {
    final res = await _send('PATCH', '/orders/$orderId/cancel', body: {'reason': reason});
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.couldNotCancelOrder);
  }

  Future<String?> updateOrderStatus(int orderId, String status) async {
    final res = await _send('PATCH', '/orders/$orderId/status', body: {'status': status});
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.couldNotUpdateOrder);
  }

  Future<List<AppNotification>> fetchNotifications() async {
    final res = await _send('GET', '/notifications', query: {'limit': '50'});
    if (res != null && res['unread_count'] != null) {
      _setBadge(unreadNotificationCount, int.tryParse('${res['unread_count']}') ?? 0);
    }
    return _mapList(res, AppNotification.fromJson);
  }

  Future<int> fetchUnreadNotificationCount() async {
    final res = await _send('GET', '/notifications/unread-count');
    if (res == null || res['success'] != true) return 0;
    final count = int.tryParse('${res['data']?['unread_count']}') ?? 0;
    _setBadge(unreadNotificationCount, count);
    return count;
  }

  Future<bool> deleteChatRoom(int roomId) async {
    final res = await _send('DELETE', '/chat/rooms/$roomId');
    return res != null && res['success'] == true;
  }

  Future<bool> markAllChatsRead() async {
    final res = await _send('PATCH', '/chat/read-all');
    final ok = res != null && res['success'] == true;
    if (ok) _setBadge(unreadChatCount, 0);
    return ok;
  }

  Future<int> fetchUnreadChatCount() async {
    final res = await _send('GET', '/chat/unread-count');
    if (res == null || res['success'] != true) return 0;
    final count = int.tryParse('${res['data']?['unread_count']}') ?? 0;
    _setBadge(unreadChatCount, count);
    return count;
  }

  Future<void> refreshBadges() async {
    if (authToken == null) {
      resetGlobalState();
      return;
    }
    await Future.wait([
      fetchCartBookIds(),
      fetchUnreadNotificationCount(),
      fetchUnreadChatCount(),
      fetchFavoriteIds(),
    ]);
  }

  Future<bool> markNotificationRead(int notificationId) async {
    final res = await _send('PATCH', '/notifications/$notificationId/read');
    final ok = res != null && res['success'] == true;
    if (ok) _setBadge(unreadNotificationCount, unreadNotificationCount.value - 1);
    return ok;
  }

  Future<bool> markAllNotificationsRead() async {
    final res = await _send('PATCH', '/notifications/read-all');
    final ok = res != null && res['success'] == true;
    if (ok) _setBadge(unreadNotificationCount, 0);
    return ok;
  }

  Future<bool> clearAllNotifications() async {
    final res = await _send('DELETE', '/notifications/all');
    final ok = res != null && res['success'] == true;
    if (ok) _setBadge(unreadNotificationCount, 0);
    return ok;
  }

  Future<bool> deleteNotification(int notificationId) async {
    final res = await _send('DELETE', '/notifications/$notificationId');
    return res != null && res['success'] == true;
  }

  Future<List<ChatRoom>> fetchChatRooms() async {
    final res = await _send('GET', '/chat/rooms');
    final rooms = _mapList(res, ChatRoom.fromJson);
    _setBadge(unreadChatCount, rooms.fold(0, (sum, r) => sum + r.unreadCount));
    return rooms;
  }

  Future<int?> openChatRoom({required int userId, int? bookId}) async {
    final res = await _send('POST', '/chat/rooms', body: {'user_id': userId, 'book_id': bookId});
    if (res == null || res['success'] != true) return null;
    return int.tryParse('${res['data']?['room_id']}');
  }

  Future<ChatFetchResult> fetchChatMessages(int roomId, {int? afterId, int? beforeId, int limit = 50, bool markRead = true}) async {
    final res = await _send('GET', '/chat/rooms/$roomId/messages', query: {
      'limit': '$limit',
      if (!markRead) 'mark_read': 'false',
      if (afterId != null) 'after_id': '$afterId',
      if (beforeId != null) 'before_id': '$beforeId',
    });
    final messages = _mapList(res, ChatMessage.fromJson);
    final partner = ChatPartner.fromJson(
      res?['partner'] is Map ? Map<String, dynamic>.from(res!['partner']) : null,
    );
    final meta = res?['meta'] is Map ? Map<String, dynamic>.from(res!['meta']) : const <String, dynamic>{};
    final reservations = <int, ChatReservation>{};
    for (final item in (meta['reservations'] as List? ?? const [])) {
      if (item is! Map) continue;
      final reservation = ChatReservation.fromJson(Map<String, dynamic>.from(item));
      reservations[reservation.reservationId] = reservation;
    }
    return ChatFetchResult(
      messages: messages,
      partner: partner,
      readUpto: parseInt(meta['read_upto']),
      partnerTyping: meta['partner_typing'] == true,
      recalledIds: (meta['recalled_ids'] as List? ?? const []).map(parseInt).toList(),
      hasMore: meta['has_more'] == true,
      reservations: reservations,
      ok: res != null && res['success'] == true,
      error: res == null || res['success'] == true ? null : res['message'] as String?,
      code: res?['code'] as String?,
      status: res?['status'] is int ? res!['status'] as int : null,
    );
  }

  Future<(ChatMessage?, String?)> sendChatMessage(int roomId, String content, {String type = 'text', int? durationSeconds}) async {
    final res = await _send('POST', '/chat/rooms/$roomId/messages', body: {
      'content': content,
      'message_type': type,
      'duration': ?durationSeconds,
    });
    if (res == null || res['success'] != true || res['data'] is! Map) {
      return (null, res?['message'] as String? ?? S.messageCouldNotSent);
    }
    return (ChatMessage.fromJson(Map<String, dynamic>.from(res['data'])), null);
  }

  Future<(String?, String?)> uploadChatImage(String filePath) async {
    final res = await _sendMultipart('/uploads/chat-image', [('file', filePath)]);
    final url = res?['data'] is Map ? res!['data']['url'] as String? : null;
    return url == null ? (null, res?['message'] as String? ?? S.uploadFailedTryAgainLater) : (url, null);
  }

  Future<(String?, String?)> uploadVoice(String filePath) async {
    final res = await _sendMultipart('/uploads/voice', [('file', filePath)]);
    final url = res?['data'] is Map ? res!['data']['url'] as String? : null;
    return url == null ? (null, res?['message'] as String? ?? S.uploadFailedTryAgainLater) : (url, null);
  }

  Future<void> sendTyping(int roomId, {bool typing = true}) async {
    await _send('POST', '/chat/rooms/$roomId/typing', body: {'typing': typing});
  }

  Future<(ChatMessage?, String?)> recallChatMessage(int roomId, int messageId) async {
    final res = await _send('POST', '/chat/rooms/$roomId/messages/$messageId/recall');
    if (res == null || res['success'] != true || res['data'] is! Map) {
      return (null, res?['message'] as String? ?? S.actionFailed);
    }
    return (ChatMessage.fromJson(Map<String, dynamic>.from(res['data'])), null);
  }

  Future<(ChatReservation?, String?)> requestReservation(int roomId, {required int bookId, required int hours, String? message}) async {
    final res = await _send('POST', '/chat/rooms/$roomId/reservations', body: {
      'book_id': bookId,
      'hours': hours,
      if (message != null && message.trim().isNotEmpty) 'message': message.trim(),
    });
    if (res == null || res['success'] != true || res['data'] is! Map) {
      return (null, res?['message'] as String? ?? S.actionFailed);
    }
    return (ChatReservation.fromJson(Map<String, dynamic>.from(res['data'])), null);
  }

  Future<(ChatReservation?, String?)> respondReservation(int reservationId, String action) async {
    final res = await _send('PATCH', '/chat/reservations/$reservationId', body: {'action': action});
    if (res == null || res['success'] != true || res['data'] is! Map) {
      return (null, res?['message'] as String? ?? S.actionFailed);
    }
    return (ChatReservation.fromJson(Map<String, dynamic>.from(res['data'])), null);
  }

  // ---------- 帳號安全 ----------

  Future<SecurityStatus> fetchSecurityStatus() async {
    final res = await _send('GET', '/security');
    if (res == null || res['success'] != true || res['data'] is! Map) return SecurityStatus.unknown;
    return SecurityStatus.fromJson(Map<String, dynamic>.from(res['data']));
  }

  Future<VerifyOutcome> verifyIdentity({
    required String scope,
    required String method,
    String? pin,
    String? password,
    String? key,
  }) async {
    final res = await _send('POST', '/security/verify', body: {
      'scope': scope,
      'method': method,
      'pin': ?pin,
      'password': ?password,
      'key': ?key,
    });
    if (res == null) return VerifyOutcome(code: 'SIGNED_OUT', message: S.pleaseSignFirst);
    if (res['success'] == true) {
      return VerifyOutcome.success(res['data']?['verify_token'] as String? ?? '');
    }
    return VerifyOutcome(
      code: res['code'] as String? ?? 'UNKNOWN',
      message: res['message'] as String? ?? S.somethingWentWrongPleaseTryAgain,
      remainingAttempts: res['remaining_attempts'] == null ? null : parseInt(res['remaining_attempts']),
    );
  }

  Future<String?> setPaymentPin(String pin, {required String verifyToken}) async {
    final res = await _send('PUT', '/security/payment-pin', body: {'pin': pin}, extraHeaders: {'X-Verify-Token': verifyToken});
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.somethingWentWrongPleaseTryAgain);
  }

  Future<(String?, String?)> enableBiometricPay({required String verifyToken}) async {
    final res = await _send('POST', '/security/biometric-key', extraHeaders: {'X-Verify-Token': verifyToken});
    if (res == null) return (null, S.pleaseSignFirst);
    final key = res['data'] is Map ? res['data']['key'] as String? : null;
    if (res['success'] != true || key == null) return (null, res['message'] as String? ?? S.somethingWentWrongPleaseTryAgain);
    final userId = currentUser?.userId;
    if (userId != null) await PaymentKeyStore.save(userId, key);
    return (key, null);
  }

  Future<bool> disableBiometricPay() async {
    await PaymentKeyStore.clear();
    final res = await _send('DELETE', '/security/biometric-key');
    return res != null && res['success'] == true;
  }

  Future<List<LoginSession>?> fetchLoginSessions() async {
    final res = await _send('GET', '/security/sessions');
    if (res == null || res['success'] != true) return null;
    return _mapList(res, LoginSession.fromJson);
  }

  Future<(bool signedOutCurrent, String? error)> revokeLoginSession(int sessionId) async {
    final res = await _send('DELETE', '/security/sessions/$sessionId');
    if (res == null) return (false, S.pleaseSignFirst);
    if (res['success'] != true) return (false, res['message'] as String? ?? S.actionFailed);
    return (res['data']?['signed_out_current'] == true, null);
  }

  Future<(int revoked, String? error)> revokeAllLoginSessions({bool includeCurrent = false}) async {
    final res = await _send('POST', '/security/sessions/revoke-all', body: {'include_current': includeCurrent});
    if (res == null) return (0, S.pleaseSignFirst);
    if (res['success'] != true) return (0, res['message'] as String? ?? S.actionFailed);
    return (parseInt(res['data']?['revoked']), null);
  }

  Future<List<PushDeviceInfo>?> fetchPushDevices() async {
    final res = await _send('GET', '/push/devices');
    if (res == null || res['success'] != true) return null;
    return _mapList(res, PushDeviceInfo.fromJson);
  }

  Future<List<Map<String, dynamic>>> fetchCabinets({double? latitude, double? longitude}) async {
    final res = await _send('GET', '/cabinets', query: {
      if (latitude != null && longitude != null) 'lat': latitude.toStringAsFixed(6),
      if (latitude != null && longitude != null) 'lng': longitude.toStringAsFixed(6),
    });
    final data = res?['data'];
    if (res?['success'] != true || data is! List) return [];
    return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<Wallet> fetchWallet() async {
    final res = await _send('GET', '/wallet');
    if (res == null || res['success'] != true || res['data'] is! Map) return Wallet.empty;
    return Wallet.fromJson(Map<String, dynamic>.from(res['data']));
  }

  Future<List<WalletTransaction>> fetchWalletTransactions() async {
    final res = await _send('GET', '/wallet/transactions', query: {'limit': '50'});
    return _mapList(res, WalletTransaction.fromJson);
  }

  Future<({List<Order> orders, double total})> fetchPendingIncome() async {
    final res = await _send('GET', '/wallet/pending');
    final orders = _mapList(res, Order.fromJson);
    final total = double.tryParse('${res?['total_amount'] ?? 0}') ?? 0;
    return (orders: orders, total: total);
  }

  Future<List<String>> uploadFiles(List<String> filePaths) async {
    if (filePaths.isEmpty) return [];
    final res = await _sendMultipart('/uploads', [for (final path in filePaths) ('files', path)]);
    final urls = res?['data'] is Map ? res!['data']['urls'] : null;
    if (res?['success'] != true || urls is! List) return [];
    return urls.map((e) => e.toString()).toList();
  }

  Future<String?> submitDispute({required int orderId, required String reason, List<String>? evidenceUrls}) async {
    final res = await _send('POST', '/disputes', body: {
      'order_id': orderId,
      'reason': reason,
      'evidence_urls': evidenceUrls,
    });
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.couldNotSubmitDispute);
  }

  Future<Map<int, String>> fetchReportStatusForMyBooks() async {
    final res = await _send('GET', '/reports/against-me');
    if (res == null || res['success'] != true || res['data'] is! List) return {};

    const priority = {'pending': 3, 'reviewing': 3, 'resolved': 2, 'dismissed': 1};
    final result = <int, String>{};

    for (final item in res['data'] as List) {
      if (item is! Map) continue;
      final bookId = parseInt(item['target_id']);
      final status = item['status'] as String? ?? 'pending';
      final current = result[bookId];
      if (current == null || (priority[status] ?? 0) > (priority[current] ?? 0)) {
        result[bookId] = status;
      }
    }
    return result;
  }

  Future<String?> submitReport({
    required String targetType,
    required int targetId,
    required String reason,
  }) async {
    final res = await _send('POST', '/reports', body: {
      'target_type': targetType,
      'target_id': targetId,
      'reason': reason,
    });
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.couldNotSubmitReport);
  }

  Future<UserStats> fetchUserStats() async {
    final res = await _send('GET', '/users/me/stats');
    if (res == null || res['success'] != true || res['data'] is! Map) return UserStats.empty;
    final stats = UserStats.fromJson(Map<String, dynamic>.from(res['data']));
    _setCartCount(stats.cartCount);
    return stats;
  }

  Future<MemberLevelInfo> fetchMemberLevel() async {
    final res = await _send('GET', '/users/me/level');
    if (res == null || res['success'] != true || res['data'] is! Map) return MemberLevelInfo.empty;
    return MemberLevelInfo.fromJson(Map<String, dynamic>.from(res['data']));
  }

  Future<String?> updateProfile({
    String? nickname,
    String? bio,
    String? phone,
    String? birthday,
  }) async {
    final res = await _send('PUT', '/users/me', body: {
      'nickname': ?nickname,
      'bio': ?bio,
      'phone': ?phone,
      'birthday': ?birthday,
    });
    if (res == null) return S.pleaseSignFirst;
    if (res['success'] != true) return res['message'] as String? ?? S.updateFailed2;
    await fetchCurrentUser();
    return null;
  }

  Future<String?> changePassword(String currentPassword, String newPassword) async {
    final res = await _send('PUT', '/users/me/password', body: {
      'current_password': currentPassword,
      'new_password': newPassword,
    });
    if (res == null) return S.pleaseSignFirst;
    if (res['success'] != true) return res['message'] as String? ?? S.couldNotChangePassword;

    // 伺服器改密碼後換發新 token，不存下來下一個請求就會被登出。
    final token = res['data'] is Map ? res['data']['token'] : null;
    if (token is String && token.isNotEmpty) {
      authToken = token;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
    }
    unawaited(onPasswordChanged?.call());
    return null;
  }

  Future<String?> registerPushDevice(String token, String platform) async {
    final res = await _send('POST', '/push/devices', body: {'token': token, 'platform': platform});
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.somethingWentWrongPleaseTryAgain);
  }

  Future<(String?, String?)> sendTestPush() async {
    final res = await _send('POST', '/push/test');
    if (res == null) return (null, S.couldNotReachServer);
    final message = res['message'] as String?;
    return res['success'] == true ? (message ?? '', null) : (null, message ?? S.somethingWentWrongPleaseTryAgain);
  }

  Future<bool> unregisterPushDevice(String token) async {
    final res = await _send('DELETE', '/push/devices', body: {'token': token});
    return res != null && res['success'] == true;
  }

  Future<int?> resolveUserShareToken(String token) async {
    final res = await _send('GET', '/users/share/$token');
    if (res == null || res['success'] != true || res['data'] is! Map) return null;
    final id = parseInt(res['data']['user_id']);
    return id > 0 ? id : null;
  }

  Future<Book?> fetchBookByShareToken(String token) async {
    final res = await _send('GET', '/books/share/$token');
    if (res == null || res['success'] != true || res['data'] is! Map) return null;
    return Book.fromJson(Map<String, dynamic>.from(res['data']));
  }

  Future<String?> fetchProfileQrData() async {
    final res = await _send('GET', '/users/me/qrcode');
    if (res == null || res['success'] != true) return null;
    return res['data']?['qr_data'] as String?;
  }

  // ---------- 帳號與隱私 ----------

  Future<(bool, DateTime?)> fetchDeletionStatus() async {
    final res = await _send('GET', '/users/me/deletion');
    if (res == null || res['success'] != true) return (false, null);
    final data = res['data'] as Map<String, dynamic>? ?? {};
    final purge = data['purge_at'] as String?;
    return (data['pending'] == true, purge == null ? null : DateTime.tryParse(purge));
  }

  Future<String?> requestAccountDeletion(String password) async {
    final res = await _send('POST', '/users/me/deletion', body: {'password': password});
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.requestFailed);
  }

  Future<String?> cancelAccountDeletion() async {
    final res = await _send('DELETE', '/users/me/deletion');
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.couldNotCancel);
  }

  Future<String?> exportMyData({Map<String, String>? extraHeaders, Set<String> handled = const {}}) async {
    try {
      final sentWithToken = authToken != null;
      final response = await http.get(Uri.parse('$baseUrl/users/me/export'), headers: _headers(extra: extraHeaders));
      if (response.statusCode == 200) return utf8.decode(response.bodyBytes);
      final res = await _interpret(
        response.statusCode,
        response.bodyBytes,
        sentWithToken: sentWithToken,
        handled: handled,
        retry: (extra, next) async {
          final content = await exportMyData(extraHeaders: {...?extraHeaders, ...extra}, handled: next);
          return content == null ? null : {'success': true, 'content': content};
        },
      );
      return res?['content'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<String?> rotateShareToken() async {
    final res = await _send('POST', '/users/me/share-token/rotate');
    if (res == null || res['success'] != true) return null;
    return res['data']?['qr_data'] as String?;
  }

  // ---------- 後台：系統維運 ----------

  Future<(List<BackupRecord>, int)> fetchBackups() async {
    final res = await _send('GET', '/admin/backups');
    if (res == null || res['success'] != true) return (<BackupRecord>[], 14);
    return (_mapList(res, BackupRecord.fromJson), (res['keep'] as num?)?.toInt() ?? 14);
  }

  Future<String?> createBackup() async {
    final res = await _send('POST', '/admin/backups');
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.backupFailed);
  }

  Future<String?> deleteBackup(int backupId) async {
    final res = await _send('DELETE', '/admin/backups/$backupId');
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.couldNotDelete);
  }

  String backupDownloadUrl(int backupId) => '$baseUrl/admin/backups/$backupId/download';

  Future<(String?, String?)> restoreBackup(int backupId, String password) async {
    final res = await _send('POST', '/admin/backups/$backupId/restore', body: {'password': password});
    if (res == null) return (null, S.couldNotReachServer);
    if (res['success'] != true) return (null, res['message'] as String? ?? S.somethingWentWrongPleaseTryAgain);
    return ((res['data'] as Map?)?['safety_backup'] as String? ?? '', null);
  }

  Future<ServerStatus?> fetchServerStatus() async {
    final res = await _send('GET', '/status');
    if (res == null) return null;
    if (res['success'] != true) {
      return res['code'] == 'ROUTE_NOT_FOUND' ? const ServerStatus(reachable: true, apiRevision: 0) : null;
    }
    final data = res['data'];
    if (data is! Map) return null;
    return ServerStatus(
      reachable: true,
      apiRevision: parseInt(data['api_revision']),
      commit: data['commit'] as String?,
      pendingMigrations: (data['pending_migrations'] as List? ?? const []).map((e) => '$e').toList(),
    );
  }

  Future<String?> fetchRestoreState() async {
    final res = await _send('GET', '/status');
    final data = res?['data'];
    if (data is! Map) return null;
    return (data['restore'] as Map?)?['state'] as String?;
  }

  Future<List<PendingDeletion>> fetchPendingDeletions() async {
    final res = await _send('GET', '/admin/deletions');
    return _mapList(res, PendingDeletion.fromJson);
  }

  Future<String?> cancelMemberDeletion(int userId) async {
    final res = await _send('POST', '/admin/deletions/$userId/cancel');
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.couldNotCancel);
  }

  Future<String?> purgeMember(int userId) async {
    final res = await _send('POST', '/admin/deletions/$userId/purge');
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.couldNotComplete);
  }

  Future<bool> uploadAvatar(String filePath) async {
    final res = await _sendMultipart('/users/me/avatar', [('avatar', filePath)]);
    if (res == null || res['success'] != true) return false;
    await fetchCurrentUser();
    return true;
  }

  Future<List<Announcement>> fetchAnnouncements({bool includeDrafts = false}) async {
    final res = await _send('GET', includeDrafts ? '/announcements/all' : '/announcements');
    return _mapList(res, Announcement.fromJson);
  }

  Future<String?> saveAnnouncement({
    int? announcementId,
    required String title,
    required String content,
    required String type,
    required bool isPublished,
  }) async {
    final body = {
      'title': title,
      'content': content,
      'type': type,
      'is_published': isPublished,
    };
    final res = announcementId == null
        ? await _send('POST', '/announcements', body: body)
        : await _send('PUT', '/announcements/$announcementId', body: body);
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.couldNotSaveAnnouncement);
  }

  Future<bool> deleteAnnouncement(int announcementId) async {
    final res = await _send('DELETE', '/announcements/$announcementId');
    return res != null && res['success'] == true;
  }

  // ---------- 說明中心與客服 ----------

  Future<List<FaqItem>> fetchFaqs() async {
    final res = await _send('GET', '/support/faqs');
    return _mapList(res, FaqItem.fromJson);
  }

  Future<List<LegalDoc>> fetchLegalDocList() async {
    final res = await _send('GET', '/support/legal');
    return _mapList(res, LegalDoc.fromJson);
  }

  Future<List<LegalDoc>?> fetchPendingConsents() async {
    final res = await _send('GET', '/users/me/legal-consents/pending');
    if (res == null || res['success'] != true) return null;
    return _mapList(res, LegalDoc.fromJson);
  }

  Future<String?> acceptLegalDoc(LegalDoc doc) async {
    final res = await _send('POST', '/users/me/legal-consents', body: {'doc_key': doc.key, 'version': doc.version});
    if (res == null) return S.couldNotReachServer;
    return res['success'] == true ? null : (res['message'] as String? ?? S.somethingWentWrongPleaseTryAgain);
  }

  Future<NotificationSettings?> fetchNotificationSettings() async {
    final res = await _send('GET', '/users/me/notification-settings');
    if (res == null || res['success'] != true || res['data'] is! Map) return null;
    return NotificationSettings.fromJson(Map<String, dynamic>.from(res['data']));
  }

  Future<NotificationSettings?> updateNotificationSettings(Map<String, bool> changes) async {
    final res = await _send('PUT', '/users/me/notification-settings', body: changes);
    if (res == null || res['success'] != true || res['data'] is! Map) return null;
    return NotificationSettings.fromJson(Map<String, dynamic>.from(res['data']));
  }

  Future<Announcement?> fetchAnnouncement(int announcementId) async {
    final res = await _send('GET', '/announcements/$announcementId');
    if (res == null || res['success'] != true || res['data'] is! Map) return null;
    return Announcement.fromJson(Map<String, dynamic>.from(res['data']));
  }

  Future<LegalDoc?> fetchLegalDoc(String key) async {
    final res = await _send('GET', '/support/legal/$key');
    if (res == null || res['success'] != true || res['data'] is! Map) return null;
    return LegalDoc.fromJson(Map<String, dynamic>.from(res['data']));
  }

  Future<List<SupportTicket>> fetchMyTickets() async {
    final res = await _send('GET', '/support/tickets');
    return _mapList(res, SupportTicket.fromJson);
  }

  Future<SupportTicket?> fetchTicket(int ticketId) async {
    final res = await _send('GET', '/support/tickets/$ticketId');
    if (res == null || res['success'] != true || res['data'] is! Map) return null;
    return SupportTicket.fromJson(Map<String, dynamic>.from(res['data']));
  }

  Future<String?> createTicket({
    required String subject,
    required String category,
    required String content,
  }) async {
    final res = await _send('POST', '/support/tickets', body: {
      'subject': subject,
      'category': category,
      'content': content,
    });
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.couldNotSend);
  }

  Future<String?> replyTicket(int ticketId, String content) async {
    final res = await _send('POST', '/support/tickets/$ticketId/messages', body: {'content': content});
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.couldNotSend);
  }

  Future<String?> closeTicket(int ticketId) async {
    final res = await _send('PATCH', '/support/tickets/$ticketId/close');
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.actionFailed);
  }

  // ---------- 管理端 ----------

  Future<List<LegalDoc>> fetchAdminLegalDocs() async {
    final res = await _send('GET', '/admin/legal');
    return _mapList(res, LegalDoc.fromJson);
  }

  Future<({String? error, String message})> saveLegalDoc(
    String key, {
    required String title,
    required String content,
    bool major = false,
  }) async {
    final res = await _send('PUT', '/admin/legal/$key', body: {
      'title': title,
      'content': content,
      'major': major,
    });
    if (res == null) return (error: S.pleaseSignFirst, message: '');
    if (res['success'] != true) {
      return (error: res['message'] as String? ?? S.couldNotSave2, message: '');
    }
    return (error: null, message: res['message'] as String? ?? S.documentUpdated);
  }

  Future<List<FaqItem>> fetchAdminFaqs() async {
    final res = await _send('GET', '/admin/faqs');
    return _mapList(res, FaqItem.fromJson);
  }

  Future<String?> saveFaq({
    int? faqId,
    required String category,
    required String question,
    required String answer,
    int sortOrder = 0,
    bool isVisible = true,
  }) async {
    final body = {
      'category': category,
      'question': question,
      'answer': answer,
      'sort_order': sortOrder,
      'is_visible': isVisible,
    };
    final res = faqId == null
        ? await _send('POST', '/admin/faqs', body: body)
        : await _send('PUT', '/admin/faqs/$faqId', body: body);
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.couldNotSave2);
  }

  Future<String?> reorderFaqs(List<int> orderedIds) async {
    final res = await _send('PUT', '/admin/faqs/reorder', body: {'order': orderedIds});
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.couldNotReorder);
  }

  Future<String?> deleteFaq(int faqId) async {
    final res = await _send('DELETE', '/admin/faqs/$faqId');
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.couldNotDelete);
  }

  Future<List<SupportTicket>> fetchAdminTickets({String? status}) async {
    final res = await _send('GET', '/admin/tickets', query: {
      if (status != null && status != 'all') 'status': status,
    });
    return _mapList(res, SupportTicket.fromJson);
  }

  Future<String?> updateTicketStatus(int ticketId, String status) async {
    final res = await _send('PATCH', '/admin/tickets/$ticketId/status', body: {'status': status});
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.updateFailed2);
  }

  Future<AdminOverview> fetchAdminOverview() async {
    final res = await _send('GET', '/admin/overview');
    if (res == null || res['success'] != true || res['data'] is! Map) return AdminOverview.empty;
    return AdminOverview.fromJson(Map<String, dynamic>.from(res['data']));
  }

  Future<List<AdminMember>> fetchAdminMembers({String keyword = '', String? status}) async {
    final res = await _send('GET', '/admin/members', query: {
      if (keyword.isNotEmpty) 'keyword': keyword,
      'status': ?status,
      'limit': '50',
    });
    return _mapList(res, AdminMember.fromJson);
  }

  Future<bool> updateMemberStatus(int userId, {bool? isActive, bool? isBlacklisted}) async {
    final res = await _send('PATCH', '/admin/members/$userId', body: {
      'is_active': ?isActive,
      'is_blacklisted': ?isBlacklisted,
    });
    return res != null && res['success'] == true;
  }

  Future<AdminMemberDetail?> fetchAdminMemberDetail(int userId) async {
    final res = await _send('GET', '/admin/members/$userId');
    if (res == null || res['success'] != true || res['data'] is! Map) return null;
    return AdminMemberDetail.fromJson(Map<String, dynamic>.from(res['data']));
  }

  Future<String?> updateMemberRole(int userId, String role) async {
    final res = await _send('PATCH', '/admin/members/$userId', body: {'role': role});
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.updateFailed2);
  }

  Future<String?> adjustMemberLevel(
    int userId, {
    int? levelId,
    int? delta,
    bool reset = false,
  }) async {
    final res = await _send('PATCH', '/admin/members/$userId/level', body: {
      if (reset) 'reset': true,
      if (!reset && delta != null) 'delta': delta,
      if (!reset && delta == null && levelId != null) 'level_id': levelId,
    });
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.couldNotAdjust);
  }

  Future<String?> updateAdminPermissions(int userId, Map<String, bool> permissions) async {
    final res = await _send('PUT', '/admin/members/$userId/permissions', body: permissions);
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.updateFailed2);
  }

  Future<List<ReportCase>> fetchAdminReports({String? status}) async {
    final res = await _send('GET', '/admin/reports', query: {'status': ?status});
    return _mapList(res, ReportCase.fromJson);
  }

  Future<String?> resolveReport(int reportId, {required String status, String? adminNote, bool removeTarget = false}) async {
    final res = await _send('PATCH', '/admin/reports/$reportId', body: {
      'status': status,
      'admin_note': adminNote,
      'remove_target': removeTarget,
    });
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.couldNotProcessReport);
  }

  Future<List<DisputeCase>> fetchAdminDisputes({String? status}) async {
    final res = await _send('GET', '/admin/disputes', query: {'status': ?status});
    return _mapList(res, DisputeCase.fromJson);
  }

  Future<String?> arbitrateDispute(int disputeId, {required String result, String? adminNote}) async {
    final res = await _send('PATCH', '/admin/disputes/$disputeId', body: {
      'result': result,
      'admin_note': adminNote,
    });
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.couldNotRecordDecision);
  }

  Future<List<AdminOrder>> fetchAdminOrders({String keyword = '', String? status}) async {
    final res = await _send('GET', '/admin/orders', query: {
      if (keyword.isNotEmpty) 'keyword': keyword,
      if (status != null && status != 'all') 'status': status,
      'limit': '50',
    });
    return _mapList(res, AdminOrder.fromJson);
  }

  Future<String?> updateOrderStatusAsAdmin(int orderId, String status, {String? note}) async {
    final res = await _send('PATCH', '/admin/orders/$orderId', body: {
      'status': status,
      'note': note,
    });
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.updateFailed2);
  }

  Future<(String? password, String? error)> resetMemberPassword(int userId) async {
    final res = await _send('POST', '/admin/members/$userId/reset-password');
    if (res == null) return (null, S.pleaseSignFirst);
    if (res['success'] != true) {
      return (null, res['message'] as String? ?? S.updateFailed);
    }
    return (res['data']?['temp_password'] as String?, null);
  }

  Future<String?> updateAdminBook(int bookId, Map<String, dynamic> fields) async {
    final res = await _send('PUT', '/admin/books/$bookId', body: fields);
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.updateFailed);
  }

  Future<AdminOrderDetail?> fetchAdminOrder(int orderId) async {
    final res = await _send('GET', '/admin/orders/$orderId');
    if (res == null || res['success'] != true || res['data'] is! Map) return null;
    return AdminOrderDetail.fromJson(Map<String, dynamic>.from(res['data']));
  }

  Future<List<AdminBook>> fetchAdminBooks({String keyword = '', String? status}) async {
    final res = await _send('GET', '/admin/books', query: {
      if (keyword.isNotEmpty) 'keyword': keyword,
      if (status != null && status != 'all') 'status': status,
      'limit': '50',
    });
    return _mapList(res, AdminBook.fromJson);
  }

  Future<String?> setBookStatusAsAdmin(int bookId, String status, {String? reason}) async {
    final res = await _send('PATCH', '/admin/books/$bookId', body: {
      'status': status,
      'reason': reason,
    });
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.actionFailed);
  }

  Future<List<AdminCategory>> fetchAdminCategories() async {
    final res = await _send('GET', '/admin/categories');
    return _mapList(res, AdminCategory.fromJson);
  }

  Future<String?> saveCategory({int? categoryId, required String name, int sortOrder = 0}) async {
    final body = {'category_name': name, 'sort_order': sortOrder};
    final res = categoryId == null
        ? await _send('POST', '/admin/categories', body: body)
        : await _send('PUT', '/admin/categories/$categoryId', body: body);
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.couldNotSave2);
  }

  Future<String?> reorderCategories(List<int> orderedIds) async {
    final res = await _send('PUT', '/admin/categories/reorder', body: {'order': orderedIds});
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.couldNotReorder);
  }

  Future<String?> deleteCategory(int categoryId) async {
    final res = await _send('DELETE', '/admin/categories/$categoryId');
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.couldNotDelete);
  }

  Future<List<AdminLevel>> fetchAdminLevels() async {
    final res = await _send('GET', '/admin/levels');
    return _mapList(res, AdminLevel.fromJson);
  }

  Future<String?> saveLevel({
    int? levelId,
    required String name,
    required int minPoints,
    int? maxPoints,
    String benefits = '',
  }) async {
    final body = {
      'level_name': name,
      'min_points': minPoints,
      'max_points': maxPoints,
      'benefits': benefits,
    };
    final res = levelId == null
        ? await _send('POST', '/admin/levels', body: body)
        : await _send('PUT', '/admin/levels/$levelId', body: body);
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.couldNotSave2);
  }

  Future<String?> deleteLevel(int levelId) async {
    final res = await _send('DELETE', '/admin/levels/$levelId');
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.couldNotDelete);
  }

  Future<List<AdminWallet>> fetchAdminWallets({String keyword = ''}) async {
    final res = await _send('GET', '/admin/wallets', query: {
      if (keyword.isNotEmpty) 'keyword': keyword,
      'limit': '50',
    });
    return _mapList(res, AdminWallet.fromJson);
  }

  Future<AdminWalletDetail?> fetchAdminWalletDetail(int userId) async {
    final res = await _send('GET', '/admin/wallets/$userId');
    if (res == null || res['success'] != true || res['data'] is! Map) return null;
    return AdminWalletDetail.fromJson(Map<String, dynamic>.from(res['data']));
  }

  Future<String?> adjustWallet(int userId, {required double amount, required String description}) async {
    final res = await _send('POST', '/admin/wallets/$userId/adjust', body: {
      'amount': amount,
      'description': description,
    });
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.couldNotAdjust);
  }

  Future<AdminStats> fetchAdminStats({int days = 7}) async {
    final res = await _send('GET', '/admin/stats', query: {'days': '$days'});
    if (res == null || res['success'] != true || res['data'] is! Map) return AdminStats.empty;
    return AdminStats.fromJson(Map<String, dynamic>.from(res['data']));
  }

  Future<List<AdminOperationLog>> fetchAdminOperationLogs({String? targetType, String? keyword}) async {
    final res = await _send('GET', '/admin/operation-logs', query: {
      'limit': '100',
      if (targetType != null) 'target_type': targetType,
      if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
    });
    return _mapList(res, AdminOperationLog.fromJson);
  }

  Future<String?> undoAdminOperation(int logId) async {
    final res = await _send('POST', '/admin/operation-logs/$logId/undo');
    if (res == null) return S.couldNotReachServer;
    return res['success'] == true ? null : (res['message'] as String? ?? S.somethingWentWrongPleaseTryAgain);
  }

  Future<List<Cabinet>> fetchAdminCabinets() async {
    final res = await _send('GET', '/admin/cabinets');
    return _mapList(res, Cabinet.fromJson);
  }

  Future<String?> saveCabinet({
    int? cabinetId,
    required String name,
    required String address,
    required double latitude,
    required double longitude,
    int totalSlots = 20,
    String? openTime,
    String? closeTime,
    bool? isActive,
  }) async {
    final body = {
      'cabinet_name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      if (cabinetId == null) 'total_slots': totalSlots,
      'open_time': ?openTime,
      'close_time': ?closeTime,
      'is_active': ?isActive,
    };
    final res = cabinetId == null
        ? await _send('POST', '/admin/cabinets', body: body)
        : await _send('PUT', '/admin/cabinets/$cabinetId', body: body);
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.couldNotSaveLocker);
  }

  Future<bool> updateSlotStatus(int cabinetId, int slotId, String status) async {
    final res = await _send('PATCH', '/admin/cabinets/$cabinetId/slots/$slotId', body: {'status': status});
    return res != null && res['success'] == true;
  }

  Future<List<MaintenanceLog>> fetchMaintenanceLogs() async {
    final res = await _send('GET', '/admin/maintenance-logs');
    return _mapList(res, MaintenanceLog.fromJson);
  }
}
