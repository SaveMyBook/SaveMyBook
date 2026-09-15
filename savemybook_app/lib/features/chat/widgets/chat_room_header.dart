import 'package:flutter/material.dart';

import '../../../i18n/strings.dart';
import '../../../utils/app_colors.dart';
import '../../../widgets/app_header.dart';
import '../groups/group_avatar.dart';

class ChatRoomHeader extends StatelessWidget {
  final String title;
  final String? avatarUrl;
  final bool isGroup;
  final int memberCount;
  final bool muted;
  final bool showBack;
  final bool showAvatar;
  final VoidCallback? onOpenSettings;

  const ChatRoomHeader({
    super.key,
    required this.title,
    required this.isGroup,
    this.avatarUrl,
    this.memberCount = 0,
    this.muted = false,
    this.showBack = true,
    this.showAvatar = true,
    this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    const titleStyle = TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold, height: 1.25);

    return LightStatusBar(
      child: ClipRRect(
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
        child: Container(
          width: double.infinity,
          color: c.headerBg,
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: 56,
              child: Row(
                children: [
                  if (showBack)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    )
                  else
                    const SizedBox(width: 10),
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Material(
                        type: MaterialType.transparency,
                        child: InkWell(
                          onTap: onOpenSettings,
                          borderRadius: BorderRadius.circular(14),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (showAvatar) ...[
                                  isGroup && (avatarUrl == null || avatarUrl!.isEmpty)
                                      ? Container(
                                          width: 34,
                                          height: 34,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.22),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.groups_rounded, size: 20, color: Colors.white),
                                        )
                                      : ChatRoomAvatar(imageUrl: avatarUrl, isGroup: isGroup, radius: 17),
                                  const SizedBox(width: 10),
                                ],
                                Flexible(
                                  child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: titleStyle),
                                ),
                                if (isGroup && memberCount > 0)
                                  Text(' ($memberCount)', style: titleStyle.copyWith(fontWeight: FontWeight.w500)),
                                if (muted) ...[
                                  const SizedBox(width: 5),
                                  Icon(Icons.notifications_off_rounded, size: 15, color: Colors.white.withValues(alpha: 0.75)),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onOpenSettings,
                    tooltip: S.moreOptions,
                    icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
