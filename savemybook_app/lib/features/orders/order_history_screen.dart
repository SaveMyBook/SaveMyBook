import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../i18n/strings.dart';
import '../../models/order.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/app_header.dart';
import '../../widgets/master_detail.dart';
import '../../widgets/responsive.dart';
import '../../widgets/state_views.dart';
import '../../widgets/app_side_nav.dart';
import '../cabinet/cabinet_entry.dart';
import '../home/home_screen.dart';
import '../selling/book_deposit_actions.dart';
import 'dispute_screen.dart';
import 'order_detail_screen.dart';
import 'widgets/order_record_card.dart';
import 'widgets/tablet_controls.dart';

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

  static final ValueNotifier<({OrderRole role, String? filter})?> _requested = ValueNotifier(null);

  static Future<void> open(BuildContext context, {OrderRole role = OrderRole.buyer, String? filter}) async {
    if (HomeScreen.showTab(AppSideNav.ordersTab)) {
      _requested.value = (role: role, filter: filter);
      return;
    }
    await Navigator.push(context, MaterialPageRoute(builder: (_) => OrderHistoryScreen(role: role, filter: filter)));
  }

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
    // 平板由其他頁面切換過來時分頁可能尚未建立，要求的篩選在此套用
    final request = OrderHistoryScreen._requested.value;
    if (request != null) OrderHistoryScreen._requested.value = null;
    final initialRole = request?.role ?? widget.role;
    final initialFilter = request != null ? request.filter : widget.filter;
    _filters = {
      for (final role in OrderRole.values)
        role: role == initialRole && OrderHistoryScreen.filtersOf(role).contains(initialFilter)
            ? initialFilter!
            : OrderHistoryScreen.filtersOf(role).first,
    };
    _tabController = TabController(length: OrderRole.values.length, vsync: this, initialIndex: initialRole.index);
    _tabController.addListener(_onTabChanged);
    OrderHistoryScreen._requested.addListener(_onRequested);
    _load();
    _loadCounts();
  }

  @override
  void dispose() {
    OrderHistoryScreen._requested.removeListener(_onRequested);
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

  void _onRequested() {
    final request = OrderHistoryScreen._requested.value;
    if (request == null) return;
    OrderHistoryScreen._requested.value = null;
    final filter = request.filter;
    if (filter != null && OrderHistoryScreen.filtersOf(request.role).contains(filter)) _filters[request.role] = filter;
    if (_tabController.index != request.role.index) {
      _tabController.index = request.role.index;
    } else {
      setState(() {});
      _load();
    }
    _loadCounts();
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

  Future<void> _openDetail(BuildContext context, Order order) async {
    await MasterDetail.open(
      context,
      OrderDetailScreen(order: order, asSeller: _role == OrderRole.seller),
      id: order.orderId,
    );
    await _afterChange();
  }

  Future<void> _openDispute(BuildContext context, Order order) async {
    await MasterDetail.open(context, DisputeScreen(orderNo: order.orderNo), id: 'dispute_${order.orderId}');
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

  Widget _buildCard(BuildContext context, Order order) {
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
        onSecondary = () => _openDispute(context, order);
      }
    }
    if (order.isCancellable) {
      secondary = S.cancelOrder;
      onSecondary = () => _cancelOrder(order);
    }

    if (context.isWide) {
      return OrderRecordRow(
        order: order,
        asSeller: asSeller,
        selected: MasterDetail.selectedId(context) == order.orderId,
        onTap: () => _openDetail(context, order),
        onMenu: () => showItemMenu(
          context,
          title: S.order(order.orderNo),
          actions: [
            MenuAction(S.viewOrder, Icons.receipt_long_outlined, () => _openDetail(context, order)),
            if (action != null && onAction != null)
              MenuAction(action, action == S.completeOrder ? Icons.task_alt_rounded : Icons.qr_code_scanner_rounded, onAction),
            if (secondary != null && onSecondary != null)
              secondary == S.cancelOrder
                  ? MenuAction(secondary, Icons.cancel_outlined, onSecondary, destructive: true)
                  : MenuAction(secondary, Icons.report_gmailerrorred_rounded, onSecondary),
          ],
        ),
        actionLabel: action,
        onAction: onAction,
        secondaryLabel: secondary,
        onSecondary: onSecondary,
      );
    }

    return OrderRecordCard(
      order: order,
      asSeller: asSeller,
      selected: MasterDetail.selectedId(context) == order.orderId,
      onTap: () => _openDetail(context, order),
      actionLabel: action,
      onAction: onAction,
      secondaryLabel: secondary,
      onSecondary: onSecondary,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    // 右側提示畫面需要 Material 祖先提供文字樣式
    return Material(
      color: c.scaffold,
      child: MasterDetail(
        masterWidth: 400,
        placeholderIcon: Icons.receipt_long_outlined,
        master: _buildMaster(c),
      ),
    );
  }

  Widget _buildMaster(AppColors c) {
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
                context.isWide ? _buildTabletFilterBar(c) : _buildFilterBar(c),
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
    if (context.isWide) return _buildTabletList(orders);
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
                          child: _buildCard(context, orders[row * columns + col]),
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

  Widget _buildTabletList(List<Order> orders) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = MasterDetail.isSplit(context)
            ? EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.paddingOf(context).bottom + 24)
            : responsiveListPadding(
                constraints,
                maxWidth: Breakpoints.listMaxWidth,
                horizontal: 24,
                top: 16,
                bottom: MediaQuery.paddingOf(context).bottom + 24,
              );
        return ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: padding,
          itemCount: orders.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) => RevealOnScroll(
            key: ValueKey('order_${orders[i].orderId}'),
            index: i,
            child: _buildCard(context, orders[i]),
          ),
        );
      },
    );
  }

  Widget _buildTabletFilterBar(AppColors c) {
    final role = _role;
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = MasterDetail.isSplit(context)
            ? 16.0
            : responsiveListPadding(constraints, maxWidth: Breakpoints.listMaxWidth, horizontal: 24).left;
        return Padding(
          padding: EdgeInsets.fromLTRB(side, 6, side, 12),
          child: SegmentedFilter<String>(
            key: ValueKey('order_filters_${role.name}'),
            value: _filter,
            onChanged: _selectFilter,
            options: [
              for (final filter in OrderHistoryScreen.filtersOf(role))
                SegmentOption(filter, OrderHistoryScreen.filterLabel(role, filter)),
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
