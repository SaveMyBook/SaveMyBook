import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/order.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../utils/motion.dart';
import '../widgets/animations.dart';
import '../widgets/buyer/pickup_code_card.dart';
import 'order_detail_screen.dart';
import 'purchase_history_screen.dart';
import '../i18n/strings.dart';

class PickupBookScreen extends StatefulWidget {
  final bool isActive;
  const PickupBookScreen({super.key, this.isActive = false});

  @override
  State<PickupBookScreen> createState() => _PickupBookScreenState();
}

class _PickupBookScreenState extends State<PickupBookScreen> {
  final ApiService _api = ApiService();
  final PageController _pageController = PageController(viewportFraction: 0.92);
  MobileScannerController? _controller;
  bool _scanned = false;
  List<Order> _ready = [];
  int _page = 0;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) {
      _controller = MobileScannerController(formats: [BarcodeFormat.qrCode]);
      _loadOrders();
    }
  }

  @override
  void didUpdateWidget(covariant PickupBookScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _startCamera();
      _loadOrders();
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
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    if (ApiService.authToken == null) return;
    final orders = await _api.fetchOrders(role: 'buyer', tab: 'pending_pickup');
    if (!mounted) return;
    final ready = orders.where((o) => canCollectOrder(o) && (o.pickupCode?.isNotEmpty ?? false)).toList();
    setState(() {
      _ready = ready;
      if (_page >= ready.length) _page = 0;
    });
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;
    final value = capture.barcodes.firstOrNull?.rawValue;
    if (value == null || value.isEmpty) return;
    HapticFeedback.mediumImpact();
    setState(() => _scanned = true);
    _handleScanResult(value);
  }

  Future<void> _handleScanResult(String value) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final c = AppColors.of(ctx);
        return AlertDialog(
          backgroundColor: c.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(S.scanned, style: TextStyle(fontWeight: FontWeight.bold, color: c.textPrimary)),
          content: SelectableText(value, style: TextStyle(color: c.textSecondary)),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
                Navigator.pop(ctx);
              },
              child: Text(S.copy, style: const TextStyle(color: AppColors.primary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(S.scanAgain, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
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
    final navSpace = media.padding.bottom + 72;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_controller != null) MobileScanner(controller: _controller!, onDetect: _onDetect),
          Column(
            children: [
              Container(
                padding: EdgeInsets.only(top: media.padding.top + 8, bottom: 12, left: 16, right: 16),
                decoration: BoxDecoration(color: c.headerBg),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
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
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final reserved = _ready.isEmpty ? 0.0 : 190.0;
                    final frame = ((constraints.maxHeight - reserved - navSpace - 110) * 0.8).clamp(120.0, 220.0);
                    return Column(
                      children: [
                        const Spacer(flex: 2),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            S.pointPickupQrCode,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white.withValues(alpha: 0.9)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(S.holdSteady, style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.6))),
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
                        const Spacer(flex: 3),
                        AnimatedSize(
                          duration: Motion.enter,
                          curve: Motion.standard,
                          child: _ready.isEmpty ? const SizedBox(width: double.infinity) : _buildReadyPanel(c),
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
            height: 158,
            child: PageView.builder(
              controller: _pageController,
              itemCount: _ready.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) {
                final order = _ready[i];
                final book = order.firstBook;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: GestureDetector(
                    onTap: () => _openOrder(order),
                    child: PickupCodeCard(
                      code: order.pickupCode!,
                      slotNumber: order.slotNumber,
                      caption: [
                        if (book != null) book.title,
                        if (order.cabinetName.isNotEmpty) order.cabinetName,
                      ].join(' · '),
                    ),
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
