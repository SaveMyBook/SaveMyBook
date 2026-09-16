import 'dart:async';
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
import '../../i18n/strings.dart';
import 'admin_layout.dart';

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
  bool _isBusy = false;

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

  static bool _isCancelled(String error) => error.isEmpty || error == S.verificationCancelled;

  Future<void> _createBackup() async {
    if (_isBusy) return;
    final confirmed = await showConfirmDialog(
      context,
      title: S.backUpNow,
      message: S.wholeDatabaseExportedCompressedWithLot,
      confirmLabel: S.startBackup,
      icon: Icons.backup_rounded,
    );
    if (!confirmed || !mounted) return;

    setState(() => _isBusy = true);
    String? error;
    try {
      error = await runBusy<String?>(context, () => _api.createBackup(), message: S.backingUpDatabase);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
    if (!mounted) return;

    if (error == null) {
      showAppSnackBar(context, S.backupComplete);
    } else if (!_isCancelled(error)) {
      showAppSnackBar(context, error, isError: true);
    }
    await _load();
  }

  Future<void> _restore(BackupRecord record) async {
    if (_isBusy) return;
    final password = await showTextInputDialog(
      context,
      title: S.restoreBackup,
      message: S.wholeDatabaseGoBackP0Orders(formatDateTime(record.createdAt)),
      hint: S.password2,
      obscure: true,
      maxLength: 72,
      confirmLabel: S.startRestore,
      isDestructive: true,
    );
    if (password == null || password.isEmpty || !mounted) return;

    setState(() => _isBusy = true);
    try {
      await _runRestore(record, password);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _runRestore(BackupRecord record, String password) async {
    final (safety, error) = await runBusy(
      context,
      () => _api.restoreBackup(record.backupId, password),
      message: S.backingUpCurrentState,
    ) ?? (null, S.somethingWentWrongPleaseTryAgain);
    if (!mounted) return;
    if (error != null) {
      if (!_isCancelled(error)) showAppSnackBar(context, error, isError: true);
      return;
    }

    final state = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RestoreProgressDialog(api: _api, safetyFileName: safety ?? ''),
    );
    if (!mounted) return;

    if (state == 'done') {
      showAppSnackBar(context, S.databaseRestoredPreviousStateWasBacked(safety ?? ''));
    } else {
      showAppSnackBar(context, S.restoreFailedDatabaseMayUnchangedPartly(safety ?? ''), isError: true);
    }
    await _load();
  }

  Future<void> _delete(BackupRecord record) async {
    // Dismissible 已移出畫面的項目必須同步從清單移除，否則 ListView 會丟例外。
    setState(() => _backups.remove(record));

    final error = await _api.deleteBackup(record.backupId);
    if (!mounted) return;
    if (error != null) {
      if (!_isCancelled(error)) showAppSnackBar(context, error, isError: true);
      await _load();
      return;
    }
    showAppSnackBar(context, S.backupDeleted);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.scaffold,
      body: AdminLayout(
        builder: (context, frame) => Column(
          children: [
            AppHeader(title: S.databaseBackups, icon: Icons.backup_outlined),
            Expanded(
              child: SwitchIn(
                child: _isLoading
                    ? const LoadingView.list()
                    : RefreshIndicator(
                        color: c.accent,
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: frame.inset(const EdgeInsets.fromLTRB(16, 20, 16, 32)),
                          itemCount: _backups.isEmpty ? 2 : _backups.length + 1,
                          itemBuilder: (_, i) {
                            if (i == 0) {
                              return FadeSlideIn(
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: _buildHeaderCard(c, wide: frame.isWide),
                                ),
                              );
                            }
                            if (_backups.isEmpty) return _buildEmptyRow(c);

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
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(AppColors c, {bool wide = false}) {
    final intro = [
      Text(
        S.backedUpDailyNewestP0Kept(_keep),
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c.textPrimary),
      ),
      const SizedBox(height: 6),
      Text(
        S.olderBackupsBeyondCountRemovedAutomatically,
        style: TextStyle(fontSize: 12, height: 1.6, color: c.textSecondary),
      ),
    ];
    final button = ElevatedButton.icon(
      onPressed: _isBusy ? null : _createBackup,
      icon: const Icon(Icons.backup_rounded, size: 18),
      label: Text(S.backUpNow, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: ElevatedButton.styleFrom(
        backgroundColor: c.accent,
        foregroundColor: Colors.white,
        disabledBackgroundColor: c.accent.withValues(alpha: 0.5),
        disabledForegroundColor: Colors.white70,
        elevation: 0,
        padding: wide ? const EdgeInsets.symmetric(horizontal: 24, vertical: 12) : const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: [
          BoxShadow(color: c.shadow.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: wide
          ? Row(
              children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: intro)),
                const SizedBox(width: 24),
                button,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...intro,
                const SizedBox(height: 14),
                SizedBox(width: double.infinity, child: button),
              ],
            ),
    );
  }

  Widget _buildEmptyRow(AppColors c) {
    return FadeSlideIn(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: c.inputFill,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Row(
          children: [
            Icon(Icons.schedule_rounded, size: 20, color: c.iconInactive),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                S.noBackupsYetSchedulerRunsOnce,
                style: TextStyle(fontSize: 13, height: 1.6, color: c.textSecondary),
              ),
            ),
          ],
        ),
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
        label: S.actionDelete,
        color: c.danger,
        dismisses: true,
        onTrigger: () => showConfirmDialog(
          context,
          title: S.deleteBackup,
          message: S.p0NNtheFileItsRecord(record.fileName),
          confirmLabel: S.actionDelete,
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary),
                  ),
                  if (formatRelative(record.createdAt) != formatDate(record.createdAt))
                    Text(
                      formatRelative(record.createdAt),
                      style: TextStyle(fontSize: 11, color: c.textHint),
                    ),
                  const SizedBox(height: 3),
                  Text(
                    record.isSuccess
                        ? '${record.sizeText}・${record.isPreRestore ? S.autoBackupBeforeRestore : record.isManual ? S.manual : S.scheduled}'
                            '${record.adminName.isEmpty ? '' : '・${record.adminName}'}'
                        : (record.detail ?? S.backupFailed),
                    style: TextStyle(fontSize: 12, color: c.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (record.isSuccess && record.available) ...[
              IconButton(
                icon: Icon(Icons.settings_backup_restore_rounded, size: 20, color: c.danger),
                tooltip: S.restoreBackup2,
                onPressed: _isBusy ? null : () => _restore(record),
              ),
              IconButton(
                icon: Icon(Icons.download_rounded, size: 20, color: c.accent),
                tooltip: S.download,
                onPressed: () => _download(record),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _download(BackupRecord record) async {
    final (url, error) = await _api.createBackupDownloadLink(record.backupId);
    if (!mounted) return;
    if (url == null) {
      if (error != null && !_isCancelled(error)) showAppSnackBar(context, error, isError: true);
      return;
    }
    final confirmed = await showConfirmDialog(
      context,
      title: S.downloadBackup,
      message: S.downloadLinkValidOnceP0P1(url, record.sizeText),
      confirmLabel: S.copyLink2,
      icon: Icons.download_rounded,
    );
    if (!confirmed || !mounted) return;
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) showAppSnackBar(context, S.downloadLinkCopied);
  }
}

class _RestoreProgressDialog extends StatefulWidget {
  final ApiService api;
  final String safetyFileName;

  const _RestoreProgressDialog({required this.api, required this.safetyFileName});

  @override
  State<_RestoreProgressDialog> createState() => _RestoreProgressDialogState();
}

class _RestoreProgressDialogState extends State<_RestoreProgressDialog> {
  Timer? _timer;
  bool _polling = false;
  bool _finished = false;
  final Stopwatch _elapsed = Stopwatch()..start();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    if (_polling || _finished) return;
    _polling = true;
    try {
      final state = await widget.api.fetchRestoreState();
      if (!mounted || _finished) return;
      setState(() {});
      if (state == 'done' || state == 'failed') {
        _finished = true;
        _timer?.cancel();
        Navigator.pop(context, state);
      }
    } finally {
      _polling = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final seconds = _elapsed.elapsed.inSeconds;

    return PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: c.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            CircularProgressIndicator(color: c.accent),
            const SizedBox(height: 20),
            Text(
              S.restoringDatabase,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              S.p0SecondsSoFarKeepApp(seconds),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.5, color: c.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

