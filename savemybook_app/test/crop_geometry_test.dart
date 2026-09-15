import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:savemybook_app/utils/crop_geometry.dart';

const image = Size(4000, 3000);

void expectRect(Rect actual, Rect expected) {
  expect(actual.left, moreOrLessEquals(expected.left, epsilon: 1e-6), reason: 'left of $actual');
  expect(actual.top, moreOrLessEquals(expected.top, epsilon: 1e-6), reason: 'top of $actual');
  expect(actual.right, moreOrLessEquals(expected.right, epsilon: 1e-6), reason: 'right of $actual');
  expect(actual.bottom, moreOrLessEquals(expected.bottom, epsilon: 1e-6), reason: 'bottom of $actual');
}

ui.Image quadrantImage(int w, int h) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(Rect.fromLTWH(0, 0, w / 2, h / 2), Paint()..color = const Color(0xFFFF0000));
  canvas.drawRect(Rect.fromLTWH(w / 2, 0, w / 2, h / 2), Paint()..color = const Color(0xFF00FF00));
  canvas.drawRect(Rect.fromLTWH(0, h / 2, w / 2, h / 2), Paint()..color = const Color(0xFF0000FF));
  canvas.drawRect(Rect.fromLTWH(w / 2, h / 2, w / 2, h / 2), Paint()..color = const Color(0xFFFFFF00));
  return recorder.endRecording().toImageSync(w, h);
}

Future<Color> pixelAt(ui.Picture picture, Size size, Offset p) async {
  final img = await picture.toImage(size.width.round(), size.height.round());
  final data = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final i = (p.dy.floor() * size.width.round() + p.dx.floor()) * 4;
  img.dispose();
  return Color.fromARGB(data.getUint8(i + 3), data.getUint8(i), data.getUint8(i + 1), data.getUint8(i + 2));
}

void main() {
  group('CropGeometry', () {
    test('initial transform covers the frame and shows the centred crop', () {
      const frame = Size(300, 300);
      final t = CropGeometry.initial(image, frame);
      expect(t.scale, 0.1);
      expect(t.offset, Offset.zero);
      expectRect(CropGeometry.visibleRect(t, image, frame), const Rect.fromLTRB(500, 0, 3500, 3000));
      expectRect(CropGeometry.sourceRect(t, image, frame), const Rect.fromLTRB(500, 0, 3500, 3000));
    });

    test('pan translates the visible rect in source pixels', () {
      const frame = Size(300, 300);
      final t = CropGeometry.initial(image, frame).copyWith(offset: const Offset(50, 0));
      expectRect(CropGeometry.sourceRect(t, image, frame), const Rect.fromLTRB(0, 0, 3000, 3000));
    });

    test('zoom narrows the visible rect around the focal point', () {
      const frame = Size(300, 300);
      final base = CropGeometry.initial(image, frame);
      final centred = CropGeometry.zoomAround(base, 0.2, Offset.zero);
      expectRect(CropGeometry.sourceRect(centred, image, frame), const Rect.fromLTRB(1250, 750, 2750, 2250));

      final corner = CropGeometry.zoomAround(base, 0.2, const Offset(-150, -150));
      final rect = CropGeometry.sourceRect(corner, image, frame);
      expect(rect.topLeft, const Offset(500, 0));
      expect(rect.size, const Size(1500, 1500));
    });

    test('clamp keeps the image covering the frame', () {
      const frame = Size(300, 300);
      final clamped = CropGeometry.clamp(
        const CropTransform(scale: 0.05, offset: Offset(900, -900)),
        image,
        frame,
      );
      expect(clamped.scale, 0.1);
      expect(clamped.offset, const Offset(50, 0));
      expectRect(CropGeometry.sourceRect(clamped, image, frame), const Rect.fromLTRB(0, 0, 3000, 3000));

      final zoomed = CropGeometry.clamp(const CropTransform(scale: 99, offset: Offset(-1e6, 1e6)), image, frame);
      expect(zoomed.scale, closeTo(0.6, 1e-9));
      final rect = CropGeometry.sourceRect(zoomed, image, frame);
      expect(rect.right, closeTo(4000, 1e-6));
      expect(rect.top, closeTo(0, 1e-6));
      expect(rect.width, closeTo(500, 1e-6));
    });

    test('source rect never leaves image bounds', () {
      const frame = Size(300, 300);
      const t = CropTransform(scale: 0.1, offset: Offset(400, 0));
      final rect = CropGeometry.sourceRect(t, image, frame);
      expect(rect.left, 0);
      expect(rect.right, lessThanOrEqualTo(4000));
    });

    test('quarter turn clockwise maps the rotated top-left to the source bottom-left', () {
      const frame = Size(300, 400);
      final t = CropGeometry.clamp(
        const CropTransform(scale: 0.2, offset: Offset(1e6, 1e6), quarterTurns: 1),
        image,
        frame,
      );
      expect(t.offset, const Offset(150, 200));
      expectRect(CropGeometry.visibleRect(t, image, frame), const Rect.fromLTRB(0, 0, 1500, 2000));
      expectRect(CropGeometry.sourceRect(t, image, frame), const Rect.fromLTRB(0, 1500, 2000, 3000));
    });

    test('half turn maps the rotated top-left to the source bottom-right', () {
      const frame = Size(300, 300);
      final t = CropGeometry.clamp(
        const CropTransform(scale: 0.2, offset: Offset(1e6, 1e6), quarterTurns: 2),
        image,
        frame,
      );
      expectRect(CropGeometry.sourceRect(t, image, frame), const Rect.fromLTRB(2500, 1500, 4000, 3000));
    });

    test('three quarter turns map the rotated top-left to the source top-right', () {
      const frame = Size(300, 400);
      final t = CropGeometry.clamp(
        const CropTransform(scale: 0.2, offset: Offset(1e6, 1e6), quarterTurns: 3),
        image,
        frame,
      );
      expectRect(CropGeometry.sourceRect(t, image, frame), const Rect.fromLTRB(2000, 0, 4000, 1500));
    });

    test('full rotation of an untouched crop covers the whole rotated image', () {
      const frame = Size(300, 400);
      final t = CropGeometry.initial(image, frame, quarterTurns: 1);
      expect(t.scale, 0.1);
      expectRect(CropGeometry.sourceRect(t, image, frame), const Rect.fromLTRB(0, 0, 4000, 3000));
    });

    test('rotating counter-clockwise keeps relative zoom and stays in bounds', () {
      const frame = Size(300, 200);
      var t = CropGeometry.zoomAround(CropGeometry.initial(image, frame), 0.15, const Offset(40, 20));
      t = CropGeometry.clamp(t, image, frame);
      final relative = t.scale / CropGeometry.minScale(image, frame, 0);

      final once = CropGeometry.rotateCounterClockwise(t, image, frame);
      expect(once.quarterTurns, 3);
      expect(once.scale / CropGeometry.minScale(image, frame, 3), closeTo(relative, 1e-9));
      expect(CropGeometry.isWithinBounds(once, image, frame), isTrue);

      var back = t;
      for (var i = 0; i < 4; i++) {
        back = CropGeometry.rotateCounterClockwise(back, image, frame);
      }
      expect(back.quarterTurns, 0);
      expect(back.scale, closeTo(t.scale, 1e-9));
    });

    test('frame size honours aspect ratio and max side', () {
      expect(CropGeometry.frameSize(const Size(350, 600), 1), const Size(350, 350));
      expect(CropGeometry.frameSize(const Size(350, 300), 4 / 3), const Size(350, 262.5));
      expect(CropGeometry.frameSize(const Size(1200, 900), 1, maxSide: 600), const Size(600, 600));
      expect(CropGeometry.frameSize(const Size(1200, 900), 0.75, maxSide: 600), const Size(450, 600));
    });

    test('output size uses the long side for the given aspect ratio', () {
      expect(CropGeometry.outputSize(1, 1080), const Size(1080, 1080));
      expect(CropGeometry.outputSize(4 / 3, 1200), const Size(1200, 900));
      expect(CropGeometry.outputSize(0.75, 1200), const Size(900, 1200));
    });

    test('rubber band is monotonic and bounded by the dimension', () {
      var last = 0.0;
      for (var x = 10.0; x < 5000; x *= 2) {
        final y = CropGeometry.rubberBand(x, 300);
        expect(y, greaterThan(last));
        expect(y, lessThan(300));
        last = y;
      }
      expect(CropGeometry.rubberBand(-40, 300), -CropGeometry.rubberBand(40, 300));
    });
  });

  group('crop output matches the preview', () {
    for (final turns in [0, 1, 2, 3]) {
      test('quarter turns $turns', () async {
        final img = quadrantImage(400, 300);
        const imageSize = Size(400, 300);
        const frame = Size(120, 120);
        const area = Size(200, 200);
        final center = area.center(Offset.zero);
        final t = CropGeometry.clamp(
          CropGeometry.zoomAround(CropGeometry.initial(imageSize, frame, quarterTurns: turns), 1.2, const Offset(-20, 10)),
          imageSize,
          frame,
        );
        final frameRect = Rect.fromCenter(center: center, width: frame.width, height: frame.height);

        final preview = ui.PictureRecorder();
        CropGeometry.paintPreview(Canvas(preview), img, center, t, turns * math.pi / 2);
        final previewPicture = preview.endRecording();

        const out = Size(240, 240);
        final output = ui.PictureRecorder();
        CropGeometry.paintOutput(Canvas(output), img, t, frame, out);
        final outputPicture = output.endRecording();

        for (final (fx, fy) in [(0.15, 0.15), (0.85, 0.15), (0.15, 0.85), (0.85, 0.85), (0.5, 0.3)]) {
          final shown = await pixelAt(
            previewPicture,
            area,
            Offset(frameRect.left + frame.width * fx, frameRect.top + frame.height * fy),
          );
          final saved = await pixelAt(outputPicture, out, Offset(out.width * fx, out.height * fy));
          expect(saved, shown, reason: 'sample ($fx, $fy) with $turns turns');
        }
        img.dispose();
      });
    }
  });
}
