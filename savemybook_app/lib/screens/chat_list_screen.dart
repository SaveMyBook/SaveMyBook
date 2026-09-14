import 'dart:async';

import 'package:flutter/material.dart';
import '../models/chat.dart';
import '../services/api_service.dart';
import '../services/chat_prefs.dart';
import '../utils/api_helpers.dart';
import '../utils/app_colors.dart';
import '../utils/motion.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/app_forms.dart';
import '../widgets/app_tiles.dart';
import '../widgets/animations.dart';
import '../widgets/app_header.dart';
import '../widgets/state_views.dart';
import '../widgets/swipe_action.dart';
import 'chat_room_screen.dart';
import '../i18n/strings.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> with WidgetsBindingObserver {
  final ApiService _api = ApiService();
  final TextEditingController _search = TextEditingController();
  List<ChatRoom> _rooms = [];
  Timer? _pollTimer;
  bool _isLoading = true;
  bool _refreshing = false;
  String _query = '';

  int get _myId => ApiService.currentUser?.userId ?? 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _startPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
      _load();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted && ModalRoute.isCurrentOf(context) != false) _load();
    });
  }

  Future<void> _load() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final rooms = await _api.fetchChatRooms();
      if (!mounted) return;
      setState(() {
        _rooms = rooms;
        _isLoading = false;
      });
    } finally {
      _refreshing = false;
    }
  }

  List<ChatRoom> get _visibleRooms {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _rooms;
    return _rooms.where((r) => r.partner.nickname.toLowerCase().contains(q)).toList();
  }

  Future<bool> _confirmDelete(ChatRoom room) {
    return showConfirmDialog(
      context,
      title: S.deleteChat,
      message: S.allMessagesWithDeletedBothCannot(room.partner.nickname),
      confirmLabel: S.actionDelete,
      isDestructive: true,
    );
  }

  Future<void> _deleteDismissed(ChatRoom room) async {
    setState(() => _rooms = _rooms.where((r) => r.roomId != room.roomId).toList());
    ChatPrefs.forget(room.roomId);

    final ok = await _api.deleteChatRoom(room.roomId);
    if (!mounted) return;

    if (ok) {
      showAppSnackBar(context, S.chatDeleted);
      _api.fetchUnreadChatCount();
    } else {
      showAppSnackBar(context, S.couldNotDeleteRestored, isError: true);
      _load();
    }
  }

  Future<bool> _toggleMute(ChatRoom room) async {
    final muted = await ChatPrefs.toggle(room.roomId);
    if (!mounted) return true;
    setState(() {});
    showAppSnackBar(context, muted ? S.chatMuted : S.chatUnmuted);
    return true;
  }

  Future<void> _markAllRead() async {
    final unread = _rooms.fold<int>(0, (sum, r) => sum + r.unreadCount);
    if (unread == 0) {
      showAppSnackBar(context, S.noUnreadMessages);
      return;
    }

    final confirmed = await showConfirmDialog(
      context,
      title: S.markAllAsRead,
      message: S.markAllUnreadMessagesAsRead(unread),
      confirmLabel: S.markAllRead,
    );
    if (!confirmed || !mounted) return;

    final ok = await runBusy(context, () => _api.markAllChatsRead());
    if (!mounted) return;

    if (ok == true) {
      showAppSnackBar(context, S.allMarkedAsRead);
      _load();
    } else {
      showAppSnackBar(context, S.somethingWentWrongPleaseTryAgain, isError: true);
    }
  }

  Future<void> _openRoom(ChatRoom room) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatRoomScreen(roomId: room.roomId, partnerName: room.partner.nickname),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          AppHeader(
            title: S.chats,
            icon: Icons.chat_bubble_outline_rounded,
            actions: [
              HeaderIconButton(icon: Icons.done_all_rounded, onTap: _markAllRead),
            ],
          ),
          Expanded(
            child: SwitchIn(
              child: _isLoading
                  ? const LoadingView.list()
                  : RefreshIndicator(
                      color: c.accent,
                      onRefresh: _load,
                      child: _buildList(c),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(AppColors c) {
    if (_rooms.isEmpty) {
      return ListView(
        key: const ValueKey('empty'),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          EmptyView(icon: Icons.forum_outlined, message: S.noConversationsYet),
        ],
      );
    }

    final rooms = _visibleRooms;
    final showSearch = _rooms.length >= 4 || _query.isNotEmpty;

    return ListView.builder(
      key: const ValueKey('items'),
      physics: const AlwaysScrollableScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: rooms.length + (showSearch ? 1 : 0) + (rooms.isEmpty ? 1 : 0),
      itemBuilder: (_, i) {
        if (showSearch && i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppSearchField(
              controller: _search,
              hint: S.searchChats,
              onChanged: (value) => setState(() => _query = value),
            ),
          );
        }
        final index = i - (showSearch ? 1 : 0);
        if (rooms.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(top: 40),
            child: EmptyView(icon: Icons.search_off_rounded, message: S.noMatchingChats),
          );
        }
        final room = rooms[index];
        return RevealOnScroll(
          key: ValueKey('reveal_${room.roomId}'),
          index: index,
          child: _buildRoomTile(room, c),
        );
      },
    );
  }

  Widget _buildRoomTile(ChatRoom room, AppColors c) {
    final muted = ChatPrefs.isMuted(room.roomId);

    return SwipeActionTile(
      itemKey: ValueKey('room_${room.roomId}'),
      startToEnd: SwipeAction(
        icon: muted ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
        label: muted ? S.unmute : S.mute,
        color: c.warning,
        onTrigger: () => _toggleMute(room),
      ),
      endToStart: SwipeAction(
        icon: Icons.delete_outline_rounded,
        label: S.actionDelete,
        color: c.danger,
        dismisses: true,
        onTrigger: () => _confirmDelete(room),
        onDismissed: () => _deleteDismissed(room),
      ),
      child: _buildRoomCard(room, c, muted),
    );
  }

  IconData? _kindIcon(String kind) {
    switch (kind) {
      case 'image':
        return Icons.image_outlined;
      case 'voice':
        return Icons.mic_none_rounded;
      case 'book':
        return Icons.menu_book_outlined;
      case 'reservation':
        return Icons.event_available_outlined;
      case 'recalled':
        return Icons.undo_rounded;
      default:
        return null;
    }
  }

  Widget _buildRoomCard(ChatRoom room, AppColors c, bool muted) {
    final unread = room.unreadCount > 0;
    final mine = room.lastSenderId != 0 && room.lastSenderId == _myId;
    final kindIcon = _kindIcon(room.lastKind);
    final previewColor = unread ? c.textPrimary : c.textSecondary;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: () => _openRoom(room),
      child: Row(
        children: [
          UserAvatar(
            imageUrl: room.partner.avatarUrl,
            radius: 26,
            enablePreview: true,
            previewTitle: room.partner.nickname,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        room.partner.nickname,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: unread ? FontWeight.w800 : FontWeight.bold,
                          color: c.textPrimary,
                        ),
                      ),
                    ),
                    if (muted) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.notifications_off_rounded, size: 14, color: c.textHint),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (mine) ...[
                      Icon(
                        room.lastIsRead ? Icons.done_all_rounded : Icons.check_rounded,
                        size: 15,
                        color: room.lastIsRead ? c.accent : c.textHint,
                      ),
                      const SizedBox(width: 3),
                      if (room.lastIsRead) ...[
                        Text(
                          S.read,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.accent),
                        ),
                        const SizedBox(width: 6),
                      ],
                    ],
                    if (kindIcon != null) ...[
                      Icon(kindIcon, size: 15, color: previewColor),
                      const SizedBox(width: 3),
                    ],
                    Expanded(
                      child: Text(
                        room.lastMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: previewColor,
                          fontWeight: unread ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatRelative(room.updatedAt),
                style: TextStyle(
                  fontSize: 11,
                  color: unread ? c.accent : c.textHint,
                  fontWeight: unread ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              const SizedBox(height: 8),
              AnimatedSwitcher(
                duration: Motion.base,
                transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                child: unread
                    ? Container(
                        key: ValueKey(room.unreadCount),
                        constraints: const BoxConstraints(minWidth: 20),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: c.danger,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          room.unreadCount > 99 ? '99+' : '${room.unreadCount}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      )
                    : const SizedBox(key: ValueKey('none'), height: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
