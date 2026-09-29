import 'package:flutter/material.dart';
import '../../../models/book.dart';
import '../../../models/order.dart';
import '../../../utils/app_colors.dart';
import '../../../widgets/responsive.dart';
import '../../../widgets/state_views.dart';
import '../../../i18n/strings.dart';
import '../../cabinet/cabinet_messages.dart';

class OrderCard extends StatelessWidget {
  final Order order;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool showPickupWindow;
  final bool asSeller;
  final VoidCallback? onTap;

  const OrderCard({
    super.key,
    required this.order,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
    this.showPickupWindow = false,
    this.asSeller = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final book = order.firstBook;
    return SaleCardFrame(
      imageUrl: book != null && book.hasImage ? book.imageUrl : null,
      title: book?.title ?? order.orderNo,
      price: order.totalAmount,
      status: order.statusLabel(asSeller: asSeller),
      address: order.cabinetAddress,
      openHours: showPickupWindow ? order.cabinetOpenHours : '',
      placement: CabinetMessages.orderPlacement(order),
      depositNote: order.hasPendingManualReport ? S.manualReportAwaitingConfirmation : null,
      actionLabel: actionLabel,
      onAction: onAction,
      secondaryLabel: secondaryLabel,
      onSecondary: onSecondary,
      onTap: onTap,
    );
  }
}

class ListingCard extends StatelessWidget {
  final Book book;
  final String? status;
  final Color? statusColor;
  final String? depositNote;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final VoidCallback? onTap;

  const ListingCard({
    super.key,
    required this.book,
    this.status,
    this.statusColor,
    this.depositNote,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SaleCardFrame(
      imageUrl: book.hasImage ? book.imageUrl : null,
      title: book.title,
      price: book.price,
      status: status ?? book.sellerStatusText,
      statusColor: statusColor,
      address: book.cabinetAddress,
      openHours: book.cabinetOpenHours,
      placement: '',
      depositNote: depositNote,
      actionLabel: actionLabel,
      onAction: onAction,
      secondaryLabel: secondaryLabel,
      onSecondary: onSecondary,
      onTap: onTap,
    );
  }
}

class SaleCardFrame extends StatelessWidget {
  final String? imageUrl;
  final String title;
  final double price;
  final String status;
  final Color? statusColor;
  final String address;
  final String openHours;
  final String placement;
  final String? depositNote;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final VoidCallback? onTap;

  const SaleCardFrame({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.price,
    required this.status,
    this.statusColor,
    required this.address,
    required this.openHours,
    required this.placement,
    this.depositNote,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    Widget infoRow(IconData icon, String text, {int maxLines = 1}) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icon, size: 13, color: c.iconInactive),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                text,
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, height: 1.35, color: c.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    final buttonText = Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 13, fontWeight: FontWeight.w600);
    final priceStyle = DefaultTextStyle.of(context).style.merge(TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.accent));

    return AppCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: AspectRatio(aspectRatio: 1, child: AppNetworkImage(url: imageUrl, fallbackIconSize: 32)),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 96),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text('\$${price.toStringAsFixed(0)}', style: priceStyle),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          status,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          strutStyle: StrutStyle.fromTextStyle(priceStyle, forceStrutHeight: true),
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: statusColor ?? c.textHint),
                        ),
                      ),
                    ],
                  ),
                  if (address.isNotEmpty) infoRow(Icons.location_on_outlined, address, maxLines: 2),
                  if (openHours.isNotEmpty) infoRow(Icons.schedule_rounded, openHours),
                  if (placement.isNotEmpty) infoRow(Icons.grid_view_rounded, placement),
                  if (depositNote != null) infoRow(Icons.inventory_2_outlined, depositNote!),
                  const Spacer(),
                  if (actionLabel != null) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: onAction,
                        style: FilledButton.styleFrom(
                          backgroundColor: c.accent,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 34),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          textStyle: buttonText,
                        ),
                        child: Text(actionLabel!, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  if (secondaryLabel != null) ...[
                    SizedBox(height: actionLabel != null ? 6 : 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: onSecondary,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: c.accent,
                          side: BorderSide(color: c.accent.withValues(alpha: 0.5)),
                          minimumSize: const Size(0, 34),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          textStyle: buttonText,
                        ),
                        child: Text(secondaryLabel!, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SaleCardGrid extends StatelessWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final EdgeInsets padding;

  const SaleCardGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.padding = const EdgeInsets.all(16),
  });

  static const double _spacing = 12;
  static const double _minTileWidth = 210;

  static int columnsFor(double width) => ((width + _spacing) / (_minTileWidth + _spacing)).floor().clamp(2, 6);

  static Widget row(BuildContext context, int row, int itemCount, IndexedWidgetBuilder itemBuilder, {int columns = 2}) {
    final first = row * columns;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < columns; i++) ...[
            if (i > 0) const SizedBox(width: _spacing),
            Expanded(child: first + i < itemCount ? itemBuilder(context, first + i) : const SizedBox.shrink()),
          ],
        ],
      ),
    );
  }

  static Widget sliver({required int itemCount, required IndexedWidgetBuilder itemBuilder}) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final columns = columnsFor(constraints.crossAxisExtent);
        return SliverList.separated(
          itemCount: (itemCount / columns).ceil(),
          separatorBuilder: (_, _) => const SizedBox(height: _spacing),
          itemBuilder: (context, i) => row(context, i, itemCount, itemBuilder, columns: columns),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = responsiveListPadding(constraints, maxWidth: Breakpoints.pageMaxWidth, horizontal: padding.left);
        final resolved = padding.copyWith(left: side.left, right: side.right);
        final columns = columnsFor(constraints.maxWidth - resolved.horizontal);
        return ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: resolved,
          itemCount: (itemCount / columns).ceil(),
          separatorBuilder: (_, _) => const SizedBox(height: _spacing),
          itemBuilder: (context, i) => row(context, i, itemCount, itemBuilder, columns: columns),
        );
      },
    );
  }
}
