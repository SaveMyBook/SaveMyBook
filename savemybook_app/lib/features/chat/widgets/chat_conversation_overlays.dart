import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../../i18n/strings.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/motion.dart';
import 'chat_format.dart';

class ChatHistoryHead extends StatelessWidget {
  final bool loading;

  const ChatHistoryHead({super.key, required this.loading});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    if (loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: c.accent),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
      child: Text(
        S.startConversation,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11.5, color: c.textHint),
      ),
    );
  }
}

class ChatJumpToBottomButton extends StatelessWidget {
  final ValueListenable<bool> showJump;
  final ValueListenable<int> unseen;
  final VoidCallback onTap;

  const ChatJumpToBottomButton({super.key, required this.showJump, required this.unseen, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AnimatedBuilder(
      animation: Listenable.merge([showJump, unseen]),
      builder: (_, _) {
        final unseenCount = unseen.value;
        final countLabel = unseenCount > 99 ? '99+' : '$unseenCount';
        final visible = showJump.value || unseenCount > 0;
        return IgnorePointer(
          ignoring: !visible,
          child: AnimatedScale(
            scale: visible ? 1 : 0.6,
            duration: Motion.base,
            curve: visible ? Motion.pop : Motion.exitCurve,
            child: AnimatedOpacity(
              opacity: visible ? 1 : 0,
              duration: Motion.micro,
              child: GestureDetector(
                onTap: onTap,
                child: AnimatedContainer(
                  duration: Motion.base,
                  curve: Motion.standard,
                  height: 40,
                  padding: EdgeInsets.symmetric(horizontal: unseenCount > 0 ? 14 : 10),
                  decoration: BoxDecoration(
                    color: unseenCount > 0 ? chatMineBubble(c) : c.card,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: c.shadow, blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 22,
                        color: unseenCount > 0 ? Colors.white : c.textPrimary,
                      ),
                      if (unseenCount > 0) ...[
                        const SizedBox(width: 2),
                        Text(
                          S.p0New(countLabel),
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
