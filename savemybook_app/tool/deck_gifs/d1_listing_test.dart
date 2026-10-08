// 複評簡報 GIF：雪喵上架《HTML & CSS：網站設計建置優化之道》（book_id 150）的兩個步驟。
//   ai_listing_isbn       第 1 步：逐字輸入 ISBN → AI 帶入 → 分析進度 → AI 建議書籍資料 → 套用。
//   ai_listing_condition  第 2 步：三張實拍照片 → AI 帶入 → 分析照片 → AI 建議書況與售價 → 套用 → 確認上架。
// 書目、照片取自正式站上這本書的真實資料；AI 回應比照第 12 章手冊的 AI 帶入內容，書況與售價改為與主線一致（近全新、$250）。

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:savemybook_app/features/home/home_screen.dart';
import 'package:savemybook_app/features/selling/ai_listing_assist.dart';
import 'package:savemybook_app/features/selling/sell_book_detail_screen.dart';
import 'package:savemybook_app/features/selling/sell_book_screen.dart';
import 'package:savemybook_app/i18n/strings.dart';
import 'package:savemybook_app/models/ai.dart';
import 'package:savemybook_app/models/user.dart';
import 'package:savemybook_app/services/ai_status.dart';

import '../manual_shots/manual_api.dart';
import '../manual_shots/manual_host.dart';
import 'd1_rec.dart';

final _ios = TargetPlatformVariant.only(TargetPlatform.iOS);

const _bookId = 150;
const _seller = 21;

final _book = bookJson(_bookId);
String get _isbn => _book['isbn'] as String;
String get _title => _book['title'] as String;
User get _snow => User.fromJson(userJson(_seller));

String _imageOf(String type) =>
    ((_book['book_images'] as List).cast<Map>()).firstWhere((i) => i['image_type'] == type)['image_url'] as String;

List<String> get _photoPaths => [for (final t in ['cover', 'back', 'other']) photoFile(_imageOf(t))!.path];

Map<String, dynamic> get _ntub => realCabinets.firstWhere((c) => c['cabinet_name'] == '國立臺北商業大學');

const _aiStatusJson = {
  'support': true,
  'listing_assist': true,
  'recommend': true,
  'book_chat': true,
  'web_search': true,
  'consented': true,
  'providers_in_use': ['OpenAI'],
  'embedding_provider': 'OpenAI',
};

final _sources = [
  {'title': 'HTML&CSS', 'url': 'https://www.gotop.com.tw/books/BookDetails.aspx?Types=v&bn=ACU061200', 'domain': 'gotop.com.tw'},
  {'title': _title, 'url': 'https://www.tenlong.com.tw/products/$_isbn', 'domain': 'tenlong.com.tw'},
];

/// 第 1 步：只有 ISBN、沒有照片，書目取自這本書在正式站的真實資料。
Map<String, dynamic> _bookAssist() => {
  'mode': 'full',
  'fields': {
    'title': _title,
    'author': _book['author'],
    'publisher': _book['publisher'],
    'publish_date': _book['publish_date'],
    'publish_date_precision': 'day',
    'isbn': _isbn,
    'description': _book['description'],
  },
  'description_source': 'mixed',
  'category': {'category_id': _book['category_id'], 'name': '專業資訊', 'confidence': 0.93},
  'sources': _sources,
  'warnings': ['未提供照片與書況說明，無法判定實際書況；請補拍封面、書背、書口及內頁。'],
  'provider': 'openai',
  'model': 'gpt-5-nano',
  'suggestion_token': 'AS7K2M9QX',
};

/// 第 2 步：依封面、封底、條碼頁三張實拍照片判斷書況與售價（照片中封面有少量刮痕、條碼頁標示 NT\$580）。
Map<String, dynamic> _conditionAssist() => {
  'mode': 'condition',
  'fields': <String, Object>{},
  'condition': {
    'level': 'good',
    'confidence': 0.84,
    'reasons': ['封面與封底有少量細微刮痕，整體平整', '書角與書背完整，無明顯摺痕或污損', '條碼頁清晰，無劃記或貼紙殘膠'],
  },
  'price': {
    'suggested': 250,
    'min': 200,
    'max': 300,
    'original_price': 580,
    'original_price_verified': true,
    'currency': 'TWD',
    'by_condition': {'like_new': 300, 'good': 250, 'fair': 200, 'poor': 120},
    'reasons': ['依定價 580 元與書況「近全新」約 4 成計算', '同書二手行情約 200 至 300 元'],
  },
  'sources': _sources,
  'warnings': <String>[],
  'provider': 'openai',
  'model': 'gpt-5-nano',
  'suggestion_token': 'AS3P8W2RT',
};

void _setAi() {
  // ignore: invalid_use_of_visible_for_testing_member
  AiStatus.debugSet(AiStatusInfo.fromJson(_aiStatusJson));
}

/// 人在國立臺北商業大學（模擬定位的位置），書櫃距離以此為起點。
void _cabinetRoutes() {
  final here = _ntub;
  double rad(Object? deg) => double.parse('$deg') * math.pi / 180;
  num distance(Map c) {
    final dLat = rad(c['latitude']) - rad(here['latitude']);
    final dLng = rad(c['longitude']) - rad(here['longitude']);
    final a = math.pow(math.sin(dLat / 2), 2) + math.cos(rad(here['latitude'])) * math.cos(rad(c['latitude'])) * math.pow(math.sin(dLng / 2), 2);
    return math.max(30, (6371000 * 2 * math.asin(math.sqrt(a))).round());
  }

  ManualApi.on('GET', '/cabinets', (_) => [for (final c in realCabinets) {...c, 'distance_m': distance(c)}]);
}

void _routes() {
  _cabinetRoutes();
  ManualApi.on('GET', '/auth/me', (_) => userJson(_seller));
  ManualApi.on('GET', '/ai/status', (_) => _aiStatusJson);
  ManualApi.on('POST', '/ai/listing-assist', (r) => r.body.contains('condition') ? _conditionAssist() : _bookAssist());
}

/// AI 上架輔助的請求先停在等待回應，呼叫 [release] 後才回應。
class _HeldAssist {
  final _gate = Completer<void>();

  http.Client client() => MockClient((request) async {
    if (request.url.path.endsWith('/ai/listing-assist')) await _gate.future;
    final copy = http.Request(request.method, request.url)
      ..headers.addAll(request.headers)
      ..bodyBytes = request.bodyBytes;
    return http.Response.fromStream(await ManualApi.client().send(copy));
  });

  void release() {
    if (!_gate.isCompleted) _gate.complete();
  }
}

final _failures = <String>[];

Future<void> Function(WidgetTester, Snap) _safe(Future<void> Function(WidgetTester) body) => (tester, _) async {
  try {
    await body(tester);
  } catch (e, st) {
    _failures.add('$e');
    debugPrint('ACT FAILED: $e\n$st');
  }
};

Future<void> _scrollTo(WidgetTester tester, Rec rec, ScrollPosition position, double target, {int ms = 520}) async {
  unawaited(position.animateTo(target, duration: Duration(milliseconds: ms), curve: Curves.easeInOutCubic));
  await rec.play(tester, ms + 80);
}

/// AI 分析中：進度面板的每一步約 2.4 秒，GIF 中以 [speed] 倍速呈現；最後一步出現後放行回應。
Future<void> _runProgress(WidgetTester tester, Rec rec, _HeldAssist held, {required int steps, double speed = 2}) async {
  final fake = 2400 * (steps - 1) + 500;
  await rec.play(tester, fake, speed: speed);
  held.release();
  for (var i = 0; i < 60 && find.byType(AiListingResultSheet).evaluate().isEmpty; i++) {
    await rec.play(tester, 40);
  }
}

void main() {
  setUpAll(setUpManual);
  setUp(_failures.clear);

  testWidgets('ai_listing_isbn', variant: _ios, (tester) async {
    final rec = Rec('ai_listing_isbn');
    await shoot(
      tester,
      folder: '_d1',
      me: _snow,
      routes: _routes,
      home: HomeScreen.new,
      act: _safe((tester) async {
        _setAi();
        EditableText.debugDeterministicCursor = true;
        addTearDown(() => EditableText.debugDeterministicCursor = false);
        await tester.tap(find.byIcon(Icons.add_rounded).last);
        await settleReal(tester, const Duration(seconds: 2));
        await waitForImages(tester);

        final sell = find.byType(SellBookScreen);
        final isbnField = find.descendant(of: sell, matching: find.byType(TextField)).first;

        await rec.hold(tester, 480);
        await rec.tap(tester, isbnField, at: tester.getCenter(isbnField) + const Offset(-40, 0));
        await rec.play(tester, 40);
        await slideKeyboard(tester, rec, keyboard: const IosNumberPad(), height: numberPadHeight, show: true);

        for (var i = 1; i <= _isbn.length; i++) {
          setKeyboard(tester, keyboard: IosNumberPad(pressed: _isbn[i - 1]), height: numberPadHeight, visible: 1);
          await tester.enterText(isbnField, _isbn.substring(0, i));
          await rec.play(tester, 40);
          setKeyboard(tester, keyboard: const IosNumberPad(), height: numberPadHeight, visible: 1);
          await rec.play(tester, 80);
        }
        await rec.play(tester, 200);

        final held = _HeldAssist();
        await http.runWithClient(() async {
          final ai = find.descendant(of: sell, matching: find.byType(AiAssistButton));
          await rec.tap(tester, ai);
          await slideKeyboard(tester, rec, keyboard: const IosNumberPad(), height: numberPadHeight, show: false);
          await _runProgress(tester, rec, held, steps: 3, speed: 2.6);
        }, held.client);
        await rec.play(tester, 480);
        await rec.hold(tester, 520);

        final sheet = find.byType(AiListingResultSheet);
        final list = tester.state<ScrollableState>(find.descendant(of: sheet, matching: find.byType(Scrollable)).first).position;
        await _scrollTo(tester, rec, list, list.maxScrollExtent);
        await rec.hold(tester, 680);

        await rec.tap(tester, find.descendant(of: sheet, matching: find.byType(ElevatedButton)));
        await rec.play(tester, 560);
        final form = tester.state<ScrollableState>(find.descendant(of: sell, matching: find.byType(Scrollable)).first).position;
        await _scrollTo(tester, rec, form, math.min(form.maxScrollExtent, 190.0), ms: 600);
        await rec.play(tester, 400);
        await rec.hold(tester, 900);
        await _scrollTo(tester, rec, form, 0, ms: 560);
        await rec.hold(tester, 160);
        rec.save();
      }),
    );
    expect(_failures, isEmpty);
  });

  testWidgets('ai_listing_condition', variant: _ios, (tester) async {
    final rec = Rec('ai_listing_condition');
    await shoot(
      tester,
      folder: '_d1',
      me: _snow,
      routes: _routes,
      prefs: {
        'sell_draft_v1': jsonEncode({
          'step2': {
            'price': '',
            'condition': 'like_new',
            'condition_touched': true,
            'cabinet_id': _ntub['cabinet_id'],
            'slots': _photoPaths,
            'extra': <String>[],
          },
          'saved_at': DateTime.now().toIso8601String(),
        }),
      },
      home: () => SellBookDetailScreen(
        isbn: _isbn,
        title: _title,
        author: _book['author'] as String,
        publisher: _book['publisher'] as String,
        publishDate: _book['publish_date'] as String,
        description: _book['description'] as String,
        categoryId: _book['category_id'] as int,
      ),
      act: _safe((tester) async {
        _setAi();
        await settleReal(tester, const Duration(seconds: 1));
        await waitForImages(tester);
        // 上架完成後回到首頁：先開一次首頁把書籍照片載入快取，錄製時才不會逐張冒出
        unawaited(navigatorKey.currentState!.push(MaterialPageRoute<void>(builder: (_) => const HomeScreen())));
        await settleReal(tester, const Duration(seconds: 2));
        await waitForImages(tester);
        await settleReal(tester, const Duration(seconds: 1));
        await waitForImages(tester);
        navigatorKey.currentState!.pop();
        await settleReal(tester, const Duration(seconds: 1));

        final detail = find.byType(SellBookDetailScreen);
        await rec.hold(tester, 600);

        final held = _HeldAssist();
        await http.runWithClient(() async {
          await rec.tap(tester, find.descendant(of: detail, matching: find.byType(AiAssistButton)));
          await rec.play(tester, 160);
          await _runProgress(tester, rec, held, steps: 3, speed: 2.6);
        }, held.client);
        await rec.play(tester, 480);
        await rec.hold(tester, 1400);

        final sheet = find.byType(AiListingResultSheet);
        await rec.tap(tester, find.descendant(of: sheet, matching: find.byType(ElevatedButton)));
        // 套用後欄位閃爍提示約 1.6 秒，之後只剩提示卡倒數，快轉到提示卡收起
        await rec.play(tester, 1600);
        await tester.pump(const Duration(milliseconds: 1100));
        await rec.play(tester, 400);

        await rec.tap(tester, find.descendant(of: detail, matching: find.text(S.listBook)));
        await rec.play(tester, 400);
        await rec.hold(tester, 1000);

        await rec.tap(tester, find.text(S.listBook).last);
        await rec.play(tester, 1400);
        await rec.hold(tester, 500);
        rec.save();
      }),
    );
    expect(_failures, isEmpty);
  });
}
