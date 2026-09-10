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
  bool _isLoading = true;
  bool _isSending = false;

  int get _myId => ApiService.currentUser?.userId ?? 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
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
          AppHeader(title: title.isEmpty ? '聊天' : title, icon: Icons.person_outline_rounded),
          Expanded(
            child: SwitchIn(child: _isLoading
                ? const LoadingView()
                : _messages.isEmpty
                    ? const EmptyView(icon: Icons.chat_outlined, message: '開始你們的第一則訊息吧')
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) => FadeSlideIn(
                          index: i,
                          offsetY: 10,
                          stagger: const Duration(milliseconds: 20),
                          child: _buildBubble(_messages[i], c),
                        ),
                      )),
          ),
          _buildInputBar(c),
        ],
      ),
    );
  }

  Widget _buildBubble(ChatMessage message, AppColors c) {
    final isMine = message.senderId == _myId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[
            UserAvatar(imageUrl: _partner?.avatarUrl, radius: 16),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMine ? c.accent : c.card,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMine ? 16 : 4),
                      bottomRight: Radius.circular(isMine ? 4 : 16),
                    ),
                  ),
                  child: Text(
                    message.content,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: isMine ? Colors.white : c.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(formatRelative(message.createdAt), style: TextStyle(fontSize: 10, color: c.textHint)),
              ],
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
