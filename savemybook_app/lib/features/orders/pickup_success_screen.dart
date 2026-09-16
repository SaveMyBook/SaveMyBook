import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/order.dart';
import '../../utils/app_colors.dart';
import '../../widgets/animations.dart';
import '../../widgets/responsive.dart';
import '../../widgets/state_views.dart';
import '../../i18n/strings.dart';

class PickupSuccessScreen extends StatefulWidget {
  final Order? order;
  const PickupSuccessScreen({super.key, this.order});

  @override
  State<PickupSuccessScreen> createState() => _PickupSuccessScreenState();
}

class _PickupSuccessScreenState extends State<PickupSuccessScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 420), () {
      if (mounted) HapticFeedback.heavyImpact();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final order = widget.order;
    final book = order?.firstBook;

    return Scaffold(
      backgroundColor: c.scaffold,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: context.isWide ? 440 : double.infinity),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DrawnCheck(color: c.success, size: 108),
                  const SizedBox(height: 28),
                  FadeSlideIn(
                    index: 3,
                    child: Text(
                      S.bookCollected,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: c.textPrimary),
                    ),
                  ),
                  if (book != null) ...[
                    const SizedBox(height: 12),
                    FadeSlideIn(
                      index: 4,
                      child: Text(
                        S.collected(book.title),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 15, color: c.textSecondary, height: 1.5),
                      ),
                    ),
                    const SizedBox(height: 20),
                    FadeSlideIn(
                      index: 5,
                      child: BookThumbnail(imageUrl: book.hasImage ? book.imageUrl : null, width: 84, height: 112, radius: 12),
                    ),
                  ],
                  if (order != null) ...[
                    const SizedBox(height: 12),
                    FadeSlideIn(
                      index: 5,
                      child: Text(
                        S.order2(order.orderNo),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: c.textHint),
                      ),
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
                        child: Text(S.actionBack, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
