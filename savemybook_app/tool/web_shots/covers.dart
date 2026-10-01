import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

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
