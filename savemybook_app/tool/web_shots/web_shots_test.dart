// 官網用 App 畫面截圖：flutter test tool/web_shots/web_shots_test.dart
// 輸出 1179×2556 PNG 至 ../savemybook_web/assets-src/screens（含總覽 _sheet.png）；只跑單張可加 --plain-name home。

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:http/http.dart' as http;
// ignore: depend_on_referenced_packages
import 'package:local_auth_platform_interface/local_auth_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:savemybook_app/features/account/ai_support_screen.dart';
import 'package:savemybook_app/features/account/wallet_screen.dart';
import 'package:savemybook_app/features/admin/admin_cabinet_edit_screen.dart';
import 'package:savemybook_app/features/admin/admin_dispute_screen.dart';
import 'package:savemybook_app/features/admin/admin_image_strip.dart';
import 'package:savemybook_app/features/admin/admin_report_screen.dart';
import 'package:savemybook_app/features/admin/dispute_ai_panel.dart';
import 'package:savemybook_app/features/books/book_detail_screen.dart';
import 'package:savemybook_app/features/cabinet/cabinet_flow_screen.dart';
import 'package:savemybook_app/features/cabinet/cabinet_guide_screen.dart';
import 'package:savemybook_app/features/cabinet/cabinet_match_code_field.dart';
import 'package:savemybook_app/features/cabinet/cabinet_scanner_view.dart';
import 'package:savemybook_app/features/chat/ai/ai_book_chat_screen.dart';
import 'package:savemybook_app/features/chat/chat_room_screen.dart';
import 'package:savemybook_app/features/home/home_screen.dart';
import 'package:savemybook_app/features/home/notification_screen.dart';
import 'package:savemybook_app/features/orders/my_reservations_screen.dart';
import 'package:savemybook_app/features/orders/order_detail_screen.dart';
import 'package:savemybook_app/features/orders/order_history_screen.dart';
import 'package:savemybook_app/features/security/passkeys_card.dart';
import 'package:savemybook_app/features/security/security_center_screen.dart';
import 'package:savemybook_app/features/selling/ai_listing_assist.dart';
import 'package:savemybook_app/features/selling/sell_book_detail_screen.dart';
import 'package:savemybook_app/features/selling/sell_book_screen.dart';
import 'package:savemybook_app/i18n/app_localizations.dart';
import 'package:savemybook_app/i18n/strings.dart';
import 'package:savemybook_app/models/ai.dart';
import 'package:savemybook_app/models/book.dart';
import 'package:savemybook_app/models/cabinet.dart';
import 'package:savemybook_app/models/order.dart';
import 'package:savemybook_app/models/security.dart';
import 'package:savemybook_app/models/user.dart';
import 'package:savemybook_app/services/ai_status.dart';
import 'package:savemybook_app/services/api_service.dart';
import 'package:savemybook_app/services/biometric_service.dart';
import 'package:savemybook_app/services/locale_provider.dart';
import 'package:savemybook_app/services/passkey_service.dart';
import 'package:savemybook_app/services/recently_viewed.dart';
import 'package:savemybook_app/services/theme_provider.dart';
import 'package:savemybook_app/services/verification_service.dart';
import 'package:savemybook_app/utils/app_theme.dart';
import 'package:savemybook_app/widgets/pin_pad.dart';

import 'covers.dart';
import 'demo_data.dart';

const _logicalSize = Size(393, 852);
const _pixelRatio = 3.0;
const _topInset = 59.0;
const _bottomInset = 34.0;

final _outDir = Directory('${Directory.current.path}/../savemybook_web/assets-src/screens');
final _navigatorKey = GlobalKey<NavigatorState>();
final _overlay = ValueNotifier<ScreenOverlay>(const ScreenOverlay());

typedef Snap = Future<void> Function(String name);
typedef Act = Future<void> Function(WidgetTester tester, Snap snap);

class Shot {
  final String name;
  final Widget Function() home;
  final Act? act;
  final List<String> outputs;
  final Map<String, Object> Function()? prefs;

  const Shot(this.name, this.home, {this.act, List<String>? outputs, this.prefs}) : outputs = outputs ?? const [];

  List<String> get files => outputs.isEmpty ? [name] : outputs;
}

Book _book(int id) => Book.fromJson(bookOf(id).toJson());

CabinetSession _session(String status, {int? remainingMs, Map<String, dynamic>? result, bool done = false}) {
  currentCabinetSession = () => cabinetSessionJson(status, remainingMs: remainingMs, result: result, done: done);
  return CabinetSession.fromJson(currentCabinetSession());
}

List<Shot> get shots => [
  const Shot('home', HomeScreen.new),
  Shot('sell', HomeScreen.new, act: _sellFlow, outputs: const ['sell_ai_sheet', 'sell_ai', 'sell_ai_detail']),
  Shot(
    'sell_price',
    _sellDetail,
    prefs: () => _draftPrefs(condition: 'fair'),
    act: _sellPrice,
  ),
  Shot(
    'book_detail',
    () => BookDetailScreen(book: _book(statsBookId)),
    act: (t, snap) async {
      await _scrollBy(t, 318);
      await snap('book_detail');
    },
  ),
  Shot('ai_chat', () => AiBookChatScreen(initialItems: _aiChatItems())),
  const Shot('chat_room', _chatRoom),
  const Shot('my_reservations', MyReservationsScreen.new),
  Shot('pay_verify', () => BookDetailScreen(book: _book(statsBookId)), act: _payVerify),
  Shot('cabinet_scan', () => const CabinetFlowScreen(scanInput: Stream.empty()), act: _cameraView),
  _matchShot('cabinet_match_empty', ''),
  _matchShot('cabinet_match', '25'),
  Shot('cabinet_open', () => CabinetFlowScreen(resume: _session('open', remainingMs: 29000))),
  Shot(
    'cabinet_done',
    () =>
        CabinetFlowScreen(resume: _session('completed', result: {'outcome': 'completed', 'code': 'COMPLETED', 'message': ''}, done: true)),
  ),
  const Shot('order_history', OrderHistoryScreen.new),
  Shot('order_detail', () => OrderDetailScreen(order: Order.fromJson(pickupOrder()))),
  const Shot('wallet', WalletScreen.new),
  const Shot('security', SecurityCenterScreen.new, act: _securityPasskeys),
  const Shot('notifications', NotificationScreen.new),
  Shot('cabinet_guide', _cabinetGuide, prefs: _departurePrefs),
  Shot('cabinet_guide_more', _cabinetGuide, prefs: _departurePrefs, act: _cabinetGuideMore),
  Shot('admin_cabinet_edit', AdminCabinetEditScreen.new, act: _adminCabinetLocate),
  const Shot('ai_support', AiSupportScreen.new),
  Shot('dispute_ai', _disputes, act: _disputeAi),
  Shot('listing_review', _listingReview, act: _listingReviewDetails),
  Shot('ai_consent', AiBookChatScreen.new, act: _aiConsent),
];

Map<String, Object> _departurePrefs() => {'transit.departure_station': departureStation};

Widget _cabinetGuide() {
  final b = _book(statsBookId);
  return CabinetGuideScreen(cabinetId: b.cabinetId!, name: b.cabinetName, address: b.cabinetAddress, openHours: b.cabinetOpenHours);
}

Future<void> _cabinetGuideMore(WidgetTester tester, Snap snap) async {
  final youbike = find.text(S.transitYoubike);
  while (youbike.evaluate().isEmpty) {
    await _scrollBy(tester, 300);
  }
  await Scrollable.ensureVisible(tester.element(youbike), alignment: 0);
  await _scrollBy(tester, -34);
  await snap('cabinet_guide_more');
}

Future<void> _adminCabinetLocate(WidgetTester tester, Snap snap) async {
  final fields = find.descendant(of: find.byType(AdminCabinetEditScreen), matching: find.byType(TextField));
  for (final (i, text) in [(0, '綜合教學館'), (1, '臺北市大安區學府路 102 號 綜合教學館一樓'), (4, '4'), (5, '08:00'), (6, '22:00')]) {
    await tester.enterText(fields.at(i), text);
  }
  FocusManager.instance.primaryFocus?.unfocus();
  await _settle(tester, const Duration(milliseconds: 600));
  tester.state<ScrollableState>(find.byType(Scrollable).first).position.jumpTo(0);
  await _settle(tester, const Duration(milliseconds: 600));
  await tester.tap(find.text(S.useCurrentLocation));
  await _settle(tester, const Duration(seconds: 5));
  await snap('admin_cabinet_edit');
}

Widget _disputes() {
  final book = bookOf(disputeBookId);
  const body = [
    (
      '第 3 章　堆疊與佇列',
      '堆疊是一種後進先出（LIFO）的資料結構，只允許在同一端進行插入與刪除。常見的操作包括 push、pop 與 peek，三者的時間複雜度皆為 O(1)。'
          '以陣列實作時須預先配置容量，元素數量超過容量時需要擴充；以鏈結串列實作則可動態增減節點。佇列則是先進先出（FIFO）的結構，常用於排程與廣度優先搜尋。',
      63,
    ),
    (
      '第 5 章　二元搜尋樹',
      '二元搜尋樹中，每個節點左子樹的鍵值皆小於該節點，右子樹的鍵值皆大於該節點。搜尋、插入與刪除的平均時間複雜度為 O(log n)，'
          '但資料依序插入時可能退化為鏈結串列，最差情況為 O(n)。為避免退化，可改用 AVL 樹或紅黑樹等自平衡結構，透過旋轉維持樹高。',
      91,
    ),
  ];
  for (final (i, (heading, text, page)) in body.indexed) {
    seedPhoto(
      disputeEvidence[i],
      () => paintInsidePage(book, heading: heading, body: text, seed: page, marked: true),
      cacheWidths: [for (final size in [52, 88]) (size * _pixelRatio).round()],
    );
  }
  return const AdminDisputeScreen();
}

Future<void> _disputeAi(WidgetTester tester, Snap snap) async {
  await tester.tap(find.text(S.handle).first);
  await _settle(tester, const Duration(seconds: 3));
  // 底部單高度超過畫面時會延伸到狀態列下方；讓佐證照片停在最上方，狀態列只疊在照片上。
  final evidence = find.ancestor(of: find.byType(DisputeAiPanel), matching: find.byType(Column)).first;
  await Scrollable.ensureVisible(tester.element(find.descendant(of: evidence, matching: find.byType(AdminImageStrip))), alignment: 0);
  await _settle(tester, const Duration(seconds: 1));
  await snap('dispute_ai');
}

Widget _listingReview() {
  final book = bookOf(reviewBookId);
  seedPhoto(reviewPhotos[0], () => paintLibraryBack(book, reviewSynopsis));
  seedPhoto(
    reviewPhotos[1],
    () => paintInsidePage(
      book,
      heading: '第 7 章　親核取代反應',
      body: 'SN2 反應為一步完成的協同反應，親核基由離去基的背面進攻，產物的立體組態因而反轉。反應速率同時取決於受質與親核基的濃度，'
          '一級鹵烷的反應最快，三級鹵烷則因立體障礙幾乎不發生。極性非質子溶劑能提高親核基的反應性。',
      seed: 17,
    ),
  );
  return const AdminReportScreen(initialTab: AdminReportScreen.listingReviewTab);
}

Future<void> _listingReviewDetails(WidgetTester tester, Snap snap) async {
  await tester.tap(find.text(S.showPhotosFullDetails).first);
  await _settle(tester, const Duration(seconds: 1));
  await snap('listing_review');
}

Future<void> _aiConsent(WidgetTester tester, Snap snap) async {
  final previous = AiStatus.value;
  // ignore: invalid_use_of_visible_for_testing_member
  AiStatus.debugSet(
    const AiStatusInfo(
      support: true,
      listingAssist: true,
      recommend: true,
      bookChat: true,
      webSearch: true,
      providersInUse: ['OpenAI'],
      embeddingProvider: 'OpenAI',
    ),
  );
  await tester.tap(find.text(S.mysteryNovelMyCommute));
  await _settle(tester, const Duration(seconds: 2));
  await snap('ai_consent');
  // ignore: invalid_use_of_visible_for_testing_member
  AiStatus.debugSet(previous);
  AiStatus.invalidate();
}

Shot _matchShot(String name, String digits) => Shot(
  name,
  () => CabinetFlowScreen(resume: _session('matching', remainingMs: 52000)),
  act: (t, snap) async {
    if (digits.isNotEmpty) {
      await t.enterText(find.descendant(of: find.byType(CabinetFlowScreen), matching: find.byType(TextField)), digits);
    }
    await _settle(t, const Duration(milliseconds: 800));
    await snap(name);
    final field = t.getRect(find.byType(CabinetMatchCodeField));
    _reportRect('$name digit 1', Rect.fromLTWH(field.left, field.top, 56, field.height));
    _reportRect('$name digit 2', Rect.fromLTWH(field.right - 56, field.top, 56, field.height));
  },
);

Widget _chatRoom() => ChatRoomScreen(roomId: 1, partnerName: users[3]!);

List<AiBookChatItem> _aiChatItems() => [
  AiBookChatItem(id: 'u1', isUser: true, content: '我是大一新生，想找統計學的入門教材，預算 300 代幣以內。', animate: false),
  AiBookChatItem(
    id: 'a1',
    isUser: false,
    content: '以下是目前上架、符合預算的統計學入門教材：\n\n- 《統計學概論》以生活實例說明觀念，並已存放於書櫃，可立即取書\n- 搭配《線性代數》可為後續的迴歸分析打好基礎',
    books: [
      AiBookSuggestion(book: _book(1), reason: '入門必讀，章節附練習題'),
      AiBookSuggestion(book: _book(10), reason: '矩陣運算為迴歸分析的基礎'),
      AiBookSuggestion(book: _book(2), reason: '機率推導常用的數學工具'),
    ],
    suggestions: const ['有沒有附習題解答的版本？', '只看已在書櫃的書', '推薦經濟系適用的教材'],
    animate: false,
    messageNo: 'AC7Q2M4XK',
  ),
];

Future<void> _sellFlow(WidgetTester tester, Snap snap) async {
  await tester.tap(find.byIcon(Icons.add_rounded));
  await _settle(tester, const Duration(seconds: 1));
  final sell = find.byType(SellBookScreen);
  await tester.enterText(find.descendant(of: sell, matching: find.byType(TextField)).first, bookOf(listingBookId).isbn);
  await _settle(tester, const Duration(milliseconds: 600));
  await tester.tap(find.descendant(of: sell, matching: find.byType(AiAssistButton)));
  await _settle(tester, const Duration(seconds: 5));
  await snap('sell_ai_sheet');

  await tester.tap(find.textContaining('套用').last);
  await _settle(tester, const Duration(milliseconds: 1000));
  await snap('sell_ai');

  final prefs = await SharedPreferences.getInstance();
  final draft = jsonDecode(prefs.getString(_draftKey) ?? '{}') as Map<String, dynamic>;
  draft['step2'] = _draftStep2(condition: 'good', touched: false);
  await prefs.setString(_draftKey, jsonEncode(draft));
  await _settle(tester, const Duration(seconds: 1));
  final next = find.descendant(of: sell, matching: find.text(S.next));
  await tester.ensureVisible(next);
  await _settle(tester, const Duration(milliseconds: 600));
  await tester.tap(next);
  await _settleReal(tester, const Duration(seconds: 3));
  await snap('sell_ai_detail');
}

const _draftKey = 'sell_draft_v1';
List<String> _listingPhotos = const [];

Map<String, Object> _draftStep2({required String condition, required bool touched}) => {
  'price': '',
  'condition': condition,
  'condition_touched': touched,
  'slots': _listingPhotos,
  'extra': <String>[],
};

Map<String, Object> _draftPrefs({required String condition}) => {
  _draftKey: jsonEncode({'step2': _draftStep2(condition: condition, touched: true), 'saved_at': DateTime.now().toIso8601String()}),
};

Widget _sellDetail() {
  final b = bookOf(listingBookId);
  return SellBookDetailScreen(
    isbn: b.isbn,
    title: b.title,
    author: b.author,
    publisher: b.publisher,
    publishDate: '${b.publishDate}-01',
    description: b.description,
    categoryId: b.categoryId,
  );
}

Future<void> _sellPrice(WidgetTester tester, Snap snap) async {
  await _settleReal(tester, const Duration(seconds: 1));
  await tester.tap(find.descendant(of: find.byType(SellBookDetailScreen), matching: find.byType(AiAssistButton)));
  await _settleReal(tester, const Duration(seconds: 6));
  await snap('sell_price');
  final sheet = find.byType(AiListingResultSheet);
  Rect tile(String text) => tester.getRect(
    find
        .ancestor(
          of: find.descendant(of: sheet, matching: find.text(text)),
          matching: find.byType(AnimatedContainer),
        )
        .first,
  );
  const margin = EdgeInsets.only(bottom: 8);
  final condition = margin.deflateRect(tile(S.conditionGood));
  final price = margin.deflateRect(tile('\$280'));
  _reportRect('sell_price sheet', tester.getRect(sheet));
  _reportRect('sell_price condition card', condition);
  _reportRect('sell_price price card', price);
  _reportRect('sell_price condition+price', condition.expandToInclude(price));
}

void _reportRect(String label, Rect r) => debugPrint(
  'RECT $label: x=${r.left.toStringAsFixed(1)} y=${r.top.toStringAsFixed(1)} w=${r.width.toStringAsFixed(1)} h=${r.height.toStringAsFixed(1)}',
);

Future<void> _settleReal(WidgetTester tester, Duration duration) async {
  final steps = duration.inMilliseconds ~/ 100;
  for (var i = 0; i < steps; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<List<String>> _createListingPhotos(Directory dir) async {
  final paths = <String>[];
  for (final kind in ['cover', 'back', 'barcode']) {
    final image = paintPhoto(bookOf(listingBookId), kind);
    final file = File('${dir.path}/$kind.png')..writeAsBytesSync(await pngBytes(image));
    image.dispose();
    paths.add(file.path);
  }
  return paths;
}

Future<void> _payVerify(WidgetTester tester, Snap snap) async {
  VerificationService.navigatorKey = _navigatorKey;
  VerificationService.paymentSummary = PaymentSummary(amount: 280, detail: S.booksTotal(1, '280') + S.balanceAfterPaymentCoins('920'));
  unawaited(VerificationService.handle(const VerificationRequest(scope: 'payment', methods: ['pin'], message: '')));
  await _settle(tester, const Duration(seconds: 2));
  for (final digit in ['3', '8']) {
    await tester.tap(find.descendant(of: find.byType(NumberPad), matching: find.text(digit)));
    await _settle(tester, const Duration(milliseconds: 400));
  }
  await _settle(tester, const Duration(seconds: 1));
  await snap('pay_verify');
  VerificationService.paymentSummary = null;
}

Future<void> _cameraView(WidgetTester tester, Snap snap) async {
  final scanner = tester.getRect(find.byType(CabinetScannerView));
  final frame = tester.getRect(find.byWidgetPredicate((w) => w is CustomPaint && w.painter is ScanFramePainter));
  final paste = find.byType(CabinetPasteButton);
  final camera = paintCameraScene(scanner.size, frame.center - scanner.topLeft, frame.width);
  _overlay.value = ScreenOverlay(
    blackouts: [if (paste.evaluate().isNotEmpty) tester.getRect(paste).inflate(6)],
    camera: camera,
    cameraRect: scanner,
  );
  await tester.pump();
  await snap('cabinet_scan');
}

Future<void> _securityPasskeys(WidgetTester tester, Snap snap) async {
  await _settleReal(tester, const Duration(seconds: 1));
  await Scrollable.ensureVisible(tester.element(find.byType(PasskeysCard)), alignment: 1);
  await _scrollBy(tester, 48);
  await snap('security');
}

Future<void> _scrollBy(WidgetTester tester, double pixels) async {
  final state = tester.state<ScrollableState>(find.byType(Scrollable).first);
  state.position.jumpTo(state.position.pixels + pixels);
  await _settle(tester, const Duration(seconds: 2));
}

Future<void> _settle(WidgetTester tester, Duration duration) async {
  final steps = duration.inMilliseconds ~/ 100;
  for (var i = 0; i < steps; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _waitForImages(WidgetTester tester, List<String> missing) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
  await _settle(tester, const Duration(milliseconds: 300));
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate().toList()) {
      final provider = (element.widget as Image).image;
      await precacheImage(provider, element, onError: (_, _) => missing.add('$provider'));
    }
  });
  await tester.pump();
}

// flutter test 固定使用測試字型，未指定字型家族的文字（例如 AnimatedDefaultTextStyle 取代整個樣式）會畫成方框；
// 截圖前改以 App 字型重新排版，對應實機以系統字型顯示的結果。
void _applyAppFontToUnstyledText(WidgetTester tester) {
  void visit(RenderObject node) {
    if (node is RenderParagraph) {
      final span = node.text;
      if (span is TextSpan && span.style?.fontFamily == null) {
        node.text = TextSpan(
          text: span.text,
          children: span.children,
          style: (span.style ?? const TextStyle()).copyWith(fontFamily: 'NotoSansTC'),
          recognizer: span.recognizer,
          semanticsLabel: span.semanticsLabel,
          locale: span.locale,
          spellOut: span.spellOut,
        );
      }
    }
    node.visitChildren(visit);
  }

  for (final view in tester.binding.renderViews) {
    visit(view);
  }
  tester.binding.rootPipelineOwner
    ..flushLayout()
    ..flushCompositingBits()
    ..flushPaint();
}

Future<void> _capture(WidgetTester tester, String name) async {
  _applyAppFontToUnstyledText(tester);
  final view = tester.binding.renderViews.first;
  await tester.runAsync(() async {
    final layer = view.debugLayer! as OffsetLayer;
    final image = await layer.toImage(view.paintBounds);
    final bytes = await pngBytes(image);
    image.dispose();
    _outDir.createSync(recursive: true);
    File('${_outDir.path}/$name.png').writeAsBytesSync(bytes);
  });
}

class ScreenOverlay {
  final List<Rect> blackouts;
  final ui.Image? camera;
  final Rect? cameraRect;

  const ScreenOverlay({this.blackouts = const [], this.camera, this.cameraRect});
}

class _OverlayPainter extends CustomPainter {
  final ScreenOverlay overlay;

  const _OverlayPainter(this.overlay);

  @override
  void paint(Canvas canvas, Size size) {
    for (final rect in overlay.blackouts) {
      canvas.drawRect(rect, Paint()..color = const Color(0xFF000000));
    }
    final camera = overlay.camera;
    final rect = overlay.cameraRect;
    if (camera == null || rect == null) return;
    canvas.drawImageRect(
      camera,
      Rect.fromLTWH(0, 0, camera.width.toDouble(), camera.height.toDouble()),
      rect,
      Paint()
        ..blendMode = BlendMode.screen
        ..filterQuality = FilterQuality.high,
    );
  }

  @override
  bool shouldRepaint(_OverlayPainter oldDelegate) => oldDelegate.overlay != overlay;
}

class DemoApp extends StatelessWidget {
  final Widget home;

  const DemoApp({super.key, required this.home});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      locale: const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant', countryCode: 'TW'),
      supportedLocales: LocaleProvider.supported,
      theme: AppTheme.build(Brightness.light),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        S = AppLocalizations.of(context);
        return Stack(
          children: [
            child ?? const SizedBox.shrink(),
            Positioned.fill(
              child: IgnorePointer(
                child: ValueListenableBuilder<ScreenOverlay>(
                  valueListenable: _overlay,
                  builder: (context, overlay, _) => CustomPaint(painter: _OverlayPainter(overlay)),
                ),
              ),
            ),
          ],
        );
      },
      home: home,
    );
  }
}

Future<void> _shoot(WidgetTester tester, Shot shot) async {
  final errors = <String>[];
  final missingImages = <String>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (details) => errors.add(details.exceptionAsString().split('\n').first);

  tester.view
    ..physicalSize = _logicalSize * _pixelRatio
    ..devicePixelRatio = _pixelRatio
    ..padding = const FakeViewPadding(top: _topInset * _pixelRatio, bottom: _bottomInset * _pixelRatio)
    ..viewPadding = const FakeViewPadding(top: _topInset * _pixelRatio, bottom: _bottomInset * _pixelRatio);
  addTearDown(tester.view.reset);

  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({'biometric_login_enabled': true, ...?shot.prefs?.call()});
  await RecentlyViewed.clear();
  await BiometricService.load();
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (call) async => switch ((call.arguments as Map?)?['key']) {
      'biometric_pay_owner' => '$meId',
      'biometric_pay_key' => 'demo-pay-key',
      _ => null,
    },
  );
  ApiService.authToken = 'demo-token';
  ApiService.currentUser = User.fromJson(user(meId));
  _overlay.value = const ScreenOverlay();
  seedCoverCache();

  Future<void> snap(String name) async {
    await _waitForImages(tester, missingImages);
    await _settle(tester, const Duration(milliseconds: 600));
    await _capture(tester, name);
  }

  await http.runWithClient(() async {
    await tester.pumpWidget(DemoApp(home: shot.home()));
    await _settle(tester, const Duration(seconds: 3));
    if (shot.act != null) {
      await shot.act!(tester, snap);
    } else {
      await snap(shot.name);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
  }, demoApi);

  _overlay.value = const ScreenOverlay();
  FlutterError.onError = previous;
  expect(missingImages, isEmpty, reason: '有圖片未載入');
  expect(errors, isEmpty, reason: '畫面有例外或版面溢出');
}

Future<void> _writeSheet() async {
  final files = [
    for (final shot in shots)
      for (final name in shot.files)
        if (File('${_outDir.path}/$name.png').existsSync()) File('${_outDir.path}/$name.png'),
  ];
  if (files.isEmpty) return;
  const columns = 6;
  const thumbWidth = 300.0;
  const thumbHeight = thumbWidth * 2556 / 1179;
  const gap = 24.0;
  const label = 36.0;
  final rows = (files.length / columns).ceil();
  final width = columns * thumbWidth + (columns + 1) * gap;
  final height = rows * (thumbHeight + label) + (rows + 1) * gap;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(Rect.fromLTWH(0, 0, width, height), Paint()..color = const Color(0xFFE9ECEF));
  for (final (i, file) in files.indexed) {
    final codec = await ui.instantiateImageCodec(file.readAsBytesSync());
    final image = (await codec.getNextFrame()).image;
    final x = gap + (i % columns) * (thumbWidth + gap);
    final y = gap + (i ~/ columns) * (thumbHeight + label + gap);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(x, y, thumbWidth, thumbHeight),
      Paint()..filterQuality = FilterQuality.medium,
    );
    final paragraph =
        (ui.ParagraphBuilder(ui.ParagraphStyle(fontFamily: 'NotoSansTC', fontSize: 20))
              ..pushStyle(ui.TextStyle(color: const Color(0xFF333333), fontFamily: 'NotoSansTC', fontSize: 20))
              ..addText(file.uri.pathSegments.last.replaceAll('.png', '')))
            .build()
          ..layout(const ui.ParagraphConstraints(width: thumbWidth));
    canvas.drawParagraph(paragraph, Offset(x, y + thumbHeight + 6));
    image.dispose();
  }
  final sheet = await recorder.endRecording().toImage(width.ceil(), height.ceil());
  File('${_outDir.path}/_sheet.png').writeAsBytesSync(await pngBytes(sheet));
  sheet.dispose();
}

class _FakePasskeyClient implements PasskeyClient {
  @override
  Future<bool> isSupported() async => true;

  @override
  Future<Map<String, dynamic>> create(Map<String, dynamic> options) async => throw const PasskeyClientException.cancelled();

  @override
  Future<Map<String, dynamic>> get(Map<String, dynamic> options, {bool immediate = true}) async =>
      throw const PasskeyClientException.cancelled();

  @override
  Future<void> forget({required String rpId, required String credentialId}) async {}
}

class _FakeBiometrics extends LocalAuthPlatform {
  @override
  Future<bool> isDeviceSupported() async => true;

  @override
  Future<bool> deviceSupportsBiometrics() async => true;

  @override
  Future<List<BiometricType>> getEnrolledBiometrics() async => [BiometricType.face];
}

class _FakeGeolocator extends GeolocatorPlatform {
  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async => LocationPermission.whileInUse;

  @override
  Future<LocationPermission> requestPermission() async => LocationPermission.whileInUse;

  @override
  Future<LocationAccuracyStatus> getLocationAccuracy() async => LocationAccuracyStatus.precise;

  @override
  Future<Position?> getLastKnownPosition({bool forceLocationManager = false}) async => _position;

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) async => _position;

  static final _position = Position(
    latitude: 25.0167,
    longitude: 121.5402,
    timestamp: DateTime.now(),
    accuracy: 8,
    altitude: 12,
    altitudeAccuracy: 3,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

void main() {
  late Directory photoDir;

  setUpAll(() async {
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    await loadAppFonts();
    photoDir = Directory.systemTemp.createTempSync('web_shots_');
    _listingPhotos = await _createListingPhotos(photoDir);
    PasskeyService.client = _FakePasskeyClient();
    PasskeyService.resetCache();
    LocalAuthPlatform.instance = _FakeBiometrics();
    GeolocatorPlatform.instance = _FakeGeolocator();
    themeProvider = await ThemeProvider.init();
    localeProvider = await LocaleProvider.init();
  });

  tearDownAll(() => photoDir.deleteSync(recursive: true));

  for (final shot in shots) {
    testWidgets(shot.name, (tester) => _shoot(tester, shot), variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  }

  testWidgets('_sheet', (tester) async {
    await tester.runAsync(_writeSheet);
  });
}
