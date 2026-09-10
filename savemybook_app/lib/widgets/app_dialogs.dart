import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = '確定',
  String cancelLabel = '取消',
  bool isDestructive = false,
}) async {
  final c = AppColors.of(context);

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: c.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.bold, color: c.textPrimary, fontSize: 17),
      ),
      content: Text(message, style: TextStyle(color: c.textSecondary, height: 1.5)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(cancelLabel, style: TextStyle(color: c.textSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(
            confirmLabel,
            style: TextStyle(
              color: isDestructive ? c.danger : c.accent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );

  return result ?? false;
}

Future<String?> showTextInputDialog(
  BuildContext context, {
  required String title,
  String? hint,
  String initialValue = '',
  int maxLines = 1,
  int maxLength = 200,
  String confirmLabel = '確定',
}) async {
  final c = AppColors.of(context);
  final controller = TextEditingController(text: initialValue);

  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: c.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.bold, color: c.textPrimary, fontSize: 17),
      ),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLines: maxLines,
        maxLength: maxLength,
        style: TextStyle(color: c.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: c.textHint),
          filled: true,
          fillColor: c.inputFill,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text('取消', style: TextStyle(color: c.textSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, controller.text.trim()),
          child: Text(
            confirmLabel,
            style: TextStyle(color: c.accent, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );

  controller.dispose();
  return result;
}

Future<T?> showOptionSheet<T>(
  BuildContext context, {
  required String title,
  String? subtitle,
  required List<SheetOption<T>> options,
}) {
  final c = AppColors.of(context);

  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: c.sheetBg,
    // 選項一多（例如八種訂單狀態）就會超出螢幕，必須讓它可以捲動。
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.75,
    ),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 14),
          Text(
            title,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(fontSize: 12, color: c.textSecondary)),
          ],
          const SizedBox(height: 8),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: options
                  .map(
                    (o) => ListTile(
                      leading: o.icon == null ? null : Icon(o.icon, color: o.color ?? c.textPrimary),
                      title: Text(o.label, style: TextStyle(color: o.color ?? c.textPrimary)),
                      trailing: o.selected ? Icon(Icons.check_rounded, color: c.accent) : null,
                      onTap: () => Navigator.pop(ctx, o.value),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

class SheetOption<T> {
  final T value;
  final String label;
  final IconData? icon;
  final Color? color;
  final bool selected;

  const SheetOption({
    required this.value,
    required this.label,
    this.icon,
    this.color,
    this.selected = false,
  });
}

Future<T?> runBusy<T>(
  BuildContext context,
  Future<T> Function() task, {
  String? message,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final c = AppColors.of(context);
  var dialogOpen = true;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: c.scrim,
    builder: (_) => PopScope(
      canPop: false,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: c.accent),
              if (message != null) ...[
                const SizedBox(height: 16),
                Text(message, style: TextStyle(color: c.textSecondary, fontSize: 14)),
              ],
            ],
          ),
        ),
      ),
    ),
  ).then((_) => dialogOpen = false);

  try {
    return await task();
  } finally {
    if (dialogOpen && navigator.canPop()) navigator.pop();
  }
}
