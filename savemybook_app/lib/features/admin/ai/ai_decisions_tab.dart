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
import 'ai_labels.dart';
import 'ai_period_picker.dart';
import '../../../i18n/strings.dart';

class AiDecisionsTab extends StatefulWidget {
  const AiDecisionsTab({super.key});

  @override
  State<AiDecisionsTab> createState() => _AiDecisionsTabState();
}

class _AiDecisionsTabState extends State<AiDecisionsTab> with AutomaticKeepAliveClientMixin {
  final ApiService _api = ApiService();
  String _period = 'month';
  AiDecisionReport? _report;
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
    final result = await _api.fetchAiDecisions(_period);
    if (!mounted || seq != _seq) return;
    setState(() {
      _loading = false;
      if (result.isOk && result.data != null) {
        _report = result.data;
        _error = null;
      } else {
        _error = result.error;
      }
    });
  }

  void _setPeriod(String period) {
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
            child: Align(alignment: Alignment.centerLeft, child: AiPeriodPicker(period: _period, onChanged: _setPeriod)),
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

  List<Widget> _sections(AppColors c, AiDecisionReport report, AdminFrame frame) {
    final features = [for (final f in report.features) _featureCard(c, f)];
    final widgets = <Widget>[];
    void add(Widget w) {
      widgets.add(Padding(
        padding: EdgeInsets.only(top: widgets.isEmpty ? 0 : 14),
        child: RevealOnScroll(index: widgets.length, child: w),
      ));
    }

    if (frame.isWide) {
      for (var i = 0; i < features.length; i += 2) {
        add(AdminColumns(gap: 14, spacing: 14, columns: [
          [features[i]],
          [if (i + 1 < features.length) features[i + 1]],
        ]));
      }
      add(AdminColumns(gap: 14, spacing: 14, columns: [
        [_versionsCard(c, report), _formatCard(c, report)],
        [_embeddingCard(c, report)],
      ]));
    } else {
      features.forEach(add);
      add(_versionsCard(c, report));
      add(_formatCard(c, report));
      add(_embeddingCard(c, report));
    }
    return widgets;
  }

  static String _percent(double ratio) => '${(ratio * 100).toStringAsFixed(ratio > 0 && ratio < 0.1 ? 1 : 0)}%';

  static String _number(double value) => value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(1);

  Widget _cardTitle(AppColors c, String title, {Widget? leading, String? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          if (leading != null) ...[leading, const SizedBox(width: 8)],
          Expanded(
            child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c.textPrimary)),
          ),
          if (trailing != null) Text(trailing, style: TextStyle(fontSize: 12, color: c.textSecondary)),
        ],
      ),
    );
  }

  Widget _subtitle(AppColors c, String text) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 8),
        child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.textSecondary)),
      );

  Widget _emptyLine(AppColors c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(child: Text(S.noDataYet, style: TextStyle(fontSize: 13, color: c.textHint))),
      );

  Widget _featureIcon(AppColors c, String feature) => Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: AiLabels.featureColor(c, feature).withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(AiLabels.featureIcon(feature), size: 15, color: AiLabels.featureColor(c, feature)),
      );

  Widget _featureCard(AppColors c, AiFeatureDecisions f) {
    final outcomes = [for (final o in AiOutcomes.all) if ((f.outcomes[o] ?? 0) > 0) (o, f.outcomes[o]!)];
    final paths = [
      for (final e in f.paths.entries)
        if (AiLabels.path(f.feature, e.key) case final label?) (label, e.value),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    final indicators = [
      for (final e in f.flags.entries)
        if (AiLabels.flag(f.feature, e.key) case final label?) (label, _percent(f.rateOf(e.value))),
      for (final e in f.averages.entries)
        if (AiLabels.average(f.feature, e.key) case final label?) (label, _number(e.value)),
    ];
    final maxPath = paths.fold<int>(0, (m, p) => math.max(m, p.$2));

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(c, AiLabels.feature(f.feature), leading: _featureIcon(c, f.feature), trailing: S.p0Calls(formatCount(f.total))),
          if (f.total == 0)
            _emptyLine(c)
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 8,
                child: Row(
                  children: [
                    for (final (o, n) in outcomes) Expanded(flex: n, child: ColoredBox(color: AiLabels.outcomeColor(c, o))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                for (final (o, n) in outcomes)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: AiLabels.outcomeColor(c, o), shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text('${AiLabels.outcome(o)} ${formatCount(n)} · ${_percent(f.rateOf(n))}',
                            style: TextStyle(fontSize: 12, color: c.textPrimary)),
                      ),
                    ],
                  ),
              ],
            ),
            if (paths.isNotEmpty) ...[
              _subtitle(c, S.processingPaths),
              for (final (label, n) in paths) _pathRow(c, label, n, maxPath, f),
            ],
            if (indicators.isNotEmpty) ...[
              _subtitle(c, S.indicators),
              for (final (label, value) in indicators) _valueRow(c, label, value),
            ],
          ],
        ],
      ),
    );
  }

  Widget _pathRow(AppColors c, String label, int count, int max, AiFeatureDecisions f) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: c.textPrimary)),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: max > 0 ? count / max : 0,
                minHeight: 6,
                backgroundColor: c.inputFill,
                valueColor: AlwaysStoppedAnimation(AiLabels.featureColor(c, f.feature)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 92,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text('${formatCount(count)} · ${_percent(f.rateOf(count))}',
                  maxLines: 1, style: TextStyle(fontSize: 12, color: c.textSecondary)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _valueRow(AppColors c, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: c.textPrimary)),
          ),
          const SizedBox(width: 8),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary)),
        ],
      ),
    );
  }

  Widget _versionsCard(AppColors c, AiDecisionReport report) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(c, S.promptVersions),
          if (report.promptVersions.isEmpty) _emptyLine(c),
          for (final (i, v) in report.promptVersions.indexed)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(padding: const EdgeInsets.only(top: 1), child: _featureIcon(c, v.feature)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(children: [
                            TextSpan(text: AiLabels.feature(v.feature),
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary)),
                            TextSpan(text: '  ${v.version}',
                                style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: c.textSecondary)),
                          ]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            S.p0Calls(formatCount(v.requests)),
                            S.errorRateP0((v.errorRate * 100).toStringAsFixed(1)),
                            if (v.degraded > 0) '${AiLabels.outcome(AiOutcomes.degraded)} ${formatCount(v.degraded)}',
                          ].join('・'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: c.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusBadge(label: formatRelative(v.lastAt), color: c.textSecondary, fontSize: 10),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _formatCard(AppColors c, AiDecisionReport report) {
    final items = report.formatErrors;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(c, S.outputFormatErrors),
          if (items.isEmpty) _emptyLine(c),
          for (final (i, e) in items.indexed)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(padding: const EdgeInsets.only(top: 1), child: _featureIcon(c, e.feature)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${AiLabels.feature(e.feature)}・${AiProviders.nameOf(e.provider)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary)),
                        const SizedBox(height: 2),
                        Text(
                          [
                            S.p0Calls(formatCount(e.requests)),
                            '${S.invalidResponseFormat} ${formatCount(e.invalidOutput)}',
                            if (e.incomplete > 0) '${S.responseExceededOutputLimit} ${formatCount(e.incomplete)}',
                            if (e.repaired > 0) '${AiLabels.outcome(AiOutcomes.repaired)} ${formatCount(e.repaired)}',
                            if (e.dropped > 0) S.someItemsMalformedP0(formatCount(e.dropped)),
                            if (e.defaulted > 0) S.fieldsDefaultedP0(formatCount(e.defaulted)),
                          ].join('・'),
                          style: TextStyle(fontSize: 11, color: c.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(_percent(e.errorRate),
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: e.errors > 0 ? c.warning : c.textPrimary)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _embeddingCard(AppColors c, AiDecisionReport report) {
    final items = report.embeddingByOrigin;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(c, S.embeddingCostsBySource),
          if (items.isEmpty) _emptyLine(c),
          for (final (i, e) in items.indexed)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(AiLabels.origin(e.origin),
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: c.textPrimary)),
                  ),
                  const SizedBox(width: 8),
                  Text(S.p0Calls(formatCount(e.requests)), style: TextStyle(fontSize: 12, color: c.textSecondary)),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 84,
                    child: Text(formatUsd(e.costUsd),
                        textAlign: TextAlign.end, maxLines: 1,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: c.textPrimary)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
