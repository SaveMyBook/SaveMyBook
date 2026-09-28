import 'package:flutter/material.dart';

import '../../models/passkey.dart';
import '../../services/passkey_service.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/state_views.dart';
import '../../i18n/strings.dart';

class PasskeySignInButton extends StatefulWidget {
  final bool disabled;

  final Future<void> Function() onSignedIn;

  final VoidCallback? onUsePassword;

  final double topSpacing;

  final bool? initialVisible;

  final ValueChanged<bool>? onBusyChanged;

  const PasskeySignInButton({
    super.key,
    required this.onSignedIn,
    this.onUsePassword,
    this.disabled = false,
    this.topSpacing = 12,
    this.initialVisible,
    this.onBusyChanged,
  });

  @override
  State<PasskeySignInButton> createState() => _PasskeySignInButtonState();
}

class _PasskeySignInButtonState extends State<PasskeySignInButton> {
  late bool _visible = widget.initialVisible ?? false;
  bool _busy = false;
  AppLifecycleListener? _lifecycle;

  @override
  void initState() {
    super.initState();
    if (widget.initialVisible == null) {
      _detect();
      _lifecycle = AppLifecycleListener(onResume: () {
        if (!_visible) _detect();
      });
    }
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    super.dispose();
  }

  Future<void> _detect() async {
    final usable = await PasskeyService.isUsable();
    if (mounted && usable && !_visible) setState(() => _visible = true);
  }

  // 登入頁切換寬窄版面時會重建此按鈕：原 State 卸載後流程仍須走完，登入成功與忙碌狀態才會回報給登入頁。
  Future<void> _signIn() async {
    final host = widget;
    if (_busy || host.disabled) return;
    FocusScope.of(context).unfocus();

    void setBusy(bool value) {
      if (_busy == value) return;
      _busy = value;
      if (mounted) setState(() {});
      host.onBusyChanged?.call(value);
    }

    setBusy(true);
    var outcome = await _attempt(immediate: true);
    if (outcome.code == PasskeyOutcome.noCredentialsCode) {
      setBusy(false);
      if (!mounted) return;
      final other = await showConfirmDialog(
        context,
        title: S.noPasskeyDevice,
        message: S.signWithPasskeyAnotherDeviceSecurity,
        confirmLabel: S.useAnotherDevice,
        cancelLabel: S.usePassword,
        icon: Icons.key_rounded,
      );
      if (!mounted) return;
      if (!other) {
        host.onUsePassword?.call();
        return;
      }
      setBusy(true);
      outcome = await _attempt(immediate: false);
    }

    if (outcome.isOk) {
      await host.onSignedIn();
      setBusy(false);
      return;
    }
    setBusy(false);
    if (mounted && !outcome.isCancelled) showAppSnackBar(context, outcome.message, isError: true);
  }

  Future<PasskeyOutcome<void>> _attempt({required bool immediate}) async {
    try {
      return await PasskeyService.signIn(immediate: immediate);
    } catch (_) {
      return PasskeyOutcome.fail('UNKNOWN', S.signFailedPleaseTryAgain);
    }
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
