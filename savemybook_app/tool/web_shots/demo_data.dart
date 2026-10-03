import 'dart:convert';
import 'dart:ui';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:savemybook_app/utils/api_helpers.dart';

const meId = 1;

final _now = DateTime.now();

String ago({int days = 0, int hours = 0, int minutes = 0}) =>
    _now.subtract(Duration(days: days, hours: hours, minutes: minutes)).toUtc().toIso8601String();

String todayAt(int hour, int minute, {int daysAgo = 0}) {
  final d = _now.subtract(Duration(days: daysAgo));
  return DateTime(d.year, d.month, d.day, hour, minute).toUtc().toIso8601String();
}

String isbn13(String first12) {
  var sum = 0;
  for (var i = 0; i < 12; i++) {
    sum += int.parse(first12[i]) * (i.isEven ? 1 : 3);
  }
  return '$first12${(10 - sum % 10) % 10}';
}

const users = <int, String>{1: '海嫄', 2: '陳柏翰', 3: '林冠宇', 4: '王思涵', 5: '張家豪', 6: '李欣怡', 7: '黃子軒', 8: '吳品妤', 9: '劉宜庭', 10: '周育廷'};

Map<String, dynamic> user(int id) => {
  'user_id': id,
  'nickname': users[id],
  'email': id == meId ? 'haewon@example.com' : 'member$id@example.com',
  'avatar_url': null,
  'role': 'buyer_seller',
  'bio': '',
  'phone': '',
  'created_at': ago(days: 200),
};

class DemoCabinet {
  final int id;
  final String name;
  final String address;
  final double lat;
  final double lng;

  const DemoCabinet(this.id, this.name, this.address, this.lat, this.lng);

  Map<String, dynamic> toJson() => {
    'cabinet_id': id,
    'cabinet_name': name,
    'address': address,
    'open_time': '1970-01-01T08:00:00.000Z',
    'close_time': '1970-01-01T22:00:00.000Z',
    'latitude': lat,
    'longitude': lng,
  };
}

const cabinets = [
  DemoCabinet(1, '圖書館大廳', '臺北市大安區學府路 102 號 圖書館一樓', 25.0174, 121.5397),
  DemoCabinet(2, '學生活動中心', '臺北市大安區學府路 102 號 學生活動中心一樓', 25.0168, 121.5412),
  DemoCabinet(3, '第二教學大樓', '臺北市大安區學府路 102 號 第二教學大樓一樓', 25.0181, 121.5421),
];

const categories = {1: '數學統計', 2: '商管經濟', 3: '資訊科技', 4: '人文社會', 5: '自然科學', 6: '法律政治', 7: '語言學習'};

class DemoBook {
  final int id;
  final String title;
  final String coverTitle;
  final String edition;
  final String series;
  final String author;
  final String publisher;
  final String publishDate;
  final String isbn;
  final int categoryId;
  final int price;
  final String condition;
  final int sellerId;
  final int cabinetId;
  final bool inCabinet;
  final int views;
  final int listedDaysAgo;
  final Color color;
  final Color accent;
  final String description;

  const DemoBook({
    required this.id,
    required this.title,
    String? coverTitle,
    this.edition = '',
    this.series = '大學用書',
    required this.author,
    required this.publisher,
    required this.publishDate,
    required this.isbn,
    required this.categoryId,
    required this.price,
    required this.condition,
    required this.sellerId,
    required this.cabinetId,
    this.inCabinet = false,
    required this.views,
    required this.listedDaysAgo,
    required this.color,
    required this.accent,
    this.description = '',
  }) : coverTitle = coverTitle ?? title;

  String get coverPath => '/uploads/books/demo-$id-cover.png';

  String get coverUrl => resolveAssetUrl(coverPath)!;

  DemoCabinet get cabinet => cabinets.firstWhere((c) => c.id == cabinetId);

  Map<String, dynamic> toJson({Map<String, dynamic> extra = const {}}) => {
    'book_id': id,
    'seller_id': sellerId,
    'title': title,
    'author': author,
    'publisher': publisher,
    'publish_date': publishDate,
    'isbn': isbn,
    'category_id': categoryId,
    'cabinet_id': cabinetId,
    'condition_level': condition,
    'condition_note': '',
    'price': price,
    'quantity': 1,
    'status': 'on_sale',
    'view_count': views,
    'description': description.isEmpty ? '$title，$author 著，$publisher 出版。' : description,
    'created_at': ago(days: listedDaysAgo, hours: 3),
    'users': {'user_id': sellerId, 'nickname': users[sellerId], 'avatar_url': null},
    'book_images': [
      {'image_id': id * 10, 'image_url': coverPath, 'image_type': 'cover'},
    ],
    'book_categories': {'category_name': categories[categoryId]},
    'smart_cabinets': cabinet.toJson(),
    'in_cabinet': inCabinet,
    ...extra,
  };
}

final demoBooks = <DemoBook>[
  DemoBook(
    id: 1,
    title: '統計學概論',
    edition: '第三版',
    author: '林志明',
    publisher: '智識出版',
    publishDate: '2022-02',
    isbn: isbn13('978626731482'),
    categoryId: 1,
    price: 280,
    condition: 'good',
    sellerId: 2,
    cabinetId: 1,
    inCabinet: true,
    views: 128,
    listedDaysAgo: 4,
    color: const Color(0xFF4F7A63),
    accent: const Color(0xFFE7D9B8),
    description: '從資料蒐集、敘述統計到推論統計，循序說明統計學的核心概念，並以生活實例與練習題幫助理解。適合大學統計學、商管與社會科學相關課程使用。',
  ),
  DemoBook(
    id: 2,
    title: '微積分（第二版）',
    coverTitle: '微積分',
    edition: '第二版',
    author: '陳建宏',
    publisher: '青松書局',
    publishDate: '2021-08',
    isbn: isbn13('978626702153'),
    categoryId: 1,
    price: 320,
    condition: 'fair',
    sellerId: 4,
    cabinetId: 2,
    views: 96,
    listedDaysAgo: 2,
    color: const Color(0xFF3E5C76),
    accent: const Color(0xFFD9C27E),
  ),
  DemoBook(
    id: 3,
    title: '經濟學原理',
    author: '王美玲',
    publisher: '博觀出版',
    publishDate: '2020-09',
    isbn: isbn13('978957661204'),
    categoryId: 2,
    price: 320,
    condition: 'good',
    sellerId: 3,
    cabinetId: 1,
    views: 73,
    listedDaysAgo: 6,
    color: const Color(0xFF8C5E58),
    accent: const Color(0xFFEAD7C3),
  ),
  DemoBook(
    id: 4,
    title: '普通心理學',
    author: '張雅婷',
    publisher: '明理文化',
    publishDate: '2021-03',
    isbn: isbn13('978986479330'),
    categoryId: 4,
    price: 260,
    condition: 'good',
    sellerId: 1,
    cabinetId: 1,
    views: 0,
    listedDaysAgo: 0,
    color: const Color(0xFF6B5B95),
    accent: const Color(0xFFD8CFE8),
    description: '介紹心理學的研究方法與主要理論，涵蓋生理心理、感覺與知覺、學習、記憶、動機與情緒、人格及社會心理等主題，並附各章重點整理與複習題。',
  ),
  DemoBook(
    id: 5,
    title: '資料結構與演算法',
    author: '李承翰',
    publisher: '新知科技',
    publishDate: '2023-01',
    isbn: isbn13('978626333915'),
    categoryId: 3,
    price: 350,
    condition: 'like_new',
    sellerId: 5,
    cabinetId: 3,
    views: 154,
    listedDaysAgo: 1,
    color: const Color(0xFF2F4858),
    accent: const Color(0xFF86BBD8),
  ),
  DemoBook(
    id: 6,
    title: '會計學原理',
    author: '黃淑芬',
    publisher: '信達出版',
    publishDate: '2019-07',
    isbn: isbn13('978957328806'),
    categoryId: 2,
    price: 240,
    condition: 'fair',
    sellerId: 6,
    cabinetId: 2,
    views: 61,
    listedDaysAgo: 8,
    color: const Color(0xFFB08D57),
    accent: const Color(0xFF4A3B2A),
  ),
  DemoBook(
    id: 7,
    title: '管理學：理論與實務',
    coverTitle: '管理學',
    edition: '理論與實務',
    author: '吳俊傑',
    publisher: '博觀出版',
    publishDate: '2022-09',
    isbn: isbn13('978957661587'),
    categoryId: 2,
    price: 220,
    condition: 'good',
    sellerId: 7,
    cabinetId: 1,
    views: 47,
    listedDaysAgo: 3,
    color: const Color(0xFF5D7B8A),
    accent: const Color(0xFFF2E6D0),
  ),
  DemoBook(
    id: 8,
    title: '有機化學',
    author: '劉家豪',
    publisher: '青松書局',
    publishDate: '2020-02',
    isbn: isbn13('978626702207'),
    categoryId: 5,
    price: 380,
    condition: 'fair',
    sellerId: 8,
    cabinetId: 3,
    views: 39,
    listedDaysAgo: 5,
    color: const Color(0xFF7A8450),
    accent: const Color(0xFFF0E6C8),
  ),
  DemoBook(
    id: 9,
    title: '社會學導論',
    author: '蔡佩君',
    publisher: '明理文化',
    publishDate: '2021-11',
    isbn: isbn13('978986479412'),
    categoryId: 4,
    price: 180,
    condition: 'good',
    sellerId: 1,
    cabinetId: 1,
    views: 58,
    listedDaysAgo: 2,
    color: const Color(0xFFA0616A),
    accent: const Color(0xFFF3DCDC),
  ),
  DemoBook(
    id: 10,
    title: '線性代數',
    author: '周文彬',
    publisher: '新知科技',
    publishDate: '2022-06',
    isbn: isbn13('978626333788'),
    categoryId: 1,
    price: 150,
    condition: 'fair',
    sellerId: 9,
    cabinetId: 1,
    inCabinet: true,
    views: 88,
    listedDaysAgo: 3,
    color: const Color(0xFF44546A),
    accent: const Color(0xFFC9D6DF),
  ),
  DemoBook(
    id: 11,
    title: '民法概要',
    author: '許志偉',
    publisher: '正典法學',
    publishDate: '2023-03',
    isbn: isbn13('978957511069'),
    categoryId: 6,
    price: 200,
    condition: 'like_new',
    sellerId: 10,
    cabinetId: 2,
    views: 42,
    listedDaysAgo: 7,
    color: const Color(0xFF9C7A5B),
    accent: const Color(0xFF2E2A26),
  ),
  DemoBook(
    id: 12,
    title: '英文寫作入門',
    author: '鄭雅文',
    publisher: '學林書屋',
    publishDate: '2021-05',
    isbn: isbn13('978957900311'),
    categoryId: 7,
    price: 160,
    condition: 'good',
    sellerId: 5,
    cabinetId: 3,
    views: 35,
    listedDaysAgo: 9,
    color: const Color(0xFF586F6B),
    accent: const Color(0xFFE8E2D0),
  ),
];

DemoBook bookOf(int id) => demoBooks.firstWhere((b) => b.id == id);

const feedOrder = [1, 5, 2, 10, 7, 9, 3, 12, 6, 8, 11];

Map<String, dynamic> bookBrief(int id, {int? price}) {
  final b = bookOf(id);
  return {'book_id': id, 'title': b.title, 'price': price ?? b.price, 'status': 'on_sale', 'image_url': b.coverPath};
}

const statsBookId = 1;
const reservedBookId = 3;
const listingBookId = 4;
const pickupOrderNo = 'ODNMX0225';

Map<String, dynamic> order(
  int id,
  String orderNo,
  int bookId,
  String status, {
  required String createdAt,
  String? slot,
  List<String> doors = const [],
  Map<String, dynamic>? access,
}) {
  final b = bookOf(bookId);
  return {
    'order_id': id,
    'order_no': orderNo,
    'buyer_id': meId,
    'seller_id': b.sellerId,
    'total_amount': b.price,
    'status': status,
    'pickup_code': null,
    'cabinet_id': b.cabinetId,
    'created_at': createdAt,
    'picked_up_at': null,
    'completed_at': status == 'completed' ? ago(days: 3) : null,
    'order_items': [
      {'item_id': id * 10, 'book_id': bookId, 'quantity': 1, 'unit_price': b.price, 'subtotal': b.price, 'books': b.toJson()},
    ],
    'smart_cabinets': b.cabinet.toJson(),
    'cabinet_slots': slot == null ? null : {'slot_id': id, 'slot_number': slot},
    'users_orders_buyer_idTousers': user(meId),
    'users_orders_seller_idTousers': user(b.sellerId),
    'transaction_disputes': <Object>[],
    'doors': doors,
    'cabinet_access': ?access,
  };
}

Map<String, dynamic> scanAccess() => {
  'mode': 'scan',
  'reason': null,
  'open_now': true,
  'open_time': '08:00',
  'close_time': '22:00',
  'available_doors': 6,
  'pre_deposit_doors': 2,
};

Map<String, dynamic> pickupOrder() => order(
  7,
  pickupOrderNo,
  statsBookId,
  'deposited',
  createdAt: ago(hours: 2, minutes: 15),
  slot: 'A01',
  doors: ['A01'],
  access: scanAccess(),
);

final ordersByTab = <String, List<Map<String, dynamic>>>{
  'awaiting_pickup': [
    pickupOrder(),
    order(6, 'OD5RT8W3K', 7, 'deposited', createdAt: ago(days: 1, hours: 4), slot: 'A03', doors: ['A03'], access: scanAccess()),
  ],
  'awaiting_deposit': [order(5, 'OD8HC2V6Q', 2, 'pending_deposit', createdAt: ago(hours: 20))],
  'disputing': [],
  'finished': [
    order(4, 'OD3JX9P4L', 12, 'completed', createdAt: ago(days: 6)),
    order(3, 'OD7FW5N2T', 11, 'completed', createdAt: ago(days: 12)),
  ],
  'cancelled': [],
};

Map<String, dynamic> reservation(
  int id,
  int bookId,
  String status, {
  int? price,
  required String createdAt,
  String? deadline,
  String? message,
  int roomId = 1,
}) => {
  'reservation_id': id,
  'book': bookBrief(bookId, price: price),
  'buyer_id': meId,
  'seller_id': bookOf(bookId).sellerId,
  'status': status,
  'hours': 72,
  'message': message,
  'pickup_deadline': deadline,
  'is_holding': status == 'confirmed',
  'created_at': createdAt,
  'seller': {'user_id': bookOf(bookId).sellerId, 'nickname': users[bookOf(bookId).sellerId]},
  'room_id': roomId,
};

final chatReservation = reservation(
  8,
  reservedBookId,
  'confirmed',
  createdAt: todayAt(14, 12, daysAgo: 1),
  deadline: DateTime.parse(todayAt(14, 12, daysAgo: 1)).add(const Duration(hours: 72)).toIso8601String(),
  message: '預計週六下午至書櫃取書。',
);

List<Map<String, dynamic>> chatMessages() {
  Map<String, dynamic> m(
    int id,
    int sender,
    String kind,
    String at, {
    String? text,
    Map<String, dynamic>? payload,
    Map<String, dynamic>? risk,
  }) => {
    'message_id': id,
    'room_id': 1,
    'sender_id': sender,
    'content': text ?? '',
    'message_type': kind == 'text' ? 'text' : 'system',
    'kind': kind,
    'body': text,
    'mentions': <Object>[],
    'payload': payload,
    'is_read': true,
    'created_at': at,
    'edited_at': null,
    'reply_to': null,
    'users': {'user_id': sender, 'nickname': users[sender], 'avatar_url': null},
    'risk': risk,
  };
  final book = bookOf(reservedBookId);
  return [
    m(
      1,
      meId,
      'book',
      todayAt(13, 58, daysAgo: 1),
      payload: {'book_id': book.id, 'title': book.title, 'price': 350, 'image_url': book.coverPath},
    ),
    m(2, meId, 'text', todayAt(13, 58, daysAgo: 1), text: '您好，請問這本書還在嗎？'),
    m(3, 3, 'text', todayAt(14, 3, daysAgo: 1), text: '您好，還在的。書況近全新，只有前兩章有少量螢光筆畫記。'),
    m(4, meId, 'text', todayAt(14, 5, daysAgo: 1), text: '請問可以算 300 代幣嗎？'),
    m(5, 3, 'text', todayAt(14, 8, daysAgo: 1), text: '最低可以算 320 代幣，已經幫您調整售價。'),
    m(6, meId, 'text', todayAt(14, 10, daysAgo: 1), text: '好的，謝謝。我先預約，週六下午到書櫃取書。'),
    m(7, meId, 'reservation', todayAt(14, 12, daysAgo: 1), payload: chatReservation),
    m(
      8,
      3,
      'text',
      todayAt(14, 20, daysAgo: 1),
      text: '已確認預約。若有問題也可以加我的 LINE：guanyu.lin，聯絡比較方便。',
      risk: {
        'level': 'high',
        'categories': ['contact'],
      },
    ),
  ];
}

Map<String, dynamic> chatMeta() => {
  'read_upto': 8,
  'partner_typing': false,
  'recalled_ids': <int>[],
  'has_more': false,
  'reservations': [chatReservation],
  'transfers': <Object>[],
  'members_read': [
    {'user_id': 3, 'last_read_message_id': 7},
  ],
  'aliases': <String, String>{},
  'edited': <Object>[],
  'room': {'type': 'direct', 'title': users[3], 'avatar_url': null, 'member_count': 2},
  'risk_banner': {
    'level': 'high',
    'categories': ['contact'],
  },
};

Map<String, dynamic> cabinetSessionJson(String status, {int? remainingMs, Map<String, dynamic>? result, bool done = false}) {
  final book = bookOf(statsBookId);
  final doorState = switch (status) {
    'open' => 'open',
    'completed' => 'closed',
    _ => 'pending',
  };
  return {
    'session_no': 'CS4N7Q2KX',
    'status': status,
    'version': 3,
    'cabinet': {...cabinets.first.toJson(), 'available_doors': 6},
    'location_status': 'granted',
    'distance_m': 12,
    'items': [
      {
        'key': 'order:9',
        'kind': 'order_deposit',
        'order_id': 9,
        'order_no': 'OD7KQ2M9X',
        'books': [
          {'book_id': book.id, 'title': book.title, 'image_url': book.coverPath, 'door': 'A01'},
        ],
        'doors': ['A01'],
        'paused': false,
        'note': null,
        'selected': true,
        'blocked': null,
        'result': done ? 'done' : 'pending',
        'error': null,
      },
    ],
    'doors': [
      {'label': 'A01', 'state': doorState},
    ],
    'remaining_ms': remainingMs,
    'open_ms': 60000,
    'notice': null,
    'result': result,
    'created_at': ago(minutes: 1),
  };
}

Map<String, dynamic> Function() currentCabinetSession = () => cabinetSessionJson('matching', remainingMs: 52000);

Map<String, dynamic> listingAssistResult({bool conditionOnly = false}) {
  final b = bookOf(listingBookId);
  return {
    'fields': conditionOnly
        ? <String, Object>{}
        : {
            'title': b.title,
            'author': b.author,
            'publisher': b.publisher,
            'publish_date': b.publishDate,
            'publish_date_precision': 'month',
            'isbn': b.isbn,
            'page_count': 448,
            'language': 'zh-Hant',
            'description': b.description,
          },
    'description_source': 'mixed',
    if (!conditionOnly) 'category': {'category_id': b.categoryId, 'name': categories[b.categoryId], 'confidence': 0.92},
    'condition': {
      'level': 'good',
      'confidence': 0.86,
      'reasons': conditionOnly ? ['封面與書背完整，邊角僅有輕微磨損', '內頁乾淨，無畫線、水漬或缺頁'] : ['封面與書背完整，僅邊角有輕微磨損', '內頁無水漬、缺頁或明顯摺痕'],
    },
    'price': {
      'suggested': 280,
      'min': 240,
      'max': 320,
      'original_price': 560,
      'original_price_verified': true,
      'currency': 'TWD',
      'by_condition': {'like_new': 320, 'good': 280, 'fair': 240, 'poor': 180},
      'reasons': ['定價 560 元，書況近全新，約為定價五折', '近期同書成交價約 240 至 320 代幣'],
    },
    'sources': [
      {'title': 'Google Books', 'url': 'https://books.google.com/books?vid=ISBN${b.isbn}', 'domain': 'books.google.com'},
      {'title': 'Open Library', 'url': 'https://openlibrary.org/isbn/${b.isbn}', 'domain': 'openlibrary.org'},
    ],
    'warnings': <String>[],
    'provider': 'openai',
    'model': 'gpt-5-nano',
    'suggestion_token': 'demo-suggestion',
  };
}

List<Map<String, dynamic>> notifications() {
  Map<String, dynamic> n(
    int id,
    String type,
    String category,
    String relatedType,
    String title,
    String content,
    String at, {
    bool read = false,
  }) => {
    'notification_id': id,
    'type': type,
    'title': title,
    'content': content,
    'related_id': id,
    'related_type': relatedType,
    'category': category,
    'is_read': read,
    'created_at': at,
  };
  return [
    n(1, 'order', 'trade', 'order', '書籍已存入書櫃', '訂單 $pickupOrderNo 的書籍已存入「圖書館大廳」書櫃，請於營業時間內至書櫃以 App 掃描 QR Code 取書。', ago(minutes: 38)),
    n(2, 'reservation', 'trade', 'reservation', '賣家已確認預約', '林冠宇已確認《經濟學原理》的預約，書籍將為您保留 72 小時。', todayAt(14, 21, daysAgo: 1)),
    n(3, 'order', 'trade', 'wallet', '款項已撥入錢包', '訂單 OD9VB3T7M 已完成，240 代幣已撥入您的錢包。', ago(hours: 5), read: true),
    n(4, 'system', 'account', 'security', '新增通行密鑰', '您已在「海嫄的 iPhone」新增通行密鑰，之後可免輸入密碼登入。', ago(days: 1, hours: 2), read: true),
    n(5, 'promotion', 'promotion', 'announcement', '新學期書櫃開放時間調整', '自本週起，圖書館大廳書櫃開放時間調整為每日 08:00 至 22:00。', ago(days: 2), read: true),
    n(6, 'order', 'trade', 'order', '訂單已成立', '您已購買《管理學：理論與實務》，書籍已在書櫃，可直接前往取書。', ago(days: 1, hours: 5), read: true),
  ]..sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));
}

List<Map<String, dynamic>> walletTransactions() {
  Map<String, dynamic> t(
    int id,
    String no,
    String type,
    int amount,
    int after,
    String description,
    String at, {
    String? orderNo,
    int? bookId,
  }) => {
    'txn_id': id,
    'txn_no': no,
    'type': type,
    'amount': amount,
    'balance_after': after,
    'description': description,
    'created_at': at,
    'orders': orderNo == null
        ? null
        : {
            'order_id': id,
            'order_no': orderNo,
            'order_items': [
              {'books': bookOf(bookId!).toJson()},
            ],
          },
  };
  return [
    t(6, 'TX7Q3M8KD', 'purchase', -280, 920, '購買《統計學概論》', ago(hours: 2, minutes: 15), orderNo: pickupOrderNo, bookId: 1),
    t(5, 'TX2W9R4HN', 'purchase', -220, 1200, '購買《管理學：理論與實務》', ago(days: 1, hours: 4), orderNo: 'OD5RT8W3K', bookId: 7),
    t(4, 'TX5K8T2PB', 'sale_income', 240, 1420, '售出《會計學原理》', ago(hours: 5), orderNo: 'OD9VB3T7M', bookId: 6),
    t(3, 'TX9D4F6LS', 'deposit', 1000, 1180, '儲值', ago(days: 5)),
    t(2, 'TX3H7N5VC', 'purchase', -160, 180, '購買《英文寫作入門》', ago(days: 6), orderNo: 'OD3JX9P4L', bookId: 12),
  ];
}

Map<String, dynamic> passkeyRow(String id, String label, String created, String used) => {
  'passkey_id': id,
  'device_label': label,
  'created_at': created,
  'last_used_at': used,
  'backed_up': true,
};

const departureStation = '台北車站';

// 書櫃周邊交通資訊，格式比照 GET /cabinets/:id/nearby（data.taipei 資料整理後的回應）。
Map<String, dynamic> cabinetNearby() {
  Map<String, dynamic> at(double lat, double lng, int distance) => {'latitude': lat, 'longitude': lng, 'distance_m': distance};
  Map<String, dynamic> route(String name, String direction, String status, [int? minutes]) =>
      {'name': name, 'direction': direction, 'status': status, 'minutes': minutes};
  Map<String, dynamic> bike(String name, String address, double lat, double lng, int distance, int rent, int giveBack) => {
    'name': name,
    'address': address,
    ...at(lat, lng, distance),
    'available_rent': rent,
    'available_return': giveBack,
    'total': rent + giveBack,
    'is_active': true,
  };
  final cabinet = cabinets.first;
  return {
    'cabinet': {'latitude': cabinet.lat, 'longitude': cabinet.lng},
    'mrt': {
      'status': 'ok',
      'updated_at': todayAt(13, 43),
      'stations': [
        {
          'name': '公館',
          'distance_m': 556,
          'nearest_exit': {'exit': '3', 'accessible': false, ...at(25.0153, 121.5351, 556)},
          'accessible_exit': {'exit': '2', 'facility': 'elevator', ...at(25.0151, 121.5346, 612)},
        },
        {
          'name': '台電大樓',
          'distance_m': 1113,
          'nearest_exit': {'exit': '2', 'accessible': false, ...at(25.020192, 121.529093, 1113)},
          'accessible_exit': {'exit': '5', 'facility': 'elevator', ...at(25.020758, 121.527739, 1262)},
        },
      ],
    },
    'bus': {
      'status': 'ok',
      'updated_at': todayAt(14, 24),
      'realtime_available': true,
      'stops': [
        {
          'name': '學府路口',
          'address': '辛亥路二段170號同向(向東)',
          ...at(25.0189, 121.5401, 172),
          'routes': [
            route('0東', '捷運市政府站', 'arriving', 0),
            route('284', '松山車站', 'minutes', 4),
            route('52', '捷運南京三民站', 'minutes', 9),
            route('棕11', '捷運六張犁站', 'minutes', 13),
            route('611', '捷運大安站', 'not_departed'),
            route('敦化幹線', '捷運南港展覽館站', 'minutes', 18),
          ],
        },
        {
          'name': '學生活動中心',
          'address': '學府路102號旁(向北)',
          ...at(25.0166, 121.5414, 196),
          'routes': [
            route('棕11', '捷運公館站', 'minutes', 6),
            route('0東', '臺大', 'minutes', 11),
          ],
        },
      ],
    },
    'road_speed': {
      'status': 'ok',
      'updated_at': todayAt(14, 23),
      'sections': [
        {'road': '辛亥路', 'between': '新生南路-復興南路', 'speed_kph': 42, 'level': 'smooth', 'distance_m': 286},
        {'road': '基隆路', 'between': '辛亥路-羅斯福路', 'speed_kph': 23, 'level': 'busy', 'distance_m': 512},
      ],
    },
    'taxi_stands': {
      'status': 'ok',
      'updated_at': todayAt(14, 23),
      'stands': [
        {'name': '學府路招呼站', 'street': '學府路102號前', 'spaces': 3, 'hours': '0~24', ...at(25.0171, 121.5409, 128)},
      ],
    },
    'youbike': {
      'status': 'ok',
      'updated_at': todayAt(14, 22),
      'stations': [
        bike('學府路圖書館前', '學府路102號圖書館前', 25.0170, 121.5399, 48, 12, 18),
        bike('學生活動中心', '學府路102號學生活動中心旁', 25.0167, 121.5413, 168, 5, 25),
        bike('辛亥學府路口', '辛亥路二段/學府路口東南側', 25.0188, 121.5405, 172, 21, 9),
        bike('第二教學大樓東側', '學府路102號第二教學大樓東側', 25.0181, 121.5424, 284, 7, 23),
      ],
    },
    'parking_lots': {
      'status': 'ok',
      'updated_at': todayAt(14, 21),
      'realtime_available': true,
      'lots': [
        {
          'name': '學府路地下停車場',
          'address': '學府路102號地下',
          'fee': '小型車：計時 30元/時',
          'hours': '00:00:00-23:59:59',
          ...at(25.0179, 121.5409, 214),
          'car': {'total': 180, 'available': 46},
          'motorcycle': {'total': 0, 'available': null},
        },
        {
          'name': '辛亥路立體停車場',
          'address': '辛亥路二段158號',
          'fee': '小型車：計時 40元/時',
          'hours': '07:00:00-23:00:00',
          ...at(25.0195, 121.5386, 418),
          'car': {'total': 96, 'available': 17},
          'motorcycle': {'total': 0, 'available': null},
        },
        {
          'name': '辛亥路二段停車場',
          'address': '辛亥路二段126巷旁空地',
          'fee': '',
          'hours': '',
          ...at(25.0201, 121.5377, 486),
          'car': {'total': 24, 'available': null},
          'motorcycle': {'total': 0, 'available': null},
        },
      ],
    },
    'roadside': {
      'status': 'ok',
      'radius_m': 300,
      'updated_at': todayAt(14, 21),
      'car': [
        {
          'name': '學府路A',
          ...at(25.0176, 121.5401, 42),
          'spaces_nearby': 18,
          'accessible_nearby': 2,
          'live': {'total': 6, 'available': 2, 'fee': '30元', 'start': '08:00', 'end': '20:00'},
        },
        {
          'name': '辛亥路二段C',
          ...at(25.0190, 121.5392, 208),
          'spaces_nearby': 9,
          'accessible_nearby': 0,
          'live': {'total': 9, 'available': null, 'fee': '40元', 'start': '09:00', 'end': '21:00'},
        },
      ],
      'motorcycle': [
        {'name': '學府路(機車)', ...at(25.0172, 121.5402, 56), 'spaces_nearby': 120, 'accessible_nearby': 0, 'has_parking_area': true},
      ],
    },
    'attribution': '資料來源：臺北市資料大平臺（data.taipei），依政府資料開放授權條款第 1 版使用',
    'sources': <Object>[],
  };
}

const mrtStations = [
  {'name': '公館', 'latitude': 25.014908, 'longitude': 121.534216},
  {'name': '台電大樓', 'latitude': 25.020553, 'longitude': 121.528111},
  {'name': '科技大樓', 'latitude': 25.026125, 'longitude': 121.543437},
  {'name': '台北車站', 'latitude': 25.046778, 'longitude': 121.517707},
];

Map<String, dynamic> mrtFares(String from) => {
  'fares': [
    {'from': from, 'to': '公館', 'fare': 25, 'concession_fare': 10, 'distance_km': 5.53},
    {'from': from, 'to': '台電大樓', 'fare': 20, 'concession_fare': 8, 'distance_km': 4.38},
  ],
};

Map<String, dynamic> aiSupportSession() {
  final cabinet = bookOf(statsBookId).cabinet;
  return {
    'session_id': 4,
    'status': 'open',
    'messages': [
      {'message_id': 41, 'role': 'user', 'content': '訂單 $pickupOrderNo 要怎麼取書？', 'created_at': ago(minutes: 6)},
      {
        'message_id': 42,
        'role': 'assistant',
        'content':
            '請於 7 天內至「${cabinet.name}」書櫃取書：\n'
            '1. 於開放時間 08:00–22:00 前往書櫃\n'
            '2. 以 App 掃描書櫃螢幕上的 QR Code\n'
            '3. 輸入螢幕顯示的兩位數字開啟櫃門\n'
            '4. 取出書籍並關上櫃門',
        'message_no': 'AS4QK7M2D',
        'feedback': {'rating': 'helpful'},
        'created_at': ago(minutes: 6),
      },
      {'message_id': 43, 'role': 'user', 'content': '取書後發現有缺頁，可以退款嗎？', 'created_at': ago(minutes: 2)},
      {
        'message_id': 44,
        'role': 'assistant',
        'content': '可在取書後 24 小時內、完成訂單前，於訂單頁面申請爭議並附上照片，由管理員裁決是否退款。',
        'message_no': 'AS9WT3R6H',
        'suggest_handoff': true,
        'created_at': ago(minutes: 2),
      },
    ],
  };
}

const disputeId = 4;
const disputeBookId = 5;

const disputeEvidence = ['/uploads/disputes/demo-evidence-1.png', '/uploads/disputes/demo-evidence-2.png'];

List<Map<String, dynamic>> adminDisputes() {
  Map<String, dynamic> dispute(
    int id,
    String orderNo,
    int bookId,
    int buyerId,
    String reason,
    String createdAt, {
    List<String> evidence = const [],
  }) {
    final b = bookOf(bookId);
    return {
      'dispute_id': id,
      'order_id': id + 20,
      'applicant_id': buyerId,
      'reason': reason,
      'status': 'pending',
      'result': null,
      'admin_note': null,
      'created_at': createdAt,
      'evidence_images': evidence,
      'users_transaction_disputes_applicant_idTousers': {'nickname': users[buyerId]},
      'orders': {
        'order_id': id + 20,
        'order_no': orderNo,
        'total_amount': b.price,
        'status': 'disputed',
        'users_orders_buyer_idTousers': {'nickname': users[buyerId]},
        'users_orders_seller_idTousers': {'nickname': users[b.sellerId]},
        'order_items': [
          {
            'books': {
              'title': b.title,
              'book_images': [
                {'image_url': b.coverPath},
              ],
            },
          },
        ],
      },
    };
  }

  return [
    dispute(
      disputeId,
      'OD6TQ4H8N',
      disputeBookId,
      6,
      '第 3 至 5 章有大量螢光筆畫線與筆記，與商品描述「近全新、內頁無畫線」不符。',
      ago(hours: 3, minutes: 20),
      evidence: disputeEvidence,
    ),
    dispute(3, 'OD2LM8C5W', 8, 10, '書櫃取出的書籍封底有水漬，商品照片與描述皆未提及。', ago(days: 1, hours: 6)),
  ];
}

Map<String, dynamic> disputeAnalysis() {
  final title = bookOf(disputeBookId).title;
  return {
    'analysis_no': 'DA7NQ2X5K',
    'summary': '買家表示第 3 至 5 章有大量螢光筆畫線與筆記；商品描述為「近全新、內頁無畫線」，上架照片僅含封面、封底與第 1 章內頁。',
    'finding_details': [
      {'content': '佐證照片可見多頁螢光筆畫線與手寫筆記，範圍涵蓋數個章節', 'basis': 'evidence_photo', 'photos': [4, 5], 'favors': 'buyer'},
      {'content': '上架內頁照片乾淨無畫線，但未呈現爭議所指的章節', 'basis': 'listing_photo', 'photos': [3], 'favors': 'neutral'},
      {'content': '封面與書背狀況和上架照片相符', 'basis': 'listing_photo', 'photos': [1, 2], 'favors': 'seller'},
    ],
    'suggestion': 'refund',
    'confidence_level': 'medium',
    'rationale': '佐證所見的畫線範圍明顯超出「近全新」的描述，屬於重大書況落差；若賣家能提供存書前的內頁照片，可再重新評估。',
    'images': {'listing': 3, 'evidence': 2, 'skipped': 0},
    'photos': [
      {'no': 1, 'source': 'listing', 'type': 'cover', 'title': title},
      {'no': 2, 'source': 'listing', 'type': 'back', 'title': title},
      {'no': 3, 'source': 'listing', 'type': 'inside', 'title': title},
      {'no': 4, 'source': 'evidence'},
      {'no': 5, 'source': 'evidence'},
    ],
    'helpful': null,
    'created_at': ago(minutes: 6),
  };
}

const reviewBookId = 8;
const reviewSynopsis = '以反應機構為主軸，系統介紹官能基的性質與合成方法，並附大量練習題。';
const reviewPhotos = ['/uploads/books/demo-8-back.png', '/uploads/books/demo-8-inside.png'];

List<Map<String, dynamic>> listingReviews() {
  Map<String, dynamic> item(
    int bookId, {
    required String verdict,
    required List<String> reasons,
    required List<String> categories,
    required String origin,
    required double confidence,
    required String createdAt,
    Map<String, dynamic>? opinion,
    List<String> photos = const [],
    String description = '',
    String conditionNote = '',
  }) {
    final b = bookOf(bookId);
    final card = b.toJson()..remove('users');
    return {
      'book_id': bookId,
      'book': {
        ...card,
        if (description.isNotEmpty) 'description': description,
        'condition_note': conditionNote,
        'book_images': [
          {'image_id': bookId * 10, 'image_url': b.coverPath, 'image_type': 'cover'},
          for (final (i, p) in photos.indexed) {'image_id': bookId * 10 + i + 1, 'image_url': p, 'image_type': 'other'},
        ],
      },
      'seller': {'user_id': b.sellerId, 'nickname': users[b.sellerId], 'avatar_url': null},
      'verdict': verdict,
      'reasons': reasons,
      'categories': categories,
      'status': 'pending',
      'origin': origin,
      'confidence': confidence,
      'decision_reason': null,
      'created_at': createdAt,
      'reviewed_at': null,
      'ai_opinion': opinion,
    };
  }

  return [
    item(
      reviewBookId,
      verdict: 'review',
      reasons: ['疑似圖書館館藏或非正規來源書籍'],
      categories: ['source'],
      origin: 'rules',
      confidence: 1,
      createdAt: ago(minutes: 18),
      photos: reviewPhotos,
      description: '封底貼有館藏標籤，為系上圖書室汰換的複本。內頁有少量鉛筆筆記，不影響閱讀。',
      conditionNote: '書角輕微磨損',
      opinion: {
        'verdict': 'review',
        'confidence': 0.82,
        'categories': ['source'],
        'reasons': ['封底照片可見圖書館館藏標籤、索書號與館藏章，未見除籍章', '書名、封面與商品資料相符，書況與描述一致'],
      },
    ),
    item(
      2,
      verdict: 'reject',
      reasons: ['內頁照片可見影印裝訂與黑邊，疑似整本影印的盜版書'],
      categories: ['prohibited'],
      origin: 'ai',
      confidence: 0.91,
      createdAt: ago(hours: 2, minutes: 40),
    ),
  ];
}

Map<String, dynamic>? _route(String method, String path, Map<String, String> query, String body) {
  final routes = <String, Object? Function()>{
    'GET /status': () => {'api_revision': 99, 'commit': 'demo'},
    'GET /auth/me': () => user(meId),
    'GET /users/me/stats': () => {'balance': 920, 'book_count': 2, 'favorite_count': 6, 'unread_notification_count': 2, 'cart_count': 1},
    'GET /users/me/legal-consents/pending': () => <Object>[],
    'GET /ai/status': () => {
      'support': true,
      'listing_assist': true,
      'recommend': true,
      'book_chat': true,
      'web_search': true,
      'consented': true,
      'providers_in_use': ['OpenAI'],
      'embedding_provider': 'OpenAI',
    },
    'GET /categories': () => [
      for (final e in categories.entries)
        {'category_id': e.key, 'category_name': e.value, 'parent_id': null, 'sort_order': e.key, 'other_book_categories': <Object>[]},
    ],
    'GET /books': () => [for (final id in feedOrder) bookOf(id).toJson()],
    'GET /books/1/similar': () => [
      for (final id in [10, 2, 5, 3]) bookOf(id).toJson(),
    ],
    'GET /favorites/ids': () => [1, 5],
    'GET /cart/book-ids': () => [10],
    'GET /chat/unread-count': () => {'unread_count': 2},
    'GET /notifications/unread-count': () => {
      'unread_count': 2,
      'by_category': {'trade': 2, 'chat': 2, 'account': 0, 'service': 0, 'promotion': 0},
    },
    'GET /notifications': () => query['category'] == null || query['category'] == 'trade' || query['category'] == 'all'
        ? notifications().where((n) => query['category'] != 'trade' || n['category'] == 'trade').toList()
        : notifications().where((n) => n['category'] == query['category']).toList(),
    'GET /chat/reservations/mine': () => [
      chatReservation,
      reservation(9, 10, 'confirmed', createdAt: todayAt(18, 0, daysAgo: 2), deadline: todayAt(18, 0, daysAgo: -1), roomId: 2),
      reservation(10, 8, 'pending', createdAt: ago(hours: 1), message: '請問週日可以取書嗎？', roomId: 3),
    ],
    'GET /chat/rooms/1': () => {
      'room_id': 1,
      'type': 'direct',
      'name': '',
      'avatar_url': null,
      'created_by': meId,
      'my_role': 'member',
      'members': [
        {...user(meId), 'role': 'member', 'joined_at': ago(days: 1)},
        {...user(3), 'role': 'member', 'joined_at': ago(days: 1)},
      ],
      'partner': {...user(3), 'alias': null},
      'muted': false,
      'pinned': false,
    },
    'GET /chat/rooms/1/messages': chatMessages,
    'GET /orders/7': pickupOrder,
    'GET /wallet': () => {'balance': 920, 'frozen_amount': 0, 'total_income': 1480, 'total_expense': 1860, 'pending_income': 240},
    'GET /wallet/transactions': walletTransactions,
    'GET /wallet/pending': () => <Object>[],
    'GET /security': () => {
      'available': true,
      'has_payment_pin': true,
      'pin_locked_until': null,
      'biometric_pay_enabled': true,
      'passkey_available': true,
      'has_passkey': true,
      'has_password': true,
    },
    'GET /auth/passkeys/status': () => {'enabled': true},
    'GET /users/me/passkeys': () => [
      passkeyRow('PK3M7Q2XA', '海嫄的 iPhone', ago(days: 1, hours: 2), ago(hours: 3)),
      passkeyRow('PK9QW2E4R', 'MacBook Air', ago(days: 21), ago(days: 4)),
    ],
    'GET /security/sessions': () => [
      {
        'session_id': 1,
        'device_name': 'iPhone 17 Pro',
        'platform': 'ios',
        'app_version': '1.0.3',
        'ip_address': '203.0.113.25',
        'created_at': ago(days: 1),
        'last_seen_at': ago(minutes: 1),
        'biometric_pay': true,
        'is_current': true,
      },
      {
        'session_id': 2,
        'device_name': 'iPad Air',
        'platform': 'ios',
        'app_version': '1.0.3',
        'ip_address': '203.0.113.47',
        'created_at': ago(days: 14),
        'last_seen_at': ago(days: 2),
        'biometric_pay': false,
        'is_current': false,
      },
    ],
    'GET /users/me/identities': () => {
      'password_set': true,
      'identities': [
        {
          'provider': 'apple',
          'display_name': '海嫄',
          'masked_email': 'ha***@icloud.com',
          'masked_phone': null,
          'created_at': ago(days: 200),
          'last_login_at': ago(days: 1),
        },
      ],
    },
    'GET /auth/providers': () => {
      'social_enabled': true,
      'providers': [
        for (final id in ['google', 'apple', 'phone']) {'id': id, 'enabled': true, 'signup': true, 'configured': true},
      ],
    },
    'GET /cabinets': () => [
      for (final c in cabinets) {...c.toJson(), 'available_slots': 6, 'distance_m': c.id * 180},
    ],
    'GET /cabinet-sessions/active': () => null,
    'GET /cabinet-sessions/CS4N7Q2KX': () => currentCabinetSession(),
    'GET /books/isbn/${bookOf(listingBookId).isbn}': () => null,
    'GET /cabinets/${cabinets.first.id}/nearby': cabinetNearby,
    'GET /admin/cabinets/nearby-preview': cabinetNearby,
    'GET /cabinets/mrt-stations': () => {'stations': mrtStations},
    'GET /cabinets/mrt-fares': () => mrtFares(query['from'] ?? departureStation),
    'GET /ai/support/session': aiSupportSession,
    'GET /admin/disputes': adminDisputes,
    'GET /admin/disputes/$disputeId/ai-analysis': disputeAnalysis,
    'GET /admin/ai/reviews': listingReviews,
  };

  final key = '$method $path';
  if (key == 'POST /ai/listing-assist') {
    return _ok(listingAssistResult(conditionOnly: RegExp(r'name="mode"\s+condition').hasMatch(body)));
  }
  if (key == 'GET /orders') {
    final tab = query['tab'] ?? 'awaiting_pickup';
    return _ok(query['role'] == 'seller' ? <Object>[] : ordersByTab[tab] ?? <Object>[]);
  }
  final book = RegExp(r'^GET /books/(\d+)$').firstMatch(key);
  if (book != null) {
    final id = int.parse(book.group(1)!);
    return _ok(
      bookOf(id).toJson(
        extra: {
          'enrichment': {'fields': <String>[], 'ai_written': false},
        },
      ),
    );
  }
  if (key == 'GET /ai/recommendations') {
    return {
      'success': true,
      'message': 'OK',
      'data': [
        for (final (id, reason) in recommendationReasons) {'book': bookOf(id).toJson(), 'reason': reason},
      ],
      'groups': [
        {
          'kind': 'book',
          'relation': 'favorite',
          'book_id': 1,
          'title': '統計學概論',
          'book_ids': [10, 2, 5],
        },
        {
          'kind': 'category',
          'category': '商管經濟',
          'book_ids': [3, 7, 6],
        },
      ],
      'meta': {'source': 'ai', 'generated_at': ago(minutes: 20)},
    };
  }
  if (routes.containsKey(key)) {
    final data = routes[key]!();
    if (key == 'GET /chat/rooms/1/messages') {
      return {'success': true, 'message': 'OK', 'data': data, 'partner': user(3), 'meta': chatMeta()};
    }
    return _ok(data);
  }
  if (method == 'GET') return _ok(<Object>[]);
  return _ok(<String, Object>{});
}

const recommendationReasons = [
  (10, '矩陣運算是多變量統計分析的基礎'),
  (2, '機率與期望值的推導需要微積分概念'),
  (5, '可延伸學習資料分析的程式實作'),
  (3, '與您近期瀏覽的商管課程用書相關'),
  (7, '同類別中評價較高的入門教材'),
  (6, '常與經濟學原理搭配修習'),
];

Map<String, dynamic> _ok(Object? data) => {
  'success': true,
  'message': 'OK',
  'data': data,
  if (data is List) 'pagination': {'total': data.length, 'page': 1, 'limit': 20, 'total_pages': 1},
};

MockClient demoApi() => MockClient((request) async {
  final path = request.url.path.replaceFirst('/api', '');
  final body = _route(request.method, path, request.url.queryParameters, utf8.decode(request.bodyBytes, allowMalformed: true));
  return http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json; charset=utf-8'});
});
