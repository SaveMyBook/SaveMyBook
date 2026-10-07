import 'package:flutter/material.dart';

import '../../utils/app_colors.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_header.dart';
import '../../widgets/responsive.dart';

/// 平板「設定」樣式的分組清單：圓角群組、群組標題與註腳、列之間的細分隔線。
class TabletListGroup extends StatelessWidget {
  final String? header;
  final String? footer;
  final List<Widget> children;

  const TabletListGroup({super.key, this.header, this.footer, required this.children});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 7),
              child: Text(header!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textSecondary)),
            ),
          Material(
            color: c.card,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final (i, child) in children.indexed) ...[
                  if (i > 0) Divider(height: 1, thickness: 1, indent: child is TabletListRow && !child.hasLeading ? 16 : 52, color: c.divider),
                  child,
                ],
              ],
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 7, 16, 0),
              child: Text(footer!, style: TextStyle(fontSize: 12, height: 1.45, color: c.textSecondary)),
            ),
        ],
      ),
    );
  }
}

/// 分組清單的一列：左側圖示、標題與說明，右側為數值、徽章或自訂元件；選取時顯示品牌色底色。
class TabletListRow extends StatelessWidget {
  final IconData? icon;
  final Widget? leading;
  final String title;
  final String? subtitle;
  final String? value;
  final int badge;
  final Widget? trailing;
  final bool chevron;
  final bool selected;
  final Color? color;
  final bool centered;
  final Widget? bottom;
  final VoidCallback? onTap;

  const TabletListRow({
    super.key,
    this.icon,
    this.leading,
    required this.title,
    this.subtitle,
    this.value,
    this.badge = 0,
    this.trailing,
    this.chevron = true,
    this.selected = false,
    this.color,
    this.centered = false,
    this.bottom,
    this.onTap,
  });

  bool get hasLeading => icon != null || leading != null;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final tint = color ?? (selected ? c.accent : c.textPrimary);
    final glyph = leading ?? (icon == null ? null : Icon(icon, size: 22, color: color ?? (selected ? c.accent : c.textSecondary)));
    final label = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: centered ? TextAlign.center : TextAlign.start,
      style: TextStyle(fontSize: 15, fontWeight: selected ? FontWeight.w600 : FontWeight.w500, color: tint),
    );

    return Semantics(
      button: onTap != null,
      selected: selected,
      child: Material(
        color: selected ? c.accent.withValues(alpha: c.isDark ? 0.22 : 0.12) : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 9, 12, 9),
              child: centered
                  ? Center(child: label)
                  : Row(
                      children: [
                        if (glyph != null) ...[SizedBox(width: 24, child: Center(child: glyph)), const SizedBox(width: 12)],
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              label,
                              if (subtitle != null && subtitle!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  subtitle!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12.5, height: 1.35, color: c.textSecondary),
                                ),
                              ],
                              if (bottom != null) ...[const SizedBox(height: 8), bottom!],
                            ],
                          ),
                        ),
                        if (value != null && value!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 160),
                            child: Text(
                              value!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 14.5, color: c.textSecondary),
                            ),
                          ),
                        ],
                        if (badge > 0) ...[const SizedBox(width: 8), CountBadge(count: badge)],
                        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
                        if (chevron && trailing == null) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.chevron_right_rounded, size: 22, color: c.iconInactive),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 平板主從版面的左欄：工具列與分組清單，與右欄頁首等高相連。
class TabletMasterColumn extends StatelessWidget {
  final String title;
  final List<Widget> actions;
  final List<Widget> children;
  final Widget? footer;
  final double maxWidth;
  final RefreshCallback? onRefresh;

  const TabletMasterColumn({
    super.key,
    required this.title,
    this.actions = const [],
    required this.children,
    this.footer,
    this.maxWidth = double.infinity,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Material(
      color: c.scaffold,
      child: Column(
        children: [
          TabletToolbar(
            title: title,
            showBack: Navigator.maybeOf(context)?.canPop() ?? false,
            actions: actions,
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final side = ((constraints.maxWidth - maxWidth) / 2).clamp(16.0, double.infinity);
                final list = ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(side, 20, side, MediaQuery.paddingOf(context).bottom + 20),
                  children: [...children, ?footer],
                );
                final refresh = onRefresh;
                return refresh == null ? list : RefreshIndicator(color: c.accent, onRefresh: refresh, child: list);
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 表單的主要按鈕：手機撐滿寬度；平板放在欄位右下方、寬度依文字。
class FormActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double height;

  const FormActionButton({super.key, required this.label, this.onPressed, this.isLoading = false, this.height = 48});

  @override
  Widget build(BuildContext context) {
    if (!context.isWide) return PrimaryButton(label: label, height: height, isLoading: isLoading, onPressed: onPressed);
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 160),
        child: PrimaryButton(label: label, height: 44, isLoading: isLoading, onPressed: onPressed, expand: false),
      ),
    );
  }
}
