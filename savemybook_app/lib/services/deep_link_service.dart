import 'package:flutter/services.dart';
import 'api_service.dart';

/// 處理 savemybook:// 開頭的外部連結，由網頁版分享頁的「在 App 中開啟」觸發：
/// 個人檔案 savemybook://user/123、書籍 savemybook://book/45。
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
      // 平台沒有實作 channel（例如桌機除錯）時直接忽略。
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

  /// App 進到有 Navigator 的畫面之後再呼叫一次，把冷啟動時收到的連結補送出去。
  static void flushPending() {
    final link = _pending;
    if (link == null) return;
    _pending = null;
    _handle(link);
  }
}
