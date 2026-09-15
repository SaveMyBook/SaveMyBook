import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

@immutable
class CropTransform {
  final double scale;
  final Offset offset;
  final int quarterTurns;

  const CropTransform({required this.scale, this.offset = Offset.zero, this.quarterTurns = 0});

  CropTransform copyWith({double? scale, Offset? offset, int? quarterTurns}) => CropTransform(
    scale: scale ?? this.scale,
    offset: offset ?? this.offset,
    quarterTurns: quarterTurns ?? this.quarterTurns,
  );

  static CropTransform lerp(CropTransform a, CropTransform b, double t) => CropTransform(
    scale: lerpDouble(a.scale, b.scale, t)!,
    offset: Offset.lerp(a.offset, b.offset, t)!,
    quarterTurns: t < 1 ? a.quarterTurns : b.quarterTurns,
  );

  @override
  bool operator ==(Object other) =>
      other is CropTransform && other.scale == scale && other.offset == offset && other.quarterTurns == quarterTurns;

  @override
  int get hashCode => Object.hash(scale, offset, quarterTurns);

  @override
  String toString() => 'CropTransform(scale: $scale, offset: $offset, turns: $quarterTurns)';
}

class CropGeometry {
  const CropGeometry._();

  static const double maxZoom = 6;

  static int normalizeTurns(int turns) => ((turns % 4) + 4) % 4;

  static Size rotatedSize(Size image, int quarterTurns) =>
      normalizeTurns(quarterTurns).isOdd ? Size(image.height, image.width) : image;

  static Size frameSize(Size available, double aspectRatio, {double? maxSide}) {
    var width = available.width;
    var height = width / aspectRatio;
    if (height > available.height) {
      height = available.height;
      width = height * aspectRatio;
    }
    if (maxSide != null) {
      final longest = math.max(width, height);
      if (longest > maxSide) {
        final k = maxSide / longest;
        width *= k;
        height *= k;
      }
    }
    return Size(math.max(0, width), math.max(0, height));
  }

  static double minScale(Size image, Size frame, int quarterTurns) {
    final r = rotatedSize(image, quarterTurns);
    if (r.width <= 0 || r.height <= 0) return 1;
    return math.max(frame.width / r.width, frame.height / r.height);
  }

  static double maxScale(Size image, Size frame, int quarterTurns) => minScale(image, frame, quarterTurns) * maxZoom;

  static Offset maxOffset(Size image, Size frame, double scale, int quarterTurns) {
    final r = rotatedSize(image, quarterTurns);
    return Offset(math.max(0, (r.width * scale - frame.width) / 2), math.max(0, (r.height * scale - frame.height) / 2));
  }

  static CropTransform initial(Size image, Size frame, {int quarterTurns = 0}) =>
      CropTransform(scale: minScale(image, frame, quarterTurns), quarterTurns: normalizeTurns(quarterTurns));

  static CropTransform clamp(CropTransform t, Size image, Size frame) {
    final turns = normalizeTurns(t.quarterTurns);
    final scale = t.scale.clamp(minScale(image, frame, turns), maxScale(image, frame, turns)).toDouble();
    final bound = maxOffset(image, frame, scale, turns);
    return CropTransform(
      scale: scale,
      offset: Offset(
        t.offset.dx.clamp(-bound.dx, bound.dx).toDouble(),
        t.offset.dy.clamp(-bound.dy, bound.dy).toDouble(),
      ),
      quarterTurns: turns,
    );
  }

  static bool isWithinBounds(CropTransform t, Size image, Size frame, {double epsilon = 0.01}) {
    final c = clamp(t, image, frame);
    return (c.scale - t.scale).abs() <= epsilon * c.scale && (c.offset - t.offset).distance <= epsilon * 10;
  }

  static CropTransform zoomAround(CropTransform t, double newScale, Offset focal) {
    final ratio = newScale / t.scale;
    return t.copyWith(scale: newScale, offset: focal - (focal - t.offset) * ratio);
  }

  static CropTransform rotateCounterClockwise(CropTransform t, Size image, Size frame) {
    final turns = normalizeTurns(t.quarterTurns);
    final nextTurns = normalizeTurns(turns - 1);
    final ratio = minScale(image, frame, nextTurns) / minScale(image, frame, turns);
    final rotated = Offset(t.offset.dy, -t.offset.dx) * ratio;
    return clamp(CropTransform(scale: t.scale * ratio, offset: rotated, quarterTurns: nextTurns), image, frame);
  }

  static Rect visibleRect(CropTransform t, Size image, Size frame) {
    final r = rotatedSize(image, t.quarterTurns);
    final center = Offset(r.width / 2 - t.offset.dx / t.scale, r.height / 2 - t.offset.dy / t.scale);
    return Rect.fromCenter(center: center, width: frame.width / t.scale, height: frame.height / t.scale);
  }

  static Rect sourceRect(CropTransform t, Size image, Size frame) {
    final v = visibleRect(t, image, frame);
    final w = image.width;
    final h = image.height;
    final Rect raw;
    switch (normalizeTurns(t.quarterTurns)) {
      case 1:
        raw = Rect.fromLTRB(v.top, h - v.right, v.bottom, h - v.left);
      case 2:
        raw = Rect.fromLTRB(w - v.right, h - v.bottom, w - v.left, h - v.top);
      case 3:
        raw = Rect.fromLTRB(w - v.bottom, v.left, w - v.top, v.right);
      default:
        raw = v;
    }
    return raw.intersect(Offset.zero & image);
  }

  static Size outputSize(double aspectRatio, int longestSide) => aspectRatio >= 1
      ? Size(longestSide.toDouble(), (longestSide / aspectRatio).roundToDouble())
      : Size((longestSide * aspectRatio).roundToDouble(), longestSide.toDouble());

  static double rubberBand(double overshoot, double dimension, {double coefficient = 0.55}) {
    if (dimension <= 0 || overshoot == 0) return 0;
    final sign = overshoot.sign;
    final x = overshoot.abs();
    return sign * (1 - 1 / (x * coefficient / dimension + 1)) * dimension;
  }

  static void paintPreview(Canvas canvas, Image image, Offset center, CropTransform t, double angle) {
    canvas.save();
    canvas.translate(center.dx + t.offset.dx, center.dy + t.offset.dy);
    canvas.rotate(angle);
    canvas.scale(t.scale);
    canvas.translate(-image.width / 2, -image.height / 2);
    canvas.drawImage(image, Offset.zero, Paint()..filterQuality = FilterQuality.medium);
    canvas.restore();
  }

  static void paintOutput(Canvas canvas, Image image, CropTransform t, Size frame, Size out) {
    final src = sourceRect(t, Size(image.width.toDouble(), image.height.toDouble()), frame);
    final quarter = normalizeTurns(t.quarterTurns).isOdd;
    canvas.save();
    canvas.translate(out.width / 2, out.height / 2);
    canvas.rotate(normalizeTurns(t.quarterTurns) * math.pi / 2);
    canvas.drawImageRect(
      image,
      src,
      Rect.fromCenter(
        center: Offset.zero,
        width: quarter ? out.height : out.width,
        height: quarter ? out.width : out.height,
      ),
      Paint()..filterQuality = FilterQuality.high,
    );
    canvas.restore();
  }
}
