import 'dart:async';

import 'package:flutter/material.dart';
import '../models/chat.dart';
import '../services/api_service.dart';
import '../services/chat_prefs.dart';
import '../utils/api_helpers.dart';
import '../utils/app_colors.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/app_tiles.dart';
import '../widgets/animations.dart';
import '../widgets/app_header.dart';
import '../widgets/state_views.dart';
import '../widgets/swipe_action.dart';
import 'cart_screen.dart';
import 'chat_room_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final ApiService _api = ApiService();
  List<ChatRoom> _rooms = [];
  Timer? _pollTimer;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) => _load());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final rooms = await _api.fetchChatRooms();
    if (!mounted) return;
    setState(() {
      _rooms = rooms;
      _isLoading = false;
    });
  }

  Future<bool> _confirmDelete(ChatRoom room) {
    return showConfirmDialog(
      context,
      title: '刪除聊天室',
      message: '會一併刪除與 ${room.partner.nickname} 的所有訊息，雙方都看不到了。此動作無法復原。',
      confirmLabel: '刪除',
      isDestructive: true,
    );
  }

  Future<void> _deleteDismissed(ChatRoom room) async {
    setState(() => _rooms.removeWhere((r) => r.roomId == room.roomId));
    ChatPrefs.forget(room.roomId);

    final ok = await _api.deleteChatRoom(room.roomId);
    if (!mounted) return;

    if (ok) {
      showAppSnackBar(context, '已刪除聊天室');
      _api.fetchUnreadChatCount();
    } else {
      showAppSnackBar(context, '刪除失敗，已還原', isError: true);
      _load();
    }
  }

  Future<bool> _toggleMute(ChatRoom room) async {
    final muted = await ChatPrefs.toggle(room.roomId);
    if (!mounted) return true;
    setState(() {});
    showAppSnackBar(context, muted ? '已靜音這個聊天室' : '已取消靜音');
    return true;
  }

  Future<void> _markAllRead() async {
    final unread = _rooms.fold<int>(0, (sum, r) => sum + r.unreadCount);
    if (unread == 0) {
      showAppSnackBar(context, '沒有未讀訊息');
      return;
    }

    final confirmed = await showConfirmDialog(
      context,
      title: '全部標為已讀',
      message: '要把 $unread 則未讀訊息全部標為已讀嗎？此動作無法復原。',
      confirmLabel: '全部已讀',
    );
    if (!confirmed || !mounted) return;

    final ok = await runBusy(context, () => _api.markAllChatsRead());
    if (!mounted) return;

    if (ok == true) {
      showAppSnackBar(context, '已全部標為已讀');
      _load();
    } else {
      showAppSnackBar(context, '操作失敗，請稍後再試', isError: true);
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
            title: '聊天室',
            icon: Icons.chat_bubble_outline_rounded,
            actions: [
              HeaderIconButton(icon: Icons.done_all_rounded, onTap: _markAllRead),
              CartIconButton(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen())),
              ),
            ],
          ),
          Expanded(
            child: SwitchIn(child: _isLoading
                ? const LoadingView.list()
                : RefreshIndicator(
                    color: c.accent,
                    onRefresh: _load,
                    child: _rooms.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 80),
                              EmptyView(
                                icon: Icons.forum_outlined,
                                message: '還沒有任何對話\n到書籍頁按「聯絡賣家」就能開始聊天',
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _rooms.length,
                            itemBuilder: (_, i) => FadeSlideIn(index: i, child: _buildRoomTile(_rooms[i], c)),
                          ),
                  )),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomTile(ChatRoom room, AppColors c) {
    final muted = ChatPrefs.isMuted(room.roomId);

    return SwipeActionTile(
      itemKey: ValueKey('room_${room.roomId}'),
      startToEnd: SwipeAction(
        icon: muted ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
        label: muted ? '取消靜音' : '靜音',
        color: c.warning,
        onTrigger: () => _toggleMute(room),
      ),
      endToStart: SwipeAction(
        icon: Icons.delete_outline_rounded,
        label: '刪除',
        color: c.danger,
        dismisses: true,
        onTrigger: () => _confirmDelete(room),
        onDismissed: () => _deleteDismissed(room),
      ),
      child: _buildRoomCard(room, c, muted),
    );
  }

  Widget _buildRoomCard(ChatRoom room, AppColors c, bool muted) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatRoomScreen(roomId: room.roomId, partnerName: room.partner.nickname),
          ),
        );
        _load();
      },
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
                          fontWeight: FontWeight.bold,
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
                Text(
                  room.lastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: c.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatRelative(room.updatedAt), style: TextStyle(fontSize: 11, color: c.textHint)),
              const SizedBox(height: 8),
              if (room.unreadCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: c.danger,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    room.unreadCount > 99 ? '99+' : '${room.unreadCount}',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
