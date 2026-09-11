import 'package:flutter/material.dart';

class AppColors {
  final bool isDark;
  const AppColors._(this.isDark);

  factory AppColors.of(BuildContext context) {
    return AppColors._(Theme.of(context).brightness == Brightness.dark);
  }

  static const primary = Color(0xFF627D8D);
  static const primaryDark = Color(0xFF8FA9B8);

  static AppColors light() => const AppColors._(false);
  static AppColors dark() => const AppColors._(true);

  Color get accent => isDark ? primaryDark : primary;

  Color get scaffold => isDark ? const Color(0xFF121212) : const Color(0xFFF3F5F7);
  Color get card => isDark ? const Color(0xFF1E1E1E) : Colors.white;
  Color get cardAlt => isDark ? const Color(0xFF252525) : const Color(0xFFFAFBFC);
  Color get inputFill => isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF3F5F7);
  Color get headerBg => isDark ? const Color(0xFF1A2F38) : const Color(0xFF627D8D);
  Color get sheetBg => isDark ? const Color(0xFF1E1E1E) : Colors.white;
  Color get scrim => Colors.black.withValues(alpha: isDark ? 0.7 : 0.5);

  Color get textPrimary => isDark ? const Color(0xFFE8E8E8) : const Color(0xFF151E27);
  Color get textSecondary => isDark ? const Color(0xFF9E9E9E) : Colors.black54;
  Color get textHint => isDark ? const Color(0xFF666666) : Colors.grey.shade400;
  Color get onHeader => Colors.white;

  Color get danger => isDark ? const Color(0xFFEF6C6C) : const Color(0xFFD64545);
  Color get success => isDark ? const Color(0xFF5FC98A) : const Color(0xFF2E9E5B);
  Color get warning => isDark ? const Color(0xFFE9A94A) : const Color(0xFFD98613);

  Color get categoryChip => isDark ? const Color(0xFF2A3A42) : const Color(0xFFE8ECEF);
  Color get divider => isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.2);
  Color get border => isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08);
  Color get navBarBg => isDark ? const Color(0xFF1E1E1E).withValues(alpha: 0.92) : Colors.white.withValues(alpha: 0.88);
  Color get navBarBorder => isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.6);
  Color get shadow => isDark ? Colors.black.withValues(alpha: 0.45) : Colors.black.withValues(alpha: 0.12);
  Color get iconInactive => isDark ? const Color(0xFF777777) : Colors.grey.shade400;

  Color get skeleton => isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE6EAEE);

  /// 代幣、點數這類「價值」的強調色。刻意跟 accent 分開，
  /// 金額才不會跟一般的可點擊元素混在一起。
  static const valueGradient = [Color(0xFFFFE082), Color(0xFFFFC107)];

  Color conditionColor(String level) {
    switch (level) {
      case 'like_new': return isDark ? const Color(0xFF4DB6AC) : const Color(0xFF26A69A);
      case 'good': return isDark ? const Color(0xFF81C784) : const Color(0xFF66BB6A);
      case 'fair': return isDark ? const Color(0xFFFFB74D) : const Color(0xFFFFA726);
      case 'poor': return isDark ? const Color(0xFFE57373) : const Color(0xFFEF5350);
      default: return neutral;
    }
  }

  Color get neutral => const Color(0xFF90A4AE);

  /// 訂單狀態的語意色。買賣雙方與後台共用同一組對應，
  /// 同一個狀態在哪一頁都是同一個顏色。
  Color orderStatusColor(String status) {
    switch (status) {
      case 'completed': return success;
      case 'cancelled':
      case 'refunded': return danger;
      case 'refunding': return warning;
      default: return accent;
    }
  }

  Color bookStatusColor(String status) {
    switch (status) {
      case 'on_sale': return success;
      case 'reserved': return warning;
      case 'sold': return accent;
      case 'removed': return iconInactive;
      default: return neutral;
    }
  }

  Color ticketStatusColor(String status) {
    switch (status) {
      case 'pending': return warning;
      case 'resolved': return success;
      case 'closed': return iconInactive;
      default: return accent;
    }
  }

  Color reportStatusColor(String status) {
    switch (status) {
      case 'pending': return warning;
      case 'reviewing': return accent;
      case 'resolved': return success;
      case 'dismissed': return iconInactive;
      default: return neutral;
    }
  }

  Color slotStatusColor(String status) {
    switch (status) {
      case 'empty': return success;
      case 'occupied': return accent;
      case 'reserved': return warning;
      case 'maintenance': return danger;
      default: return neutral;
    }
  }
}
