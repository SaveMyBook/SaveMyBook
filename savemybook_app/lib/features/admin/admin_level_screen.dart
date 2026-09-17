import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/admin_models.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/level_style.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/app_header.dart';
import '../../widgets/state_views.dart';
import '../../i18n/strings.dart';
import 'admin_layout.dart';
import 'admin_level_edit_screen.dart';
import 'level_rules.dart';

class AdminLevelScreen extends StatefulWidget {
  const AdminLevelScreen({super.key});

  @override
  State<AdminLevelScreen> createState() => _AdminLevelScreenState();
}

class _AdminLevelScreenState extends State<AdminLevelScreen> {
  static const double _twoPaneWidth = 900;

  final ApiService _api = ApiService();
  List<AdminLevel> _levels = [];
  bool _isLoading = true;
  bool _isBusy = false;
  int? _selectedId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final levels = await _api.fetchAdminLevels();
    if (!mounted) return;
    setState(() {
      _levels = LevelRules.sorted(levels);
      _isLoading = false;
      if (!_levels.any((l) => l.levelId == _selectedId)) _selectedId = _levels.firstOrNull?.levelId;
    });
  }

  Future<void> _retry() async {
    setState(() => _isLoading = true);
    await _load();
  }

  AdminLevel? get _selected => _levels.where((l) => l.levelId == _selectedId).firstOrNull;

  Future<void> _edit({AdminLevel? level}) async {
    if (_isBusy) return;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AdminLevelEditScreen(level: level, levels: _levels)),
    );
    if (saved != true || !mounted) return;
    showAppSnackBar(context, level == null ? S.tierAdded : S.tierUpdated);
    await _load();
  }

  Future<void> _showActions(AdminLevel level) async {
    final c = AppColors.of(context);
    final choice = await showOptionSheet<String>(
      context,
      title: level.name,
      options: [
        SheetOption(value: 'edit', label: S.actionEdit, icon: Icons.edit_outlined),
        SheetOption(value: 'delete', label: S.actionDelete, icon: Icons.delete_outline_rounded, color: c.danger),
      ],
    );
    if (!mounted || choice == null) return;
    if (choice == 'edit') _edit(level: level);
    if (choice == 'delete') _delete(level);
  }

  Future<void> _delete(AdminLevel level) async {
    if (_isBusy) return;
    final blocked = LevelRules.deleteBlockReason(level, _levels);
    if (blocked != null) {
      HapticFeedback.heavyImpact();
      showAppSnackBar(context, blocked, isError: true);
      return;
    }

    final fallback = LevelRules.fallbackAfterDelete(level, _levels);
    final ok = await showConfirmDialog(
      context,
      title: S.deleteTier,
      message: level.memberCount > 0 && fallback != null
          ? S.p0CurrentlyP1MembersAfterDeletion(level.name, level.memberCount, fallback.name)
          : S.noMembersCurrentlyP0OtherTiers(level.name),
      confirmLabel: S.actionDelete,
      isDestructive: true,
    );
    if (!ok || !mounted) return;

    setState(() => _isBusy = true);
    final result = await runBusy(context, () => _api.deleteLevel(level.levelId));
    if (!mounted) return;
    setState(() => _isBusy = false);
    if (result == null) return;

    final error = result.error;
    if (error != null) {
      if (error.isNotEmpty && error != S.verificationCancelled) showAppSnackBar(context, error, isError: true);
      return;
    }
    final movedTo = result.movedTo;
    showAppSnackBar(
      context,
      result.movedMembers > 0 && movedTo != null ? S.tierDeletedP0MembersMovedP1(result.movedMembers, movedTo) : S.tierDeleted,
    );
    await _load();
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    if (_isBusy) return;
    final before = _levels;
    final target = newIndex > oldIndex ? newIndex - 1 : newIndex;
    if (target == oldIndex) return;
    final reordered = [...before];
    reordered.insert(target, reordered.removeAt(oldIndex));

    final changes = LevelRules.reorderChanges(before, reordered);
    if (changes.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _levels = reordered);

    final ok = await showConfirmDialog(
      context,
      title: S.changeTierOrder,
      message: [
        S.thresholdsStayWithTheirPositionThese,
        for (final change in changes) S.p0P1P2Pts(change.level.name, change.from, change.to),
      ].join('\n'),
      confirmLabel: S.actionSave,
    );
    if (!mounted) return;
    if (!ok) {
      setState(() => _levels = before);
      return;
    }

    setState(() => _isBusy = true);
    final error = await runBusy(context, () => _api.reorderLevels([for (final l in reordered) l.levelId]));
    if (!mounted) return;
    setState(() => _isBusy = false);
    if (error != null) {
      setState(() => _levels = before);
      if (error.isNotEmpty && error != S.verificationCancelled) showAppSnackBar(context, error, isError: true);
      return;
    }
    showAppSnackBar(context, S.tierOrderUpdated);
    await _load();
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
                HeaderIconButton(icon: Icons.add_rounded, onTap: _isBusy || _isLoading ? null : () => _edit()),
              ],
            ),
            Expanded(
              child: SwitchIn(
                child: _isLoading
                    ? const LoadingView.list()
                    : _levels.isEmpty
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
                        : frame.width >= _twoPaneWidth
                            ? _buildTwoPane(c, frame)
                            : _buildList(c, frame, twoPane: false),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTwoPane(AppColors c, AdminFrame frame) {
    final selected = _selected ?? _levels.first;
    final index = _levels.indexOf(selected);

    return Center(
      key: const ValueKey('two-pane'),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: _buildList(c, frame, twoPane: true)),
            Expanded(
              flex: 2,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(8, 16, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LevelPreviewCard(
                      style: LevelStyle.at(index),
                      name: selected.name,
                      range: LevelRules.rangeLabel(selected.minPoints, LevelRules.maxPointsOf(_levels, index)),
                      benefits: LevelRules.benefitsOf(selected.benefits),
                    ),
                    const SizedBox(height: 12),
                    AppCard(
                      child: Row(
                        children: [
                          Icon(Icons.groups_outlined, color: c.textSecondary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              S.p0Members(selected.memberCount),
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.textPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: SecondaryButton(
                            label: S.actionDelete,
                            icon: Icons.delete_outline_rounded,
                            color: c.danger,
                            onPressed: _isBusy ? null : () => _delete(selected),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: PrimaryButton(
                            label: S.actionEdit,
                            icon: Icons.edit_outlined,
                            onPressed: _isBusy ? null : () => _edit(level: selected),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(AppColors c, AdminFrame frame, {required bool twoPane}) {
    final padding = twoPane
        ? const EdgeInsets.fromLTRB(24, 16, 12, 24)
        : frame.inset(const EdgeInsets.fromLTRB(16, 16, 16, 24), maxWidth: 760);

    return RefreshIndicator(
      key: const ValueKey('items'),
      color: c.accent,
      onRefresh: _load,
      child: ReorderableListView.builder(
        padding: padding,
        buildDefaultDragHandles: false,
        header: _LevelOverview(levels: _levels),
        itemCount: _levels.length,
        onReorder: _reorder,
        proxyDecorator: (child, _, _) => Material(color: Colors.transparent, elevation: 6, child: child),
        itemBuilder: (context, i) {
          final level = _levels[i];
          return Padding(
            key: ValueKey('level-${level.levelId}'),
            padding: const EdgeInsets.only(bottom: 10),
            child: _LevelTile(
              level: level,
              index: i,
              maxPoints: LevelRules.maxPointsOf(_levels, i),
              selected: twoPane && level.levelId == (_selected ?? _levels.first).levelId,
              canReorder: _levels.length > 1 && !_isBusy,
              onTap: twoPane ? () => setState(() => _selectedId = level.levelId) : () => _edit(level: level),
              onMore: _isBusy ? null : () => _showActions(level),
            ),
          );
        },
      ),
    );
  }
}

class _LevelOverview extends StatelessWidget {
  final List<AdminLevel> levels;

  const _LevelOverview({required this.levels});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final total = levels.fold<int>(0, (sum, l) => sum + l.memberCount);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 24,
              runSpacing: 8,
              children: [
                _Figure(value: '${levels.length}', label: S.tiers),
                _Figure(value: '$total', label: S.members4),
              ],
            ),
            const SizedBox(height: 14),
            Semantics(
              label: S.memberDistribution,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 12,
                  child: total == 0
                      ? ColoredBox(color: c.inputFill)
                      : Row(
                          children: [
                            for (final (i, level) in levels.indexed)
                              if (level.memberCount > 0)
                                Expanded(
                                  flex: level.memberCount,
                                  child: Container(
                                    margin: EdgeInsets.only(right: i == levels.length - 1 ? 0 : 2),
                                    color: LevelStyle.at(i).accent,
                                  ),
                                ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  final String value;
  final String label;

  const _Figure({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: value,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c.textPrimary),
          ),
          TextSpan(text: ' $label', style: TextStyle(fontSize: 13, color: c.textSecondary)),
        ],
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  final AdminLevel level;
  final int index;
  final int? maxPoints;
  final bool selected;
  final bool canReorder;
  final VoidCallback onTap;
  final VoidCallback? onMore;

  const _LevelTile({
    required this.level,
    required this.index,
    required this.maxPoints,
    required this.selected,
    required this.canReorder,
    required this.onTap,
    this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final style = LevelStyle.at(index);
    final benefits = LevelRules.benefitsOf(level.benefits);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: selected ? c.accent : Colors.transparent, width: 1.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [style.gradient[1], style.gradient[0]]),
                  ),
                  child: Icon(style.icon, size: 22, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        level.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        LevelRules.rangeLabel(level.minPoints, maxPoints),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: c.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        benefits.isEmpty ? S.noBenefitsSet : benefits.join('・'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: benefits.isEmpty ? c.textHint : c.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${level.memberCount}',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.textPrimary),
                    ),
                    Text(S.members4, style: TextStyle(fontSize: 11, color: c.textSecondary)),
                  ],
                ),
                IconButton(
                  tooltip: S.moreActions,
                  onPressed: onMore,
                  icon: Icon(Icons.more_horiz_rounded, color: c.textSecondary),
                ),
                if (canReorder)
                  ReorderableDragStartListener(
                    index: index,
                    child: Semantics(
                      label: S.dragReorder,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(0, 8, 8, 8),
                        child: Icon(Icons.drag_indicator_rounded, color: c.iconInactive),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
