import 'package:flutter/material.dart';

import '../../../utils/app_colors.dart';
import '../../../widgets/animations.dart';
import 'chat_format.dart';

class ChatStatusBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final String? actionLabel;
  final VoidCallback? onAction;

  const ChatStatusBanner({super.key, required this.icon, required this.text, required this.color, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: c.isDark ? 0.18 : 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                text,
                style: TextStyle(fontSize: 12.5, color: c.textPrimary, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: color,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: Text(actionLabel!, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }
}

class ChatSuggestionStrip extends StatelessWidget {
  final List<Widget> chips;

  const ChatSuggestionStrip({super.key, required this.chips});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => FadeSlideIn(index: i, offsetY: 8, child: chips[i]),
      ),
    );
  }
}

class ChatSuggestionChip extends StatelessWidget {
  final IconData? icon;
  final String label;
  final bool highlighted;
  final VoidCallback? onTap;

  const ChatSuggestionChip({super.key, required this.label, this.icon, this.highlighted = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final fg = highlighted ? Colors.white : c.textPrimary;
    return PressableScale(
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: highlighted ? chatMineBubble(c) : c.inputFill,
          borderRadius: BorderRadius.circular(18),
          border: highlighted ? null : Border.all(color: c.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
            ],
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, fontWeight: highlighted ? FontWeight.w700 : FontWeight.w500, color: fg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
