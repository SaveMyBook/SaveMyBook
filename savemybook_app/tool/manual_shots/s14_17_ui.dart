// 第 14–17 節截圖用的模擬 iOS 系統畫面（淺色、iOS 26）：密碼欄位的英文鍵盤與檔案分享面板。
// iPhone 的系統語言為英文，系統畫面的文字比照實機使用英文。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'manual_host.dart';

const _text = TextStyle(fontFamily: 'NotoSansTC', color: Colors.black, decoration: TextDecoration.none);

/// 密碼欄位的 iOS 英文鍵盤：上方為「Passwords」自動填入列，右下角為藍色「done」；安全輸入欄位不提供聽寫。
/// 高度與注音鍵盤相同（336pt），按鍵尺寸依 393 寬 iPhone 的英文鍵盤比例。
class IosQwertyKeyboard extends StatelessWidget {
  const IosQwertyKeyboard({super.key});

  static const _background = Color(0xFFD0D3D9);
  static const _special = Color(0xFFACB1BB);
  static const _shadow = Color(0xFF898A8D);
  static const _side = 3.33;
  static const _gap = 6.33;
  static const _keyHeight = 42.0;
  static const _rowTops = [51.0, 105.0, 159.0, 213.0];
  static final _keyWidth = (393 - 2 * _side - 9 * _gap) / 10;

  @override
  Widget build(BuildContext context) {
    Widget key(double left, double top, double width, {String? label, IconData? icon, Color color = Colors.white, Color fg = Colors.black, double size = 23}) =>
        Positioned(
          left: left,
          top: top,
          width: width,
          height: _keyHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
              boxShadow: const [BoxShadow(color: _shadow, offset: Offset(0, 1))],
            ),
            child: Center(
              child: icon != null ? Icon(icon, size: 22, color: fg) : Text(label ?? '', style: _text.copyWith(fontSize: size, color: fg, height: 1.1)),
            ),
          ),
        );
    List<Widget> letters(String keys, double top) {
      final width = keys.length * _keyWidth + (keys.length - 1) * _gap;
      final left = (393 - width) / 2;
      return [
        for (final (i, k) in keys.split('').indexed) key(left + i * (_keyWidth + _gap), top, _keyWidth, label: k),
      ];
    }

    return ColoredBox(
      color: _background,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 46,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.key_rounded, size: 20, color: Colors.black),
                const SizedBox(width: 6),
                Text('Passwords', style: _text.copyWith(fontSize: 17)),
              ],
            ),
          ),
          ...letters('qwertyuiop', _rowTops[0]),
          ...letters('asdfghjkl', _rowTops[1]),
          key(_side, _rowTops[2], 44, icon: Icons.arrow_upward_rounded, color: _special),
          ...letters('zxcvbnm', _rowTops[2]),
          key(393 - _side - 44, _rowTops[2], 44, icon: Icons.backspace_outlined, color: _special),
          key(_side, _rowTops[3], 92, label: '123', color: _special, size: 17),
          key(_side + 92 + _gap, _rowTops[3], 393 - 2 * _side - 2 * 92 - 2 * _gap, label: 'space', size: 17),
          key(393 - _side - 92, _rowTops[3], 92, label: 'done', color: const Color(0xFF0A84FF), fg: Colors.white, size: 17),
          const Positioned(left: 27, top: 281, child: Icon(Icons.language, size: 29, color: Color(0xFF1C1C1E))),
        ],
      ),
    );
  }
}

/// 顯示英文鍵盤：App 依鍵盤高度縮減可用空間（與 showKeyboard 相同的高度）。
void showQwertyKeyboard(WidgetTester tester) {
  tester.view
    ..viewInsets = const FakeViewPadding(bottom: keyboardHeight * pixelRatio)
    ..padding = const FakeViewPadding(top: topInset * pixelRatio);
  systemOverlay.value = [
    ...systemOverlay.value,
    const Positioned(left: 0, right: 0, bottom: 0, height: keyboardHeight, child: IosQwertyKeyboard()),
  ];
}

/// iOS 26 分享面板（分享檔案）：上方為檔名與大小、右上圓形關閉鈕，下方為 App 列與動作清單。
class IosFileShareSheet extends StatelessWidget {
  final String fileName;
  final String detail;

  const IosFileShareSheet({super.key, required this.fileName, required this.detail});

  @override
  Widget build(BuildContext context) {
    const apps = [
      ('AirDrop', Color(0xFF1E90FF), Icons.wifi_tethering),
      ('Messages', Color(0xFF34C759), Icons.chat_bubble),
      ('Mail', Color(0xFF1A8CFF), Icons.mail),
      ('LINE', Color(0xFF06C755), Icons.chat),
      ('Notes', Color(0xFFFFCC00), Icons.edit_note),
    ];
    const actions = [
      ('Copy', Icons.copy_rounded),
      ('New Quick Note', Icons.note_alt_outlined),
      ('Save to Files', Icons.folder_outlined),
    ];
    return ColoredBox(
      color: const Color(0x1F000000),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: 456,
          margin: const EdgeInsets.fromLTRB(9, 0, 9, 9),
          decoration: BoxDecoration(
            color: const Color(0xFFEDEDF0),
            borderRadius: BorderRadius.circular(48),
            boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 30, offset: Offset(0, -2))],
          ),
          clipBehavior: Clip.antiAlias,
          child: DefaultTextStyle(
            style: _text.copyWith(fontSize: 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 16, 14),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFD1D1D6)),
                        ),
                        padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final w in [22.0, 16.0, 24.0, 12.0, 20.0, 18.0, 14.0])
                              Padding(
                                padding: const EdgeInsets.only(bottom: 3),
                                child: Container(width: w, height: 1.6, color: const Color(0xFFAEAEB2)),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(detail, style: const TextStyle(fontSize: 14, color: Color(0xFF8E8E93))),
                          ],
                        ),
                      ),
                      Container(
                        width: 42,
                        height: 42,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Color(0x1A000000), blurRadius: 6)],
                        ),
                        child: const Icon(Icons.close_rounded, size: 26, color: Colors.black),
                      ),
                    ],
                  ),
                ),
                Container(height: 0.5, margin: const EdgeInsets.symmetric(horizontal: 20), color: const Color(0x4D3C3C43)),
                // App 列可左右捲動，最右側的圖示只露出一部分
                SizedBox(
                  height: 120,
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      for (final (i, (name, color, icon)) in apps.indexed)
                        Positioned(
                          left: 22 + i * 84.0,
                          top: 18,
                          width: 62,
                          child: Column(
                            children: [
                              Container(
                                width: 62,
                                height: 62,
                                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(15)),
                                child: Icon(icon, color: Colors.white, size: 34),
                              ),
                              const SizedBox(height: 6),
                              Text(name, maxLines: 1, softWrap: false, overflow: TextOverflow.visible, style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26)),
                  child: Column(
                    children: [
                      for (final (i, (label, icon)) in actions.indexed) ...[
                        if (i > 0) Container(height: 0.5, margin: const EdgeInsets.symmetric(horizontal: 20), color: const Color(0x4D3C3C43)),
                        SizedBox(
                          height: 52,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(children: [Text(label, style: const TextStyle(fontSize: 17)), const Spacer(), Icon(icon, size: 23)]),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26)),
                  child: const Text('Edit Actions...', style: TextStyle(fontSize: 17, color: Color(0xFF0A84FF))),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
