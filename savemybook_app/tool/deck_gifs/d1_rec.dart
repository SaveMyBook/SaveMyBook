// 複評簡報 GIF／影片（子任務 d1）的逐格錄製工具：以假時間每格推進一次並截圖（預設 25 fps，環境變數 D1_FPS=60 時錄 60 fps），
// 輸出 2 倍解析度（786×1704）PNG 與 frames.json，交給 gif_kit.py 加外框、狀態列與點擊標記（GIF 用 build，影片用 video）。

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marquee/marquee.dart';

import '../manual_shots/manual_host.dart';

const d1Root =
    '/private/tmp/claude-501/-Users-xukaijun-Desktop-SaveMyBook-savemybook-app/f52b6347-17b0-4b79-95e7-263531604b33/scratchpad/deck_gif/d1';

/// 截圖解析度（每 pt 幾 px）。
const _outRatio = 2.0;

/// 錄製格率：GIF 為 25，影片為 60。
final recFps = int.tryParse(Platform.environment['D1_FPS'] ?? '') ?? 25;

class Rec {
  final String dir;
  final frames = <Map<String, Object>>[];
  final taps = <Map<String, Object>>[];

  /// 每格的長度（微秒）。
  final int frameUs = (1000000 / recFps).round();

  /// 已要求推進但尚未推進的假時間（微秒）；格長除不盡的零頭累積到下一段，總長才不會漂移。
  int _owedUs = 0;

  Rec(String name) : dir = '$d1Root/$name/${recFps == 25 ? 'frames' : 'frames$recFps'}' {
    final d = Directory(dir);
    if (d.existsSync()) d.deleteSync(recursive: true);
    d.createSync(recursive: true);
  }

  double get frameMs => frameUs / 1000;

  Future<void> grab(WidgetTester tester, {double? ms}) async {
    final file = '${frames.length.toString().padLeft(5, '0')}.png';
    await _capture(tester, '$dir/$file');
    frames.add({'file': file, 'ms': ms ?? frameMs});
  }

  /// 以假時間推進 [ms] 並逐格截圖；[speed] 大於 1 為快轉（每格推進 speed 倍的假時間，影片長度為 ms / speed）。
  Future<void> play(WidgetTester tester, int ms, {double speed = 1, bool real = true}) async {
    final stepUs = (frameUs * speed).round();
    _owedUs += ms * 1000;
    final n = (_owedUs / stepUs).round();
    _owedUs -= n * stepUs;
    for (var i = 0; i < n; i++) {
      if (real) await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 2)));
      await tester.pump(Duration(microseconds: stepUs));
      await grab(tester);
    }
  }

  /// 畫面靜止時只截一格並停留 [ms]。
  Future<void> hold(WidgetTester tester, int ms) => grab(tester, ms: ms.toDouble());

  void mark(Offset p) => taps.add({'frame': frames.length, 'x': p.dx, 'y': p.dy});

  /// 按下 [pressMs] 後放開，期間逐格截圖（按鈕的按壓縮放與點擊標記都會被錄到）。
  Future<void> tap(WidgetTester tester, Finder finder, {Offset? at, int pressMs = 120}) async {
    final p = at ?? tester.getCenter(finder);
    mark(p);
    final gesture = await tester.startGesture(p);
    await play(tester, pressMs);
    await gesture.up();
  }

  void save({bool statusbar = true}) {
    File('${Directory(dir).path}/frames.json').writeAsStringSync(
      const JsonEncoder.withIndent(' ').convert({'frames': frames, 'taps': taps, 'statusbar': statusbar}),
    );
  }
}

// 以下兩段比照 manual_host.dart 的 capture()（該檔不可修改且未公開這兩個函式），改為 2 倍解析度輸出到指定路徑。

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

Future<void> _capture(WidgetTester tester, String path) async {
  final marquees = find.descendant(of: find.byType(Marquee), matching: find.byType(Scrollable)).evaluate().toList();
  for (final element in marquees) {
    (element as StatefulElement).state is ScrollableState ? (element.state as ScrollableState).position.jumpTo(0) : null;
  }
  if (marquees.isNotEmpty) await tester.pump();
  _applyAppFontToUnstyledText(tester);
  final view = tester.binding.renderViews.first;
  await tester.runAsync(() async {
    final layer = view.debugLayer! as OffsetLayer;
    final image = await layer.toImage(view.paintBounds, pixelRatio: _outRatio / pixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File(path).writeAsBytesSync(data!.buffer.asUint8List());
  });
}

// ───────────── 鍵盤滑入滑出 ─────────────

/// 數字鍵盤（ISBN 等數字欄位）的高度。
const numberPadHeight = 291.0;

/// 鍵盤以 iOS 的節奏滑入或滑出（約 0.28 秒），App 可用空間逐格跟著改變。
Future<void> slideKeyboard(
  WidgetTester tester,
  Rec rec, {
  required Widget keyboard,
  required double height,
  required bool show,
  int ms = 280,
}) async {
  final steps = (ms / rec.frameMs).round();
  for (var i = 1; i <= steps; i++) {
    final t = Curves.easeOutCubic.transform(i / steps);
    final k = show ? t : 1 - t;
    setKeyboard(tester, keyboard: keyboard, height: height, visible: k);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 2)));
    await tester.pump(Duration(microseconds: rec.frameUs));
    await rec.grab(tester);
  }
}

/// 把鍵盤放在 [visible]（0～1）的位置；visible 為 0 時移除。鍵盤的 Positioned 子元件為 IosKeyboard 時 hideKeyboard 也能移除。
void setKeyboard(WidgetTester tester, {required Widget keyboard, required double height, required double visible}) {
  final others = [
    for (final w in systemOverlay.value)
      if (!(w is Positioned && w.key == const ValueKey('d1-keyboard'))) w,
  ];
  final inset = height * visible;
  tester.view
    ..viewInsets = FakeViewPadding(bottom: inset * pixelRatio)
    ..padding = FakeViewPadding(top: topInset * pixelRatio, bottom: (bottomInset - inset).clamp(0, bottomInset) * pixelRatio);
  systemOverlay.value = [
    ...others,
    if (visible > 0)
      Positioned(key: const ValueKey('d1-keyboard'), left: 0, right: 0, bottom: inset - height, height: height, child: keyboard),
  ];
}

/// 模擬的 iOS 淺色數字鍵盤（UIKeyboardTypeNumberPad），[pressed] 為正在按下的鍵。
class IosNumberPad extends StatelessWidget {
  final String? pressed;

  const IosNumberPad({super.key, this.pressed});

  static const _letters = {'2': 'ABC', '3': 'DEF', '4': 'GHI', '5': 'JKL', '6': 'MNO', '7': 'PQRS', '8': 'TUV', '9': 'WXYZ'};

  @override
  Widget build(BuildContext context) {
    const text = TextStyle(fontFamily: 'NotoSansTC', color: Colors.black, decoration: TextDecoration.none);
    const gap = 6.0;
    const keyH = 46.0;
    const width = (393 - gap * 4) / 3;
    Widget key(int row, int col, String label) {
      final left = gap + col * (width + gap);
      final top = 6 + row * (keyH + 7);
      final down = pressed == label;
      if (label == '⌫') {
        return Positioned(
          left: left,
          top: top,
          width: width,
          height: keyH,
          child: DecoratedBox(
            decoration: BoxDecoration(color: down ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(6)),
            child: const Center(child: Icon(Icons.backspace_outlined, size: 24, color: Colors.black)),
          ),
        );
      }
      if (label.isEmpty) return const SizedBox.shrink();
      return Positioned(
        left: left,
        top: top,
        width: width,
        height: keyH,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: down ? const Color(0xFFB9BDC5) : Colors.white,
            borderRadius: BorderRadius.circular(6),
            boxShadow: const [BoxShadow(color: Color(0xFF898A8D), offset: Offset(0, 1))],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: text.copyWith(fontSize: 25, height: 1.0)),
              if (_letters[label] != null)
                Text(_letters[label]!, style: text.copyWith(fontSize: 9.5, height: 1.25, fontWeight: FontWeight.w700, letterSpacing: 1.6)),
            ],
          ),
        ),
      );
    }

    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];
    return ColoredBox(
      color: const Color(0xFFD0D3D9),
      child: Stack(
        children: [
          for (final (r, row) in rows.indexed)
            for (final (c, label) in row.indexed) key(r, c, label),
        ],
      ),
    );
  }
}
