import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final String? initialTab;

  const SalesHistoryScreen({super.key, this.initialTab});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen>
    with SingleTickerProviderStateMixin {
  List<({String key, String label})> get _tabs => [
    (key: 'pending_deposit', label: S.orderPendingDeposit),
    (key: 'on_sale', label: S.bookOnSale),
    (key: 'cancelled', label: S.orderCancelled),
    (key: 'completed', label: S.orderCompleted),
  ];

  final ApiService _api = ApiService();
  late final TabController _tabController;
  final Map<String, List<Order>> _cache = {};
  final Map<String, int> _requestIds = {};
  bool _busy = false;
  int _lastIndex = 0;

  @override
  void initState() {
    super.initState();
    final initial = _tabs.indexWhere((t) => t.key == widget.initialTab);
    _lastIndex = initial < 0 ? 0 : initial;
    _tabController = TabController(length: _tabs.length, vsync: this, initialIndex: _lastIndex);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging || _tabController.index == _lastIndex) return;
      _lastIndex = _tabController.index;
      setState(() {});
      _load();
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
    final tab = _currentTab;
    final requestId = (_requestIds[tab] ?? 0) + 1;
    _requestIds[tab] = requestId;
    final orders = await _api.fetchOrders(role: 'seller', tab: tab);
    if (!mounted || _requestIds[tab] != requestId) return;
    setState(() {
      _cache[tab] = orders;
    });
  }

  Future<void> _copy(String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    HapticFeedback.selectionClick();
    showAppSnackBar(context, S.copied(label));
  }

  Future<void> _markDeposited(Order order) async {
    if (_busy) return;
    final confirmed = await showConfirmDialog(
      context,
      title: S.markAsDroppedOff,
      message: S.confirmPutLocker(order.firstBook?.title ?? S.untitled),
      confirmLabel: S.droppedOff,
    );
    if (!confirmed || !mounted) return;

    _busy = true;
    final error = await runBusy(context, () => _api.updateOrderStatus(order.orderId, 'deposited'));
    _busy = false;
    if (!mounted) return;

    if (error != null) {
      showAppSnackBar(context, error, isError: true);
    } else {
      showAppSnackBar(context, S.markedAsDroppedOff);
      _load();
    }
  }

  Future<void> _cancelOrder(Order order) async {
    if (_busy) return;
    final confirmed = await showConfirmDialog(
      context,
      title: S.cancelOrder,
      message: S.buyerNotifiedBookReturnsShop,
      confirmLabel: S.cancelOrder,
      cancelLabel: S.actionBack,
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    _busy = true;
    final error = await runBusy(context, () => _api.cancelOrder(order.orderId, reason: S.cancelledBySeller));
    _busy = false;
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
    final code = order.pickupCode;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(S.dropOffPickupCode, style: TextStyle(fontWeight: FontWeight.bold, color: c.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PressableScale(
              onTap: code == null ? null : () => _copy(S.dropOffPickupCode, code),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        code ?? S.notGeneratedYet,
                        style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: c.accent, letterSpacing: 4),
                      ),
                    ),
                    if (code != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.copy_rounded, size: 13, color: c.textHint),
                          const SizedBox(width: 4),
                          Text(S.copy, style: TextStyle(fontSize: 12, color: c.textHint)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(S.enterCodeLocker, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: c.textSecondary)),
            const SizedBox(height: 12),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _copy(S.orderNumber, order.orderNo),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Row(
                  children: [
                    Text(S.orderNumber, style: TextStyle(fontSize: 12, color: c.textHint)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        order.orderNo,
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.textSecondary),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.copy_rounded, size: 13, color: c.iconInactive),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(S.actionClose)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final orders = _cache[_currentTab];

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
              child: SwitchIn(
                child: orders == null
                    ? LoadingView.grid(key: ValueKey('loading_$_currentTab'))
                    : orders.isEmpty
                        ? RefreshableCenter(
                            key: ValueKey('empty_$_currentTab'),
                            onRefresh: _load,
                            child: EmptyView(icon: Icons.sell_outlined, message: S.noOrdersTab),
                          )
                        : RefreshIndicator(
                            key: ValueKey('list_$_currentTab'),
                            color: c.accent,
                            onRefresh: _load,
                            child: GridView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(16),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 0.55,
                              ),
                              itemCount: orders.length,
                              itemBuilder: (_, i) => RevealOnScroll(index: i, child: _buildCard(orders[i])),
                            ),
                          ),
              ),
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
