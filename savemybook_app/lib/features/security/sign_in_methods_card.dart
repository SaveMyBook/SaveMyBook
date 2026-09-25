import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/auth_social.dart';
import '../../services/api_service.dart';
import '../../services/social_auth_service.dart';
import '../../utils/api_helpers.dart';
import '../../utils/app_colors.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/state_views.dart';
import '../auth/phone_sign_in_screen.dart';
import '../auth/social_sign_in.dart';
import 'set_password_screen.dart';
import '../../i18n/strings.dart';

/// 帳號安全的「登入方式」：列出已綁定項目並提供綁定／解除綁定與設定密碼。
class SignInMethodsCard extends StatefulWidget {
  final bool hasPaymentPin;
  final ValueChanged<AuthIdentityList>? onLoaded;

  /// 外層畫面改變這個值即可要求重新載入（例如在別處設定完密碼）。
  final int refreshTick;

  /// 測試用：直接帶入資料，不再呼叫伺服器。
  final AuthProvidersInfo? initialProviders;
  final AuthIdentityList? initialIdentities;

  const SignInMethodsCard({
    super.key,
    this.hasPaymentPin = false,
    this.refreshTick = 0,
    this.onLoaded,
    this.initialProviders,
    this.initialIdentities,
  });

  @override
  State<SignInMethodsCard> createState() => _SignInMethodsCardState();
}

class _SignInMethodsCardState extends State<SignInMethodsCard> {
  final ApiService _api = ApiService();

  late AuthProvidersInfo _providers = widget.initialProviders ?? AuthProvidersInfo.none;
  late AuthIdentityList _identities = widget.initialIdentities ?? AuthIdentityList.unknown;
  late bool _loading = widget.initialProviders == null;
  String? _error;
  String? _busy;

  @override
  void initState() {
    super.initState();
    if (widget.initialProviders == null) _load();
  }

  @override
  void didUpdateWidget(covariant SignInMethodsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshTick != oldWidget.refreshTick && widget.initialProviders == null) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final providers = await _api.fetchAuthProviders();
    if (!mounted) return;
    if (!providers.socialEnabled) {
      setState(() {
        _providers = providers;
        _loading = false;
      });
      return;
    }

    final identities = await _api.fetchIdentities();
    if (!mounted) return;
    setState(() {
      _providers = providers;
      _loading = false;
      if (identities.isOk && identities.data != null) {
        _identities = identities.data!;
      } else {
        _error = identities.message;
      }
    });
    widget.onLoaded?.call(_identities);
  }

  bool get _needsPassword => !_identities.passwordSet && !widget.hasPaymentPin;

  Future<bool> _requirePassword() async {
    if (!_needsPassword) return true;
    final go = await showConfirmDialog(
      context,
      title: S.setPasswordFirst,
      message: S.changingSignMethodsRequiresIdentityVerification,
      confirmLabel: S.setPassword,
      cancelLabel: S.later,
      icon: Icons.password_rounded,
    );
    if (go && mounted) await _openSetPassword();
    return false;
  }

  Future<void> _openSetPassword() async {
    final done = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SetPasswordScreen()),
    );
    if (done != true || !mounted) return;
    await _load();
    widget.onLoaded?.call(_identities);
  }

  Future<void> _link(String provider) async {
    if (_busy != null || !await _requirePassword()) return;
    if (!mounted) return;

    setState(() => _busy = provider);
    final pending = provider == AuthProviders.phone
        ? _linkPhone()
        : SocialSignInFlow.link(context, provider);
    final result = await pending;
    if (!mounted) return;
    setState(() => _busy = null);
    if (result == null) return;

    setState(() => _identities = result);
    HapticFeedback.mediumImpact();
    final name = AuthProviders.labelOf(provider);
    showAppSnackBar(context, S.p0Linked(name));
    widget.onLoaded?.call(_identities);
  }

  Future<AuthIdentityList?> _linkPhone() async {
    final idToken = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const PhoneSignInScreen(linking: true)),
    );
    if (idToken == null || !mounted) return null;

    final result = await _api.linkIdentity(provider: AuthProviders.phone, idToken: idToken);
    if (result.isOk) return result.data;
    if (mounted && !result.isCancelled) showAppSnackBar(context, result.message, isError: true);
    return null;
  }

  Future<void> _unlink(String provider) async {
    if (_busy != null || !await _requirePassword()) return;
    if (!mounted) return;

    final name = AuthProviders.labelOf(provider);
    final confirmed = await showConfirmDialog(
      context,
      title: S.unlinkP0(name),
      message: S.noLongerAbleSignWayCan,
      confirmLabel: S.unlink,
      isDestructive: true,
      icon: Icons.link_off_rounded,
    );
    if (!confirmed || !mounted) return;

    setState(() => _busy = provider);
    final result = await _api.unlinkIdentity(provider);
    if (!mounted) return;
    setState(() => _busy = null);

    if (!result.isOk) {
      if (!result.isCancelled) showAppSnackBar(context, result.message, isError: true);
      return;
    }
    setState(() => _identities = result.data ?? _identities);
    showAppSnackBar(context, S.p0Unlinked(name));
    widget.onLoaded?.call(_identities);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    if (_loading) {
      return AppCard(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: c.accent)),
        ),
      );
    }

    if (!_providers.socialEnabled) {
      return AppCard(
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, size: 18, color: c.textHint),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                S.socialSmsSignNotAvailableRight,
                style: TextStyle(fontSize: 12.5, height: 1.45, color: c.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return AppCard(child: ErrorView(message: _error, onRetry: _load));
    }

    final available = [
      for (final option in _providers.enabled)
        if (SocialAuth.isAvailableOn(option.id) || _identities.isLinked(option.id)) option.id,
    ];
    final linked = [for (final id in available) if (_identities.isLinked(id)) id];
    final unlinked = [for (final id in available) if (!_identities.isLinked(id)) id];

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_identities.passwordSet) ...[
            _passwordRow(c),
            const SizedBox(height: 14),
            Divider(color: c.divider, height: 1),
            const SizedBox(height: 14),
          ],
          if (linked.isEmpty && unlinked.isEmpty)
            Text(
              S.noSignMethodAvailableLink,
              style: TextStyle(fontSize: 12.5, color: c.textSecondary),
            ),
          for (final id in linked) ...[
            _row(c, id, linked: true),
            if (id != linked.last || unlinked.isNotEmpty) const SizedBox(height: 12),
          ],
          for (final id in unlinked) ...[
            _row(c, id, linked: false),
            if (id != unlinked.last) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _passwordRow(AppColors c) {
    return Row(
      children: [
        Icon(Icons.password_rounded, size: 22, color: c.warning),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                S.noPasswordSet,
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: c.textPrimary),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SmallActionButton(label: S.setPassword, filled: true, onTap: _openSetPassword),
      ],
    );
  }

  Widget _row(AppColors c, String provider, {required bool linked}) {
    final identity = _identities.identityOf(provider);
    final account = identity?.account;
    final boundAt = identity?.createdAt;
    final boundDate = boundAt == null ? null : formatDate(boundAt);
    final subtitle = [
      ?account,
      if (boundDate != null) S.linkedP0(boundDate),
    ].join('　');

    return Row(
      children: [
        SizedBox(width: 26, child: Center(child: ProviderGlyph(provider: provider, size: 20))),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AuthProviders.labelOf(provider),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: c.textPrimary),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, height: 1.35, color: c.textSecondary),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        SmallActionButton(
          label: linked ? S.unlink : S.link,
          filled: !linked,
          isLoading: _busy == provider,
          color: linked ? c.danger : null,
          onTap: _busy != null ? null : () => linked ? _unlink(provider) : _link(provider),
        ),
      ],
    );
  }
}
