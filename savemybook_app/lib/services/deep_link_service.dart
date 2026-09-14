import 'package:flutter/services.dart';
import 'api_service.dart';

class DeepLinkService {
  static const _channel = MethodChannel('savemybook/deeplink');

  static void Function(String token)? onProfileLink;
  static void Function(String token)? onBookLink;

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
    final parsed = ApiService.parseShareLink(link);
    if (parsed == null) return;

    final handler = parsed.kind == 'b' ? onBookLink : onProfileLink;
    if (handler == null) {
      _pending = link;
      return;
    }
    handler(parsed.token);
  }

  static void flushPending() {
    final link = _pending;
    if (link == null) return;
    _pending = null;
    _handle(link);
  }
}
