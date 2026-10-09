// 系統簡介影片第二版的劇情資料。書籍、照片、賣家、書櫃一律取自正式站公開端點（../manual_shots/real_data.g.dart）；
// 需要登入才看得到的內容（AI 回覆、聊天、審核紀錄）以這些真實書籍與使用者組合，數值依後端實際規則計算。

import 'dart:ui' show Offset;

import 'package:savemybook_app/i18n/strings.dart';

import '../manual_shots/manual_api.dart';

// ───────────── 劇情主角 ─────────────

/// 《HTML & CSS：網站設計建置優化之道》，雪喵上架、存放於新北高工書櫃。
const storyBookId = 150;

/// 劇情訂單（各段共用，訂單編號與時間必須一致）：es 兩天前 14:30:22 付款，雪喵 15:12 存入新北高工 A01，
/// es 當晚 19:12 取書，滿 24 小時無爭議後於前一天 19:19 撥款。編號格式比照伺服器：SMB + 年月日時分秒 + 6 位亂數。
const storyOrderId = 451;
DateTime storyAt(int daysAgo, int hour, int minute, [int second = 0]) {
  final d = DateTime.now().subtract(Duration(days: daysAgo));
  return DateTime(d.year, d.month, d.day, hour, minute, second);
}
final storyPaidAt = storyAt(2, 14, 30, 22);
final storyDepositedAt = storyAt(2, 15, 12, 40);
final storyPickedAt = storyAt(2, 19, 12, 5);
final storyPayoutAt = storyAt(1, 19, 19, 5);
String _p2(int n) => n.toString().padLeft(2, '0');
final storyOrderNo = 'SMB${storyPaidAt.year}${_p2(storyPaidAt.month)}${_p2(storyPaidAt.day)}'
    '${_p2(storyPaidAt.hour)}${_p2(storyPaidAt.minute)}${_p2(storyPaidAt.second)}618904';
const sellerId = 21;
const buyerId = meId;
const cabinetId = 7;

Map<String, dynamic> get storyBook => bookJson(storyBookId);
String get storyTitle => storyBook['title'] as String;
String get storyIsbn => storyBook['isbn'] as String;
String get sellerName => realUsers[sellerId]!.nickname;

List<Map> get _storyImages => (storyBook['book_images'] as List).cast<Map>();

/// 實拍照片：cover 封面、back 封底、other 為 ISBN 條碼特寫。
String storyPhoto(String type) => _storyImages.firstWhere((i) => i['image_type'] == type)['image_url'] as String;

/// 條碼特寫照片中條碼的中心（原檔 900×1200 的像素座標）與傾斜角度（度，順時針轉正）。
const barcodeCenter = (x: 392.0, y: 792.0);
const barcodeTilt = 45.0;

/// 轉正後條碼線條（不含下方數字）相對 [barcodeCenter] 的中心與大小（原檔像素），用於標示辨識到的條碼範圍。
const barcodeBars = (dx: 14.0, dy: 12.0, w: 262.0, h: 132.0);

/// 相機畫面中照片的縮放（pt／原檔像素）與條碼相對掃描框中心的位移。
const cameraScale = 0.80;
const cameraShift = Offset(-12, 22);

/// 新書定價：條碼特寫照片上印有 NT$580，即 AI 上架輔助可由照片查證的定價。
const listPrice = 580;

// ───────────── AI 上架輔助（第 2 步：依照片判斷書況與售價）─────────────

/// 後端 listing-assist.js 的書況比例（RATIO_RANGE、PRICE_RATIO）與 10 元級距，定價已知時由伺服器算出四種書況的價格。
const _ratioRange = {'like_new': (0.5, 0.65), 'good': (0.35, 0.5), 'fair': (0.2, 0.35), 'poor': (0.1, 0.2)};
const _priceRatio = {'like_new': 0.575, 'good': 0.425, 'fair': 0.275, 'poor': 0.15};

int _step(double v) => ((v / 10).round() * 10).clamp(20, listPrice);

Map<String, Map<String, int>> get priceTable => {
  for (final level in _ratioRange.keys)
    level: {
      'suggested': _step(listPrice * _priceRatio[level]!),
      'min': _step(listPrice * _ratioRange[level]!.$1),
      'max': _step(listPrice * _ratioRange[level]!.$2),
    },
};

Map<String, dynamic> conditionAssist() {
  final good = priceTable['good']!;
  return {
    'mode': 'condition',
    'fields': <String, Object>{},
    'condition': {
      'level': 'good',
      'confidence': 0.82,
      'reasons': ['封面與封底可見細小刮痕，屬輕微使用痕跡', '書角與書緣完整，未見摺痕或缺角', '條碼頁乾淨，無污漬或貼紙'],
    },
    'price': {
      'suggested': good['suggested'],
      'min': good['min'],
      'max': good['max'],
      'original_price': listPrice,
      'original_price_verified': true,
      'currency': 'TWD',
      'by_condition': {for (final e in priceTable.entries) e.key: e.value['suggested']},
      // 後端以 constants/domain.js 的名稱寫「良好」，App 繁中把同一等級（good）顯示為「近全新」；畫面上統一用 App 的名稱
      'reasons': ['依定價 $listPrice 元與書況「${S.conditionGood}」約 3.5 至 5 成的比例計算'],
    },
    'sources': [
      {'title': 'HTML&CSS', 'url': 'https://www.gotop.com.tw/books/BookDetails.aspx?Types=v&bn=ACU061200', 'domain': 'gotop.com.tw'},
      {'title': storyTitle, 'url': 'https://www.tenlong.com.tw/products/$storyIsbn', 'domain': 'tenlong.com.tw'},
    ],
    'warnings': ['照片未拍到內頁與書口，建議補拍後再確認書況'],
    'provider': 'openai',
    'model': 'gpt-5-nano',
    'suggestion_token': 'AS3P8W2RT',
  };
}

/// ISBN 查詢（GET /books/isbn/:isbn）：正式站已有這本書的書目資料。
Map<String, dynamic> isbnLookup() => {
  'isbn': storyIsbn,
  'title': storyTitle,
  'author': storyBook['author'],
  'publisher': storyBook['publisher'],
  'publish_date': storyBook['publish_date'],
  'description': storyBook['description'],
  'category_id': storyBook['category_id'],
};

// ───────────── 上架審核 ─────────────

/// 書籍描述末尾附有出版社官網（下載範例檔），命中規則「站外交易或聯絡資訊」（listing-screening.js 的 CONTACT_RISKS，
/// 網址一律視為連結）而送人工審核；AI 審核意見附在審核紀錄上（reviews.attachOpinion）。
const reviewDescriptionTail = '書中範例檔可至碁峰資訊官網 www.gotop.com.tw 下載。';

Map<String, dynamic> reviewItem() {
  final b = storyBook;
  return {
    'book_id': storyBookId,
    'book': {
      ...b,
      'description': '${b['description']}\n\n$reviewDescriptionTail',
      'is_approved': false,
    },
    'seller': {'user_id': sellerId, 'nickname': sellerName, 'avatar_url': realUsers[sellerId]!.avatar},
    'verdict': 'review',
    'reasons': ['站外交易或聯絡資訊'],
    'categories': ['contact'],
    'status': 'pending',
    'origin': 'rules',
    'confidence': null,
    'decision_reason': null,
    'provider': null,
    'model': 'rules',
    'created_at': b['created_at'],
    'reviewed_at': null,
    'ai_opinion': {
      'verdict': 'allow',
      'confidence': 0.93,
      'categories': <String>[],
      'reasons': ['描述中的網址為出版社官網，用於下載範例檔', '照片為實體書封面、封底與條碼頁，與書名相符', '售價低於定價，未見異常'],
    },
  };
}

// ───────────── 買家找書 ─────────────

const searchKeyword = 'HTML';

/// 首頁「為您推薦」：與網頁設計、程式實作相關的真實在售書籍，推薦理由比照 recommend.js 的規則（30 字內、指出與紀錄的關聯）。
const recommendations = [
  (id: 78, reason: '延伸網頁前端開發，以實例學習 Vue.js 框架'),
  (id: 125, reason: '以 JavaScript 擴充自動化流程，適合實作練習'),
  (id: 96, reason: '延伸 Python 程式實作的自然語言處理主題'),
  (id: 97, reason: '介紹 Gemini 與 NotebookLM 等 AI 工具的應用'),
];

// AI 書籍顧問：需求含預算 300 代幣；挑選的兩本皆為正式站在售且售價在預算內（150：250、78：200）。
const advisorRequest = '我想自學網頁設計，請推薦 HTML、CSS 或前端框架的入門書，預算 300 代幣以內。';
const advisorBudget = 300;

const advisorPicks = [
  (id: storyBookId, reason: '以循序漸進的範例說明 HTML 結構與 CSS 樣式'),
  (id: 78, reason: '熟悉基礎後，以完整實例學習 Vue.js 框架'),
];

String get advisorReply =>
    '了解，您想自學網頁設計，預算在 300 代幣以內。建議先從《$storyTitle》入門，書中以範例說明網頁結構與樣式；'
    '熟悉基礎後，可再以《${bookJson(78)['title']}》學習前端框架的實作。';

const advisorSuggestions = ['有沒有 JavaScript 的入門書？', '只看已在書櫃的書', '推薦網頁排版設計的書'];

Map<String, dynamic> advisorAnswer(String clientId) => {
  'session_id': 31,
  'user_message': {'message_id': 801, 'role': 'user', 'content': advisorRequest, 'client_id': clientId, 'created_at': ago(minutes: 0)},
  'reply': {
    'message_id': 802,
    'role': 'assistant',
    'content': advisorReply,
    'books': [
      for (final p in advisorPicks) {'book': bookJson(p.id), 'reason': p.reason},
    ],
    'suggestions': advisorSuggestions,
    'degraded': false,
    'created_at': ago(minutes: 0),
    'message_no': 'AC4M7Q2KX',
    'feedback': null,
  },
};

// ───────────── 聊天室 ─────────────

const sellerRoomId = 12;
const scamRoomId = 13;

/// 陌生帳號：主動私訊買家、要求私下轉帳的新註冊帳號（虛構，不對應任何真實會員）。
const strangerId = 64;
const strangerName = '二手書出清';

const voicePath = '/uploads/voice/1791451230847-3f9c2a7d5e1b0846.m4a';

Map<String, dynamic> _sender(int id) => id == strangerId
    ? {'user_id': id, 'nickname': strangerName, 'avatar_url': null}
    : {'user_id': id, 'nickname': realUsers[id]!.nickname, 'avatar_url': realUsers[id]!.avatar};

Map<String, dynamic> chatMessage(
  int room,
  int id,
  int sender,
  String kind,
  String at, {
  String? text,
  Map<String, dynamic>? payload,
  Map<String, dynamic>? risk,
}) => {
  'message_id': id,
  'room_id': room,
  'sender_id': sender,
  'content': text ?? '',
  'message_type': switch (kind) {
    'text' => 'text',
    'image' => 'image',
    'voice' => 'voice',
    _ => 'system',
  },
  'kind': kind,
  'body': text,
  'mentions': <Object>[],
  'payload': payload,
  'is_read': true,
  'created_at': at,
  'edited_at': null,
  'reply_to': null,
  'users': _sender(sender),
  'risk': risk,
};

const chatQuestion = '您好，請問這本書的書況如何？可以看一下封底嗎？';
const chatSellerText = '付款後我會把書存入新北高工的書櫃，存好就能去取書。';

List<Map<String, dynamic>> sellerMessages() {
  Map<String, dynamic> m(int id, int sender, String kind, String at, {String? text, Map<String, dynamic>? payload}) =>
      chatMessage(sellerRoomId, id, sender, kind, at, text: text, payload: payload);
  final b = storyBook;
  return [
    m(1, buyerId, 'book', todayAt(14, 20, daysAgo: 2), payload: {'book_id': storyBookId, 'title': storyTitle, 'price': b['price'], 'image_url': coverOf(storyBookId)}),
    m(2, buyerId, 'text', todayAt(14, 20, daysAgo: 2), text: chatQuestion),
    m(3, sellerId, 'image', todayAt(14, 22, daysAgo: 2), text: storyPhoto('back')),
    m(4, sellerId, 'voice', todayAt(14, 22, daysAgo: 2), payload: {'url': voicePath, 'duration': 9}),
    m(5, sellerId, 'text', todayAt(14, 23, daysAgo: 2), text: chatSellerText),
  ];
}

/// 陌生帳號的訊息：依 chat/risk.js 的規則命中「付款」（轉帳到我的帳戶）與「平台外交易」（直接轉帳），
/// 再加上新註冊、無完成交易的帳號因素，分數達到高風險門檻。
const scamGreeting = '您好，看到您在找網頁設計的書，我手邊有幾本，價格可以算便宜一點。';
const scamReply = '請問有哪些書？';
const scamText = '有《HTML & CSS》，比平台上便宜。平台要等存書比較慢，直接轉帳到我的帳戶，我今天就寄出。';
const scamRisk = {
  'level': 'high',
  'categories': ['payment', 'offsite'],
};

List<Map<String, dynamic>> scamMessages({required bool withScam}) {
  Map<String, dynamic> m(int id, int sender, String at, String text, {Map<String, dynamic>? risk}) =>
      chatMessage(scamRoomId, id, sender, 'text', at, text: text, risk: risk);
  return [
    m(1, strangerId, todayAt(15, 2), scamGreeting),
    m(2, buyerId, todayAt(15, 4), scamReply),
    if (withScam) m(3, strangerId, todayAt(15, 5), scamText, risk: scamRisk),
  ];
}

Map<String, dynamic> roomMeta({required int partner, required int count, Map<String, dynamic>? riskBanner}) => {
  'read_upto': count,
  'partner_typing': false,
  'recalled_ids': <int>[],
  'has_more': false,
  'reservations': <Object>[],
  'transfers': <Object>[],
  'members_read': [
    {'user_id': partner, 'last_read_message_id': count},
  ],
  'aliases': <String, String>{},
  'edited': <Object>[],
  'room': {'type': 'direct', 'title': _sender(partner)['nickname'], 'avatar_url': _sender(partner)['avatar_url'], 'member_count': 2},
  'risk_banner': riskBanner,
};

Map<String, dynamic> roomJson(int roomId, int partner) => {
  'room_id': roomId,
  'type': 'direct',
  'name': '',
  'avatar_url': null,
  'created_by': partner,
  'my_role': 'member',
  'members': [
    {...userJson(buyerId), 'role': 'member', 'joined_at': ago(days: 1)},
    {..._sender(partner), 'role': 'member', 'joined_at': ago(days: 1)},
  ],
  'partner': {..._sender(partner), 'alias': null},
  'muted': false,
  'pinned': false,
};
