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
        // 透明度先到位、位移後收尾，避免進場顯得生硬。
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

  /// 按下時是否給觸覺回饋。列表中密集的小元件應關閉，否則滑過會連續震動。
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
  /// 0 = 原始大小，1 = 完全按下。用 unbounded 是因為回彈的彈簧會衝過
  /// 0 變成負值，那一段負值正好變成放開瞬間的微微放大。
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
    // 帶著目前的速度交給彈簧，手指放開的動作跟回彈之間才沒有接縫。
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

/// 捲到看得見才進場。
///
/// [FadeSlideIn] 在掛載當下就播，第一屏以外的項目等捲到時早已播完，
/// 畫面下半部永遠是靜止的。這個元件改為等項目進入視窗才觸發。
class RevealOnScroll extends StatefulWidget {
  final Widget child;
  final int index;
  final double offsetY;
  final Duration duration;
  final Duration stagger;

  /// 距視窗底部這段距離內才算進場，避免只露出一角就開始動。
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

    // 往上收集每一層可捲動的祖先，不只最近的那一層。
    // 首頁的書籍格是 shrinkWrap + NeverScrollableScrollPhysics 包在
    // SingleChildScrollView 裡，內層那個 position 永遠不會動；只聽它
    // 的話第一屏以外的卡片會一直停在透明狀態。
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
      // 根本不在可捲動容器裡（例如被放進 Column），直接放行。
      _reveal();
      return;
    }

    // 保險：萬一某個版面的捲動事件傳不到這裡，也不能讓內容永遠看不見。
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

    // 只有開頁時就在畫面內的那一批需要依序錯開；之後捲進來的立刻播，
    // 不然每滑一下都要等，反而像卡頓。
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
        // 透明度先到位、位移後收尾，避免進場顯得生硬。
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

/// 極輕微的呼吸循環，用於空狀態圖示。
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

/// 自中心擴散的圈，用於收藏、加入購物車等正向操作的瞬間。
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

/// 依序描繪的打勾，用於結帳完成、取書成功等結果頁。
class DrawnCheck extends StatefulWidget {
  final Color color;
  final double size;
  final Duration delay;

  const DrawnCheck({
    super.key,
    required this.color,
    this.size = 96,
    this.delay = const Duration(milliseconds: 120),
  });

  @override
  State<DrawnCheck> createState() => _DrawnCheckState();
}

class _DrawnCheckState extends State<DrawnCheck> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
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
        // 圓圈先畫完一半，勾才開始下筆，兩段動作才不會糊在一起。
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
        -1.5708, // 從 12 點鐘方向開始
        6.2832 * ring,
        false,
        stroke..strokeWidth = 3.2,
      );
    }

    if (tick > 0) {
      // 勾的三個點，以圓心為基準用比例定位，換 size 也不會跑掉。
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
