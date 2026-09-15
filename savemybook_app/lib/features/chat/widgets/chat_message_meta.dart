import 'package:flutter/material.dart';

import '../../../i18n/strings.dart';
import '../../../utils/app_colors.dart';
import 'chat_format.dart';

class ChatSendFailedMark extends StatelessWidget {
  final VoidCallback onTap;

  const ChatSendFailedMark({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Icon(Icons.error_rounded, size: 20, color: c.danger),
      ),
    );
  }
}

class ChatSendingLabel extends StatelessWidget {
  const ChatSendingLabel({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(S.sending, style: _metaStyle(AppColors.of(context))),
    );
  }
}

class ChatMessageTime extends StatelessWidget {
  final DateTime? createdAt;
  final bool isMine;
  final String? readLabel;
  final bool edited;

  const ChatMessageTime({super.key, required this.createdAt, required this.isMine, this.readLabel, this.edited = false});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final small = _metaStyle(c);
    return Padding(
      padding: const EdgeInsets.only(bottom: 1),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (readLabel != null) Text(readLabel!, style: small),
          if (edited) Text(S.edited, style: small),
          Text(chatClock(createdAt), style: small),
        ],
      ),
    );
  }
}

TextStyle _metaStyle(AppColors c) => TextStyle(fontSize: 10.5, color: c.textSecondary, height: 1.25);
