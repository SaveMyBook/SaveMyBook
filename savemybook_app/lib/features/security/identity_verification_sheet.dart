import 'package:flutter/material.dart';

import '../../i18n/strings.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_forms.dart';
import '../../widgets/biometric_icon.dart';
import 'set_password_screen.dart';

/// 生物辨識與通行密鑰驗證的入口，回傳權杖代表成功，回傳訊息代表失敗，兩者皆空代表使用者取消。
typedef BiometricVerify = Future<({String? token, String? message})> Function();

typedef PasskeyVerify = BiometricVerify;

/// 這些狀況重試也不會過，訊息顯示為整塊警示並停用送出鍵。
const _blockingCodes = {'RATE_LIMITED', 'PASSWORD_NOT_SET', 'SECURITY_UNAVAILABLE', 'SIGNED_OUT'};

/// 以登入密碼或通行密鑰驗證身分的專用面板。回傳驗證權杖，使用者取消則回傳 null。
/// 提供 [onPasskey] 時預設顯示通行密鑰，輸入密碼改為次要選項。
Future<String?> showIdentityVerificationSheet(
  BuildContext context, {
  required String scope,
  required String reason,
  bool hasPassword = true,
  BiometricVerify? onBiometric,
  String? biometricLabel,
  PasskeyVerify? onPasskey,
}) {
  final c = AppColors.of(context);
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: c.sheetBg,
    constraints: BoxConstraints(maxWidth: 560, maxHeight: MediaQuery.sizeOf(context).height * 0.92),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => IdentityVerificationSheet(
      scope: scope,
      reason: reason,
      hasPassword: hasPassword,
      onBiometric: onBiometric,
      biometricLabel: biometricLabel,
      onPasskey: onPasskey,
    ),
  );
}

class IdentityVerificationSheet extends StatefulWidget {
  final String scope;
  final String reason;
  final bool hasPassword;
  final BiometricVerify? onBiometric;
  final String? biometricLabel;
  final PasskeyVerify? onPasskey;

  const IdentityVerificationSheet({
    super.key,
    required this.scope,
    required this.reason,
    this.hasPassword = true,
    this.onBiometric,
    this.biometricLabel,
    this.onPasskey,
  });

  @override
  State<IdentityVerificationSheet> createState() => _IdentityVerificationSheetState();
}

class _IdentityVerificationSheetState extends State<IdentityVerificationSheet> {
  final ApiService _api = ApiService();
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();

  late bool _hasPassword = widget.hasPassword;
  late bool _usePasskey = widget.onPasskey != null;
  bool _obscure = true;
  bool _submitting = false;
  bool _blocked = false;
  String? _fieldError;
  String? _alert;

  @override
  void initState() {
    super.initState();
    if (_hasPassword && !_usePasskey) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _fail(String code, String message) {
    setState(() {
      if (code == 'PASSWORD_NOT_SET') _hasPassword = false;
      if (_blockingCodes.contains(code)) {
        _alert = message;
        _blocked = true;
      } else {
        _fieldError = message;
      }
    });
  }

  Future<void> _submit() async {
    if (_submitting || _blocked) return;
    final password = _controller.text;
    if (password.isEmpty) {
      setState(() => _fieldError = S.enterPassword);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _fieldError = null;
      _alert = null;
    });

    final outcome = await _api.verifyIdentity(scope: widget.scope, method: 'password', password: password);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (outcome.isSuccess) {
      Navigator.of(context).pop(outcome.token);
      return;
    }
    _fail(outcome.code, outcome.message);
  }

  Future<void> _biometric() => _runExternal(widget.onBiometric);

  Future<void> _passkey() => _runExternal(widget.onPasskey);

  void _switchToPassword() {
    setState(() {
      _usePasskey = false;
      _alert = null;
    });
    if (!_hasPassword) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  void _switchToPasskey() {
    FocusScope.of(context).unfocus();
    setState(() {
      _usePasskey = true;
      _fieldError = null;
      _alert = null;
    });
  }

  Future<void> _runExternal(BiometricVerify? run) async {
    if (run == null || _submitting) return;
    setState(() {
      _submitting = true;
      _fieldError = null;
      _alert = null;
    });
    final result = await run();
    if (!mounted) return;
    setState(() => _submitting = false);
    if (result.token != null) {
      Navigator.of(context).pop(result.token);
      return;
    }
    if (result.message != null) setState(() => _alert = result.message);
  }

  Future<void> _goSetPassword() async {
    final done = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const SetPasswordScreen()));
    if (!mounted || done != true) return;
    setState(() {
      _hasPassword = true;
      _blocked = false;
      _alert = null;
    });
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
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
              _header(c),
              const SizedBox(height: 20),
              if (_usePasskey)
                ..._passkeyBody(c)
              else if (_hasPassword)
                ..._passwordBody(c)
              else
                ..._noPasswordBody(c),
              const SizedBox(height: 4),
              Center(
                child: TextButton(
                  onPressed: _submitting ? null : () => Navigator.of(context).pop(),
                  child: Text(S.actionCancel, style: TextStyle(color: c.textSecondary)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(AppColors c) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(color: c.accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
          child: Icon(Icons.lock_person_rounded, color: c.accent, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                S.verifyS,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: c.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                widget.reason.isNotEmpty
                    ? widget.reason
                    : _usePasskey
                        ? S.verifyIdentityWithPasskeyContinue
                        : S.enterPasswordContinue,
                style: TextStyle(fontSize: 13, height: 1.5, color: c.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _passwordBody(AppColors c) {
    return [
      Text(
        S.password2,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary),
      ),
      const SizedBox(height: 8),
      AppTextField(
        controller: _controller,
        focusNode: _focus,
        hint: S.enterPassword,
        errorText: _fieldError,
        obscureText: _obscure,
        enabled: !_blocked,
        maxLength: 72,
        keyboardType: TextInputType.visiblePassword,
        autofillHints: const [AutofillHints.password],
        textInputAction: TextInputAction.done,
        inputFormatters: [
          PasswordCharactersFormatter(
            onRejected: () => setState(() => _fieldError = S.passwordsCanOnlyContainEnglishLetters),
          ),
        ],
        onChanged: (_) {
          if (_fieldError != null) setState(() => _fieldError = null);
        },
        onSubmitted: (_) => _submit(),
        suffix: IconButton(
          icon: Icon(
            _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 20,
            color: c.iconInactive,
          ),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
      ?_alertBox(c),
      const SizedBox(height: 12),
      _notice(c, Icons.shield_outlined, S.appNeverStoresPasswordUsedOnly),
      const SizedBox(height: 18),
      PrimaryButton(
        label: S.verifyS,
        height: 50,
        isLoading: _submitting,
        onPressed: _blocked ? null : _submit,
      ),
      if (widget.onBiometric != null) ...[
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _submitting ? null : _biometric,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(46),
            foregroundColor: c.accent,
            side: BorderSide(color: c.border),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          icon: BiometricGlyph(label: widget.biometricLabel ?? S.biometrics, color: c.accent, size: 20),
          label: Text(S.verifyWithBiometricsInstead, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
      if (widget.onPasskey != null) ...[
        const SizedBox(height: 4),
        Center(
          child: TextButton.icon(
            onPressed: _submitting ? null : _switchToPasskey,
            icon: Icon(Icons.key_rounded, size: 18, color: c.accent),
            label: Text(S.verifyWithPasskeyInstead, style: TextStyle(color: c.accent)),
          ),
        ),
      ],
    ];
  }

  List<Widget> _passkeyBody(AppColors c) {
    return [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.accent.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.accent.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Icon(Icons.key_rounded, size: 26, color: c.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    S.passkeys,
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: c.textPrimary),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    S.verifyWithFaceIdFingerprintScreen,
                    style: TextStyle(fontSize: 12, height: 1.45, color: c.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ?_alertBox(c),
      const SizedBox(height: 18),
      PrimaryButton(
        label: S.verifyWithPasskey,
        height: 50,
        isLoading: _submitting,
        onPressed: _passkey,
      ),
      if (_hasPassword) ...[
        const SizedBox(height: 4),
        Center(
          child: TextButton(
            onPressed: _submitting ? null : _switchToPassword,
            child: Text(S.useSignPasswordInstead, style: TextStyle(color: c.accent)),
          ),
        ),
      ],
    ];
  }

  List<Widget> _noPasswordBody(AppColors c) {
    return [
      _notice(c, Icons.info_outline_rounded, S.accountWasCreatedWithSocialPhone),
      ?_alertBox(c),
      const SizedBox(height: 18),
      PrimaryButton(label: S.setSignPassword, height: 50, onPressed: _goSetPassword),
    ];
  }

  Widget? _alertBox(AppColors c) {
    final alert = _alert;
    if (alert == null) return null;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: c.danger.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline_rounded, size: 16, color: c.danger),
            const SizedBox(width: 8),
            Expanded(
              child: Text(alert, style: TextStyle(fontSize: 12, height: 1.5, color: c.danger)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notice(AppColors c, IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: c.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: TextStyle(fontSize: 12, height: 1.5, color: c.textSecondary)),
        ),
      ],
    );
  }
}
