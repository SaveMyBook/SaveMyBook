// 第 7、8、9、11 節截圖用的資料：以真實書籍、書櫃與使用者組合訂單、書櫃作業、交通資訊、爭議、通知與客服工單。

import 'manual_api.dart';

// 第 7 節：Gary 賣出「數學大歷史」，存放於國立臺北商業大學書櫃 A01，買家為 es。
const cabBookId = 98;
const cabSellerId = 11;
const cabCabinetId = 2;
const cabOrderId = 412;
const cabOrderNo = 'SMB20261007111804517306';
const cabDoor = 'A01';

// 第 8、9 節：es 向 KJ 購買「International Management Behavior」，指定國立國父紀念館書櫃（原圖為 KJ 的「行銷學」，真實資料中已無此書）。
const disBookId = 115;
const disSellerId = 7;
const disCabinetId = 4;
const disOrderId = 398;
const disOrderNo = 'SMB20261006232252888428';
const otherOrderNo = 'SMB20261006233438118889';

/// 相對時間（「N 分鐘前」）以拍攝當下計算；manual_api 的 ago() 以載入時間為準，整批執行時會逐漸偏差。
String agoNow({int days = 0, int hours = 0, int minutes = 0}) =>
    DateTime.now().subtract(Duration(days: days, hours: hours, minutes: minutes)).toUtc().toIso8601String();

String _price(int bookId) => '${bookJson(bookId)['price']}';

Map<String, dynamic> orderJson({
  required int id,
  required String no,
  required int bookId,
  required int cabinetId,
  required String status,
  required String createdAt,
  int buyerId = meId,
  String? pickedUpAt,
  List<String> doors = const [],
  Map<String, dynamic>? access,
  List<Map<String, dynamic>> disputes = const [],
}) {
  final b = bookJson(bookId);
  final price = _price(bookId);
  return {
    'order_id': id,
    'order_no': no,
    'buyer_id': buyerId,
    'seller_id': b['seller_id'],
    'total_amount': price,
    'status': status,
    'pickup_code': null,
    'cabinet_id': cabinetId,
    'created_at': createdAt,
    'picked_up_at': pickedUpAt,
    'completed_at': null,
    'order_items': [
      {'item_id': id * 10, 'book_id': bookId, 'quantity': 1, 'unit_price': price, 'subtotal': price, 'books': b},
    ],
    'smart_cabinets': cabinetJson(cabinetId),
    'cabinet_slots': doors.isEmpty ? null : {'slot_id': id, 'slot_number': doors.first},
    'users_orders_buyer_idTousers': userJson(buyerId),
    'users_orders_seller_idTousers': userJson(b['seller_id'] as int),
    'transaction_disputes': disputes,
    'doors': doors,
    'cabinet_access': ?access,
  };
}

Map<String, dynamic> scanAccess() => {
  'mode': 'scan',
  'reason': null,
  'open_now': true,
  'open_time': '00:00',
  'close_time': '23:59',
  'available_doors': 3,
  'pre_deposit_doors': 1,
};

Map<String, dynamic> cabOrder(String status, {String? pickedUpAt}) => orderJson(
  id: cabOrderId,
  no: cabOrderNo,
  bookId: cabBookId,
  cabinetId: cabCabinetId,
  status: status,
  createdAt: agoNow(days: 1, hours: 2),
  pickedUpAt: pickedUpAt,
  doors: status == 'pending_deposit' ? const [] : const [cabDoor],
  access: scanAccess(),
);

/// 書櫃作業（GET /cabinet-sessions/:no 的回應）。[kind] 為 order_deposit（賣家存書）或 pickup（買家取書）。
Map<String, dynamic> cabinetSessionJson(String kind, String status, {int? remainingMs, Map<String, dynamic>? result, bool done = false}) {
  final book = bookJson(cabBookId);
  final selecting = status == 'selecting';
  final placed = !selecting || kind == 'pickup';
  final doorState = switch (status) {
    'open' => 'open',
    'completed' => 'closed',
    _ => 'pending',
  };
  return {
    'session_no': kind == 'pickup' ? 'CS7HW2Q5K' : 'CS4N7Q2KX',
    'status': status,
    'version': 3,
    'cabinet': {...cabinetJson(cabCabinetId), 'available_doors': 3},
    'location_status': 'granted',
    'distance_m': 12,
    'items': [
      {
        'key': 'order:$cabOrderId',
        'kind': kind,
        'order_id': cabOrderId,
        'order_no': cabOrderNo,
        'books': [
          {'book_id': cabBookId, 'title': book['title'], 'image_url': coverOf(cabBookId), 'door': placed ? cabDoor : null},
        ],
        'doors': [if (placed) cabDoor],
        'paused': false,
        'note': null,
        'selected': true,
        'blocked': null,
        'result': done ? 'done' : 'pending',
        'error': null,
      },
    ],
    'doors': [
      if (!selecting) {'label': cabDoor, 'state': doorState},
    ],
    'remaining_ms': remainingMs,
    'open_ms': 60000,
    'notice': null,
    'result': result,
    'created_at': agoNow(minutes: 1),
  };
}

// 第 8 節：國立國父紀念館書櫃（信義路四段與敦化南路口）周邊交通資訊，內容取自原實機截圖（臺北市資料大平臺即時資料）。
const departureStation = '海山';

Map<String, dynamic> _at(double lat, double lng, int distance) => {'latitude': lat, 'longitude': lng, 'distance_m': distance};

Map<String, dynamic> _route(String name, String direction, String status, [int? minutes]) =>
    {'name': name, 'direction': direction, 'status': status, 'minutes': minutes};

Map<String, dynamic> _bike(String name, String address, double lat, double lng, int distance, int rent, int giveBack) => {
  'name': name,
  'address': address,
  ..._at(lat, lng, distance),
  'available_rent': rent,
  'available_return': giveBack,
  'total': rent + giveBack,
  'is_active': true,
};

Map<String, dynamic> cabinetNearby() {
  final cabinet = cabinetJson(disCabinetId);
  return {
    'cabinet': {'latitude': double.parse('${cabinet['latitude']}'), 'longitude': double.parse('${cabinet['longitude']}')},
    'mrt': {
      'status': 'ok',
      'updated_at': todayAt(23, 29),
      'stations': [
        {
          'name': '大安',
          'distance_m': 372,
          'nearest_exit': {'exit': '4', 'accessible': false, ..._at(25.0331, 121.5440, 372)},
          'accessible_exit': {'exit': '3', 'facility': 'elevator', ..._at(25.0334, 121.5437, 401)},
        },
        {
          'name': '信義安和',
          'distance_m': 478,
          'nearest_exit': {'exit': '2', 'accessible': false, ..._at(25.0330, 121.5524, 478)},
          'accessible_exit': {'exit': '2A', 'facility': 'elevator', ..._at(25.0332, 121.5527, 506)},
        },
      ],
    },
    'bus': {
      'status': 'ok',
      'updated_at': todayAt(23, 29),
      'realtime_available': true,
      'stops': [
        {
          'name': '信義敦化路口',
          'address': '信義路上近敦化南路同向公車專用道(向東)',
          ..._at(25.0331, 121.5486, 92),
          'routes': [
            _route('信義幹線', '威剛科技總部大樓', 'arriving', 0),
            _route('22', '松德站', 'minutes', 8),
            _route('20', '永春高中', 'minutes', 20),
            _route('0東', '瑞湖街口', 'last_passed'),
            _route('88', '南港高工(重陽)', 'last_passed'),
            _route('226', '吳興街', 'last_passed'),
            _route('611', '仁愛國小', 'last_passed'),
            _route('621', '福德街', 'last_passed'),
            _route('668', '中研院', 'last_passed'),
          ],
        },
        {
          'name': '大安國中',
          'address': '敦化南路二段26號同向(向南)',
          ..._at(25.0318, 121.5490, 101),
          'routes': [
            _route('902', '大我新舍', 'minutes', 7),
            _route('敦化幹線', '麟光站', 'minutes', 15),
            _route('52', '景明街口', 'minutes', 34),
            _route('294', '富德', 'last_passed'),
            _route('556', '富德', 'last_passed'),
            _route('1503', '新店', 'last_passed'),
          ],
        },
        {
          'name': '大安國中',
          'address': '敦化南路二段32號同向(向南)',
          ..._at(25.0315, 121.5491, 112),
          'routes': [
            _route('688', '尖山腳', 'last_passed'),
            _route('905', '碧瑤', 'last_passed'),
            _route('905副', '碧瑤', 'last_passed'),
          ],
        },
        {
          'name': '信義敦化路口',
          'address': '敦化南路一段362號(專用道)(向南)',
          ..._at(25.0340, 121.5489, 158),
          'routes': [
            _route('902', '大我新舍', 'minutes', 6),
            _route('敦化幹線', '麟光站', 'minutes', 14),
            _route('52', '景明街口', 'minutes', 33),
            _route('33', '成福宮', 'last_passed'),
            _route('294', '富德', 'last_passed'),
            _route('556', '富德', 'last_passed'),
            _route('688', '尖山腳', 'last_passed'),
            _route('905', '碧瑤', 'last_passed'),
            _route('905副', '碧瑤', 'last_passed'),
          ],
        },
      ],
    },
    'road_speed': {
      'status': 'ok',
      'updated_at': todayAt(23, 22),
      'sections': [
        {'road': '敦化南路', 'between': '和平東路-信義路', 'speed_kph': 54, 'level': 'smooth', 'distance_m': 120},
        {'road': '敦化南路', 'between': '信義路-仁愛路', 'speed_kph': 41, 'level': 'smooth', 'distance_m': 180},
        {'road': '信義路四段', 'between': '復興南路-大安路一段', 'speed_kph': 48, 'level': 'smooth', 'distance_m': 260},
      ],
    },
    'taxi_stands': {
      'status': 'ok',
      'updated_at': todayAt(23, 22),
      'stands': [
        {'name': '信義敦化招呼站', 'street': '信義路四段1號前', 'spaces': 3, 'hours': '0~24', ..._at(25.0333, 121.5482, 64)},
      ],
    },
    'youbike': {
      'status': 'ok',
      'updated_at': todayAt(23, 28),
      'stations': [
        _bike('信義四維路口', '信義路四段/四維路口', 25.0330, 121.5468, 82, 4, 15),
        _bike('信義大安路口(信維大樓)', '信義路四段/大安路一段口', 25.0334, 121.5463, 128, 6, 12),
        _bike('敦化信義路口(東南側)', '敦化南路二段/信義路四段口東南側', 25.0326, 121.5491, 151, 8, 12),
        _bike('德安公園(四維路66巷)', '四維路66巷', 25.0315, 121.5462, 219, 6, 16),
        _bike('信義敦化路口', '信義路四段/敦化南路口', 25.0336, 121.5492, 232, 11, 39),
      ],
    },
    'parking_lots': {
      'status': 'ok',
      'updated_at': todayAt(23, 22),
      'realtime_available': true,
      'lots': [
        {
          'name': '168停車聯盟-中華信義場',
          'address': '信義路四段',
          'fee': '計時：小型車80元/時，停車全程以半小時計。月租：小型車平面車位7,000元/月，機械大車位5,500元/月，機械小車位5,000元/月。',
          'hours': '00:00:00-23:59:59',
          ..._at(25.0327, 121.5478, 31),
          'car': {'total': 124, 'available': 51},
          'motorcycle': {'total': 0, 'available': 0},
        },
        {
          'name': 'USPACE信義四維停車場',
          'address': '四維路',
          'fee': '小型車：計時 150元/時，未滿1小時以1小時計，逾1小時以上，未滿半小時以半小時計;月租 全日15,000元',
          'hours': '00:00:00-23:59:59',
          ..._at(25.0324, 121.5469, 78),
          'car': {'total': 3, 'available': 0},
          'motorcycle': {'total': 0, 'available': 0},
        },
        {
          'name': '大安國中地下停車場',
          'address': '敦化南路二段',
          'fee': '小型車：計時 40元/時',
          'hours': '00:00:00-23:59:59',
          ..._at(25.0312, 121.5493, 168),
          'car': {'total': 210, 'available': 37},
          'motorcycle': {'total': 0, 'available': 0},
        },
      ],
    },
    'roadside': {
      'status': 'ok',
      'radius_m': 300,
      'updated_at': todayAt(23, 22),
      'car': <Object>[],
      'motorcycle': <Object>[],
    },
    'attribution': '資料來源：臺北市資料大平臺（data.taipei），依政府資料開放授權條款第 1 版使用',
    'sources': <Object>[],
  };
}

const mrtStations = [
  {'name': '海山', 'latitude': 25.005393, 'longitude': 121.448636},
  {'name': '大安', 'latitude': 25.033041, 'longitude': 121.543409},
  {'name': '信義安和', 'latitude': 25.033322, 'longitude': 121.553118},
  {'name': '忠孝復興', 'latitude': 25.041629, 'longitude': 121.543767},
  {'name': '台北車站', 'latitude': 25.046255, 'longitude': 121.517532},
];

Map<String, dynamic> mrtFares(String from) => {
  'fares': [
    {'from': from, 'to': '大安', 'fare': 40, 'concession_fare': 16, 'distance_km': 14.7},
    {'from': from, 'to': '信義安和', 'fare': 40, 'concession_fare': 16, 'distance_km': 15.7},
  ],
};
