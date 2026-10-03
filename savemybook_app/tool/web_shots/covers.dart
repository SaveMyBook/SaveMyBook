import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:savemybook_app/utils/api_helpers.dart';

import 'demo_data.dart';

Future<void> loadAppFonts() async {
  final manifest = jsonDecode(await rootBundle.loadString('FontManifest.json')) as List<dynamic>;
  final noto = <Future<ByteData>>[];
  for (final family in manifest.cast<Map<String, dynamic>>()) {
    final name = family['family'] as String;
    final loader = FontLoader(name);
    for (final font in (family['fonts'] as List).cast<Map<String, dynamic>>()) {
      final data = rootBundle.load(font['asset'] as String);
      loader.addFont(data);
      if (name == 'NotoSansTC') noto.add(data);
    }
    await loader.load();
  }
  for (final alias in ['Roboto', 'CupertinoSystemText', 'CupertinoSystemDisplay']) {
    final loader = FontLoader(alias);
    for (final data in noto) {
      loader.addFont(data);
    }
    await loader.load();
  }
}

ui.Image paintCover(DemoBook book, {int width = 600, int height = 800}) {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final w = width.toDouble();
  final h = height.toDouble();
  final base = book.color;
  final dark = base.computeLuminance() < 0.42;
  final ink = dark ? const Color(0xFFFFFFFF) : const Color(0xFF1F2328);
  final soft = ink.withValues(alpha: 0.72);

  canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = base);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, w, h),
    Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(w, h),
        [const Color(0x14FFFFFF), const Color(0x00FFFFFF), const Color(0x1A000000)],
        [0, 0.5, 1],
      ),
  );
  canvas.drawRect(Rect.fromLTWH(0, 0, w * 0.035, h), Paint()..color = const Color(0x22000000));

  final bandTop = h * 0.075;
  final bandHeight = h * 0.085;
  canvas.drawRect(Rect.fromLTWH(w * 0.035, bandTop, w * 0.965, bandHeight), Paint()..color = book.accent);
  _text(
    canvas,
    book.series,
    Offset(w * 0.11, bandTop + bandHeight * 0.2),
    w * 0.8,
    size: bandHeight * 0.42,
    weight: FontWeight.w700,
    color: _onAccent(book.accent),
    spacing: 6,
  );

  final titleWidth = w * 0.8;
  final titleSize = w * math.min(0.125, 0.78 / book.coverTitle.length);
  final title = _paragraph(book.coverTitle, titleWidth, size: titleSize, weight: FontWeight.w800, color: ink, height: 1.22);
  final titleTop = h * 0.36 - title.height / 2;
  canvas.drawParagraph(title, Offset(w * 0.11, titleTop));
  title.dispose();

  canvas.drawRect(Rect.fromLTWH(w * 0.11, h * 0.36 + titleSize * 1.2, w * 0.14, h * 0.008), Paint()..color = book.accent);

  if (book.edition.isNotEmpty) {
    _text(
      canvas,
      book.edition,
      Offset(w * 0.11, h * 0.36 + titleSize * 1.2 + h * 0.03),
      titleWidth,
      size: w * 0.05,
      weight: FontWeight.w500,
      color: soft,
    );
  }

  final motif = Paint()
    ..color = ink.withValues(alpha: 0.10)
    ..style = PaintingStyle.stroke
    ..strokeWidth = w * 0.012;
  final center = Offset(w * 0.78, h * 0.72);
  for (var i = 0; i < 3; i++) {
    canvas.drawCircle(center, w * (0.1 + i * 0.07), motif);
  }
  canvas.drawLine(Offset(w * 0.6, h * 0.72), Offset(w * 0.96, h * 0.72), motif);
  canvas.drawLine(center.translate(0, -w * 0.18), center.translate(0, w * 0.18), motif);

  _text(canvas, book.author, Offset(w * 0.11, h * 0.84), titleWidth, size: w * 0.048, weight: FontWeight.w600, color: ink);
  _text(canvas, book.publisher, Offset(w * 0.11, h * 0.9), titleWidth, size: w * 0.04, weight: FontWeight.w400, color: soft);

  final picture = recorder.endRecording();
  final image = picture.toImageSync(width, height);
  picture.dispose();
  return image;
}

Color _onAccent(Color accent) => accent.computeLuminance() > 0.5 ? const Color(0xFF2B2B2B) : const Color(0xFFFFFFFF);

ui.Paragraph _paragraph(
  String text,
  double width, {
  required double size,
  required FontWeight weight,
  required Color color,
  double height = 1.3,
  double spacing = 0,
}) {
  final builder = ui.ParagraphBuilder(ui.ParagraphStyle(fontFamily: 'NotoSansTC', textDirection: TextDirection.ltr, maxLines: 3))
    ..pushStyle(
      ui.TextStyle(fontFamily: 'NotoSansTC', fontSize: size, fontWeight: weight, color: color, height: height, letterSpacing: spacing),
    )
    ..addText(text);
  final paragraph = builder.build()..layout(ui.ParagraphConstraints(width: width));
  return paragraph;
}

void _text(
  ui.Canvas canvas,
  String text,
  Offset at,
  double width, {
  required double size,
  required FontWeight weight,
  required Color color,
  double spacing = 0,
}) {
  if (text.isEmpty) return;
  final paragraph = _paragraph(text, width, size: size, weight: weight, color: color, spacing: spacing);
  canvas.drawParagraph(paragraph, at);
  paragraph.dispose();
}

ui.Image paintPhoto(DemoBook book, String kind, {int width = 900, int height = 1200}) {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final w = width.toDouble();
  final h = height.toDouble();
  canvas.drawRect(
    Rect.fromLTWH(0, 0, w, h),
    Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(w, h), const [Color(0xFFD9CBB5), Color(0xFFB9A88F)]),
  );
  final rng = math.Random(kind.hashCode);
  final grain = Paint()..color = const Color(0x0F000000);
  for (var i = 0; i < 40; i++) {
    canvas.drawLine(Offset(0, rng.nextDouble() * h), Offset(w, rng.nextDouble() * h), grain..strokeWidth = rng.nextDouble() * 3);
  }
  final rect = Rect.fromCenter(center: Offset(w / 2, h / 2), width: w * 0.74, height: w * 0.74 * 4 / 3);
  canvas.drawRRect(
    RRect.fromRectAndRadius(rect.shift(const Offset(14, 18)), const Radius.circular(10)),
    Paint()
      ..color = const Color(0x40000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
  );
  canvas.save();
  canvas.clipRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)));
  if (kind == 'cover') {
    final cover = paintCover(book, width: rect.width.round(), height: rect.height.round());
    canvas.drawImage(cover, rect.topLeft, Paint());
    cover.dispose();
  } else {
    canvas.drawRect(rect, Paint()..color = book.color);
    final text = _paragraph(
      kind == 'back' ? book.description : book.isbn,
      rect.width * 0.76,
      size: rect.width * 0.05,
      weight: FontWeight.w500,
      color: const Color(0xE6FFFFFF),
      height: 1.6,
    );
    canvas.drawParagraph(text, Offset(rect.left + rect.width * 0.12, rect.top + rect.height * 0.14));
    text.dispose();
    final code = Rect.fromLTWH(rect.left + rect.width * 0.5, rect.bottom - rect.height * 0.24, rect.width * 0.4, rect.height * 0.15);
    canvas.drawRect(code, Paint()..color = const Color(0xFFFFFFFF));
    final bars = math.Random(book.isbn.hashCode);
    var x = code.left + code.width * 0.08;
    while (x < code.right - code.width * 0.08) {
      final bw = 1.5 + bars.nextInt(3) * 1.5;
      canvas.drawRect(Rect.fromLTWH(x, code.top + code.height * 0.12, bw, code.height * 0.62), Paint()..color = const Color(0xFF111111));
      x += bw + 1.5 + bars.nextInt(3) * 1.5;
    }
  }
  canvas.restore();
  final picture = recorder.endRecording();
  final image = picture.toImageSync(width, height);
  picture.dispose();
  return image;
}

ui.Image _framedPhoto(String seed, void Function(ui.Canvas canvas, Rect rect) content, {double tilt = 0}) {
  const width = 900;
  const height = 1200;
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  const w = 900.0;
  const h = 1200.0;
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, w, h),
    Paint()..shader = ui.Gradient.linear(Offset.zero, const Offset(w, h), const [Color(0xFFD9CBB5), Color(0xFFB9A88F)]),
  );
  final rng = math.Random(seed.hashCode);
  final grain = Paint()..color = const Color(0x0F000000);
  for (var i = 0; i < 40; i++) {
    canvas.drawLine(Offset(0, rng.nextDouble() * h), Offset(w, rng.nextDouble() * h), grain..strokeWidth = rng.nextDouble() * 3);
  }
  final rect = Rect.fromCenter(center: const Offset(w / 2, h / 2), width: w * 0.8, height: w * 0.8 * 4 / 3);
  canvas.save();
  canvas.translate(w / 2, h / 2);
  canvas.rotate(tilt);
  canvas.translate(-w / 2, -h / 2);
  canvas.drawRRect(
    RRect.fromRectAndRadius(rect.shift(const Offset(14, 18)), const Radius.circular(10)),
    Paint()
      ..color = const Color(0x40000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
  );
  canvas.clipRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)));
  content(canvas, rect);
  canvas.restore();
  final picture = recorder.endRecording();
  final image = picture.toImageSync(width, height);
  picture.dispose();
  return image;
}

void _barcode(ui.Canvas canvas, Rect code, int seed) {
  canvas.drawRect(code, Paint()..color = const Color(0xFFFFFFFF));
  final bars = math.Random(seed);
  var x = code.left + code.width * 0.08;
  while (x < code.right - code.width * 0.08) {
    final bw = 1.5 + bars.nextInt(3) * 1.5;
    canvas.drawRect(Rect.fromLTWH(x, code.top + code.height * 0.12, bw, code.height * 0.62), Paint()..color = const Color(0xFF111111));
    x += bw + 1.5 + bars.nextInt(3) * 1.5;
  }
}

// 封底貼有圖書館館藏標籤與館藏章的照片，用於上架審核畫面。
ui.Image paintLibraryBack(DemoBook book, String synopsis) => _framedPhoto('library-${book.id}', (canvas, rect) {
  canvas.drawRect(rect, Paint()..color = book.color);
  final text = _paragraph(synopsis, rect.width * 0.76, size: rect.width * 0.045, weight: FontWeight.w500, color: const Color(0xE6FFFFFF), height: 1.6);
  canvas.drawParagraph(text, Offset(rect.left + rect.width * 0.12, rect.top + rect.height * 0.42));
  text.dispose();
  _barcode(canvas, Rect.fromLTWH(rect.left + rect.width * 0.5, rect.bottom - rect.height * 0.2, rect.width * 0.4, rect.height * 0.13), book.isbn.hashCode);

  final label = Rect.fromLTWH(rect.left + rect.width * 0.1, rect.top + rect.height * 0.07, rect.width * 0.52, rect.height * 0.26);
  canvas.drawRRect(
    RRect.fromRectAndRadius(label.shift(const Offset(3, 4)), const Radius.circular(6)),
    Paint()
      ..color = const Color(0x33000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
  );
  canvas.drawRRect(RRect.fromRectAndRadius(label, const Radius.circular(6)), Paint()..color = const Color(0xFFF7F5EF));
  canvas.drawRect(Rect.fromLTWH(label.left, label.top, label.width, label.height * 0.2), Paint()..color = const Color(0xFF2F5D8A));
  _text(canvas, '圖書館 館藏', Offset(label.left + label.width * 0.08, label.top + label.height * 0.03), label.width,
      size: label.height * 0.11, weight: FontWeight.w700, color: const Color(0xFFFFFFFF), spacing: 2);
  _barcode(canvas, Rect.fromLTWH(label.left + label.width * 0.08, label.top + label.height * 0.27, label.width * 0.84, label.height * 0.38), 7310);
  _text(canvas, '346.1 8472  c.2', Offset(label.left + label.width * 0.08, label.top + label.height * 0.7), label.width,
      size: label.height * 0.12, weight: FontWeight.w600, color: const Color(0xFF333333));

  final stamp = Offset(rect.left + rect.width * 0.76, rect.top + rect.height * 0.2);
  final ink = Paint()
    ..color = const Color(0xB3C0392B)
    ..style = PaintingStyle.stroke
    ..strokeWidth = rect.width * 0.012;
  canvas.drawCircle(stamp, rect.width * 0.11, ink);
  canvas.drawCircle(stamp, rect.width * 0.088, ink..strokeWidth = rect.width * 0.005);
  final mark = _paragraph('館藏', rect.width, size: rect.width * 0.06, weight: FontWeight.w800, color: const Color(0xB3C0392B));
  canvas.drawParagraph(mark, stamp - Offset(mark.maxIntrinsicWidth / 2, mark.height / 2));
  mark.dispose();
});

// 書本內頁照片；marked 為買家佐證照片中的大量螢光筆畫線與筆記。
ui.Image paintInsidePage(DemoBook book, {required String heading, required String body, required int seed, bool marked = false}) =>
    _framedPhoto('page-${book.id}-$seed', tilt: marked ? -0.035 : 0.02, (canvas, rect) {
      canvas.drawRect(rect, Paint()..color = const Color(0xFFF6F1E6));
      canvas.drawRect(
        Rect.fromLTWH(rect.left, rect.top, rect.width * 0.12, rect.height),
        Paint()..shader = ui.Gradient.linear(rect.topLeft, Offset(rect.left + rect.width * 0.12, rect.top), const [Color(0x33000000), Color(0x00000000)]),
      );
      final left = rect.left + rect.width * 0.12;
      final width = rect.width * 0.78;
      final title = _paragraph(heading, width, size: rect.width * 0.055, weight: FontWeight.w700, color: const Color(0xFF2B2B2B));
      final titleTop = rect.top + rect.height * 0.08;
      canvas.drawParagraph(title, Offset(left, titleTop));
      final bodyTop = titleTop + title.height + rect.height * 0.04;
      title.dispose();

      final builder = ui.ParagraphBuilder(ui.ParagraphStyle(fontFamily: 'NotoSansTC', textDirection: TextDirection.ltr))
        ..pushStyle(ui.TextStyle(fontFamily: 'NotoSansTC', fontSize: rect.width * 0.037, color: const Color(0xFF3A3A3A), height: 1.9))
        ..addText(body);
      final paragraph = builder.build()..layout(ui.ParagraphConstraints(width: width));
      final lines = paragraph.computeLineMetrics();
      if (marked) {
        final rng = math.Random(seed);
        final highlight = Paint()..color = const Color(0x80FFE14D);
        for (final line in lines) {
          if (rng.nextDouble() < 0.3) continue;
          final start = rng.nextDouble() < 0.5 ? 0.0 : line.width * rng.nextDouble() * 0.4;
          final end = rng.nextDouble() < 0.6 ? line.width : start + (line.width - start) * (0.5 + rng.nextDouble() * 0.5);
          final top = bodyTop + line.baseline - line.ascent * 1.05;
          canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTRB(left + start - 4, top, left + end + 4, top + line.ascent * 1.35), const Radius.circular(4)),
            highlight,
          );
        }
      }
      canvas.drawParagraph(paragraph, Offset(left, bodyTop));
      if (marked) {
        final pen = Paint()
          ..color = const Color(0xCC1F4FA8)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = rect.width * 0.006;
        final rng = math.Random(seed * 7);
        for (final line in lines.where((l) => l.lineNumber.isOdd)) {
          final y = bodyTop + line.baseline + 6;
          final path = Path()..moveTo(left, y);
          for (var x = 0.0; x < line.width * 0.8; x += 18) {
            path.lineTo(left + x, y + (rng.nextDouble() - 0.5) * 3);
          }
          canvas.drawPath(path, pen);
        }
        final note = Path();
        final noteTop = bodyTop + paragraph.height + rect.height * 0.04;
        for (var row = 0; row < 3; row++) {
          final y = noteTop + row * rect.height * 0.045;
          note.moveTo(left + rect.width * 0.04, y);
          for (var x = 0.0; x < width * (0.75 - row * 0.15); x += 10) {
            note.lineTo(left + rect.width * 0.04 + x, y + math.sin(x / 7 + row) * 6);
          }
        }
        canvas.drawPath(note, pen..color = const Color(0xCC2B2B2B));
      }
      paragraph.dispose();
      final folio = _paragraph('$seed', rect.width, size: rect.width * 0.032, weight: FontWeight.w400, color: const Color(0xFF8A8577));
      canvas.drawParagraph(folio, Offset(rect.right - rect.width * 0.12, rect.bottom - rect.height * 0.07));
      folio.dispose();
    });

final Map<String, ui.Image> _photos = {};

// 以 cacheWidth 縮圖顯示的圖片（例如 AdminImageStrip）實際以 ResizeImage 為快取鍵，須一併放入快取。
void seedPhoto(String path, ui.Image Function() paint, {List<int> cacheWidths = const []}) {
  final url = resolveAssetUrl(path)!;
  final image = _photos.putIfAbsent(url, paint);
  final cache = PaintingBinding.instance.imageCache;
  for (final provider in <ImageProvider<Object>>[
    NetworkImage(url),
    for (final width in cacheWidths) ResizeImage(NetworkImage(url), width: width),
  ]) {
    provider.obtainKey(ImageConfiguration.empty).then((key) {
      cache.evict(key);
      cache.putIfAbsent(key, () => OneFrameImageStreamCompleter(SynchronousFuture(ImageInfo(image: image.clone()))));
    });
  }
}

final Map<String, ui.Image> _covers = {};

void seedCoverCache() {
  final cache = PaintingBinding.instance.imageCache;
  for (final book in demoBooks) {
    final image = _covers.putIfAbsent(book.coverUrl, () => paintCover(book));
    final provider = NetworkImage(book.coverUrl);
    cache.evict(provider);
    cache.putIfAbsent(provider, () => OneFrameImageStreamCompleter(SynchronousFuture(ImageInfo(image: image.clone()))));
  }
}

Future<Uint8List> pngBytes(ui.Image image) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

ui.Image paintCameraScene(Size size, Offset frameCenter, double frame, {double scale = 3}) {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder)..scale(scale);
  final bounds = Offset.zero & size;

  canvas.drawRect(
    bounds,
    Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(0, size.height),
        const [Color(0xFF4A463E), Color(0xFF2B2C2E), Color(0xFF1E1F21)],
        [0, 0.55, 1],
      ),
  );
  final glow = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);
  canvas.drawCircle(Offset(size.width * 0.12, size.height * 0.08), 110, glow..color = const Color(0x66C9A66B));
  canvas.drawCircle(Offset(size.width * 0.95, size.height * 0.2), 90, glow..color = const Color(0x405F7F8F));
  canvas.drawRect(Rect.fromLTWH(0, size.height * 0.82, size.width, size.height * 0.18), Paint()..color = const Color(0x33000000));

  final body = Rect.fromCenter(center: frameCenter.translate(0, frame * 0.62), width: frame * 1.36, height: frame * 2.3);
  canvas.drawRRect(
    RRect.fromRectAndRadius(body.shift(const Offset(0, 10)), const Radius.circular(18)),
    Paint()
      ..color = const Color(0x66000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(body, const Radius.circular(18)),
    Paint()..shader = ui.Gradient.linear(body.topLeft, body.bottomRight, const [Color(0xFF59616A), Color(0xFF3E444B)]),
  );
  final seam = Paint()
    ..color = const Color(0x55000000)
    ..strokeWidth = 1.4;
  final doorsTop = frameCenter.dy + frame * 0.56;
  canvas.drawLine(Offset(body.left + 10, doorsTop), Offset(body.right - 10, doorsTop), seam);
  canvas.drawLine(Offset(body.center.dx, doorsTop), Offset(body.center.dx, body.bottom - 10), seam);
  canvas.drawLine(Offset(body.left + 10, doorsTop + frame * 0.55), Offset(body.right - 10, doorsTop + frame * 0.55), seam);

  final screen = Rect.fromCenter(center: frameCenter, width: frame * 0.8, height: frame * 0.86);
  canvas.drawRRect(RRect.fromRectAndRadius(screen.inflate(6), const Radius.circular(14)), Paint()..color = const Color(0xFF16181A));
  canvas.drawRRect(
    RRect.fromRectAndRadius(screen, const Radius.circular(10)),
    Paint()..shader = ui.Gradient.linear(screen.topLeft, screen.bottomRight, const [Color(0xFFF1F4F5), Color(0xFFD9DFE2)]),
  );
  final title = _paragraph('圖書館大廳', screen.width, size: frame * 0.055, weight: FontWeight.w700, color: const Color(0xFF51606B));
  canvas.drawParagraph(title, Offset(screen.center.dx - title.maxIntrinsicWidth / 2, screen.top + frame * 0.045));
  title.dispose();
  final qrSize = frame * 0.52;
  canvas.save();
  canvas.translate(screen.center.dx - qrSize / 2, screen.center.dy - qrSize / 2 + frame * 0.005);
  QrPainter(
    data: 'NMIXX HAEWON 0225',
    version: QrVersions.auto,
    gapless: true,
    eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF1C2226)),
    dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF1C2226)),
  ).paint(canvas, Size.square(qrSize));
  canvas.restore();
  final hint = _paragraph('請以 App 掃描', screen.width, size: frame * 0.045, weight: FontWeight.w500, color: const Color(0xFF6B7782));
  canvas.drawParagraph(hint, Offset(screen.center.dx - hint.maxIntrinsicWidth / 2, screen.bottom - frame * 0.115));
  hint.dispose();

  canvas.drawRect(
    bounds,
    Paint()..shader = ui.Gradient.radial(bounds.center, size.longestSide * 0.62, const [Color(0x00000000), Color(0x8C000000)], [0.55, 1]),
  );
  final picture = recorder.endRecording();
  final image = picture.toImageSync((size.width * scale).round(), (size.height * scale).round());
  picture.dispose();
  return image;
}
