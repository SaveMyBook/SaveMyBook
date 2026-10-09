// 系統簡介影片第二版「智慧書櫃」「管理後台」段落：flutter test tool/video_shots/cabinet_admin_test.dart
// 賣家雪喵在新北高工書櫃（cabinet 7）存放《HTML & CSS》：先在捷運海山站出口掃描被拒（距離書櫃約 310 公尺），
// 到書櫃前重新掃描、輸入書櫃螢幕上的兩位數字、放書關門；買家 es 收到存書通知並查看前往書櫃的交通資訊。
// 管理後台：管理員（es，管理員身分）檢視後台模組，並輸入新北高工書櫃螢幕上的八位數配對碼 0151-7752 完成配對。
// 交通資訊為 2026-10-09 以後端 services/transit（與正式站同一份程式）向臺北市資料大平臺唯讀取得的新北高工附近資料（_transitJson）。

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:savemybook_app/features/admin/admin_cabinet_device_screen.dart';
import 'package:savemybook_app/features/admin/admin_cabinet_pairing_dialog.dart';
import 'package:savemybook_app/features/admin/admin_home_screen.dart';
import 'package:savemybook_app/features/cabinet/cabinet_flow_controller.dart';
import 'package:savemybook_app/features/cabinet/cabinet_flow_screen.dart';
import 'package:savemybook_app/features/cabinet/cabinet_guide_screen.dart';
import 'package:savemybook_app/features/cabinet/cabinet_match_code_field.dart';
import 'package:savemybook_app/features/cabinet/cabinet_scanner_view.dart';
import 'package:savemybook_app/features/home/home_screen.dart';
import 'package:savemybook_app/models/cabinet.dart';
import 'package:savemybook_app/models/notification_category.dart';
import 'package:savemybook_app/models/order.dart';
import 'package:savemybook_app/models/user.dart';
import 'package:savemybook_app/services/location_service.dart';
import 'package:savemybook_app/widgets/app_header.dart';
import 'package:savemybook_app/widgets/app_tiles.dart';
import 'package:savemybook_app/widgets/in_app_banner.dart';
import 'package:savemybook_app/widgets/state_views.dart';

import '../manual_shots/manual_api.dart';
import '../manual_shots/manual_host.dart' show pixelRatio;
import '../manual_shots/s07_08_09_11_ui.dart' show CameraLayer;
import '../manual_shots/s19_keyboards.dart';
import 'video_data.dart';
import 'video_host.dart';

final _ios = TargetPlatformVariant.only(TargetPlatform.iOS);

// ───────────── 劇情資料 ─────────────

/// 買家 es 購買《HTML & CSS》的訂單（指定新北高工書櫃，櫃門 A01）。
const _orderId = storyOrderId;
final _orderNo = storyOrderNo;
const _sessionNo = 'CS7Q2HX5K';
const _door = 'A01';

/// 賣家在捷運海山站 2 號出口掃描：出口與書櫃的距離 314 公尺（data.taipei 捷運出入口座標，見 _transitJson），App 顯示約 310 公尺。
const _farLat = 24.9853326, _farLng = 121.4488709;
const _farMeters = 314;

/// 書櫃 QR Code 內容：與影片中 3D 書櫃螢幕（textures.ts 的 Kiosk）相同，第 0 組與 30 秒後更新的第 1 組。
String _qrData(int i) => i == 0 ? 'NMIXX HAEWON 0225' : 'NMIXX HAEWON 0225 #$i';

/// 掃描時送出的書櫃代碼（格式同正式站：savemybook://k/ 加 32 位十六進位權杖）。
const _scanCode = 'savemybook://k/7c3e9a1f04b25d68e1a9c07f3b5d2e48';

Map<String, dynamic> get _cabinet => cabinetJson(cabinetId);
String get _cabinetName => _cabinet['cabinet_name'] as String;

User get _seller => User.fromJson(userJson(sellerId));
User get _admin => User.fromJson(userJson(meId, extra: {'role': 'admin'}));

Map<String, dynamic> _order(String status) => {
  'order_id': _orderId,
  'order_no': _orderNo,
  'buyer_id': buyerId,
  'seller_id': sellerId,
  'total_amount': storyBook['price'],
  'status': status,
  'pickup_code': null,
  'cabinet_id': cabinetId,
  'created_at': storyPaidAt.toUtc().toIso8601String(),
  'picked_up_at': null,
  'completed_at': null,
  'order_items': [
    {'item_id': _orderId * 10, 'book_id': storyBookId, 'quantity': 1, 'unit_price': storyBook['price'], 'subtotal': storyBook['price'], 'books': storyBook},
  ],
  'smart_cabinets': _cabinet,
  'cabinet_slots': status == 'pending_deposit' ? null : {'slot_id': 701, 'slot_number': _door},
  'users_orders_buyer_idTousers': userJson(buyerId),
  'users_orders_seller_idTousers': userJson(sellerId),
  'transaction_disputes': <Object>[],
  'doors': status == 'pending_deposit' ? <String>[] : [_door],
};

/// 書櫃作業（GET /cabinet-sessions/:no）：賣家依訂單存書，一扇櫃門開門 30 秒（policy.js CABINET_DOOR_OPEN_SECONDS）。
Map<String, dynamic> _session(String status, {int? remainingMs, bool done = false}) {
  final selecting = status == 'selecting';
  return {
    'session_no': _sessionNo,
    'status': status,
    'version': 3,
    'cabinet': {..._cabinet, 'available_doors': 4},
    'location_status': 'granted',
    'distance_m': 6,
    'items': [
      {
        'key': 'order:$_orderId',
        'kind': 'order_deposit',
        'order_id': _orderId,
        'order_no': _orderNo,
        'books': [
          {'book_id': storyBookId, 'title': storyTitle, 'image_url': coverOf(storyBookId), 'door': selecting ? null : _door},
        ],
        'doors': [if (!selecting) _door],
        'paused': false,
        'note': null,
        'selected': true,
        'blocked': null,
        'result': done ? 'done' : 'pending',
        'error': null,
      },
    ],
    'doors': [
      if (!selecting)
        {
          'label': _door,
          'state': switch (status) {
            'open' => 'open',
            'completed' => 'closed',
            _ => 'pending',
          },
        },
    ],
    'remaining_ms': remainingMs,
    'open_ms': 30000,
    'notice': null,
    'result': done ? {'outcome': 'completed', 'code': 'COMPLETED', 'message': ''} : null,
    'created_at': ago(minutes: 1),
  };
}

Map<String, dynamic> Function() _current = () => _session('selecting', remainingMs: 59000);

void _cabinetRoutes() {
  ManualApi.on('GET', '/cabinet-sessions/active', (_) => null);
  ManualApi.on('GET', '/cabinet-sessions/:no', (_) => _current());
  ManualApi.on('GET', '/orders/:id', (_) => _order('pending_deposit'));
}

CabinetFlowController _controller({bool far = false}) => CabinetFlowController(
  locate: () async => FreshLocation(status: FreshLocation.granted, lat: far ? _farLat : 24.98279, lng: far ? _farLng : 121.45023, accuracyM: 8, ageMs: 400),
  checkLocation: () async => LocationAccess.granted,
);

/// 依真實回應建立的工作階段（resume 用）。
CabinetSession _resume(String status, {int? remainingMs, bool done = false}) {
  _current = () => _session(status, remainingMs: remainingMs, done: done);
  return CabinetSession.fromJson(_current());
}

// ───────────── 相機畫面：鏡頭對準新北高工書櫃的螢幕 ─────────────

ui.Paragraph _text(String text, double width, {required double size, FontWeight weight = FontWeight.w400, Color color = Colors.white}) {
  final b = ui.ParagraphBuilder(ui.ParagraphStyle(fontFamily: 'NotoSansTC', fontSize: size, fontWeight: weight, height: 1.0))
    ..pushStyle(ui.TextStyle(color: color, fontFamily: 'NotoSansTC', fontSize: size, fontWeight: weight))
    ..addText(text);
  return b.build()..layout(ui.ParagraphConstraints(width: width));
}

/// 比照 web_shots/covers.dart 的 paintCameraScene，螢幕內容改為與 3D 書櫃相同：
/// QR Code 為版本 4、錯誤修正 M（同韌體），頂列為書櫃名稱與 14:25，[bar] 為 QR Code 更新倒數條剩餘比例。
ui.Image _cameraScene(Size size, Offset frameCenter, double frame, {required String qr, required double bar, double scale = 3}) {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder)..scale(scale);
  final bounds = Offset.zero & size;

  canvas.drawRect(
    bounds,
    Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(0, size.height), const [Color(0xFF4A463E), Color(0xFF2B2C2E), Color(0xFF1E1F21)], [0, 0.55, 1]),
  );
  final glow = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);
  canvas.drawCircle(Offset(size.width * 0.12, size.height * 0.08), 110, glow..color = const Color(0x66C9A66B));
  canvas.drawCircle(Offset(size.width * 0.95, size.height * 0.2), 90, glow..color = const Color(0x405F7F8F));

  final qrBox = frame * 0.46;
  final u = qrBox / 164;
  final screen = Rect.fromLTWH(frameCenter.dx - 98 * u, frameCenter.dy - 122 * u, 320 * u, 240 * u);
  final sw = screen.width;
  final pad = sw * 0.06;
  final face = Rect.fromLTRB(-sw, screen.top - pad - sw * 0.27, screen.right + pad + sw * 0.3, size.height + sw);
  final topRowBottom = screen.center.dy + sw * 0.582;

  final wood = Paint()..shader = ui.Gradient.linear(face.topRight, face.topRight.translate(sw * 0.1, sw * 0.4), const [Color(0xFFB79668), Color(0xFF8F7149)]);
  canvas.drawPath(
    Path()
      ..moveTo(face.right, face.top)
      ..lineTo(face.right + sw * 0.09, face.top - sw * 0.05)
      ..lineTo(face.right + sw * 0.09, size.height)
      ..lineTo(face.right, size.height)
      ..close(),
    wood,
  );
  canvas.drawPath(
    Path()
      ..moveTo(face.left, face.top)
      ..lineTo(face.right, face.top)
      ..lineTo(face.right + sw * 0.09, face.top - sw * 0.05)
      ..lineTo(face.left, face.top - sw * 0.05)
      ..close(),
    Paint()..color = const Color(0xFFC9A87A),
  );
  canvas.drawRect(
    face,
    Paint()..shader = ui.Gradient.linear(face.topCenter, face.topCenter.translate(0, sw * 1.6), const [Color(0xFFDDE2E5), Color(0xFFB7BFC4)]),
  );

  final openRight = face.right - sw * 0.128;
  for (var i = 0; i < 2; i++) {
    final top = topRowBottom + sw * 0.128 + i * sw * (0.866 + 0.128);
    final cell = Rect.fromLTRB(face.left, top, openRight, top + sw * 0.866);
    canvas.drawRect(cell, Paint()..shader = ui.Gradient.linear(cell.topCenter, cell.bottomCenter, const [Color(0xFF8C7250), Color(0xFFA88A62)]));
    canvas.drawRect(Rect.fromLTRB(cell.left, cell.bottom - sw * 0.2, cell.right, cell.bottom), Paint()..color = const Color(0xFFB99A70));
    canvas.drawRect(cell, Paint()..color = const Color(0x2ECFE0E8));
    canvas.drawRect(
      cell.deflate(1.2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = const Color(0xCCB4C8D2),
    );
    canvas.drawPath(
      Path()
        ..moveTo(cell.right - sw * 0.55, cell.top)
        ..lineTo(cell.right - sw * 0.42, cell.top)
        ..lineTo(cell.right - sw * 0.7, cell.bottom)
        ..lineTo(cell.right - sw * 0.83, cell.bottom)
        ..close(),
      Paint()..color = const Color(0x1FFFFFFF),
    );
    final hinge = Paint()..color = const Color(0xFFB7BEC4);
    for (final y in [cell.top + sw * 0.17, cell.bottom - sw * 0.17]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cell.right + 1, y), width: sw * 0.05, height: sw * 0.17), const Radius.circular(2)),
        hinge,
      );
    }
  }

  canvas.drawRRect(RRect.fromRectAndRadius(screen.inflate(pad), Radius.circular(pad * 0.5)), Paint()..color = const Color(0xFF1D2126));
  canvas.drawRect(screen, Paint()..color = const Color(0xFF0E1318));
  canvas.drawRect(Rect.fromLTWH(screen.left, screen.top, sw, 28 * u), Paint()..color = const Color(0xFF18212A));
  final title = _text(_cabinetName, sw, size: 16 * u, weight: FontWeight.w500, color: const Color(0xFFEEF2F5));
  canvas.drawParagraph(title, Offset(screen.left + 10 * u, screen.top + 14 * u - title.height / 2));
  final clock = _text('14:25', sw, size: 16 * u, weight: FontWeight.w500, color: const Color(0xFFEEF2F5));
  canvas.drawParagraph(clock, Offset(screen.right - 10 * u - clock.maxIntrinsicWidth, screen.top + 14 * u - clock.height / 2));
  final qrRect = Rect.fromLTWH(screen.left + 16 * u, screen.top + 40 * u, qrBox, qrBox);
  canvas.drawRect(qrRect, Paint()..color = const Color(0xFFFFFFFF));
  canvas.save();
  canvas.translate(qrRect.left + 16 * u, qrRect.top + 16 * u);
  QrPainter(
    data: qr,
    version: 4,
    errorCorrectionLevel: QrErrorCorrectLevel.M,
    gapless: true,
    eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF0E1318)),
    dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF0E1318)),
  ).paint(canvas, Size.square(qrBox - 32 * u));
  canvas.restore();
  canvas.drawRect(Rect.fromLTWH(qrRect.left, qrRect.bottom + 8 * u, qrBox, 4 * u), Paint()..color = const Color(0xFF2A3540));
  canvas.drawRect(Rect.fromLTWH(qrRect.left, qrRect.bottom + 8 * u, qrBox * bar, 4 * u), Paint()..color = const Color(0xFF46B59C));
  // 與 3D 書櫃螢幕（textures.ts 的 balancedWrap）相同的斷行
  final lines = ['請使用', 'SaveMyBook', 'App 掃描'];
  final cx = screen.left + (qrRect.right - screen.left + 12 * u + (sw - 8 * u)) / 2;
  var y = qrRect.center.dy - lines.length * 12 * u;
  for (final line in lines) {
    final p = _text(line, sw, size: 15 * u, color: const Color(0xFFEEF2F5));
    canvas.drawParagraph(p, Offset(cx - p.maxIntrinsicWidth / 2, y + 12 * u - p.height / 2));
    y += 24 * u;
  }

  canvas.drawRect(
    bounds,
    Paint()..shader = ui.Gradient.radial(bounds.center, size.longestSide * 0.62, const [Color(0x00000000), Color(0x8C000000)], [0.55, 1]),
  );
  final picture = recorder.endRecording();
  final image = picture.toImageSync((size.width * scale).round(), (size.height * scale).round());
  picture.dispose();
  return image;
}

Future<void> _scanCamera(WidgetTester tester, {required int qr, required double bar}) async {
  final scanner = tester.getRect(find.byType(CabinetScannerView));
  final frame = tester.getRect(find.byWidgetPredicate((w) => w is CustomPaint && w.painter is ScanFramePainter));
  final paste = find.byType(CabinetPasteButton);
  final camera = _cameraScene(scanner.size, frame.center - scanner.topLeft, frame.width, qr: _qrData(qr), bar: bar);
  systemOverlay.value = [
    Positioned.fill(
      child: CameraLayer(image: camera, rect: scanner, blackouts: [if (paste.evaluate().isNotEmpty) tester.getRect(paste).inflate(6)]),
    ),
  ];
  await tester.pump();
}


/// 元件四周補上它在 App 中實際襯著的底色後輸出（同 video_host.dart 的 cut，外框向外加 [pad]）：
/// 選單列、交通資訊列本身沒有內距，緊貼外框裁切時文字會碰到浮出元件的邊緣。
/// 補上的範圍在原畫面中必須也是同一底色（卡片內距或頁面背景），貼回原畫面才會逐像素相符。
Future<void> _cutPadded(
  WidgetTester tester,
  String name, {
  required String screen,
  required RenderBox box,
  required EdgeInsets pad,
  required Color backdrop,
  double radius = 14,
  String? note,
}) async {
  // 截圖時 snapScreen 把未指定字型的文字改成 App 字型，之後的重建會還原；這裡重新套用，元件與整張畫面的字型才一致
  void appFont(RenderObject node) {
    if (node is RenderParagraph) {
      final span = node.text;
      if (span is TextSpan && span.style?.fontFamily == null) {
        node.text = TextSpan(text: span.text, children: span.children, style: (span.style ?? const TextStyle()).copyWith(fontFamily: 'NotoSansTC'));
      }
    }
    node.visitChildren(appFont);
  }

  appFont(box);
  tester.binding.rootPipelineOwner
    ..flushLayout()
    ..flushCompositingBits()
    ..flushPaint();
  final rect = pad.inflateRect(box.localToGlobal(Offset.zero) & box.size);
  final px = Rect.fromLTRB(
    (rect.left * pixelRatio + 1e-6).floorToDouble(),
    (rect.top * pixelRatio + 1e-6).floorToDouble(),
    (rect.right * pixelRatio - 1e-6).ceilToDouble(),
    (rect.bottom * pixelRatio - 1e-6).ceilToDouble(),
  );
  final phase = rect.topLeft - px.topLeft / pixelRatio;
  final rrect = RRect.fromRectAndRadius(phase & rect.size, Radius.circular(radius));
  final layer = OffsetLayer();
  // ignore: invalid_use_of_protected_member
  final context = PaintingContext(layer, Offset.zero & (px.size / pixelRatio));
  context.canvas.drawRRect(rrect, Paint()..color = backdrop);
  context.pushClipRRect(true, Offset.zero, phase & rect.size, rrect, (c, o) => c.paintChild(box, phase + Offset(pad.left, pad.top)));
  // ignore: invalid_use_of_protected_member
  context.stopRecordingIfNeeded();
  await tester.runAsync(() async {
    final image = await layer.toImage(Offset.zero & (px.size / pixelRatio), pixelRatio: pixelRatio);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
    File('$videoOutDir/cuts/$name.png')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(bytes);
    image.dispose();
  });
  layer.dispose();
  await restoreTree(tester);
  double r3(double v) => double.parse((v / pixelRatio).toStringAsFixed(4));
  double r2(double v) => double.parse(v.toStringAsFixed(3));
  String hex(Color c) => '#${[c.r, c.g, c.b].map((v) => (v * 255).round().toRadixString(16).padLeft(2, '0')).join()}'.toUpperCase();
  final file = File('$videoOutDir/cuts.json');
  final all = file.existsSync() ? jsonDecode(file.readAsStringSync()) as Map<String, dynamic> : <String, dynamic>{};
  all[name] = {
    'screen': screen,
    'x': r3(px.left),
    'y': r3(px.top),
    'w': r3(px.width),
    'h': r3(px.height),
    'r': r2(radius),
    'px': {'x': px.left.round(), 'y': px.top.round(), 'w': px.width.round(), 'h': px.height.round()},
    'exact': {'x': r2(rect.left), 'y': r2(rect.top), 'w': r2(rect.width), 'h': r2(rect.height)},
    'backdrop': hex(backdrop),
    'padded': true,
    'note': ?note,
  };
  final keys = all.keys.toList()..sort();
  file.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert({for (final k in keys) k: all[k]})}\n');
}

// ───────────── 交通資訊 ─────────────

/// 2026-10-09 以 savemybook_api/services/transit 的 nearby()、stations()、fares() 向 data.taipei 唯讀取得（新北高工 24.9827866, 121.4502229）。
const _transitJson =
    r'''{"fetched_at":"2026-10-08T23:57:21.408Z","lat":24.9827866,"lng":121.4502229,"nearby":{"mrt":{"status":"ok","updated_at":"2026-10-08T23:57:19.778Z","stations":[{"name":"海山","distance_m":314,"nearest_exit":{"exit":"2","accessible":true,"latitude":24.9853326,"longitude":121.4488709,"distance_m":314},"accessible_exit":{"exit":"2","facility":"elevator","latitude":24.9853454,"longitude":121.4489386,"distance_m":313}},{"name":"土城","distance_m":1126,"nearest_exit":{"exit":"3","accessible":false,"latitude":24.973714,"longitude":121.445266,"distance_m":1126},"accessible_exit":{"exit":"1","facility":"elevator","latitude":24.973459,"longitude":121.4441438,"distance_m":1205}}]},"bus":{"status":"ok","updated_at":"2026-10-08T23:57:15.000Z","realtime_available":true,"stops":[{"name":"新北高工(學府)","address":"學府路1段241號(向北)","latitude":24.98301,"longitude":121.450081,"distance_m":29,"routes":[{"name":"262","direction":"宏國德霖科技大學","status":"minutes","minutes":14}]},{"name":"新北高工(學府)","address":"學府路1段241號對面(向南)","latitude":24.98314,"longitude":121.44997,"distance_m":47,"routes":[{"name":"262","direction":"塔悠疏散門","status":"minutes","minutes":2}]},{"name":"學士路口","address":"明德路二段117號同向","latitude":24.98198,"longitude":121.45038,"distance_m":91,"routes":[{"name":"262","direction":"宏國德霖科技大學","status":"minutes","minutes":13},{"name":"265經明德路","direction":"立法院","status":"minutes","minutes":44}]},{"name":"學士路口","address":"明德路二段117號同向(向東)","latitude":24.981917,"longitude":121.450306,"distance_m":97,"routes":[{"name":"262","direction":"塔悠疏散門","status":"minutes","minutes":3},{"name":"265經明德路","direction":"土城站","status":"minutes","minutes":30}]}]},"youbike":{"status":"ok","updated_at":"2026-10-08T23:56:18.000Z","stations":[]},"parking_lots":{"status":"ok","updated_at":"2026-10-08T23:52:00.000Z","realtime_available":true,"lots":[]},"roadside":{"status":"ok","radius_m":300,"layer_updated_at":"2026-08-27T09:32:00.000Z","updated_at":"2026-10-08T23:55:10.000Z","car":[],"motorcycle":[]},"road_speed":{"status":"ok","updated_at":"2026-10-08T23:57:19.731Z","sections":[]},"taxi_stands":{"status":"ok","updated_at":"2026-10-08T23:57:19.802Z","stands":[]},"attribution":"資料來源：臺北市資料大平臺（data.taipei），依政府資料開放授權條款第 1 版使用","sources":[{"title":"臺北捷運車站出入口座標","url":"https://data.taipei/dataset/detail?id=cfa4778c-62c1-497b-b704-756231de348b"},{"title":"臺北捷運車站出入口無障礙電梯、無障礙坡道GPS座標","url":"https://data.taipei/dataset/detail?id=0a3bb422-9eb5-459b-a9d4-138456516183"},{"title":"臺北捷運系統票價","url":"https://data.taipei/dataset/detail?id=4acb4911-0360-4063-808d-fcee629508b3"},{"title":"臺北市站牌","url":"https://data.taipei/dataset/detail?id=62bc76da-6e6b-46ee-8976-c1945092d504"},{"title":"臺北市預估到站時間(公車)","url":"https://data.taipei/dataset/detail?id=f11a5af0-7b37-48ef-98cc-f6f102ed43c6"},{"title":"臺北市公車結構性票價資訊","url":"https://data.taipei/dataset/detail?id=651f6f05-074c-4f7a-a9cf-a367c32aa60b"},{"title":"YouBike2.0臺北市公共自行車即時資訊","url":"https://data.taipei/dataset/detail?id=c6bc8aed-557d-41d5-bfb1-8da24f78f2fb"},{"title":"臺北市停車場資訊","url":"https://data.taipei/dataset/detail?id=d5c0656b-5250-4179-a491-c94daa56ef2c"},{"title":"臺北市路邊停車格位","url":"https://data.taipei/dataset/detail?id=5a911ea5-1694-4301-808e-e1780d971611"},{"title":"臺北市路邊停車格位使用情形","url":"https://data.taipei/dataset/detail?id=434638ca-8770-42c1-940d-0386a74f6eb9"},{"title":"臺北市道路速率","url":"https://data.taipei/dataset/detail?id=b5aaf33a-a6dc-4836-bce6-09986241fe11"},{"title":"計程車招呼站","url":"https://data.taipei/dataset/detail?id=a0cf5e08-2b46-46be-aaa6-ac894b439156"}]},"stations":{"updated_at":"2026-10-08T23:57:19.778Z","stations":[{"name":"七張","latitude":24.975968,"longitude":121.542855},{"name":"十四張","latitude":24.984467,"longitude":121.527701},{"name":"三民高中","latitude":25.085665,"longitude":121.473131},{"name":"三和國中","latitude":25.076785,"longitude":121.486441},{"name":"三重","latitude":25.055701,"longitude":121.484246},{"name":"三重國小","latitude":25.070646,"longitude":121.496702},{"name":"土城","latitude":24.973209,"longitude":121.44437},{"name":"士林","latitude":25.093483,"longitude":121.526203},{"name":"大安","latitude":25.033414,"longitude":121.542894},{"name":"大安森林公園","latitude":25.033482,"longitude":121.535174},{"name":"大坪林","latitude":24.982837,"longitude":121.541736},{"name":"大直","latitude":25.079795,"longitude":121.54692},{"name":"大湖公園","latitude":25.083785,"longitude":121.602294},{"name":"大橋頭","latitude":25.063362,"longitude":121.512688},{"name":"小南門","latitude":25.035676,"longitude":121.510515},{"name":"小碧潭","latitude":24.972498,"longitude":121.529923},{"name":"中山","latitude":25.052689,"longitude":121.520194},{"name":"中山國小","latitude":25.062653,"longitude":121.526548},{"name":"中山國中","latitude":25.060826,"longitude":121.543979},{"name":"中正紀念堂","latitude":25.033889,"longitude":121.517488},{"name":"中和","latitude":25.002212,"longitude":121.496491},{"name":"中原","latitude":25.00841,"longitude":121.484159},{"name":"丹鳳","latitude":25.028866,"longitude":121.422463},{"name":"內湖","latitude":25.083691,"longitude":121.594439},{"name":"公館","latitude":25.014949,"longitude":121.534187},{"name":"六張犁","latitude":25.023852,"longitude":121.552737},{"name":"文德","latitude":25.078512,"longitude":121.585119},{"name":"木柵","latitude":24.998174,"longitude":121.573417},{"name":"北投","latitude":25.131676,"longitude":121.498656},{"name":"北門","latitude":25.049462,"longitude":121.51024},{"name":"古亭","latitude":25.026695,"longitude":121.522662},{"name":"台大醫院","latitude":25.041955,"longitude":121.516313},{"name":"台北101/世貿","latitude":25.032965,"longitude":121.562933},{"name":"台北小巨蛋","latitude":25.05166,"longitude":121.551952},{"name":"台北車站","latitude":25.046778,"longitude":121.517707},{"name":"台北橋","latitude":25.062966,"longitude":121.500281},{"name":"台電大樓","latitude":25.020553,"longitude":121.528111},{"name":"市政府","latitude":25.041136,"longitude":121.566213},{"name":"民權西路","latitude":25.062541,"longitude":121.519789},{"name":"永安市場","latitude":25.002375,"longitude":121.510962},{"name":"永春","latitude":25.040813,"longitude":121.575971},{"name":"永寧","latitude":24.966863,"longitude":121.436334},{"name":"石牌","latitude":25.114242,"longitude":121.515752},{"name":"先嗇宮","latitude":25.046292,"longitude":121.471423},{"name":"江子翠","latitude":25.030249,"longitude":121.47253},{"name":"竹圍","latitude":25.136902,"longitude":121.459548},{"name":"行天宮","latitude":25.059282,"longitude":121.533193},{"name":"西門","latitude":25.042197,"longitude":121.508381},{"name":"西湖","latitude":25.082181,"longitude":121.566894},{"name":"秀朗橋","latitude":24.990537,"longitude":121.525165},{"name":"辛亥","latitude":25.005119,"longitude":121.557021},{"name":"亞東醫院","latitude":24.998687,"longitude":121.452613},{"name":"奇岩","latitude":25.125427,"longitude":121.501111},{"name":"幸福","latitude":25.049943,"longitude":121.460191},{"name":"府中","latitude":25.008864,"longitude":121.459183},{"name":"忠孝復興","latitude":25.041652,"longitude":121.544102},{"name":"忠孝敦化","latitude":25.041478,"longitude":121.550316},{"name":"忠孝新生","latitude":25.041813,"longitude":121.53276},{"name":"忠義","latitude":25.131021,"longitude":121.473408},{"name":"昆陽","latitude":25.050473,"longitude":121.593245},{"name":"明德","latitude":25.109757,"longitude":121.518806},{"name":"東門","latitude":25.033903,"longitude":121.5288},{"name":"東湖","latitude":25.067146,"longitude":121.611386},{"name":"松山","latitude":25.050128,"longitude":121.57731},{"name":"松山機場","latitude":25.063446,"longitude":121.551624},{"name":"松江南京","latitude":25.051878,"longitude":121.53316},{"name":"板新","latitude":25.014491,"longitude":121.472212},{"name":"板橋","latitude":25.014317,"longitude":121.463269},{"name":"芝山","latitude":25.102943,"longitude":121.522486},{"name":"信義安和","latitude":25.033104,"longitude":121.552954},{"name":"南京三民","latitude":25.051441,"longitude":121.563895},{"name":"南京復興","latitude":25.052016,"longitude":121.543489},{"name":"南港","latitude":25.051968,"longitude":121.606894},{"name":"南港展覽館","latitude":25.05509,"longitude":121.617612},{"name":"南港軟體園區","latitude":25.060253,"longitude":121.616097},{"name":"南勢角","latitude":24.990059,"longitude":121.508829},{"name":"後山埤","latitude":25.044753,"longitude":121.582246},{"name":"科技大樓","latitude":25.026007,"longitude":121.543466},{"name":"紅樹林","latitude":25.154547,"longitude":121.458883},{"name":"徐匯中學","latitude":25.080318,"longitude":121.480232},{"name":"海山","latitude":24.985674,"longitude":121.448901},{"name":"迴龍","latitude":25.02185,"longitude":121.41151},{"name":"動物園","latitude":24.998135,"longitude":121.579632},{"name":"唭哩岸","latitude":25.120782,"longitude":121.506404},{"name":"國父紀念館","latitude":25.041347,"longitude":121.557578},{"name":"淡水","latitude":25.167876,"longitude":121.445622},{"name":"頂埔","latitude":24.959508,"longitude":121.418986},{"name":"頂溪","latitude":25.013559,"longitude":121.51543},{"name":"善導寺","latitude":25.044577,"longitude":121.523955},{"name":"復興崗","latitude":25.137497,"longitude":121.485266},{"name":"景平","latitude":24.991926,"longitude":121.51625},{"name":"景安","latitude":24.993731,"longitude":121.50456},{"name":"景美","latitude":24.992649,"longitude":121.540919},{"name":"港墘","latitude":25.080098,"longitude":121.575252},{"name":"菜寮","latitude":25.059851,"longitude":121.491297},{"name":"象山","latitude":25.032786,"longitude":121.569958},{"name":"圓山","latitude":25.071281,"longitude":121.520071},{"name":"新北投","latitude":25.136901,"longitude":121.50299},{"name":"新北產業園區","latitude":25.061564,"longitude":121.459774},{"name":"新店","latitude":24.95784,"longitude":121.53758},{"name":"新店區公所","latitude":24.967689,"longitude":121.541426},{"name":"新埔","latitude":25.023206,"longitude":121.46822},{"name":"新埔民生","latitude":25.026125,"longitude":121.466839},{"name":"新莊","latitude":25.036158,"longitude":121.452472},{"name":"萬芳社區","latitude":24.998581,"longitude":121.568409},{"name":"萬芳醫院","latitude":24.999383,"longitude":121.557737},{"name":"萬隆","latitude":25.001942,"longitude":121.539056},{"name":"葫洲","latitude":25.072522,"longitude":121.607633},{"name":"輔大","latitude":25.03276,"longitude":121.435904},{"name":"劍南路","latitude":25.084802,"longitude":121.555541},{"name":"劍潭","latitude":25.084196,"longitude":121.524962},{"name":"廣慈/奉天宮","latitude":25.037892,"longitude":121.582567},{"name":"橋和","latitude":25.004803,"longitude":121.490278},{"name":"頭前庄","latitude":25.039756,"longitude":121.461438},{"name":"龍山寺","latitude":25.035338,"longitude":121.500317},{"name":"雙連","latitude":25.057662,"longitude":121.520602},{"name":"關渡","latitude":25.125451,"longitude":121.467038},{"name":"蘆洲","latitude":25.091635,"longitude":121.464629},{"name":"麟光","latitude":25.018554,"longitude":121.558606}]},"fares":{"updated_at":"2026-10-08T23:57:21.408Z","fares":[{"from":"台北車站","to":"海山","fare":35,"concession_fare":14,"distance_km":11.46},{"from":"台北車站","to":"土城","fare":35,"concession_fare":14,"distance_km":12.93}]}}''';

final Map<String, dynamic> _transit = jsonDecode(_transitJson) as Map<String, dynamic>;

void _transitRoutes() {
  ManualApi.on(
    'GET',
    '/cabinets/:id/nearby',
    (_) => {
      'cabinet': {'latitude': _transit['lat'], 'longitude': _transit['lng']},
      ...(_transit['nearby'] as Map<String, dynamic>),
    },
  );
  ManualApi.on('GET', '/cabinets/mrt-stations', (_) => _transit['stations']);
  ManualApi.on('GET', '/cabinets/mrt-fares', (_) => _transit['fares']);
}

const _departure = '台北車站';

String get _openHours => Order.fromJson(_order('deposited')).cabinetOpenHours;

// ───────────── 管理後台 ─────────────

/// 新北高工書櫃裝置（比照 manual_shots/s19_test.dart 的配對截圖）：[state] 為 none、pending、online。
Map<String, dynamic> _device(String state) {
  final online = state == 'online';
  return {
    'cabinet': {
      'cabinet_id': cabinetId,
      'cabinet_name': _cabinetName,
      'is_active': true,
      'is_maintenance': false,
      'open_time': '00:00',
      'close_time': '23:59',
      'screen_brightness': 100,
    },
    'access': online ? {'mode': 'scan', 'online': true, 'open_now': true} : {'mode': 'manual', 'reason': 'no_device', 'online': false, 'open_now': true},
    'simulator_enabled': true,
    'kiosk_url': 'https://api.savemybook.today/kiosk',
    'device': online
        ? {
            'device_no': 'DV2Q85S3A',
            'kind': 'esp32',
            'status': 'active',
            'online': true,
            'last_seen_at': ago(minutes: 0),
            'paired_at': ago(minutes: 0),
            'firmware': 'esp-1.0.0',
            'door_count': 4,
            'has_door_sensor': true,
            'unlock_pulse_ms': 3000,
          }
        : null,
    'pairing': state == 'pending'
        ? {'kind': 'esp32', 'door_count': 4, 'has_door_sensor': true, 'firmware': 'esp-1.0.0', 'expires_at': ago(minutes: -10)}
        : null,
    'active_session_no': null,
    'doors': online
        ? [
            for (var i = 1; i <= 4; i++)
              {'slot_id': 700 + i, 'slot_no': 'A0$i', 'label': 'A0$i', 'channel': i, 'status': 'empty', 'check': null, 'items': <Object>[]},
          ]
        : <Object>[],
    'unplaced': <Object>[],
  };
}

/// 後台首頁統計：會員數取正式站公開資料中的會員；待審核 1 件為上架段送審的這本書，今日訂單 1 筆為本段的訂單。
void _overviewRoute() => ManualApi.on(
  'GET',
  '/admin/overview',
  (_) => {
    'member_count': realUsers.length,
    'pending_report_count': 0,
    'pending_listing_review_count': 1,
    'open_risk_alert_count': 0,
    'pending_dispute_count': 0,
    'active_cabinet_count': realCabinets.length,
    'today_order_count': 1,
    'open_ticket_count': 0,
  },
);

Finder _menuItem(String title) => find.ancestor(of: find.text(title), matching: find.byType(AppMenuItem));

/// 後台選單列：列本身透明，疊在卡片的白底上；連同卡片底色輸出，四角統一圓角。
Future<void> _cutRow(WidgetTester tester, String name, String screen, String title) async {
  final tile = find.descendant(of: _menuItem(title), matching: find.byType(ListTile));
  final box = renderOf(tester, tile);
  await cut(
    tester,
    name,
    screen: screen,
    box: box,
    // 圓角與卡片（AppCard）相同：卡片頂端與底端的列，外框圓角才會和原畫面一致
    shape: CutShape.rect(BorderRadius.circular(16)),
    backdrop: opaqueBackdropOf(box),
    clip: true,
    note: '後台選單「$title」',
  );
}

/// 依 [total] 平滑捲動並逐格截圖（真實 App 捲動，標題列固定），回傳畫面名稱。
Future<List<String>> _scrollFrames(WidgetTester tester, String prefix, double total, {int frames = 10, Finder? scrollable}) async {
  final state = tester.state<ScrollableState>(scrollable ?? find.byType(Scrollable).first);
  final start = state.position.pixels;
  final names = <String>[];
  for (var i = 1; i <= frames; i++) {
    final k = i / frames;
    final e = k * k * k * (k * (k * 6 - 15) + 10);
    state.position.jumpTo(start + total * e);
    await tester.pump();
    final name = '${prefix}_s${i.toString().padLeft(2, '0')}';
    await snapScreen(tester, name);
    names.add(name);
  }
  return names;
}

void main() {
  setUpAll(setUpManual);
  setUp(failures.clear);
  tearDownAll(writeJson);

  // ───────────── 智慧書櫃：賣家存書 ─────────────

  testWidgets('書櫃：距離太遠', variant: _ios, (tester) async {
    await videoShoot(
      tester,
      me: _seller,
      routes: () {
        _cabinetRoutes();
        ManualApi.on(
          'POST',
          '/cabinet-sessions',
          (_) => {'success': false, 'code': 'CABINET_TOO_FAR', 'message': '您目前的位置距離書櫃約 $_farMeters 公尺，請於書櫃旁操作', 'distance_m': _farMeters},
        );
      },
      home: () => CabinetFlowScreen(code: _scanCode, controller: _controller(far: true)),
      act: (tester) async {
        await settleReal(tester, const Duration(seconds: 1));
        await snapScreen(tester, 'v_cab_far');
        // 錯誤畫面的圖示與訊息（置中的一欄，沒有卡片），連同頁面底色輸出
        final message = find.textContaining('請於書櫃旁操作');
        final column = renderOf(tester, find.ancestor(of: message, matching: find.byType(Column)).first);
        debugPrint('FAR column ${column.localToGlobal(Offset.zero) & column.size}');
        await _cutPadded(tester, 'cut_cab_far', screen: 'v_cab_far', box: column, pad: const EdgeInsets.symmetric(horizontal: 10, vertical: 12), backdrop: opaqueBackdropOf(column)!, radius: 18, note: '距離書櫃太遠的提示');
        tapAt(tester, 'tap_cab_rescan', screen: 'v_cab_far', finder: find.text('重新掃描'));
      },
    );
    expect(failures, isEmpty);
  });

  testWidgets('書櫃：掃描與確認', variant: _ios, (tester) async {
    final scans = StreamController<String>();
    addTearDown(scans.close);
    await videoShoot(
      tester,
      me: _seller,
      routes: () {
        _cabinetRoutes();
        ManualApi.on('POST', '/cabinet-sessions', (_) {
          _current = () => _session('selecting', remainingMs: 59000);
          return _current();
        });
        ManualApi.on('POST', '/cabinet-sessions/:no/cancel', (_) => _session('cancelled'));
      },
      home: () => CabinetFlowScreen(scanInput: scans.stream, controller: _controller()),
      act: (tester) async {
        await settleReal(tester, const Duration(seconds: 1));
        await _scanCamera(tester, qr: 0, bar: 0.06);
        await snapScreen(tester, 'v_cab_scan_0');
        await _scanCamera(tester, qr: 1, bar: 1.0);
        await snapScreen(tester, 'v_cab_scan_1');
        systemOverlay.value = const [];

        holdApi('POST /cabinet-sessions');
        scans.add(_scanCode);
        await tester.pump();
        await untilHeld(tester);
        await settle(tester, const Duration(milliseconds: 600));
        spinnerFocus = find.byType(CabinetFlowScreen);
        await snapScreen(tester, 'v_cab_checking');
        spinnerFocus = null;
        releaseApi();
        await settleReal(tester, const Duration(seconds: 2));
        await snapScreen(tester, 'v_cab_confirm');
        tapAt(tester, 'tap_cab_open', screen: 'v_cab_confirm', finder: find.text('開啟櫃門'));
      },
    );
    expect(failures, isEmpty);
  });

  for (final (seconds, filled) in [(59, false), (58, false), (57, true)]) {
    testWidgets('書櫃：輸入數字 $seconds ${filled ? '已輸入' : '空白'}', variant: _ios, (tester) async {
      await videoShoot(
        tester,
        me: _seller,
        routes: _cabinetRoutes,
        home: () => CabinetFlowScreen(
          resume: _resume('matching', remainingMs: seconds * 1000),
          controller: _controller(),
        ),
        act: (tester) async {
          if (filled) {
            await tester.enterText(find.descendant(of: find.byType(CabinetFlowScreen), matching: find.byType(TextField)), '25');
          }
          FocusManager.instance.primaryFocus?.unfocus();
          await settle(tester, const Duration(milliseconds: 600));
          final name = filled ? 'v_cab_match_25' : 'v_cab_match_$seconds';
          await snapScreen(tester, name);
          if (filled) {
            tapAt(tester, 'tap_cab_confirm', screen: name, finder: find.text('確認'));
            final boxes = find.descendant(of: find.byType(CabinetMatchCodeField), matching: find.byType(Container));
            tapAt(tester, 'tap_cab_digit_1', screen: name, finder: boxes.at(0));
            tapAt(tester, 'tap_cab_digit_2', screen: name, finder: boxes.at(1));
          }
        },
      );
      expect(failures, isEmpty);
    });
  }

  testWidgets('書櫃：櫃門開啟中', variant: _ios, (tester) async {
    await videoShoot(
      tester,
      me: _seller,
      routes: _cabinetRoutes,
      home: () => CabinetFlowScreen(resume: _resume('opening'), controller: _controller()),
      act: (tester) async {
        await settle(tester, const Duration(milliseconds: 600));
        spinnerFocus = find.byType(CabinetFlowScreen);
        await snapScreen(tester, 'v_cab_opening');
        spinnerFocus = null;
      },
    );
    expect(failures, isEmpty);
  });

  for (final seconds in [30, 29, 28, 27]) {
    testWidgets('書櫃：櫃門已開啟 $seconds', variant: _ios, (tester) async {
      await videoShoot(
        tester,
        me: _seller,
        routes: _cabinetRoutes,
        home: () => CabinetFlowScreen(
          resume: _resume('open', remainingMs: seconds * 1000),
          controller: _controller(),
        ),
        act: (tester) async {
          await settle(tester, const Duration(milliseconds: 600));
          final name = 'v_cab_open_$seconds';
          await snapScreen(tester, name);
          if (seconds == 30) {
            final card = find.ancestor(of: find.textContaining('請將下列書籍放入櫃門'), matching: find.byType(AppCard));
            await cut(
              tester,
              'cut_cab_open_door',
              screen: name,
              box: renderOf(tester, card.first, pick: isBoxDecoration),
              note: '請將下列書籍放入櫃門 A01',
            );
            await restoreTree(tester);
          }
        },
      );
      expect(failures, isEmpty);
    });
  }

  testWidgets('書櫃：存書完成', variant: _ios, (tester) async {
    await videoShoot(
      tester,
      me: _seller,
      routes: _cabinetRoutes,
      home: () => CabinetFlowScreen(resume: _resume('completed', done: true), controller: _controller()),
      act: (tester) async {
        await settleReal(tester, const Duration(seconds: 2));
        await snapScreen(tester, 'v_cab_done');
      },
    );
    expect(failures, isEmpty);
  });

  // ───────────── 智慧書櫃：買家收到通知、前往書櫃 ─────────────

  testWidgets('書櫃：買家收到存書通知', variant: _ios, (tester) async {
    await videoShoot(
      tester,
      routes: () => ManualApi.on(
        'GET',
        '/ai/recommendations',
        (_) => {
          'success': true,
          'message': 'OK',
          'data': [
            for (final r in recommendations) {'book': bookJson(r.id), 'reason': r.reason},
          ],
          'groups': [
            {
              'kind': 'more',
              'book_ids': [for (final r in recommendations) r.id],
            },
          ],
          'meta': {'source': 'ai', 'generated_at': ago(minutes: 30), 'refreshing': false},
        },
      ),
      home: HomeScreen.new,
      act: (tester) async {
        await settleReal(tester, const Duration(seconds: 1));
        await snapScreen(tester, 'v_cab_home');
        // 後端 services/orders/index.js notifyDeposited 的標題與內容；App 在前景收到推播時顯示 in_app_banner
        showInAppBanner(
          navigatorKey.currentState!.overlay!,
          title: '書籍已存入書櫃',
          body: '訂單 $_orderNo 的書籍已存入「$_cabinetName」書櫃，請於營業時間內至書櫃以 App 掃描 QR Code 取書。',
          icon: NotificationCategory.of('order', 'order').icon,
        );
        final frames = <String>[];
        // 每 16 毫秒拍一格（約 60 fps），橫幅滑下時才不會一格一格跳
        for (var i = 1; i <= 20; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          final name = 'v_cab_banner_f$i';
          await snapScreen(tester, name, settleFirst: false);
          frames.add(name);
        }
        await tester.pump(const Duration(milliseconds: 400));
        await snapScreen(tester, 'v_cab_banner', settleFirst: false);
        recordSequence('cab_banner', [...frames, 'v_cab_banner']);
        final banner = find.text('書籍已存入書櫃');
        tapAt(tester, 'tap_cab_banner', screen: 'v_cab_banner', finder: banner);
        final card = renderOf(tester, ancestorWhere(banner, (w) => w is Container && w.decoration is BoxDecoration));
        await cut(tester, 'cut_cab_banner', screen: 'v_cab_banner', box: card, note: 'App 在前景收到的存書通知');
        await restoreTree(tester);
        // ignore: invalid_use_of_visible_for_testing_member
        resetInAppBanners();
        await tester.pump(const Duration(seconds: 1));
      },
    );
    expect(failures, isEmpty);
  });

  testWidgets('書櫃：前往書櫃交通資訊', variant: _ios, (tester) async {
    await videoShoot(
      tester,
      routes: _transitRoutes,
      prefs: const {'transit.departure_station': _departure},
      home: () => CabinetGuideScreen(cabinetId: cabinetId, name: _cabinetName, address: _cabinet['address'] as String, openHours: _openHours),
      act: (tester) async {
        await settleReal(tester, const Duration(seconds: 2));
        await snapScreen(tester, 'v_cab_guide');
        Rect cardOf(String title) =>
            tester.getRect(find.ancestor(of: find.text(title), matching: find.byWidgetPredicate((w) => w.runtimeType.toString() == '_SectionCard')).first);
        final mrt = cardOf('捷運');
        final header = tester.getRect(find.byType(AppHeader)).bottom;
        // 影片以 60 fps 播放 0.45 秒：27 格才不會一格一格跳
        final names = await _scrollFrames(tester, 'v_cab_guide', mrt.top - (header + 10), frames: 27);
        recordSequence('cab_guide_scroll', ['v_cab_guide', ...names]);
        final last = names.last;
        debugPrint('GUIDE header=$header mrt=${cardOf('捷運')} bus=${cardOf('公車')}');
        // 捷運最近車站、票價、最近的公車站牌，三者同時在畫面上；列本身透明，連同卡片底色輸出
        Future<void> row(String name, Finder text, String type, String note) async {
          final box = renderOf(tester, ancestorWhere(text, (w) => w.runtimeType.toString() == type));
          debugPrint('ROW $name ${box.localToGlobal(Offset.zero) & box.size}');
          await _cutPadded(tester, name, screen: last, box: box, pad: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), backdrop: opaqueBackdropOf(box)!, note: note);
        }

        await row('cut_cab_mrt_row', find.text('海山站'), '_TransitRow', '捷運海山站（最近出口與距離）');
        await row('cut_cab_fare', find.textContaining('到海山站'), '_FareLine', '台北車站到海山站的票價');
        await row('cut_cab_bus_stop', find.text('新北高工(學府)').first, '_BusStopTile', '最近的公車站牌與路線');
        for (final n in ['cut_cab_mrt_row', 'cut_cab_fare', 'cut_cab_bus_stop']) {
          debugPrint('CUT $n');
        }
        await restoreTree(tester);
      },
    );
    expect(failures, isEmpty);
  });

  // ───────────── 管理後台 ─────────────

  testWidgets('後台：首頁模組', variant: _ios, (tester) async {
    await videoShoot(
      tester,
      me: _admin,
      routes: () {
        ManualApi.on('GET', '/auth/me', (_) => userJson(meId, extra: {'role': 'admin'}));
        _overviewRoute();
      },
      home: AdminHomeScreen.new,
      act: (tester) async {
        await settleReal(tester, const Duration(seconds: 2));
        await snapScreen(tester, 'v_adm_home');
        // 捲到訂單管理貼齊標題列下緣，四個模組（訂單、爭議、內容審核、系統公告）同時在畫面上
        final header = tester.getRect(find.byType(AppHeader)).bottom;
        final target = tester.getRect(_menuItem('訂單管理')).top - (header + 6);
        final notice = _menuItem('系統公告');
        final names = await _scrollFrames(tester, 'v_adm_home', target, frames: 27);
        recordSequence('adm_scroll', ['v_adm_home', ...names]);
        debugPrint('ADMIN header=$header notice=${tester.getRect(notice)} orders=${tester.getRect(_menuItem('訂單管理'))}');
        for (final (title, name) in [('內容審核', 'cut_adm_review'), ('訂單管理', 'cut_adm_orders'), ('交易爭議', 'cut_adm_disputes'), ('系統公告', 'cut_adm_notice')]) {
          await _cutRow(tester, name, names.last, title);
        }
        await restoreTree(tester);
      },
    );
    expect(failures, isEmpty);
  });

  testWidgets('後台：配對書櫃裝置', variant: _ios, (tester) async {
    var state = 'none';
    await videoShoot(
      tester,
      me: _admin,
      routes: () {
        ManualApi.on('GET', '/auth/me', (_) => userJson(meId, extra: {'role': 'admin'}));
        ManualApi.on('GET', '/admin/cabinets/$cabinetId/device', (_) => _device(state));
        ManualApi.on('GET', '/security', (_) => {'available': true, 'has_password': true, 'has_payment_pin': true, 'passkey_available': false});
        ManualApi.on('POST', '/security/verify', (_) => {'verify_token': 'video-verify-token'});
        ManualApi.on('POST', '/admin/cabinets/$cabinetId/device/pair', (_) {
          state = 'pending';
          return {'kind': 'esp32', 'door_count': 4, 'has_door_sensor': true, 'firmware': 'esp-1.0.0', 'summary': _device('pending')};
        });
      },
      home: () => AdminCabinetDeviceScreen(cabinetId: cabinetId, cabinetName: _cabinetName),
      act: (tester) async {
        await settleReal(tester, const Duration(seconds: 1));
        await snapScreen(tester, 'v_adm_device');
        tapAt(tester, 'tap_adm_pair_open', screen: 'v_adm_device', finder: find.text('配對裝置'));
        await tapAndSettle(tester, find.text('配對裝置'));
        await tester.enterText(find.byType(TextField).last, 'video-password');
        await tapAndSettle(tester, find.text('驗證身分').last, duration: const Duration(seconds: 2));
        s19ShowKeyboard(tester, const S19NumberPad(), height: numberPadHeight);
        await settleReal(tester, const Duration(milliseconds: 600));
        await snapScreen(tester, 'v_adm_pair_t00');
        final field = find.descendant(of: find.byType(Dialog), matching: find.byType(TextField));
        // 配對碼輸入框：每輸入一個數字就輸出一次（影片中浮出放大，跟著逐字更新）
        final decorator = find.descendant(of: field, matching: find.byType(InputDecorator));
        Future<void> cutField(String name, String screen) async {
          final decoration = tester.widget<InputDecorator>(decorator).decoration;
          final border = decoration.focusedBorder ?? decoration.enabledBorder ?? decoration.border;
          await cut(
            tester,
            name,
            screen: screen,
            box: renderOf(tester, decorator),
            shape: border is OutlineInputBorder ? CutShape.rect(border.borderRadius) : null,
            backdrop: opaqueBackdropOf(renderOf(tester, decorator)),
            note: '配對碼輸入框',
          );
        }

        await cutField('cut_adm_field_t00', 'v_adm_pair_t00');
        final typed = <String>[];
        const code = '01517752';
        for (var i = 1; i <= code.length; i++) {
          await tester.enterText(field, code.substring(0, i));
          await settle(tester, const Duration(milliseconds: 300));
          final name = 'v_adm_pair_t${i.toString().padLeft(2, '0')}';
          await snapScreen(tester, name);
          typed.add(name);
          await cutField('cut_adm_field_t${i.toString().padLeft(2, '0')}', name);
        }
        await restoreTree(tester);
        recordSequence('adm_pair_type', ['v_adm_pair_t00', ...typed]);
        final confirm = find.descendant(of: find.byType(Dialog), matching: find.text('配對裝置')).last;
        tapAt(tester, 'tap_adm_pair', screen: typed.last, finder: confirm);

        s19HideKeyboard(tester);
        await tapAndSettle(tester, confirm, duration: const Duration(seconds: 2));
        await tester.pump(const Duration(milliseconds: 300));
        spinnerFocus = find.byType(AdminCabinetPairingDialog);
        await snapScreen(tester, 'v_adm_pair_wait');
        spinnerFocus = null;
        state = 'online';
        await settleReal(tester, const Duration(milliseconds: 3500));
        await snapScreen(tester, 'v_adm_pair_done');
      },
    );
    expect(failures, isEmpty);
  });
}
