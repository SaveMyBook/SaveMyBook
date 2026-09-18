import 'package:flutter/material.dart';

import '../../models/passkey.dart';
import '../../services/api_service.dart';
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

  const PasskeySignInButton({
    super.key,
    required this.onSignedIn,
    this.onUsePassword,
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

    var outcome = await _attempt(immediate: true);
    if (!mounted) return;
    if (outcome.code == PasskeyOutcome.noCredentialsCode) {
      setState(() => _busy = false);
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
        widget.onUsePassword?.call();
        return;
      }
      setState(() => _busy = true);
      outcome = await _attempt(immediate: false);
      if (!mounted) return;
    }

    if (outcome.isOk) {
      await widget.onSignedIn();
      if (mounted) setState(() => _busy = false);
      return;
    }
    setState(() => _busy = false);
    if (!outcome.isCancelled) showAppSnackBar(context, outcome.message, isError: true);
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
