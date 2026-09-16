import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../i18n/strings.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/app_radius.dart';
import '../../../utils/motion.dart';
import '../../../widgets/animations.dart';
import '../../../widgets/state_views.dart';
import 'legal_section.dart';
import 'legal_text.dart';

class LegalSectionsHeading extends StatelessWidget {
  final int count;

  const LegalSectionsHeading({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      children: [
        Flexible(
          child: Text(
            '${S.articles}（$count）',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c.textPrimary),
          ),
        ),
      ],
    );
  }
}

class LegalIntroRow extends StatelessWidget {
  final TextEditingController intro;
  final VoidCallback onTap;

  const LegalIntroRow({super.key, required this.intro, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      onTap: onTap,
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: intro,
        builder: (_, value, _) {
          final text = value.text.trim();
          return Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: c.inputFill,
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
                child: Icon(Icons.notes_rounded, size: 16, color: c.textSecondary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      S.preamble,
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: c.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      text.isEmpty ? S.unnumberedOpeningTextLeaveEmptyIf : _snippet(text),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: text.isEmpty ? c.textHint : c.textSecondary),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: c.iconInactive),
            ],
          );
        },
      ),
    );
  }
}

class LegalSectionRow extends StatelessWidget {
  final LegalSection section;
  final int index;
  final bool flagged;
  final VoidCallback onOpen;
  final VoidCallback onMenu;

  const LegalSectionRow({
    super.key,
    required this.section,
    required this.index,
    required this.flagged,
    required this.onOpen,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Reveal(
        visible: !section.removing,
        child: FadeSlideIn(
          index: math.min(index, 8),
          offsetY: 12,
          child: ListenableBuilder(
            listenable: Listenable.merge([section.title, section.body]),
            builder: (context, _) {
              final title = section.title.text.trim();
              final body = section.body.text.trim();

              return AnimatedContainer(
                duration: Motion.base,
                curve: Motion.standard,
                decoration: BoxDecoration(
                  color: c.card,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(color: flagged ? c.danger : c.border, width: flagged ? 1.4 : 1),
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    onTap: onOpen,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 0, 10),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: (flagged ? c.danger : c.accent).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(AppRadius.chip),
                            ),
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: flagged ? c.danger : c.accent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title.isEmpty ? (flagged ? S.sectionTitleRequired : S.untitledSection) : title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                    color: title.isEmpty ? (flagged ? c.danger : c.textHint) : c.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  body.isEmpty ? S.noContentYet : _snippet(body),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12, color: body.isEmpty ? c.textHint : c.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: Icon(Icons.more_horiz_rounded, size: 20, color: c.iconInactive),
                            onPressed: onMenu,
                          ),
                          ReorderableDragStartListener(
                            index: index,
                            child: SizedBox(
                              width: 40,
                              height: 44,
                              child: Icon(Icons.drag_indicator_rounded, size: 20, color: c.iconInactive),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class LegalAddSectionButton extends StatelessWidget {
  final bool showEmptyHint;
  final VoidCallback onTap;

  const LegalAddSectionButton({super.key, required this.showEmptyHint, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      children: [
        if (showEmptyHint)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              S.noArticlesYetAddFirstOne,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: c.textHint),
            ),
          ),
        PressableScale(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: c.accent.withValues(alpha: 0.4)),
              color: c.accent.withValues(alpha: 0.05),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_rounded, size: 18, color: c.accent),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    S.addSection,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.accent),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

Widget legalLiftDragged(Widget child, int index, Animation<double> animation) {
  return AnimatedBuilder(
    animation: animation,
    builder: (context, _) {
      final t = Curves.easeOut.transform(animation.value);
      final c = AppColors.of(context);
      return Transform.scale(
        scale: 1 + 0.03 * t,
        child: Material(
          type: MaterialType.transparency,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.card),
              boxShadow: [
                BoxShadow(
                  color: c.shadow.withValues(alpha: 0.18 * t),
                  blurRadius: 24 * t,
                  offset: Offset(0, 8 * t),
                ),
              ],
            ),
            child: child,
          ),
        ),
      );
    },
  );
}

String _snippet(String text) => '${S.p0Characters(LegalText.charCount(text))}・${text.trim().split('\n').first}';
