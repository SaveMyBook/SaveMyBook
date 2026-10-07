// 第 12 章第 10 節「錢包與會員等級」、第 12 節「通行密鑰與生物辨識設定」、第 13 節「帳號安全與交易密碼」截圖。
// 第 10、13 節的原實機截圖以雪喵的帳號拍攝（會員中心顯示雪喵、待撥款項為雪喵上架的《HTML & CSS》），登入者改為雪喵；
// 第 12 節原圖為其他帳號，改用登入者 es。錢包紀錄以真實書籍的購買與退款組成。

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:savemybook_app/features/account/member_level_screen.dart';
import 'package:savemybook_app/features/account/wallet_screen.dart';
import 'package:savemybook_app/features/auth/login_screen.dart';
import 'package:savemybook_app/features/books/book_detail_screen.dart';
import 'package:savemybook_app/features/home/home_screen.dart';
import 'package:savemybook_app/features/security/login_devices_screen.dart';
import 'package:savemybook_app/features/security/security_center_screen.dart';
import 'package:savemybook_app/features/selling/pending_income_screen.dart';
import 'package:savemybook_app/i18n/strings.dart';
import 'package:savemybook_app/models/book.dart';
import 'package:savemybook_app/models/user.dart';
import 'package:savemybook_app/services/api_service.dart';
import 'package:savemybook_app/services/passkey_service.dart';
import 'package:savemybook_app/services/verification_service.dart';
import 'package:savemybook_app/widgets/custom_bottom_nav.dart';
import 'package:savemybook_app/widgets/pin_pad.dart';

import 'manual_api.dart';
import 'manual_host.dart';

const _f10 = '10. 錢包與會員等級';
const _f12 = '12. 通行密鑰與生物辨識設定';
const _f13 = '13. 帳號安全與交易密碼';

const _snow = 21;
const _htmlCss = 150;
const _brainwash = 148;
const _earth = 146;
const _infoMgmt = 126;
const _powerPoint = 145;
const _halfBlue = 144;

const _password = 'snowmeow24';

final _ios = TargetPlatformVariant.only(TargetPlatform.iOS);

User get _snowUser => User.fromJson(userJson(_snow));

DateTime _at(int daysAgo, int hour, int minute, [int second = 0]) {
  final d = DateTime.now().subtract(Duration(days: daysAgo));
  return DateTime(d.year, d.month, d.day, hour, minute, second);
}

String _iso(DateTime local) => local.toUtc().toIso8601String();

String _two(int n) => n.toString().padLeft(2, '0');

/// 訂單編號格式比照伺服器：SMB + 年月日時分秒 + 6 位亂數。
String _orderNo(DateTime t, int tail) =>
    'SMB${t.year}${_two(t.month)}${_two(t.day)}${_two(t.hour)}${_two(t.minute)}${_two(t.second)}$tail';

// ---------- 第 10 節：錢包 ----------

List<Map<String, dynamic>> _transactions() {
  var id = 40;
  var balance = 0;
  final rows = <Map<String, dynamic>>[];
  void t(String type, int amount, String description, DateTime at, {int? bookId, String? orderNo}) {
    balance += amount;
    rows.add({
      'txn_id': ++id,
      'txn_no': 'TX${(id * 7919).toRadixString(36).toUpperCase()}Q${id}M',
      'type': type,
      'amount': amount,
      'balance_after': balance,
      'description': description,
      'created_at': _iso(at),
      'orders': orderNo == null
          ? null
          : {
              'order_id': id,
              'order_no': orderNo,
              'order_items': [
                {'books': bookJson(bookId!)},
              ],
            },
    });
  }

  final halfBlue = _orderNo(_at(5, 14, 6, 41), 528317);
  final powerPoint = _orderNo(_at(5, 20, 12, 8), 904265);
  final brainwash = _orderNo(_at(2, 10, 25, 37), 361904);
  final infoCancelled = _orderNo(_at(1, 23, 33, 11), 737248);
  final info = _orderNo(_at(1, 23, 34, 38), 118889);
  t('admin_adjust', 10000, '管理員調整：代幣儲值', _at(6, 9, 30));
  t('purchase', -140, '購買訂單 $halfBlue', _at(5, 14, 6, 41), bookId: _halfBlue, orderNo: halfBlue);
  t('purchase', -220, '購買訂單 $powerPoint', _at(5, 20, 12, 8), bookId: _powerPoint, orderNo: powerPoint);
  t('refund', 220, '訂單 $powerPoint 取消退款', _at(4, 9, 2), bookId: _powerPoint, orderNo: powerPoint);
  t('purchase', -400, '購買訂單 $brainwash', _at(2, 10, 25, 37), bookId: _brainwash, orderNo: brainwash);
  t('purchase', -666, '購買訂單 $infoCancelled', _at(1, 23, 33, 11), bookId: _infoMgmt, orderNo: infoCancelled);
  t('refund', 666, '訂單 $infoCancelled 取消退款', _at(1, 23, 33, 52), bookId: _infoMgmt, orderNo: infoCancelled);
  t('purchase', -666, '購買訂單 $info', _at(1, 23, 34, 38), bookId: _infoMgmt, orderNo: info);
  t('refund', 400, '訂單 $brainwash 退款', _at(1, 23, 41, 5), bookId: _brainwash, orderNo: brainwash);
  return rows.reversed.toList();
}

Map<String, dynamic> _wallet() {
  final rows = _transactions();
  final income = rows.where((r) => (r['amount'] as int) > 0).fold<int>(0, (s, r) => s + (r['amount'] as int));
  final expense = rows.where((r) => (r['amount'] as int) < 0).fold<int>(0, (s, r) => s - (r['amount'] as int));
  return {
    'balance': rows.first['balance_after'],
    'frozen_amount': 0,
    'total_income': income,
    'total_expense': expense,
    'pending_income': bookJson(_htmlCss)['price'],
  };
}

Map<String, dynamic> _pendingOrder() {
  final book = bookJson(_htmlCss);
  final created = _at(1, 16, 32, 19);
  return {
    'order_id': 88,
    'order_no': _orderNo(created, 640512),
    'total_amount': book['price'],
    'status': 'pending_deposit',
    'buyer_id': 11,
    'seller_id': _snow,
    'users_orders_buyer_idTousers': {'user_id': 11, 'nickname': realUsers[11]!.nickname},
    'users_orders_seller_idTousers': {'user_id': _snow, 'nickname': realUsers[_snow]!.nickname},
    'cabinet_id': book['cabinet_id'],
    'smart_cabinets': book['smart_cabinets'],
    'created_at': _iso(created),
    'order_items': [
      {'item_id': 1, 'unit_price': book['price'], 'subtotal': book['price'], 'books': book},
    ],
  };
}

// ---------- 會員等級 ----------

Map<String, dynamic> _level(int id, String name, int min, int? max, String benefits) =>
    {'level_id': id, 'level_name': name, 'min_points': min, 'max_points': max, 'benefits': benefits};

Map<String, dynamic> _levelInfo() {
  final levels = [
    _level(1, '新手書友', 0, 99, '基本交易功能'),
    _level(2, '活躍書友', 100, 499, '享有推薦曝光加成'),
    _level(3, '資深書友', 500, 1999, '享有交易手續費折扣'),
    _level(4, '菁英書友', 2000, null, '享有全部VIP權益'),
  ];
  return {
    'points': 0,
    'completed_orders': 0,
    'current_level': levels[0],
    'next_level': levels[1],
    'points_to_next': 100,
    'levels': levels,
  };
}

void _snowRoutes() {
  ManualApi.on('GET', '/auth/me', (_) => userJson(_snow));
  ManualApi.on('GET', '/users/me/level', (_) => _levelInfo());
}

// ---------- 帳號安全 ----------

Map<String, dynamic> _security({required bool pin, bool passkey = false}) => {
  'available': true,
  'has_payment_pin': pin,
  'pin_locked_until': null,
  'biometric_pay_enabled': false,
  'passkey_available': true,
  'has_passkey': passkey,
  'has_password': true,
};

Map<String, dynamic> _session(int id, String device, String ip, {required bool current, required String created, String? seen}) => {
  'session_id': id,
  'device_name': device,
  'platform': 'ios',
  'app_version': '1.0.3',
  'ip_address': ip,
  'created_at': created,
  'last_seen_at': seen ?? created,
  'biometric_pay': false,
  'is_current': current,
};

Map<String, dynamic> _passkeyRow({String? lastUsed}) => {
  'passkey_id': 'PK7Q2M9XA',
  'credential_id': 'cred-iphone-15-pro',
  'device_label': 'iPhone 15 Pro',
  'created_at': _iso(_at(0, 0, 25)),
  'last_used_at': lastUsed,
  'backed_up': true,
  'authenticator': 'icloud_keychain',
};

void _securityRoutes({required bool pin, required List<Map<String, dynamic>> Function() passkeys, required List<Map<String, dynamic>> sessions}) {
  ManualApi.on('GET', '/security', (_) => _security(pin: pin, passkey: passkeys().isNotEmpty));
  ManualApi.on('GET', '/auth/passkeys/status', (_) => {'enabled': true, 'rp_id': 'savemybook.today'});
  ManualApi.on('GET', '/users/me/passkeys', (_) => passkeys());
  ManualApi.on('GET', '/security/sessions', (_) => sessions);
  ManualApi.on('GET', '/users/me/identities', (_) => {'password_set': true, 'identities': <Object>[]});
  ManualApi.on('GET', '/auth/providers', (_) => {
    'social_enabled': true,
    'providers': [
      for (final id in ['google', 'apple', 'phone', 'line', 'discord']) {'id': id, 'enabled': true, 'signup': true, 'configured': true},
    ],
  });
  ManualApi.on('POST', '/security/verify', (_) => {'verify_token': 'manual-verify-token'});
  ManualApi.on('PUT', '/security/payment-pin', (_) => {'has_payment_pin': true});
}

/// 系統的通行密鑰視窗：建立時疊上模擬的 iOS 面板並等待測試放行。
class _SheetPasskeyClient implements PasskeyClient {
  Completer<Map<String, dynamic>>? pending;

  @override
  Future<bool> isSupported() async => true;

  @override
  Future<Map<String, dynamic>> create(Map<String, dynamic> options) {
    systemOverlay.value = [
      const Positioned.fill(
        child: IosPasskeySheet(
          title: 'Save a passkey?',
          message:
              '“救舊我的書” supports passkeys, a stronger alternative to passwords that cannot be leaked or stolen. A passkey for “$meEmail” will be saved in “Passwords”.',
          primary: 'Add Passkey',
          secondary: 'More Options',
        ),
      ),
    ];
    return (pending = Completer<Map<String, dynamic>>()).future;
  }

  @override
  Future<Map<String, dynamic>> get(Map<String, dynamic> options, {bool immediate = true}) async =>
      throw const PasskeyClientException.cancelled();

  @override
  Future<void> forget({required String rpId, required String credentialId}) async {}
}

Future<void> _tapDigits(WidgetTester tester, String digits) async {
  for (final d in digits.split('')) {
    await tester.tap(find.descendant(of: find.byType(NumberPad), matching: find.text(d)));
    await settle(tester, const Duration(milliseconds: 200));
  }
}

/// 讓畫面中「使用 Face ID 付款」那一列停在標題列下方（比照原圖的捲動位置）。
Future<void> _scrollToBiometricPay(WidgetTester tester) async {
  final row = find.widgetWithText(SwitchListTile, '使用 Face ID 付款');
  final y = tester.getCenter(row).dy;
  await scrollBy(tester, y - 140);
}

/// 點擊「直接購買」：結帳請求回應需要交易密碼驗證（正式伺服器的行為），其餘請求照常由 ManualApi 回應。
Future<void> _tapBuyNow(WidgetTester tester) async {
  http.Client client() => MockClient((request) async {
    if (request.method == 'POST' && request.url.path.endsWith('/orders/buy-now')) {
      return http.Response(
        jsonEncode({
          'success': false,
          'code': 'VERIFICATION_REQUIRED',
          'message': '請輸入交易密碼',
          'verification': {
            'scope': 'payment',
            'methods': ['pin', 'biometric'],
          },
        }),
        403,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    final copy = http.Request(request.method, request.url)
      ..headers.addAll(request.headers)
      ..bodyBytes = request.bodyBytes;
    return http.Response.fromStream(await ManualApi.client().send(copy));
  });
  await http.runWithClient(() => tester.tap(find.text('直接購買').first), client);
  await settleReal(tester, const Duration(seconds: 2));
}

void main() {
  setUpAll(() async {
    await setUpManual();
    VerificationService.navigatorKey = navigatorKey;
    ApiService.onVerificationRequired = VerificationService.handle;
  });
  setUp(() {
    VerificationService.clearCache();
    VerificationService.paymentSummary = null;
    PasskeyService.resetCache();
  });

  // ================= 第 10 節 =================

  testWidgets('10-1 代幣中心', variant: _ios, (tester) async {
    await shoot(
      tester,
      folder: _f10,
      me: _snowUser,
      home: WalletScreen.new,
      routes: () {
        _snowRoutes();
        ManualApi.on('GET', '/wallet', (_) => _wallet());
        ManualApi.on('GET', '/wallet/transactions', (_) => _transactions());
      },
      act: (tester, snap) async {
        await settleReal(tester, const Duration(seconds: 2));
        await snap('表12-10-1 代幣中心');
      },
    );
  });

  testWidgets('10-1 待撥款項', variant: _ios, (tester) async {
    await shoot(
      tester,
      folder: _f10,
      me: _snowUser,
      home: PendingIncomeScreen.new,
      routes: () {
        _snowRoutes();
        ManualApi.on('GET', '/wallet/pending', (_) => {
          ...ok([_pendingOrder()]),
          'total_amount': bookJson(_htmlCss)['price'],
        });
      },
      act: (tester, snap) async {
        await settleReal(tester, const Duration(seconds: 2));
        await snap('表12-10-1 待撥款項');
      },
    );
  });

  testWidgets('10-1 會員等級', variant: _ios, (tester) async {
    await shoot(
      tester,
      folder: _f10,
      me: _snowUser,
      home: MemberLevelScreen.new,
      routes: _snowRoutes,
      act: (tester, snap) async {
        await settleReal(tester, const Duration(seconds: 2));
        await snap('表12-10-1 會員等級');
        final nodes = find.byWidgetPredicate(
          (w) => w is GestureDetector && w.behavior == HitTestBehavior.opaque && w.child is SizedBox && (w.child! as SizedBox).width == 38,
        );
        for (final (i, file) in ['IMG_7195', 'IMG_7196', 'IMG_7197'].indexed) {
          await tester.tap(nodes.at(i + 1));
          await settleReal(tester, const Duration(seconds: 2));
          await snap(file);
        }
      },
    );
  });

  // ================= 第 12 節 =================

  testWidgets('12-1 新增通行密鑰與 12-2 通行密鑰清單', variant: _ios, (tester) async {
    final passkeys = <Map<String, dynamic>>[];
    final client = _SheetPasskeyClient();
    PasskeyService.client = client;
    PasskeyService.handoffDelay = const Duration(milliseconds: 500);
    await shoot(
      tester,
      folder: _f12,
      home: SecurityCenterScreen.new,
      routes: () {
        _securityRoutes(
          pin: true,
          passkeys: () => passkeys,
          sessions: [
            _session(1, 'iPhone 15 Pro', '101.10.49.173', current: true, created: ago(hours: 1)),
            _session(2, 'iPad Air', '114.37.152.66', current: false, created: ago(days: 12), seen: ago(days: 2)),
          ],
        );
        ManualApi.on('POST', '/users/me/passkeys/options', (_) => {
          'options': {
            'challenge': 'bWFudWFsLWNoYWxsZW5nZQ',
            'rp': {'id': 'savemybook.today', 'name': '救舊我的書'},
            'user': {'id': 'dXNlci0zMA', 'name': meEmail, 'displayName': meName},
          },
        });
        ManualApi.on('POST', '/users/me/passkeys', (_) {
          passkeys
            ..clear()
            ..add(_passkeyRow());
          return passkeys;
        });
      },
      act: (tester, snap) async {
        await settleReal(tester, const Duration(seconds: 1));
        await _scrollToBiometricPay(tester);
        await snap('表12-12-1 帳號安全');

        await tester.tap(find.text(S.addPasskey));
        await settleReal(tester, const Duration(seconds: 2));
        await snap('表12-12-1 驗證身分');

        await _tapDigits(tester, '582036');
        await settleReal(tester, const Duration(seconds: 2));
        expect(client.pending, isNotNull, reason: '未叫出建立通行密鑰的系統面板');
        await snap('表12-12-1 儲存通行密鑰');

        systemOverlay.value = const [];
        client.pending!.complete({'id': 'cred-iphone-15-pro', 'type': 'public-key'});
        await settleReal(tester, const Duration(seconds: 2));
        await snap('表12-12-2 已新增通行密鑰');

        await tester.tap(find.text(S.got));
        await settleReal(tester, const Duration(seconds: 2));
        await snap('表12-12-2 通行密鑰清單');
      },
    );
  });

  testWidgets('12-2 以通行密鑰登入', variant: _ios, (tester) async {
    await shoot(
      tester,
      folder: _f12,
      loggedIn: false,
      prefs: {'last_login_email': meEmail},
      home: LoginScreen.new,
      routes: () {
        ManualApi.on('GET', '/auth/providers', (_) => {
          'social_enabled': true,
          'providers': [
            for (final id in ['google', 'apple', 'phone', 'line', 'discord']) {'id': id, 'enabled': true, 'signup': true, 'configured': true},
          ],
        });
        ManualApi.on('GET', '/auth/passkeys/status', (_) => {'enabled': true, 'rp_id': 'savemybook.today'});
      },
      act: (tester, snap) async {
        await settleReal(tester, const Duration(seconds: 1));
        systemOverlay.value = [
          const Positioned.fill(
            child: IosPasskeySheet(
              title: 'Sign In',
              message: 'Sign in to “救舊我的書” with your passkey for “$meEmail”?',
              primary: 'Use Passkey',
              secondary: 'Sign In with Other Device',
            ),
          ),
        ];
        await tester.pump();
        await snap('表12-12-2 以通行密鑰登入');
      },
    );
  });

  testWidgets('12-3 Face ID 登入與付款', variant: _ios, (tester) async {
    await shoot(
      tester,
      folder: _f12,
      home: SecurityCenterScreen.new,
      routes: () => _securityRoutes(
        pin: true,
        passkeys: () => [_passkeyRow(lastUsed: _iso(_at(0, 0, 25, 40)))],
        sessions: [
          _session(1, 'iPhone 15 Pro', '101.10.49.173', current: true, created: ago(hours: 1)),
          _session(2, 'iPad Air', '114.37.152.66', current: false, created: ago(days: 12), seen: ago(days: 2)),
        ],
      ),
      act: (tester, snap) async {
        await settleReal(tester, const Duration(seconds: 2));
        await snap('表12-12-3 Face ID 登入與付款');
      },
    );
  });

  // ================= 第 13 節 =================

  testWidgets('13-1 會員中心', variant: _ios, (tester) async {
    await shoot(
      tester,
      folder: _f13,
      me: _snowUser,
      home: HomeScreen.new,
      routes: () {
        _snowRoutes();
        ManualApi.on('GET', '/users/me/stats', (_) => {
          'balance': 0,
          'book_count': 1,
          'favorite_count': 0,
          'unread_notification_count': 0,
          'cart_count': 0,
        });
      },
      act: (tester, snap) async {
        await tester.tap(find.descendant(of: find.byType(CustomBottomNav), matching: find.text(S.member)));
        await settleReal(tester, const Duration(seconds: 3));
        await snap('表12-13-1 會員中心');
      },
    );
  });

  testWidgets('13-1 設定交易密碼與 13-2 輸入交易密碼', variant: _ios, (tester) async {
    await shoot(
      tester,
      folder: _f13,
      me: _snowUser,
      home: SecurityCenterScreen.new,
      routes: () {
        _snowRoutes();
        _securityRoutes(
          pin: false,
          passkeys: () => const [],
          sessions: [_session(1, 'iPhone 16', '101.10.49.173', current: true, created: ago(minutes: 20))],
        );
      },
      act: (tester, snap) async {
        await settleReal(tester, const Duration(seconds: 2));
        await snap('表12-13-1 帳號安全');

        await tester.tap(find.text(S.paymentPin).last);
        await settleReal(tester, const Duration(seconds: 2));
        await snap('IMG_3948');

        final field = find.byType(TextField);
        await tester.enterText(field, _password.substring(0, _password.length - 1));
        await settle(tester, const Duration(milliseconds: 600));
        await tester.enterText(field, _password);
        await tester.pump();
        await snap('表12-13-1 驗證登入密碼');

        await tester.tap(find.text(S.confirm));
        await settleReal(tester, const Duration(seconds: 2));
        await snap('表12-13-2 設定 6 位數交易密碼');

        await _tapDigits(tester, '582036');
        await settleReal(tester, const Duration(seconds: 1));
        await snap('表12-13-2 再次輸入確認');

        await _tapDigits(tester, '582036');
        await settleReal(tester, const Duration(milliseconds: 300));
        await snap('表12-13-2 交易密碼已設定');
      },
    );
  });

  testWidgets('13-4 交易密碼錯誤', variant: _ios, (tester) async {
    var failures = 0;
    await shoot(
      tester,
      folder: _f13,
      me: _snowUser,
      home: () => BookDetailScreen(book: Book.fromJson(bookJson(_earth))),
      routes: () {
        _snowRoutes();
        ManualApi.on('GET', '/wallet', (_) => {'balance': 10000, 'frozen_amount': 0, 'total_income': 10000, 'total_expense': 0, 'pending_income': 0});
        ManualApi.on('GET', '/security', (_) => _security(pin: true));
        ManualApi.on('POST', '/security/verify', (_) {
          failures++;
          if (failures >= 5) {
            return {'success': false, 'code': 'PIN_LOCKED', 'message': '交易密碼錯誤次數過多，請 15 分鐘後再試', 'locked_until': ago(minutes: -15)};
          }
          return {'success': false, 'code': 'INVALID_PIN', 'message': '交易密碼錯誤，剩餘嘗試次數 ${5 - failures} 次', 'remaining_attempts': 5 - failures};
        });
      },
      act: (tester, snap) async {
        await _tapBuyNow(tester);
        for (final (i, file) in ['表12-13-4 交易密碼錯誤', 'IMG_3964', 'IMG_3965', '表12-13-4 剩餘 1 次嘗試'].indexed) {
          await _tapDigits(tester, ['135790', '246813', '370914', '159260'][i]);
          await settleReal(tester, const Duration(seconds: 1));
          await snap(file);
        }
        await _tapDigits(tester, '481357');
        await settleReal(tester, const Duration(seconds: 1));
        await snap('表12-13-4 暫時鎖定');
      },
    );
  });

  testWidgets('13-3 結帳時設定交易密碼', variant: _ios, (tester) async {
    await shoot(
      tester,
      folder: _f13,
      me: _snowUser,
      home: () => BookDetailScreen(book: Book.fromJson(bookJson(_brainwash))),
      routes: () {
        _snowRoutes();
        ManualApi.on('GET', '/wallet', (_) => {'balance': 10000, 'frozen_amount': 0, 'total_income': 10000, 'total_expense': 0, 'pending_income': 0});
        ManualApi.on('GET', '/security', (_) => _security(pin: false));
        ManualApi.on('POST', '/security/verify', (_) => {'verify_token': 'manual-verify-token'});
      },
      act: (tester, snap) async {
        await _tapBuyNow(tester);
        // 「直接購買」的載入圈會轉動，停在圓弧較長的畫格（比照原圖）
        await waitForImages(tester);
        await tester.pump(const Duration(milliseconds: 150));
        await capture(tester, _f13, '表12-13-3 提示先設定交易密碼');

        await tester.tap(find.text(S.setUpNow));
        await settleReal(tester, const Duration(seconds: 2));
        await snap('表12-13-3 驗證身分');

        await tester.enterText(find.byType(TextField), _password);
        await tester.pump();
        await tester.tap(find.text(S.confirm));
        await settleReal(tester, const Duration(seconds: 2));
        await snap('表12-13-3 設定交易密碼');

        // 關閉設定頁讓付款驗證結束，避免留下進行中的驗證
        navigatorKey.currentState!.pop(false);
        await settleReal(tester, const Duration(seconds: 1));
      },
    );
  });

  testWidgets('13-5 登入裝置', variant: _ios, (tester) async {
    await shoot(
      tester,
      folder: _f13,
      me: _snowUser,
      home: LoginDevicesScreen.new,
      routes: () {
        _snowRoutes();
        ManualApi.on('GET', '/security/sessions', (_) => [
          _session(1, 'iPhone 16', '101.10.49.173', current: true, created: ago(minutes: 20)),
        ]);
      },
      act: (tester, snap) async {
        await settleReal(tester, const Duration(seconds: 1));
        await snap('表12-13-5 登入裝置');
      },
    );
  });
}
