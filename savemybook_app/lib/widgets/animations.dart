import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration duration;
  final Duration stagger;
  final Duration maxDelay;
  final double offsetY;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.duration = const Duration(milliseconds: 380),
    this.stagger = const Duration(milliseconds: 45),
    this.maxDelay = const Duration(milliseconds: 320),
    this.offsetY = 24,
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.duration);

  @override
  void initState() {
    super.initState();
    final delayMs =
        (widget.stagger.inMilliseconds * widget.index).clamp(0, widget.maxDelay.inMilliseconds);

    if (delayMs == 0) {
      _controller.forward();
    } else {
      Future.delayed(Duration(milliseconds: delayMs), () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final raw = _controller.value;
        // 透明度用較快的曲線先到位，位移慢一點收尾，進場才不會有「啪」的感覺。
        final fade = Curves.easeOut.transform((raw * 1.35).clamp(0.0, 1.0));
        final slide = Curves.easeOutCubic.transform(raw);
        return Opacity(
          opacity: fade,
          child: Transform.translate(
            offset: Offset(0, widget.offsetY * (1 - slide)),
            child: Transform.scale(
              scale: 0.985 + 0.015 * slide,
              child: child,
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}

class PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  const PressableScale({super.key, required this.child, this.onTap, this.scale = 0.97});

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.onTap == null || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1.0,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: _pressed ? 0.82 : 1,
          duration: const Duration(milliseconds: 130),
          child: widget.child,
        ),
      ),
    );
  }
}

class AnimatedCount extends StatelessWidget {
  final double value;
  final TextStyle? style;
  final String prefix;
  final int decimals;
  final Duration duration;

  const AnimatedCount({
    super.key,
    required this.value,
    this.style,
    this.prefix = '',
    this.decimals = 0,
    this.duration = const Duration(milliseconds: 650),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (_, animated, _) =>
          Text('$prefix${animated.toStringAsFixed(decimals)}', style: style),
    );
  }
}

class SwitchIn extends StatelessWidget {
  final Widget child;
  final Duration duration;

  const SwitchIn({super.key, required this.child, this.duration = const Duration(milliseconds: 280)});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.03), end: Offset.zero).animate(animation),
          child: child,
        ),
      ),
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [...previous, ?current],
      ),
      child: child,
    );
  }
}

class PopIn extends StatelessWidget {
  final Widget child;
  final Object? triggerKey;

  const PopIn({super.key, required this.child, this.triggerKey});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: KeyedSubtree(key: ValueKey(triggerKey), child: child),
    );
  }
}

/// 掃過去的高光，用來做骨架載入。
class Shimmer extends StatefulWidget {
  final Widget child;

  const Shimmer({super.key, required this.child});

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final highlight = c.isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.75);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final slide = _controller.value * 2 - 1;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(slide - 0.6, -0.3),
            end: Alignment(slide + 0.6, 0.3),
            colors: [Colors.transparent, highlight, Colors.transparent],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(bounds),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// 骨架的單一方塊。
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const SkeletonBox({super.key, this.width, this.height = 14, this.radius = 6});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: c.isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE6EAEE),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
