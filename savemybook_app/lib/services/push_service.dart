import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../firebase_options.dart';
import '../models/notification_category.dart';
import '../features/chat/chat_room_screen.dart';
import '../features/home/notification_screen.dart';
import '../widgets/in_app_banner.dart';
import 'api_service.dart';
import 'notification_router.dart';
import '../i18n/strings.dart';

class PushService {
  static const _badgeChannel = MethodChannel('savemybook/push');

  static GlobalKey<NavigatorState>? navigatorKey;

  static bool _initialized = false;
  static bool get isAvailable => _initialized;

  static String? _registeredToken;
  static StreamSubscription<String>? _tokenRefresh;
  static Map<String, dynamic>? _pendingOpen;
  static bool _navigatorReady = false;
  static DateTime? _lastRegisteredAt;
  static AppLifecycleListener? _lifecycle;

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

    await messaging.setForegroundNotificationPresentationOptions(alert: false, badge: true, sound: false);

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen((m) => _open(m.data));

    final initial = await messaging.getInitialMessage();
    if (initial != null) _pendingOpen = initial.data;

    ApiService.unreadNotificationCount.addListener(_syncBadge);
  }

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
    _lifecycle ??= AppLifecycleListener(onResume: () {
      final last = _lastRegisteredAt;
      if (ApiService.authToken != null && (last == null || DateTime.now().difference(last).inHours >= 6)) {
        unawaited(registerCurrentDevice());
      }
    });
  }

  static Future<String?> registerCurrentDevice() async {
    if (!_initialized || ApiService.authToken == null) return null;
    final (token, problem) = await _fetchToken();
    if (token == null) return problem;
    return _register(token);
  }

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
    }
  }

  static Future<(String, bool, bool)> sendTest() async {
    if (!_initialized) {
      return (S.pushNotificationsNotSetUpBuild, true, false);
    }

    final settings = await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return (S.notificationsTurnedOffAllowAppSend, true, true);
    }

    final problem = await registerCurrentDevice();
    if (problem != null) return (problem, true, false);

    final (message, error) = await ApiService().sendTestPush();
    return error != null ? (error, true, false) : (message!, false, false);
  }

  static Future<void> openSystemSettings() async {
    try {
      await _badgeChannel.invokeMethod('openNotificationSettings');
    } catch (_) {}
  }

  static Future<String?> _apnsError() async {
    try {
      final state = await _badgeChannel.invokeMapMethod<String, dynamic>('apnsState');
      final error = state?['error'];
      return error is String && error.isNotEmpty ? error : null;
    } catch (_) {
      return null;
    }
  }

  static Future<(String?, String?)> _fetchToken() async {
    final messaging = FirebaseMessaging.instance;
    try {
      if (Platform.isIOS) {
        String? apns = await messaging.getAPNSToken();
        if (apns == null) {
          try {
            await _badgeChannel.invokeMethod('registerForRemoteNotifications');
          } catch (_) {}
        }
        String? nativeError;
        for (var i = 0; i < 15 && apns == null && nativeError == null; i++) {
          await Future<void>.delayed(const Duration(seconds: 1));
          apns = await messaging.getAPNSToken();
          nativeError = await _apnsError();
        }
        if (apns == null) {
          if (nativeError != null) {
            final hint = nativeError.contains('aps-environment')
                ? S.buildSProvisioningProfileDoesnT
                : S.checkPhoneOnlinePushNotificationsAdded;
            return (null, S.iphoneFailedRegisterPushNotificationsWith(nativeError, hint));
          }
          return (null, S.iphoneDidnTReceiveApnsToken);
        }
      }
      final token = await messaging.getToken();
      return token == null ? (null, S.firebaseDidnTIssuePushToken) : (token, null);
    } catch (e) {
      debugPrint('[Push] getToken failed: $e');
      return (null, S.couldnTGetPushTokenP0(e));
    }
  }

  static Future<String?> _register(String token) async {
    final error = await ApiService().registerPushDevice(token, Platform.isIOS ? 'ios' : 'android');
    if (error == null) {
      _registeredToken = token;
      _lastRegisteredAt = DateTime.now();
      return null;
    }
    return S.couldnTRegisterPushTokenWith(error);
  }

  static void _onForegroundMessage(RemoteMessage message) {
    unawaited(ApiService().refreshBadges());

    final data = message.data;
    if (data['related_type'] == 'chat_room' &&
        ChatRoomScreen.isShowing(int.tryParse('${data['related_id']}'))) {
      return;
    }

    final overlay = navigatorKey?.currentState?.overlay;
    final notification = message.notification;
    final title = notification?.title ?? data['title']?.toString() ?? '';
    final body = notification?.body ?? data['body']?.toString() ?? '';
    if (overlay == null || (title.isEmpty && body.isEmpty)) return;

    final avatar = '${data['sender_avatar'] ?? ''}';
    showInAppBanner(
      overlay,
      title: title,
      body: body,
      icon: NotificationCategory.of('${data['type']}', data['related_type']?.toString()).icon,
      imageUrl: avatar.isEmpty ? null : avatar,
      onTap: () => _open(data),
    );
  }

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

    final relatedType = '${data['related_type'] ?? ''}';
    final opened = await NotificationRouter.open(
      navigator,
      relatedType: relatedType.isEmpty ? null : relatedType,
      relatedId: int.tryParse('${data['related_id']}'),
    );
    if (!opened) {
      navigatorKey?.currentState?.push(MaterialPageRoute(builder: (_) => const NotificationScreen()));
    }
  }

  static void _syncBadge() => unawaited(_setBadge(ApiService.unreadNotificationCount.value));

  static Future<void> _setBadge(int count) async {
    if (!Platform.isIOS) return;
    try {
      await _badgeChannel.invokeMethod('setBadge', count < 0 ? 0 : count);
    } catch (_) {}
  }
}
