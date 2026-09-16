import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:local_auth_platform_interface/local_auth_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:savemybook_app/features/account/edit_profile_screen.dart';
import 'package:savemybook_app/features/account/help_center_screen.dart';
import 'package:savemybook_app/features/account/profile_screen.dart';
import 'package:savemybook_app/features/account/settings_screen.dart';
import 'package:savemybook_app/features/account/share_profile_screen.dart';
import 'package:savemybook_app/features/account/support_ticket_screen.dart';
import 'package:savemybook_app/features/home/notification_screen.dart';
import 'package:savemybook_app/features/orders/purchase_history_screen.dart';
import 'package:savemybook_app/features/security/security_center_screen.dart';
import 'package:savemybook_app/features/selling/book_manage_screen.dart';
import 'package:savemybook_app/features/selling/sales_history_screen.dart';
import 'package:savemybook_app/features/books/favorites_screen.dart';
import 'package:savemybook_app/features/account/wallet_screen.dart';
import 'package:savemybook_app/i18n/app_localizations.dart';
import 'package:savemybook_app/i18n/strings.dart';
import 'package:savemybook_app/models/app_notification.dart';
import 'package:savemybook_app/models/notification_category.dart';
import 'package:savemybook_app/models/user.dart';
import 'package:savemybook_app/services/api_service.dart';
import 'package:savemybook_app/services/biometric_service.dart';
import 'package:savemybook_app/services/locale_provider.dart';
import 'package:savemybook_app/services/theme_provider.dart';
import 'package:savemybook_app/utils/app_theme.dart';

import 'layout_overflow_test.dart' show fakeData;

class _FakeLocalAuth extends LocalAuthPlatform {
  bool authenticated = true;

  @override
  Future<bool> isDeviceSupported() async => true;

  @override
  Future<bool> deviceSupportsBiometrics() async => true;

  @override
  Future<List<BiometricType>> getEnrolledBiometrics() async => [BiometricType.fingerprint];

  @override
  Future<bool> authenticate({
    required String localizedReason,
    required Iterable<AuthMessages> authMessages,
    AuthenticationOptions options = const AuthenticationOptions(),
  }) async =>
      authenticated;

  @override
  Future<bool> stopAuthentication() async => true;
}

const _now = '2026-09-16T08:00:00.000Z';

Map<String, Object?> _notification(int id, String type, String? relatedType, {bool read = false}) => {
      'notification_id': id,
      'type': type,
      'title': '通知 $id',
      'content': '內容',
      'related_id': null,
      'related_type': relatedType,
      'is_read': read,
      'created_at': _now,
      'category': NotificationCategory.of(type, relatedType).key,
    };

final _allNotifications = [
  _notification(1, 'order', 'order'),
  _notification(2, 'message', 'chat_room'),
  _notification(3, 'system', 'security'),
  _notification(4, 'system', 'ticket', read: true),
  _notification(5, 'promotion', 'book'),
  _notification(6, 'order', 'order', read: true),
];

class _Server {
  final Map<String, Object?> me;
  _Server({this.me = _user});

  final log = <String>[];
  final notifications = [..._allNotifications];
  final unread = {'trade': 1, 'chat': 1, 'account': 1, 'service': 0, 'promotion': 1};

  http.Client client() => MockClient((req) async {
        final path = req.url.path.replaceFirst('/api', '');
        final query = req.url.query;
        log.add('${req.method} $path${query.isEmpty ? '' : '?$query'}');
        Object? data;
        final extra = <String, Object?>{};
        if (req.method == 'GET' && path == '/notifications') {
          final category = req.url.queryParameters['category'];
          final page = int.parse(req.url.queryParameters['page'] ?? '1');
          final items = notifications.where((n) => category == null || n['category'] == category).toList();
          data = items.skip((page - 1) * 20).take(20).toList();
          extra['unread_count'] = unread.values.fold<int>(0, (a, b) => a + b);
          extra['pagination'] = {'total': items.length, 'page': page, 'limit': 20, 'total_pages': (items.length / 20).ceil()};
        } else if (path == '/notifications/unread-count') {
          data = {'unread_count': unread.values.fold<int>(0, (a, b) => a + b), 'by_category': unread};
        } else if (path == '/notifications/read-all') {
          final category = req.url.queryParameters['category'];
          if (category != null) unread[category] = 0;
          data = {'updated': 1};
        } else if (path == '/notifications/all') {
          final category = req.url.queryParameters['category'];
          notifications.removeWhere((n) => category == null || n['category'] == category);
          if (category != null) unread[category] = 0;
          data = {'deleted': 1};
        } else if (path == '/auth/me') {
          data = me;
        } else {
          data = fakeData(req.method, path);
          if (data is List) extra['pagination'] = {'total': data.length, 'page': 1, 'limit': 20, 'total_pages': 1};
        }
        return http.Response(jsonEncode({'success': true, 'data': data, ...extra}), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      });
}

const _user = {'user_id': 1, 'nickname': '測試使用者', 'email': 'a@example.com', 'role': 'buyer_seller'};

Future<void> _pump(WidgetTester tester, Widget home, http.Client client, {Size size = const Size(390, 844)}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    locale: const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    supportedLocales: LocaleProvider.supported,
    theme: AppTheme.build(Brightness.light),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, child) {
      S = AppLocalizations.of(context);
      return child!;
    },
    home: home,
  ));
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester, [int rounds = 12]) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Future<void> _tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await _settle(tester);
}

Finder _chip(String key) => find.byKey(ValueKey('notification_category_$key'));

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    themeProvider = await ThemeProvider.init();
    localeProvider = await LocaleProvider.init();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiService.authToken = 'test-token';
    ApiService.currentUser = User.fromJson(_user);
    ApiService.resetGlobalState();
  });

  group('通知分類', () {
    test('分類規則與 API 一致：type 優先，未列出的組合歸帳號', () {
      expect(NotificationCategory.of('order', 'order'), NotificationCategory.trade);
      expect(NotificationCategory.of('reservation', 'chat_room'), NotificationCategory.trade);
      expect(NotificationCategory.of('reservation', null), NotificationCategory.trade);
      expect(NotificationCategory.of('system', 'wallet'), NotificationCategory.trade);
      expect(NotificationCategory.of('system', 'book'), NotificationCategory.trade);
      expect(NotificationCategory.of('message', 'chat_room'), NotificationCategory.chat);
      expect(NotificationCategory.of('system', 'security'), NotificationCategory.account);
      expect(NotificationCategory.of('system', 'user'), NotificationCategory.account);
      expect(NotificationCategory.of('system', 'push_test'), NotificationCategory.account);
      expect(NotificationCategory.of('system', null), NotificationCategory.account);
      expect(NotificationCategory.of('system', 'admin_ticket'), NotificationCategory.service);
      expect(NotificationCategory.of('system', 'report'), NotificationCategory.service);
      expect(NotificationCategory.of('promotion', 'book'), NotificationCategory.promotion);
      expect(NotificationCategory.of('system', 'announcement'), NotificationCategory.promotion);
    });

    test('優先採用伺服器回傳的分類', () {
      final n = AppNotification.fromJson({..._notification(9, 'system', null), 'category': 'service'});
      expect(n.category, NotificationCategory.service);
      expect(n.asRead().category, NotificationCategory.service);
    });

    testWidgets('分類膠囊顯示未讀數，切換分類以 category 查詢並各自快取', (tester) async {
      final server = _Server();
      await http.runWithClient(() async {
        await _pump(tester, const NotificationScreen(), server.client(), size: const Size(700, 1000));

        for (final key in ['all', 'trade', 'chat', 'account', 'service', 'promotion']) {
          expect(_chip(key), findsOneWidget);
        }
        expect(find.descendant(of: _chip('all'), matching: find.text('4')), findsOneWidget);
        expect(find.descendant(of: _chip('trade'), matching: find.text('1')), findsOneWidget);
        expect(find.descendant(of: _chip('service'), matching: find.text('0')), findsNothing);
        expect(server.log, contains('GET /notifications?page=1&limit=20'));
        expect(find.text('通知 6'), findsOneWidget);

        await _tapAndSettle(tester, _chip('trade'));
        expect(server.log, contains('GET /notifications?page=1&limit=20&category=trade'));
        expect(find.text('通知 1'), findsOneWidget);
        expect(find.text('通知 2'), findsNothing);

        await _tapAndSettle(tester, _chip('service'));
        expect(server.log, contains('GET /notifications?page=1&limit=20&category=service'));

        final before = server.log.where((l) => l.contains('category=trade')).length;
        await _tapAndSettle(tester, _chip('trade'));
        expect(server.log.where((l) => l.contains('category=trade')).length, before);
      }, server.client);
    });

    testWidgets('各分類分別分頁，捲動到底載入同分類的下一頁', (tester) async {
      final server = _Server();
      server.notifications.addAll([for (var i = 100; i < 125; i++) _notification(i, 'system', 'wallet', read: true)]);
      await http.runWithClient(() async {
        await _pump(tester, const NotificationScreen(), server.client(), size: const Size(700, 1000));
        await _tapAndSettle(tester, _chip('trade'));
        expect(server.log, contains('GET /notifications?page=1&limit=20&category=trade'));
        await tester.dragUntilVisible(find.text('通知 124'), find.byKey(const ValueKey('items_trade')), const Offset(0, -400));
        await _settle(tester);
        expect(server.log, contains('GET /notifications?page=2&limit=20&category=trade'));
        expect(server.log.where((l) => l.startsWith('GET /notifications?page=2') && !l.contains('category=trade')), isEmpty);
        expect(find.text('通知 124'), findsOneWidget);
      }, server.client);
    });

    testWidgets('無通知的分類顯示對應的空狀態', (tester) async {
      final server = _Server();
      server.notifications.removeWhere((n) => n['category'] == 'promotion');
      await http.runWithClient(() async {
        await _pump(tester, const NotificationScreen(), server.client(), size: const Size(700, 1000));
        await _tapAndSettle(tester, _chip('promotion'));
        expect(find.text(S.noOfferNotifications), findsOneWidget);
      }, server.client);
    });

    testWidgets('全部標為已讀與清除全部依目前分類執行，對話框指出分類', (tester) async {
      final server = _Server();
      await http.runWithClient(() async {
        await _pump(tester, const NotificationScreen(), server.client(), size: const Size(700, 1000));
        await _tapAndSettle(tester, _chip('trade'));

        await _tapAndSettle(tester, find.byIcon(Icons.done_all_rounded));
        expect(find.text(S.markAllP1UnreadNotificationsP0(S.faqCatTrade, 1)), findsOneWidget);
        await _tapAndSettle(tester, find.text(S.markAllRead).last);
        expect(server.log, contains('PATCH /notifications/read-all?category=trade'));
        expect(find.descendant(of: _chip('trade'), matching: find.text('1')), findsNothing);

        await _tapAndSettle(tester, _chip('chat'));
        await _tapAndSettle(tester, find.byIcon(Icons.delete_sweep_outlined));
        expect(find.text(S.clearP0Notifications(S.chat)), findsOneWidget);
        expect(find.text(S.p1NotificationsP0DeletedCannotUndone(S.chat, 1)), findsOneWidget);
        await _tapAndSettle(tester, find.text(S.clearAll).last);
        expect(server.log, contains('DELETE /notifications/all?category=chat'), reason: server.log.join('\n'));
        expect(find.text(S.noChatNotifications), findsOneWidget);

        await _tapAndSettle(tester, _chip('all'));
        await _tapAndSettle(tester, find.byIcon(Icons.done_all_rounded));
        expect(find.text(S.markAllUnreadNotificationsAsRead(3)), findsOneWidget);
        await _tapAndSettle(tester, find.text(S.markAllRead).last);
        expect(server.log, contains('PATCH /notifications/read-all'));
      }, server.client);
    });
  });

  group('會員中心與設定', () {
    testWidgets('會員中心：重複入口已移除，每個功能仍可到達', (tester) async {
      final server = _Server();
      await http.runWithClient(() async {
        await _pump(tester, const ProfileScreen(), server.client());

        expect(find.text(S.editProfile), findsNothing);
        expect(find.text(S.myQrCode), findsNothing);
        expect(find.text(S.coins), findsNothing);
        for (final label in [S.pickUp, S.orderPendingDeposit, S.saved, S.myBooks, S.purchases, S.sales, S.accountSecurity, S.helpCentre2, S.settings]) {
          expect(find.text(label), findsOneWidget, reason: label);
        }
        expect(find.text(S.admin), findsNothing);

        final routes = <(Finder, Type)>[
          (find.byKey(const ValueKey('profile_edit_area')), EditProfileScreen),
          (find.byKey(const ValueKey('profile_qr_code')), ShareProfileScreen),
          (find.byIcon(Icons.monetization_on_rounded), WalletScreen),
          (find.text(S.pickUp), PurchaseHistoryScreen),
          (find.text(S.orderPendingDeposit), SalesHistoryScreen),
          (find.text(S.saved), FavoritesScreen),
          (find.text(S.myBooks), BookManageScreen),
          (find.text(S.purchases), PurchaseHistoryScreen),
          (find.text(S.sales), SalesHistoryScreen),
          (find.text(S.accountSecurity), SecurityCenterScreen),
          (find.text(S.helpCentre2), HelpCenterScreen),
          (find.text(S.settings), SettingsScreen),
        ];
        for (final (finder, screen) in routes) {
          await _tapAndSettle(tester, finder);
          expect(find.byType(screen), findsOneWidget, reason: '$screen');
          Navigator.of(tester.element(find.byType(screen))).pop();
          await _settle(tester);
        }
      }, server.client);
    });

    testWidgets('會員中心：管理員顯示管理後台', (tester) async {
      final admin = <String, Object?>{..._user, 'role': 'admin'};
      ApiService.currentUser = User.fromJson(admin);
      final server = _Server(me: admin);
      await http.runWithClient(() async {
        await _pump(tester, const ProfileScreen(), server.client());
        expect(find.text(S.admin), findsOneWidget);
      }, server.client);
    });

    testWidgets('設定：分為偏好設定、通知、隱私、關於，不再重複帳號安全與客服', (tester) async {
      final server = _Server();
      await http.runWithClient(() async {
        await _pump(tester, const SettingsScreen(), server.client(), size: const Size(390, 2400));
        for (final label in [
          S.preferences, S.alerts, S.privacy, S.about2,
          S.appearance, S.themeColour, S.language, S.homeRecommendations,
          S.orderProgress, S.chatMessages, S.promotions2, S.systemNotificationSettings,
          S.account, S.blockedUsers,
          S.termsService, S.privacyPolicy, S.aboutSavemybook, S.clearCache,
        ]) {
          expect(find.text(label), findsOneWidget, reason: label);
        }
        for (final label in [S.accountSecurity, S.changePassword, S.helpCentre, S.contactUs, S.sign3(S.biometrics), S.sign3(S.fingerprint)]) {
          expect(find.text(label), findsNothing, reason: label);
        }
      }, server.client);
    });

    testWidgets('說明中心固定提供聯絡客服入口', (tester) async {
      final server = _Server();
      await http.runWithClient(() async {
        await _pump(tester, const HelpCenterScreen(), server.client());
        expect(find.text(S.contactSupport), findsWidgets);
        await _tapAndSettle(tester, find.byKey(const ValueKey('help_contact_support')));
        expect(find.byType(SupportTicketScreen), findsOneWidget);
      }, server.client);
    });

    testWidgets('帳號安全的登入區塊提供生物辨識登入開關', (tester) async {
      final previous = LocalAuthPlatform.instance;
      final fake = _FakeLocalAuth();
      LocalAuthPlatform.instance = fake;
      addTearDown(() => LocalAuthPlatform.instance = previous);
      await BiometricService.setEnabled(false);

      final server = _Server();
      await http.runWithClient(() async {
        await _pump(tester, const SecurityCenterScreen(), server.client(), size: const Size(390, 2000));
        final toggle = find.byKey(const ValueKey('biometric_login_switch'));
        expect(toggle, findsOneWidget);
        expect(find.text(S.sign3(S.fingerprint)), findsOneWidget);

        fake.authenticated = false;
        await _tapAndSettle(tester, toggle);
        expect(BiometricService.isEnabled, isFalse);

        fake.authenticated = true;
        await _tapAndSettle(tester, toggle);
        expect(BiometricService.isEnabled, isTrue);
        expect(tester.widget<SwitchListTile>(toggle).value, isTrue);

        await _tapAndSettle(tester, toggle);
        expect(BiometricService.isEnabled, isFalse);
      }, server.client);
    });
  });
}
