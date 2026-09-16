import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/social_auth_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/app_forms.dart';
import '../../widgets/app_header.dart';
import '../../widgets/pin_pad.dart';
import '../../widgets/responsive.dart';
import '../../widgets/state_views.dart';
import '../../i18n/strings.dart';

class DialCode {
  final String code;
  final String name;

  const DialCode(this.code, this.name);
}

List<DialCode> dialCodes() => [
      DialCode('+886', S.taiwan),
      DialCode('+852', S.hongKong),
      DialCode('+853', S.macau),
      DialCode('+86', S.china),
      DialCode('+81', S.japan),
      DialCode('+82', S.southKorea),
      DialCode('+65', S.singapore),
      DialCode('+60', S.malaysia),
      DialCode('+1', S.unitedStatesCanada),
      DialCode('+44', S.unitedKingdom),
      DialCode('+61', S.australia),
    ];

/// 撥號碼 + 使用者輸入組成 E.164；多數地區的市內表示法會多一個前導 0。
String toE164(String dialCode, String local) {
  var digits = local.replaceAll(RegExp(r'\D'), '');
  while (digits.startsWith('0')) {
    digits = digits.substring(1);
  }
  return '$dialCode$digits';
}

class PhoneSignInScreen extends StatefulWidget {
  /// 綁定流程用的標題與說明。
  final bool linking;
  final PhoneSignInController? controller;

  const PhoneSignInScreen({super.key, this.linking = false, this.controller});

  @override
  State<PhoneSignInScreen> createState() => _PhoneSignInScreenState();
}

class _PhoneSignInScreenState extends State<PhoneSignInScreen> {
  late final PhoneSignInController _controller = widget.controller ?? PhoneSignInController();
  final _numberController = TextEditingController();

  late DialCode _dialCode = dialCodes().first;
  String? _error;
  bool _sending = false;

  @override
  void dispose() {
    _numberController.dispose();
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  Future<void> _pickDialCode() async {
    final picked = await showOptionSheet<String>(
      context,
      title: S.countryCode,
      options: [
        for (final item in dialCodes())
          SheetOption(value: item.code, label: '${item.name}　${item.code}', selected: item.code == _dialCode.code),
      ],
    );
    if (picked == null) return;
    setState(() => _dialCode = dialCodes().firstWhere((item) => item.code == picked));
  }

  Future<void> _submit() async {
    if (_sending) return;
    final digits = _numberController.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 8) {
      setState(() => _error = S.enterValidMobileNumber);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _sending = true;
      _error = null;
    });

    await _controller.send(toE164(_dialCode.code, digits));
    if (!mounted) return;
    setState(() => _sending = false);

    if (_controller.stage == PhoneSignInStage.verified) {
      Navigator.pop(context, _controller.idToken);
      return;
    }
    if (_controller.stage != PhoneSignInStage.codeSent) {
      setState(() => _error = _controller.error ?? S.couldNotSendCodePleaseTry);
      return;
    }

    final token = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => SmsCodeScreen(controller: _controller)),
    );
    if (token == null || !mounted) return;
    Navigator.pop(context, token);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          AppHeader(
            title: widget.linking ? S.linkMobileNumber : S.signWithMobileNumber,
            icon: Icons.sms_outlined,
          ),
          Expanded(
            child: GestureDetector(
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
                              child: Icon(Icons.sms_outlined, color: c.accent),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                S.k6DigitCodeSentNumberMessage,
                                style: TextStyle(fontSize: 12, height: 1.5, color: c.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    FadeSlideIn(
                      index: 1,
                      child: AppCard(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.phone_iphone_rounded, size: 16, color: c.accent),
                                const SizedBox(width: 6),
                                Text(
                                  S.mobileNumber,
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  height: AppTextField.singleLineHeight,
                                  child: OutlinedButton(
                                    onPressed: _sending ? null : _pickDialCode,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: c.textPrimary,
                                      side: BorderSide(color: c.border),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(_dialCode.code,
                                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                        Icon(Icons.expand_more_rounded, size: 18, color: c.iconInactive),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: AppTextField(
                                    controller: _numberController,
                                    hint: '0912345678',
                                    errorText: _error,
                                    keyboardType: TextInputType.phone,
                                    maxLength: 15,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    textInputAction: TextInputAction.done,
                                    onSubmitted: (_) => _submit(),
                                    onChanged: (_) {
                                      if (_error != null) setState(() => _error = null);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FadeSlideIn(
                      index: 2,
                      child: PrimaryButton(
                        label: S.sendCode,
                        height: 50,
                        isLoading: _sending,
                        onPressed: _submit,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SmsCodeScreen extends StatefulWidget {
  final PhoneSignInController controller;

  const SmsCodeScreen({super.key, required this.controller});

  @override
  State<SmsCodeScreen> createState() => _SmsCodeScreenState();
}

class _SmsCodeScreenState extends State<SmsCodeScreen> {
  final _panelKey = GlobalKey<PinEntryPanelState>();
  bool _resending = false;
  bool _popped = false;

  PhoneSignInController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {});
    if (_controller.stage == PhoneSignInStage.verified) _finish();
  }

  // Android 可能自動完成驗證，讓監聽與手動送出都經過同一個出口，避免重複 pop。
  void _finish() {
    if (_popped || !mounted) return;
    _popped = true;
    Navigator.of(context).pop(_controller.idToken);
  }

  Future<String?> _verify(String code) async {
    final ok = await _controller.submitCode(code);
    if (!mounted) return null;
    if (ok) {
      _finish();
      return null;
    }
    return _controller.error ?? S.codeIncorrectPleaseEnterAgain;
  }

  Future<void> _resend() async {
    if (_resending || !_controller.canResend) return;
    setState(() => _resending = true);
    await _controller.resend();
    if (!mounted) return;
    setState(() => _resending = false);
    _panelKey.currentState?.reset();
    if (_controller.error != null) {
      showAppSnackBar(context, _controller.error!, isError: true);
      return;
    }
    showAppSnackBar(context, S.codeBeenSentAgain);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final seconds = _controller.resendSeconds;
    final phone = _controller.phoneNumber;

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          AppHeader(title: S.enterCode, icon: Icons.password_rounded),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: responsiveListPadding(constraints,
                    maxWidth: Breakpoints.formMaxWidth, horizontal: 20, top: 24, bottom: 32),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - 56),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      PinEntryPanel(
                        key: _panelKey,
                        title: S.enterSmsCode,
                        subtitle: S.codeWasSentP0(phone),
                        onCompleted: _verify,
                        footer: [
                          const SizedBox(height: 4),
                          _resending
                              ? SizedBox(
                                  height: 44,
                                  child: Center(
                                    child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: c.accent),
                                    ),
                                  ),
                                )
                              : TextButton(
                                  onPressed: _controller.canResend ? _resend : null,
                                  child: Text(
                                    seconds > 0 ? S.canResendP0S(seconds) : S.resendCode,
                                    style: TextStyle(
                                      color: _controller.canResend ? c.accent : c.textHint,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                        ],
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
}
