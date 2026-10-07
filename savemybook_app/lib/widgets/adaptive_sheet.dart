import 'package:flutter/material.dart';

import '../utils/app_colors.dart';
import 'responsive.dart';

/// 由底部滑出的面板：手機維持底部面板，平板等寬螢幕改為置中對話框（底部面板在大螢幕上會拉成整排寬度）。
/// 參數與 [showModalBottomSheet] 相同；面板內容可用 [isDialogSheet] 判斷目前的呈現方式。
Future<T?> showAppModalSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? backgroundColor,
  bool isScrollControlled = false,
  bool isDismissible = true,
  bool enableDrag = true,
  bool useSafeArea = false,
  bool useRootNavigator = false,
  BoxConstraints? constraints,
  ShapeBorder? shape,
  Color? barrierColor,
  RouteSettings? routeSettings,
  AnimationStyle? sheetAnimationStyle,
  Clip? clipBehavior,
  double dialogMaxWidth = 520,
}) {
  if (!context.isWide) {
    return showModalBottomSheet<T>(
      context: context,
      builder: builder,
      backgroundColor: backgroundColor,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      useSafeArea: useSafeArea,
      useRootNavigator: useRootNavigator,
      constraints: constraints,
      shape: shape,
      barrierColor: barrierColor,
      routeSettings: routeSettings,
      sheetAnimationStyle: sheetAnimationStyle,
      clipBehavior: clipBehavior,
    );
  }
  final c = AppColors.of(context);
  // 平板的頁面放在分頁各自的 Navigator 內，對話框一律開在最上層才會蓋住側邊欄
  return showDialog<T>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: isDismissible,
    barrierColor: barrierColor ?? c.scrim,
    routeSettings: routeSettings,
    builder: (ctx) {
      final size = MediaQuery.sizeOf(ctx);
      return Dialog(
        backgroundColor: backgroundColor ?? c.sheetBg,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: dialogMaxWidth, maxHeight: size.height * 0.85),
          child: MediaQuery.removePadding(
            context: ctx,
            removeTop: true,
            removeBottom: true,
            removeLeft: true,
            removeRight: true,
            child: _DialogSheetScope(child: Builder(builder: builder)),
          ),
        ),
      );
    },
  );
}

class _DialogSheetScope extends InheritedWidget {
  const _DialogSheetScope({required super.child});

  @override
  bool updateShouldNotify(_DialogSheetScope oldWidget) => false;
}

/// 目前是否以置中對話框呈現（見 [showAppModalSheet]）。
bool isDialogSheet(BuildContext context) => context.getInheritedWidgetOfExactType<_DialogSheetScope>() != null;

/// 面板頂端的拖曳把手；以對話框呈現時不顯示，改留一點上邊距。
class SheetHandle extends StatelessWidget {
  final EdgeInsetsGeometry margin;

  const SheetHandle({super.key, this.margin = const EdgeInsets.only(top: 10, bottom: 12)});

  @override
  Widget build(BuildContext context) {
    if (isDialogSheet(context)) return const SizedBox(height: 16);
    final c = AppColors.of(context);
    return Padding(
      padding: margin,
      child: Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(color: c.divider, borderRadius: BorderRadius.circular(2)),
        ),
      ),
    );
  }
}
