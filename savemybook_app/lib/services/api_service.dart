import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show ValueChanged, ValueNotifier;
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

part 'api/admin_cabinets_api.dart';
part 'api/admin_commerce_api.dart';
part 'api/admin_members_api.dart';
part 'api/admin_support_api.dart';
part 'api/admin_system_api.dart';
part 'api/announcements_api.dart';
part 'api/auth_api.dart';
part 'api/books_api.dart';
part 'api/cart_api.dart';
part 'api/chat_api.dart';
part 'api/favorites_api.dart';
part 'api/legal_api.dart';
part 'api/notifications_api.dart';
part 'api/orders_api.dart';
part 'api/privacy_api.dart';
part 'api/profile_api.dart';
part 'api/push_api.dart';
part 'api/reports_api.dart';
part 'api/security_api.dart';
part 'api/status_api.dart';
part 'api/support_api.dart';
part 'api/wallet_api.dart';

enum _RefreshResult { refreshed, failed, offline }

const _requestTimeout = Duration(seconds: 30);

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
          response = await http.post(uri, headers: headers, body: encoded).timeout(_requestTimeout);
          break;
        case 'PUT':
          response = await http.put(uri, headers: headers, body: encoded).timeout(_requestTimeout);
          break;
        case 'PATCH':
          response = await http.patch(uri, headers: headers, body: encoded).timeout(_requestTimeout);
          break;
        case 'DELETE':
          response = await http.delete(uri, headers: headers, body: encoded).timeout(_requestTimeout);
          break;
        case 'GET':
        default:
          response = await http.get(uri, headers: headers).timeout(_requestTimeout);
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
    ValueChanged<double>? onProgress,
  }) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'));
      final sentWithToken = authToken != null;
      request.headers.addAll(_headers());
      if (fields != null) request.fields.addAll(fields);
      for (final (field, filePath) in files) {
        request.files.add(await http.MultipartFile.fromPath(field, filePath));
      }
      final streamed = await (onProgress == null ? request : _withUploadProgress(request, onProgress))
          .send()
          .timeout(const Duration(seconds: 90));
      final bytes = await streamed.stream.toBytes().timeout(const Duration(seconds: 90));
      return await _interpret(
        streamed.statusCode,
        bytes,
        sentWithToken: sentWithToken,
        handled: handled,
        retry: (extra, nextHandled) =>
            _sendMultipart(path, files, fields: fields, handled: nextHandled, onProgress: onProgress),
      );
    } catch (_) {
      return {'success': false, 'code': 'NETWORK', 'message': S.couldNotReachServer};
    }
  }

  http.BaseRequest _withUploadProgress(http.MultipartRequest request, ValueChanged<double> onProgress) {
    final total = request.contentLength;
    final body = request.finalize();
    final streamed = http.StreamedRequest(request.method, request.url)
      ..contentLength = total
      ..headers.addAll(request.headers);
    var sent = 0;
    onProgress(0);
    body.listen(
      (chunk) {
        sent += chunk.length;
        streamed.sink.add(chunk);
        if (total > 0) onProgress((sent / total).clamp(0.0, 1.0));
      },
      onError: streamed.sink.addError,
      onDone: streamed.sink.close,
      cancelOnError: true,
    );
    return streamed;
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
}
