import 'package:flutter/material.dart';

import '../../models/ai.dart';
import '../../services/ai_status.dart';
import '../../utils/app_colors.dart';
import '../../utils/motion.dart';
import '../../widgets/responsive.dart';
import '../../widgets/state_views.dart';
import 'ai_support_screen.dart';
import '../../i18n/strings.dart';

class AiSupportEntry extends StatelessWidget {
  final double maxWidth;
  final double horizontal;

  const AiSupportEntry({super.key, this.maxWidth = Breakpoints.readingMaxWidth, this.horizontal = 16});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return ValueListenableBuilder<AiStatusInfo>(
      valueListenable: AiStatus.listenable,
      builder: (context, status, _) => AnimatedSize(
        duration: Motion.base,
        curve: Motion.emphasized,
        alignment: Alignment.topCenter,
        child: !status.support
            ? const SizedBox(width: double.infinity)
            : ResponsiveListPadding(
                maxWidth: maxWidth,
                horizontal: horizontal,
                top: 12,
                bottom: 4,
                builder: (context, padding) => Padding(
                  padding: padding,
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiSupportScreen())),
                    child: Row(
                      children: [
                        const AiAvatar(size: 36),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            S.aiSupport,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c.textPrimary),
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: c.iconInactive),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
