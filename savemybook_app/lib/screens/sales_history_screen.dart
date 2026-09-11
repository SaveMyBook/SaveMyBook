import 'package:flutter/material.dart';
import '../models/order.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../widgets/animations.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/app_header.dart';
import '../widgets/order_card.dart';
import '../widgets/state_views.dart';
import 'order_detail_screen.dart';
import '../i18n/strings.dart';

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen>
    with SingleTickerProviderStateMixin {
  static const _tabs = [
    (key: 'pending_deposit', label: S.orderPendingDeposit),
    (key: 'on_sale', label: S.bookOnSale),
    (key: 'cancelled', label: S.orderCancelled),
    (key: 'completed', label: S.orderCompleted),
  ];

  final ApiService _api = ApiService();
  late final TabController _tabController;
  final Map<String, List<Order>> _cache = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) _load();
    });
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _currentTab => _tabs[_tabController.index].key;

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final orders = await _api.fetchOrders(role: 'seller', tab: _currentTab);
    if (!mounted) return;
    setState(() {
      _cache[_currentTab] = orders;
      _isLoading = false;
    });
  }

  Future<void> _markDeposited(Order order) async {
    final confirmed = await showConfirmDialog(
      context,
      title: S.markAsDroppedOff,
      message: S.confirmPutLocker(order.firstBook?.title ?? S.untitled),
      confirmLabel: S.droppedOff,
    );
    if (!confirmed || !mounted) return;

    final error = await runBusy(context, () => _api.updateOrderStatus(order.orderId, 'deposited'));
    if (!mounted) return;

    if (error != null) {
      showAppSnackBar(context, error, isError: true);
    } else {
      showAppSnackBar(context, S.markedAsDroppedOff);
      _load();
    }
  }

  Future<void> _cancelOrder(Order order) async {
    final confirmed = await showConfirmDialog(
      context,
      title: S.cancelOrder,
      message: S.buyerNotifiedBookReturnsShop,
      confirmLabel: S.cancelOrder,
      cancelLabel: S.actionBack,
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    final error = await runBusy(context, () => _api.cancelOrder(order.orderId, reason: S.cancelledBySeller));
    if (!mounted) return;

    if (error != null) {
      showAppSnackBar(context, error, isError: true);
    } else {
      showAppSnackBar(context, S.orderCancelled2);
      _load();
    }
  }

  void _showPickupCode(Order order) {
    final c = AppColors.of(context);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(S.dropOffPickupCode, style: TextStyle(fontWeight: FontWeight.bold, color: c.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              order.pickupCode ?? S.notGeneratedYet,
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: 4),
            ),
            const SizedBox(height: 12),
            Text(S.enterCodeLocker, style: TextStyle(fontSize: 13, color: c.textSecondary)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(S.actionClose)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final orders = _cache[_currentTab] ?? const <Order>[];

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          AppHeader(
            title: S.sales,
            icon: Icons.inventory_2_outlined,
            bottom: AppTabBar(
              controller: _tabController,
              tabs: _tabs.map((t) => t.label).toList(),
            ),
          ),
          Expanded(
            child: SwipeTabs(
              controller: _tabController,
              child: SwitchIn(child: _isLoading
                ? const LoadingView.grid()
                : RefreshIndicator(
                    color: c.accent,
                    onRefresh: _load,
                    child: SwitchIn(child: orders.isEmpty
                        ? ListView(key: const ValueKey('empty'), 
                            children: [
                              SizedBox(height: 80),
                              EmptyView(icon: Icons.sell_outlined, message: S.noOrdersTab),
                            ],
                          )
                        : GridView.builder(key: const ValueKey('items'), 
                            padding: const EdgeInsets.all(16),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.55,
                            ),
                            itemCount: orders.length,
                            itemBuilder: (_, i) => RevealOnScroll(index: i, child: _buildCard(orders[i])),
                          )),
                  )),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openDetail(Order order) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => OrderDetailScreen(order: order, asSeller: true)),
    );
    _load();
  }

  Widget _buildCard(Order order) {
    switch (_currentTab) {
      case 'pending_deposit':
        return OrderCard(
          order: order,
          onTap: () => _openDetail(order),
          showPickupWindow: true,
          onShowQr: () => _showPickupCode(order),
          actionLabel: S.markAsDroppedOff,
          onAction: () => _markDeposited(order),
        );
      case 'on_sale':
        return OrderCard(
          order: order,
          onTap: () => _openDetail(order),
          showPickupWindow: true,
          onShowQr: () => _showPickupCode(order),
          actionLabel: order.isCancellable ? S.cancelOrder : null,
          onAction: () => _cancelOrder(order),
        );
      default:
        return OrderCard(order: order, onTap: () => _openDetail(order));
    }
  }
}
