import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

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

