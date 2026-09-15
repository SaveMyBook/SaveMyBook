import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../i18n/strings.dart';
import '../services/image_save_service.dart';
import '../utils/app_colors.dart';
import 'state_views.dart';

Future<bool> saveImagesWithFeedback(
  BuildContext context,
  List<String> urls, {
  ValueChanged<double>? onProgress,
  bool showProgressDialog = false,
}) async {
  if (urls.isEmpty) return false;
  final progress = ValueNotifier<double>(0);
  final navigator = Navigator.of(context, rootNavigator: true);
  DialogRoute<void>? route;
  if (showProgressDialog) {
    route = DialogRoute<void>(
      context: context,
      themes: InheritedTheme.capture(from: context, to: navigator.context),
      barrierDismissible: false,
      barrierColor: AppColors.of(context).scrim,
      builder: (_) => PopScope(canPop: false, child: _SavingDialog(progress: progress, count: urls.length)),
    );
    navigator.push(route);
  }

  final ok = await ImageSaveService.saveUrls(urls, onProgress: (value) {
    progress.value = value;
    onProgress?.call(value);
  });

  if (route != null) {
    if (route.isCurrent) {
      navigator.pop();
    } else if (route.isActive) {
      navigator.removeRoute(route);
    }
  }
  if (!context.mounted) return ok;
  if (ok) HapticFeedback.lightImpact();
  final downloads = ImageSaveService.savesToDownloads;
  showAppSnackBar(
    context,
    ok ? (downloads ? S.savedDownloads : S.savedPhotos) : (downloads ? S.couldNotSaveImage : S.couldNotSaveCheckPhotoLibrary),
    isError: !ok,
  );
  return ok;
}

class _SavingDialog extends StatelessWidget {
  final ValueNotifier<double> progress;
  final int count;

  const _SavingDialog({required this.progress, required this.count});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 260),
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
        decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(16)),
        child: Material(
          type: MaterialType.transparency,
          child: ValueListenableBuilder<double>(
            valueListenable: progress,
            builder: (context, value, _) {
              final done = (value * count).floor().clamp(0, count);
              final current = done < count ? done + 1 : count;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    count > 1 ? S.savingImagesP0P1(current, count) : S.savingImage,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: value <= 0 ? null : value,
                      minHeight: 6,
                      color: c.accent,
                      backgroundColor: c.inputFill,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
