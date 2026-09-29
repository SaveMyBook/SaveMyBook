import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:savemybook_app/features/admin/admin_cabinet_deposit_screen.dart';
import 'package:savemybook_app/features/admin/admin_cabinet_device_screen.dart';
import 'package:savemybook_app/features/admin/admin_cabinet_open_sheet.dart';
import 'package:savemybook_app/features/admin/admin_cabinet_pairing_dialog.dart';
import 'package:savemybook_app/features/admin/admin_cabinet_screen.dart';
import 'package:savemybook_app/features/admin/admin_order_detail_screen.dart';
import 'package:savemybook_app/features/security/identity_verification_sheet.dart';
import 'package:savemybook_app/i18n/app_localizations.dart';
import 'package:savemybook_app/i18n/strings.dart';
import 'package:savemybook_app/models/notification_category.dart';
import 'package:savemybook_app/models/user.dart';
import 'package:savemybook_app/services/api_service.dart';
import 'package:savemybook_app/services/locale_provider.dart';
import 'package:savemybook_app/services/notification_router.dart';
import 'package:savemybook_app/services/verification_service.dart';
import 'package:savemybook_app/utils/app_theme.dart';

const _now = '2026-09-28T10:30:00.000Z';

Map<String, dynamic> _door(int slotId, String label, {String status = 'empty', String? fault, Map<String, dynamic>? check, List<Map<String, dynamic>> items = const []}) => {
      'slot_id': slotId,
      'slot_no': 'SL5T2K8Q$label',
      'label': label,
      'channel': int.parse(label.substring(1)),
      'status': status,
      'fault_code': fault,
      'sensor': null,
      'check': check,
      'items': items,
    };

Map<String, dynamic> _device(String deviceNo, {String kind = 'simulator', bool online = true, bool sensor = false, String firmware = 'sim-1.0.0'}) => {
      'device_no': deviceNo, 'kind': kind, 'status': 'active', 'online': online, 'last_seen_at': _now, 'paired_at': _now,
      'firmware': firmware, 'door_count': 4, 'has_door_sensor': sensor, 'unlock_pulse_ms': 800, 'fault_code': null,
    };

const _newDevice = 'DV8NEWK2Q';

Map<String, dynamic> _pairing() => {
      'kind': 'esp32',
      'door_count': 4,
      'has_door_sensor': true,
      'firmware': 'esp-1.0.0',
      'expires_at': DateTime.now().toUtc().add(const Duration(minutes: 10)).toIso8601String(),
    };

Map<String, dynamic> _summary({bool online = true, bool a04Checked = false, bool pairing = false, bool replaced = false, String? active}) => {
      'cabinet': {'cabinet_id': 3, 'cabinet_name': '北商大書櫃', 'is_active': true, 'is_maintenance': false, 'open_time': '08:00', 'close_time': '22:00'},
      'access': {'mode': 'scan', 'reason': null, 'online': online, 'open_now': true},
      'simulator_enabled': true,
      'kiosk_url': 'https://api.savemybook.today/kiosk',
      'device': replaced ? _device(_newDevice, kind: 'esp32', sensor: true, firmware: 'esp-1.0.0') : _device('DV3K9QX2M', online: online),
      'pairing': pairing ? _pairing() : null,
      'active_session_no': active,
      'doors': [
        _door(41, 'A01', status: 'occupied', items: [
          {'kind': 'deposit', 'book_id': 55, 'book_no': 'BK7Q2M4XA', 'title': '資料庫系統概論', 'order_id': null, 'order_no': null, 'seller_nickname': '小明', 'placed_at': _now},
        ]),
        _door(42, 'A02', check: {
          'at': _now,
          'reason': 'CANCELLED_AFTER_OPEN',
          'session_no': 'CS7Q2M4XA',
          'candidates': [
            {'book_id': 58, 'book_no': 'BK9W3E5RT', 'title': '作業系統', 'kind': 'pre_deposit'},
          ],
        }),
        _door(43, 'A03', fault: 'LOCK_NO_RELEASE'),
        _door(44, 'A04', check: a04Checked ? {'at': _now, 'reason': 'ADMIN_OPEN', 'session_no': 'CSADMIN01', 'candidates': <Object>[]} : null),
      ],
      'unplaced': [
        {'kind': 'order', 'order_id': 128, 'order_no': 'SMB20260928143015123456', 'book_id': 57, 'book_no': 'BK4R6T8YU', 'title': '計算機概論'},
      ],
    };

Map<String, dynamic> _sessionRow(String no, String status, {String kind = 'user', List<String> kinds = const ['pickup']}) => {
      'session_no': no,
      'kind': kind,
      'status': status,
      'result_code': status == 'needs_review' ? 'DEVICE_LOST' : 'COMPLETED',
      'user': {'user_no': 'MB3KER74B', 'nickname': '小華'},
      'item_kinds': kinds,
      'doors': ['A01'],
      'location_status': 'denied',
      'distance_m': null,
      'close_reason': null,
      'created_at': _now,
      'opened_at': _now,
      'finished_at': null,
    };

Map<String, dynamic> _reviewDetail() => {
      'session_no': 'CS8MZQ41K',
      'status': 'needs_review',
      'version': 5,
      'cabinet': {'cabinet_id': 3, 'cabinet_name': '北商大書櫃', 'address': '臺北市', 'latitude': 25.04, 'longitude': 121.52},
      'location_status': 'denied',
      'distance_m': null,
      'items': [
        {
          'key': 'order:130', 'kind': 'pickup', 'order_id': 130, 'order_no': 'SMB20260928143015999999',
          'books': [{'book_id': 60, 'title': '線性代數', 'image_url': null, 'door': 'A01'}],
          'doors': ['A01'], 'paused': false, 'note': null, 'selected': true, 'blocked': null, 'result': 'pending', 'error': null,
          'seller_nickname': '小明', 'buyer_nickname': '小華',
        },
      ],
      'doors': [{'label': 'A01', 'state': 'open'}],
      'remaining_ms': null,
      'open_ms': 30000,
      'result': {'outcome': 'needs_review', 'code': 'DEVICE_LOST', 'message': '書櫃連線異常，本次作業待客服確認'},
      'created_at': _now,
      'finished_at': _now,
      'kind': 'user',
      'result_code': 'DEVICE_LOST',
      'user': {'user_no': 'MB3KER74B', 'nickname': '小華'},
      'close_reason': 'user_cancel',
      'started_at': _now,
      'matched_at': _now,
      'opened_at': _now,
      'closed_at': null,
      'accuracy_m': null,
      'admin_reason': null,
      'admin_force': false,
      'doors_timeline': [
        {'label': 'A01', 'state': 'open', 'command_served_at': _now, 'opened_at': _now, 'closed_at': null, 'close_reason': null},
      ],
      'events': [
        {'type': 'match_entered', 'source': 'user', 'label': null, 'detail': {'matched': true}, 'result': 'ok', 'occurred_at': _now},
        {'type': 'door_opened', 'source': 'device', 'label': 'A01', 'detail': null, 'result': 'ok', 'occurred_at': _now},
        {'type': 'close_refused', 'source': 'device', 'label': null, 'detail': {'command_id': 12, 'code': 'DOOR_OPEN'}, 'result': 'ok', 'occurred_at': _now},
      ],
      'review': null,
    };

Map<String, dynamic> _adminDetail(String status, int version, {int? remaining, String? notice, bool force = false, Map<String, dynamic>? result}) => {
      'session_no': 'CSADMIN01',
      'status': status,
      'version': version,
      'cabinet': {'cabinet_id': 3, 'cabinet_name': '北商大書櫃'},
      'items': <Object>[],
      'doors': [{'label': 'A04', 'state': status == 'open' ? 'open' : 'pending'}],
      'remaining_ms': remaining,
      'open_ms': 120000,
      'notice': notice,
      'result': result,
      'kind': 'admin',
      'admin_reason': '測試電磁鎖',
      'admin_force': force,
      'doors_timeline': <Object>[],
      'events': <Object>[],
      'review': null,
    };

(int, Map<String, dynamic>) _fail(int status, String code, String message, [Map<String, dynamic> extra = const {}]) =>
    (status, {'success': false, 'code': code, 'message': message, ...extra});

class _FakeServer {
  final List<String> requests = [];
  final Map<String, Map<String, dynamic>> bodies = {};
  final Map<String, String?> verifyTokens = {};
  bool a04Checked = false;
  bool cooldown = false;
  bool rateLimited = false;
  bool pairExpires = false;
  bool paired = false;
  int pairPolls = 0;
  String adminStage = 'matching';
  String? active;

  MockClient get client => MockClient((req) async {
        final path = req.url.path.replaceFirst('/api', '');
        final key = '${req.method} $path';
        requests.add(key);
        final body = req.body.isEmpty ? const <String, dynamic>{} : Map<String, dynamic>.from(jsonDecode(req.body) as Map);
        if (req.body.isNotEmpty) bodies[key] = body;
        verifyTokens[key] = req.headers['X-Verify-Token'];
        final (status, payload) = _route(req.method, path, req.url.queryParameters, body);
        return http.Response(jsonEncode(payload), status, headers: {'content-type': 'application/json; charset=utf-8'});
      });

  (int, Map<String, dynamic>) _ok(Object? data, {int status = 200, String? message}) => (
        status,
        {
          'success': true,
          'message': ?message,
          'data': data,
          if (data is List) 'pagination': {'total': data.length, 'page': 1, 'limit': 20, 'total_pages': 1},
        },
      );

  (int, Map<String, dynamic>) _adminSession() {
    switch (adminStage) {
      case 'opening':
        adminStage = 'open';
        return _ok(_adminDetail('open', 4, remaining: 118000));
      case 'open':
        return _ok(_adminDetail('open', 4, remaining: 118000));
      case 'closing':
        adminStage = 'refused';
        return _ok(_adminDetail('open', 6, remaining: 100000, notice: 'CLOSE_DOOR_FIRST'));
      case 'refused':
        return _ok(_adminDetail('open', 6, remaining: 100000, notice: 'CLOSE_DOOR_FIRST'));
      case 'done':
        a04Checked = true;
        return _ok(_adminDetail('completed', 8, result: {'outcome': 'completed', 'code': 'COMPLETED', 'message': '作業完成'}));
    }
    return _ok(_adminDetail('matching', 2, remaining: 58000));
  }

  (int, Map<String, dynamic>) _route(String method, String path, Map<String, String> query, Map<String, dynamic> body) {
    switch ('$method $path') {
      case 'GET /security':
        return _ok({'available': true, 'has_password': true, 'has_payment_pin': false, 'biometric_pay_enabled': false});
      case 'POST /security/verify':
        if (body['password'] != 'Passw0rd123') return _fail(400, 'INVALID_PASSWORD', '密碼錯誤');
        return _ok({'verify_token': 'admin-token', 'scope': 'admin', 'expires_in': 300});
      case 'GET /admin/cabinets/3/device':
        if (paired) {
          pairPolls++;
          if (pairPolls < 2) return _ok(_summary(pairing: true));
          return _ok(pairExpires ? _summary() : _summary(replaced: true));
        }
        return _ok(_summary(a04Checked: a04Checked, active: active));
      case 'POST /admin/cabinets/3/device/pair':
        if (body['code'] == '00000000') return _fail(400, 'PAIRING_CODE_INVALID', '配對碼無效或已逾時');
        if (body['code'] == '99999999') return _fail(429, 'RATE_LIMITED', '嘗試次數過多，請稍後再試');
        paired = true;
        pairPolls = 0;
        return _ok(
          {'kind': 'esp32', 'door_count': 4, 'has_door_sensor': true, 'firmware': 'esp-1.0.0', 'summary': _summary(pairing: true)},
          status: 201,
          message: '已送出配對，裝置連線後即完成',
        );
      case 'GET /admin/cabinets/3/manual-reports':
        return _ok([
          {
            'report_no': 'MR4K2Q8ZT', 'kind': 'deposit', 'status': 'pending', 'target_status': 'deposited', 'reason': 'offline',
            'created_at': _now, 'reviewed_at': null, 'review_note': null,
            'user': {'user_no': 'MB3KER74B', 'nickname': '小華'},
            'order': {'order_id': 128, 'order_no': 'SMB20260928143015123456', 'status': 'pending_deposit'},
            'book': null, 'titles': ['計算機概論'], 'requires_door': true, 'reviewer_nickname': null,
          },
        ]);
      case 'GET /admin/cabinets/3/sessions':
        if (query['status'] == 'review') return _ok([_sessionRow('CS8MZQ41K', 'needs_review')]);
        return _ok([
          _sessionRow('CS8MZQ41K', 'needs_review'),
          _sessionRow('CS2B7N5PL', 'completed', kinds: ['order_deposit']),
        ]);
      case 'GET /admin/cabinets/3/events':
        return _ok([
          {'type': 'fault', 'source': 'device', 'channel': 3, 'label': 'A03', 'detail': {'code': 'LOCK_NO_RELEASE'}, 'occurred_at': _now},
          {'type': 'connection_restored', 'source': 'server', 'channel': null, 'label': null, 'detail': {'offline_ms': 125000}, 'occurred_at': _now},
          {'type': 'revoked', 'source': 'server', 'channel': null, 'label': null, 'detail': {'reason': 'simulator_off'}, 'occurred_at': _now},
          {'type': 'match_entered', 'source': 'admin', 'channel': null, 'label': null, 'detail': {'matched': false}, 'session_no': 'CSADMIN01', 'occurred_at': _now},
        ]);
      case 'GET /admin/cabinet-sessions/CS8MZQ41K':
        return _ok(_reviewDetail());
      case 'POST /admin/cabinet-sessions/CS8MZQ41K/resolve':
        return _ok(_reviewDetail());
      case 'POST /admin/cabinets/3/doors/44/open':
        if (rateLimited) return _fail(429, 'RATE_LIMITED', '操作過於頻繁，請稍後再試');
        final force = body['force'] == true;
        if (cooldown && !force) return _fail(429, 'CABINET_COOLDOWN', '數字確認多次未完成，請於 3 分鐘後再試', {'retry_after_s': 125});
        adminStage = force ? 'opening' : 'matching';
        return _ok({'session_no': 'CSADMIN01', 'status': force ? 'opening' : 'matching', 'remaining_ms': force ? 10000 : 60000}, status: 201);
      case 'GET /admin/cabinet-sessions/CSADMIN01':
        return _adminSession();
      case 'POST /admin/cabinet-sessions/CSADMIN01/match':
        if (body['code'] != '37') {
          adminStage = 'failed';
          return _ok(_adminDetail('failed', 3, result: {'outcome': 'failed', 'code': 'MATCH_FAILED', 'message': '數字不符，本次作業已取消'}));
        }
        adminStage = 'opening';
        return _ok(_adminDetail('opening', 3));
      case 'POST /admin/cabinet-sessions/CSADMIN01/close':
        adminStage = 'closing';
        return _ok(_adminDetail('open', 5, remaining: 101000), message: '已要求書櫃結束作業');
      case 'POST /admin/cabinet-manual-reports/MR4K2Q8ZT/reject':
        return (409, {'success': false, 'code': 'MANUAL_REPORT_SELF_REVIEW', 'message': '此手動回報與您本人相關，須由其他管理員處理'});
      case 'GET /admin/cabinets/deposits':
        return _ok([
          {
            'book_id': 55, 'book_no': 'BK7Q2M4XA', 'title': '資料庫系統概論', 'book_status': 'on_sale', 'image_url': null,
            'seller': {'user_id': 2, 'user_no': 'MB7Q2XK9D', 'nickname': '小明', 'avatar_url': null, 'deleted': false},
            'cabinet': {'cabinet_id': 3, 'cabinet_name': '北商大書櫃'},
            'door': {'slot_id': 41, 'label': 'A01'},
            'deposited_at': _now, 'days_stored': 15, 'paused': false, 'escalated': true, 'overdue': true,
          },
        ]);
      case 'GET /admin/cabinets':
        return _ok([
          {
            'cabinet_id': 3, 'cabinet_name': '北商大書櫃', 'address': '臺北市中正區濟南路一段 321 號', 'latitude': 25.04, 'longitude': 121.52,
            'total_slots': 4, 'available_slots': 1, 'is_active': true, 'slot_summary': {'empty': 1, 'occupied': 1},
            'device': {'device_no': 'DV3K9QX2M', 'kind': 'esp32', 'status': 'active', 'online': false, 'last_seen_at': _now},
            'cabinet_slots': [
              {'slot_id': 1, 'slot_number': 'B01', 'status': 'empty', 'lock_channel': null},
              {'slot_id': 41, 'slot_number': 'A01', 'status': 'occupied', 'lock_channel': 1},
              {'slot_id': 42, 'slot_number': 'A02', 'status': 'empty', 'lock_channel': 2, 'check_required_at': _now},
            ],
          },
        ]);
      case 'GET /admin/orders/7':
        return _ok({
          'order_id': 7, 'order_no': 'SMB20260928143015123456', 'status': 'deposited', 'total_amount': 350, 'created_at': _now,
          'buyer': {'user_id': 1, 'nickname': '小華'}, 'seller': {'user_id': 2, 'nickname': '小明'},
          'cabinet': {'cabinet_id': 3, 'cabinet_name': '北商大書櫃', 'address': '臺北市'},
          'items': [{'book_id': 5, 'title': '資料庫系統概論', 'unit_price': 350, 'subtotal': 350, 'quantity': 1, 'image_url': null}],
          'slot': null,
          'doors': ['A02', 'A03'],
          'timeline': {'created_at': _now},
          'refunds': <Object>[], 'disputes': <Object>[], 'wallet_transactions': <Object>[],
        });
    }
    if (method == 'GET') return _ok(<Object>[]);
    return _ok(<String, Object>{});
  }
}

Widget _host(Widget child, {GlobalKey<NavigatorState>? navigatorKey}) => MaterialApp(
      navigatorKey: navigatorKey,
      locale: const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      supportedLocales: LocaleProvider.supported,
      theme: AppTheme.build(Brightness.light),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, inner) {
        S = AppLocalizations.of(context);
        return inner ?? const SizedBox.shrink();
      },
      home: child,
    );

Future<void> _settle(WidgetTester tester, [int frames = 6]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 4));
}

void _tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 4200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _enter(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField).last, text);
  await tester.pump();
}

Future<void> _openDoorMenu(WidgetTester tester, String label) async {
  await tester.pump(const Duration(seconds: 3));
  final index = ['A01', 'A02', 'A03', 'A04'].indexOf(label);
  await tester.tap(find.byTooltip(S.moreActions).at(index));
  await _settle(tester);
}

void main() {
  late _FakeServer server;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    VerificationService.clearCache();
    ApiService.authToken = 'token';
    ApiService.currentUser = User.fromJson({'user_id': 9, 'nickname': '管理員', 'email': 'a@x.com', 'role': 'admin'});
    server = _FakeServer();
  });

  group('後台書櫃裝置管理', () {
    testWidgets('摘要顯示裝置、櫃門、待確認內容、未登記項目、手動回報與作業紀錄', (tester) async {
      _tallView(tester);
      await http.runWithClient(() async {
        await tester.pumpWidget(_host(const AdminCabinetDeviceScreen(cabinetId: 3)));
        await _settle(tester);

        expect(find.text('北商大書櫃'), findsOneWidget);
        expect(find.text(S.online), findsOneWidget);
        expect(find.text(S.scanningRequired), findsOneWidget);
        expect(find.text('DV3K9QX2M'), findsOneWidget);
        expect(find.text(S.simulator), findsOneWidget);
        expect(find.text(S.simulatorUrl), findsOneWidget, reason: '模擬書櫃顯示網址供開啟模擬畫面');
        expect(find.text('https://api.savemybook.today/kiosk'), findsOneWidget);
        expect(find.byTooltip(S.copyLink2), findsOneWidget);

        for (final label in ['A01', 'A02', 'A03', 'A04']) {
          expect(find.text(label), findsOneWidget);
        }
        expect(find.text('資料庫系統概論'), findsOneWidget);
        expect(find.text(S.contentsNeedChecking), findsOneWidget);
        expect(find.textContaining(S.dropOffCancelledAfterDoorOpened), findsOneWidget);
        expect(find.text(S.booksMayInside), findsOneWidget);
        expect(find.text('・作業系統'), findsOneWidget);
        expect(find.text(S.faultP0(S.lockDidNotRelease)), findsOneWidget);
        expect(find.text(S.noContentsRecorded), findsNWidgets(3));

        expect(find.text(S.itemsWithoutDoorRecord), findsOneWidget);
        expect(find.text('計算機概論'), findsNWidgets(2), reason: '未登記項目與手動回報的書名');
        expect(find.text(S.manualReportsConfirm), findsOneWidget);
        expect(find.text(S.dropOffReport), findsOneWidget);
        expect(find.textContaining(S.deviceOffline), findsOneWidget);
        expect(find.text(S.tasksConfirm), findsOneWidget);
        expect(find.textContaining('CS8MZQ41K'), findsOneWidget);

        expect(find.text(S.recentTasks), findsOneWidget);
        expect(find.text(S.orderDropOff), findsOneWidget);
        await tester.tap(find.text(S.eventLog));
        await _settle(tester);
        expect(find.text(S.fault), findsOneWidget);
        expect(find.text('A03・${S.lockDidNotRelease}'), findsOneWidget);
        expect(find.text(S.offlineP0('02:05')), findsOneWidget, reason: '恢復連線事件顯示離線時間');
        expect(find.text(S.simulatorTurnedOff), findsOneWidget, reason: '撤銷事件顯示撤銷原因');
        expect(find.text(S.matchCodeEntered), findsOneWidget);
        expect(find.text('${S.numberDidNotMatch}・CSADMIN01'), findsOneWidget, reason: '比對事件只顯示是否相符');
        await _finish(tester);
      }, () => server.client);
    });

    testWidgets('配對裝置：先驗證身分，再輸入書櫃螢幕上的配對碼，核對裝置回報的資訊並等待裝置連線', (tester) async {
      _tallView(tester);
      await http.runWithClient(() async {
        await tester.pumpWidget(_host(const AdminCabinetDeviceScreen(cabinetId: 3)));
        await _settle(tester);

        await tester.tap(find.text(S.pairDevice));
        await _settle(tester);
        expect(find.byType(IdentityVerificationSheet), findsOneWidget, reason: '先驗證身分才輸入配對碼');
        expect(find.text(S.enterPairingCodeShownLockerScreen), findsNothing);
        await tester.enterText(find.byType(TextField), 'Passw0rd123');
        await tester.tap(find.widgetWithText(ElevatedButton, S.verifyS));
        await _settle(tester);

        expect(find.text(S.enterPairingCodeShownLockerScreen), findsOneWidget);
        await _enter(tester, '1234');
        await tester.tap(find.text(S.pairDevice).last);
        await _settle(tester, 2);
        expect(find.text(S.enter8DigitPairingCode), findsOneWidget);
        expect(server.requests.where((r) => r.endsWith('/device/pair')), isEmpty, reason: '格式不符不送出');

        await _enter(tester, 'A1234-5678');
        expect(find.text('1234-5678'), findsOneWidget, reason: '只接受數字、空白與連字號');
        expect(find.textContaining('/9'), findsNothing, reason: '不顯示字數計數');
        await tester.tap(find.text(S.pairDevice).last);
        await _settle(tester);
        expect(server.bodies['POST /admin/cabinets/3/device/pair'], {'code': '12345678'});
        expect(server.verifyTokens['POST /admin/cabinets/3/device/pair'], 'admin-token');

        expect(find.byType(AdminCabinetPairingDialog), findsOneWidget);
        final dialog = find.byType(AlertDialog);
        expect(find.descendant(of: dialog, matching: find.text(S.physicalLocker)), findsOneWidget);
        expect(find.descendant(of: dialog, matching: find.text('4')), findsOneWidget);
        expect(find.descendant(of: dialog, matching: find.text(S.installed)), findsOneWidget);
        expect(find.descendant(of: dialog, matching: find.text('esp-1.0.0')), findsOneWidget);
        expect(find.text(S.waitingDeviceConnect), findsOneWidget);

        await tester.pump(AdminCabinetPairingDialog.pollInterval);
        await _settle(tester, 2);
        expect(server.pairPolls, 1);
        expect(find.text(S.waitingDeviceConnect), findsOneWidget);

        await tester.pump(AdminCabinetPairingDialog.pollInterval);
        await _settle(tester, 2);
        expect(server.pairPolls, 2);
        expect(find.text(S.paired), findsOneWidget);
        expect(find.text(S.waitingDeviceConnect), findsNothing);

        await tester.tap(find.text(S.actionClose));
        await _settle(tester);
        expect(find.byType(AdminCabinetPairingDialog), findsNothing);
        expect(find.text(_newDevice), findsOneWidget);
        await _finish(tester);
      }, () => server.client);
    });

    testWidgets('配對逾時顯示失敗並可重新輸入配對碼；配對碼無效或嘗試過多時顯示對應訊息', (tester) async {
      _tallView(tester);
      server.pairExpires = true;
      await http.runWithClient(() async {
        await tester.pumpWidget(_host(const AdminCabinetDeviceScreen(cabinetId: 3)));
        await _settle(tester);

        await tester.tap(find.text(S.pairDevice));
        await _settle(tester);
        await tester.enterText(find.byType(TextField), 'Passw0rd123');
        await tester.tap(find.widgetWithText(ElevatedButton, S.verifyS));
        await _settle(tester);
        await _enter(tester, '00000000');
        await tester.tap(find.text(S.pairDevice).last);
        await _settle(tester);
        expect(find.text(S.pairingCodeInvalidExpired), findsOneWidget);
        expect(find.byType(AdminCabinetPairingDialog), findsNothing);
        await tester.pump(const Duration(seconds: 4));

        await tester.tap(find.text(S.pairDevice));
        await _settle(tester);
        expect(find.byType(IdentityVerificationSheet), findsNothing, reason: '驗證效期內不重複驗證');
        await _enter(tester, '9999 9999');
        await tester.tap(find.text(S.pairDevice).last);
        await _settle(tester);
        expect(find.text(S.tooManyAttemptsPleaseTryAgain), findsOneWidget);
        await tester.pump(const Duration(seconds: 4));

        await tester.tap(find.text(S.pairDevice));
        await _settle(tester);
        await _enter(tester, '12345678');
        await tester.tap(find.text(S.pairDevice).last);
        await _settle(tester);
        expect(find.text(S.waitingDeviceConnect), findsOneWidget);

        await tester.pump(AdminCabinetPairingDialog.pollInterval);
        await _settle(tester, 2);
        await tester.pump(AdminCabinetPairingDialog.pollInterval);
        await _settle(tester, 2);
        expect(find.text(S.pairingWasNotCompletedEnterNew), findsOneWidget);
        expect(find.text(S.paired), findsNothing);

        await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text(S.pairDevice)).last);
        await _settle(tester);
        expect(find.byType(AdminCabinetPairingDialog), findsNothing);
        expect(find.text(S.enterPairingCodeShownLockerScreen), findsOneWidget, reason: '重新輸入新的配對碼');
        expect(server.requests.where((r) => r == 'POST /security/verify').length, 1);
        await tester.tap(find.text(S.actionCancel));
        await _settle(tester);
        await _finish(tester);
      }, () => server.client);
    });

    testWidgets('撤銷裝置前須確認', (tester) async {
      _tallView(tester);
      await http.runWithClient(() async {
        await tester.pumpWidget(_host(const AdminCabinetDeviceScreen(cabinetId: 3)));
        await _settle(tester);

        await tester.tap(find.text(S.revokeDevice));
        await _settle(tester);
        expect(find.text(S.onceRevokedDeviceCanNoLonger('北商大書櫃')), findsOneWidget);
        await tester.tap(find.text(S.actionCancel));
        await _settle(tester);
        expect(server.requests, isNot(contains('DELETE /admin/cabinets/3/device')));

        await tester.tap(find.text(S.revokeDevice));
        await _settle(tester);
        await tester.tap(find.text(S.revokeDevice).last);
        await _settle(tester);
        expect(server.requests, contains('DELETE /admin/cabinets/3/device'));
        expect(find.text(S.deviceRevoked), findsOneWidget);
        await _finish(tester);
      }, () => server.client);
    });

    testWidgets('待確認櫃門可確認內容無誤、登記存放內容或清空紀錄，選單呼叫對應端點', (tester) async {
      _tallView(tester);
      await http.runWithClient(() async {
        await tester.pumpWidget(_host(const AdminCabinetDeviceScreen(cabinetId: 3)));
        await _settle(tester);

        await _openDoorMenu(tester, 'A02');
        expect(find.text(S.confirmContents), findsOneWidget);
        expect(find.text(S.clearContentsRecord), findsNothing, reason: '沒有存放紀錄時不提供清空');
        await tester.tap(find.text(S.confirmContents));
        await _settle(tester);
        await _enter(tester, '現場確認無書');
        await tester.tap(find.text(S.confirmContents).last);
        await _settle(tester);
        expect(server.bodies['POST /admin/cabinets/3/doors/42/check-clear'], {'note': '現場確認無書'});

        await _openDoorMenu(tester, 'A02');
        await tester.tap(find.text(S.recordContents).last);
        await _settle(tester);
        expect(find.text(S.selectItemsActuallyStoredDoor), findsOneWidget);
        await tester.tap(find.text('作業系統').last);
        await _settle(tester, 2);
        await tester.tap(find.widgetWithText(ElevatedButton, S.recordContents));
        await _settle(tester);
        expect(server.bodies['POST /admin/cabinets/3/doors/42/place'], {'book_ids': [58]});

        await _openDoorMenu(tester, 'A01');
        expect(find.text(S.confirmContents), findsNothing, reason: '非待確認櫃門不提供確認內容');
        await tester.tap(find.text(S.clearContentsRecord));
        await _settle(tester);
        await tester.tap(find.text(S.booksRemoved));
        await _settle(tester);
        expect(find.text(S.confirmStaffRemovedBooksFromDoor('A01')), findsOneWidget);
        await tester.tap(find.text(S.clearContentsRecord).last);
        await _settle(tester);
        expect(server.requests.where((r) => r.endsWith('/doors/41/clear')), isEmpty, reason: '清空原因必填');
        await _enter(tester, '派員取出');
        await tester.tap(find.text(S.clearContentsRecord).last);
        await _settle(tester);
        expect(server.bodies['POST /admin/cabinets/3/doors/41/clear'], {'mode': 'removed', 'reason': '派員取出'});

        await _openDoorMenu(tester, 'A01');
        await tester.tap(find.text(S.clearContentsRecord));
        await _settle(tester);
        await tester.tap(find.text(S.correctRecordOnly));
        await _settle(tester);
        expect(find.text(S.confirmTheseBooksNotActuallyDoor('A01')), findsOneWidget);
        await _enter(tester, '紀錄有誤');
        await tester.tap(find.text(S.clearContentsRecord).last);
        await _settle(tester);
        expect(server.bodies['POST /admin/cabinets/3/doors/41/clear'], {'mode': 'correct', 'reason': '紀錄有誤'});

        await _openDoorMenu(tester, 'A03');
        await tester.tap(find.text(S.clearFault));
        await _settle(tester);
        expect(server.requests, contains('POST /admin/cabinets/3/doors/43/fault-clear'));

        await _openDoorMenu(tester, 'A04');
        await tester.tap(find.text(S.markLockerMaintenance));
        await _settle(tester);
        await tester.tap(find.text(S.markLockerMaintenance).last);
        await _settle(tester);
        expect(server.bodies['PATCH /admin/cabinets/3/slots/44'], {'status': 'maintenance'});

        await tester.pump(const Duration(seconds: 3));
        await tester.tap(find.text(S.recordContents).first);
        await _settle(tester);
        await tester.tap(find.textContaining('${S.doorP0('A04')}・'));
        await _settle(tester);
        expect(server.bodies['POST /admin/cabinets/3/doors/44/place'], {'book_ids': [57]});
        await _finish(tester);
      }, () => server.client);
    });

    testWidgets('處理待確認作業：確認已完成須填寫處理說明', (tester) async {
      _tallView(tester);
      await http.runWithClient(() async {
        await tester.pumpWidget(_host(const AdminCabinetDeviceScreen(cabinetId: 3)));
        await _settle(tester);

        await tester.tap(find.textContaining('CS8MZQ41K'));
        await _settle(tester);
        expect(find.text(S.taskDetails), findsOneWidget);
        expect(find.text(S.thereWasLockerConnectionProblemSupport), findsOneWidget);
        expect(find.textContaining(S.buyerP0SellerP1('小華', '小明')), findsOneWidget);
        expect(find.text(S.locationNotPermitted), findsOneWidget);
        expect(find.text(S.cancelledPhone), findsOneWidget);
        expect(find.text(S.matchCodeEntered), findsOneWidget, reason: '進度顯示輸入比對碼的時間');
        expect(find.text('${S.matchCodeEntered}・${S.numberMatched}'), findsOneWidget);
        expect(find.text(S.lockerRefusedEndDoorOpen), findsOneWidget);

        await tester.tap(find.text(S.markAsCompleted));
        await _settle(tester);
        expect(find.text(S.ordersDropOffsUpdatedAccordingTask), findsOneWidget);
        await tester.tap(find.text(S.markAsCompleted).last);
        await _settle(tester);
        expect(find.text(S.actionRequired), findsOneWidget);
        await _enter(tester, '已確認買家取書');
        await tester.tap(find.text(S.markAsCompleted).last);
        await _settle(tester);

        expect(server.bodies['POST /admin/cabinet-sessions/CS8MZQ41K/resolve'], {'action': 'commit', 'note': '已確認買家取書'});
        expect(find.text(S.taskDetails), findsNothing);
        expect(find.text(S.reportResolved), findsOneWidget);
        await _finish(tester);
      }, () => server.client);
    });

    testWidgets('手動回報：確認存書回報須指定櫃門；駁回須填寫說明並顯示伺服器訊息', (tester) async {
      _tallView(tester);
      await http.runWithClient(() async {
        await tester.pumpWidget(_host(const AdminCabinetDeviceScreen(cabinetId: 3)));
        await _settle(tester);

        await tester.tap(find.text(S.confirmReport));
        await _settle(tester);
        expect(find.text(S.selectDoorWhereBooksActuallyStored), findsOneWidget);
        await tester.tap(find.textContaining('${S.doorP0('A02')}・'));
        await _settle(tester);
        expect(find.text(S.ordersDropOffsUpdatedAsReported), findsOneWidget);
        await tester.tap(find.text(S.confirmReport).last);
        await _settle(tester);
        expect(server.bodies['POST /admin/cabinet-manual-reports/MR4K2Q8ZT/confirm'], {'slot_id': 42});
        expect(find.text(S.manualReportConfirmed), findsOneWidget);
        await tester.pump(const Duration(seconds: 3));

        await tester.tap(find.text(S.rejectReport));
        await _settle(tester);
        await tester.tap(find.text(S.rejectReport).last);
        await _settle(tester);
        expect(server.requests.where((r) => r.endsWith('/reject')), isEmpty);
        await _enter(tester, '與實際不符');
        await tester.tap(find.text(S.rejectReport).last);
        await _settle(tester);
        expect(server.bodies['POST /admin/cabinet-manual-reports/MR4K2Q8ZT/reject'], {'note': '與實際不符'});
        expect(find.text('此手動回報與您本人相關，須由其他管理員處理'), findsOneWidget);
        await _finish(tester);
      }, () => server.client);
    });

    testWidgets('遠端開櫃：有存放紀錄的櫃門不可直接開啟；送出後輸入書櫃螢幕上的數字，開門後可結束作業', (tester) async {
      _tallView(tester);
      await http.runWithClient(() async {
        await tester.pumpWidget(_host(const AdminCabinetDeviceScreen(cabinetId: 3)));
        await _settle(tester);

        await _openDoorMenu(tester, 'A01');
        await tester.tap(find.text(S.openDoorRemotely));
        await _settle(tester);
        expect(find.byType(AdminCabinetOpenSheet), findsOneWidget);
        expect(find.text(S.openWithoutNumberConfirmation), findsNothing);
        Navigator.of(tester.element(find.byType(AdminCabinetOpenSheet))).pop();
        await _settle(tester);

        await _openDoorMenu(tester, 'A02');
        await tester.tap(find.text(S.openDoorRemotely));
        await _settle(tester);
        expect(find.text(S.openWithoutNumberConfirmation), findsNothing, reason: '待確認的櫃門不可直接開啟');
        Navigator.of(tester.element(find.byType(AdminCabinetOpenSheet))).pop();
        await _settle(tester);

        await _openDoorMenu(tester, 'A04');
        await tester.tap(find.text(S.openDoorRemotely));
        await _settle(tester);
        expect(find.text(S.openWithoutNumberConfirmation), findsOneWidget);
        expect(find.text(S.onlyDoorsWithNoRecordedContents), findsOneWidget);
        await tester.tap(find.widgetWithText(ElevatedButton, S.openDoor));
        await _settle(tester, 2);
        expect(server.requests.where((r) => r.endsWith('/open')), isEmpty, reason: '開啟原因必填');

        await _enter(tester, '測試電磁鎖');
        await tester.tap(find.widgetWithText(ElevatedButton, S.openDoor));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
        expect(server.bodies['POST /admin/cabinets/3/doors/44/open'], {'reason': '測試電磁鎖', 'force': false});
        expect(find.text(S.enterNumberShownLockerScreen), findsOneWidget);
        expect(find.text(S.p0SRemaining(60)), findsOneWidget);
        final confirm = find.widgetWithText(ElevatedButton, S.confirm);
        expect(tester.widget<ElevatedButton>(confirm).onPressed, isNull, reason: '輸入兩位數字前不可確認');

        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.text(S.p0SRemaining(58)), findsOneWidget);

        await _enter(tester, '0a7');
        expect(find.text('07'), findsOneWidget, reason: '只接受數字');
        await tester.tap(confirm);
        await tester.pump();
        expect(find.text(S.enterTwoDigits), findsOneWidget);
        expect(server.requests.where((r) => r.endsWith('/match')), isEmpty, reason: '格式不符不送出，也不消耗比對機會');

        await _enter(tester, '37');
        expect(find.text(S.enterTwoDigits), findsNothing);
        await tester.tap(confirm);
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
        expect(server.bodies['POST /admin/cabinet-sessions/CSADMIN01/match'], {'code': '37'});
        expect(find.text(S.openingDoor), findsOneWidget);
        expect(find.text('37'), findsNothing, reason: '比對碼不得顯示於畫面');

        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.text(S.doorOpened), findsOneWidget);
        expect(find.text(S.p0SRemaining(118)), findsOneWidget);
        expect(find.text(S.closeDoorFirst), findsNothing);

        await tester.tap(find.widgetWithText(ElevatedButton, S.endTask));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
        expect(server.requests, contains('POST /admin/cabinet-sessions/CSADMIN01/close'));
        expect(find.text(S.lockerBeenAskedEndTask), findsOneWidget);

        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.text(S.closeDoorFirst), findsOneWidget);
        expect(find.text(S.taskCompleteAutomaticallyOnceDoorClosed), findsOneWidget);
        expect(find.byType(AdminCabinetOpenSheet), findsOneWidget);

        server.adminStage = 'done';
        await tester.pump(const Duration(seconds: 1));
        await _settle(tester);
        expect(find.byType(AdminCabinetOpenSheet), findsNothing);
        expect(find.text(S.checkContentsDoorP0('A04')), findsWidgets);
        expect(find.textContaining(S.openedByStaff), findsOneWidget);
        await _finish(tester);
      }, () => server.client);
    });

    testWidgets('遠端開櫃：關閉面板後由進行中作業回到數字輸入與結束作業；其他管理員仍開啟作業詳情', (tester) async {
      _tallView(tester);
      await http.runWithClient(() async {
        await tester.pumpWidget(_host(const AdminCabinetDeviceScreen(cabinetId: 3)));
        await _settle(tester);

        await _openDoorMenu(tester, 'A04');
        await tester.tap(find.text(S.openDoorRemotely));
        await _settle(tester);
        await _enter(tester, '測試電磁鎖');
        await tester.tap(find.widgetWithText(ElevatedButton, S.openDoor));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text(S.enterNumberShownLockerScreen), findsOneWidget);

        server.active = 'CSADMIN01';
        await tester.tap(find.text(S.actionClose));
        await _settle(tester);
        expect(find.byType(AdminCabinetOpenSheet), findsNothing);
        expect(server.requests.where((r) => r.endsWith('/match')), isEmpty);

        await tester.tap(find.text(S.taskProgressP0('CSADMIN01')));
        await _settle(tester, 2);
        expect(find.byType(AdminCabinetOpenSheet), findsOneWidget, reason: '本人發起的作業重新開啟遠端開櫃面板');
        expect(find.text(S.taskDetails), findsNothing);
        expect(find.text(S.enterNumberShownLockerScreen), findsOneWidget);
        await _enter(tester, '37');
        await tester.tap(find.widgetWithText(ElevatedButton, S.confirm));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
        expect(server.bodies['POST /admin/cabinet-sessions/CSADMIN01/match'], {'code': '37'});
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.text(S.doorOpened), findsOneWidget);

        await tester.tap(find.text(S.actionClose));
        await _settle(tester);
        await tester.tap(find.text(S.taskProgressP0('CSADMIN01')));
        await _settle(tester, 2);
        expect(find.text(S.doorOpened), findsOneWidget);
        await tester.tap(find.widgetWithText(ElevatedButton, S.endTask));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
        expect(server.requests, contains('POST /admin/cabinet-sessions/CSADMIN01/close'));
        await tester.pump(const Duration(seconds: 3));
        await _settle(tester);
        await tester.tap(find.text(S.actionClose));
        await _settle(tester);

        ApiService.currentUser = User.fromJson({'user_id': 10, 'nickname': '其他管理員', 'email': 'b@x.com', 'role': 'admin'});
        await tester.tap(find.text(S.taskProgressP0('CSADMIN01')));
        await _settle(tester);
        expect(find.byType(AdminCabinetOpenSheet), findsNothing);
        expect(find.text(S.taskDetails), findsOneWidget);
        await _finish(tester);
      }, () => server.client);
    });

    testWidgets('遠端開櫃：數字不符即結束作業，只有一次機會', (tester) async {
      _tallView(tester);
      await http.runWithClient(() async {
        await tester.pumpWidget(_host(const AdminCabinetDeviceScreen(cabinetId: 3)));
        await _settle(tester);

        await _openDoorMenu(tester, 'A04');
        await tester.tap(find.text(S.openDoorRemotely));
        await _settle(tester);
        await _enter(tester, '測試電磁鎖');
        await tester.tap(find.widgetWithText(ElevatedButton, S.openDoor));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));

        await _enter(tester, '42');
        await tester.tap(find.widgetWithText(ElevatedButton, S.confirm));
        await _settle(tester);
        expect(server.bodies['POST /admin/cabinet-sessions/CSADMIN01/match'], {'code': '42'});
        expect(find.byType(AdminCabinetOpenSheet), findsNothing);
        expect(find.text(S.numberDidNotMatchTaskBeen), findsOneWidget);
        expect(server.requests.where((r) => r.endsWith('/match')).length, 1);
        await _finish(tester);
      }, () => server.client);
    });

    testWidgets('遠端開櫃：數字確認多次未完成時停用開門，不經數字確認的開啟不受影響；請求過多顯示訊息', (tester) async {
      _tallView(tester);
      server.rateLimited = true;
      await http.runWithClient(() async {
        await tester.pumpWidget(_host(const AdminCabinetDeviceScreen(cabinetId: 3)));
        await _settle(tester);

        await _openDoorMenu(tester, 'A04');
        await tester.tap(find.text(S.openDoorRemotely));
        await _settle(tester);
        await _enter(tester, '測試電磁鎖');
        await tester.tap(find.widgetWithText(ElevatedButton, S.openDoor));
        await _settle(tester, 2);
        expect(find.text(S.tooManyRequestsPleaseTryAgain), findsOneWidget);
        expect(find.text(S.enterNumberShownLockerScreen), findsNothing);

        server.rateLimited = false;
        server.cooldown = true;
        await tester.pump(const Duration(seconds: 3));
        await _settle(tester);
        await tester.tap(find.widgetWithText(ElevatedButton, S.openDoor));
        await _settle(tester, 2);
        expect(find.text(S.numberConfirmationWasNotCompletedSeveral(3)), findsOneWidget);
        final open = find.widgetWithText(ElevatedButton, S.openDoor);
        expect(tester.widget<ElevatedButton>(open).onPressed, isNull);

        await tester.tap(find.byType(Switch));
        await tester.pump();
        expect(find.text(S.numberConfirmationWasNotCompletedSeveral(3)), findsNothing);
        expect(tester.widget<ElevatedButton>(open).onPressed, isNotNull);
        await tester.tap(open);
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
        expect(server.bodies['POST /admin/cabinets/3/doors/44/open'], {'reason': '測試電磁鎖', 'force': true});
        expect(find.text(S.openCommandSent), findsOneWidget);
        expect(find.text(S.openingDoor), findsOneWidget);
        expect(find.byType(TextField), findsNothing, reason: '不經數字確認時不顯示數字輸入');
        await tester.pump(const Duration(seconds: 3));
        await _settle(tester);
        await tester.tap(find.text(S.actionClose));
        await _settle(tester);
        expect(find.byType(AdminCabinetOpenSheet), findsNothing);
        await _finish(tester);
      }, () => server.client);
    });

    testWidgets('由通知開啟時捲動至待確認的手動回報', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(_host(const AdminCabinetDeviceScreen(cabinetId: 3)));
        await _settle(tester);
        final viewport = tester.view.physicalSize.height / tester.view.devicePixelRatio;
        expect(tester.getTopLeft(find.text(S.manualReportsConfirm)).dy, greaterThan(viewport));
        await _finish(tester);

        await tester.pumpWidget(_host(const AdminCabinetDeviceScreen(cabinetId: 3, focusPending: true)));
        await _settle(tester);
        final top = tester.getTopLeft(find.text(S.manualReportsConfirm)).dy;
        expect(top, greaterThan(0));
        expect(top, lessThan(viewport));
        await _finish(tester);
      }, () => server.client);
    });

    testWidgets('通知導向：管理員開啟書櫃裝置畫面，一般會員不導向', (tester) async {
      expect(NotificationCategory.of('system', 'cabinet'), NotificationCategory.service);
      final navigatorKey = GlobalKey<NavigatorState>();
      await http.runWithClient(() async {
        await tester.pumpWidget(_host(const Scaffold(body: SizedBox.expand()), navigatorKey: navigatorKey));
        await tester.pump();
        expect(NotificationRouter.hasTarget('cabinet', 3), isTrue);
        final opened = await NotificationRouter.open(navigatorKey.currentState!, relatedType: 'cabinet', relatedId: 3);
        expect(opened, isTrue);
        await _settle(tester);
        final screen = tester.widget<AdminCabinetDeviceScreen>(find.byType(AdminCabinetDeviceScreen));
        expect(screen.cabinetId, 3);
        expect(screen.focusPending, isTrue);
        await _finish(tester);

        ApiService.currentUser = User.fromJson({'user_id': 1, 'nickname': '小華', 'email': 'b@x.com', 'role': 'buyer_seller'});
        await tester.pumpWidget(_host(const Scaffold(body: SizedBox.expand()), navigatorKey: navigatorKey));
        await tester.pump();
        expect(await NotificationRouter.open(navigatorKey.currentState!, relatedType: 'cabinet', relatedId: 3), isFalse);
      }, () => server.client);
    });
  });

  group('既有後台畫面的櫃門資訊', () {
    testWidgets('存書列表顯示櫃門並可直接遠端開啟，原因預設為派員取出', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(_host(const AdminCabinetDepositScreen()));
        await _settle(tester);
        expect(find.text(S.doorP0('A01')), findsOneWidget);

        await tester.tap(find.byTooltip(S.openDoorRemotely));
        await _settle(tester);
        expect(find.byType(AdminCabinetOpenSheet), findsOneWidget);
        expect(find.widgetWithText(TextField, S.staffRetrievalOverdueBooks), findsOneWidget);
        expect(find.text(S.openWithoutNumberConfirmation), findsNothing);
        Navigator.of(tester.element(find.byType(AdminCabinetOpenSheet))).pop();
        await _settle(tester);
        await _finish(tester);
      }, () => server.client);
    });

    testWidgets('訂單詳情的櫃位以櫃門顯示', (tester) async {
      _tallView(tester);
      await http.runWithClient(() async {
        await tester.pumpWidget(_host(const AdminOrderDetailScreen(orderId: 7, orderNo: 'SMB20260928143015123456')));
        await _settle(tester);
        expect(find.text('A02、A03'), findsOneWidget);
        await _finish(tester);
      }, () => server.client);
    });

    testWidgets('書櫃列表：有裝置時只列櫃門並標示待確認，按鈕開啟裝置管理', (tester) async {
      _tallView(tester);
      await http.runWithClient(() async {
        await tester.pumpWidget(_host(const AdminCabinetScreen()));
        await _settle(tester);
        expect(find.text(S.offline), findsOneWidget);
        expect(find.textContaining('B01'), findsNothing);
        expect(find.text('A02・${S.slotEmpty}・${S.contentsNeedChecking}'), findsOneWidget);

        await tester.tap(find.byTooltip(S.lockerDevice));
        await _settle(tester);
        expect(find.byType(AdminCabinetDeviceScreen), findsOneWidget);
        await _finish(tester);
      }, () => server.client);
    });
  });
}
