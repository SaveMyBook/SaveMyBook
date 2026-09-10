import 'dart:async';

import 'package:flutter/material.dart';
import '../models/chat.dart';
import '../services/api_service.dart';
import '../utils/api_helpers.dart';
import '../utils/app_colors.dart';
import '../widgets/app_tiles.dart';
import '../widgets/animations.dart';
import '../widgets/app_header.dart';
import '../widgets/state_views.dart';

class ChatRoomScreen extends StatefulWidget {
  final int roomId;
  final String partnerName;

  const ChatRoomScreen({super.key, required this.roomId, this.partnerName = ''});

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ChatMessage> _messages = [];
  ChatPartner? _partner;
  Timer? _pollTimer;
  bool _isLoading = true;
  bool _isSending = false;
  bool _isPolling = false;

  int get _myId => ApiService.currentUser?.userId ?? 0;

  @override
  void initState() {
    super.initState();
    _load();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    // 進聊天室等於已讀，離開時把 header 的紅點數字補正。
    _api.fetchUnreadChatCount();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _poll() async {
    if (_isPolling || _isSending || !mounted) return;
    _isPolling = true;

    try {
      final result = await _api.fetchChatMessages(widget.roomId);
      if (!mounted) return;

      final latestId = _messages.isEmpty ? 0 : _messages.last.messageId;
      final incomingId = result.messages.isEmpty ? 0 : result.messages.last.messageId;
      if (incomingId == latestId && result.messages.length == _messages.length) return;

      final wasAtBottom = !_scrollController.hasClients ||
          _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 80;

      setState(() {
        _messages = result.messages;
        _partner = result.partner;
      });

      if (wasAtBottom) _scrollToBottom();
    } finally {
      _isPolling = false;
    }
  }

  Future<void> _load() async {
    final result = await _api.fetchChatMessages(widget.roomId);
    if (!mounted) return;
    setState(() {
      _messages = result.messages;
      _partner = result.partner;
      _isLoading = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    if (text.length > 500) {
      showAppSnackBar(context, '訊息長度不可超過 500 字', isError: true);
      return;
    }

    setState(() => _isSending = true);
    final message = await _api.sendChatMessage(widget.roomId, text);
    if (!mounted) return;

    setState(() {
      _isSending = false;
      if (message != null) {
        _messages = [..._messages, message];
        _controller.clear();
      }
    });

    if (message == null) {
      showAppSnackBar(context, '訊息傳送失敗', isError: true);
    } else {
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final title = _partner?.nickname.isNotEmpty == true ? _partner!.nickname : widget.partnerName;

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          AppHeader(
            title: title.isEmpty ? '聊天' : title,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: UserAvatar(
                  imageUrl: _partner?.avatarUrl,
                  radius: 17,
                  background: Colors.white24,
                  enablePreview: true,
                  previewTitle: title,
                ),
              ),
            ],
          ),
          Expanded(
            child: SwitchIn(child: _isLoading
                ? const LoadingView()
                : _messages.isEmpty
                    ? const EmptyView(icon: Icons.chat_outlined, message: '開始你們的第一則訊息吧')
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) => FadeSlideIn(
                          index: i,
                          offsetY: 10,
                          stagger: const Duration(milliseconds: 20),
                          child: _buildBubble(i, c),
                        ),
                      )),
          ),
          _buildInputBar(c),
        ],
      ),
    );
  }

  Widget _buildBubble(int index, AppColors c) {
    final message = _messages[index];
    final isMine = message.senderId == _myId;

    // 連續同一人的訊息只在最後一則顯示頭像與時間，中間的收緊間距，
    // 不然每一行都掛一顆頭像、每一行都有時間戳，整個版面會很雜。
    final next = index + 1 < _messages.length ? _messages[index + 1] : null;
    final isGroupEnd = next == null || next.senderId != message.senderId;
    final previous = index > 0 ? _messages[index - 1] : null;
    final isGroupStart = previous == null || previous.senderId != message.senderId;

    const avatarSize = 32.0;

    return Padding(
      padding: EdgeInsets.only(top: isGroupStart ? 10 : 2, bottom: isGroupEnd ? 4 : 0),
      child: Column(
        crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMine)
                SizedBox(
                  width: avatarSize,
                  child: isGroupEnd
                      ? UserAvatar(
                          imageUrl: _partner?.avatarUrl,
                          radius: avatarSize / 2,
                          enablePreview: true,
                          previewTitle: _partner?.nickname,
                        )
                      : null,
                ),
              if (!isMine) const SizedBox(width: 8),
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.68,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isMine ? c.accent : c.card,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(isMine || isGroupStart ? 16 : 6),
                        topRight: Radius.circular(!isMine || isGroupStart ? 16 : 6),
                        bottomLeft: Radius.circular(isMine || !isGroupEnd ? 16 : 6),
                        bottomRight: Radius.circular(!isMine || !isGroupEnd ? 16 : 6),
                      ),
                    ),
                    child: Text(
                      message.content,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: isMine ? Colors.white : c.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (isGroupEnd)
            Padding(
              padding: EdgeInsets.only(
                left: isMine ? 0 : avatarSize + 8,
                right: 2,
                top: 4,
              ),
              child: Text(
                formatRelative(message.createdAt),
                style: TextStyle(fontSize: 10, color: c.textHint),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInputBar(AppColors c) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: c.card,
        border: Border(top: BorderSide(color: c.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              style: TextStyle(color: c.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: '輸入訊息…',
                hintStyle: TextStyle(color: c.textHint, fontSize: 14),
                filled: true,
                fillColor: c.inputFill,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _send,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
              child: _isSending
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
