import 'dart:ui';

import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

/// 液態玻璃表面。
///
/// Flutter 沒有 iOS 26 的 UIGlassEffect，這裡用三層疊出同樣的觀感：
/// 1. 背景高斯模糊（BackdropFilter）
/// 2. 高不透明度的表面漸層 —— 玻璃要「乾淨」，不是「灰」
/// 3. 上亮下淡的鏡面描邊，做出邊界的立體感
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

    // 玻璃本體要夠不透明，內容才看得清楚。之前把三層半透明疊在模糊過的
    // 灰底上，混出來就是一片髒灰色，圖示跟文字都糊掉。
    final surfaceTop = isDark
        ? const Color(0xFF23282F).withValues(alpha: 0.92 * thickness)
        : Colors.white.withValues(alpha: 0.93 * thickness);
    final surfaceBottom = isDark
        ? const Color(0xFF171B20).withValues(alpha: 0.88 * thickness)
        : Colors.white.withValues(alpha: 0.86 * thickness);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: shadows ??
            [
              BoxShadow(color: c.shadow, blurRadius: 30, offset: const Offset(0, 8)),
              BoxShadow(
                color: c.shadow.withValues(alpha: 0.06),
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
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [surfaceTop, surfaceBottom],
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
    final outer = borderRadius.toRRect(rect).deflate(0.5);

    // 鏡面描邊：上緣亮、下緣淡，只做出邊界的立體感，
    // 不再往表面裡面灌高光（那會讓整塊看起來霧霧的）。
    canvas.drawRRect(
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: isDark ? 0.22 : 0.95),
            Colors.white.withValues(alpha: isDark ? 0.06 : 0.35),
          ],
        ).createShader(rect),
    );

    // 深色模式再補一圈很細的外緣暗線，跟背景分開。
    if (isDark) {
      canvas.drawRRect(
        borderRadius.toRRect(rect).deflate(0.25),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5
          ..color = Colors.black.withValues(alpha: 0.35),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GlassRimPainter oldDelegate) =>
      oldDelegate.isDark != isDark || oldDelegate.borderRadius != borderRadius;
}
