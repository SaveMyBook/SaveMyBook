import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../i18n/strings.dart';
import '../../models/admin_models.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/level_style.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_forms.dart';
import '../../widgets/app_header.dart';
import '../../widgets/guards.dart';
import '../../widgets/responsive.dart';
import '../../widgets/state_views.dart';
import 'level_rules.dart';

class AdminLevelEditScreen extends StatefulWidget {
  final AdminLevel? level;
  final List<AdminLevel> levels;

  const AdminLevelEditScreen({super.key, this.level, required this.levels});

  @override
  State<AdminLevelEditScreen> createState() => _AdminLevelEditScreenState();
}

class _AdminLevelEditScreenState extends State<AdminLevelEditScreen> {
  final ApiService _api = ApiService();

  late final List<AdminLevel> _levels = LevelRules.sorted(widget.levels);
  late final bool _pointsLocked = LevelRules.isThresholdLocked(_levels, editingId: widget.level?.levelId);
  late final TextEditingController _name = TextEditingController(text: widget.level?.name ?? '');
  late final TextEditingController _points = TextEditingController(text: _initialPoints);
  late final TextEditingController _benefits = TextEditingController(text: widget.level?.benefits ?? '');
  late final List<String> _initial = [_name.text, _points.text, _benefits.text];

  bool _isSaving = false;
  bool _saved = false;
  bool _attempted = false;

  bool get _isEdit => widget.level != null;

  String get _initialPoints {
    final level = widget.level;
    if (level != null) return '${level.minPoints}';
    if (_levels.isEmpty) return '0';
    return '';
  }

  @override
  void initState() {
    super.initState();
    assert(_initial.length == 3);
    for (final controller in [_name, _points, _benefits]) {
      controller.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _points.dispose();
    _benefits.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  bool get _isDirty =>
      !_saved && [_name.text, _points.text, _benefits.text].indexed.any((e) => e.$2 != _initial[e.$1]);

  String? get _nameError {
    if (!_attempted && _name.text.trim().isEmpty) return null;
    return LevelRules.nameError(_name.text, _levels, editingId: widget.level?.levelId);
  }

  String? get _pointsError {
    if (!_attempted && _points.text.trim().isEmpty) return null;
    return LevelRules.pointsError(_points.text, _levels, editingId: widget.level?.levelId);
  }

  Future<void> _save() async {
    if (_isSaving) return;
    FocusScope.of(context).unfocus();
    setState(() => _attempted = true);
    final levelId = widget.level?.levelId;
    if (LevelRules.nameError(_name.text, _levels, editingId: levelId) != null ||
        LevelRules.pointsError(_points.text, _levels, editingId: levelId) != null) {
      HapticFeedback.heavyImpact();
      return;
    }

    setState(() => _isSaving = true);
    final error = await _api.saveLevel(
      levelId: levelId,
      name: _name.text.trim(),
      minPoints: int.parse(_points.text.trim()),
      benefits: _benefits.text.trim(),
    );
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (error != null) {
      if (error.isNotEmpty && error != S.verificationCancelled) showAppSnackBar(context, error, isError: true);
      return;
    }
    _saved = true;
    HapticFeedback.mediumImpact();
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return UnsavedGuard(
      isDirty: _isDirty && !_isSaving,
      child: Scaffold(
        backgroundColor: c.scaffold,
        body: Column(
          children: [
            AppHeader(
              title: _isEdit ? S.editTier : S.newTier,
              icon: Icons.workspace_premium_outlined,
            ),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => FocusScope.of(context).unfocus(),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 840;
                    final form = _buildForm(c);
                    final preview = _buildPreview(c);
                    final bottom = MediaQuery.of(context).viewInsets.bottom + 32;

                    if (!wide) {
                      return ListView(
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: responsiveListPadding(
                          constraints,
                          maxWidth: Breakpoints.formMaxWidth,
                          top: 20,
                          bottom: bottom,
                        ),
                        children: [form, const SizedBox(height: 20), preview],
                      );
                    }
                    return SingleChildScrollView(
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: responsiveListPadding(
                        constraints,
                        maxWidth: Breakpoints.listMaxWidth,
                        horizontal: 24,
                        top: 24,
                        bottom: bottom,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 5, child: form),
                          const SizedBox(width: 24),
                          Expanded(flex: 4, child: preview),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(AppColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FormRowCard(
          label: S.tierName,
          isRequired: true,
          child: AppTextField(
            controller: _name,
            hint: S.eGGoldMember,
            maxLength: LevelRules.nameMaxLength,
            enabled: !_isSaving,
            textInputAction: TextInputAction.next,
            errorText: _nameError,
          ),
        ),
        FormRowCard(
          label: S.pointsThreshold,
          isRequired: true,
          state: _pointsLocked ? FieldState.locked : FieldState.normal,
          child: AppTextField(
            controller: _points,
            hint: '0',
            enabled: !_isSaving && !_pointsLocked,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
            suffix: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(S.pts, style: TextStyle(fontSize: 14, color: c.textSecondary)),
            ),
            errorText: _pointsLocked ? null : _pointsError,
          ),
        ),
        FormRowCard(
          label: S.tierBenefits,
          alignTop: true,
          child: AppTextField(
            controller: _benefits,
            hint: S.oneBenefitPerLine,
            minLines: 4,
            maxLines: 8,
            maxLength: LevelRules.benefitsMaxLength,
            enabled: !_isSaving,
            keyboardType: TextInputType.multiline,
          ),
        ),
        const SizedBox(height: 8),
        PrimaryButton(
          label: S.actionSave,
          icon: Icons.check_rounded,
          height: 50,
          isLoading: _isSaving,
          onPressed: _save,
        ),
      ],
    );
  }

  Widget _buildPreview(AppColors c) {
    final points = int.tryParse(_points.text.trim());
    final name = _name.text.trim();
    final ladder = LevelRules.ladder(
      _levels,
      editingId: widget.level?.levelId,
      name: name.isEmpty ? S.newTier2 : name,
      points: points,
    );
    final index = ladder.indexWhere((s) => s.isDraft);
    final slot = index < 0 ? null : ladder[index];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(S.whatMembersSee),
        const SizedBox(height: 10),
        LevelPreviewCard(
          style: LevelStyle.at(index < 0 ? _levels.length : index),
          name: name.isEmpty ? S.tierName : name,
          range: slot == null ? S.noThresholdSet : LevelRules.rangeLabel(slot.minPoints, slot.maxPoints),
          benefits: LevelRules.benefitsOf(_benefits.text),
        ),
        const SizedBox(height: 20),
        _SectionTitle(S.tierOrder),
        const SizedBox(height: 10),
        LevelLadder(slots: ladder),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Text(text, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.textSecondary));
  }
}

class LevelPreviewCard extends StatelessWidget {
  final LevelStyle style;
  final String name;
  final String range;
  final List<String> benefits;

  const LevelPreviewCard({
    super.key,
    required this.style,
    required this.name,
    required this.range,
    required this.benefits,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: DecoratedBox(
        decoration: BoxDecoration(color: c.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [style.gradient[1], style.gradient[0]],
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          range,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.22),
                    ),
                    child: Icon(style.icon, size: 34, color: Colors.white),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: benefits.isEmpty
                  ? Text(S.noBenefitsSet, style: TextStyle(fontSize: 13, color: c.textHint))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (i, benefit) in benefits.indexed) ...[
                          if (i > 0) const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: style.accent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.card_giftcard_rounded, size: 16, color: style.accent),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    benefit,
                                    style: TextStyle(
                                      fontSize: 14,
                                      height: 1.4,
                                      fontWeight: FontWeight.w600,
                                      color: c.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class LevelLadder extends StatelessWidget {
  final List<LevelSlot> slots;

  const LevelLadder({super.key, required this.slots});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    if (slots.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          for (final (i, slot) in slots.indexed)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: slot.isDraft ? c.accent.withValues(alpha: 0.1) : null,
                borderRadius: BorderRadius.circular(10),
                border: slot.isDraft ? Border.all(color: c.accent.withValues(alpha: 0.5)) : null,
              ),
              child: Row(
                children: [
                  Icon(LevelStyle.at(i).icon, size: 18, color: LevelStyle.at(i).accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      slot.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: slot.isDraft ? FontWeight.w700 : FontWeight.w500,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      LevelRules.rangeLabel(slot.minPoints, slot.maxPoints),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: TextStyle(fontSize: 12, color: c.textSecondary),
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
