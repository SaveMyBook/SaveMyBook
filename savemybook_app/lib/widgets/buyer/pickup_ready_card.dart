import 'package:flutter/material.dart';
import '../../i18n/strings.dart';
import '../../models/order.dart';
import '../../utils/app_colors.dart';
import '../state_views.dart';

class PickupReadyCard extends StatelessWidget {
  final Order order;

  const PickupReadyCard({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final book = order.firstBook;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          BookThumbnail(imageUrl: book != null && book.hasImage ? book.imageUrl : null, width: 60, height: 80, radius: 10),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  book?.title ?? order.orderNo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.textPrimary, height: 1.3),
                ),
                if (order.cabinetName.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _line(c, Icons.storage_rounded, order.cabinetName),
                ],
                if (order.slotNumber.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _line(c, Icons.grid_view_rounded, S.slot2(order.slotNumber)),
                ],
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: c.iconInactive),
        ],
      ),
    );
  }

  Widget _line(AppColors c, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: c.iconInactive),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, color: c.textSecondary),
          ),
        ),
      ],
    );
  }
}
