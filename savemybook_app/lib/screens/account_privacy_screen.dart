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
    final json = await runBusy(context, () => _api.exportMyData(), message: '正在整理您的資料');
    if (!mounted) return;
    if (json == null) {
      showAppSnackBar(context, AppLabels.loadFailed, isError: true);
      return;
    }

    final stamp = DateTime.now().toIso8601String().substring(0, 10);
    final path = '${Directory.systemTemp.path}/savemybook-$stamp.json';
    await File(path).writeAsString(json);
    if (!mounted) return;

    final ok = await ShareService.shareFile(path, subject: '我的 SaveMyBook 資料');
    if (!mounted) return;
    showAppSnackBar(context, ok ? '已匯出，請選擇儲存位置' : '匯出完成，但無法開啟分享');
  }

  Future<void> _rotateShareLink() async {
    final confirmed = await showConfirmDialog(
      context,
      title: '重新產生分享連結',
      message: '舊的連結與 QR Code 會立即失效，已經分享出去的人將無法再開啟。確定要重新產生嗎？',
      confirmLabel: '重新產生',
      icon: Icons.link_off_rounded,
    );
    if (!confirmed || !mounted) return;

    final url = await runBusy(context, () => _api.rotateShareToken());
    if (!mounted) return;
    showAppSnackBar(
      context,
      url == null ? AppLabels.updateFailed : '已產生新連結，舊連結已失效',
      isError: url == null,
    );
  }

  Future<void> _requestDeletion() async {
    final confirmed = await showConfirmDialog(
      context,
      title: '刪除帳號',
      message: '帳號將在 30 天後永久停用，期間內重新登入即可取消。\n\n'
          '停用後個人資料會被清除，但已完成的訂單與交易紀錄會保留，'
          '交易對象的紀錄才不會出現缺漏。',
      confirmLabel: '繼續',
      isDestructive: true,
      icon: Icons.person_remove_rounded,
    );
    if (!confirmed || !mounted) return;

    final password = await showTextInputDialog(
      context,
      title: '確認身分',
      message: '請輸入密碼以確認這是本人的操作。',
      hint: '密碼',
      obscure: true,
      confirmLabel: '申請刪除',
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
    showAppSnackBar(context, '已受理，30 天內重新登入即可取消');
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
    showAppSnackBar(context, '已取消刪除，帳號恢復正常');
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
          const AppHeader(title: '帳號與隱私', icon: Icons.shield_outlined),
          Expanded(
            child: SwitchIn(
              child: _isLoading
                  ? const LoadingView.menu()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                      children: [
                        Reveal(visible: _pendingDeletion, child: _buildPendingCard(c)),
                        _buildSection(c, '你的資料', [
                          AppMenuItem(
                            icon: Icons.download_rounded,
                            title: '匯出我的資料',
                            subtitle: '個人檔案、書籍、訂單與交易紀錄，JSON 格式',
                            onTap: _export,
                          ),
                          AppMenuItem(
                            icon: Icons.link_off_rounded,
                            title: '重新產生分享連結',
                            subtitle: '舊的連結與 QR Code 會立即失效',
                            isLast: true,
                            onTap: _rotateShareLink,
                          ),
                        ]),
                        const SizedBox(height: 24),
                        _buildSection(c, '帳號', [
                          AppMenuItem(
                            icon: Icons.person_remove_rounded,
                            title: _pendingDeletion ? '取消刪除帳號' : '刪除帳號',
                            subtitle: _pendingDeletion
                                ? '恢復帳號，停止刪除倒數'
                                : '30 天緩衝期內可以反悔',
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
                    '刪除倒數中',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: c.danger,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '還有 $days 天。在這之前隨時可以取消，逾期後個人資料將被清除且無法復原。',
                    style: TextStyle(fontSize: 13, height: 1.5, color: c.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _logout,
                    child: Text(
                      '登出',
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
