import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../widgets/app_buttons.dart';
import '../widgets/state_views.dart';
import '../i18n/strings.dart';

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
  final TransformationController _controller = TransformationController();

  ui.Image? _image;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _image?.dispose();
    super.dispose();
  }

  Future<void> _decode() async {
    try {
      final bytes = await File(widget.sourcePath).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() => _image = frame.image);
    } catch (_) {
      if (mounted) setState(() => _error = S.couldNotReadPhoto);
    }
  }

  static const double _actionAreaHeight = 86;

  Size _viewportOf(BoxConstraints constraints) {
    final maxW = constraints.maxWidth - 32;
    final maxH = constraints.maxHeight - 32 - _actionAreaHeight;
    var width = maxW;
    var height = width / widget.aspectRatio;
    if (height > maxH) {
      height = maxH;
      width = height * widget.aspectRatio;
    }
    return Size(width, height);
  }

  Future<void> _confirm(Size viewport) async {
    final image = _image;
    if (image == null || _isSaving) return;

    setState(() => _isSaving = true);
    try {
      final path = await _render(image, viewport);
      if (!mounted) return;
      Navigator.pop(context, path);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      showAppSnackBar(context, S.croppingFailedPleaseTryAgain, isError: true);
    }
  }

  Future<String> _render(ui.Image image, Size viewport) async {
    final matrix = _controller.value;
    final scale = matrix.getMaxScaleOnAxis();
    final translation = matrix.getTranslation();

    final visible = Rect.fromLTWH(
      -translation.x / scale,
      -translation.y / scale,
      viewport.width / scale,
      viewport.height / scale,
    );

    final cover = _coverFactor(image, viewport);
    final dx = (viewport.width - image.width * cover) / 2;
    final dy = (viewport.height - image.height * cover) / 2;

    final src = Rect.fromLTRB(
      (visible.left - dx) / cover,
      (visible.top - dy) / cover,
      (visible.right - dx) / cover,
      (visible.bottom - dy) / cover,
    ).intersect(Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()));

    final outWidth = widget.aspectRatio >= 1
        ? widget.outputSize
        : (widget.outputSize * widget.aspectRatio).round();
    final outHeight = widget.aspectRatio >= 1
        ? (widget.outputSize / widget.aspectRatio).round()
        : widget.outputSize;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, outWidth.toDouble(), outHeight.toDouble()),
      Paint()..color = Colors.white,
    );
    canvas.drawImageRect(
      image,
      src,
      Rect.fromLTWH(0, 0, outWidth.toDouble(), outHeight.toDouble()),
      Paint()..filterQuality = FilterQuality.high,
    );

    final picture = recorder.endRecording();
    final cropped = await picture.toImage(outWidth, outHeight);
    picture.dispose();

    final data = await cropped.toByteData(format: ui.ImageByteFormat.png);
    cropped.dispose();
    if (data == null) throw StateError('encode failed');

    final dir = Directory.systemTemp;
    final file = File('${dir.path}/crop_${DateTime.now().microsecondsSinceEpoch}.png');
    await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    return file.path;
  }

  double _coverFactor(ui.Image image, Size viewport) {
    final byWidth = viewport.width / image.width;
    final byHeight = viewport.height / image.height;
    return byWidth > byHeight ? byWidth : byHeight;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: _isSaving ? null : () => Navigator.pop(context),
                ),
                Expanded(
                  child: Text(
                    S.adjustPhoto,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.restart_alt_rounded, color: Colors.white),
                  tooltip: S.reset,
                  onPressed: _isSaving ? null : () => _controller.value = Matrix4.identity(),
                ),
              ],
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (_error != null) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
                          const SizedBox(height: 12),
                          Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                        ],
                      ),
                    );
                  }

                  final image = _image;
                  if (image == null) {
                    return const Center(child: CircularProgressIndicator(color: Colors.white));
                  }

                  final viewport = _viewportOf(constraints);

                  return Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              widget.circular ? viewport.width / 2 : 12,
                            ),
                            child: SizedBox(
                              width: viewport.width,
                              height: viewport.height,
                              child: InteractiveViewer(
                                transformationController: _controller,
                                minScale: 1,
                                maxScale: 5,
                                clipBehavior: Clip.hardEdge,
                                child: SizedBox(
                                  width: viewport.width,
                                  height: viewport.height,
                                  child: RawImage(image: image, fit: BoxFit.cover),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Container(
                        height: _actionAreaHeight,
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                        child: PrimaryButton(
                          label: S.usePhoto,
                          height: 50,
                          color: c.accent,
                          isLoading: _isSaving,
                          onPressed: () => _confirm(viewport),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
