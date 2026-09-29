import 'package:flutter/services.dart';
import 'api_service.dart';
import 'cabinet_code.dart';

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
  static void Function()? onCabinetLink;

  static String? _pending;
  static bool _pendingCabinet = false;

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

    // 系統相機掃到的書櫃連結可能是轉傳的，連結中的碼一律丟棄，只開啟 App 的掃描頁重新掃描書櫃螢幕。
    if (isCabinetCode(link)) {
      final handler = onCabinetLink;
      if (handler == null) {
        _pendingCabinet = true;
      } else {
        handler();
      }
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
    if (_pendingCabinet && onCabinetLink != null) {
      _pendingCabinet = false;
      onCabinetLink!();
    }
    final link = _pending;
    if (link == null) return;
    _pending = null;
    _handle(link);
  }

  static void deliver(String link) => _handle(link);

  static void reset() {
    _pending = null;
    _pendingCabinet = false;
  }
}
