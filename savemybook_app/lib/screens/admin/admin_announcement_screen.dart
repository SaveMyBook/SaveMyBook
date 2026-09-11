import 'package:flutter/material.dart';
import '../../models/admin_models.dart';
import '../../services/api_service.dart';
import '../../utils/api_helpers.dart';
import '../../utils/app_colors.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/app_header.dart';
import '../../widgets/state_views.dart';
import 'admin_announcement_edit_screen.dart';
import '../../i18n/strings.dart';

class AdminAnnouncementScreen extends StatefulWidget {
  const AdminAnnouncementScreen({super.key});

  @override
  State<AdminAnnouncementScreen> createState() => _AdminAnnouncementScreenState();
}

class _AdminAnnouncementScreenState extends State<AdminAnnouncementScreen> {
  final ApiService _api = ApiService();
  List<Announcement> _announcements = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _api.fetchAnnouncements(includeDrafts: true);
    if (!mounted) return;
    setState(() {
      _announcements = list;
      _isLoading = false;
    });
  }

  Future<void> _delete(Announcement announcement) async {
    final confirmed = await showConfirmDialog(
      context,
      title: S.deleteAnnouncement,
      message: S.deleteP0CannotUndone(announcement.title),
      confirmLabel: S.actionDelete,
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    final ok = await runBusy(context, () => _api.deleteAnnouncement(announcement.announcementId));
    if (!mounted) return;

    if (ok == true) {
      showAppSnackBar(context, S.announcementDeleted);
      _load();
    } else {
      showAppSnackBar(context, S.couldNotDeleteTryAgainLater, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          AppHeader(
            title: S.announcements,
            icon: Icons.campaign_outlined,
            actions: [
              HeaderIconButton(
                icon: Icons.add_rounded,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminAnnouncementEditScreen()),
                  );
                  _load();
                },
              ),
            ],
          ),
          Expanded(
            child: SwitchIn(child: _isLoading
                ? const LoadingView.list()
                : RefreshIndicator(
                    color: c.accent,
                    onRefresh: _load,
                    child: SwitchIn(child: _announcements.isEmpty
                        ? ListView(key: const ValueKey('empty'), 
                            children: [
                              SizedBox(height: 80),
                              EmptyView(icon: Icons.campaign_outlined, message: S.noAnnouncementsYetTapAddOne),
                            ],
                          )
                        : ListView.builder(key: const ValueKey('items'), 
                            padding: const EdgeInsets.all(16),
                            itemCount: _announcements.length,
                            itemBuilder: (_, i) => RevealOnScroll(index: i, child: _buildCard(_announcements[i], c)),
                          )),
                  )),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Announcement announcement, AppColors c) {
    final statusColor = announcement.isPublished ? c.success : c.warning;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AdminAnnouncementEditScreen(announcement: announcement),
          ),
        );
        _load();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(announcement.typeText,
                    style: const TextStyle(fontSize: 10, color: AppColors.primary)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(announcement.isPublished ? S.published : S.draft,
                    style: TextStyle(fontSize: 10, color: statusColor)),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _delete(announcement),
                child: Icon(Icons.delete_outline_rounded, size: 20, color: c.iconInactive),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(announcement.title,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c.textPrimary)),
          const SizedBox(height: 6),
          Text(
            announcement.content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: c.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(S.audienceEveryone, style: TextStyle(fontSize: 11, color: c.textHint)),
              const Spacer(),
              Text(
                formatDateTime(announcement.publishedAt ?? announcement.createdAt),
                style: TextStyle(fontSize: 11, color: c.textHint),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
