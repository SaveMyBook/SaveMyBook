import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../features/books/image_crop_screen.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/state_views.dart';
import '../i18n/strings.dart';

class PhotoService {
  static final ImagePicker _picker = ImagePicker();

  static Future<String?> pickAndCrop(
    BuildContext context, {
    double aspectRatio = 1,
    bool circular = false,
    int outputSize = 1080,
  }) async {
    final source = await _askSource(context);
    if (source == null || !context.mounted) return null;

    final picked = await _pick(context, source);
    if (picked == null || !context.mounted) return null;

    return Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => ImageCropScreen(
          sourcePath: picked.path,
          aspectRatio: aspectRatio,
          circular: circular,
          outputSize: outputSize,
        ),
      ),
    );
  }

  static Future<List<String>> pickAndCropMultiple(
    BuildContext context, {
    required int remaining,
    double aspectRatio = 1,
    int outputSize = 1080,
  }) async {
    if (remaining <= 0) return const [];

    final source = await _askSource(context);
    if (source == null || !context.mounted) return const [];

    final List<XFile> picked;
    if (source == ImageSource.camera) {
      final shot = await _pick(context, source);
      picked = shot == null ? const [] : [shot];
    } else {
      try {
        picked = await _picker.pickMultiImage(maxWidth: 2400, maxHeight: 2400, imageQuality: 90);
      } catch (_) {
        if (context.mounted) showAppSnackBar(context, S.couldNotOpenPhotosCheckPermission, isError: true);
        return const [];
      }
    }

    final results = <String>[];
    for (final file in picked.take(remaining)) {
      if (!context.mounted) break;
      final cropped = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (_) => ImageCropScreen(
            sourcePath: file.path,
            aspectRatio: aspectRatio,
            outputSize: outputSize,
          ),
        ),
      );
      if (cropped != null) results.add(cropped);
    }
    return results;
  }

  static Future<List<String>> pickImages(BuildContext context, {required int remaining}) async {
    if (remaining <= 0) return const [];

    final source = await _askSource(context);
    if (source == null || !context.mounted) return const [];

    if (source == ImageSource.camera) {
      final shot = await _pick(context, source);
      return shot == null ? const [] : [shot.path];
    }
    try {
      final picked = remaining == 1
          ? [?await _picker.pickImage(source: source, maxWidth: 2400, maxHeight: 2400, imageQuality: 90)]
          : await _picker.pickMultiImage(maxWidth: 2400, maxHeight: 2400, imageQuality: 90, limit: remaining);
      return [for (final file in picked.take(remaining)) file.path];
    } catch (_) {
      if (context.mounted) showAppSnackBar(context, S.couldNotOpenPhotosCheckPermission, isError: true);
      return const [];
    }
  }

  static bool get canUseCamera => _picker.supportsImageSource(ImageSource.camera);

  static Future<ImageSource?> _askSource(BuildContext context) async {
    if (!canUseCamera) return ImageSource.gallery;
    final choice = await showOptionSheet<ImageSource>(
      context,
      title: S.choosePhotoSource,
      options: [
        SheetOption(
          value: ImageSource.camera,
          label: S.takePhoto,
          icon: Icons.photo_camera_outlined,
        ),
        SheetOption(
          value: ImageSource.gallery,
          label: S.chooseFromPhotos,
          icon: Icons.photo_library_outlined,
        ),
      ],
    );
    return choice;
  }

  static Future<XFile?> _pick(BuildContext context, ImageSource source) async {
    try {
      return await _picker.pickImage(
        source: source,
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 90,
      );
    } catch (_) {
      if (context.mounted) {
        showAppSnackBar(
          context,
          source == ImageSource.camera ? S.couldNotOpenCameraCheckPermission : S.couldNotOpenPhotosCheckPermission,
          isError: true,
        );
      }
      return null;
    }
  }
}
