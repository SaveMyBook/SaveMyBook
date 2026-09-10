import 'package:flutter/material.dart';
import '../models/app_notification.dart';
import '../services/api_service.dart';
import '../utils/api_helpers.dart';
import '../utils/app_colors.dart';
import '../widgets/app_header.dart';
import '../widgets/state_views.dart';
import 'chat_list_screen.dart';
import 'purchase_history_screen.dart';

/// 通知中心。可獨立開啟，也可嵌在首頁的底部導覽（embedded = true 時不顯示返回鍵）。
class NotificationScreen extends StatefulWidget {
  final bool embedded;
  const NotificationScreen({super.key, this.embedded = false});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final ApiService _api = ApiService();
  List<AppNotification> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _api.fetchNotifications();
    if (!mounted) return;
    setState(() {
      _notifications = list;
      _isLoading = false;
    });
  }

  Future<void> _markAllRead() async {
    final ok = await _api.markAllNotificationsRead();
    if (!mounted) return;
    if (ok) {
      showAppSnackBar(context, '已全部標為已讀');
      await _load();
    } else {
      showAppSnackBar(context, '操作失敗，請稍後再試', isError: true);
    }
  }

  Future<void> _onTapNotification(AppNotification n) async {
    if (!n.isRead) {
      await _api.markNotificationRead(n.notificationId);
      if (mounted) {
        setState(() {
          _notifications = _notifications
              .map((e) => e.notificationId == n.notificationId
                  ? AppNotification(
                      notificationId: e.notificationId,
                      type: e.type,
                      title: e.title,
                      content: e.content,
                      relatedId: e.relatedId,
                      relatedType: e.relatedType,
                      isRead: true,
                      createdAt: e.createdAt,
                    )
                  : e)
              .toList();
        });
      }
    }

    if (!mounted) return;
    if (n.relatedType == 'chat_room') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatListScreen()));
    } else if (n.relatedType == 'order') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const PurchaseHistoryScreen()));
    }
  }

  Future<void> _delete(AppNotification n) async {
    final ok = await _api.deleteNotification(n.notificationId);
    if (!mounted) return;
    if (ok) {
      setState(() => _notifications.removeWhere((e) => e.notificationId == n.notificationId));
    } else {
      showAppSnackBar(context, '刪除失敗', isError: true);
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
            title: '通知中心',
            icon: Icons.notifications_none_rounded,
            showBack: !widget.embedded,
            actions: [
              HeaderIconButton(icon: Icons.done_all_rounded, onTap: _markAllRead),
            ],
          ),
          Expanded(
            child: _isLoading
                ? const LoadingView()
                : RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: _load,
                    child: _notifications.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 80),
                              EmptyView(icon: Icons.notifications_off_outlined, message: '目前沒有任何通知'),
                            ],
                          )
                        : ListView.builder(
                            padding: EdgeInsets.only(
                              left: 16,
                              right: 16,
                              top: 16,
                              bottom: MediaQuery.of(context).padding.bottom + (widget.embedded ? 100 : 24),
                            ),
                            itemCount: _notifications.length,
                            itemBuilder: (_, i) => _buildTile(_notifications[i], c),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(AppNotification n, AppColors c) {
    return Dismissible(
      key: ValueKey(n.notificationId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
      ),
      onDismissed: (_) => _delete(n),
      child: AppCard(
        margin: const EdgeInsets.only(bottom: 12),
        onTap: () => _onTapNotification(n),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(n.icon, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          n.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: n.isRead ? FontWeight.w500 : FontWeight.bold,
                            color: c.textPrimary,
                          ),
                        ),
                      ),
                      if (!n.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    n.content,
                    style: TextStyle(fontSize: 13, color: c.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    formatDateTime(n.createdAt),
                    style: TextStyle(fontSize: 11, color: c.textHint),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
