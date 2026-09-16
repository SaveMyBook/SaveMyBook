import 'package:flutter/material.dart';

import '../../models/security.dart';
import '../../services/api_service.dart';
import '../../services/verification_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/motion.dart';
import '../../widgets/responsive.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_forms.dart';
import '../../widgets/app_header.dart';
import '../../widgets/pin_pad.dart';
import '../../widgets/state_views.dart';
import '../../i18n/strings.dart';

String? paymentPinProblem(String pin) {
  if (!RegExp(r'^\d{6}$').hasMatch(pin)) return S.paymentPinMust6Digits;
  if (RegExp(r'^(\d)\1{5}$').hasMatch(pin)) return S.pinTooEasyGuessTryAnother;
  final digits = pin.split('').map(int.parse).toList();
  final steps = <int>{for (var i = 1; i < digits.length; i++) (digits[i] - digits[i - 1] + 10) % 10};
  if (steps.length == 1 && (steps.contains(1) || steps.contains(9))) return S.pinTooEasyGuessTryAnother;
  if (RegExp(r'^(\d\d)\1\1$').hasMatch(pin) || RegExp(r'^(\d\d\d)\1$').hasMatch(pin))
    return S.pinTooEasyGuessTryAnother;
  return null;
}

class PaymentPinScreen extends StatefulWidget {
  final bool forgot;

  const PaymentPinScreen({super.key, this.forgot = false});

  @override
  State<PaymentPinScreen> createState() => _PaymentPinScreenState();
}

class _PaymentPinScreenState extends State<PaymentPinScreen> {
  final _api = ApiService();

  final _password = TextEditingController();

  String? _verifyToken;
  String? _firstPin;
  String? _notice;
  int _round = 0;
  bool _verifying = true;
  bool _needsPassword = false;
  bool _passwordHidden = true;
  bool _submitting = false;
  String? _passwordError;
  String? _loadError;
  bool _done = false;
  bool _popped = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _verify());
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  // 未設定交易密碼時改在頁面內輸入登入密碼，不在換頁動畫期間疊加對話框。
  Future<void> _verify() async {
    setState(() {
      _loadError = null;
      _needsPassword = false;
    });

    if (!widget.forgot) {
      final cached = VerificationService.cachedSensitiveToken;
      if (cached != null) return _verified(cached);

      final status = await _api.fetchSecurityStatus().timeout(
        const Duration(seconds: 15),
        onTimeout: () => SecurityStatus.unknown,
      );
      if (!mounted) return;
      if (!status.available) {
        setState(() => _loadError = S.networkError);
        return;
      }
      if (status.hasPaymentPin) {
        final token = await VerificationService.requireSensitive(context, reason: S.confirmSBeforeSettingPaymentPin);
        if (!mounted) return;
        if (token == null) return _finish(false);
        return _verified(token);
      }
    }

    setState(() => _needsPassword = true);
  }

  Future<void> _submitPassword() async {
    if (_submitting) return;
    final password = _password.text;
    if (password.isEmpty) {
      setState(() => _passwordError = S.enterPassword);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _passwordError = null;
    });
    final outcome = await _api.verifyIdentity(scope: 'sensitive', method: 'password', password: password);
    if (!mounted) return;
    setState(() => _submitting = false);
    final token = outcome.token;
    if (!outcome.isSuccess || token == null) {
      setState(() => _passwordError = outcome.message);
      return;
    }
    VerificationService.rememberSensitive(token);
    _verified(token);
  }

  void _verified(String token) {
    if (!mounted) return;
    setState(() {
      _verifyToken = token;
      _verifying = false;
      _needsPassword = false;
    });
  }

  void _finish(bool result) {
    if (_popped || !mounted) return;
    _popped = true;
    Navigator.pop(context, result);
  }

  void _restart(String notice) {
    setState(() {
      _firstPin = null;
      _notice = notice;
      _round++;
    });
  }

  Future<String?> _onPin(String pin) async {
    if (_firstPin == null) {
      final problem = paymentPinProblem(pin);
      if (problem != null) return problem;
      setState(() {
        _firstPin = pin;
        _notice = null;
        _round++;
      });
      return null;
    }

    if (pin != _firstPin) {
      _restart(S.pinsDonTMatchStartAgain);
      return null;
    }

    final error = await _api.setPaymentPin(pin, verifyToken: _verifyToken!);
    if (!mounted) return null;
    if (error != null) {
      _restart(error);
      return null;
    }
    setState(() => _done = true);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final confirming = _firstPin != null;

    final Widget body;
    if (_done) {
      body = SuccessView(
        key: const ValueKey('done'),
        title: widget.forgot ? S.paymentPinReset : S.paymentPinSet,
        actionLabel: S.completed,
        onAction: () => _finish(true),
        onAnimationDone: () => Future.delayed(const Duration(milliseconds: 900), () => _finish(true)),
      );
    } else if (_verifying && _loadError != null) {
      body = ErrorView(key: const ValueKey('error'), message: _loadError!, onRetry: _verify);
    } else if (_verifying && _needsPassword) {
      body = _buildPasswordForm(c);
    } else if (_verifying) {
      body = Center(
        key: const ValueKey('verifying'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Breathe(child: Icon(Icons.verified_user_outlined, size: 56, color: c.accent.withValues(alpha: 0.7))),
            const SizedBox(height: 16),
            Text(S.verifyingIdentity, style: TextStyle(fontSize: 14, color: c.textSecondary)),
          ],
        ),
      );
    } else {
      body = LayoutBuilder(
        key: const ValueKey('entry'),
        builder: (context, constraints) => SingleChildScrollView(
          padding: responsiveListPadding(constraints, maxWidth: 440, horizontal: 24, top: 24, bottom: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _StepIndicator(step: confirming ? 2 : 1),
                const SizedBox(height: 20),
                AnimatedSwitcher(
                  duration: Motion.base,
                  switchInCurve: Motion.enterCurve,
                  switchOutCurve: Motion.exitCurve,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween(begin: Offset(confirming ? 0.08 : -0.08, 0), end: Offset.zero).animate(animation),
                      child: child,
                    ),
                  ),
                  child: Column(
                    key: ValueKey(_round),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(color: c.accent.withValues(alpha: 0.12), shape: BoxShape.circle),
                        child: Icon(
                          confirming ? Icons.verified_user_outlined : Icons.lock_outline_rounded,
                          size: 32,
                          color: c.accent,
                        ),
                      ),
                      const SizedBox(height: 16),
                      PinEntryPanel(
                        title: confirming ? S.enterAgainConfirm : S.set6DigitPaymentPin,
                        subtitle: confirming ? S.enterSamePinAgain : S.avoidRepeatedSequentialPatternedDigits,
                        initialError: _notice,
                        onCompleted: _onPin,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: !_done,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish(true);
      },
      child: Scaffold(
        backgroundColor: c.scaffold,
        body: Column(
          children: [
            AppHeader(
              title: widget.forgot ? S.resetPaymentPin : S.paymentPin,
              icon: Icons.password_rounded,
              onBack: _done ? () => _finish(true) : null,
            ),
            Expanded(child: SwitchIn(child: body)),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordForm(AppColors c) {
    return LayoutBuilder(key: const ValueKey('password'), builder: (context, constraints) => SingleChildScrollView(
      padding: responsiveListPadding(constraints, maxWidth: 480, horizontal: 24, top: 40, bottom: 24),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: c.accent.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(Icons.verified_user_outlined, size: 32, color: c.accent),
          ),
          const SizedBox(height: 16),
          Text(
            S.verifyS,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            widget.forgot ? S.enterPasswordResetPaymentPin : S.confirmSBeforeSettingPaymentPin,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, height: 1.5, color: c.textSecondary),
          ),
          const SizedBox(height: 24),
          AppCard(
            child: AutofillGroup(
              child: AppTextField(
                controller: _password,
                label: S.password,
                hint: S.enterPassword,
                obscureText: _passwordHidden,
                errorText: _passwordError,
                enabled: !_submitting,
                maxLength: 72,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                onChanged: (_) {
                  if (_passwordError != null) setState(() => _passwordError = null);
                },
                onSubmitted: (_) => _submitPassword(),
                suffix: IconButton(
                  icon: Icon(
                    _passwordHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 20,
                    color: c.iconInactive,
                  ),
                  onPressed: () => setState(() => _passwordHidden = !_passwordHidden),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          PrimaryButton(label: S.confirm, isLoading: _submitting, onPressed: _submitting ? null : _submitPassword),
        ],
      ),
    ));
  }
}

class _StepIndicator extends StatelessWidget {
  final int step;

  const _StepIndicator({required this.step});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    Widget dot(int index) {
      final active = step >= index;
      return AnimatedContainer(
        duration: Motion.base,
        curve: Motion.emphasized,
        width: step == index ? 28 : 10,
        height: 6,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(color: active ? c.accent : c.divider, borderRadius: BorderRadius.circular(3)),
      );
    }

    return Column(
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: [dot(1), dot(2)]),
        const SizedBox(height: 8),
        Text(
          S.stepP02(step),
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.textHint),
        ),
      ],
    );
  }
}
