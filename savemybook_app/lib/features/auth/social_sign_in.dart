import 'package:flutter/material.dart';

import '../../models/auth_social.dart';
import '../../services/api_service.dart';
import '../../services/social_auth_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/state_views.dart';
import 'phone_sign_in_screen.dart';
import 'social_profile_screen.dart';
import '../../i18n/strings.dart';

class ProviderGlyph extends StatelessWidget {
  final String provider;
  final double size;

  const ProviderGlyph({super.key, required this.provider, this.size = 20});

  static Color colorOf(String provider, AppColors c) => switch (provider) {
        AuthProviders.google => const Color(0xFF4285F4),
        AuthProviders.apple => c.textPrimary,
        AuthProviders.line => const Color(0xFF06C755),
        AuthProviders.discord => const Color(0xFF5865F2),
        _ => c.accent,
      };

  static IconData? iconOf(String provider) => switch (provider) {
        AuthProviders.apple => Icons.apple,
        AuthProviders.phone => Icons.sms_outlined,
        AuthProviders.line => Icons.chat_bubble_rounded,
        AuthProviders.discord => Icons.forum_rounded,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final tint = colorOf(provider, c);
    final icon = iconOf(provider);

    if (icon != null) return Icon(icon, size: size + 2, color: tint);

    // Google 沒有合適的內建圖示，用品牌色的字首代替。
    return SizedBox(
      width: size + 2,
      height: size + 2,
      child: Center(
        child: Text(
          'G',
          style: TextStyle(fontSize: size, fontWeight: FontWeight.w900, color: tint, height: 1),
        ),
      ),
    );
  }
}

class SocialSignInButton extends StatelessWidget {
  final String provider;
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  const SocialSignInButton({
    super.key,
    required this.provider,
    required this.label,
    this.isLoading = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final faded = onPressed == null && !isLoading;

    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: c.textPrimary,
          disabledForegroundColor: c.textPrimary.withValues(alpha: 0.45),
          side: BorderSide(color: c.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Center(
                child: isLoading
                    ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: c.accent))
                    : Opacity(opacity: faded ? 0.45 : 1, child: ProviderGlyph(provider: provider)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 登入頁的社群登入區塊；只顯示伺服器允許且本平台支援的渠道。
class SocialSignInSection extends StatelessWidget {
  final AuthProvidersInfo providers;
  final String? busyProvider;
  final bool disabled;
  final ValueChanged<String> onSelect;

  const SocialSignInSection({
    super.key,
    required this.providers,
    required this.onSelect,
    this.busyProvider,
    this.disabled = false,
  });

  static List<String> visibleIds(AuthProvidersInfo providers) => [
        for (final option in providers.enabled)
          if (SocialAuth.isAvailableOn(option.id)) option.id,
      ];

  String labelOf(String provider) {
    if (provider == AuthProviders.phone) return S.signWithMobileNumber;
    final name = AuthProviders.labelOf(provider);
    return S.signWithP0(name);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final ids = visibleIds(providers);
    if (ids.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: c.divider, height: 1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                S.signWith2,
                style: TextStyle(fontSize: 12, color: c.textSecondary),
              ),
            ),
            Expanded(child: Divider(color: c.divider, height: 1)),
          ],
        ),
        const SizedBox(height: 14),
        for (final id in ids) ...[
          if (id != ids.first) const SizedBox(height: 10),
          SocialSignInButton(
            provider: id,
            label: labelOf(id),
            isLoading: busyProvider == id,
            onPressed: disabled || busyProvider != null ? null : () => onSelect(id),
          ),
        ],
        const SizedBox(height: 14),
        Text(
          S.creatingAccountWithMethodsAboveMeans,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, height: 1.5, color: c.textHint),
        ),
      ],
    );
  }
}

/// 登入與綁定共用的流程；回傳 true 代表已完成。
class SocialSignInFlow {
  const SocialSignInFlow._();

  static Future<bool> signIn(BuildContext context, String provider) async {
    if (AuthProviders.isOauth(provider)) {
      final code = await _oauthCode(context, provider, link: false);
      if (code == null) return false;

      final exchange = await ApiService().exchangeOAuthCode(code);
      if (exchange.isOk) return true;
      if (context.mounted) await _report(context, exchange.code, exchange.message);
      return false;
    }

    final idToken = await _firebaseIdToken(context, provider);
    if (idToken == null || !context.mounted) return false;
    return _submit(context, provider, idToken);
  }

  static Future<AuthIdentityList?> link(BuildContext context, String provider) async {
    final api = ApiService();

    if (AuthProviders.isOauth(provider)) {
      final code = await _oauthCode(context, provider, link: true);
      if (code == null) return null;

      final exchange = await api.exchangeOAuthCode(code);
      if (!exchange.isOk) {
        if (context.mounted) await _report(context, exchange.code, exchange.message);
        return null;
      }
      final refreshed = await api.fetchIdentities();
      return refreshed.isOk ? refreshed.data : null;
    }

    final idToken = await _firebaseIdToken(context, provider);
    if (idToken == null) return null;

    final result = await api.linkIdentity(provider: provider, idToken: idToken);
    if (result.isOk) return result.data;
    if (context.mounted && !result.isCancelled) await _report(context, result.code, result.message);
    return null;
  }

  static Future<String?> _firebaseIdToken(BuildContext context, String provider) async {
    if (provider == AuthProviders.phone) {
      return Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => const PhoneSignInScreen()),
      );
    }
    final result = await SocialAuth.firebaseIdToken(provider);
    if (result.isOk) return result.data;
    if (context.mounted && !result.isCancelled) await _report(context, result.code, result.message);
    return null;
  }

  static Future<String?> _oauthCode(BuildContext context, String provider, {required bool link}) async {
    final start = await ApiService().startOAuth(provider, link: link);
    if (!start.isOk) {
      if (context.mounted && !start.isCancelled) await _report(context, start.code, start.message);
      return null;
    }
    final code = await SocialAuth.awaitOAuthCode(start.data!);
    if (code.isOk) return code.data;
    if (context.mounted && !code.isCancelled) await _report(context, code.code, code.message);
    return null;
  }

  static Future<bool> _submit(
    BuildContext context,
    String provider,
    String idToken, {
    String? email,
    String? nickname,
    bool retried = false,
  }) async {
    final outcome = await ApiService().socialSignIn(
      provider: provider,
      idToken: idToken,
      email: email,
      nickname: nickname,
      acceptLegal: true,
    );
    if (outcome.isOk) return true;
    if (!context.mounted) return false;

    if (outcome.code == AuthCodes.emailRequired && !retried) {
      final profile = await Navigator.push<SocialProfile>(
        context,
        MaterialPageRoute(builder: (_) => SocialProfileScreen(provider: provider)),
      );
      if (profile == null || !context.mounted) return false;
      return _submit(context, provider, idToken,
          email: profile.email, nickname: profile.nickname, retried: true);
    }

    await _report(context, outcome.code, outcome.message);
    return false;
  }

  static Future<void> _report(BuildContext context, String? code, String message) async {
    if (code == AuthCodes.accountExists) {
      await showConfirmDialog(
        context,
        title: S.emailAlreadyRegistered,
        message: S.signWithPasswordThenLinkMethod,
        confirmLabel: S.signWithPassword,
        cancelLabel: S.actionClose,
        icon: Icons.link_off_rounded,
      );
      return;
    }
    showAppSnackBar(context, message, isError: true);
  }
}
