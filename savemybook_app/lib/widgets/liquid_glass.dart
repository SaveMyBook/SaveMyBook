import 'dart:ui';

import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

/// 液態玻璃表面。
///
/// Flutter 沒有 iOS 26 的 UIGlassEffect，這裡用四層疊出同樣的觀感：
/// 1. 背景高斯模糊（BackdropFilter）
/// 2. 由左上到右下的半透明色調，模擬玻璃本身的厚度
/// 3. 上緣的內側高光，模擬光線從上方打進玻璃
/// 4. 一圈亮度會沿著邊緣變化的鏡面描邊（左上最亮、右下次亮、中間近乎消失）
class LiquidGlass extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final double blur;

  /// 玻璃本身的濃度，0 = 幾乎全透明，1 = 接近實心。
  final double thickness;

  final List<BoxShadow>? shadows;

  const LiquidGlass({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(28)),
    this.blur = 32,
    this.thickness = 1,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isDark = c.isDark;

    final tintTop = (isDark ? Colors.white : Colors.white)
        .withValues(alpha: (isDark ? 0.14 : 0.62) * thickness);
    final tintBottom = (isDark ? Colors.white : Colors.white)
        .withValues(alpha: (isDark ? 0.05 : 0.34) * thickness);
    final base = (isDark ? const Color(0xFF14181C) : const Color(0xFFF4F7F9))
        .withValues(alpha: (isDark ? 0.55 : 0.30) * thickness);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: shadows ??
            [
              BoxShadow(color: c.shadow, blurRadius: 34, offset: const Offset(0, 10)),
              BoxShadow(
                color: c.shadow.withValues(alpha: 0.08),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              color: base,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [tintTop, tintBottom],
              ),
            ),
            child: CustomPaint(
              foregroundPainter: _GlassRimPainter(
                borderRadius: borderRadius,
                isDark: isDark,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassRimPainter extends CustomPainter {
  final BorderRadius borderRadius;
  final bool isDark;

  _GlassRimPainter({required this.borderRadius, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final outer = borderRadius.toRRect(rect).deflate(0.6);

    // 鏡面描邊：左上最亮、中段幾乎消失、右下再回來一點，
    // 這個亮度落差就是玻璃邊緣折射的感覺。
    canvas.drawRRect(
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: isDark ? 0.42 : 0.95),
            Colors.white.withValues(alpha: isDark ? 0.04 : 0.12),
            Colors.white.withValues(alpha: isDark ? 0.16 : 0.45),
          ],
          stops: const [0, 0.5, 1],
        ).createShader(rect),
    );

    // 上緣往內漸層的高光，讓玻璃看起來有厚度而不是一張貼紙。
    final inner = borderRadius.toRRect(rect).deflate(1.4);
    canvas.save();
    canvas.clipRRect(inner);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height * 0.5),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: isDark ? 0.10 : 0.34),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.5)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GlassRimPainter oldDelegate) =>
      oldDelegate.isDark != isDark || oldDelegate.borderRadius != borderRadius;
}
