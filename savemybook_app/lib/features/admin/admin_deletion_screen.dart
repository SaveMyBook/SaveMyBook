import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/admin_models.dart';
import '../../services/api_service.dart';
import '../../utils/api_helpers.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_radius.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_tiles.dart';
import '../../widgets/state_views.dart';
import 'admin_member_detail_screen.dart';
import '../../i18n/strings.dart';
import 'admin_layout.dart';

class AdminDeletionScreen extends StatefulWidget {
  const AdminDeletionScreen({super.key});

  @override
  State<AdminDeletionScreen> createState() => _AdminDeletionScreenState();
}

class _AdminDeletionScreenState extends State<AdminDeletionScreen> {
  final ApiService _api = ApiService();

  List<PendingDeletion> _pending = [];
  bool _isLoading = true;
  int? _busyUserId;
  bool _busyPurge = false;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pending = await _api.fetchPendingDeletions();
    if (!mounted) return;
    pending.sort((a, b) {
      final left = a.purgeAt ?? DateTime(9999);
      final right = b.purgeAt ?? DateTime(9999);
      return left.compareTo(right);
    });
    setState(() {
      _pending = pending;
      _isLoading = false;
    });
  }

  Future<void> _retry() async {
    setState(() => _isLoading = true);
    await _load();
  }

  void _report(String? error, String success) {
    if (error == null) {
      showAppSnackBar(context, success);
    } else if (error.isNotEmpty && error != S.verificationCancelled) {
      showAppSnackBar(context, error, isError: true);
    }
  }

  Future<void> _cancel(PendingDeletion item) async {
    if (_busyUserId != null) return;
    final confirmed = await showConfirmDialog(
      context,
      title: S.cancelDeletionRequest,
      message: S.p0SAccountReturnsNormalCountdown(item.nickname),
      confirmLabel: S.cancelDeletion,
      icon: Icons.undo_rounded,
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _busyUserId = item.userId;
      _busyPurge = false;
    });
    String? error;
    try {
      error = await _api.cancelMemberDeletion(item.userId);
    } finally {
      if (mounted) setState(() => _busyUserId = null);
    }
    if (!mounted) return;
    _report(error, S.deletionRequestCancelled);
    if (error == null) await _load();
  }

  Future<void> _purge(PendingDeletion item) async {
    if (_busyUserId != null) return;
    final confirmed = await showConfirmDialog(
      context,
      title: S.anonymiseNow,
      message: S.eraseP0SPersonalDataDisable(item.nickname),
      confirmLabel: S.doNow,
      isDestructive: true,
      icon: Icons.delete_forever_rounded,
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _busyUserId = item.userId;
      _busyPurge = true;
    });
    String? error;
    try {
      error = await _api.purgeMember(item.userId);
    } finally {
      if (mounted) setState(() => _busyUserId = null);
    }
    if (!mounted) return;
    _report(error, S.anonymised);
    if (error == null) {
      HapticFeedback.mediumImpact();
      await _load();
    }
  }

  Future<void> _openMember(PendingDeletion item) async {
    if (_navigating) return;
    _navigating = true;
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AdminMemberDetailScreen(userId: item.userId)),
      );
    } finally {
      _navigating = false;
    }
    if (mounted) _load();
  }

  void _copyEmail(PendingDeletion item) {
    if (item.email.isEmpty) return;
    Clipboard.setData(ClipboardData(text: item.email));
    HapticFeedback.selectionClick();
    showAppSnackBar(context, S.copied('Email'));
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.scaffold,
      body: AdminLayout(
        builder: (context, frame) => Column(
          children: [
            AppHeader(title: S.pendingDeletions, icon: Icons.person_remove_outlined),
            Expanded(
              child: SwitchIn(
                child: _isLoading
                    ? const LoadingView.list()
                    : RefreshIndicator(
                        color: c.accent,
                        onRefresh: _load,
                        child: SwitchIn(
                          child: _pending.isEmpty
                              ? ListView(
                                  key: const ValueKey('empty'),
                                  children: [
                                    const SizedBox(height: 80),
                                    EmptyView(
                                      icon: Icons.verified_user_outlined,
                                      message: S.noDeletionRequestsPending,
                                      actionLabel: S.refresh,
                                      onAction: _retry,
                                    ),
                                  ],
                                )
                              : ListView.builder(
                                  key: const ValueKey('items'),
                                  padding: frame.inset(const EdgeInsets.fromLTRB(16, 20, 16, 32)),
                                  itemCount: _pending.length,
                                  itemBuilder: (_, i) => RevealOnScroll(
                                    index: i,
                                    child: Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: _buildCard(_pending[i], c),
                                    ),
                                  ),
                                ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(PendingDeletion item, AppColors c) {
    final days = item.daysLeft;
    final urgent = days <= 7;
    final busy = _busyUserId == item.userId;
    final locked = _busyUserId != null;

    return AppCard(
      padding: const EdgeInsets.all(16),
      onTap: () => _openMember(item),
      onLongPress: () => _copyEmail(item),
      child: Column(
        children: [
          Row(
            children: [
              UserAvatar(imageUrl: item.avatarUrl, radius: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.nickname,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.email,
                            style: TextStyle(fontSize: 12, color: c.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (item.email.isNotEmpty)
                          PressableScale(
                            onTap: () => _copyEmail(item),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              child: Icon(Icons.copy_rounded, size: 13, color: c.iconInactive),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(
                label: days == 0 ? S.dueSoon : S.p0DaysLeft(days),
                color: urgent ? c.danger : c.warning,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.schedule_rounded, size: 14, color: c.textHint),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  S.requestedP0ScheduledP1(formatDateTime(item.requestedAt), formatDateTime(item.purgeAt)),
                  style: TextStyle(fontSize: 11, height: 1.4, color: c.textHint),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: locked ? null : () => _cancel(item),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.accent,
                    side: BorderSide(color: locked ? c.border : c.accent),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.control),
                    ),
                  ),
                  child: busy && !_busyPurge
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: c.accent),
                        )
                      : Text(S.cancelDeletion, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: locked ? null : () => _purge(item),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.danger,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: c.danger.withValues(alpha: 0.4),
                    disabledForegroundColor: Colors.white70,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.control),
                    ),
                  ),
                  child: busy && _busyPurge
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(S.doNow, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
