import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:savemybook_app/models/admin_models.dart';
import 'package:savemybook_app/models/book.dart';
import 'package:savemybook_app/models/cabinet.dart';
import 'package:savemybook_app/models/order.dart';
import 'package:savemybook_app/services/api_service.dart';
import 'package:savemybook_app/services/cabinet_session_tracker.dart';
import 'package:savemybook_app/services/realtime_service.dart';

Map<String, dynamic> sessionJson({
  String no = 'CS8MZQ41K',
  String status = 'open',
  int version = 6,
  int? remainingMs = 24300,
  String? notice,
  Map<String, dynamic>? result,
}) => {
  'session_no': no,
  'status': status,
  'version': version,
  'cabinet': {
    'cabinet_id': 3,
    'cabinet_name': '北商大書櫃',
    'address': '臺北市中正區濟南路一段 321 號',
    'latitude': 25.0421,
    'longitude': 121.5254,
    'open_time': '08:00',
    'close_time': '22:00',
    'available_doors': 2,
  },
  'location_status': 'granted',
  'distance_m': 35,
  'items': [
    {
      'key': 'order:128',
      'kind': 'order_deposit',
      'order_id': 128,
      'order_no': 'SMB20260928143015123456',
      'books': [
        {'book_id': 55, 'title': '資料庫系統概論', 'image_url': '/uploads/books/55.jpg', 'door': 'A02'},
        {'book_id': 56, 'title': '作業系統', 'image_url': null, 'door': 'A02'},
      ],
      'doors': ['A02'],
      'paused': false,
      'note': null,
      'selected': true,
      'blocked': null,
      'result': 'pending',
      'error': null,
    },
    {
      'key': 'book:57',
      'kind': 'retrieval',
      'order_id': null,
      'order_no': null,
      'books': [
        {'book_id': 57, 'title': '演算法', 'image_url': null, 'door': null},
      ],
      'doors': <String>[],
      'paused': true,
      'note': {'code': 'MOVE_TO_ORDER_CABINET', 'message': '此書籍已售出，取回後請存入訂單指定的書櫃「師大書櫃」'},
      'selected': false,
      'blocked': {'code': 'DOOR_UNKNOWN', 'message': '無法確認此項目的櫃門，請聯絡客服'},
      'result': 'pending',
      'error': null,
    },
  ],
  'doors': [
    {'label': 'A02', 'state': 'open'},
  ],
  'remaining_ms': remainingMs,
  'open_ms': 30000,
  'notice': notice,
  'result': result,
  'created_at': '2026-09-28T10:30:00.000Z',
  'finished_at': null,
};

CabinetSession session({String status = 'open', int version = 6, int? remainingMs = 24300}) =>
    CabinetSession.fromJson(sessionJson(status: status, version: version, remainingMs: remainingMs));

class _FakeStopwatch implements Stopwatch {
  int ms = 0;

  @override
  int get elapsedMilliseconds => ms;

  @override
  void reset() => ms = 0;

  @override
  void start() {}

  @override
  void stop() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('CabinetSession', () {
    test('解析作業、項目、櫃門與結果', () {
      final s = CabinetSession.fromJson(sessionJson(
        status: 'partial',
        result: {'outcome': 'partial', 'code': 'ITEMS_FAILED', 'message': '項目未能完成，請查看各項目說明'},
      ));

      expect(s.sessionNo, 'CS8MZQ41K');
      expect(s.version, 6);
      expect(s.cabinet.cabinetName, '北商大書櫃');
      expect(s.cabinet.openHours, '08:00~22:00');
      expect(s.cabinet.availableDoors, 2);
      expect(s.cabinet.hasCoordinates, isTrue);
      expect(s.locationStatus, 'granted');
      expect(s.distanceM, 35);
      expect(s.doors.single.label, 'A02');
      expect(s.doors.single.state, 'open');
      expect(s.openMs, 30000);
      expect(s.notice, isNull);
      expect(s.closeDoorFirst, isFalse);
      expect(s.isTerminal, isTrue);
      expect(s.isSettled, isTrue);
      expect(s.isActive, isFalse);
      expect(s.result!.code, 'ITEMS_FAILED');

      final deposit = s.items.first;
      expect(deposit.kind, CabinetItemKind.orderDeposit);
      expect(deposit.kind!.isDeposit, isTrue);
      expect(deposit.orderNo, 'SMB20260928143015123456');
      expect(deposit.books.map((b) => b.door), ['A02', 'A02']);
      expect(deposit.books.first.imageUrl, 'https://api.savemybook.today/uploads/books/55.jpg');
      expect(deposit.books.last.imageUrl, isNull);

      final retrieval = s.items.last;
      expect(retrieval.kind, CabinetItemKind.retrieval);
      expect(retrieval.paused, isTrue);
      expect(retrieval.isBlocked, isTrue);
      expect(retrieval.blocked!.code, 'DOOR_UNKNOWN');
      expect(retrieval.note!.code, 'MOVE_TO_ORDER_CABINET');

      expect(s.selectedKeys, ['order:128']);
      expect(s.itemsAtDoor('A02').single.key, 'order:128');
    });

    test('開門後書櫃拒絕結束時帶出關門提示；needs_review 視為已結束但不是終態', () {
      final refused = CabinetSession.fromJson(sessionJson(notice: 'CLOSE_DOOR_FIRST'));
      expect(refused.notice, CabinetSession.noticeCloseDoorFirst);
      expect(refused.closeDoorFirst, isTrue);
      expect(refused.isActive, isTrue);

      final review = session(status: 'needs_review', remainingMs: null);
      expect(review.needsReview, isTrue);
      expect(review.isTerminal, isFalse);
      expect(review.isSettled, isTrue);
    });

    test('比對碼只接受 10 至 99 的兩個半形數字', () {
      for (final code in ['10', '37', '99']) {
        expect(CabinetSession.isMatchCode(code), isTrue, reason: code);
      }
      for (final code in ['', '7', '09', '100', ' 37', '37 ', '３７', '3a', '-1']) {
        expect(CabinetSession.isMatchCode(code), isFalse, reason: code);
      }
    });

    test('tryParse 對不完整的內容回傳 null', () {
      expect(CabinetSession.tryParse(null), isNull);
      expect(CabinetSession.tryParse({'status': 'open'}), isNull);
      expect(CabinetSession.tryParse({'session_no': 'CS1', 'status': 'open', 'version': 1})!.items, isEmpty);
    });
  });

  group('CabinetApiError', () {
    test('保留附帶欄位並提供讀取方法', () {
      final error = CabinetApiError.fromResponse({
        'success': false,
        'status': 409,
        'code': 'CABINET_WRONG_CABINET',
        'message': '此訂單的指定書櫃為「北商大書櫃」，請至該書櫃辦理',
        'cabinet': {'cabinet_id': 3, 'cabinet_name': '北商大書櫃', 'address': '地址', 'latitude': 25.0, 'longitude': 121.5},
        'other_cabinets': [
          {'cabinet_id': 5, 'cabinet_name': '師大書櫃', 'address': '和平東路', 'kinds': ['pickup']},
        ],
        'manual_allowed': true,
        'distance_m': 850,
        'retry_after_s': 452,
        'session_no': 'CS8MZQ41K',
        'open_time': '08:00',
        'close_time': '22:00',
        'available_doors': 1,
        'required_doors': 2,
        'session': sessionJson(status: 'selecting'),
        'items': [sessionJson()['items'][1]],
      });

      expect(error.code, 'CABINET_WRONG_CABINET');
      expect(error.status, 409);
      expect(error.extra.containsKey('success'), isFalse);
      expect(error.extra.containsKey('code'), isFalse);
      expect(error.cabinet!.cabinetName, '北商大書櫃');
      expect(error.otherCabinets.single.kinds, ['pickup']);
      expect(error.manualAllowed, isTrue);
      expect(error.distanceM, 850);
      expect(error.retryAfterS, 452);
      expect(error.sessionNo, 'CS8MZQ41K');
      expect(error.openTime, '08:00');
      expect(error.availableDoors, 1);
      expect(error.requiredDoors, 2);
      expect(error.session!.status, 'selecting');
      expect(error.items.single.blocked!.code, 'DOOR_UNKNOWN');
    });
  });

  group('訂單與書籍的書櫃欄位', () {
    test('訂單：存取模式、櫃門標籤與待確認的手動回報', () {
      final order = Order.fromJson({
        'order_id': 128,
        'order_no': 'SMB1',
        'status': 'deposited',
        'cabinet_id': 3,
        'cabinet_slots': {'slot_number': 'A01'},
        'doors': ['A02', 'A03'],
        'cabinet_access': {
          'mode': 'scan',
          'reason': null,
          'open_now': false,
          'open_time': '08:00',
          'close_time': '22:00',
          'available_doors': 0,
          'pre_deposit_doors': 0,
        },
        'manual_report': {'report_no': 'MR4K2Q8ZT', 'kind': 'pickup', 'status': 'pending', 'reason': 'offline', 'target_status': 'picked_up'},
      });

      expect(order.doorLabel, 'A02、A03');
      expect(order.cabinetAccess!.isScan, isTrue);
      expect(order.cabinetAccess!.openNow, isFalse);
      expect(order.cabinetAccess!.openHours, '08:00~22:00');
      expect(order.cabinetAccess!.availableDoors, 0);
      expect(order.hasPendingManualReport, isTrue);
      expect(order.manualReport!.reason, 'offline');

      final legacy = Order.fromJson({'order_id': 1, 'order_no': 'SMB2', 'cabinet_slots': {'slot_number': 'A01'}});
      expect(legacy.doorLabel, 'A01');
      expect(legacy.cabinetAccess, isNull);
      expect(legacy.manualReport, isNull);
    });

    test('書籍：櫃門、實際存放位置與取回條件', () {
      final book = Book.fromJson({
        'book_id': 55,
        'title': '資料庫系統概論',
        'price': 180,
        'status': 'removed',
        'cabinet_id': 3,
        'deposit': null,
        'cabinet_access': {'mode': 'manual', 'reason': 'no_device', 'open_now': true},
        'location': {
          'cabinet_id': 5,
          'cabinet_name': '師大書櫃',
          'door': 'A03',
          'retrievable': true,
          'access': {'mode': 'scan', 'reason': null, 'open_now': true},
        },
        'manual_report': null,
      });

      expect(book.cabinetAccess!.isManual, isTrue);
      expect(book.cabinetLocation!.door, 'A03');
      expect(book.canRetrieve, isTrue);
      expect(book.retrievalAccess!.isScan, isTrue);
      expect(book.hasPendingManualReport, isFalse);

      final deposited = Book.fromJson({
        'book_id': 56,
        'title': 'x',
        'deposit': {'deposited_at': '2026-09-01T00:00:00Z', 'paused': false, 'days_stored': 3, 'door': 'A01'},
      });
      expect(deposited.deposit!.door, 'A01');
      expect(deposited.canRetrieve, isTrue);
      expect(deposited.retrievalAccess, isNull);
    });
  });

  group('後台模型', () {
    test('書櫃列表的裝置摘要、櫃門欄位與存書列表的櫃門', () {
      final cabinet = Cabinet.fromJson({
        'cabinet_id': 3,
        'cabinet_name': '北商大書櫃',
        'device': {'device_no': 'DV3K9QX2M', 'kind': 'esp32', 'status': 'active', 'online': true, 'last_seen_at': '2026-09-28T10:00:00Z'},
        'cabinet_slots': [
          {'slot_id': 41, 'slot_number': 'A01', 'status': 'occupied', 'lock_channel': 1, 'fault_code': null, 'check_required_at': '2026-09-28T10:00:00Z'},
          {'slot_id': 90, 'slot_number': 'A05', 'status': 'empty', 'lock_channel': null},
        ],
      });
      expect(cabinet.device!.online, isTrue);
      expect(cabinet.doors.map((d) => d.slotNumber), ['A01']);
      expect(cabinet.doors.single.needsCheck, isTrue);

      final deposit = CabinetDeposit.fromJson({'book_id': 55, 'title': 'x', 'door': {'slot_id': 41, 'label': 'A01'}});
      expect(deposit.doorSlotId, 41);
      expect(deposit.doorLabel, 'A01');
      expect(CabinetDeposit.fromJson({'book_id': 56, 'title': 'y', 'door': null}).doorLabel, isNull);
    });

    test('裝置摘要：存取模式、裝置、配對碼、櫃門與未登記項目', () {
      final summary = AdminCabinetDeviceSummary.fromJson({
        'cabinet': {'cabinet_id': 3, 'cabinet_name': '北商大書櫃', 'is_active': true, 'is_maintenance': false, 'open_time': '08:00', 'close_time': '22:00'},
        'access': {'mode': 'manual', 'reason': 'offline', 'online': false, 'open_now': true},
        'simulator_enabled': true,
        'kiosk_url': 'https://api.savemybook.today/kiosk',
        'device': {
          'device_no': 'DV3K9QX2M',
          'kind': 'simulator',
          'status': 'active',
          'online': false,
          'last_seen_at': '2026-09-28T10:00:00Z',
          'paired_at': '2026-09-27T10:00:00Z',
          'firmware': 'sim-1.0.0',
          'door_count': 4,
          'has_door_sensor': false,
          'unlock_pulse_ms': 800,
          'fault_code': 'POWER',
        },
        'pairing': {'kind': 'esp32', 'door_count': 4, 'has_door_sensor': true, 'firmware': 'esp-1.0.0', 'expires_at': '2026-09-28T10:10:00Z'},
        'active_session_no': null,
        'doors': [
          {
            'slot_id': 41,
            'slot_no': 'SL5T2K8QW',
            'label': 'A01',
            'channel': 1,
            'status': 'occupied',
            'fault_code': null,
            'sensor': null,
            'check': {
              'at': '2026-09-28T10:00:00Z',
              'reason': 'CANCELLED_AFTER_OPEN',
              'session_no': 'CS1',
              'candidates': [
                {'book_id': 58, 'book_no': 'BK1', 'title': '作業系統', 'kind': 'pre_deposit', 'order_id': null},
                {'book_id': 57, 'book_no': 'BK2', 'title': '演算法', 'kind': 'order_deposit', 'order_id': 128},
              ],
            },
            'items': [
              {'kind': 'deposit', 'book_id': 55, 'book_no': 'BK3', 'title': '資料庫系統概論', 'order_id': null, 'order_no': null, 'seller_nickname': '小明', 'placed_at': '2026-09-28T09:00:00Z'},
            ],
          },
        ],
        'unplaced': [
          {'kind': 'order', 'order_id': 128, 'order_no': 'SMB1', 'book_id': 57, 'book_no': 'BK2', 'title': '演算法'},
        ],
      });

      expect(summary.cabinetName, '北商大書櫃');
      expect(summary.openHours, '08:00~22:00');
      expect(summary.access.isManual, isTrue);
      expect(summary.access.reason, 'offline');
      expect(summary.device!.isSimulator, isTrue);
      expect(summary.device!.faultCode, 'POWER');
      expect(summary.pairing!.kind, 'esp32');
      expect(summary.pairing!.doorCount, 4);
      expect(summary.pairing!.hasDoorSensor, isTrue);
      expect(summary.pairing!.firmware, 'esp-1.0.0');
      expect(summary.pairing!.expiresAt, DateTime.utc(2026, 9, 28, 10, 10));
      final door = summary.doors.single;
      expect(door.needsCheck, isTrue);
      expect(door.hasContents, isTrue);
      expect(door.check!.candidates, hasLength(2));
      expect(door.items.single.sellerNickname, '小明');
      expect(summary.placeableFor(door).map((b) => b.bookId), [57, 58]);
    });

    test('作業列表、作業詳情、事件與手動回報', () {
      final row = AdminCabinetSessionRow.fromJson({
        'session_no': 'CS1',
        'kind': 'user',
        'status': 'needs_review',
        'result_code': 'DEVICE_LOST',
        'user': {'user_no': 'MB1', 'nickname': '小明'},
        'item_kinds': ['pickup'],
        'doors': ['A02'],
        'location_status': 'denied',
        'distance_m': null,
        'close_reason': null,
        'created_at': '2026-09-28T10:00:00Z',
      });
      expect(row.user!.nickname, '小明');
      expect(row.itemKinds, ['pickup']);
      expect(row.isAdmin, isFalse);

      final detail = AdminCabinetSessionDetail.fromJson({
        ...sessionJson(status: 'open', notice: 'CLOSE_DOOR_FIRST'),
        'kind': 'admin',
        'result_code': null,
        'user': {'user_no': 'MB9', 'nickname': '客服人員'},
        'items': [
          {...(sessionJson()['items'] as List).first as Map<String, dynamic>, 'seller_nickname': '小明', 'buyer_nickname': '小華'},
        ],
        'close_reason': null,
        'accuracy_m': 18,
        'admin_reason': '協助賣家取回書籍',
        'admin_force': false,
        'doors_timeline': [
          {'label': 'A02', 'state': 'pending', 'command_served_at': null, 'opened_at': null, 'closed_at': null, 'close_reason': null},
        ],
        'events': [
          {'type': 'admin_open', 'source': 'admin', 'label': 'A02', 'detail': {'force': false}, 'result': null, 'occurred_at': '2026-09-28T10:00:00Z'},
        ],
        'review': null,
      });
      expect(detail.isAdmin, isTrue);
      expect(detail.closeDoorFirst, isTrue);
      expect(detail.isActive, isTrue);
      expect(detail.canCommit, isFalse);
      expect(detail.canDiscard, isFalse);
      expect(detail.items.single.buyerNickname, '小華');
      expect(detail.items.single.kind, CabinetItemKind.orderDeposit);
      expect(detail.doorsTimeline.single.state, 'pending');
      expect(detail.events.single.detail, {'force': false});
      expect(detail.accuracyM, 18);

      final matching = AdminCabinetSessionDetail.fromJson({...sessionJson(status: 'matching'), 'kind': 'admin'});
      expect(matching.notice, isNull);
      expect(matching.canDiscard, isTrue);

      final event = AdminCabinetEventRow.fromJson({
        'type': 'fault',
        'source': 'device',
        'channel': 2,
        'label': 'A02',
        'device_no': 'DV1',
        'session_no': null,
        'actor': null,
        'detail': {'code': 'LOCK_NO_RELEASE'},
        'result': 'ok',
        'occurred_at': '2026-09-28T10:00:00Z',
        'received_at': '2026-09-28T10:00:01Z',
      });
      expect(event.channel, 2);
      expect(event.detail!['code'], 'LOCK_NO_RELEASE');

      final report = AdminCabinetManualReport.fromJson({
        'report_no': 'MR1',
        'kind': 'deposit',
        'status': 'pending',
        'target_status': 'deposited',
        'reason': 'fault',
        'created_at': '2026-09-28T10:00:00Z',
        'user': {'user_no': 'MB1', 'nickname': '小明'},
        'order': {'order_id': 128, 'order_no': 'SMB1', 'status': 'pending_deposit'},
        'book': null,
        'titles': ['資料庫系統概論', '作業系統'],
        'reviewer_nickname': null,
      });
      expect(report.isPending, isTrue);
      expect(report.orderNo, 'SMB1');
      expect(report.orderStatus, 'pending_deposit');
      expect(report.bookId, isNull);
      expect(report.titles, hasLength(2));
    });
  });

  group('遠端開櫃與裝置配對', () {
    test('遠端開櫃回應依狀態判斷是否需要比對，缺少作業編號時為 null', () {
      final matching = AdminCabinetRemoteOpen.fromJson({'session_no': 'CS1', 'status': 'matching', 'remaining_ms': 60000})!;
      expect(matching.sessionNo, 'CS1');
      expect(matching.needsMatch, isTrue);
      expect(matching.remainingMs, 60000);
      final forced = AdminCabinetRemoteOpen.fromJson({'session_no': 'CS2', 'status': 'opening', 'remaining_ms': null})!;
      expect(forced.needsMatch, isFalse);
      expect(forced.remainingMs, isNull);
      expect(AdminCabinetRemoteOpen.fromJson({'status': 'matching'}), isNull);
      expect(AdminCabinetRemoteOpen.fromJson(null), isNull);
    });

    test('配對結果與配對碼格式', () {
      final result = AdminCabinetPairResult.fromJson({'kind': 'simulator', 'door_count': 2, 'has_door_sensor': false, 'firmware': 'sim-1.0.0'});
      expect(result.kind, 'simulator');
      expect(result.doorCount, 2);
      expect(result.hasDoorSensor, isFalse);
      expect(result.firmware, 'sim-1.0.0');
      expect(result.summary, isNull);

      expect(AdminCabinetPairing.codeOf('1234-5678'), '12345678');
      expect(AdminCabinetPairing.codeOf(' 1234 5678 '), '12345678');
      expect(AdminCabinetPairing.codeOf('12345678'), '12345678');
      for (final code in ['', '1234567', '123456789', '1234-567a', '１２３４５６７８']) {
        expect(AdminCabinetPairing.codeOf(code), isNull, reason: code);
      }
    });
  });

  group('CabinetSessionTracker', () {
    late StreamController<Map<String, dynamic>> pushes;
    late _FakeStopwatch clock;
    late List<String> fetched;
    late CabinetSession Function() next;

    CabinetSessionTracker tracker(CabinetSession initial) => CabinetSessionTracker(
      initial,
      changes: pushes.stream,
      stopwatch: clock,
      fetch: (no) async {
        fetched.add(no);
        return CabinetResult.success(next());
      },
    );

    setUp(() {
      pushes = StreamController<Map<String, dynamic>>.broadcast();
      clock = _FakeStopwatch();
      fetched = [];
      next = () => session(version: 6);
    });

    tearDown(() => pushes.close());

    test('倒數以伺服器剩餘時間減去收到後經過的時間計算，歸零後停在 0', () {
      final t = tracker(session(remainingMs: 24300));
      clock.ms = 4300;
      expect(t.remaining, const Duration(seconds: 20));
      clock.ms = 30000;
      expect(t.remaining, Duration.zero);

      t.accept(session(version: 7, remainingMs: 10000));
      expect(t.remaining, const Duration(seconds: 10));
      t.dispose();
    });

    test('較舊的版本與其他作業一律忽略', () {
      final t = tracker(session(version: 6));
      expect(t.accept(session(status: 'matching', version: 5)), isFalse);
      expect(t.session.status, 'open');
      expect(t.accept(CabinetSession.fromJson(sessionJson(no: 'CS0THER', version: 9))), isFalse);
      expect(t.accept(session(status: 'completed', version: 7)), isTrue);
      expect(t.session.status, 'completed');
      t.dispose();
    });

    test('推播只接受同一作業且版本較新的狀態', () async {
      final t = tracker(session(version: 6));
      var notified = 0;
      t.addListener(() => notified++);

      pushes.add(sessionJson(version: 6, status: 'completed'));
      pushes.add(sessionJson(no: 'CS0THER', version: 10, status: 'completed'));
      await Future<void>.delayed(Duration.zero);
      expect(t.session.status, 'open');
      expect(notified, 0);

      pushes.add(sessionJson(version: 7, status: 'completed', result: {'outcome': 'completed', 'code': 'COMPLETED', 'message': '作業完成'}));
      await Future<void>.delayed(Duration.zero);
      expect(t.session.status, 'completed');
      expect(t.session.result!.code, 'COMPLETED');
      expect(notified, 1);
      t.dispose();
    });

    test('輪詢間隔依狀態決定，結束或待確認後停止', () {
      Duration? intervalOf(String status) {
        final t = tracker(session(status: status));
        final interval = t.pollInterval;
        t.dispose();
        return interval;
      }

      expect(intervalOf('selecting'), const Duration(seconds: 2));
      expect(intervalOf('matching'), const Duration(seconds: 2));
      expect(intervalOf('opening'), const Duration(seconds: 1));
      expect(intervalOf('open'), const Duration(seconds: 1));
      expect(intervalOf('needs_review'), isNull);
      expect(intervalOf('expired'), isNull);
    });

    testWidgets('開門後每秒輪詢，收到終態即停止；暫停期間不輪詢，恢復時立即讀取', (tester) async {
      final t = tracker(session(status: 'open', version: 6));

      await tester.pump(const Duration(milliseconds: 1100));
      expect(fetched, ['CS8MZQ41K']);

      t.pause();
      await tester.pump(const Duration(seconds: 3));
      expect(fetched, hasLength(1));

      t.resume();
      await tester.pump();
      expect(fetched, hasLength(2));

      next = () => session(status: 'completed', version: 8, remainingMs: null);
      await tester.pump(const Duration(seconds: 1));
      expect(t.session.status, 'completed');
      final count = fetched.length;
      await tester.pump(const Duration(seconds: 5));
      expect(fetched.length, count);
      t.dispose();
    });

    testWidgets('讀取失敗時保留原狀態並記錄錯誤', (tester) async {
      final t = CabinetSessionTracker(
        session(status: 'matching'),
        changes: pushes.stream,
        stopwatch: clock,
        fetch: (_) async => CabinetResult.failure(const CabinetApiError(code: CabinetApiError.network)),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(t.session.status, 'matching');
      expect(t.lastError!.isNetwork, isTrue);
      t.dispose();
    });
  });

  test('RealtimeService 只轉發帶有作業編號的 cabinet:session 推播', () async {
    final received = <Map<String, dynamic>>[];
    final sub = RealtimeService.instance.cabinetSessionChanges.listen(received.add);

    RealtimeService.instance.handleCabinetSession({'session': sessionJson()});
    RealtimeService.instance.handleCabinetSession({'session': {'status': 'open'}});
    RealtimeService.instance.handleCabinetSession('noise');
    await Future<void>.delayed(Duration.zero);

    expect(received, hasLength(1));
    expect(received.single['session_no'], 'CS8MZQ41K');
    await sub.cancel();
  });
}
