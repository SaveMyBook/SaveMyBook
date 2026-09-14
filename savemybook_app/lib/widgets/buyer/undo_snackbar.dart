import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/app_colors.dart';
import '../app_toast.dart';
import '../../i18n/strings.dart';

Future<bool> showUndoSnackBar(
  BuildContext context,
  String message, {
  IconData icon = Icons.delete_outline_rounded,
  Duration duration = const Duration(seconds: 4),
}) async {
  final c = AppColors.of(context);
  final reason = await showToast(
    context,
    duration: duration,
    builder: (context, close) => ToastCard(
      icon: icon,
      tint: c.textSecondary,
      message: message,
      actionLabel: S.undo2,
      onAction: () {
        HapticFeedback.selectionClick();
        close(ToastCloseReason.action);
      },
    ),
  );
  return reason == ToastCloseReason.action;
}
