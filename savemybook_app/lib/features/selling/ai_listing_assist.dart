import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/ai.dart';
import '../../models/category.dart';
import '../../services/ai_status.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_labels.dart';
import '../../utils/motion.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/state_views.dart';
import '../account/ai_consent_sheet.dart';
import '../../i18n/strings.dart';

class AiAssistButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool busy;
  final String? label;

  const AiAssistButton({super.key, required this.onTap, this.busy = false, this.label});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Semantics(
      button: true,
      child: PressableScale(
        scale: 0.97,
        haptic: true,
        onTap: busy ? null : onTap,
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: [
                c.accent.withValues(alpha: c.isDark ? 0.22 : 0.1),
                AiPalette.violet(c).withValues(alpha: c.isDark ? 0.22 : 0.1),
              ],
            ),
            border: Border.all(color: c.accent.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              busy
                  ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: c.accent))
                  : Icon(Icons.auto_awesome_rounded, size: 19, color: c.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label ?? S.fillWithAi,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c.accent),
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 20, color: c.accent.withValues(alpha: 0.7)),
            ],
          ),
        ),
      ),
    );
  }
}

class AiPalette {
  const AiPalette._();

  static Color violet(AppColors c) => c.isDark ? const Color(0xFFB79CFF) : const Color(0xFF7B5CE6);
}

class AiFlash extends StatefulWidget {
  final int trigger;
  final Widget child;
  final EdgeInsets inset;

  const AiFlash({super.key, required this.trigger, required this.child, this.inset = const EdgeInsets.only(bottom: 12)});

  @override
  State<AiFlash> createState() => _AiFlashState();
}

class _AiFlashState extends State<AiFlash> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void didUpdateWidget(covariant AiFlash oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger && widget.trigger > 0) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Stack(
      children: [
        widget.child,
        Positioned(
          left: widget.inset.left,
          top: widget.inset.top,
          right: widget.inset.right,
          bottom: widget.inset.bottom,
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = _controller.value;
                if (t == 0 || t == 1) return const SizedBox.shrink();
                final strength = t < 0.15 ? t / 0.15 : (1 - (t - 0.15) / 0.85);
                return DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.accent.withValues(alpha: 0.08 * strength),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: c.accent.withValues(alpha: 0.9 * strength), width: 1.6),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class AiListingTargets {
  final Map<String, String> fields;
  final int? categoryId;
  final List<Category> categories;
  final bool supportsCategory;
  final String? condition;
  final bool conditionTouched;
  final bool supportsCondition;
  final int? price;
  final bool supportsPrice;

  const AiListingTargets({
    this.fields = const {},
    this.categoryId,
    this.categories = const [],
    this.supportsCategory = false,
    this.condition,
    this.conditionTouched = false,
    this.supportsCondition = false,
    this.price,
    this.supportsPrice = false,
  });
}

String aiFieldLabel(String key) => switch (key) {
      'title' => S.title,
      'subtitle' => S.subtitle,
      'author' => S.author2,
      'publisher' => S.publisher2,
      'publish_date' => S.publicationDate,
      'isbn' => 'ISBN',
      'page_count' => S.pages,
      'language' => S.language,
      'description' => S.summary,
      _ => key,
    };

/// 只做參考、上架表單沒有對應欄位的補充資料。
const aiReferenceFieldKeys = ['subtitle', 'page_count', 'language'];

String aiPublishDatePrecisionLabel(String precision) => switch (precision) {
      'month' => S.monthOnly,
      'year' => S.yearOnly,
      _ => '',
    };

String aiLanguageLabel(String tag) => switch (tag) {
      'zh-Hant' => S.msg,
      'zh-Hans' => S.simplifiedChinese,
      'zh' => S.chinese,
      'en' => S.english,
      'ja' => S.japanese,
      'ko' => S.korean,
      _ => tag,
    };

Future<AiListingAssist?> runAiListingAssist(
  BuildContext context, {
  String? isbn,
  String? title,
  String? conditionNote,
  List<String> imagePaths = const [],
  bool retried = false,
}) async {
  if (!await ensureAiConsent(context) || !context.mounted) return null;
  final status = AiStatus.value;
  final steps = <String>[
    S.lookingUpBookDetails,
    if (status.webSearch) S.searchingWeb,
    if (imagePaths.isNotEmpty) S.analyzingPhotos,
    S.suggestingCategoryConditionPrice,
  ];
  final c = AppColors.of(context);
  var needsConsent = false;
  final result = await showModalBottomSheet<AiListingAssist>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: c.sheetBg,
    constraints: const BoxConstraints(maxWidth: 520),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => AiAssistProgressSheet(
      steps: steps,
      run: () async {
        final response = await ApiService().requestListingAssist(isbn: isbn, title: title, conditionNote: conditionNote, imagePaths: imagePaths);
        needsConsent = response.needsConsent;
        return response;
      },
    ),
  );
  if (!needsConsent || retried || !context.mounted) return result;
  AiStatus.markConsentRevoked();
  return runAiListingAssist(context, isbn: isbn, title: title, conditionNote: conditionNote, imagePaths: imagePaths, retried: true);
}

class AiAssistProgressSheet extends StatefulWidget {
  final List<String> steps;
  final Future<AiResult<AiListingAssist>> Function() run;

  const AiAssistProgressSheet({super.key, required this.steps, required this.run});

  @override
  State<AiAssistProgressSheet> createState() => _AiAssistProgressSheetState();
}

class _AiAssistProgressSheetState extends State<AiAssistProgressSheet> {
  int _step = 0;
  bool _done = false;
  String? _error;
  Timer? _ticker;
  int _attempt = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    final attempt = ++_attempt;
    setState(() {
      _step = 0;
      _done = false;
      _error = null;
    });
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 2400), (_) {
      if (_step < widget.steps.length - 1) setState(() => _step++);
    });
    final result = await widget.run();
    if (!mounted || attempt != _attempt) return;
    _ticker?.cancel();
    if (result.needsConsent) {
      Navigator.of(context).pop();
      return;
    }
    if (!result.isOk || result.data == null) {
      HapticFeedback.heavyImpact();
      setState(() => _error = result.error);
      return;
    }
    setState(() {
      _step = widget.steps.length;
      _done = true;
    });
    HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (mounted && attempt == _attempt) Navigator.of(context).pop(result.data);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Breathe(child: Icon(Icons.auto_awesome_rounded, color: _error == null ? c.accent : c.iconInactive)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _error != null ? S.couldNotGetAiSuggestions : (_done ? S.done : S.aiAnalyzing),
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: c.textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            AnimatedSize(
              duration: Motion.base,
              curve: Motion.standard,
              alignment: Alignment.topCenter,
              child: _error != null
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: c.danger.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
                      child: Text(_error!, style: TextStyle(fontSize: 13.5, height: 1.5, color: c.textPrimary)),
                    )
                  : Column(
                      children: [
                        for (var i = 0; i < widget.steps.length; i++) _stepRow(c, i),
                      ],
                    ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      _attempt++;
                      Navigator.of(context).pop();
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: c.inputFill,
                      foregroundColor: c.textSecondary,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(_error != null ? S.actionClose : S.actionCancel, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _start,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.accent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(S.retry, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepRow(AppColors c, int i) {
    final done = i < _step;
    final active = i == _step && !_done;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: AnimatedSwitcher(
              duration: Motion.base,
              transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
              child: done
                  ? Icon(Icons.check_circle_rounded, key: const ValueKey('done'), size: 22, color: c.success)
                  : active
                      ? Padding(
                          key: const ValueKey('active'),
                          padding: const EdgeInsets.all(3),
                          child: CircularProgressIndicator(strokeWidth: 2.2, color: c.accent),
                        )
                      : Icon(Icons.radio_button_unchecked_rounded, key: const ValueKey('todo'), size: 22, color: c.iconInactive),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AnimatedDefaultTextStyle(
              duration: Motion.base,
              style: TextStyle(
                fontSize: 14,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                color: done || active ? c.textPrimary : c.textHint,
              ),
              child: Text(widget.steps[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class AiListingSelection {
  final Set<String> fields;
  final bool category;
  final bool condition;
  final bool price;

  const AiListingSelection({this.fields = const {}, this.category = false, this.condition = false, this.price = false});

  int get count => fields.length + (category ? 1 : 0) + (condition ? 1 : 0) + (price ? 1 : 0);
}

Future<AiListingSelection?> showAiListingResultSheet(
  BuildContext context, {
  required AiListingAssist result,
  required AiListingTargets targets,
}) {
  final c = AppColors.of(context);
  return showModalBottomSheet<AiListingSelection>(
    context: context,
    isScrollControlled: true,
    backgroundColor: c.sheetBg,
    constraints: BoxConstraints(maxWidth: 640, maxHeight: MediaQuery.sizeOf(context).height * 0.9),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => AiListingResultSheet(result: result, targets: targets),
  );
}

class AiListingResultSheet extends StatefulWidget {
  final AiListingAssist result;
  final AiListingTargets targets;

  const AiListingResultSheet({super.key, required this.result, required this.targets});

  @override
  State<AiListingResultSheet> createState() => _AiListingResultSheetState();
}

class _AiListingResultSheetState extends State<AiListingResultSheet> {
  late final Set<String> _fields;
  late bool _category;
  late bool _condition;
  late bool _price;
  bool _descriptionExpanded = false;

  AiListingTargets get t => widget.targets;
  AiListingAssist get r => widget.result;

  bool _same(String key) => (t.fields[key] ?? '').trim() == (r.fields[key] ?? '').trim();

  List<String> get _fieldKeys => [
        for (final key in AiListingAssist.fieldKeys)
          if (t.fields.containsKey(key) && r.fields.containsKey(key)) key,
      ];

  Category? get _categoryMatch {
    final guess = r.category;
    if (guess == null) return null;
    for (final cat in t.categories) {
      if (cat.categoryId == guess.categoryId) return cat;
    }
    return null;
  }

  List<String> get _referenceKeys => [
        for (final key in aiReferenceFieldKeys)
          if ((r.fields[key] ?? '').trim().isNotEmpty) key,
      ];

  bool get _showCategory => t.supportsCategory && _categoryMatch != null;
  bool get _showCondition => t.supportsCondition && r.condition != null && AppLabels.condition.containsKey(r.condition!.level);
  bool get _showPrice => t.supportsPrice && r.price != null;

  @override
  void initState() {
    super.initState();
    _fields = {
      for (final key in _fieldKeys)
        if ((t.fields[key] ?? '').trim().isEmpty) key,
    };
    _category = _showCategory && t.categoryId == null;
    _condition = _showCondition && !t.conditionTouched && t.condition != r.condition!.level;
    _price = _showPrice && (t.price == null || t.price! <= 0);
  }

  AiListingSelection get _selection => AiListingSelection(fields: _fields, category: _category, condition: _condition, price: _price);

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final selection = _selection;
    final referenceKeys = _referenceKeys;
    final hasAny = _fieldKeys.isNotEmpty || _showCategory || _showCondition || _showPrice || referenceKeys.isNotEmpty;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(width: 36, height: 4, decoration: BoxDecoration(color: c.divider, borderRadius: BorderRadius.circular(2))),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
            child: Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: c.accent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(S.aiSuggestions, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: c.textPrimary)),
                ),
                if (r.provider.isNotEmpty)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 120),
                    child: Text(
                      AiProviders.nameOf(r.provider),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: c.textHint),
                    ),
                  ),
              ],
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
              children: [
                for (final w in r.warnings) _warning(c, w),
                if (!hasAny)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text(S.noSuggestionsApply, style: TextStyle(fontSize: 14, color: c.textSecondary))),
                  ),
                if (_fieldKeys.isNotEmpty) ...[
                  _section(c, S.bookDetails),
                  for (final (i, key) in _fieldKeys.indexed)
                    FadeSlideIn(index: i, offsetY: 8, child: _fieldTile(c, key)),
                ],
                if (referenceKeys.isNotEmpty) ...[
                  _section(c, S.additionalInformation),
                  for (final key in referenceKeys) _referenceRow(c, key),
                ],
                if (_showCategory) ...[
                  _section(c, S.category),
                  _choiceTile(
                    c,
                    selected: _category,
                    onChanged: (v) => setState(() => _category = v),
                    title: _categoryMatch!.categoryName,
                    current: t.categoryId == null || t.categoryId == r.category!.categoryId
                        ? null
                        : t.categories.where((cat) => cat.categoryId == t.categoryId).map((cat) => cat.categoryName).firstOrNull,
                    same: t.categoryId == r.category!.categoryId,
                  ),
                ],
                if (_showCondition) ...[
                  _section(c, S.condition),
                  _choiceTile(
                    c,
                    selected: _condition,
                    onChanged: (v) => setState(() => _condition = v),
                    title: AppLabels.conditionOf(r.condition!.level),
                    titleColor: c.conditionColor(r.condition!.level),
                    reasons: r.condition!.reasons,
                    current: t.condition != null && t.conditionTouched && t.condition != r.condition!.level ? AppLabels.conditionOf(t.condition!) : null,
                    same: t.condition == r.condition!.level,
                  ),
                ],
                if (_showPrice) ...[
                  _section(c, S.suggestedPrice),
                  _choiceTile(
                    c,
                    selected: _price,
                    onChanged: (v) => setState(() => _price = v),
                    title: '\$${r.price!.suggested}',
                    detail: [
                      if (r.price!.min != null && r.price!.max != null) S.rangeP0P1(r.price!.min!, r.price!.max!),
                      if (r.price!.originalPrice != null) S.listPriceP0(r.price!.originalPrice!),
                    ].join('・'),
                    reasons: r.price!.reasons,
                    current: t.price != null && t.price! > 0 && t.price != r.price!.suggested ? '\$${t.price}' : null,
                    same: t.price == r.price!.suggested,
                  ),
                ],
                if (r.sources.isNotEmpty) ...[
                  _section(c, S.sources),
                  for (final s in r.sources.take(5))
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Row(
                        children: [
                          Icon(Icons.link_rounded, size: 15, color: c.textHint),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text.rich(
                              TextSpan(children: [
                                TextSpan(text: s.title.isEmpty ? s.host : s.title, style: TextStyle(color: c.textPrimary)),
                                if (s.title.isNotEmpty && s.host.isNotEmpty) TextSpan(text: '  ${s.host}', style: TextStyle(color: c.textHint)),
                              ]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: c.divider))),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      backgroundColor: c.inputFill,
                      foregroundColor: c.textSecondary,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(S.actionCancel, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: selection.count == 0 ? null : () => Navigator.of(context).pop(selection),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.accent,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: c.accent.withValues(alpha: 0.35),
                      disabledForegroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: Text(
                      selection.count == 0 ? S.apply : S.applyP0(selection.count),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(AppColors c, String title) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
        child: Text(title, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: c.textSecondary, letterSpacing: 0.4)),
      );

  Widget _warning(AppColors c, String text) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: c.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, size: 17, color: c.warning),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: TextStyle(fontSize: 12.5, height: 1.45, color: c.textPrimary))),
          ],
        ),
      );

  Widget _checkFrame(AppColors c, {required bool selected, required bool enabled, required ValueChanged<bool> onChanged, required Widget child}) {
    return AnimatedContainer(
      duration: Motion.micro,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: selected ? c.accent.withValues(alpha: c.isDark ? 0.14 : 0.06) : c.inputFill.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: selected ? c.accent.withValues(alpha: 0.5) : Colors.transparent),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: enabled
              ? () {
                  HapticFeedback.selectionClick();
                  onChanged(!selected);
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 12, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: selected,
                  activeColor: c.accent,
                  visualDensity: VisualDensity.compact,
                  onChanged: enabled ? (v) => onChanged(v ?? false) : null,
                ),
                const SizedBox(width: 2),
                Expanded(child: Padding(padding: const EdgeInsets.only(top: 8), child: child)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _currentLine(AppColors c, String current) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          S.currentP0(current),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11.5, color: c.textHint, decoration: TextDecoration.lineThrough, decorationColor: c.textHint),
        ),
      );

  Widget _sameTag(AppColors c) => Container(
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(color: c.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
        child: Text(S.sameAsCurrent, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: c.success)),
      );

  Widget _noteTag(AppColors c, String label, Color color) => Container(
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
        child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
      );

  Widget _referenceRow(AppColors c, String key) {
    final value = r.fields[key]!.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 68,
            child: Text(aiFieldLabel(key), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.textSecondary)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              key == 'language' ? aiLanguageLabel(value) : (key == 'page_count' ? S.p0Pages(value) : value),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, height: 1.4, color: c.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldTile(AppColors c, String key) {
    final same = _same(key);
    final current = (t.fields[key] ?? '').trim();
    final selected = _fields.contains(key);
    final value = r.fields[key]!;
    final isDescription = key == 'description';
    final precisionNote = key == 'publish_date' && r.publishDateIsApproximate ? aiPublishDatePrecisionLabel(r.publishDatePrecision) : '';
    final expandable = isDescription && value.length > 90;

    return _checkFrame(
      c,
      selected: selected,
      enabled: !same,
      onChanged: (v) => setState(() => v ? _fields.add(key) : _fields.remove(key)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 2,
            children: [
              Text(aiFieldLabel(key), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: c.textSecondary)),
              if (same) _sameTag(c),
              if (precisionNote.isNotEmpty) _noteTag(c, precisionNote, c.warning),
            ],
          ),
          const SizedBox(height: 3),
          AnimatedSize(
            duration: Motion.base,
            curve: Motion.standard,
            alignment: Alignment.topLeft,
            child: Text(
              value,
              maxLines: isDescription ? (_descriptionExpanded ? null : 3) : 2,
              overflow: isDescription && _descriptionExpanded ? TextOverflow.clip : TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, height: 1.45, color: same ? c.textSecondary : c.textPrimary),
            ),
          ),
          if (expandable)
            // 勾選框整塊都吃點擊，展開鈕必須自己攔下手勢，否則會連帶切換勾選狀態。
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _descriptionExpanded = !_descriptionExpanded),
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_descriptionExpanded ? S.collapse : S.readFull,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.accent)),
                    Icon(_descriptionExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 16, color: c.accent),
                  ],
                ),
              ),
            ),
          if (!same && current.isNotEmpty) _currentLine(c, current),
        ],
      ),
    );
  }

  Widget _choiceTile(
    AppColors c, {
    required bool selected,
    required ValueChanged<bool> onChanged,
    required String title,
    Color? titleColor,
    String? detail,
    List<String> reasons = const [],
    String? current,
    bool same = false,
  }) {
    return _checkFrame(
      c,
      selected: selected,
      enabled: !same,
      onChanged: onChanged,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: titleColor ?? c.textPrimary)),
              if (same) _sameTag(c),
            ],
          ),
          if (detail != null && detail.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(detail, style: TextStyle(fontSize: 12, color: c.textSecondary)),
          ],
          for (final reason in reasons.take(3))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6, right: 6),
                    child: Container(width: 4, height: 4, decoration: BoxDecoration(color: c.textHint, shape: BoxShape.circle)),
                  ),
                  Expanded(child: Text(reason, style: TextStyle(fontSize: 12, height: 1.45, color: c.textSecondary))),
                ],
              ),
            ),
          if (current != null && !same) _currentLine(c, current),
        ],
      ),
    );
  }
}

Future<void> showListingRejectedDialog(BuildContext context, ListingOutcome outcome) {
  final reasons = outcome.reasons;
  return showConfirmDialog(
    context,
    title: S.listingNotApproved,
    message: reasons.isEmpty ? (outcome.error ?? '') : reasons.map((r) => '・$r').join('\n'),
    confirmLabel: S.editListing,
    cancelLabel: S.actionClose,
    isDestructive: true,
    icon: Icons.policy_outlined,
  );
}

Future<void> showPendingReviewNotice(BuildContext context) {
  return showConfirmDialog(
    context,
    title: S.submittedReview,
    message: S.goSaleOnceApprovedNotifiedResult,
    confirmLabel: S.got,
    cancelLabel: S.actionClose,
    icon: Icons.hourglass_top_rounded,
  );
}

void showAiUnavailable(BuildContext context, String? message) {
  showAppSnackBar(context, message?.isNotEmpty == true ? message! : S.aiFeaturesNotAvailableRightNow, isError: true);
}
