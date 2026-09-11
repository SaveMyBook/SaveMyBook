import 'dart:io';

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/share_service.dart';
import '../utils/app_colors.dart';
import '../utils/app_labels.dart';
import '../utils/app_radius.dart';
import '../utils/motion.dart';
import '../widgets/animations.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/app_header.dart';
import '../widgets/app_tiles.dart';
import '../widgets/state_views.dart';
import 'login_screen.dart';
import '../i18n/strings.dart';

class AccountPrivacyScreen extends StatefulWidget {
  const AccountPrivacyScreen({super.key});

  @override
  State<AccountPrivacyScreen> createState() => _AccountPrivacyScreenState();
}

class _AccountPrivacyScreenState extends State<AccountPrivacyScreen> {
  final ApiService _api = ApiService();

  bool _isLoading = true;
  bool _pendingDeletion = false;
  DateTime? _purgeAt;

  @override
  void initState() {
    super.initState();
    _load();
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
    final json = await runBusy(context, () => _api.exportMyData(), message: S.preparingData);
    if (!mounted) return;
    if (json == null) {
      showAppSnackBar(context, AppLabels.loadFailed, isError: true);
      return;
    }

    final stamp = DateTime.now().toIso8601String().substring(0, 10);
    final path = '${Directory.systemTemp.path}/savemybook-$stamp.json';
    await File(path).writeAsString(json);
    if (!mounted) return;

    final ok = await ShareService.shareFile(path, subject: S.mySavemybookData);
    if (!mounted) return;
    showAppSnackBar(context, ok ? S.exportedChooseWhereSave : S.exportedButSharingCouldNotOpen);
  }

  Future<void> _rotateShareLink() async {
    final confirmed = await showConfirmDialog(
      context,
      title: S.regenerateShareLink,
      message: S.oldLinkQrCodeStopWorking,
      confirmLabel: S.regenerate,
      icon: Icons.link_off_rounded,
    );
    if (!confirmed || !mounted) return;

    final url = await runBusy(context, () => _api.rotateShareToken());
    if (!mounted) return;
    showAppSnackBar(
      context,
      url == null ? AppLabels.updateFailed : S.newLinkCreatedOldOneNo,
      isError: url == null,
    );
  }

  Future<void> _requestDeletion() async {
    final confirmed = await showConfirmDialog(
      context,
      title: S.deleteAccount,
      message: S.accountPermanentlyDisabled30DaysSign +
          S.personalDataErasedButCompletedOrders +
          S.peopleTradedWithDoNotLose,
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

    final error = await runBusy(context, () => _api.requestAccountDeletion(password));
    if (!mounted) return;

    if (error != null) {
      showAppSnackBar(context, error, isError: true);
      return;
    }

    await _load();
    if (!mounted) return;
    showAppSnackBar(context, S.receivedSignAgainWithin30Days);
  }

  Future<void> _cancelDeletion() async {
    final error = await runBusy(context, () => _api.cancelAccountDeletion());
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
                  ? const LoadingView.menu()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                      children: [
                        Reveal(visible: _pendingDeletion, child: _buildPendingCard(c)),
                        _buildSection(c, S.data, [
                          AppMenuItem(
                            icon: Icons.download_rounded,
                            title: S.exportMyData,
                            subtitle: S.profileBooksOrdersTransactionsJson,
                            onTap: _export,
                          ),
                          AppMenuItem(
                            icon: Icons.link_off_rounded,
                            title: S.regenerateShareLink,
                            subtitle: S.oldLinkQrCodeStopWorking2,
                            isLast: true,
                            onTap: _rotateShareLink,
                          ),
                        ]),
                        const SizedBox(height: 24),
                        _buildSection(c, S.faqCatAccount, [
                          AppMenuItem(
                            icon: Icons.person_remove_rounded,
                            title: _pendingDeletion ? S.cancelAccountDeletion : S.deleteAccount,
                            subtitle: _pendingDeletion
                                ? S.restoreAccountStopCountdown
                                : S.canChangeMindWithin30Days,
                            iconColor: _pendingDeletion ? null : c.danger,
                            isLast: true,
                            onTap: _pendingDeletion ? _cancelDeletion : _requestDeletion,
                          ),
                        ]),
                      ],
                    ),
            ),
          ),
        ],
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
