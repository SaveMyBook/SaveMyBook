// 第 12 章使用手冊 19 節「書櫃裝置與櫃門管理（管理員）」截圖。
// 新北高工（配對、遠端開門、確認存放內容、撤銷）與北商大臺北校區ｉ郵箱（離線時的手動回報）皆為真實書櫃，
// 櫃門內的書籍為該書櫃真實存放的書（原圖的書名不在真實資料中時，改用同一賣家存於該書櫃的書）。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:savemybook_app/features/admin/admin_cabinet_device_screen.dart';
import 'package:savemybook_app/features/admin/admin_cabinet_open_sheet.dart';
import 'package:savemybook_app/features/admin/admin_cabinet_screen.dart';
import 'package:savemybook_app/features/admin/admin_home_screen.dart';
import 'package:savemybook_app/models/admin_models.dart';
import 'package:savemybook_app/models/user.dart';

import 'manual_api.dart';
import 'manual_host.dart';
import 's19_keyboards.dart';

const _folder = '19. 書櫃裝置與櫃門管理（管理員）';
final _ios = TargetPlatformVariant.only(TargetPlatform.iOS);

// 原圖的登入密碼欄位已切換為顯示明文
// 示範用密碼；截圖中保持遮蔽，不顯示真實密碼
const _adminPassword = 'Demo2026pass';

String _at(int month, int day, int hour, int minute, [int second = 0]) =>
    DateTime(2026, month, day, hour, minute, second).toUtc().toIso8601String();

String _agoIso(Duration d) => DateTime.now().subtract(d).toUtc().toIso8601String();

User _es() => User.fromJson(userJson(meId, extra: {'role': 'admin'}));

User _kj() => User.fromJson(userJson(adminId));

Map<String, dynamic> _user(int id) => {'user_no': 'MB${id.toString().padLeft(2, '0')}K7Q2X', 'nickname': realUsers[id]!.nickname};

int _byName(String nickname) => realUsers.entries.firstWhere((e) => e.value.nickname == nickname).key;

String _title(int bookId) => bookJson(bookId)['title'] as String;

// ---- 新北高工 ----

const _xbId = 7;
const _xbSession = 'CS05DPHAB';

Map<String, dynamic> _xbDoor(int i, {String status = 'empty', bool check = false}) => {
      'slot_id': 700 + i,
      'slot_no': 'A0$i',
      'label': 'A0$i',
      'channel': i,
      'status': status,
      'check': check ? {'at': _at(10, 6, 23, 26), 'reason': 'ADMIN_OPEN', 'session_no': _xbSession, 'candidates': <Object>[]} : null,
      'items': <Object>[],
    };

/// [state]：none（未配對）、pending（等待配對）、online（已配對連線中）、revoked（撤銷後）。
Map<String, dynamic> _xb(String state, {bool reserved = false, bool check = false}) {
  final online = state == 'online';
  return {
    'cabinet': {
      'cabinet_id': _xbId,
      'cabinet_name': cabinetJson(_xbId)['cabinet_name'],
      'is_active': true,
      'is_maintenance': false,
      'open_time': '10:00',
      'close_time': '00:00',
      'screen_brightness': 100,
    },
    'access': online ? {'mode': 'scan', 'online': true, 'open_now': true} : {'mode': 'manual', 'reason': 'no_device', 'online': false, 'open_now': true},
    'simulator_enabled': true,
    'kiosk_url': 'https://api.savemybook.today/kiosk',
    'device': online
        ? {
            'device_no': 'DV2Q85S3A',
            'kind': 'esp32',
            'status': 'active',
            'online': true,
            'last_seen_at': _agoIso(const Duration(seconds: 8)),
            'paired_at': _at(10, 6, 23, 23),
            'firmware': 'esp-1.0.0',
            'door_count': 4,
            'has_door_sensor': true,
            'unlock_pulse_ms': 800,
          }
        : null,
    'pairing': state == 'pending'
        ? {'kind': 'esp32', 'door_count': 4, 'has_door_sensor': true, 'firmware': 'esp-1.0.0', 'expires_at': _agoIso(const Duration(minutes: -10))}
        : null,
    'active_session_no': reserved ? _xbSession : null,
    'doors': state == 'online' || state == 'revoked'
        ? [_xbDoor(1, status: reserved ? 'reserved' : 'empty', check: check), _xbDoor(2), _xbDoor(3), _xbDoor(4)]
        : <Object>[],
    'unplaced': <Object>[],
  };
}

Map<String, dynamic> _xbSessionDetail(String status, int remainingMs) => {
      'session_no': _xbSession,
      'kind': 'admin',
      'status': status,
      'version': status == 'open' ? 3 : 1,
      'user': _user(meId),
      'cabinet': {'cabinet_id': _xbId, 'cabinet_name': cabinetJson(_xbId)['cabinet_name']},
      'items': <Object>[],
      'doors': [
        {'label': 'A01', 'state': status == 'open' ? 'open' : 'pending'},
      ],
      'remaining_ms': remainingMs,
      'created_at': _at(10, 6, 23, 25),
      'admin_reason': '開啟原因',
    };

void _xbRoutes(String Function() state, {bool Function()? reserved, bool Function()? check}) {
  ManualApi.on('GET', '/auth/me', (_) => userJson(meId, extra: {'role': 'admin'}));
  ManualApi.on('GET', '/admin/cabinets/$_xbId/device', (_) => _xb(state(), reserved: reserved?.call() ?? false, check: check?.call() ?? false));
}

// ---- 北商大臺北校區ｉ郵箱（模擬書櫃，裝置離線） ----

const _ntubId = 3;
const _orderNew = 'SMB20261006233438118889';
const _orderOld = 'SMB20260924234016166089';

// 原圖 A01、A03 為 KJ 存放的書，回報的是 yx 的訂單；改用兩人存於此書櫃的真實書籍。
final _kjId = _byName('KJ');
final _yxId = _byName('yx');
final _a01Book = booksOfSeller(_kjId).firstWhere((id) => bookJson(id)['cabinet_id'] == _ntubId && _title(id).startsWith('讓未來'));
final _a03Book = booksOfSeller(_kjId).firstWhere((id) => bookJson(id)['cabinet_id'] == _ntubId && id != _a01Book);
final _reportBook = booksOfSeller(_yxId).firstWhere((id) => bookJson(id)['cabinet_id'] == _ntubId);

Map<String, dynamic> _ntub({bool confirmed = false, bool a03Deposit = false}) => {
      'cabinet': {
        'cabinet_id': _ntubId,
        'cabinet_name': cabinetJson(_ntubId)['cabinet_name'],
        'is_active': true,
        'is_maintenance': false,
        'open_time': null,
        'close_time': null,
        'screen_brightness': 100,
      },
      'access': {'mode': 'manual', 'reason': 'offline', 'online': false, 'open_now': true},
      'simulator_enabled': true,
      'kiosk_url': 'https://api.savemybook.today/kiosk',
      'device': {
        'device_no': 'DV27P4F0H',
        'kind': 'simulator',
        'status': 'active',
        'online': false,
        'last_seen_at': _agoIso(const Duration(hours: 12, minutes: 7)),
        'paired_at': _at(9, 29, 10, 3),
        'firmware': 'sim-1.0.0',
        'door_count': 4,
        'has_door_sensor': true,
        'unlock_pulse_ms': 800,
      },
      'pairing': null,
      'active_session_no': null,
      'doors': [
        {
          'slot_id': 301, 'slot_no': 'A01', 'label': 'A01', 'channel': 1, 'status': 'occupied', 'check': null,
          'items': [
            {'kind': 'deposit', 'book_id': _a01Book, 'book_no': 'BK4N8R2TA', 'title': _title(_a01Book), 'seller_nickname': 'KJ', 'placed_at': _at(9, 29, 10, 4)},
          ],
        },
        {
          'slot_id': 302, 'slot_no': 'A02', 'label': 'A02', 'channel': 2, 'status': confirmed ? 'occupied' : 'empty', 'check': null,
          'items': [
            if (confirmed)
              {
                'kind': 'order', 'book_id': _reportBook, 'book_no': 'BK7Y3W9QD', 'title': _title(_reportBook), 'order_id': 9102,
                'order_no': _orderNew, 'seller_nickname': 'yx', 'placed_at': _at(10, 6, 23, 42),
              },
          ],
        },
        {
          'slot_id': 303, 'slot_no': 'A03', 'label': 'A03', 'channel': 3, 'status': 'occupied', 'check': null,
          'items': [
            a03Deposit
                ? {'kind': 'deposit', 'book_id': _a03Book, 'book_no': 'BK2C6M5HE', 'title': _title(_a03Book), 'seller_nickname': 'KJ', 'placed_at': _at(9, 29, 10, 5)}
                : {
                    'kind': 'order', 'book_id': _a03Book, 'book_no': 'BK2C6M5HE', 'title': _title(_a03Book), 'order_id': 9087,
                    'order_no': _orderOld, 'seller_nickname': 'KJ', 'placed_at': _at(9, 29, 10, 5),
                  },
          ],
        },
        {'slot_id': 304, 'slot_no': 'A04', 'label': 'A04', 'channel': 4, 'status': 'empty', 'check': null, 'items': <Object>[]},
      ],
      'unplaced': <Object>[],
    };

Map<String, dynamic> _ntubReport(String createdAt) => {
      'report_no': 'MR6T2K9WB',
      'kind': 'deposit',
      'status': 'pending',
      'target_status': 'deposited',
      'reason': 'offline',
      'created_at': createdAt,
      'user': _user(_yxId),
      'order': {'order_id': 9102, 'order_no': _orderNew, 'status': 'pending_deposit'},
      'book': null,
      'titles': [_title(_reportBook)],
      'requires_door': true,
      'door_books': [
        {'book_id': _reportBook, 'title': _title(_reportBook)},
      ],
      'reviewer_nickname': null,
    };

final _ntubSessions = [
  {
    'session_no': 'CS3P8V2LN', 'kind': 'admin', 'status': 'completed', 'user': _user(_kjId), 'item_kinds': <String>[], 'doors': ['A01'],
    'created_at': _at(9, 29, 10, 5), 'finished_at': _at(9, 29, 10, 6),
  },
  {
    'session_no': 'CS9H4D7QK', 'kind': 'user', 'status': 'completed', 'user': _user(_kjId), 'item_kinds': ['pre_deposit'], 'doors': ['A01'],
    'created_at': _at(9, 29, 10, 3), 'finished_at': _at(9, 29, 10, 4),
  },
];

Map<String, dynamic> _event(String type, String at, {String? label, String? orderNo, int? actor, Map<String, dynamic>? detail}) => {
      'type': type,
      'source': actor == null ? 'device' : 'admin',
      'label': label,
      'device_no': 'DV27P4F0H',
      'order_no': orderNo,
      'actor': actor == null ? null : _user(actor),
      'detail': detail,
      'result': 'ok',
      'occurred_at': at,
    };

final _ntubEvents = [
  _event('manual_report_reviewed', _at(10, 6, 23, 42, 30), orderNo: _orderNew, actor: _kjId, detail: {'status': 'confirmed', 'note': '確認回報'}),
  _event('door_placed', _at(10, 6, 23, 42, 20), label: 'A02', orderNo: _orderNew, actor: _kjId),
  _event('manual_report', _at(10, 6, 23, 41), orderNo: _orderNew, actor: _yxId, detail: {'kind': 'deposit', 'reason': 'offline'}),
  _event('manual_report_reviewed', _at(10, 6, 23, 40, 30), orderNo: _orderNew, actor: _kjId, detail: {'status': 'rejected', 'note': '駁回回報'}),
  _event('manual_report_reviewed', _at(10, 6, 23, 40, 10), orderNo: _orderOld, actor: _yxId, detail: {'status': 'rejected', 'note': '不'}),
  _event('manual_report', _at(10, 6, 23, 39), orderNo: _orderNew, actor: _yxId, detail: {'kind': 'deposit', 'reason': 'offline'}),
  _event('connection_lost', _at(10, 6, 11, 28)),
  _event('boot', _at(10, 6, 11, 26, 40)),
  _event('connection_restored', _at(10, 6, 11, 26, 30), detail: {'offline_ms': ((168 * 60 + 37) * 60 + 43) * 1000}),
  _event('overdue_review', _at(9, 29, 22, 40), orderNo: _orderOld),
];

void _ntubRoutes({
  required Map<String, dynamic> Function() device,
  required List<Map<String, dynamic>> Function() reports,
}) {
  ManualApi.on('GET', '/auth/me', (_) => userJson(adminId));
  ManualApi.on('GET', '/admin/cabinets/$_ntubId/device', (_) => device());
  ManualApi.on('GET', '/admin/cabinets/$_ntubId/manual-reports', (_) => reports());
  ManualApi.on('GET', '/admin/cabinets/$_ntubId/sessions', (r) => r.query['status'] == 'review' ? <Object>[] : _ntubSessions);
  ManualApi.on('GET', '/admin/cabinets/$_ntubId/events', (_) => _ntubEvents);
}

// ---- 共用操作 ----

Finder get _mainScroll => find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first;

Future<void> _scrollTo(WidgetTester tester, double offset) async {
  final position = tester.state<ScrollableState>(_mainScroll).position;
  position.jumpTo(offset.clamp(position.minScrollExtent, position.maxScrollExtent));
  await settleReal(tester, const Duration(milliseconds: 800));
}

// 清單為延遲建立，最大捲動範圍要捲到底後才確定
Future<void> _scrollToEnd(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    final position = tester.state<ScrollableState>(_mainScroll).position;
    await _scrollTo(tester, position.maxScrollExtent);
  }
}

/// 捲動到 [finder] 的中心位於畫面 y = [y]（邏輯座標）。
Future<void> _scrollCenterTo(WidgetTester tester, Finder finder, double y) async {
  final position = tester.state<ScrollableState>(_mainScroll).position;
  await _scrollTo(tester, position.pixels + tester.getCenter(finder).dy - y);
}

Finder _inDialog(String text) => find.descendant(of: find.byType(Dialog), matching: find.text(text));

Future<void> _openDoorMenu(WidgetTester tester) async {
  await tapAndSettle(tester, find.byIcon(Icons.more_horiz_rounded).first);
}

Widget _zhuyin(List<String> candidates, {bool newline = false}) => S19ZhuyinKeyboard(candidates: candidates, newline: newline);

void main() {
  setUpAll(setUpManual);

  testWidgets('表12-19-1 管理後台', variant: _ios, (tester) async {
    await shoot(
      tester,
      folder: _folder,
      me: _es(),
      home: () => const AdminHomeScreen(),
      routes: () {
        ManualApi.on('GET', '/auth/me', (_) => userJson(meId, extra: {'role': 'admin'}));
        ManualApi.on('GET', '/admin/overview', (_) => {
              'member_count': 32,
              'pending_report_count': 0,
              'pending_listing_review_count': 0,
              'open_risk_alert_count': 0,
              'pending_dispute_count': 0,
              'active_cabinet_count': realCabinets.length,
              'today_order_count': 3,
              'open_ticket_count': 5,
            });
      },
      act: (tester, snap) async {
        await _scrollCenterTo(tester, find.text('內容審核'), 139);
        await snap('表12-19-1 管理後台');
      },
    );
  });

  testWidgets('表12-19-1 書櫃監控', variant: _ios, (tester) async {
    Map<String, dynamic> cabinet(Map<String, dynamic> c) {
      final id = c['cabinet_id'] as int;
      // 新北高工的書是 10/7 才存入，原圖（10/6）時全部空置
      final inCabinet = id == _xbId ? 0 : realBooks.where((b) => b['cabinet_id'] == id && b['in_cabinet'] == true).length;
      final ntub = id == _ntubId;
      final slots = [
        for (var i = 1; i <= (ntub ? 4 : 20); i++)
          {
            'slot_id': id * 100 + i,
            'slot_number': 'A${i.toString().padLeft(2, '0')}',
            'status': ntub ? (i == 1 || i == 3 ? 'occupied' : 'empty') : (i <= inCabinet ? 'occupied' : 'empty'),
            'updated_at': ago(days: 1),
            'lock_channel': ntub ? i : null,
          },
      ];
      final empty = slots.where((s) => s['status'] == 'empty').length;
      return {
        ...c,
        if (id == _xbId) ...{'open_time': '10:00', 'close_time': '00:00'},
        'total_slots': slots.length,
        'available_slots': empty,
        'is_active': true,
        'is_maintenance': false,
        'slot_summary': {'empty': empty, 'occupied': slots.length - empty},
        'cabinet_slots': slots,
        'device': ntub
            ? {'device_no': 'DV27P4F0H', 'kind': 'simulator', 'status': 'active', 'online': false, 'last_seen_at': _at(10, 6, 11, 28)}
            : null,
      };
    }

    await shoot(
      tester,
      folder: _folder,
      me: _es(),
      home: () => const AdminCabinetScreen(),
      routes: () {
        ManualApi.on('GET', '/auth/me', (_) => userJson(meId, extra: {'role': 'admin'}));
        ManualApi.on('GET', '/admin/cabinets', (_) {
          final list = [...realCabinets]..sort((a, b) => (a['cabinet_id'] as int).compareTo(b['cabinet_id'] as int));
          return [for (final c in list) cabinet(c)];
        });
      },
      act: (tester, snap) async {
        await _scrollToEnd(tester);
        await snap('表12-19-1 書櫃監控');
      },
    );
  });

  testWidgets('配對裝置', variant: _ios, (tester) async {
    var state = 'none';
    await shoot(
      tester,
      folder: _folder,
      me: _es(),
      home: () => const AdminCabinetDeviceScreen(cabinetId: _xbId, cabinetName: '新北高工'),
      routes: () {
        _xbRoutes(() => state);
        ManualApi.on('GET', '/security', (_) => {'available': true, 'has_password': true, 'has_payment_pin': true, 'passkey_available': false});
        ManualApi.on('POST', '/security/verify', (_) => {'verify_token': 'manual-verify-token'});
        ManualApi.on('POST', '/admin/cabinets/$_xbId/device/pair', (_) {
          state = 'pending';
          return {'kind': 'esp32', 'door_count': 4, 'has_door_sensor': true, 'firmware': 'esp-1.0.0', 'summary': _xb('pending')};
        });
      },
      act: (tester, snap) async {
        await snap('表12-19-1 書櫃裝置');

        await tapAndSettle(tester, find.text('配對裝置'));
        s19ShowKeyboard(tester, null);
        await settleReal(tester, const Duration(milliseconds: 600));
        await snap('IMG_3886');

        await tester.enterText(find.byType(TextField).last, _adminPassword);
        s19ShowKeyboard(tester, const S19QwertyKeyboard());
        await snap('表12-19-2 驗證身分');

        s19HideKeyboard(tester);
        await tapAndSettle(tester, find.text('驗證身分').last, duration: const Duration(seconds: 2));
        s19ShowKeyboard(tester, const S19NumberPad(), height: numberPadHeight);
        await settleReal(tester, const Duration(milliseconds: 600));
        await snap('IMG_3888');

        await tester.enterText(find.descendant(of: find.byType(Dialog), matching: find.byType(TextField)), '01517752');
        await snap('表12-19-2 輸入配對碼');

        s19HideKeyboard(tester);
        await tapAndSettle(tester, _inDialog('配對裝置').last, duration: const Duration(seconds: 2));
        // 讓轉圈停在接近整圈的時刻，與原圖相同
        await tester.pump(const Duration(milliseconds: 500));
        await snap('表12-19-2 等待裝置連線');

        state = 'online';
        await settleReal(tester, const Duration(milliseconds: 3500));
        await snap('表12-19-3 完成配對');

        await tapAndSettle(tester, _inDialog('關閉'), duration: const Duration(seconds: 2));
        await snap('表12-19-3 裝置連線中');
      },
    );
  });

  testWidgets('遠端開啟櫃門', variant: _ios, (tester) async {
    var status = 'none';
    var remaining = 59000;
    await shoot(
      tester,
      folder: _folder,
      me: _es(),
      home: () => const AdminCabinetDeviceScreen(cabinetId: _xbId, cabinetName: '新北高工'),
      routes: () {
        _xbRoutes(() => 'online');
        ManualApi.on('POST', '/admin/cabinets/$_xbId/doors/701/open', (_) {
          status = 'matching';
          return {'session_no': _xbSession, 'status': 'matching', 'remaining_ms': remaining};
        });
        ManualApi.on('GET', '/admin/cabinet-sessions/$_xbSession', (_) => _xbSessionDetail(status, remaining));
      },
      act: (tester, snap) async {
        await _scrollCenterTo(tester, find.text('配對時間'), 135);
        await _openDoorMenu(tester);
        await snap('表12-19-4 櫃門選單');

        await tapAndSettle(tester, find.text('遠端開啟櫃門'));
        await snap('IMG_3895');

        await tester.enterText(find.byType(TextField).last, '開啟原因');
        await tester.pump();
        await tapAndSettle(tester, find.text('開啟櫃門'));
        s19ShowKeyboard(tester, const S19NumberPad(), height: numberPadHeight);
        await settleReal(tester, const Duration(milliseconds: 600));
        await snap('IMG_3896');

        remaining = 37000;
        await tester.enterText(find.byType(TextField).last, '17');
        await settleReal(tester, const Duration(milliseconds: 1200));
        await snap('表12-19-4 輸入書櫃螢幕數字');
      },
    );
  });

  testWidgets('表12-19-4 輸入開啟原因', variant: _ios, (tester) async {
    await shoot(
      tester,
      folder: _folder,
      me: _es(),
      home: () => const AdminCabinetDeviceScreen(cabinetId: _xbId, cabinetName: '新北高工'),
      routes: () => _xbRoutes(() => 'online'),
      act: (tester, snap) async {
        await _openDoorMenu(tester);
        await tapAndSettle(tester, find.text('遠端開啟櫃門'));
        await tester.enterText(find.byType(TextField).last, '開啟原因');
        s19ShowKeyboard(tester, _zhuyin(const ['是', '就是', '的', '嗎', '之', '是因為', '了']));
        await settleReal(tester, const Duration(milliseconds: 600));
        await snap('表12-19-4 輸入開啟原因');
      },
    );
  });

  testWidgets('表12-19-5 櫃門已開啟', variant: _ios, (tester) async {
    await shoot(
      tester,
      folder: _folder,
      me: _es(),
      home: () => const AdminCabinetDeviceScreen(cabinetId: _xbId, cabinetName: '新北高工'),
      routes: () {
        _xbRoutes(() => 'online', reserved: () => true);
        ManualApi.on('GET', '/admin/cabinet-sessions/$_xbSession', (_) => _xbSessionDetail('open', 120000));
      },
      act: (tester, snap) async {
        await _scrollCenterTo(tester, find.text('配對時間'), 135);
        unawaited(showAdminCabinetOpenSheet(
          tester.element(find.byType(AdminCabinetDeviceScreen)),
          cabinetId: _xbId,
          slotId: 701,
          label: 'A01',
          cabinetName: '新北高工',
          resume: const AdminCabinetRemoteOpen(sessionNo: _xbSession, status: 'open', remainingMs: 120000),
        ));
        await settleReal(tester, const Duration(milliseconds: 1500));
        await snap('表12-19-5 櫃門已開啟');
      },
    );
  });

  testWidgets('確認存放內容', variant: _ios, (tester) async {
    var check = true;
    await shoot(
      tester,
      folder: _folder,
      me: _es(),
      home: () => const AdminCabinetDeviceScreen(cabinetId: _xbId, cabinetName: '新北高工'),
      routes: () {
        _xbRoutes(() => 'online', check: () => check);
        ManualApi.on('POST', '/admin/cabinets/$_xbId/doors/701/check-clear', (_) {
          check = false;
          return <String, Object>{};
        });
      },
      act: (tester, snap) async {
        await _scrollCenterTo(tester, find.text('使用者須掃碼存取'), 126);
        await snap('表12-19-5 待確認存放內容');

        await _openDoorMenu(tester);
        await snap('表12-19-5 櫃門選單');

        await tapAndSettle(tester, find.text('確認內容無誤'));
        s19ShowKeyboard(tester, _zhuyin(const ['我', '你', '好', '不', '這', '那', '他', '是', '點']));
        await settleReal(tester, const Duration(milliseconds: 600));
        await snap('IMG_3901');

        await tester.enterText(find.descendant(of: find.byType(Dialog), matching: find.byType(TextField)), '確認存放');
        s19ShowKeyboard(tester, _zhuyin(const ['在', '日期', '的', '於', '地點', '時間', '期間']));
        await snap('表12-19-6 填寫處理說明');

        s19HideKeyboard(tester);
        await tapAndSettle(tester, _inDialog('確認內容無誤').last, duration: const Duration(milliseconds: 700));
        await snap('表12-19-6 已確認存放內容');
      },
    );
  });

  testWidgets('駁回手動回報', variant: _ios, (tester) async {
    var reports = [_ntubReport(_at(10, 6, 23, 39))];
    await shoot(
      tester,
      folder: _folder,
      me: _kj(),
      home: () => const AdminCabinetDeviceScreen(cabinetId: _ntubId, cabinetName: '北商大臺北校區ｉ郵箱'),
      routes: () {
        _ntubRoutes(device: _ntub, reports: () => reports);
        ManualApi.on('POST', '/admin/cabinet-manual-reports/:no/reject', (_) {
          reports = [];
          return <String, Object>{};
        });
      },
      act: (tester, snap) async {
        await snap('表12-19-7 書櫃離線');

        await _scrollToEnd(tester);
        await snap('表12-19-7 待確認手動回報');

        const candidates = ['如果', '如果行情', '一下', '給', '不', '的'];
        await tapAndSettle(tester, find.text('駁回回報'));
        await tester.enterText(find.descendant(of: find.byType(Dialog), matching: find.byType(TextField)), '駁回回報');
        s19ShowKeyboard(tester, _zhuyin(candidates, newline: true));
        await settleReal(tester, const Duration(milliseconds: 600));
        await snap('表12-19-7 駁回回報');

        // 原圖鍵盤尚未收起：重新載入時可視範圍仍扣除鍵盤高度，捲動位置不變
        await tapAndSettle(tester, _inDialog('駁回回報').last, duration: const Duration(milliseconds: 900));
        await snap('表12-19-8 已駁回回報');
      },
    );
  });

  testWidgets('確認手動回報', variant: _ios, (tester) async {
    var confirmed = false;
    await shoot(
      tester,
      folder: _folder,
      me: _kj(),
      home: () => const AdminCabinetDeviceScreen(cabinetId: _ntubId, cabinetName: '北商大臺北校區ｉ郵箱'),
      routes: () {
        _ntubRoutes(device: () => _ntub(confirmed: confirmed), reports: () => confirmed ? [] : [_ntubReport(_at(10, 6, 23, 41))]);
        ManualApi.on('POST', '/admin/cabinet-manual-reports/:no/confirm', (_) {
          confirmed = true;
          return <String, Object>{};
        });
      },
      act: (tester, snap) async {
        await _scrollToEnd(tester);
        await tapAndSettle(tester, find.text('確認回報'));
        await snap('表12-19-8 選擇實際存放櫃門');

        await tapAndSettle(tester, find.text('櫃門 A02・空置'));
        await tester.enterText(find.descendant(of: find.byType(Dialog), matching: find.byType(TextField)), '確認回報');
        s19ShowKeyboard(tester, _zhuyin(const ['如果', '如果行情', '一下', '的', '給', '不'], newline: true));
        await settleReal(tester, const Duration(milliseconds: 600));
        await snap('表12-19-8 確認回報');

        s19HideKeyboard(tester);
        await tapAndSettle(tester, _inDialog('確認回報').last, duration: const Duration(milliseconds: 700));
        await _scrollToEnd(tester);
        await snap('表12-19-9 已確認手動回報');
      },
    );
  });

  testWidgets('作業與事件紀錄', variant: _ios, (tester) async {
    await shoot(
      tester,
      folder: _folder,
      me: _kj(),
      home: () => const AdminCabinetDeviceScreen(cabinetId: _ntubId, cabinetName: '北商大臺北校區ｉ郵箱'),
      routes: () => _ntubRoutes(device: () => _ntub(confirmed: true, a03Deposit: true), reports: () => []),
      act: (tester, snap) async {
        await _scrollToEnd(tester);
        await snap('表12-19-9 最近作業');

        await tapAndSettle(tester, find.text('事件紀錄'));
        await _scrollCenterTo(tester, find.text('待確認手動回報'), 148);
        await snap('表12-19-9 事件紀錄');
      },
    );
  });

  testWidgets('撤銷裝置', variant: _ios, (tester) async {
    var state = 'online';
    await shoot(
      tester,
      folder: _folder,
      me: _es(),
      home: () => const AdminCabinetDeviceScreen(cabinetId: _xbId, cabinetName: '新北高工'),
      routes: () {
        _xbRoutes(() => state);
        ManualApi.on('DELETE', '/admin/cabinets/$_xbId/device', (_) {
          state = 'revoked';
          return <String, Object>{};
        });
      },
      act: (tester, snap) async {
        await snap('表12-19-10 書櫃裝置');

        await tapAndSettle(tester, find.text('撤銷裝置'));
        await snap('表12-19-10 撤銷裝置');

        await tapAndSettle(tester, _inDialog('撤銷裝置').last, duration: const Duration(milliseconds: 700));
        await snap('表12-19-10 已撤銷裝置');
      },
    );
  });
}
