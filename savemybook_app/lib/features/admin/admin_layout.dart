import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../utils/app_colors.dart';
import '../../widgets/master_detail.dart';
import '../../widgets/responsive.dart';
import '../../widgets/state_views.dart';

class AdminFrame {
  final double width;

  const AdminFrame(this.width);

  static const double gridMaxWidth = 1200;

  ScreenSize get size => Breakpoints.sizeFor(width);

  bool get isWide => size != ScreenSize.compact;

  bool get isExpanded => size == ScreenSize.expanded;

  EdgeInsets inset(EdgeInsets base, {double maxWidth = Breakpoints.listMaxWidth}) {
    final side = (width - maxWidth) / 2;
    return EdgeInsets.fromLTRB(math.max(base.left, side), base.top, math.max(base.right, side), base.bottom);
  }

  EdgeInsets pad(EdgeInsets base, {double maxWidth = gridMaxWidth}) {
    if (!isWide) return inset(base, maxWidth: maxWidth);
    return inset(EdgeInsets.fromLTRB(math.max(base.left, 24), base.top, math.max(base.right, 24), base.bottom), maxWidth: maxWidth);
  }

  int columns({double minTileWidth = 360, int max = 3}) {
    if (!isWide) return 1;
    final content = math.min(width, gridMaxWidth) - 48;
    return (content / minTileWidth).floor().clamp(1, max);
  }
}

class AdminLayout extends StatelessWidget {
  final Widget Function(BuildContext context, AdminFrame frame) builder;

  const AdminLayout({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) => builder(context, AdminFrame(constraints.maxWidth)));
  }
}

class AdminColumns extends StatelessWidget {
  final List<List<Widget>> columns;
  final double gap;
  final double spacing;

  const AdminColumns({super.key, required this.columns, this.gap = 16, this.spacing = 16});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, column) in columns.indexed) ...[
          if (i > 0) SizedBox(width: gap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (j, child) in column.indexed) ...[
                  if (j > 0) SizedBox(height: spacing),
                  child,
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// [equalHeight] 以 IntrinsicHeight 讓同一列等高；卡片內有寬度設為 double.infinity 的 Wrap 子項時須關閉，
/// 否則 Wrap 的固有高度會少算一行而溢出。
class AdminCardList extends StatelessWidget {
  final AdminFrame frame;
  final EdgeInsets padding;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double minTileWidth;
  final int maxColumns;
  final double gap;
  final ScrollPhysics? physics;
  final Widget? header;
  final bool equalHeight;

  const AdminCardList({
    super.key,
    required this.frame,
    required this.padding,
    required this.itemCount,
    required this.itemBuilder,
    this.minTileWidth = 360,
    this.maxColumns = 3,
    this.gap = 16,
    this.physics,
    this.header,
    this.equalHeight = true,
  });

  @override
  Widget build(BuildContext context) {
    final columns = frame.columns(minTileWidth: minTileWidth, max: maxColumns);
    final offset = header == null ? 0 : 1;
    if (columns <= 1) {
      return ListView.builder(
        physics: physics,
        padding: frame.isWide ? frame.pad(padding) : frame.inset(padding),
        itemCount: itemCount + offset,
        itemBuilder: (context, i) => i < offset ? header! : itemBuilder(context, i - offset),
      );
    }
    final rows = (itemCount / columns).ceil();
    return ListView.builder(
      physics: physics,
      padding: frame.pad(padding),
      itemCount: rows + offset,
      itemBuilder: (context, row) {
        if (row < offset) return header!;
        final first = (row - offset) * columns;
        final cells = Row(
          crossAxisAlignment: equalHeight ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
          children: [
            for (var col = 0; col < columns; col++) ...[
              if (col > 0) SizedBox(width: gap),
              Expanded(child: first + col < itemCount ? itemBuilder(context, first + col) : const SizedBox.shrink()),
            ],
          ],
        );
        return equalHeight ? IntrinsicHeight(child: cells) : cells;
      },
    );
  }
}

class AdminToolbar extends StatelessWidget {
  final AdminFrame frame;
  final Widget search;
  final Widget? filters;
  final EdgeInsets padding;
  final double? searchWidth;

  const AdminToolbar({
    super.key,
    required this.frame,
    required this.search,
    this.filters,
    this.padding = const EdgeInsets.fromLTRB(24, 16, 24, 8),
    this.searchWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: frame.pad(padding),
      child: Row(
        children: [
          if (filters == null)
            Flexible(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: searchWidth ?? 480), child: search))
          else ...[
            SizedBox(width: searchWidth ?? math.min(400, (frame.width - 48) * 0.45), child: search),
            const SizedBox(width: 16),
            Expanded(child: SizedBox(height: 34, child: filters)),
          ],
        ],
      ),
    );
  }
}

class AdminSelectable extends StatelessWidget {
  final List<Object> ids;
  final Widget Function(EdgeInsets margin) builder;

  const AdminSelectable({super.key, required this.ids, required this.builder});

  static const EdgeInsets _spacing = EdgeInsets.only(bottom: 12);

  @override
  Widget build(BuildContext context) {
    if (!MasterDetail.isSplit(context)) return builder(_spacing);
    return Padding(
      padding: _spacing,
      child: AdminSelectionBorder(
        selected: ids.contains(MasterDetail.selectedId(context)),
        child: builder(EdgeInsets.zero),
      ),
    );
  }
}

class AdminSelectionBorder extends StatelessWidget {
  final bool selected;
  final Widget child;

  const AdminSelectionBorder({super.key, required this.selected, required this.child});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: selected ? c.accent : Colors.transparent, width: 1.5),
      ),
      child: child,
    );
  }
}

/// 按鈕本身不可要求無限寬度（例如 PrimaryButton 須設 expand: false），否則在 Row 內無法排版。
class AdminButtonRow extends StatelessWidget {
  final List<Widget> children;
  final double minWidth;

  const AdminButtonRow({super.key, required this.children, this.minWidth = 150});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        for (final (i, child) in children.indexed) ...[
          if (i > 0) const SizedBox(width: 12),
          ConstrainedBox(constraints: BoxConstraints(minWidth: minWidth), child: child),
        ],
      ],
    );
  }
}

class AdminSearchBar extends StatelessWidget {
  final AdminFrame frame;
  final Widget search;
  final Widget? filter;
  final EdgeInsets padding;

  const AdminSearchBar({
    super.key,
    required this.frame,
    required this.search,
    this.filter,
    this.padding = const EdgeInsets.fromLTRB(24, 16, 24, 8),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: frame.isWide ? frame.pad(padding) : EdgeInsets.fromLTRB(16, padding.top, 16, padding.bottom),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Row(
            children: [
              Expanded(child: search),
              if (filter != null) ...[const SizedBox(width: 8), filter!],
            ],
          ),
        ),
      ),
    );
  }
}

class AdminRowList extends StatelessWidget {
  final AdminFrame frame;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final EdgeInsets padding;
  final Widget? header;

  const AdminRowList({
    super.key,
    required this.frame,
    required this.itemCount,
    required this.itemBuilder,
    this.padding = const EdgeInsets.fromLTRB(24, 8, 24, 24),
    this.header,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final offset = header == null ? 0 : 1;
    final base = frame.isWide ? frame.pad(padding) : EdgeInsets.fromLTRB(8, padding.top, 8, padding.bottom);
    return ListView.separated(
      padding: base.copyWith(bottom: base.bottom + bottom),
      itemCount: itemCount + offset,
      separatorBuilder: (_, i) => i < offset
          ? const SizedBox.shrink()
          : Divider(height: 1, thickness: 1, indent: 12, endIndent: 12, color: c.divider),
      itemBuilder: (context, i) => i < offset ? header! : itemBuilder(context, i - offset),
    );
  }
}

class AdminListRow extends StatelessWidget {
  static const double tableWidth = 600;

  final bool selected;
  final VoidCallback? onTap;

  final VoidCallback? onMenu;
  final Widget? leading;
  final String title;
  final List<Widget> tags;
  final String? subtitle;
  final String? detail;

  /// 只在表格排列時顯示，窄列表不顯示；不可放只有這裡才看得到的資訊。
  final Widget? detailFooter;
  final Widget? status;
  final String? amount;
  final String? time;
  final Widget? trailing;

  const AdminListRow({
    super.key,
    required this.title,
    this.selected = false,
    this.onTap,
    this.onMenu,
    this.leading,
    this.tags = const [],
    this.subtitle,
    this.detail,
    this.detailFooter,
    this.status,
    this.amount,
    this.time,
    this.trailing,
  });

  static bool isSelected(BuildContext context, List<Object> ids) => ids.contains(MasterDetail.selectedId(context));

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final radius = BorderRadius.circular(12);
    return Semantics(
      selected: selected,
      child: Material(
        color: selected ? c.accent.withValues(alpha: c.isDark ? 0.28 : 0.18) : Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          onLongPress: onMenu,
          onSecondaryTap: onMenu,
          borderRadius: radius,
          child: LayoutBuilder(
            builder: (context, constraints) => constraints.maxWidth >= tableWidth ? _buildTable(c) : _buildStacked(c),
          ),
        ),
      ),
    );
  }

  TextStyle _titleStyle(AppColors c) =>
      TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: selected ? c.accent : c.textPrimary);

  Widget _title(AppColors c) => Row(
        children: [
          Flexible(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _titleStyle(c))),
          for (final tag in tags) ...[const SizedBox(width: 6), tag],
        ],
      );

  Widget _secondary(AppColors c, String text, {int maxLines = 1}) =>
      Text(text, maxLines: maxLines, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, height: 1.35, color: c.textSecondary));

  Widget _amount(AppColors c) => Text(
        amount!,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c.accent),
      );

  Widget _time(AppColors c) =>
      Text(time!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.textHint));

  Widget _buildTable(AppColors c) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _title(c),
                if (subtitle != null && subtitle!.isNotEmpty) ...[const SizedBox(height: 2), _secondary(c, subtitle!)],
              ],
            ),
          ),
          if (detail != null || detailFooter != null) ...[
            const SizedBox(width: 16),
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (detail != null) _secondary(c, detail!, maxLines: detailFooter == null ? 2 : 1),
                  if (detail != null && detailFooter != null) const SizedBox(height: 6),
                  ?detailFooter,
                ],
              ),
            ),
          ],
          if (status != null) ...[
            const SizedBox(width: 16),
            SizedBox(width: 104, child: Align(alignment: Alignment.centerLeft, child: status!)),
          ],
          if (amount != null) ...[
            const SizedBox(width: 12),
            SizedBox(width: 96, child: Align(alignment: Alignment.centerRight, child: _amount(c))),
          ],
          if (time != null) ...[
            const SizedBox(width: 16),
            SizedBox(width: 120, child: Align(alignment: Alignment.centerRight, child: _time(c))),
          ],
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
  }

  Widget _buildStacked(AppColors c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(child: LayoutBuilder(builder: (context, box) => _stackedLines(c, box.maxWidth))),
          if (trailing != null) ...[const SizedBox(width: 10), Padding(padding: const EdgeInsets.only(top: 6), child: trailing!)],
        ],
      ),
    );
  }

  Widget _stackedLines(AppColors c, double width) {
    final hasDetail = detail != null && detail!.isNotEmpty;
    // 右側的金額、狀態與時間最多佔一半寬度，窄欄（英文、大字）時改為省略而不溢出
    Widget side(Widget child) => ConstrainedBox(constraints: BoxConstraints(maxWidth: width * 0.5), child: child);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(child: _title(c)),
            if (amount != null) ...[const SizedBox(width: 8), side(_amount(c))] else if (time != null) ...[const SizedBox(width: 8), side(_time(c))],
          ],
        ),
        if ((subtitle != null && subtitle!.isNotEmpty) || status != null) ...[
          const SizedBox(height: 3),
          Row(
            children: [
              Expanded(child: subtitle == null ? const SizedBox.shrink() : _secondary(c, subtitle!)),
              if (status != null) ...[const SizedBox(width: 8), side(status!)],
            ],
          ),
        ],
        if (hasDetail || (amount != null && time != null)) ...[
          const SizedBox(height: 3),
          Row(
            children: [
              Expanded(
                child: hasDetail
                    ? Text(detail!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.textHint))
                    : const SizedBox.shrink(),
              ),
              if (amount != null && time != null) ...[const SizedBox(width: 8), side(_time(c))],
            ],
          ),
        ],
      ],
    );
  }
}

class AdminRowThumbnail extends StatelessWidget {
  final String? imageUrl;

  const AdminRowThumbnail({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) => BookThumbnail(imageUrl: imageUrl, width: 36, height: 48, radius: 6);
}
