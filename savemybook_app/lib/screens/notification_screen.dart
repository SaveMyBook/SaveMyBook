import 'package:flutter/material.dart';
import '../models/app_notification.dart';
import '../services/api_service.dart';
import '../utils/api_helpers.dart';
import '../utils/app_colors.dart';
import '../utils/motion.dart';
import 'package:flutter/services.dart';
import '../widgets/animations.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/app_header.dart';
import '../widgets/state_views.dart';
import '../widgets/swipe_action.dart';
import '../widgets/buyer/undo_snackbar.dart';
import '../services/notification_router.dart';
import 'announcement_screen.dart';
import '../i18n/strings.dart';

class NotificationScreen extends StatefulWidget {
  final bool embedded;
  const NotificationScreen({super.key, this.embedded = false});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this)..addListener(_onTabChanged);
  final ApiService _api = ApiService();
  List<AppNotification> _notifications = [];
  final Set<int> _pendingDelete = {};
  bool _isLoading = true;

  int _lastSeenUnread = ApiService.unreadNotificationCount.value;

  @override
  void initState() {
    super.initState();
    ApiService.unreadNotificationCount.addListener(_onUnreadChanged);
    _load();
  }

  @override
  void dispose() {
    ApiService.unreadNotificationCount.removeListener(_onUnreadChanged);
    _tabs.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabs.indexIsChanging && mounted) setState(() {});
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
      showAppSnackBar(context, S.noNotificationsClear);
      return;
    }

    final confirmed = await showConfirmDialog(
      context,
      title: S.clearAllNotifications,
      message: S.notificationsDeletedCannotUndone(_notifications.length),
      confirmLabel: S.clearAll,
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    final ok = await runBusy(context, () => _api.clearAllNotifications());
    if (!mounted) return;

    if (ok == true) {
      setState(() => _notifications = []);
      showAppSnackBar(context, S.allNotificationsCleared);
    } else {
      showAppSnackBar(context, S.couldNotClearPleaseTryAgain, isError: true);
    }
  }

  Future<void> _markAllRead() async {
    final unread = _notifications.where((n) => !n.isRead).length;
    if (unread == 0) {
      showAppSnackBar(context, S.noUnreadNotifications);
      return;
    }

    final confirmed = await showConfirmDialog(
      context,
      title: S.markAllAsRead,
      message: S.markAllUnreadNotificationsAsRead(unread),
      confirmLabel: S.markAllRead,
    );
    if (!confirmed || !mounted) return;

    final ok = await runBusy(context, () => _api.markAllNotificationsRead());
    if (!mounted) return;

    if (ok == true) {
      setState(() => _notifications = _notifications.map((e) => _asRead(e)).toList());
      showAppSnackBar(context, S.allMarkedAsRead);
    } else {
      showAppSnackBar(context, S.somethingWentWrongPleaseTryAgain, isError: true);
    }
  }

  AppNotification _asRead(AppNotification e) => e.isRead
      ? e
      : AppNotification(
          notificationId: e.notificationId,
          type: e.type,
          title: e.title,
          content: e.content,
          relatedId: e.relatedId,
          relatedType: e.relatedType,
          isRead: true,
          createdAt: e.createdAt,
        );

  Future<bool> _markRead(AppNotification n) async {
    if (n.isRead) return false;
    HapticFeedback.selectionClick();
    setState(() {
      _notifications = _notifications.map((e) => e.notificationId == n.notificationId ? _asRead(e) : e).toList();
    });
    final ok = await _api.markNotificationRead(n.notificationId);
    if (!ok && mounted) {
      showAppSnackBar(context, S.somethingWentWrongPleaseTryAgain, isError: true);
      _load();
    }
    return false;
  }

  Future<void> _onTapNotification(AppNotification n) async {
    if (!n.isRead) _markRead(n);
    await _showDetail(n);
  }

  Future<void> _showDetail(AppNotification n) async {
    final c = AppColors.of(context);

    final target = NotificationRouter.hasTarget(n.relatedType, n.relatedId)
        ? (label: S.viewDetails,)
        : null;

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
              Text(formatDateTime(n.createdAt?.toLocal()), style: TextStyle(fontSize: 12, color: c.textHint)),
              const SizedBox(height: 22),
              if (target != null)
                PrimaryButton(label: target.label, onPressed: () => Navigator.pop(ctx, true))
              else
                SecondaryButton(label: S.actionClose, onPressed: () => Navigator.pop(ctx, false)),
            ],
          ),
        ),
      ),
    );

    if (go == true && target != null && mounted) {
      final opened = await runBusy(context, () => NotificationRouter.openNotification(Navigator.of(context), n));
      if (opened != true && mounted) {
        showAppSnackBar(context, S.notFoundMayBeenDeletedRemoved, isError: true);
      }
    }
  }

  Future<void> _delete(AppNotification n) async {
    setState(() => _pendingDelete.add(n.notificationId));
    final undo = await showUndoSnackBar(context, S.notificationDeleted, icon: Icons.notifications_off_outlined);
    if (undo) {
      if (mounted) setState(() => _pendingDelete.remove(n.notificationId));
      return;
    }

    final ok = await _api.deleteNotification(n.notificationId);
    if (!mounted) return;
    setState(() {
      _pendingDelete.remove(n.notificationId);
      if (ok) _notifications.removeWhere((e) => e.notificationId == n.notificationId);
    });
    if (!ok) {
      showAppSnackBar(context, S.couldNotDeleteRestored, isError: true);
    } else if (!n.isRead) {
      _api.fetchUnreadNotificationCount();
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
            title: S.notifications,
            icon: Icons.notifications_none_rounded,
            showBack: !widget.embedded,
            actions: _tabs.index == 0
                ? [
                    HeaderIconButton(icon: Icons.done_all_rounded, onTap: _markAllRead),
                    HeaderIconButton(icon: Icons.delete_sweep_outlined, onTap: _clearAll),
                  ]
                : const [],
            bottom: AppTabBar(controller: _tabs, tabs: [S.alerts, S.announcement]),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _buildNotificationList(c),
                AnnouncementList(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + (widget.embedded ? 100 : 24)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationList(AppColors c) {
    final visible = _notifications.where((n) => !_pendingDelete.contains(n.notificationId)).toList();
    final bottom = MediaQuery.of(context).padding.bottom + (widget.embedded ? 100 : 24);

    return SwitchIn(
      child: _isLoading
          ? const LoadingView.list()
          : RefreshIndicator(
              key: const ValueKey('content'),
              color: c.accent,
              onRefresh: _load,
              child: SwitchIn(
                child: visible.isEmpty
                    ? ListView(
                        key: const ValueKey('empty'),
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 80),
                          EmptyView(icon: Icons.notifications_off_outlined, message: S.noNotifications),
                        ],
                      )
                    : ListView.builder(
                        key: const ValueKey('items'),
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(16, 16, 16, bottom),
                        itemCount: visible.length,
                        itemBuilder: (_, i) => RevealOnScroll(
                          key: ValueKey(visible[i].notificationId),
                          index: i,
                          child: _buildTile(visible[i], c),
                        ),
                      ),
              ),
            ),
    );
  }

  Widget _buildTile(AppNotification n, AppColors c) {
    return SwipeActionTile(
      itemKey: ValueKey('notification_${n.notificationId}'),
      startToEnd: n.isRead
          ? null
          : SwipeAction(
              icon: Icons.mark_email_read_outlined,
              label: S.read,
              color: c.success,
              onTrigger: () => _markRead(n),
            ),
      endToStart: SwipeAction(
        icon: Icons.delete_outline_rounded,
        label: S.actionDelete,
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
            AnimatedContainer(
              duration: Motion.base,
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: (n.isRead ? c.textHint : c.accent).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(n.icon, size: 20, color: n.isRead ? c.textSecondary : c.accent),
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
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: c.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    formatRelative(n.createdAt?.toLocal()),
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
