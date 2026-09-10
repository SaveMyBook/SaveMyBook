import 'dart:async';

import 'package:flutter/material.dart';
import '../models/chat.dart';
import '../services/api_service.dart';
import '../utils/api_helpers.dart';
import '../utils/app_colors.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/app_tiles.dart';
import '../widgets/animations.dart';
import '../widgets/app_header.dart';
import '../widgets/state_views.dart';
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
                ? const LoadingView()
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
          UserAvatar(imageUrl: room.partner.avatarUrl, radius: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  room.partner.nickname,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c.textPrimary),
                ),
                if (room.bookTitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '關於《${room.bookTitle}》',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: AppColors.primary),
                  ),
                ],
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
