import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../i18n/strings.dart';
import '../../utils/app_info.dart';

bool get cabinetPasteEnabled => kDebugMode || const bool.fromEnvironment('CABINET_PASTE');

Future<String?> readClipboardText() async {
  try {
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim();
    return text == null || text.isEmpty ? null : text;
  } catch (_) {
    return null;
  }
}

// mobile_scanner 的平台層只有一個相機實例：前一個控制器尚未完全釋放時，另一個控制器啟動會丟出
// controllerAlreadyInitialized（除錯模式會先強制停止，所以只在正式版出現）。
class CabinetCamera {
  const CabinetCamera._();

  static Future<void> _released = Future<void>.value();
  static final Expando<Future<void>> _starts = Expando();
  static final Expando<bool> _retired = Expando();

  static MobileScannerController create() => MobileScannerController(formats: const [BarcodeFormat.qrCode], autoStart: false);

  static Future<void> start(MobileScannerController controller) => _starts[controller] = _start(controller);

  static Future<void> _start(MobileScannerController controller) async {
    Future<void> pending;
    do {
      pending = _released;
      await pending;
      if (_retired[controller] == true) return;
    } while (!identical(pending, _released));
    try {
      await controller.start();
    } catch (_) {}
  }

  static void release(MobileScannerController? controller) {
    if (controller == null || _retired[controller] == true) return;
    _retired[controller] = true;
    final starting = _starts[controller] ?? Future<void>.value();
    final disposed = starting.then((_) => controller.dispose()).catchError((Object _) {});
    _released = Future.wait([_released, disposed]).then((_) {});
  }
}

class CabinetScannerView extends StatefulWidget {
  final ValueChanged<String> onScan;
  final Stream<String>? scanInput;
  final String? hint;

  const CabinetScannerView({super.key, required this.onScan, this.scanInput, this.hint});

  @visibleForTesting
  static Stream<String>? debugScanInput;

  @override
  State<CabinetScannerView> createState() => _CabinetScannerViewState();
}

class _CabinetScannerViewState extends State<CabinetScannerView> {
  MobileScannerController? _controller;
  StreamSubscription<String>? _input;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    final input = widget.scanInput ?? CabinetScannerView.debugScanInput;
    if (input != null) {
      _input = input.listen(_handle);
    } else {
      final controller = CabinetCamera.create();
      _controller = controller;
      unawaited(CabinetCamera.start(controller));
    }
  }

  @override
  void dispose() {
    unawaited(_input?.cancel());
    CabinetCamera.release(_controller);
    super.dispose();
  }

  void _handle(String raw) {
    if (_done || !mounted || raw.trim().isEmpty) return;
    _done = true;
    HapticFeedback.mediumImpact();
    widget.onScan(raw);
  }

  void _onDetect(BarcodeCapture capture) {
    final value = capture.barcodes.firstOrNull?.rawValue;
    if (value != null) _handle(value);
  }

  Future<void> _paste() async {
    final text = await readClipboardText();
    if (text != null) _handle(text);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (controller != null)
            MobileScanner(
              controller: controller,
              onDetect: _onDetect,
              errorBuilder: (context, error, _) => CabinetCameraError(error: error),
            ),
          if (controller == null)
            _overlay(context)
          else
            ValueListenableBuilder<MobileScannerState>(
              valueListenable: controller,
              builder: (context, state, _) => state.error == null ? _overlay(context) : const SizedBox.shrink(),
            ),
          if (controller != null)
            Positioned(top: 8, right: 8, child: CabinetTorchButton(controller: controller)),
        ],
      ),
    );
  }

  Widget _overlay(BuildContext context) {
    final hint = widget.hint ?? S.pointQrCodeLockerScreen;
    return SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final frame = math.max(0.0, math.min(260.0, math.min(constraints.maxHeight * 0.42, constraints.maxWidth - 64)));
          return Column(
            children: [
              const Spacer(flex: 2),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  hint,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white.withValues(alpha: 0.92)),
                ),
              ),
              const SizedBox(height: 20),
              IgnorePointer(
                child: SizedBox(
                  width: frame,
                  height: frame,
                  child: CustomPaint(
                    painter: ScanFramePainter(color: Colors.white.withValues(alpha: 0.85), cornerLength: frame * 0.23),
                  ),
                ),
              ),
              const Spacer(flex: 3),
              if (cabinetPasteEnabled)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: CabinetPasteButton(onPressed: _paste),
                ),
            ],
          );
        },
      ),
    );
  }
}

class CabinetPasteButton extends StatelessWidget {
  final VoidCallback onPressed;

  const CabinetPasteButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(foregroundColor: Colors.white),
      icon: const Icon(Icons.content_paste_rounded, size: 18),
      label: Text(S.pasteQrContent, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

class CabinetTorchButton extends StatelessWidget {
  final MobileScannerController controller;

  const CabinetTorchButton({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MobileScannerState>(
      valueListenable: controller,
      builder: (context, state, _) {
        final available = state.isInitialized && state.error == null && state.torchState != TorchState.unavailable;
        final on = state.torchState == TorchState.on;
        return AnimatedOpacity(
          opacity: available ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: IconButton(
            tooltip: S.flashlight,
            onPressed: available ? () => controller.toggleTorch() : null,
            icon: Icon(
              on ? Icons.flashlight_on_rounded : Icons.flashlight_off_rounded,
              color: on ? Colors.amber : Colors.white,
            ),
          ),
        );
      },
    );
  }
}

class CabinetCameraError extends StatelessWidget {
  final MobileScannerException error;

  const CabinetCameraError({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
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
            ],
          ),
        ),
      ),
    );
  }
}

class ScanFramePainter extends CustomPainter {
  final Color color;
  final double cornerLength;
  final double strokeWidth;
  final double radius;

  const ScanFramePainter({required this.color, required this.cornerLength, this.strokeWidth = 5, this.radius = 16});

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
  bool shouldRepaint(covariant ScanFramePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.cornerLength != cornerLength;
}
