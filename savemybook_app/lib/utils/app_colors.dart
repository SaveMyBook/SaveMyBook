import 'package:flutter/material.dart';

class AppColors {
  final bool isDark;
  const AppColors._(this.isDark);

  factory AppColors.of(BuildContext context) {
    return AppColors._(Theme.of(context).brightness == Brightness.dark);
  }

  static const primary = Color(0xFF627D8D);

  Color get scaffold => isDark ? const Color(0xFF121212) : const Color(0xFFF3F5F7);
  Color get card => isDark ? const Color(0xFF1E1E1E) : Colors.white;
  Color get inputFill => isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF3F5F7);
  Color get headerBg => isDark ? const Color(0xFF1A2F38) : const Color(0xFF627D8D);

  Color get textPrimary => isDark ? const Color(0xFFE8E8E8) : const Color(0xFF151E27);
  Color get textSecondary => isDark ? const Color(0xFF9E9E9E) : Colors.black54;
  Color get textHint => isDark ? const Color(0xFF666666) : Colors.grey.shade400;

  Color get categoryChip => isDark ? const Color(0xFF2A3A42) : const Color(0xFFE8ECEF);
  Color get divider => isDark ? Colors.white.withOpacity(0.08) : Colors.grey.withOpacity(0.1);
  Color get navBarBg => isDark ? const Color(0xFF1E1E1E).withOpacity(0.92) : Colors.white.withOpacity(0.88);
  Color get navBarBorder => isDark ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.6);
  Color get shadow => isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.12);
  Color get iconInactive => isDark ? const Color(0xFF777777) : Colors.grey.shade400;
}