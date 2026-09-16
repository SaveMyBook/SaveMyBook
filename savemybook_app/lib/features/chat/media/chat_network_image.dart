import 'dart:io';

import 'package:flutter/material.dart';

import '../../../utils/app_colors.dart';
import '../../../utils/motion.dart';
import '../../../widgets/animations.dart';
import '../../../widgets/app_asset_image.dart';

class ChatNetworkImage extends StatefulWidget {
  final String? url;
  final String? localPath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool showProgress;
  final double iconSize;
  final Map<String, String>? headers;

  const ChatNetworkImage({
    super.key,
    this.url,
    this.localPath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.showProgress = false,
    this.iconSize = 26,
    this.headers,
  });

  @override
  State<ChatNetworkImage> createState() => _ChatNetworkImageState();
}

class _ChatNetworkImageState extends State<ChatNetworkImage> {
  int _attempt = 0;
  bool _permanent = false;

  @override
  void didUpdateWidget(covariant ChatNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url || oldWidget.localPath != widget.localPath) _permanent = false;
  }

  ImageProvider? get _provider {
    final path = widget.localPath;
    if (path != null && File(path).existsSync()) return FileImage(File(path));
    final url = widget.url;
    return url == null || url.isEmpty ? null : NetworkImage(url, headers: widget.headers);
  }

  void _retry() {
    final url = widget.url;
    if (url == null) return;
    NetworkImage(url, headers: widget.headers).evict();
    setState(() {
      _attempt++;
      _permanent = false;
    });
  }

  void _onError(Object error) {
    if (!mounted || _permanent || !isPermanentImageError(error)) return;
    setState(() => _permanent = true);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final provider = _provider;

    Widget box(Widget child) => SizedBox(width: widget.width, height: widget.height, child: child);

    Widget fallback({VoidCallback? onTap}) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: box(ColoredBox(
            color: c.skeleton,
            child: Center(
              child: Icon(
                onTap == null ? Icons.image_outlined : Icons.refresh_rounded,
                size: widget.iconSize,
                color: c.iconInactive.withValues(alpha: 0.7),
              ),
            ),
          )),
        );

    if (provider == null) return fallback();

    final skeleton = Shimmer(child: ColoredBox(color: c.skeleton));

    return box(Image(
      key: ValueKey('${widget.url}#$_attempt'),
      image: provider,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      gaplessPlayback: true,
      // 404 代表檔案已不在伺服器上，只顯示替代圖，不提供會再打一次的重試入口。
      errorBuilder: (_, error, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _onError(error));
        return fallback(onTap: widget.url == null || _permanent || isPermanentImageError(error) ? null : _retry);
      },
      frameBuilder: (_, child, frame, sync) {
        if (sync) return child;
        return Stack(
          fit: StackFit.expand,
          children: [
            if (frame == null) skeleton,
            AnimatedOpacity(
              opacity: frame == null ? 0 : 1,
              duration: Motion.base,
              curve: Curves.easeOut,
              child: child,
            ),
          ],
        );
      },
      loadingBuilder: (_, child, progress) {
        if (progress == null || !widget.showProgress) return child;
        final expected = progress.expectedTotalBytes;
        if (expected == null || expected == 0) return child;
        return Stack(
          fit: StackFit.expand,
          children: [
            child,
            Center(
              child: SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  value: progress.cumulativeBytesLoaded / expected,
                  strokeWidth: 2.4,
                  color: c.accent,
                  backgroundColor: c.accent.withValues(alpha: 0.18),
                ),
              ),
            ),
          ],
        );
      },
    ));
  }
}
