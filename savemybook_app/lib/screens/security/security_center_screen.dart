import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../i18n/strings.dart';
import '../../models/security.dart';
import '../../services/api_service.dart';
import '../../services/biometric_service.dart';
import '../../services/payment_key_store.dart';
import '../../services/verification_service.dart';
import '../../utils/api_helpers.dart';
import '../../utils/app_colors.dart';
import '../../utils/motion.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_tiles.dart';
import '../../widgets/state_views.dart';
import '../change_password_screen.dart';
import 'login_devices_screen.dart';
import 'payment_pin_screen.dart';

class SecurityCenterScreen extends StatefulWidget {
  const SecurityCenterScreen({super.key});

  @override
  State<SecurityCenterScreen> createState() => _SecurityCenterScreenState();
}

class _SecurityCenterScreenState extends State<SecurityCenterScreen> {
  final _api = ApiService();

  SecurityStatus _status = SecurityStatus.unknown;
  bool _loading = true;
  bool _biometricAvailable = false;
  bool _hasLocalKey = false;
  String _biometricLabel = S.biometrics;
  int? _deviceCount;
  bool _togglingBiometric = false;
  Future<void>? _loadingFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() => _loadingFuture ??= _fetch().whenComplete(() => _loadingFuture = null);

  Future<void> _fetch() async {
    final userId = ApiService.currentUser?.userId;
    final results = await Future.wait([
      _api.fetchSecurityStatus(),
      BiometricService.isAvailable(),
      _api.fetchLoginSessions(),
      if (userId != null) PaymentKeyStore.read(userId) else Future.value(null),
    ]);
    final available = results[1] as bool;
    final label = available ? await BiometricService.label() : S.biometrics;
    if (!mounted) return;
    setState(() {
      _status = results[0] as SecurityStatus;
      _biometricAvailable = available;
      _biometricLabel = label;
      _deviceCount = (results[2] as List<LoginSession>?)?.length;
      _hasLocalKey = results.length > 3 && results[3] != null;
      _loading = false;
    });
  }

  bool get _biometricPayOn => _status.biometricPayEnabled && _hasLocalKey;

  Future<void> _openPin({bool forgot = false}) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => PaymentPinScreen(forgot: forgot)),
    );
    if (changed == true) _load();
  }

  Future<void> _openDevices() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginDevicesScreen()));
    _load();
  }

  Future<void> _toggleBiometricPay(bool value) async {
    if (_togglingBiometric) return;
    if (value && !_status.hasPaymentPin) {
      final setup = await showConfirmDialog(
        context,
        title: S.setPaymentPinFirst,
        message: S.setPaymentPinFirstSoFallback,
        confirmLabel: S.setUpNow,
        icon: Icons.password_rounded,
      );
      if (setup && mounted) _openPin();
      return;
    }
    setState(() => _togglingBiometric = true);
    try {
      if (!value) {
        final ok = await _api.disableBiometricPay();
        if (!mounted) return;
        if (ok) {
          showAppSnackBar(context, S.biometricPaymentTurnedOff);
        } else {
          showAppSnackBar(context, S.updateFailed2, isError: true);
        }
        return;
      }
      if (!await BiometricService.authenticate(reason: S.verifyTurnBiometricPayment, biometricOnly: true)) return;
      if (!mounted) return;
      final token = await VerificationService.requireSensitive(context);
      if (token == null || !mounted) return;
      final (_, error) = await _api.enableBiometricPay(verifyToken: token);
      if (!mounted) return;
      if (error != null) {
        showAppSnackBar(context, error, isError: true);
      } else {
        HapticFeedback.mediumImpact();
        showAppSnackBar(context, S.p0PaymentsTurned(_biometricLabel));
      }
    } finally {
      if (mounted) setState(() => _togglingBiometric = false);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          AppHeader(title: S.accountSecurity, icon: Icons.shield_outlined),
          Expanded(
            child: SwitchIn(
              child: _loading
                  ? const LoadingView.menu()
                  : RefreshIndicator(
                      color: c.accent,
                      onRefresh: _load,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                        children: [
                          if (!_status.available) ...[
                            FadeSlideIn(child: _unavailableCard(c)),
                            const SizedBox(height: 16),
                          ],
                          FadeSlideIn(index: 1, child: _statusCard(c)),
                          const SizedBox(height: 24),
                          _sectionTitle(c, S.paid),
                          FadeSlideIn(index: 2, child: _paymentCard(c)),
                          const SizedBox(height: 24),
                          _sectionTitle(c, S.sign),
                          FadeSlideIn(index: 3, child: _signInCard(c)),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(AppColors c, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: c.textSecondary)),
    );
  }

  Widget _unavailableCard(AppColors c) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: c.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, size: 20, color: c.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              S.securitySettingsUnavailableRightNowMay,
              style: TextStyle(fontSize: 12.5, height: 1.45, color: c.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() => _loading = true);
              _load();
            },
            child: Text(S.retry, style: TextStyle(color: c.accent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _statusCard(AppColors c) {
    final checks = [
      (done: _status.hasPaymentPin, label: S.paymentPin),
      if (_biometricAvailable) (done: _biometricPayOn, label: S.payWithP0(_biometricLabel)),
    ];
    final doneCount = checks.where((x) => x.done).length;
    final ratio = checks.isEmpty ? 1.0 : doneCount / checks.length;
    final good = doneCount == checks.length;
    final tint = good ? c.success : c.warning;

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: ratio),
                  duration: Motion.count,
                  curve: Motion.emphasized,
                  builder: (_, value, _) => Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 56,
                        height: 56,
                        child: CircularProgressIndicator(
                          value: value,
                          strokeWidth: 5,
                          strokeCap: StrokeCap.round,
                          color: tint,
                          backgroundColor: tint.withValues(alpha: 0.15),
                        ),
                      ),
                      SwitchIn(
                        duration: Motion.micro,
                        child: Icon(
                          good ? Icons.verified_user_rounded : Icons.gpp_maybe_rounded,
                          key: ValueKey(good),
                          color: tint,
                          size: 26,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      good ? S.accountWellProtected : S.accountCouldSafer,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      good ? S.paymentPinBiometricPaymentSetCheck : S.setPaymentPinTurnBiometricPayment,
                      style: TextStyle(fontSize: 12, color: c.textSecondary, height: 1.45),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final check in checks)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: (check.done ? c.success : c.textHint).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        check.done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        size: 14,
                        color: check.done ? c.success : c.textHint,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          check.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: check.done ? c.success : c.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _paymentCard(AppColors c) {
    final locked = _status.pinLockedUntil;
    final isLocked = locked != null && locked.isAfter(DateTime.now());

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          AppMenuItem(
            icon: Icons.password_rounded,
            iconColor: isLocked ? c.danger : c.accent,
            title: S.paymentPin,
            subtitle: isLocked
                ? S.tooManyAttemptsLockedUntilP0(formatDateTime(locked))
                : _status.hasPaymentPin
                    ? S.usedConfirmPaymentsCheckout
                    : S.notSetRequiredBeforeCheckout,
            trailingText: _status.hasPaymentPin ? S.change : S.settings,
            isLast: !_status.hasPaymentPin && !_biometricAvailable,
            onTap: _status.available ? _openPin : null,
          ),
          if (_status.hasPaymentPin)
            AppMenuItem(
              icon: Icons.help_outline_rounded,
              iconColor: c.accent,
              title: S.forgotPaymentPin,
              subtitle: S.enterPasswordResetPaymentPin,
              isLast: !_biometricAvailable,
              onTap: _status.available ? () => _openPin(forgot: true) : null,
            ),
          if (_biometricAvailable)
            SwitchListTile.adaptive(
              secondary: _togglingBiometric
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: CircularProgressIndicator(strokeWidth: 2, color: c.accent),
                      ),
                    )
                  : BiometricGlyph(label: _biometricLabel, color: c.accent),
              title: Text(
                S.payWithP0(_biometricLabel),
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: c.textPrimary),
              ),
              subtitle: Text(
                S.ifFailsCanEnterPaymentPin,
                style: TextStyle(fontSize: 12, color: c.textSecondary),
              ),
              value: _biometricPayOn,
              activeTrackColor: c.accent,
              onChanged: _togglingBiometric || !_status.available ? null : _toggleBiometricPay,
            ),
        ],
      ),
    );
  }

  Widget _signInCard(AppColors c) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          AppMenuItem(
            icon: Icons.devices_rounded,
            iconColor: c.accent,
            title: S.signedDevices,
            subtitle: S.viewRemotelySignOutDevices,
            trailingText: _deviceCount == null ? null : S.p0Devices(_deviceCount!),
            onTap: _openDevices,
          ),
          AppMenuItem(
            icon: Icons.lock_reset_rounded,
            iconColor: c.accent,
            title: S.changePassword,
            subtitle: S.otherDevicesNeedSignAgain,
            isLast: true,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen())),
          ),
        ],
      ),
    );
  }
}
