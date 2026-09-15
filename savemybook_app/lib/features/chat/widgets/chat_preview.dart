import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../i18n/strings.dart';
import '../../../models/chat.dart';
import '../../../services/api_service.dart';
import '../../../utils/api_helpers.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/motion.dart';
import '../../../widgets/app_tiles.dart';
import '../groups/group_avatar.dart';
import '../media/chat_network_image.dart';
import 'chat_format.dart';

enum ChatPreviewAction { open, markRead, toggleMute, togglePin, delete }

Future<ChatPreviewAction?> showChatPreview(
  BuildContext context, {
  required ChatRoom room,
  required bool muted,
}) {
  HapticFeedback.mediumImpact();
  return Navigator.of(context).push<ChatPreviewAction>(
    PageRouteBuilder(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.25),
      transitionDuration: Motion.base,
      reverseTransitionDuration: Motion.micro,
      pageBuilder: (_, _, _) => Material(
        type: MaterialType.transparency,
        child: _ChatPreview(room: room, muted: muted),
      ),
      transitionsBuilder: (_, animation, _, child) {
        final curved = CurvedAnimation(parent: animation, curve: Motion.emphasized, reverseCurve: Motion.exitCurve);
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: Tween(begin: 0.94, end: 1.0).animate(curved), child: child),
        );
      },
    ),
  );
}

class _ChatPreview extends StatefulWidget {
  final ChatRoom room;
  final bool muted;

  const _ChatPreview({required this.room, required this.muted});

  @override
  State<_ChatPreview> createState() => _ChatPreviewState();
}

class _ChatPreviewState extends State<_ChatPreview> {
  List<ChatMessage>? _messages;
  bool _failed = false;

  int get _myId => ApiService.currentUser?.userId ?? 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await ApiService().fetchChatMessages(widget.room.roomId, limit: 30, markRead: false);
    if (!mounted) return;
    setState(() {
      _failed = !result.ok;
      _messages = result.messages;
    });
  }

  void _close([ChatPreviewAction? action]) => Navigator.of(context).pop(action);

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final size = MediaQuery.of(context).size;
    final cardHeight = (size.height * 0.52).clamp(260.0, 480.0);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _close,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GestureDetector(
                      onTap: () => _close(ChatPreviewAction.open),
                      child: Container(
                        height: cardHeight,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: c.scaffold,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 30, offset: const Offset(0, 12))],
                        ),
                        child: Column(
                          children: [
                            _header(c),
                            Divider(height: 1, color: c.divider),
                            Expanded(child: _body(c)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _actions(c),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(AppColors c) {
    final room = widget.room;
    return Container(
      color: c.card,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          ChatRoomAvatar(imageUrl: room.avatarUrl, isGroup: room.isGroup, radius: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  room.isGroup ? '${room.title} (${room.memberCount})' : room.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c.textPrimary),
                ),
                if (room.updatedAt != null)
                  Text(formatRelative(room.updatedAt), style: TextStyle(fontSize: 11.5, color: c.textSecondary)),
              ],
            ),
          ),
          if (room.pinned) ...[
            Transform.rotate(angle: 0.6, child: Icon(Icons.push_pin_rounded, size: 15, color: c.accent)),
            const SizedBox(width: 6),
          ],
          if (widget.muted) Icon(Icons.notifications_off_rounded, size: 16, color: c.textHint),
        ],
      ),
    );
  }

  Widget _body(AppColors c) {
    final messages = _messages;
    if (messages == null) {
      return Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: c.accent)));
    }
    if (_failed || messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _failed ? S.somethingWentWrongPleaseTryAgain : S.noMessagesYet,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: c.textSecondary),
          ),
        ),
      );
    }
    final ordered = messages.reversed.toList();
    return IgnorePointer(
      child: ListView.builder(
        reverse: true,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        itemCount: ordered.length,
        itemBuilder: (_, i) => _bubble(c, ordered[i]),
      ),
    );
  }

  Widget _bubble(AppColors c, ChatMessage m) {
    final mine = m.senderId == _myId;
    if (m.isRecalled || m.kind == 'notice' || m.kind == 'book' || m.kind == 'reservation' || m.kind == 'transfer') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: c.categoryChip, borderRadius: BorderRadius.circular(12)),
            child: Text(
              m.preview,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, color: c.textSecondary),
            ),
          ),
        ),
      );
    }

    final bubbleColor = mine ? chatMineBubble(c) : c.card;
    final textColor = mine ? Colors.white : c.textPrimary;
    final image = m.imageUrls.firstOrNull;
    final sender = widget.room.isGroup && !mine && m.senderName.isNotEmpty ? m.senderName : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (widget.room.isGroup && !mine) ...[
            UserAvatar(imageUrl: m.senderAvatarUrl, radius: 12),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (sender != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 2),
                    child: Text(
                      sender,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: c.textSecondary),
                    ),
                  ),
                ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: image != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Stack(
                        children: [
                          ChatNetworkImage(url: image, width: 140, height: 104),
                          if (m.kind == 'album')
                            Positioned(
                              right: 6,
                              bottom: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${m.imageUrls.length}',
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                        ],
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: bubbleColor,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: Radius.circular(mine ? 16 : 4),
                          bottomRight: Radius.circular(mine ? 4 : 16),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (m.kind == 'voice') ...[
                            Icon(Icons.graphic_eq_rounded, size: 16, color: textColor),
                            const SizedBox(width: 6),
                          ],
                          Flexible(
                            child: Text(
                              m.kind == 'voice' ? '${m.voice?.durationSeconds ?? 0}″' : m.text,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13.5, height: 1.4, color: textColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actions(AppColors c) {
    final room = widget.room;
    final items = <(IconData, String, ChatPreviewAction, bool)>[
      (Icons.chat_bubble_outline_rounded, S.openChat, ChatPreviewAction.open, false),
      if (room.unreadCount > 0) (Icons.mark_chat_read_outlined, S.markAsRead, ChatPreviewAction.markRead, false),
      (
        room.pinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
        room.pinned ? S.unpin : S.pin,
        ChatPreviewAction.togglePin,
        false,
      ),
      (
        widget.muted ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
        widget.muted ? S.unmute : S.mute,
        ChatPreviewAction.toggleMute,
        false,
      ),
      room.isGroup
          ? (Icons.logout_rounded, S.leaveGroup, ChatPreviewAction.delete, true)
          : (Icons.delete_outline_rounded, S.deleteChat, ChatPreviewAction.delete, true),
    ];

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, item) in items.indexed) ...[
              if (i > 0) Divider(height: 1, color: c.divider),
              InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  _close(item.$3);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.$2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: item.$4 ? c.danger : c.textPrimary),
                        ),
                      ),
                      Icon(item.$1, size: 20, color: item.$4 ? c.danger : c.textSecondary),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
