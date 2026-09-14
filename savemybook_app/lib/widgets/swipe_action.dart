import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/motion.dart';

class SwipeAction {
  final IconData icon;
  final String label;
  final Color color;
  final Future<bool> Function() onTrigger;

  // dismisses 為 true 時必須在這裡同步把資料移出清單，否則列表會保留已消失的項目。
  final VoidCallback? onDismissed;

  final bool dismisses;

  const SwipeAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTrigger,
    this.onDismissed,
    this.dismisses = false,
  });
}

class SwipeActionTile extends StatefulWidget {
  final Widget child;
  final Key itemKey;
  final SwipeAction? endToStart;
  final SwipeAction? startToEnd;
  final EdgeInsets backgroundMargin;

  const SwipeActionTile({
    super.key,
    required this.itemKey,
    required this.child,
    this.endToStart,
    this.startToEnd,
    this.backgroundMargin = const EdgeInsets.only(bottom: 12),
  });

  @override
  State<SwipeActionTile> createState() => _SwipeActionTileState();
}

class _SwipeActionTileState extends State<SwipeActionTile> with TickerProviderStateMixin {
  static final ValueNotifier<Object?> _openTile = ValueNotifier<Object?>(null);

  static const double _actionWidth = 84;
  static const double _activationDistance = 18;

  late final AnimationController _slide = AnimationController.unbounded(vsync: this);
  late final AnimationController _collapse = AnimationController(vsync: this, duration: Motion.base, value: 1);

  double _dragStartOffset = 0;
  bool _tracking = false;
  bool _engaged = false;
  double _accumulated = 0;
  bool _busy = false;
  ScrollPosition? _scrollPosition;

  double get _offset => _slide.value;

  @override
  void initState() {
    super.initState();
    _openTile.addListener(_onOtherOpened);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (position != _scrollPosition) {
      _scrollPosition?.isScrollingNotifier.removeListener(_onScroll);
      _scrollPosition = position;
      _scrollPosition?.isScrollingNotifier.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    _openTile.removeListener(_onOtherOpened);
    _scrollPosition?.isScrollingNotifier.removeListener(_onScroll);
    if (identical(_openTile.value, this)) _openTile.value = null;
    _slide.dispose();
    _collapse.dispose();
    super.dispose();
  }

  void _onOtherOpened() {
    if (!identical(_openTile.value, this) && _offset != 0) _animateTo(0);
  }

  void _onScroll() {
    if (_scrollPosition?.isScrollingNotifier.value == true && _offset != 0) _close();
  }

  double get _maxRight => widget.startToEnd == null ? 0 : _actionWidth;
  double get _maxLeft => widget.endToStart == null ? 0 : -_actionWidth;

  void _animateTo(double target) {
    _slide.animateTo(target, duration: Motion.base, curve: Motion.emphasized);
  }

  void _close() {
    _animateTo(0);
    if (identical(_openTile.value, this)) _openTile.value = null;
  }

  void _onDragStart(DragStartDetails details) {
    if (_busy) return;
    final media = MediaQuery.of(context);
    final edge = math.max(28.0, math.max(media.systemGestureInsets.left, media.systemGestureInsets.right));
    final x = details.globalPosition.dx;
    _tracking = x > edge && x < media.size.width - edge;
    _engaged = false;
    _accumulated = 0;
    _dragStartOffset = _offset;
    _slide.stop();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_tracking) return;
    _accumulated += details.primaryDelta ?? 0;
    if (!_engaged) {
      if (_accumulated.abs() < _activationDistance) return;
      _engaged = true;
      _accumulated -= _activationDistance * _accumulated.sign;
    }
    var next = _dragStartOffset + _accumulated;
    if (next > _maxRight) next = _maxRight + (next - _maxRight) * 0.25;
    if (next < _maxLeft) next = _maxLeft + (next - _maxLeft) * 0.25;
    if (_maxRight == 0 && next > 0) next = 0;
    if (_maxLeft == 0 && next < 0) next = 0;
    _slide.value = next;
  }

  void _onDragEnd(DragEndDetails details) {
    if (!_tracking || !_engaged) {
      if (_offset != 0 && !_engaged) _animateTo(_offset.abs() > _actionWidth / 2 ? _offset.sign * _actionWidth : 0);
      return;
    }
    final velocity = details.primaryVelocity ?? 0;
    double target = 0;
    if (_offset > _actionWidth * 0.55 || (velocity > 700 && _offset > 0)) target = _maxRight;
    if (_offset < -_actionWidth * 0.55 || (velocity < -700 && _offset < 0)) target = _maxLeft;
    if (target != 0 && _dragStartOffset == 0) HapticFeedback.selectionClick();
    _animateTo(target);
    _openTile.value = target == 0 ? (identical(_openTile.value, this) ? null : _openTile.value) : this;
  }

  Future<void> _run(SwipeAction action) async {
    if (_busy) return;
    _busy = true;
    HapticFeedback.mediumImpact();
    try {
      final ok = await action.onTrigger();
      if (!mounted) return;
      if (ok && action.dismisses) {
        final width = context.size?.width ?? 400;
        await _slide.animateTo(_offset.sign * width, duration: Motion.base, curve: Motion.exitCurve);
        if (!mounted) return;
        await _collapse.animateTo(0, curve: Motion.standard);
        if (!mounted) return;
        action.onDismissed?.call();
      } else {
        _close();
      }
    } finally {
      _busy = false;
    }
  }

  Widget _actionButton(SwipeAction action, bool alignRight) {
    return Align(
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      child: SizedBox(
        width: _actionWidth,
        child: Semantics(
          button: true,
          label: action.label,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _run(action),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(action.icon, color: Colors.white, size: 22),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    action.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.startToEnd == null && widget.endToStart == null) return widget.child;

    return SizeTransition(
      sizeFactor: _collapse,
      axisAlignment: -1,
      child: AnimatedBuilder(
        animation: _slide,
        child: widget.child,
        builder: (context, child) {
          final offset = _offset;
          final action = offset > 0 ? widget.startToEnd : offset < 0 ? widget.endToStart : null;
          return Stack(
            children: [
              Positioned.fill(
                child: action == null
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: widget.backgroundMargin,
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: action.color, borderRadius: BorderRadius.circular(16)),
                          child: Opacity(
                            opacity: (offset.abs() / _actionWidth).clamp(0.0, 1.0),
                            child: _actionButton(action, offset < 0),
                          ),
                        ),
                      ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragStart: _onDragStart,
                onHorizontalDragUpdate: _onDragUpdate,
                onHorizontalDragEnd: _onDragEnd,
                child: Transform.translate(
                  offset: Offset(offset, 0),
                  child: Stack(
                    children: [
                      child!,
                      Positioned.fill(
                        child: IgnorePointer(
                          ignoring: offset == 0,
                          child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _close),
                        ),
                      ),
                    ],
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
