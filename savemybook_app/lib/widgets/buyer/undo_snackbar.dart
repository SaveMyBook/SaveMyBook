import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/app_colors.dart';
import '../state_views.dart';
import '../../i18n/strings.dart';

Future<bool> showUndoSnackBar(
  BuildContext context,
  String message, {
  IconData icon = Icons.delete_outline_rounded,
  Duration duration = const Duration(seconds: 4),
}) async {
  final c = AppColors.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final overlapsNav = kBottomNavVisible && (ModalRoute.of(context)?.isFirst ?? false);
  final bottomInset = MediaQuery.of(context).viewInsets.bottom;
  final bottomMargin = bottomInset > 0 ? 16.0 : (overlapsNav ? 74.0 : 16.0);

  messenger.hideCurrentSnackBar();
  final controller = messenger.showSnackBar(
    SnackBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      padding: EdgeInsets.zero,
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.fromLTRB(16, 0, 16, bottomMargin),
      duration: duration,
      content: Container(
        padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border),
          boxShadow: [BoxShadow(color: c.shadow, blurRadius: 20, offset: const Offset(0, 6))],
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: c.textSecondary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 18, color: c.textSecondary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13.5, height: 1.4, fontWeight: FontWeight.w500, color: c.textPrimary),
              ),
            ),
            const SizedBox(width: 4),
            TextButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                messenger.hideCurrentSnackBar(reason: SnackBarClosedReason.action);
              },
              style: TextButton.styleFrom(
                foregroundColor: c.accent,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(0, 36),
              ),
              child: Text(S.undo2, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    ),
  );

  final reason = await controller.closed;
  return reason == SnackBarClosedReason.action;
}
