import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'covers.dart';
import 'intro_data.dart';

ui.Paragraph _paragraph(String text, double width, {required double size, required FontWeight weight, required Color color, double height = 1.3}) {
  final builder = ui.ParagraphBuilder(ui.ParagraphStyle(fontFamily: 'NotoSansTC', textDirection: TextDirection.ltr, maxLines: 3))
    ..pushStyle(ui.TextStyle(fontFamily: 'NotoSansTC', fontSize: size, fontWeight: weight, color: color, height: height))
    ..addText(text);
  return builder.build()..layout(ui.ParagraphConstraints(width: width));
}

final Map<String, ui.Image> _covers = {};

void seedIntroCovers() {
  final cache = PaintingBinding.instance.imageCache;
  for (final book in introBooks) {
    final image = _covers.putIfAbsent(book.coverUrl, () => paintCover(book.paintable));
    final provider = NetworkImage(book.coverUrl);
    cache.evict(provider);
    cache.putIfAbsent(provider, () => OneFrameImageStreamCompleter(SynchronousFuture(ImageInfo(image: image.clone()))));
  }
}

ui.Image paintFramedPage(String seed, void Function(ui.Canvas canvas, Rect rect) content, {double tilt = 0}) {
  const width = 900;
  const height = 1200;
  const w = 900.0;
  const h = 1200.0;
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, w, h),
    Paint()..shader = ui.Gradient.linear(Offset.zero, const Offset(w, h), const [Color(0xFFD9CBB5), Color(0xFFB9A88F)]),
  );
  final rng = math.Random(seed.hashCode);
  final grain = Paint()..color = const Color(0x0F000000);
  for (var i = 0; i < 40; i++) {
    canvas.drawLine(Offset(0, rng.nextDouble() * h), Offset(w, rng.nextDouble() * h), grain..strokeWidth = rng.nextDouble() * 3);
  }
  final rect = Rect.fromCenter(center: const Offset(w / 2, h / 2), width: w * 0.74, height: w * 0.74 * 4 / 3);
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

ui.Image paintChemistryPage() => paintFramedPage('journey-page', tilt: 0.015, (canvas, rect) {
  canvas.drawRect(rect, Paint()..color = const Color(0xFFF6F1E6));
  canvas.drawRect(
    Rect.fromLTWH(rect.left, rect.top, rect.width * 0.12, rect.height),
    Paint()..shader = ui.Gradient.linear(rect.topLeft, Offset(rect.left + rect.width * 0.12, rect.top), const [Color(0x33000000), Color(0x00000000)]),
  );
  final left = rect.left + rect.width * 0.12;
  final width = rect.width * 0.78;
  final title = _paragraph('氧化與還原', width, size: rect.width * 0.055, weight: FontWeight.w700, color: const Color(0xFF2B2B2B));
  final titleTop = rect.top + rect.height * 0.08;
  canvas.drawParagraph(title, Offset(left, titleTop));
  final bodyTop = titleTop + title.height + rect.height * 0.04;
  title.dispose();
  const body = '物質失去電子的反應稱為氧化，獲得電子的反應稱為還原，兩者必定同時發生。氧化數是假設化合物中的鍵結皆為離子鍵時，原子所帶的電荷數；'
      '元素態物質的氧化數為零，單原子離子的氧化數等於其電荷。氧化數增加的物質被氧化，本身為還原劑；氧化數減少的物質被還原，本身為氧化劑。';
  final builder = ui.ParagraphBuilder(ui.ParagraphStyle(fontFamily: 'NotoSansTC', textDirection: TextDirection.ltr))
    ..pushStyle(ui.TextStyle(fontFamily: 'NotoSansTC', fontSize: rect.width * 0.037, color: const Color(0xFF3A3A3A), height: 1.9))
    ..addText(body);
  final paragraph = builder.build()..layout(ui.ParagraphConstraints(width: width));
  final lines = paragraph.computeLineMetrics();
  final highlight = Paint()..color = const Color(0x80FFE14D);
  for (final line in lines.where((l) => const [1, 2, 6].contains(l.lineNumber))) {
    final top = bodyTop + line.baseline - line.ascent * 1.05;
    final end = line.lineNumber == 2 ? line.width * 0.55 : line.width;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(left - 4, top, left + end + 4, top + line.ascent * 1.35), const Radius.circular(4)), highlight);
  }
  canvas.drawParagraph(paragraph, Offset(left, bodyTop));
  paragraph.dispose();
  final folio = _paragraph('183', rect.width, size: rect.width * 0.032, weight: FontWeight.w400, color: const Color(0xFF8A8577));
  canvas.drawParagraph(folio, Offset(rect.right - rect.width * 0.14, rect.bottom - rect.height * 0.07));
  folio.dispose();
});

ui.Image paintCameraScene(Size size, Offset frameCenter, double frame, {required String name, double scale = 3}) {
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
  final title = _paragraph(name, screen.width, size: frame * 0.055, weight: FontWeight.w700, color: const Color(0xFF51606B));
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
