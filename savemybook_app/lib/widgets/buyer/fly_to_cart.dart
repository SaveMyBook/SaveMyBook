import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../utils/motion.dart';
import '../state_views.dart';

void flyToCart(
  BuildContext context, {
  required GlobalKey from,
  required GlobalKey to,
  String? imageUrl,
  VoidCallback? onArrive,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  final fromBox = from.currentContext?.findRenderObject() as RenderBox?;
  final toBox = to.currentContext?.findRenderObject() as RenderBox?;
  final overlayBox = overlay?.context.findRenderObject() as RenderBox?;
  if (overlay == null || fromBox == null || toBox == null || overlayBox == null ||
      !fromBox.attached || !toBox.attached) {
    onArrive?.call();
    return;
  }

  final start = fromBox.localToGlobal(fromBox.size.center(Offset.zero), ancestor: overlayBox);
  final end = toBox.localToGlobal(toBox.size.center(Offset.zero), ancestor: overlayBox);

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _FlyingThumb(
      start: start,
      end: end,
      imageUrl: imageUrl,
      onDone: () {
        entry.remove();
        onArrive?.call();
      },
    ),
  );
  overlay.insert(entry);
}

class _FlyingThumb extends StatefulWidget {
  final Offset start;
  final Offset end;
  final String? imageUrl;
  final VoidCallback onDone;

  const _FlyingThumb({required this.start, required this.end, required this.imageUrl, required this.onDone});

  @override
  State<_FlyingThumb> createState() => _FlyingThumbState();
}

class _FlyingThumbState extends State<_FlyingThumb> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 620))
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onDone();
    })
    ..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    const size = 56.0;
    final control = Offset(
      (widget.start.dx + widget.end.dx) / 2,
      (widget.start.dy < widget.end.dy ? widget.start.dy : widget.end.dy) - 120,
    );

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = Motion.standard.transform(_controller.value);
          final u = 1 - t;
          final point = widget.start * (u * u) + control * (2 * u * t) + widget.end * (t * t);
          final scale = lerpDouble(1, 0.28, t)!;
          final opacity = _controller.value < 0.85 ? 1.0 : (1 - (_controller.value - 0.85) / 0.15).clamp(0.0, 1.0);
          return Stack(
            children: [
              Positioned(
                left: point.dx - size / 2,
                top: point.dy - size / 2,
                child: Opacity(
                  opacity: opacity,
                  child: Transform.scale(scale: scale, child: child),
                ),
              ),
            ],
          );
        },
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.accent, width: 2),
            boxShadow: [BoxShadow(color: c.shadow, blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: widget.imageUrl == null || widget.imageUrl!.isEmpty
                ? Icon(Icons.menu_book_rounded, color: c.accent, size: 26)
                : AppNetworkImage(url: widget.imageUrl, width: size, height: size, fallbackIconSize: 22),
          ),
        ),
      ),
    );
  }
}
