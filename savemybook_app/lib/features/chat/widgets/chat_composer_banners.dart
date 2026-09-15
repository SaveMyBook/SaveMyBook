import 'package:flutter/material.dart';

import '../../../i18n/strings.dart';
import '../../../models/chat.dart';
import '../../../utils/app_colors.dart';
import 'chat_bubbles.dart';

class ChatReplyComposer extends StatelessWidget {
  final ChatReply reply;
  final String senderName;
  final VoidCallback onClose;

  const ChatReplyComposer({super.key, required this.reply, required this.senderName, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return _ComposerBanner(
      leading: ChatReplyThumb.has(reply) ? ChatReplyThumb(reply: reply, size: 40) : const _BannerIcon(icon: Icons.reply_rounded),
      title: senderName,
      subtitle: reply.preview.replaceAll('\n', ' '),
      closeTooltip: S.cancelReply,
      onClose: onClose,
    );
  }
}

class ChatEditComposer extends StatelessWidget {
  final String original;
  final VoidCallback onClose;

  const ChatEditComposer({super.key, required this.original, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return _ComposerBanner(
      leading: const _BannerIcon(icon: Icons.edit_rounded),
      title: S.editMessage,
      subtitle: original.replaceAll('\n', ' '),
      closeTooltip: S.cancelEditing,
      onClose: onClose,
    );
  }
}

class _BannerIcon extends StatelessWidget {
  final IconData icon;

  const _BannerIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: c.accent.withValues(alpha: c.isDark ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 20, color: c.accent),
    );
  }
}

class _ComposerBanner extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final String closeTooltip;
  final VoidCallback onClose;

  const _ComposerBanner({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.closeTooltip,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.divider))),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.accent, height: 1.3),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: c.textSecondary, height: 1.3),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            tooltip: closeTooltip,
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.close_rounded, size: 20, color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}
