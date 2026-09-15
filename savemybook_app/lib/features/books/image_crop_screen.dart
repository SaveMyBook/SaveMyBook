import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../../utils/app_colors.dart';
import '../../utils/crop_geometry.dart';
import '../../utils/motion.dart';
import '../../widgets/responsive.dart';
import '../../widgets/state_views.dart';
import '../../i18n/strings.dart';

class ImageCropScreen extends StatefulWidget {
  final String sourcePath;

  final double aspectRatio;

  final bool circular;

  final int outputSize;

  const ImageCropScreen({
    super.key,
    required this.sourcePath,
    this.aspectRatio = 1,
    this.circular = false,
    this.outputSize = 1080,
  });

  @override
  State<ImageCropScreen> createState() => _ImageCropScreenState();
}

class _ImageCropScreenState extends State<ImageCropScreen> {
  static const int _maxDecodeSide = 4096;

  ui.Image? _image;
  String? _error;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  Future<void> _decode() async {
    try {
      final bytes = await File(widget.sourcePath).readAsBytes();
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      final longest = math.max(descriptor.width, descriptor.height);
      final shrink = longest > _maxDecodeSide ? _maxDecodeSide / longest : 1.0;
      final codec = await descriptor.instantiateCodec(
        targetWidth: shrink < 1 ? (descriptor.width * shrink).round() : null,
        targetHeight: shrink < 1 ? (descriptor.height * shrink).round() : null,
      );
      final frame = await codec.getNextFrame();
      codec.dispose();
      descriptor.dispose();
      buffer.dispose();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() => _image = frame.image);
    } catch (_) {
      if (mounted) setState(() => _error = S.couldNotReadPhoto);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ImageCropView(
      image: _image,
      error: _error,
      aspectRatio: widget.aspectRatio,
      circular: widget.circular,
      outputSize: widget.outputSize,
    );
  }
}

class ImageCropView extends StatefulWidget {
  final ui.Image? image;
  final String? error;
  final double aspectRatio;
  final bool circular;
  final int outputSize;

  const ImageCropView({
    super.key,
    required this.image,
    this.error,
    this.aspectRatio = 1,
    this.circular = false,
    this.outputSize = 1080,
  });

  @override
  State<ImageCropView> createState() => ImageCropViewState();
}

@visibleForTesting
class ImageCropViewState extends State<ImageCropView> with TickerProviderStateMixin {
  static const _settleSpring = SpringDescription(mass: 1, stiffness: 260, damping: 2 * 16.1245);
  static const _edgeSpring = SpringDescription(mass: 1, stiffness: 180, damping: 2 * 13.4164);
  static const _inertiaTolerance = Tolerance(distance: 0.5, velocity: 12);

  late final AnimationController _settle;
  late final AnimationController _overlay;
  late final Ticker _inertia;

  CropTransform? _t;
  Size _frame = Size.zero;
  double _angle = 0;

  CropTransform? _from;
  CropTransform? _to;
  double _fromAngle = 0;
  double _toAngle = 0;
  Curve? _settleCurve;

  Simulation? _simX;
  Simulation? _simY;

  double _lastGestureScale = 1;
  Offset _lastFocal = Offset.zero;
  Offset _doubleTapAt = Offset.zero;
  int _pointers = 0;
  bool _saving = false;
  Timer? _overlayTimer;

  CropTransform? get transform => _t;

  Size get frameSize => _frame;

  @override
  void initState() {
    super.initState();
    _settle = AnimationController.unbounded(vsync: this)..addListener(_onSettleTick);
    _overlay = AnimationController(vsync: this, duration: Motion.micro);
    _inertia = createTicker(_onInertiaTick);
  }

  @override
  void didUpdateWidget(covariant ImageCropView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image != widget.image) {
      _stopMotion();
      _t = null;
      _angle = 0;
    }
  }

  @override
  void dispose() {
    _overlayTimer?.cancel();
    _inertia.dispose();
    _settle.dispose();
    _overlay.dispose();
    super.dispose();
  }

  Size get _imageSize {
    final image = widget.image!;
    return Size(image.width.toDouble(), image.height.toDouble());
  }

  bool get _ready => widget.image != null && _t != null && !_frame.isEmpty;

  bool get _isPristine {
    final t = _t;
    if (!_ready || t == null) return true;
    final base = CropGeometry.initial(_imageSize, _frame);
    return t.quarterTurns == 0 && (t.scale - base.scale).abs() < base.scale * 0.005 && t.offset.distance < 0.5;
  }

  void _syncFrame(Size frame) {
    if (widget.image == null || frame.isEmpty) return;
    final previous = _frame;
    if (previous == frame && _t != null) return;
    _frame = frame;
    final t = _t;
    if (t == null || previous.isEmpty) {
      _t = CropGeometry.initial(_imageSize, frame);
      _angle = 0;
      return;
    }
    _stopMotion();
    final k = frame.width / previous.width;
    _t = CropGeometry.clamp(t.copyWith(scale: t.scale * k, offset: t.offset * k), _imageSize, frame);
    _angle = _t!.quarterTurns * math.pi / 2;
  }

  void _stopMotion() {
    if (_inertia.isActive) _inertia.stop();
    if (_settle.isAnimating) _settle.stop();
    _simX = null;
    _simY = null;
    final to = _to;
    _from = null;
    _to = null;
    if (to != null && _t != null && to.quarterTurns != _t!.quarterTurns) {
      _t = to;
      _angle = _toAngle;
    }
  }

  void _showOverlay() {
    _overlayTimer?.cancel();
    _overlay.forward();
  }

  void _hideOverlaySoon() {
    _overlayTimer?.cancel();
    _overlayTimer = Timer(const Duration(milliseconds: 520), () {
      if (!mounted || _pointers > 0 || _settle.isAnimating || _inertia.isActive) return;
      _overlay.reverse();
    });
  }

  void _animateTo(CropTransform target, {double? toAngle, Curve? curve, Duration? duration}) {
    final t = _t;
    if (t == null) return;
    _stopMotion();
    _from = t;
    _to = target;
    _fromAngle = _angle;
    _toAngle = toAngle ?? _angle;
    _settleCurve = curve;
    _showOverlay();
    _settle.value = 0;
    final run = curve != null
        ? _settle.animateTo(1, duration: duration ?? Motion.base, curve: Curves.linear)
        : _settle.animateWith(SpringSimulation(_settleSpring, 0, 1, 0));
    run.whenCompleteOrCancel(_hideOverlaySoon);
  }

  void _onSettleTick() {
    final from = _from;
    final to = _to;
    if (from == null || to == null) return;
    final raw = _settle.value;
    final v = _settleCurve?.transform(raw.clamp(0.0, 1.0)) ?? raw;
    setState(() {
      _t = raw >= 1 ? to : CropTransform.lerp(from, to, v);
      _angle = ui.lerpDouble(_fromAngle, _toAngle, v)!;
      if (raw >= 1) {
        _from = null;
        _to = null;
      }
    });
  }

  double _resist(double value, double lo, double hi, double delta, double dimension) {
    double raw;
    if (value > hi) {
      raw = hi + _inverseRubber(value - hi, dimension);
    } else if (value < lo) {
      raw = lo - _inverseRubber(lo - value, dimension);
    } else {
      raw = value;
    }
    raw += delta;
    if (raw > hi) return hi + CropGeometry.rubberBand(raw - hi, dimension);
    if (raw < lo) return lo - CropGeometry.rubberBand(lo - raw, dimension);
    return raw;
  }

  double _inverseRubber(double y, double d, {double coefficient = 0.55}) {
    final ratio = (y / d).clamp(0.0, 0.999);
    return (1 / (1 - ratio) - 1) * d / coefficient;
  }

  void _onScaleStart(ScaleStartDetails details, Offset center) {
    if (!_ready || _saving) return;
    _stopMotion();
    _lastGestureScale = 1;
    _lastFocal = details.localFocalPoint - center;
    _showOverlay();
  }

  void _onScaleUpdate(ScaleUpdateDetails details, Offset center) {
    final t = _t;
    if (!_ready || _saving || t == null) return;
    final image = _imageSize;
    final focal = details.localFocalPoint - center;
    final ratio = _lastGestureScale <= 0 ? 1.0 : details.scale / _lastGestureScale;
    _lastGestureScale = details.scale;
    final pan = focal - _lastFocal;
    _lastFocal = focal;

    var next = t;
    if (details.pointerCount > 1 && ratio != 1) {
      final minS = CropGeometry.minScale(image, _frame, t.quarterTurns);
      final maxS = CropGeometry.maxScale(image, _frame, t.quarterTurns);
      final logScale = _resist(math.log(t.scale), math.log(minS), math.log(maxS), math.log(ratio), 0.6);
      next = CropGeometry.zoomAround(t, math.exp(logScale), focal);
    }

    final bound = CropGeometry.maxOffset(image, _frame, next.scale, next.quarterTurns);
    next = next.copyWith(
      offset: Offset(
        _resist(next.offset.dx, -bound.dx, bound.dx, pan.dx, _frame.width * 0.5),
        _resist(next.offset.dy, -bound.dy, bound.dy, pan.dy, _frame.height * 0.5),
      ),
    );
    setState(() => _t = next);
  }

  void _onScaleEnd(ScaleEndDetails details) {
    final t = _t;
    if (!_ready || t == null) return;
    final image = _imageSize;
    final minS = CropGeometry.minScale(image, _frame, t.quarterTurns);
    final maxS = CropGeometry.maxScale(image, _frame, t.quarterTurns);

    if (t.scale < minS * 0.999 || t.scale > maxS * 1.001) {
      final focal = t.scale > maxS ? _lastFocal : Offset.zero;
      final zoomed = CropGeometry.zoomAround(t, t.scale.clamp(minS, maxS).toDouble(), focal);
      _animateTo(CropGeometry.clamp(zoomed, image, _frame));
      return;
    }

    final bound = CropGeometry.maxOffset(image, _frame, t.scale, t.quarterTurns);
    var velocity = details.velocity.pixelsPerSecond;
    if (velocity.distance < 60) velocity = Offset.zero;
    final outside = t.offset.dx.abs() > bound.dx + 0.5 || t.offset.dy.abs() > bound.dy + 0.5;
    if (velocity == Offset.zero && !outside) {
      _t = CropGeometry.clamp(t, image, _frame);
      _hideOverlaySoon();
      return;
    }

    _simX = BouncingScrollSimulation(
      position: t.offset.dx,
      velocity: velocity.dx,
      leadingExtent: -bound.dx,
      trailingExtent: bound.dx,
      spring: _edgeSpring,
      tolerance: _inertiaTolerance,
    );
    _simY = BouncingScrollSimulation(
      position: t.offset.dy,
      velocity: velocity.dy,
      leadingExtent: -bound.dy,
      trailingExtent: bound.dy,
      spring: _edgeSpring,
      tolerance: _inertiaTolerance,
    );
    _inertia.start();
  }

  void _onInertiaTick(Duration elapsed) {
    final t = _t;
    final sx = _simX;
    final sy = _simY;
    if (t == null || sx == null || sy == null) {
      _inertia.stop();
      return;
    }
    final seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    final done = sx.isDone(seconds) && sy.isDone(seconds);
    var next = t.copyWith(offset: Offset(sx.x(seconds), sy.x(seconds)));
    if (done) {
      next = CropGeometry.clamp(next, _imageSize, _frame);
      _inertia.stop();
      _simX = null;
      _simY = null;
      _hideOverlaySoon();
    }
    setState(() => _t = next);
  }

  void _onDoubleTap(Offset center) {
    final t = _t;
    if (!_ready || _saving || t == null) return;
    final image = _imageSize;
    final minS = CropGeometry.minScale(image, _frame, t.quarterTurns);
    HapticFeedback.selectionClick();
    if (t.scale > minS * 1.02) {
      _animateTo(
        CropGeometry.clamp(CropGeometry.zoomAround(t, minS, Offset.zero), image, _frame),
        curve: Motion.emphasized,
        duration: Motion.enter,
      );
    } else {
      final focal = _doubleTapAt - center;
      _animateTo(
        CropGeometry.clamp(CropGeometry.zoomAround(t, minS * 2.5, focal), image, _frame),
        curve: Motion.emphasized,
        duration: Motion.enter,
      );
    }
  }

  void _onPointerSignal(PointerSignalEvent event, Offset center) {
    final t = _t;
    if (event is! PointerScrollEvent || !_ready || _saving || t == null) return;
    _stopMotion();
    final image = _imageSize;
    final current = _t!;
    final minS = CropGeometry.minScale(image, _frame, current.quarterTurns);
    final maxS = CropGeometry.maxScale(image, _frame, current.quarterTurns);
    final target = (current.scale * math.exp(-event.scrollDelta.dy / 400)).clamp(minS, maxS).toDouble();
    final zoomed = CropGeometry.zoomAround(current, target, event.localPosition - center);
    _showOverlay();
    setState(() => _t = CropGeometry.clamp(zoomed, image, _frame));
    _hideOverlaySoon();
  }

  void _rotate() {
    if (!_ready || _saving) return;
    _stopMotion();
    HapticFeedback.selectionClick();
    final target = CropGeometry.rotateCounterClockwise(_t!, _imageSize, _frame);
    _animateTo(target, toAngle: _angle - math.pi / 2, curve: Motion.emphasized, duration: Motion.enter);
  }

  void _reset() {
    if (!_ready || _saving || _isPristine) return;
    _stopMotion();
    HapticFeedback.selectionClick();
    _animateTo(
      CropGeometry.initial(_imageSize, _frame),
      toAngle: (_angle / (2 * math.pi)).round() * 2 * math.pi,
      curve: Motion.emphasized,
      duration: Motion.enter,
    );
  }

  CropTransform _settled() {
    _stopMotion();
    return CropGeometry.clamp(_t!, _imageSize, _frame);
  }

  Future<void> _confirm() async {
    final image = widget.image;
    if (image == null || !_ready || _saving) return;
    final t = _settled();
    setState(() {
      _t = t;
      _angle = t.quarterTurns * math.pi / 2;
      _saving = true;
    });
    try {
      final path = await _render(image, t, _frame);
      if (!mounted) return;
      Navigator.pop(context, path);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppSnackBar(context, S.croppingFailedPleaseTryAgain, isError: true);
    }
  }

  Future<String> _render(ui.Image image, CropTransform t, Size frame) async {
    final out = CropGeometry.outputSize(widget.aspectRatio, widget.outputSize);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(Offset.zero & out, Paint()..color = Colors.white);
    CropGeometry.paintOutput(canvas, image, t, frame, out);

    final picture = recorder.endRecording();
    final cropped = await picture.toImage(out.width.round(), out.height.round());
    picture.dispose();

    final data = await cropped.toByteData(format: ui.ImageByteFormat.png);
    cropped.dispose();
    if (data == null) throw StateError('encode failed');

    final file = File('${Directory.systemTemp.path}/crop_${DateTime.now().microsecondsSinceEpoch}.png');
    await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    return file.path;
  }

  static const double _titleHeight = 52;
  static const double _toolbarHeight = 68;

  EdgeInsets _areaPadding(BuildContext context) =>
      context.isCompact ? const EdgeInsets.symmetric(horizontal: 20, vertical: 24) : const EdgeInsets.all(48);

  double? _maxFrameSide(BuildContext context) => switch (context.screenSize) {
    ScreenSize.compact => null,
    ScreenSize.medium => 620,
    ScreenSize.expanded => 700,
  };

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => Column(
              children: [
                SizedBox(
                  height: _titleHeight,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        S.adjustPhoto,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: constraints.maxWidth,
                  height: math.max(0, constraints.maxHeight - _titleHeight - _toolbarHeight),
                  child: _buildEditor(
                    context,
                    Size(constraints.maxWidth, math.max(0, constraints.maxHeight - _titleHeight - _toolbarHeight)),
                  ),
                ),
                SizedBox(height: _toolbarHeight, child: _buildToolbar(c)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditor(BuildContext context, Size area) {
    final padding = _areaPadding(context);
    final frame = CropGeometry.frameSize(
      Size(math.max(0, area.width - padding.horizontal), math.max(0, area.height - padding.vertical)),
      widget.aspectRatio,
      maxSide: _maxFrameSide(context),
    );
    if (widget.error == null && widget.image != null) _syncFrame(frame);
    final center = area.center(Offset.zero);
    final frameRect = Rect.fromCenter(center: center, width: frame.width, height: frame.height);

    if (widget.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
              const SizedBox(height: 12),
              Text(
                widget.error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    final image = widget.image;
    if (image == null || frame.isEmpty) {
      return Stack(
        children: [
          Positioned.fromRect(
            rect: frameRect,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                shape: widget.circular ? BoxShape.circle : BoxShape.rectangle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              ),
            ),
          ),
          Center(
            child: Semantics(
              label: S.loading,
              child: const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white70),
              ),
            ),
          ),
        ],
      );
    }

    final t = _t!;

    return TweenAnimationBuilder<double>(
      key: ObjectKey(image),
      tween: Tween(begin: 0, end: 1),
      duration: Motion.base,
      curve: Motion.enterCurve,
      builder: (context, appear, child) => Opacity(opacity: appear, child: child),
      child: Listener(
        onPointerDown: (_) => _pointers++,
        onPointerUp: (_) => _pointers = math.max(0, _pointers - 1),
        onPointerCancel: (_) => _pointers = math.max(0, _pointers - 1),
        onPointerSignal: (event) => _onPointerSignal(event, center),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: (d) => _onScaleStart(d, center),
          onScaleUpdate: (d) => _onScaleUpdate(d, center),
          onScaleEnd: _onScaleEnd,
          onDoubleTapDown: (d) => _doubleTapAt = d.localPosition,
          onDoubleTap: () => _onDoubleTap(center),
          child: AnimatedBuilder(
            animation: _overlay,
            builder: (context, _) => CustomPaint(
              size: area,
              painter: _CropImagePainter(image: image, center: center, transform: t, angle: _angle),
              foregroundPainter: _CropOverlayPainter(
                frame: frameRect,
                circular: widget.circular,
                interaction: Motion.standard.transform(_overlay.value),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolbar(AppColors c) {
    final ready = _ready && !_saving;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    child: Text(
                      S.actionCancel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ),
              _ToolButton(icon: Icons.rotate_90_degrees_ccw_rounded, tooltip: S.rotate, onPressed: ready ? _rotate : null),
              const SizedBox(width: 12),
              _ToolButton(
                icon: Icons.restart_alt_rounded,
                tooltip: S.reset,
                onPressed: ready && !_isPristine ? _reset : null,
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _DoneButton(
                    label: S.completed,
                    color: c.accent,
                    loading: _saving,
                    onPressed: ready ? _confirm : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _ToolButton({required this.icon, required this.tooltip, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      iconSize: 26,
      color: Colors.white,
      disabledColor: Colors.white30,
      icon: Icon(icon),
    );
  }
}

class _DoneButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool loading;
  final VoidCallback? onPressed;

  const _DoneButton({required this.label, required this.color, required this.loading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null || loading;
    return AnimatedOpacity(
      duration: Motion.micro,
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: color,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: loading ? null : onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 72, minHeight: 40),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Center(
                widthFactor: 1,
                child: AnimatedSwitcher(
                  duration: Motion.micro,
                  child: loading
                      ? const SizedBox(
                          key: ValueKey('loading'),
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                        )
                      : Text(
                          label,
                          key: const ValueKey('label'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CropImagePainter extends CustomPainter {
  final ui.Image image;
  final Offset center;
  final CropTransform transform;
  final double angle;

  _CropImagePainter({required this.image, required this.center, required this.transform, required this.angle});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    CropGeometry.paintPreview(canvas, image, center, transform, angle);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CropImagePainter old) =>
      old.image != image || old.center != center || old.transform != transform || old.angle != angle;
}

class _CropOverlayPainter extends CustomPainter {
  final Rect frame;
  final bool circular;
  final double interaction;

  _CropOverlayPainter({required this.frame, required this.circular, required this.interaction});

  @override
  void paint(Canvas canvas, Size size) {
    final shape = Path();
    if (circular) {
      shape.addOval(frame);
    } else {
      shape.addRect(frame);
    }
    final dim = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addPath(shape, Offset.zero);
    canvas.drawPath(dim, Paint()..color = Colors.black.withValues(alpha: ui.lerpDouble(0.62, 0.42, interaction)!));

    if (interaction > 0) {
      canvas.save();
      canvas.clipPath(shape);
      final grid = Paint()
        ..color = Colors.white.withValues(alpha: 0.5 * interaction)
        ..strokeWidth = 0.8;
      for (var i = 1; i < 3; i++) {
        final x = frame.left + frame.width * i / 3;
        final y = frame.top + frame.height * i / 3;
        canvas.drawLine(Offset(x, frame.top), Offset(x, frame.bottom), grid);
        canvas.drawLine(Offset(frame.left, y), Offset(frame.right, y), grid);
      }
      canvas.restore();
    }

    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.85);
    if (circular) {
      canvas.drawOval(frame, border);
      return;
    }
    canvas.drawRect(frame, border);

    final corner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.square
      ..color = Colors.white;
    final len = math.min(22.0, math.min(frame.width, frame.height) / 4);
    final r = frame.deflate(-1.5);
    for (final (p, dx, dy) in [
      (r.topLeft, 1.0, 1.0),
      (r.topRight, -1.0, 1.0),
      (r.bottomLeft, 1.0, -1.0),
      (r.bottomRight, -1.0, -1.0),
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(p.dx + dx * len, p.dy)
          ..lineTo(p.dx, p.dy)
          ..lineTo(p.dx, p.dy + dy * len),
        corner,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter old) =>
      old.frame != frame || old.circular != circular || old.interaction != interaction;
}
