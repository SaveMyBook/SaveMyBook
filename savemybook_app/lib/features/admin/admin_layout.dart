import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../utils/app_colors.dart';
import '../../widgets/master_detail.dart';
import '../../widgets/responsive.dart';

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
