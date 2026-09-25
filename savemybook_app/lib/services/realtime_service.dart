import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'api_service.dart';

typedef ChatTypingEvent = ({int roomId, int userId, bool typing});

class RealtimeService {
  RealtimeService._();

  static final RealtimeService instance = RealtimeService._();

  static const _retryAfterRejected = Duration(seconds: 30);

  // 元件測試沒有伺服器可連，連線的重試計時器會讓測試因殘留計時器而失敗。
  static bool enabled = !Platform.environment.containsKey('FLUTTER_TEST');

  final ValueNotifier<bool> connected = ValueNotifier(false);
  final StreamController<int> _rooms = StreamController<int>.broadcast();
  final StreamController<ChatTypingEvent> _typing = StreamController<ChatTypingEvent>.broadcast();

  io.Socket? _socket;
  Timer? _retry;

  Stream<int> get roomChanges => _rooms.stream;

  Stream<ChatTypingEvent> get typingChanges => _typing.stream;

  void start() {
    if (!enabled || ApiService.authToken == null) return;
    final socket = _socket ??= _create();
    if (!socket.connected && !socket.active) socket.connect();
  }

  void stop() {
    _retry?.cancel();
    _retry = null;
    _socket?.dispose();
    _socket = null;
    connected.value = false;
  }

  bool sendTyping(int roomId, {bool typing = true}) {
    final socket = _socket;
    if (socket == null || !socket.connected) return false;
    socket.emit('typing', {'room_id': roomId, 'typing': typing});
    return true;
  }

  io.Socket _create() {
    final socket = io.io(
      Uri.parse(ApiService.baseUrl).origin,
      io.OptionBuilder()
          .setPath('/socket.io')
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableForceNew()
          .enableReconnection()
          .setReconnectionDelay(2000)
          .setReconnectionDelayMax(30000)
          // 每次重新連線都要讀最新的權杖，權杖更新後舊值會被伺服器拒絕。
          .setAuthFn((callback) => callback({'token': ApiService.authToken ?? ''}))
          .build(),
    );
    socket.onConnect((_) => connected.value = true);
    socket.onDisconnect((_) => connected.value = false);
    socket.onConnectError((_) {
      connected.value = false;
      // 被伺服器的驗證拒絕時不會自動重連，等 HTTP 端換好新權杖後再試。
      if (!socket.active) {
        _retry?.cancel();
        _retry = Timer(_retryAfterRejected, start);
      }
    });
    socket.on('chat:room', (data) {
      final roomId = _intOf(data, 'room_id');
      if (roomId != null) _rooms.add(roomId);
    });
    socket.on('chat:typing', (data) {
      final roomId = _intOf(data, 'room_id');
      final userId = _intOf(data, 'user_id');
      if (roomId == null || userId == null) return;
      _typing.add((roomId: roomId, userId: userId, typing: data is Map && data['typing'] != false));
    });
    return socket;
  }

  static int? _intOf(Object? data, String key) {
    if (data is! Map) return null;
    final value = data[key];
    return value is int ? value : int.tryParse('$value');
  }
}
