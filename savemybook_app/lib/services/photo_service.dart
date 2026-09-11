import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../screens/image_crop_screen.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/state_views.dart';

class PhotoService {
  static final ImagePicker _picker = ImagePicker();

  /// 回傳裁切後的檔案路徑；使用者中途取消則回傳 null。
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

  /// 一次選多張（只有相簿才支援），每張都會依序進裁切畫面。
  /// 拍照則是一次一張。
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
        if (context.mounted) showAppSnackBar(context, '無法開啟相簿，請確認已授權', isError: true);
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
      // 這張跳過裁切就不收，讓使用者可以邊裁邊淘汰。
      if (cropped != null) results.add(cropped);
    }
    return results;
  }

  static Future<ImageSource?> _askSource(BuildContext context) async {
    final choice = await showOptionSheet<ImageSource>(
      context,
      title: '選擇照片來源',
      options: const [
        SheetOption(
          value: ImageSource.camera,
          label: '拍照',
          icon: Icons.photo_camera_outlined,
        ),
        SheetOption(
          value: ImageSource.gallery,
          label: '從相簿選擇',
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
          source == ImageSource.camera ? '無法開啟相機，請確認已授權' : '無法開啟相簿，請確認已授權',
          isError: true,
        );
      }
      return null;
    }
  }
}
