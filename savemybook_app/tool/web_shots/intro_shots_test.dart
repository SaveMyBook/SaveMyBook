// 介紹動畫用 App 畫面截圖：flutter test tool/web_shots/intro_shots_test.dart
// 輸出 1179×2556（長圖為 1179×3H）PNG 至 ../presentation/介紹動畫/v2/assets-src/screens，並附 rects.json（邏輯座標）。

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
import 'package:savemybook_app/features/chat/chat_list_screen.dart';
import 'package:savemybook_app/features/chat/chat_room_screen.dart';
import 'package:savemybook_app/features/chat/widgets/reservation_card.dart';
import 'package:savemybook_app/features/home/home_screen.dart';
import 'package:savemybook_app/features/orders/pickup_book_screen.dart';
import 'package:savemybook_app/features/orders/pickup_success_screen.dart';
import 'package:savemybook_app/features/orders/widgets/pickup_ready_card.dart';
import 'package:savemybook_app/features/orders/widgets/payment_success_dialog.dart';
import 'package:savemybook_app/features/selling/ai_listing_assist.dart';
import 'package:savemybook_app/features/selling/book_manage_screen.dart';
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
import 'intro_data.dart';
import 'intro_paint.dart';

const _width = 393.0;
const _height = 852.0;
const _pixelRatio = 3.0;
const _topInset = 59.0;
const _bottomInset = 34.0;

// SHOTS_OUT 改變輸出資料夾、SHOTS_THEME=dark 改用深色模式（系統手冊使用手冊章節用）；搭配 --name 只產生部分畫面
final _outDir = Directory(Platform.environment['SHOTS_OUT'] ?? '${Directory.current.path}/../presentation/介紹動畫/v2/assets-src/screens');
final _brightness = Platform.environment['SHOTS_THEME'] == 'dark' ? Brightness.dark : Brightness.light;
final _navigatorKey = GlobalKey<NavigatorState>();
final _overlay = ValueNotifier<ScreenOverlay>(const ScreenOverlay());
final _rects = <String, Map<String, Object>>{};
final _sequences = <String, List<String>>{};

typedef Snap = Future<void> Function(String name);
typedef Act = Future<void> Function(WidgetTester tester, Snap snap);
typedef Point = ({double lat, double lng});

const _nearTaipeiMain = (lat: 25.046778, lng: 121.517707);
const _atCabinet = (lat: cabinetLat, lng: cabinetLng);

class Shot {
  final String name;
  final Widget Function() home;
  final Act? act;
  final List<String> outputs;
  final Map<String, Object> Function()? prefs;
  final int user;
  final Point location;

  const Shot(
    this.name,
    this.home, {
    this.act,
    List<String>? outputs,
    this.prefs,
    this.user = buyerId,
    this.location = _nearTaipeiMain,
  }) : outputs = outputs ?? const [];

  List<String> get files => outputs.isEmpty ? [name] : outputs;
}

Book _book(int id) => Book.fromJson(bookOf(id).toJson());

CabinetSession _session(String kind, String status, {int? remainingMs, Map<String, dynamic>? result, bool done = false}) {
  currentCabinetSession = () => cabinetSessionJson(kind, status, remainingMs: remainingMs, result: result, done: done);
  return CabinetSession.fromJson(currentCabinetSession());
}

List<Shot> get shots => [
  Shot('s_sell_fill', HomeScreen.new, user: sellerId, act: _sellFill, outputs: const ['s_sell_isbn', 's_sell_fill', 's_sell_info']),
  Shot('s_sell_photos', _sellDetail, user: sellerId, prefs: _draftPrefs, act: _sellPhotos, outputs: const ['s_sell_photos', 's_sell_photos_inner']),
  Shot('s_sell_ready', _sellDetail, user: sellerId, prefs: () => _draftPrefs(price: '222', condition: 'fair'), act: _sellReady),
  Shot('s_sell_ai_sheet', _sellDetail, user: sellerId, prefs: _draftPrefs, act: (t, snap) => _sellAiSheet(t, snap, 222, 's_sell_ai_sheet')),
  Shot(
    's_sell_ai_sheet_220',
    _sellDetail,
    user: sellerId,
    prefs: _draftPrefs,
    act: (t, snap) => _sellAiSheet(t, snap, 220, 's_sell_ai_sheet_220'),
  ),
  Shot('s_listed', BookManageScreen.new, user: sellerId, act: _listed),
  Shot('b_home', HomeScreen.new, act: _home),
  Shot('b_advisor', () => AiBookChatScreen(initialItems: _advisorItems()), act: _advisor),
  Shot('b_book_detail', () => BookDetailScreen(book: _book(journeyId)), act: _bookDetail),
  for (final stage in [1, 2, 3, 4]) Shot('b_chat_$stage', _journeyChat(stage), act: (t, snap) => _chat(t, snap, stage)),
  Shot('b_chat_warn', () => ChatRoomScreen(roomId: warnRoomId, partnerName: users[strangerId]!), act: _chatWarn),
  for (final filled in [0, 1, 2, 3, 4, 5, 6])
    Shot('b_pay_$filled', () => BookDetailScreen(book: _book(journeyId)), act: (t, snap) => _pay(t, snap, filled)),
  Shot('b_pay_done', () => BookDetailScreen(book: _book(journeyId)), act: _payDone),
  Shot('s_cab_scan', () => const CabinetFlowScreen(scanInput: Stream.empty()), user: sellerId, location: _atCabinet, act: _cameraView),
  _matchShot('s_cab_match_empty', 'order_deposit', '', sellerId),
  _matchShot('s_cab_match', 'order_deposit', '25', sellerId),
  Shot(
    's_cab_open',
    () => CabinetFlowScreen(resume: _session('order_deposit', 'open', remainingMs: 29000)),
    user: sellerId,
    location: _atCabinet,
  ),
  Shot(
    's_cab_done',
    () => CabinetFlowScreen(
      resume: _session('order_deposit', 'completed', result: {'outcome': 'completed', 'code': 'COMPLETED', 'message': ''}, done: true),
    ),
    user: sellerId,
    location: _atCabinet,
  ),
  Shot('b_guide', _cabinetGuide, prefs: _departurePrefs, act: _guide),
  Shot('b_guide_long', _cabinetGuide, prefs: _departurePrefs, act: _guideLong),
  Shot('a_cabinet_edit', AdminCabinetEditScreen.new, location: _atCabinet, act: _adminCabinetLocate, outputs: const ['a_cabinet_pre', 'a_cabinet_edit']),
  Shot('b_pickup_scan', () => const PickupBookScreen(isActive: true, scanInput: Stream.empty()), location: _atCabinet, act: _pickupScan),
  _matchShot('b_cab_match_empty', 'pickup', '', buyerId),
  _matchShot('b_cab_match', 'pickup', '25', buyerId),
  Shot('b_pickup_open', () => CabinetFlowScreen(resume: _session('pickup', 'open', remainingMs: 25000)), location: _atCabinet),
  Shot('b_pickup_done', () => PickupSuccessScreen(order: Order.fromJson(journeyOrder('picked_up'))), location: _atCabinet),
  Shot('s_wallet', WalletScreen.new, user: sellerId, act: _wallet, outputs: const ['s_wallet', 's_wallet_detail']),
  Shot('b_chat_list', ChatListScreen.new, act: _chatList),
  Shot('b_support', AiSupportScreen.new, act: _support),
  Shot('a_dispute_ai', _disputes, act: _disputeAi),
  Shot('a_listing_review', _listingReview, act: _listingReviewDetails),
  Shot('b_ai_consent', AiBookChatScreen.new, act: _aiConsent),
  Shot('s_sell_isbn_type', HomeScreen.new, user: sellerId, act: _sellIsbnType),
  Shot('s_sell_ai_loading', _sellDetail, user: sellerId, prefs: _draftPrefs, act: _sellAiLoading),
  Shot('b_advisor_type', AiBookChatScreen.new, act: _advisorType),
  for (final turn in [1, 2])
    Shot(
      'b_support_q$turn',
      () {
        supportUpto = turn == 1 ? 0 : 2;
        return const AiSupportScreen();
      },
      act: (t, snap) => _supportAsk(t, snap, turn),
    ),
  for (final stage in [0, 1])
    Shot(
      'b_chat_warn_$stage',
      () {
        warnStage = stage;
        return ChatRoomScreen(roomId: warnRoomId, partnerName: users[strangerId]!);
      },
      act: (t, snap) => _chatWarnStage(t, snap, stage),
    ),
  _selectShot('s_cab_select', 'order_deposit', sellerId),
  _selectShot('b_cab_select', 'pickup', buyerId),
  Shot(
    'a_dispute_loading',
    () {
      disputeAnalyzed = false;
      return _disputes();
    },
    act: _disputeLoading,
  ),
];

const _sequenceOrder = ['isbn_type', 'sell_ai_loading', 'advisor_type', 'support_q1', 'support_q2', 'warn', 'cab_deposit', 'cab_pickup', 'dispute_ai'];

const _staticSequences = {
  'isbn_type': ['s_sell_isbn_t00', 's_sell_isbn_t03', 's_sell_isbn_t06', 's_sell_isbn_t09', 's_sell_isbn_t13', 's_sell_isbn_loading', 's_sell_fill'],
  'warn': ['b_chat_warn_0', 'b_chat_warn_1', 'b_chat_warn'],
  'dispute_ai': ['a_dispute_loading', 'a_dispute_ai'],
  'cab_deposit': ['s_cab_scan', 's_cab_select', 's_cab_match_empty', 's_cab_match', 's_cab_open', 's_cab_done'],
  'cab_pickup': ['b_pickup_scan', 'b_cab_select', 'b_cab_match_empty', 'b_cab_match', 'b_pickup_open', 'b_pickup_done'],
};

void _resetIntroState() {
  warnStage = 2;
  supportUpto = null;
  disputeAnalyzed = true;
  _spinnerFocus = null;
  _releaseApi();
}

Finder? _spinnerFocus;

final _spinnerPaint = find.byWidgetPredicate((w) => w is CustomPaint && w.painter.runtimeType.toString() == '_CircularProgressIndicatorPainter');

List<double> _sweeps(Finder finder) => [for (final e in finder.evaluate()) ((e.widget as CustomPaint).painter as dynamic).arcSweep as double];

// 不定進度圈每 1333ms 由一點長成大弧再縮回，截圖時機若落在週期起點只會畫出一個點。
Future<void> _alignSpinners(WidgetTester tester, Finder focus) async {
  bool ready(bool strict) {
    final main = _sweeps(find.descendant(of: focus, matching: _spinnerPaint));
    if (main.isEmpty || main.any((s) => s < 3.6)) return false;
    return !strict || _sweeps(_spinnerPaint).every((s) => s >= 1.5);
  }

  for (final strict in [true, false]) {
    for (var i = 0; i < 84; i++) {
      if (ready(strict)) return;
      await tester.pump(const Duration(milliseconds: 16));
    }
  }
  throw StateError('spinner phase not reached');
}

int _activeStep(WidgetTester tester) {
  final sheet = find.byType(AiAssistProgressSheet);
  final spinner = find.descendant(of: sheet, matching: find.byType(CircularProgressIndicator));
  if (spinner.evaluate().length != 1) return -1;
  final y = tester.getCenter(spinner).dy;
  for (final (i, step) in tester.widget<AiAssistProgressSheet>(sheet).steps.indexed) {
    if ((tester.getCenter(find.descendant(of: sheet, matching: find.text(step))).dy - y).abs() < 12) return i;
  }
  return -1;
}

Future<void> _untilStep(WidgetTester tester, int step) async {
  for (var i = 0; i < 80 && _activeStep(tester) != step; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  if (_activeStep(tester) != step) throw StateError('step $step not shown');
}

Completer<void>? _apiGate;
String? _apiHold;
int _apiHeld = 0;

void _holdApi(String key) {
  _apiGate = Completer<void>();
  _apiHold = key;
  _apiHeld = 0;
}

void _releaseApi() {
  final gate = _apiGate;
  if (gate != null && !gate.isCompleted) gate.complete();
  _apiGate = null;
  _apiHold = null;
}

Future<void> _untilHeld(WidgetTester tester) async {
  for (var i = 0; i < 100 && _apiHeld == 0; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
  }
  if (_apiHeld == 0) throw StateError('request not held: $_apiHold');
}

void _consentGiven() {
  // ignore: invalid_use_of_visible_for_testing_member
  AiStatus.debugSet(
    const AiStatusInfo(
      support: true,
      listingAssist: true,
      recommend: true,
      bookChat: true,
      webSearch: true,
      consented: true,
      providersInUse: ['OpenAI'],
      embeddingProvider: 'OpenAI',
    ),
  );
}

List<int> _typingSteps(int length) => [for (var n = 3; n < length; n += 3) n, length];

String _two(int n) => n.toString().padLeft(2, '0');

Future<void> _typeInto(WidgetTester tester, Finder field, String text) async {
  await tester.enterText(field, text);
  FocusManager.instance.primaryFocus?.unfocus();
  await _settle(tester, const Duration(milliseconds: 600));
}

Future<List<String>> _typeFrames(WidgetTester tester, Snap snap, Finder field, String text, String prefix) async {
  final runes = text.runes.toList();
  final names = <String>[];
  for (final n in _typingSteps(runes.length)) {
    await _typeInto(tester, field, String.fromCharCodes(runes.take(n)));
    final name = '${prefix}_t${_two(n)}';
    await snap(name);
    names.add(name);
  }
  return names;
}

Future<void> _sendAndWait(WidgetTester tester, Snap snap, String api, String name, String text) async {
  _holdApi(api);
  await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
  await _settle(tester, const Duration(milliseconds: 600));
  await _untilHeld(tester);
  _spinnerFocus = find.byType(MaterialApp);
  await snap(name);
  _spinnerFocus = null;
  _recordFinder(tester, name, 'user bubble', _ancestorOf(find.text(text), Container));
  _recordFinder(tester, name, 'typing bubble', find.byWidgetPredicate((w) => w.runtimeType.toString() == 'ChatTypingBubble'));
}

Rect _inputBar(WidgetTester tester, Finder field) {
  for (final element in find.ancestor(of: field, matching: find.byType(Container)).evaluate()) {
    final box = element.findRenderObject() as RenderBox;
    if (box.size.width >= _width - 0.5) return box.localToGlobal(Offset.zero) & box.size;
  }
  throw StateError('no input bar');
}

Future<void> _sellIsbnType(WidgetTester tester, Snap snap) async {
  _consentGiven();
  await tester.tap(find.byIcon(Icons.add_rounded));
  await _settle(tester, const Duration(seconds: 1));
  final sell = find.byType(SellBookScreen);
  final field = find.descendant(of: sell, matching: find.byType(TextField)).first;
  final button = find.descendant(of: sell, matching: find.byType(AiAssistButton));
  await _settle(tester, const Duration(milliseconds: 600));
  await snap('s_sell_isbn_t00');
  _recordFinder(tester, 's_sell_isbn_t00', 'isbn field', field);
  _recordFinder(tester, 's_sell_isbn_t00', 'button AI 帶入', button);
  final isbn = bookOf(journeyId).isbn;
  for (final n in [3, 6, 9, 13]) {
    await _typeInto(tester, field, isbn.substring(0, n));
    await snap('s_sell_isbn_t${_two(n)}');
  }
  _holdApi('POST /ai/listing-assist');
  await tester.tap(button);
  await tester.pump();
  await _untilHeld(tester);
  _spinnerFocus = find.byType(AiAssistProgressSheet);
  await snap('s_sell_isbn_loading');
  _spinnerFocus = null;
  if (_activeStep(tester) != 0) throw StateError('loading step moved on');
}

Future<void> _sellAiLoading(WidgetTester tester, Snap snap) async {
  _consentGiven();
  conditionPrice = 220;
  try {
    await _settleReal(tester, const Duration(seconds: 1));
    _holdApi('POST /ai/listing-assist');
    await tester.tap(find.descendant(of: find.byType(SellBookDetailScreen), matching: find.byType(AiAssistButton)));
    await tester.pump();
    final steps = tester.widget<AiAssistProgressSheet>(find.byType(AiAssistProgressSheet)).steps.length;
    final names = <String>[];
    _spinnerFocus = find.byType(AiAssistProgressSheet);
    for (var i = 0; i < steps; i++) {
      await _untilStep(tester, i);
      final name = 's_sell_ai_loading_${i + 1}';
      await snap(name);
      if (_activeStep(tester) != i) throw StateError('$name captured after the step changed');
      names.add(name);
    }
    _spinnerFocus = null;
    await _untilHeld(tester);
    _sequences['sell_ai_loading'] = [...names, 's_sell_ai_sheet_220'];
  } finally {
    conditionPrice = 222;
  }
}

Future<void> _advisorType(WidgetTester tester, Snap snap) async {
  _consentGiven();
  const name = 'b_advisor_empty';
  await snap(name);
  final input = find.descendant(of: find.byType(AiBookChatScreen), matching: find.byType(TextField));
  final bar = _inputBar(tester, input);
  final header = tester.getRect(find.byWidgetPredicate((w) => w.runtimeType.toString() == 'AppHeader'));
  _record(name, 'input bar', bar);
  _record(name, 'messages area', Rect.fromLTRB(0, header.bottom, _width, bar.top));
  final typed = await _typeFrames(tester, snap, input, _advisorRequest, 'b_advisor');
  await _sendAndWait(tester, snap, 'POST /ai/book-chat/messages', 'b_advisor_wait', _advisorRequest);
  _sequences['advisor_type'] = [name, ...typed, 'b_advisor_wait', 'b_advisor'];
}

Future<void> _supportAsk(WidgetTester tester, Snap snap, int turn) async {
  _consentGiven();
  final input = find.descendant(of: find.byType(AiSupportScreen), matching: find.byType(TextField));
  final start = turn == 1 ? 'b_support_empty' : 'b_support_a1';
  await snap(start);
  if (turn == 1) {
    _record(start, 'input bar', _inputBar(tester, input));
  } else {
    _recordBox(tester, start, 'ai reply 1 bubble', _textContaining('取書期限為存書後 7 天'));
  }
  final question = turn == 1 ? supportQuestion1 : supportQuestion2;
  final typed = await _typeFrames(tester, snap, input, question, 'b_support_q$turn');
  await _sendAndWait(tester, snap, 'POST /ai/support/messages', 'b_support_wait$turn', question);
  _sequences['support_q$turn'] = [start, ...typed, 'b_support_wait$turn', turn == 1 ? 'b_support_a1' : 'b_support'];
}

Future<void> _chatWarnStage(WidgetTester tester, Snap snap, int stage) async {
  final name = 'b_chat_warn_$stage';
  await snap(name);
  if (stage == 0) return;
  _recordFinder(tester, name, 'stranger message', _textContaining('guanyu.lin'));
  _recordFinder(tester, name, 'risk note under message', find.byWidgetPredicate((w) => w.runtimeType.toString() == 'ChatRiskNote'));
}

Shot _selectShot(String name, String kind, int user) => Shot(
  name,
  () => CabinetFlowScreen(resume: _session(kind, 'selecting', remainingMs: 56000)),
  user: user,
  location: _atCabinet,
  act: (t, snap) async {
    await _settle(t, const Duration(milliseconds: 800));
    await snap(name);
    final card = find.ancestor(of: find.text(bookOf(journeyId).title), matching: find.byWidgetPredicate((w) => w.runtimeType.toString() == 'AppCard'));
    _recordFinder(t, name, 'item card', card);
    _recordBox(t, name, 'confirm button', find.text(S.openDoor));
  },
);

Future<void> _disputeLoading(WidgetTester tester, Snap snap) async {
  await tester.tap(find.text(S.handle).first);
  await _settle(tester, const Duration(seconds: 3));
  final evidence = find.ancestor(of: find.byType(DisputeAiPanel), matching: find.byType(Column)).first;
  await Scrollable.ensureVisible(tester.element(find.descendant(of: evidence, matching: find.byType(AdminImageStrip))), alignment: 0);
  await _settle(tester, const Duration(seconds: 1));
  _holdApi('POST /admin/disputes/$disputeId/ai-analysis');
  await tester.tap(find.descendant(of: find.byType(DisputeAiPanel), matching: find.text(S.analyze)));
  await _settle(tester, const Duration(milliseconds: 600));
  await _untilHeld(tester);
  _spinnerFocus = find.byType(DisputeAiPanel);
  await snap('a_dispute_loading');
  _spinnerFocus = null;
  _recordFinder(tester, 'a_dispute_loading', 'ai panel', find.byType(DisputeAiPanel));
}

void _record(String shot, String label, Rect r) {
  final entry = _rects.putIfAbsent(shot, () => {});
  entry[label] = [for (final v in [r.left, r.top, r.width, r.height]) double.parse(v.toStringAsFixed(1))];
}

void _recordFinder(WidgetTester tester, String shot, String label, Finder finder) {
  try {
    if (finder.evaluate().isEmpty) throw StateError('empty');
    _record(shot, label, tester.getRect(finder.first));
  } catch (_) {
    debugPrint('RECT MISSING $shot $label');
  }
}

Finder _textContaining(String text) => find.textContaining(text);

void _recordBox(WidgetTester tester, String shot, String label, Finder child) {
  try {
    final inner = tester.getRect(child.first);
    final candidates = find.ancestor(
      of: child.first,
      matching: find.byWidgetPredicate((w) => w is Container || w is DecoratedBox || w is Material || w is Ink),
    );
    for (final element in candidates.evaluate()) {
      final w = element.widget;
      final decoration = switch (w) {
        Container() => w.decoration,
        DecoratedBox() => w.decoration,
        Ink() => w.decoration,
        _ => null,
      };
      final decorated = decoration is BoxDecoration && (decoration.color != null || decoration.border != null || decoration.gradient != null);
      final material = w is Material && w.type != MaterialType.transparency && (w.color?.a ?? 0) > 0;
      if (!decorated && !material) continue;
      final box = element.findRenderObject() as RenderBox;
      final r = box.localToGlobal(Offset.zero) & box.size;
      if (r.width < inner.width + 8 || r.height < inner.height + 8) continue;
      _record(shot, label, r);
      return;
    }
    throw StateError('no box');
  } catch (_) {
    debugPrint('RECT MISSING $shot $label');
  }
}

Finder _ancestorOf(Finder child, Type type) => find.ancestor(of: child, matching: find.byType(type)).first;

Map<String, Object> _departurePrefs() => {'transit.departure_station': '台北車站'};

Widget _cabinetGuide() =>
    const CabinetGuideScreen(cabinetId: cabinetId, name: cabinetName, address: cabinetAddress, openHours: '08:00~22:00');

Future<void> _guide(WidgetTester tester, Snap snap) async {
  await snap('b_guide');
}

Future<void> _guideLong(WidgetTester tester, Snap snap) async {
  tester.view.physicalSize = const Size(_width, 4000) * _pixelRatio;
  await _settle(tester, const Duration(seconds: 2));
  final footer = tester.getRect(find.textContaining('data.taipei').last);
  final finalHeight = (footer.bottom + _bottomInset + 40).ceilToDouble();
  tester.view.physicalSize = Size(_width, finalHeight) * _pixelRatio;
  await _settle(tester, const Duration(seconds: 2));
  _rects.putIfAbsent('b_guide_long', () => {})['logical_size'] = [_width, finalHeight];
  Rect card(String title) =>
      tester.getRect(find.ancestor(of: find.text(title), matching: find.byWidgetPredicate((w) => w.runtimeType.toString() == 'AppCard')).first);
  for (final (label, title) in [
    ('card 前往書櫃', cabinetName),
    ('card 捷運', S.transitMrt),
    ('card 公車', S.transitBus),
    ('card YouBike', S.transitYoubike),
    ('card 開車與計程車', S.drivingAndTaxi),
  ]) {
    try {
      _record('b_guide_long', label, card(title));
    } catch (_) {
      debugPrint('RECT MISSING b_guide_long $label');
    }
  }
  await snap('b_guide_long');
}

Future<void> _adminCabinetLocate(WidgetTester tester, Snap snap) async {
  final fields = find.descendant(of: find.byType(AdminCabinetEditScreen), matching: find.byType(TextField));
  for (final (i, text) in [(0, cabinetName), (1, cabinetAddress), (4, '4'), (5, '08:00'), (6, '22:00')]) {
    await tester.enterText(fields.at(i), text);
  }
  FocusManager.instance.primaryFocus?.unfocus();
  await _settle(tester, const Duration(milliseconds: 600));
  tester.state<ScrollableState>(find.byType(Scrollable).first).position.jumpTo(0);
  await _settle(tester, const Duration(milliseconds: 600));
  await snap('a_cabinet_pre');
  await tester.tap(find.text(S.useCurrentLocation));
  await _settle(tester, const Duration(seconds: 5));
  await snap('a_cabinet_edit');
  _recordFinder(tester, 'a_cabinet_edit', 'button 使用目前位置', _ancestorOf(find.text(S.useCurrentLocation), OutlinedButton));
  _recordFinder(tester, 'a_cabinet_edit', 'field 緯度', fields.at(2));
  _recordFinder(tester, 'a_cabinet_edit', 'field 經度', fields.at(3));
  _recordFinder(tester, 'a_cabinet_edit', 'accuracy hint', _textContaining('定位精確度'));
  _recordFinder(tester, 'a_cabinet_edit', 'nearby preview title', find.text(S.nearbyPreview));
}

Widget _disputes() {
  final book = bookOf(disputeBookId).paintable;
  const body = [
    (
      '堆疊與佇列',
      '堆疊是一種後進先出（LIFO）的資料結構，只允許在同一端進行插入與刪除。常見的操作包括 push、pop 與 peek，三者的時間複雜度皆為 O(1)。'
          '以陣列實作時須預先配置容量，元素數量超過容量時需要擴充；以鏈結串列實作則可動態增減節點。佇列則是先進先出（FIFO）的結構，常用於排程與廣度優先搜尋。',
      63,
    ),
    (
      '二元搜尋樹',
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
  final evidence = find.ancestor(of: find.byType(DisputeAiPanel), matching: find.byType(Column)).first;
  await Scrollable.ensureVisible(tester.element(find.descendant(of: evidence, matching: find.byType(AdminImageStrip))), alignment: 0);
  await _settle(tester, const Duration(seconds: 1));
  await snap('a_dispute_ai');
  _recordFinder(tester, 'a_dispute_ai', 'ai panel', find.byType(DisputeAiPanel));
  _recordBox(tester, 'a_dispute_ai', 'suggestion chip', _textContaining('可信度'));
  _recordFinder(tester, 'a_dispute_ai', 'summary', _textContaining('買家表示'));
  final findings = disputeAnalysis()['finding_details'] as List;
  for (final (i, f) in findings.indexed) {
    _recordFinder(tester, 'a_dispute_ai', 'finding ${i + 1}', find.text((f as Map)['content'] as String));
  }
  _recordFinder(tester, 'a_dispute_ai', 'rationale', _textContaining('佐證所見'));
}

Widget _listingReview() {
  final book = bookOf(reviewBookId).paintable;
  seedPhoto(reviewPhotos[0], () => paintLibraryBack(book, reviewSynopsis));
  seedPhoto(
    reviewPhotos[1],
    () => paintInsidePage(
      book,
      heading: '親核取代反應',
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
  await snap('a_listing_review');
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
  await snap('b_ai_consent');
  _recordFinder(tester, 'b_ai_consent', 'recipient section title', find.text(S.recipients));
  _recordFinder(tester, 'b_ai_consent', 'recipient OpenAI', find.text('OpenAI'));
  _recordFinder(tester, 'b_ai_consent', 'recipient note', _textContaining('語意向量'));
  // ignore: invalid_use_of_visible_for_testing_member
  AiStatus.debugSet(previous);
  AiStatus.invalidate();
}

Shot _matchShot(String name, String kind, String digits, int user) => Shot(
  name,
  () => CabinetFlowScreen(resume: _session(kind, 'matching', remainingMs: 52000)),
  user: user,
  location: _atCabinet,
  act: (t, snap) async {
    if (digits.isNotEmpty) {
      await t.enterText(find.descendant(of: find.byType(CabinetFlowScreen), matching: find.byType(TextField)), digits);
    }
    await _settle(t, const Duration(milliseconds: 800));
    await snap(name);
    final field = t.getRect(find.byType(CabinetMatchCodeField));
    _record(name, 'digit 1', Rect.fromLTWH(field.left, field.top, 56, field.height));
    _record(name, 'digit 2', Rect.fromLTWH(field.right - 56, field.top, 56, field.height));
  },
);

Widget Function() _journeyChat(int stage) => () {
  chatStage = stage;
  return ChatRoomScreen(roomId: journeyRoomId, partnerName: users[sellerId]!);
};

Future<void> _chat(WidgetTester tester, Snap snap, int stage) async {
  final name = 'b_chat_$stage';
  await snap(name);
  if (stage == 4) {
    final buy = find.text(S.buyNow);
    _recordFinder(tester, name, 'reservation card', find.ancestor(of: buy, matching: find.byType(ReservationCardView)));
    _recordBox(tester, name, 'button 立即購買', buy);
    _recordFinder(tester, name, 'held until', _textContaining('已保留至'));
  }
}

Future<void> _chatList(WidgetTester tester, Snap snap) async {
  await _settleReal(tester, const Duration(seconds: 1));
  await snap('b_chat_list');
  _recordFinder(
    tester,
    'b_chat_list',
    'AI 書籍顧問 entry',
    find.ancestor(of: find.text(S.aiBookAdvisor), matching: find.byWidgetPredicate((w) => w.runtimeType.toString() == 'AppCard')),
  );
}

Future<void> _chatWarn(WidgetTester tester, Snap snap) async {
  await snap('b_chat_warn');
  _recordFinder(tester, 'b_chat_warn', 'risk banner', find.byWidgetPredicate((w) => w.runtimeType.toString() == 'ChatRiskBanner'));
  _recordFinder(tester, 'b_chat_warn', 'risk note under message', find.byWidgetPredicate((w) => w.runtimeType.toString() == 'ChatRiskNote'));
  _recordFinder(tester, 'b_chat_warn', 'stranger message', _textContaining('guanyu.lin'));
}

const _advisorRequest = '我想找普通化學的入門書，要能解釋像 Fe3O4 這類化合物，預算 300 代幣以內。';

List<AiBookChatItem> _advisorItems() => [
  AiBookChatItem(id: 'u1', isUser: true, content: _advisorRequest, animate: false),
  AiBookChatItem(
    id: 'a1',
    isUser: false,
    content: '以下是目前上架、符合 300 代幣預算的普通化學入門書：\n\n'
        '- 《普通化學》涵蓋化學基本概念與氧化還原，可用來理解 Fe3O4 這類同時含有二價與三價鐵離子的化合物\n'
        '- 《觀念化學2》以生活實例說明化學鍵與分子，適合搭配閱讀',
    books: [
      AiBookSuggestion(book: _book(journeyId), reason: '涵蓋氧化還原的基礎概念'),
      AiBookSuggestion(book: _book(companionId), reason: '以生活實例說明化學鍵'),
    ],
    suggestions: const ['只看已在書櫃的書', '有沒有普通化學的實驗教材？', '推薦有機化學的入門書'],
    animate: false,
    messageNo: 'AC7Q2M4XK',
  ),
];

Future<void> _advisor(WidgetTester tester, Snap snap) async {
  await snap('b_advisor');
  _recordFinder(tester, 'b_advisor', 'user request bubble', _ancestorOf(_textContaining('Fe3O4 這類化合物'), Container));
  _recordBox(tester, 'b_advisor', 'ai answer bubble', _textContaining('以下是目前上架'));
  for (final title in ['普通化學', '觀念化學2：化學鍵．分子']) {
    final card = find.ancestor(of: find.text(title).last, matching: find.byWidgetPredicate((w) => w.runtimeType.toString().contains('Card')));
    _recordFinder(tester, 'b_advisor', 'card $title', card);
  }
}

Future<void> _home(WidgetTester tester, Snap snap) async {
  await _settleReal(tester, const Duration(seconds: 1));
  await snap('b_home');
  for (final id in [journeyId, companionId, 104, 105, strangerBookId, 103]) {
    final b = bookOf(id);
    final reason = find.text(recommendationReasons[id]!);
    if (reason.evaluate().isEmpty) continue;
    final card = find.ancestor(of: reason, matching: find.byWidgetPredicate((w) => w.runtimeType.toString() == 'PressableScale')).first;
    _recordFinder(tester, 'b_home', 'card ${b.title}', card);
  }
  _recordFinder(tester, 'b_home', 'group title 1', _textContaining('觀念化學1'));
}

Future<void> _bookDetail(WidgetTester tester, Snap snap) async {
  await _scrollBy(tester, 318);
  final seller = tester.getRect(find.text(users[sellerId]!));
  final barTop = tester.getRect(find.text(S.addCart)).top - 28;
  final delta = seller.bottom + 16 - barTop;
  if (delta > 0) await _scrollBy(tester, delta);
  _recordFinder(tester, 'b_book_detail', 'title', find.text('普通化學').first);
  _recordBox(tester, 'b_book_detail', 'condition badge', find.text(S.conditionFair));
  await snap('b_book_detail');
  _recordFinder(tester, 'b_book_detail', 'button 聊聊', find.ancestor(of: find.byIcon(Icons.chat_bubble_outline), matching: find.byType(OutlinedButton)));
  _recordFinder(tester, 'b_book_detail', 'price', find.text('\$222'));
  _recordFinder(tester, 'b_book_detail', 'seller', find.text(users[sellerId]!));
}

final _verifyGate = Completer<void>();
bool _holdVerify = false;

Future<void> _pay(WidgetTester tester, Snap snap, int filled) async {
  VerificationService.navigatorKey = _navigatorKey;
  VerificationService.paymentSummary = PaymentSummary(amount: 222, detail: S.booksTotal(1, '222') + S.balanceAfterPaymentCoins('1017'));
  _holdVerify = filled == 6;
  unawaited(VerificationService.handle(const VerificationRequest(scope: 'payment', methods: ['pin'], message: '')));
  await _settle(tester, const Duration(seconds: 2));
  for (final digit in ['0', '2', '2', '2', '2', '5'].take(filled)) {
    await tester.tap(find.descendant(of: find.byType(NumberPad), matching: find.text(digit)));
    await _settle(tester, const Duration(milliseconds: 400));
  }
  await _settle(tester, const Duration(seconds: 1));
  final name = 'b_pay_$filled';
  final dots = find.byType(PinDots);
  if (filled == 6) {
    final spinner = find.descendant(of: find.byType(PinEntryPanel), matching: find.byType(CircularProgressIndicator));
    if (spinner.evaluate().isNotEmpty) {
      final sheet = find.ancestor(of: find.byType(PinEntryPanel), matching: find.byType(Material)).first;
      final color = tester.widget<Material>(sheet).color ?? Colors.white;
      _overlay.value = ScreenOverlay(covers: [(tester.getRect(spinner).inflate(4), color)]);
      await tester.pump();
    }
  }
  await snap(name);
  _overlay.value = const ScreenOverlay();
  _record(name, 'dots row', tester.getRect(dots));
  _recordFinder(tester, name, 'sheet', find.ancestor(of: find.byType(PinEntryPanel), matching: find.byType(Material)).first);
  for (var d = 0; d <= 9; d++) {
    final key = find.descendant(of: find.byType(NumberPad), matching: find.text('$d'));
    final r = tester.getRect(key);
    _rects.putIfAbsent(name, () => {})['key $d center'] = [
      double.parse(r.center.dx.toStringAsFixed(1)),
      double.parse(r.center.dy.toStringAsFixed(1)),
    ];
  }
  VerificationService.paymentSummary = null;
  if (filled < 6) {
    _navigatorKey.currentState?.pop();
    await _settle(tester, const Duration(seconds: 1));
  }
}

Future<void> _payDone(WidgetTester tester, Snap snap) async {
  final context = _navigatorKey.currentContext!;
  unawaited(showPaymentSuccess(context, total: 222));
  await _settle(tester, const Duration(seconds: 3));
  await snap('b_pay_done');
  _recordFinder(tester, 'b_pay_done', 'success dialog', _ancestorOf(find.text(S.paymentSuccessful), Material));
}

Future<void> _sellFill(WidgetTester tester, Snap snap) async {
  await tester.tap(find.byIcon(Icons.add_rounded));
  await _settle(tester, const Duration(seconds: 1));
  final sell = find.byType(SellBookScreen);
  await tester.enterText(find.descendant(of: sell, matching: find.byType(TextField)).first, bookOf(journeyId).isbn);
  FocusManager.instance.primaryFocus?.unfocus();
  await _settle(tester, const Duration(milliseconds: 600));
  await snap('s_sell_isbn');
  _recordFinder(tester, 's_sell_isbn', 'button AI 帶入', find.descendant(of: sell, matching: find.byType(AiAssistButton)));
  await tester.tap(find.descendant(of: sell, matching: find.byType(AiAssistButton)));
  await _settle(tester, const Duration(seconds: 5));
  await snap('s_sell_fill');
  final sheet = find.byType(AiListingResultSheet);
  _recordFinder(tester, 's_sell_fill', 'sheet', sheet);
  _recordFinder(
    tester,
    's_sell_fill',
    'field 簡介',
    find.ancestor(of: find.descendant(of: sheet, matching: find.text(S.summary)), matching: find.byType(AnimatedContainer)),
  );
  _recordFinder(tester, 's_sell_fill', 'button 套用', _applyButton(sheet));
  await tester.tap(_applyButton(sheet));
  await _settle(tester, const Duration(seconds: 3));
  await snap('s_sell_info');
  _recordBox(tester, 's_sell_info', 'field 簡介', find.text(S.description));
  _recordFinder(tester, 's_sell_info', 'button 下一步', _ancestorOf(find.text(S.next), ButtonStyleButton));
}

Future<void> _sellReady(WidgetTester tester, Snap snap) async {
  await _settleReal(tester, const Duration(seconds: 1));
  await snap('s_sell_ready');
  _recordBox(tester, 's_sell_ready', 'field 書況', find.text(S.conditionFair));
  _recordBox(tester, 's_sell_ready', 'field 售價', find.text('222'));
  _recordBox(tester, 's_sell_ready', 'button 確認上架', find.text(S.confirmListing));
}

Finder _applyButton(Finder sheet) => find
    .ancestor(of: find.descendant(of: sheet, matching: find.textContaining('套用')), matching: find.byWidgetPredicate((w) => w is ButtonStyleButton))
    .first;

const _draftKey = 'sell_draft_v1';
List<String> _listingPhotos = const [];
List<String> _extraPhotos = const [];

Map<String, Object> _draftPrefs({String price = '', String condition = 'good'}) => {
  _draftKey: jsonEncode({
    'step2': {
      'price': price,
      'condition': condition,
      'condition_touched': price.isNotEmpty,
      'cabinet_id': cabinetId,
      'slots': _listingPhotos,
      'extra': _extraPhotos,
    },
    'saved_at': DateTime.now().toIso8601String(),
  }),
};

Widget _sellDetail() {
  final b = bookOf(journeyId);
  return SellBookDetailScreen(
    isbn: b.isbn,
    title: b.title,
    author: b.author,
    publisher: b.publisher,
    publishDate: '2015-07-12',
    description: b.description,
    categoryId: b.categoryId,
  );
}

Future<void> _sellPhotos(WidgetTester tester, Snap snap) async {
  await _settleReal(tester, const Duration(seconds: 1));
  await snap('s_sell_photos');
  _recordFinder(tester, 's_sell_photos', 'button AI 帶入', find.byType(AiAssistButton));
  _recordBox(tester, 's_sell_photos', 'button 確認上架', find.text(S.confirmListing));
  _recordBox(tester, 's_sell_photos', 'photos card', _textContaining('書籍照片'));
  final strip = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.right);
  final position = tester.state<ScrollableState>(strip.first).position;
  position.jumpTo(position.maxScrollExtent);
  await _settle(tester, const Duration(seconds: 1));
  await snap('s_sell_photos_inner');
}

Future<void> _sellAiSheet(WidgetTester tester, Snap snap, int price, String name) async {
  conditionPrice = price;
  await _settleReal(tester, const Duration(seconds: 1));
  await tester.tap(find.descendant(of: find.byType(SellBookDetailScreen), matching: find.byType(AiAssistButton)));
  await _settleReal(tester, const Duration(seconds: 6));
  await snap(name);
  conditionPrice = 222;
  final sheet = find.byType(AiListingResultSheet);
  Rect tile(String text) => tester.getRect(
    find.ancestor(of: find.descendant(of: sheet, matching: find.text(text)), matching: find.byType(AnimatedContainer)).first,
  );
  const margin = EdgeInsets.only(bottom: 8);
  _record(name, 'sheet', tester.getRect(sheet));
  _record(name, 'condition card', margin.deflateRect(tile(S.conditionFair)));
  _record(name, 'price card', margin.deflateRect(tile('\$$price')));
  _recordFinder(tester, name, 'button 套用', _applyButton(sheet));
}

Future<void> _listed(WidgetTester tester, Snap snap) async {
  await _settleReal(tester, const Duration(seconds: 1));
  await snap('s_listed');
  _recordFinder(tester, 's_listed', 'journey book title', find.text('普通化學'));
}

Future<void> _wallet(WidgetTester tester, Snap snap) async {
  await _settleReal(tester, const Duration(seconds: 1));
  await snap('s_wallet');
  final row = find.ancestor(of: find.text('售出《普通化學》'), matching: find.byWidgetPredicate((w) => w.runtimeType.toString() == 'AppCard'));
  _recordFinder(tester, 's_wallet', 'top transaction', row);
  _recordFinder(tester, 's_wallet', 'amount +222', find.descendant(of: row, matching: find.text('+\$222')));
  _recordFinder(tester, 's_wallet', 'balance', find.text('1,228'));
  await tester.tap(find.text('售出《普通化學》'));
  await _settle(tester, const Duration(seconds: 2));
  await snap('s_wallet_detail');
  _recordFinder(tester, 's_wallet_detail', 'order number', find.text(orderNo).last);
}

Future<void> _support(WidgetTester tester, Snap snap) async {
  await snap('b_support');
  _recordFinder(tester, 'b_support', 'ai reply 1', _textContaining('取書期限為存書後 7 天'));
  _recordFinder(tester, 'b_support', 'ai reply 2', _textContaining('無法變更取書書櫃'));
  _recordBox(tester, 'b_support', 'handoff card', _textContaining('此問題建議由客服人員'));
  _recordBox(tester, 'b_support', 'ai reply 1 bubble', _textContaining('取書期限為存書後 7 天'));
  _recordBox(tester, 'b_support', 'ai reply 2 bubble', _textContaining('無法變更取書書櫃'));
  _recordFinder(tester, 'b_support', 'handoff button', find.text(S.talkPerson).last);
}

Future<void> _cameraView(WidgetTester tester, Snap snap) async {
  final scanner = tester.getRect(find.byType(CabinetScannerView));
  final frame = tester.getRect(find.byWidgetPredicate((w) => w is CustomPaint && w.painter is ScanFramePainter));
  final paste = find.byType(CabinetPasteButton);
  final camera = paintCameraScene(scanner.size, frame.center - scanner.topLeft, frame.width, name: cabinetName);
  _overlay.value = ScreenOverlay(
    blackouts: [if (paste.evaluate().isNotEmpty) tester.getRect(paste).inflate(6)],
    camera: camera,
    cameraRect: scanner,
  );
  await tester.pump();
  await snap('s_cab_scan');
}

Future<void> _pickupScan(WidgetTester tester, Snap snap) async {
  await _settleReal(tester, const Duration(seconds: 1));
  final frameFinder = find.byWidgetPredicate((w) => w is CustomPaint && w.painter.runtimeType.toString() == '_CornerFramePainter');
  final frame = tester.getRect(frameFinder);
  final view = Offset.zero & const Size(_width, _height);
  final header = tester.getRect(find.text(S.collectBook));
  final top = header.bottom + 14;
  final area = Rect.fromLTRB(0, top, view.width, view.height);
  final paste = find.byType(CabinetPasteButton);
  final panel = find.byType(PickupReadyCard);
  final camera = paintCameraScene(area.size, frame.center - area.topLeft, frame.width, name: cabinetName, bookInA01: true);
  _overlay.value = ScreenOverlay(
    blackouts: [if (paste.evaluate().isNotEmpty) tester.getRect(paste).inflate(6)],
    camera: camera,
    cameraRect: area,
    cameraExclude: [if (panel.evaluate().isNotEmpty) RRect.fromRectAndRadius(tester.getRect(panel), const Radius.circular(18))],
  );
  await tester.pump();
  await snap('b_pickup_scan');
  if (panel.evaluate().isNotEmpty) _record('b_pickup_scan', 'ready card', tester.getRect(panel));
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

Future<void> _settleReal(WidgetTester tester, Duration duration) async {
  final steps = duration.inMilliseconds ~/ 100;
  for (var i = 0; i < steps; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
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

// flutter test 固定使用測試字型，未指定字型家族的文字會畫成方框；截圖前改以 App 字型重新排版。
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
  final List<(Rect, Color)> covers;
  final ui.Image? camera;
  final Rect? cameraRect;
  final List<RRect> cameraExclude;

  const ScreenOverlay({this.blackouts = const [], this.covers = const [], this.camera, this.cameraRect, this.cameraExclude = const []});
}

class _OverlayPainter extends CustomPainter {
  final ScreenOverlay overlay;

  const _OverlayPainter(this.overlay);

  @override
  void paint(Canvas canvas, Size size) {
    for (final rect in overlay.blackouts) {
      canvas.drawRect(rect, Paint()..color = const Color(0xFF000000));
    }
    for (final (rect, color) in overlay.covers) {
      canvas.drawRect(rect, Paint()..color = color);
    }
    final camera = overlay.camera;
    final rect = overlay.cameraRect;
    if (camera == null || rect == null) return;
    canvas.save();
    if (overlay.cameraExclude.isNotEmpty) {
      final path = Path()..addRect(rect);
      for (final r in overlay.cameraExclude) {
        path.addRRect(r);
      }
      path.fillType = PathFillType.evenOdd;
      canvas.clipPath(path);
    }
    canvas.drawImageRect(
      camera,
      Rect.fromLTWH(0, 0, camera.width.toDouble(), camera.height.toDouble()),
      rect,
      Paint()
        ..blendMode = BlendMode.screen
        ..filterQuality = FilterQuality.high,
    );
    canvas.restore();
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
      theme: AppTheme.build(_brightness),
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
    ..physicalSize = const Size(_width, _height) * _pixelRatio
    ..devicePixelRatio = _pixelRatio
    ..padding = const FakeViewPadding(top: _topInset * _pixelRatio, bottom: _bottomInset * _pixelRatio)
    ..viewPadding = const FakeViewPadding(top: _topInset * _pixelRatio, bottom: _bottomInset * _pixelRatio);
  addTearDown(tester.view.reset);

  _resetIntroState();
  me = shot.user;
  _FakeGeolocator.position = shot.location;
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({'biometric_login_enabled': true, ...?shot.prefs?.call()});
  await RecentlyViewed.clear();
  await BiometricService.load();
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (call) async => switch ((call.arguments as Map?)?['key']) {
      'biometric_pay_owner' => '${shot.user}',
      'biometric_pay_key' => 'demo-pay-key',
      _ => null,
    },
  );
  ApiService.authToken = 'demo-token';
  ApiService.currentUser = User.fromJson(user(shot.user));
  _overlay.value = const ScreenOverlay();
  seedIntroCovers();

  Future<void> snap(String name) async {
    await _waitForImages(tester, missingImages);
    await _settle(tester, const Duration(milliseconds: 600));
    final focus = _spinnerFocus;
    if (focus != null) await _alignSpinners(tester, focus);
    await _capture(tester, name);
  }

  await http.runWithClient(() async {
    await tester.pumpWidget(DemoApp(home: shot.home()));
    await _settle(tester, const Duration(seconds: 3));
    try {
      if (shot.act != null) {
        await shot.act!(tester, snap);
      } else {
        await snap(shot.name);
      }
    } catch (e, st) {
      errors.add('act: $e');
      debugPrint('ACT ERROR ${shot.name}: $e\n$st');
    }
    if (_holdVerify && !_verifyGate.isCompleted) _verifyGate.complete();
    _holdVerify = false;
    await _settle(tester, const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox.shrink());
    if (_apiGate != null) {
      _releaseApi();
      await _settleReal(tester, const Duration(seconds: 2));
    }
    await tester.pump(const Duration(seconds: 5));
  }, _api);

  _overlay.value = const ScreenOverlay();
  FlutterError.onError = previous;
  for (final e in errors) {
    debugPrint('SHOT ERROR ${shot.name}: $e');
  }
  expect(missingImages, isEmpty, reason: '有圖片未載入');
  expect(errors, isEmpty, reason: '畫面有例外或版面溢出');
}

http.Client _api() {
  final inner = introApi();
  return MockClientGate(inner);
}

class MockClientGate extends http.BaseClient {
  final http.Client inner;

  MockClientGate(this.inner);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (_holdVerify && request.method == 'POST' && request.url.path.endsWith('/security/verify')) {
      await _verifyGate.future;
    }
    final gate = _apiGate;
    if (gate != null && '${request.method} ${request.url.path.replaceFirst('/api', '')}' == _apiHold) {
      final held = http.Request(request.method, request.url)
        ..headers.addAll(request.headers)
        ..bodyBytes = await request.finalize().toBytes();
      _apiHeld++;
      await gate.future;
      return inner.send(held);
    }
    return inner.send(request);
  }
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
  static Point position = _nearTaipeiMain;

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async => LocationPermission.whileInUse;

  @override
  Future<LocationPermission> requestPermission() async => LocationPermission.whileInUse;

  @override
  Future<LocationAccuracyStatus> getLocationAccuracy() async => LocationAccuracyStatus.precise;

  @override
  Future<Position?> getLastKnownPosition({bool forceLocationManager = false}) async => _current();

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) async => _current();

  static Position _current() => Position(
    latitude: position.lat,
    longitude: position.lng,
    timestamp: DateTime.now(),
    accuracy: 6,
    altitude: 12,
    altitudeAccuracy: 3,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

Future<List<String>> _createListingPhotos(Directory dir) async {
  final book = bookOf(journeyId).paintable;
  final paths = <String>[];
  for (final kind in ['cover', 'back', 'barcode']) {
    final image = paintPhoto(book, kind);
    final file = File('${dir.path}/$kind.png')..writeAsBytesSync(await pngBytes(image));
    image.dispose();
    paths.add(file.path);
  }
  return paths;
}

Future<List<String>> _createExtraPhotos(Directory dir) async {
  final image = paintChemistryPage();
  final file = File('${dir.path}/inside.png')..writeAsBytesSync(await pngBytes(image));
  image.dispose();
  return [file.path];
}

void main() {
  late Directory photoDir;

  setUpAll(() async {
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    await loadAppFonts();
    transitSnapshotPath = '${Directory.current.path}/../presentation/介紹動畫/v2/assets-src/transit_nearby.json';
    photoDir = Directory.systemTemp.createTempSync('intro_shots_');
    _listingPhotos = await _createListingPhotos(photoDir);
    _extraPhotos = await _createExtraPhotos(photoDir);
    PasskeyService.client = _FakePasskeyClient();
    PasskeyService.resetCache();
    LocalAuthPlatform.instance = _FakeBiometrics();
    GeolocatorPlatform.instance = _FakeGeolocator();
    themeProvider = await ThemeProvider.init();
    localeProvider = await LocaleProvider.init();
  });

  tearDownAll(() {
    photoDir.deleteSync(recursive: true);
    _outDir.createSync(recursive: true);
    final existing = File('${_outDir.path}/rects.json');
    final merged = <String, Object?>{};
    if (existing.existsSync()) {
      try {
        merged.addAll(jsonDecode(existing.readAsStringSync()) as Map<String, dynamic>);
      } catch (_) {}
    }
    merged.addAll(_rects);
    if (daytimeChanges.isNotEmpty) merged['_transit_daytime_changes'] = daytimeChanges;
    existing.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(merged));
    final sequences = File('${_outDir.path}/sequences.json');
    final allSequences = <String, Object?>{};
    if (sequences.existsSync()) {
      try {
        allSequences.addAll(jsonDecode(sequences.readAsStringSync()) as Map<String, dynamic>);
      } catch (_) {}
    }
    allSequences
      ..addAll(_staticSequences)
      ..addAll(_sequences);
    final ordered = {
      for (final key in _sequenceOrder)
        if (allSequences.containsKey(key)) key: allSequences[key],
      for (final entry in allSequences.entries)
        if (!_sequenceOrder.contains(entry.key)) entry.key: entry.value,
    };
    sequences.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(ordered));
  });

  for (final shot in shots) {
    testWidgets(shot.name, (tester) => _shoot(tester, shot), variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  }
}
