import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final c = isDark ? AppColors.dark() : AppColors.light();

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: c.accent,
      onPrimary: Colors.white,
      primaryContainer: c.categoryChip,
      onPrimaryContainer: c.accent,
      secondary: c.accent,
      onSecondary: Colors.white,
      error: c.danger,
      onError: Colors.white,
      surface: c.card,
      onSurface: c.textPrimary,
      surfaceContainerHighest: c.inputFill,
      onSurfaceVariant: c.textSecondary,
      outline: c.border,
      outlineVariant: c.divider,
      shadow: c.shadow,
      scrim: c.scrim,
      inverseSurface: isDark ? Colors.white : const Color(0xFF2A2A2A),
      onInverseSurface: isDark ? Colors.black : Colors.white,
      inversePrimary: c.accent,
    );

    final baseText = TextStyle(color: c.textPrimary);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      primaryColor: c.accent,
      scaffoldBackgroundColor: c.scaffold,
      canvasColor: c.card,
      dividerColor: c.divider,
      fontFamily: 'NotoSansTC',
      fontFamilyFallback: const ['PingFang TC', 'Heiti TC', 'Noto Sans TC', 'sans-serif'],
      splashColor: isDark ? Colors.white12 : Colors.black12,
      highlightColor: isDark ? Colors.white10 : Colors.black12,
      // 一定要用 Cupertino 這個 builder：左滑返回的手勢偵測器綁在它裡面，
      // 換成自訂的轉場等於把整個 App 的左滑返回一起關掉。
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      // 全站的下拉更新一次定調，35 個列表頁不用各自設一遍。
      refreshIndicatorTheme: RefreshIndicatorThemeData(
        color: c.accent,
        backgroundColor: c.card,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.headerBg,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          fontFamily: 'NotoSansTC',
        ),
      ),
      cardTheme: CardThemeData(
        color: c.card,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: TextStyle(
          color: c.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.bold,
          fontFamily: 'NotoSansTC',
        ),
        contentTextStyle: TextStyle(color: c.textSecondary, fontSize: 14, fontFamily: 'NotoSansTC'),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.sheetBg,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: c.sheetBg,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: TextStyle(color: c.textPrimary, fontSize: 14, fontFamily: 'NotoSansTC'),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.accent,
        contentTextStyle: const TextStyle(color: Colors.white, fontFamily: 'NotoSansTC'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.inputFill,
        hintStyle: TextStyle(color: c.textHint, fontSize: 14),
        labelStyle: TextStyle(color: c.textSecondary),
        prefixIconColor: c.iconInactive,
        suffixIconColor: c.iconInactive,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.accent, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.danger, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.danger, width: 1.4),
        ),
        errorStyle: TextStyle(color: c.danger, fontSize: 12),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.accent,
        selectionColor: c.accent.withValues(alpha: 0.3),
        selectionHandleColor: c.accent,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.accent,
        linearTrackColor: c.inputFill,
        circularTrackColor: Colors.transparent,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? c.accent : c.iconInactive,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? c.accent.withValues(alpha: 0.4)
              : c.inputFill,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? c.accent : Colors.transparent,
        ),
        checkColor: const WidgetStatePropertyAll(Colors.white),
        side: BorderSide(color: c.iconInactive, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? c.accent : c.iconInactive,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.iconInactive,
        textColor: c.textPrimary,
      ),
      iconTheme: IconThemeData(color: c.textPrimary),
      tabBarTheme: TabBarThemeData(
        labelColor: c.accent,
        unselectedLabelColor: c.textSecondary,
        indicatorColor: c.accent,
        dividerColor: Colors.transparent,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: c.accent),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: c.accent.withValues(alpha: 0.4),
          disabledForegroundColor: Colors.white70,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.accent,
          side: BorderSide(color: c.accent),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textTheme: TextTheme(
        bodyLarge: baseText,
        bodyMedium: baseText,
        bodySmall: baseText,
        displayLarge: baseText,
        displayMedium: baseText,
        displaySmall: baseText,
        headlineLarge: baseText,
        headlineMedium: baseText,
        headlineSmall: baseText,
        titleLarge: baseText,
        titleMedium: baseText,
        titleSmall: baseText,
        labelLarge: baseText,
        labelMedium: baseText,
        labelSmall: baseText,
      ).apply(fontFamily: 'NotoSansTC'),
    );
  }
}
