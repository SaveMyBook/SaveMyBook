// 第 12 章使用手冊第 14–17 節截圖：社群帳號綁定與解除、通知偏好設定、會員等級查看、帳號資料匯出與刪除。
// flutter test tool/manual_shots/s14_17_test.dart（只跑單張可加 --plain-name）

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:savemybook_app/features/account/account_privacy_screen.dart';
import 'package:savemybook_app/features/account/member_level_screen.dart';
import 'package:savemybook_app/features/account/settings_screen.dart';
import 'package:savemybook_app/features/admin/admin_home_screen.dart';
import 'package:savemybook_app/features/home/home_screen.dart';
import 'package:savemybook_app/features/security/security_center_screen.dart';
import 'package:savemybook_app/i18n/strings.dart';
import 'package:savemybook_app/models/notification_category.dart';
import 'package:savemybook_app/models/user.dart';
import 'package:savemybook_app/services/locale_provider.dart';
import 'package:savemybook_app/services/theme_provider.dart';
import 'package:savemybook_app/widgets/custom_bottom_nav.dart';
import 'package:savemybook_app/widgets/in_app_banner.dart';
import 'package:savemybook_app/widgets/state_views.dart';

import 'manual_api.dart';
import 'manual_host.dart';
import 's14_17_ui.dart';

const _f14 = '14. 社群帳號綁定與解除';
const _f15 = '15. 通知偏好設定';
const _f16 = '16. 會員等級查看';
const _f17 = '17. 帳號資料匯出與刪除';

final _ios = TargetPlatformVariant.only(TargetPlatform.iOS);

/// 第 14 節的登入者：原圖為「雪喵」的帳號（一般會員）。
const _snowId = 21;

Map<String, dynamic> _snow() => userJson(_snowId);

/// 第 15–17 節的登入者：原圖為具管理員權限的 es。
Map<String, dynamic> _es() => userJson(meId, extra: {'role': 'admin'});

const _levels = [
  {'level_id': 1, 'level_name': '新手書友', 'min_points': 0, 'max_points': 99, 'benefits': '基本交易功能'},
  {'level_id': 2, 'level_name': '活躍書友', 'min_points': 100, 'max_points': 499, 'benefits': '享有推薦曝光加成'},
  {'level_id': 3, 'level_name': '資深書友', 'min_points': 500, 'max_points': 1999, 'benefits': '享有交易手續費折扣'},
  {'level_id': 4, 'level_name': '菁英書友', 'min_points': 2000, 'max_points': null, 'benefits': '享有全部VIP權益'},
];

Map<String, dynamic> _levelInfo() => {
  'points': 0,
  'completed_orders': 0,
  'current_level': _levels[0],
  'next_level': _levels[1],
  'points_to_next': 100,
  'levels': _levels,
};

/// 會員中心需要的資料：使用者、代幣、等級、待存書與收藏數、通知未讀數。
void _profileRoutes(Map<String, dynamic> me, {double balance = 0, int unread = 0, int deposit = 0, int favorites = 0}) {
  ManualApi.on('GET', '/auth/me', (_) => me);
  ManualApi.on('GET', '/users/me/stats', (_) => {
    'balance': balance,
    'book_count': booksOfSeller(me['user_id'] as int).length,
    'favorite_count': favorites,
    'unread_notification_count': unread,
    'cart_count': 0,
  });
  ManualApi.on('GET', '/users/me/level', (_) => _levelInfo());
  ManualApi.on('GET', '/orders', (r) => ok(<Object>[], pagination: {
    'total': r.query['role'] == 'seller' ? deposit : 0,
    'page': 1,
    'limit': 1,
    'total_pages': 1,
  }));
  ManualApi.on('GET', '/notifications/unread-count', (_) => {
    'unread_count': unread,
    'by_category': {'trade': 0, 'chat': 0, 'account': unread, 'service': 0, 'promotion': 0},
  });
}

/// 帳號安全頁需要的資料。
void _securityRoutes({required bool passwordSet, required bool paymentPin, List<Map<String, dynamic>> identities = const []}) {
  ManualApi.on('GET', '/security', (_) => {
    'available': true,
    'has_password': passwordSet,
    'has_payment_pin': paymentPin,
    'pin_locked_until': null,
    'biometric_pay_enabled': false,
    'passkey_available': true,
    'has_passkey': false,
  });
  ManualApi.on('GET', '/security/sessions', (_) => [
    {
      'session_id': 1,
      'device_name': 'iPhone 16 Pro',
      'platform': 'ios',
      'app_version': '1.0.0',
      'ip_address': '163.20.230.201',
      'created_at': ago(days: 2),
      'last_seen_at': ago(minutes: 1),
      'biometric_pay': false,
      'is_current': true,
    },
  ]);
  ManualApi.on('GET', '/auth/passkeys/status', (_) => {'enabled': true});
  ManualApi.on('GET', '/users/me/passkeys', (_) => <Object>[]);
  ManualApi.on('GET', '/auth/providers', (_) => {
    'social_enabled': true,
    'providers': [
      for (final id in ['google', 'apple', 'phone', 'line', 'discord']) {'id': id, 'enabled': true, 'signup': true, 'configured': true},
    ],
  });
  ManualApi.on('GET', '/users/me/identities', (_) => {'password_set': passwordSet, 'identities': identities});
}

void _settingsRoutes() {
  ManualApi.on('GET', '/auth/me', (_) => _es());
  ManualApi.on('GET', '/users/me/notification-settings', (_) => {'order': true, 'message': true, 'promotion': true});
}

void _aiStatus({required bool consented}) {
  ManualApi.on('GET', '/ai/status', (_) => {
    'support': true,
    'listing_assist': true,
    'recommend': true,
    'book_chat': true,
    'web_search': true,
    'consented': consented,
    'providers_in_use': ['OpenAI'],
    'embedding_provider': 'OpenAI',
  });
}

User _user(Map<String, dynamic> json) => User.fromJson(json);

/// 頁面中主要的直向捲動區域（可捲動距離最大者）。
ScrollableState _mainScrollable(WidgetTester tester) {
  ScrollableState? best;
  for (final e in find.byType(Scrollable).evaluate()) {
    final s = (e as StatefulElement).state as ScrollableState;
    if (s.axisDirection != AxisDirection.down || !s.position.hasContentDimensions) continue;
    if (best == null || s.position.maxScrollExtent > best.position.maxScrollExtent) best = s;
  }
  return best!;
}

Future<void> _scrollToEnd(WidgetTester tester) async {
  final s = _mainScrollable(tester);
  s.position.jumpTo(s.position.maxScrollExtent);
  await settleReal(tester, const Duration(milliseconds: 800));
}

/// 捲動使 [finder] 的頂端位於畫面 y = [top]。
Future<void> _scrollTo(WidgetTester tester, Finder finder, double top) async {
  final s = _mainScrollable(tester);
  final dy = tester.getTopLeft(finder).dy - top;
  s.position.jumpTo((s.position.pixels + dy).clamp(0.0, s.position.maxScrollExtent));
  await settleReal(tester, const Duration(milliseconds: 800));
}

Future<void> _openTab(WidgetTester tester, String label) =>
    tapAndSettle(tester, find.descendant(of: find.byType(CustomBottomNav), matching: find.text(label)), duration: const Duration(seconds: 2));

void main() {
  setUpAll(() async {
    await setUpManual();
    themeProvider.value = ThemeMode.light;
    localeProvider.value = LocaleProvider.supported.first;
  });

  // ───────────── 14. 社群帳號綁定與解除 ─────────────

  testWidgets('14-1 會員中心', variant: _ios, (tester) async {
    await shoot(
      tester,
      folder: _f14,
      me: _user(_snow()),
      home: HomeScreen.new,
      routes: () => _profileRoutes(_snow(), unread: 1),
      act: (tester, snap) async {
        await _openTab(tester, S.member);
        await snap('表12-14-1 會員中心');
      },
    );
  });

  testWidgets('14-1 帳號安全與登入方式', variant: _ios, (tester) async {
    await shoot(
      tester,
      folder: _f14,
      me: _user(_snow()),
      home: SecurityCenterScreen.new,
      routes: () {
        ManualApi.on('GET', '/auth/me', (_) => _snow());
        _securityRoutes(passwordSet: true, paymentPin: true);
      },
      act: (tester, snap) async {
        await snap('表12-14-1 帳號安全');
        await _scrollToEnd(tester);
        await snap('表12-14-1 登入方式');
      },
    );
  });

  testWidgets('14-2 解除綁定', variant: _ios, (tester) async {
    await shoot(
      tester,
      folder: _f14,
      me: _user(_snow()),
      home: SecurityCenterScreen.new,
      routes: () {
        ManualApi.on('GET', '/auth/me', (_) => _snow());
        _securityRoutes(passwordSet: false, paymentPin: false, identities: [
          {
            'provider': 'phone',
            'display_name': null,
            'masked_email': null,
            'masked_phone': '09**-***-287',
            'created_at': todayAt(0, 33),
            'last_login_at': todayAt(0, 33),
          },
        ]);
      },
      act: (tester, snap) async {
        await _scrollToEnd(tester);
        await snap('表12-14-2 已綁定之登入方式');
        await tapAndSettle(tester, find.text(S.unlink));
        await snap('表12-14-2 請先設定密碼');
      },
    );
  });

  // ───────────── 15. 通知偏好設定 ─────────────

  testWidgets('15-1 通知設定', variant: _ios, (tester) async {
    await shoot(
      tester,
      folder: _f15,
      me: _user(_es()),
      home: SettingsScreen.new,
      routes: _settingsRoutes,
      act: (tester, snap) async {
        await snap('表12-15-1 偏好與通知設定');
        final alerts = find.text(S.alerts);
        await _scrollTo(tester, alerts, 132);
        await snap('表12-15-1 通知類別開關');
        await _scrollTo(tester, alerts, 326);
        showAppSnackBar(tester.element(find.byType(SettingsScreen)), '10 秒後送出，請返回主畫面或鎖定手機');
        await settle(tester, const Duration(milliseconds: 400));
        await snap('表12-15-1 傳送測試通知');
      },
    );
  });

  testWidgets('15-2 收到測試通知', variant: _ios, (tester) async {
    await shoot(
      tester,
      folder: _f15,
      me: _user(_es()),
      home: HomeScreen.new,
      routes: () => _profileRoutes(_es(), balance: 9981, unread: 23, deposit: 1, favorites: 1),
      act: (tester, snap) async {
        await _openTab(tester, S.member);
        showInAppBanner(
          navigatorKey.currentState!.overlay!,
          title: '測試通知',
          body: '收到此通知表示推播設定正常。',
          icon: NotificationCategory.of('system', 'push_test').icon,
        );
        await settle(tester, const Duration(milliseconds: 600));
        await snap('表12-15-2 收到測試通知');
        // ignore: invalid_use_of_visible_for_testing_member
        resetInAppBanners();
      },
    );
  });

  testWidgets('15-2 通知中心', variant: _ios, (tester) async {
    Map<String, dynamic> n(int id, String title, String content, String relatedType, String category, int minutes, {bool read = false}) => {
      'notification_id': id,
      'type': 'system',
      'title': title,
      'content': content,
      'related_id': id,
      'related_type': relatedType,
      'category': category,
      'is_read': read,
      'created_at': ago(minutes: minutes),
    };
    final items = [
      n(124, '測試通知', '收到此通知表示推播設定正常。', 'push_test', 'account', 1),
      n(123, '測試通知', '收到此通知表示推播設定正常。', 'push_test', 'account', 3),
      n(122, '書櫃櫃門異常開啟', '「新北高工」櫃門 A01 在未收到開門指令時被開啟。', 'cabinet', 'service', 9),
      n(121, '書櫃裝置已配對', '「新北高工」已完成實體書櫃裝置配對（來源 IP：163.20.230.201）。', 'cabinet', 'service', 11),
      n(120, '客服已回覆您的問題', '您的提問「存書時櫃門沒有開啟」有新的回覆。', 'ticket', 'service', 26),
      n(119, '書籍已存入書櫃', '訂單 SMB202610062215340412 的書籍已存放於「國立臺北商業大學」書櫃，即日起可於營業時間內至書櫃以 App 掃描 QR Code 取書。', 'order', 'trade', 95),
    ];
    await shoot(
      tester,
      folder: _f15,
      me: _user(_es()),
      home: HomeScreen.new,
      routes: () {
        _profileRoutes(_es(), balance: 9981, unread: 24, deposit: 1, favorites: 1);
        ManualApi.on('GET', '/notifications/unread-count', (_) => {
          'unread_count': 24,
          'by_category': {'trade': 8, 'chat': 0, 'account': 5, 'service': 11, 'promotion': 0},
        });
        ManualApi.on('GET', '/notifications', (r) {
          final category = r.query['category'];
          final list = [for (final i in items) if (category == null || i['category'] == category) i];
          return {...ok(list, pagination: {'total': list.length, 'page': 1, 'limit': 20, 'total_pages': 1}), 'unread_count': 24};
        });
      },
      act: (tester, snap) async {
        await _openTab(tester, S.alerts);
        await snap('表12-15-2 通知中心');
      },
    );
  });

  // ───────────── 16. 會員等級查看 ─────────────

  testWidgets('16-1 會員中心', variant: _ios, (tester) async {
    await shoot(
      tester,
      folder: _f16,
      me: _user(_es()),
      home: HomeScreen.new,
      routes: () => _profileRoutes(_es(), balance: 9981, unread: 21, deposit: 1, favorites: 1),
      act: (tester, snap) async {
        await _openTab(tester, S.member);
        await snap('表12-16-1 會員中心');
      },
    );
  });

  testWidgets('16-1 16-2 會員等級', variant: _ios, (tester) async {
    await shoot(
      tester,
      folder: _f16,
      me: _user(_es()),
      home: MemberLevelScreen.new,
      routes: () => _profileRoutes(_es(), balance: 9981),
      act: (tester, snap) async {
        Future<void> page(int i) async {
          tester.widget<PageView>(find.byType(PageView)).controller!.jumpToPage(i);
          await settleReal(tester, const Duration(seconds: 1));
        }

        await snap('表12-16-1 新手書友');
        await page(1);
        await snap('表12-16-1 活躍書友');
        await page(2);
        await snap('表12-16-2 資深書友');
        await snap('IMG_3934');
        await page(3);
        await snap('表12-16-2 菁英書友');
      },
    );
  });

  testWidgets('16-3 管理後台與會員等級管理', variant: _ios, (tester) async {
    await shoot(
      tester,
      folder: _f16,
      me: _user(_es()),
      home: AdminHomeScreen.new,
      routes: () {
        ManualApi.on('GET', '/auth/me', (_) => _es());
        ManualApi.on('GET', '/admin/overview', (_) => {
          'member_count': 9,
          'pending_report_count': 0,
          'pending_listing_review_count': 0,
          'open_risk_alert_count': 0,
          'pending_dispute_count': 1,
          'active_cabinet_count': realCabinets.length,
          'today_order_count': 0,
          'open_ticket_count': 0,
        });
        ManualApi.on('GET', '/admin/levels', (_) => [
          for (final (i, l) in _levels.indexed) {...l, 'member_count': [6, 0, 1, 2][i]},
        ]);
      },
      act: (tester, snap) async {
        await snap('表12-16-3 管理後台');
        await tapAndSettle(tester, find.text(S.membershipTiers), duration: const Duration(seconds: 2));
        await snap('表12-16-3 會員等級管理');
      },
    );
  });

  // ───────────── 17. 帳號資料匯出與刪除 ─────────────

  testWidgets('17-1 設定與帳號管理入口', variant: _ios, (tester) async {
    await shoot(
      tester,
      folder: _f17,
      me: _user(_es()),
      home: SettingsScreen.new,
      routes: _settingsRoutes,
      act: (tester, snap) async {
        await snap('表12-17-1 設定');
        await _scrollToEnd(tester);
        await snap('表12-17-1 帳號管理入口');
      },
    );
  });

  void privacyRoutes({required bool consented, bool pinSet = true}) {
    ManualApi.on('GET', '/auth/me', (_) => _es());
    ManualApi.on('GET', '/users/me/deletion', (_) => {'pending': false, 'grace_days': 30});
    _aiStatus(consented: consented);
    _securityRoutes(passwordSet: true, paymentPin: pinSet);
  }

  testWidgets('17-1 17-2 帳號管理與匯出', variant: _ios, (tester) async {
    await shoot(
      tester,
      folder: _f17,
      me: _user(_es()),
      home: AccountPrivacyScreen.new,
      routes: () => privacyRoutes(consented: true),
      act: (tester, snap) async {
        await snap('表12-17-1 帳號管理');
        await tapAndSettle(tester, find.text(S.exportMyData), duration: const Duration(seconds: 2));
        await snap('表12-17-2 驗證身分');
      },
    );
  });

  testWidgets('17-2 儲存匯出檔案', variant: _ios, (tester) async {
    final stamp = DateTime.now().toIso8601String().substring(0, 10);
    await shoot(
      tester,
      folder: _f17,
      me: _user(_es()),
      home: AccountPrivacyScreen.new,
      routes: () => privacyRoutes(consented: true),
      act: (tester, snap) async {
        systemOverlay.value = [Positioned.fill(child: IosFileShareSheet(fileName: 'savemybook-$stamp', detail: 'JSON · 26 KB'))];
        await tester.pump();
        await snap('表12-17-2 儲存匯出檔案');
      },
    );
  });

  /// 申請刪除帳號：說明 → 輸入密碼 → 送出。[blocked] 為尚有書籍存放於書櫃時伺服器拒絕。
  Future<void> deletion(
    WidgetTester tester, {
    required bool consented,
    String? explain,
    String? confirm,
    String? done,
    bool blocked = false,
  }) async {
    var pending = false;
    await shoot(
      tester,
      folder: _f17,
      me: _user(_es()),
      home: AccountPrivacyScreen.new,
      routes: () {
        privacyRoutes(consented: consented);
        ManualApi.on('GET', '/users/me/deletion', (_) => pending
            ? {'pending': true, 'grace_days': 30, 'purge_at': DateTime.now().add(const Duration(days: 30, minutes: 5)).toUtc().toIso8601String()}
            : {'pending': false, 'grace_days': 30});
        ManualApi.on('POST', '/users/me/deletion', (_) {
          if (blocked) {
            return {'success': false, 'code': 'BOOKS_IN_CABINET', 'message': '尚有 1 本書籍存放於書櫃，請先至書櫃以 App 掃描 QR Code 取回後再申請刪除'};
          }
          pending = true;
          return {'success': true, 'message': '已受理'};
        });
      },
      act: (tester, snap) async {
        await tapAndSettle(tester, find.text(S.deleteAccount));
        if (explain != null) await snap(explain);
        await tapAndSettle(tester, find.text(S.actionContinue));
        final field = find.byType(EditableText);
        tester.testTextInput.enterText('');
        await tester.showKeyboard(field);
        tester.testTextInput.enterText('savemyboo');
        await tester.pump();
        tester.testTextInput.enterText('savemybook');
        await tester.pump();
        if (confirm != null) {
          showQwertyKeyboard(tester);
          await tester.pump(const Duration(milliseconds: 100));
          await snap(confirm);
          hideKeyboard(tester);
          systemOverlay.value = const [];
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tapAndSettle(tester, find.text(S.requestDeletion), duration: const Duration(milliseconds: 1500));
        if (done != null) await snap(done);
      },
    );
  }

  testWidgets('17-3 申請刪除帳號', variant: _ios, (tester) async {
    await deletion(tester, consented: false, explain: '表12-17-3 刪除帳號說明', confirm: '表12-17-3 確認身分', done: '表12-17-3 待刪除期間');
  });

  testWidgets('17-4 尚有書籍存放於書櫃', variant: _ios, (tester) async {
    await deletion(tester, consented: true, explain: 'IMG_3925', confirm: 'IMG_3926', done: '表12-17-4 尚有書籍存放於書櫃', blocked: true);
  });
}
