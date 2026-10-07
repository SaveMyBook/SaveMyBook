// 第 7、8 節截圖用的模擬畫面：書櫃相機畫面疊加層、地圖 App 的大眾運輸路線畫面。

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// 相機畫面：以 screen 混合畫在 App 的黑色掃描區上，掃描框與文字仍清楚可見；[exclude] 範圍（例如可取書卡片）不畫。
class CameraLayer extends StatelessWidget {
  final ui.Image image;
  final Rect rect;
  final List<Rect> blackouts;
  final List<RRect> exclude;

  const CameraLayer({super.key, required this.image, required this.rect, this.blackouts = const [], this.exclude = const []});

  @override
  Widget build(BuildContext context) =>
      IgnorePointer(child: CustomPaint(size: Size.infinite, painter: _CameraPainter(image, rect, blackouts, exclude)));
}

class _CameraPainter extends CustomPainter {
  final ui.Image image;
  final Rect rect;
  final List<Rect> blackouts;
  final List<RRect> exclude;

  const _CameraPainter(this.image, this.rect, this.blackouts, this.exclude);

  @override
  void paint(Canvas canvas, Size size) {
    for (final r in blackouts) {
      canvas.drawRect(r, Paint()..color = const Color(0xFF000000));
    }
    canvas.save();
    if (exclude.isNotEmpty) {
      final path = Path()..addRect(rect);
      for (final r in exclude) {
        path.addRRect(r);
      }
      path.fillType = PathFillType.evenOdd;
      canvas.clipPath(path);
    }
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      rect,
      Paint()
        ..blendMode = BlendMode.screen
        ..filterQuality = FilterQuality.high,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CameraPainter oldDelegate) => true;
}

// ---------------------------------------------------------------------------
// 地圖 App：由書櫃頁點「導航」後開啟的大眾運輸路線（淺色）。座標以經緯度換算，涵蓋土城至內湖一帶。

typedef LatLng = (double, double);

const _mapLon0 = 121.3934;
const _mapLat0 = 25.1737;
const _pxPerLon = 1900.0;
const _pxPerLat = 2097.0;

Offset _px(LatLng p) => Offset((p.$2 - _mapLon0) * _pxPerLon, (_mapLat0 - p.$1) * _pxPerLat);

const _haishan = (24.9853, 121.4487);
const _cabinet = (25.0328, 121.5476);

const _bl = [
  (24.9600, 121.4205), (24.9668, 121.4363), _haishan, (24.9980, 121.4524), (25.0085, 121.4593), (25.0141, 121.4625),
  (25.0233, 121.4683), (25.0300, 121.4721), (25.0353, 121.4999), (25.0421, 121.5081), (25.0462, 121.5175),
  (25.0447, 121.5231), (25.0424, 121.5329), (25.0416, 121.5437), (25.0413, 121.5512), (25.0413, 121.5577),
  (25.0411, 121.5651), (25.0450, 121.5760), (25.0510, 121.5860), (25.0520, 121.6070),
];
const _br = [
  (24.9980, 121.5730), (25.0050, 121.5570), (25.0180, 121.5440), (25.0262, 121.5435), (25.0330, 121.5434),
  (25.0416, 121.5437), (25.0520, 121.5440), (25.0610, 121.5440), (25.0630, 121.5520), (25.0680, 121.5520),
  (25.0800, 121.5460), (25.0840, 121.5560), (25.0800, 121.5750), (25.0830, 121.5940),
];
const _r = [
  (25.1370, 121.5020), (25.1200, 121.5070), (25.0920, 121.5180), (25.0630, 121.5200), (25.0526, 121.5205),
  (25.0462, 121.5175), (25.0412, 121.5163), (25.0327, 121.5183), (25.0337, 121.5287), (25.0336, 121.5357),
  (25.0330, 121.5434), (25.0333, 121.5531), (25.0331, 121.5630), (25.0329, 121.5700),
];
const _g = [
  (24.9580, 121.5380), (24.9750, 121.5420), (25.0146, 121.5343), (25.0262, 121.5229), (25.0327, 121.5183),
  (25.0421, 121.5081), (25.0496, 121.5103), (25.0526, 121.5205), (25.0520, 121.5330), (25.0520, 121.5440),
  (25.0516, 121.5520), (25.0500, 121.5780),
];
const _o = [
  (24.9900, 121.5090), (25.0140, 121.5150), (25.0262, 121.5229), (25.0337, 121.5287), (25.0424, 121.5329),
  (25.0520, 121.5330), (25.0610, 121.5330), (25.0630, 121.5250), (25.0627, 121.5130), (25.0630, 121.4980),
  (25.0700, 121.4880), (25.0850, 121.4720),
];
const _y = [
  (24.9750, 121.5420), (24.9900, 121.5260), (24.9930, 121.5040), (25.0000, 121.4850), (25.0141, 121.4625),
  (25.0300, 121.4700), (25.0450, 121.4620), (25.0600, 121.4560),
];

const _tamsui = [(25.0350, 121.4880), (25.0500, 121.5030), (25.0650, 121.5050), (25.0800, 121.5050), (25.0950, 121.4950), (25.1100, 121.4750), (25.1300, 121.4600), (25.1600, 121.4400)];
const _dahan = [(24.9400, 121.3950), (24.9600, 121.4100), (24.9850, 121.4250), (25.0050, 121.4430), (25.0200, 121.4590), (25.0300, 121.4750), (25.0350, 121.4880)];
const _xindian = [(24.9400, 121.5350), (24.9650, 121.5400), (24.9850, 121.5350), (25.0050, 121.5220), (25.0150, 121.5100), (25.0250, 121.5000), (25.0350, 121.4880)];
const _keelung = [
  (25.0600, 121.6300), (25.0700, 121.6000), (25.0780, 121.5800), (25.0720, 121.5650), (25.0800, 121.5500), (25.0850, 121.5400),
  (25.0780, 121.5300), (25.0830, 121.5180), (25.0900, 121.5080), (25.0950, 121.4950),
];
const _jingmei = [(24.9500, 121.5700), (24.9750, 121.5580), (24.9900, 121.5450), (25.0050, 121.5300)];

const _fwy1 = [(25.1100, 121.3950), (25.0830, 121.4400), (25.0700, 121.4700), (25.0680, 121.5000), (25.0750, 121.5250), (25.0720, 121.5550), (25.0650, 121.5850), (25.0600, 121.6200)];
const _fwy3 = [(24.9800, 121.3950), (24.9820, 121.4300), (24.9780, 121.4600), (24.9850, 121.4850), (24.9800, 121.5150), (24.9700, 121.5400), (24.9900, 121.5700), (25.0000, 121.6100)];
const _expressways = [
  [(25.0480, 121.4400), (25.0400, 121.4650), (25.0320, 121.4820), (25.0300, 121.5000)],
  [(25.0460, 121.5050), (25.0460, 121.5300), (25.0460, 121.5550), (25.0490, 121.5800)],
  [(25.0250, 121.5370), (25.0400, 121.5370), (25.0550, 121.5370), (25.0700, 121.5370)],
  [(25.0050, 121.5130), (25.0200, 121.4950), (25.0400, 121.4880), (25.0600, 121.4960), (25.0750, 121.4990)],
  [(24.9950, 121.4450), (25.0050, 121.4700), (25.0000, 121.4950), (24.9950, 121.5200)],
];

const _parks = [
  (25.0300, 121.5355, 0.0055, 0.0045),
  (25.0400, 121.5210, 0.0030, 0.0025),
  (25.0700, 121.5240, 0.0040, 0.0040),
  (25.0090, 121.4600, 0.0030, 0.0030),
  (25.0950, 121.5600, 0.0200, 0.0150),
  (25.0050, 121.5800, 0.0150, 0.0120),
  (25.0880, 121.4200, 0.0180, 0.0120),
];

const _districts = [
  ('五股區', (25.0880, 121.4380)), ('蘆洲區', (25.0890, 121.4730)), ('泰山區', (25.0560, 121.4300)), ('三重區', (25.0630, 121.4880)),
  ('新莊區', (25.0360, 121.4230)), ('板橋區', (25.0110, 121.4480)), ('中和區', (24.9990, 121.4960)), ('永和區', (25.0080, 121.5160)),
  ('萬華區', (25.0270, 121.4930)), ('新店區', (24.9700, 121.5300)), ('文山區', (24.9930, 121.5680)), ('樹林區', (24.9910, 121.4130)),
  ('土城區', (24.9740, 121.4450)), ('松山區', (25.0560, 121.5620)), ('內湖區', (25.0800, 121.5960)), ('大同區', (25.0650, 121.5110)),
  ('中山區', (25.0700, 121.5330)), ('士林區', (25.0990, 121.5260)), ('信義區', (25.0300, 121.5790)),
];

class _MapPainter extends CustomPainter {
  const _MapPainter();

  void _line(Canvas canvas, List<LatLng> points, Paint paint) {
    final path = Path()..moveTo(_px(points.first).dx, _px(points.first).dy);
    for (var i = 1; i < points.length; i++) {
      final a = _px(points[i - 1]);
      final b = _px(points[i]);
      final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
      path.quadraticBezierTo(a.dx, a.dy, mid.dx, mid.dy);
    }
    path.lineTo(_px(points.last).dx, _px(points.last).dy);
    canvas.drawPath(path, paint);
  }

  Paint _stroke(Color color, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  void _label(Canvas canvas, String text, Offset at, {double size = 13, Color color = const Color(0xFF5F6368), FontWeight weight = FontWeight.w500, bool center = true}) {
    final halo = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'NotoSansTC',
          fontSize: size,
          fontWeight: weight,
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = const Color(0xE6FFFFFF),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final fill = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontFamily: 'NotoSansTC', fontSize: size, fontWeight: weight, color: color)),
      textDirection: TextDirection.ltr,
    )..layout();
    final o = center ? at - Offset(fill.width / 2, fill.height / 2) : at - Offset(0, fill.height / 2);
    halo.paint(canvas, o);
    fill.paint(canvas, o);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFF2EFE9));
    // 市區街廓
    final urban = Paint()..color = const Color(0xFFE9E6E0);
    canvas.drawPath(
      Path()
        ..addOval(Rect.fromCenter(center: _px((25.045, 121.530)), width: 230, height: 150))
        ..addOval(Rect.fromCenter(center: _px((25.010, 121.480)), width: 150, height: 110)),
      urban,
    );
    for (final (lat, lon, dLat, dLon) in _parks) {
      final a = _px((lat + dLat, lon - dLon));
      final b = _px((lat - dLat, lon + dLon));
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromPoints(a, b), const Radius.circular(6)), Paint()..color = const Color(0xFFCDE8C4));
    }
    // 山區
    final hills = Paint()..color = const Color(0xFFDDEBD3);
    canvas.drawOval(Rect.fromCenter(center: _px((25.135, 121.545)), width: 260, height: 90), hills);
    canvas.drawOval(Rect.fromCenter(center: _px((24.975, 121.600)), width: 160, height: 120), hills);
    // 河川
    final water = _stroke(const Color(0xFFAAD3EE), 9);
    for (final river in [_tamsui, _dahan, _xindian]) {
      _line(canvas, river, water);
    }
    _line(canvas, _keelung, _stroke(const Color(0xFFAAD3EE), 6));
    _line(canvas, _jingmei, _stroke(const Color(0xFFAAD3EE), 4));
    // 一般道路網
    const jitter = [0.0, 0.0031, -0.0022, 0.0040, -0.0035, 0.0012, -0.0008, 0.0027];
    var k = 0;
    for (var lat = 24.95; lat < 25.17; lat += 0.0125) {
      final j = jitter[k++ % jitter.length];
      _line(canvas, [(lat + j, 121.39), (lat + 0.003 - j, 121.47), (lat + j * 0.5, 121.53), (lat - 0.002, 121.61)], _stroke(Colors.white, k.isEven ? 2.2 : 1.2));
    }
    k = 0;
    for (var lon = 121.40; lon < 121.61; lon += 0.0140) {
      final j = jitter[(k++ * 3) % jitter.length];
      _line(canvas, [(24.94, lon + j), (25.00, lon - j), (25.07, lon + 0.003), (25.18, lon - 0.002 + j)], _stroke(Colors.white, k.isEven ? 2.2 : 1.2));
    }
    // 快速道路與國道
    for (final road in _expressways) {
      _line(canvas, road, _stroke(const Color(0xFFE8C66A), 4));
      _line(canvas, road, _stroke(const Color(0xFFFFE9A6), 2.4));
    }
    for (final road in [_fwy1, _fwy3]) {
      _line(canvas, road, _stroke(const Color(0xFFE0A93B), 5));
      _line(canvas, road, _stroke(const Color(0xFFFCD27A), 3.2));
    }
    // 捷運路線
    for (final (line, color) in [
      (_r, const Color(0xFFE3002C)),
      (_g, const Color(0xFF008659)),
      (_o, const Color(0xFFF8B61C)),
      (_y, const Color(0xFFFFDB00)),
      (_br, const Color(0xFFC48C31)),
      (_bl, const Color(0xFF0070BD)),
    ]) {
      _line(canvas, line, _stroke(color.withValues(alpha: 0.75), 2.2));
    }
    for (final (name, p) in _districts) {
      _label(canvas, name, _px(p), size: 12.5);
    }
    _label(canvas, '新北', _px((25.0730, 121.4570)), size: 16, color: const Color(0xFF3C4043), weight: FontWeight.w600);
    _label(canvas, '臺北松山機場', _px((25.0700, 121.5520)) + const Offset(0, -12), size: 12, color: const Color(0xFF1A73E8));
    canvas.drawCircle(_px((25.0700, 121.5520)) + const Offset(42, -12), 8, Paint()..color = const Color(0xFF1A73E8));
    _label(canvas, '✈', _px((25.0700, 121.5520)) + const Offset(42, -12), size: 9, color: Colors.white, weight: FontWeight.w700);
    _label(canvas, '國立故宮博物院', _px((25.1020, 121.5485)), size: 12, color: const Color(0xFF7B5E3B));

    // 路線：步行至海山站 → 板南線 → 忠孝復興轉文湖線 → 大安站 → 步行至書櫃
    final route = _bl.sublist(2, 14);
    _line(canvas, route, _stroke(const Color(0xFF1967D2), 9));
    _line(canvas, route, _stroke(const Color(0xFF4A8AF4), 6));
    final brPart = [(25.0416, 121.5437), (25.0370, 121.5436), (25.0330, 121.5434)];
    _line(canvas, brPart, _stroke(const Color(0xFF8C5E14), 9));
    _line(canvas, brPart, _stroke(const Color(0xFFC48C31), 6));
    final walk = Paint()..color = const Color(0xFF4A8AF4);
    final a = _px((25.0330, 121.5434));
    final b = _px(_cabinet);
    for (var t = 0.15; t < 1; t += 0.28) {
      canvas.drawCircle(Offset.lerp(a, b, t)!, 1.6, walk);
    }
    for (final (station, label, dx) in [((25.0416, 121.5437), '忠孝復興', -34.0), ((25.0330, 121.5434), '', 0.0)]) {
      final p = _px(station);
      canvas.drawCircle(p, 5, Paint()..color = Colors.white);
      canvas.drawCircle(p, 5, _stroke(const Color(0xFF3C4043), 1.6));
      if (label.isNotEmpty) _label(canvas, label, p + Offset(dx, -12), size: 12.5, color: const Color(0xFF202124), weight: FontWeight.w700);
    }
    _label(canvas, '大安', _px(_cabinet) + const Offset(22, 6), size: 13, color: const Color(0xFF202124), weight: FontWeight.w700);
    _label(canvas, '海山', _px(_haishan) + const Offset(24, -4), size: 13, color: const Color(0xFF202124), weight: FontWeight.w700);

    // 目前位置
    final here = _px(_haishan);
    canvas.drawCircle(here, 24, Paint()..color = const Color(0x334285F4));
    canvas.drawCircle(here, 10, Paint()..color = Colors.white);
    canvas.drawCircle(here, 7, Paint()..color = const Color(0xFF1A73E8));
    // 目的地圖釘
    final pin = _px(_cabinet);
    final head = pin + const Offset(0, -24);
    final pinPath = Path()
      ..moveTo(pin.dx, pin.dy)
      ..quadraticBezierTo(pin.dx - 4, pin.dy - 10, head.dx - 10, head.dy + 4)
      ..arcToPoint(Offset(head.dx + 10, head.dy + 4), radius: const Radius.circular(11), largeArc: true)
      ..quadraticBezierTo(pin.dx + 4, pin.dy - 10, pin.dx, pin.dy)
      ..close();
    canvas.drawPath(pinPath.shift(const Offset(0, 1.5)), Paint()..color = const Color(0x40000000));
    canvas.drawPath(pinPath, Paint()..color = const Color(0xFFEA4335));
    canvas.drawCircle(head + const Offset(0, 1), 3.6, Paint()..color = const Color(0xFFB31412));
  }

  @override
  bool shouldRepaint(_MapPainter oldDelegate) => false;
}

/// 地圖 App 的大眾運輸路線畫面（點書櫃頁「導航」後跳轉）。左上角為 iOS 返回原 App 的「◀ 救舊我的書」。
class MapsTransitScreen extends StatelessWidget {
  const MapsTransitScreen({super.key});

  static const _text = TextStyle(fontFamily: 'NotoSansTC', color: Color(0xFF202124), decoration: TextDecoration.none);
  static const _grey = Color(0xFF5F6368);

  Widget _round(IconData icon, {double size = 40, Color color = const Color(0xFF3C4043), Color bg = Colors.white}) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: bg,
      shape: BoxShape.circle,
      boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 1))],
    ),
    child: Icon(icon, size: size * 0.5, color: color),
  );

  Widget _chip(String label, Color bg, {Color fg = Colors.white}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
    child: Text(label, style: _text.copyWith(fontSize: 12, fontWeight: FontWeight.w700, color: fg, height: 1.25)),
  );

  Widget _walk(int minutes) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        padding: const EdgeInsets.fromLTRB(3, 1, 4, 1),
        decoration: BoxDecoration(border: Border.all(color: const Color(0xFFDADCE0)), borderRadius: BorderRadius.circular(4)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.directions_walk_rounded, size: 16, color: Color(0xFF3C4043)),
            Text('$minutes', style: _text.copyWith(fontSize: 10, color: _grey, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    ],
  );

  Widget get _arrow => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 4),
    child: Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF80868B)),
  );

  Widget _option({required String minutes, required String time, required List<Widget> steps}) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(minutes, style: _text.copyWith(fontSize: 19, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('\$40', style: _text.copyWith(fontSize: 13, color: _grey)),
          ],
        ),
        const SizedBox(height: 2),
        Text(time, style: _text.copyWith(fontSize: 13, color: const Color(0xFF3C4043))),
        const SizedBox(height: 8),
        Row(children: steps),
        const SizedBox(height: 8),
        Text('每 8 分鐘一班從海山發車', style: _text.copyWith(fontSize: 13, color: _grey)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    const divider = Divider(height: 1, thickness: 1, color: Color(0xFFE8EAED));
    final bl = _chip('BL', const Color(0xFF0070BD));
    final line = _chip('板南線', const Color(0xFF0070BD));
    return DefaultTextStyle(
      style: _text,
      child: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: _MapPainter())),
          Positioned(
            left: 10,
            top: 36,
            child: Row(
              children: [
                const Icon(Icons.arrow_left_rounded, size: 18, color: Color(0xFF202124)),
                Text('救舊我的書', style: _text.copyWith(fontSize: 11.5, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            top: 68,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 2))],
              ),
              child: Column(
                children: [
                  SizedBox(
                    height: 40,
                    child: Row(
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A73E8),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 2)],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text('你的位置', style: _text.copyWith(fontSize: 15, color: const Color(0xFF1A73E8))),
                        const Spacer(),
                        const Icon(Icons.more_horiz_rounded, color: Color(0xFF3C4043)),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      SizedBox(
                        width: 14,
                        child: Column(
                          children: [
                            for (var i = 0; i < 3; i++)
                              const Padding(padding: EdgeInsets.symmetric(vertical: 1.5), child: CircleAvatar(radius: 1.3, backgroundColor: Color(0xFF9AA0A6))),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(child: Container(height: 1, color: const Color(0xFFE8EAED))),
                    ],
                  ),
                  SizedBox(
                    height: 40,
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 18, color: Color(0xFFEA4335)),
                        const SizedBox(width: 14),
                        Text('已放置圖釘', style: _text.copyWith(fontSize: 15)),
                        const Spacer(),
                        const Icon(Icons.swap_vert_rounded, color: Color(0xFF3C4043)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(right: 14, top: 192, child: _round(Icons.layers_outlined, size: 42, color: const Color(0xFF1A73E8))),
          Positioned(
            left: 16,
            top: 400,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 2),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFB9D3EA), Color(0xFFD9D6CC), Color(0xFF8E8A80)],
                  stops: [0, 0.55, 1],
                ),
                boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 4)],
              ),
              alignment: Alignment.bottomLeft,
              padding: const EdgeInsets.all(4),
              child: const Icon(Icons.threesixty_rounded, size: 18, color: Colors.white),
            ),
          ),
          Positioned(right: 14, top: 410, child: _round(Icons.my_location_rounded, size: 46, color: const Color(0xFF1A73E8))),
          Positioned(
            left: 0,
            right: 0,
            top: 472,
            bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 10, offset: Offset(0, -2))],
              ),
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 8),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(color: const Color(0xFFDADCE0), borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 16, 6),
                    child: Row(
                      children: [
                        Text('大眾運輸', style: _text.copyWith(fontSize: 21, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        _round(Icons.tune_rounded, size: 36, bg: const Color(0xFFF1F3F4)),
                        const SizedBox(width: 12),
                        _round(Icons.ios_share_rounded, size: 36, bg: const Color(0xFFF1F3F4)),
                        const SizedBox(width: 12),
                        _round(Icons.close_rounded, size: 36, bg: const Color(0xFFF1F3F4)),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 44,
                    child: Row(
                      children: [
                        for (final (icon, label, selected) in [
                          (Icons.directions_car_outlined, '29 分鐘', false),
                          (Icons.two_wheeler_rounded, '33 分鐘', false),
                          (Icons.directions_transit_outlined, '58 分鐘', true),
                          (Icons.directions_walk_rounded, '3 小時 7…', false),
                        ])
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border(bottom: BorderSide(color: selected ? const Color(0xFF1A73E8) : Colors.transparent, width: 3)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(icon, size: 18, color: selected ? const Color(0xFF1A73E8) : const Color(0xFF3C4043)),
                                  const SizedBox(width: 6),
                                  Text(
                                    label,
                                    style: _text.copyWith(
                                      fontSize: 12.5,
                                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                                      color: selected ? const Color(0xFF1A73E8) : const Color(0xFF3C4043),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  divider,
                  SizedBox(
                    height: 52,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(right: 12),
                          child: Icon(Icons.refresh_rounded, color: Color(0xFF3C4043)),
                        ),
                        for (final label in ['出發時間：晚上 11:33', '交通工具', '篩選條件'])
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.fromLTRB(12, 0, 6, 0),
                            decoration: BoxDecoration(border: Border.all(color: const Color(0xFFDADCE0)), borderRadius: BorderRadius.circular(8)),
                            child: Row(
                              children: [
                                Text(label, style: _text.copyWith(fontSize: 13, color: const Color(0xFF3C4043))),
                                const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF3C4043)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  _option(
                    minutes: '58 分鐘',
                    time: '晚上 11:33 - 凌晨 12:31 (週三)',
                    steps: [_walk(11), _arrow, bl, const SizedBox(width: 4), line, _arrow, _chip('BR', const Color(0xFFC48C31)), const SizedBox(width: 4), _chip('文湖線', const Color(0xFFC48C31)), _arrow, _walk(7)],
                  ),
                  divider,
                  _option(
                    minutes: '55 分鐘',
                    time: '晚上 11:33 - 凌晨 12:28 (週三)',
                    steps: [_walk(11), _arrow, bl, const SizedBox(width: 4), line, _arrow, _walk(22)],
                  ),
                ],
              ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
