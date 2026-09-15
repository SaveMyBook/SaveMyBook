import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../i18n/strings.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/app_radius.dart';
import '../../../utils/motion.dart';
import '../../../widgets/animations.dart';
import '../../../widgets/app_buttons.dart';
import 'legal_text.dart';

Future<bool?> showLegalSaveSheet(
  BuildContext context, {
  required String title,
  required int? currentVersion,
  required bool requiresConsent,
  required bool contentChanged,
  required LegalDiff diff,
}) {
  final c = AppColors.of(context);
  FocusManager.instance.primaryFocus?.unfocus();

  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: c.sheetBg,
    barrierColor: c.scrim,
    sheetAnimationStyle: const AnimationStyle(duration: Motion.enter, reverseDuration: Motion.base),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    clipBehavior: Clip.antiAlias,
    builder: (_) => _LegalSaveSheet(
      title: title,
      currentVersion: currentVersion,
      requiresConsent: requiresConsent,
      contentChanged: contentChanged,
      diff: diff,
    ),
  );
}

class _LegalSaveSheet extends StatefulWidget {
  final String title;
  final int? currentVersion;
  final bool requiresConsent;
  final bool contentChanged;
  final LegalDiff diff;

  const _LegalSaveSheet({
    required this.title,
    required this.currentVersion,
    required this.requiresConsent,
    required this.contentChanged,
    required this.diff,
  });

  @override
  State<_LegalSaveSheet> createState() => _LegalSaveSheetState();
}

class _LegalSaveSheetState extends State<_LegalSaveSheet> {
  bool? _major;

  void _pick(bool major) {
    HapticFeedback.selectionClick();
    setState(() => _major = major);
  }

  List<({IconData icon, String label, Color color})> _summary(AppColors c) {
    final d = widget.diff;
    return [
      if (d.titleChanged) (icon: Icons.title_rounded, label: S.titleEdited, color: c.accent),
      if (d.added > 0) (icon: Icons.add_rounded, label: S.p0Added(d.added), color: c.success),
      if (d.removed > 0) (icon: Icons.remove_rounded, label: S.p0Removed(d.removed), color: c.danger),
      if (d.changed > 0) (icon: Icons.edit_rounded, label: S.p0Edited(d.changed), color: c.accent),
      if (d.reordered) (icon: Icons.swap_vert_rounded, label: S.sectionsReordered, color: c.accent),
      if (d.introChanged) (icon: Icons.notes_rounded, label: d.hasSections ? S.preambleEdited : S.contentEdited, color: c.accent),
      if (widget.contentChanged && d.charDelta != 0)
        (
          icon: Icons.text_fields_rounded,
          label: d.charDelta > 0 ? S.p0Characters2(d.charDelta) : S.p0Characters3(d.charDelta),
          color: c.textSecondary,
        ),
      if (widget.contentChanged && d.isEmpty && d.charDelta == 0)
        (icon: Icons.format_align_left_rounded, label: S.formattingAdjusted, color: c.textSecondary),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final current = widget.currentVersion;
    final summary = _summary(c);
    final isNew = current == null;

    final minorVersion = isNew ? S.createdAsVersion1 : S.staysVersionP0(current);
    final majorVersion = isNew ? S.createdAsVersion1 : S.versionP0P12(current, current + 1);
    final majorDetail = widget.requiresConsent
        ? S.substantiveChangesRightsObligationsTermsAll
        : S.substantiveContentChangesAllUsersNotified;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(color: c.divider, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Text(
            S.saveP0(widget.title),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: c.textPrimary),
          ),
          const SizedBox(height: 16),
          _heading(S.summaryChanges, c),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final item in summary) _SummaryChip(icon: item.icon, label: item.label, color: item.color),
            ],
          ),
          const SizedBox(height: 18),
          _heading(S.updateType, c),
          _ChoiceCard(
            icon: Icons.edit_note_rounded,
            tint: c.accent,
            title: S.minorEdit,
            detail: S.fixingTyposFormattingUsersNotNotified,
            version: minorVersion,
            selected: _major == false,
            onTap: () => _pick(false),
          ),
          const SizedBox(height: 10),
          _ChoiceCard(
            icon: Icons.campaign_outlined,
            tint: c.warning,
            title: S.majorUpdate2,
            detail: majorDetail,
            version: majorVersion,
            selected: _major == true,
            disabledReason: widget.contentChanged ? null : S.contentUnchangedTitleOnlyChangeCannot,
            onTap: widget.contentChanged ? () => _pick(true) : null,
          ),
          Reveal(
            visible: _major == true,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.control),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 16, color: c.warning),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        S.notificationsSentImmediatelyAfterSubmittingCannot,
                        style: TextStyle(fontSize: 12.5, height: 1.5, color: c.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: S.actionCancel,
                  height: 46,
                  color: c.textSecondary,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PrimaryButton(
                  label: _major == true ? S.publishNotify : S.actionSave,
                  height: 46,
                  color: _major == true ? c.warning : null,
                  onPressed: _major == null ? null : () => Navigator.pop(context, _major),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heading(String text, AppColors c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textSecondary),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SummaryChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final IconData icon;
  final Color tint;
  final String title;
  final String detail;
  final String version;
  final bool selected;
  final String? disabledReason;
  final VoidCallback? onTap;

  const _ChoiceCard({
    required this.icon,
    required this.tint,
    required this.title,
    required this.detail,
    required this.version,
    required this.selected,
    this.disabledReason,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final enabled = onTap != null;

    return PressableScale(
      scale: 0.98,
      onTap: onTap,
      child: AnimatedOpacity(
        duration: Motion.base,
        opacity: enabled ? 1 : 0.55,
        child: AnimatedContainer(
          duration: Motion.base,
          curve: Motion.standard,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? tint.withValues(alpha: 0.08) : c.card,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: selected ? tint : c.border, width: selected ? 1.6 : 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.control),
                ),
                child: Icon(icon, size: 20, color: tint),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c.textPrimary),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      disabledReason ?? detail,
                      style: TextStyle(fontSize: 12.5, height: 1.5, color: c.textSecondary),
                    ),
                    if (enabled)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            Icon(Icons.history_rounded, size: 13, color: tint),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                version,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tint),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedSwitcher(
                duration: Motion.micro,
                child: Icon(
                  selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                  key: ValueKey(selected),
                  size: 22,
                  color: selected ? tint : c.iconInactive,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
