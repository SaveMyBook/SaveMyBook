import 'package:flutter/services.dart';
import 'api_service.dart';

class DeepLinkService {
  static const _channel = MethodChannel('savemybook/deeplink');

  static final _bookLink = RegExp(r'^savemybook://book/(\d+)/?$');

  static void Function(int userId)? onProfileLink;
  static void Function(int bookId)? onBookLink;

  static String? _pending;

  static Future<void> init() async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onLink') _handle(call.arguments as String?);
    });

    try {
      _handle(await _channel.invokeMethod<String>('getInitialLink'));
    } on PlatformException {
    } on MissingPluginException {
    }
  }

  static void _handle(String? link) {
    if (link == null || link.isEmpty) return;

    final bookId = int.tryParse(_bookLink.firstMatch(link.trim())?.group(1) ?? '');
    if (bookId != null) {
      final handler = onBookLink;
      if (handler == null) {
        _pending = link;
      } else {
        handler(bookId);
      }
      return;
    }

    final userId = ApiService.parseProfileUserId(link);
    if (userId == null) return;

    final handler = onProfileLink;
    if (handler == null) {
      _pending = link;
      return;
    }
    handler(userId);
  }

  static void flushPending() {
    final link = _pending;
    if (link == null) return;
    _pending = null;
    _handle(link);
  }
}
