import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../i18n/strings.dart';
import '../../widgets/animations.dart';
import '../../utils/app_info.dart';

class BarcodeScannerScreen extends StatefulWidget {
  final List<BarcodeFormat> formats;
  final String? title;
  final String? hint;

  const BarcodeScannerScreen({
    super.key,
    this.formats = const [BarcodeFormat.ean13, BarcodeFormat.ean8],
    this.title,
    this.hint,
  });

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  late final MobileScannerController _controller =
      MobileScannerController(formats: widget.formats);
  bool _hasPopped = false;

  bool get _isQrMode => widget.formats.contains(BarcodeFormat.qrCode);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasPopped) return;
    final barcode = capture.barcodes.firstOrNull;
    final value = barcode?.rawValue;
    if (value == null || value.isEmpty) return;
    _hasPopped = true;
    HapticFeedback.mediumImpact();
    Navigator.pop(context, value);
  }

  Widget _buildError(BuildContext context, MobileScannerException error) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(denied ? Icons.no_photography_outlined : Icons.videocam_off_outlined, color: Colors.white70, size: 56),
              const SizedBox(height: 16),
              Text(
                denied ? S.cameraAccessOff : S.couldNotStartCamera,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                denied ? S.allowP0UseCameraSettingsThen(kAppName) : S.closeScreenTryAgain,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(S.actionClose),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error, _) => _buildError(context, error),
          ),
          IgnorePointer(
            child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.black.withValues(alpha: 0.5), Colors.transparent, Colors.transparent, Colors.black.withValues(alpha: 0.5)],
                stops: const [0.0, 0.3, 0.7, 1.0],
              ),
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
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 22),
                      ),
                      Expanded(
                        child: Text(
                          widget.title ?? S.scanBarcode,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      ValueListenableBuilder<MobileScannerState>(
                        valueListenable: _controller,
                        builder: (context, state, _) {
                          final available = state.isInitialized && state.torchState != TorchState.unavailable;
                          final on = state.torchState == TorchState.on;
                          return AnimatedOpacity(
                            opacity: available ? 1 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: IconButton(
                              onPressed: available ? () => _controller.toggleTorch() : null,
                              icon: Icon(
                                on ? Icons.flashlight_on_rounded : Icons.flashlight_off_rounded,
                                color: on ? Colors.amber : Colors.white,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    widget.hint ?? S.lineUpBarcodeSpineWithFrame,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 16),
                IgnorePointer(
                  child: Breathe(
                    amount: 0.02,
                    child: SizedBox(
                      width: _isQrMode ? 260 : 280,
                      height: _isQrMode ? 260 : 160,
                      child: CustomPaint(painter: _CornerFramePainter(color: Colors.white, cornerLength: 30, strokeWidth: 4, radius: 12)),
                    ),
                  ),
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