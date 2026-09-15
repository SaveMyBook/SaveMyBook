import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:savemybook_app/services/ai_image_prep.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('ai_prep_test'));
  tearDown(() => dir.deleteSync(recursive: true));

  String writePng(int width, int height) {
    final image = img.Image(width: width, height: height);
    img.fill(image, color: img.ColorRgb8(200, 120, 40));
    final file = File('${dir.path}/w${width}_h$height.png')..writeAsBytesSync(img.encodePng(image));
    return file.path;
  }

  test('判斷伺服器可處理的格式', () {
    expect(AiImagePrep.sniff(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0])), AiImageFormat.jpeg);
    expect(AiImagePrep.sniff(Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D])), AiImageFormat.png);
    expect(AiImagePrep.sniff(Uint8List.fromList('RIFF\x00\x00\x00\x00WEBPVP8 '.codeUnits)), AiImageFormat.webp);
    expect(AiImagePrep.sniff(Uint8List.fromList('\x00\x00\x00\x18ftypheic'.codeUnits)), AiImageFormat.other);
    expect(AiImagePrep.sniff(Uint8List.fromList('GIF89a'.codeUnits)), AiImageFormat.other);
  });

  testWidgets('小於門檻的 PNG 直接送出原檔', (tester) async {
    final path = writePng(40, 30);
    final result = await tester.runAsync(() => AiImagePrep.prepare(path));
    expect(result, path);
  });

  testWidgets('需轉檔時輸出為 JPEG 並縮小長邊', (tester) async {
    final path = writePng(2400, 120);
    final result = await tester.runAsync(() => AiImagePrep.prepare(path, reencodeAbove: 0));
    expect(result, isNotNull);
    expect(result, isNot(path));
    final bytes = File(result!).readAsBytesSync();
    expect(AiImagePrep.sniff(bytes), AiImageFormat.jpeg);
    final decoded = img.decodeJpg(bytes)!;
    expect(decoded.width, AiImagePrep.maxLongSide);
    expect(decoded.height, 100);
    File(result).deleteSync();
  });

  testWidgets('無法解碼的檔案不送出', (tester) async {
    final file = File('${dir.path}/broken.heic')..writeAsBytesSync('\x00\x00\x00\x18ftypheic-not-an-image'.codeUnits);
    final result = await tester.runAsync(() => AiImagePrep.prepare(file.path));
    expect(result, isNull);
  });
}
