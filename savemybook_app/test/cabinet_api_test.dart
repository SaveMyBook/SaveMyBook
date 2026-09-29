import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:savemybook_app/i18n/strings.dart';
import 'package:savemybook_app/models/cabinet.dart';
import 'package:savemybook_app/services/api_service.dart';
import 'package:savemybook_app/services/location_service.dart';

const _token = '3f9c0a5e1d2b4c6a8e0f1a2b3c4d5e6f';

Map<String, dynamic> _session({String status = 'selecting', int version = 1}) => {
  'session_no': 'CS8MZQ41K',
  'status': status,
  'version': version,
  'cabinet': {'cabinet_id': 3, 'cabinet_name': '北商大書櫃', 'address': '臺北市'},
  'location_status': 'granted',
  'distance_m': 35,
  'items': [
    {'key': 'order:128', 'kind': 'pickup', 'order_id': 128, 'order_no': 'SMB1', 'books': [], 'doors': ['A02'], 'selected': true, 'result': 'pending'},
  ],
  'doors': [],
  'remaining_ms': 60000,
  'open_ms': null,
  'notice': null,
  'result': null,
  'created_at': '2026-09-28T10:30:00.000Z',
  'finished_at': null,
};

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json; charset=utf-8'});

class _Recorder {
  final List<http.Request> requests = [];

  Map<String, dynamic> bodyOf(int index) => jsonDecode(requests[index].body) as Map<String, dynamic>;

  String pathOf(int index) => requests[index].url.path;
}

Future<T> _withServer<T>(_Recorder recorder, Future<http.Response> Function(http.Request request) handler, Future<T> Function() body) =>
    http.runWithClient(body, () => MockClient((request) {
      recorder.requests.add(request);
      return handler(request);
    }));

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiService.authToken = 'token';
  });

  tearDown(() => ApiService.authToken = null);

  group('使用者作業 API', () {
    test('建立作業時送出正規化的 QR 內容、情境與當次定位', () async {
      final r = _Recorder();
      final result = await _withServer(r, (_) async => _json({'success': true, 'data': _session()}, 201), () {
        return ApiService().createCabinetSession(
          code: '  SAVEMYBOOK://K/${_token.toUpperCase()}/ ',
          context: const CabinetContext.order(128),
          location: const FreshLocation(status: FreshLocation.granted, lat: 25.0421, lng: 121.5254, accuracyM: 18, ageMs: 1200),
        );
      });

      expect(result.ok, isTrue);
      expect(result.session!.sessionNo, 'CS8MZQ41K');
      expect(r.requests.single.method, 'POST');
      expect(r.pathOf(0), '/api/cabinet-sessions');
      expect(r.requests.single.headers['Authorization'], 'Bearer token');
      expect(r.bodyOf(0), {
        'code': 'savemybook://k/$_token',
        'context': {'type': 'order', 'id': 128},
        'location_status': 'granted',
        'location': {'lat': 25.0421, 'lng': 121.5254, 'accuracy_m': 18.0, 'age_ms': 1200},
      });
    });

    test('拒絕定位時只送出狀態，不帶座標與情境', () async {
      final r = _Recorder();
      await _withServer(r, (_) async => _json({'success': true, 'data': _session()}, 201), () {
        return ApiService().createCabinetSession(code: 'savemybook://k/$_token', location: const FreshLocation(status: FreshLocation.denied));
      });
      expect(r.bodyOf(0), {'code': 'savemybook://k/$_token', 'location_status': 'denied'});
    });

    test('不是書櫃 QR Code 時不送出請求', () async {
      final r = _Recorder();
      final result = await _withServer(r, (_) async => _json({}), () {
        return ApiService().createCabinetSession(
          code: 'https://example.com/pay?id=1',
          location: const FreshLocation(status: FreshLocation.unavailable),
        );
      });
      expect(r.requests, isEmpty);
      expect(result.error!.code, 'CABINET_CODE_INVALID');
      expect(result.error!.message, S.notSavemybookLockerQrCode);
    });

    test('錯誤回應保留代碼、HTTP 狀態與附帶欄位', () async {
      final r = _Recorder();
      final result = await _withServer(
        r,
        (_) async => _json({'success': false, 'code': 'CABINET_TOO_FAR', 'message': '您目前的位置距離書櫃約 850 公尺，請於書櫃旁操作', 'distance_m': 850}, 403),
        () => ApiService().createCabinetSession(code: 'savemybook://k/$_token', location: const FreshLocation(status: FreshLocation.unavailable)),
      );
      expect(result.ok, isFalse);
      expect(result.error!.code, 'CABINET_TOO_FAR');
      expect(result.error!.status, 403);
      expect(result.error!.distanceM, 850);

      final offline = await _withServer(
        r,
        (_) async => _json({'success': false, 'code': 'CABINET_OFFLINE', 'message': '書櫃目前連線中斷，暫時無法使用', 'manual_allowed': true}, 409),
        () => ApiService().createCabinetSession(code: 'savemybook://k/$_token', location: const FreshLocation(status: FreshLocation.unavailable)),
      );
      expect(offline.error!.manualAllowed, isTrue);
    });

    test('網路錯誤回傳 NETWORK，已登出回傳 SIGNED_OUT', () async {
      final r = _Recorder();
      final network = await _withServer(r, (_) async => throw http.ClientException('offline'), () {
        return ApiService().fetchCabinetSession('CS8MZQ41K');
      });
      expect(network.error!.isNetwork, isTrue);
      expect(network.error!.message, S.networkError);

      final signedOut = await _withServer(
        r,
        (_) async => _json({'success': false, 'code': 'TOKEN_REVOKED', 'message': '登入已失效'}, 401),
        () => ApiService().fetchCabinetSession('CS8MZQ41K'),
      );
      expect(signedOut.error!.code, CabinetApiError.signedOut);
    });

    test('開始、讀取、取消與進行中作業的路徑', () async {
      final r = _Recorder();
      final responses = [
        _json({'success': true, 'data': _session(status: 'matching', version: 2)}),
        _json({'success': true, 'data': _session(status: 'matching', version: 2)}),
        _json({'success': true, 'data': _session(status: 'cancelled', version: 3)}),
        _json({'success': true, 'data': _session(status: 'open', version: 5)}),
        _json({'success': true, 'data': null}),
      ];
      var i = 0;
      await _withServer(r, (_) async => responses[i++], () async {
        final api = ApiService();
        final started = await api.startCabinetSession('CS8MZQ41K', ['order:128', 'book:55']);
        expect(started.session!.status, 'matching');
        await api.fetchCabinetSession('CS8MZQ41K');
        final cancelled = await api.cancelCabinetSession('CS8MZQ41K');
        expect(cancelled.session!.status, 'cancelled');
        expect((await api.fetchActiveCabinetSession())!.status, 'open');
        expect(await api.fetchActiveCabinetSession(), isNull);
      });

      expect([for (final q in r.requests) '${q.method} ${q.url.path}'], [
        'POST /api/cabinet-sessions/CS8MZQ41K/start',
        'GET /api/cabinet-sessions/CS8MZQ41K',
        'POST /api/cabinet-sessions/CS8MZQ41K/cancel',
        'GET /api/cabinet-sessions/active',
        'GET /api/cabinet-sessions/active',
      ]);
      expect(r.bodyOf(0), {'keys': ['order:128', 'book:55']});
    });

    test('比對送出兩位數字字串，格式不符時不送出請求', () async {
      final r = _Recorder();
      await _withServer(r, (_) async => _json({'success': true, 'data': _session(status: 'opening', version: 3)}), () async {
        final api = ApiService();
        for (final code in ['7', '09', '100', ' 37', '37 ', '３７', '']) {
          final rejected = await api.matchCabinetSession('CS8MZQ41K', code);
          expect(rejected.error!.code, CabinetApiError.matchCodeInvalid, reason: code);
          expect(rejected.error!.message, S.enterTwoDigits);
        }
        expect(r.requests, isEmpty);
        final matched = await api.matchCabinetSession('CS8MZQ41K', '37');
        expect(matched.session!.status, 'opening');
      });
      expect(r.requests.single.method, 'POST');
      expect(r.pathOf(0), '/api/cabinet-sessions/CS8MZQ41K/match');
      expect(r.bodyOf(0), {'code': '37'});
    });

    test('比對錯誤與格式不符的回應', () async {
      final r = _Recorder();
      final failed = await _withServer(
        r,
        (_) async => _json({
          'success': true,
          'data': {..._session(status: 'failed', version: 3), 'result': {'outcome': 'failed', 'code': 'MATCH_FAILED', 'message': '數字不符，本次作業已取消'}},
        }),
        () => ApiService().matchCabinetSession('CS8MZQ41K', '42'),
      );
      expect(failed.session!.status, 'failed');
      expect(failed.session!.result!.code, 'MATCH_FAILED');

      final invalid = await _withServer(
        r,
        (_) async => _json({'success': false, 'code': 'MATCH_CODE_INVALID', 'message': '請輸入兩位數字'}, 400),
        () => ApiService().matchCabinetSession('CS8MZQ41K', '42'),
      );
      expect(invalid.error!.code, CabinetApiError.matchCodeInvalid);
      expect(invalid.error!.status, 400);
    });

    test('開門後以完成或取消結束作業，書櫃拒絕時帶出關門提示', () async {
      final r = _Recorder();
      final responses = [
        _json({'success': true, 'data': _session(status: 'open', version: 7)}),
        _json({'success': true, 'data': {..._session(status: 'open', version: 8), 'notice': 'CLOSE_DOOR_FIRST'}}),
        _json({'success': false, 'code': 'CABINET_SESSION_STATE', 'message': '本次作業處理中，請稍候', 'session': _session(status: 'open', version: 9)}, 409),
      ];
      var i = 0;
      await _withServer(r, (_) async => responses[i++], () async {
        final api = ApiService();
        final done = await api.closeCabinetSession('CS8MZQ41K', CabinetCloseOutcome.completed);
        expect(done.session!.closeDoorFirst, isFalse);
        final refused = await api.closeCabinetSession('CS8MZQ41K', CabinetCloseOutcome.cancelled);
        expect(refused.session!.notice, CabinetSession.noticeCloseDoorFirst);
        expect(refused.session!.closeDoorFirst, isTrue);
        final busy = await api.closeCabinetSession('CS8MZQ41K', CabinetCloseOutcome.completed);
        expect(busy.error!.code, 'CABINET_SESSION_STATE');
        expect(busy.error!.session!.version, 9);
      });
      expect([for (final q in r.requests) '${q.method} ${q.url.path}'], List.filled(3, 'POST /api/cabinet-sessions/CS8MZQ41K/close'));
      expect(r.bodyOf(0), {'outcome': 'completed'});
      expect(r.bodyOf(1), {'outcome': 'cancelled'});
    });

    test('項目已變更時錯誤附帶最新的作業', () async {
      final r = _Recorder();
      final result = await _withServer(
        r,
        (_) async => _json({'success': false, 'code': 'CABINET_ITEMS_CHANGED', 'message': '部分項目狀態已變更，請重新確認', 'session': _session(version: 1)}, 409),
        () => ApiService().startCabinetSession('CS8MZQ41K', ['order:128']),
      );
      expect(result.error!.session!.sessionNo, 'CS8MZQ41K');
    });
  });

  group('故障備援的手動回報', () {
    test('回應 202 時帶出待客服確認的回報', () async {
      final r = _Recorder();
      final report = {'report_no': 'MR4K2Q8ZT', 'kind': 'pickup', 'status': 'pending', 'reason': 'offline', 'target_status': 'picked_up'};
      final result = await _withServer(
        r,
        (_) async => _json({'success': true, 'message': '已送出手動回報，待客服確認後生效', 'data': {'order_id': 128, 'manual_report': report}}, 202),
        () => ApiService().reportOrderManually(128, 'picked_up'),
      );
      expect(r.requests.single.method, 'PATCH');
      expect(r.pathOf(0), '/api/orders/128/status');
      expect(r.bodyOf(0), {'status': 'picked_up'});
      expect(result.ok, isTrue);
      expect(result.pending, isTrue);
      expect(result.report!.reportNo, 'MR4K2Q8ZT');
    });

    test('回報取回一律待客服確認', () async {
      final r = _Recorder();
      final report = {'report_no': 'MR7P3X2QW', 'kind': 'retrieve', 'status': 'pending', 'reason': 'no_device', 'target_status': null};
      final result = await _withServer(
        r,
        (_) async => _json({
          'success': true,
          'message': '已送出手動回報，待客服確認後生效',
          'data': {'book_id': 55, 'status': 'removed', 'restored': false, 'manual_report': report},
        }, 202),
        () => ApiService().reportBookRetrievalManually(55),
      );
      expect(r.requests.single.method, 'POST');
      expect(r.pathOf(0), '/api/books/55/retrieve');
      expect(result.ok, isTrue);
      expect(result.pending, isTrue);
      expect(result.report!.kind, 'retrieve');
    });

    test('裝置已恢復時回報 CABINET_SCAN_REQUIRED', () async {
      final r = _Recorder();
      final result = await _withServer(
        r,
        (_) async => _json({'success': false, 'code': 'CABINET_SCAN_REQUIRED', 'message': '此書櫃已啟用掃碼存取，請至書櫃以 App 掃描 QR Code 辦理', 'cabinet_id': 3}, 409),
        () => ApiService().reportBookDepositManually(55),
      );
      expect(r.pathOf(0), '/api/books/55/deposit');
      expect(result.ok, isFalse);
      expect(result.scanRequired, isTrue);
      expect(result.error, contains('掃碼'));
    });

    test('訂單正於書櫃辦理中時，取消訂單與提出爭議依代碼顯示訊息', () async {
      final r = _Recorder();
      final busy = {'success': false, 'code': 'ORDER_IN_CABINET_SESSION', 'message': 'server message'};
      final cancelError = await _withServer(r, (_) async => _json(busy, 409), () => ApiService().cancelOrder(128));
      final disputeError = await _withServer(r, (_) async => _json(busy, 409), () => ApiService().submitDispute(orderNo: 'SMB20260928143015123456', reason: '書況不符'));
      expect(r.pathOf(0), '/api/orders/128/cancel');
      expect(r.pathOf(1), '/api/disputes');
      expect(r.bodyOf(1)['order_no'], 'SMB20260928143015123456');
      expect(r.bodyOf(1).containsKey('order_id'), isFalse);
      expect(cancelError, S.orderBeingHandledLockerPleaseTry);
      expect(disputeError, S.orderBeingHandledLockerPleaseTry);
    });
  });

  group('後台書櫃裝置 API', () {
    test('裝置摘要', () async {
      final r = _Recorder();
      final summary = await _withServer(
        r,
        (_) async => _json({
          'success': true,
          'data': {
            'cabinet': {'cabinet_id': 3, 'cabinet_name': '北商大書櫃'},
            'access': {'mode': 'scan', 'reason': null, 'online': true, 'open_now': true},
            'simulator_enabled': false,
            'kiosk_url': null,
            'device': null,
            'pairing': null,
            'active_session_no': null,
            'doors': [],
            'unplaced': [],
          },
        }),
        () => ApiService().fetchCabinetDevice(3),
      );
      expect(r.pathOf(0), '/api/admin/cabinets/3/device');
      expect(summary!.access.isScan, isTrue);
      expect(summary.device, isNull);
    });

    test('輸入配對碼綁定裝置，回應附裝置資訊與摘要', () async {
      final r = _Recorder();
      final summary = {
        'cabinet': {'cabinet_id': 3, 'cabinet_name': '北商大書櫃'},
        'access': {'mode': 'manual', 'reason': 'no_device', 'online': false, 'open_now': true},
        'device': null,
        'pairing': {'kind': 'esp32', 'door_count': 4, 'has_door_sensor': true, 'firmware': 'esp-1.0.0', 'expires_at': '2026-09-28T10:10:00Z'},
        'doors': [],
        'unplaced': [],
      };
      final result = await _withServer(
        r,
        (_) async => _json({
          'success': true,
          'message': '已送出配對，裝置連線後即完成',
          'data': {'kind': 'esp32', 'door_count': 4, 'has_door_sensor': true, 'firmware': 'esp-1.0.0', 'summary': summary},
        }, 201),
        () => ApiService().pairCabinetDevice(3, ' 1234-5678 '),
      );
      expect(r.requests.single.method, 'POST');
      expect(r.pathOf(0), '/api/admin/cabinets/3/device/pair');
      expect(r.bodyOf(0), {'code': '12345678'});
      expect(result.error, isNull);
      expect(result.paired!.kind, 'esp32');
      expect(result.paired!.doorCount, 4);
      expect(result.paired!.hasDoorSensor, isTrue);
      expect(result.paired!.firmware, 'esp-1.0.0');
      expect(result.paired!.summary!.pairing!.hasDoorSensor, isTrue);
      expect(result.paired!.summary!.device, isNull);

      final invalid = await _withServer(
        r,
        (_) async => _json({'success': false, 'code': 'PAIRING_CODE_INVALID', 'message': '配對碼無效或已逾時'}, 400),
        () => ApiService().pairCabinetDevice(3, '1234'),
      );
      expect(r.bodyOf(1), {'code': '1234'});
      expect(invalid.paired, isNull);
      expect(invalid.error!.code, 'PAIRING_CODE_INVALID');
    });

    test('遠端開櫃：需比對、直接開啟、冷卻與空門限制', () async {
      final r = _Recorder();
      final responses = [
        _json({'success': true, 'message': '請輸入書櫃螢幕上顯示的數字', 'data': {'session_no': 'CS1', 'status': 'matching', 'remaining_ms': 60000}}, 201),
        _json({'success': true, 'message': '已送出開門指令', 'data': {'session_no': 'CS2', 'status': 'opening', 'remaining_ms': 20000}}, 201),
        _json({'success': false, 'code': 'DOOR_NOT_EMPTY', 'message': '櫃門內有存放紀錄或待確認，須完成數字確認後開啟'}, 409),
        _json({'success': false, 'code': 'CABINET_COOLDOWN', 'message': '數字確認多次未完成，請於 8 分鐘後再試', 'retry_after_s': 452}, 429),
      ];
      var i = 0;
      await _withServer(r, (_) async => responses[i++], () async {
        final api = ApiService();
        final open = await api.openCabinetDoor(3, 41, ' 協助賣家取回書籍 ');
        expect(open.opened!.sessionNo, 'CS1');
        expect(open.opened!.needsMatch, isTrue);
        expect(open.opened!.remainingMs, 60000);
        final forced = await api.openCabinetDoor(3, 41, '測試電磁鎖', force: true);
        expect(forced.opened!.status, 'opening');
        expect(forced.opened!.needsMatch, isFalse);
        final rejected = await api.openCabinetDoor(3, 42, '測試電磁鎖', force: true);
        expect(rejected.opened, isNull);
        expect(rejected.error!.code, 'DOOR_NOT_EMPTY');
        final cooling = await api.openCabinetDoor(3, 42, '協助賣家取回書籍');
        expect(cooling.error!.code, 'CABINET_COOLDOWN');
        expect(cooling.error!.retryAfterS, 452);
      });
      expect(r.pathOf(0), '/api/admin/cabinets/3/doors/41/open');
      expect(r.bodyOf(0), {'reason': '協助賣家取回書籍', 'force': false});
      expect(r.bodyOf(1)['force'], isTrue);
    });

    test('遠端開櫃的比對與結束作業', () async {
      final r = _Recorder();
      Map<String, dynamic> detail(String status, {String? notice}) => {
        ..._session(status: status, version: 4),
        'kind': 'admin',
        'notice': notice,
        'doors_timeline': [],
        'events': [],
      };
      final responses = [
        _json({'success': true, 'data': detail('opening')}),
        _json({'success': false, 'code': 'CABINET_SESSION_STATE', 'message': '目前無法執行此操作', 'session': _session(status: 'expired', version: 5)}, 409),
        _json({'success': true, 'message': '已要求書櫃結束作業', 'data': detail('open', notice: 'CLOSE_DOOR_FIRST')}),
        _json({'success': false, 'code': 'CABINET_SESSION_NOT_FOUND', 'message': '找不到此書櫃作業'}, 404),
      ];
      var i = 0;
      await _withServer(r, (_) async => responses[i++], () async {
        final api = ApiService();
        final invalid = await api.matchRemoteCabinetSession('CS1', '5');
        expect(invalid.error!.code, CabinetApiError.matchCodeInvalid);
        final matched = await api.matchRemoteCabinetSession('CS1', '42');
        expect(matched.detail!.status, 'opening');
        expect(matched.detail!.isAdmin, isTrue);
        final expired = await api.matchRemoteCabinetSession('CS1', '42');
        expect(expired.detail, isNull);
        expect(expired.error!.session!.status, 'expired');
        final closing = await api.closeRemoteCabinetSession('CS1');
        expect(closing.detail!.closeDoorFirst, isTrue);
        final other = await api.closeRemoteCabinetSession('CS9');
        expect(other.error!.code, 'CABINET_SESSION_NOT_FOUND');
      });
      expect([for (final q in r.requests) '${q.method} ${q.url.path}'], [
        'POST /api/admin/cabinet-sessions/CS1/match',
        'POST /api/admin/cabinet-sessions/CS1/match',
        'POST /api/admin/cabinet-sessions/CS1/close',
        'POST /api/admin/cabinet-sessions/CS9/close',
      ]);
      expect(r.bodyOf(0), {'code': '42'});
      expect(r.requests[2].body, isEmpty);
    });

    test('身分驗證取消時標示為已取消', () async {
      ApiService.onVerificationRequired = (_) async => null;
      addTearDown(() => ApiService.onVerificationRequired = null);
      final cancelled = await http.runWithClient(
        () => ApiService().pairCabinetDevice(3, '1234-5678'),
        () => MockClient((_) async => _json({
          'success': false,
          'code': 'VERIFICATION_REQUIRED',
          'message': '請驗證身分',
          'verification': {'scope': 'admin', 'methods': ['password']},
        }, 403)),
      );
      expect(cancelled.paired, isNull);
      expect(cancelled.error!.isVerificationCancelled, isTrue);
    });

    test('櫃門操作的路徑與內容', () async {
      final r = _Recorder();
      await _withServer(r, (_) async => _json({'success': true, 'data': {}}), () async {
        final api = ApiService();
        expect(await api.placeCabinetDoorItems(3, 41, orderId: 128), isNull);
        expect(await api.placeCabinetDoorItems(3, 41, bookIds: [55, 56]), isNull);
        expect(await api.confirmCabinetDoor(3, 41, note: ' 現場確認 '), isNull);
        expect(await api.confirmCabinetDoor(3, 41), isNull);
        expect(await api.clearCabinetDoor(3, 41, removed: true, reason: '人員已取出'), isNull);
        expect(await api.clearCabinetDoor(3, 41, removed: false, reason: '紀錄有誤'), isNull);
        expect(await api.clearCabinetFault(3, slotId: 41), isNull);
        expect(await api.clearCabinetFault(3), isNull);
        expect(await api.revokeCabinetDevice(3, reason: '更換主機板'), isNull);
      });
      expect([for (final q in r.requests) '${q.method} ${q.url.path}'], [
        'POST /api/admin/cabinets/3/doors/41/place',
        'POST /api/admin/cabinets/3/doors/41/place',
        'POST /api/admin/cabinets/3/doors/41/check-clear',
        'POST /api/admin/cabinets/3/doors/41/check-clear',
        'POST /api/admin/cabinets/3/doors/41/clear',
        'POST /api/admin/cabinets/3/doors/41/clear',
        'POST /api/admin/cabinets/3/doors/41/fault-clear',
        'POST /api/admin/cabinets/3/device/fault-clear',
        'DELETE /api/admin/cabinets/3/device',
      ]);
      expect(r.bodyOf(0), {'order_id': 128});
      expect(r.bodyOf(1), {'book_ids': [55, 56]});
      expect(r.bodyOf(2), {'note': '現場確認'});
      expect(r.bodyOf(3), isEmpty);
      expect(r.bodyOf(4), {'mode': 'removed', 'reason': '人員已取出'});
      expect(r.bodyOf(5), {'mode': 'correct', 'reason': '紀錄有誤'});
      expect(r.bodyOf(8), {'reason': '更換主機板'});
    });

    test('作業、事件與手動回報的列表、處理與分頁', () async {
      final r = _Recorder();
      await _withServer(r, (request) async {
        final path = request.url.path;
        if (path.endsWith('/sessions')) {
          return _json({
            'success': true,
            'pagination': {'total': 25, 'page': 1, 'limit': 20, 'total_pages': 2},
            'data': [
              {'session_no': 'CS1', 'kind': 'user', 'status': 'needs_review', 'item_kinds': ['pickup'], 'doors': ['A02']},
            ],
          });
        }
        if (path.endsWith('/events')) {
          return _json({
            'success': true,
            'pagination': {'total': 1, 'page': 1, 'limit': 20, 'total_pages': 1},
            'data': [
              {'type': 'fault', 'source': 'device', 'detail': {'code': 'POWER'}},
            ],
          });
        }
        if (path.endsWith('/manual-reports')) {
          return _json({
            'success': true,
            'pagination': {'total': 1, 'page': 1, 'limit': 20, 'total_pages': 1},
            'data': [
              {'report_no': 'MR1', 'kind': 'retrieve', 'status': 'pending', 'book': {'book_id': 55, 'book_no': 'BK1', 'title': '作業系統'}, 'titles': ['作業系統']},
            ],
          });
        }
        if (path.startsWith('/api/admin/cabinet-sessions/') && request.method == 'GET') {
          return _json({'success': true, 'data': {..._session(status: 'needs_review'), 'kind': 'user', 'doors_timeline': [], 'events': []}});
        }
        if (path.endsWith('/confirm')) {
          return _json({'success': false, 'code': 'MANUAL_REPORT_STALE', 'message': '項目狀態已變更，此手動回報已失效'}, 409);
        }
        return _json({'success': true, 'data': {}});
      }, () async {
        final api = ApiService();
        final sessions = await api.fetchCabinetSessions(3, status: 'review');
        expect(sessions.ok, isTrue);
        expect(sessions.hasMore, isTrue);
        expect(sessions.items.single.status, 'needs_review');
        final detail = await api.fetchCabinetSessionDetail('CS1');
        expect(detail!.needsReview, isTrue);
        expect(await api.resolveCabinetSession('CS1', commit: true, note: ' 已至現場確認 '), isNull);
        final events = await api.fetchCabinetEvents(3, type: 'fault', page: 1);
        expect(events.hasMore, isFalse);
        expect(events.items.single.detail!['code'], 'POWER');
        final reports = await api.fetchCabinetManualReports(3);
        expect(reports.items.single.bookTitle, '作業系統');
        expect(await api.confirmCabinetManualReport('MR1'), '項目狀態已變更，此手動回報已失效');
        expect(await api.rejectCabinetManualReport('MR1', note: '書籍仍在櫃內'), isNull);
      });

      expect(r.requests[0].url.queryParameters, {'status': 'review', 'page': '1', 'limit': '20'});
      expect(r.pathOf(1), '/api/admin/cabinet-sessions/CS1');
      expect(r.pathOf(2), '/api/admin/cabinet-sessions/CS1/resolve');
      expect(r.bodyOf(2), {'action': 'commit', 'note': '已至現場確認'});
      expect(r.requests[3].url.queryParameters, {'type': 'fault', 'page': '1', 'limit': '20'});
      expect(r.requests[4].url.queryParameters, {'status': 'pending', 'page': '1', 'limit': '20'});
      expect(r.pathOf(5), '/api/admin/cabinet-manual-reports/MR1/confirm');
      expect(r.bodyOf(5), isEmpty);
      expect(r.pathOf(6), '/api/admin/cabinet-manual-reports/MR1/reject');
      expect(r.bodyOf(6), {'note': '書籍仍在櫃內'});
    });

    test('讀取失敗時列表標示為失敗', () async {
      final r = _Recorder();
      final page = await _withServer(
        r,
        (_) async => _json({'success': false, 'message': '伺服器錯誤'}, 500),
        () => ApiService().fetchCabinetSessions(3),
      );
      expect(page.ok, isFalse);
      expect(page.items, isEmpty);
    });
  });
}
