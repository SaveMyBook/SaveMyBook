import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../i18n/strings.dart';

class ImageViewer extends StatefulWidget {
  final String imageUrl;
  final String? title;
  final String? heroTag;

  const ImageViewer({super.key, required this.imageUrl, this.title, this.heroTag});

  static Future<void> open(
    BuildContext context, {
    required String? imageUrl,
    String? title,
    String? heroTag,
  }) {
    if (imageUrl == null || imageUrl.isEmpty) return Future.value();
    return Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, _, _) =>
            ImageViewer(imageUrl: imageUrl, title: title, heroTag: heroTag),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  State<ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<ImageViewer> with SingleTickerProviderStateMixin {
  final TransformationController _controller = TransformationController();
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  Animation<Matrix4>? _zoom;

  @override
  void dispose() {
    _animation.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _toggleZoom(TapDownDetails details) {
    const scale = 2.5;
    final zoomed = _controller.value.getMaxScaleOnAxis() > 1.05;
    final point = details.localPosition;

    // 直接寫矩陣，避開 translate/scale 這幾個在不同 Flutter 版本改過名字的 helper。
    final target = zoomed
        ? Matrix4.identity()
        : (Matrix4.identity()
          ..setEntry(0, 0, scale)
          ..setEntry(1, 1, scale)
          ..setEntry(2, 2, scale)
          ..setEntry(0, 3, -(scale - 1) * point.dx)
          ..setEntry(1, 3, -(scale - 1) * point.dy));

    _zoom = Matrix4Tween(begin: _controller.value, end: target).animate(
      CurvedAnimation(parent: _animation, curve: Curves.easeOutCubic),
    )..addListener(() => _controller.value = _zoom!.value);
    _animation.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    Widget image = Image.network(
      widget.imageUrl,
      fit: BoxFit.contain,
      loadingBuilder: (_, child, progress) => progress == null
          ? child
          : const Center(child: CircularProgressIndicator(color: Colors.white)),
      errorBuilder: (_, _, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_outlined, color: c.iconInactive, size: 56),
            const SizedBox(height: 12),
            Text(S.couldNotLoadPhoto, style: TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );

    if (widget.heroTag != null) {
      image = Hero(tag: widget.heroTag!, child: image);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).maybePop(),
            onDoubleTapDown: _toggleZoom,
            child: InteractiveViewer(
              transformationController: _controller,
              minScale: 1,
              maxScale: 5,
              child: Center(child: image),
            ),
          ),
          SafeArea(
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                if (widget.title != null && widget.title!.isNotEmpty)
                  Expanded(
                    child: Text(
                      widget.title!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const SizedBox(width: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
