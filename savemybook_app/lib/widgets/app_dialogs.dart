import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/app_radius.dart';
import '../utils/motion.dart';
import '../i18n/strings.dart';

Future<T?> _showAnimatedDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  Color? barrierColor,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: barrierColor ?? AppColors.of(context).scrim,
    transitionDuration: Motion.base,
    pageBuilder: (ctx, _, _) => builder(ctx),
    transitionBuilder: (ctx, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Motion.emphasized,
        reverseCurve: Motion.exitCurve,
      );
      return FadeTransition(
        opacity: curved,
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - curved.value)),
          child: Transform.scale(
            scale: 0.94 + 0.06 * curved.value,
            child: child,
          ),
        ),
      );
    },
  );
}

Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String? confirmLabel,
  String? cancelLabel,
  bool isDestructive = false,
  IconData? icon,
}) async {
  final c = AppColors.of(context);
  final tint = isDestructive ? c.danger : c.accent;

  final result = await _showAnimatedDialog<bool>(
    context,
    builder: (ctx) => AlertDialog(
      scrollable: true,
      backgroundColor: c.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon ?? (isDestructive ? Icons.warning_amber_rounded : Icons.help_outline_rounded),
              color: tint,
              size: 24,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold, color: c.textPrimary, fontSize: 17),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: c.textSecondary, fontSize: 13.5, height: 1.6),
          ),
        ],
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 46,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: TextButton.styleFrom(
                    backgroundColor: c.inputFill,
                    foregroundColor: c.textSecondary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    cancelLabel ?? S.actionCancel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 46,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tint,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    confirmLabel ?? S.actionConfirm,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
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
  String? confirmLabel,
  String? message,
  bool obscure = false,
  bool isDestructive = false,
  String? Function(String value)? validator,
  TextInputType? keyboardType,
}) {
  return _showAnimatedDialog<String>(
    context,
    builder: (ctx) => _TextInputDialog(
      title: title,
      hint: hint,
      initialValue: initialValue,
      maxLines: maxLines,
      maxLength: maxLength,
      confirmLabel: confirmLabel,
      message: message,
      obscure: obscure,
      isDestructive: isDestructive,
      validator: validator,
      keyboardType: keyboardType,
    ),
  );
}

class _TextInputDialog extends StatefulWidget {
  final String title;
  final String? hint;
  final String initialValue;
  final int maxLines;
  final int maxLength;
  final String? confirmLabel;
  final String? message;
  final bool obscure;
  final bool isDestructive;
  final String? Function(String value)? validator;
  final TextInputType? keyboardType;

  const _TextInputDialog({
    required this.title,
    required this.hint,
    required this.initialValue,
    required this.maxLines,
    required this.maxLength,
    required this.confirmLabel,
    required this.message,
    required this.obscure,
    required this.isDestructive,
    required this.validator,
    required this.keyboardType,
  });

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  late final TextEditingController _controller = TextEditingController(text: widget.initialValue);
  late bool _hidden = widget.obscure;
  String? _error;
  bool _closing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_closing) return;
    final value = _controller.text.trim();
    final error = widget.validator?.call(value);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    _closing = true;
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final singleLine = widget.obscure || widget.maxLines == 1;

    return AlertDialog(
      backgroundColor: c.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        widget.title,
        style: TextStyle(fontWeight: FontWeight.bold, color: c.textPrimary, fontSize: 17),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.message != null) ...[
              Text(
                widget.message!,
                style: TextStyle(fontSize: 14, height: 1.5, color: c.textSecondary),
              ),
              const SizedBox(height: 14),
            ],
            TextField(
              controller: _controller,
              autofocus: true,
              obscureText: _hidden,
              enableSuggestions: !widget.obscure,
              autocorrect: !widget.obscure,
              keyboardType: widget.keyboardType,
              maxLines: singleLine ? 1 : widget.maxLines,
              maxLength: widget.obscure ? null : widget.maxLength,
              textInputAction: singleLine ? TextInputAction.done : TextInputAction.newline,
              onSubmitted: singleLine ? (_) => _submit() : null,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              style: TextStyle(color: c.textPrimary),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: TextStyle(color: c.textHint),
                errorText: _error,
                filled: true,
                fillColor: c.inputFill,
                suffixIcon: widget.obscure
                    ? IconButton(
                        icon: Icon(
                          _hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 20,
                          color: c.iconInactive,
                        ),
                        onPressed: () => setState(() => _hidden = !_hidden),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.control),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(S.actionCancel, style: TextStyle(color: c.textSecondary)),
        ),
        TextButton(
          onPressed: _submit,
          child: Text(
            widget.confirmLabel ?? S.actionConfirm,
            style: TextStyle(
              color: widget.isDestructive ? c.danger : c.accent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
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
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(color: c.divider, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: c.textSecondary),
              ),
            ),
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

  final route = DialogRoute<void>(
    context: context,
    themes: InheritedTheme.capture(from: context, to: navigator.context),
    barrierDismissible: false,
    barrierColor: c.scrim,
    builder: (_) => PopScope(
      canPop: false,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 260),
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
                Material(
                  type: MaterialType.transparency,
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: c.textSecondary, fontSize: 14),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
  navigator.push(route);

  try {
    return await task();
  } finally {
    if (route.isCurrent) {
      navigator.pop();
    } else if (route.isActive) {
      navigator.removeRoute(route);
    }
  }
}
