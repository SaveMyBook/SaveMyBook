import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import '../utils/app_colors.dart';
import '../utils/motion.dart';

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

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _controller.value = 1;
      return;
    }

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
  final VoidCallback? onLongPress;
  final double scale;

  final bool haptic;

  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.97,
    this.haptic = false,
  });

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController.unbounded(vsync: this, value: 0);

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  void _press() {
    if (!_enabled) return;
    if (widget.haptic) HapticFeedback.selectionClick();
    _controller.animateTo(1, duration: Motion.instant, curve: Curves.easeOut);
  }

  void _release() {
    if (!_enabled) return;
    _controller.animateWith(
      SpringSimulation(Motion.pressSpring, _controller.value, 0, -_controller.velocity),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _press(),
      onTapUp: (_) => _release(),
      onTapCancel: _release,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value;
          return Transform.scale(
            scale: 1 + (widget.scale - 1) * t,
            child: Opacity(
              opacity: 1 - 0.14 * t.clamp(0.0, 1.0),
              child: child,
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}

class RevealOnScroll extends StatefulWidget {
  final Widget child;
  final int index;
  final double offsetY;
  final Duration duration;
  final Duration stagger;

  final double threshold;

  const RevealOnScroll({
    super.key,
    required this.child,
    this.index = 0,
    this.offsetY = 26,
    this.duration = Motion.enter,
    this.stagger = Motion.stagger,
    this.threshold = 72,
  });

  @override
  State<RevealOnScroll> createState() => _RevealOnScrollState();
}

class _RevealOnScrollState extends State<RevealOnScroll>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.duration);

  final List<ScrollPosition> _positions = <ScrollPosition>[];
  Timer? _fallback;
  bool _revealed = false;
  bool _firstCheck = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _attach());
  }

  void _attach() {
    if (!mounted) return;

    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _revealed = true;
      _controller.value = 1;
      return;
    }

    // 必須聽每一層祖先 Scrollable：shrinkWrap 的內層清單永遠不會捲動，只聽最近一層會讓卡片一直透明。
    BuildContext? ctx = context;
    while (ctx != null && _positions.length < 4) {
      final scrollable = Scrollable.maybeOf(ctx);
      if (scrollable == null) break;
      _positions.add(scrollable.position);
      ctx = scrollable.context;
    }

    for (final position in _positions) {
      position.addListener(_check);
    }

    _check();
    _firstCheck = false;

    if (_revealed) return;

    if (_positions.isEmpty) {
      _reveal();
      return;
    }

    _fallback = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) _reveal();
    });
  }

  void _check() {
    if (_revealed || !mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    final top = box.localToGlobal(Offset.zero).dy;
    final viewportBottom = MediaQuery.of(context).size.height - widget.threshold;
    if (top <= viewportBottom) _reveal();
  }

  void _reveal() {
    if (_revealed) return;
    _revealed = true;
    _fallback?.cancel();
    for (final position in _positions) {
      position.removeListener(_check);
    }

    final delay = _firstCheck ? Motion.delayFor(widget.index, step: widget.stagger) : Duration.zero;

    if (delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _fallback?.cancel();
    for (final position in _positions) {
      position.removeListener(_check);
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final raw = _controller.value;
        final fade = Curves.easeOut.transform((raw * 1.4).clamp(0.0, 1.0));
        final slide = Motion.enterCurve.transform(raw);
        return Opacity(
          opacity: fade,
          child: Transform.translate(
            offset: Offset(0, widget.offsetY * (1 - slide)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

class Reveal extends StatelessWidget {
  final bool visible;
  final Widget child;
  final Duration duration;
  final Alignment alignment;

  const Reveal({
    super.key,
    required this.visible,
    required this.child,
    this.duration = Motion.base,
    this.alignment = Alignment.topCenter,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: visible ? 1 : 0, end: visible ? 1 : 0),
      duration: duration,
      curve: Motion.emphasized,
      builder: (context, t, inner) => t == 0
          ? const SizedBox.shrink()
          : ClipRect(
              child: Align(
                alignment: alignment,
                heightFactor: t,
                child: Opacity(opacity: t.clamp(0.0, 1.0), child: inner),
              ),
            ),
      child: child,
    );
  }
}

class Breathe extends StatefulWidget {
  final Widget child;
  final double amount;
  final Duration period;

  const Breathe({
    super.key,
    required this.child,
    this.amount = 0.035,
    this.period = const Duration(milliseconds: 2800),
  });

  @override
  State<Breathe> createState() => _BreatheState();
}

class _BreatheState extends State<Breathe> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.period)..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) => Transform.scale(
        scale: 1 + widget.amount * curved.value,
        child: Transform.translate(
          offset: Offset(0, -3 * curved.value),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

class BurstRing extends StatefulWidget {
  final Color color;
  final double size;

  const BurstRing({super.key, required this.color, this.size = 34});

  @override
  State<BurstRing> createState() => BurstRingState();
}

class BurstRingState extends State<BurstRing> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 520));

  void fire() {
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          if (t == 0 || t == 1) return SizedBox(width: widget.size, height: widget.size);
          final grow = Curves.easeOutCubic.transform(t);
          return SizedBox(
            width: widget.size,
            height: widget.size,
            child: CustomPaint(
              painter: _BurstPainter(
                color: widget.color,
                progress: grow,
                opacity: (1 - t) * 0.55,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  final Color color;
  final double progress;
  final double opacity;

  const _BurstPainter({
    required this.color,
    required this.progress,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final maxRadius = size.shortestSide / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4 * (1 - progress) + 0.6
      ..color = color.withValues(alpha: opacity);

    canvas.drawCircle(centre, maxRadius * (0.35 + 0.65 * progress), paint);
  }

  @override
  bool shouldRepaint(_BurstPainter old) =>
      old.progress != progress || old.opacity != opacity || old.color != color;
}

class DrawnCheck extends StatefulWidget {
  final Color color;
  final double size;
  final Duration delay;
  final bool haptic;
  final VoidCallback? onCompleted;

  const DrawnCheck({
    super.key,
    required this.color,
    this.size = 96,
    this.delay = const Duration(milliseconds: 120),
    this.haptic = false,
    this.onCompleted,
  });

  @override
  State<DrawnCheck> createState() => _DrawnCheckState();
}

class _DrawnCheckState extends State<DrawnCheck> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed) widget.onCompleted?.call();
        });

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (!mounted) return;
      if (widget.haptic) HapticFeedback.mediumImpact();
      _controller.forward();
    });
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
      builder: (context, _) {
        final t = _controller.value;
        final ring = Curves.easeOutCubic.transform((t / 0.55).clamp(0.0, 1.0));
        final tick = Curves.easeOutCubic.transform(((t - 0.42) / 0.58).clamp(0.0, 1.0));
        final pulse = Curves.easeOutBack.transform(((t - 0.30) / 0.70).clamp(0.0, 1.0));

        return Transform.scale(
          scale: 0.88 + 0.12 * pulse,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: CustomPaint(
              painter: _CheckPainter(color: widget.color, ring: ring, tick: tick),
            ),
          ),
        );
      },
    );
  }
}

class _CheckPainter extends CustomPainter {
  final Color color;
  final double ring;
  final double tick;

  const _CheckPainter({required this.color, required this.ring, required this.tick});

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 4;

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;

    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..style = PaintingStyle.fill
        ..color = color.withValues(alpha: 0.10),
    );

    if (ring > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: centre, radius: radius),
        -1.5708,
        6.2832 * ring,
        false,
        stroke..strokeWidth = 3.2,
      );
    }

    if (tick > 0) {
      final a = centre + Offset(-radius * 0.34, radius * 0.02);
      final b = centre + Offset(-radius * 0.08, radius * 0.28);
      final c = centre + Offset(radius * 0.38, -radius * 0.26);

      final firstLeg = (tick / 0.4).clamp(0.0, 1.0);
      final secondLeg = ((tick - 0.4) / 0.6).clamp(0.0, 1.0);

      final path = Path()..moveTo(a.dx, a.dy);
      final mid = Offset.lerp(a, b, firstLeg)!;
      path.lineTo(mid.dx, mid.dy);
      if (secondLeg > 0) {
        final end = Offset.lerp(b, c, secondLeg)!;
        path.lineTo(end.dx, end.dy);
      }

      canvas.drawPath(path, stroke..strokeWidth = 4.0);
    }
  }

  @override
  bool shouldRepaint(_CheckPainter old) =>
      old.ring != ring || old.tick != tick || old.color != color;
}

class AnimatedCount extends StatelessWidget {
  final double value;
  final TextStyle? style;
  final String prefix;
  final String suffix;
  final int decimals;
  final Duration duration;
  final Curve curve;
  final bool thousands;
  final String Function(double value)? formatter;
  final TextAlign? textAlign;

  const AnimatedCount({
    super.key,
    required this.value,
    this.style,
    this.prefix = '',
    this.suffix = '',
    this.decimals = 0,
    this.duration = const Duration(milliseconds: 650),
    this.curve = Curves.easeOutCubic,
    this.thousands = false,
    this.formatter,
    this.textAlign,
  });

  static String group(String digits) {
    final negative = digits.startsWith('-');
    final body = negative ? digits.substring(1) : digits;
    final dot = body.indexOf('.');
    final whole = dot < 0 ? body : body.substring(0, dot);
    final fraction = dot < 0 ? '' : body.substring(dot);
    final buffer = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) buffer.write(',');
      buffer.write(whole[i]);
    }
    return '${negative ? '-' : ''}$buffer$fraction';
  }

  String _format(double v) {
    if (formatter != null) return formatter!(v);
    final fixed = v.toStringAsFixed(decimals);
    return '$prefix${thousands ? group(fixed) : fixed}$suffix';
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: reduceMotion ? Duration.zero : duration,
      curve: curve,
      builder: (_, animated, _) => Text(_format(animated), style: style, textAlign: textAlign),
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
        color: c.skeleton,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
