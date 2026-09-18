import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../models/auth_social.dart';
import '../../services/api_service.dart';
import '../../services/social_auth_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/state_views.dart';
import 'link_sign_in_sheet.dart';
import 'phone_sign_in_screen.dart';
import 'social_account_choice.dart';
import 'social_profile_screen.dart';
import '../../i18n/strings.dart';

/// 各渠道的標誌：品牌用 Font Awesome Free 的 brands 字型，簡訊沿用 Material 圖示。
/// 認不得的渠道退回品牌色字首，任何情況都不會留白或丟出例外。
class ProviderGlyph extends StatelessWidget {
  final String provider;
  final double size;

  const ProviderGlyph({super.key, required this.provider, this.size = 20});

  static const Map<String, FaIconData> brandIcons = {
    AuthProviders.google: FontAwesomeIcons.google,
    AuthProviders.apple: FontAwesomeIcons.apple,
    AuthProviders.line: FontAwesomeIcons.line,
    AuthProviders.discord: FontAwesomeIcons.discord,
  };

  static Color colorOf(String provider, AppColors c) => switch (provider) {
        AuthProviders.google => const Color(0xFF4285F4),
        AuthProviders.apple => c.textPrimary,
        AuthProviders.line => const Color(0xFF06C755),
        AuthProviders.discord => const Color(0xFF5865F2),
        _ => c.accent,
      };

  static IconData? iconOf(String provider) => switch (provider) {
        AuthProviders.phone => Icons.sms_outlined,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final side = size + 2;
    final tint = colorOf(provider, AppColors.of(context));
    final brand = brandIcons[provider];
    final icon = iconOf(provider);

    return SizedBox(
      width: side,
      height: side,
      child: Center(
        child: switch ((brand, icon)) {
          // FaIcon 不會把圖示塞進正方形，寬扁的品牌標誌才不會被裁掉。
          (final FaIconData brand, _) => FaIcon(brand, size: size, color: tint),
          (_, final IconData icon) => Icon(icon, size: side, color: tint),
          _ => Text(
              _initialOf(provider),
              style: TextStyle(fontSize: size, fontWeight: FontWeight.w900, color: tint, height: 1),
            ),
        },
      ),
    );
  }

  static String _initialOf(String provider) {
    final label = AuthProviders.labelOf(provider);
    return label.isEmpty ? '?' : label.substring(0, 1).toUpperCase();
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

/// 三個以上渠道時改用的方形圖示按鈕，避免登入頁被一整排長條按鈕塞滿。
class SocialSignInTile extends StatelessWidget {
  final String provider;
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;
  final double? width;

  const SocialSignInTile({
    super.key,
    required this.provider,
    required this.label,
    this.isLoading = false,
    this.onPressed,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final faded = onPressed == null && !isLoading;

    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 54,
              width: double.infinity,
              child: OutlinedButton(
                onPressed: isLoading ? null : onPressed,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  side: BorderSide(color: c.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: isLoading
                    ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: c.accent))
                    : Opacity(opacity: faded ? 0.45 : 1, child: ProviderGlyph(provider: provider, size: 24)),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: faded ? c.textHint : c.textSecondary),
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
  final VoidCallback? onCancel;

  const SocialSignInSection({
    super.key,
    required this.providers,
    required this.onSelect,
    this.onCancel,
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
        if (ids.length > 2)
          // 一列平均分配，五個渠道在手機寬度下仍排得下，不會落單成第二列。
          Row(
            children: [
              for (final id in ids) ...[
                if (id != ids.first) const SizedBox(width: 8),
                Expanded(
                  child: SocialSignInTile(
                    provider: id,
                    label: AuthProviders.labelOf(id),
                    isLoading: busyProvider == id,
                    onPressed: disabled || busyProvider != null ? null : () => onSelect(id),
                  ),
                ),
              ],
            ],
          )
        else
          for (final id in ids) ...[
            if (id != ids.first) const SizedBox(height: 10),
            SocialSignInButton(
              provider: id,
              label: labelOf(id),
              isLoading: busyProvider == id,
              onPressed: disabled || busyProvider != null ? null : () => onSelect(id),
            ),
          ],
        if (onCancel != null)
          Center(
            child: TextButton(
              onPressed: onCancel,
              style: TextButton.styleFrom(foregroundColor: c.textSecondary),
              child: Text(S.actionCancel),
            ),
          ),
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
      if (code == null || !context.mounted) return false;
      return _exchange(context, provider, code);
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
    bool create = false,
    bool retried = false,
  }) async {
    final outcome = await ApiService().socialSignIn(
      provider: provider,
      idToken: idToken,
      email: email,
      nickname: nickname,
      acceptLegal: true,
      create: create,
    );
    if (outcome.isOk) return true;
    if (!context.mounted) return false;

    if (outcome.code == AuthCodes.noAccountForProvider && !create) {
      return switch (await showSocialAccountChoice(context, provider)) {
        SocialAccountChoice.createNew =>
          context.mounted && await _submit(context, provider, idToken, create: true),
        SocialAccountChoice.linkExisting =>
          context.mounted && await _linkExisting(context, provider, idToken: idToken, email: outcome.providerEmail),
        null => false,
      };
    }

    if (outcome.code == AuthCodes.emailRequired && !retried) {
      final profile = await _profile(context, provider);
      if (profile == null || !context.mounted) return false;
      return _submit(context, provider, idToken,
          email: profile.email, nickname: profile.nickname, create: true, retried: true);
    }

    if (outcome.code == AuthCodes.accountExists) {
      return _linkExisting(context, provider,
          idToken: idToken, email: outcome.providerEmail ?? email, emailRegistered: true);
    }

    await _report(context, outcome.code, outcome.message);
    return false;
  }

  /// LINE／Discord：一次性碼在「尚未綁定」與「需補電子郵件」後仍然有效，
  /// 使用者做完選擇可以直接重送，不必再開一次授權頁。
  static Future<bool> _exchange(
    BuildContext context,
    String provider,
    String code, {
    String? email,
    String? nickname,
    bool create = false,
    bool retried = false,
  }) async {
    final outcome = await ApiService().exchangeOAuthCode(
      code,
      create: create,
      email: email,
      nickname: nickname,
    );
    if (outcome.isOk) return true;
    if (!context.mounted) return false;

    if (outcome.code == AuthCodes.noAccountForProvider && !create) {
      return switch (await showSocialAccountChoice(context, provider)) {
        SocialAccountChoice.createNew =>
          context.mounted && await _exchange(context, provider, code, create: true),
        SocialAccountChoice.linkExisting =>
          context.mounted && await _linkExisting(context, provider, oauthCode: code, email: outcome.providerEmail),
        null => false,
      };
    }

    if (outcome.code == AuthCodes.emailRequired && !retried) {
      final profile = await _profile(context, provider);
      if (profile == null || !context.mounted) return false;
      return _exchange(context, provider, code,
          email: profile.email, nickname: profile.nickname, create: true, retried: true);
    }

    if (outcome.code == AuthCodes.accountExists) {
      return _linkExisting(context, provider,
          oauthCode: code, email: outcome.providerEmail ?? email, emailRegistered: true);
    }

    await _report(context, outcome.code, outcome.message);
    return false;
  }

  static bool? passkeyAvailableOverride;

  static Future<bool> _linkExisting(
    BuildContext context,
    String provider, {
    String? idToken,
    String? oauthCode,
    String? email,
    bool emailRegistered = false,
  }) async {
    final linked = await showLinkSignInSheet(
      context,
      provider: provider,
      initialEmail: email,
      emailRegistered: emailRegistered,
      passkeyAvailable: passkeyAvailableOverride,
      submit: ({email, password, assertion}) => ApiService().socialLinkLogin(
        provider: provider,
        idToken: idToken,
        oauthCode: oauthCode,
        email: email,
        password: password,
        assertion: assertion,
      ),
    );
    if (linked && context.mounted) showAppSnackBar(context, S.p0Linked(AuthProviders.labelOf(provider)));
    return linked;
  }

  static Future<SocialProfile?> _profile(BuildContext context, String provider) => Navigator.push<SocialProfile>(
        context,
        MaterialPageRoute(builder: (_) => SocialProfileScreen(provider: provider)),
      );

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
