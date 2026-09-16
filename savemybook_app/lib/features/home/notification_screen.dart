import 'package:flutter/material.dart';
import '../../models/app_notification.dart';
import '../../models/notification_category.dart';
import '../../services/api_service.dart';
import '../../utils/api_helpers.dart';
import '../../utils/app_colors.dart';
import '../../utils/motion.dart';
import 'package:flutter/services.dart';
import '../../widgets/responsive.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/app_header.dart';
import '../../widgets/state_views.dart';
import '../../widgets/swipe_action.dart';
import '../../widgets/buyer/undo_snackbar.dart';
import '../../services/notification_router.dart';
import 'announcement_screen.dart';
import '../../i18n/strings.dart';

class NotificationScreen extends StatefulWidget {
  final bool embedded;
  final NotificationCategory? initialCategory;
  const NotificationScreen({super.key, this.embedded = false, this.initialCategory});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _CategoryFeed {
  List<AppNotification> items = [];
  int total = 0;
  int page = 0;
  bool hasMore = false;
  bool loaded = false;
  bool loadingMore = false;
  int generation = 0;
}

class _NotificationScreenState extends State<NotificationScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this)..addListener(_onTabChanged);
  final ApiService _api = ApiService();
  final Map<NotificationCategory?, _CategoryFeed> _feeds = {};
  final Set<int> _pendingDelete = {};
  late NotificationCategory? _category = widget.initialCategory;

  int _lastSeenUnread = ApiService.unreadNotificationCount.value;
  int _requestsInFlight = 0;

  _CategoryFeed get _feed => _feeds.putIfAbsent(_category, _CategoryFeed.new);

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
    // 本頁自己的請求也會更新未讀數，若據此重新載入會與伺服器回應互相觸發而無限迴圈。
    if (increased && mounted && _requestsInFlight == 0) {
      for (final entry in _feeds.entries) {
        if (entry.key != _category) entry.value.loaded = false;
      }
      _load();
    }
  }

  Future<void> _load() async {
    final category = _category;
    final feed = _feed;
    final generation = ++feed.generation;
    _requestsInFlight++;
    final List<Object> results;
    try {
      results = await Future.wait([
        _api.fetchNotificationPage(category: category),
        _api.fetchUnreadNotificationCount(),
      ]);
    } finally {
      _requestsInFlight--;
    }
    final page = results[0] as NotificationPage;
    if (!mounted || generation != feed.generation) return;
    _lastSeenUnread = ApiService.unreadNotificationCount.value;
    setState(() {
      if (page.ok || !feed.loaded) {
        feed.items = page.items;
        feed.total = page.total;
        feed.page = 1;
        feed.hasMore = page.hasMore;
      }
      feed.loaded = true;
      feed.loadingMore = false;
    });
  }

  Future<void> _loadMore() async {
    final category = _category;
    final feed = _feed;
    if (!feed.loaded || !feed.hasMore || feed.loadingMore) return;
    final generation = feed.generation;
    setState(() => feed.loadingMore = true);
    _requestsInFlight++;
    final NotificationPage page;
    try {
      page = await _api.fetchNotificationPage(category: category, page: feed.page + 1);
    } finally {
      _requestsInFlight--;
    }
    if (!mounted || generation != feed.generation) return;
    setState(() {
      feed.loadingMore = false;
      if (!page.ok) {
        feed.hasMore = false;
        return;
      }
      final known = feed.items.map((n) => n.notificationId).toSet();
      feed.items = [...feed.items, ...page.items.where((n) => !known.contains(n.notificationId))];
      feed.total = page.total;
      feed.page += 1;
      feed.hasMore = page.hasMore;
    });
  }

  void _selectCategory(NotificationCategory? category) {
    if (category == _category) return;
    HapticFeedback.selectionClick();
    setState(() => _category = category);
    if (!_feed.loaded) _load();
  }

  bool _inScope(AppNotification n, NotificationCategory? category) => category == null || n.category == category;

  Future<void> _clearAll() async {
    final category = _category;
    final feed = _feed;
    if (feed.items.isEmpty) {
      showAppSnackBar(context, S.noNotificationsClear);
      return;
    }

    final count = feed.total > feed.items.length ? feed.total : feed.items.length;
    final label = category?.label;
    final confirmed = await showConfirmDialog(
      context,
      title: label == null ? S.clearAllNotifications : S.clearP0Notifications(label),
      message: label == null ? S.notificationsDeletedCannotUndone(count) : S.p1NotificationsP0DeletedCannotUndone(label, count),
      confirmLabel: S.clearAll,
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    _requestsInFlight++;
    final ok = await runBusy(context, () => _api.clearAllNotifications(category: category)).whenComplete(() => _requestsInFlight--);
    if (!mounted) return;

    if (ok == true) {
      setState(() {
        for (final entry in _feeds.entries) {
          if (entry.key == category) {
            entry.value
              ..items = []
              ..total = 0
              ..hasMore = false;
          } else if (category == null || entry.key == null) {
            entry.value.loaded = false;
            entry.value.items = category == null ? [] : entry.value.items.where((n) => !_inScope(n, category)).toList();
          }
        }
      });
      showAppSnackBar(context, label == null ? S.allNotificationsCleared : S.p0NotificationsCleared(label));
    } else {
      showAppSnackBar(context, S.couldNotClearPleaseTryAgain, isError: true);
    }
  }

  Future<void> _markAllRead() async {
    final category = _category;
    final loadedUnread = _feed.items.where((n) => !n.isRead).length;
    final serverUnread = category == null
        ? ApiService.unreadNotificationCount.value
        : ApiService.unreadNotificationsByCategory.value[category] ?? 0;
    final unread = serverUnread > loadedUnread ? serverUnread : loadedUnread;
    if (unread == 0) {
      showAppSnackBar(context, S.noUnreadNotifications);
      return;
    }

    final label = category?.label;
    final confirmed = await showConfirmDialog(
      context,
      title: S.markAllAsRead,
      message: label == null ? S.markAllUnreadNotificationsAsRead(unread) : S.markAllP1UnreadNotificationsP0(label, unread),
      confirmLabel: S.markAllRead,
    );
    if (!confirmed || !mounted) return;

    _requestsInFlight++;
    final ok = await runBusy(context, () => _api.markAllNotificationsRead(category: category)).whenComplete(() => _requestsInFlight--);
    if (!mounted) return;

    if (ok == true) {
      _lastSeenUnread = ApiService.unreadNotificationCount.value;
      setState(() {
        for (final feed in _feeds.values) {
          feed.items = feed.items.map((e) => _inScope(e, category) ? e.asRead() : e).toList();
        }
      });
      showAppSnackBar(context, S.allMarkedAsRead);
    } else {
      showAppSnackBar(context, S.somethingWentWrongPleaseTryAgain, isError: true);
    }
  }

  Future<bool> _markRead(AppNotification n) async {
    if (n.isRead) return false;
    HapticFeedback.selectionClick();
    setState(() {
      for (final feed in _feeds.values) {
        feed.items = feed.items.map((e) => e.notificationId == n.notificationId ? e.asRead() : e).toList();
      }
    });
    final ok = await _api.markNotificationRead(n.notificationId, category: n.category);
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
                      color: n.category.toneOf(c).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(n.icon, size: 20, color: n.category.toneOf(c)),
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
      if (ok) {
        for (final feed in _feeds.values) {
          final before = feed.items.length;
          feed.items = feed.items.where((e) => e.notificationId != n.notificationId).toList();
          if (feed.items.length < before && feed.total > 0) feed.total -= 1;
        }
      }
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
                  padding: EdgeInsets.fromLTRB(16, 16, 16, _bottomSpace),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double get _bottomSpace =>
      widget.embedded ? floatingNavClearance(context, 100) : MediaQuery.of(context).padding.bottom + 24;

  Widget _buildNotificationList(AppColors c) {
    return Column(
      children: [
        _buildCategoryBar(c),
        Expanded(child: _buildFeed(c)),
      ],
    );
  }

  Widget _buildCategoryBar(AppColors c) {
    final options = <NotificationCategory?>[null, ...NotificationCategory.values];
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = responsiveListPadding(constraints).left;
        return ValueListenableBuilder<Map<NotificationCategory, int>>(
          valueListenable: ApiService.unreadNotificationsByCategory,
          builder: (context, byCategory, _) => ValueListenableBuilder<int>(
            valueListenable: ApiService.unreadNotificationCount,
            builder: (context, total, _) => SizedBox(
              height: 52,
              child: ListView.separated(
                key: const ValueKey('notification_categories'),
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.fromLTRB(side, 12, side, 6),
                itemCount: options.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final category = options[i];
                  return _CategoryChip(
                    key: ValueKey('notification_category_${category?.key ?? 'all'}'),
                    label: category?.label ?? S.actionAll,
                    unread: category == null ? total : byCategory[category] ?? 0,
                    selected: category == _category,
                    onTap: () => _selectCategory(category),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeed(AppColors c) {
    final category = _category;
    final feed = _feed;
    final visible = feed.items.where((n) => !_pendingDelete.contains(n.notificationId)).toList();
    final bottom = _bottomSpace;

    return SwitchIn(
      child: !feed.loaded
          ? LoadingView.list(key: ValueKey('loading_${category?.key}'))
          : RefreshIndicator(
              key: ValueKey('content_${category?.key}'),
              color: c.accent,
              onRefresh: _load,
              child: SwitchIn(
                child: visible.isEmpty
                    ? ListView(
                        key: ValueKey('empty_${category?.key}'),
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 80),
                          EmptyView(
                            icon: category?.icon ?? Icons.notifications_off_outlined,
                            message: category?.emptyMessage ?? S.noNotifications,
                          ),
                        ],
                      )
                    : NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          if (notification.metrics.extentAfter < 400) _loadMore();
                          return false;
                        },
                        child: LayoutBuilder(builder: (context, constraints) => ListView.builder(
                          key: ValueKey('items_${category?.key}'),
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: responsiveListPadding(constraints, top: 10, bottom: bottom),
                          itemCount: visible.length + (feed.hasMore ? 1 : 0),
                          itemBuilder: (_, i) {
                            if (i >= visible.length) {
                              if (!feed.loadingMore) WidgetsBinding.instance.addPostFrameCallback((_) => _loadMore());
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                  child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: c.accent)),
                                ),
                              );
                            }
                            return RevealOnScroll(
                              key: ValueKey(visible[i].notificationId),
                              index: i,
                              child: _buildTile(visible[i], c),
                            );
                          },
                        )),
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
                color: n.category.toneOf(c).withValues(alpha: n.isRead ? 0.07 : 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(n.icon, size: 20, color: n.category.toneOf(c).withValues(alpha: n.isRead ? 0.6 : 1)),
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

class _CategoryChip extends StatelessWidget {
  final String label;
  final int unread;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({super.key, required this.label, required this.unread, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final foreground = selected ? Colors.white : c.accent;
    return Semantics(
      button: true,
      selected: selected,
      child: PressableScale(
        scale: 0.95,
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.micro,
          curve: Curves.easeOut,
          padding: EdgeInsets.fromLTRB(14, 0, unread > 0 ? 6 : 14, 0),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? c.accent : c.categoryChip,
            borderRadius: BorderRadius.circular(17),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.bold : FontWeight.w500, color: foreground),
              ),
              if (unread > 0) ...[
                const SizedBox(width: 6),
                Container(
                  constraints: const BoxConstraints(minWidth: 20),
                  height: 20,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? Colors.white.withValues(alpha: 0.25) : c.danger,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    unread > 99 ? '99+' : '$unread',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white, height: 1.1),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
