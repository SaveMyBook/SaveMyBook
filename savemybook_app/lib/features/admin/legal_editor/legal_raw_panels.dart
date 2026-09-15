import 'package:flutter/material.dart';
import '../../../i18n/strings.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/app_radius.dart';
import '../../../utils/motion.dart';
import '../../../widgets/animations.dart';
import '../../../widgets/state_views.dart';
import 'legal_text.dart';

class LegalFormatNotice extends StatelessWidget {
  const LegalFormatNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: c.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              S.documentSFormatDoesNotFully,
              style: TextStyle(fontSize: 12.5, height: 1.5, color: c.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class LegalFormatHelpCard extends StatelessWidget {
  final bool open;
  final VoidCallback onToggle;

  const LegalFormatHelpCard({super.key, required this.open, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final rules = [
      S.paragraphWhoseFirstLine1Title,
      S.sectionNumbersMustStart1Increase,
      S.blankLineStartsNewParagraphSingle,
      S.whenSwitchingSectionsAskedConfirmAny,
    ];

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(AppRadius.card),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                children: [
                  Icon(Icons.help_outline_rounded, size: 18, color: c.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      S.howSectionHeadingsDetected,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: c.textPrimary),
                    ),
                  ),
                  AnimatedRotation(
                    turns: open ? 0.5 : 0,
                    duration: Motion.base,
                    curve: Motion.emphasized,
                    child: Icon(Icons.expand_more_rounded, size: 20, color: c.iconInactive),
                  ),
                ],
              ),
            ),
          ),
          Reveal(
            visible: open,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final rule in rules)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 7, right: 8),
                            child: Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(color: c.textHint, shape: BoxShape.circle),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              rule,
                              style: TextStyle(fontSize: 12.5, height: 1.6, color: c.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LegalRawTextField extends StatelessWidget {
  final TextEditingController controller;

  const LegalRawTextField({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: c.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: TextField(
        controller: controller,
        maxLines: null,
        minLines: 14,
        keyboardType: TextInputType.multiline,
        scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
        style: TextStyle(fontSize: 14, height: 1.8, color: c.textPrimary),
        decoration: InputDecoration(
          isDense: true,
          filled: false,
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          hintText: S.enterPasteFullTextHere,
          hintStyle: TextStyle(color: c.textHint, height: 1.8, fontSize: 13),
        ),
      ),
    );
  }
}

class LegalDetectedSectionCount extends StatelessWidget {
  final TextEditingController controller;

  const LegalDetectedSectionCount({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (_, value, _) {
        final count = LegalText.parse(value.text).sections.length;
        return Row(
          children: [
            Icon(Icons.segment_rounded, size: 13, color: c.textHint),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                count == 0 ? S.noSectionHeadingsDetected : S.p0SectionsDetected(count),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: c.textHint),
              ),
            ),
          ],
        );
      },
    );
  }
}
