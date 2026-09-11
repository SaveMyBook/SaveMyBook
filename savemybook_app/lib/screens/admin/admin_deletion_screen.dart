import 'package:flutter/material.dart';
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
import '../../i18n/strings.dart';

class AdminDeletionScreen extends StatefulWidget {
  const AdminDeletionScreen({super.key});

  @override
  State<AdminDeletionScreen> createState() => _AdminDeletionScreenState();
}

class _AdminDeletionScreenState extends State<AdminDeletionScreen> {
  final ApiService _api = ApiService();

  List<PendingDeletion> _pending = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pending = await _api.fetchPendingDeletions();
    if (!mounted) return;
    setState(() {
      _pending = pending;
      _isLoading = false;
    });
  }

  Future<void> _cancel(PendingDeletion item) async {
    final confirmed = await showConfirmDialog(
      context,
      title: S.cancelDeletionRequest,
      message: S.p0SAccountReturnsNormalCountdown(item.nickname),
      confirmLabel: S.cancelDeletion,
      icon: Icons.undo_rounded,
    );
    if (!confirmed || !mounted) return;

    final error = await runBusy(context, () => _api.cancelMemberDeletion(item.userId));
    if (!mounted) return;
    showAppSnackBar(context, error ?? S.deletionRequestCancelled, isError: error != null);
    await _load();
  }

  Future<void> _purge(PendingDeletion item) async {
    final confirmed = await showConfirmDialog(
      context,
      title: S.anonymiseNow,
      message: S.eraseP0SPersonalDataDisable(item.nickname),
      confirmLabel: S.doNow,
      isDestructive: true,
      icon: Icons.delete_forever_rounded,
    );
    if (!confirmed || !mounted) return;

    final error = await runBusy(context, () => _api.purgeMember(item.userId));
    if (!mounted) return;
    showAppSnackBar(context, error ?? S.anonymised, isError: error != null);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
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
                                  SizedBox(height: 80),
                                  EmptyView(
                                    icon: Icons.verified_user_outlined,
                                    message: S.noDeletionRequestsPending,
                                  ),
                                ],
                              )
                            : ListView.builder(
                                key: const ValueKey('items'),
                                padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
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
    );
  }

  Widget _buildCard(PendingDeletion item, AppColors c) {
    final days = item.daysLeft;
    // 剩不到一週就用警示色，讓客服知道快要來不及攔了。
    final urgent = days <= 7;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: [
          BoxShadow(color: c.shadow.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
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
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.email,
                      style: TextStyle(fontSize: 12, color: c.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              StatusBadge(
                label: days == 0 ? S.dueSoon : S.p0DaysLeft(days),
                color: urgent ? c.danger : c.warning,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 14, color: c.textHint),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  S.requestedP0ScheduledP1(formatDateTime(item.requestedAt), formatDateTime(item.purgeAt)),
                  style: TextStyle(fontSize: 11, color: c.textHint),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _cancel(item),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.accent,
                    side: BorderSide(color: c.accent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.control),
                    ),
                  ),
                  child: Text(S.cancelDeletion),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _purge(item),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.danger,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.control),
                    ),
                  ),
                  child: Text(S.doNow),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
