import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/ai.dart';
import '../../../services/api_service.dart';
import '../../../utils/api_helpers.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/motion.dart';
import '../../../widgets/animations.dart';
import '../../../widgets/app_dialogs.dart';
import '../../../widgets/app_tiles.dart';
import '../../../widgets/state_views.dart';
import '../admin_layout.dart';
import 'ai_labels.dart';
import '../../../i18n/strings.dart';

class AiReviewTab extends StatefulWidget {
  final ValueChanged<int>? onCountChanged;

  const AiReviewTab({super.key, this.onCountChanged});

  @override
  State<AiReviewTab> createState() => _AiReviewTabState();
}

class _AiReviewTabState extends State<AiReviewTab> with AutomaticKeepAliveClientMixin {
  final ApiService _api = ApiService();
  List<AiReviewItem> _items = [];
  final Set<int> _busy = {};
  final Map<int, bool> _leaving = {};
  String? _error;
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await _api.fetchAiReviews();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result.isOk) {
        _items = result.data ?? [];
        _error = null;
        _leaving.clear();
      } else {
        _error = result.error;
      }
    });
    if (result.isOk) widget.onCountChanged?.call(_items.length);
  }

  Future<void> _decide(AiReviewItem item, {required bool approve}) async {
    if (_busy.contains(item.bookId)) return;
    String? note;
    if (!approve) {
      note = await showTextInputDialog(
        context,
        title: S.rejectListing,
        message: item.title,
        hint: S.noteOptionalSentSeller,
        maxLines: 3,
        maxLength: 200,
        confirmLabel: S.reject,
        isDestructive: true,
      );
      if (note == null || !mounted) return;
    }
    setState(() => _busy.add(item.bookId));
    final error = await _api.decideAiReview(item.bookId, approve: approve, note: note);
    if (!mounted) return;
    setState(() => _busy.remove(item.bookId));
    if (error != null) {
      HapticFeedback.heavyImpact();
      showAppSnackBar(context, error, isError: true);
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() => _leaving[item.bookId] = approve);
    showAppSnackBar(context, approve ? S.listingApproved : S.listingRejected);
    await Future<void>.delayed(Motion.large);
    if (!mounted) return;
    setState(() {
      _items.removeWhere((i) => i.bookId == item.bookId);
      _leaving.remove(item.bookId);
    });
    widget.onCountChanged?.call(_items.length);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = AppColors.of(context);

    return SwitchIn(
      child: _loading
          ? const LoadingView.list(key: ValueKey('loading'))
          : _error != null && _items.isEmpty
              ? RefreshableCenter(key: const ValueKey('error'), onRefresh: _load, child: ErrorView(message: _error, onRetry: _load))
              : _items.isEmpty
                  ? RefreshableCenter(
                      key: const ValueKey('empty'),
                      onRefresh: _load,
                      child: EmptyView(icon: Icons.verified_outlined, message: S.noListingsAwaitingReview),
                    )
                  : RefreshIndicator(
                      key: const ValueKey('list'),
                      color: c.accent,
                      onRefresh: _load,
                      child: AdminLayout(
                        builder: (context, frame) {
                          final cards = [
                            for (final (i, item) in _items.indexed)
                              KeyedSubtree(
                                key: ValueKey(item.bookId),
                                child: RevealOnScroll(index: i, child: _leavingWrap(item, _card(c, item))),
                              ),
                          ];
                          return ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: frame.inset(const EdgeInsets.fromLTRB(16, 16, 16, 40), maxWidth: 1200),
                            children: frame.isWide
                                ? [
                                    AdminColumns(gap: 14, spacing: 0, columns: [
                                      [for (var i = 0; i < cards.length; i += 2) cards[i]],
                                      [for (var i = 1; i < cards.length; i += 2) cards[i]],
                                    ]),
                                  ]
                                : cards,
                          );
                        },
                      ),
                    ),
    );
  }

  Widget _leavingWrap(AiReviewItem item, Widget child) {
    final leaving = _leaving[item.bookId];
    return AnimatedSize(
      duration: Motion.base,
      curve: Motion.standard,
      alignment: Alignment.topCenter,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 1, end: leaving == null ? 1 : 0),
        duration: Motion.enter,
        curve: Motion.exitCurve,
        builder: (context, v, child) => leaving != null && v == 0
            ? const SizedBox(width: double.infinity)
            : Opacity(
                opacity: v,
                child: Transform.translate(offset: Offset((leaving == true ? 40 : -40) * (1 - v), 0), child: child),
              ),
        child: Padding(padding: const EdgeInsets.only(bottom: 14), child: child),
      ),
    );
  }

  Widget _card(AppColors c, AiReviewItem item) {
    final busy = _busy.contains(item.bookId);
    final leaving = _leaving[item.bookId];
    final reject = item.verdict == 'reject';

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AppNetworkImage(url: item.imageUrl, width: 64, height: 86, fallbackIconSize: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 14, height: 1.35, fontWeight: FontWeight.w600, color: c.textPrimary)),
                        ),
                        const SizedBox(width: 6),
                        StatusBadge(label: reject ? S.likelyViolation : S.needsReview, color: reject ? c.danger : c.warning, fontSize: 10),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (item.sellerName.isNotEmpty) item.sellerName,
                        if (item.price > 0) '\$${item.price.toStringAsFixed(0)}',
                        formatRelative(item.createdAt),
                      ].join('・'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: c.textSecondary),
                    ),
                    if (item.categories.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final cat in item.categories)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: (reject ? c.danger : c.warning).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(AiLabels.reviewCategory(cat),
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: reject ? c.danger : c.warning)),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (item.reasons.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: c.inputFill, borderRadius: BorderRadius.circular(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final reason in item.reasons)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Container(width: 4, height: 4, decoration: BoxDecoration(color: c.textSecondary, shape: BoxShape.circle)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(reason, style: TextStyle(fontSize: 12.5, height: 1.45, color: c.textPrimary))),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: Motion.base,
            child: leaving != null
                ? Row(
                    key: const ValueKey('done'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      leaving ? DrawnCheck(size: 22, color: c.success) : Icon(Icons.block_rounded, size: 20, color: c.danger),
                      const SizedBox(width: 6),
                      Text(leaving ? S.approved : S.rejected,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: leaving ? c.success : c.danger)),
                    ],
                  )
                : Row(
                    key: const ValueKey('actions'),
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: busy ? null : () => _decide(item, approve: false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: c.danger,
                            side: BorderSide(color: c.danger.withValues(alpha: 0.5)),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.block_rounded, size: 17),
                          label: Text(S.reject, style: const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: busy ? null : () => _decide(item, approve: true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: c.success,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: busy
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.check_rounded, size: 18),
                          label: Text(S.approve, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
