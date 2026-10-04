import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:savemybook_app/utils/api_helpers.dart';

import 'demo_data.dart' show DemoBook;

final _now = DateTime.now();

String ago({int days = 0, int hours = 0, int minutes = 0}) =>
    _now.subtract(Duration(days: days, hours: hours, minutes: minutes)).toUtc().toIso8601String();

String todayAt(int hour, int minute, {int daysAgo = 0}) {
  final d = _now.subtract(Duration(days: daysAgo));
  return DateTime(d.year, d.month, d.day, hour, minute).toUtc().toIso8601String();
}

const buyerId = 1;
const sellerId = 2;
const strangerId = 3;

const users = <int, String>{
  1: '海嫄',
  2: '侖娥',
  3: '林冠宇',
  4: '王思涵',
  5: '張家豪',
  6: '李欣怡',
  7: '黃子軒',
  8: '吳品妤',
  9: '莉莉',
  10: 'BAE',
  11: '智友',
  12: '圭珍',
};

Map<String, dynamic> user(int id) => {
  'user_id': id,
  'nickname': users[id],
  'email': 'member$id@example.com',
  'avatar_url': null,
  'role': 'buyer_seller',
  'bio': '',
  'phone': '',
  'created_at': ago(days: 200),
};

const cabinetId = 1;
const cabinetName = '圖書館總館一樓';
const cabinetAddress = '臺北市大安區建國南路二段 125 號';
const cabinetLat = 25.0292374;
const cabinetLng = 121.5383324;

Map<String, dynamic> cabinetJson() => {
  'cabinet_id': cabinetId,
  'cabinet_name': cabinetName,
  'address': cabinetAddress,
  'open_time': '1970-01-01T08:00:00.000Z',
  'close_time': '1970-01-01T22:00:00.000Z',
  'latitude': cabinetLat,
  'longitude': cabinetLng,
};

const categories = {1: '數學統計', 2: '商管經濟', 3: '資訊科技', 4: '人文社會', 5: '自然科學', 6: '法律政治', 7: '語言學習'};

class IntroBook {
  final int id;
  final String title;
  final String coverTitle;
  final String coverSubtitle;
  final String author;
  final String publisher;
  final String publishDate;
  final String isbn;
  final String source;
  final int categoryId;
  final int price;
  final String condition;
  final String conditionNote;
  final int sellerId;
  final bool inCabinet;
  final int views;
  final String createdAt;
  final Color color;
  final Color accent;
  final String description;

  const IntroBook({
    required this.id,
    required this.title,
    required this.coverTitle,
    this.coverSubtitle = '',
    required this.author,
    required this.publisher,
    required this.publishDate,
    required this.isbn,
    required this.source,
    required this.categoryId,
    required this.price,
    required this.condition,
    this.conditionNote = '',
    required this.sellerId,
    this.inCabinet = false,
    required this.views,
    required this.createdAt,
    required this.color,
    required this.accent,
    required this.description,
  });

  String get coverPath => '/uploads/books/intro-$id-cover.png';

  String get coverUrl => resolveAssetUrl(coverPath)!;

  DemoBook get paintable => DemoBook(
    id: id,
    title: title,
    coverTitle: coverTitle,
    edition: coverSubtitle,
    series: '',
    author: author,
    publisher: publisher,
    publishDate: publishDate,
    isbn: isbn,
    categoryId: categoryId,
    price: price,
    condition: condition,
    sellerId: sellerId,
    cabinetId: 1,
    views: views,
    listedDaysAgo: 0,
    color: color,
    accent: accent,
    description: description,
  );

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
    'condition_note': conditionNote,
    'price': price,
    'quantity': 1,
    'status': 'on_sale',
    'view_count': views,
    'description': description,
    'created_at': createdAt,
    'users': {'user_id': sellerId, 'nickname': users[sellerId], 'avatar_url': null},
    'book_images': [
      {'image_id': id * 10, 'image_url': coverPath, 'image_type': 'cover'},
    ],
    'book_categories': {'category_name': categories[categoryId]},
    'smart_cabinets': cabinetJson(),
    'in_cabinet': inCabinet,
    ...extra,
  };
}

const journeyId = 101;
const companionId = 102;
const strangerBookId = 106;
const reviewBookId = 107;
const disputeBookId = 108;
const favoriteBookId = 109;
const sellerPastSaleId = 110;
const sellerPurchaseId = 111;
const secondDisputeBookId = 112;
const secondReviewBookId = 113;

const journeySummary = '銜接高中（職）化學與大學課程，介紹化學基本概念、熱力學、氧化還原與核化學。';

final introBooks = <IntroBook>[
  IntroBook(
    id: journeyId,
    title: '普通化學',
    coverTitle: '普通化學',
    author: '魏明通',
    publisher: '台灣五南圖書出版股份有限公司',
    publishDate: '2015-07',
    isbn: '9789571143491',
    source: 'https://books.google.com/books?id=BGBqsgM1LIsC',
    categoryId: 5,
    price: 222,
    condition: 'fair',
    conditionNote: '書背上緣有摺痕，部分內頁有螢光筆劃線，不影響閱讀。',
    sellerId: sellerId,
    views: 25,
    createdAt: ago(hours: 2, minutes: 26),
    color: const Color(0xFF2F5D62),
    accent: const Color(0xFFE8C872),
    description: journeySummary,
  ),
  IntroBook(
    id: companionId,
    title: '觀念化學2：化學鍵．分子',
    coverTitle: '觀念化學2',
    coverSubtitle: '化學鍵．分子',
    author: '蘇卡奇John Suchocki、蔡信行',
    publisher: '遠見天下文化出版股份有限公司',
    publishDate: '2020-06',
    isbn: '9789865535087',
    source: 'https://books.google.com/books?id=rzHwDwAAQBAJ',
    categoryId: 5,
    price: 180,
    condition: 'good',
    sellerId: 9,
    views: 41,
    createdAt: ago(days: 3, hours: 5),
    color: const Color(0xFF3D5A80),
    accent: const Color(0xFFEE6C4D),
    description: '《觀念化學2》帶領讀者瞭解原子、分子這些小到看不見的東西，理解它們基本的運作原理，進而知道這個廣大世界隱藏的奧秘。',
  ),
  IntroBook(
    id: 103,
    title: '觀念化學3：化學反應',
    coverTitle: '觀念化學3',
    coverSubtitle: '化學反應',
    author: '蘇卡奇John Suchocki',
    publisher: '遠見天下文化出版股份有限公司',
    publishDate: '2020-06',
    isbn: '9789865535094',
    source: 'https://books.google.com/books?id=uTHwDwAAQBAJ',
    categoryId: 5,
    price: 170,
    condition: 'good',
    sellerId: 10,
    views: 33,
    createdAt: ago(days: 4, hours: 2),
    color: const Color(0xFF6D597A),
    accent: const Color(0xFFF2CC8F),
    description: '《觀念化學3》講解化學反應的原理，以生活中的疑問說明化學知識的應用。',
  ),
  IntroBook(
    id: 104,
    title: '普通化學實驗',
    coverTitle: '普通化學實驗',
    author: '石鳳城',
    publisher: '台灣五南圖書出版股份有限公司',
    publishDate: '2013-09',
    isbn: '9789571173443',
    source: 'https://books.google.com/books?id=hCoyCgAAQBAJ',
    categoryId: 5,
    price: 120,
    condition: 'good',
    sellerId: 11,
    views: 18,
    createdAt: ago(days: 2, hours: 7),
    color: const Color(0xFF52796F),
    accent: const Color(0xFFCAD2C5),
    description: '實驗題材適合普通化學課程，編排循序漸進，所需設備、器材與藥品簡單而普遍，並注意用藥安全與環保。',
  ),
  IntroBook(
    id: 105,
    title: '觀念物理1：牛頓運動定律．動量',
    coverTitle: '觀念物理1',
    coverSubtitle: '牛頓運動定律．動量',
    author: '休伊特',
    publisher: '遠見天下文化出版股份有限公司',
    publishDate: '2018-06',
    isbn: '9789864795062',
    source: 'https://books.google.com/books?id=oeNiDwAAQBAJ',
    categoryId: 5,
    price: 220,
    condition: 'like_new',
    sellerId: 12,
    views: 57,
    createdAt: ago(days: 1, hours: 9),
    color: const Color(0xFF1D3557),
    accent: const Color(0xFFA8DADC),
    description: '《觀念物理》第 1 冊從力學開始，介紹牛頓運動定律、動量與能量守恆。',
  ),
  IntroBook(
    id: strangerBookId,
    title: '大師說化學：理解世界必修的化學課',
    coverTitle: '大師說化學',
    coverSubtitle: '理解世界必修的化學課',
    author: '霍夫曼 Roald Hoffmann',
    publisher: '遠見天下文化出版股份有限公司',
    publishDate: '2016-06',
    isbn: '9789864790173',
    source: 'https://books.google.com/books?id=x6HkDAAAQBAJ',
    categoryId: 5,
    price: 160,
    condition: 'good',
    sellerId: strangerId,
    views: 29,
    createdAt: ago(days: 5, hours: 3),
    color: const Color(0xFF8D5A3B),
    accent: const Color(0xFFF1E3C8),
    description: '諾貝爾獎得主霍夫曼說明化學是什麼、化學家在做什麼，以及如何享用化學的好處而不受化學所傷。',
  ),
  IntroBook(
    id: reviewBookId,
    title: '有機化學的反應機構論',
    coverTitle: '有機化學的反應機構論',
    author: '蘇明德',
    publisher: '台灣五南圖書出版股份有限公司',
    publishDate: '2014-04',
    isbn: '9789571175935',
    source: 'https://books.google.com/books?id=XXtFCgAAQBAJ',
    categoryId: 5,
    price: 150,
    condition: 'good',
    sellerId: 8,
    views: 0,
    createdAt: ago(minutes: 18),
    color: const Color(0xFF7A8450),
    accent: const Color(0xFFF0E6C8),
    description: '教導讀者在短時間內學會畫有機化學的反應機構，並能記住各種有機反應式及預測可能的反應途徑。',
  ),
  IntroBook(
    id: disputeBookId,
    title: '秒懂資料結構',
    coverTitle: '秒懂資料結構',
    author: '施保旭',
    publisher: '五南圖書出版股份有限公司',
    publishDate: '2016-01',
    isbn: '9789571184586',
    source: 'https://books.google.com/books?id=GQqqDwAAQBAJ',
    categoryId: 3,
    price: 200,
    condition: 'like_new',
    sellerId: 5,
    views: 64,
    createdAt: ago(days: 9),
    color: const Color(0xFF2F4858),
    accent: const Color(0xFF86BBD8),
    description: '介紹堆疊、佇列、樹與圖等常用資料結構及其操作。',
  ),
  IntroBook(
    id: favoriteBookId,
    title: '觀念化學1：基本概念．原子',
    coverTitle: '觀念化學1',
    coverSubtitle: '基本概念．原子',
    author: '蘇卡奇John Suchocki',
    publisher: '遠見天下文化出版股份有限公司',
    publishDate: '2020-06',
    isbn: '9789865535070',
    source: 'https://books.google.com/books?id=rTHwDwAAQBAJ',
    categoryId: 5,
    price: 170,
    condition: 'good',
    sellerId: 10,
    views: 48,
    createdAt: ago(days: 6),
    color: const Color(0xFF3A6EA5),
    accent: const Color(0xFFFFD166),
    description: '《觀念化學1》從生活中進行探索，介紹化學的基本概念與原子。',
  ),
  IntroBook(
    id: sellerPastSaleId,
    title: '普通化學學習手冊',
    coverTitle: '普通化學學習手冊',
    author: '魏明通',
    publisher: '五南圖書出版股份有限公司',
    publishDate: '2006',
    isbn: '9789571144535',
    source: 'https://books.google.com/books?id=-p-XdwvgJZMC',
    categoryId: 5,
    price: 60,
    condition: 'good',
    sellerId: sellerId,
    views: 12,
    createdAt: ago(days: 12),
    color: const Color(0xFF4F6D7A),
    accent: const Color(0xFFDBE9EE),
    description: '可配合《普通化學》學習使用。',
  ),
  IntroBook(
    id: sellerPurchaseId,
    title: '觀念化學4：生活中的化學',
    coverTitle: '觀念化學4',
    coverSubtitle: '生活中的化學',
    author: '蘇卡奇John Suchocki',
    publisher: '遠見天下文化出版股份有限公司',
    publishDate: '2020-06',
    isbn: '9789865535100',
    source: 'https://books.google.com/books?id=2zHwDwAAQBAJ',
    categoryId: 5,
    price: 150,
    condition: 'good',
    sellerId: 9,
    views: 22,
    createdAt: ago(days: 8),
    color: const Color(0xFF9C6644),
    accent: const Color(0xFFEDE0D4),
    description: '介紹生活中的化學。',
  ),
  IntroBook(
    id: secondDisputeBookId,
    title: '圖解資料結構-使用C++',
    coverTitle: '圖解資料結構',
    coverSubtitle: '使用C++',
    author: '黃建庭',
    publisher: '台科大圖書股份有限公司',
    publishDate: '2023-04',
    isbn: '9789865237332',
    source: 'https://books.google.com/books?id=DCe8EAAAQBAJ',
    categoryId: 3,
    price: 240,
    condition: 'good',
    sellerId: 7,
    views: 37,
    createdAt: ago(days: 10),
    color: const Color(0xFF355070),
    accent: const Color(0xFFEAAC8B),
    description: '以圖解方式說明資料結構。',
  ),
  IntroBook(
    id: secondReviewBookId,
    title: '基礎微積分',
    coverTitle: '基礎微積分',
    author: '黃學亮',
    publisher: '五南圖書出版股份有限公司',
    publishDate: '2024-01',
    isbn: '9786263669352',
    source: 'https://books.google.com/books?id=CokrEQAAQBAJ',
    categoryId: 1,
    price: 180,
    condition: 'good',
    sellerId: 6,
    views: 0,
    createdAt: ago(hours: 2, minutes: 40),
    color: const Color(0xFF3E5C76),
    accent: const Color(0xFFD9C27E),
    description: '介紹微積分的基礎概念與運算。',
  ),
];

IntroBook bookOf(int id) => introBooks.firstWhere((b) => b.id == id);

const feedOrder = [journeyId, 105, companionId, 104, 103, strangerBookId];

const homeGroups = [
  (relation: 'favorite', titleId: favoriteBookId, ids: [journeyId, companionId, 104]),
  (relation: null, titleId: null, ids: [105, strangerBookId, 103]),
];

const recommendationReasons = {
  journeyId: '銜接高中化學與大學課程的入門教材',
  companionId: '同系列續作，說明化學鍵與分子',
  104: '可搭配普通化學課程的實驗教材',
  105: '同出版社觀念系列的物理入門',
  strangerBookId: '由諾貝爾化學獎得主撰寫的化學入門讀物',
  103: '同系列續作，介紹化學反應的原理',
};

const orderNo = 'ODNMX0225';
const orderId = 25;
const door = 'A01';
const reservationHours = 48;

String get chatConfirmedAt => todayAt(14, 25);

String get reservationDeadline =>
    DateTime.parse(chatConfirmedAt).add(const Duration(hours: reservationHours)).toUtc().toIso8601String();

Map<String, dynamic> journeyOrder(String status, {Map<String, dynamic>? access}) {
  final b = bookOf(journeyId);
  final deposited = status != 'pending_deposit';
  return {
    'order_id': orderId,
    'order_no': orderNo,
    'buyer_id': buyerId,
    'seller_id': sellerId,
    'total_amount': b.price,
    'status': status,
    'pickup_code': null,
    'cabinet_id': cabinetId,
    'created_at': todayAt(14, 25),
    'picked_up_at': status == 'picked_up' || status == 'completed' ? ago(minutes: 1) : null,
    'completed_at': status == 'completed' ? ago(minutes: 1) : null,
    'order_items': [
      {'item_id': orderId * 10, 'book_id': b.id, 'quantity': 1, 'unit_price': b.price, 'subtotal': b.price, 'books': b.toJson()},
    ],
    'smart_cabinets': cabinetJson(),
    'cabinet_slots': deposited ? {'slot_id': 1, 'slot_number': door} : null,
    'users_orders_buyer_idTousers': user(buyerId),
    'users_orders_seller_idTousers': user(sellerId),
    'transaction_disputes': <Object>[],
    'doors': deposited ? [door] : <String>[],
    'cabinet_access': ?access,
  };
}

Map<String, dynamic> scanAccess() => {
  'mode': 'scan',
  'reason': null,
  'open_now': true,
  'open_time': '08:00',
  'close_time': '22:00',
  'available_doors': 3,
  'pre_deposit_doors': 1,
};

Map<String, dynamic> cabinetSessionJson(
  String kind,
  String status, {
  int? remainingMs,
  Map<String, dynamic>? result,
  bool done = false,
}) {
  final book = bookOf(journeyId);
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
    'cabinet': {...cabinetJson(), 'available_doors': 3},
    'location_status': 'granted',
    'distance_m': 12,
    'items': [
      {
        'key': 'order:$orderId',
        'kind': kind,
        'order_id': orderId,
        'order_no': orderNo,
        'books': [
          {'book_id': book.id, 'title': book.title, 'image_url': book.coverPath, 'door': placed ? door : null},
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
    'remaining_ms': remainingMs,
    'open_ms': 60000,
    'notice': null,
    'result': result,
    'created_at': ago(minutes: 1),
  };
}

Map<String, dynamic> Function() currentCabinetSession = () => cabinetSessionJson('order_deposit', 'matching', remainingMs: 52000);

Map<String, dynamic> listingFieldsResult() {
  final b = bookOf(journeyId);
  return {
    'fields': {
      'title': b.title,
      'author': b.author,
      'publisher': b.publisher,
      'publish_date': '2015-07-12',
      'publish_date_precision': 'day',
      'isbn': b.isbn,
      'page_count': 440,
      'language': 'zh-Hant',
      'description': journeySummary,
    },
    'description_source': 'mixed',
    'category': {'category_id': b.categoryId, 'name': categories[b.categoryId], 'confidence': 0.93},
    'condition': null,
    'price': {
      'suggested': 290,
      'min': 240,
      'max': 340,
      'original_price': 680,
      'original_price_verified': true,
      'currency': 'TWD',
      'by_condition': {'like_new': 390, 'good': 290, 'fair': 190, 'poor': 100},
      'reasons': ['尚未判斷書況，暫依定價 680 元約 3.5 至 5 成的比例計算，選擇書況後自動換算'],
    },
    'sources': _listingSources,
    'warnings': <String>[],
    'provider': 'openai',
    'model': 'gpt-5-nano',
    'suggestion_token': 'demo-suggestion-fields',
  };
}

const _listingSources = [
  {'title': 'Google Books', 'url': 'https://books.google.com/books?id=BGBqsgM1LIsC', 'domain': 'books.google.com'},
  {'title': '五南官網', 'url': 'https://www.wunan.com.tw/bookdetail?NO=8372', 'domain': 'www.wunan.com.tw'},
];

int conditionPrice = 222;

Map<String, dynamic> listingConditionResult() => {
  'fields': <String, Object>{},
  'description_source': 'mixed',
  'condition': {
    'level': 'fair',
    'confidence': 0.84,
    'reasons': ['書背上緣有明顯摺痕，封面四角輕微磨損', '內頁有螢光筆劃線，無缺頁或水漬'],
  },
  'price': {
    'suggested': conditionPrice,
    'min': 140,
    'max': 240,
    'original_price': 680,
    'original_price_verified': true,
    'currency': 'TWD',
    'by_condition': {'like_new': 390, 'good': 290, 'fair': conditionPrice, 'poor': 100},
    'reasons': ['依定價 680 元與目前書況約 2 至 3.5 成的比例計算', '本書 2025 年仍有新印刷，屬仍在使用的教科書，略為上調'],
  },
  'sources': _listingSources,
  'warnings': <String>[],
  'provider': 'openai',
  'model': 'gpt-5-nano',
  'suggestion_token': 'demo-suggestion-condition',
};

Map<String, dynamic> _message(
  int roomId,
  int id,
  int sender,
  String kind,
  String at, {
  String? text,
  Map<String, dynamic>? payload,
  Map<String, dynamic>? risk,
}) => {
  'message_id': id,
  'room_id': roomId,
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

const journeyRoomId = 7;
const warnRoomId = 3;

Map<String, dynamic> journeyReservation({required bool confirmed}) {
  final b = bookOf(journeyId);
  return {
    'reservation_id': 12,
    'book': {'book_id': b.id, 'title': b.title, 'price': b.price, 'status': 'on_sale', 'image_url': b.coverPath},
    'buyer_id': buyerId,
    'seller_id': sellerId,
    'status': confirmed ? 'confirmed' : 'pending',
    'hours': reservationHours,
    'message': '預計後天下午至書櫃取書。',
    'pickup_deadline': confirmed ? reservationDeadline : null,
    'is_holding': confirmed,
    'created_at': todayAt(14, 24),
    'seller': {'user_id': sellerId, 'nickname': users[sellerId]},
    'room_id': journeyRoomId,
  };
}

int chatStage = 1;

List<Map<String, dynamic>> journeyMessages() {
  final b = bookOf(journeyId);
  Map<String, dynamic> m(int id, int sender, String kind, String at, {String? text, Map<String, dynamic>? payload}) =>
      _message(journeyRoomId, id, sender, kind, at, text: text, payload: payload);
  return [
    m(1, buyerId, 'book', todayAt(14, 21), payload: {'book_id': b.id, 'title': b.title, 'price': b.price, 'image_url': b.coverPath}),
    m(2, buyerId, 'text', todayAt(14, 21), text: '您好，請問這本《普通化學》還在嗎？'),
    if (chatStage >= 2) ...[
      m(3, sellerId, 'text', todayAt(14, 22), text: '您好，還在的。書背上緣有摺痕，部分內頁有螢光筆劃線，不影響閱讀。'),
      m(4, buyerId, 'text', todayAt(14, 22), text: '好的。可以存放在圖書館總館一樓的書櫃嗎？我取書比較方便。'),
      m(5, sellerId, 'text', todayAt(14, 23), text: '可以，書會存放在圖書館總館一樓的書櫃。'),
    ],
    if (chatStage >= 3) m(6, buyerId, 'reservation', todayAt(14, 24), payload: journeyReservation(confirmed: chatStage >= 4)),
    if (chatStage >= 4) m(7, sellerId, 'text', todayAt(14, 25), text: '已確認預約，您付款後我會盡快存書。'),
  ];
}

Map<String, dynamic> journeyMeta() {
  final messages = journeyMessages();
  return {
    'read_upto': messages.length,
    'partner_typing': false,
    'recalled_ids': <int>[],
    'has_more': false,
    'reservations': [if (chatStage >= 3) journeyReservation(confirmed: chatStage >= 4)],
    'transfers': <Object>[],
    'members_read': [
      {'user_id': sellerId, 'last_read_message_id': messages.length},
    ],
    'aliases': <String, String>{},
    'edited': <Object>[],
    'room': {'type': 'direct', 'title': users[sellerId], 'avatar_url': null, 'member_count': 2},
    'risk_banner': null,
  };
}

int warnStage = 2;

List<Map<String, dynamic>> warnMessages() {
  final b = bookOf(strangerBookId);
  Map<String, dynamic> m(int id, int sender, String kind, String at, {String? text, Map<String, dynamic>? payload, Map<String, dynamic>? risk}) =>
      _message(warnRoomId, id, sender, kind, at, text: text, payload: payload, risk: risk);
  return [
    m(1, buyerId, 'book', todayAt(14, 20), payload: {'book_id': b.id, 'title': b.title, 'price': b.price, 'image_url': b.coverPath}),
    m(2, buyerId, 'text', todayAt(14, 20), text: '您好，請問這本書還在嗎？'),
    if (warnStage >= 1)
      m(
        3,
        strangerId,
        'text',
        todayAt(14, 22),
        text: '還在。平台要等存書比較慢，可以加我的 LINE：guanyu.lin，直接轉帳到我的帳戶，算您 120 元就好。',
        risk: {
          'level': 'high',
          'categories': ['payment', 'offsite', 'contact'],
        },
      ),
  ];
}

Map<String, dynamic> warnMeta() => {
  'read_upto': warnStage >= 1 ? 3 : 2,
  'partner_typing': false,
  'recalled_ids': <int>[],
  'has_more': false,
  'reservations': <Object>[],
  'transfers': <Object>[],
  'members_read': [
    {'user_id': strangerId, 'last_read_message_id': 2},
  ],
  'aliases': <String, String>{},
  'edited': <Object>[],
  'room': {'type': 'direct', 'title': users[strangerId], 'avatar_url': null, 'member_count': 2},
  'risk_banner': warnStage >= 2
      ? {
          'level': 'high',
          'categories': ['payment', 'offsite', 'contact'],
        }
      : null,
};

Map<String, dynamic> roomJson(int roomId, int partnerId, int me) => {
  'room_id': roomId,
  'type': 'direct',
  'name': '',
  'avatar_url': null,
  'created_by': me,
  'my_role': 'member',
  'members': [
    {...user(me), 'role': 'member', 'joined_at': ago(days: 1)},
    {...user(partnerId), 'role': 'member', 'joined_at': ago(days: 1)},
  ],
  'partner': {...user(partnerId), 'alias': null},
  'muted': false,
  'pinned': false,
};

List<Map<String, dynamic>> sellerTransactions() {
  Map<String, dynamic> t(int id, String no, String type, int amount, int after, String description, String at, {String? order, int? bookId}) => {
    'txn_id': id,
    'txn_no': no,
    'type': type,
    'amount': amount,
    'balance_after': after,
    'description': description,
    'created_at': at,
    'orders': order == null
        ? null
        : {
            'order_id': id,
            'order_no': order,
            'order_items': [
              {'books': bookOf(bookId!).toJson()},
            ],
          },
  };
  return [
    t(9, 'TX8NQ2W5K', 'sale_income', 222, 1228, '售出《普通化學》', todayAt(14, 25), order: orderNo, bookId: journeyId),
    t(7, 'TX3VH6M2R', 'purchase', -150, 1006, '購買《觀念化學4：生活中的化學》', ago(days: 5, hours: 3), order: 'OD6KW3P8T', bookId: sellerPurchaseId),
    t(5, 'TX5RJ9C4D', 'sale_income', 60, 1156, '售出《普通化學學習手冊》', ago(days: 8, hours: 6), order: 'OD2QF7L9M', bookId: sellerPastSaleId),
    t(2, 'TX7DL4B8N', 'deposit', 1000, 1096, '儲值', ago(days: 20)),
  ];
}

const supportQuestion1 = '訂單 $orderNo 的取書期限是什麼時候？';
const supportQuestion2 = '可以把這筆訂單改到其他書櫃取書嗎？';

int? supportUpto;

Map<String, dynamic> supportSession() => {
  'session_id': 4,
  'status': 'open',
  'messages': [
    {'message_id': 41, 'role': 'user', 'content': supportQuestion1, 'created_at': ago(minutes: 4)},
    {
      'message_id': 42,
      'role': 'assistant',
      'content':
          '訂單 $orderNo 已存入「$cabinetName」書櫃，取書期限為存書後 7 天。請於開放時間 08:00–22:00 至書櫃以 App 掃描 QR Code 取書；'
          '逾期未取書時，訂單將自動取消，代幣全額退回您的錢包。',
      'message_no': 'AS4QK7M2D',
      'feedback': {'rating': 'helpful'},
      'created_at': ago(minutes: 4),
    },
    {'message_id': 43, 'role': 'user', 'content': supportQuestion2, 'created_at': ago(minutes: 1)},
    {
      'message_id': 44,
      'role': 'assistant',
      'content': '書籍存入書櫃後無法變更取書書櫃。如有特殊情況，建議由客服人員協助確認。',
      'message_no': 'AS9WT3R6H',
      'suggest_handoff': true,
      'created_at': ago(minutes: 1),
    },
  ].take(supportUpto ?? 4).toList(),
};

const disputeId = 4;
const disputeEvidence = ['/uploads/disputes/intro-evidence-1.png', '/uploads/disputes/intro-evidence-2.png'];

bool disputeAnalyzed = true;

List<Map<String, dynamic>> adminDisputes() {
  Map<String, dynamic> dispute(int id, String no, int bookId, int buyer, String reason, String createdAt, {List<String> evidence = const []}) {
    final b = bookOf(bookId);
    return {
      'dispute_id': id,
      'order_id': id + 20,
      'applicant_id': buyer,
      'reason': reason,
      'status': 'pending',
      'result': null,
      'admin_note': null,
      'created_at': createdAt,
      'evidence_images': evidence,
      'users_transaction_disputes_applicant_idTousers': {'nickname': users[buyer]},
      'orders': {
        'order_id': id + 20,
        'order_no': no,
        'total_amount': b.price,
        'status': 'disputed',
        'users_orders_buyer_idTousers': {'nickname': users[buyer]},
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
      4,
      '書中多個章節有大量螢光筆畫線與筆記，與商品描述「近全新、內頁無畫線」不符。',
      ago(hours: 3, minutes: 20),
      evidence: disputeEvidence,
    ),
    dispute(3, 'OD2LM8C5W', secondDisputeBookId, 6, '書櫃取出的書籍封底有水漬，商品照片與描述皆未提及。', ago(days: 1, hours: 6)),
  ];
}

Map<String, dynamic> disputeAnalysis() {
  final title = bookOf(disputeBookId).title;
  return {
    'analysis_no': 'DA7NQ2X5K',
    'summary': '買家表示書中多個章節有大量螢光筆畫線與筆記；商品描述為「近全新、內頁無畫線」，上架照片僅含封面、封底與一張內頁。',
    'finding_details': [
      {'content': '佐證照片可見多頁螢光筆畫線與手寫筆記，範圍涵蓋數個章節', 'basis': 'evidence_photo', 'photos': [4, 5], 'favors': 'buyer'},
      {'content': '上架內頁照片乾淨無畫線，但未呈現爭議所指的頁面', 'basis': 'listing_photo', 'photos': [3], 'favors': 'neutral'},
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

const reviewSynopsis = '教導讀者在最短時間內學會畫好有機化學的反應機構，並附大量題目即時演練。';
const reviewPhotos = ['/uploads/books/intro-107-back.png', '/uploads/books/intro-107-inside.png'];

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
      secondReviewBookId,
      verdict: 'reject',
      reasons: ['內頁照片可見影印裝訂與黑邊，疑似整本影印的盜版書'],
      categories: ['prohibited'],
      origin: 'ai',
      confidence: 0.91,
      createdAt: ago(hours: 2, minutes: 40),
    ),
  ];
}

Map<String, dynamic> _cabinetNearby() {
  final snapshot = jsonDecode(File(transitSnapshotPath).readAsStringSync()) as Map<String, dynamic>;
  final nearby = Map<String, dynamic>.from(snapshot['nearby'] as Map);
  return applyDaytime(nearby);
}

late final String transitSnapshotPath;

final daytimeChanges = <String>[];

Map<String, dynamic> applyDaytime(Map<String, dynamic> nearby) {
  final out = jsonDecode(jsonEncode(nearby)) as Map<String, dynamic>;
  out['cabinet'] = {'latitude': cabinetLat, 'longitude': cabinetLng};
  final changes = <String>[];

  final times = {'mrt': (14, 23), 'bus': (14, 24), 'youbike': (14, 22), 'parking_lots': (14, 21), 'road_speed': (14, 23), 'taxi_stands': (14, 23)};
  for (final MapEntry(key: section, value: (h, m)) in times.entries) {
    final block = out[section] as Map<String, dynamic>;
    if (block['updated_at'] != null) {
      changes.add('$section.updated_at：${block['updated_at']} → 今天 ${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}');
      block['updated_at'] = todayAt(h, m);
    }
  }

  const busEta = {
    '大安國宅|建國南路二段109號前(向北)|38': ('minutes', 4),
    '大安國宅|建國南路二段109號前(向北)|298': ('minutes', 7),
    '大安國宅|建國南路二段109號前(向北)|紅57': ('minutes', 12),
    '大安國宅|建國南路二段大安森林公園四號出入口(向南)|298': ('arriving', 0),
    '大安國宅|建國南路二段大安森林公園四號出入口(向南)|紅57': ('minutes', 9),
    '建國南路|建國南路2段大安森林公園信箱前|298': ('minutes', 14),
    '建國南路|建國南路2段大安森林公園信箱前|紅57': ('minutes', 8),
  };
  for (final stop in (out['bus']['stops'] as List).cast<Map<String, dynamic>>()) {
    for (final route in (stop['routes'] as List).cast<Map<String, dynamic>>()) {
      final key = '${stop['name']}|${stop['address']}|${route['name']}';
      final eta = busEta[key];
      if (eta == null) continue;
      changes.add('公車 ${stop['name']}（${stop['address']}）${route['name']}：${route['status']}${route['minutes'] == null ? '' : ' ${route['minutes']} 分'} → ${eta.$1 == 'arriving' ? '即將進站' : '${eta.$2} 分'}');
      route['status'] = eta.$1;
      route['minutes'] = eta.$2;
    }
  }

  const bikes = {'臺北市立圖書館(總館)': 41, '瑞安街208巷': 5, '建國南路二段瑞安街264巷口': 12, '建國和平路口西北側': 17, '龍圖公園': 8};
  for (final s in (out['youbike']['stations'] as List).cast<Map<String, dynamic>>()) {
    final rent = bikes[s['name']];
    if (rent == null) continue;
    final total = s['total'] as int;
    changes.add('YouBike ${s['name']}：可借 ${s['available_rent']}・可還 ${s['available_return']} → 可借 $rent・可還 ${total - rent}（總數 $total 不變）');
    s['available_rent'] = rent;
    s['available_return'] = total - rent;
    s['updated_at'] = todayAt(14, 22);
  }

  const lots = {'建國南路高架橋下停車場B區': 21, '臺北市大安福邸公寓大廈社區中庭地下停車場': 9, '建國南路高架橋下停車場A區': 35, '建國南路高架橋下停車場C區': 12};
  for (final lot in (out['parking_lots']['lots'] as List).cast<Map<String, dynamic>>()) {
    final available = lots[lot['name']];
    if (available == null) continue;
    final car = lot['car'] as Map<String, dynamic>;
    changes.add('停車場 ${lot['name']}：汽車空位 ${car['available']} → $available（總數 ${car['total']} 不變）');
    car['available'] = available;
  }

  if (daytimeChanges.isEmpty) daytimeChanges.addAll(changes);
  return out;
}

Map<String, dynamic> _snapshotPart(String key) =>
    Map<String, dynamic>.from((jsonDecode(File(transitSnapshotPath).readAsStringSync()) as Map<String, dynamic>)[key] as Map);

int me = buyerId;

Map<String, dynamic>? _route(String method, String path, Map<String, String> query, String body) {
  final isSeller = me == sellerId;
  final routes = <String, Object? Function()>{
    'GET /status': () => {'api_revision': 99, 'commit': 'demo'},
    'GET /auth/me': () => user(me),
    'GET /users/me/stats': () => isSeller
        ? {'balance': 1228, 'book_count': 1, 'favorite_count': 3, 'unread_notification_count': 1, 'cart_count': 0}
        : {'balance': 1239, 'book_count': 0, 'favorite_count': 4, 'unread_notification_count': 1, 'cart_count': 1},
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
    'GET /favorites/ids': () => [favoriteBookId, companionId],
    'GET /cart/book-ids': () => [104],
    'GET /chat/unread-count': () => {'unread_count': 1},
    'GET /notifications/unread-count': () => {
      'unread_count': 1,
      'by_category': {'trade': 1, 'chat': 1, 'account': 0, 'service': 0, 'promotion': 0},
    },
    'GET /chat/rooms': () => [
      {
        'room_id': warnRoomId,
        'type': 'direct',
        'title': users[strangerId],
        'avatar_url': null,
        'partner': {...user(strangerId), 'alias': null},
        'member_count': 2,
        'last_message': {
          'sender_id': buyerId,
          'sender_name': users[buyerId],
          'content': '您好，請問這本書還在嗎？',
          'body': '您好，請問這本書還在嗎？',
          'kind': 'text',
          'message_type': 'text',
          'is_read': true,
          'created_at': ago(minutes: 5),
        },
        'unread_count': 0,
        'mention_unread': false,
        'muted': false,
        'blocked': false,
        'pinned': false,
        'updated_at': ago(minutes: 5),
      },
    ],
    'GET /chat/rooms/$journeyRoomId': () => roomJson(journeyRoomId, sellerId, buyerId),
    'GET /chat/rooms/$warnRoomId': () => roomJson(warnRoomId, strangerId, buyerId),
    'GET /books/$journeyId/similar': () => [for (final id in [companionId, 104, 103]) bookOf(id).toJson()],
    'GET /orders/$orderId': () => journeyOrder(pickupOrderStatus),
    'GET /wallet': () => isSeller
        ? {'balance': 1228, 'frozen_amount': 0, 'total_income': 282, 'total_expense': 150, 'pending_income': 0}
        : {'balance': 1239, 'frozen_amount': 0, 'total_income': 0, 'total_expense': 0, 'pending_income': 0},
    'GET /wallet/transactions': () => isSeller ? sellerTransactions() : <Object>[],
    'GET /wallet/pending': () => <Object>[],
    'GET /reports/against-me': () => <Object>[],
    'GET /security': () => {
      'available': true,
      'has_payment_pin': true,
      'pin_locked_until': null,
      'biometric_pay_enabled': false,
      'passkey_available': true,
      'has_passkey': true,
      'has_password': true,
    },
    'POST /security/verify': () => {'verify_token': 'demo-verify-token', 'expires_in': 300},
    'GET /cabinets': () => [
      {...cabinetJson(), 'available_slots': 3, 'distance_m': 380},
    ],
    'GET /cabinet-sessions/active': () => null,
    'GET /cabinet-sessions/CS4N7Q2KX': () => currentCabinetSession(),
    'GET /cabinet-sessions/CS7HW2Q5K': () => currentCabinetSession(),
    'GET /books/isbn/${bookOf(journeyId).isbn}': () => null,
    'GET /cabinets/$cabinetId/nearby': _cabinetNearby,
    'GET /admin/cabinets/nearby-preview': _cabinetNearby,
    'GET /cabinets/mrt-stations': () => _snapshotPart('stations'),
    'GET /cabinets/mrt-fares': () => _snapshotPart('fares'),
    'GET /ai/support/session': supportSession,
    'GET /admin/disputes': adminDisputes,
    'GET /admin/disputes/$disputeId/ai-analysis': () => disputeAnalyzed ? disputeAnalysis() : null,
    'POST /admin/disputes/$disputeId/ai-analysis': disputeAnalysis,
    'GET /admin/ai/reviews': listingReviews,
  };

  final key = '$method $path';
  if (key == 'POST /ai/listing-assist') {
    final conditionOnly = RegExp(r'name="mode"\s+condition').hasMatch(body);
    return _ok(conditionOnly ? listingConditionResult() : listingFieldsResult());
  }
  if (key == 'GET /books') {
    if (query['seller_id'] == '$sellerId') return _ok(sellerBooks());
    return _ok([for (final id in feedOrder) bookOf(id).toJson()]);
  }
  if (key == 'GET /orders') {
    final tab = query['tab'] ?? '';
    if (query['role'] == 'seller') return _ok(<Object>[]);
    if (tab == 'awaiting_pickup' || tab == 'pending_pickup') return _ok([journeyOrder('deposited', access: scanAccess())]);
    return _ok(<Object>[]);
  }
  if (key == 'GET /chat/rooms/$journeyRoomId/messages') {
    return {'success': true, 'message': 'OK', 'data': journeyMessages(), 'partner': user(sellerId), 'meta': journeyMeta()};
  }
  if (key == 'GET /chat/rooms/$warnRoomId/messages') {
    return {'success': true, 'message': 'OK', 'data': warnMessages(), 'partner': user(strangerId), 'meta': warnMeta()};
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
    final ids = {for (final g in homeGroups) ...g.ids};
    return {
      'success': true,
      'message': 'OK',
      'data': [
        for (final id in ids) {'book': bookOf(id).toJson(), 'reason': recommendationReasons[id]},
      ],
      'groups': [
        for (final g in homeGroups)
          if (g.relation != null)
            {'kind': 'book', 'relation': g.relation, 'book_id': g.titleId, 'title': bookOf(g.titleId!).title, 'book_ids': g.ids}
          else
            {'kind': 'category', 'category': categories[5], 'book_ids': g.ids},
      ],
      'meta': {'source': 'ai', 'generated_at': ago(minutes: 20)},
    };
  }
  if (routes.containsKey(key)) return _ok(routes[key]!());
  if (method == 'GET') return _ok(<Object>[]);
  return _ok(<String, Object>{});
}

String pickupOrderStatus = 'deposited';

List<Map<String, dynamic>> sellerBooks() => [
  bookOf(journeyId).toJson(),
  bookOf(sellerPastSaleId).toJson(extra: {'status': 'sold'}),
];

Map<String, dynamic> _ok(Object? data) => {
  'success': true,
  'message': 'OK',
  'data': data,
  if (data is List) 'pagination': {'total': data.length, 'page': 1, 'limit': 20, 'total_pages': 1},
};

MockClient introApi() => MockClient((request) async {
  final path = request.url.path.replaceFirst('/api', '');
  final body = _route(request.method, path, request.url.queryParameters, utf8.decode(request.bodyBytes, allowMalformed: true));
  return http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json; charset=utf-8'});
});
