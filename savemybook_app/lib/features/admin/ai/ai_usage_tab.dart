import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../models/ai.dart';
import '../../../services/api_service.dart';
import '../../../utils/api_helpers.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/motion.dart';
import '../../../widgets/animations.dart';
import '../../../widgets/app_tiles.dart';
import '../../../widgets/state_views.dart';
import '../admin_layout.dart';
import 'ai_cost_chart.dart';
import 'ai_labels.dart';
import '../../../i18n/strings.dart';

class AiUsageTab extends StatefulWidget {
  final VoidCallback? onOpenReviews;
  final ValueChanged<int>? onPendingReviews;

  const AiUsageTab({super.key, this.onOpenReviews, this.onPendingReviews});

  @override
  State<AiUsageTab> createState() => _AiUsageTabState();
}

class _AiUsageTabState extends State<AiUsageTab> with AutomaticKeepAliveClientMixin {
  final ApiService _api = ApiService();
  String _period = 'month';
  AiUsageReport? _report;
  AiCostChartData? _chart;
  String? _error;
  bool _loading = true;
  int _seq = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool showLoading = true}) async {
    final seq = ++_seq;
    if (showLoading) setState(() => _loading = true);
    final result = await _api.fetchAiUsage(_period);
    if (!mounted || seq != _seq) return;
    setState(() {
      _loading = false;
      if (result.isOk && result.data != null) {
        _report = result.data;
        _chart = AiCostChartData.from(result.data!.daily);
        _error = null;
        widget.onPendingReviews?.call(result.data!.pendingReviews);
      } else {
        _error = result.error;
      }
    });
  }

  void _setPeriod(String period) {
    if (period == _period) return;
    setState(() => _period = period);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = AppColors.of(context);
    final report = _report;

    return AdminLayout(
      builder: (context, frame) => Column(
        children: [
          Padding(
            padding: frame.inset(const EdgeInsets.fromLTRB(16, 14, 16, 4), maxWidth: 1200),
            child: Align(alignment: Alignment.centerLeft, child: _periodPicker(c)),
          ),
          Expanded(
            child: SwitchIn(
              child: _loading && report == null
                  ? const LoadingView.list(key: ValueKey('loading'))
                  : report == null
                      ? RefreshableCenter(
                          key: const ValueKey('error'),
                          onRefresh: _load,
                          child: ErrorView(message: _error, onRetry: _load),
                        )
                      : RefreshIndicator(
                          key: const ValueKey('report'),
                          color: c.accent,
                          onRefresh: () => _load(showLoading: false),
                          child: AnimatedOpacity(
                            opacity: _loading ? 0.55 : 1,
                            duration: Motion.micro,
                            child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: frame.inset(const EdgeInsets.fromLTRB(16, 10, 16, 40), maxWidth: 1200),
                              children: _sections(c, report, frame),
                            ),
                          ),
                        ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _sections(AppColors c, AiUsageReport report, AdminFrame frame) {
    final chart = AiCostChart(data: _chart!, height: frame.isWide ? 230 : 180);
    final pending = report.pendingReviews > 0 ? _pendingBanner(c, report.pendingReviews) : null;
    final widgets = <Widget>[];
    void add(Widget w) {
      widgets.add(Padding(
        padding: EdgeInsets.only(top: widgets.isEmpty ? 0 : 14),
        child: RevealOnScroll(index: widgets.length, child: w),
      ));
    }

    if (frame.isWide) {
      add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 4, child: _budgetCard(c, report.summary)),
            const SizedBox(width: 14),
            Expanded(flex: frame.isExpanded ? 7 : 5, child: _statGrid(c, report.summary, columns: frame.isExpanded ? 4 : 2, fill: true)),
          ],
        ),
      ));
      if (pending != null) add(pending);
      add(chart);
      add(AdminColumns(gap: 14, spacing: 14, columns: [
        [_featureCard(c, report)],
        [_providerCard(c, report)],
      ]));
      add(AdminColumns(gap: 14, spacing: 14, columns: [
        [_topUsersCard(c, report)],
        [_errorsCard(c, report)],
      ]));
    } else {
      add(_budgetCard(c, report.summary));
      add(_statGrid(c, report.summary, columns: 2));
      if (pending != null) add(pending);
      add(chart);
      add(_featureCard(c, report));
      add(_providerCard(c, report));
      add(_topUsersCard(c, report));
      add(_errorsCard(c, report));
    }
    return widgets;
  }

  Widget _periodPicker(AppColors c) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: c.categoryChip, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          for (final p in AiLabels.periods)
            Expanded(child: PressableScale(
              scale: 0.95,
              onTap: () => _setPeriod(p),
              child: AnimatedContainer(
                duration: Motion.base,
                curve: Motion.standard,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
                decoration: BoxDecoration(
                  color: _period == p ? c.card : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: _period == p ? [BoxShadow(color: c.shadow.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 1))] : null,
                ),
                alignment: Alignment.center,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    AiLabels.period(p),
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: _period == p ? FontWeight.bold : FontWeight.w500,
                      color: _period == p ? c.textPrimary : c.textSecondary,
                    ),
                  ),
                ),
              ),
            )),
        ],
      ),
    ),
    );
  }

  Widget _budgetCard(AppColors c, AiUsageSummary s) {
    final hasBudget = s.monthlyBudgetUsd > 0;
    final ratio = hasBudget ? s.budgetUsedRatio : 0.0;
    final tone = ratio >= 1 ? c.danger : (ratio >= 0.8 ? c.warning : c.accent);
    final projectedOver = hasBudget && s.projectedMonthCostUsd > s.monthlyBudgetUsd;

    return AppCard(
      child: Row(
        children: [
          SizedBox(
            width: 92,
            height: 92,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: ratio.clamp(0.0, 1.0)),
              duration: Motion.count,
              curve: Motion.emphasized,
              builder: (context, value, _) => CustomPaint(
                painter: BudgetRingPainter(value: value, color: tone, track: c.inputFill),
                child: Center(
                  child: hasBudget
                      ? FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Text(
                              '${(ratio * 100).clamp(0, 999).toStringAsFixed(ratio < 0.1 && ratio > 0 ? 1 : 0)}%',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: tone),
                            ),
                          ),
                        )
                      : Icon(Icons.all_inclusive_rounded, color: c.iconInactive),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(S.month2, style: TextStyle(fontSize: 12, color: c.textSecondary)),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formatUsd(s.monthCostUsd),
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: c.textPrimary),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasBudget ? S.budgetP0(formatUsd(s.monthlyBudgetUsd)) : S.noMonthlyBudget,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: c.textSecondary),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(projectedOver ? Icons.trending_up_rounded : Icons.show_chart_rounded,
                        size: 14, color: projectedOver ? c.warning : c.textHint),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        S.projectedP0(formatUsd(s.projectedMonthCostUsd)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: projectedOver ? FontWeight.bold : FontWeight.normal,
                          color: projectedOver ? c.warning : c.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statGrid(AppColors c, AiUsageSummary s, {required int columns, bool fill = false}) {
    final tiles = [
      _stat(c, Icons.payments_outlined, S.periodCost, formatUsd(s.costUsd), null, c.accent),
      _stat(c, Icons.bolt_rounded, S.requests, formatCount(s.requests),
          s.searchCalls > 0 ? S.p0Searches(formatCount(s.searchCalls)) : null, AiLabels.featureColor(c, AiFeatures.support)),
      _stat(c, Icons.data_usage_rounded, 'Tokens', formatTokens(s.totalTokens),
          S.p0OutP1(formatTokens(s.inputTokens), formatTokens(s.outputTokens)), AiLabels.featureColor(c, AiFeatures.moderation)),
      _stat(c, Icons.error_outline_rounded, S.errors, formatCount(s.errors),
          s.requests > 0 ? S.errorRateP0((s.errorRate * 100).toStringAsFixed(1)) : null, s.errors > 0 ? c.danger : c.success),
    ];
    final rows = <List<Widget>>[];
    for (var i = 0; i < tiles.length; i += columns) {
      rows.add(tiles.sublist(i, math.min(i + columns, tiles.length)));
    }
    return Column(
      children: [
        for (final (i, row) in rows.indexed) ...[
          if (i > 0) const SizedBox(height: 10),
          if (fill)
            Expanded(child: _statRow(row))
          else
            IntrinsicHeight(child: _statRow(row)),
        ],
      ],
    );
  }

  Widget _statRow(List<Widget> row) => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (j, tile) in row.indexed) ...[
            if (j > 0) const SizedBox(width: 10),
            Expanded(child: tile),
          ],
        ],
      );

  Widget _stat(AppColors c, IconData icon, String label, String value, String? detail, Color tint) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: tint),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.textSecondary)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, maxLines: 1, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: c.textPrimary)),
          ),
          if (detail != null) ...[
            const SizedBox(height: 2),
            Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: c.textHint)),
          ],
        ],
      ),
    );
  }

  Widget _pendingBanner(AppColors c, int count) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      onTap: widget.onOpenReviews,
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: c.warning.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.policy_outlined, size: 18, color: c.warning),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              S.p0ListingsAwaitingReview(count),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary),
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: c.iconInactive),
        ],
      ),
    );
  }

  Widget _cardTitle(AppColors c, String title, {String? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c.textPrimary)),
          ),
          if (trailing != null) Text(trailing, style: TextStyle(fontSize: 11, color: c.textHint)),
        ],
      ),
    );
  }

  Widget _emptyLine(AppColors c, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(child: Text(text, style: TextStyle(fontSize: 13, color: c.textHint))),
      );

  Widget _barRow(AppColors c, {
    required Widget leading,
    required String title,
    String? subtitle,
    required double ratio,
    required Color color,
    required String value,
    String? valueDetail,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              leading,
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary)),
                    if (subtitle != null) TextSpan(text: '  $subtitle', style: TextStyle(fontSize: 11, color: c.textHint)),
                  ]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: c.textPrimary)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: ratio.clamp(0.0, 1.0)),
                    duration: Motion.large,
                    curve: Motion.emphasized,
                    builder: (_, v, _) => LinearProgressIndicator(
                      value: v,
                      minHeight: 7,
                      backgroundColor: c.inputFill,
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                ),
              ),
              if (valueDetail != null) ...[
                const SizedBox(width: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 64),
                  child: Text(valueDetail, textAlign: TextAlign.end, style: TextStyle(fontSize: 11, color: c.textSecondary)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _featureCard(AppColors c, AiUsageReport report) {
    final items = report.byFeature.where((f) => f.requests > 0 || f.costUsd > 0).toList();
    final maxCost = items.fold<double>(0, (m, f) => math.max(m, f.costUsd));
    final maxRequests = items.fold<int>(0, (m, f) => math.max(m, f.requests));
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(c, S.byFeature),
          if (items.isEmpty) _emptyLine(c, S.noDataYet),
          for (final f in items)
            _barRow(
              c,
              leading: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: AiLabels.featureColor(c, f.feature).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(AiLabels.featureIcon(f.feature), size: 15, color: AiLabels.featureColor(c, f.feature)),
              ),
              title: AiLabels.feature(f.feature),
              subtitle: f.errors > 0 ? S.errorsP0(f.errors) : null,
              ratio: maxCost > 0 ? f.costUsd / maxCost : (maxRequests > 0 ? f.requests / maxRequests : 0),
              color: AiLabels.featureColor(c, f.feature),
              value: formatUsd(f.costUsd),
              valueDetail: S.p0Calls(formatCount(f.requests)),
            ),
        ],
      ),
    );
  }

  Widget _providerCard(AppColors c, AiUsageReport report) {
    final items = report.byProvider.where((p) => p.requests > 0 || p.costUsd > 0).toList();
    final maxCost = items.fold<double>(0, (m, p) => math.max(m, p.costUsd));
    final maxRequests = items.fold<int>(0, (m, p) => math.max(m, p.requests));
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(c, S.byModel),
          if (items.isEmpty) _emptyLine(c, S.noDataYet),
          for (final p in items)
            _barRow(
              c,
              leading: Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(color: AiLabels.providerColor(c, p.provider), shape: BoxShape.circle),
              ),
              title: AiProviders.nameOf(p.provider),
              subtitle: p.model,
              ratio: maxCost > 0 ? p.costUsd / maxCost : (maxRequests > 0 ? p.requests / maxRequests : 0),
              color: AiLabels.providerColor(c, p.provider),
              value: formatUsd(p.costUsd),
              valueDetail: S.p0CallsP1Ms(formatCount(p.requests), p.avgLatencyMs),
            ),
        ],
      ),
    );
  }

  Widget _topUsersCard(AppColors c, AiUsageReport report) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(c, S.topMembers),
          if (report.topUsers.isEmpty) _emptyLine(c, S.noDataYet),
          for (final (i, u) in report.topUsers.indexed)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == 0 ? c.accent : c.inputFill,
                      shape: BoxShape.circle,
                    ),
                    child: Text('${i + 1}',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: i == 0 ? Colors.white : c.textSecondary)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      u.nickname.isEmpty ? '—' : u.nickname,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: c.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(S.p0Uses(formatCount(u.requests)), style: TextStyle(fontSize: 12, color: c.textSecondary)),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 76,
                    child: Text(
                      formatUsd(u.costUsd),
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: c.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _errorsCard(AppColors c, AiUsageReport report) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(c, S.recentErrors),
          if (report.recentErrors.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline_rounded, size: 16, color: c.success),
                  const SizedBox(width: 6),
                  Text(S.noErrors, style: TextStyle(fontSize: 13, color: c.textSecondary)),
                ],
              ),
            ),
          for (final (i, e) in report.recentErrors.take(8).indexed)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(Icons.error_outline_rounded, size: 15, color: c.danger),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AiLabels.errorCode(e.errorCode),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary),
                        ),
                        Text(
                          [AiLabels.feature(e.feature), AiProviders.nameOf(e.provider), ?e.model].join('・'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: c.textSecondary),
                        ),
                        if (e.errorDetail != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              e.errorDetail!,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, color: c.textSecondary, height: 1.35),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusBadge(label: formatRelative(e.createdAt), color: c.textSecondary, fontSize: 10),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class BudgetRingPainter extends CustomPainter {
  final double value;
  final Color color;
  final Color track;

  BudgetRingPainter({required this.value, required this.color, required this.track});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 9.0;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    canvas.drawArc(arcRect, 0, math.pi * 2, false, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track);
    if (value <= 0) return;
    canvas.drawArc(arcRect, -math.pi / 2, math.pi * 2 * value, false, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color);
  }

  @override
  bool shouldRepaint(covariant BudgetRingPainter old) => old.value != value || old.color != color || old.track != track;
}
