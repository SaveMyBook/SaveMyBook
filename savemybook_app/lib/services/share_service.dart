import 'package:flutter/services.dart';

/// 系統分享頁與存圖，走原生 channel，不額外依賴套件。
class ShareService {
  static const _channel = MethodChannel('savemybook/share');

  static Future<bool> shareText(String text) => _invoke('shareText', {'text': text});

  static Future<bool> shareImage(String path, {String? text}) =>
      _invoke('shareImage', {'path': path, 'text': text});

  /// 存到系統相簿。Android 9 以下沒有 MediaStore 的相對路徑，會回 false。
  static Future<bool> saveImage(String path) => _invoke('saveImage', {'path': path});

  static Future<bool> _invoke(String method, Map<String, dynamic> args) async {
    try {
      return await _channel.invokeMethod<bool>(method, args) ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
