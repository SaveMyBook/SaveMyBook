import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/order.dart';
import '../../services/api_service.dart';
import '../../utils/api_helpers.dart';
import '../../utils/app_colors.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_tiles.dart';
import '../../widgets/responsive.dart';
import '../../widgets/state_views.dart';
import '../books/book_detail_screen.dart';
import 'pickup_success_screen.dart';
import 'purchase_history_screen.dart';
import '../../utils/app_labels.dart';
import '../../utils/motion.dart';
import '../../i18n/strings.dart';

class OrderDetailScreen extends StatefulWidget {
  final Order order;

  final bool asSeller;

  const OrderDetailScreen({super.key, required this.order, this.asSeller = false});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  List<({String status, String label})> get _flow => AppLabels.orderFlow;

  final ApiService _api = ApiService();
  late Order _order = widget.order;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final detail = await _api.fetchOrderDetail(widget.order.orderId);
    if (!mounted) return;
    setState(() {
      if (detail != null) _order = detail;
      _isLoading = false;
    });
  }

  int get _flowIndex {
    if (_order.status == 'pending_payment') return 0;
    return _flow.indexWhere((f) => f.status == _order.status);
  }

  bool get _isClosed =>
      _order.status == 'cancelled' || _order.status == 'refunded' || _order.status == 'refunding';

  String? _stepHint(String status) {
    switch (status) {
      case 'pending_deposit':
        return widget.asSeller ? S.pleasePutBookAssignedLockerSoon : S.weLlLetKnowWhenSeller;
      case 'deposited':
      case 'pending_pickup':
        return widget.asSeller ? S.waitingBuyerCollect : S.bookLockerScanQrCodeLocker;
      case 'completed':
        return S.transactionCompleteThank;
    }
    return null;
  }

  Future<void> _copy(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    HapticFeedback.selectionClick();
    showAppSnackBar(context, S.copied(label));
  }

  Future<void> _confirmCollected() async {
    final confirmed = await showConfirmDialog(
      context,
      title: S.iCollected,
      message: S.confirmVeTakenBookFromLocker,
      confirmLabel: S.confirm,
      icon: Icons.inventory_2_outlined,
    );
    if (!confirmed || !mounted) return;

    final error = await runBusy(context, () => _api.updateOrderStatus(_order.orderId, 'completed'));
    if (!mounted) return;
    if (error != null) {
      showAppSnackBar(context, error, isError: true);
      _load();
      return;
    }
    await Navigator.push(context, MaterialPageRoute(builder: (_) => PickupSuccessScreen(order: _order)));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final canCollect = !widget.asSeller && canCollectOrder(_order);

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          AppHeader(title: S.orderDetails, icon: Icons.receipt_long_outlined),
          Expanded(
            child: RefreshIndicator(
              color: c.accent,
              onRefresh: _load,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = context.screenSize == ScreenSize.expanded;
                  final padding = responsiveListPadding(
                    constraints,
                    maxWidth: wide ? 1120 : Breakpoints.readingMaxWidth,
                    horizontal: wide ? 32 : 20,
                    top: 20,
                    bottom: MediaQuery.of(context).padding.bottom + 40,
                  );
                  final collect = Reveal(
                    visible: canCollect,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: PrimaryButton(
                        label: S.iCollected,
                        icon: Icons.check_rounded,
                        onPressed: canCollect ? _confirmCollected : null,
                      ),
                    ),
                  );
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: padding,
                    children: [
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 5,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  FadeSlideIn(child: _buildItemsCard(c)),
                                  const SizedBox(height: 14),
                                  FadeSlideIn(index: 1, child: _buildPickupCard(c)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  FadeSlideIn(index: 2, child: _buildStatusCard(c)),
                                  const SizedBox(height: 14),
                                  FadeSlideIn(index: 3, child: _buildFlowCard(c)),
                                  const SizedBox(height: 14),
                                  FadeSlideIn(index: 4, child: _buildInfoCard(c)),
                                  collect,
                                ],
                              ),
                            ),
                          ],
                        )
                      else ...[
                        FadeSlideIn(child: _buildStatusCard(c)),
                        const SizedBox(height: 14),
                        FadeSlideIn(index: 1, child: _buildFlowCard(c)),
                        const SizedBox(height: 14),
                        FadeSlideIn(index: 2, child: _buildItemsCard(c)),
                        const SizedBox(height: 14),
                        FadeSlideIn(index: 3, child: _buildPickupCard(c)),
                        const SizedBox(height: 14),
                        FadeSlideIn(index: 4, child: _buildInfoCard(c)),
                        collect,
                      ],
                      if (_isLoading) ...[
                        const SizedBox(height: 20),
                        Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: c.iconInactive),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(AppColors c) {
    final color = c.orderStatusColor(_order.status);
    final label = AppLabels.order(_order.status, asBuyer: !widget.asSeller);

    return AppCard(
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _isClosed
                  ? Icons.info_outline_rounded
                  : _order.status == 'completed'
                      ? Icons.task_alt_rounded
                      : Icons.local_shipping_outlined,
              color: color,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchIn(
                  child: Text(
                    label,
                    key: ValueKey(_order.status),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
                  ),
                ),
                const SizedBox(height: 2),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _copy(_order.orderNo, S.orderNumber),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          S.order(_order.orderNo),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: c.textSecondary),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.copy_rounded, size: 12, color: c.iconInactive),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlowCard(AppColors c) {
    final current = _flowIndex;
    final steps = <({String label, bool done, bool active, bool failed, String? hint})>[];

    if (_isClosed) {
      final reached = _order.status == 'cancelled' ? 0 : _flow.length - 1;
      for (var i = 0; i <= reached; i++) {
        steps.add((label: _flow[i].label, done: true, active: false, failed: false, hint: null));
      }
      steps.add((
        label: AppLabels.order(_order.status, asBuyer: !widget.asSeller),
        done: true,
        active: true,
        failed: true,
        hint: null,
      ));
    } else {
      for (var i = 0; i < _flow.length; i++) {
        final active = i == current;
        steps.add((
          label: _flow[i].label,
          done: i <= current,
          active: active,
          failed: false,
          hint: active ? _stepHint(_flow[i].status) : null,
        ));
      }
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(title: S.orderProgress),
          const SizedBox(height: 16),
          for (var i = 0; i < steps.length; i++) _buildStep(c, steps[i], i, isLast: i == steps.length - 1),
        ],
      ),
    );
  }

  Widget _buildStep(
    AppColors c,
    ({String label, bool done, bool active, bool failed, String? hint}) step,
    int index, {
    required bool isLast,
  }) {
    final tint = step.failed ? c.danger : c.accent;
    final dot = AnimatedContainer(
      duration: Duration(milliseconds: 300 + index * 80),
      curve: Motion.enterCurve,
      width: step.active ? 22 : 18,
      height: step.active ? 22 : 18,
      decoration: BoxDecoration(
        color: step.done ? tint : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(color: step.done ? tint : c.divider, width: 2),
        boxShadow: step.active
            ? [BoxShadow(color: tint.withValues(alpha: 0.35), blurRadius: 10, spreadRadius: 1)]
            : null,
      ),
      child: step.done
          ? Icon(step.failed ? Icons.close_rounded : Icons.check_rounded, size: step.active ? 13 : 11, color: Colors.white)
          : null,
    );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                step.active && !step.failed ? Breathe(amount: 0.08, period: const Duration(milliseconds: 1800), child: dot) : dot,
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      constraints: const BoxConstraints(minHeight: 18),
                      color: step.done && !step.active ? c.accent : c.divider,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: step.active ? 2 : 0, bottom: isLast ? 0 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    step.label,
                    style: TextStyle(
                      fontSize: step.active ? 14 : 13,
                      fontWeight: step.active ? FontWeight.bold : FontWeight.normal,
                      color: step.failed ? c.danger : (step.done ? c.textPrimary : c.textHint),
                    ),
                  ),
                  if (step.hint != null) ...[
                    const SizedBox(height: 3),
                    Text(step.hint!, style: TextStyle(fontSize: 12, height: 1.4, color: c.textSecondary)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsCard(AppColors c) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(title: S.items2(_order.items.length)),
          const SizedBox(height: 12),
          if (_order.items.isEmpty)
            Text(S.orderNoItemDetails, style: TextStyle(fontSize: 13, color: c.textHint))
          else
            for (final item in _order.items) ...[
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: item.book.bookId == 0
                    ? null
                    : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BookDetailScreen(book: item.book, heroTag: 'order_item_${item.itemId}'),
                          ),
                        ),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Hero(
                        tag: 'order_item_${item.itemId}',
                        child: BookThumbnail(
                          imageUrl: item.book.hasImage ? item.book.imageUrl : null,
                          width: 52,
                          height: 68,
                          radius: 8,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              item.book.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c.textPrimary, height: 1.3),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              S.msg4(item.unitPrice.toStringAsFixed(0), item.quantity),
                              style: TextStyle(fontSize: 12, color: c.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '\$${item.subtotal.toStringAsFixed(0)}',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c.textPrimary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          Divider(color: c.divider, height: 20),
          Row(
            children: [
              Text(S.orderTotal, style: TextStyle(fontSize: 14, color: c.textSecondary)),
              const SizedBox(width: 12),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    '\$${_order.totalAmount.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: c.accent),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPickupCard(AppColors c) {
    final address = [_order.cabinetName, _order.cabinetAddress].where((s) => s.isNotEmpty).join(' ');

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: SectionHeading(title: S.pickupDetails)),
              if (_order.cabinetAddress.isNotEmpty)
                TextButton.icon(
                  onPressed: () => _copy(address, S.address),
                  style: TextButton.styleFrom(
                    foregroundColor: c.accent,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  icon: const Icon(Icons.copy_rounded, size: 14),
                  label: Text(S.copyAddress, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          InfoLine(
            icon: Icons.storage_rounded,
            label: S.faqCatCabinet,
            value: _order.cabinetName.isEmpty ? S.notAssigned : _order.cabinetName,
            fontSize: 13,
          ),
          const SizedBox(height: 6),
          InfoLine(
            icon: Icons.location_on_outlined,
            label: S.address,
            value: _order.cabinetAddress.isEmpty ? S.notAssigned : _order.cabinetAddress,
            fontSize: 13,
          ),
          const SizedBox(height: 6),
          InfoLine(
            icon: Icons.schedule_rounded,
            label: S.openingHours,
            value: _order.cabinetOpenHours.isEmpty ? S.notProvided : _order.cabinetOpenHours,
            fontSize: 13,
          ),
          const SizedBox(height: 6),
          InfoLine(
            icon: Icons.grid_view_rounded,
            label: S.slot,
            value: _order.slotNumber.isEmpty ? S.notAssignedYet : _order.slotNumber,
            fontSize: 13,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(AppColors c) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(title: S.transaction),
          const SizedBox(height: 12),
          InfoLine(
            icon: widget.asSeller ? Icons.person_outline_rounded : Icons.storefront_outlined,
            label: widget.asSeller ? S.buyer : S.seller,
            value: widget.asSeller
                ? (_order.buyerName.isEmpty ? '—' : _order.buyerName)
                : (_order.sellerName.isEmpty ? '—' : _order.sellerName),
            fontSize: 13,
          ),
          const SizedBox(height: 6),
          InfoLine(
            icon: Icons.event_outlined,
            label: S.placed,
            value: formatDateTime(_order.createdAt?.toLocal()),
            fontSize: 13,
          ),
          Reveal(
            visible: _order.hasOpenDispute,
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: InfoLine(
                icon: Icons.gavel_rounded,
                label: S.dispute2,
                value: S.orderOpenDispute,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
