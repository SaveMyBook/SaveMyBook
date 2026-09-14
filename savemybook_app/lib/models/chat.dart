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
  final String lastKind;
  final int lastSenderId;
  final bool lastIsRead;
  final int unreadCount;
  final DateTime? updatedAt;

  ChatRoom({
    required this.roomId,
    required this.partner,
    required this.lastMessage,
    this.lastKind = 'text',
    this.lastSenderId = 0,
    this.lastIsRead = false,
    required this.unreadCount,
    this.updatedAt,
  });

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    final last = json['last_message'] as Map<String, dynamic>?;
    final message = last == null ? null : ChatMessage.fromJson({...last, 'message_id': 0});

    return ChatRoom(
      roomId: parseInt(json['room_id']),
      partner: ChatPartner.fromJson(json['partner'] as Map<String, dynamic>?),
      lastMessage: message == null ? S.noMessagesYet : message.preview,
      lastKind: message?.kind ?? 'text',
      lastSenderId: parseInt(last?['sender_id']),
      lastIsRead: last?['is_read'] == true,
      unreadCount: parseInt(json['unread_count']),
      updatedAt: parseDate(json['updated_at']),
    );
  }
}

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

  factory ChatBookCard.fromMap(Map json) => ChatBookCard(
        bookId: parseInt(json['book_id']),
        title: json['title'] as String? ?? '',
        price: parseDouble(json['price']),
        imageUrl: resolveAssetUrl(json['image_url']),
      );

  static ChatBookCard? tryParse(String content) {
    if (!content.startsWith(prefix)) return null;
    try {
      final json = jsonDecode(content.substring(prefix.length));
      return json is Map ? ChatBookCard.fromMap(json) : null;
    } catch (_) {
      return null;
    }
  }
}

class ChatVoice {
  final String url;
  final int durationSeconds;

  const ChatVoice({required this.url, required this.durationSeconds});

  factory ChatVoice.fromMap(Map json) => ChatVoice(
        url: resolveAssetUrl(json['url']) ?? '',
        durationSeconds: parseInt(json['duration']),
      );
}

class ChatReservation {
  final int reservationId;
  final int bookId;
  final String bookTitle;
  final double bookPrice;
  final String? bookImageUrl;
  final String bookStatus;
  final int buyerId;
  final int sellerId;
  final String status;
  final int hours;
  final String? message;
  final String? closedBy;
  final String? closedAction;
  final DateTime? pickupDeadline;
  final bool isHolding;
  final DateTime? createdAt;

  const ChatReservation({
    required this.reservationId,
    required this.bookId,
    required this.bookTitle,
    required this.bookPrice,
    this.bookImageUrl,
    required this.bookStatus,
    required this.buyerId,
    required this.sellerId,
    required this.status,
    required this.hours,
    this.message,
    this.closedBy,
    this.closedAction,
    this.pickupDeadline,
    required this.isHolding,
    this.createdAt,
  });

  bool get isPending => status == 'pending';
  bool get isConfirmed => status == 'confirmed' && isHolding;

  factory ChatReservation.fromJson(Map<String, dynamic> json) {
    final book = json['book'] is Map ? Map<String, dynamic>.from(json['book']) : const <String, dynamic>{};
    return ChatReservation(
      reservationId: parseInt(json['reservation_id']),
      bookId: parseInt(book['book_id']),
      bookTitle: book['title'] as String? ?? '',
      bookPrice: parseDouble(book['price']),
      bookImageUrl: resolveAssetUrl(book['image_url']),
      bookStatus: book['status'] as String? ?? '',
      buyerId: parseInt(json['buyer_id']),
      sellerId: parseInt(json['seller_id']),
      status: json['status'] as String? ?? 'pending',
      hours: parseInt(json['hours']),
      message: json['message'] as String?,
      closedBy: json['closed_by'] as String?,
      closedAction: json['closed_action'] as String?,
      pickupDeadline: parseDate(json['pickup_deadline'])?.toLocal(),
      isHolding: json['is_holding'] == true,
      createdAt: parseDate(json['created_at'])?.toLocal(),
    );
  }
}

class ChatMessage {
  final int messageId;
  final int senderId;
  final String content;
  final String messageType;
  final String kind;
  final String? body;
  final Map<String, dynamic>? payload;
  final bool isRead;
  final DateTime? createdAt;

  ChatMessage({
    required this.messageId,
    required this.senderId,
    required this.content,
    required this.messageType,
    String? kind,
    this.body,
    this.payload,
    this.isRead = false,
    this.createdAt,
  }) : kind = kind ?? _legacyKind(messageType, content);

  static String _legacyKind(String type, String content) {
    if (type == 'image') return 'image';
    if (type != 'system') return 'text';
    if (content.startsWith(ChatBookCard.prefix)) return 'book';
    if (content.startsWith('[recalled]')) return 'recalled';
    return 'notice';
  }

  bool get isRecalled => kind == 'recalled';

  String get text => body ?? content;

  String? get imageUrl => kind == 'image' ? resolveAssetUrl(body ?? content) : null;

  ChatBookCard? get bookCard {
    if (kind != 'book') return null;
    final data = payload;
    return data != null ? ChatBookCard.fromMap(data) : ChatBookCard.tryParse(content);
  }

  ChatVoice? get voice => kind == 'voice' && payload != null ? ChatVoice.fromMap(payload!) : null;

  int? get reservationId => kind == 'reservation' ? parseInt(payload?['reservation_id']) : null;

  String get preview {
    switch (kind) {
      case 'image':
        return S.photo;
      case 'voice':
        return S.voice;
      case 'book':
        return S.item2(bookCard?.title ?? '');
      case 'reservation':
        return S.reservation;
      case 'recalled':
        return S.messageUnsent;
      default:
        return text;
    }
  }

  ChatMessage copyWith({bool? isRead, String? kind, String? body, Map<String, dynamic>? payload}) => ChatMessage(
        messageId: messageId,
        senderId: senderId,
        content: content,
        messageType: messageType,
        kind: kind ?? this.kind,
        body: body ?? this.body,
        payload: payload ?? this.payload,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
      );

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'];
    return ChatMessage(
      messageId: parseInt(json['message_id']),
      senderId: parseInt(json['sender_id']),
      content: json['content'] as String? ?? '',
      messageType: json['message_type'] as String? ?? 'text',
      kind: json['kind'] as String?,
      body: json['body'] as String?,
      payload: payload is Map ? Map<String, dynamic>.from(payload) : null,
      isRead: json['is_read'] == true,
      createdAt: parseDate(json['created_at']),
    );
  }
}

class ChatFetchResult {
  final List<ChatMessage> messages;
  final ChatPartner partner;
  final int readUpto;
  final bool partnerTyping;
  final List<int> recalledIds;
  final bool hasMore;
  final Map<int, ChatReservation> reservations;
  final bool ok;
  final String? error;
  final String? code;
  final int? status;

  const ChatFetchResult({
    required this.messages,
    required this.partner,
    this.readUpto = 0,
    this.partnerTyping = false,
    this.recalledIds = const [],
    this.hasMore = false,
    this.reservations = const {},
    this.ok = true,
    this.error,
    this.code,
    this.status,
  });
}
