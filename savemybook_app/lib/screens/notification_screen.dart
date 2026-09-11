import 'package:flutter/material.dart';
import '../models/app_notification.dart';
import '../services/api_service.dart';
import '../utils/api_helpers.dart';
import '../utils/app_colors.dart';
import '../widgets/animations.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/app_header.dart';
import '../widgets/state_views.dart';
import '../widgets/swipe_action.dart';
import 'book_manage_screen.dart';
import 'chat_list_screen.dart';
import 'purchase_history_screen.dart';

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

  int _lastSeenUnread = ApiService.unreadNotificationCount.value;

  @override
  void initState() {
    super.initState();
    // 首頁把通知頁包在 IndexedStack 裡，不會重建，所以改成聽未讀數自己補資料。
    ApiService.unreadNotificationCount.addListener(_onUnreadChanged);
    _load();
  }

  @override
  void dispose() {
    ApiService.unreadNotificationCount.removeListener(_onUnreadChanged);
    super.dispose();
  }

  void _onUnreadChanged() {
    final next = ApiService.unreadNotificationCount.value;
    final increased = next > _lastSeenUnread;
    _lastSeenUnread = next;
    if (increased && mounted) _load();
  }

  Future<void> _load() async {
    final list = await _api.fetchNotifications();
    if (!mounted) return;
    _lastSeenUnread = ApiService.unreadNotificationCount.value;
    setState(() {
      _notifications = list;
      _isLoading = false;
    });
  }

  Future<void> _clearAll() async {
    if (_notifications.isEmpty) {
      showAppSnackBar(context, '沒有通知可以清除');
      return;
    }

    final confirmed = await showConfirmDialog(
      context,
      title: '清除全部通知',
      message: '會刪除 ${_notifications.length} 則通知，無法復原。',
      confirmLabel: '全部清除',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    final ok = await runBusy(context, () => _api.clearAllNotifications());
    if (!mounted) return;

    if (ok == true) {
      setState(() => _notifications = []);
      showAppSnackBar(context, '已清除全部通知');
    } else {
      showAppSnackBar(context, '清除失敗，請稍後再試', isError: true);
    }
  }

  Future<void> _markAllRead() async {
    final unread = _notifications.where((n) => !n.isRead).length;
    if (unread == 0) {
      showAppSnackBar(context, '沒有未讀的通知');
      return;
    }

    final confirmed = await showConfirmDialog(
      context,
      title: '全部標為已讀',
      message: '要把 $unread 則未讀通知全部標為已讀嗎？此動作無法復原。',
      confirmLabel: '全部已讀',
    );
    if (!confirmed || !mounted) return;

    final ok = await runBusy(context, () => _api.markAllNotificationsRead());
    if (!mounted) return;

    if (ok == true) {
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
    await _showDetail(n);
  }

  Future<void> _showDetail(AppNotification n) async {
    final c = AppColors.of(context);

    final target = switch (n.relatedType) {
      'chat_room' => (label: '前往聊天室', screen: const ChatListScreen()),
      'order' => (label: '查看訂單', screen: const PurchaseHistoryScreen()),
      'book' => (label: '前往書籍管理', screen: const BookManageScreen()),
      _ => null,
    };

    final go = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: c.sheetBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: c.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(n.icon, size: 20, color: c.accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      n.title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                n.content,
                style: TextStyle(fontSize: 14, height: 1.7, color: c.textSecondary),
              ),
              const SizedBox(height: 14),
              Text(formatDateTime(n.createdAt), style: TextStyle(fontSize: 12, color: c.textHint)),
              const SizedBox(height: 22),
              if (target != null)
                PrimaryButton(label: target.label, onPressed: () => Navigator.pop(ctx, true))
              else
                SecondaryButton(label: '關閉', onPressed: () => Navigator.pop(ctx, false)),
            ],
          ),
        ),
      ),
    );

    if (go == true && target != null && mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => target.screen));
    }
  }

  Future<void> _delete(AppNotification n) async {
    setState(() => _notifications.removeWhere((e) => e.notificationId == n.notificationId));

    final ok = await _api.deleteNotification(n.notificationId);
    if (!mounted) return;

    if (!ok) {
      showAppSnackBar(context, '刪除失敗，已還原', isError: true);
      _load();
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
              HeaderIconButton(icon: Icons.delete_sweep_outlined, onTap: _clearAll),
            ],
          ),
          Expanded(
            child: SwitchIn(child: _isLoading
                ? const LoadingView.list()
                : RefreshIndicator(
                    color: c.accent,
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
                            itemBuilder: (_, i) => RevealOnScroll(index: i, child: _buildTile(_notifications[i], c)),
                          ),
                  )),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(AppNotification n, AppColors c) {
    return SwipeActionTile(
      itemKey: ValueKey('notification_${n.notificationId}'),
      endToStart: SwipeAction(
        icon: Icons.delete_outline_rounded,
        label: '刪除',
        color: c.danger,
        dismisses: true,
        onTrigger: () async => true,
        onDismissed: () => _delete(n),
      ),
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
                color: c.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(n.icon, size: 20, color: c.accent),
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
                      PopIn(
                        triggerKey: n.isRead,
                        child: n.isRead
                            ? const SizedBox(width: 8, height: 8)
                            : Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: c.danger,
                                  shape: BoxShape.circle,
                                ),
                              ),
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
