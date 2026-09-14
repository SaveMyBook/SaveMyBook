import 'package:flutter/material.dart';
import '../../models/admin_models.dart';
import '../../services/api_service.dart';
import '../../utils/api_helpers.dart';
import '../../utils/app_colors.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_tiles.dart';
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
  bool _isBusy = false;
  bool _navigating = false;
  String _filter = 'all';

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

  Future<void> _retry() async {
    setState(() => _isLoading = true);
    await _load();
  }

  List<Announcement> get _visible => switch (_filter) {
        'published' => _announcements.where((a) => a.isPublished).toList(),
        'draft' => _announcements.where((a) => !a.isPublished).toList(),
        _ => _announcements,
      };

  Future<void> _openEditor([Announcement? announcement]) async {
    if (_navigating) return;
    _navigating = true;
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AdminAnnouncementEditScreen(announcement: announcement),
        ),
      );
    } finally {
      _navigating = false;
    }
    if (mounted) _load();
  }

  Future<void> _delete(Announcement announcement) async {
    if (_isBusy) return;
    final confirmed = await showConfirmDialog(
      context,
      title: S.deleteAnnouncement,
      message: S.deleteP0CannotUndone(announcement.title),
      confirmLabel: S.actionDelete,
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _isBusy = true);
    final ok = await runBusy(context, () => _api.deleteAnnouncement(announcement.announcementId));
    if (!mounted) return;
    setState(() => _isBusy = false);

    if (ok == true) {
      showAppSnackBar(context, S.announcementDeleted);
      await _load();
    } else {
      showAppSnackBar(context, S.couldNotDeleteTryAgainLater, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final visible = _visible;

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
                onTap: () => _openEditor(),
              ),
            ],
          ),
          if (_announcements.isNotEmpty)
            SizedBox(
              height: 46,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                children: [
                  _chip(S.actionAll, 'all', _announcements.length, c),
                  _chip(S.published, 'published', _announcements.where((a) => a.isPublished).length, c),
                  _chip(S.draft, 'draft', _announcements.where((a) => !a.isPublished).length, c),
                ],
              ),
            ),
          Expanded(
            child: SwitchIn(child: _isLoading
                ? const LoadingView.list()
                : RefreshIndicator(
                    color: c.accent,
                    onRefresh: _load,
                    child: SwitchIn(child: visible.isEmpty
                        ? ListView(key: const ValueKey('empty'),
                            children: [
                              const SizedBox(height: 80),
                              EmptyView(
                                icon: Icons.campaign_outlined,
                                message: S.noAnnouncementsYetTapAddOne,
                                actionLabel: _filter == 'all' ? S.refresh : S.clearFilters,
                                onAction: _filter == 'all' ? _retry : () => setState(() => _filter = 'all'),
                              ),
                            ],
                          )
                        : ListView.builder(key: ValueKey('items_$_filter'),
                            padding: const EdgeInsets.all(16),
                            itemCount: visible.length,
                            itemBuilder: (_, i) => RevealOnScroll(index: i, child: _buildCard(visible[i], c)),
                          )),
                  )),
          ),
        ],
      ),
    );
  }

  static String _when(DateTime? dt) {
    if (dt == null) return '';
    final relative = formatRelative(dt);
    final exact = formatDateTime(dt);
    return exact.startsWith(relative) ? exact : '$relative・$exact';
  }

  Widget _chip(String label, String value, int count, AppColors c) {
    final selected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: PressableScale(
        scale: 0.94,
        onTap: () => setState(() => _filter = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? c.accent : c.categoryChip,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            '$label $count',
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              color: selected ? Colors.white : c.accent,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(Announcement announcement, AppColors c) {
    final statusColor = announcement.isPublished ? c.success : c.warning;
    final expired = announcement.expiresAt != null && announcement.expiresAt!.isBefore(DateTime.now());

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () => _openEditor(announcement),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    StatusBadge(label: announcement.typeText, color: c.accent, fontSize: 10),
                    StatusBadge(
                      label: announcement.isPublished ? S.published : S.draft,
                      color: statusColor,
                      fontSize: 10,
                    ),
                    if (expired) StatusBadge(label: S.expired, color: c.iconInactive, fontSize: 10),
                  ],
                ),
              ),
              PressableScale(
                onTap: _isBusy ? null : () => _delete(announcement),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.delete_outline_rounded, size: 20, color: c.iconInactive),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(announcement.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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
              Expanded(
                child: Text(S.audienceEveryone, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: c.textHint)),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  _when(announcement.publishedAt ?? announcement.createdAt),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: c.textHint),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
