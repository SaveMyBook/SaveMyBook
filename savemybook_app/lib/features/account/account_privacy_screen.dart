import 'dart:io';

import 'package:flutter/material.dart';
import '../../models/ai.dart';
import '../../models/auth_social.dart';
import '../../services/ai_status.dart';
import '../../services/api_service.dart';
import '../../services/share_service.dart';
import '../../services/verification_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_labels.dart';
import '../../utils/app_radius.dart';
import '../../utils/motion.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_tiles.dart';
import '../../widgets/responsive.dart';
import '../../widgets/state_views.dart';
import '../auth/login_screen.dart';
import '../security/set_password_screen.dart';
import 'ai_consent_sheet.dart';
import '../../i18n/strings.dart';

class AccountPrivacyScreen extends StatefulWidget {
  const AccountPrivacyScreen({super.key});

  @override
  State<AccountPrivacyScreen> createState() => _AccountPrivacyScreenState();
}

class _AccountPrivacyScreenState extends State<AccountPrivacyScreen> {
  final ApiService _api = ApiService();

  bool _isLoading = true;
  bool _exporting = false;
  bool _busy = false;
  bool _pendingDeletion = false;
  bool _consentBusy = false;
  DateTime? _purgeAt;

  @override
  void initState() {
    super.initState();
    _load();
    AiStatus.refresh(force: true);
  }

  Future<void> _load() async {
    final (pending, purgeAt) = await _api.fetchDeletionStatus();
    if (!mounted) return;
    setState(() {
      _pendingDeletion = pending;
      _purgeAt = purgeAt;
      _isLoading = false;
    });
  }

  Future<void> _export() async {
    if (_exporting) return;
    _exporting = true;
    try {
      final token = await VerificationService.requireSensitive(context, reason: S.confirmBeforeExportingData);
      if (token == null || !mounted) return;

      final json = await runBusy(
        context,
        () => _api.exportMyData(extraHeaders: {'X-Verify-Token': token}),
        message: S.preparingData,
      );
      if (!mounted) return;
      if (json == null) {
        showAppSnackBar(context, S.exportFailedPleaseTryAgainLater, isError: true);
        return;
      }

      final stamp = DateTime.now().toIso8601String().substring(0, 10);
      final path = '${Directory.systemTemp.path}/savemybook-$stamp.json';
      try {
        await File(path).writeAsString(json);
      } catch (_) {
        if (mounted) showAppSnackBar(context, S.exportFailedPleaseTryAgainLater, isError: true);
        return;
      }
      if (!mounted) return;

      final ok = await ShareService.shareFile(path, subject: S.mySavemybookData);
      if (!mounted) return;
      showAppSnackBar(context, ok ? S.exportedChooseWhereSave : S.exportedButSharingCouldNotOpen, isError: !ok);
    } finally {
      _exporting = false;
    }
  }

  Future<void> _toggleAiConsent(bool enable) async {
    if (_consentBusy) return;
    _consentBusy = true;
    try {
      if (enable) {
        final agreed = await showAiConsentSheet(context);
        if (!agreed || !mounted) return;
      }
      final result = await runBusy(context, () => AiStatus.setConsent(enable));
      if (!mounted) return;
      if (result == null || !result.isOk) {
        showAppSnackBar(context, result?.error ?? AppLabels.updateFailed, isError: true);
        return;
      }
      showAppSnackBar(context, enable ? S.aiDataProcessingEnabled : S.aiDataProcessingTurnedOff);
    } finally {
      _consentBusy = false;
    }
  }

  Future<void> _rotateShareLink() async {
    if (_busy) return;
    final confirmed = await showConfirmDialog(
      context,
      title: S.regenerateShareLink,
      message: S.oldLinkQrCodeStopWorking,
      confirmLabel: S.regenerate,
      icon: Icons.link_off_rounded,
    );
    if (!confirmed || !mounted) return;

    _busy = true;
    final url = await runBusy(context, () => _api.rotateShareToken());
    _busy = false;
    if (!mounted) return;
    showAppSnackBar(
      context,
      url == null ? AppLabels.updateFailed : S.newLinkCreatedOldOneNo,
      isError: url == null,
    );
  }

  Future<void> _requestDeletion() async {
    if (_busy) return;
    final confirmed = await showConfirmDialog(
      context,
      title: S.deleteAccount,
      message: S.accountPermanentlyDisabled30DaysSign,
      confirmLabel: S.actionContinue,
      isDestructive: true,
      icon: Icons.person_remove_rounded,
    );
    if (!confirmed || !mounted) return;

    final password = await showTextInputDialog(
      context,
      title: S.verify,
      message: S.enterPasswordConfirm,
      hint: S.password,
      obscure: true,
      confirmLabel: S.requestDeletion,
      isDestructive: true,
    );
    if (password == null || password.isEmpty || !mounted) return;

    _busy = true;
    final result = await runBusy(context, () => _api.requestAccountDeletion(password));
    _busy = false;
    if (result == null || !mounted) return;

    if (!result.isOk) {
      if (result.code == AuthCodes.passwordNotSet) {
        await _offerSetPassword(result.message);
        return;
      }
      showAppSnackBar(context, result.message, isError: true);
      return;
    }

    await _load();
    if (!mounted) return;
    showAppSnackBar(context, S.receivedSignAgainWithin30Days);
  }

  Future<void> _offerSetPassword(String message) async {
    final go = await showConfirmDialog(
      context,
      title: S.setPasswordFirst,
      message: message,
      confirmLabel: S.setPassword,
      cancelLabel: S.actionClose,
      icon: Icons.password_rounded,
    );
    if (!go || !mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const SetPasswordScreen()));
  }

  Future<void> _cancelDeletion() async {
    if (_busy) return;
    _busy = true;
    final error = await runBusy(context, () => _api.cancelAccountDeletion());
    _busy = false;
    if (!mounted) return;
    if (error != null) {
      showAppSnackBar(context, error, isError: true);
      return;
    }
    await _load();
    if (!mounted) return;
    showAppSnackBar(context, S.deletionCancelledAccountActiveAgain);
  }

  Future<void> _logout() async {
    await _api.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          AppHeader(title: S.account, icon: Icons.manage_accounts_outlined),
          Expanded(
            child: SwitchIn(
              child: _isLoading
                  ? context.isWide
                      ? const ResponsiveCenter(maxWidth: Breakpoints.formMaxWidth, child: LoadingView.menu())
                      : const LoadingView.menu()
                  : RefreshIndicator(
                      color: c.accent,
                      onRefresh: _load,
                      child: LayoutBuilder(
                      builder: (context, constraints) => ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: responsiveListPadding(constraints, maxWidth: Breakpoints.formMaxWidth, horizontal: 20, top: 20, bottom: 40),
                      children: [
                        Reveal(visible: _pendingDeletion, child: _buildPendingCard(c)),
                        FadeSlideIn(
                          child: ValueListenableBuilder<AiStatusInfo>(
                            valueListenable: AiStatus.listenable,
                            builder: (context, status, _) => _buildSection(c, S.data, [
                              AppMenuItem(
                                icon: Icons.download_rounded,
                                title: S.exportMyData,
                                onTap: _export,
                              ),
                              AppMenuItem(
                                icon: Icons.link_off_rounded,
                                title: S.regenerateShareLink,
                                isLast: !status.any,
                                onTap: _rotateShareLink,
                              ),
                              if (status.any) _buildAiConsentItem(c, status),
                            ]),
                          ),
                        ),
                        const SizedBox(height: 24),
                        FadeSlideIn(index: 1, child: _buildSection(c, S.faqCatAccount, [
                          AppMenuItem(
                            icon: Icons.person_remove_rounded,
                            title: _pendingDeletion ? S.cancelAccountDeletion : S.deleteAccount,
                            iconColor: _pendingDeletion ? null : c.danger,
                            isLast: true,
                            onTap: _pendingDeletion ? _cancelDeletion : _requestDeletion,
                          ),
                        ])),
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

  Widget _buildAiConsentItem(AppColors c, AiStatusInfo status) {
    return AppMenuItem(
      icon: Icons.auto_awesome_outlined,
      title: S.aiDataProcessing,
      isLast: true,
      showChevron: false,
      onTap: () => _toggleAiConsent(!status.consented),
      trailing: Switch.adaptive(
        value: status.consented,
        activeThumbColor: c.accent,
        onChanged: _toggleAiConsent,
      ),
    );
  }

  Widget _buildPendingCard(AppColors c) {
    final days = _purgeAt == null
        ? 30
        : _purgeAt!.difference(DateTime.now()).inDays.clamp(0, 30);

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: c.danger.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: c.danger.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.schedule_rounded, color: c.danger, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    S.deletionPending,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: c.danger,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    S.daysLeftCanCancelAnyTime(days),
                    style: TextStyle(fontSize: 13, height: 1.5, color: c.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _logout,
                    child: Text(
                      S.signOut,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: c.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(AppColors c, String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            title,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: c.textSecondary),
          ),
        ),
        AnimatedContainer(
          duration: Motion.base,
          curve: Motion.standard,
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(AppRadius.card),
            boxShadow: [BoxShadow(color: c.shadow.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: Column(children: items),
          ),
        ),
      ],
    );
  }
}
