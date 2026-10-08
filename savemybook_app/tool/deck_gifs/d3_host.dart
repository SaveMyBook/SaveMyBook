// 複評簡報 GIF（子任務 D3：智慧書櫃手機端）的逐格拍攝流程：沿用第 12 章手冊截圖的 ManualApp、真實資料與模擬系統畫面，
// 操作後以固定間隔推進假時間並每格截圖（2 倍解析度 786×1704），輸出 frames.json 給 gif_kit.py 合成。

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:marquee/marquee.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:savemybook_app/models/user.dart';
import 'package:savemybook_app/services/api_service.dart';
import 'package:savemybook_app/services/biometric_service.dart';
import 'package:savemybook_app/services/recently_viewed.dart';

import '../manual_shots/manual_api.dart';
import '../manual_shots/manual_host.dart';
import '../manual_shots/s19_keyboards.dart' show S19NumberPad, numberPadHeight;

final d3Out = Platform.environment['D3_OUT'] ??
    '/private/tmp/claude-501/-Users-xukaijun-Desktop-SaveMyBook-savemybook-app/f52b6347-17b0-4b79-95e7-263531604b33/scratchpad/deck_gif/d3';

/// 輸出解析度：每 pt 2 px。
const outScale = 2.0;

typedef ApiDelay = Duration Function(ApiRequest request);

/// 疊加層依名稱管理（相機、鍵盤、通知橫幅、轉場），每次變動後重組 systemOverlay。
class Layers {
  static final Map<String, Widget> _items = {};

  static void set(String name, Widget? widget) {
    if (widget == null) {
      _items.remove(name);
    } else {
      _items[name] = widget;
    }
    const order = ['camera', 'keyboard', 'banner', 'fade'];
    systemOverlay.value = [
      for (final key in order) ?_items[key],
    ];
  }

  static void clear() {
    _items.clear();
    systemOverlay.value = const [];
  }
}

/// 錄製格率：GIF 用 25 fps，簡報影片用 60 fps（環境變數 D3_FPS=60，畫格輸出到 <名稱>_60fps）。
final int recFps = int.parse(Platform.environment['D3_FPS'] ?? '25');

class GifRec {
  GifRec(this.tester, String name) : name = recFps == 25 ? name : '${name}_${recFps}fps', dir = Directory('$d3Out/${recFps == 25 ? name : '${name}_${recFps}fps'}') {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);
  }

  final WidgetTester tester;
  final String name;
  final Directory dir;
  final frames = <Map<String, Object>>[];
  final taps = <Map<String, Object>>[];
  final marks = <(double, String)>[];

  /// 每格推進前執行（例如推送書櫃作業的倒數）。
  final List<void Function()> before = [];

  /// 每格推進後、截圖前執行（例如依版面更新相機畫面位置）；有任何一個時會再補一個不推進時間的畫格。
  final List<void Function()> after = [];

  int _index = 0;
  int _us = 0;

  // 腳本的時間軸（微秒）：各段停留時間累加於此，畫格追到最接近的一格，不同格率的總長與事件時間一致。
  int _scriptUs = 0;

  /// 目前時間軸位置（毫秒），即下一格的開始時間。
  double get t => _us / 1000;

  void mark(String label) => marks.add((t, label));

  final _watches = <(Finder, String)>[];

  /// [finder] 第一次出現在畫面上的那一格記為 [label]（畫面切換時的淡入由此格開始）。
  void watch(Finder finder, String label) => _watches.add((finder, label));

  int _frameEnd(int index) => (index * 1000000 / recFps).round();

  Future<void> _frame() async {
    final end = _frameEnd(_index + 1);
    final stepUs = end - _us;
    for (final hook in [...before]) {
      hook();
    }
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 4)));
    await tester.pump(Duration(microseconds: stepUs));
    await waitForImages(tester);
    if (after.isNotEmpty) {
      for (final hook in [...after]) {
        hook();
      }
      await tester.pump();
    }
    for (final w in [..._watches]) {
      if (w.$1.evaluate().isNotEmpty) {
        marks.add((t, w.$2));
        _watches.remove(w);
      }
    }
    await _capture(stepUs / 1000);
    _us = end;
    _index++;
  }

  /// 腳本時間前進 [ms] 毫秒，逐格截圖；[apply] 於每格推進前以 0～1 的進度呼叫（以該格結束時間計）。
  Future<void> animate(int ms, [FutureOr<void> Function(double k)? apply]) async {
    final start = _scriptUs;
    _scriptUs += ms * 1000;
    while (true) {
      final end = _frameEnd(_index + 1);
      // 追到最接近腳本時間的一格
      if (end - _scriptUs > (end - _us) / 2) break;
      await apply?.call(ms == 0 ? 1 : ((end - start) / (ms * 1000)).clamp(0.0, 1.0));
      await _frame();
    }
  }

  Future<void> play(int ms) => animate(ms);

  /// 按下並放開：按住 [hold] 毫秒期間逐格截圖，放開後由呼叫端繼續推進。
  Future<void> pressAt(Offset p, {int hold = 120}) async {
    taps.add({'ms': t, 'x': p.dx, 'y': p.dy});
    final gesture = await tester.startGesture(p);
    await play(hold);
    await gesture.up();
  }

  Future<void> press(Finder finder, {int hold = 120}) => pressAt(tester.getCenter(finder), hold: hold);

  /// 以動畫捲動到 [to]（捲動位置的絕對值）。
  Future<void> scrollTo(ScrollableState state, double to, int ms, {Curve curve = Curves.easeInOutCubic}) async {
    final target = to.clamp(state.position.minScrollExtent, state.position.maxScrollExtent);
    unawaited(state.position.animateTo(target, duration: Duration(milliseconds: ms), curve: curve));
    await play(ms + 40);
  }

  Future<void> _capture(double ms) async {
    final marquees = find.descendant(of: find.byType(Marquee), matching: find.byType(Scrollable)).evaluate().toList();
    for (final element in marquees) {
      if (element is StatefulElement && element.state is ScrollableState) (element.state as ScrollableState).position.jumpTo(0);
    }
    if (marquees.isNotEmpty) await tester.pump();
    _applyAppFontToUnstyledText(tester);
    final file = '${frames.length.toString().padLeft(5, '0')}.png';
    final view = tester.binding.renderViews.first;
    await tester.runAsync(() async {
      final layer = view.debugLayer! as OffsetLayer;
      final image = await layer.toImage(view.paintBounds, pixelRatio: outScale / pixelRatio);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      File('${dir.path}/$file').writeAsBytesSync(data!.buffer.asUint8List());
    });
    frames.add({'file': file, 'ms': ms});
  }

  /// 目前畫面（2 倍解析度）為 ui.Image，供轉場淡出使用。
  Future<ui.Image> grab() async {
    final view = tester.binding.renderViews.first;
    return (await tester.runAsync(() async {
      final layer = view.debugLayer! as OffsetLayer;
      return layer.toImage(view.paintBounds, pixelRatio: outScale / pixelRatio);
    }))!;
  }

  void save({bool statusbar = true}) {
    File('${dir.path}/frames.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({'fps': recFps, 'frames': frames, 'taps': taps, 'statusbar': statusbar}),
    );
    final sorted = [...marks]..sort((a, b) => a.$1.compareTo(b.$1));
    final lines = [
      for (final (ms, label) in sorted) '${(ms / 1000).toStringAsFixed(3)}s\t$label',
      '${(t / 1000).toStringAsFixed(3)}s\t（結尾）',
    ];
    File('${dir.path}/marks.txt').writeAsStringSync('${lines.join('\n')}\n');
  }
}

// flutter test 固定使用測試字型，未指定字型家族的文字會畫成方框；截圖前改以 App 字型重新排版（比照 manual_host.dart）。
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

http.Client _delayedClient(ApiDelay? delay) {
  final inner = ManualApi.client();
  return MockClient((request) async {
    final r = (
      method: request.method,
      path: request.url.path.replaceFirst('/api', ''),
      query: request.url.queryParameters,
      body: utf8.decode(request.bodyBytes, allowMalformed: true),
    );
    final wait = delay?.call(r) ?? Duration.zero;
    if (wait > Duration.zero) await Future<void>.delayed(wait);
    final copy = http.Request(request.method, request.url)
      ..headers.addAll(request.headers)
      ..bodyBytes = request.bodyBytes;
    return http.Response.fromStream(await inner.send(copy));
  });
}

/// 拍一段 GIF 的畫格：[home] 為起始頁，[act] 內以 [GifRec] 逐格操作；結束時寫出 frames.json 與 marks.txt。
Future<void> gifShoot(
  WidgetTester tester, {
  required String name,
  required Widget Function() home,
  required Future<void> Function(GifRec rec) act,
  Map<String, Object> prefs = const {},
  User? me,
  void Function()? routes,
  ApiDelay? delay,
}) async {
  final errors = <String>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (details) => errors.add(details.exceptionAsString().split('\n').first);

  tester.view
    ..physicalSize = logicalSize * pixelRatio
    ..devicePixelRatio = pixelRatio
    ..padding = const FakeViewPadding(top: topInset * pixelRatio, bottom: bottomInset * pixelRatio)
    ..viewPadding = const FakeViewPadding(top: topInset * pixelRatio, bottom: bottomInset * pixelRatio);
  addTearDown(tester.view.reset);

  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({'biometric_login_enabled': true, ...prefs});
  await RecentlyViewed.clear();
  await BiometricService.load();
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (call) async => null,
  );
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
  ApiService.authToken = 'manual-token';
  ApiService.currentUser = me ?? User.fromJson(userJson(meId));
  Layers.clear();
  ManualApi.reset();
  routes?.call();
  debugNetworkImageHttpClientProvider = () => _PhotoClient();
  debugDisableShadows = false;

  final rec = GifRec(tester, name);
  try {
    await http.runWithClient(() async {
      await tester.pumpWidget(ManualApp(home: home()));
      await settleReal(tester, const Duration(seconds: 2));
      await act(rec);
      rec.save();
      Layers.clear();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    }, () => _delayedClient(delay));
  } finally {
    Layers.clear();
    debugNetworkImageHttpClientProvider = null;
    debugDisableShadows = true;
    setKeyboardInset(tester, 0);
    FlutterError.onError = previous;
  }
  expect(errors, isEmpty, reason: '畫面有例外或版面溢出');
}

// ---------------------------------------------------------------------------
// 鍵盤：數字鍵盤由下方滑入、滑出，App 的可用高度同步縮放；按鍵按下時短暫變灰。

final _keyboard = ValueNotifier<({double height, Rect? pressed})>((height: 0, pressed: null));

void setKeyboardInset(WidgetTester tester, double height) {
  tester.view
    ..viewInsets = FakeViewPadding(bottom: height * pixelRatio)
    ..padding = FakeViewPadding(top: topInset * pixelRatio, bottom: math.max(0, bottomInset - height) * pixelRatio);
}

class _NumberPadLayer extends StatelessWidget {
  const _NumberPadLayer();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: _keyboard,
      builder: (context, state, _) => Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: state.height - numberPadHeight,
            height: numberPadHeight,
            child: ColoredBox(
              color: const Color(0xFFD0D3D9),
              child: Stack(
                children: [
                  const Positioned.fill(child: S19NumberPad()),
                  if (state.pressed case final r?)
                    Positioned.fromRect(
                      rect: r,
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: const Color(0x66808489), borderRadius: BorderRadius.circular(5)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> animateNumberPad(GifRec rec, {required bool show, int ms = 280}) async {
  if (show) Layers.set('keyboard', const IgnorePointer(child: _NumberPadLayer()));
  await rec.animate(ms, (p) {
    final k = Curves.easeOutCubic.transform(p);
    final h = numberPadHeight * (show ? k : 1 - k);
    setKeyboardInset(rec.tester, h);
    _keyboard.value = (height: h, pressed: null);
  });
  if (!show) Layers.set('keyboard', null);
}

/// 數字鍵在螢幕上的位置（鍵盤完全升起時）。
Rect numberKeyRect(String digit) {
  const lefts = [6.0, 135.0, 264.0];
  const tops = [6.0, 59.0, 113.0, 167.0];
  final index = digit == '0' ? 10 : int.parse(digit) - 1;
  final row = index ~/ 3;
  final col = index % 3;
  return Rect.fromLTWH(lefts[col], tops[row], 122.7, 47);
}

Offset numberKeyCenter(String digit) => numberKeyRect(digit).center + const Offset(0, 852 - numberPadHeight);

/// 在數字鍵盤按一個數字：按鍵變灰、點擊標記，[apply] 在放開時更新輸入框。
Future<void> typeDigit(GifRec rec, String digit, Future<void> Function() apply) async {
  rec.taps.add({'ms': rec.t, 'x': numberKeyCenter(digit).dx, 'y': numberKeyCenter(digit).dy});
  _keyboard.value = (height: numberPadHeight, pressed: numberKeyRect(digit));
  await rec.play(80);
  await apply();
  _keyboard.value = (height: numberPadHeight, pressed: null);
}

// ---------------------------------------------------------------------------
// 相機畫面：以 screen 混合畫在掃描區（黑底）上，位置與透明度跟著頁面轉場與步驟切換。

class CameraOverlay extends StatelessWidget {
  final ui.Image image;
  final Rect rect;
  final double opacity;
  final Offset drift;
  final List<Rect> blackouts;

  const CameraOverlay({super.key, required this.image, required this.rect, required this.opacity, this.drift = Offset.zero, this.blackouts = const []});

  @override
  Widget build(BuildContext context) =>
      IgnorePointer(child: CustomPaint(size: Size.infinite, painter: _CameraPainter(image, rect, opacity, drift, blackouts)));
}

class _CameraPainter extends CustomPainter {
  final ui.Image image;
  final Rect rect;
  final double opacity;
  final Offset drift;
  final List<Rect> blackouts;

  const _CameraPainter(this.image, this.rect, this.opacity, this.drift, this.blackouts);

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;
    canvas.save();
    canvas.clipRect(rect);
    for (final r in blackouts) {
      canvas.drawRect(r, Paint()..color = Color.fromRGBO(0, 0, 0, opacity));
    }
    // 手持相機的輕微晃動：畫面略放大後平移，邊緣不露出黑邊
    final dst = rect.inflate(6).shift(drift);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      dst,
      Paint()
        ..blendMode = BlendMode.screen
        ..color = Color.fromRGBO(255, 255, 255, opacity)
        ..filterQuality = FilterQuality.high,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CameraPainter oldDelegate) => true;
}

/// [element] 祖先中所有 FadeTransition 的透明度乘積（步驟切換的淡入淡出）。
double fadeOf(Element element) {
  var opacity = 1.0;
  element.visitAncestorElements((ancestor) {
    final widget = ancestor.widget;
    if (widget is FadeTransition) opacity *= widget.opacity.value;
    return true;
  });
  return opacity;
}

/// 相機手持晃動量（pt），以時間軸計算，振幅約 2 pt。
Offset handheldDrift(double ms) {
  final t = ms / 1000;
  return Offset(1.6 * math.sin(t * 1.7) + 0.6 * math.sin(t * 4.1), 1.2 * math.sin(t * 1.3 + 1) + 0.5 * math.sin(t * 3.7));
}

// ---------------------------------------------------------------------------
// iOS 通知橫幅（淺色）：App 圖示、粗體標題、內文、右側時間。

class IosBanner extends StatelessWidget {
  final String title;
  final String body;
  final double top;

  const IosBanner({super.key, required this.title, required this.body, required this.top});

  @override
  Widget build(BuildContext context) {
    const text = TextStyle(fontFamily: 'NotoSansTC', decoration: TextDecoration.none, color: Colors.black);
    return Stack(
      children: [
        Positioned(
          left: 10,
          right: 10,
          top: top,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
            decoration: BoxDecoration(
              color: const Color(0xF5F4F4F6),
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [BoxShadow(color: Color(0x29000000), blurRadius: 24, offset: Offset(0, 6))],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(color: const Color(0xFF6E8696), borderRadius: BorderRadius.circular(9)),
                  child: const Icon(Icons.menu_book_rounded, size: 22, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(title, style: text.copyWith(fontSize: 15, fontWeight: FontWeight.w700, height: 1.3))),
                          Text('現在', style: text.copyWith(fontSize: 13, color: const Color(0xFF8E8E93))),
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(body, style: text.copyWith(fontSize: 14, height: 1.35, color: const Color(0xFF1C1C1E))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 轉場：前一段的最後畫面疊在最上層並淡出。
class FadeImage extends StatelessWidget {
  final ui.Image image;
  final double opacity;

  const FadeImage({super.key, required this.image, required this.opacity});

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Opacity(opacity: opacity, child: RawImage(image: image, width: logicalSize.width, height: logicalSize.height, fit: BoxFit.fill)),
  );
}

// ---------------------------------------------------------------------------
// 圖片：由本機真實照片供應（比照 manual_host.dart）。

class _PhotoClient implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _PhotoRequest(url);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PhotoRequest implements HttpClientRequest {
  final Uri url;

  _PhotoRequest(this.url);

  @override
  final HttpHeaders headers = _NoHeaders();

  @override
  Future<HttpClientResponse> close() async {
    final file = photoFile(url.toString());
    return _PhotoResponse(file?.readAsBytesSync());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoHeaders implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PhotoResponse extends Stream<List<int>> implements HttpClientResponse {
  final Uint8List? bytes;

  _PhotoResponse(this.bytes);

  @override
  int get statusCode => bytes == null ? 404 : 200;

  @override
  int get contentLength => bytes?.length ?? 0;

  @override
  HttpClientResponseCompressionState get compressionState => HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      Stream<List<int>>.fromIterable([?bytes]).listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
