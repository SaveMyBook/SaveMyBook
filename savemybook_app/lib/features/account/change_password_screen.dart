import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/responsive.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_forms.dart';
import '../../widgets/app_header.dart';
import '../../widgets/guards.dart';
import '../../widgets/state_views.dart';
import '../../i18n/strings.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final ApiService _api = ApiService();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isSaving = false;
  bool _done = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  String? _currentError;
  String? _newError;
  String? _confirmError;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool _validate() {
    final current = _currentController.text;
    final next = _newController.text;
    final confirm = _confirmController.text;

    String? currentError;
    String? newError;
    String? confirmError;

    if (current.isEmpty) currentError = S.enterCurrentPassword;

    if (next.isEmpty) {
      newError = S.enterNewPassword;
    } else {
      newError = Validators.password(next);
      if (newError == null && next == current) newError = S.newPasswordMustDifferent;
    }

    if (confirm.isEmpty) {
      confirmError = S.enterNewPasswordAgain;
    } else if (confirm != next) {
      confirmError = S.passwordsDoNotMatch;
    }

    setState(() {
      _currentError = currentError;
      _newError = newError;
      _confirmError = confirmError;
    });

    return currentError == null && newError == null && confirmError == null;
  }

  Future<void> _submit() async {
    if (_isSaving || !_validate()) return;
    FocusScope.of(context).unfocus();

    setState(() => _isSaving = true);
    final error = await _api.changePassword(_currentController.text, _newController.text);
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (error != null) {
      if (error.contains(S.currentPassword)) {
        setState(() => _currentError = error);
      } else if (error.contains(S.newPassword)) {
        setState(() => _newError = error);
      } else {
        showAppSnackBar(context, error, isError: true);
      }
      return;
    }

    setState(() => _done = true);
  }

  void _close() {
    if (!mounted) return;
    final route = ModalRoute.of(context);
    if (route != null && route.isCurrent) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          AppHeader(title: S.changePassword, icon: Icons.key_outlined),
          Expanded(
            child: SwitchIn(
              child: _done
                  ? SuccessView(
                      key: const ValueKey('done'),
                      title: S.passwordUpdated,
                      message: S.otherDevicesNeedSignAgainWith,
                      actionLabel: S.completed,
                      onAction: _close,
                      onAnimationDone: () => Future.delayed(const Duration(milliseconds: 1200), _close),
                    )
                  : GestureDetector(
              key: const ValueKey('form'),
              behavior: HitTestBehavior.opaque,
              onTap: () => FocusScope.of(context).unfocus(),
              child: LayoutBuilder(builder: (context, constraints) => ListView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: responsiveListPadding(constraints, maxWidth: Breakpoints.formMaxWidth, horizontal: 20, top: 20, bottom: 40),
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
                              S.useLeast8CharactersWithBoth,
                              style: TextStyle(fontSize: 12, height: 1.5, color: c.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  FadeSlideIn(
                    index: 1,
                    child: _buildField(
                      c,
                      label: S.currentPassword,
                      icon: Icons.password_rounded,
                      controller: _currentController,
                      errorText: _currentError,
                      obscure: _obscureCurrent,
                      onToggle: () => setState(() => _obscureCurrent = !_obscureCurrent),
                      onChanged: () {
                        if (_currentError != null) setState(() => _currentError = null);
                      },
                    ),
                  ),
                  FadeSlideIn(
                    index: 2,
                    child: _buildField(
                      c,
                      label: S.newPassword,
                      icon: Icons.lock_reset_rounded,
                      controller: _newController,
                      errorText: _newError,
                      obscure: _obscureNew,
                      onToggle: () => setState(() => _obscureNew = !_obscureNew),
                      onChanged: () => setState(() => _newError = null),
                      onInvalidCharacters: () => setState(() => _newError = S.passwordsCanOnlyContainEnglishLetters),
                      footer: PasswordStrengthMeter(password: _newController.text),
                    ),
                  ),
                  FadeSlideIn(
                    index: 3,
                    child: _buildField(
                      c,
                      label: S.confirmNewPassword,
                      icon: Icons.check_circle_outline_rounded,
                      controller: _confirmController,
                      errorText: _confirmError,
                      obscure: _obscureNew,
                      isLast: true,
                      onToggle: () => setState(() => _obscureNew = !_obscureNew),
                      onChanged: () {
                        if (_confirmError != null) setState(() => _confirmError = null);
                      },
                      onSubmitted: _submit,
                      onInvalidCharacters: () => setState(() => _confirmError = S.passwordsCanOnlyContainEnglishLetters),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FadeSlideIn(
                    index: 4,
                    child: PrimaryButton(
                      label: S.updatePassword,
                      height: 50,
                      isLoading: _isSaving,
                      onPressed: _submit,
                    ),
                  ),
                ],
              )),
            ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(
    AppColors c, {
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback onToggle,
    required VoidCallback onChanged,
    String? errorText,
    bool isLast = false,
    VoidCallback? onSubmitted,
    Widget? footer,
    VoidCallback? onInvalidCharacters,
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
            obscureText: obscure,
            maxLength: 64,
            keyboardType: onInvalidCharacters == null ? null : TextInputType.visiblePassword,
            inputFormatters: onInvalidCharacters == null
                ? null
                : [PasswordCharactersFormatter(onRejected: onInvalidCharacters)],
            textInputAction: isLast ? TextInputAction.done : TextInputAction.next,
            onChanged: (_) => onChanged(),
            onSubmitted: onSubmitted == null ? null : (_) => onSubmitted(),
            suffix: IconButton(
              icon: Icon(
                obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 20,
                color: c.iconInactive,
              ),
              onPressed: onToggle,
            ),
          ),
          ?footer,
        ],
      ),
    );
  }
}
