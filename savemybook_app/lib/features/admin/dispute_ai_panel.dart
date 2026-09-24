import 'package:flutter/material.dart';

import '../../models/admin_models.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/motion.dart';
import '../../widgets/animations.dart';
import '../../i18n/strings.dart';

/// 裁決爭議前可選擇讓 AI 比對上架資料與申訴佐證；結果只供參考，不會自動套用任何裁決。
class DisputeAiPanel extends StatefulWidget {
  final int disputeId;

  const DisputeAiPanel({super.key, required this.disputeId});

  @override
  State<DisputeAiPanel> createState() => _DisputeAiPanelState();
}

class _DisputeAiPanelState extends State<DisputeAiPanel> {
  final ApiService _api = ApiService();
  DisputeAnalysis? _result;
  String? _error;
  bool _loading = false;

  Future<void> _analyze() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final (result, error) = await _api.analyzeDispute(widget.disputeId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _result = result;
      _error = error;
    });
  }

  ({String label, Color color, IconData icon}) _suggestion(AppColors c, String code) => switch (code) {
    'refund' => (label: S.suggestRefund, color: c.warning, icon: Icons.undo_rounded),
    'dismiss' => (label: S.suggestDismissal, color: c.success, icon: Icons.gavel_rounded),
    _ => (label: S.needsMoreInformation, color: c.neutral, icon: Icons.help_outline_rounded),
  };

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final result = _result;

    return AnimatedSize(
      duration: Motion.base,
      curve: Motion.standard,
      alignment: Alignment.topCenter,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(
          color: c.accent.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.accent.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome_rounded, size: 16, color: c.accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    S.aiAnalysis,
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: c.textPrimary),
                  ),
                ),
                TextButton(
                  onPressed: _loading ? null : _analyze,
                  style: TextButton.styleFrom(
                    foregroundColor: c.accent,
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: _loading
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: c.accent),
                        )
                      : Text(
                          result == null ? S.analyze : S.analyzeAgain,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 4),
              Text(_error!, style: TextStyle(fontSize: 12.5, color: c.danger, height: 1.4)),
            ],
            if (result != null) ...[
              const SizedBox(height: 6),
              _SuggestionChip(style: _suggestion(c, result.suggestion), confidence: result.confidence),
              if (result.summary.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(result.summary, style: TextStyle(fontSize: 13, height: 1.5, color: c.textPrimary)),
              ],
              for (final finding in result.findings) ...[
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 7, right: 6),
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(color: c.textSecondary, shape: BoxShape.circle),
                      ),
                    ),
                    Expanded(
                      child: Text(finding, style: TextStyle(fontSize: 12.5, height: 1.45, color: c.textSecondary)),
                    ),
                  ],
                ),
              ],
              if (result.rationale.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(result.rationale, style: TextStyle(fontSize: 12.5, height: 1.45, color: c.textSecondary)),
              ],
              const SizedBox(height: 6),
              Text(S.aiAnalysisReferenceOnlyDecideBased, style: TextStyle(fontSize: 11.5, color: c.textHint)),
            ],
          ],
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final ({String label, Color color, IconData icon}) style;
  final double confidence;

  const _SuggestionChip({required this.style, required this.confidence});

  @override
  Widget build(BuildContext context) {
    final percent = (confidence * 100).round();
    final label = style.label;
    return FadeSlideIn(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: style.color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(style.icon, size: 14, color: style.color),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                S.p0P1Confidence(label, percent),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: style.color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
