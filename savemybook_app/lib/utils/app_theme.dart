import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
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

    final menuStyle = MenuStyle(
      backgroundColor: WidgetStatePropertyAll(c.card),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      shadowColor: WidgetStatePropertyAll(c.shadow),
      elevation: const WidgetStatePropertyAll(10),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 6)),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: c.border),
        ),
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      primaryColor: c.accent,
      scaffoldBackgroundColor: c.scaffold,
      canvasColor: c.card,
      dividerColor: c.divider,
      fontFamily: 'NotoSansTC',
      // Noto Sans TC 沒有諺文與部分簡體字，韓文與簡體介面靠這裡的系統字型補；PingFang TC／Heiti TC 補不到，不可排到前面。
      fontFamilyFallback: const [
        'PingFang SC',
        'Apple SD Gothic Neo',
        'Hiragino Sans',
        'Noto Sans CJK SC',
        'Noto Sans CJK KR',
        'Noto Sans CJK JP',
      ],
      splashColor: isDark ? Colors.white12 : Colors.black12,
      highlightColor: isDark ? Colors.white10 : Colors.black12,
      // 左滑返回的手勢綁在 CupertinoPageTransitionsBuilder 裡，換成自訂轉場會關掉整個 App 的左滑返回。
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
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
        elevation: 12,
        shadowColor: c.shadow,
        barrierColor: c.scrim,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: TextStyle(
          color: c.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.bold,
          fontFamily: 'NotoSansTC',
        ),
        contentTextStyle: TextStyle(color: c.textSecondary, fontSize: 14, height: 1.5, fontFamily: 'NotoSansTC'),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.sheetBg,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: c.sheetBg,
        modalBarrierColor: c.scrim,
        modalElevation: 0,
        dragHandleColor: c.iconInactive.withValues(alpha: 0.5),
        dragHandleSize: const Size(38, 4),
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.card,
        surfaceTintColor: Colors.transparent,
        elevation: 10,
        shadowColor: c.shadow,
        position: PopupMenuPosition.under,
        menuPadding: const EdgeInsets.symmetric(vertical: 6),
        iconColor: c.textPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: c.border),
        ),
        textStyle: TextStyle(color: c.textPrimary, fontSize: 14, fontFamily: 'NotoSansTC'),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.disabled) ? c.textHint : c.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            fontFamily: 'NotoSansTC',
          ),
        ),
      ),
      menuTheme: MenuThemeData(style: menuStyle),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: TextStyle(color: c.textPrimary, fontSize: 14, fontFamily: 'NotoSansTC'),
        menuStyle: menuStyle,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: c.inputFill,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: c.accent, width: 1.4),
          ),
        ),
      ),
      menuButtonTheme: MenuButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(c.textPrimary),
          iconColor: WidgetStatePropertyAll(c.textSecondary),
          overlayColor: WidgetStatePropertyAll(c.accent.withValues(alpha: 0.08)),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 14)),
          textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 14, fontFamily: 'NotoSansTC')),
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: c.card,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shadowColor: c.shadow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        headerBackgroundColor: c.headerBg,
        headerForegroundColor: Colors.white,
        dividerColor: c.divider,
        weekdayStyle: TextStyle(color: c.textSecondary, fontFamily: 'NotoSansTC'),
        dayStyle: const TextStyle(fontFamily: 'NotoSansTC'),
        dayForegroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : states.contains(WidgetState.disabled)
                  ? c.textHint
                  : c.textPrimary,
        ),
        dayBackgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? c.accent : Colors.transparent,
        ),
        todayForegroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? Colors.white : c.accent,
        ),
        todayBackgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? c.accent : Colors.transparent,
        ),
        todayBorder: BorderSide(color: c.accent),
        yearForegroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? Colors.white : c.textPrimary,
        ),
        yearBackgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? c.accent : Colors.transparent,
        ),
        rangeSelectionBackgroundColor: c.accent.withValues(alpha: 0.16),
        cancelButtonStyle: TextButton.styleFrom(foregroundColor: c.textSecondary),
        confirmButtonStyle: TextButton.styleFrom(
          foregroundColor: c.accent,
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'NotoSansTC'),
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: c.card,
        elevation: 12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        hourMinuteShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        dayPeriodShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        hourMinuteColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected) ? c.accent.withValues(alpha: 0.16) : c.inputFill,
        ),
        hourMinuteTextColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected) ? c.accent : c.textPrimary,
        ),
        dayPeriodColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected) ? c.accent.withValues(alpha: 0.16) : Colors.transparent,
        ),
        dayPeriodTextColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected) ? c.accent : c.textSecondary,
        ),
        dayPeriodBorderSide: BorderSide(color: c.border),
        dialBackgroundColor: c.inputFill,
        dialHandColor: c.accent,
        dialTextColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected) ? Colors.white : c.textPrimary,
        ),
        entryModeIconColor: c.textSecondary,
        helpTextStyle: TextStyle(color: c.textSecondary, fontSize: 13, fontFamily: 'NotoSansTC'),
        cancelButtonStyle: TextButton.styleFrom(foregroundColor: c.textSecondary),
        confirmButtonStyle: TextButton.styleFrom(
          foregroundColor: c.accent,
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'NotoSansTC'),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.card,
        contentTextStyle: TextStyle(color: c.textPrimary, fontFamily: 'NotoSansTC'),
        actionTextColor: c.accent,
        closeIconColor: c.textSecondary,
        elevation: 6,
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: c.border),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF3A3A3A) : const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'NotoSansTC'),
      ),
      dividerTheme: DividerThemeData(color: c.divider, thickness: 1, space: 1),
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
              ? c.accent.withValues(alpha: 0.35)
              : c.inputFill,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? Colors.transparent : c.border,
        ),
        overlayColor: WidgetStatePropertyAll(c.accent.withValues(alpha: 0.08)),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? c.accent : Colors.transparent,
        ),
        checkColor: const WidgetStatePropertyAll(Colors.white),
        side: BorderSide(color: c.iconInactive, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
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
