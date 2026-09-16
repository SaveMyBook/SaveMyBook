import 'dart:io';

import 'package:flutter/material.dart';

import '../utils/app_colors.dart';

/// 圖片載入失敗時，判斷是否為重試也不會成功的永久性錯誤。
///
/// 只有 [NetworkImageLoadException] 帶得到 HTTP 狀態碼；4xx（含 404）代表檔案
/// 在伺服器上已不存在，必須停止自動重試，否則每張失敗的圖都會固定打好幾次後端。
bool isPermanentImageError(Object error) {
  if (error is NetworkImageLoadException) return error.statusCode >= 400 && error.statusCode < 500;
  if (error is SocketException || error is HttpException) return false;
  if (error is FileSystemException) return true;
  return false;
}

/// 本地資產圖片的統一入口：檔案不存在時顯示同尺寸的品牌色替代圖。
///
/// `Image.asset` 找不到資產時只會經由 errorBuilder 回報，沒有 errorBuilder 就會
/// 把例外丟到畫面上，因此所有資產圖一律走這個元件。
class AppAssetImage extends StatelessWidget {
  final String asset;
  final double? width;
  final double? height;
  final BoxFit fit;
  final int? cacheWidth;
  final IconData fallbackIcon;
  final Color? fallbackBackground;
  final Color? fallbackIconColor;
  final double? fallbackIconSize;
  final Widget? fallback;
  final String? semanticLabel;

  const AppAssetImage({
    super.key,
    required this.asset,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.cacheWidth,
    this.fallbackIcon = Icons.image_not_supported_outlined,
    this.fallbackBackground,
    this.fallbackIconColor,
    this.fallbackIconSize,
    this.fallback,
    this.semanticLabel,
  });

  double _iconSize() {
    final custom = fallbackIconSize;
    if (custom != null) return custom;
    final box = [width, height].whereType<double>();
    if (box.isEmpty) return 24;
    return (box.reduce((a, b) => a < b ? a : b) * 0.5).clamp(12.0, 48.0);
  }

  Widget _buildFallback(BuildContext context) {
    final custom = fallback;
    if (custom != null) return SizedBox(width: width, height: height, child: custom);
    final c = AppColors.of(context);
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      color: fallbackBackground ?? c.accent.withValues(alpha: 0.12),
      child: Icon(fallbackIcon, size: _iconSize(), color: fallbackIconColor ?? c.accent.withValues(alpha: 0.75)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      width: width,
      height: height,
      fit: fit,
      cacheWidth: cacheWidth,
      semanticLabel: semanticLabel,
      errorBuilder: (context, _, _) => _buildFallback(context),
    );
  }
}
