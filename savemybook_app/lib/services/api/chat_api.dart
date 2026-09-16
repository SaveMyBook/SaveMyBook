part of '../api_service.dart';

extension ChatApi on ApiService {
  Future<({LinkPreview? preview, bool settled})> fetchLinkPreview(String url) async {
    final res = await _send('GET', '/chat/link-preview', query: {'url': url});
    if (res == null || res['success'] != true) return (preview: null, settled: false);
    return (preview: LinkPreview.tryParse(res['data']), settled: true);
  }

  Future<bool> deleteChatRoom(int roomId) async {
    final res = await _send('DELETE', '/chat/rooms/$roomId');
    return res != null && res['success'] == true;
  }

  Future<String?> setChatRoomMuted(int roomId, bool muted) async {
    final res = await _send('PUT', '/chat/rooms/$roomId/mute', body: {'muted': muted});
    if (res != null && res['success'] == true) return null;
    return res?['message'] as String? ?? S.somethingWentWrongPleaseTryAgain;
  }

  Future<String?> setUserBlocked(int userId, bool blocked) async {
    final res = await _send(blocked ? 'PUT' : 'DELETE', '/chat/blocks/$userId');
    if (res != null && res['success'] == true) return null;
    return res?['message'] as String? ?? S.somethingWentWrongPleaseTryAgain;
  }

  Future<List<ChatPartner>?> fetchBlockedUsers() async {
    final res = await _send('GET', '/chat/blocks');
    if (res == null || res['success'] != true) return null;
    return _mapList(res, ChatPartner.fromJson);
  }

  Future<bool> markAllChatsRead() async {
    final res = await _send('PATCH', '/chat/read-all');
    final ok = res != null && res['success'] == true;
    if (ok) ApiService._setBadge(ApiService.unreadChatCount, 0);
    return ok;
  }

  Future<int> fetchUnreadChatCount() async {
    final res = await _send('GET', '/chat/unread-count');
    if (res == null || res['success'] != true) return 0;
    final count = int.tryParse('${res['data']?['unread_count']}') ?? 0;
    ApiService._setBadge(ApiService.unreadChatCount, count);
    return count;
  }

  Future<List<ChatRoom>> fetchChatRooms() async {
    final res = await _send('GET', '/chat/rooms');
    final rooms = _mapList(res, ChatRoom.fromJson);
    ApiService._setBadge(ApiService.unreadChatCount, rooms.fold(0, (sum, r) => sum + r.unreadCount));
    return rooms;
  }

  Future<int?> openChatRoom({required int userId, int? bookId}) async {
    final res = await _send('POST', '/chat/rooms', body: {'user_id': userId, 'book_id': bookId});
    if (res == null || res['success'] != true) return null;
    return int.tryParse('${res['data']?['room_id']}');
  }

  Future<ChatFetchResult> fetchChatMessages(int roomId, {int? afterId, int? beforeId, int limit = 50, bool markRead = true}) async {
    final res = await _send('GET', '/chat/rooms/$roomId/messages', query: {
      'limit': '$limit',
      if (!markRead) 'mark_read': 'false',
      if (afterId != null) 'after_id': '$afterId',
      if (beforeId != null) 'before_id': '$beforeId',
    });
    final messages = _mapList(res, ChatMessage.fromJson);
    final partner = ChatPartner.fromJson(
      res?['partner'] is Map ? Map<String, dynamic>.from(res!['partner']) : null,
    );
    final meta = res?['meta'] is Map ? Map<String, dynamic>.from(res!['meta']) : const <String, dynamic>{};
    final reservations = <int, ChatReservation>{};
    for (final item in (meta['reservations'] as List? ?? const [])) {
      if (item is! Map) continue;
      final reservation = ChatReservation.fromJson(Map<String, dynamic>.from(item));
      reservations[reservation.reservationId] = reservation;
    }
    final transfers = <int, ChatTransfer>{};
    for (final item in (meta['transfers'] as List? ?? const [])) {
      if (item is! Map) continue;
      final transfer = ChatTransfer.fromJson(Map<String, dynamic>.from(item));
      transfers[transfer.transferId] = transfer;
    }
    final membersRead = <int, int>{
      for (final item in (meta['members_read'] as List? ?? const []))
        if (item is Map) parseInt(item['user_id']): parseInt(item['last_read_message_id']),
    };
    final aliases = <int, String>{
      if (meta['aliases'] is Map)
        for (final entry in (meta['aliases'] as Map).entries)
          if ('${entry.value}'.isNotEmpty) parseInt(entry.key): '${entry.value}',
    };
    final edited = <ChatEdit>[
      for (final item in (meta['edited'] as List? ?? const []))
        if (item is Map)
          ChatEdit(
            messageId: parseInt(item['message_id']),
            body: item['body'] as String? ?? '',
            editedAt: parseDate(item['edited_at']),
            mentions: item.containsKey('mentions') ? ChatMention.listFrom(item['mentions']) : null,
          ),
    ];
    final room = meta['room'] is Map ? Map<String, dynamic>.from(meta['room']) : const <String, dynamic>{};
    return ChatFetchResult(
      messages: messages,
      partner: partner,
      readUpto: parseInt(meta['read_upto']),
      partnerTyping: meta['partner_typing'] == true,
      recalledIds: (meta['recalled_ids'] as List? ?? const []).map(parseInt).toList(),
      hasMore: meta['has_more'] == true,
      reservations: reservations,
      transfers: transfers,
      membersRead: membersRead,
      typingUserIds: (meta['typing_user_ids'] as List? ?? const []).map(parseInt).toList(),
      aliases: aliases,
      edited: edited,
      roomType: room['type'] as String? ?? 'direct',
      roomTitle: room['title'] as String? ?? '',
      roomAvatarUrl: resolveAssetUrl(room['avatar_url']),
      memberCount: room['member_count'] == null ? 2 : parseInt(room['member_count']),
      muted: meta['muted'] == true,
      blocked: meta['blocked'] == true,
      canSend: meta['can_send'] != false,
      ok: res != null && res['success'] == true,
      error: res == null || res['success'] == true ? null : res['message'] as String?,
      code: res?['code'] as String?,
      status: res?['status'] is int ? res!['status'] as int : null,
    );
  }

  static const _chatV3Unavailable = 'CHAT_V3_UNAVAILABLE';

  Future<(ChatMessage?, String?)> sendChatMessage(
    int roomId,
    Object content, {
    String type = 'text',
    int? durationSeconds,
    int? replyToId,
    List<ChatMention> mentions = const [],
  }) async {
    Future<Map<String, dynamic>?> post(bool withMentions) => _send('POST', '/chat/rooms/$roomId/messages', body: {
          'content': content,
          'message_type': type,
          'duration': ?durationSeconds,
          'reply_to_id': ?replyToId,
          if (withMentions) 'mentions': [for (final m in mentions) m.toJson()],
        });
    var res = await post(mentions.isNotEmpty);
    // 伺服器尚未套用 010 遷移時會拒收提及；訊息本身仍須送出。
    if (mentions.isNotEmpty && res?['code'] == _chatV3Unavailable) res = await post(false);
    if (res == null || res['success'] != true || res['data'] is! Map) {
      return (null, res?['message'] as String? ?? S.messageCouldNotSent);
    }
    return (ChatMessage.fromJson(Map<String, dynamic>.from(res['data'])), null);
  }

  Future<(String?, String?)> uploadChatImage(String filePath, {ValueChanged<double>? onProgress}) async {
    final res = await _sendMultipart('/uploads/chat-image', [('file', filePath)], onProgress: onProgress);
    final url = res?['data'] is Map ? res!['data']['url'] as String? : null;
    return url == null ? (null, res?['message'] as String? ?? S.uploadFailedTryAgainLater) : (url, null);
  }

  Future<(String?, String?)> uploadVoice(String filePath) async {
    final res = await _sendMultipart('/uploads/voice', [('file', filePath)]);
    final url = res?['data'] is Map ? res!['data']['url'] as String? : null;
    return url == null ? (null, res?['message'] as String? ?? S.uploadFailedTryAgainLater) : (url, null);
  }

  Future<void> sendTyping(int roomId, {bool typing = true}) async {
    await _send('POST', '/chat/rooms/$roomId/typing', body: {'typing': typing});
  }

  Future<(ChatMessage?, String?)> recallChatMessage(int roomId, int messageId) async {
    final res = await _send('POST', '/chat/rooms/$roomId/messages/$messageId/recall');
    if (res == null || res['success'] != true || res['data'] is! Map) {
      return (null, res?['message'] as String? ?? S.actionFailed);
    }
    return (ChatMessage.fromJson(Map<String, dynamic>.from(res['data'])), null);
  }

  Future<(ChatReservation?, String?)> requestReservation(int roomId, {required int bookId, required int hours, String? message}) async {
    final res = await _send('POST', '/chat/rooms/$roomId/reservations', body: {
      'book_id': bookId,
      'hours': hours,
      if (message != null && message.trim().isNotEmpty) 'message': message.trim(),
    });
    if (res == null || res['success'] != true || res['data'] is! Map) {
      return (null, res?['message'] as String? ?? S.actionFailed);
    }
    return (ChatReservation.fromJson(Map<String, dynamic>.from(res['data'])), null);
  }

  Future<(ChatReservation?, String?)> respondReservation(int reservationId, String action) async {
    final res = await _send('PATCH', '/chat/reservations/$reservationId', body: {'action': action});
    if (res == null || res['success'] != true || res['data'] is! Map) {
      return (null, res?['message'] as String? ?? S.actionFailed);
    }
    return (ChatReservation.fromJson(Map<String, dynamic>.from(res['data'])), null);
  }

  String _errorOf(Map<String, dynamic>? res) => res?['message'] as String? ?? S.actionFailed;

  Future<(int?, String?)> createChatGroup({required String name, required List<int> memberIds, String? avatarUrl}) async {
    final res = await _send('POST', '/chat/groups', body: {
      'name': name,
      'member_ids': memberIds,
      'avatar_url': ?avatarUrl,
    });
    if (res == null || res['success'] != true) return (null, _errorOf(res));
    return (int.tryParse('${res['data']?['room_id']}'), null);
  }

  Future<(ChatRoomInfo?, String?)> fetchChatRoomInfo(int roomId) async {
    final res = await _send('GET', '/chat/rooms/$roomId');
    if (res == null || res['success'] != true || res['data'] is! Map) return (null, _errorOf(res));
    return (ChatRoomInfo.fromJson(Map<String, dynamic>.from(res['data'])), null);
  }

  Future<String?> updateChatGroup(int roomId, {String? name, String? avatarUrl}) async {
    final res = await _send('PATCH', '/chat/groups/$roomId', body: {'name': ?name, 'avatar_url': ?avatarUrl});
    return res != null && res['success'] == true ? null : _errorOf(res);
  }

  Future<String?> addChatGroupMembers(int roomId, List<int> userIds) async {
    final res = await _send('POST', '/chat/groups/$roomId/members', body: {'user_ids': userIds});
    return res != null && res['success'] == true ? null : _errorOf(res);
  }

  Future<(ChatRoomInfo?, String?)> setChatMemberRole(int roomId, int userId, {required bool admin}) async {
    final res = await _send('PATCH', '/chat/groups/$roomId/members/$userId', body: {'role': admin ? 'owner' : 'member'});
    if (res == null || res['success'] != true) return (null, _errorOf(res));
    final data = res['data'];
    if (data is! Map) return (null, null);
    return (ChatRoomInfo.fromJson(Map<String, dynamic>.from(data)), null);
  }

  Future<String?> removeChatGroupMember(int roomId, int userId) async {
    final res = await _send('DELETE', '/chat/groups/$roomId/members/$userId');
    return res != null && res['success'] == true ? null : _errorOf(res);
  }

  Future<String?> leaveChatGroup(int roomId) async {
    final res = await _send('POST', '/chat/groups/$roomId/leave');
    return res != null && res['success'] == true ? null : _errorOf(res);
  }

  Future<String?> setChatRoomPinned(int roomId, bool pinned) async {
    final res = await _send('PUT', '/chat/rooms/$roomId/pin', body: {'pinned': pinned});
    return res != null && res['success'] == true ? null : _errorOf(res);
  }

  Future<String?> setChatAlias(int userId, String? alias) async {
    final value = alias?.trim() ?? '';
    final res = await _send('PUT', '/chat/aliases/$userId', body: {'alias': value.isEmpty ? null : value});
    return res != null && res['success'] == true ? null : _errorOf(res);
  }

  Future<(ChatMessage?, String?)> editChatMessage(
    int roomId,
    int messageId,
    String content, {
    List<ChatMention> mentions = const [],
  }) async {
    Future<Map<String, dynamic>?> patch(bool withMentions) => _send('PATCH', '/chat/rooms/$roomId/messages/$messageId', body: {
          'content': content,
          if (withMentions) 'mentions': [for (final m in mentions) m.toJson()],
        });
    var res = await patch(true);
    if (res?['code'] == _chatV3Unavailable) res = await patch(false);
    if (res == null || res['success'] != true || res['data'] is! Map) return (null, _errorOf(res));
    return (ChatMessage.fromJson(Map<String, dynamic>.from(res['data'])), null);
  }

  (ChatTransfer?, ChatMessage?) _transferResult(Map<String, dynamic> data) => (
        data['transfer'] is Map ? ChatTransfer.fromJson(Map<String, dynamic>.from(data['transfer'])) : null,
        data['message'] is Map ? ChatMessage.fromJson(Map<String, dynamic>.from(data['message'])) : null,
      );

  Future<(ChatTransfer?, ChatMessage?, String?)> sendCoinTransfer(
    int roomId, {
    int? toUserId,
    required int amount,
    String? note,
  }) async {
    final res = await _send('POST', '/chat/rooms/$roomId/transfers', body: {
      'to_user_id': ?toUserId,
      'amount': amount,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
    if (res == null || res['success'] != true || res['data'] is! Map) return (null, null, _errorOf(res));
    final (transfer, message) = _transferResult(Map<String, dynamic>.from(res['data']));
    return (transfer, message, null);
  }

  Future<(ChatTransfer?, ChatMessage?, String?)> requestCoinTransfer(
    int roomId, {
    int? fromUserId,
    required int amount,
    String? note,
  }) async {
    final res = await _send('POST', '/chat/rooms/$roomId/transfer-requests', body: {
      'from_user_id': ?fromUserId,
      'amount': amount,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
    if (res == null || res['success'] != true || res['data'] is! Map) return (null, null, _errorOf(res));
    final (transfer, message) = _transferResult(Map<String, dynamic>.from(res['data']));
    return (transfer, message, null);
  }

  Future<(ChatTransfer?, String?)> _respondTransfer(int transferId, String action) async {
    final res = await _send('POST', '/chat/transfers/$transferId/$action');
    if (res == null || res['success'] != true || res['data'] is! Map) return (null, _errorOf(res));
    final (transfer, _) = _transferResult(Map<String, dynamic>.from(res['data']));
    return (transfer, transfer == null ? _errorOf(res) : null);
  }

  Future<(ChatTransfer?, String?)> payCoinTransfer(int transferId) => _respondTransfer(transferId, 'pay');

  Future<(ChatTransfer?, String?)> declineCoinTransfer(int transferId) => _respondTransfer(transferId, 'decline');

  Future<(ChatTransfer?, String?)> cancelCoinTransfer(int transferId) => _respondTransfer(transferId, 'cancel');
}
