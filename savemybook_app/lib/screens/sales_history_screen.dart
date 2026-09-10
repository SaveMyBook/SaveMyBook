import 'package:flutter/material.dart';
import '../models/order.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../widgets/animations.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/app_header.dart';
import '../widgets/order_card.dart';
import '../widgets/state_views.dart';

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen>
    with SingleTickerProviderStateMixin {
  static const _tabs = [
    (key: 'pending_deposit', label: '待存書'),
    (key: 'on_sale', label: '販售中'),
    (key: 'cancelled', label: '已取消'),
    (key: 'completed', label: '已完成'),
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
      title: '完成存書',
      message: '確認已把《${order.firstBook?.title ?? '書籍'}》放入書櫃了嗎？\n買家會收到可取書的通知。',
      confirmLabel: '已放入書櫃',
    );
    if (!confirmed || !mounted) return;

    final error = await runBusy(context, () => _api.updateOrderStatus(order.orderId, 'deposited'));
    if (!mounted) return;

    if (error != null) {
      showAppSnackBar(context, error, isError: true);
    } else {
      showAppSnackBar(context, '已標記為完成存書');
      _load();
    }
  }

  Future<void> _cancelOrder(Order order) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '取消訂單',
      message: '取消後買家會收到通知，書籍會回到商城重新販售。',
      confirmLabel: '取消訂單',
      cancelLabel: '返回',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    final error = await runBusy(context, () => _api.cancelOrder(order.orderId, reason: '賣家取消'));
    if (!mounted) return;

    if (error != null) {
      showAppSnackBar(context, error, isError: true);
    } else {
      showAppSnackBar(context, '訂單已取消');
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
        title: Text('存書／取書代碼', style: TextStyle(fontWeight: FontWeight.bold, color: c.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              order.pickupCode ?? '尚未產生',
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: 4),
            ),
            const SizedBox(height: 12),
            Text('請在書櫃上輸入此代碼', style: TextStyle(fontSize: 13, color: c.textSecondary)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('關閉')),
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
            title: '銷售紀錄',
            icon: Icons.inventory_2_outlined,
            bottom: AppTabBar(
              controller: _tabController,
              tabs: _tabs.map((t) => t.label).toList(),
            ),
          ),
          Expanded(
            child: SwitchIn(child: _isLoading
                ? const LoadingView.list()
                : RefreshIndicator(
                    color: c.accent,
                    onRefresh: _load,
                    child: orders.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 80),
                              EmptyView(icon: Icons.sell_outlined, message: '此分類目前沒有訂單'),
                            ],
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.55,
                            ),
                            itemCount: orders.length,
                            itemBuilder: (_, i) => FadeSlideIn(index: i, child: _buildCard(orders[i])),
                          ),
                  )),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Order order) {
    switch (_currentTab) {
      case 'pending_deposit':
        return OrderCard(
          order: order,
          showPickupWindow: true,
          onShowQr: () => _showPickupCode(order),
          actionLabel: '完成存書',
          onAction: () => _markDeposited(order),
        );
      case 'on_sale':
        return OrderCard(
          order: order,
          showPickupWindow: true,
          onShowQr: () => _showPickupCode(order),
          actionLabel: order.isCancellable ? '取消訂單' : null,
          onAction: () => _cancelOrder(order),
        );
      default:
        return OrderCard(order: order);
    }
  }
}
