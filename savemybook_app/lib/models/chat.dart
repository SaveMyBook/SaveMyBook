import '../utils/api_helpers.dart';

class ChatPartner {
  final int userId;
  final String nickname;
  final String? avatarUrl;

  ChatPartner({required this.userId, required this.nickname, this.avatarUrl});

  factory ChatPartner.fromJson(Map<String, dynamic>? json) {
    return ChatPartner(
      userId: parseInt(json?['user_id']),
      nickname: json?['nickname'] as String? ?? '使用者',
      avatarUrl: resolveAssetUrl(json?['avatar_url']),
    );
  }
}

class ChatRoom {
  final int roomId;
  final ChatPartner partner;
  final String? bookTitle;
  final String? bookImageUrl;
  final String lastMessage;
  final int unreadCount;
  final DateTime? updatedAt;

  ChatRoom({
    required this.roomId,
    required this.partner,
    required this.lastMessage,
    required this.unreadCount,
    this.bookTitle,
    this.bookImageUrl,
    this.updatedAt,
  });

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    final book = json['book'] as Map<String, dynamic>?;
    final last = json['last_message'] as Map<String, dynamic>?;
    final messageType = last?['message_type'] as String?;

    return ChatRoom(
      roomId: parseInt(json['room_id']),
      partner: ChatPartner.fromJson(json['partner'] as Map<String, dynamic>?),
      bookTitle: book?['title'] as String?,
      bookImageUrl: resolveAssetUrl(book?['image_url']),
      lastMessage: last == null
          ? '尚無訊息'
          : (messageType == 'image' ? '[圖片]' : (last['content'] as String? ?? '')),
      unreadCount: parseInt(json['unread_count']),
      updatedAt: parseDate(json['updated_at']),
    );
  }
}

class ChatMessage {
  final int messageId;
  final int senderId;
  final String content;
  final String messageType;
  final DateTime? createdAt;

  ChatMessage({
    required this.messageId,
    required this.senderId,
    required this.content,
    required this.messageType,
    this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      messageId: parseInt(json['message_id']),
      senderId: parseInt(json['sender_id']),
      content: json['content'] as String? ?? '',
      messageType: json['message_type'] as String? ?? 'text',
      createdAt: parseDate(json['created_at']),
    );
  }
}
