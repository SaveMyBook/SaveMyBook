import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/ai_image_prep.dart';
import '../../services/api_service.dart';
import '../../services/photo_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/motion.dart';
import '../../widgets/image_viewer.dart';
import '../../widgets/state_views.dart';
import '../../i18n/strings.dart';

enum TicketAttachmentState { uploading, uploaded, failed }

class TicketAttachment {
  final int key;
  final String localPath;
  TicketAttachmentState state = TicketAttachmentState.uploading;
  double progress = 0;
  String? url;
  String? error;

  TicketAttachment._(this.key, this.localPath);
}

typedef TicketImageUploader = Future<(String?, String?)> Function(String path, ValueChanged<double> onProgress);
typedef TicketImagePreparer = Future<String?> Function(String path);
typedef TicketImageSizer = Future<int> Function(String path);

class TicketAttachmentController extends ChangeNotifier {
  static const maxCount = 4;
  static const maxBytes = 10 * 1024 * 1024;

  final TicketImageUploader _uploader;
  final TicketImagePreparer _preparer;
  final TicketImageSizer _sizeOf;
  final List<TicketAttachment> _items = [];
  int _seq = 0;
  bool _disposed = false;

  TicketAttachmentController({TicketImageUploader? uploader, TicketImagePreparer? preparer, TicketImageSizer? sizeOf})
    : _uploader = uploader ?? ((path, onProgress) => ApiService().uploadSupportImage(path, onProgress: onProgress)),
      _preparer = preparer ?? _defaultPrepare,
      _sizeOf = sizeOf ?? _fileSize;

  // HEIC 等格式在部分裝置無法顯示，且超過門檻的照片先縮小，行為與 AI 上傳一致。
  static Future<String?> _defaultPrepare(String path) => AiImagePrep.prepare(path, reencodeAbove: 8 * 1024 * 1024);

  List<TicketAttachment> get items => List.unmodifiable(_items);
  int get remaining => maxCount - _items.length;
  bool get isEmpty => _items.isEmpty;
  bool get isUploading => _items.any((i) => i.state == TicketAttachmentState.uploading);
  bool get hasFailed => _items.any((i) => i.state == TicketAttachmentState.failed);
  bool get isReady => !isUploading && !hasFailed;
  List<String> get urls => [
    for (final i in _items)
      if (i.url != null) i.url!,
  ];

  Future<void> add(Iterable<String> paths) {
    final added = [for (final path in paths.take(remaining)) TicketAttachment._(_seq++, path)];
    if (added.isEmpty) return Future.value();
    _items.addAll(added);
    _notify();
    return Future.wait(added.map(_upload));
  }

  Future<void> retry(TicketAttachment item) {
    if (!_items.contains(item) || item.state != TicketAttachmentState.failed) return Future.value();
    return _upload(item);
  }

  void remove(TicketAttachment item) {
    if (_items.remove(item)) _notify();
  }

  void clear() {
    if (_items.isEmpty) return;
    _items.clear();
    _notify();
  }

  Future<void> _upload(TicketAttachment item) async {
    item
      ..state = TicketAttachmentState.uploading
      ..progress = 0
      ..error = null;
    _notify();

    String? error;
    String? url;
    final prepared = await _preparer(item.localPath);
    if (prepared == null) {
      error = S.imageCouldNotRead;
    } else if (await _sizeOf(prepared) > maxBytes) {
      error = S.imagesMust10MbSmaller;
    } else {
      (url, error) = await _uploader(prepared, (value) {
        if (!_items.contains(item)) return;
        item.progress = value;
        _notify();
      });
    }

    if (_disposed || !_items.contains(item)) return;
    item
      ..url = url
      ..error = url == null ? (error ?? S.uploadFailedTryAgainLater) : null
      ..progress = url == null ? 0 : 1
      ..state = url == null ? TicketAttachmentState.failed : TicketAttachmentState.uploaded;
    _notify();
  }

  static Future<int> _fileSize(String path) async {
    try {
      return await File(path).length();
    } catch (_) {
      return 0;
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

Future<void> pickTicketImages(BuildContext context, TicketAttachmentController controller) async {
  if (controller.remaining <= 0) {
    showAppSnackBar(context, S.up4ImagesPerMessage, isError: true);
    return;
  }
  final paths = await PhotoService.pickImages(context, remaining: controller.remaining);
  if (paths.isEmpty) return;
  HapticFeedback.selectionClick();
  await controller.add(paths);
}

class TicketAttachmentStrip extends StatelessWidget {
  final TicketAttachmentController controller;
  final VoidCallback? onAdd;
  final double tileSize;
  final bool enabled;

  const TicketAttachmentStrip({
    super.key,
    required this.controller,
    this.onAdd,
    this.tileSize = 76,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final items = controller.items;
        final canAdd = onAdd != null && controller.remaining > 0;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final (index, item) in items.indexed)
              _AttachmentTile(
                key: ValueKey('ticket-attachment-${item.key}'),
                item: item,
                index: index,
                size: tileSize,
                onRemove: enabled ? () => controller.remove(item) : null,
                onRetry: enabled ? () => controller.retry(item) : null,
              ),
            if (canAdd) _AddTile(size: tileSize, count: items.length, onTap: enabled ? onAdd : null),
          ],
        );
      },
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  final TicketAttachment item;
  final int index;
  final double size;
  final VoidCallback? onRemove;
  final VoidCallback? onRetry;

  const _AttachmentTile({
    super.key,
    required this.item,
    required this.index,
    required this.size,
    this.onRemove,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final failed = item.state == TicketAttachmentState.failed;
    final uploading = item.state == TicketAttachmentState.uploading;
    final cacheWidth = (size * MediaQuery.devicePixelRatioOf(context)).round();

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(
                    File(item.localPath),
                    fit: BoxFit.cover,
                    cacheWidth: cacheWidth,
                    errorBuilder: (_, _, _) => ColoredBox(
                      color: c.skeleton,
                      child: Icon(Icons.image_outlined, color: c.iconInactive),
                    ),
                  ),
                  AnimatedOpacity(
                    opacity: uploading || failed ? 1 : 0,
                    duration: Motion.base,
                    child: ColoredBox(color: Colors.black.withValues(alpha: 0.45)),
                  ),
                  if (uploading)
                    Center(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          value: item.progress > 0 && item.progress < 1 ? item.progress : null,
                          strokeWidth: 3,
                          color: Colors.white,
                          backgroundColor: Colors.white24,
                        ),
                      ),
                    ),
                  if (failed)
                    Semantics(
                      container: true,
                      button: true,
                      label: S.retryUploadingImageP0(index + 1),
                      child: InkWell(
                        onTap: onRetry,
                        child: Tooltip(
                          message: item.error ?? '',
                          child: const Center(child: Icon(Icons.refresh_rounded, color: Colors.white, size: 26)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (failed) Positioned(left: 4, bottom: 4, child: Icon(Icons.error_rounded, size: 16, color: c.danger)),
          Positioned(
            top: -6,
            right: -6,
            child: Semantics(
              container: true,
              button: true,
              label: S.removeImageP0(index + 1),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onRemove,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: c.textPrimary,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.card, width: 2),
                  ),
                  child: Icon(Icons.close_rounded, size: 14, color: c.card),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  final double size;
  final int count;
  final VoidCallback? onTap;

  const _AddTile({required this.size, required this.count, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Semantics(
      container: true,
      button: true,
      label: S.addImages,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: c.inputFill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_photo_alternate_outlined, size: 24, color: c.textSecondary),
              const SizedBox(height: 4),
              Text(
                '$count/${TicketAttachmentController.maxCount}',
                style: TextStyle(fontSize: 11, color: c.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TicketImageGrid extends StatelessWidget {
  final List<String> urls;
  final double maxWidth;
  final String? title;

  const TicketImageGrid({super.key, required this.urls, required this.maxWidth, this.title});

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return const SizedBox.shrink();
    const gap = 6.0;
    final single = urls.length == 1;
    final tile = single ? maxWidth.clamp(0.0, 220.0) : ((maxWidth - gap) / 2).clamp(0.0, 132.0);
    final cacheWidth = (tile * MediaQuery.devicePixelRatioOf(context)).round();

    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: [
        for (final (index, url) in urls.indexed)
          Semantics(
            container: true,
            button: true,
            image: true,
            label: S.viewImageP0(index + 1),
            child: GestureDetector(
              onTap: () => ImageViewer.openGallery(context, imageUrls: urls, initialIndex: index, title: title),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AppNetworkImage(
                  url: url,
                  width: tile,
                  height: single ? tile * 0.75 : tile,
                  cacheWidth: cacheWidth,
                  fallbackIcon: Icons.image_outlined,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
