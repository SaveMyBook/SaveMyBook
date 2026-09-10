import 'package:flutter/material.dart';

/// Face ID 的圖示。
///
/// Material 沒有對應的字符，`Icons.face` 是一顆卡通臉，跟系統跳出來的
/// Face ID 完全不像。這裡照 Apple 的樣式自己畫：四個角括號框住一張臉。
class FaceIdIcon extends StatelessWidget {
  final double size;
  final Color color;

  const FaceIdIcon({super.key, this.size = 22, this.color = Colors.black});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _FaceIdPainter(color)),
    );
  }
}

class _FaceIdPainter extends CustomPainter {
  final Color color;

  _FaceIdPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final stroke = s * 0.085;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // 四個角括號
    final inset = stroke / 2;
    final arm = s * 0.26;
    final radius = s * 0.16;

    void corner(Offset origin, int dx, int dy) {
      final path = Path()
        ..moveTo(origin.dx + dx * arm, origin.dy)
        ..lineTo(origin.dx + dx * radius, origin.dy)
        ..arcToPoint(
          Offset(origin.dx, origin.dy + dy * radius),
          radius: Radius.circular(radius),
          clockwise: dx * dy < 0,
        )
        ..lineTo(origin.dx, origin.dy + dy * arm);
      canvas.drawPath(path, paint);
    }

    corner(Offset(inset, inset), 1, 1);
    corner(Offset(s - inset, inset), -1, 1);
    corner(Offset(inset, s - inset), 1, -1);
    corner(Offset(s - inset, s - inset), -1, -1);

    // 眼睛
    final eyeTop = s * 0.34;
    final eyeBottom = s * 0.44;
    canvas.drawLine(Offset(s * 0.34, eyeTop), Offset(s * 0.34, eyeBottom), paint);
    canvas.drawLine(Offset(s * 0.66, eyeTop), Offset(s * 0.66, eyeBottom), paint);

    // 鼻子
    canvas.drawPath(
      Path()
        ..moveTo(s * 0.5, s * 0.36)
        ..lineTo(s * 0.5, s * 0.54)
        ..lineTo(s * 0.42, s * 0.54),
      paint,
    );

    // 嘴巴
    canvas.drawPath(
      Path()
        ..moveTo(s * 0.35, s * 0.64)
        ..quadraticBezierTo(s * 0.5, s * 0.74, s * 0.65, s * 0.64),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _FaceIdPainter oldDelegate) => oldDelegate.color != color;
}
