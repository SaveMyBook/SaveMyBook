import 'package:flutter/material.dart';
import '../models/order.dart';
import '../utils/app_colors.dart';
import '../widgets/animations.dart';
import '../i18n/strings.dart';

class PickupSuccessScreen extends StatelessWidget {
  final Order? order;
  const PickupSuccessScreen({super.key, this.order});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final book = order?.firstBook;

    return Scaffold(
      backgroundColor: c.scaffold,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DrawnCheck(color: c.accent, size: 108),
              const SizedBox(height: 28),
              FadeSlideIn(
                index: 3,
                child: Text(
                S.bookCollected,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: c.textPrimary),
                ),
              ),
              const SizedBox(height: 12),
              FadeSlideIn(
                index: 4,
                child: Text(
                  book == null ? S.thanksUsingSavemybookHappyReading : S.collected(book.title),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: c.textSecondary, height: 1.5),
                ),
              ),
              if (order != null) ...[
                const SizedBox(height: 8),
                Text(
                  S.order2(order!.orderNo),
                  style: TextStyle(fontSize: 12, color: c.textHint),
                ),
              ],
              const SizedBox(height: 40),
              FadeSlideIn(
                index: 6,
                child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(S.actionBack, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
