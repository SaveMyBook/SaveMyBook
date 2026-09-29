import 'package:flutter/material.dart';

import '../../models/admin_models.dart';
import '../../services/api_service.dart';
import '../../utils/api_helpers.dart';
import '../../utils/app_colors.dart';
import '../../utils/motion.dart';
import '../../widgets/animations.dart';
import '../../widgets/state_views.dart';
import '../../i18n/strings.dart';

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
  bool _blocked = false;
  bool _rating = false;

  @override
  void initState() {
    super.initState();
    _loadLatest();
  }

  Future<void> _loadLatest() async {
    setState(() => _loading = true);
    final (result, _) = await _api.fetchDisputeAnalysis(widget.disputeId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _result ??= result;
    });
  }

  Future<void> _rate(bool helpful) async {
    final result = _result;
    if (result == null || _rating || result.helpful == helpful) return;
    setState(() {
      _rating = true;
      _result = result.withHelpful(helpful);
    });
    final error = await _api.rateDisputeAnalysis(widget.disputeId, analysisNo: result.analysisNo, helpful: helpful);
    if (!mounted) return;
    setState(() {
      _rating = false;
      if (error != null) _result = result;
    });
    if (error != null) showAppSnackBar(context, error, isError: true);
  }

  Future<void> _analyze() async {
    if (_loading || _blocked) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final (result, error, code) = await _api.analyzeDispute(widget.disputeId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _result = result;
      _error = error;
      _blocked = code == 'AI_CONTENT_BLOCKED';
    });
  }

  ({String label, Color color, IconData icon}) _suggestion(AppColors c, String code) => switch (code) {
    'refund' => (label: S.suggestRefund, color: c.warning, icon: Icons.undo_rounded),
    'dismiss' => (label: S.suggestDismissal, color: c.success, icon: Icons.gavel_rounded),
    'mediate' => (label: S.suggestMediation, color: c.accent, icon: Icons.handshake_outlined),
    _ => (label: S.needsMoreInformation, color: c.neutral, icon: Icons.help_outline_rounded),
  };

  String _confidence(String level) => switch (level) {
    'high' => S.highConfidence,
    'medium' => S.mediumConfidence,
    _ => S.lowConfidence,
  };

  String? _favors(String code) => switch (code) {
    'buyer' => S.favorsBuyer,
    'seller' => S.favorsSeller,
    _ => null,
  };

  String _photoType(String? type) => switch (type) {
    'cover' => S.photoCover,
    'back' => S.photoBack,
    'inside' => S.insidePage,
    _ => S.ticketCatOther,
  };

  String _photoLabel(DisputeAnalysis result, int no) {
    final photo = result.photo(no);
    if (photo == null || !photo.isListing) return S.photoP0Evidence(no);
    final titles = {for (final p in result.photos) if (p.isListing) p.title};
    final type = _photoType(photo.type);
    return titles.length > 1 ? S.photoP0P1P2(no, photo.title, type) : S.photoP0P1(no, type);
  }

  String _findingMeta(DisputeAnalysis result, DisputeFinding finding) => [
        ?_favors(finding.favors),
        for (final no in finding.photos) _photoLabel(result, no),
      ].join('・');

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
                  onPressed: _loading || _blocked ? null : _analyze,
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
              _SuggestionChip(style: _suggestion(c, result.suggestion), confidence: _confidence(result.confidenceLevel)),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(finding.content, style: TextStyle(fontSize: 12.5, height: 1.45, color: c.textSecondary)),
                          if (_findingMeta(result, finding) case final meta when meta.isNotEmpty)
                            Text(meta, style: TextStyle(fontSize: 11.5, height: 1.4, color: c.textHint)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              if (result.rationale.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(result.rationale, style: TextStyle(fontSize: 12.5, height: 1.45, color: c.textSecondary)),
              ],
              const SizedBox(height: 6),
              Text(
                result.skippedPhotos > 0
                    ? S.aiReviewedP0ListingP1Evidence(result.listingPhotos, result.evidencePhotos, result.skippedPhotos)
                    : S.aiReviewedP0ListingP1Evidence2(result.listingPhotos, result.evidencePhotos),
                style: TextStyle(fontSize: 11.5, color: c.textHint),
              ),
              const SizedBox(height: 2),
              Text(
                [
                  S.aiAnalysisReferenceOnlyDecideBased,
                  if (result.createdAt != null) S.analysedP0(formatRelative(result.createdAt)),
                ].join('\n'),
                style: TextStyle(fontSize: 11.5, height: 1.4, color: c.textHint),
              ),
              if (result.analysisNo.isNotEmpty) ...[
                const SizedBox(height: 4),
                _HelpfulRow(value: result.helpful, busy: _rating, onChanged: _rate),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _HelpfulRow extends StatelessWidget {
  final bool? value;
  final bool busy;
  final ValueChanged<bool> onChanged;

  const _HelpfulRow({required this.value, required this.busy, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    Widget option(bool helpful, String label, IconData icon) {
      final selected = value == helpful;
      return TextButton.icon(
        onPressed: busy ? null : () => onChanged(helpful),
        style: TextButton.styleFrom(
          foregroundColor: selected ? c.accent : c.textSecondary,
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        icon: Icon(icon, size: 15),
        label: Text(label, style: TextStyle(fontSize: 12.5, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
      );
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 2,
      children: [
        Text(S.wasAnalysisHelpful, style: TextStyle(fontSize: 12, color: c.textSecondary)),
        option(true, S.helpful, value == true ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined),
        option(false, S.notHelpful, value == false ? Icons.thumb_down_alt_rounded : Icons.thumb_down_alt_outlined),
      ],
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final ({String label, Color color, IconData icon}) style;
  final String confidence;

  const _SuggestionChip({required this.style, required this.confidence});

  @override
  Widget build(BuildContext context) {
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
                '${style.label}・$confidence',
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
