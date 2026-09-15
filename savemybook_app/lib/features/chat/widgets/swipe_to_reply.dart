import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../../../utils/app_colors.dart';
import '../../../utils/motion.dart';

class SwipeToReply extends StatefulWidget {
  static const trigger = 56.0;
  static const maxOverdrag = 34.0;
  static const flingVelocity = 450.0;
  static const flingMinOffset = 12.0;

  final Widget child;
  final VoidCallback? onReply;

  const SwipeToReply({super.key, required this.child, this.onReply});

  static double visualOffset(double drag) {
    final distance = drag.abs();
    if (distance <= trigger) return drag;
    final over = distance - trigger;
    final extra = maxOverdrag * (1 - 1 / (over * 0.55 / maxOverdrag + 1));
    return drag.sign * (trigger + extra);
  }

  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply> with SingleTickerProviderStateMixin {
  static const _iconSize = 32.0;
  static final _spring = SpringDescription(mass: 1, stiffness: 520, damping: 2 * math.sqrt(520));

  late final AnimationController _offset = AnimationController.unbounded(vsync: this);
  double _drag = 0;
  double _direction = 0;
  bool _armed = false;

  @override
  void didUpdateWidget(covariant SwipeToReply oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onReply == null && oldWidget.onReply != null) _settle(0);
  }

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  void _onStart(DragStartDetails _) {
    _offset.stop();
    _drag = _offset.value;
    _direction = _drag.sign;
  }

  void _onUpdate(DragUpdateDetails details) {
    var drag = _drag + (details.primaryDelta ?? details.delta.dx);
    if (_direction == 0 && drag != 0) _direction = drag.sign;
    drag = _direction > 0 ? math.max(0.0, drag) : math.min(0.0, drag);
    _drag = drag;
    _offset.value = SwipeToReply.visualOffset(drag);
    final armed = drag.abs() >= (_armed ? SwipeToReply.trigger - 8 : SwipeToReply.trigger);
    if (armed != _armed) {
      if (armed) HapticFeedback.lightImpact();
      setState(() => _armed = armed);
    }
  }

  void _onEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? details.velocity.pixelsPerSecond.dx;
    final fling = _drag != 0 &&
        velocity.sign == _drag.sign &&
        velocity.abs() >= SwipeToReply.flingVelocity &&
        _drag.abs() >= SwipeToReply.flingMinOffset;
    final reply = widget.onReply;
    if (reply != null && (_armed || fling)) {
      if (!_armed) HapticFeedback.lightImpact();
      reply();
    }
    _settle(velocity.sign == _offset.value.sign ? 0 : velocity);
  }

  void _onCancel() => _settle(0);

  void _settle(double velocity) {
    _drag = 0;
    _direction = 0;
    if (_armed) setState(() => _armed = false);
    if (_offset.value == 0) return;
    _offset
        .animateWith(
          SpringSimulation(_spring, _offset.value, 0, velocity, tolerance: const Tolerance(distance: 0.5, velocity: 20)),
        )
        .then((_) {
          if (mounted) _offset.value = 0;
        });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return RawGestureDetector(
      gestures: widget.onReply == null
          ? const <Type, GestureRecognizerFactory>{}
          : {
              _ReplyDragRecognizer: GestureRecognizerFactoryWithHandlers<_ReplyDragRecognizer>(
                () => _ReplyDragRecognizer(debugOwner: this),
                (r) => r
                  ..dragStartBehavior = DragStartBehavior.down
                  ..onStart = _onStart
                  ..onUpdate = _onUpdate
                  ..onEnd = _onEnd
                  ..onCancel = _onCancel,
              ),
            },
      child: AnimatedBuilder(
        animation: _offset,
        child: widget.child,
        builder: (context, child) {
          final dx = _offset.value;
          final progress = (dx.abs() / SwipeToReply.trigger).clamp(0.0, 1.0);
          final inset = math.max(4.0, (math.min(dx.abs(), SwipeToReply.trigger) - _iconSize) / 2);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Transform.translate(offset: Offset(dx, 0), child: child),
              if (progress > 0.02)
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: dx > 0 ? inset : null,
                  right: dx < 0 ? inset : null,
                  child: IgnorePointer(
                    child: Center(
                      child: Opacity(
                        opacity: Curves.easeOut.transform(progress),
                        child: Transform.scale(
                          scale: 0.45 + 0.55 * progress,
                          child: AnimatedScale(
                            scale: _armed ? 1.1 : 1.0,
                            duration: Motion.micro,
                            curve: Motion.pop,
                            child: AnimatedContainer(
                              key: const ValueKey('swipe_reply_icon'),
                              duration: Motion.micro,
                              width: _iconSize,
                              height: _iconSize,
                              decoration: BoxDecoration(
                                color: _armed
                                    ? c.accent
                                    : (c.isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.07)),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.reply_rounded, size: 18, color: _armed ? Colors.white : c.textSecondary),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// iOS 的返回手勢從螢幕左緣開始；若在那裡搶下水平拖曳，使用者就無法滑動返回。
// 另外必須等水平位移明顯大於垂直位移才接手，否則斜向捲動訊息清單時會被誤判成回覆。
class _ReplyDragRecognizer extends HorizontalDragGestureRecognizer {
  _ReplyDragRecognizer({super.debugOwner});

  static const _edge = 28.0;
  static const _dominance = 1.6;

  Offset _moved = Offset.zero;

  @override
  bool isPointerAllowed(PointerEvent event) {
    if (event is PointerDownEvent && event.position.dx < _edge) return false;
    return super.isPointerAllowed(event);
  }

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _moved = Offset.zero;
    super.addAllowedPointer(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent) _moved += event.delta;
    super.handleEvent(event);
  }

  @override
  bool hasSufficientGlobalDistanceToAccept(PointerDeviceKind pointerDeviceKind, double? deviceTouchSlop) {
    return super.hasSufficientGlobalDistanceToAccept(pointerDeviceKind, deviceTouchSlop) &&
        _moved.dx.abs() > _moved.dy.abs() * _dominance;
  }
}
