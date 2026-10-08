// 複評簡報 GIF／影片（子任務 D2）的錄製工具：操作後以固定間隔推進並逐格輸出 2 倍解析度（786×1704）的 App 畫面，
// 點擊與捲動的手指位置寫入 frames.json，由 d2_build.py（沿用 gif_kit.py 的合成）畫上標記與 iPhone 外框。
// 環境變數 D2_FPS 決定錄製格率：預設 25（GIF，畫格放 frames/），60 為影片（放 frames60/）；時間軸以毫秒計，兩者長度相同。

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marquee/marquee.dart';

import '../manual_shots/manual_host.dart';

const gifRoot =
    '/private/tmp/claude-501/-Users-xukaijun-Desktop-SaveMyBook-savemybook-app/f52b6347-17b0-4b79-95e7-263531604b33/scratchpad/deck_gif/d2';

final int recordFps = int.tryParse(Platform.environment['D2_FPS'] ?? '') ?? 25;
final Duration frameStep = Duration(microseconds: (1000000 / recordFps).round());
const gifRatio = 2.0;

int framesFor(Duration d) => (d.inMicroseconds / frameStep.inMicroseconds).round();

class GifRecorder {
  final WidgetTester tester;
  final String name;
  final Directory dir;
  final List<String> _frames = [];
  final List<Map<String, Object>> _taps = [];
  final List<Map<String, Object>> _drags = [];

  final ValueNotifier<double> _keyboard = ValueNotifier(0);
  final ValueNotifier<List<String>> _candidates = ValueNotifier(const []);
  bool _keyboardMounted = false;

  GifRecorder(this.tester, this.name) : dir = Directory('$gifRoot/$name/${recordFps == 25 ? 'frames' : 'frames$recordFps'}') {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);
  }

  int get count => _frames.length;

  Future<void> frame() async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 3)));
    await tester.pump(frameStep);
    await _capture();
  }

  Future<void> play(Duration duration) async {
    for (var i = 0; i < framesFor(duration); i++) {
      await frame();
    }
  }

  /// 逐格推進直到條件成立（最多 [max]），用於等待載入完成。
  Future<void> until(bool Function() done, {Duration max = const Duration(seconds: 3)}) async {
    for (var i = 0; i < framesFor(max) && !done(); i++) {
      await frame();
    }
  }

  /// 按下、停留 [hold] 後放開；標記從按下的那一格開始。
  Future<void> tap(Finder finder, {Offset? at, Offset shift = Offset.zero, Duration hold = const Duration(milliseconds: 120)}) async {
    final p = (at ?? tester.getCenter(finder.first)) + shift;
    _taps.add({'frame': count, 'x': p.dx, 'y': p.dy});
    final gesture = await tester.startGesture(p);
    await play(hold);
    await gesture.up();
  }

  /// 以緩動曲線捲動；手指隨內容移動 [follow] pt 後放開（之後內容依慣性滑完），[finger] 為按下的位置。
  Future<void> scroll(
    ScrollPosition position,
    double delta, {
    required Offset finger,
    Duration duration = const Duration(milliseconds: 720),
    Curve curve = Curves.easeInOutCubic,
    double follow = 260,
  }) async {
    final start = position.pixels;
    final horizontal = position.axis == Axis.horizontal;
    final steps = framesFor(duration);
    _drags.add({'frame': count, 'x': finger.dx, 'y': finger.dy, 'phase': 'down'});
    await frame();
    var lifted = false;
    for (var i = 1; i <= steps; i++) {
      final t = curve.transform(i / steps);
      position.jumpTo(start + delta * t);
      if (!lifted) {
        final moved = delta * t;
        lifted = i == steps || moved.abs() >= follow;
        final p = finger - (horizontal ? Offset(moved, 0) : Offset(0, moved));
        _drags.add({'frame': count, 'x': p.dx, 'y': p.dy, 'phase': lifted ? 'up' : 'move'});
      }
      await frame();
    }
  }

  /// 模擬鍵盤滑入或滑出；App 可用空間隨鍵盤高度逐格縮減。
  Future<void> keyboard(bool show, {Duration duration = const Duration(milliseconds: 320), List<String>? candidates}) async {
    if (candidates != null) _candidates.value = candidates;
    if (!_keyboardMounted) {
      _keyboardMounted = true;
      systemOverlay.value = [
        ...systemOverlay.value,
        Positioned.fill(
          child: IgnorePointer(
            child: ValueListenableBuilder<double>(
              valueListenable: _keyboard,
              builder: (context, v, _) => Stack(
                children: [
                  if (v > 0)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: -keyboardHeight * (1 - v),
                      height: keyboardHeight,
                      child: ValueListenableBuilder<List<String>>(
                        valueListenable: _candidates,
                        builder: (context, list, _) => IosKeyboard(candidates: list),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ];
    }
    final from = _keyboard.value;
    final to = show ? 1.0 : 0.0;
    final steps = framesFor(duration);
    for (var i = 1; i <= steps; i++) {
      final t = Curves.easeOutCubic.transform(i / steps);
      _setKeyboard(from + (to - from) * t);
      await frame();
    }
  }

  void _setKeyboard(double v) {
    _keyboard.value = v;
    final inset = keyboardHeight * v;
    tester.view
      ..viewInsets = FakeViewPadding(bottom: inset * pixelRatio)
      ..padding = FakeViewPadding(top: topInset * pixelRatio, bottom: (bottomInset - inset).clamp(0, bottomInset) * pixelRatio);
  }

  /// 逐段輸入文字（中文一次一個詞），每段停留 [step]；[candidates] 為每段輸入後鍵盤候選字列的內容。
  Future<void> type(Finder field, List<String> chunks, {Duration step = const Duration(milliseconds: 160), List<List<String>>? candidates}) async {
    var text = '';
    for (final (i, chunk) in chunks.indexed) {
      text += chunk;
      if (candidates != null && i < candidates.length) _candidates.value = candidates[i];
      await tester.enterText(field, text);
      await play(step);
    }
  }

  void save({bool statusbar = true, bool home = true}) {
    final spec = {
      'fps': recordFps,
      'frames': [for (final f in _frames) {'file': f, 'ms': 1000 / recordFps}],
      'taps': _taps,
      'drags': _drags,
      'statusbar': statusbar,
      'home': home,
    };
    File('${dir.path}/frames.json').writeAsStringSync(const JsonEncoder.withIndent(' ').convert(spec));
  }

  Future<void> _capture() async {
    final marquees = find.descendant(of: find.byType(Marquee), matching: find.byType(Scrollable)).evaluate().toList();
    for (final element in marquees) {
      final state = (element as StatefulElement).state;
      if (state is ScrollableState) state.position.jumpTo(0);
    }
    if (marquees.isNotEmpty) await tester.pump();
    applyAppFontToUnstyledText(tester);
    final view = tester.binding.renderViews.first;
    final file = '${count.toString().padLeft(5, '0')}.png';
    await tester.runAsync(() async {
      final layer = view.debugLayer! as OffsetLayer;
      final image = await layer.toImage(view.paintBounds, pixelRatio: gifRatio / pixelRatio);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      File('${dir.path}/$file').writeAsBytesSync(data!.buffer.asUint8List());
    });
    _frames.add(file);
  }
}

// flutter test 固定使用測試字型，未指定字型家族的文字會畫成方框；每格輸出前改以 App 字型重新排版（同 manual_host 的作法）。
void applyAppFontToUnstyledText(WidgetTester tester) {
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

/// 圖片請求：先查 [extra]（例如爭議佐證照片），其餘交給 manual_host 的真實照片。
class GifPhotoClient implements HttpClient {
  final Map<String, File> extra;

  GifPhotoClient(this.extra);

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _Request(url, extra);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Request implements HttpClientRequest {
  final Uri url;
  final Map<String, File> extra;

  _Request(this.url, this.extra);

  @override
  final HttpHeaders headers = _NoHeaders();

  @override
  Future<HttpClientResponse> close() async {
    final file = extra[url.path] ?? photoFile(url.toString());
    return _Response(file?.readAsBytesSync());
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

class _Response extends Stream<List<int>> implements HttpClientResponse {
  final Uint8List? bytes;

  _Response(this.bytes);

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
