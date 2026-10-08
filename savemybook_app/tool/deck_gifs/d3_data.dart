// D3 書櫃 GIF 的資料：故事主線為雪喵上架的《HTML & CSS：網站設計建置優化之道》（book_id 150，$250），
// 買家 es 下單、指定國立臺北商業大學書櫃（cabinet_id 2）。訂單編號與手冊第 10 節「待撥款項」相同。

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:savemybook_app/services/realtime_service.dart';

import '../manual_shots/manual_api.dart';
import 'd3_transit_data.dart';

const storyBookId = 150;
const sellerId = 21;
const cabinetId = 2;
const orderId = 88;
const door = 'A01';
const matchCode = '25';

/// 書櫃螢幕 QR Code 的內容（32 位十六進位權杖）。
const cabinetQr = 'savemybook://k/7c3e9a1f52b84d06a9e1c47f0b2d6835';

DateTime _at(int daysAgo, int hour, int minute, [int second = 0]) {
  final d = DateTime.now().subtract(Duration(days: daysAgo));
  return DateTime(d.year, d.month, d.day, hour, minute, second);
}

String _iso(DateTime local) => local.toUtc().toIso8601String();

String _two(int n) => n.toString().padLeft(2, '0');

final DateTime orderCreated = _at(1, 16, 32, 19);

/// 訂單編號格式比照伺服器：SMB + 年月日時分秒 + 6 位亂數。
final String orderNo =
    'SMB${orderCreated.year}${_two(orderCreated.month)}${_two(orderCreated.day)}${_two(orderCreated.hour)}${_two(orderCreated.minute)}${_two(orderCreated.second)}640512';

String agoNow({int days = 0, int hours = 0, int minutes = 0}) =>
    DateTime.now().subtract(Duration(days: days, hours: hours, minutes: minutes)).toUtc().toIso8601String();

/// 書籍資料改為存放在國立臺北商業大學書櫃。
Map<String, dynamic> storyBook() => bookJson(storyBookId, extra: {'cabinet_id': cabinetId, 'smart_cabinets': cabinetJson(cabinetId)});

String get bookTitle => storyBook()['title'] as String;

String get cabinetName => cabinetJson(cabinetId)['cabinet_name'] as String;

Map<String, dynamic> scanAccess() => {
  'mode': 'scan',
  'reason': null,
  'open_now': true,
  'open_time': '00:00',
  'close_time': '23:59',
  'available_doors': 3,
  'pre_deposit_doors': 1,
};

Map<String, dynamic> storyOrder(String status, {String? pickedUpAt, String? completedAt}) {
  final b = storyBook();
  final price = '${b['price']}';
  final doors = status == 'pending_deposit' ? const <String>[] : const [door];
  return {
    'order_id': orderId,
    'order_no': orderNo,
    'buyer_id': meId,
    'seller_id': sellerId,
    'total_amount': price,
    'status': status,
    'pickup_code': null,
    'cabinet_id': cabinetId,
    'created_at': _iso(orderCreated),
    'picked_up_at': pickedUpAt,
    'completed_at': completedAt,
    'order_items': [
      {'item_id': orderId * 10, 'book_id': storyBookId, 'quantity': 1, 'unit_price': price, 'subtotal': price, 'books': b},
    ],
    'smart_cabinets': cabinetJson(cabinetId),
    'cabinet_slots': doors.isEmpty ? null : {'slot_id': 7, 'slot_number': doors.first},
    'users_orders_buyer_idTousers': userJson(meId),
    'users_orders_seller_idTousers': userJson(sellerId),
    'transaction_disputes': <Object>[],
    'doors': doors,
    'cabinet_access': scanAccess(),
  };
}

/// 書櫃作業的假伺服器：依假時間計算各階段的倒數，每格以即時推播送出最新狀態（版本號遞增）。
class FakeCabinet {
  FakeCabinet(this.tester, {required this.kind});

  final WidgetTester tester;

  /// order_deposit（賣家依訂單存書）或 pickup（買家取書）。
  final String kind;

  String status = 'none';
  int version = 1;
  DateTime _start = DateTime(2000);
  int _phaseMs = 0;

  static const openMs = 30000;

  DateTime get _now => tester.binding.clock.now();

  bool get active => const {'selecting', 'matching', 'opening', 'open'}.contains(status);

  String get sessionNo => kind == 'pickup' ? 'CS7HW2Q5K' : 'CS4N7Q2KX';

  void phase(String next, [int ms = 0]) {
    status = next;
    _phaseMs = ms;
    _start = _now;
    version++;
  }

  int get remaining => math.max(0, _phaseMs - _now.difference(_start).inMilliseconds);

  Map<String, dynamic> json() {
    final book = storyBook();
    final selecting = status == 'selecting';
    final placed = !selecting || kind == 'pickup';
    final done = status == 'completed';
    final doorState = switch (status) {
      'open' => 'open',
      'completed' => 'closed',
      _ => 'pending',
    };
    return {
      'session_no': sessionNo,
      'status': status,
      'version': version,
      'cabinet': {...cabinetJson(cabinetId), 'available_doors': 3},
      'location_status': 'granted',
      'distance_m': 12,
      'items': [
        {
          'key': 'order:$orderId',
          'kind': kind,
          'order_id': orderId,
          'order_no': orderNo,
          'books': [
            {'book_id': storyBookId, 'title': book['title'], 'image_url': coverOf(storyBookId), 'door': placed ? door : null},
          ],
          'doors': [if (placed) door],
          'paused': false,
          'note': null,
          'selected': true,
          'blocked': null,
          'result': done ? 'done' : 'pending',
          'error': null,
        },
      ],
      'doors': [
        if (!selecting) {'label': door, 'state': doorState},
      ],
      'remaining_ms': active ? remaining : null,
      'open_ms': openMs,
      'notice': null,
      'result': done ? {'outcome': 'completed', 'code': 'COMPLETED', 'message': ''} : null,
      'created_at': agoNow(minutes: 1),
    };
  }

  /// 即時推播目前狀態；作業結束後不再推送。
  void push() {
    if (!active) return;
    version++;
    // ignore: invalid_use_of_visible_for_testing_member
    RealtimeService.instance.handleCabinetSession({'session': json()});
  }

  void routes() {
    ManualApi.on('POST', '/cabinet-sessions', (_) {
      phase('selecting', 60000);
      return json();
    });
    ManualApi.on('POST', '/cabinet-sessions/:no/start', (_) {
      phase('matching', 60000);
      return json();
    });
    ManualApi.on('POST', '/cabinet-sessions/:no/match', (r) {
      final code = (jsonDecode(r.body) as Map)['code'];
      if (code != matchCode) return {'success': false, 'code': 'CABINET_MATCH_CODE_WRONG', 'message': '數字不正確'};
      phase('opening', 10000);
      return json();
    });
    ManualApi.on('POST', '/cabinet-sessions/:no/close', (_) {
      phase('completed');
      return json();
    });
    ManualApi.on('GET', '/cabinet-sessions/:no', (_) => json());
    ManualApi.on('GET', '/cabinet-sessions/active', (_) => null);
  }
}

// ---------------------------------------------------------------------------
// 前往書櫃：國立臺北商業大學周邊交通資訊（d3_transit_data.dart，資料時間改為與狀態列 11:22 一致）。

const departureStation = '海山';

String _todayAt(int hour, int minute) {
  final d = DateTime.now();
  return DateTime(d.year, d.month, d.day, hour, minute).toUtc().toIso8601String();
}

Map<String, dynamic> cabinetNearby() {
  final data = jsonDecode(d3NearbyJson) as Map<String, dynamic>;
  final nearby = Map<String, dynamic>.from(data['nearby'] as Map);
  final cabinet = cabinetJson(cabinetId);
  const minutes = {'mrt': 21, 'bus': 21, 'youbike': 20, 'parking_lots': 18, 'roadside': 20, 'road_speed': 21, 'taxi_stands': 21};
  for (final MapEntry(:key, :value) in minutes.entries) {
    final section = Map<String, dynamic>.from(nearby[key] as Map);
    section['updated_at'] = _todayAt(11, value);
    nearby[key] = section;
  }
  final roadside = nearby['roadside'] as Map<String, dynamic>;
  for (final kind in ['car', 'motorcycle']) {
    for (final s in (roadside[kind] as List).cast<Map<String, dynamic>>()) {
      final live = s['live'];
      if (live is Map<String, dynamic>) live['updated_at'] = _todayAt(11, 20);
    }
  }
  return {
    'cabinet': {'latitude': double.parse('${cabinet['latitude']}'), 'longitude': double.parse('${cabinet['longitude']}')},
    ...nearby,
  };
}

const mrtStations = [
  {'name': '海山', 'latitude': 25.005393, 'longitude': 121.448636},
  {'name': '善導寺', 'latitude': 25.044823, 'longitude': 121.523208},
  {'name': '台北車站', 'latitude': 25.046255, 'longitude': 121.517532},
];

Map<String, dynamic> mrtFares(String from) {
  final data = jsonDecode(d3NearbyJson) as Map<String, dynamic>;
  return {'fares': data['fares']};
}

// ---------------------------------------------------------------------------
// 雪喵的代幣中心：交易紀錄比照手冊第 10 節，訂單完成後新增《HTML & CSS》的賣出收入。

List<Map<String, dynamic>> walletTransactions({required bool paid}) {
  var id = 40;
  var balance = 0;
  final rows = <Map<String, dynamic>>[];
  void t(String type, int amount, String description, DateTime at, {int? bookId, String? no, int? order}) {
    balance += amount;
    rows.add({
      'txn_id': ++id,
      'txn_no': 'TX${(id * 7919).toRadixString(36).toUpperCase()}Q${id}M',
      'type': type,
      'amount': amount,
      'balance_after': balance,
      'description': description,
      'created_at': _iso(at),
      'orders': no == null
          ? null
          : {
              'order_id': order ?? id,
              'order_no': no,
              'order_items': [
                {'books': bookId == storyBookId ? storyBook() : bookJson(bookId!)},
              ],
            },
    });
  }

  String no(DateTime t, int tail) => 'SMB${t.year}${_two(t.month)}${_two(t.day)}${_two(t.hour)}${_two(t.minute)}${_two(t.second)}$tail';
  final halfBlue = no(_at(5, 14, 6, 41), 528317);
  final powerPoint = no(_at(5, 20, 12, 8), 904265);
  final brainwash = no(_at(2, 10, 25, 37), 361904);
  final infoCancelled = no(_at(1, 23, 33, 11), 737248);
  final info = no(_at(1, 23, 34, 38), 118889);
  t('admin_adjust', 10000, '管理員調整：代幣儲值', _at(6, 9, 30));
  t('purchase', -140, '購買訂單 $halfBlue', _at(5, 14, 6, 41), bookId: 144, no: halfBlue);
  t('purchase', -220, '購買訂單 $powerPoint', _at(5, 20, 12, 8), bookId: 145, no: powerPoint);
  t('refund', 220, '訂單 $powerPoint 取消退款', _at(4, 9, 2), bookId: 145, no: powerPoint);
  t('purchase', -400, '購買訂單 $brainwash', _at(2, 10, 25, 37), bookId: 148, no: brainwash);
  t('purchase', -666, '購買訂單 $infoCancelled', _at(1, 23, 33, 11), bookId: 126, no: infoCancelled);
  t('refund', 666, '訂單 $infoCancelled 取消退款', _at(1, 23, 33, 52), bookId: 126, no: infoCancelled);
  t('purchase', -666, '購買訂單 $info', _at(1, 23, 34, 38), bookId: 126, no: info);
  t('refund', 400, '訂單 $brainwash 退款', _at(1, 23, 41, 5), bookId: 148, no: brainwash);
  if (paid) t('sale_income', 250, '賣出', DateTime.now(), bookId: storyBookId, no: orderNo, order: orderId);
  return rows.reversed.toList();
}

Map<String, dynamic> wallet({required bool paid}) {
  final rows = walletTransactions(paid: paid);
  final income = rows.where((r) => (r['amount'] as int) > 0).fold<int>(0, (s, r) => s + (r['amount'] as int));
  final expense = rows.where((r) => (r['amount'] as int) < 0).fold<int>(0, (s, r) => s - (r['amount'] as int));
  return {
    'balance': rows.first['balance_after'],
    'frozen_amount': 0,
    'total_income': income,
    'total_expense': expense,
    'pending_income': paid ? 0 : 250,
  };
}
