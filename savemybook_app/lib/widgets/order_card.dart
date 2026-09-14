import 'package:flutter/material.dart';
import '../models/order.dart';
import '../utils/app_colors.dart';
import 'state_views.dart';
import '../i18n/strings.dart';

class OrderCard extends StatelessWidget {
  final Order order;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool showPickupWindow;
  final VoidCallback? onShowQr;
  final VoidCallback? onTap;

  const OrderCard({
    super.key,
    required this.order,
    this.actionLabel,
    this.onAction,
    this.showPickupWindow = false,
    this.onShowQr,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final book = order.firstBook;

    return AppCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: SizedBox(
              width: double.infinity,
              child: AppNetworkImage(
                url: book != null && book.hasImage ? book.imageUrl : null,
                fallbackIconSize: 32,
              ),
            ),
            ),
          ),
          Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Text(
                  book?.title ?? order.orderNo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '\$${order.totalAmount.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: c.accent,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        order.statusText,
                        textAlign: TextAlign.end,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: c.textHint),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (order.cabinetAddress.isNotEmpty)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.location_on_outlined, size: 12, color: c.iconInactive),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          order.cabinetAddress,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 10, color: c.textSecondary, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                if (showPickupWindow && order.cabinetOpenHours.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded, size: 12, color: c.iconInactive),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          order.cabinetOpenHours,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 10, color: c.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ],
                if (showPickupWindow && onShowQr != null) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onShowQr,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: c.accent.withValues(alpha: c.isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.qr_code_2_rounded, size: 16, color: c.accent),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              S.pickupCode,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: c.accent),
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, size: 16, color: c.accent),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        order.slotNumber.isEmpty ? '' : S.slot2(order.slotNumber),
                        style: TextStyle(fontSize: 10, color: c.textHint),
                      ),
                    ),
                    if (actionLabel != null)
                      Flexible(
                        child: GestureDetector(
                        onTap: onAction,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: c.categoryChip,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            actionLabel!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: c.accent,
                            ),
                          ),
                        ),
                      ),
                      ),
                  ],
                ),
                ],
              ),
          ),
        ],
      ),
    );
  }
}
