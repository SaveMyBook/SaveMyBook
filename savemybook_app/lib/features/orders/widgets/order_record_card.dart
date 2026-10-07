import 'package:flutter/material.dart';
import '../../../i18n/strings.dart';
import '../../../models/order.dart';
import '../../../utils/app_colors.dart';
import '../../../widgets/app_tiles.dart';
import '../../../widgets/state_views.dart';
import '../../cabinet/cabinet_messages.dart';

class OrderRecordCard extends StatelessWidget {
  final Order order;
  final bool asSeller;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final VoidCallback? onTap;
  final bool selected;

  const OrderRecordCard({
    super.key,
    required this.order,
    this.asSeller = false,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
    this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final counterpart = asSeller ? order.buyerName : order.sellerName;
    final items = order.items.take(Order.maxBooks).toList();
    final cabinet = [
      order.cabinetName.isNotEmpty ? order.cabinetName : order.cabinetAddress,
      CabinetMessages.orderPlacement(order),
    ].where((s) => s.isNotEmpty).join('・');
    final hint = TextStyle(fontSize: 12, color: c.textSecondary);

    final card = AppCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, box) => Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: asSeller ? S.buyer : S.seller, style: TextStyle(color: c.textSecondary)),
                        const TextSpan(text: '  '),
                        TextSpan(text: counterpart.isEmpty ? '—' : counterpart),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary),
                  ),
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: box.maxWidth * 0.45),
                  child: StatusBadge(
                    label: order.statusLabel(asSeller: asSeller),
                    color: c.orderStatusColor(order.status),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(S.order(order.orderNo), maxLines: 1, overflow: TextOverflow.ellipsis, style: hint),
          const SizedBox(height: 10),
          for (final (i, item) in items.indexed) ...[
            if (i > 0) const SizedBox(height: 8),
            Row(
              children: [
                BookThumbnail(imageUrl: item.book.hasImage ? item.book.imageUrl : null, width: 44, height: 58, radius: 6),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.book.title.isEmpty ? S.untitled : item.book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, height: 1.35, fontWeight: FontWeight.w600, color: c.textPrimary),
                  ),
                ),
              ],
            ),
          ],
          if (order.items.length > items.length)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(S.p0ItemsTotal(order.items.length), style: TextStyle(fontSize: 11, color: c.textHint)),
            ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.location_on_outlined, size: 14, color: c.iconInactive),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  cabinet.isEmpty ? S.notAssigned : cabinet,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: hint,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '\$${order.totalAmount.toStringAsFixed(0)}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.accent),
              ),
            ],
          ),
          if (order.hasPendingManualReport)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Icon(Icons.inventory_2_outlined, size: 14, color: c.iconInactive),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(S.manualReportAwaitingConfirmation, maxLines: 2, overflow: TextOverflow.ellipsis, style: hint),
                  ),
                ],
              ),
            ),
          if (actionLabel != null || secondaryLabel != null) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (secondaryLabel != null) Flexible(child: _button(context, secondaryLabel!, onSecondary, filled: false)),
                if (secondaryLabel != null && actionLabel != null) const SizedBox(width: 8),
                if (actionLabel != null) Flexible(child: _button(context, actionLabel!, onAction, filled: true)),
              ],
            ),
          ],
        ],
      ),
    );
    if (!selected) return card;
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.accent, width: 2),
      ),
      child: card,
    );
  }

  Widget _button(BuildContext context, String label, VoidCallback? onPressed, {required bool filled}) {
    final c = AppColors.of(context);
    final textStyle = Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 13, fontWeight: FontWeight.w600);
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));
    const padding = EdgeInsets.symmetric(horizontal: 14, vertical: 6);
    final child = Text(label, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis);
    if (filled) {
      return FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: Colors.white,
          minimumSize: const Size(88, 36),
          padding: padding,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: shape,
          textStyle: textStyle,
        ),
        child: child,
      );
    }
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: c.accent,
        side: BorderSide(color: c.accent.withValues(alpha: 0.5)),
        minimumSize: const Size(88, 36),
        padding: padding,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: shape,
        textStyle: textStyle,
      ),
      child: child,
    );
  }
}
