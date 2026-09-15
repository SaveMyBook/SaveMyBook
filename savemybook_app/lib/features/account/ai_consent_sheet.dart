import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/ai.dart';
import '../../services/ai_status.dart';
import '../../utils/app_colors.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/state_views.dart';
import '../../i18n/strings.dart';

const aiProviderFallbackNames = ['DeepSeek', 'Google Gemini', 'OpenAI'];

String aiProviderNames(AiStatusInfo status) =>
    (status.providersInUse.isEmpty ? aiProviderFallbackNames : status.providersInUse).join('、');

Future<bool> showAiConsentSheet(BuildContext context, {AiStatusInfo? status}) async {
  final c = AppColors.of(context);
  final agreed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: c.sheetBg,
    constraints: BoxConstraints(maxWidth: 560, maxHeight: MediaQuery.sizeOf(context).height * 0.9),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => AiConsentSheet(status: status ?? AiStatus.value),
  );
  return agreed == true;
}

Future<bool> ensureAiConsent(BuildContext context) async {
  if (AiStatus.value.consented) return true;
  final agreed = await showAiConsentSheet(context);
  if (!agreed || !context.mounted) return false;
  final result = await runBusy(context, () => AiStatus.setConsent(true));
  if (!context.mounted) return false;
  if (result == null || !result.isOk || result.data?.consented != true) {
    showAppSnackBar(context, result?.error ?? S.actionFailed, isError: true);
    return false;
  }
  return true;
}

class AiConsentSheet extends StatelessWidget {
  final AiStatusInfo status;

  const AiConsentSheet({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final showAll = !status.any;
    final rows = <(IconData, String, String)>[
      if (showAll || status.support) (Icons.support_agent_rounded, S.aiSupport, S.messagesEnterStatusOrdersReservations),
      if (showAll || status.listingAssist) (Icons.auto_awesome_rounded, S.listingAssist, S.isbnTitleConditionNotesPhotosSelect),
      if (showAll || status.recommend) (Icons.menu_book_rounded, S.recommendations, S.bookDetailsFromFavoritesPurchaseHistory),
    ];

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: c.divider, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.privacy_tip_outlined, color: c.accent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          S.aiDataProcessing2,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.textPrimary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    S.whenUseAiFeaturesWeShare,
                    style: TextStyle(fontSize: 14, height: 1.55, color: c.textPrimary),
                  ),
                  _heading(c, S.dataShared),
                  for (final (icon, label, detail) in rows) _dataRow(c, icon, label, detail),
                  _heading(c, S.recipients),
                  _body(c, aiProviderNames(status)),
                  _heading(c, S.purpose),
                  _body(c, S.usedOnlyGenerateSupportRepliesPrepare),
                  _heading(c, S.withdrawingConsent),
                  _body(c, S.canTurnOffAiDataProcessing),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: S.decline,
                    color: c.textSecondary,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PrimaryButton(
                    label: S.agreeContinue,
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      Navigator.of(context).pop(true);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heading(AppColors c, String text) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: c.textSecondary)),
      );

  Widget _body(AppColors c, String text) =>
      Text(text, style: TextStyle(fontSize: 14, height: 1.55, color: c.textPrimary));

  Widget _dataRow(AppColors c, IconData icon, String label, String detail) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: c.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, size: 18, color: c.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary)),
                  const SizedBox(height: 2),
                  Text(detail, style: TextStyle(fontSize: 13, height: 1.5, color: c.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      );
}
