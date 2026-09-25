import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'widgets/chat_preview.dart';
import 'ai/ai_book_chat_screen.dart';
import '../account/ai_support_screen.dart' show AiAvatar;
import '../../models/ai.dart';
import '../../models/chat.dart';
import '../../services/ai_status.dart';
import '../../services/api_service.dart';
import '../../services/realtime_service.dart';
import '../../utils/api_helpers.dart';
import '../../utils/app_colors.dart';
import '../../utils/motion.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/app_forms.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_header.dart';
import '../../widgets/state_views.dart';
import '../../widgets/swipe_action.dart';
import 'chat_room_screen.dart';
import 'groups/create_group_screen.dart';
import 'groups/group_avatar.dart';
import '../../i18n/strings.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> with WidgetsBindingObserver {
  final ApiService _api = ApiService();
  final TextEditingController _search = TextEditingController();
  List<ChatRoom> _rooms = [];
  static const _pollInterval = Duration(seconds: 8);
  static const _fallbackInterval = Duration(seconds: 30);

  Timer? _pollTimer;
  Timer? _pushDebounce;
  StreamSubscription<int>? _roomChanges;
  DateTime _loadedAt = DateTime(0);
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
    _roomChanges = RealtimeService.instance.roomChanges.listen((_) => _onPushed());
    AiStatus.refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _pushDebounce?.cancel();
    _roomChanges?.cancel();
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
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      final pushed = RealtimeService.instance.connected.value;
      if (pushed && DateTime.now().difference(_loadedAt) < _fallbackInterval) return;
      if (mounted && ModalRoute.isCurrentOf(context) != false) _load();
    });
  }

  void _onPushed() {
    _pushDebounce?.cancel();
    _pushDebounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted && ModalRoute.isCurrentOf(context) != false) _load();
    });
  }

  Future<void> _load() async {
    if (_refreshing) return;
    _refreshing = true;
    _loadedAt = DateTime.now();
    try {
      final rooms = await _api.fetchChatRooms();
      if (!mounted) return;
      setState(() {
        _rooms = _ordered(rooms);
        _isLoading = false;
      });
    } finally {
      _refreshing = false;
    }
  }

  static List<ChatRoom> _ordered(List<ChatRoom> rooms) {
    final epoch = DateTime.fromMillisecondsSinceEpoch(0);
    final indexed = rooms.indexed.toList()
      ..sort((a, b) {
        final x = a.$2;
        final y = b.$2;
        if (x.pinned != y.pinned) return x.pinned ? -1 : 1;
        final byTime = x.pinned
            ? (y.pinnedAt ?? epoch).compareTo(x.pinnedAt ?? epoch)
            : (y.updatedAt ?? epoch).compareTo(x.updatedAt ?? epoch);
        return byTime != 0 ? byTime : a.$1.compareTo(b.$1);
      });
    return [for (final entry in indexed) entry.$2];
  }

  List<ChatRoom> get _visibleRooms {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _rooms;
    return _rooms
        .where((r) => r.title.toLowerCase().contains(q) || (!r.isGroup && r.partner.nickname.toLowerCase().contains(q)))
        .toList();
  }

  Future<bool> _confirmDelete(ChatRoom room) {
    if (room.isGroup) {
      final name = room.title;
      return showConfirmDialog(
        context,
        title: S.leaveGroup,
        message: S.leaveP0(name),
        confirmLabel: S.leave,
        isDestructive: true,
        icon: Icons.logout_rounded,
      );
    }
    return showConfirmDialog(
      context,
      title: S.deleteChat,
      message: S.allMessagesWithDeletedBothCannot(room.title),
      confirmLabel: S.actionDelete,
      isDestructive: true,
    );
  }

  Future<void> _deleteDismissed(ChatRoom room) async {
    setState(() {
      _rooms = _rooms.where((r) => r.roomId != room.roomId).toList();
      if (_selectedRoomId == room.roomId) _selectedRoomId = null;
    });

    final String? error;
    if (room.isGroup) {
      error = await _api.leaveChatGroup(room.roomId);
    } else {
      error = await _api.deleteChatRoom(room.roomId) ? null : S.couldNotDeleteRestored;
    }
    if (!mounted) return;

    if (error == null) {
      showAppSnackBar(context, room.isGroup ? S.leftGroup : S.chatDeleted);
      _api.fetchUnreadChatCount();
    } else {
      showAppSnackBar(context, error, isError: true);
      _load();
    }
  }

  Future<bool> _togglePin(ChatRoom room) async {
    final pinned = !room.pinned;
    _replaceRoom(room.roomId, (r) => r.copyWith(pinned: pinned, pinnedAt: pinned ? DateTime.now().toUtc() : null), reorder: true);
    final error = await _api.setChatRoomPinned(room.roomId, pinned);
    if (!mounted) return true;
    if (error != null) {
      _replaceRoom(room.roomId, (r) => r.copyWith(pinned: room.pinned, pinnedAt: room.pinnedAt), reorder: true);
      showAppSnackBar(context, error, isError: true);
    } else {
      HapticFeedback.selectionClick();
    }
    return true;
  }

  Future<void> _createGroup() async {
    final roomId = await Navigator.push<int>(context, MaterialPageRoute(builder: (_) => const CreateGroupScreen()));
    if (roomId == null || !mounted) return;
    await _load();
    if (!mounted) return;
    final room = _rooms.where((r) => r.roomId == roomId).firstOrNull;
    if (_split) {
      setState(() => _selectedRoomId = roomId);
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatRoomScreen(roomId: roomId, partnerName: room?.title ?? '')),
    );
    _load();
  }

  Future<bool> _toggleMute(ChatRoom room) async {
    final muted = !room.muted;
    _replaceRoom(room.roomId, (r) => r.copyWith(muted: muted));
    final error = await _api.setChatRoomMuted(room.roomId, muted);
    if (!mounted) return true;
    if (error != null) {
      _replaceRoom(room.roomId, (r) => r.copyWith(muted: !muted));
      showAppSnackBar(context, error, isError: true);
    } else {
      showAppSnackBar(context, muted ? S.chatMuted : S.chatUnmuted);
    }
    return true;
  }

  void _replaceRoom(int roomId, ChatRoom Function(ChatRoom) update, {bool reorder = false}) {
    setState(() {
      final next = [for (final r in _rooms) r.roomId == roomId ? update(r) : r];
      _rooms = reorder ? _ordered(next) : next;
    });
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

  Future<void> _preview(ChatRoom room) async {
    final action = await showChatPreview(context, room: room, muted: room.muted);
    if (!mounted || action == null) return;
    switch (action) {
      case ChatPreviewAction.open:
        await _openRoom(room);
      case ChatPreviewAction.markRead:
        await _api.fetchChatMessages(room.roomId, limit: 1);
        if (!mounted) return;
        await _load();
        _api.fetchUnreadChatCount();
      case ChatPreviewAction.toggleMute:
        await _toggleMute(room);
      case ChatPreviewAction.togglePin:
        await _togglePin(room);
      case ChatPreviewAction.delete:
        if (await _confirmDelete(room) && mounted) await _deleteDismissed(room);
    }
  }

  static const double _splitMinWidth = 840;
  static const double _listPaneWidth = 360;

  int? _selectedRoomId;
  bool _split = false;

  Future<void> _openRoom(ChatRoom room) async {
    if (_split) {
      if (_selectedRoomId != room.roomId) setState(() => _selectedRoomId = room.roomId);
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatRoomScreen(roomId: room.roomId, partnerName: room.title),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.scaffold,
      body: LayoutBuilder(
        builder: (context, constraints) {
          _split = constraints.maxWidth >= _splitMinWidth;
          if (!_split) return _buildListPane(c);

          final selected = _rooms.where((r) => r.roomId == _selectedRoomId).firstOrNull;
          return Row(
            children: [
              SizedBox(
                width: _listPaneWidth,
                child: MediaQuery.removePadding(context: context, removeRight: true, child: _buildListPane(c)),
              ),
              VerticalDivider(width: 1, thickness: 1, color: c.divider),
              Expanded(
                child: MediaQuery.removePadding(
                  context: context,
                  removeLeft: true,
                  child: selected == null
                      ? Center(
                          child: EmptyView(icon: Icons.forum_outlined, message: _rooms.isEmpty ? S.noConversationsYet : S.selectChat),
                        )
                      : ChatRoomScreen(
                          key: ValueKey('room_${selected.roomId}'),
                          roomId: selected.roomId,
                          partnerName: selected.title,
                          onClose: () {
                            setState(() => _selectedRoomId = null);
                            _load();
                          },
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildListPane(AppColors c) {
    return Column(
        children: [
          AppHeader(
            title: S.chats,
            icon: Icons.chat_bubble_outline_rounded,
            actions: [
              HeaderIconButton(icon: Icons.group_add_outlined, onTap: _createGroup),
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
    );
  }

  Widget _buildList(AppColors c) {
    return ValueListenableBuilder<AiStatusInfo>(
      valueListenable: AiStatus.listenable,
      builder: (context, status, _) {
        // AI 書籍顧問固定在最上方，搜尋時一併隱藏，避免與搜尋結果混淆。
        final leading = <Widget>[
          if (status.bookChat && _query.isEmpty) _buildAdvisorTile(c),
        ];

        if (_rooms.isEmpty) {
          return ListView(
            key: const ValueKey('empty'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              ...leading,
              const SizedBox(height: 64),
              EmptyView(icon: Icons.forum_outlined, message: S.noConversationsYet),
            ],
          );
        }

        final rooms = _visibleRooms;
        final showSearch = _rooms.length >= 4 || _query.isNotEmpty;
        final header = <Widget>[
          if (showSearch)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppSearchField(
                controller: _search,
                hint: S.searchChats,
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
          ...leading,
        ];

        return ListView.builder(
          key: const ValueKey('items'),
          physics: const AlwaysScrollableScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: rooms.length + header.length + (rooms.isEmpty ? 1 : 0),
          itemBuilder: (_, i) {
            if (i < header.length) return header[i];
            final index = i - header.length;
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
      },
    );
  }

  Widget _buildAdvisorTile(AppColors c) {
    return AppCard(
      key: const ValueKey('ai_book_advisor'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiBookChatScreen())),
      child: Row(
        children: [
          const AiAvatar(size: 52),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        S.aiBookAdvisor,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(color: c.accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                      child: Text('AI', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c.accent)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  S.tellMeWhatWantReadI,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: c.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded, size: 20, color: c.textHint),
        ],
      ),
    );
  }

  Widget _buildRoomTile(ChatRoom room, AppColors c) {
    final muted = room.muted;

    return SwipeActionTile(
      key: ValueKey('swipe_${room.roomId}'),
      itemKey: ValueKey('room_${room.roomId}'),
      startToEnd: SwipeAction(
        icon: room.pinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
        label: room.pinned ? S.unpin : S.pin,
        color: c.accent,
        onTrigger: () => _togglePin(room),
      ),
      startToEndExtra: [
        SwipeAction(
          icon: muted ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
          label: muted ? S.unmute : S.mute,
          color: c.warning,
          onTrigger: () => _toggleMute(room),
        ),
      ],
      endToStart: SwipeAction(
        icon: room.isGroup ? Icons.logout_rounded : Icons.delete_outline_rounded,
        label: room.isGroup ? S.leave : S.actionDelete,
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
      case 'album':
        return Icons.photo_library_outlined;
      case 'voice':
        return Icons.mic_none_rounded;
      case 'book':
        return Icons.menu_book_outlined;
      case 'reservation':
        return Icons.event_available_outlined;
      case 'transfer':
        return Icons.currency_exchange_rounded;
      case 'recalled':
        return Icons.undo_rounded;
      default:
        return null;
    }
  }

  Widget _buildRoomCard(ChatRoom room, AppColors c, bool muted) {
    final unread = room.unreadCount > 0;
    final mine = !room.isGroup && room.lastSenderId != 0 && room.lastSenderId == _myId;
    final sender = room.isGroup && room.lastKind != 'notice' && room.lastSenderName.isNotEmpty
        ? (room.lastSenderId == _myId ? S.you3 : room.lastSenderName)
        : null;
    final kindIcon = _kindIcon(room.lastKind);
    final mentioned = unread && room.mentionUnread;
    final previewColor = unread ? c.textPrimary : c.textSecondary;

    final selected = _split && room.roomId == _selectedRoomId;
    final card = AppCard(
      margin: selected ? EdgeInsets.zero : const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: () => _openRoom(room),
      onLongPress: () => _preview(room),
      child: Row(
        children: [
          ChatRoomAvatar(
            imageUrl: room.avatarUrl,
            isGroup: room.isGroup,
            radius: 26,
            enablePreview: true,
            previewTitle: room.title,
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
                        room.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: unread ? FontWeight.w800 : FontWeight.bold,
                          color: c.textPrimary,
                        ),
                      ),
                    ),
                    if (room.isGroup) ...[
                      const SizedBox(width: 4),
                      Text(
                        '(${room.memberCount})',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: c.textSecondary),
                      ),
                    ],
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
                    if (kindIcon != null && !mentioned) ...[
                      Icon(kindIcon, size: 15, color: previewColor),
                      const SizedBox(width: 3),
                    ],
                    Expanded(
                      child: Text.rich(
                        TextSpan(children: [
                          if (mentioned) ...[
                            TextSpan(
                              text: '${S.mentioned} ',
                              style: TextStyle(fontWeight: FontWeight.w700, color: c.accent),
                            ),
                            if (kindIcon != null)
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 3),
                                  child: Icon(kindIcon, size: 15, color: previewColor),
                                ),
                              ),
                          ],
                          TextSpan(text: sender == null ? room.lastMessage : '$sender：${room.lastMessage}'),
                        ]),
                        key: mentioned ? const ValueKey('mention_unread') : null,
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: Motion.base,
                    transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                    child: room.pinned
                        ? Padding(
                            key: const ValueKey('pinned'),
                            padding: const EdgeInsets.only(right: 4),
                            child: Transform.rotate(
                              angle: 0.6,
                              child: Icon(Icons.push_pin_rounded, size: 13, color: c.accent),
                            ),
                          )
                        : const SizedBox(key: ValueKey('unpinned')),
                  ),
                  Text(
                    formatRelative(room.updatedAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: unread ? c.accent : c.textHint,
                      fontWeight: unread ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
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
    if (!selected) return card;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.accent, width: 1.5),
      ),
      child: card,
    );
  }
}
