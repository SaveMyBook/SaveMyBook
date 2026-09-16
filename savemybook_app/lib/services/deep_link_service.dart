import 'package:flutter/services.dart';
import 'api_service.dart';

/// savemybook://auth/oauth?code=… 或 ?error=… 的解析結果。
class OAuthDeepLink {
  final String? code;
  final String? error;

  const OAuthDeepLink({this.code, this.error});
}

class DeepLinkService {
  static const _channel = MethodChannel('savemybook/deeplink');

  static void Function(String token)? onProfileLink;
  static void Function(String token)? onBookLink;
  static void Function(OAuthDeepLink result)? onOAuthResult;

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

  static OAuthDeepLink? parseOAuthLink(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || uri.scheme != 'savemybook') return null;
    // savemybook://auth/oauth 的 host 是 auth、path 是 /oauth。
    if (uri.host != 'auth' || uri.path.replaceAll('/', '') != 'oauth') return null;
    return OAuthDeepLink(code: uri.queryParameters['code'], error: uri.queryParameters['error']);
  }

  static void _handle(String? link) {
    if (link == null || link.isEmpty) return;

    final oauth = parseOAuthLink(link);
    if (oauth != null) {
      // 沒有等待中的授權流程時直接丟棄：一次性碼只對當初送出的那一次授權有效，
      // 留到下一次登入只會讓流程立刻以失效的碼結束，使用者被迫一直重按而不停開新視窗。
      onOAuthResult?.call(oauth);
      return;
    }

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

  /// 測試用：模擬原生端送進來的深層連結。
  static void deliver(String link) => _handle(link);

  /// 測試用：清掉尚未派送的連結。
  static void reset() {
    _pending = null;
  }
}
