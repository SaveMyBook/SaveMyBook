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
import '../models/wallet.dart';
import '../models/member_level.dart';
import '../models/admin_models.dart';
import '../utils/api_helpers.dart';

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

  static const String publicWebUrl = 'https://api.savemybook.today';

  static String profileUrlFor(int userId) => '$publicWebUrl/u/$userId';

  static int? parseProfileUserId(String raw) {
    final value = raw.trim();
    final patterns = [
      RegExp(r'^https?://[^/]+/u/(\d+)/?$'),
      RegExp(r'^savemybook://user/(\d+)$'),
    ];
    for (final p in patterns) {
      final match = p.firstMatch(value);
      if (match != null) return int.tryParse(match.group(1)!);
    }
    return null;
  }

  static final ValueNotifier<int> cartCount = ValueNotifier<int>(0);
  static final ValueNotifier<int> unreadNotificationCount = ValueNotifier<int>(0);
  static final ValueNotifier<int> unreadChatCount = ValueNotifier<int>(0);
  static final ValueNotifier<Set<int>> favoriteBookIds = ValueNotifier<Set<int>>(<int>{});

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
  }

  static List<String> searchHistory = [];

  static void addSearchHistory(String keyword) {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) return;
    searchHistory.remove(trimmed);
    searchHistory.insert(0, trimmed);
    if (searchHistory.length > 10) {
      searchHistory.removeLast();
    }
  }

  static void removeSearchHistory(String keyword) {
    searchHistory.remove(keyword);
  }

  static Future<void> _handleUnauthorized({String? reason}) async {
    if (authToken == null) return;
    authToken = null;
    currentUser = null;
    resetGlobalState();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    onUnauthorized?.call(reason);
  }

  static Map<String, String> _headers({bool json = false}) {
    return {
      'Accept': 'application/json',
      if (json) 'Content-Type': 'application/json',
      if (authToken != null) 'Authorization': 'Bearer $authToken',
    };
  }

  Future<Map<String, dynamic>?> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    try {
      var uri = Uri.parse('$baseUrl$path');
      if (query != null && query.isNotEmpty) {
        uri = uri.replace(queryParameters: query);
      }

      final headers = _headers(json: body != null);
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

      if (response.statusCode == 401) {
        // 停權／黑名單的訊息要帶回去給使用者看，不能只是靜靜踢回登入頁。
        String? reason;
        try {
          final payload = jsonDecode(utf8.decode(response.bodyBytes));
          if (payload is Map) {
            final code = payload['code'];
            if (code == 'ACCOUNT_BLACKLISTED' ||
                code == 'ACCOUNT_INACTIVE' ||
                code == 'ACCOUNT_NOT_FOUND') {
              reason = payload['message'] as String?;
            }
          }
        } catch (_) {
          // 沒有 JSON body 就當成一般的 token 過期。
        }

        await _handleUnauthorized(reason: reason);
        return null;
      }

      final decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(utf8.decode(response.bodyBytes));

      if (decoded is! Map<String, dynamic>) return null;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decoded;
      }

      return {
        'success': false,
        'message': decoded['message'] ?? '請求失敗（${response.statusCode}）',
      };
    } catch (e) {
      return {'success': false, 'message': '無法連線至伺服器'};
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
    final res = await _send('POST', '/auth/login', body: {'email': email, 'password': password});

    if (res == null) {
      return const LoginOutcome(code: 'NETWORK', message: '無法連線至伺服器，請檢查網路');
    }

    if (res['success'] != true) {
      return LoginOutcome(
        code: res['code'] as String? ?? 'UNKNOWN',
        message: res['message'] as String? ?? '登入失敗',
      );
    }

    final token = res['data']?['token'] as String?;
    if (token == null) {
      return const LoginOutcome(code: 'UNKNOWN', message: '登入失敗，請稍後再試');
    }

    authToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);

    await fetchCurrentUser();
    return const LoginOutcome.success();
  }

  Future<String?> register(String email, String password, String nickname) async {
    final res = await _send('POST', '/users',
        body: {'email': email, 'password': password, 'nickname': nickname});
    if (res == null) return '無法連線至伺服器，請檢查網路';
    return res['success'] == true ? null : (res['message'] as String? ?? '註冊失敗');
  }

  Future<void> logout() async {
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
      switch (sort) {
        case '熱門推薦': query['sort'] = 'popular'; break;
        case '價格由低到高': query['sort'] = 'price_asc'; break;
        case '價格由高到低': query['sort'] = 'price_desc'; break;
        case '最新上架':
        default: query['sort'] = 'newest'; break;
      }
    }

    final res = await _send('GET', '/books', query: query);
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

  Future<bool> uploadBookImages(int bookId, List<String> filePaths) async {
    if (filePaths.isEmpty) return true;
    try {
      final uri = Uri.parse('$baseUrl/books/$bookId/images');
      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $authToken';
      for (final path in filePaths) {
        request.files.add(await http.MultipartFile.fromPath('images', path));
      }
      final streamed = await request.send();
      if (streamed.statusCode == 401) {
        await _handleUnauthorized();
        return false;
      }
      return streamed.statusCode >= 200 && streamed.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteBookImage(int bookId, int imageId) async {
    final res = await _send('DELETE', '/books/$bookId/images/$imageId');
    return res != null && res['success'] == true;
  }

  Future<bool> removeBook(int bookId) async {
    final res = await _send('DELETE', '/books/$bookId');
    return res != null && res['success'] == true;
  }

  Future<bool> relistBook(int bookId) async {
    return updateBook(bookId, {'status': 'on_sale'});
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

  /// 先切換本地狀態再打 API，失敗時自動回滾，讓愛心點下去就有反應。
  Future<String?> toggleFavorite(int bookId) async {
    if (authToken == null) return '請先登入';
    final wasFavorite = favoriteBookIds.value.contains(bookId);
    _setFavorite(bookId, !wasFavorite);

    final ok = wasFavorite ? await removeFavorite(bookId) : await addFavorite(bookId);
    if (!ok) {
      _setFavorite(bookId, wasFavorite);
      return wasFavorite ? '取消收藏失敗' : '收藏失敗';
    }
    return null;
  }

  Future<List<CartItem>> fetchCart() async {
    final res = await _send('GET', '/cart');
    final items = _mapList(res, CartItem.fromJson);
    _setCartCount(items.length);
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
    if (res == null) return '請先登入';
    if (res['success'] != true) return res['message'] as String? ?? '加入購物車失敗';
    _setCartCount(cartCount.value + 1);
    return null;
  }

  Future<bool> updateCartQuantity(int cartId, int quantity) async {
    final res = await _send('PATCH', '/cart/$cartId', body: {'quantity': quantity});
    return res != null && res['success'] == true;
  }

  Future<bool> removeCartItem(int cartId) async {
    final res = await _send('DELETE', '/cart/$cartId');
    final ok = res != null && res['success'] == true;
    if (ok) _setCartCount(cartCount.value - 1);
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
    if (res == null) return '請先登入';
    if (res['success'] != true) return res['message'] as String? ?? '結帳失敗';
    _setCartCount(cartCount.value - cartIds.length);
    return null;
  }

  Future<String?> cancelOrder(int orderId, {String? reason}) async {
    final res = await _send('PATCH', '/orders/$orderId/cancel', body: {'reason': reason});
    if (res == null) return '請先登入';
    return res['success'] == true ? null : (res['message'] as String? ?? '取消訂單失敗');
  }

  Future<String?> updateOrderStatus(int orderId, String status) async {
    final res = await _send('PATCH', '/orders/$orderId/status', body: {'status': status});
    if (res == null) return '請先登入';
    return res['success'] == true ? null : (res['message'] as String? ?? '更新訂單狀態失敗');
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

  /// 一次刷新底部導覽列與 header 上所有的紅點數字。
  Future<void> refreshBadges() async {
    if (authToken == null) {
      resetGlobalState();
      return;
    }
    await Future.wait([
      refreshCartCount(),
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

  Future<({List<ChatMessage> messages, ChatPartner partner})> fetchChatMessages(int roomId) async {
    final res = await _send('GET', '/chat/rooms/$roomId/messages');
    final messages = _mapList(res, ChatMessage.fromJson);
    final partner = ChatPartner.fromJson(
      res?['partner'] is Map ? Map<String, dynamic>.from(res!['partner']) : null,
    );
    return (messages: messages, partner: partner);
  }

  Future<ChatMessage?> sendChatMessage(int roomId, String content) async {
    final res = await _send('POST', '/chat/rooms/$roomId/messages', body: {'content': content});
    if (res == null || res['success'] != true || res['data'] is! Map) return null;
    return ChatMessage.fromJson(Map<String, dynamic>.from(res['data']));
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
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/uploads'));
      request.headers['Authorization'] = 'Bearer $authToken';
      for (final path in filePaths) {
        request.files.add(await http.MultipartFile.fromPath('files', path));
      }
      final streamed = await request.send();
      if (streamed.statusCode == 401) {
        await _handleUnauthorized();
        return [];
      }
      if (streamed.statusCode < 200 || streamed.statusCode >= 300) return [];

      final body = jsonDecode(utf8.decode(await streamed.stream.toBytes()));
      final data = body is Map ? body['data'] : null;
      final urls = data is Map ? data['urls'] : null;
      if (urls is! List) return [];
      return urls.map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  Future<String?> submitDispute({required int orderId, required String reason, List<String>? evidenceUrls}) async {
    final res = await _send('POST', '/disputes', body: {
      'order_id': orderId,
      'reason': reason,
      'evidence_urls': evidenceUrls,
    });
    if (res == null) return '請先登入';
    return res['success'] == true ? null : (res['message'] as String? ?? '送出爭議申請失敗');
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
    if (res == null) return '請先登入';
    return res['success'] == true ? null : (res['message'] as String? ?? '送出檢舉失敗');
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
    if (res == null) return '請先登入';
    if (res['success'] != true) return res['message'] as String? ?? '更新失敗';
    await fetchCurrentUser();
    return null;
  }

  Future<String?> changePassword(String currentPassword, String newPassword) async {
    final res = await _send('PUT', '/users/me/password', body: {
      'current_password': currentPassword,
      'new_password': newPassword,
    });
    if (res == null) return '請先登入';
    return res['success'] == true ? null : (res['message'] as String? ?? '更改密碼失敗');
  }

  Future<String?> fetchProfileQrData() async {
    final res = await _send('GET', '/users/me/qrcode');
    if (res == null || res['success'] != true) return null;
    return res['data']?['qr_data'] as String?;
  }

  Future<bool> uploadAvatar(String filePath) async {
    try {
      final uri = Uri.parse('$baseUrl/users/me/avatar');
      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $authToken';
      request.files.add(await http.MultipartFile.fromPath('avatar', filePath));

      final streamed = await request.send();
      if (streamed.statusCode == 401) {
        await _handleUnauthorized();
        return false;
      }
      if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
        await fetchCurrentUser();
        return true;
      }
    } catch (_) {}
    return false;
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
    if (res == null) return '請先登入';
    return res['success'] == true ? null : (res['message'] as String? ?? '儲存公告失敗');
  }

  Future<bool> deleteAnnouncement(int announcementId) async {
    final res = await _send('DELETE', '/announcements/$announcementId');
    return res != null && res['success'] == true;
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
    if (res == null) return '請先登入';
    return res['success'] == true ? null : (res['message'] as String? ?? '更新失敗');
  }

  /// 三選一：指定等級、加減點數、或恢復自動計算。
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
    if (res == null) return '請先登入';
    return res['success'] == true ? null : (res['message'] as String? ?? '調整失敗');
  }

  Future<String?> updateAdminPermissions(int userId, Map<String, bool> permissions) async {
    final res = await _send('PUT', '/admin/members/$userId/permissions', body: permissions);
    if (res == null) return '請先登入';
    return res['success'] == true ? null : (res['message'] as String? ?? '更新失敗');
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
    if (res == null) return '請先登入';
    return res['success'] == true ? null : (res['message'] as String? ?? '處理檢舉失敗');
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
    if (res == null) return '請先登入';
    return res['success'] == true ? null : (res['message'] as String? ?? '裁決失敗');
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
    if (res == null) return '請先登入';
    return res['success'] == true ? null : (res['message'] as String? ?? '更新失敗');
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
    if (res == null) return '請先登入';
    return res['success'] == true ? null : (res['message'] as String? ?? '操作失敗');
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
    if (res == null) return '請先登入';
    return res['success'] == true ? null : (res['message'] as String? ?? '儲存失敗');
  }

  Future<String?> deleteCategory(int categoryId) async {
    final res = await _send('DELETE', '/admin/categories/$categoryId');
    if (res == null) return '請先登入';
    return res['success'] == true ? null : (res['message'] as String? ?? '刪除失敗');
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
    if (res == null) return '請先登入';
    return res['success'] == true ? null : (res['message'] as String? ?? '儲存失敗');
  }

  Future<String?> deleteLevel(int levelId) async {
    final res = await _send('DELETE', '/admin/levels/$levelId');
    if (res == null) return '請先登入';
    return res['success'] == true ? null : (res['message'] as String? ?? '刪除失敗');
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
    if (res == null) return '請先登入';
    return res['success'] == true ? null : (res['message'] as String? ?? '調整失敗');
  }

  Future<AdminStats> fetchAdminStats({int days = 7}) async {
    final res = await _send('GET', '/admin/stats', query: {'days': '$days'});
    if (res == null || res['success'] != true || res['data'] is! Map) return AdminStats.empty;
    return AdminStats.fromJson(Map<String, dynamic>.from(res['data']));
  }

  Future<List<AdminOperationLog>> fetchAdminOperationLogs() async {
    final res = await _send('GET', '/admin/operation-logs', query: {'limit': '80'});
    return _mapList(res, AdminOperationLog.fromJson);
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
    if (res == null) return '請先登入';
    return res['success'] == true ? null : (res['message'] as String? ?? '儲存書櫃失敗');
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
