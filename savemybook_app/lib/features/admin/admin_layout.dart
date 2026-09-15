import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../widgets/responsive.dart';

class AdminFrame {
  final double width;

  const AdminFrame(this.width);

  ScreenSize get size => Breakpoints.sizeFor(width);

  bool get isWide => size != ScreenSize.compact;

  bool get isExpanded => size == ScreenSize.expanded;

  EdgeInsets inset(EdgeInsets base, {double maxWidth = Breakpoints.listMaxWidth}) {
    final side = (width - maxWidth) / 2;
    return EdgeInsets.fromLTRB(math.max(base.left, side), base.top, math.max(base.right, side), base.bottom);
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
