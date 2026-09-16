import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_forms.dart';
import '../../widgets/app_header.dart';
import '../../widgets/guards.dart';
import '../../widgets/responsive.dart';
import '../../widgets/state_views.dart';
import '../../i18n/strings.dart';

/// 給以社群或簡訊建立、尚未設定密碼的帳號使用；不需要輸入舊密碼。
class SetPasswordScreen extends StatefulWidget {
  const SetPasswordScreen({super.key});

  @override
  State<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends State<SetPasswordScreen> {
  final ApiService _api = ApiService();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isSaving = false;
  bool _done = false;
  bool _obscure = true;
  String? _newError;
  String? _confirmError;

  @override
  void dispose() {
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool _validate() {
    final next = _newController.text;
    final confirm = _confirmController.text;

    final newError = next.isEmpty ? S.enterPassword : Validators.password(next);
    String? confirmError;
    if (confirm.isEmpty) {
      confirmError = S.enterPasswordAgain2;
    } else if (confirm != next) {
      confirmError = S.passwordsDoNotMatch2;
    }

    setState(() {
      _newError = newError;
      _confirmError = confirmError;
    });
    return newError == null && confirmError == null;
  }

  Future<void> _submit() async {
    if (_isSaving || !_validate()) return;
    FocusScope.of(context).unfocus();

    setState(() => _isSaving = true);
    final result = await _api.setLoginPassword(_newController.text);
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (!result.isOk) {
      if (result.isCancelled) return;
      showAppSnackBar(context, result.message, isError: true);
      return;
    }
    setState(() => _done = true);
  }

  void _close() {
    if (!mounted) return;
    final route = ModalRoute.of(context);
    if (route != null && route.isCurrent) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          AppHeader(title: S.setPassword, icon: Icons.password_rounded),
          Expanded(
            child: SwitchIn(
              child: _done
                  ? SuccessView(
                      key: const ValueKey('done'),
                      title: S.passwordSet,
                      message: S.canNowSignWithEmailPassword,
                      actionLabel: S.completed,
                      onAction: _close,
                      onAnimationDone: () => Future.delayed(const Duration(milliseconds: 1200), _close),
                    )
                  : GestureDetector(
                      key: const ValueKey('form'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => FocusScope.of(context).unfocus(),
                      child: LayoutBuilder(
                        builder: (context, constraints) => ListView(
                          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: responsiveListPadding(constraints,
                              maxWidth: Breakpoints.formMaxWidth, horizontal: 20, top: 20, bottom: 40),
                          children: [
                            FadeSlideIn(
                              child: AppCard(
                                margin: const EdgeInsets.only(bottom: 16),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: c.accent.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Icon(Icons.lock_outline_rounded, color: c.accent),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Text(
                                        S.passwordRequiredBeforeCanUnlinkSign,
                                        style: TextStyle(fontSize: 12, height: 1.5, color: c.textSecondary),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            FadeSlideIn(
                              index: 1,
                              child: _field(
                                c,
                                label: S.password,
                                icon: Icons.lock_reset_rounded,
                                controller: _newController,
                                errorText: _newError,
                                onChanged: () => setState(() => _newError = null),
                                onInvalidCharacters: () =>
                                    setState(() => _newError = S.passwordsCanOnlyContainEnglishLetters),
                                footer: PasswordStrengthMeter(password: _newController.text),
                              ),
                            ),
                            FadeSlideIn(
                              index: 2,
                              child: _field(
                                c,
                                label: S.confirmPassword,
                                icon: Icons.check_circle_outline_rounded,
                                controller: _confirmController,
                                errorText: _confirmError,
                                isLast: true,
                                onChanged: () {
                                  if (_confirmError != null) setState(() => _confirmError = null);
                                },
                                onSubmitted: _submit,
                                onInvalidCharacters: () =>
                                    setState(() => _confirmError = S.passwordsCanOnlyContainEnglishLetters),
                              ),
                            ),
                            const SizedBox(height: 24),
                            FadeSlideIn(
                              index: 3,
                              child: PrimaryButton(
                                label: S.setPassword,
                                height: 50,
                                isLoading: _isSaving,
                                onPressed: _submit,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    AppColors c, {
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required VoidCallback onChanged,
    required VoidCallback onInvalidCharacters,
    String? errorText,
    bool isLast = false,
    VoidCallback? onSubmitted,
    Widget? footer,
  }) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: c.accent),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AppTextField(
            controller: controller,
            errorText: errorText,
            obscureText: _obscure,
            maxLength: 64,
            keyboardType: TextInputType.visiblePassword,
            inputFormatters: [PasswordCharactersFormatter(onRejected: onInvalidCharacters)],
            textInputAction: isLast ? TextInputAction.done : TextInputAction.next,
            onChanged: (_) => onChanged(),
            onSubmitted: onSubmitted == null ? null : (_) => onSubmitted(),
            suffix: IconButton(
              icon: Icon(
                _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 20,
                color: c.iconInactive,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          ?footer,
        ],
      ),
    );
  }
}
