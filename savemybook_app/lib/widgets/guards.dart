import 'package:flutter/material.dart';
import 'app_dialogs.dart';
import 'state_views.dart';
import '../utils/app_colors.dart';
import '../utils/motion.dart';
import '../i18n/strings.dart';

class UnsavedGuard extends StatelessWidget {
  final bool isDirty;
  final Widget child;

  final String? message;

  const UnsavedGuard({
    super.key,
    required this.isDirty,
    required this.child,
    this.message,
  });

  static Future<bool> confirm(BuildContext context, {String? message}) {
    return showConfirmDialog(
      context,
      title: S.discardChanges,
      message: message ?? S.screenUnsavedChangesTheyLostIf,
      confirmLabel: S.discard,
      cancelLabel: S.keepEditing,
      isDestructive: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !isDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await confirm(context, message: message)) navigator.pop();
      },
      child: child,
    );
  }
}

class DisabledHint extends StatelessWidget {
  final bool disabled;
  final String reason;
  final Widget child;

  const DisabledHint({
    super.key,
    required this.disabled,
    required this.reason,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!disabled) return child;

    return Semantics(
      enabled: false,
      hint: reason,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showAppSnackBar(context, reason),
        child: AnimatedOpacity(
          opacity: 0.45,
          duration: Motion.base,
          curve: Motion.standard,
          child: AbsorbPointer(child: child),
        ),
      ),
    );
  }
}

class MissingHint extends StatelessWidget {
  final List<String> missing;

  const MissingHint({super.key, required this.missing});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = missing.join('、');

    return AnimatedSize(
      duration: Motion.base,
      curve: Motion.emphasized,
      alignment: Alignment.topCenter,
      child: missing.isEmpty
          ? const SizedBox(width: double.infinity)
          : Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: c.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 15, color: c.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      S.stillNeededP0(text),
                      style: TextStyle(fontSize: 12, height: 1.4, color: c.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class PasswordStrengthMeter extends StatelessWidget {
  final String password;

  const PasswordStrengthMeter({super.key, required this.password});

  static int scoreOf(String value) {
    if (value.isEmpty) return 0;
    var score = 0;
    if (value.length >= 8) score++;
    if (value.length >= 12) score++;
    if (RegExp(r'[A-Za-z]').hasMatch(value) && RegExp(r'[0-9]').hasMatch(value)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(value) ||
        (RegExp(r'[a-z]').hasMatch(value) && RegExp(r'[A-Z]').hasMatch(value))) {
      score++;
    }
    return score.clamp(1, 4);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final score = scoreOf(password);
    final colors = [c.danger, c.danger, c.warning, c.success, c.success];
    final label = switch (score) {
      0 => '',
      1 => S.weak,
      2 => S.fair,
      3 => S.conditionFair,
      _ => S.strong,
    };

    return AnimatedSize(
      duration: Motion.base,
      curve: Motion.emphasized,
      alignment: Alignment.topCenter,
      child: score == 0
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  for (var i = 0; i < 4; i++) ...[
                    Expanded(
                      child: AnimatedContainer(
                        duration: Duration(milliseconds: 220 + i * 60),
                        curve: Curves.easeOut,
                        height: 4,
                        decoration: BoxDecoration(
                          color: i < score ? colors[score] : c.inputFill,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                    if (i != 3) const SizedBox(width: 4),
                  ],
                  const SizedBox(width: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 34, maxWidth: 72),
                    child: AnimatedSwitcher(
                      duration: Motion.micro,
                      child: Text(
                        label,
                        key: ValueKey(score),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colors[score]),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
