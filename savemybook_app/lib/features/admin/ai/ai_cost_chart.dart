import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/ai.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/motion.dart';
import '../../../widgets/animations.dart';
import '../../../widgets/state_views.dart';
import 'ai_labels.dart';
import '../../../i18n/strings.dart';

class AiCostChart extends StatefulWidget {
  final AiCostChartData data;
  final double height;

  const AiCostChart({super.key, required this.data, this.height = 190});

  @override
  State<AiCostChart> createState() => _AiCostChartState();
}

class _AiCostChartState extends State<AiCostChart> {
  int? _selected;

  @override
  void didUpdateWidget(covariant AiCostChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.data, widget.data)) _selected = null;
  }

  static const _axisWidth = 58.0;
  static const _labelHeight = 22.0;

  void _pick(Offset position, double width) {
    final n = widget.data.columns.length;
    if (n == 0) return;
    final plot = width - _axisWidth;
    final x = position.dx - _axisWidth;
    if (x < 0) return;
    final index = (x / plot * n).floor().clamp(0, n - 1);
    if (index != _selected) {
      HapticFeedback.selectionClick();
      setState(() => _selected = index);
    }
  }

  static String dayLabel(String iso, {bool withMonth = true}) {
    final parts = iso.split('-');
    if (parts.length < 3) return iso;
    final month = int.tryParse(parts[1]) ?? 0;
    final day = int.tryParse(parts[2]) ?? 0;
    return withMonth ? '$month/$day' : '$day';
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final data = widget.data;
    final total = data.columns.fold<double>(0, (sum, col) => sum + col.total);
    final selected = _selected == null || _selected! >= data.columns.length ? null : data.columns[_selected!];

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  S.dailyCost,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c.textPrimary),
                ),
              ),
              if (selected != null)
                GestureDetector(
                  onTap: () => setState(() => _selected = null),
                  child: Icon(Icons.close_rounded, size: 18, color: c.textHint),
                ),
            ],
          ),
          const SizedBox(height: 8),
          AnimatedSize(
            duration: Motion.base,
            curve: Motion.standard,
            alignment: Alignment.topLeft,
            child: SwitchIn(
              duration: Motion.micro,
              child: selected == null
                  ? _summaryLine(c, total, data.peak, key: const ValueKey('total'))
                  : _selectionDetail(c, selected, key: ValueKey(selected.date)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: widget.height,
            child: data.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bar_chart_rounded, size: 36, color: c.iconInactive),
                        const SizedBox(height: 6),
                        Text(S.noCostPeriod, style: TextStyle(fontSize: 13, color: c.textSecondary)),
                      ],
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) => GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (d) => _pick(d.localPosition, constraints.maxWidth),
                      onHorizontalDragUpdate: (d) => _pick(d.localPosition, constraints.maxWidth),
                      child: TweenAnimationBuilder<double>(
                        key: ValueKey(data),
                        tween: Tween(begin: 0, end: 1),
                        duration: Motion.large,
                        curve: Motion.emphasized,
                        builder: (context, progress, _) => CustomPaint(
                          size: Size(constraints.maxWidth, widget.height),
                          painter: AiCostChartPainter(
                            data: data,
                            progress: progress,
                            selected: _selected,
                            colorOf: (f) => AiLabels.featureColor(c, f),
                            gridColor: c.divider,
                            labelColor: c.textHint,
                            highlightColor: c.accent.withValues(alpha: c.isDark ? 0.14 : 0.08),
                            axisWidth: _axisWidth,
                            labelHeight: _labelHeight,
                            textScaler: MediaQuery.textScalerOf(context),
                            labelStyle: DefaultTextStyle.of(context).style,
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
          if (data.features.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                for (final f in data.features) _legend(c, AiLabels.feature(f), AiLabels.featureColor(c, f)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryLine(AppColors c, double total, double peak, {Key? key}) {
    return Wrap(
      key: key,
      spacing: 14,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _metric(c, S.total, formatUsd(total)),
        _metric(c, S.peakDay, formatUsd(peak)),
      ],
    );
  }

  Widget _metric(AppColors c, String label, String value) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '$label ', style: TextStyle(fontSize: 12, color: c.textSecondary)),
          TextSpan(text: value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: c.textPrimary)),
        ],
      ),
    );
  }

  Widget _selectionDetail(AppColors c, AiChartColumn column, {Key? key}) {
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: c.inputFill, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(dayLabel(column.date), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: c.textPrimary)),
              Text(formatUsd(column.total), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: c.accent)),
              Text(S.p0Requests(formatCount(column.requests)), style: TextStyle(fontSize: 12, color: c.textSecondary)),
            ],
          ),
          if (column.segments.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 12,
              runSpacing: 2,
              children: [
                for (final s in column.segments.reversed)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: AiLabels.featureColor(c, s.feature), borderRadius: BorderRadius.circular(2)),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${AiLabels.feature(s.feature)} ${formatUsd(s.value)}',
                        style: TextStyle(fontSize: 11.5, color: c.textSecondary),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _legend(AppColors c, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 11.5, color: c.textSecondary)),
      ],
    );
  }
}

class AiCostChartPainter extends CustomPainter {
  final AiCostChartData data;
  final double progress;
  final int? selected;
  final Color Function(String feature) colorOf;
  final Color gridColor;
  final Color labelColor;
  final Color highlightColor;
  final double axisWidth;
  final double labelHeight;
  final TextScaler textScaler;
  final TextStyle? labelStyle;

  AiCostChartPainter({
    required this.data,
    required this.progress,
    required this.selected,
    required this.colorOf,
    required this.gridColor,
    required this.labelColor,
    required this.highlightColor,
    required this.axisWidth,
    required this.labelHeight,
    required this.textScaler,
    this.labelStyle,
  });

  void _text(Canvas canvas, String text, Offset anchor, {TextAlign align = TextAlign.left, double maxWidth = 80}) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: (labelStyle ?? const TextStyle()).copyWith(fontSize: 10, color: labelColor, fontWeight: FontWeight.normal)),
      textDirection: TextDirection.ltr,
      textScaler: textScaler.clamp(maxScaleFactor: 1.3),
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
    final dx = switch (align) {
      TextAlign.right => anchor.dx - painter.width,
      TextAlign.center => anchor.dx - painter.width / 2,
      _ => anchor.dx,
    };
    painter.paint(canvas, Offset(dx, anchor.dy - painter.height / 2));
    painter.dispose();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final n = data.columns.length;
    if (n == 0) return;
    final plotTop = 6.0;
    final plotBottom = size.height - labelHeight;
    final plotHeight = plotBottom - plotTop;
    final plotWidth = size.width - axisWidth;
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    for (var i = 0; i <= 4; i++) {
      final y = plotBottom - plotHeight * i / 4;
      canvas.drawLine(Offset(axisWidth, y), Offset(size.width, y), grid);
      if (i.isEven) {
        _text(canvas, formatUsd(data.axisMax * i / 4, compact: true), Offset(axisWidth - 6, y), align: TextAlign.right, maxWidth: axisWidth - 6);
      }
    }

    final slot = plotWidth / n;
    final barWidth = math.min(28.0, math.max(2.0, slot * (n > 20 ? 0.62 : 0.56)));
    final radius = Radius.circular(math.min(5, barWidth / 3));

    if (selected != null && selected! < n) {
      final left = axisWidth + slot * selected!;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(left + 1, plotTop - 4, slot - 2, plotHeight + 4), const Radius.circular(6)),
        Paint()..color = highlightColor,
      );
    }

    for (var i = 0; i < n; i++) {
      final column = data.columns[i];
      final centerX = axisWidth + slot * (i + 0.5);
      final dim = selected != null && selected != i;
      final fullHeight = column.total / data.axisMax * plotHeight * progress;
      if (column.total <= 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(centerX, plotBottom - 1), width: barWidth, height: 2), const Radius.circular(1)),
          Paint()..color = gridColor,
        );
        continue;
      }
      final barHeight = math.max(2.0, fullHeight);
      final barRect = Rect.fromLTWH(centerX - barWidth / 2, plotBottom - barHeight, barWidth, barHeight);
      canvas.save();
      canvas.clipRRect(RRect.fromRectAndCorners(barRect, topLeft: radius, topRight: radius));
      var y = plotBottom;
      for (final segment in column.segments) {
        final h = column.total == 0 ? 0.0 : barHeight * segment.value / column.total;
        final color = colorOf(segment.feature);
        canvas.drawRect(
          Rect.fromLTWH(barRect.left, y - h, barWidth, h + 0.5),
          Paint()..color = dim ? color.withValues(alpha: 0.35) : color,
        );
        y -= h;
      }
      canvas.restore();
    }

    final labels = data.labelIndices(maxLabels: math.max(2, (plotWidth / 44).floor()));
    for (final i in labels) {
      final centerX = axisWidth + slot * (i + 0.5);
      final label = _AiCostChartState.dayLabel(data.columns[i].date);
      _text(canvas, label, Offset(centerX, plotBottom + labelHeight / 2 + 2), align: TextAlign.center, maxWidth: 44);
    }
  }

  @override
  bool shouldRepaint(covariant AiCostChartPainter old) =>
      old.data != data ||
      old.progress != progress ||
      old.selected != selected ||
      old.gridColor != gridColor ||
      old.labelColor != labelColor ||
      old.highlightColor != highlightColor;
}
