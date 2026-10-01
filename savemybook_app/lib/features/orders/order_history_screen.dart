import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../i18n/strings.dart';
import '../../models/order.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/app_header.dart';
import '../../widgets/responsive.dart';
import '../../widgets/state_views.dart';
import '../cabinet/cabinet_entry.dart';
import '../selling/book_deposit_actions.dart';
import 'dispute_screen.dart';
import 'order_detail_screen.dart';
import 'widgets/order_record_card.dart';

enum OrderRole { buyer, seller }

class OrderHistoryScreen extends StatefulWidget {
  final OrderRole role;
  final String? filter;

  const OrderHistoryScreen({super.key, this.role = OrderRole.buyer, this.filter});

  static const awaitingPickup = 'awaiting_pickup';
  static const awaitingDeposit = 'awaiting_deposit';
  static const disputing = 'disputing';
  static const finished = 'finished';
  static const cancelled = 'cancelled';

  static List<String> filtersOf(OrderRole role) => role == OrderRole.buyer
      ? const [awaitingPickup, awaitingDeposit, disputing, finished, cancelled]
      : const [awaitingDeposit, awaitingPickup, disputing, finished, cancelled];

  static String actionFilterOf(OrderRole role) => role == OrderRole.buyer ? awaitingPickup : awaitingDeposit;

  static String purchaseFilterAfterPayment(bool readyForPickup) => readyForPickup ? awaitingPickup : awaitingDeposit;

  static String filterLabel(OrderRole role, String filter) => switch (filter) {
    awaitingPickup => role == OrderRole.buyer ? S.orderBuyerDeposited : S.orderSellerAwaitingPickup,
    awaitingDeposit => role == OrderRole.buyer ? S.orderBuyerPendingDeposit : S.orderPendingDeposit,
    disputing => S.orderRefunding,
    finished => S.orderCompleted,
    _ => S.orderCancelled,
  };

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late final TabController _tabController;
  late final Map<OrderRole, String> _filters;
  final Map<String, List<Order>> _cache = {};
  final Map<String, int> _requests = {};
  final Map<OrderRole, int> _counts = {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _filters = {
      for (final role in OrderRole.values)
        role: role == widget.role && OrderHistoryScreen.filtersOf(role).contains(widget.filter)
            ? widget.filter!
            : OrderHistoryScreen.filtersOf(role).first,
    };
    _tabController = TabController(length: OrderRole.values.length, vsync: this, initialIndex: widget.role.index);
    _tabController.addListener(_onTabChanged);
    _load();
    _loadCounts();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  OrderRole get _role => OrderRole.values[_tabController.index];

  String get _filter => _filters[_role]!;

  String _keyOf(OrderRole role, String filter) => '${role.name}/$filter';

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    setState(() {});
    _load();
  }

  void _selectFilter(String filter) {
    if (_filter == filter) return;
    HapticFeedback.selectionClick();
    setState(() => _filters[_role] = filter);
    _load();
  }

  Future<void> _load() async {
    final role = _role;
    final filter = _filter;
    final key = _keyOf(role, filter);
    final request = (_requests[key] ?? 0) + 1;
    _requests[key] = request;
    final orders = await _api.fetchOrders(role: role.name, tab: filter);
    if (!mounted || _requests[key] != request) return;
    setState(() => _cache[key] = orders);
  }

  Future<void> _loadCounts() async {
    final counts = await Future.wait([
      for (final role in OrderRole.values)
        _api.fetchOrderCount(role: role.name, tab: OrderHistoryScreen.actionFilterOf(role)),
    ]);
    if (!mounted) return;
    setState(() {
      for (final role in OrderRole.values) {
        _counts[role] = counts[role.index];
      }
    });
  }

  Future<void> _refresh() => Future.wait([_load(), _loadCounts()]);

  Future<void> _afterChange() async {
    if (mounted) await _refresh();
  }

  Future<void> _openDetail(Order order) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => OrderDetailScreen(order: order, asSeller: _role == OrderRole.seller)),
    );
    await _afterChange();
  }

  Future<void> _openDispute(Order order) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => DisputeScreen(orderNo: order.orderNo)));
    await _afterChange();
  }

  Future<void> _runCabinet(Order order, Future<bool> Function(BuildContext context, Order order) action) async {
    if (_busy) return;
    _busy = true;
    final changed = await action(context, order);
    _busy = false;
    if (changed) await _afterChange();
  }

  Future<void> _completeOrder(Order order) async {
    final confirmed = await showConfirmDialog(
      context,
      title: S.completeOrder,
      message: S.onceCompleteOrderPaymentReleasedSeller,
      confirmLabel: S.completeOrder,
      cancelLabel: S.actionBack,
      icon: Icons.task_alt_rounded,
    );
    if (!confirmed || !mounted) return;
    final error = await runBusy(context, () => _api.updateOrderStatus(order.orderId, 'completed'));
    if (!mounted) return;
    if (error != null) {
      showAppSnackBar(context, error, isError: true);
    } else {
      HapticFeedback.mediumImpact();
      showAppSnackBar(context, S.orderCompleted2);
    }
    await _afterChange();
  }

  Future<void> _cancelOrder(Order order) async {
    if (_busy) return;
    final asSeller = _role == OrderRole.seller;
    final confirmed = await showConfirmDialog(
      context,
      title: S.cancelOrder,
      message: asSeller ? S.buyerNotifiedBookReturnsShop : S.cancelOrderBookReturnsShop(order.orderNo),
      confirmLabel: S.cancelOrder,
      cancelLabel: S.actionBack,
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    _busy = true;
    final error = await runBusy(
      context,
      () => _api.cancelOrder(order.orderId, reason: asSeller ? S.cancelledBySeller : null),
    );
    _busy = false;
    if (!mounted) return;
    if (error != null) {
      showAppSnackBar(context, error, isError: true);
    } else {
      HapticFeedback.mediumImpact();
      showAppSnackBar(context, S.orderCancelled2);
    }
    await _afterChange();
  }

  Widget _buildCard(Order order) {
    final asSeller = _role == OrderRole.seller;
    final reportPending = order.hasPendingManualReport;
    String? action;
    VoidCallback? onAction;
    String? secondary;
    VoidCallback? onSecondary;

    if (asSeller) {
      if (order.status == 'pending_payment' || order.status == 'pending_deposit') {
        action = cabinetActionLabel(order.cabinetAccess, CabinetAction.orderDeposit);
        onAction = reportPending ? null : () => _runCabinet(order, confirmOrderDeposit);
      }
    } else if (order.canCollect) {
      action = cabinetActionLabel(order.cabinetAccess, CabinetAction.pickup);
      onAction = reportPending ? null : () => _runCabinet(order, confirmOrderPickup);
    } else if (order.awaitingConfirmation) {
      action = S.completeOrder;
      onAction = () => _completeOrder(order);
      if (order.canOpenDispute()) {
        secondary = S.openDispute;
        onSecondary = () => _openDispute(order);
      }
    }
    if (order.isCancellable) {
      secondary = S.cancelOrder;
      onSecondary = () => _cancelOrder(order);
    }

    return OrderRecordCard(
      order: order,
      asSeller: asSeller,
      onTap: () => _openDetail(order),
      actionLabel: action,
      onAction: onAction,
      secondaryLabel: secondary,
      onSecondary: onSecondary,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final role = _role;
    final filter = _filter;
    final key = _keyOf(role, filter);
    final orders = _cache[key];

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          AppHeader(
            title: S.orderHistory,
            icon: Icons.receipt_long_outlined,
            bottom: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTabBar(
                  controller: _tabController,
                  tabs: [S.purchaseOrders, S.salesOrders],
                  badges: [for (final r in OrderRole.values) _counts[r] ?? 0],
                ),
                _buildFilterBar(c),
              ],
            ),
          ),
          Expanded(
            child: SwipeTabs(
              controller: _tabController,
              child: SwitchIn(
                child: orders == null
                    ? LoadingView.list(key: ValueKey('loading_$key'))
                    : orders.isEmpty
                    ? RefreshableCenter(
                        key: ValueKey('empty_$key'),
                        onRefresh: _refresh,
                        child: EmptyView(icon: Icons.receipt_long_outlined, message: S.noOrdersTab),
                      )
                    : RefreshIndicator(
                        key: ValueKey('list_$key'),
                        color: c.accent,
                        onRefresh: _refresh,
                        child: _buildList(orders),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<Order> orders) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = responsiveListPadding(
          constraints,
          maxWidth: Breakpoints.pageMaxWidth,
          top: 14,
          bottom: MediaQuery.of(context).padding.bottom + 24,
        );
        final columns = context.isWide ? ((constraints.maxWidth - padding.horizontal + 12) / 372).floor().clamp(1, 3) : 1;
        final rows = (orders.length / columns).ceil();
        return ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: padding,
          itemCount: rows,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (_, row) => Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var col = 0; col < columns; col++) ...[
                if (col > 0) const SizedBox(width: 12),
                Expanded(
                  child: row * columns + col < orders.length
                      ? RevealOnScroll(
                          key: ValueKey('order_${orders[row * columns + col].orderId}'),
                          index: row * columns + col,
                          child: _buildCard(orders[row * columns + col]),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterBar(AppColors c) {
    final role = _role;
    return Container(
      width: double.infinity,
      color: c.card,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final side = responsiveListPadding(constraints, maxWidth: Breakpoints.pageMaxWidth).left;
          return SingleChildScrollView(
            key: ValueKey('order_filters_${role.name}'),
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: side),
            child: Row(
              children: [
                for (final (i, filter) in OrderHistoryScreen.filtersOf(role).indexed) ...[
                  if (i > 0) const SizedBox(width: 8),
                  _FilterChip(
                    label: OrderHistoryScreen.filterLabel(role, filter),
                    selected: filter == _filter,
                    onTap: () => _selectFilter(filter),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Semantics(
      button: true,
      selected: selected,
      child: PressableScale(
        scale: 0.95,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? c.accent : c.categoryChip,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              color: selected ? Colors.white : c.accent,
            ),
          ),
        ),
      ),
    );
  }
}
