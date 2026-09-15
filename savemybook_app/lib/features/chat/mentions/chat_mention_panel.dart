import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../i18n/strings.dart';
import '../../../utils/app_colors.dart';
import '../../../widgets/app_tiles.dart';
import 'chat_mention_controller.dart';

class ChatMentionPanel extends StatelessWidget {
  static const rowHeight = 52.0;

  final ChatMentionController controller;

  const ChatMentionPanel({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final candidates = controller.candidates;
    final screen = MediaQuery.sizeOf(context).height;
    final maxHeight = math.min(rowHeight * 4.5, math.max(rowHeight * 2, screen * 0.28));

    return Container(
      key: const ValueKey('mention_panel'),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.divider))),
      constraints: BoxConstraints(maxHeight: math.min(maxHeight, candidates.length * rowHeight + 8)),
      child: Semantics(
        label: S.mentionMembers,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: candidates.length,
          itemExtent: rowHeight,
          itemBuilder: (context, i) => _MentionRow(
            candidate: candidates[i],
            onTap: () {
              HapticFeedback.selectionClick();
              controller.select(candidates[i]);
            },
          ),
        ),
      ),
    );
  }
}

class _MentionRow extends StatelessWidget {
  final ChatMentionCandidate candidate;
  final VoidCallback onTap;

  const _MentionRow({required this.candidate, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final nickname = candidate.nickname;
    final showNickname = nickname != null && nickname.isNotEmpty && nickname != candidate.name;

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              candidate.isEveryone
                  ? Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: c.accent.withValues(alpha: c.isDark ? 0.24 : 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.alternate_email_rounded, size: 17, color: c.accent),
                    )
                  : UserAvatar(imageUrl: candidate.avatarUrl, radius: 16),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  candidate.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: c.textPrimary),
                ),
              ),
              if (showNickname) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    nickname,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: c.textSecondary),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
