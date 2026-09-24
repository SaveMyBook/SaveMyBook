import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/chat.dart';
import '../../models/order.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/app_header.dart';
import 'widgets/order_card.dart';
import '../../widgets/state_views.dart';
import 'order_detail_screen.dart';
import 'dispute_screen.dart';
import 'pickup_success_screen.dart';
import '../../i18n/strings.dart';
import '../books/book_detail_screen.dart';

bool canCollectOrder(Order order) => order.canCollect;

class PurchaseHistoryScreen extends StatefulWidget {
  const PurchaseHistoryScreen({super.key});

  @override
  State<PurchaseHistoryScreen> createState() => _PurchaseHistoryScreenState();
}

class _PurchaseHistoryScreenState extends State<PurchaseHistoryScreen> with SingleTickerProviderStateMixin {
  static const _reservedTab = 'reserved';

  List<({String key, String label})> get _tabs => [
    (key: _reservedTab, label: S.bookReserved),
    (key: 'pending_pickup', label: S.orderBuyerDeposited),
    (key: 'completed', label: S.orderCompleted),
    (key: 'cancelled', label: S.orderCancelled),
    (key: 'disputing', label: S.orderBuyerRefunding),
  ];

  final ApiService _api = ApiService();
  late final TabController _tabController;

  final Map<String, List<Object>> _cache = {};
  final Map<String, int> _requests = {};
  final Set<String> _loadingTabs = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this, initialIndex: 1);
    _tabController.addListener(_onTabChanged);
    _load();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    setState(() {});
    _load();
  }

  String get _currentTab => _tabs[_tabController.index].key;

  Future<void> _load([String? tab]) async {
    final key = tab ?? _currentTab;
    final request = (_requests[key] ?? 0) + 1;
    _requests[key] = request;
    if (!_cache.containsKey(key)) setState(() => _loadingTabs.add(key));

    final List<Object> items = key == _reservedTab
        ? await _api.fetchMyReservations()
        : await _api.fetchOrders(role: 'buyer', tab: key);
    if (!mounted || _requests[key] != request) return;
    setState(() {
      _cache[key] = items;
      _loadingTabs.remove(key);
    });
  }

  Future<void> _cancelOrder(Order order) async {
    final confirmed = await showConfirmDialog(
      context,
      title: S.cancelOrder,
      message: S.cancelOrderBookReturnsShop(order.orderNo),
      confirmLabel: S.cancelOrder,
      cancelLabel: S.actionBack,
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    final error = await runBusy(context, () => _api.cancelOrder(order.orderId));
    if (!mounted) return;

    if (error != null) {
      showAppSnackBar(context, error, isError: true);
      _load();
    } else {
      HapticFeedback.mediumImpact();
      showAppSnackBar(context, S.orderCancelled2);
      _load();
      _load('cancelled');
    }
  }

  Future<void> _confirmPickup(Order order) async {
    final confirmed = await showConfirmDialog(
      context,
      title: S.iCollected,
      message: S.confirmVeTakenBookFromLocker,
      confirmLabel: S.confirm,
      icon: Icons.inventory_2_outlined,
    );

    if (!confirmed || !mounted) return;

    final error = await runBusy(context, () => _api.updateOrderStatus(order.orderId, 'picked_up'));
    if (!mounted) return;

    if (error != null) {
      showAppSnackBar(context, error, isError: true);
      _load();
      return;
    }
    await Navigator.push(context, MaterialPageRoute(builder: (_) => PickupSuccessScreen(order: order)));
    if (!mounted) return;
    _load();
    _load('completed');
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
    _load();
  }

  Future<void> _cancelReservation(ChatReservation reservation) async {
    final confirmed = await showConfirmDialog(
      context,
      title: S.cancelReservation2,
      message: S.cancelReservation,
      confirmLabel: S.cancelReservation2,
      cancelLabel: S.actionBack,
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    final (_, error) =
        await runBusy(context, () => _api.respondReservation(reservation.reservationId, 'cancel')) ??
        (null, S.actionFailed);
    if (!mounted) return;
    if (error != null) {
      showAppSnackBar(context, error, isError: true);
    } else {
      showAppSnackBar(context, S.reservationCanceled);
    }
    _load();
  }

  Future<void> _openReservedBook(ChatReservation reservation) async {
    final book = await runBusy(context, () => _api.fetchBookDetail(reservation.bookId));
    if (!mounted) return;
    if (book == null) {
      showAppSnackBar(context, S.bookNoLongerListed, isError: true);
      _load();
      return;
    }
    await Navigator.push(context, MaterialPageRoute(builder: (_) => BookDetailScreen(book: book)));
    if (mounted) _load();
  }

  Future<void> _openDetail(Order order) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailScreen(order: order)));
    if (mounted) _load();
  }

  Future<void> _openDispute(Order order) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => DisputeScreen(orderId: order.orderId)));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final tab = _currentTab;
    final orders = _cache[tab] ?? const <Object>[];
    final loading = _loadingTabs.contains(tab) && !_cache.containsKey(tab);

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          AppHeader(
            title: S.purchases,
            icon: Icons.shopping_bag_outlined,
            bottom: AppTabBar(controller: _tabController, tabs: _tabs.map((t) => t.label).toList()),
          ),
          Expanded(
            child: SwipeTabs(
              controller: _tabController,
              child: SwitchIn(
                child: KeyedSubtree(
                  key: ValueKey(
                    'tab_${tab}_${loading
                        ? 'loading'
                        : orders.isEmpty
                        ? 'empty'
                        : 'items'}',
                  ),
                  child: loading
                      ? const LoadingView.grid()
                      : RefreshIndicator(
                          color: c.accent,
                          onRefresh: _load,
                          child: orders.isEmpty
                              ? ListView(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  children: [
                                    const SizedBox(height: 80),
                                    tab == _reservedTab
                                        ? EmptyView(icon: Icons.bookmark_border_rounded, message: S.noReservedBooks)
                                        : EmptyView(icon: Icons.receipt_long_outlined, message: S.noOrdersTab),
                                  ],
                                )
                              : SaleCardGrid(
                                  padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
                                  itemCount: orders.length,
                                  itemBuilder: (_, i) => RevealOnScroll(
                                    key: ValueKey(_itemKey(orders[i])),
                                    index: i,
                                    child: _buildCard(tab, orders[i]),
                                  ),
                                ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _itemKey(Object item) =>
      item is ChatReservation ? 'reservation_${item.reservationId}' : 'order_${(item as Order).orderId}';

  Widget _buildCard(String tab, Object item) {
    if (item is ChatReservation) return _buildReservationCard(item);
    final order = item as Order;
    switch (tab) {
      case 'pending_pickup':
        final collectable = canCollectOrder(order);
        return OrderCard(
          order: order,
          onTap: () => _openDetail(order),
          showPickupWindow: true,
          actionLabel: collectable ? S.iCollected : (order.isCancellable ? S.cancelOrder : null),
          onAction: () => collectable ? _confirmPickup(order) : _cancelOrder(order),
        );
      case 'completed':
        final awaiting = order.awaitingConfirmation;
        final canDispute = order.canOpenDispute();
        return OrderCard(
          order: order,
          onTap: () => _openDetail(order),
          actionLabel: awaiting ? S.completeOrder : null,
          onAction: () => _completeOrder(order),
          secondaryLabel: canDispute ? S.openDispute : null,
          onSecondary: () => _openDispute(order),
        );
      default:
        return OrderCard(order: order, onTap: () => _openDetail(order));
    }
  }

  Widget _buildReservationCard(ChatReservation r) {
    final deadline = r.pickupDeadline;
    final holding = r.isConfirmed && deadline != null;
    String two(int n) => n.toString().padLeft(2, '0');
    final until = holding
        ? '${two(deadline.month)}/${two(deadline.day)} ${two(deadline.hour)}:${two(deadline.minute)}'
        : '';
    return SaleCardFrame(
      imageUrl: r.bookImageUrl,
      title: r.bookTitle,
      price: r.bookPrice,
      status: holding ? S.heldUntilP02(until) : S.awaitingReply,
      address: '',
      openHours: '',
      slotNumber: '',
      onTap: () => _openReservedBook(r),
      actionLabel: holding ? S.buyNow : null,
      onAction: () => _openReservedBook(r),
      secondaryLabel: S.cancelReservation2,
      onSecondary: () => _cancelReservation(r),
    );
  }
}
