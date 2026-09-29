import 'package:flutter/material.dart';

import '../../i18n/strings.dart';
import '../../widgets/image_viewer.dart';
import '../../widgets/state_views.dart';

class AdminImageStrip extends StatelessWidget {
  final List<String> urls;
  final double size;
  final String? title;

  const AdminImageStrip({super.key, required this.urls, this.size = 72, this.title});

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return const SizedBox.shrink();
    final cacheWidth = (size * MediaQuery.devicePixelRatioOf(context)).round();

    return SizedBox(
      height: size,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: urls.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) => Semantics(
          container: true,
          button: true,
          image: true,
          label: S.viewImageP0(i + 1),
          child: GestureDetector(
            onTap: () => ImageViewer.openGallery(context, imageUrls: urls, initialIndex: i, title: title, allowSave: false),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AppNetworkImage(
                url: urls[i],
                width: size,
                height: size,
                cacheWidth: cacheWidth,
                fallbackIcon: Icons.image_outlined,
                fallbackIconSize: size * 0.35,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
