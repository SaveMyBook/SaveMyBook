import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/admin_models.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_radius.dart';
import '../../utils/api_helpers.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/app_header.dart';
import '../../widgets/state_views.dart';
import '../../widgets/swipe_action.dart';

class AdminBackupScreen extends StatefulWidget {
  const AdminBackupScreen({super.key});

  @override
  State<AdminBackupScreen> createState() => _AdminBackupScreenState();
}

class _AdminBackupScreenState extends State<AdminBackupScreen> {
  final ApiService _api = ApiService();

  List<BackupRecord> _backups = [];
  int _keep = 14;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final (backups, keep) = await _api.fetchBackups();
    if (!mounted) return;
    setState(() {
      _backups = backups;
      _keep = keep;
      _isLoading = false;
    });
  }

  Future<void> _createBackup() async {
    final confirmed = await showConfirmDialog(
      context,
      title: '立即備份',
      message: '將匯出整個資料庫並壓縮保存。資料量大時可能需要數十秒，期間請不要離開這個畫面。',
      confirmLabel: '開始備份',
      icon: Icons.backup_rounded,
    );
    if (!confirmed || !mounted) return;

    final error = await runBusy(context, () => _api.createBackup(), message: '正在備份資料庫');
    if (!mounted) return;

    showAppSnackBar(context, error ?? '備份完成', isError: error != null);
    await _load();
  }

  Future<void> _delete(BackupRecord record) async {
    // Dismissible 已經把項目移出畫面，清單資料必須同步，
    // 否則 ListView 還握著一個已 dismiss 的項目會丟例外。
    setState(() => _backups.remove(record));

    final error = await _api.deleteBackup(record.backupId);
    if (!mounted) return;
    if (error != null) {
      showAppSnackBar(context, error, isError: true);
      await _load();
      return;
    }
    showAppSnackBar(context, '已刪除備份');
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          const AppHeader(title: '資料庫備份', icon: Icons.backup_outlined),
          Expanded(
            child: SwitchIn(
              child: _isLoading
                  ? const LoadingView.list()
                  : RefreshIndicator(
                      color: c.accent,
                      onRefresh: _load,
                      child: SwitchIn(
                        child: _backups.isEmpty
                            ? ListView(
                                key: const ValueKey('empty'),
                                children: [
                                  const SizedBox(height: 20),
                                  _buildHeaderCard(c),
                                  const SizedBox(height: 40),
                                  const EmptyView(
                                    icon: Icons.backup_outlined,
                                    message: '尚無備份紀錄',
                                  ),
                                ],
                              )
                            : ListView.builder(
                                key: const ValueKey('items'),
                                padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                                itemCount: _backups.length + 1,
                                itemBuilder: (_, i) {
                                  if (i == 0) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 20),
                                      child: _buildHeaderCard(c),
                                    );
                                  }
                                  final record = _backups[i - 1];
                                  return RevealOnScroll(
                                    index: i,
                                    child: Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: _buildRow(record, c),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(AppColors c) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: [
          BoxShadow(color: c.shadow.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '每日自動備份，保留最新 $_keep 份',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            '超出份數的舊備份會自動清除。備份檔含全站個人資料，下載後請妥善保管，'
            '每次下載都會記入操作紀錄。',
            style: TextStyle(fontSize: 12, height: 1.6, color: c.textSecondary),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _createBackup,
              icon: const Icon(Icons.backup_rounded, size: 18),
              label: const Text('立即備份'),
              style: ElevatedButton.styleFrom(
                backgroundColor: c.accent,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.field),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(BackupRecord record, AppColors c) {
    final tint = record.isSuccess ? c.success : c.danger;

    return SwipeActionTile(
      itemKey: ValueKey(record.backupId),
      backgroundMargin: EdgeInsets.zero,
      endToStart: SwipeAction(
        icon: Icons.delete_outline_rounded,
        label: '刪除',
        color: c.danger,
        dismisses: true,
        onTrigger: () => showConfirmDialog(
          context,
          title: '刪除備份',
          message: '${record.fileName}\n\n檔案與紀錄會一併移除，無法復原。',
          confirmLabel: '刪除',
          isDestructive: true,
        ),
        onDismissed: () => _delete(record),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: [
            BoxShadow(color: c.shadow.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              child: Icon(
                record.isSuccess ? Icons.inventory_2_outlined : Icons.error_outline_rounded,
                size: 20,
                color: tint,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatDateTime(record.createdAt),
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    record.isSuccess
                        ? '${record.sizeText}・${record.isManual ? '手動' : '排程'}'
                            '${record.adminName.isEmpty ? '' : '・${record.adminName}'}'
                        : (record.detail ?? '備份失敗'),
                    style: TextStyle(fontSize: 12, color: c.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Reveal(
              visible: record.isSuccess && record.available,
              child: IconButton(
                icon: Icon(Icons.download_rounded, size: 20, color: c.accent),
                tooltip: '下載',
                onPressed: () => _showDownloadHint(record),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 備份檔可能有數百 MB，在 App 內下載沒有意義。
  /// 改成把附帶授權的網址交給使用者，在電腦上取回。
  void _showDownloadHint(BackupRecord record) {
    showConfirmDialog(
      context,
      title: '下載備份',
      message: '備份檔請在電腦上取回，並帶上你的授權標頭：\n\n'
          '${_api.backupDownloadUrl(record.backupId)}\n\n'
          '檔案大小 ${record.sizeText}。',
      confirmLabel: '複製網址',
      icon: Icons.download_rounded,
    ).then((confirmed) {
      if (!confirmed || !mounted) return;
      Clipboard.setData(ClipboardData(text: _api.backupDownloadUrl(record.backupId)));
      showAppSnackBar(context, '已複製下載網址');
    });
  }
}
