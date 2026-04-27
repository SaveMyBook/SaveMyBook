import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: [BarcodeFormat.ean13, BarcodeFormat.ean8],
  );
  bool _hasPopped = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasPopped) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue != null) {
      _hasPopped = true;
      Navigator.pop(context, barcode!.rawValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.black.withOpacity(0.5), Colors.transparent, Colors.transparent, Colors.black.withOpacity(0.5)],
                stops: const [0.0, 0.3, 0.7, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Padding(padding: EdgeInsets.all(4.0), child: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 22)),
                      ),
                      const Expanded(child: Text('掃描 ISBN', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
                      const SizedBox(width: 30),
                    ],
                  ),
                ),
                const Spacer(),
                const Text('將條碼放入框內自動掃描', style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 16),
                SizedBox(
                  width: 280, height: 160,
                  child: CustomPaint(painter: _CornerFramePainter(color: Colors.white, cornerLength: 30, strokeWidth: 4, radius: 12)),
                ),
                const Spacer(),
                const SizedBox(height: 60),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CornerFramePainter extends CustomPainter {
  final Color color;
  final double cornerLength;
  final double strokeWidth;
  final double radius;

  _CornerFramePainter({required this.color, required this.cornerLength, required this.strokeWidth, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;
    final r = radius;
    final cl = cornerLength;

    canvas.drawPath(Path()..moveTo(0, cl)..lineTo(0, r)..quadraticBezierTo(0, 0, r, 0)..lineTo(cl, 0), paint);
    canvas.drawPath(Path()..moveTo(w - cl, 0)..lineTo(w - r, 0)..quadraticBezierTo(w, 0, w, r)..lineTo(w, cl), paint);
    canvas.drawPath(Path()..moveTo(0, h - cl)..lineTo(0, h - r)..quadraticBezierTo(0, h, r, h)..lineTo(cl, h), paint);
    canvas.drawPath(Path()..moveTo(w - cl, h)..lineTo(w - r, h)..quadraticBezierTo(w, h, w, h - r)..lineTo(w, h - cl), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}