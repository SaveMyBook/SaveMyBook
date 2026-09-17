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

class _BenefitRow {
  final Key key = UniqueKey();
  final TextEditingController controller;
  final FocusNode focusNode = FocusNode();

  _BenefitRow([String text = '']) : controller = TextEditingController(text: text);

  void dispose() {
    controller.dispose();
    focusNode.dispose();
  }
}

class _AdminLevelEditScreenState extends State<AdminLevelEditScreen> {
  static const _wideWidth = 840.0;

  final ApiService _api = ApiService();

  late final List<AdminLevel> _levels = LevelRules.sorted(widget.levels);
  late final bool _pointsLocked = LevelRules.isThresholdLocked(_levels, editingId: widget.level?.levelId);
  late final TextEditingController _name = TextEditingController(text: widget.level?.name ?? '');
  late final TextEditingController _points = TextEditingController(text: _initialPoints);
  late final List<_BenefitRow> _benefits = [
    for (final benefit in LevelRules.benefitsOf(widget.level?.benefits ?? '')) _BenefitRow(benefit),
  ];
  late final String _initialName = _name.text;
  late final String _initialPointsText = _points.text;
  late final String _initialBenefits;

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

  List<String> get _benefitValues =>
      [for (final row in _benefits) row.controller.text.trim()].where((e) => e.isNotEmpty).toList();

  String get _benefitsText => _benefitValues.join('\n');

  @override
  void initState() {
    super.initState();
    if (_benefits.isEmpty) _benefits.add(_BenefitRow());
    for (final row in _benefits) {
      row.controller.addListener(_onChanged);
    }
    _initialBenefits = _benefitsText;
    _name.addListener(_onChanged);
    _points.addListener(_onChanged);
  }

  @override
  void dispose() {
    _name.dispose();
    _points.dispose();
    for (final row in _benefits) {
      row.dispose();
    }
    super.dispose();
  }

  void _onChanged() => setState(() {});

  bool get _isDirty =>
      !_saved &&
      (_name.text != _initialName || _points.text != _initialPointsText || _benefitsText != _initialBenefits);

  String? get _nameError {
    if (!_attempted && _name.text.trim().isEmpty) return null;
    return LevelRules.nameError(_name.text, _levels, editingId: widget.level?.levelId);
  }

  String? get _pointsError {
    if (!_attempted && _points.text.trim().isEmpty) return null;
    return LevelRules.pointsError(_points.text, _levels, editingId: widget.level?.levelId);
  }

  bool get _canAddBenefit => _benefits.length < LevelRules.maxBenefits;

  _BenefitRow _insertBenefit(int index, [String text = '']) {
    final row = _BenefitRow(text)..controller.addListener(_onChanged);
    _benefits.insert(index, row);
    return row;
  }

  void _addBenefit({int? after}) {
    final index = after == null ? _benefits.length : after + 1;
    if (index < _benefits.length && _benefits[index].controller.text.trim().isEmpty) {
      _benefits[index].focusNode.requestFocus();
      return;
    }
    if (!_canAddBenefit) return;
    final row = _insertBenefit(index);
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) row.focusNode.requestFocus();
    });
  }

  void _removeBenefit(_BenefitRow row) {
    if (_benefits.length == 1) {
      row.controller.clear();
      return;
    }
    setState(() => _benefits.remove(row));
    WidgetsBinding.instance.addPostFrameCallback((_) => row.dispose());
  }

  // 換行或貼上多行文字時拆成多筆福利，讓 Enter 直接成為「新增下一筆」。
  void _onBenefitChanged(_BenefitRow row, String value) {
    if (!value.contains(RegExp(r'[\r\n]'))) return;
    final parts = value.split(RegExp(r'\r?\n|\r')).map((e) => e.trim()).toList();
    final rest = parts.skip(1).where((e) => e.isNotEmpty).toList();
    final endsWithBreak = parts.length > 1 && parts.last.isEmpty;
    row.controller.value = TextEditingValue(
      text: parts.first,
      selection: TextSelection.collapsed(offset: parts.first.length),
    );

    var index = _benefits.indexOf(row);
    _BenefitRow? focus;
    for (final text in rest) {
      if (!_canAddBenefit) break;
      focus = _insertBenefit(++index, text);
    }
    if (endsWithBreak && _canAddBenefit && parts.first.isNotEmpty) {
      focus = index + 1 < _benefits.length && _benefits[index + 1].controller.text.isEmpty
          ? _benefits[index + 1]
          : _insertBenefit(index + 1);
    }
    setState(() {});
    final target = focus;
    if (target != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) target.focusNode.requestFocus();
      });
    }
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
      benefits: _benefitsText,
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

  List<LevelSlot> get _ladder {
    final name = _name.text.trim();
    return LevelRules.ladder(
      _levels,
      editingId: widget.level?.levelId,
      name: name.isEmpty ? S.newTier2 : name,
      points: int.tryParse(_points.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final ladder = _ladder;

    return UnsavedGuard(
      isDirty: _isDirty && !_isSaving,
      child: Scaffold(
        backgroundColor: c.scaffold,
        body: Column(
          children: [
            AppHeader(title: _isEdit ? S.editTier : S.newTier, icon: Icons.workspace_premium_outlined),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => FocusScope.of(context).unfocus(),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < _wideWidth) {
                      return ListView(
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: responsiveListPadding(
                          constraints,
                          maxWidth: Breakpoints.formMaxWidth,
                          top: 16,
                          bottom: 24,
                        ),
                        children: [
                          _buildPreviewCard(ladder, showBenefits: false),
                          const SizedBox(height: 16),
                          _buildBasicSection(c, ladder: ladder),
                          const SizedBox(height: 16),
                          _buildBenefitsSection(c),
                        ],
                      );
                    }

                    final padding = responsiveListPadding(
                      constraints,
                      maxWidth: Breakpoints.listMaxWidth,
                      horizontal: 24,
                      top: 24,
                      bottom: 24,
                    );
                    return Padding(
                      padding: EdgeInsets.only(left: padding.left, right: padding.right),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: ListView(
                              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                              padding: EdgeInsets.only(top: padding.top, bottom: padding.bottom),
                              children: [_buildBasicSection(c), const SizedBox(height: 16), _buildBenefitsSection(c)],
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 4,
                            child: SingleChildScrollView(
                              padding: EdgeInsets.only(top: padding.top, bottom: padding.bottom),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _SectionTitle(S.whatMembersSee),
                                  const SizedBox(height: 10),
                                  _buildPreviewCard(ladder, showBenefits: true),
                                  if (ladder.length > 1) ...[
                                    const SizedBox(height: 20),
                                    _SectionTitle(S.tierOrder),
                                    const SizedBox(height: 10),
                                    LevelLadder(slots: ladder),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            _buildSaveBar(c),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard(List<LevelSlot> ladder, {required bool showBenefits}) {
    final name = _name.text.trim();
    final index = ladder.indexWhere((s) => s.isDraft);
    final slot = index < 0 ? null : ladder[index];

    return LevelPreviewCard(
      style: LevelStyle.at(index < 0 ? _levels.length : index),
      name: name.isEmpty ? S.tierName : name,
      range: slot == null ? S.noThresholdSet : LevelRules.rangeLabel(slot.minPoints, slot.maxPoints),
      benefits: _benefitValues,
      showBenefits: showBenefits,
    );
  }

  Widget _buildBasicSection(AppColors c, {List<LevelSlot>? ladder}) {
    return _SectionCard(
      title: S.basicSettings,
      children: [
        AppTextField(
          controller: _name,
          label: '${S.tierName} *',
          hint: S.eGGoldMember,
          maxLength: LevelRules.nameMaxLength,
          enabled: !_isSaving,
          textInputAction: TextInputAction.next,
          errorText: _nameError,
        ),
        const SizedBox(height: 16),
        AppTextField(
          controller: _points,
          label: _pointsLocked ? '${S.pointsThreshold}（${S.canTChanged}）' : '${S.pointsThreshold} *',
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
        if (ladder != null && ladder.length > 1) ...[
          const SizedBox(height: 16),
          Text(
            S.tierOrder,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textSecondary),
          ),
          const SizedBox(height: 6),
          LevelLadder(slots: ladder, embedded: true),
        ],
      ],
    );
  }

  Widget _buildBenefitsSection(AppColors c) {
    return _SectionCard(
      title: S.tierBenefits,
      trailing: Text(
        '${_benefitValues.length}/${LevelRules.maxBenefits}',
        style: TextStyle(fontSize: 12, color: c.textHint),
      ),
      children: [
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          padding: EdgeInsets.zero,
          proxyDecorator: (child, _, _) => Material(color: Colors.transparent, child: child),
          onReorder: (from, to) {
            setState(() {
              final row = _benefits.removeAt(from);
              _benefits.insert(to > from ? to - 1 : to, row);
            });
          },
          children: [
            for (final (i, row) in _benefits.indexed)
              Padding(
                key: row.key,
                padding: EdgeInsets.only(bottom: i == _benefits.length - 1 ? 0 : 8),
                child: _buildBenefitRow(c, i, row),
              ),
          ],
        ),
        const SizedBox(height: 10),
        _AddBenefitButton(enabled: _canAddBenefit && !_isSaving, onPressed: () => _addBenefit()),
      ],
    );
  }

  Widget _buildBenefitRow(AppColors c, int index, _BenefitRow row) {
    final canDrag = _benefits.length > 1 && !_isSaving;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 28,
          height: 46,
          child: canDrag
              ? ReorderableDragStartListener(
                  index: index,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: Tooltip(
                      message: S.dragReorder,
                      child: Icon(Icons.drag_indicator_rounded, size: 20, color: c.textHint),
                    ),
                  ),
                )
              : Icon(Icons.card_giftcard_rounded, size: 18, color: c.textHint),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: AppTextField(
            controller: row.controller,
            focusNode: row.focusNode,
            hint: index == 0 ? S.eGBirthdayVoucher : S.benefitDetails,
            minLines: 1,
            maxLines: 3,
            maxLength: LevelRules.benefitMaxLength,
            enabled: !_isSaving,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.next,
            onChanged: (value) => _onBenefitChanged(row, value),
            onSubmitted: (value) {
              if (value.trim().isEmpty) {
                FocusScope.of(context).unfocus();
              } else {
                _addBenefit(after: _benefits.indexOf(row));
              }
            },
          ),
        ),
        const SizedBox(width: 2),
        SizedBox(
          height: 46,
          child: IconButton(
            tooltip: S.remove,
            onPressed: _isSaving ? null : () => _removeBenefit(row),
            icon: Icon(Icons.remove_circle_outline_rounded, size: 20, color: c.textHint),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveBar(AppColors c) {
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        border: Border(top: BorderSide(color: c.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Breakpoints.formMaxWidth),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: PrimaryButton(
                label: S.actionSave,
                icon: Icons.check_rounded,
                height: 48,
                isLoading: _isSaving,
                onPressed: _save,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final List<Widget> children;

  const _SectionCard({required this.title, this.trailing, required this.children});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.textPrimary),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _AddBenefitButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPressed;

  const _AddBenefitButton({required this.enabled, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final color = enabled ? c.accent : c.textHint;
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: enabled ? onPressed : null,
        child: SizedBox(
          height: 44,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, size: 20, color: color),
              const SizedBox(width: 6),
              Text(
                S.addBenefit,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Text(
      text,
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.textSecondary),
    );
  }
}

class LevelPreviewCard extends StatelessWidget {
  final LevelStyle style;
  final String name;
  final String range;
  final List<String> benefits;
  final bool showBenefits;

  const LevelPreviewCard({
    super.key,
    required this.style,
    required this.name,
    required this.range,
    required this.benefits,
    this.showBenefits = true,
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
                    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.22)),
                    child: Icon(style.icon, size: 34, color: Colors.white),
                  ),
                ],
              ),
            ),
            if (showBenefits)
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
  final bool embedded;

  const LevelLadder({super.key, required this.slots, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    if (slots.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: embedded ? c.inputFill : c.card,
        borderRadius: BorderRadius.circular(embedded ? 10 : 16),
      ),
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
