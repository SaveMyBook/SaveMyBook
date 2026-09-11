import 'dart:convert';

import '../utils/api_helpers.dart';
import '../i18n/strings.dart';

class ChatPartner {
  final int userId;
  final String nickname;
  final String? avatarUrl;

  ChatPartner({required this.userId, required this.nickname, this.avatarUrl});

  factory ChatPartner.fromJson(Map<String, dynamic>? json) {
    return ChatPartner(
      userId: parseInt(json?['user_id']),
      nickname: json?['nickname'] as String? ?? S.user,
      avatarUrl: resolveAssetUrl(json?['avatar_url']),
    );
  }
}

class ChatRoom {
  final int roomId;
  final ChatPartner partner;
  final String lastMessage;
  final int unreadCount;
  final DateTime? updatedAt;

  ChatRoom({
    required this.roomId,
    required this.partner,
    required this.lastMessage,
    required this.unreadCount,
    this.updatedAt,
  });

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    final last = json['last_message'] as Map<String, dynamic>?;
    final messageType = last?['message_type'] as String?;
    final content = last?['content'] as String? ?? '';

    String preview() {
      if (last == null) return S.noMessagesYet;
      if (messageType == 'image') return S.photo;
      final card = ChatBookCard.tryParse(content);
      return card == null ? content : S.item2(card.title);
    }

    return ChatRoom(
      roomId: parseInt(json['room_id']),
      partner: ChatPartner.fromJson(json['partner'] as Map<String, dynamic>?),
      lastMessage: preview(),
      unreadCount: parseInt(json['unread_count']),
      updatedAt: parseDate(json['updated_at']),
    );
  }
}

/// 對話裡的商品卡片。後端用 system 訊息夾帶 JSON 送過來，
/// 前端解出來才畫成卡片，解不出來就當一般文字顯示。
class ChatBookCard {
  static const prefix = '[book]';

  final int bookId;
  final String title;
  final double price;
  final String? imageUrl;

  ChatBookCard({
    required this.bookId,
    required this.title,
    required this.price,
    this.imageUrl,
  });

  static ChatBookCard? tryParse(String content) {
    if (!content.startsWith(prefix)) return null;
    try {
      final json = jsonDecode(content.substring(prefix.length));
      if (json is! Map) return null;
      return ChatBookCard(
        bookId: parseInt(json['book_id']),
        title: json['title'] as String? ?? '',
        price: parseDouble(json['price']),
        imageUrl: resolveAssetUrl(json['image_url']),
      );
    } catch (_) {
      return null;
    }
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

  ChatBookCard? get bookCard => messageType == 'system' ? ChatBookCard.tryParse(content) : null;

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
