import 'package:flutter/material.dart';

import '../../widgets/responsive.dart';

class ListingFormLayout {
  const ListingFormLayout._();

  static const double splitWidth = 900;
  static const double splitMaxWidth = 1080;
  static const double gap = 24;

  static bool isSplit(BoxConstraints constraints) => constraints.maxWidth >= splitWidth;

  static EdgeInsets padding(BuildContext context, BoxConstraints constraints, {double top = 16, required double bottom}) {
    return responsiveListPadding(
      constraints,
      maxWidth: isSplit(constraints) ? splitMaxWidth : Breakpoints.formMaxWidth,
      horizontal: context.isWide ? 24 : 16,
      top: top,
      bottom: bottom,
    );
  }

  static Widget columns({required List<Widget> left, required List<Widget> right}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: left),
        ),
        const SizedBox(width: gap),
        Expanded(
          flex: 6,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: right),
        ),
      ],
    );
  }
}

class ListingPhotoStrip extends StatelessWidget {
  final bool grid;
  final List<Widget Function(double width)> tiles;

  const ListingPhotoStrip({super.key, required this.grid, required this.tiles});

  static const double tileWidth = 90;
  static const double spacing = 12;

  static double heightOf(double width) => width * 11 / 9;

  @override
  Widget build(BuildContext context) {
    if (!grid) {
      return SizedBox(
        height: 140,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final tile in tiles) Padding(padding: const EdgeInsets.only(right: spacing), child: tile(tileWidth)),
          ],
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = ((constraints.maxWidth + spacing) / (tileWidth + spacing)).floor().clamp(3, 5);
        final width = ((constraints.maxWidth - spacing * (columns - 1)) / columns).floorToDouble();
        return Wrap(
          spacing: spacing,
          runSpacing: 14,
          children: [for (final tile in tiles) tile(width)],
        );
      },
    );
  }
}
