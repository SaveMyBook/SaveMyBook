import 'package:flutter/material.dart';

import '../../../utils/app_colors.dart';
import '../../../utils/motion.dart';

class ChatRowAnchor extends StatefulWidget {
  final String id;
  final Map<String, BuildContext> anchors;
  final Widget child;

  const ChatRowAnchor({super.key, required this.id, required this.anchors, required this.child});

  @override
  State<ChatRowAnchor> createState() => _ChatRowAnchorState();
}

class _ChatRowAnchorState extends State<ChatRowAnchor> {
  @override
  Widget build(BuildContext context) {
    widget.anchors[widget.id] = context;
    return widget.child;
  }

  @override
  void didUpdateWidget(ChatRowAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id && identical(oldWidget.anchors[oldWidget.id], context)) {
      oldWidget.anchors.remove(oldWidget.id);
    }
  }

  @override
  void dispose() {
    if (identical(widget.anchors[widget.id], context)) widget.anchors.remove(widget.id);
    super.dispose();
  }
}

class ChatHighlightFlash extends StatelessWidget {
  final String id;
  final ValueNotifier<String?> highlight;
  final Widget child;

  const ChatHighlightFlash({super.key, required this.id, required this.highlight, required this.child});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return ValueListenableBuilder<String?>(
      valueListenable: highlight,
      child: child,
      builder: (_, value, child) => AnimatedContainer(
        duration: value == id ? Motion.micro : const Duration(milliseconds: 600),
        curve: Motion.standard,
        color: value == id ? c.accent.withValues(alpha: c.isDark ? 0.22 : 0.14) : c.accent.withValues(alpha: 0),
        child: child,
      ),
    );
  }
}
