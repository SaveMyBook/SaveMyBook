// 系統簡介影片第二版截圖的自我驗收：flutter test tool/video_shots/verify_test.dart
// 1. 去背元件貼到洋紅色底上（原尺寸與放大 2 倍），供逐張檢查邊緣。
// 2. 去背元件依 cuts.json 貼回所屬畫面，與無損原畫面逐像素比較：
//    不透明部分直接比對；半透明邊緣以「元件 + (1 − α) × 周圍底色」重建後比對，底色取元件外框內 α = 0 的原畫面像素。
// 3. 所有畫面拼成總覽圖。結果寫入 VIDEO_REPORT（預設 scratchpad 的 shots_v2）。

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'video_host.dart' show videoOutDir, videoVerifyDir;

final _reportDir = Platform.environment['VIDEO_REPORT'] ?? Directory(videoVerifyDir).parent.path;

void main() {
  test('去背元件與畫面驗收', () {
    final cuts = jsonDecode(File('$videoOutDir/cuts.json').readAsStringSync()) as Map<String, dynamic>;
    final screens = jsonDecode(File('$videoOutDir/screens.json').readAsStringSync()) as Map<String, dynamic>;
    final magentaDir = Directory('$_reportDir/magenta')..createSync(recursive: true);
    final report = StringBuffer('元件\t畫面\t不透明像素\t不透明最大差\t不透明平均差\t差大於2的像素\t邊緣像素\t邊緣最大差\t邊緣99%差\t四角透明\n');
    final problems = <String>[];
    final tiles = <img.Image>[];
    final cache = <String, img.Image>{};

    for (final entry in cuts.entries) {
      final name = entry.key;
      final c = entry.value as Map<String, dynamic>;
      final cut = img.decodePng(File('$videoOutDir/cuts/$name.png').readAsBytesSync())!;
      final screen = cache.putIfAbsent(c['screen'] as String, () => img.decodePng(File('$videoVerifyDir/${c['screen']}.png').readAsBytesSync())!);
      final px = c['px'] as Map<String, dynamic>;
      final ox = px['x'] as int;
      final oy = px['y'] as int;
      if (cut.width != px['w'] || cut.height != px['h']) problems.add('$name 尺寸與 cuts.json 不符');
      if (((c['x'] as num) * 3 - ox).abs() > 0.01 || ((c['y'] as num) * 3 - oy).abs() > 0.01) problems.add('$name 的 x、y 與 px 不一致');

      // 周圍底色：元件外框內、元件完全透明處的原畫面像素中位數
      final bg = <List<int>>[[], [], []];
      for (var y = 0; y < cut.height; y++) {
        for (var x = 0; x < cut.width; x++) {
          if (cut.getPixel(x, y).a == 0) {
            final o = screen.getPixel(ox + x, oy + y);
            bg[0].add(o.r.toInt());
            bg[1].add(o.g.toInt());
            bg[2].add(o.b.toInt());
          }
        }
      }
      int median(List<int> v) => v.isEmpty ? -1 : (v..sort())[v.length ~/ 2];
      final b = [median(bg[0]), median(bg[1]), median(bg[2])];

      var opaque = 0, opaqueMax = 0, opaqueSum = 0, opaqueOver = 0, edge = 0, edgeMax = 0;
      final edgeDiffs = <int>[];
      for (var y = 0; y < cut.height; y++) {
        for (var x = 0; x < cut.width; x++) {
          final p = cut.getPixel(x, y);
          final a = p.a.toInt();
          if (a == 0) continue;
          final o = screen.getPixel(ox + x, oy + y);
          final oc = [o.r.toInt(), o.g.toInt(), o.b.toInt()];
          final pc = [p.r.toInt(), p.g.toInt(), p.b.toInt()];
          if (a == 255) {
            opaque++;
            final d = [for (var i = 0; i < 3; i++) (pc[i] - oc[i]).abs()].reduce(math.max);
            opaqueMax = math.max(opaqueMax, d);
            opaqueSum += d;
            if (d > 2) opaqueOver++;
          } else {
            edge++;
            if (b[0] < 0) continue;
            final af = a / 255;
            final d = [for (var i = 0; i < 3; i++) (pc[i] * af + b[i] * (1 - af) - oc[i]).abs().round()].reduce(math.max);
            edgeMax = math.max(edgeMax, d);
            edgeDiffs.add(d);
          }
        }
      }
      edgeDiffs.sort();
      final edge99 = edgeDiffs.isEmpty ? 0 : edgeDiffs[(edgeDiffs.length * 0.99).floor().clamp(0, edgeDiffs.length - 1)];
      final r = c['r'];
      final roundCorners = r == 'circle' || (r is num && r >= 2);
      final corners = [cut.getPixel(0, 0), cut.getPixel(cut.width - 1, 0), cut.getPixel(0, cut.height - 1), cut.getPixel(cut.width - 1, cut.height - 1)];
      final cornersClear = !roundCorners || corners.every((p) => p.a == 0);
      report.writeln(
        '$name\t${c['screen']}\t$opaque\t$opaqueMax\t${opaque == 0 ? 0 : (opaqueSum / opaque).toStringAsFixed(3)}\t$opaqueOver\t$edge\t$edgeMax\t$edge99\t${roundCorners ? (cornersClear ? '是' : '否') : '—'}',
      );
      if (opaqueMax > 8 || opaqueOver > opaque * 0.0001) problems.add('$name 不透明部分與原畫面差異：最大 $opaqueMax、超過 2 的像素 $opaqueOver');
      if (edge99 > 6) problems.add('$name 邊緣重建差（99%）$edge99');
      if (!cornersClear) problems.add('$name 圓角外仍有像素');

      // 洋紅色底：原尺寸與放大 2 倍
      final magenta = img.Image(width: cut.width + 24, height: cut.height + 24);
      img.fill(magenta, color: img.ColorRgb8(255, 0, 255));
      img.compositeImage(magenta, cut, dstX: 12, dstY: 12);
      File('${magentaDir.path}/$name.png').writeAsBytesSync(img.encodePng(magenta));
      final zoom = img.copyResize(magenta, width: magenta.width * 2, height: magenta.height * 2, interpolation: img.Interpolation.nearest);
      File('${magentaDir.path}/${name}_x2.png').writeAsBytesSync(img.encodePng(zoom));
      tiles.add(_labeled(magenta, name));
    }

    File('$_reportDir/cuts_report.tsv').writeAsStringSync(report.toString());
    File('$_reportDir/cuts_overview.png').writeAsBytesSync(img.encodePng(_grid(tiles, columns: 3, cell: 560, background: img.ColorRgb8(60, 60, 60))));

    final shots = <img.Image>[];
    for (final name in screens.keys.where((n) => n.startsWith('v_')).toList()..sort(_storyOrder)) {
      final file = File('$videoOutDir/screens/$name.webp');
      final decoded = img.decodeWebP(file.readAsBytesSync())!;
      shots.add(_labeled(img.copyResize(decoded, width: 393, interpolation: img.Interpolation.average), name));
    }
    File('$_reportDir/screens_overview.png').writeAsBytesSync(img.encodePng(_grid(shots, columns: 6, cell: 400, background: img.ColorRgb8(40, 40, 40))));

    // ignore: avoid_print
    print(report);
    expect(problems, isEmpty, reason: problems.join('\n'));
  });
}

const _order = [
  'v_sell_scan', 'v_sell_scan_ok', 'v_sell_form_empty', 'v_sell_form_lookup', 'v_sell_form_filled', 'v_sell_photos', 'v_sell_ai_loading',
  'v_sell_ai_result', 'v_admin_review', 'v_home', 'v_search', 'v_search_result', 'v_home_rec', 'v_advisor', 'v_chat',
];

int _storyOrder(String a, String b) {
  int rank(String n) {
    final i = _order.lastIndexWhere((p) => n == p || n.startsWith('${p}_'));
    return i < 0 ? 999 : i;
  }

  final r = rank(a).compareTo(rank(b));
  return r != 0 ? r : a.compareTo(b);
}

img.Image _labeled(img.Image src, String label) {
  final out = img.Image(width: src.width, height: src.height + 22);
  img.fill(out, color: img.ColorRgb8(255, 255, 255));
  img.compositeImage(out, src, dstY: 22);
  img.drawString(out, label, font: img.arial14, x: 4, y: 4, color: img.ColorRgb8(0, 0, 0));
  return out;
}

img.Image _grid(List<img.Image> tiles, {required int columns, required int cell, required img.Color background}) {
  final scaled = [for (final t in tiles) t.width > cell ? img.copyResize(t, width: cell, interpolation: img.Interpolation.average) : t];
  final rows = <List<img.Image>>[];
  for (var i = 0; i < scaled.length; i += columns) {
    rows.add(scaled.sublist(i, math.min(i + columns, scaled.length)));
  }
  final heights = [for (final r in rows) r.map((t) => t.height).reduce(math.max)];
  final out = img.Image(width: columns * (cell + 10) + 10, height: heights.fold(10, (s, h) => s + h + 10));
  img.fill(out, color: background);
  var y = 10;
  for (final (i, row) in rows.indexed) {
    for (final (j, t) in row.indexed) {
      img.compositeImage(out, t, dstX: 10 + j * (cell + 10), dstY: y);
    }
    y += heights[i] + 10;
  }
  return out;
}
