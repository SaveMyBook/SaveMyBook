import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/chat.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/motion.dart';
import '../../../widgets/animations.dart';
import '../widgets/chat_format.dart';
import '../../../i18n/strings.dart';

enum TransferAction { pay, decline, cancel }

String formatCoinAmount(double amount) => AnimatedCount.group(amount.abs().toStringAsFixed(0));

class TransferCardView extends StatelessWidget {
  final ChatTransfer transfer;
  final int myId;
  final bool isMine;
  final String Function(int userId) nameOf;
  final bool busy;
  final ValueChanged<TransferAction> onAction;

  const TransferCardView({
    super.key,
    required this.transfer,
    required this.myId,
    required this.isMine,
    required this.nameOf,
    this.busy = false,
    required this.onAction,
  });

  String get _direction {
    final t = transfer;
    if (t.isRequest) {
      if (t.toUserId == myId) {
        final payer = nameOf(t.fromUserId);
        return S.requestedFromP0(payer);
      }
      final requester = nameOf(t.toUserId);
      if (t.fromUserId == myId) return S.p0RequestedPaymentFrom(requester);
      final payer = nameOf(t.fromUserId);
      return S.p0RequestedPaymentFromP1(requester, payer);
    }
    if (t.fromUserId == myId) {
      final receiver = nameOf(t.toUserId);
      return S.sentP0(receiver);
    }
    final sender = nameOf(t.fromUserId);
    if (t.toUserId == myId) return S.p0SentCoins(sender);
    final receiver = nameOf(t.toUserId);
    return S.p0SentCoinsP1(sender, receiver);
  }

  (String, IconData, Color) _status(AppColors c) {
    switch (transfer.effectiveStatus) {
      case 'completed':
        return (S.orderCompleted, Icons.check_circle_rounded, c.success);
      case 'pending':
        return (S.orderPendingPayment, Icons.schedule_rounded, c.warning);
      case 'declined':
        return (S.declined2, Icons.block_rounded, c.danger);
      case 'cancelled':
        return (S.orderCancelled, Icons.cancel_outlined, c.neutral);
      default:
        return (S.expired2, Icons.hourglass_disabled_rounded, c.neutral);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = transfer;
    final status = t.effectiveStatus;
    final inactive = status == 'declined' || status == 'cancelled' || status == 'expired';
    final (statusLabel, statusIcon, statusTint) = _status(c);
    final base = inactive ? c.neutral : chatMineBubble(c);
    final bandTop = Color.lerp(base, Colors.white, c.isDark ? 0.0 : 0.08)!;
    final bandBottom = Color.lerp(base, Colors.black, c.isDark ? 0.25 : 0.12)!;
    final note = t.note?.trim() ?? '';
    final expires = t.expiresAt;

    final actions = <Widget>[];
    if (t.isRequest && t.isPending) {
      if (t.fromUserId == myId) {
        actions.add(_ActionButton(label: S.decline2, primary: false, onTap: () => onAction(TransferAction.decline)));
        actions.add(_ActionButton(label: S.payNow, primary: true, onTap: () => onAction(TransferAction.pay)));
      } else if (t.toUserId == myId) {
        actions.add(_ActionButton(label: S.cancelRequest, primary: false, onTap: () => onAction(TransferAction.cancel)));
      }
    }

    const big = Radius.circular(18);
    const small = Radius.circular(6);
    final radius = BorderRadius.only(
      topLeft: big,
      topRight: big,
      bottomLeft: isMine ? big : small,
      bottomRight: isMine ? small : big,
    );

    return AnimatedContainer(
      duration: Motion.base,
      curve: Motion.standard,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: radius,
        border: Border.all(color: c.border),
        boxShadow: c.isDark
            ? null
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedContainer(
            duration: Motion.base,
            curve: Motion.standard,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [bandTop, bandBottom],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                      child: Icon(
                        t.isRequest ? Icons.request_quote_outlined : Icons.currency_exchange_rounded,
                        size: 15,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        t.isRequest ? S.request : S.transfer,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        formatCoinAmount(t.amount),
                        style: TextStyle(
                          fontSize: 30,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                          decoration: inactive ? TextDecoration.lineThrough : null,
                          decorationColor: Colors.white70,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        S.faqCatWallet,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.85)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _direction,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: c.textPrimary, height: 1.35),
                ),
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    note,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: c.textSecondary, height: 1.45),
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    AnimatedSwitcher(
                      duration: Motion.base,
                      child: Container(
                        key: ValueKey(statusLabel),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusTint.withValues(alpha: c.isDark ? 0.2 : 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, size: 13, color: statusTint),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                statusLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: statusTint),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (t.isPending && expires != null)
                      Text(
                        S.dueP0(chatDeadline(expires)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: c.textHint),
                      ),
                  ],
                ),
                if (t.transferNo.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    t.transferNo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10.5, color: c.textHint, letterSpacing: 0.3),
                  ),
                ],
                AnimatedSize(
                  duration: Motion.base,
                  curve: Motion.standard,
                  child: actions.isEmpty
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: busy
                              ? SizedBox(
                                  height: 40,
                                  child: Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2.2, color: c.accent),
                                    ),
                                  ),
                                )
                              : Row(
                                  children: [
                                    for (var i = 0; i < actions.length; i++) ...[
                                      if (i > 0) const SizedBox(width: 8),
                                      Expanded(child: actions[i]),
                                    ],
                                  ],
                                ),
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

class _ActionButton extends StatelessWidget {
  final String label;
  final bool primary;
  final VoidCallback onTap;

  const _ActionButton({required this.label, required this.primary, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return SizedBox(
      height: 40,
      child: TextButton(
        onPressed: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        style: TextButton.styleFrom(
          backgroundColor: primary ? chatMineBubble(c) : c.inputFill,
          foregroundColor: primary ? Colors.white : c.textPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
