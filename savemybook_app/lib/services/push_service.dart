import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../firebase_options.dart';
import '../models/app_notification.dart';
import '../screens/book_detail_screen.dart';
import '../screens/chat_room_screen.dart';
import '../screens/notification_screen.dart';
import '../screens/order_detail_screen.dart';
import '../screens/support_ticket_screen.dart';
import '../widgets/in_app_banner.dart';
import 'api_service.dart';
import '../i18n/strings.dart';

/// 手機推播：Firebase Cloud Messaging，iOS 由 FCM 轉交 APNs。
///
/// 伺服器沒設定、Firebase 設定檔還沒放、使用者拒絕通知權限時都會安靜停用，
/// 站內通知與紅點輪詢照常運作。
class PushService {
  static const _badgeChannel = MethodChannel('savemybook/push');

  static GlobalKey<NavigatorState>? navigatorKey;

  static bool _initialized = false;
  static bool get isAvailable => _initialized;

  static String? _registeredToken;
  static StreamSubscription<String>? _tokenRefresh;
  static Map<String, dynamic>? _pendingOpen;
  static bool _navigatorReady = false;

  /// 冷啟動時呼叫一次。不會要求權限，那要等使用者登入後。
  static Future<void> init() async {
    final options = DefaultFirebaseOptions.currentPlatform;
    if (options == null || !(Platform.isIOS || Platform.isAndroid)) return;

    try {
      await Firebase.initializeApp(options: options);
    } catch (e) {
      debugPrint('[Push] Firebase init failed: $e');
      return;
    }
    _initialized = true;

    final messaging = FirebaseMessaging.instance;

    // 前景一律不出系統橫幅，交給 showInAppBanner，才能略過正在看的聊天室。
    await messaging.setForegroundNotificationPresentationOptions(alert: false, badge: true, sound: false);

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen((m) => _open(m.data));

    // 從「App 完全關閉」的狀態點推播進來。此時畫面還沒建好，先存著。
    final initial = await messaging.getInitialMessage();
    if (initial != null) _pendingOpen = initial.data;

    ApiService.unreadNotificationCount.addListener(_syncBadge);
  }

  /// 進到首頁後呼叫：要求權限、登記裝置，並處理冷啟動時點進來的推播。
  static Future<void> onSignedIn() async {
    _navigatorReady = true;
    final pending = _pendingOpen;
    _pendingOpen = null;
    // 呼叫端在 initState 裡，要等這一幀建完才能 push 新畫面。
    if (pending != null) WidgetsBinding.instance.addPostFrameCallback((_) => _open(pending));

    if (!_initialized) return;
    final messaging = FirebaseMessaging.instance;

    final settings = await messaging.requestPermission(alert: true, badge: true, sound: true);
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    await registerCurrentDevice();

    _tokenRefresh ??= messaging.onTokenRefresh.listen((token) {
      if (ApiService.authToken != null) _register(token);
    });
  }

  /// 改密碼後伺服器會清掉這個帳號的所有裝置，要重新登記。
  static Future<void> registerCurrentDevice() async {
    if (!_initialized || ApiService.authToken == null) return;
    final token = await _fetchToken();
    if (token != null) await _register(token);
  }

  /// 登出前呼叫（此時登入 Token 還有效）。canReachServer 為 false 代表登入已經失效，
  /// 只能刪掉本機的 FCM token，伺服器下次推送時會收到失效回報而自動移除。
  static Future<void> onSigningOut({required bool canReachServer}) async {
    _navigatorReady = false;
    unawaited(_setBadge(0));
    if (!_initialized) return;

    final token = _registeredToken;
    _registeredToken = null;
    if (canReachServer && token != null) {
      await ApiService().unregisterPushDevice(token).timeout(const Duration(seconds: 4), onTimeout: () => false);
    }
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {
      // 沒有網路時刪不掉，伺服器端的失效清理會補上。
    }
  }

  /// 設定頁的「傳送測試通知」。回傳 (訊息, 是否為錯誤, 是否該引導去系統設定)。
  static Future<(String, bool, bool)> sendTest() async {
    if (!_initialized) {
      return (S.pushNotificationsNotSetUpBuild, true, false);
    }

    final settings = await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return (S.notificationsTurnedOffAllowAppSend, true, true);
    }

    // 伺服器那邊可能因為改密碼清掉了裝置，送之前先補登記一次。
    await registerCurrentDevice();

    final (message, error) = await ApiService().sendTestPush();
    return error != null ? (error, true, false) : (message!, false, false);
  }

  static Future<void> openSystemSettings() async {
    try {
      await _badgeChannel.invokeMethod('openNotificationSettings');
    } catch (_) {}
  }

  static Future<String?> _fetchToken() async {
    final messaging = FirebaseMessaging.instance;
    try {
      // iOS 要先拿到 APNs token，FCM 才發得出 token；剛取得權限時可能要等一下。
      if (Platform.isIOS) {
        for (var i = 0; i < 10 && await messaging.getAPNSToken() == null; i++) {
          await Future<void>.delayed(const Duration(seconds: 1));
        }
      }
      return await messaging.getToken();
    } catch (e) {
      debugPrint('[Push] getToken failed: $e');
      return null;
    }
  }

  static Future<void> _register(String token) async {
    final ok = await ApiService().registerPushDevice(token, Platform.isIOS ? 'ios' : 'android');
    if (ok) _registeredToken = token;
  }

  static void _onForegroundMessage(RemoteMessage message) {
    unawaited(ApiService().refreshBadges());

    final data = message.data;
    if (data['related_type'] == 'chat_room' &&
        int.tryParse('${data['related_id']}') == ChatRoomScreen.activeRoomId) {
      return;
    }

    final overlay = navigatorKey?.currentState?.overlay;
    final notification = message.notification;
    if (overlay == null || notification == null) return;

    showInAppBanner(
      overlay,
      title: notification.title ?? '',
      body: notification.body ?? '',
      icon: AppNotification.iconFor('${data['type']}'),
      onTap: () => _open(data),
    );
  }

  /// 依通知的關聯對象開啟對應畫面，找不到對象時退回通知列表。
  static Future<void> _open(Map<String, dynamic> data) async {
    if (!_navigatorReady || ApiService.authToken == null) {
      _pendingOpen = data;
      return;
    }
    final navigator = navigatorKey?.currentState;
    if (navigator == null) return;

    final api = ApiService();
    final notificationId = int.tryParse('${data['notification_id']}');
    if (notificationId != null) unawaited(api.markNotificationRead(notificationId));

    final relatedId = int.tryParse('${data['related_id']}');
    Widget? screen;

    if (relatedId != null) {
      switch (data['related_type']) {
        case 'chat_room':
          screen = ChatRoomScreen(roomId: relatedId);
        case 'ticket':
          screen = TicketDetailScreen(ticketId: relatedId);
        case 'order':
          final order = await api.fetchOrderDetail(relatedId);
          if (order != null) {
            screen = OrderDetailScreen(order: order, asSeller: order.sellerId == ApiService.currentUser?.userId);
          }
        case 'book':
          final book = await api.fetchBookDetail(relatedId);
          if (book != null) screen = BookDetailScreen(book: book);
      }
    }

    navigatorKey?.currentState?.push(
      MaterialPageRoute(builder: (_) => screen ?? const NotificationScreen()),
    );
  }

  static void _syncBadge() => unawaited(_setBadge(ApiService.unreadNotificationCount.value));

  /// Android 的角標由啟動器依系統通知自行計算，只有 iOS 需要手動設定。
  static Future<void> _setBadge(int count) async {
    if (!Platform.isIOS) return;
    try {
      await _badgeChannel.invokeMethod('setBadge', count < 0 ? 0 : count);
    } catch (_) {}
  }
}
