import 'package:flutter/material.dart';

import '../../i18n/strings.dart';
import '../../models/auth_social.dart';
import '../../models/passkey.dart';
import '../../services/passkey_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_forms.dart';
import 'social_sign_in.dart';

typedef LinkSignInSubmit = Future<AuthResult<void>> Function({
  String? email,
  String? password,
  Map<String, dynamic>? assertion,
});

const _blockingCodes = {
  AuthCodes.codeInvalid,
  AuthCodes.invalidIdToken,
  AuthCodes.methodDisabled,
  AuthCodes.unavailable,
};

Future<bool> showLinkSignInSheet(
  BuildContext context, {
  required String provider,
  required LinkSignInSubmit submit,
  String? initialEmail,
  bool emailRegistered = false,
  bool? passkeyAvailable,
}) async {
  final c = AppColors.of(context);
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: c.sheetBg,
    constraints: BoxConstraints(maxWidth: 560, maxHeight: MediaQuery.sizeOf(context).height * 0.92),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => LinkSignInSheet(
      provider: provider,
      submit: submit,
      initialEmail: initialEmail,
      emailRegistered: emailRegistered,
      passkeyAvailable: passkeyAvailable,
    ),
  );
  return result ?? false;
}

class LinkSignInSheet extends StatefulWidget {
  final String provider;
  final LinkSignInSubmit submit;
  final String? initialEmail;
  final bool emailRegistered;
  final bool? passkeyAvailable;

  const LinkSignInSheet({
    super.key,
    required this.provider,
    required this.submit,
    this.initialEmail,
    this.emailRegistered = false,
    this.passkeyAvailable,
  });

  @override
  State<LinkSignInSheet> createState() => _LinkSignInSheetState();
}

class _LinkSignInSheetState extends State<LinkSignInSheet> {
  late final TextEditingController _email = TextEditingController(text: widget.initialEmail ?? '');
  final TextEditingController _password = TextEditingController();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  late bool _passkey = widget.passkeyAvailable ?? false;
  bool _obscure = true;
  bool _submitting = false;
  bool _passkeyBusy = false;
  bool _blocked = false;
  String? _emailError;
  String? _passwordError;
  String? _alert;

  bool get _busy => _submitting || _passkeyBusy;

  @override
  void initState() {
    super.initState();
    if (widget.passkeyAvailable == null) _detectPasskey();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      (_email.text.isEmpty ? _emailFocus : _passwordFocus).requestFocus();
    });
  }

  Future<void> _detectPasskey() async {
    final usable = await PasskeyService.isUsable();
    if (mounted && usable) setState(() => _passkey = true);
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submitPassword() async {
    if (_busy || _blocked) return;
    final email = _email.text.trim();
    final password = _password.text;
    final emailError = email.isEmpty
        ? S.enterEmail
        : !Validators.isEmail(email)
            ? S.emailAddressNotValid
            : null;
    final passwordError = password.isEmpty ? S.enterPassword : null;
    setState(() {
      _emailError = emailError;
      _passwordError = passwordError;
      _alert = null;
    });
    if (emailError != null || passwordError != null) return;

    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    final outcome = await widget.submit(email: email, password: password);
    if (!mounted) return;
    setState(() => _submitting = false);
    _finish(outcome);
  }

  Future<void> _submitPasskey() async {
    if (_busy || _blocked) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _passkeyBusy = true;
      _alert = null;
      _emailError = null;
      _passwordError = null;
    });

    final step = await PasskeyService.loginAssertion(immediate: false);
    if (!mounted) return;
    final assertion = step.assertion;
    if (assertion == null) {
      final failure = step.failure!;
      setState(() {
        _passkeyBusy = false;
        if (!failure.isCancelled) _alert = failure.message;
      });
      return;
    }

    final outcome = await widget.submit(assertion: assertion);
    if (outcome.code == 'PASSKEY_NOT_RECOGNIZED') {
      await PasskeyService.forgetIfUnknown(PasskeyOutcome.fail(outcome.code!, outcome.message), step);
    }
    if (!mounted) return;
    setState(() => _passkeyBusy = false);
    _finish(outcome);
  }

  void _finish(AuthResult<void> outcome) {
    if (outcome.isOk) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      switch (outcome.code) {
        case 'INVALID_PASSWORD':
          _password.clear();
          _passwordError = outcome.message;
          _passwordFocus.requestFocus();
        case 'ACCOUNT_NOT_FOUND':
          _emailError = outcome.message;
        default:
          _alert = outcome.message;
          if (_blockingCodes.contains(outcome.code)) _blocked = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final name = AuthProviders.labelOf(widget.provider);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: AutofillGroup(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: c.divider, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 18),
                _header(c, name),
                const SizedBox(height: 20),
                AppTextField(
                  controller: _email,
                  focusNode: _emailFocus,
                  label: S.email,
                  hint: 'name@example.com',
                  errorText: _emailError,
                  enabled: !_busy && !_blocked,
                  maxLength: 255,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email, AutofillHints.username],
                  textInputAction: TextInputAction.next,
                  onChanged: (_) {
                    if (_emailError != null) setState(() => _emailError = null);
                  },
                  onSubmitted: (_) => _passwordFocus.requestFocus(),
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _password,
                  focusNode: _passwordFocus,
                  label: S.password,
                  hint: S.enterPassword,
                  errorText: _passwordError,
                  obscureText: _obscure,
                  enabled: !_busy && !_blocked,
                  maxLength: 64,
                  keyboardType: TextInputType.visiblePassword,
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.done,
                  onChanged: (_) {
                    if (_passwordError != null) setState(() => _passwordError = null);
                  },
                  onSubmitted: (_) => _submitPassword(),
                  suffix: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 20,
                      color: c.iconInactive,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                if (_alert != null) ...[
                  const SizedBox(height: 12),
                  _alertBox(c, _alert!),
                ],
                const SizedBox(height: 18),
                PrimaryButton(
                  label: S.signLink,
                  height: 50,
                  isLoading: _submitting,
                  onPressed: _blocked || _passkeyBusy ? null : _submitPassword,
                ),
                if (_passkey) ...[
                  const SizedBox(height: 10),
                  SecondaryButton(
                    label: S.signWithPasskey,
                    icon: Icons.key_rounded,
                    height: 48,
                    isLoading: _passkeyBusy,
                    onPressed: _blocked || _submitting ? null : _submitPasskey,
                  ),
                ],
                const SizedBox(height: 4),
                Center(
                  child: TextButton(
                    onPressed: _busy ? null : () => Navigator.of(context).pop(false),
                    child: Text(S.actionCancel, style: TextStyle(color: c.textSecondary)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(AppColors c, String name) {
    final tint = ProviderGlyph.colorOf(widget.provider, c);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(color: tint.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
          child: Center(child: ProviderGlyph(provider: widget.provider, size: 22)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                S.signAccount,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: c.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                widget.emailRegistered ? S.emailAlreadyRegisteredSignLinkName(name) : S.signLinkNameCanThenSign(name, name),
                style: TextStyle(fontSize: 13, height: 1.5, color: c.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _alertBox(AppColors c, String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: c.danger.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, size: 16, color: c.danger),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: TextStyle(fontSize: 12, height: 1.5, color: c.danger))),
        ],
      ),
    );
  }
}
