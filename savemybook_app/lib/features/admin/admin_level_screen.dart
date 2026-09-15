import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/admin_models.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/app_forms.dart';
import '../../widgets/app_header.dart';
import '../../widgets/state_views.dart';
import '../../i18n/strings.dart';
import 'admin_layout.dart';

class AdminLevelScreen extends StatefulWidget {
  const AdminLevelScreen({super.key});

  @override
  State<AdminLevelScreen> createState() => _AdminLevelScreenState();
}

class _AdminLevelScreenState extends State<AdminLevelScreen> {
  static const int _maxPointsLimit = 100000000;

  final ApiService _api = ApiService();
  List<AdminLevel> _levels = [];
  bool _isLoading = true;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final levels = await _api.fetchAdminLevels();
    if (!mounted) return;
    levels.sort((a, b) => a.minPoints.compareTo(b.minPoints));
    setState(() {
      _levels = levels;
      _isLoading = false;
    });
  }

  Future<void> _retry() async {
    setState(() => _isLoading = true);
    await _load();
  }

  AdminLevel? _overlapping(int min, int? max, {int? exceptId}) {
    final upper = max ?? _maxPointsLimit * 10;
    for (final other in _levels) {
      if (other.levelId == exceptId) continue;
      final otherUpper = other.maxPoints ?? _maxPointsLimit * 10;
      if (min <= otherUpper && other.minPoints <= upper) return other;
    }
    return null;
  }

  String _rangeText(AdminLevel level) => level.maxPoints == null
      ? S.p0PointsUp(level.minPoints)
      : S.p0P1Points(level.minPoints, level.maxPoints!);

  Future<void> _edit({AdminLevel? level}) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      await _runEdit(level);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _runEdit(AdminLevel? level) async {
    final c = AppColors.of(context);
    final nameController = TextEditingController(text: level?.name ?? '');
    final suggestedMin = level?.minPoints ??
        (_levels.isEmpty ? 0 : ((_levels.last.maxPoints ?? _levels.last.minPoints) + 1));
    final minController = TextEditingController(text: '$suggestedMin');
    final maxController = TextEditingController(text: level?.maxPoints?.toString() ?? '');
    final benefitsController = TextEditingController(text: level?.benefits ?? '');
    String? nameError;
    String? rangeError;

    final digits = [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(9),
    ];

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  level == null ? S.newTier : S.editTier,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.textPrimary),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: nameController,
                  hint: S.tierName,
                  maxLength: 50,
                  errorText: nameError,
                  onChanged: (_) {
                    if (nameError != null) setSheetState(() => nameError = null);
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: minController,
                        hint: S.minimumPoints,
                        keyboardType: TextInputType.number,
                        inputFormatters: digits,
                        onChanged: (_) {
                          if (rangeError != null) setSheetState(() => rangeError = null);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AppTextField(
                        controller: maxController,
                        hint: S.maximumPointsLeaveEmptyNoCap,
                        keyboardType: TextInputType.number,
                        inputFormatters: digits,
                        onChanged: (_) {
                          if (rangeError != null) setSheetState(() => rangeError = null);
                        },
                      ),
                    ),
                  ],
                ),
                Reveal(
                  visible: rangeError != null,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6, left: 4),
                    child: Text(
                      rangeError ?? '',
                      style: TextStyle(fontSize: 12, color: c.danger, height: 1.4),
                    ),
                  ),
                ),
                if (_levels.any((l) => l.levelId != level?.levelId)) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final other in _levels)
                        if (other.levelId != level?.levelId)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: c.inputFill,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${other.name}・${_rangeText(other)}',
                              style: TextStyle(fontSize: 11, color: c.textSecondary),
                            ),
                          ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                AppTextField(
                  controller: benefitsController,
                  hint: S.benefitsSeparatedByCommasLineBreaks,
                  maxLines: 4,
                  maxLength: 500,
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: S.actionSave,
                  height: 46,
                  onPressed: () {
                    final name = nameController.text.trim();
                    final min = int.tryParse(minController.text.trim());
                    final maxText = maxController.text.trim();
                    final max = maxText.isEmpty ? null : int.tryParse(maxText);

                    String? nextNameError;
                    String? nextRangeError;
                    if (name.isEmpty) nextNameError = S.enterTierName;
                    if (min == null) {
                      nextRangeError = S.enterMinimumPoints;
                    } else if (max != null && max <= min) {
                      nextRangeError = S.maximumPointsMustExceedMinimum;
                    } else {
                      final clash = _overlapping(min, max, exceptId: level?.levelId);
                      if (clash != null) {
                        nextRangeError = S.pointsRangeOverlapsWithP0P1(clash.name, _rangeText(clash));
                      }
                    }

                    if (nextNameError != null || nextRangeError != null) {
                      HapticFeedback.lightImpact();
                      setSheetState(() {
                        nameError = nextNameError;
                        rangeError = nextRangeError;
                      });
                      return;
                    }
                    Navigator.pop(ctx, true);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (saved != true || !mounted) return;

    final maxText = maxController.text.trim();
    final error = await runBusy(
      context,
      () => _api.saveLevel(
        levelId: level?.levelId,
        name: nameController.text.trim(),
        minPoints: int.parse(minController.text.trim()),
        maxPoints: maxText.isEmpty ? null : int.parse(maxText),
        benefits: benefitsController.text.trim(),
      ),
    );
    if (!mounted) return;

    if (error != null) {
      if (error.isNotEmpty && error != S.verificationCancelled) showAppSnackBar(context, error, isError: true);
    } else {
      showAppSnackBar(context, level == null ? S.tierAdded : S.tierUpdated);
      await _load();
    }
  }

  Future<void> _delete(AdminLevel level) async {
    if (_isBusy) return;
    final ok = await showConfirmDialog(
      context,
      title: S.deleteTier,
      message: S.deleteP0MembersTierDropNext(level.name),
      confirmLabel: S.actionDelete,
      isDestructive: true,
    );
    if (!ok || !mounted) return;

    setState(() => _isBusy = true);
    final error = await runBusy(context, () => _api.deleteLevel(level.levelId));
    if (!mounted) return;
    setState(() => _isBusy = false);

    if (error != null) {
      if (error.isNotEmpty && error != S.verificationCancelled) showAppSnackBar(context, error, isError: true);
    } else {
      showAppSnackBar(context, S.tierDeleted);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.scaffold,
      body: AdminLayout(
        builder: (context, frame) => Column(
          children: [
            AppHeader(
              title: S.membershipTiers,
              icon: Icons.workspace_premium_outlined,
              actions: [
                HeaderIconButton(icon: Icons.add_rounded, onTap: _isBusy ? null : () => _edit()),
              ],
            ),
            Expanded(
              child: SwitchIn(
                child: _isLoading
                    ? const LoadingView.list()
                    : RefreshIndicator(
                        color: c.accent,
                        onRefresh: _load,
                        child: SwitchIn(
                          child: _levels.isEmpty
                              ? ListView(
                                  key: const ValueKey('empty'),
                                  children: [
                                    const SizedBox(height: 60),
                                    EmptyView(
                                      icon: Icons.workspace_premium_outlined,
                                      message: S.noMembershipTiersSetUp,
                                      actionLabel: S.newTier,
                                      onAction: () => _edit(),
                                    ),
                                    Center(
                                      child: TextButton(
                                        onPressed: _retry,
                                        child: Text(S.refresh, style: TextStyle(color: c.textSecondary)),
                                      ),
                                    ),
                                  ],
                                )
                              : ListView.builder(
                                  key: const ValueKey('items'),
                                  padding: frame.inset(const EdgeInsets.fromLTRB(16, 16, 16, 24)),
                                  itemCount: _levels.length,
                                  itemBuilder: (_, i) => RevealOnScroll(
                                    index: i,
                                    child: _buildCard(_levels[i], i, c, wide: frame.isWide),
                                  ),
                                ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(AdminLevel level, int index, AppColors c, {bool wide = false}) {
    final next = index + 1 < _levels.length ? _levels[index + 1] : null;
    final gap = level.maxPoints != null && next != null && next.minPoints > level.maxPoints! + 1;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () => _edit(level: level),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.workspace_premium_rounded, size: 20, color: c.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  level.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: c.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                flex: wide ? 0 : 1,
                child: Text(_rangeText(level),
                    textAlign: TextAlign.end,
                    maxLines: 2,
                    style: TextStyle(fontSize: 12, color: c.textSecondary)),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline_rounded, color: c.iconInactive, size: 20),
                onPressed: _isBusy ? null : () => _delete(level),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            level.benefits.isEmpty ? S.noBenefitsDescribedYet : level.benefits,
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: level.benefits.isEmpty ? c.textHint : c.textSecondary,
            ),
          ),
          if (gap) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 14, color: c.warning),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    S.noTierCoversP0P1Points(level.maxPoints! + 1, next.minPoints - 1),
                    style: TextStyle(fontSize: 11, color: c.warning),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
