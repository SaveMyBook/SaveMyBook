import 'package:flutter/foundation.dart';

import '../../../models/chat.dart';
import '../../../services/api_service.dart';

enum ChatSendState { sending, failed }

const int kChatAlbumMax = 20;
const int kChatImageMaxBytes = 10 * 1024 * 1024;

class ChatUploadSlot {
  final String localPath;
  String? url;
  final ValueNotifier<double> progress = ValueNotifier(0);
  final ValueNotifier<bool> failed = ValueNotifier(false);

  ChatUploadSlot(this.localPath);

  bool get uploaded => url != null;
}

class ChatPendingMessage {
  final String key;
  final String kind;
  final String text;
  final String? localPath;
  final int seconds;
  final ChatReply? replyTo;
  final List<ChatMention> mentions;
  final List<ChatUploadSlot> slots;
  final DateTime createdAt = DateTime.now();
  String? uploadedUrl;
  ChatSendState state = ChatSendState.sending;

  ChatPendingMessage({
    required this.key,
    required this.kind,
    this.text = '',
    this.localPath,
    this.seconds = 0,
    this.replyTo,
    this.mentions = const [],
    this.slots = const [],
  });

  factory ChatPendingMessage.images({required String key, required List<String> paths, ChatReply? replyTo}) =>
      ChatPendingMessage(
        key: key,
        kind: paths.length == 1 ? 'image' : 'album',
        localPath: paths.first,
        replyTo: replyTo,
        slots: [for (final path in paths) ChatUploadSlot(path)],
      );
}

({List<List<String>> groups, int skipped}) groupImagesForSend(
  List<({String path, int bytes})> files, {
  int maxBytes = kChatImageMaxBytes,
  int maxPerAlbum = kChatAlbumMax,
}) {
  final accepted = [for (final f in files) if (f.bytes != 0 && f.bytes <= maxBytes) f.path];
  final groups = <List<String>>[
    for (var i = 0; i < accepted.length; i += maxPerAlbum)
      accepted.sublist(i, i + maxPerAlbum > accepted.length ? accepted.length : i + maxPerAlbum),
  ];
  return (groups: groups, skipped: files.length - accepted.length);
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

  List<ChatMention> get mentions => message?.mentions ?? pending?.mentions ?? const [];

  bool get isCentered => const {'book', 'recalled', 'notice'}.contains(kind);
}
