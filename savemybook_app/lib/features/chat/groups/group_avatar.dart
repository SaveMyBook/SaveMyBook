import 'package:flutter/material.dart';

import '../../../utils/app_colors.dart';
import '../../../widgets/app_tiles.dart';

class ChatRoomAvatar extends StatelessWidget {
  final String? imageUrl;
  final bool isGroup;
  final double radius;
  final bool enablePreview;
  final String? previewTitle;
  final VoidCallback? onTap;

  const ChatRoomAvatar({
    super.key,
    required this.imageUrl,
    required this.isGroup,
    this.radius = 20,
    this.enablePreview = false,
    this.previewTitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    if (!isGroup || (url != null && url.isNotEmpty)) {
      return UserAvatar(
        imageUrl: url,
        radius: radius,
        enablePreview: enablePreview,
        previewTitle: previewTitle,
        onTap: onTap,
      );
    }
    final c = AppColors.of(context);
    final placeholder = Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            c.accent.withValues(alpha: c.isDark ? 0.34 : 0.2),
            c.accent.withValues(alpha: c.isDark ? 0.18 : 0.08),
          ],
        ),
      ),
      child: Icon(Icons.groups_rounded, size: radius * 1.1, color: c.accent),
    );
    if (onTap == null) return placeholder;
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: placeholder);
  }
}
