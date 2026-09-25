import 'package:flutter/material.dart';

import '../../i18n/strings.dart';
import '../../models/chat.dart';
import '../../utils/app_colors.dart';
import '../../widgets/app_dialogs.dart';

String chatRiskNote(ChatRiskCategory category) => switch (category) {
  ChatRiskCategory.credential => S.neverShareVerificationCodesPasswordsCard,
  ChatRiskCategory.scam => S.messageContainsCommonScamWordingWe,
  ChatRiskCategory.link => S.messageContainsSuspiciousLinkDoNot,
  ChatRiskCategory.payment => S.doNotPayTransferMoneyOutside,
  ChatRiskCategory.offsite => S.pleaseCompleteDealAppWeCannot,
  ChatRiskCategory.contact => S.personSharedOutsideContactDetailsWatch,
};

/// 同一聊天室每種類別只在最早出現的那則訊息下提醒一次；高風險訊息則每則都提醒。
Map<int, ChatRisk> chatRiskNotes(Iterable<ChatMessage> messages, int myId) {
  final shown = <ChatRiskCategory>{};
  final notes = <int, ChatRisk>{};
  for (final m in messages) {
    final risk = m.risk;
    if (risk == null || m.senderId == myId || m.isRecalled) continue;
    if (risk.high) {
      notes[m.messageId] = risk;
      shown.addAll(risk.categories);
      continue;
    }
    final fresh = risk.categories.where((c) => !shown.contains(c)).toList();
    if (fresh.isEmpty) continue;
    shown.addAll(fresh);
    notes[m.messageId] = ChatRisk(high: false, categories: fresh);
  }
  return notes;
}

class ChatRiskNote extends StatelessWidget {
  final ChatRisk risk;
  final VoidCallback onTips;
  final VoidCallback? onReport;

  const ChatRiskNote({super.key, required this.risk, required this.onTips, this.onReport});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final tone = risk.high ? c.danger : c.textSecondary;
    final link = TextStyle(fontSize: 11.5, height: 1.4, fontWeight: FontWeight.w600, color: risk.high ? c.danger : c.accent);
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1.5),
            child: Icon(risk.high ? Icons.gpp_maybe_rounded : Icons.shield_outlined, size: 13, color: tone),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: chatRiskNote(risk.primary)),
                  const TextSpan(text: '  '),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: GestureDetector(onTap: onTips, child: Text(S.scamSafetyTips, style: link)),
                  ),
                  if (onReport != null) ...[
                    const TextSpan(text: '・'),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.baseline,
                      baseline: TextBaseline.alphabetic,
                      child: GestureDetector(onTap: onReport, child: Text(S.report, style: link)),
                    ),
                  ],
                ],
              ),
              style: TextStyle(fontSize: 11.5, height: 1.4, color: tone, fontWeight: risk.high ? FontWeight.w500 : FontWeight.w400),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatRiskBanner extends StatelessWidget {
  final VoidCallback onTips;
  final VoidCallback? onReport;
  final VoidCallback onDismiss;

  const ChatRiskBanner({super.key, required this.onTips, required this.onDismiss, this.onReport});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final action = TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.danger);
    final compact = TextButton.styleFrom(
      minimumSize: const Size(0, 32),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    return Material(
      color: c.danger.withValues(alpha: c.isDark ? 0.16 : 0.08),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 4, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(Icons.gpp_maybe_rounded, size: 20, color: c.danger),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    S.chatHighRiskMessagesDoNot,
                    style: TextStyle(fontSize: 13, height: 1.4, fontWeight: FontWeight.w600, color: c.textPrimary),
                  ),
                ),
                SizedBox(
                  width: 36,
                  height: 24,
                  child: IconButton(
                    onPressed: onDismiss,
                    tooltip: S.close,
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.close_rounded, size: 18, color: c.textSecondary),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Wrap(
                children: [
                  TextButton(onPressed: onTips, style: compact, child: Text(S.scamSafetyTips, style: action)),
                  if (onReport != null)
                    TextButton(onPressed: onReport, style: compact, child: Text(S.report, style: action)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void showFraudTipsSheet(BuildContext context) {
  final c = AppColors.of(context);
  final tips = [
    (Icons.inventory_2_outlined, S.payEveryDealAppUseSmart),
    (Icons.password_rounded, S.weOurSupportTeamNeverAsk),
    (Icons.link_off_rounded, S.doNotOpenUnknownShortLinks),
    (Icons.report_gmailerrorred_rounded, S.cancelInstallmentsAccountFrozenPaymentVerification),
    (Icons.flag_outlined, S.ifSeeSuspiciousMessageReportAdministrator),
  ];
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: c.sheetBg,
    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8, maxWidth: 640),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: c.divider, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 18),
            Text(S.scamSafetyTips, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c.textPrimary)),
            const SizedBox(height: 16),
            for (final (icon, text) in tips)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 20, color: c.accent),
                    const SizedBox(width: 12),
                    Expanded(child: Text(text, style: TextStyle(fontSize: 14.5, height: 1.5, color: c.textPrimary))),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

Future<bool> confirmRiskySend(BuildContext context) => showConfirmDialog(
  context,
  title: S.confirmSending,
  message: S.messageIncludesContactPaymentDetailsDeals,
  confirmLabel: S.sendAnyway,
  cancelLabel: S.editMessage2,
  icon: Icons.shield_outlined,
);
