import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'share_service.dart';

class ImageSaveService {
  const ImageSaveService._();

  static const _timeout = Duration(seconds: 45);

  static bool get savesToDownloads => !kIsWeb && Platform.isMacOS;

  static Future<bool> saveUrls(List<String> urls, {ValueChanged<double>? onProgress}) async {
    if (urls.isEmpty) return false;
    try {
      final dir = Directory('${(await getTemporaryDirectory()).path}/chat_image_save');
      // iOS 的相簿寫入是非同步的，暫存檔不能在呼叫後立刻刪除，只能留到下次儲存前清理。
      if (dir.existsSync()) dir.deleteSync(recursive: true);
      dir.createSync(recursive: true);
      final stamp = DateTime.now().millisecondsSinceEpoch;
      for (var i = 0; i < urls.length; i++) {
        final file = await _download(
          urls[i],
          dir,
          'SaveMyBook_${stamp}_${i + 1}',
          (p) => onProgress?.call((i + p * 0.95) / urls.length),
        );
        if (file == null || !await ShareService.saveImage(file.path)) return false;
        onProgress?.call((i + 1) / urls.length);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<File?> _download(String url, Directory dir, String name, ValueChanged<double> onProgress) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final dot = uri.path.lastIndexOf('.');
    final ext = dot >= 0 && uri.path.length - dot <= 5 ? uri.path.substring(dot).toLowerCase() : '.jpg';
    final file = File('${dir.path}/$name$ext');
    final client = http.Client();
    IOSink? sink;
    try {
      final response = await client.send(http.Request('GET', uri)).timeout(_timeout);
      if (response.statusCode != 200) return null;
      final total = response.contentLength ?? 0;
      var received = 0;
      sink = file.openWrite();
      await for (final chunk in response.stream.timeout(_timeout)) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress((received / total).clamp(0.0, 1.0));
      }
      await sink.close();
      sink = null;
      return received > 0 ? file : null;
    } catch (_) {
      return null;
    } finally {
      await sink?.close();
      client.close();
    }
  }
}
