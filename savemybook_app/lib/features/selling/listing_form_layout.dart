import 'package:flutter/material.dart';

import '../../i18n/strings.dart';
import '../../utils/app_colors.dart';
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

  static Widget action(BuildContext context, Widget button) {
    if (!context.isWide) return button;
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: ConstrainedBox(constraints: const BoxConstraints(minWidth: 200), child: button),
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

class ListingStepIndicator extends StatelessWidget {
  final int step;

  const ListingStepIndicator({super.key, required this.step});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final labels = [S.bookDetails, S.detailsPhotos];
    return Semantics(
      label: '$step / ${labels.length}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) Container(width: 28, height: 1.5, margin: const EdgeInsets.symmetric(horizontal: 10), color: c.divider),
            _dot(c, i + 1),
            const SizedBox(width: 8),
            Text(
              labels[i],
              maxLines: 1,
              style: TextStyle(
                fontSize: 13,
                fontWeight: i + 1 == step ? FontWeight.w700 : FontWeight.w500,
                color: i + 1 == step ? c.textPrimary : c.textSecondary,
              ),
            ),
          ],
          const SizedBox(width: 12),
        ],
      ),
    );
  }

  Widget _dot(AppColors c, int index) {
    final done = index < step;
    final current = index == step;
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done || current ? c.accent : Colors.transparent,
        border: done || current ? null : Border.all(color: c.border, width: 1.5),
      ),
      child: done
          ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
          : Text(
              '$index',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: current ? Colors.white : c.textSecondary),
            ),
    );
  }
}
