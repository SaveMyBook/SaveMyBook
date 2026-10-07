import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../models/order.dart';
import '../../services/api_service.dart';
import '../../services/cabinet_code.dart';
import '../cabinet/cabinet_entry.dart';
import '../cabinet/cabinet_flow_screen.dart';
import '../cabinet/cabinet_resume.dart';
import '../cabinet/cabinet_scanner_view.dart';
import '../../utils/app_colors.dart';
import '../../utils/motion.dart';
import '../../widgets/animations.dart';
import '../../widgets/responsive.dart';
import 'widgets/pickup_ready_card.dart';
import 'order_detail_screen.dart';
import '../../i18n/strings.dart';

class PickupBookScreen extends StatefulWidget {
  final bool isActive;
  final Stream<String>? scanInput;
  const PickupBookScreen({super.key, this.isActive = false, this.scanInput});

  @override
  State<PickupBookScreen> createState() => _PickupBookScreenState();
}

class _PickupBookScreenState extends State<PickupBookScreen> {
  final ApiService _api = ApiService();
  final PageController _pageController = PageController(viewportFraction: 0.92);
  MobileScannerController? _controller;
  StreamSubscription<String>? _input;
  bool _scanned = false;
  bool _cameraOn = false;
  bool _suspended = false;
  List<Order> _ready = [];
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _input = widget.scanInput?.listen(_onValue);
    CabinetFlowScreen.showing.addListener(_onFlowShowing);
    if (widget.isActive) {
      _startCamera(rebuild: false);
      _loadOrders();
      unawaited(CabinetResume.check());
    }
  }

  @override
  void didUpdateWidget(covariant PickupBookScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _startCamera();
      _loadOrders();
      unawaited(CabinetResume.check());
    } else if (!widget.isActive && oldWidget.isActive) {
      _suspended = false;
      _stopCamera();
    }
  }

  void _startCamera({bool rebuild = true}) {
    if (CabinetFlowScreen.isShowing) {
      _suspended = true;
      return;
    }
    if (_cameraOn) return;
    _cameraOn = true;
    _scanned = false;
    if (widget.scanInput == null) {
      final controller = CabinetCamera.create();
      _controller = controller;
      unawaited(CabinetCamera.start(controller));
    }
    if (rebuild && mounted) setState(() {});
  }

  void _stopCamera() {
    CabinetCamera.release(_controller);
    _controller = null;
    _cameraOn = false;
    if (mounted) setState(() {});
  }

  // 顯示計數會在流程畫面的 initState 與 dispose 變動，這兩個時點都不能 setState。
  void _onFlowShowing() => scheduleMicrotask(() {
    if (!mounted) return;
    if (CabinetFlowScreen.isShowing) {
      if (!_cameraOn) return;
      _stopCamera();
      _suspended = true;
    } else if (_suspended) {
      _suspended = false;
      if (widget.isActive) _startCamera();
    }
  });

  @override
  void dispose() {
    unawaited(_input?.cancel());
    CabinetFlowScreen.showing.removeListener(_onFlowShowing);
    CabinetCamera.release(_controller);
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    if (ApiService.authToken == null) return;
    final orders = await _api.fetchOrders(role: 'buyer', tab: 'pending_pickup');
    if (!mounted) return;
    final ready = orders.where((o) => o.canCollect).toList();
    setState(() {
      _ready = ready;
      if (_page >= ready.length) _page = 0;
    });
  }

  void _onDetect(BarcodeCapture capture) {
    final value = capture.barcodes.firstOrNull?.rawValue;
    if (value != null) _onValue(value);
  }

  void _onValue(String value) {
    if (_scanned || !_cameraOn || !mounted || value.trim().isEmpty || CabinetFlowScreen.isShowing) return;
    HapticFeedback.mediumImpact();
    setState(() => _scanned = true);
    if (isCabinetCode(value)) {
      _openCabinet(value);
    } else {
      _showNotCabinetCode();
    }
  }

  Future<void> _paste() async {
    final text = await readClipboardText();
    if (text != null) _onValue(text);
  }

  Future<void> _openCabinet(String value) async {
    _stopCamera();
    await openCabinetFlow(context, code: value);
    if (!mounted) return;
    _scanned = false;
    if (widget.isActive) _startCamera();
    _loadOrders();
  }

  Future<void> _showNotCabinetCode() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final c = AppColors.of(ctx);
        return AlertDialog(
          backgroundColor: c.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Text(S.notSavemybookLockerQrCode, style: TextStyle(fontWeight: FontWeight.w600, color: c.textPrimary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(S.rescan, style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
    if (mounted) setState(() => _scanned = false);
  }

  Future<void> _openOrder(Order order) async {
    _stopCamera();
    await Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailScreen(order: order)));
    if (!mounted) return;
    if (widget.isActive) _startCamera();
    _loadOrders();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final media = MediaQuery.of(context);
    final navSpace = floatingNavClearance(context, 72);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_controller != null)
            MobileScanner(
              controller: _controller!,
              onDetect: _onDetect,
              errorBuilder: (context, error, _) => CabinetCameraError(error: error),
            ),
          Column(
            children: [
              Container(
                padding: EdgeInsets.only(top: media.padding.top, left: 16, right: 16),
                decoration: BoxDecoration(color: c.headerBg),
                child: SizedBox(
                  height: 56,
                  width: double.infinity,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                S.collectBook,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_controller != null)
                        Positioned(right: -8, child: CabinetTorchButton(controller: _controller!)),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final sidePanel = context.isWide && constraints.maxWidth >= 840 && _ready.isNotEmpty;
                    final reserved = _ready.isEmpty || sidePanel ? 0.0 : 136.0;
                    final paste = cabinetPasteEnabled ? 48.0 : 0.0;
                    final frame = ((constraints.maxHeight - reserved - paste - navSpace - 110) * 0.8).clamp(120.0, context.isWide ? 280.0 : 220.0);
                    if (sidePanel) {
                      return Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                const Spacer(flex: 2),
                                _buildScanTarget(frame),
                                const Spacer(flex: 3),
                                SizedBox(height: navSpace),
                              ],
                            ),
                          ),
                          SizedBox(width: 360, child: _buildReadyList(c, bottom: navSpace)),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        const Spacer(flex: 2),
                        _buildScanTarget(frame),
                        const Spacer(flex: 3),
                        AnimatedSize(
                          duration: Motion.enter,
                          curve: Motion.standard,
                          child: _ready.isEmpty
                              ? const SizedBox(width: double.infinity)
                              : context.isWide
                                  ? ResponsiveCenter(maxWidth: Breakpoints.formMaxWidth, child: _buildReadyPanel(c))
                                  : _buildReadyPanel(c),
                        ),
                        SizedBox(height: navSpace),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScanTarget(double frame) {
    return Column(
      children: [
        _unlessCameraError(
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  S.pointQrCodeLockerScreen,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white.withValues(alpha: 0.9)),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: frame,
                height: frame,
                child: CustomPaint(
                  painter: _CornerFramePainter(
                    color: Colors.white.withValues(alpha: 0.85),
                    cornerLength: frame * 0.23,
                    strokeWidth: 5,
                    radius: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (cabinetPasteEnabled)
          Padding(padding: const EdgeInsets.only(top: 8), child: CabinetPasteButton(onPressed: _paste)),
      ],
    );
  }

  Widget _buildReadyList(AppColors c, {required double bottom}) {
    return Align(
      alignment: Alignment.topCenter,
      child: FadeSlideIn(
        offsetY: 20,
        child: Container(
          margin: EdgeInsets.fromLTRB(0, 24, 24, bottom + 24),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 16, color: Colors.white),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      S.p0ReadyPickup(_ready.length),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: _ready.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => GestureDetector(
                    onTap: () => _openOrder(_ready[i]),
                    child: PickupReadyCard(order: _ready[i]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _unlessCameraError(Widget child) {
    final controller = _controller;
    if (controller == null) return child;
    return ValueListenableBuilder<MobileScannerState>(
      valueListenable: controller,
      builder: (context, state, child) => Visibility(
        visible: state.error == null,
        maintainSize: true,
        maintainAnimation: true,
        maintainState: true,
        child: child!,
      ),
      child: child,
    );
  }

  Widget _buildReadyPanel(AppColors c) {
    return FadeSlideIn(
      offsetY: 20,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Row(
              children: [
                const Icon(Icons.inventory_2_outlined, size: 16, color: Colors.white),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    S.p0ReadyPickup(_ready.length),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
                if (_ready.length > 1)
                  Text(
                    '${_page + 1} / ${_ready.length}',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 104,
            child: PageView.builder(
              controller: _pageController,
              itemCount: _ready.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) {
                final order = _ready[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: GestureDetector(
                    onTap: () => _openOrder(order),
                    child: PickupReadyCard(order: order),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
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
  bool shouldRepaint(covariant _CornerFramePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.cornerLength != cornerLength;
}
