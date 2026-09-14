import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/verification_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/motion.dart';
import '../../widgets/animations.dart';
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
  if (RegExp(r'^(\d\d)\1\1$').hasMatch(pin) || RegExp(r'^(\d\d\d)\1$').hasMatch(pin)) return S.pinTooEasyGuessTryAnother;
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

  String? _verifyToken;
  String? _firstPin;
  String? _notice;
  int _round = 0;
  bool _verifying = true;
  bool _done = false;
  bool _popped = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _verify());
  }

  Future<void> _verify() async {
    final token = widget.forgot
        ? await VerificationService.requirePassword(context, reason: S.enterPasswordResetPaymentPin)
        : await VerificationService.requireSensitive(context, reason: S.confirmSBeforeSettingPaymentPin);
    if (!mounted) return;
    if (token == null) {
      _finish(false);
      return;
    }
    setState(() {
      _verifyToken = token;
      _verifying = false;
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
        message: S.use6DigitPinConfirmPayments,
        actionLabel: S.completed,
        onAction: () => _finish(true),
        onAnimationDone: () => Future.delayed(const Duration(milliseconds: 900), () => _finish(true)),
      );
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
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
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
                      position: Tween(
                        begin: Offset(confirming ? 0.08 : -0.08, 0),
                        end: Offset.zero,
                      ).animate(animation),
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
                        decoration: BoxDecoration(
                          color: c.accent.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
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
        decoration: BoxDecoration(
          color: active ? c.accent : c.divider,
          borderRadius: BorderRadius.circular(3),
        ),
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
