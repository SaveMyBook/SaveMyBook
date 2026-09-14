import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/app_colors.dart';
import '../../utils/motion.dart';
import '../animations.dart';

class BackToTopButton extends StatefulWidget {
  final ScrollController controller;
  final double threshold;

  const BackToTopButton({super.key, required this.controller, this.threshold = 900});

  static Future<void> scrollToTop(ScrollController controller) async {
    if (!controller.hasClients) return;
    final offset = controller.offset;
    if (offset <= 0) return;
    if (offset > 4000) controller.jumpTo(1200);
    await controller.animateTo(0, duration: Motion.large, curve: Motion.standard);
  }

  @override
  State<BackToTopButton> createState() => _BackToTopButtonState();
}

class _BackToTopButtonState extends State<BackToTopButton> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant BackToTopButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onScroll);
      widget.controller.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (!widget.controller.hasClients) return;
    final next = widget.controller.offset > widget.threshold;
    if (next != _visible && mounted) setState(() => _visible = next);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return IgnorePointer(
      ignoring: !_visible,
      child: AnimatedScale(
        scale: _visible ? 1 : 0.6,
        duration: Motion.base,
        curve: _visible ? Motion.pop : Motion.exitCurve,
        child: AnimatedOpacity(
          opacity: _visible ? 1 : 0,
          duration: Motion.micro,
          child: PressableScale(
            scale: 0.88,
            onTap: () {
              HapticFeedback.selectionClick();
              BackToTopButton.scrollToTop(widget.controller);
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: c.card,
                shape: BoxShape.circle,
                border: Border.all(color: c.border),
                boxShadow: [BoxShadow(color: c.shadow, blurRadius: 14, offset: const Offset(0, 4))],
              ),
              child: Icon(Icons.keyboard_arrow_up_rounded, color: c.accent, size: 26),
            ),
          ),
        ),
      ),
    );
  }
}
