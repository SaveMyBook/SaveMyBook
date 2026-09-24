import 'package:flutter/material.dart';

import '../../../i18n/strings.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/motion.dart';
import '../../../widgets/animations.dart';
import '../../../widgets/app_buttons.dart';

/// 付款成功：結帳與直接購買共用。回傳 true 表示使用者選擇查看訂單。
Future<bool?> showPaymentSuccess(BuildContext context, {required double total, int count = 1, int sellerCount = 1}) {
  final c = AppColors.of(context);
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierColor: c.scrim,
    transitionDuration: Motion.enter,
    transitionBuilder: (_, animation, _, child) => FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween(begin: 0.9, end: 1.0).animate(CurvedAnimation(parent: animation, curve: Motion.emphasized)),
        child: child,
      ),
    ),
    pageBuilder: (ctx, _, _) => Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Material(
          color: c.card,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DrawnCheck(color: c.success, size: 88),
                const SizedBox(height: 18),
                FadeSlideIn(
                  index: 3,
                  child: Text(
                    S.paymentSuccessful,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: c.textPrimary),
                  ),
                ),
                const SizedBox(height: 8),
                FadeSlideIn(
                  index: 4,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: AnimatedCount(
                      value: total,
                      prefix: '-',
                      style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: c.accent),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                FadeSlideIn(
                  index: 5,
                  child: Text(
                    sellerCount > 1 ? S.p0BooksSplitIntoP1Orders(count, sellerCount) : S.orderPlacedSellerDropBookOff,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, height: 1.5, color: c.textSecondary),
                  ),
                ),
                const SizedBox(height: 22),
                PrimaryButton(
                  label: S.viewOrder,
                  icon: Icons.receipt_long_rounded,
                  onPressed: () => Navigator.pop(ctx, true),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: TextButton.styleFrom(foregroundColor: c.textSecondary),
                  child: Text(S.keepBrowsing),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
