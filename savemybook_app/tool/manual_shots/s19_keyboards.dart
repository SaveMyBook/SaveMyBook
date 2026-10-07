// 第 19 節用的模擬 iOS 淺色鍵盤：數字鍵盤、密碼欄位的英文鍵盤，以及右下角為「完成」或換行鍵的注音鍵盤。
// 尺寸取自原實機截圖（393 寬），顏色與注音鍵盤比照 manual_host.dart 的 IosKeyboard。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'manual_host.dart';

const _background = Color(0xFFD0D3D9);
const _special = Color(0xFFACB1BB);
const _shadow = Color(0xFF898A8D);
const _blue = Color(0xFF007AFF);
const _text = TextStyle(fontFamily: 'NotoSansTC', color: Colors.black, decoration: TextDecoration.none, fontWeight: FontWeight.w400);

const numberPadHeight = 291.0;

/// 顯示鍵盤：App 依 [height] 縮減可用空間，[keyboard] 畫在最上層（null 時只保留空間，模擬鍵盤正在升起）。
void s19ShowKeyboard(WidgetTester tester, Widget? keyboard, {double height = keyboardHeight}) {
  s19HideKeyboard(tester);
  tester.view
    ..viewInsets = FakeViewPadding(bottom: height * pixelRatio)
    ..padding = const FakeViewPadding(top: topInset * pixelRatio);
  if (keyboard != null) {
    systemOverlay.value = [
      ...systemOverlay.value,
      Positioned(left: 0, right: 0, bottom: 0, height: height, child: _S19Keyboard(child: keyboard)),
    ];
  }
}

void s19HideKeyboard(WidgetTester tester) {
  tester.view
    ..viewInsets = FakeViewPadding.zero
    ..padding = const FakeViewPadding(top: topInset * pixelRatio, bottom: bottomInset * pixelRatio);
  systemOverlay.value = [for (final w in systemOverlay.value) if (w is! Positioned || w.child is! _S19Keyboard) w];
}

class _S19Keyboard extends StatelessWidget {
  final Widget child;

  const _S19Keyboard({required this.child});

  @override
  Widget build(BuildContext context) => ColoredBox(color: _background, child: child);
}

Widget _key(double left, double top, double width, double height, {Widget? child, Color color = Colors.white}) => Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(5),
          boxShadow: const [BoxShadow(color: _shadow, offset: Offset(0, 1))],
        ),
        child: Center(child: child),
      ),
    );

Widget _label(String text, {double size = 22, Color color = Colors.black}) =>
    Text(text, style: _text.copyWith(fontSize: size, color: color, height: 1.1));

const _mic = Positioned(left: 336, top: 281, child: Icon(Icons.mic_none_rounded, size: 30, color: Color(0xFF1C1C1E)));

/// iOS 數字鍵盤（配對碼、櫃門數字）。
class S19NumberPad extends StatelessWidget {
  const S19NumberPad({super.key});

  static const _lefts = [6.0, 135.0, 264.0];
  static const _tops = [6.0, 59.0, 113.0, 167.0];
  static const _width = 122.7;
  static const _height = 47.0;
  static const _keys = [
    [('1', ''), ('2', 'ABC'), ('3', 'DEF')],
    [('4', 'GHI'), ('5', 'JKL'), ('6', 'MNO')],
    [('7', 'PQRS'), ('8', 'TUV'), ('9', 'WXYZ')],
  ];

  @override
  Widget build(BuildContext context) {
    Widget digit(int row, int col, String d, String letters) => _key(
          _lefts[col],
          _tops[row],
          _width,
          _height,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(d, style: _text.copyWith(fontSize: 26, height: 1.05)),
              if (letters.isNotEmpty)
                Text(letters, style: _text.copyWith(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 2.2, height: 1.1)),
            ],
          ),
        );
    return Stack(
      children: [
        for (final (r, row) in _keys.indexed)
          for (final (c, (d, l)) in row.indexed) digit(r, c, d, l),
        digit(3, 1, '0', ''),
        Positioned(
          left: _lefts[2],
          top: _tops[3],
          width: _width,
          height: _height,
          child: const Center(child: Icon(Icons.backspace_outlined, size: 25, color: Colors.black)),
        ),
      ],
    );
  }
}

/// 密碼欄位的英文鍵盤：上方為「密碼」自動填入列，右下角為「done」。
class S19QwertyKeyboard extends StatelessWidget {
  const S19QwertyKeyboard({super.key});

  static const _pitch = 39.33;
  static const _width = 33.3;
  static const _height = 43.0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned(left: 31, top: 11, width: 1, height: 28, child: ColoredBox(color: Color(0x33000000))),
        const Positioned(right: 31, top: 11, width: 1, height: 28, child: ColoredBox(color: Color(0x33000000))),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 50,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.key_rounded, size: 22, color: Color(0xFF1C1C1E)),
              const SizedBox(width: 4),
              Text('密碼', style: _text.copyWith(fontSize: 18)),
            ],
          ),
        ),
        for (final (i, k) in 'qwertyuiop'.split('').indexed) _key(3 + i * _pitch, 53, _width, _height, child: _label(k, size: 24)),
        for (final (i, k) in 'asdfghjkl'.split('').indexed) _key(22.3 + i * _pitch, 107, _width, _height, child: _label(k, size: 24)),
        _key(3, 161, 44.3, _height, color: _special, child: const Icon(Icons.arrow_upward_rounded, size: 24, color: Colors.black)),
        for (final (i, k) in 'zxcvbnm'.split('').indexed) _key(61.7 + i * _pitch, 161, _width, _height, child: _label(k, size: 24)),
        _key(345.7, 161, 44.3, _height, color: _special, child: const Icon(Icons.backspace_outlined, size: 21, color: Colors.black)),
        _key(3, 215, 92.7, _height, color: _special, child: _label('123', size: 17)),
        _key(100.3, 215, 191.7, _height, child: _label('space', size: 17)),
        _key(298, 215, 92, _height, color: _blue, child: _label('done', size: 17, color: Colors.white)),
        _mic,
      ],
    );
  }
}

/// 注音鍵盤（含候選字列）；[newline] 為 true 時右下角為換行鍵（多行欄位），否則為藍色「完成」。
class S19ZhuyinKeyboard extends StatelessWidget {
  final List<String> candidates;
  final bool newline;

  const S19ZhuyinKeyboard({super.key, this.candidates = const [], this.newline = false});

  static const _rows = [
    (3.33, ['ㄅ', 'ㄉ', 'ˇ', 'ˋ', 'ㄓ', 'ˊ', '˙', 'ㄚ', 'ㄞ', 'ㄢ', 'ㄦ']),
    (15.0, ['ㄆ', 'ㄊ', 'ㄍ', 'ㄐ', 'ㄔ', 'ㄗ', 'ㄧ', 'ㄛ', 'ㄟ', 'ㄣ']),
    (26.0, ['ㄇ', 'ㄋ', 'ㄎ', 'ㄑ', 'ㄕ', 'ㄘ', 'ㄨ', 'ㄜ', 'ㄠ', 'ㄤ']),
    (3.33, ['ㄈ', 'ㄌ', 'ㄏ', 'ㄒ', 'ㄖ', 'ㄙ', 'ㄩ', 'ㄝ', 'ㄡ', 'ㄥ', '⌫']),
  ];
  static const _rowTops = [52.3, 95.0, 137.3, 179.0];
  static const _keyWidth = 29.33;
  static const _keyGap = 6.33;
  static const _keyHeight = 33.5;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 12,
          top: 0,
          height: 49,
          right: 54,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: SizedBox(
              height: 49,
              child: Row(
                children: [
                  for (final c in candidates) ...[
                    Text(c, style: _text.copyWith(fontSize: 18)),
                    const SizedBox(width: 23),
                  ],
                ],
              ),
            ),
          ),
        ),
        const Positioned(left: 347.7, top: 8, width: 1, height: 33, child: ColoredBox(color: Color(0x33000000))),
        const Positioned(left: 357, top: 9, child: Icon(Icons.keyboard_arrow_down_rounded, size: 32, color: Colors.black)),
        for (final (r, (left, keys)) in _rows.indexed)
          for (final (i, k) in keys.indexed)
            k == '⌫'
                ? _key(left + i * (_keyWidth + _keyGap), _rowTops[r], _keyWidth, _keyHeight,
                    color: _special, child: const Icon(Icons.backspace_outlined, size: 20, color: Colors.black))
                : _key(left + i * (_keyWidth + _keyGap), _rowTops[r], _keyWidth, _keyHeight, child: _label(k)),
        _key(3.33, 221.3, 42.3, 35.3, color: _special, child: _label('123', size: 17)),
        _key(51.7, 221.3, 43.3, 35.3, color: _special, child: const Icon(Icons.emoji_emotions, size: 25, color: Colors.black)),
        _key(
          100,
          221.3,
          192,
          35.3,
          child: newline
              ? Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 0, 10, 4),
                    child: Text('注', style: _text.copyWith(fontSize: 10, color: const Color(0xFF8E8E93))),
                  ),
                )
              : _label('空格', size: 17),
        ),
        newline
            ? _key(297.7, 221.3, 92.3, 35.3, color: _special, child: const Icon(Icons.keyboard_return_rounded, size: 24, color: Colors.black))
            : _key(297.7, 221.3, 92.3, 35.3, color: _blue, child: _label('完成', size: 17, color: Colors.white)),
        const Positioned(left: 27, top: 281, child: Icon(Icons.language, size: 29, color: Color(0xFF1C1C1E))),
        _mic,
      ],
    );
  }
}
