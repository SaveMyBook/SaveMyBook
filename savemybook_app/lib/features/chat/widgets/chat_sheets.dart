import 'package:flutter/material.dart';

import '../../../i18n/strings.dart';
import '../../../utils/app_colors.dart';
import '../../../widgets/animations.dart';

enum ChatAttachChoice { camera, gallery, transfer, request, reserve, quickReplies }

Future<ChatAttachChoice?> showChatAttachSheet(BuildContext context, {required bool canReserve, bool canTransfer = false}) {
  final c = AppColors.of(context);
  return showModalBottomSheet<ChatAttachChoice>(
    context: context,
    backgroundColor: c.sheetBg,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) {
      ChatAttachTile tile(IconData icon, String label, Color color, ChatAttachChoice choice) =>
          ChatAttachTile(icon: icon, label: label, color: color, onTap: () => Navigator.pop(ctx, choice));
      final tiles = [
        tile(Icons.photo_camera_rounded, S.takePhoto, const Color(0xFF4F8CC9), ChatAttachChoice.camera),
        tile(Icons.photo_library_rounded, S.chooseFromPhotos, const Color(0xFF3FA37C), ChatAttachChoice.gallery),
        if (canTransfer) ...[
          tile(Icons.payments_rounded, S.transfer, const Color(0xFF14A38B), ChatAttachChoice.transfer),
          tile(Icons.request_quote_rounded, S.request, const Color(0xFFCF5C8A), ChatAttachChoice.request),
        ],
        if (canReserve) tile(Icons.event_available_rounded, S.reserveBook, const Color(0xFFD98613), ChatAttachChoice.reserve),
        tile(Icons.bolt_rounded, S.quickReplies, const Color(0xFF8A6FD1), ChatAttachChoice.quickReplies),
      ];
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: c.divider, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (_, constraints) {
                  final columns = constraints.maxWidth >= 480 ? 6 : 4;
                  return Wrap(
                    runSpacing: 16,
                    children: [
                      for (final t in tiles) SizedBox(width: constraints.maxWidth / columns, child: Center(child: t)),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

void showChatSelectableTextSheet(BuildContext context, String text) {
  final c = AppColors.of(context);
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: c.sheetBg,
    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7, maxWidth: 640),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: SelectableText(text, style: TextStyle(fontSize: 16, height: 1.6, color: c.textPrimary)),
      ),
    ),
  );
}

class ChatAttachTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const ChatAttachTile({super.key, required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return SizedBox(
      width: 76,
      child: PressableScale(
        onTap: onTap,
        haptic: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: c.isDark ? 0.22 : 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: c.textPrimary, height: 1.3),
            ),
          ],
        ),
      ),
    );
  }
}
