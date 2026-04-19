import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../utils/app_colors.dart';

class PickupBookScreen extends StatefulWidget {
  final bool isActive;
  const PickupBookScreen({super.key, this.isActive = false});

  @override
  State<PickupBookScreen> createState() => _PickupBookScreenState();
}

class _PickupBookScreenState extends State<PickupBookScreen> {
  MobileScannerController? _controller;
  bool _scanned = false;

  @override
  void didUpdateWidget(covariant PickupBookScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _startCamera();
    } else if (!widget.isActive && oldWidget.isActive) {
      _stopCamera();
    }
  }

  void _startCamera() {
    _controller?.dispose();
    _controller = MobileScannerController(formats: [BarcodeFormat.qrCode]);
    _scanned = false;
    if (mounted) setState(() {});
  }

  void _stopCamera() {
    _controller?.dispose();
    _controller = null;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue != null) {
      setState(() => _scanned = true);
      _handleScanResult(barcode!.rawValue!);
    }
  }

  void _handleScanResult(String value) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final c = AppColors.of(ctx);
        return AlertDialog(
          backgroundColor: c.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('掃描成功', style: TextStyle(fontWeight: FontWeight.bold, color: c.textPrimary)),
          content: Text(value, style: TextStyle(color: c.textSecondary)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() => _scanned = false);
              },
              child: const Text('繼續掃描', style: TextStyle(color: AppColors.primary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('確認', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_controller != null)
            MobileScanner(controller: _controller!, onDetect: _onDetect),

          Column(
            children: [
              Container(
                padding: EdgeInsets.only(top: topPadding + 8, bottom: 12, left: 16, right: 16),
                decoration: BoxDecoration(color: c.headerBg),
                child: Row(
                  children: [
                    const SizedBox(width: 22),
                    const Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text('我要取書', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 22),
                  ],
                ),
              ),
              const Spacer(flex: 2),
              Text('請將 QR Code 放入鏡頭內', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white.withOpacity(0.9))),
              const SizedBox(height: 8),
              Text('對準勿搖晃', style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.6))),
              const SizedBox(height: 40),
              SizedBox(
                width: 220, height: 220,
                child: CustomPaint(painter: _CornerFramePainter(color: Colors.white.withOpacity(0.85), cornerLength: 50, strokeWidth: 5, radius: 16)),
              ),
              const Spacer(flex: 3),
            ],
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