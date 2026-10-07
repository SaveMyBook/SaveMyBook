import 'dart:math' as math;

import 'package:flutter/gestures.dart' show HitTestResult;
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
  final bool popover;

  const _DialogSheetScope({required super.child, this.popover = false});

  @override
  bool updateShouldNotify(_DialogSheetScope oldWidget) => false;
}

/// 目前是否以置中對話框呈現（見 [showAppModalSheet]）。
bool isDialogSheet(BuildContext context) => context.getInheritedWidgetOfExactType<_DialogSheetScope>() != null;

/// 目前是否以平板的彈出框呈現（見 [showAppPopoverSheet]）；選單項目可改用較緊湊的行高。
bool isPopoverSheet(BuildContext context) => context.getInheritedWidgetOfExactType<_DialogSheetScope>()?.popover ?? false;

/// 面板頂端的拖曳把手；以對話框呈現時不顯示，改留一點上邊距。
class SheetHandle extends StatelessWidget {
  final EdgeInsetsGeometry margin;

  const SheetHandle({super.key, this.margin = const EdgeInsets.only(top: 10, bottom: 12)});

  @override
  Widget build(BuildContext context) {
    if (isPopoverSheet(context)) return const SizedBox(height: 8);
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

/// 記錄最後一次按下的位置，供平板的彈出選單定位（呼叫端多半只傳頁面的 context，無從得知按了哪個按鈕）。
class PointerAnchor extends StatelessWidget {
  final Widget child;

  const PointerAnchor({super.key, required this.child});

  static Offset? _last;
  static int _viewId = 0;
  static DateTime? _at;

  /// 最近 3 秒內按下的元件位置（找不到合適的元件時為按下的點）；太久以前的位置可能與目前開啟的選單無關。
  static Rect? recent() {
    final at = _at;
    final last = _last;
    if (at == null || last == null || DateTime.now().difference(at) > const Duration(seconds: 3)) return null;
    return _targetAt(last) ?? Rect.fromCenter(center: last, width: 1, height: 1);
  }

  // 由按下的點往外找第一個按鈕或列表項目大小的元件，讓彈出框貼齊它的下緣而不是蓋住它
  static Rect? _targetAt(Offset position) {
    final result = HitTestResult();
    WidgetsBinding.instance.hitTestInView(result, position, _viewId);
    for (final entry in result.path) {
      final target = entry.target;
      if (target is! RenderBox || !target.hasSize || !target.attached) continue;
      final size = target.size;
      if (size.width < 28 || size.height < 28) continue;
      if (size.width > 640 || size.height > 160) return null;
      return target.localToGlobal(Offset.zero) & size;
    }
    return null;
  }

  /// 元件在畫面上的位置，作為彈出選單的錨點。
  static Rect? of(BuildContext context) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        _last = event.position;
        _viewId = event.viewId;
        _at = DateTime.now();
      },
      child: child,
    );
  }
}

/// 選單與選擇器：手機維持底部面板，平板在按下的位置（或 [anchor] 元件）旁彈出，找不到位置時改為置中對話框。
Future<T?> showAppPopoverSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Rect? anchor,
  double popoverWidth = 320,
  Color? backgroundColor,
  bool isScrollControlled = false,
  bool useSafeArea = false,
  Color? barrierColor,
  ShapeBorder? shape,
  BoxConstraints? constraints,
  AnimationStyle? sheetAnimationStyle,
  Clip? clipBehavior,
}) {
  final rect = context.isWide ? (anchor ?? PointerAnchor.recent()) : null;
  if (rect == null) {
    return showAppModalSheet<T>(
      context: context,
      builder: builder,
      backgroundColor: backgroundColor,
      isScrollControlled: isScrollControlled,
      useSafeArea: useSafeArea,
      barrierColor: barrierColor,
      shape: shape,
      constraints: constraints,
      sheetAnimationStyle: sheetAnimationStyle,
      clipBehavior: clipBehavior,
    );
  }
  final c = AppColors.of(context);
  return Navigator.of(context, rootNavigator: true).push<T>(
    _PopoverRoute<T>(
      anchor: rect,
      alignToAnchor: anchor != null,
      width: math.max(popoverWidth, anchor?.width ?? 0),
      background: backgroundColor ?? c.sheetBg,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      builder: builder,
    ),
  );
}

class _PopoverRoute<T> extends PopupRoute<T> {
  final Rect anchor;
  final bool alignToAnchor;
  final double width;
  final Color background;
  final WidgetBuilder builder;

  _PopoverRoute({
    required this.anchor,
    required this.alignToAnchor,
    required this.width,
    required this.background,
    required this.barrierLabel,
    required this.builder,
  });

  @override
  final String barrierLabel;

  @override
  Color? get barrierColor => Colors.black.withValues(alpha: 0.08);

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 160);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    final media = MediaQuery.of(context);
    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      removeBottom: true,
      removeLeft: true,
      removeRight: true,
      child: CustomSingleChildLayout(
        delegate: _PopoverLayout(
          anchor: anchor,
          alignToAnchor: alignToAnchor,
          width: width,
          // 鍵盤開啟時（例如可搜尋的選擇器）彈出框要留在鍵盤上方
          safe: media.padding + EdgeInsets.only(bottom: media.viewInsets.bottom),
        ),
        child: Material(
          color: background,
          elevation: 8,
          shadowColor: Colors.black38,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: AppColors.of(context).divider),
          ),
          clipBehavior: Clip.antiAlias,
          child: _DialogSheetScope(popover: true, child: Builder(builder: builder)),
        ),
      ),
    );
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeIn);
    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(scale: Tween<double>(begin: 0.96, end: 1).animate(curved), child: child),
    );
  }
}

class _PopoverLayout extends SingleChildLayoutDelegate {
  static const double _gap = 8;
  static const double _margin = 12;

  final Rect anchor;
  final bool alignToAnchor;
  final double width;
  final EdgeInsets safe;

  _PopoverLayout({required this.anchor, required this.alignToAnchor, required this.width, required this.safe});

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final maxWidth = math.min(width, constraints.maxWidth - _margin * 2);
    final available = constraints.maxHeight - safe.vertical - _margin * 2;
    return BoxConstraints(minWidth: maxWidth, maxWidth: maxWidth, maxHeight: math.min(available, constraints.maxHeight * 0.7));
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final top = safe.top + _margin;
    final bottom = size.height - safe.bottom - _margin;
    double y;
    if (anchor.bottom + _gap + childSize.height <= bottom) {
      y = anchor.bottom + _gap;
    } else if (anchor.top - _gap - childSize.height >= top) {
      y = anchor.top - _gap - childSize.height;
    } else {
      y = math.max(top, bottom - childSize.height);
    }
    final preferred = alignToAnchor ? anchor.left : anchor.center.dx - childSize.width / 2;
    final x = preferred.clamp(_margin, math.max(_margin, size.width - _margin - childSize.width)).toDouble();
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_PopoverLayout oldDelegate) =>
      anchor != oldDelegate.anchor || width != oldDelegate.width || safe != oldDelegate.safe || alignToAnchor != oldDelegate.alignToAnchor;
}
