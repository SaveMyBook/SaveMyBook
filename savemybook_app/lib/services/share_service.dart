import 'package:flutter/services.dart';

class ShareService {
  static const _channel = MethodChannel('savemybook/share');

  static Future<bool> shareText(String text) => _invoke('shareText', {'text': text});

  static Future<bool> shareImage(String path, {String? text}) =>
      _invoke('shareImage', {'path': path, 'text': text});

  static Future<bool> saveImage(String path) => _invoke('saveImage', {'path': path});

  static Future<bool> shareFile(String path, {String? subject}) =>
      _invoke('shareFile', {'path': path, if (subject != null) 'text': subject});

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
