import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../utils/app_colors.dart';
import '../../../utils/motion.dart';
import '../../../widgets/adaptive_sheet.dart';
import '../../../widgets/app_dialogs.dart';
import '../../../widgets/responsive.dart';

Color tabletSelectionColor(AppColors c) => c.accent.withValues(alpha: c.isDark ? 0.22 : 0.12);

// 淺色模式的輸入框底色與頁面底色相同，分段控制的底槽改用標籤底色才看得出範圍
Color _trackColor(AppColors c) => c.isDark ? c.inputFill : c.categoryChip;

class SegmentOption<T> {
  final T value;
  final String label;
  final int count;

  const SegmentOption(this.value, this.label, {this.count = 0});
}

class SegmentedFilter<T> extends StatelessWidget {
  final List<SegmentOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;

  const SegmentedFilter({super.key, required this.options, required this.value, required this.onChanged});

  static const _labelStyle = TextStyle(fontSize: 13, fontWeight: FontWeight.w600);
  static const double _segmentPadding = 20;

  String _textOf(SegmentOption<T> o) => o.count > 0 ? '${o.label} ${o.count}' : o.label;

  bool _fits(BuildContext context, double width) {
    final per = (width - 6) / options.length - _segmentPadding;
    final style = DefaultTextStyle.of(context).style.merge(_labelStyle);
    for (final o in options) {
      final painter = TextPainter(
        text: TextSpan(text: _textOf(o), style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      final w = painter.width;
      painter.dispose();
      if (w > per) return false;
    }
    return true;
  }

  void _select(T next) {
    if (next == value) return;
    HapticFeedback.selectionClick();
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) =>
          _fits(context, constraints.maxWidth) ? _buildSegments(context) : Align(alignment: Alignment.centerLeft, child: _PullDown<T>(filter: this)),
    );
  }

  Widget _buildSegments(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: _trackColor(c), borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          for (final o in options)
            Expanded(
              child: Semantics(
                button: true,
                selected: o.value == value,
                child: AnimatedContainer(
                  duration: Motion.base,
                  curve: Motion.standard,
                  decoration: BoxDecoration(
                    color: o.value == value ? (c.isDark ? c.categoryChip : c.card) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: o.value == value && !c.isDark
                        ? [BoxShadow(color: c.shadow.withValues(alpha: 0.12), blurRadius: 4, offset: const Offset(0, 1))]
                        : null,
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _select(o.value),
                      child: Center(
                        child: Text(
                          _textOf(o),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _labelStyle.copyWith(
                            fontWeight: o.value == value ? FontWeight.w700 : FontWeight.w500,
                            color: o.value == value ? c.textPrimary : c.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PullDown<T> extends StatelessWidget {
  final SegmentedFilter<T> filter;

  const _PullDown({super.key, required this.filter});

  Future<void> _open(BuildContext context) async {
    final picked = await showAppPopoverSheet<T>(
      context: context,
      anchor: PointerAnchor.of(context),
      popoverWidth: 260,
      builder: (ctx) {
        final c = AppColors.of(ctx);
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 6),
          children: [
            for (final o in filter.options)
              ListTile(
                dense: true,
                title: Text(filter._textOf(o), style: TextStyle(fontSize: 14, color: c.textPrimary)),
                trailing: o.value == filter.value ? Icon(Icons.check_rounded, size: 20, color: c.accent) : null,
                onTap: () => Navigator.pop(ctx, o.value),
              ),
          ],
        );
      },
    );
    if (picked != null) filter._select(picked);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final current = filter.options.firstWhere((o) => o.value == filter.value, orElse: () => filter.options.first);
    return Semantics(
      button: true,
      child: Material(
        color: _trackColor(c),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _open(context),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.filter_list_rounded, size: 18, color: c.accent),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    filter._textOf(current),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SegmentedFilter._labelStyle.copyWith(color: c.textPrimary),
                  ),
                ),
                const SizedBox(width: 2),
                Icon(Icons.expand_more_rounded, size: 20, color: c.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TabletListItem extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onMenu;
  final bool selected;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final Color? color;

  const TabletListItem({
    super.key,
    required this.child,
    this.onTap,
    this.onMenu,
    this.selected = false,
    this.padding = const EdgeInsets.all(12),
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Semantics(
      selected: selected,
      child: Material(
        color: selected ? tabletSelectionColor(c) : (color ?? c.card),
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onMenu,
          onSecondaryTap: onMenu,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class MenuAction {
  final String label;
  final IconData icon;
  final VoidCallback onSelected;
  final bool destructive;

  const MenuAction(this.label, this.icon, this.onSelected, {this.destructive = false});
}

Future<void> showItemMenu(BuildContext context, {required String title, required List<MenuAction> actions}) async {
  if (actions.isEmpty) return;
  final c = AppColors.of(context);
  HapticFeedback.selectionClick();
  final index = await showOptionSheet<int>(
    context,
    title: title,
    options: [
      for (final (i, a) in actions.indexed) SheetOption(value: i, label: a.label, icon: a.icon, color: a.destructive ? c.danger : null),
    ],
  );
  if (index != null) actions[index].onSelected();
}

class CompactActionButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool filled;
  final bool isLoading;
  final double height;

  const CompactActionButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.filled = false,
    this.isLoading = false,
    this.height = 38,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(10));
    // 須沿用主題字型，只給字級時按鈕文字會改用系統預設字型
    final textStyle = Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 14, fontWeight: FontWeight.w600);
    final padding = EdgeInsets.symmetric(horizontal: icon == null ? 16 : 14);
    final content = isLoading
        ? SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: filled ? Colors.white : c.accent),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 17), const SizedBox(width: 6)],
              Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
          );
    final enabled = onPressed != null && !isLoading;
    if (filled) {
      return FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: c.accent.withValues(alpha: 0.4),
          disabledForegroundColor: Colors.white70,
          minimumSize: Size(0, height),
          padding: padding,
          shape: shape,
          textStyle: textStyle,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: content,
      );
    }
    return OutlinedButton(
      onPressed: enabled ? onPressed : null,
      style: OutlinedButton.styleFrom(
        foregroundColor: c.accent,
        side: BorderSide(color: c.accent.withValues(alpha: enabled ? 0.55 : 0.25)),
        minimumSize: Size(0, height),
        padding: padding,
        shape: shape,
        textStyle: textStyle,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: content,
    );
  }
}

class ToolbarTextButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  const ToolbarTextButton({super.key, required this.label, this.icon, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final style = TextButton.styleFrom(
      foregroundColor: c.accent,
      textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
      padding: const EdgeInsets.symmetric(horizontal: 12),
    );
    final text = Text(label, maxLines: 1, overflow: TextOverflow.ellipsis);
    if (icon == null) return TextButton(onPressed: onPressed, style: style, child: text);
    return TextButton.icon(onPressed: onPressed, style: style, icon: Icon(icon, size: 18), label: text);
  }
}

// 輸入法組字中的 Enter 用來確認選字，不可攔截
FocusOnKeyEventCallback enterToSubmit(BuildContext context, TextEditingController controller, VoidCallback onSubmit) {
  return (node, event) {
    if (event is! KeyDownEvent || !context.mounted || !context.isWide) return KeyEventResult.ignored;
    if (event.logicalKey != LogicalKeyboardKey.enter && event.logicalKey != LogicalKeyboardKey.numpadEnter) {
      return KeyEventResult.ignored;
    }
    if (HardwareKeyboard.instance.isShiftPressed || controller.value.composing.isValid) return KeyEventResult.ignored;
    onSubmit();
    return KeyEventResult.handled;
  };
}
