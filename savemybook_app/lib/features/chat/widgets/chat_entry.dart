import '../../../models/chat.dart';
import '../../../services/api_service.dart';

enum ChatSendState { sending, failed }

class ChatPendingMessage {
  final String key;
  final String kind;
  final String text;
  final String? localPath;
  final int seconds;
  final ChatReply? replyTo;
  final DateTime createdAt = DateTime.now();
  String? uploadedUrl;
  ChatSendState state = ChatSendState.sending;

  ChatPendingMessage({required this.key, required this.kind, this.text = '', this.localPath, this.seconds = 0, this.replyTo});
}

class ChatEntry {
  final String key;
  final ChatMessage? message;
  final ChatPendingMessage? pending;

  const ChatEntry.message(this.key, ChatMessage this.message) : pending = null;

  const ChatEntry.pending(ChatPendingMessage this.pending)
      : key = '',
        message = null;

  String get id => pending?.key ?? key;

  int get senderId => message?.senderId ?? (ApiService.currentUser?.userId ?? 0);

  DateTime? get createdAt => message?.createdAt ?? pending?.createdAt;

  String get kind => message?.kind ?? pending!.kind;

  ChatReply? get replyTo => message?.replyTo ?? pending?.replyTo;

  bool get isCentered => const {'book', 'recalled', 'notice'}.contains(kind);
}
