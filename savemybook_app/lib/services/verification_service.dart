import 'package:flutter/material.dart';

import '../i18n/strings.dart';
import '../models/security.dart';
import '../features/security/identity_verification_sheet.dart';
import '../features/security/payment_pin_screen.dart';
import '../utils/app_colors.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/pin_pad.dart';
import '../widgets/state_views.dart';
import 'api_service.dart';
import 'biometric_service.dart';
import 'passkey_service.dart';
import 'payment_key_store.dart';

class PaymentSummary {
  final double amount;
  final String detail;

  const PaymentSummary({required this.amount, required this.detail});
}

typedef _CachedToken = ({String token, DateTime expiresAt, String? owner});

class VerificationService {
  static GlobalKey<NavigatorState>? navigatorKey;
  static PaymentSummary? paymentSummary;

  // 依範圍分開存放：後台範圍只認登入密碼簽發的權杖，不能拿一般敏感操作的權杖頂替。
  static final Map<String, _CachedToken> _tokens = {};
  static Future<String?>? _inFlight;

  static void clearCache() => _tokens.clear();

  static Future<String?> handle(VerificationRequest request) {
    return _inFlight ??= _handle(request).whenComplete(() => _inFlight = null);
  }

  // 不可共用 _inFlight：付款驗證流程會開啟設定交易密碼頁，該頁再次要求驗證時若等待同一個 Future 會互相卡死。
  static Future<String?> requireSensitive(BuildContext context, {String? reason}) {
    return _handle(
      VerificationRequest(scope: 'sensitive', methods: const ['password', 'passkey', 'pin', 'biometric'], message: reason ?? ''),
      context: context,
    );
  }

  /// 後台高風險操作：只接受登入密碼或通行密鑰，不提供交易密碼與生物辨識。
  static Future<String?> requireAdminPassword(BuildContext context, {String? reason}) {
    return _handle(
      VerificationRequest(
        scope: 'admin',
        methods: const ['password', 'passkey'],
        message: reason ?? S.enterSignPasswordRunAdminAction,
      ),
      context: context,
    );
  }

  static String? _cached(String scope) {
    final entry = _tokens[scope];
    if (entry == null || entry.owner != ApiService.authToken) return null;
    return DateTime.now().isBefore(entry.expiresAt) ? entry.token : null;
  }

  static String? get cachedSensitiveToken => _cached('sensitive');

  static void rememberSensitive(String token) => _store('sensitive', token);

  static Future<String?> _handle(VerificationRequest request, {BuildContext? context}) async {
    final ctx = context ?? navigatorKey?.currentContext;
    if (ctx == null) return null;

    if (!request.isPayment) {
      final cached = _cached(request.scope);
      if (cached != null) return cached;
    }

    final api = ApiService();
    final status = await api.fetchSecurityStatus().timeout(const Duration(seconds: 15), onTimeout: () => SecurityStatus.unknown);
    if (!ctx.mounted) return null;

    if (request.isPayment && !status.available) {
      showAppSnackBar(ctx, S.networkError, isError: true);
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
    String? payKey;
    if (canUseBiometric) {
      final key = await PaymentKeyStore.read(userId);
      if (key != null && await BiometricService.isAvailable()) {
        payKey = key;
        final reason = request.isPayment
            ? S.confirmPaymentP0Coins((paymentSummary?.amount ?? 0).toStringAsFixed(0))
            : S.verifyIdentityContinue;
        if (await BiometricService.authenticate(reason: reason, biometricOnly: true)) {
          final outcome = await api.verifyIdentity(scope: request.scope, method: 'biometric', key: key);
          if (outcome.isSuccess) return _remember(request, outcome.token!);
          if (outcome.code == 'BIOMETRIC_KEY_INVALID') {
            await PaymentKeyStore.clear();
            payKey = null;
          }
        }
      }
    }
    // 已註冊通行密鑰時預設使用通行密鑰，交易密碼面板只留給付款。
    final usePasskey = await _canUsePasskey(request, status);
    if (!ctx.mounted) return null;

    final hasPin = request.isPayment || status.hasPaymentPin;
    final usePin = hasPin && request.methods.contains('pin') && !usePasskey;
    final pending = usePin
        ? _pinSheet(ctx, request, status: status, payKey: payKey)
        : _passwordSheet(ctx, request, status: status, payKey: payKey);
    final token = await pending;
    return token == null ? null : _remember(request, token);
  }

  static Future<bool> _canUsePasskey(VerificationRequest request, SecurityStatus status) async =>
      !request.isPayment && request.methods.contains('passkey') && status.hasPasskey && await PasskeyService.isSupported();

  static void _store(String scope, String token) {
    _tokens[scope] = (token: token, expiresAt: DateTime.now().add(const Duration(minutes: 4)), owner: ApiService.authToken);
  }

  static String _remember(VerificationRequest request, String token) {
    if (!request.isPayment) _store(request.scope, token);
    return token;
  }

  static Future<({String? token, String? message})> _biometricVerify(VerificationRequest request, String key) async {
    if (!await BiometricService.authenticate(reason: S.verifyIdentityContinue, biometricOnly: true)) {
      return (token: null, message: null);
    }
    final outcome = await ApiService().verifyIdentity(scope: request.scope, method: 'biometric', key: key);
    if (outcome.isSuccess) return (token: outcome.token, message: null);
    if (outcome.code == 'BIOMETRIC_KEY_INVALID') await PaymentKeyStore.clear();
    return (token: null, message: outcome.message);
  }

  static Future<String?> _passwordSheet(
    BuildContext context,
    VerificationRequest request, {
    required SecurityStatus status,
    String? payKey,
  }) async {
    final key = request.methods.contains('biometric') && status.biometricPayEnabled ? payKey : null;
    final label = key == null ? null : await BiometricService.label();
    final passkey = await _canUsePasskey(request, status);
    if (!context.mounted) return null;

    return showIdentityVerificationSheet(
      context,
      scope: request.scope,
      reason: request.message,
      hasPassword: status.hasPassword,
      biometricLabel: label,
      onBiometric: key == null ? null : () => _biometricVerify(request, key),
      onPasskey: passkey ? () => PasskeyService.verify(request.scope) : null,
    );
  }

  static Future<String?> _pinSheet(
    BuildContext context,
    VerificationRequest request, {
    required SecurityStatus status,
    String? payKey,
  }) {
    final c = AppColors.of(context);
    final summary = paymentSummary;
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.sheetBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => _PinSheet(
        request: request,
        summary: summary,
        status: status,
        payKey: payKey,
        allowPassword: !request.isPayment && request.methods.contains('password'),
      ),
    );
  }
}

class _PinSheet extends StatelessWidget {
  final VerificationRequest request;
  final PaymentSummary? summary;
  final SecurityStatus status;
  final String? payKey;
  final bool allowPassword;

  const _PinSheet({
    required this.request,
    required this.summary,
    required this.status,
    required this.payKey,
    required this.allowPassword,
  });

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
                      final token = await VerificationService._passwordSheet(context, request, status: status, payKey: payKey);
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
