import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import '../../../i18n/strings.dart';
import '../../../models/support.dart';
import '../../../utils/api_helpers.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/app_radius.dart';
import '../../../utils/motion.dart';
import '../../../widgets/animations.dart';
import 'legal_draft_store.dart';

class LegalStatusStrip extends StatelessWidget {
  final LegalDoc? doc;
  final bool dirty;
  final bool draftSaved;
  final ValueListenable<String> stats;

  const LegalStatusStrip({
    super.key,
    required this.doc,
    required this.dirty,
    required this.draftSaved,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final doc = this.doc;
    final String label;
    final IconData icon;
    final Color tint;

    if (dirty) {
      label = draftSaved ? '${S.unsaved}・${S.draftSavedAutomatically}' : S.unsaved;
      icon = Icons.edit_rounded;
      tint = c.warning;
    } else if (doc == null) {
      label = S.notCreatedYet;
      icon = Icons.fiber_new_outlined;
      tint = c.textHint;
    } else {
      final updated = S.updatedP0(formatDateTime(doc.updatedAt));
      label = S.versionP0P1(doc.version, updated);
      icon = Icons.check_circle_rounded;
      tint = c.success;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
      child: Row(
        children: [
          SwitchIn(
            duration: Motion.micro,
            child: Icon(icon, key: ValueKey(icon), size: 14, color: tint),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 3,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: dirty ? c.warning : c.textSecondary),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            flex: 2,
            child: ValueListenableBuilder<String>(
              valueListenable: stats,
              builder: (_, value, _) => Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 12, color: c.textHint),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LegalDraftBanner extends StatelessWidget {
  final LegalDraft draft;
  final LegalDoc? doc;
  final VoidCallback onDiscard;
  final VoidCallback onRestore;

  const LegalDraftBanner({
    super.key,
    required this.draft,
    required this.doc,
    required this.onDiscard,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final stale = draft.baseUpdatedAt != doc?.updatedAt?.toIso8601String();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        decoration: BoxDecoration(
          color: c.warning.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: c.warning.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.restore_rounded, size: 18, color: c.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    S.unsavedDraftFromP0Found(formatDateTime(draft.savedAt)),
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: c.textPrimary),
                  ),
                ),
              ],
            ),
            if (stale) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 26),
                child: Text(
                  S.documentWasUpdatedAfterDraftWas,
                  style: TextStyle(fontSize: 12, height: 1.5, color: c.textSecondary),
                ),
              ),
            ],
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 4,
                children: [
                  TextButton(
                    onPressed: onDiscard,
                    style: TextButton.styleFrom(foregroundColor: c.textSecondary),
                    child: Text(S.discardDraft, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  TextButton(
                    onPressed: onRestore,
                    style: TextButton.styleFrom(foregroundColor: c.accent),
                    child: Text(S.restoreDraft, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
