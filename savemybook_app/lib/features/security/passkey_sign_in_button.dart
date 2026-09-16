import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/passkey_service.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/state_views.dart';
import '../../i18n/strings.dart';

/// 登入頁的「使用通行密鑰登入」。裝置不支援或伺服器未啟用時不佔任何空間。
class PasskeySignInButton extends StatefulWidget {
  final bool disabled;

  /// 登入成功（Token 與使用者資料已存好）後呼叫，由登入頁決定後續導向。
  final Future<void> Function() onSignedIn;

  final double topSpacing;

  /// 測試用：直接指定是否顯示，不再偵測裝置與伺服器。
  final bool? initialVisible;

  const PasskeySignInButton({
    super.key,
    required this.onSignedIn,
    this.disabled = false,
    this.topSpacing = 12,
    this.initialVisible,
  });

  @override
  State<PasskeySignInButton> createState() => _PasskeySignInButtonState();
}

class _PasskeySignInButtonState extends State<PasskeySignInButton> {
  late bool _visible = widget.initialVisible ?? false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialVisible == null) _detect();
  }

  Future<void> _detect() async {
    if (!await PasskeyService.isSupported()) return;
    final enabled = await ApiService().fetchPasskeyServerEnabled();
    if (mounted && enabled) setState(() => _visible = true);
  }

  Future<void> _signIn() async {
    if (_busy || widget.disabled) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    final outcome = await PasskeyService.signIn();
    if (!mounted) return;
    if (outcome.isOk) {
      await widget.onSignedIn();
      if (mounted) setState(() => _busy = false);
      return;
    }
    setState(() => _busy = false);
    if (!outcome.isCancelled) showAppSnackBar(context, outcome.message, isError: true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: widget.topSpacing),
      child: SecondaryButton(
        label: S.signWithPasskey,
        icon: Icons.key_rounded,
        height: 50,
        isLoading: _busy,
        onPressed: widget.disabled ? null : _signIn,
      ),
    );
  }
}
