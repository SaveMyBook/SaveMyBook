import 'package:flutter/material.dart';

import '../../models/auth_social.dart';
import '../../utils/app_colors.dart';
import '../../utils/motion.dart';
import 'social_sign_in.dart';
import '../../i18n/strings.dart';

/// 第三方身分尚未綁定帳號時，使用者可以做的三個決定。
enum SocialAccountChoice { linkExisting, createNew }

/// 伺服器回 NO_ACCOUNT_FOR_PROVIDER 時詢問後續處理方式；取消時回傳 null。
Future<SocialAccountChoice?> showSocialAccountChoice(BuildContext context, String provider) {
  final c = AppColors.of(context);
  final name = AuthProviders.labelOf(provider);

  return showGeneralDialog<SocialAccountChoice>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: c.scrim,
    transitionDuration: Motion.base,
    pageBuilder: (ctx, _, _) => _ChoiceDialog(provider: provider, name: name),
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
          child: Transform.scale(scale: 0.94 + 0.06 * curved.value, child: child),
        ),
      );
    },
  );
}

class _ChoiceDialog extends StatelessWidget {
  final String provider;
  final String name;

  const _ChoiceDialog({required this.provider, required this.name});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final tint = ProviderGlyph.colorOf(provider, c);

    return AlertDialog(
      scrollable: true,
      backgroundColor: c.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Center(child: ProviderGlyph(provider: provider, size: 28)),
            ),
            const SizedBox(height: 16),
            Text(
              S.signMethodNotLinkedAccount,
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, color: c.textPrimary, fontSize: 17),
            ),
            const SizedBox(height: 8),
            Text(
              S.p0AccountNotLinkedAnySavemybook(name),
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textSecondary, fontSize: 13.5, height: 1.6),
            ),
          ],
        ),
      ),
      actions: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _action(
              context,
              label: S.iAlreadyAccountSignFirst,
              icon: Icons.link_rounded,
              onPressed: () => Navigator.pop(context, SocialAccountChoice.linkExisting),
            ),
            const SizedBox(height: 10),
            _action(
              context,
              label: S.createNewAccountWithIdentity,
              icon: Icons.person_add_alt_1_rounded,
              primary: true,
              onPressed: () => Navigator.pop(context, SocialAccountChoice.createNew),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 44,
              child: TextButton(
                onPressed: () => Navigator.pop(context, null),
                style: TextButton.styleFrom(foregroundColor: c.textSecondary),
                child: Text(S.actionCancel, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _action(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    bool primary = false,
  }) {
    final c = AppColors.of(context);

    return SizedBox(
      height: 48,
      child: primary
          ? ElevatedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 18),
              label: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: c.accent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            )
          : OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 18),
              label: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: c.textPrimary,
                side: BorderSide(color: c.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
    );
  }
}
