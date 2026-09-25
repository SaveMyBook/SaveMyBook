import 'dart:convert';

import '../utils/api_helpers.dart';
import '../i18n/strings.dart';

class ChatPartner {
  final int userId;
  final String nickname;
  final String? avatarUrl;
  final String? alias;

  ChatPartner({required this.userId, required this.nickname, this.avatarUrl, this.alias});

  String get displayName => alias != null && alias!.isNotEmpty ? alias! : nickname;

  ChatPartner copyWith({String? alias, bool clearAlias = false}) => ChatPartner(
        userId: userId,
        nickname: nickname,
        avatarUrl: avatarUrl,
        alias: clearAlias ? null : (alias ?? this.alias),
      );

  factory ChatPartner.fromJson(Map<String, dynamic>? json) {
    final alias = json?['alias'] as String?;
    return ChatPartner(
      userId: parseInt(json?['user_id']),
      nickname: json?['nickname'] as String? ?? S.user,
      avatarUrl: resolveAssetUrl(json?['avatar_url']),
      alias: alias == null || alias.isEmpty ? null : alias,
    );
  }
}

class ChatMember {
  final int userId;
  final String nickname;
  final String? avatarUrl;
  final String? alias;
  final String role;
  final DateTime? joinedAt;

  const ChatMember({
    required this.userId,
    required this.nickname,
    this.avatarUrl,
    this.alias,
    this.role = 'member',
    this.joinedAt,
  });

  bool get isOwner => role == 'owner';

  String get displayName => alias != null && alias!.isNotEmpty ? alias! : nickname;

  ChatMember copyWith({String? role}) => ChatMember(
        userId: userId,
        nickname: nickname,
        avatarUrl: avatarUrl,
        alias: alias,
        role: role ?? this.role,
        joinedAt: joinedAt,
      );

  factory ChatMember.fromJson(Map<String, dynamic> json) {
    final alias = json['alias'] as String?;
    return ChatMember(
      userId: parseInt(json['user_id']),
      nickname: json['nickname'] as String? ?? S.user,
      avatarUrl: resolveAssetUrl(json['avatar_url']),
      alias: alias == null || alias.isEmpty ? null : alias,
      role: json['role'] as String? ?? 'member',
      joinedAt: parseDate(json['joined_at']),
    );
  }
}

class ChatRoomInfo {
  final int roomId;
  final String type;
  final String name;
  final String? avatarUrl;
  final int createdBy;
  final String? myRole;
  final List<ChatMember> members;
  final ChatPartner? partner;
  final bool muted;
  final bool pinned;
  final bool blocked;

  const ChatRoomInfo({
    required this.roomId,
    required this.type,
    required this.name,
    this.avatarUrl,
    this.createdBy = 0,
    this.myRole,
    this.members = const [],
    this.partner,
    this.muted = false,
    this.pinned = false,
    this.blocked = false,
  });

  bool get isGroup => type == 'group';

  bool get isOwner => myRole == 'owner';

  factory ChatRoomInfo.fromJson(Map<String, dynamic> json) => ChatRoomInfo(
        roomId: parseInt(json['room_id']),
        type: json['type'] as String? ?? 'direct',
        name: json['name'] as String? ?? '',
        avatarUrl: resolveAssetUrl(json['avatar_url']),
        createdBy: parseInt(json['created_by']),
        myRole: json['my_role'] as String?,
        members: [
          for (final m in (json['members'] as List? ?? const []))
            if (m is Map) ChatMember.fromJson(Map<String, dynamic>.from(m)),
        ],
        partner: json['partner'] is Map ? ChatPartner.fromJson(Map<String, dynamic>.from(json['partner'])) : null,
        muted: json['muted'] == true,
        pinned: json['pinned'] == true,
        blocked: json['blocked'] == true,
      );
}

class ChatTransfer {
  final int transferId;
  final String transferNo;
  final String kind;
  final int roomId;
  final int messageId;
  final int fromUserId;
  final int toUserId;
  final double amount;
  final String? note;
  final String status;
  final DateTime? createdAt;
  final DateTime? respondedAt;
  final DateTime? expiresAt;

  const ChatTransfer({
    required this.transferId,
    this.transferNo = '',
    required this.kind,
    this.roomId = 0,
    this.messageId = 0,
    required this.fromUserId,
    required this.toUserId,
    required this.amount,
    this.note,
    required this.status,
    this.createdAt,
    this.respondedAt,
    this.expiresAt,
  });

  bool get isRequest => kind == 'request';

  bool get isPending => status == 'pending' && !(expiresAt?.isBefore(DateTime.now()) ?? false);

  String get effectiveStatus => status == 'pending' && !isPending ? 'expired' : status;

  factory ChatTransfer.fromJson(Map<String, dynamic> json) {
    final note = json['note'] as String?;
    return ChatTransfer(
      transferId: parseInt(json['transfer_id']),
      transferNo: json['transfer_no'] as String? ?? '',
      kind: json['kind'] as String? ?? 'transfer',
      roomId: parseInt(json['room_id']),
      messageId: parseInt(json['message_id']),
      fromUserId: parseInt(json['from_user_id']),
      toUserId: parseInt(json['to_user_id']),
      amount: parseDouble(json['amount']),
      note: note == null || note.trim().isEmpty ? null : note,
      status: json['status'] as String? ?? 'pending',
      createdAt: parseDate(json['created_at']),
      respondedAt: parseDate(json['responded_at']),
      expiresAt: parseDate(json['expires_at']),
    );
  }
}

class ChatEdit {
  final int messageId;
  final String body;
  final DateTime? editedAt;
  final List<ChatMention>? mentions;

  const ChatEdit({required this.messageId, required this.body, this.editedAt, this.mentions});
}

class ChatMention {
  static const everyone = 0;

  final int userId;
  final int start;
  final int length;

  const ChatMention({required this.userId, required this.start, required this.length});

  int get end => start + length;

  bool get isEveryone => userId == everyone;

  ChatMention shift(int delta) => ChatMention(userId: userId, start: start + delta, length: length);

  Map<String, dynamic> toJson() => {'user_id': userId, 'start': start, 'length': length};

  static ChatMention? tryParse(Object? json) {
    if (json is! Map) return null;
    final start = int.tryParse('${json['start']}');
    final length = int.tryParse('${json['length']}');
    final userId = int.tryParse('${json['user_id']}');
    if (start == null || length == null || userId == null || start < 0 || length <= 0) return null;
    return ChatMention(userId: userId, start: start, length: length);
  }

  static List<ChatMention> listFrom(Object? raw) {
    if (raw is! List) return const [];
    final list = [for (final item in raw) ?tryParse(item)]..sort((a, b) => a.start.compareTo(b.start));
    return list;
  }

  static List<ChatMention> validFor(String text, List<ChatMention> mentions) {
    final result = <ChatMention>[];
    var cursor = 0;
    for (final m in [...mentions]..sort((a, b) => a.start.compareTo(b.start))) {
      if (m.start < cursor || m.end > text.length || text.codeUnitAt(m.start) != 0x40) continue;
      result.add(m);
      cursor = m.end;
    }
    return result;
  }

  @override
  bool operator ==(Object other) =>
      other is ChatMention && other.userId == userId && other.start == start && other.length == length;

  @override
  int get hashCode => Object.hash(userId, start, length);

  @override
  String toString() => 'ChatMention($userId, $start, $length)';
}

class ChatRoom {
  final int roomId;
  final String type;
  final String title;
  final String? avatarUrl;
  final ChatPartner partner;
  final int memberCount;
  final String lastMessage;
  final String lastKind;
  final int lastSenderId;
  final String lastSenderName;
  final bool lastIsRead;
  final int unreadCount;
  final bool mentionUnread;
  final bool muted;
  final bool blocked;
  final bool pinned;
  final DateTime? pinnedAt;
  final DateTime? updatedAt;

  ChatRoom({
    required this.roomId,
    this.type = 'direct',
    String? title,
    String? avatarUrl,
    required this.partner,
    this.memberCount = 2,
    required this.lastMessage,
    this.lastKind = 'text',
    this.lastSenderId = 0,
    this.lastSenderName = '',
    this.lastIsRead = false,
    required this.unreadCount,
    this.mentionUnread = false,
    this.muted = false,
    this.blocked = false,
    this.pinned = false,
    this.pinnedAt,
    this.updatedAt,
  })  : title = title == null || title.isEmpty ? partner.displayName : title,
        avatarUrl = avatarUrl ?? (type == 'group' ? null : partner.avatarUrl);

  bool get isGroup => type == 'group';

  ChatRoom copyWith({bool? muted, bool? blocked, bool? pinned, DateTime? pinnedAt, String? title, ChatPartner? partner}) =>
      ChatRoom(
        roomId: roomId,
        type: type,
        title: title ?? this.title,
        avatarUrl: avatarUrl,
        partner: partner ?? this.partner,
        memberCount: memberCount,
        lastMessage: lastMessage,
        lastKind: lastKind,
        lastSenderId: lastSenderId,
        lastSenderName: lastSenderName,
        lastIsRead: lastIsRead,
        unreadCount: unreadCount,
        mentionUnread: mentionUnread,
        muted: muted ?? this.muted,
        blocked: blocked ?? this.blocked,
        pinned: pinned ?? this.pinned,
        pinnedAt: pinned == false ? null : (pinnedAt ?? this.pinnedAt),
        updatedAt: updatedAt,
      );

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    final last = json['last_message'] as Map<String, dynamic>?;
    final message = last == null ? null : ChatMessage.fromJson({...last, 'message_id': 0});
    final type = json['type'] as String? ?? 'direct';

    return ChatRoom(
      roomId: parseInt(json['room_id']),
      type: type,
      title: json['title'] as String?,
      avatarUrl: resolveAssetUrl(json['avatar_url']),
      partner: ChatPartner.fromJson(json['partner'] as Map<String, dynamic>?),
      memberCount: json['member_count'] == null ? 2 : parseInt(json['member_count']),
      lastMessage: message == null ? S.noMessagesYet : message.preview,
      lastKind: message?.kind ?? 'text',
      lastSenderId: parseInt(last?['sender_id']),
      lastSenderName: last?['sender_name'] as String? ?? '',
      lastIsRead: last?['is_read'] == true,
      unreadCount: parseInt(json['unread_count']),
      mentionUnread: json['mention_unread'] == true,
      muted: json['muted'] == true,
      blocked: json['blocked'] == true,
      pinned: json['pinned'] == true,
      pinnedAt: parseDate(json['pinned_at']),
      updatedAt: parseDate(json['updated_at']),
    );
  }
}

String chatAlbumPreview(int count) => S.photosP02(count);

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

class ChatReply {
  final int messageId;
  final int senderId;
  final String senderName;
  final String kind;
  final String preview;
  final String? imageUrl;

  const ChatReply({
    required this.messageId,
    required this.senderId,
    required this.senderName,
    required this.kind,
    required this.preview,
    this.imageUrl,
  });

  bool get isUnavailable => kind == 'recalled' || kind == 'deleted';

  factory ChatReply.fromJson(Map<String, dynamic> json) => ChatReply(
        messageId: parseInt(json['message_id']),
        senderId: parseInt(json['sender_id']),
        senderName: json['sender_nickname'] as String? ?? '',
        kind: json['kind'] as String? ?? 'text',
        preview: json['preview'] as String? ?? '',
        imageUrl: resolveAssetUrl(json['image_url']),
      );

  factory ChatReply.of(ChatMessage message, {required String senderName}) => ChatReply(
        messageId: message.messageId,
        senderId: message.senderId,
        senderName: senderName,
        kind: message.kind,
        preview: message.preview,
        imageUrl: message.imageUrls.firstOrNull,
      );
}

enum ChatRiskCategory { credential, scam, link, payment, offsite, contact }

class ChatRisk {
  final bool high;

  /// 依危險程度排序，第一個即為提醒文字採用的類別。
  final List<ChatRiskCategory> categories;

  const ChatRisk({required this.high, required this.categories});

  ChatRiskCategory get primary => categories.first;

  static ChatRisk? fromJson(Object? json) {
    if (json is! Map) return null;
    final names = json['categories'] is List ? (json['categories'] as List).map((e) => '$e').toSet() : const <String>{};
    final categories = [for (final c in ChatRiskCategory.values) if (names.contains(c.name)) c];
    if (categories.isEmpty) return null;
    return ChatRisk(high: json['level'] == 'high', categories: categories);
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
  final DateTime? editedAt;
  final ChatReply? replyTo;
  final String senderName;
  final String? senderAvatarUrl;
  final List<ChatMention> mentions;
  final ChatRisk? risk;

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
    this.editedAt,
    this.replyTo,
    this.senderName = '',
    this.senderAvatarUrl,
    this.mentions = const [],
    this.risk,
  }) : kind = kind ?? _legacyKind(messageType, content);

  static const albumPrefix = '[album]';

  static String _legacyKind(String type, String content) {
    if (type == 'image') return 'image';
    if (type != 'system') return 'text';
    if (content.startsWith(ChatBookCard.prefix)) return 'book';
    if (content.startsWith(albumPrefix)) return 'album';
    if (content.startsWith('[recalled]')) return 'recalled';
    return 'notice';
  }

  bool get isRecalled => kind == 'recalled';

  String get text => body ?? content;

  String? get imageUrl => kind == 'image' ? resolveAssetUrl(body ?? content) : null;

  bool get hasImages => kind == 'image' || kind == 'album';

  List<String> get imageUrls {
    if (kind == 'image') return [?imageUrl];
    if (kind != 'album') return const [];
    Object? raw = payload?['urls'];
    if (raw == null && content.startsWith(albumPrefix)) {
      try {
        final decoded = jsonDecode(content.substring(albumPrefix.length));
        if (decoded is Map) raw = decoded['urls'];
      } catch (_) {}
    }
    if (raw is! List) return const [];
    return [for (final url in raw) ?resolveAssetUrl(url)];
  }

  ChatBookCard? get bookCard {
    if (kind != 'book') return null;
    final data = payload;
    return data != null ? ChatBookCard.fromMap(data) : ChatBookCard.tryParse(content);
  }

  ChatVoice? get voice => kind == 'voice' && payload != null ? ChatVoice.fromMap(payload!) : null;

  int? get reservationId => kind == 'reservation' ? parseInt(payload?['reservation_id']) : null;

  int? get transferId => kind == 'transfer' ? parseInt(payload?['transfer_id']) : null;

  ChatTransfer? get transfer =>
      kind == 'transfer' && payload != null && payload!['status'] != null ? ChatTransfer.fromJson(payload!) : null;

  bool get isEdited => editedAt != null;

  String get preview {
    switch (kind) {
      case 'image':
        return S.photo;
      case 'album':
        return chatAlbumPreview(imageUrls.length);
      case 'voice':
        return S.voice;
      case 'book':
        return S.item2(bookCard?.title ?? '');
      case 'reservation':
        return S.reservation;
      case 'transfer':
        return payload?['kind'] == 'request' ? S.paymentRequest : S.transfer2;
      case 'recalled':
        return S.messageUnsent;
      default:
        return text;
    }
  }

  ChatMessage copyWith({
    bool? isRead,
    String? kind,
    String? body,
    Map<String, dynamic>? payload,
    DateTime? editedAt,
    List<ChatMention>? mentions,
  }) =>
      ChatMessage(
        messageId: messageId,
        senderId: senderId,
        content: body ?? content,
        messageType: messageType,
        kind: kind ?? this.kind,
        body: body ?? this.body,
        payload: payload ?? this.payload,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
        editedAt: editedAt ?? this.editedAt,
        replyTo: replyTo,
        senderName: senderName,
        senderAvatarUrl: senderAvatarUrl,
        mentions: mentions ?? this.mentions,
        risk: risk,
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
      editedAt: parseDate(json['edited_at']),
      replyTo: json['reply_to'] is Map ? ChatReply.fromJson(Map<String, dynamic>.from(json['reply_to'])) : null,
      senderName: json['users'] is Map ? json['users']['nickname'] as String? ?? '' : '',
      senderAvatarUrl: json['users'] is Map ? resolveAssetUrl(json['users']['avatar_url']) : null,
      mentions: ChatMention.listFrom(json['mentions']),
      risk: ChatRisk.fromJson(json['risk']),
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
  final Map<int, ChatTransfer> transfers;
  final Map<int, int> membersRead;
  final List<int> typingUserIds;
  final Map<int, String> aliases;
  final List<ChatEdit> edited;
  final String roomType;
  final String roomTitle;
  final String? roomAvatarUrl;
  final int memberCount;
  final bool muted;
  final bool blocked;
  final bool canSend;
  final ChatRisk? riskBanner;
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
    this.transfers = const {},
    this.membersRead = const {},
    this.typingUserIds = const [],
    this.aliases = const {},
    this.edited = const [],
    this.roomType = 'direct',
    this.roomTitle = '',
    this.roomAvatarUrl,
    this.memberCount = 2,
    this.muted = false,
    this.blocked = false,
    this.canSend = true,
    this.riskBanner,
    this.ok = true,
    this.error,
    this.code,
    this.status,
  });
}
