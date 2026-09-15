import 'dart:math' as math;

import 'package:flutter/material.dart';

enum ScreenSize { compact, medium, expanded }

class Breakpoints {
  static const double medium = 600;
  static const double expanded = 1024;

  static const double formMaxWidth = 640;
  static const double readingMaxWidth = 760;
  static const double listMaxWidth = 960;
  static const double pageMaxWidth = 1280;

  static ScreenSize sizeFor(double width) {
    if (width >= expanded) return ScreenSize.expanded;
    if (width >= medium) return ScreenSize.medium;
    return ScreenSize.compact;
  }

  static int columnsFor(double width, {double minTileWidth = 170, int min = 2, int max = 6}) {
    return (width / minTileWidth).floor().clamp(min, max);
  }
}

extension ResponsiveContext on BuildContext {
  ScreenSize get screenSize => Breakpoints.sizeFor(MediaQuery.sizeOf(this).width);

  bool get isCompact => screenSize == ScreenSize.compact;

  bool get isWide => screenSize != ScreenSize.compact;

  bool get usesSideNavigation => isWide;
}

class ResponsiveCenter extends StatelessWidget {
  final double maxWidth;
  final Widget child;
  final AlignmentGeometry alignment;

  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth = Breakpoints.listMaxWidth,
    this.alignment = Alignment.topCenter,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child),
    );
  }
}

EdgeInsets responsiveListPadding(
  BoxConstraints constraints, {
  double maxWidth = Breakpoints.listMaxWidth,
  double horizontal = 16,
  double top = 16,
  double bottom = 16,
}) {
  final side = math.max(horizontal, (constraints.maxWidth - maxWidth) / 2);
  return EdgeInsets.fromLTRB(side, top, side, bottom);
}

class ResponsiveListPadding extends StatelessWidget {
  final double maxWidth;
  final double horizontal;
  final double top;
  final double bottom;
  final Widget Function(BuildContext context, EdgeInsets padding) builder;

  const ResponsiveListPadding({
    super.key,
    required this.builder,
    this.maxWidth = Breakpoints.listMaxWidth,
    this.horizontal = 16,
    this.top = 16,
    this.bottom = 16,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => builder(
        context,
        responsiveListPadding(constraints, maxWidth: maxWidth, horizontal: horizontal, top: top, bottom: bottom),
      ),
    );
  }
}

double floatingNavClearance(BuildContext context, double navSpace) {
  final bottom = MediaQuery.paddingOf(context).bottom;
  return context.usesSideNavigation ? bottom + 16 : bottom + navSpace;
}
