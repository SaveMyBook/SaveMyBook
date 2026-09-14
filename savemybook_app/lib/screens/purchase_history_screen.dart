import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/order.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../widgets/animations.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/app_header.dart';
import '../widgets/buyer/pickup_code_card.dart';
import '../widgets/order_card.dart';
import '../widgets/state_views.dart';
import 'order_detail_screen.dart';
import 'dispute_screen.dart';
import 'pickup_success_screen.dart';
import '../i18n/strings.dart';

bool canCollectOrder(Order order) => order.status == 'deposited' || order.status == 'pending_pickup';

class PurchaseHistoryScreen extends StatefulWidget {
  const PurchaseHistoryScreen({super.key});

  @override
  State<PurchaseHistoryScreen> createState() => _PurchaseHistoryScreenState();
}

class _PurchaseHistoryScreenState extends State<PurchaseHistoryScreen> with SingleTickerProviderStateMixin {
  List<({String key, String label})> get _tabs => [
        (key: 'pending_pickup', label: S.orderBuyerDeposited),
        (key: 'completed', label: S.orderCompleted),
        (key: 'cancelled', label: S.orderCancelled),
        (key: 'disputing', label: S.orderBuyerRefunding),
      ];

  final ApiService _api = ApiService();
  late final TabController _tabController;

  final Map<String, List<Order>> _cache = {};
  final Map<String, int> _requests = {};
  final Set<String> _loadingTabs = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
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

    final orders = await _api.fetchOrders(role: 'buyer', tab: key);
    if (!mounted || _requests[key] != request) return;
    setState(() {
      _cache[key] = orders;
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

  Future<void> _pickup(Order order) async {
    final c = AppColors.of(context);
    final code = order.pickupCode;
    final collectable = canCollectOrder(order);

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: c.sheetBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                S.pickupCode2,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.textPrimary),
              ),
              const SizedBox(height: 14),
              if (code == null || code.isEmpty)
                Text(S.notGeneratedYet, style: TextStyle(fontSize: 14, color: c.textSecondary))
              else
                PickupCodeCard(
                  code: code,
                  slotNumber: order.slotNumber,
                  caption: order.cabinetName.isEmpty ? S.enterCodeLockerCollect : S.enterCodeCollect(order.cabinetName),
                ),
              if (!collectable) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 16, color: c.warning),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        S.sellerHasnTPutBookLocker,
                        style: TextStyle(fontSize: 12, color: c.textSecondary),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              PrimaryButton(
                label: S.iCollected,
                icon: Icons.check_rounded,
                onPressed: collectable ? () => Navigator.pop(ctx, true) : null,
              ),
              const SizedBox(height: 4),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: TextButton.styleFrom(foregroundColor: c.textSecondary),
                  child: Text(S.actionClose),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    final error = await runBusy(context, () => _api.updateOrderStatus(order.orderId, 'completed'));
    if (!mounted) return;

    if (error != null) {
      showAppSnackBar(context, error, isError: true);
      _load();
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PickupSuccessScreen(order: order)),
    );
    if (!mounted) return;
    _load();
    _load('completed');
  }

  Future<void> _openDetail(Order order) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => OrderDetailScreen(order: order)),
    );
    if (mounted) _load();
  }

  Future<void> _openDispute(Order order) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DisputeScreen(orderId: order.orderId)),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final tab = _currentTab;
    final orders = _cache[tab] ?? const <Order>[];
    final loading = _loadingTabs.contains(tab) && !_cache.containsKey(tab);

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          AppHeader(
            title: S.purchases,
            icon: Icons.shopping_bag_outlined,
            bottom: AppTabBar(
              controller: _tabController,
              tabs: _tabs.map((t) => t.label).toList(),
            ),
          ),
          Expanded(
            child: SwipeTabs(
              controller: _tabController,
              child: SwitchIn(
                child: KeyedSubtree(
                  key: ValueKey('tab_${tab}_${loading ? 'loading' : orders.isEmpty ? 'empty' : 'items'}'),
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
                                    EmptyView(icon: Icons.receipt_long_outlined, message: S.noOrdersTab),
                                  ],
                                )
                              : GridView.builder(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: tab == 'pending_pickup' ? 0.5 : 0.55,
                                  ),
                                  itemCount: orders.length,
                                  itemBuilder: (_, i) => RevealOnScroll(
                                    key: ValueKey(orders[i].orderId),
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

  Widget _buildCard(String tab, Order order) {
    switch (tab) {
      case 'pending_pickup':
        return OrderCard(
          order: order,
          onTap: () => _openDetail(order),
          showPickupWindow: true,
          actionLabel: order.isCancellable ? S.cancelOrder : null,
          onAction: () => _cancelOrder(order),
          onShowQr: () => _pickup(order),
        );
      case 'completed':
        return OrderCard(
          order: order,
          onTap: () => _openDetail(order),
          actionLabel: order.hasOpenDispute ? null : S.openDispute,
          onAction: () => _openDispute(order),
        );
      default:
        return OrderCard(order: order, onTap: () => _openDetail(order));
    }
  }
}
