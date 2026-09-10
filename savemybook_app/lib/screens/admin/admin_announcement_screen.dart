import 'package:flutter/material.dart';
import '../../models/admin_models.dart';
import '../../services/api_service.dart';
import '../../utils/api_helpers.dart';
import '../../utils/app_colors.dart';
import '../../widgets/app_header.dart';
import '../../widgets/state_views.dart';
import 'admin_announcement_edit_screen.dart';

/// 系統公告－推播管理
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
    final c = AppColors.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('刪除公告', style: TextStyle(fontWeight: FontWeight.bold, color: c.textPrimary)),
        content: Text('確定要刪除「${announcement.title}」嗎？', style: TextStyle(color: c.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('刪除', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final ok = await _api.deleteAnnouncement(announcement.announcementId);
    if (!mounted) return;
    if (ok) {
      showAppSnackBar(context, '公告已刪除');
      _load();
    } else {
      showAppSnackBar(context, '刪除失敗，請稍後再試', isError: true);
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
            title: '系統公告',
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
            child: _isLoading
                ? const LoadingView()
                : RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: _load,
                    child: _announcements.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 80),
                              EmptyView(icon: Icons.campaign_outlined, message: '還沒有任何公告，點右上角新增推播'),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _announcements.length,
                            itemBuilder: (_, i) => _buildCard(_announcements[i], c),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Announcement announcement, AppColors c) {
    final statusColor = announcement.isPublished ? const Color(0xFF2E9E5B) : Colors.orangeAccent;

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
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(announcement.typeText,
                    style: const TextStyle(fontSize: 10, color: AppColors.primary)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(announcement.isPublished ? '已發布' : '草稿',
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
              Text('發送對象：全體使用者', style: TextStyle(fontSize: 11, color: c.textHint)),
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
