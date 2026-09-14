import 'package:flutter/material.dart';

import '../i18n/strings.dart';
import '../models/security.dart';
import '../screens/security/payment_pin_screen.dart';
import '../utils/app_colors.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/biometric_icon.dart';
import '../widgets/pin_pad.dart';
import '../widgets/state_views.dart';
import 'api_service.dart';
import 'biometric_service.dart';
import 'payment_key_store.dart';

class PaymentSummary {
  final double amount;
  final String detail;

  const PaymentSummary({required this.amount, required this.detail});
}

class VerificationService {
  static GlobalKey<NavigatorState>? navigatorKey;
  static PaymentSummary? paymentSummary;

  static String? _sensitiveToken;
  static DateTime? _sensitiveExpiresAt;
  static String? _sensitiveOwner;
  static Future<String?>? _inFlight;

  static void clearCache() {
    _sensitiveToken = null;
    _sensitiveExpiresAt = null;
  }

  static Future<String?> handle(VerificationRequest request) {
    return _inFlight ??= _handle(request).whenComplete(() => _inFlight = null);
  }

  // 不可共用 _inFlight：付款驗證流程會開啟設定交易密碼頁，該頁再次要求驗證時若等待同一個 Future 會互相卡死。
  static Future<String?> requireSensitive(BuildContext context, {String? reason}) {
    return _handle(
      VerificationRequest(scope: 'sensitive', methods: const ['password', 'pin', 'biometric'], message: reason ?? ''),
      context: context,
    );
  }

  static String? get cachedSensitiveToken {
    final cached = _sensitiveToken;
    final expiresAt = _sensitiveExpiresAt;
    if (cached == null || expiresAt == null || _sensitiveOwner != ApiService.authToken) return null;
    return DateTime.now().isBefore(expiresAt) ? cached : null;
  }

  static void rememberSensitive(String token) =>
      _remember(const VerificationRequest(scope: 'sensitive', methods: [], message: ''), token);

  static Future<String?> _handle(VerificationRequest request, {BuildContext? context}) async {
    final ctx = context ?? navigatorKey?.currentContext;
    if (ctx == null) return null;

    if (!request.isPayment) {
      final cached = cachedSensitiveToken;
      if (cached != null) return cached;
    }

    final api = ApiService();
    final status = await api.fetchSecurityStatus().timeout(const Duration(seconds: 15), onTimeout: () => SecurityStatus.unknown);
    if (!ctx.mounted) return null;

    if (request.isPayment && !status.available) {
      showAppSnackBar(ctx, S.couldNotReachServer, isError: true);
      return null;
    }

    if (request.isPayment && !status.hasPaymentPin) {
      final setup = await showConfirmDialog(
        ctx,
        title: S.setPaymentPinFirst,
        message: S.protectCoinsCheckoutRequires6Digit,
        confirmLabel: S.setUpNow,
        icon: Icons.password_rounded,
      );
      if (!setup || !ctx.mounted) return null;
      final done = await Navigator.of(ctx).push<bool>(MaterialPageRoute(builder: (_) => const PaymentPinScreen()));
      if (done != true || !ctx.mounted) return null;
    }

    final userId = ApiService.currentUser?.userId;
    final canUseBiometric = request.methods.contains('biometric') && status.biometricPayEnabled && userId != null;
    if (canUseBiometric) {
      final key = await PaymentKeyStore.read(userId);
      if (key != null && await BiometricService.isAvailable()) {
        final reason = request.isPayment
            ? S.confirmPaymentP0Coins((paymentSummary?.amount ?? 0).toStringAsFixed(0))
            : S.verifyIdentityContinue;
        if (await BiometricService.authenticate(reason: reason, biometricOnly: true)) {
          final outcome = await api.verifyIdentity(scope: request.scope, method: 'biometric', key: key);
          if (outcome.isSuccess) return _remember(request, outcome.token!);
          if (outcome.code == 'BIOMETRIC_KEY_INVALID') await PaymentKeyStore.clear();
        }
      }
    }
    if (!ctx.mounted) return null;

    final hasPin = request.isPayment || status.hasPaymentPin;
    final token = hasPin && request.methods.contains('pin')
        ? await _pinSheet(ctx, request, allowPassword: !request.isPayment)
        : await _passwordDialog(ctx, request);
    return token == null ? null : _remember(request, token);
  }

  static String _remember(VerificationRequest request, String token) {
    if (!request.isPayment) {
      _sensitiveToken = token;
      _sensitiveOwner = ApiService.authToken;
      _sensitiveExpiresAt = DateTime.now().add(const Duration(minutes: 4));
    }
    return token;
  }

  static Future<String?> _passwordDialog(BuildContext context, VerificationRequest request) async {
    final api = ApiService();
    String? message = request.message.isEmpty ? S.enterPasswordContinue : request.message;
    while (context.mounted) {
      final password = await showTextInputDialog(
        context,
        title: S.verifyS,
        message: message,
        hint: S.password,
        obscure: true,
        maxLength: 72,
        confirmLabel: S.confirm,
      );
      if (password == null || password.isEmpty || !context.mounted) return null;
      final outcome = await runBusy(context, () => api.verifyIdentity(scope: request.scope, method: 'password', password: password));
      if (outcome == null) return null;
      if (outcome.isSuccess) return outcome.token;
      message = outcome.message;
    }
    return null;
  }

  static Future<String?> _pinSheet(BuildContext context, VerificationRequest request, {required bool allowPassword}) {
    final c = AppColors.of(context);
    final summary = paymentSummary;
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.sheetBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => _PinSheet(request: request, summary: summary, allowPassword: allowPassword),
    );
  }
}

class _PinSheet extends StatelessWidget {
  final VerificationRequest request;
  final PaymentSummary? summary;
  final bool allowPassword;

  const _PinSheet({required this.request, required this.summary, required this.allowPassword});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final api = ApiService();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: PinEntryPanel(
          header: Column(
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: c.divider, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              if (request.isPayment && summary != null) ...[
                Text(S.amount, style: TextStyle(fontSize: 13, color: c.textSecondary)),
                const SizedBox(height: 4),
                FittedBox(
                  child: Text(
                    S.p0Coins(summary!.amount.toStringAsFixed(0)),
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: c.textPrimary),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ],
          ),
          title: request.isPayment ? S.enterPaymentPin : S.verifyS,
          subtitle: request.isPayment ? summary?.detail : S.enterPaymentPinContinue,
          onCompleted: (pin) async {
            final outcome = await api.verifyIdentity(scope: request.scope, method: 'pin', pin: pin);
            if (!context.mounted) return null;
            if (outcome.isSuccess) {
              Navigator.pop(context, outcome.token);
              return null;
            }
            if (outcome.code == 'PIN_LOCKED') {
              Navigator.pop(context);
              showAppSnackBar(context, outcome.message, isError: true);
              return null;
            }
            return outcome.message;
          },
          padLeading: const SizedBox.shrink(),
          footer: [
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () async {
                    final changed = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(builder: (_) => const PaymentPinScreen(forgot: true)),
                    );
                    if (changed == true && context.mounted) showAppSnackBar(context, S.paymentPinResetEnterAgain);
                  },
                  child: Text(S.forgotPaymentPin, style: TextStyle(color: c.accent)),
                ),
                if (allowPassword)
                  TextButton(
                    onPressed: () async {
                      final token = await VerificationService._passwordDialog(context, request);
                      if (token != null && context.mounted) Navigator.pop(context, token);
                    },
                    child: Text(S.usePasswordInstead, style: TextStyle(color: c.accent)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class BiometricGlyph extends StatelessWidget {
  final String label;
  final Color color;
  final double size;

  const BiometricGlyph({super.key, required this.label, required this.color, this.size = 22});

  @override
  Widget build(BuildContext context) {
    return label == 'Face ID'
        ? FaceIdIcon(size: size, color: color)
        : Icon(Icons.fingerprint_rounded, size: size + 2, color: color);
  }
}
