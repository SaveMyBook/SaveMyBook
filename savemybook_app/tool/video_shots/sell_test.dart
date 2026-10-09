// 系統簡介影片第二版「賣家上架」段落（分鏡v2.md 第三節）：flutter test tool/video_shots/sell_test.dart
// 雪喵掃描《HTML & CSS》的 ISBN 條碼、帶出書目、以三張實拍照片請 AI 判斷書況與售價，管理員在內容審核頁檢視規則與 AI 審核結果。

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:savemybook_app/features/admin/admin_report_screen.dart';
import 'package:savemybook_app/features/books/barcode_scanner_screen.dart';
import 'package:savemybook_app/features/home/home_screen.dart';
import 'package:savemybook_app/features/selling/ai_listing_assist.dart';
import 'package:savemybook_app/features/selling/sell_book_detail_screen.dart';
import 'package:savemybook_app/features/selling/sell_book_screen.dart';
import 'package:savemybook_app/i18n/strings.dart';
import 'package:savemybook_app/models/user.dart';
import 'package:savemybook_app/widgets/app_forms.dart';
import 'package:savemybook_app/widgets/state_views.dart';

import '../manual_shots/manual_api.dart';
import 'video_data.dart';
import 'video_host.dart';

final _ios = TargetPlatformVariant.only(TargetPlatform.iOS);

User get _seller => User.fromJson(userJson(sellerId));

void _sellRoutes() {
  ManualApi.on('GET', '/books/isbn/:isbn', (_) => isbnLookup());
  ManualApi.on('GET', '/cabinets', (_) => [for (final c in realCabinets) {...c, 'distance_m': _distanceFromCabinet(c)}]);
  ManualApi.on('POST', '/ai/listing-assist', (_) => conditionAssist());
}

/// 賣家人在新北高工上架，書櫃距離以新北高工為起點。
num _distanceFromCabinet(Map c) {
  final here = cabinetJson(cabinetId);
  double rad(Object? deg) => double.parse('$deg') * math.pi / 180;
  final dLat = rad(c['latitude']) - rad(here['latitude']);
  final dLng = rad(c['longitude']) - rad(here['longitude']);
  final a = math.pow(math.sin(dLat / 2), 2) + math.cos(rad(here['latitude'])) * math.cos(rad(c['latitude'])) * math.pow(math.sin(dLng / 2), 2);
  return math.max(30, (6371000 * 2 * math.asin(math.sqrt(a))).round());
}

// ───────────── 相機畫面 ─────────────

const _scannerMethod = MethodChannel('dev.steenbakker.mobile_scanner/scanner/method');
const _scannerEvents = EventChannel('dev.steenbakker.mobile_scanner/scanner/event');

void _mockScanner(WidgetTester tester) {
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(_scannerMethod, (call) async => switch (call.method) {
    'state' => 1,
    'request' => true,
    'start' => {
      'textureId': 1,
      'numberOfCameras': 2,
      'currentTorchState': 0,
      'size': {'width': 1080.0, 'height': 1920.0},
    },
    _ => null,
  });
  messenger.setMockStreamHandler(_scannerEvents, MockStreamHandler.inline(onListen: (_, _) {}));
  addTearDown(() {
    messenger.setMockMethodCallHandler(_scannerMethod, null);
    messenger.setMockStreamHandler(_scannerEvents, null);
  });
}

/// 相機預覽（比照 manual_shots 的做法）：App 的掃描頁在相機區域是黑底，以「濾色」把實拍照片疊進黑底，
/// 白色的標題、提示與掃描框維持不變；掃描頁上下的漸層暗角先畫在照片上。
/// 照片依條碼位置轉正、縮放，讓條碼落在掃描框內；照片涵蓋不到的角落以照片邊緣的模糊延伸補滿（如同景深外的書面）。
class _CameraFeed extends CustomPainter {
  final ui.Image photo;
  final Rect frame;
  final bool detected;

  const _CameraFeed(this.photo, this.frame, {this.detected = false});

  static final _tune = (Platform.environment['CAM'] ?? '').split(',').where((s) => s.isNotEmpty).map(double.parse).toList();
  double get scale => _tune.isNotEmpty ? _tune[0] : cameraScale;
  double get tilt => _tune.length > 1 ? _tune[1] : barcodeTilt;
  Offset get shift => _tune.length > 3 ? Offset(_tune[2], _tune[3]) : cameraShift;

  Matrix4 get _transform => Matrix4.identity()
    ..translateByDouble(frame.center.dx + shift.dx, frame.center.dy + shift.dy, 0, 1)
    ..rotateZ(tilt * math.pi / 180)
    ..scaleByDouble(scale, scale, 1, 1)
    ..translateByDouble(-barcodeCenter.x, -barcodeCenter.y, 0, 1);

  @override
  void paint(Canvas canvas, Size size) {
    final screen = Offset.zero & size;
    final source = Rect.fromLTWH(0, 0, photo.width.toDouble(), photo.height.toDouble());
    canvas.saveLayer(screen, Paint()..blendMode = BlendMode.screen);

    canvas.drawRect(
      screen,
      Paint()
        ..shader = ImageShader(photo, TileMode.mirror, TileMode.mirror, _transform.storage, filterQuality: FilterQuality.high)
        ..imageFilter = ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30, tileMode: TileMode.mirror)
        ..colorFilter = const ColorFilter.matrix([0.6, 0, 0, 0, 0, 0, 0.6, 0, 0, 0, 0, 0, 0.6, 0, 0, 0, 0, 0, 1, 0]),
    );

    canvas.save();
    canvas.transform(_transform.storage);
    canvas.saveLayer(source, Paint());
    canvas.drawImageRect(photo, source, source, Paint()..filterQuality = FilterQuality.high);
    // 照片邊緣羽化，與模糊延伸的部分自然銜接
    const feather = 90.0;
    for (final (from, to) in [
      (source.topLeft, source.topLeft + const Offset(feather, 0)),
      (source.topRight, source.topRight - const Offset(feather, 0)),
      (source.topLeft, source.topLeft + const Offset(0, feather)),
      (source.bottomLeft, source.bottomLeft - const Offset(0, feather)),
    ]) {
      canvas.drawRect(
        source,
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = ui.Gradient.linear(from, to, [const Color(0x00000000), const Color(0xFF000000)]),
      );
    }
    canvas.restore();
    canvas.restore();

    canvas.drawRect(
      screen,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, size.height),
          [const Color(0x80000000), const Color(0x00000000), const Color(0x00000000), const Color(0x80000000)],
          [0, 0.3, 0.7, 1],
        ),
    );
    canvas.restore();

    if (detected) {
      // 相機辨識到條碼時，系統相機在條碼上標示的範圍
      final center = frame.center + shift + Offset(barcodeBars.dx, barcodeBars.dy) * scale;
      final box = RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: barcodeBars.w * scale + 16, height: barcodeBars.h * scale + 12),
        const Radius.circular(8),
      );
      canvas.drawRRect(box, Paint()..color = const Color(0x3334C759));
      canvas.drawRRect(
        box,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = const Color(0xFF34C759),
      );
    }
  }

  @override
  bool shouldRepaint(_CameraFeed oldDelegate) => true;
}

Rect _scanFrame(WidgetTester tester) =>
    tester.getRect(find.byWidgetPredicate((w) => w is CustomPaint && w.painter.runtimeType.toString() == '_CornerFramePainter'));

Future<void> _openSell(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.add_rounded).last);
  await settleReal(tester, const Duration(seconds: 2));
}

Finder _formRow(String label) => find.byWidgetPredicate((w) => w is FormRowCard && w.label == label);

void main() {
  setUpAll(setUpManual);
  setUp(failures.clear);
  tearDownAll(writeJson);

  testWidgets('條碼掃描', variant: _ios, (tester) async {
    await videoShoot(
      tester,
      me: _seller,
      routes: _sellRoutes,
      home: HomeScreen.new,
      act: (tester) async {
        _mockScanner(tester);
        final photo = await loadPhoto(tester, storyPhoto('other'));
        await _openSell(tester);
        await tester.tap(find.descendant(of: find.byType(SellBookScreen), matching: find.byIcon(Icons.qr_code_scanner_rounded)));
        await settleReal(tester, const Duration(seconds: 2));
        expect(find.byType(BarcodeScannerScreen), findsOneWidget);
        final frame = _scanFrame(tester);
        for (final (name, detected) in [('v_sell_scan', false), ('v_sell_scan_ok', true)]) {
          systemOverlay.value = [
            Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _CameraFeed(photo, frame, detected: detected)))),
          ];
          await tester.pump();
          await snapScreen(tester, name);
        }
        systemOverlay.value = const [];
      },
    );
    expect(failures, isEmpty);
  });

  testWidgets('帶出書目', variant: _ios, (tester) async {
    await videoShoot(
      tester,
      me: _seller,
      routes: _sellRoutes,
      home: HomeScreen.new,
      act: (tester) async {
        await _openSell(tester);
        final sell = find.byType(SellBookScreen);
        await tester.enterText(find.descendant(of: sell, matching: find.byType(TextField)).first, storyIsbn);
        FocusManager.instance.primaryFocus?.unfocus();
        await settleReal(tester, const Duration(seconds: 1));
        await snapScreen(tester, 'v_sell_form_empty');
        final empty = {for (final l in [S.title, S.author2, S.publisher2]) l: tester.getRect(_formRow(l))};

        holdApi('GET /books/isbn/$storyIsbn');
        await tester.tap(find.descendant(of: sell, matching: find.byIcon(Icons.search_rounded)));
        await tester.pump();
        await untilHeld(tester);
        await settle(tester, const Duration(milliseconds: 600));
        spinnerFocus = find.byType(CircularProgressIndicator);
        await snapScreen(tester, 'v_sell_form_lookup');
        spinnerFocus = null;
        releaseApi();
        await settleReal(tester, const Duration(seconds: 2));
        // 等「已自動帶入書籍資料」提示收起，畫面只留表單
        await settle(tester, const Duration(seconds: 6));
        await snapScreen(tester, 'v_sell_form_filled');

        for (final (label, name) in [(S.title, 'cut_field_title'), (S.author2, 'cut_field_author'), (S.publisher2, 'cut_field_publisher')]) {
          final box = renderOf(tester, _formRow(label), pick: isBoxDecoration);
          if (tester.getRect(_formRow(label)) != empty[label]) failures.add('$name 在填入前後位置不同');
          await cut(tester, name, screen: 'v_sell_form_filled', box: box, note: '欄位位置與 v_sell_form_empty 相同，可直接貼到空白表單上逐一填入');
        }
        await restoreTree(tester);
      },
    );
    expect(failures, isEmpty);
  });

  testWidgets('照片與 AI 判斷書況', variant: _ios, (tester) async {
    final photos = [for (final t in ['cover', 'back', 'other']) photoFile(storyPhoto(t))!.path];
    await videoShoot(
      tester,
      me: _seller,
      routes: _sellRoutes,
      prefs: {
        'sell_draft_v1': jsonEncode({
          'step2': {
            'price': '',
            'condition': 'good',
            'condition_touched': false,
            'cabinet_id': cabinetId,
            'slots': photos,
            'extra': <String>[],
          },
          'saved_at': DateTime.now().toIso8601String(),
        }),
      },
      home: () => SellBookDetailScreen(
        isbn: storyIsbn,
        title: storyTitle,
        author: storyBook['author'] as String,
        publisher: storyBook['publisher'] as String,
        publishDate: storyBook['publish_date'] as String,
        description: storyBook['description'] as String,
        categoryId: storyBook['category_id'] as int,
      ),
      act: (tester) async {
        await settleReal(tester, const Duration(seconds: 1));
        final detail = find.byType(SellBookDetailScreen);
        final button = find.descendant(of: detail, matching: find.byType(AiAssistButton));
        await snapScreen(tester, 'v_sell_photos');
        tapAt(tester, 'tap_sell_ai', screen: 'v_sell_photos', finder: button);

        holdApi('POST /ai/listing-assist');
        await tester.tap(button);
        await tester.pump();
        await untilHeld(tester);
        await settle(tester, const Duration(milliseconds: 1500));
        spinnerFocus = find.byType(AiAssistProgressSheet);
        await snapScreen(tester, 'v_sell_ai_loading');
        spinnerFocus = null;
        releaseApi();
        for (var i = 0; i < 40 && find.byType(AiListingResultSheet).evaluate().isEmpty; i++) {
          await settleReal(tester, const Duration(milliseconds: 500));
        }
        await settleReal(tester, const Duration(seconds: 1));
        await snapScreen(tester, 'v_sell_ai_result');

        final sheet = find.byType(AiListingResultSheet);
        Finder tile(String text) => find
            .ancestor(of: find.descendant(of: sheet, matching: find.text(text)), matching: find.byType(AnimatedContainer))
            .first;
        final good = priceTable['good']!;
        await cut(tester, 'cut_ai_condition', screen: 'v_sell_ai_result', box: renderOf(tester, tile(S.conditionGood), pick: isBoxDecoration));
        await cut(tester, 'cut_ai_price', screen: 'v_sell_ai_result', box: renderOf(tester, tile('\$${good['suggested']}'), pick: isBoxDecoration));
        await restoreTree(tester);
      },
    );
    expect(failures, isEmpty);
  });

  testWidgets('內容審核', variant: _ios, (tester) async {
    await videoShoot(
      tester,
      me: User.fromJson(userJson(meId, extra: {'role': 'admin'})),
      routes: () {
        ManualApi.on('GET', '/admin/reports', (_) => <Object>[]);
        ManualApi.on('GET', '/admin/ai/reviews', (_) => [reviewItem()]);
      },
      home: () => const AdminReportScreen(initialTab: AdminReportScreen.listingReviewTab),
      act: (tester) async {
        await settleReal(tester, const Duration(seconds: 2));
        await snapScreen(tester, 'v_admin_review');
        final ruleText = find.text('站外交易或聯絡資訊').evaluate().map((e) => renderOf(tester, find.byElementPredicate((x) => x == e)));
        final rule = ruleText
            .map((t) {
              RenderObject? n = t;
              while (n != null && !isBoxDecoration(n)) {
                n = n.parent;
              }
              return n is RenderBox && n.size.width > 200 ? n : null;
            })
            .whereType<RenderBox>()
            .single;
        await cut(tester, 'cut_review_rule', screen: 'v_admin_review', box: rule, note: '規則檢查：即時規則送審的原因');
        final ai = find.ancestor(of: find.textContaining('AI 判定'), matching: find.byType(Column)).first;
        final card = ancestorWhere(find.text(storyTitle), (w) => w is AppCard);
        await cut(tester, 'cut_review_card', screen: 'v_admin_review', box: renderOf(tester, card, pick: isBoxDecoration), note: '整張待審卡片：書封、書名、標籤、規則原因、AI 判定與按鈕');
        await cut(tester, 'cut_review_ai', screen: 'v_admin_review', box: renderOf(tester, ai), note: 'AI 檢查：附在審核紀錄上的 AI 意見（文字元件，無底色）');
        await restoreTree(tester);
      },
    );
    expect(failures, isEmpty);
  });
}
