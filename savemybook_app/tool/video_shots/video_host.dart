// 系統簡介影片第二版的截圖共用流程：畫面以 manual_shots 的 App 外殼與正式站真實資料拍攝，輸出整張畫面（WebP）、
// 去背元件（透明 PNG）與座標檔。各段落的測試檔只需描述「要拍哪些畫面、哪些元件要浮出」。
//
// 輸出（VIDEO_OUT，預設 ../presentation/系統簡介影片/project/public/v2）：
//   screens/<名稱>.webp   1179×2556（長圖高度另見 screens.json）
//   cuts/<名稱>.png       3 倍解析度去背元件
//   cuts.json / taps.json / sequences.json / screens.json
// 驗收用的無損整張畫面另存於 VIDEO_VERIFY（預設在 scratchpad 的 shots_v2/lossless）。

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:marquee/marquee.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:savemybook_app/models/ai.dart';
import 'package:savemybook_app/models/user.dart';
import 'package:savemybook_app/services/ai_status.dart';
import 'package:savemybook_app/services/api_service.dart';
import 'package:savemybook_app/services/biometric_service.dart';
import 'package:savemybook_app/services/recently_viewed.dart';

import '../manual_shots/manual_api.dart';
import '../manual_shots/manual_host.dart' show ManualApp, systemOverlay, settle, settleReal, hideKeyboard, logicalSize, pixelRatio, topInset, bottomInset;

export '../manual_shots/manual_host.dart' show navigatorKey, systemOverlay, settle, settleReal, setUpManual, scrollBy, tapAndSettle;

final _env = Platform.environment;
const _scratch = '/private/tmp/claude-501/-Users-xukaijun-Desktop-SaveMyBook/a06bcee0-3b01-4abe-8aa7-42d6d03a9aa5/scratchpad';

/// 正式站照片的本機快取：orig/ 為原檔（PNG），img/ 為縮至 900px 的 JPEG（由 fetch_photos.sh 下載）。
final videoDataDir = _env['VIDEO_DATA'] ?? '$_scratch/video_data';
final videoOutDir = _env['VIDEO_OUT'] ?? '${Directory.current.path}/../presentation/系統簡介影片/project/public/v2';
final videoVerifyDir = _env['VIDEO_VERIFY'] ?? '$_scratch/shots_v2/lossless';

/// 本次執行拍到的畫面、元件、點擊位置與連續畫面，測試結束時併入既有的 json。
final _screens = <String, Map<String, Object?>>{};
final _cuts = <String, Map<String, Object?>>{};
final _taps = <String, Map<String, Object?>>{};
final _sequences = <String, List<String>>{};
final failures = <String>[];

void recordSequence(String name, List<String> screens) => _sequences[name] = screens;

// ───────────── 拍攝流程 ─────────────

typedef Snap = Future<void> Function(String name);

/// [focus] 為截圖時需要對齊不定進度圈相位的範圍（例如 AI 分析中的面板）。
Finder? spinnerFocus;

Future<void> videoShoot(
  WidgetTester tester, {
  required Widget Function() home,
  required Future<void> Function(WidgetTester tester) act,
  Map<String, Object> prefs = const {},
  User? me,
  void Function()? routes,
}) async {
  final errors = <String>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    if (errors.isEmpty && _env['VIDEO_DEBUG'] != null) debugPrint('FIRST ERROR: ${details.exceptionAsString()}\n${details.stack}');
    errors.add(details.exceptionAsString().split('\n').first);
  };

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
  ApiService.authToken = 'video-token';
  ApiService.currentUser = me ?? User.fromJson(userJson(meId));
  systemOverlay.value = const [];
  spinnerFocus = null;
  ManualApi.reset();
  routes?.call();
  debugNetworkImageHttpClientProvider = () => _PhotoClient();
  // flutter test 預設把陰影畫成硬邊，截圖時改畫真實陰影
  debugDisableShadows = false;
  EditableText.debugDeterministicCursor = true;

  try {
    await http.runWithClient(() async {
      await tester.pumpWidget(ManualApp(home: home()));
      await settleReal(tester, const Duration(seconds: 2));
      try {
        await act(tester);
      } catch (e, st) {
        failures.add('$e');
        debugPrint('ACT FAILED: $e\n$st');
      }
      systemOverlay.value = const [];
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    }, () => _gatedClient);
  } finally {
    releaseApi();
    systemOverlay.value = const [];
    debugNetworkImageHttpClientProvider = null;
    debugDisableShadows = true;
    EditableText.debugDeterministicCursor = false;
    hideKeyboard(tester);
    FlutterError.onError = previous;
  }
  expect(errors, isEmpty, reason: '畫面有例外或版面溢出：${errors.join('；')}');
}

/// 拍一張整張畫面：輸出 `screens/<name>.webp`（品質 92）與驗收用的無損 PNG。
Future<void> snapScreen(WidgetTester tester, String name, {bool settleFirst = true}) async {
  if (settleFirst) {
    await settle(tester, const Duration(milliseconds: 600));
    await waitForImages(tester);
    await settle(tester, const Duration(milliseconds: 300));
  }
  final focus = spinnerFocus;
  if (focus != null) await alignSpinners(tester, focus);
  await _prepareForCapture(tester);
  final view = tester.binding.renderViews.first;
  await tester.runAsync(() async {
    final layer = view.debugLayer! as OffsetLayer;
    final image = await layer.toImage(view.paintBounds);
    final png = await _png(image);
    final size = Size(image.width / pixelRatio, image.height / pixelRatio);
    image.dispose();
    final lossless = File('$videoVerifyDir/$name.png')..parent.createSync(recursive: true);
    lossless.writeAsBytesSync(png);
    final webp = File('$videoOutDir/screens/$name.webp')..parent.createSync(recursive: true);
    final result = await Process.run('cwebp', ['-quiet', '-q', '92', '-m', '6', '-metadata', 'none', lossless.path, '-o', webp.path]);
    if (result.exitCode != 0) throw StateError('cwebp 失敗：${result.stderr}');
    _screens[name] = {
      'w': size.width,
      'h': size.height,
      if (size.height != logicalSize.height) 'long': true,
    };
  });
  await tester.pump();
}

Future<Uint8List> _png(ui.Image image) async => (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();

/// 過長書名的跑馬燈固定在開頭、未指定字型的文字改用 App 字型。
Future<void> _prepareForCapture(WidgetTester tester) async {
  final marquees = find.descendant(of: find.byType(Marquee), matching: find.byType(Scrollable)).evaluate().toList();
  for (final element in marquees) {
    if (element is StatefulElement && element.state is ScrollableState) (element.state as ScrollableState).position.jumpTo(0);
  }
  // jumpTo 會中止捲動動畫，補一個不推進時間的畫格讓畫面重建，否則下面直接排版會在框架外重建元件
  if (marquees.isNotEmpty) await tester.pump();
  void visit(RenderObject node) {
    // 捲動清單外暫存、未排版的項目不會出現在畫面上，改字型反而會讓它們留在待排版狀態
    if (node.debugNeedsLayout) return;
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

Future<void> waitForImages(WidgetTester tester) async {
  final missing = <String>[];
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    for (final element in find.byType(Image).evaluate().toList()) {
      final provider = (element.widget as Image).image;
      try {
        await precacheImage(provider, element, onError: (_, _) => missing.add('$provider'));
      } catch (_) {}
    }
  });
  await tester.pump();
  if (missing.isNotEmpty) failures.add('圖片未載入：${missing.join('、')}');
}

// ───────────── 讓指定請求停在等待回應 ─────────────

Completer<void>? _gate;
String? _gateKey;
int _held = 0;

/// 讓 [key]（例如 'POST /ai/listing-assist'）的請求停住，用來拍「分析中」「查詢中」的畫面；[releaseApi] 後才回應。
void holdApi(String key) {
  _gate = Completer<void>();
  _gateKey = key;
  _held = 0;
}

void releaseApi() {
  final gate = _gate;
  if (gate != null && !gate.isCompleted) gate.complete();
  _gate = null;
  _gateKey = null;
}

Future<void> untilHeld(WidgetTester tester) async {
  for (var i = 0; i < 400 && _held == 0; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump();
  }
  if (_held == 0) throw StateError('請求未送出：$_gateKey');
}

final http.Client _gatedClient = _GatedClient();

class _GatedClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final copy = http.Request(request.method, request.url)
      ..headers.addAll(request.headers)
      ..bodyBytes = await request.finalize().toBytes();
    final gate = _gate;
    if (gate != null && '${request.method} ${request.url.path.replaceFirst('/api', '')}' == _gateKey) {
      _held++;
      await gate.future;
    }
    return ManualApi.client().send(copy);
  }
}

// ───────────── 不定進度圈 ─────────────

final _spinnerPaint = find.byWidgetPredicate((w) => w is CustomPaint && w.painter.runtimeType.toString() == '_CircularProgressIndicatorPainter');

List<double> _sweeps(Finder finder) => [for (final e in finder.evaluate()) ((e.widget as CustomPaint).painter as dynamic).arcSweep as double];

// 不定進度圈每 1333ms 由一點長成大弧再縮回，截圖時機若落在週期起點只會畫出一個點。
Future<void> alignSpinners(WidgetTester tester, Finder focus) async {
  bool ready() {
    final main = _sweeps(find.descendant(of: focus, matching: _spinnerPaint));
    return main.isNotEmpty && main.every((s) => s >= 3.6);
  }

  for (var i = 0; i < 84 && !ready(); i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  if (!ready()) throw StateError('進度圈相位未對齊');
}

// ───────────── 去背元件 ─────────────

/// 元件外形：圓角矩形（[radius] 四角相同時另記於 json 的 r）或圓形。
class CutShape {
  final BorderRadius? radius;
  final bool circle;

  const CutShape.rect([this.radius]) : circle = false;
  const CutShape.circle() : radius = null, circle = true;

  RRect rrect(Rect rect) {
    if (circle) return RRect.fromRectAndRadius(rect, Radius.circular(rect.shortestSide / 2));
    return (radius ?? BorderRadius.zero).toRRect(rect);
  }

  double get r {
    if (circle) return -1;
    final b = radius ?? BorderRadius.zero;
    return b.topLeft.x;
  }
}

/// 由元件本身的 render object 取得外形與陰影：BoxDecoration 的圓角／圓形、ClipRRect、PhysicalModel 等。
({CutShape shape, List<BoxShadow> shadows, Color? fill}) shapeOf(RenderObject box) {
  if (box is RenderDecoratedBox && box.decoration is BoxDecoration) {
    final d = box.decoration as BoxDecoration;
    final shape = d.shape == BoxShape.circle ? const CutShape.circle() : CutShape.rect(d.borderRadius?.resolve(TextDirection.ltr));
    return (shape: shape, shadows: d.boxShadow ?? const [], fill: d.color);
  }
  if (box is RenderClipRRect) return (shape: CutShape.rect(box.borderRadius.resolve(TextDirection.ltr)), shadows: const [], fill: null);
  if (box is RenderClipOval) return (shape: const CutShape.circle(), shadows: const [], fill: null);
  if (box is RenderPhysicalModel) {
    final shape = box.shape == BoxShape.circle ? const CutShape.circle() : CutShape.rect(box.borderRadius ?? BorderRadius.zero);
    return (shape: shape, shadows: const [], fill: box.color);
  }
  if (box is RenderPhysicalShape) {
    final clipper = box.clipper;
    if (clipper is ShapeBorderClipper && clipper.shape is RoundedRectangleBorder) {
      final r = (clipper.shape as RoundedRectangleBorder).borderRadius.resolve(TextDirection.ltr);
      return (shape: CutShape.rect(r), shadows: const [], fill: box.color);
    }
  }
  return (shape: const CutShape.rect(), shadows: const [], fill: null);
}

/// 元件底下實際襯著的不透明底色：往上找第一個以不透明顏色填滿的祖先（Material、DecoratedBox、ColoredBox）。
Color? opaqueBackdropOf(RenderObject box) {
  for (var node = box.parent; node != null; node = node.parent) {
    final color = switch (node) {
      RenderPhysicalModel() => node.color,
      RenderPhysicalShape() => node.color,
      RenderDecoratedBox() when node.decoration is BoxDecoration => (node.decoration as BoxDecoration).color,
      _ => null,
    };
    if (color != null && color.a >= 1) return color;
  }
  return null;
}

/// 取 [finder] 對應的 render object；[pick] 可改從其子孫中挑出實際畫出外框的那一層。
/// [target] 為 Finder 或 Element。
RenderBox renderOf(WidgetTester tester, Object target, {bool Function(RenderObject ro)? pick}) {
  final element = target is Element ? target : (target as Finder).evaluate().single;
  final root = element.renderObject!;
  if (pick == null) return root as RenderBox;
  RenderBox? found;
  void visit(RenderObject node) {
    if (found != null) return;
    if (pick(node)) {
      found = node as RenderBox;
      return;
    }
    node.visitChildren(visit);
  }

  visit(root);
  if (found == null) throw StateError('找不到符合條件的 render object：$target');
  return found!;
}

/// 由 [of] 找到的元件往上找第一個符合 [test] 的元件。直接走元素樹，不經過 flutter_test 的全樹搜尋
/// （捲動清單中暫存、尚未排版的項目會讓全樹搜尋觸發排版斷言）。
Element ancestorWhere(Finder of, bool Function(Widget w) test) {
  Element? found;
  final start = of.evaluate().first;
  if (test(start.widget)) return start;
  start.visitAncestorElements((e) {
    if (test(e.widget)) {
      found = e;
      return false;
    }
    return true;
  });
  return found ?? (throw StateError('找不到符合條件的上層元件：$of'));
}

bool isBoxDecoration(RenderObject ro) => ro is RenderDecoratedBox && ro.decoration is BoxDecoration && (ro.decoration as BoxDecoration).color != null;

/// 直接渲染元件本身（不經過整張截圖）：以全新的圖層只畫這個 render object 與其子孫，
/// 元件自身的陰影暫時拿掉（參數記在 json 由影片引擎另外畫），外框以外完全透明；[clip] 為 true 時另以外框裁切子元件。
///
/// [backdrop]：元件底色為半透明時（例如 6% 的強調色），先在外框內鋪上它在 App 中實際疊加的不透明底色，外觀才與畫面相同。
Future<void> cut(
  WidgetTester tester,
  String name, {
  required String screen,
  required RenderBox box,
  CutShape? shape,
  Color? backdrop,
  bool clip = false,
  String? note,
}) async {
  final info = shapeOf(box);
  final outline = shape ?? info.shape;
  // 半透明底色的元件（例如 6% 強調色、8% 警示紅）在 App 中是疊在不透明的面板上，單獨輸出時要連同那層底色
  backdrop ??= info.fill != null && info.fill!.a < 1 ? opaqueBackdropOf(box) : null;
  final topLeft = box.localToGlobal(Offset.zero);
  final bottomRight = box.localToGlobal(box.size.bottomRight(Offset.zero));
  final rect = Rect.fromPoints(topLeft, bottomRight);
  if ((rect.width - box.size.width).abs() > 0.01 || (rect.height - box.size.height).abs() > 0.01) {
    throw StateError('$name 有縮放或旋轉，無法貼回原位');
  }
  // 去背圖對齊整張畫面的像素格：PNG 的範圍是元件外框向外取整到 1/3 pt，元件以原本的次像素位置畫入。
  final px = Rect.fromLTRB(
    (rect.left * pixelRatio + 1e-6).floorToDouble(),
    (rect.top * pixelRatio + 1e-6).floorToDouble(),
    (rect.right * pixelRatio - 1e-6).ceilToDouble(),
    (rect.bottom * pixelRatio - 1e-6).ceilToDouble(),
  );
  final phase = rect.topLeft - px.topLeft / pixelRatio;
  final local = phase & box.size;
  final rrect = outline.rrect(local);

  // 陰影畫在外框之外，影片引擎另外畫；暫時拿掉元件自身的陰影再畫，不必裁切，圓角的反鋸齒與原畫面完全相同
  final original = box is RenderDecoratedBox ? box.decoration : null;
  if (box is RenderDecoratedBox && info.shadows.isNotEmpty) box.decoration = (original! as BoxDecoration).copyWith(boxShadow: const []);
  final elevation = box is RenderPhysicalModel ? box.elevation : box is RenderPhysicalShape ? box.elevation : null;
  if (box is RenderPhysicalModel) box.elevation = 0;
  if (box is RenderPhysicalShape) box.elevation = 0;

  final layer = OffsetLayer();
  // ignore: invalid_use_of_protected_member
  final context = PaintingContext(layer, Offset.zero & (px.size / pixelRatio));
  if (backdrop != null) context.canvas.drawRRect(rrect, Paint()..color = backdrop);
  if (clip) {
    context.pushClipRRect(true, Offset.zero, local, rrect, (c, o) => c.paintChild(box, phase));
  } else {
    context.paintChild(box, phase);
  }
  // ignore: invalid_use_of_protected_member
  context.stopRecordingIfNeeded();
  if (box is RenderDecoratedBox && original != null) box.decoration = original;
  if (box is RenderPhysicalModel) box.elevation = elevation!;
  if (box is RenderPhysicalShape) box.elevation = elevation!;

  await tester.runAsync(() async {
    final image = await layer.toImage(Offset.zero & (px.size / pixelRatio), pixelRatio: pixelRatio);
    if (image.width != px.width.round() || image.height != px.height.round()) {
      throw StateError('$name 輸出尺寸 ${image.width}×${image.height} 與預期 ${px.width}×${px.height} 不符');
    }
    final file = File('$videoOutDir/cuts/$name.png')..parent.createSync(recursive: true);
    file.writeAsBytesSync(await _png(image));
    image.dispose();
  });
  layer.dispose();
  await restoreTree(tester);

  double r3(double v) => double.parse((v / pixelRatio).toStringAsFixed(4));
  double r2(double v) => double.parse(v.toStringAsFixed(3));
  final shadows = info.shadows;
  _cuts[name] = {
    'screen': screen,
    'x': r3(px.left),
    'y': r3(px.top),
    'w': r3(px.width),
    'h': r3(px.height),
    'r': outline.circle ? 'circle' : r2(outline.r),
    if (outline.radius != null && !_uniform(outline.radius!)) 'radii': [for (final c in _corners(outline.radius!)) r2(c)],
    'px': {'x': px.left.round(), 'y': px.top.round(), 'w': px.width.round(), 'h': px.height.round()},
    'exact': {'x': r2(rect.left), 'y': r2(rect.top), 'w': r2(rect.width), 'h': r2(rect.height)},
    if (backdrop != null) 'backdrop': _hex(backdrop),
    if (shadows.isNotEmpty)
      'shadow': {
        'included': false,
        'layers': [
          for (final s in shadows)
            {'color': _hex(s.color), 'blur': s.blurRadius, 'spread': s.spreadRadius, 'dx': s.offset.dx, 'dy': s.offset.dy},
        ],
      },
    'note': ?note,
  };
}

/// 去背後必須把被偷用的圖層還回原本的 render tree：子孫中的 RepaintBoundary 圖層在 paintChild 時會被移到新圖層。
Future<void> restoreTree(WidgetTester tester) async {
  void visit(RenderObject node) {
    // 未完成排版的子元件（例如捲動清單外暫存的項目）不會被畫，標記重畫反而會觸發排版斷言
    if (node.attached && !node.debugNeedsLayout) node.markNeedsPaint();
    node.visitChildren(visit);
  }

  for (final view in tester.binding.renderViews) {
    visit(view);
  }
  await tester.pump();
}

bool _uniform(BorderRadius b) => {b.topLeft, b.topRight, b.bottomLeft, b.bottomRight}.length == 1 && b.topLeft.x == b.topLeft.y;

List<double> _corners(BorderRadius b) => [b.topLeft.x, b.topRight.x, b.bottomRight.x, b.bottomLeft.x];

String _hex(Color c) {
  String two(double v) => (v * 255).round().toRadixString(16).padLeft(2, '0');
  return '#${two(c.r)}${two(c.g)}${two(c.b)}${c.a < 1 ? two(c.a) : ''}'.toUpperCase();
}

/// 影片中要「點擊」的按鈕位置（App 邏輯座標，取自 render tree）。
void tapAt(WidgetTester tester, String name, {required String screen, required Finder finder}) {
  final r = tester.getRect(finder);
  double v(double x) => double.parse(x.toStringAsFixed(2));
  _taps[name] = {'screen': screen, 'x': v(r.left), 'y': v(r.top), 'w': v(r.width), 'h': v(r.height)};
}

/// 記錄任意元件位置（例如貼回同一元件到其他畫面時用來確認位置一致）。
Rect rectOf(WidgetTester tester, Finder finder) => tester.getRect(finder);

// ───────────── json 輸出 ─────────────

void writeJson() {
  Map<String, Object?> merge(String file, Map<String, Object?> fresh, {List<String>? order}) {
    final f = File('$videoOutDir/$file');
    final merged = <String, Object?>{};
    if (f.existsSync()) {
      try {
        merged.addAll(jsonDecode(f.readAsStringSync()) as Map<String, dynamic>);
      } catch (_) {}
    }
    merged.addAll(fresh);
    final keys = merged.keys.toList()..sort();
    final sorted = {for (final k in keys) k: merged[k]};
    f
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(sorted)}\n');
    return sorted;
  }

  merge('cuts.json', _cuts);
  merge('taps.json', _taps);
  merge('sequences.json', _sequences);
  merge('screens.json', _screens);
}

// ───────────── 照片 ─────────────

/// 本機真實照片：優先用原檔，其次用 900px JPEG。
File? photoFile(String urlOrPath) {
  final path = Uri.parse(urlOrPath).path.replaceFirst(RegExp(r'^/'), '');
  final base = path.replaceAll('/', '_');
  final stem = base.contains('.') ? base.substring(0, base.lastIndexOf('.')) : base;
  for (final candidate in ['$videoDataDir/orig/$stem.png', '$videoDataDir/img/$stem.jpg']) {
    final f = File(candidate);
    if (f.existsSync()) return f;
  }
  return null;
}

Future<ui.Image> loadPhoto(WidgetTester tester, String urlOrPath) async {
  final file = photoFile(urlOrPath) ?? (throw StateError('缺少照片 $urlOrPath，請先執行 fetch_photos.sh'));
  return (await tester.runAsync(() async {
    final codec = await ui.instantiateImageCodec(file.readAsBytesSync());
    return (await codec.getNextFrame()).image;
  }))!;
}

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
  Future<HttpClientResponse> close() async => _PhotoResponse(photoFile(url.toString())?.readAsBytesSync());

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
  StreamSubscription<List<int>> listen(void Function(List<int> event)? onData, {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      Stream<List<int>>.fromIterable([?bytes]).listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ───────────── 打字 ─────────────

/// 逐字輸入的中間畫面：每 [step] 個字一張，名稱為 `<prefix>_t01`、`_t02`…，最後一張為完整文字。
Future<List<String>> typeFrames(WidgetTester tester, Finder field, String text, String prefix, {int step = 1}) async {
  final runes = text.runes.toList();
  final counts = [for (var n = step; n < runes.length; n += step) n, runes.length];
  final names = <String>[];
  for (final (i, n) in counts.indexed) {
    await tester.enterText(field, String.fromCharCodes(runes.take(n)));
    await settle(tester, const Duration(milliseconds: 300));
    final name = '${prefix}_t${(i + 1).toString().padLeft(2, '0')}';
    await snapScreen(tester, name);
    names.add(name);
  }
  return names;
}
