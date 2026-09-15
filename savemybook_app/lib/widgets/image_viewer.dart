import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../i18n/strings.dart';
import '../utils/app_colors.dart';
import '../utils/motion.dart';
import 'image_save_feedback.dart';

class ImageViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  final List<String?> heroTags;
  final String? title;
  final bool allowSave;

  ImageViewer({super.key, required String imageUrl, this.title, String? heroTag, this.allowSave = false})
      : imageUrls = [imageUrl],
        initialIndex = 0,
        heroTags = [heroTag];

  const ImageViewer.gallery({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
    this.heroTags = const [],
    this.title,
    this.allowSave = true,
  });

  static Future<void> open(
    BuildContext context, {
    required String? imageUrl,
    String? title,
    String? heroTag,
    bool allowSave = false,
  }) {
    if (imageUrl == null || imageUrl.isEmpty) return Future.value();
    return _push(context, ImageViewer(imageUrl: imageUrl, title: title, heroTag: heroTag, allowSave: allowSave));
  }

  static Future<void> openGallery(
    BuildContext context, {
    required List<String> imageUrls,
    int initialIndex = 0,
    List<String?>? heroTags,
    String? title,
    bool allowSave = true,
  }) {
    final urls = [for (final url in imageUrls) if (url.isNotEmpty) url];
    if (urls.isEmpty) return Future.value();
    return _push(
      context,
      ImageViewer.gallery(
        imageUrls: urls,
        initialIndex: initialIndex.clamp(0, urls.length - 1),
        heroTags: heroTags ?? const [],
        title: title,
        allowSave: allowSave,
      ),
    );
  }

  static Future<void> _push(BuildContext context, Widget viewer) {
    return Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, _, _) => viewer,
        transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  State<ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<ImageViewer> with SingleTickerProviderStateMixin {
  static const _dismissDistance = 120.0;
  static const _dismissVelocity = 800.0;

  late final PageController _pages = PageController(initialPage: widget.initialIndex);
  late final ValueNotifier<int> _index = ValueNotifier(widget.initialIndex);
  late final AnimationController _drag = AnimationController.unbounded(vsync: this);
  final ValueNotifier<double?> _saving = ValueNotifier(null);
  final FocusNode _focus = FocusNode();
  bool _zoomed = false;
  bool _closing = false;

  int get _count => widget.imageUrls.length;

  @override
  void dispose() {
    _pages.dispose();
    _index.dispose();
    _drag.dispose();
    _saving.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _close() {
    if (_closing) return;
    _closing = true;
    Navigator.of(context).maybePop();
  }

  void _onZoomChanged(bool zoomed) {
    if (_zoomed != zoomed) setState(() => _zoomed = zoomed);
  }

  void _go(int delta) {
    final target = _index.value + delta;
    if (target < 0 || target >= _count || !_pages.hasClients) return;
    _pages.animateToPage(target, duration: Motion.base, curve: Motion.standard);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _drag.stop();
    _drag.value += details.primaryDelta ?? details.delta.dy;
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (_drag.value.abs() > _dismissDistance || velocity.abs() > _dismissVelocity) {
      _close();
      return;
    }
    _drag.animateWith(SpringSimulation(
      SpringDescription(mass: 1, stiffness: 420, damping: 2 * math.sqrt(420)),
      _drag.value,
      0,
      velocity,
    ));
  }

  Future<void> _save() async {
    if (_saving.value != null) return;
    HapticFeedback.selectionClick();
    _saving.value = 0;
    await saveImagesWithFeedback(
      context,
      [widget.imageUrls[_index.value]],
      onProgress: (value) {
        if (mounted) _saving.value = value;
      },
    );
    if (mounted) _saving.value = null;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _close();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _go(-1);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _go(1);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 600;
    final height = MediaQuery.sizeOf(context).height;

    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AnimatedBuilder(
          animation: _drag,
          builder: (context, child) {
            final progress = (_drag.value.abs() / (height * 0.5)).clamp(0.0, 1.0);
            return Stack(
              children: [
                Positioned.fill(child: ColoredBox(color: Colors.black.withValues(alpha: 0.92 * (1 - progress * 0.8)))),
                Positioned.fill(
                  child: Transform.translate(
                    offset: Offset(0, _drag.value),
                    child: Transform.scale(scale: 1 - progress * 0.12, child: child),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: Opacity(opacity: (1 - progress * 3).clamp(0.0, 1.0), child: _buildTopBar()),
                ),
                if (wide && _count > 1) ...[
                  _arrow(left: true, visible: progress == 0),
                  _arrow(left: false, visible: progress == 0),
                ],
              ],
            );
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: _zoomed ? null : _onDragUpdate,
            onVerticalDragEnd: _zoomed ? null : _onDragEnd,
            child: PageView.builder(
              controller: _pages,
              physics: _zoomed ? const NeverScrollableScrollPhysics() : const PageScrollPhysics(),
              itemCount: _count,
              onPageChanged: (i) {
                _index.value = i;
                if (_zoomed) setState(() => _zoomed = false);
              },
              itemBuilder: (context, i) => _ZoomableImage(
                key: ValueKey('viewer_page_$i'),
                url: widget.imageUrls[i],
                heroTag: i < widget.heroTags.length ? widget.heroTags[i] : null,
                onZoomChanged: _onZoomChanged,
                onTap: _close,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _arrow({required bool left, required bool visible}) {
    return Positioned(
      left: left ? 12 : null,
      right: left ? null : 12,
      top: 0,
      bottom: 0,
      child: Center(
        child: ValueListenableBuilder<int>(
          valueListenable: _index,
          builder: (context, index, _) {
            final enabled = visible && (left ? index > 0 : index < _count - 1);
            return AnimatedOpacity(
              opacity: enabled ? 1 : 0,
              duration: Motion.micro,
              child: IgnorePointer(
                ignoring: !enabled,
                child: IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.14)),
                  onPressed: () => _go(left ? -1 : 1),
                  icon: Icon(left ? Icons.chevron_left_rounded : Icons.chevron_right_rounded, color: Colors.white, size: 30),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final title = widget.title;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withValues(alpha: 0.45), Colors.transparent],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              const SizedBox(width: 4),
              IconButton(
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                onPressed: _close,
              ),
              Expanded(
                child: ValueListenableBuilder<int>(
                  valueListenable: _index,
                  builder: (context, index, _) {
                    final label = _count > 1 ? '${index + 1} / $_count' : (title ?? '');
                    return Text(
                      label,
                      key: const ValueKey('viewer_title'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: _count > 1 ? TextAlign.center : TextAlign.start,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    );
                  },
                ),
              ),
              if (widget.allowSave)
                ValueListenableBuilder<double?>(
                  valueListenable: _saving,
                  builder: (context, saving, _) => IconButton(
                    tooltip: S.saveImage,
                    onPressed: saving == null ? _save : null,
                    icon: saving == null
                        ? const Icon(Icons.download_rounded, color: Colors.white, size: 26)
                        : SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              value: saving <= 0 ? null : saving,
                              strokeWidth: 2.4,
                              color: Colors.white,
                              backgroundColor: Colors.white24,
                            ),
                          ),
                  ),
                )
              else
                const SizedBox(width: 48),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}

class _ZoomableImage extends StatefulWidget {
  final String url;
  final String? heroTag;
  final ValueChanged<bool> onZoomChanged;
  final VoidCallback onTap;

  const _ZoomableImage({super.key, required this.url, required this.onZoomChanged, required this.onTap, this.heroTag});

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage> with SingleTickerProviderStateMixin {
  final TransformationController _controller = TransformationController();
  late final AnimationController _animation;
  Animation<Matrix4>? _zoom;
  TapDownDetails? _doubleTap;
  bool _zoomed = false;
  int _attempt = 0;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(vsync: this, duration: const Duration(milliseconds: 240));
    _controller.addListener(_onTransform);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTransform);
    _animation.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onTransform() {
    final zoomed = _controller.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed == _zoomed) return;
    _zoomed = zoomed;
    widget.onZoomChanged(zoomed);
    setState(() {});
  }

  void _toggleZoom() {
    final details = _doubleTap;
    if (details == null) return;
    const scale = 2.5;
    final point = details.localPosition;
    final target = _zoomed
        ? Matrix4.identity()
        : (Matrix4.identity()
          ..setEntry(0, 0, scale)
          ..setEntry(1, 1, scale)
          ..setEntry(2, 2, scale)
          ..setEntry(0, 3, -(scale - 1) * point.dx)
          ..setEntry(1, 3, -(scale - 1) * point.dy));
    _zoom?.removeListener(_applyZoom);
    _zoom = Matrix4Tween(begin: _controller.value, end: target)
        .animate(CurvedAnimation(parent: _animation, curve: Curves.easeOutCubic))
      ..addListener(_applyZoom);
    _animation.forward(from: 0);
  }

  void _applyZoom() {
    final zoom = _zoom;
    if (zoom != null) _controller.value = zoom.value;
  }

  void _retry() {
    NetworkImage(widget.url).evict();
    setState(() => _attempt++);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    Widget image = Image.network(
      widget.url,
      key: ValueKey('${widget.url}#$_attempt'),
      fit: BoxFit.contain,
      gaplessPlayback: true,
      loadingBuilder: (_, child, progress) {
        if (progress == null) return child;
        final expected = progress.expectedTotalBytes;
        return Stack(
          fit: StackFit.expand,
          children: [
            child,
            Center(
              child: SizedBox(
                width: 44,
                height: 44,
                child: CircularProgressIndicator(
                  value: expected == null || expected == 0 ? null : progress.cumulativeBytesLoaded / expected,
                  strokeWidth: 3,
                  color: Colors.white,
                  backgroundColor: Colors.white24,
                ),
              ),
            ),
          ],
        );
      },
      errorBuilder: (_, _, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_outlined, color: c.iconInactive, size: 56),
            const SizedBox(height: 12),
            Text(S.couldNotLoadPhoto, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              label: Text(S.retry, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    image = SizedBox.expand(child: image);
    final tag = widget.heroTag;
    if (tag != null) image = Hero(tag: tag, child: image);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onDoubleTapDown: (details) => _doubleTap = details,
      onDoubleTap: _toggleZoom,
      child: InteractiveViewer(
        transformationController: _controller,
        minScale: 1,
        maxScale: 5,
        panEnabled: _zoomed,
        child: image,
      ),
    );
  }
}
