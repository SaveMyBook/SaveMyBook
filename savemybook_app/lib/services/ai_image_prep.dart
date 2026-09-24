import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

enum AiImageFormat { jpeg, png, webp, other }

class AiImagePrep {
  const AiImagePrep._();

  static const maxLongSide = 2000;
  static const reencodeAboveBytes = 4 * 1024 * 1024;
  static const jpegQuality = 88;

  static AiImageFormat sniff(Uint8List head) {
    if (head.length >= 3 && head[0] == 0xFF && head[1] == 0xD8 && head[2] == 0xFF) return AiImageFormat.jpeg;
    if (head.length >= 4 && head[0] == 0x89 && head[1] == 0x50 && head[2] == 0x4E && head[3] == 0x47) return AiImageFormat.png;
    if (head.length >= 12 &&
        String.fromCharCodes(head.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(head.sublist(8, 12)) == 'WEBP') {
      return AiImageFormat.webp;
    }
    return AiImageFormat.other;
  }

  // 伺服器只能移除 JPEG、PNG、WebP 的中繼資料，其餘格式（HEIC、HEIF、AVIF、GIF）會被略過不送 AI，
  // 因此須在 App 端先解碼並重新編碼為 JPEG；重新編碼的輸出本身不含任何中繼資料。
  static Future<List<String>> prepareAll(Iterable<String> paths) async {
    final out = <String>[];
    for (final path in paths) {
      final prepared = await prepare(path);
      if (prepared != null) out.add(prepared);
    }
    return out;
  }

  static Future<String?> prepare(String path, {int reencodeAbove = reencodeAboveBytes}) async {
    try {
      final file = File(path);
      final bytes = await file.readAsBytes();
      final format = sniff(bytes);
      if (format != AiImageFormat.other && bytes.length <= reencodeAbove) return path;

      final jpeg = await toJpeg(bytes);
      if (jpeg == null) return null;
      final target = File('${Directory.systemTemp.path}/ai_${DateTime.now().microsecondsSinceEpoch}.jpg');
      await target.writeAsBytes(jpeg, flush: true);
      return target.path;
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List?> toJpeg(Uint8List encoded) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(encoded);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    try {
      final longSide = math.max(descriptor.width, descriptor.height);
      final scale = longSide > maxLongSide ? maxLongSide / longSide : 1.0;
      final codec = await descriptor.instantiateCodec(
        targetWidth: (descriptor.width * scale).round(),
        targetHeight: (descriptor.height * scale).round(),
      );
      final frame = await codec.getNextFrame();
      codec.dispose();
      final image = frame.image;
      final rgba = await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
      final width = image.width;
      final height = image.height;
      image.dispose();
      if (rgba == null) return null;
      return await compute(_encodeJpeg, (rgba.buffer.asUint8List(), width, height));
    } finally {
      descriptor.dispose();
      buffer.dispose();
    }
  }
}

Uint8List _encodeJpeg((Uint8List, int, int) input) {
  final (rgba, width, height) = input;
  final image = img.Image.fromBytes(
    width: width,
    height: height,
    bytes: rgba.buffer,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  return img.encodeJpg(image, quality: AiImagePrep.jpegQuality);
}
