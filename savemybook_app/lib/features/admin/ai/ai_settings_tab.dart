import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/ai.dart';
import '../../../services/ai_status.dart';
import '../../../services/api_service.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/motion.dart';
import '../../../widgets/animations.dart';
import '../../../widgets/app_buttons.dart';
import '../../../widgets/app_forms.dart';
import '../../../widgets/app_select.dart';
import '../../../widgets/state_views.dart';
import '../admin_layout.dart';
import 'ai_labels.dart';
import 'ai_settings_form.dart';
import '../../../i18n/strings.dart';

class AiSettingsTab extends StatefulWidget {
  final ValueChanged<bool>? onDirtyChanged;
  final bool initialAdvancedOpen;

  const AiSettingsTab({super.key, this.onDirtyChanged, this.initialAdvancedOpen = false});

  @override
  State<AiSettingsTab> createState() => AiSettingsTabState();
}

class AiSettingsTabState extends State<AiSettingsTab> with AutomaticKeepAliveClientMixin {
  final ApiService _api = ApiService();
  final Map<String, TextEditingController> _controllers = {};

  AiSettingsBundle? _bundle;
  AiSettingsForm? _form;
  String? _error;
  bool _loading = true;
  bool _saving = false;
  late bool _advancedOpen = widget.initialAdvancedOpen;
  bool _lastDirty = false;
  final Map<String, AiTestResult> _tests = {};
  final Set<String> _testing = {};

  @override
  bool get wantKeepAlive => true;

  bool get isDirty => _form?.isDirty ?? false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _api.fetchAiSettings();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result.isOk && result.data != null) {
        _bundle = result.data;
        _form = AiSettingsForm(result.data!.settings);
        _syncControllers();
      } else {
        _error = result.error;
      }
    });
    _notifyDirty();
  }

  void _syncControllers() {
    final form = _form;
    if (form == null) return;
    for (final spec in AiSettingsForm.specs) {
      final text = form.textFor(spec.key);
      final controller = _controllers.putIfAbsent(spec.key, () => TextEditingController());
      if (controller.text != text) controller.text = text;
    }
  }

  void _notifyDirty() {
    final dirty = isDirty;
    if (dirty == _lastDirty) return;
    _lastDirty = dirty;
    widget.onDirtyChanged?.call(dirty);
  }

  void _update(AiSettings Function(AiSettings s) change) {
    final form = _form;
    if (form == null) return;
    setState(() => form.update(change(form.draft)));
    _notifyDirty();
  }

  void _onField(String key, String text) {
    final form = _form;
    if (form == null) return;
    setState(() => form.setText(key, text));
    _notifyDirty();
  }

  void revert() {
    final form = _form;
    if (form == null) return;
    HapticFeedback.selectionClick();
    setState(() {
      form.reset();
      _syncControllers();
    });
    _notifyDirty();
  }

  Future<bool> save() async {
    final form = _form;
    if (form == null || _saving) return false;
    FocusScope.of(context).unfocus();
    if (form.hasErrors) {
      HapticFeedback.heavyImpact();
      showAppSnackBar(context, S.pleaseFixHighlightedFields, isError: true);
      if (!_advancedOpen &&
          AiProviders.ids.any(
            (id) => AiSettingsForm.specs.any((s) => s.key.startsWith('$id.') && form.isInvalid(s.key)),
          )) {
        setState(() => _advancedOpen = true);
      }
      return false;
    }
    setState(() => _saving = true);
    final result = await _api.saveAiSettings(form.draft);
    if (!mounted) return false;
    setState(() {
      _saving = false;
      if (result.isOk) {
        final bundle = result.data;
        if (bundle != null) _bundle = bundle;
        form.markSaved(bundle?.settings ?? form.draft);
        _syncControllers();
      }
    });
    _notifyDirty();
    if (!result.isOk) {
      if (result.code == 'VERIFICATION_CANCELLED') return false;
      HapticFeedback.heavyImpact();
      showAppSnackBar(context, result.error ?? '', isError: true);
      return false;
    }
    HapticFeedback.mediumImpact();
    showAppSnackBar(context, S.aiSettingsSaved);
    AiStatus.invalidate();
    return true;
  }

  Future<void> _test(String provider) async {
    if (_testing.contains(provider)) return;
    setState(() {
      _testing.add(provider);
      _tests.remove(provider);
    });
    final result = await _api.testAiProvider(provider);
    if (!mounted) return;
    setState(() {
      _testing.remove(provider);
      _tests[provider] =
          result.data ?? AiTestResult(ok: false, provider: provider, model: '', latencyMs: 0, error: result.error);
    });
    HapticFeedback.selectionClick();
  }

  String? _errorText(String key) {
    final form = _form;
    if (form == null || !form.isInvalid(key)) return null;
    final spec = AiSettingsForm.specFor(key);
    final text = _controllers[key]?.text.trim() ?? '';
    if (text.isEmpty) return S.actionRequired;
    if (spec?.kind == AiFieldKind.model) return S.invalidFormat;
    final max = spec == null ? 0 : spec.max;
    return S.enter0P0(AiSettingsForm.formatNumber(max));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = AppColors.of(context);
    final bundle = _bundle;
    final form = _form;

    if (_loading && form == null) return const LoadingView.list();
    if (bundle == null || form == null) {
      return RefreshableCenter(
        onRefresh: _load,
        child: ErrorView(message: _error, onRetry: _load),
      );
    }

    return AdminLayout(
      builder: (context, frame) => Column(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusScope.of(context).unfocus(),
              child: ListView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: frame.inset(const EdgeInsets.fromLTRB(16, 16, 16, 32), maxWidth: 1200),
                children: [
                  FadeSlideIn(child: _masterCard(c, bundle, form.draft)),
                  const SizedBox(height: 22),
                  _heading(c, S.defaultModel),
                  FadeSlideIn(index: 1, child: _providerCards(c, bundle, form.draft, frame)),
                  const SizedBox(height: 22),
                  _heading(c, S.features),
                  FadeSlideIn(index: 2, child: _featureGrid(c, bundle, form.draft, frame)),
                  const SizedBox(height: 22),
                  _heading(c, S.semanticSearch),
                  FadeSlideIn(index: 3, child: _retrievalCard(c, bundle.retrieval)),
                  const SizedBox(height: 22),
                  if (frame.isWide)
                    FadeSlideIn(
                      index: 4,
                      child: AdminColumns(
                        gap: 14,
                        columns: [
                          [_limitsCard(c, form.draft)],
                          [_advancedCard(c, bundle, frame)],
                        ],
                      ),
                    )
                  else ...[
                    FadeSlideIn(index: 3, child: _limitsCard(c, form.draft)),
                    const SizedBox(height: 14),
                    FadeSlideIn(index: 4, child: _advancedCard(c, bundle, frame)),
                  ],
                ],
              ),
            ),
          ),
          _saveBar(c, form, frame),
        ],
      ),
    );
  }

  Widget _heading(AppColors c, String text) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 10),
    child: Text(
      text,
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: c.textSecondary, letterSpacing: 0.5),
    ),
  );

  Widget _notice(AppColors c, IconData icon, Color color, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 12.5, height: 1.45, color: c.textPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _masterCard(AppColors c, AiSettingsBundle bundle, AiSettings s) {
    final noKeys = !bundle.providers.any((p) => p.keyConfigured);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedContainer(
                duration: Motion.base,
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: (s.enabled ? c.accent : c.iconInactive).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.auto_awesome_rounded, color: s.enabled ? c.accent : c.iconInactive),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      S.aiFeatures,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    AnimatedSwitcher(
                      duration: Motion.micro,
                      child: Text(
                        s.enabled ? S.on : S.disabled,
                        key: ValueKey(s.enabled),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: s.enabled ? c.success : c.textHint,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: s.enabled,
                activeThumbColor: c.accent,
                onChanged: (v) {
                  HapticFeedback.selectionClick();
                  _update((s) => s.copyWith(enabled: v));
                },
              ),
            ],
          ),
          if (s.enabled && noKeys) ...[
            const SizedBox(height: 10),
            _notice(c, Icons.key_off_rounded, c.warning, S.noProviderApiKeysSetSo),
          ],
        ],
      ),
    );
  }

  Widget _retrievalCard(AppColors c, AiRetrievalStatus r) {
    final color = r.ready ? c.success : c.warning;
    final String detail;
    if (r.ready) {
      final books = r.books;
      final docs = r.knowledge;
      final counts = S.p0BooksP1HelpArticlesIndexed(books, docs);
      detail = '${AiProviders.nameOf(r.provider ?? '')}・${r.model ?? ''}\n$counts';
    } else {
      detail = S.noOpenaiGeminiKeyConfiguredOnly;
    }
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
            child: Icon(r.ready ? Icons.hub_outlined : Icons.manage_search_rounded, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.ready ? S.hybridSearchKeywordSemantic : S.keywordSearchOnly,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(detail, style: TextStyle(fontSize: 12.5, height: 1.45, color: c.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _providerCards(AppColors c, AiSettingsBundle bundle, AiSettings s, AdminFrame frame) {
    final cards = [for (final info in bundle.providers) _providerCard(c, info, s, fill: frame.isWide)];
    if (!frame.isWide) {
      return Column(
        children: [
          for (final (i, card) in cards.indexed)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
              child: card,
            ),
        ],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, card) in cards.indexed) ...[if (i > 0) const SizedBox(width: 12), Expanded(child: card)],
        ],
      ),
    );
  }

  Widget _providerCard(AppColors c, AiProviderInfo info, AiSettings s, {bool fill = false}) {
    final selected = s.defaultProvider == info.id;
    final pricing = s.providers[info.id]!;
    final tint = AiLabels.providerColor(c, info.id);
    final test = _tests[info.id];
    final testing = _testing.contains(info.id);

    return Semantics(
      selected: selected,
      button: true,
      child: AnimatedContainer(
        duration: Motion.base,
        curve: Motion.standard,
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? c.accent : c.border, width: selected ? 1.8 : 1),
          boxShadow: [
            BoxShadow(
              color: c.shadow.withValues(alpha: selected ? 0.1 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              if (!info.keyConfigured) {
                showAppSnackBar(context, S.p0NoApiKeyCannotSelected(info.name), isError: true);
                return;
              }
              if (selected) return;
              HapticFeedback.selectionClick();
              _update((s) => s.copyWith(defaultProvider: info.id));
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AnimatedSwitcher(
                        duration: Motion.micro,
                        transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
                        child: Icon(
                          !info.keyConfigured
                              ? Icons.lock_outline_rounded
                              : selected
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          key: ValueKey('${info.keyConfigured}$selected'),
                          size: 20,
                          color: selected ? c.accent : c.iconInactive,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          info.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c.textPrimary),
                        ),
                      ),
                      _keyChip(c, info.keyConfigured),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 28),
                    child: Text(
                      pricing.model,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: c.textSecondary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _priceCell(c, S.input, pricing.inputPerM)),
                      Container(width: 1, height: 28, color: c.divider),
                      Expanded(child: _priceCell(c, S.output, pricing.outputPerM)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(S.per1mTokens, style: TextStyle(fontSize: 10.5, color: c.textHint)),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _capability(c, Icons.image_outlined, S.vision, info.vision),
                      _capability(c, Icons.travel_explore_rounded, S.webSearch, info.webSearch),
                    ],
                  ),
                  if (fill) const Spacer(),
                  const SizedBox(height: 6),
                  Divider(height: 1, color: c.divider),
                  Row(
                    children: [
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: Motion.micro,
                          child: testing
                              ? Row(
                                  key: const ValueKey('testing'),
                                  children: [
                                    SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(strokeWidth: 1.6, color: c.accent),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(S.testing, style: TextStyle(fontSize: 12, color: c.textSecondary)),
                                  ],
                                )
                              : test == null
                              ? const SizedBox(key: ValueKey('none'), height: 12)
                              : _testResult(c, test),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: info.keyConfigured && !testing ? () => _test(info.id) : null,
                        style: TextButton.styleFrom(
                          foregroundColor: c.accent,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        icon: const Icon(Icons.network_check_rounded, size: 16),
                        label: Text(S.test, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _testResult(AppColors c, AiTestResult test) {
    final color = test.ok ? c.success : c.danger;
    final text = test.ok
        ? S.connectedP0Ms(test.latencyMs)
        : (test.error?.isNotEmpty == true ? test.error! : S.connectionFailed);
    return GestureDetector(
      key: ValueKey('${test.ok}${test.latencyMs}${test.error}'),
      onTap: test.ok ? null : () => showAppSnackBar(context, text, isError: true),
      child: Row(
        children: [
          Icon(test.ok ? Icons.check_circle_rounded : Icons.error_rounded, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _keyChip(AppColors c, bool configured) {
    final color = configured ? c.success : c.textHint;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(configured ? Icons.key_rounded : Icons.key_off_rounded, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            configured ? S.keySet : S.noKey,
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }

  Widget _priceCell(AppColors c, String label, double price) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: c.textSecondary)),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            formatUsdPrice(price),
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c.textPrimary),
          ),
        ),
      ],
    );
  }

  Widget _capability(AppColors c, IconData icon, String label, bool available) {
    final color = available ? c.accent : c.textHint;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: available ? c.accent.withValues(alpha: 0.1) : Colors.transparent,
        border: available ? null : Border.all(color: c.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(available ? icon : Icons.block_rounded, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: color,
              decoration: available ? null : TextDecoration.lineThrough,
              decorationColor: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _featureGrid(AppColors c, AiSettingsBundle bundle, AiSettings s, AdminFrame frame) {
    final cards = [for (final f in AiFeatures.configurable) _featureCard(c, bundle, s, f)];
    if (!frame.isWide) {
      return Column(
        children: [
          for (final (i, card) in cards.indexed)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
              child: card,
            ),
        ],
      );
    }
    return AdminColumns(
      gap: 14,
      spacing: 14,
      columns: [
        [
          for (final (i, card) in cards.indexed)
            if (i.isEven) card,
        ],
        [
          for (final (i, card) in cards.indexed)
            if (i.isOdd) card,
        ],
      ],
    );
  }

  Widget _featureCard(AppColors c, AiSettingsBundle bundle, AiSettings s, String feature) {
    final config = s.features[feature]!;
    final tint = AiLabels.featureColor(c, feature);
    final effective = s.effectiveProvider(feature);
    final effectiveInfo = bundle.provider(effective);

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: tint.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
                child: Icon(AiLabels.featureIcon(feature), size: 20, color: tint),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AiLabels.feature(feature),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c.textPrimary),
                ),
              ),
              Switch.adaptive(
                value: config.enabled,
                activeThumbColor: c.accent,
                onChanged: (v) {
                  HapticFeedback.selectionClick();
                  _update((s) => s.withFeature(feature, config.copyWith(enabled: v)));
                },
              ),
            ],
          ),
          AnimatedSize(
            duration: Motion.base,
            curve: Motion.emphasized,
            alignment: Alignment.topCenter,
            child: !config.enabled
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 12, right: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _label(c, S.model),
                        AppSelect<String>(
                          value: config.provider ?? '',
                          title: S.model,
                          leadingIcon: Icons.memory_rounded,
                          options: [
                            AppSelectOption(value: '', label: S.defaultP0(AiProviders.nameOf(s.defaultProvider))),
                            for (final info in bundle.providers)
                              AppSelectOption(
                                value: info.id,
                                label: info.name,
                                subtitle: s.providers[info.id]!.model,
                                enabled: info.keyConfigured,
                                disabledReason: info.keyConfigured ? null : S.noKey,
                              ),
                          ],
                          onChanged: (v) => _update(
                            (s) => s.withFeature(feature, config.copyWith(provider: () => v.isEmpty ? null : v)),
                          ),
                        ),
                        if (!effectiveInfo.keyConfigured) ...[
                          const SizedBox(height: 8),
                          _inlineNote(c, Icons.key_off_rounded, c.warning, S.p0NoApiKey(effectiveInfo.name)),
                        ],
                        if (feature == AiFeatures.listingAssist) ..._webSearchOption(c, s, config, effectiveInfo),
                        if (feature == AiFeatures.moderation) ..._moderationOption(c, config),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _label(AppColors c, String text) => Padding(
    padding: const EdgeInsets.only(left: 2, bottom: 6),
    child: Text(
      text,
      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: c.textSecondary),
    ),
  );

  Widget _inlineNote(AppColors c, IconData icon, Color color, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text, style: TextStyle(fontSize: 12, height: 1.4, color: color)),
        ),
      ],
    );
  }

  String webSearchCostNote(AiSettings s, AiProviderInfo info) {
    if (!info.webSearch) return S.p0DoesNotSupportWebSearch(info.name);
    final pricing = s.providers[info.id]!;
    final price = formatUsdPrice(pricing.searchPricePerK);
    if (pricing.searchPricePerK <= 0) return S.searchNotBilledSeparately;
    if (pricing.searchFreePerMonth > 0) {
      return S.firstP0SearchesFreeEachMonth(formatCount(pricing.searchFreePerMonth), price);
    }
    return S.p0Per1000SearchesPlus(price);
  }

  List<Widget> _webSearchOption(AppColors c, AiSettings s, AiFeatureConfig config, AiProviderInfo info) {
    return [
      const SizedBox(height: 12),
      Row(
        children: [
          Icon(Icons.travel_explore_rounded, size: 18, color: c.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(S.webSearch, style: TextStyle(fontSize: 14, color: c.textPrimary)),
          ),
          Switch.adaptive(
            value: config.webSearch,
            activeThumbColor: c.accent,
            onChanged: (v) => _update((s) => s.withFeature(AiFeatures.listingAssist, config.copyWith(webSearch: v))),
          ),
        ],
      ),
      AnimatedOpacity(
        duration: Motion.micro,
        opacity: config.webSearch ? 1 : 0.5,
        child: _inlineNote(
          c,
          info.webSearch ? Icons.info_outline_rounded : Icons.block_rounded,
          info.webSearch ? c.textSecondary : c.warning,
          webSearchCostNote(s, info),
        ),
      ),
    ];
  }

  List<Widget> _moderationOption(AppColors c, AiFeatureConfig config) {
    Widget option(String value, String label, IconData icon) {
      final active = config.action == value;
      return Expanded(
        child: PressableScale(
          scale: 0.97,
          onTap: () {
            if (active) return;
            HapticFeedback.selectionClick();
            _update((s) => s.withFeature(AiFeatures.moderation, config.copyWith(action: value)));
          },
          child: AnimatedContainer(
            duration: Motion.base,
            curve: Motion.standard,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: active ? c.accent.withValues(alpha: 0.12) : c.inputFill,
              border: Border.all(color: active ? c.accent : Colors.transparent, width: 1.4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Icon(icon, size: 18, color: active ? c.accent : c.textSecondary),
                const SizedBox(height: 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: active ? FontWeight.bold : FontWeight.w500,
                    color: active ? c.accent : c.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return [
      const SizedBox(height: 14),
      _label(c, S.suspiciousListings),
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            option('review', S.holdReview, Icons.fact_check_outlined),
            const SizedBox(width: 8),
            option('block', S.rejectClearViolations, Icons.block_rounded),
          ],
        ),
      ),
    ];
  }

  Widget _field(
    AppColors c,
    String key,
    String label, {
    String? prefix,
    bool integer = false,
    bool text = false,
    String? hint,
  }) {
    return AppTextField(
      controller: _controllers[key]!,
      label: label,
      hint: hint,
      prefixText: prefix,
      errorText: _errorText(key),
      maxLength: text ? 80 : 12,
      keyboardType: text ? TextInputType.text : TextInputType.numberWithOptions(decimal: !integer),
      inputFormatters: text
          ? [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9._:\-/]'))]
          : [FilteringTextInputFormatter.allow(RegExp(integer ? r'[0-9]' : r'[0-9.]'))],
      textInputAction: TextInputAction.next,
      onChanged: (v) => _onField(key, v),
    );
  }

  Widget _grid(List<Widget> children, {double minWidth = 150, double gap = 12}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = math.max(
          1,
          math.min(children.length, ((constraints.maxWidth + gap) / (minWidth + gap)).floor()),
        );
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: 12,
          children: [for (final child in children) SizedBox(width: width, child: child)],
        );
      },
    );
  }

  Widget _limitsCard(AppColors c, AiSettings s) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.budgetLimits,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c.textPrimary),
          ),
          const SizedBox(height: 14),
          _field(c, 'budget', S.monthlyBudgetUsd, prefix: 'US\$ ', hint: S.k0MeansNoCap),
          const SizedBox(height: 16),
          _label(c, S.dailyLimitPerMember),
          const SizedBox(height: 2),
          _grid([
            for (final f in AiFeatures.limited)
              _field(c, 'limit.$f', AiLabels.feature(f), integer: true, hint: S.k0MeansUnlimited),
          ], minWidth: 120),
        ],
      ),
    );
  }

  Widget _advancedCard(AppColors c, AiSettingsBundle bundle, AdminFrame frame) {
    final form = _form!;
    final invalidAdvanced = AiSettingsForm.specs.any(
      (spec) => !spec.key.startsWith('budget') && !spec.key.startsWith('limit.') && form.isInvalid(spec.key),
    );
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _advancedOpen = !_advancedOpen),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                children: [
                  Icon(Icons.tune_rounded, size: 20, color: c.textSecondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      S.advanced,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c.textPrimary),
                    ),
                  ),
                  if (invalidAdvanced)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(Icons.error_rounded, size: 16, color: c.danger),
                    ),
                  AnimatedRotation(
                    turns: _advancedOpen ? 0.5 : 0,
                    duration: Motion.base,
                    child: Icon(Icons.expand_more_rounded, color: c.iconInactive),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: Motion.base,
            curve: Motion.emphasized,
            alignment: Alignment.topCenter,
            child: !_advancedOpen
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (i, info) in bundle.providers.indexed) ...[
                          if (i > 0)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: Divider(height: 1, color: c.divider),
                            ),
                          _providerPricingEditor(c, info),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _providerPricingEditor(AppColors c, AiProviderInfo info) {
    final id = info.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: AiLabels.providerColor(c, id), shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                info.name,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c.textPrimary),
              ),
            ),
            TextButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _form!.resetProvider(id);
                  _syncControllers();
                });
                _notifyDirty();
              },
              style: TextButton.styleFrom(foregroundColor: c.textSecondary, visualDensity: VisualDensity.compact),
              child: Text(S.resetDefault, style: const TextStyle(fontSize: 12.5)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _field(c, '$id.model', S.modelId, text: true),
        const SizedBox(height: 12),
        _label(c, S.priceUsPer1mTokens),
        _grid(
          [
            _field(c, '$id.input_per_m', S.input),
            _field(c, '$id.cached_input_per_m', S.cachedInput),
            _field(c, '$id.output_per_m', S.output),
          ],
          minWidth: 96,
          gap: 10,
        ),
        if (info.webSearch) ...[
          const SizedBox(height: 12),
          _grid(
            [
              _field(c, '$id.search_price_per_k', S.searchPriceUsPer1000),
              _field(c, '$id.search_free_per_month', S.freeSearchesPerMonth, integer: true),
            ],
            minWidth: 150,
            gap: 10,
          ),
        ],
      ],
    );
  }

  Widget _saveBar(AppColors c, AiSettingsForm form, AdminFrame frame) {
    final dirty = form.isDirty;
    final changed = form.changedSections.length;
    return AnimatedSize(
      duration: Motion.base,
      curve: Motion.emphasized,
      alignment: Alignment.bottomCenter,
      child: !dirty
          ? const SizedBox(width: double.infinity)
          : Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: c.card,
                border: Border(top: BorderSide(color: c.divider)),
                boxShadow: [
                  BoxShadow(color: c.shadow.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, -2)),
                ],
              ),
              padding: frame.inset(
                EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.paddingOf(context).bottom + 10),
                maxWidth: 1200,
              ),
              child: Row(
                children: [
                  Icon(
                    form.hasErrors ? Icons.error_outline_rounded : Icons.edit_note_rounded,
                    size: 20,
                    color: form.hasErrors ? c.danger : c.warning,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      form.hasErrors
                          ? S.p0FieldsInvalid(form.errorCount)
                          : changed > 0
                          ? S.p0UnsavedChanges(changed)
                          : S.unsavedChanges,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary),
                    ),
                  ),
                  TextButton(
                    onPressed: _saving ? null : revert,
                    style: TextButton.styleFrom(foregroundColor: c.textSecondary),
                    child: Text(S.undo),
                  ),
                  const SizedBox(width: 4),
                  PrimaryButton(
                    label: S.actionSave,
                    icon: Icons.check_rounded,
                    expand: false,
                    height: 42,
                    isLoading: _saving,
                    onPressed: save,
                  ),
                ],
              ),
            ),
    );
  }
}
