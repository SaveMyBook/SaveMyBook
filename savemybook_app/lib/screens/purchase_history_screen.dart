import 'package:flutter/material.dart';
import '../models/order.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../widgets/animations.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/app_header.dart';
import '../widgets/order_card.dart';
import '../widgets/state_views.dart';
import 'dispute_screen.dart';
import 'pickup_success_screen.dart';

class PurchaseHistoryScreen extends StatefulWidget {
  const PurchaseHistoryScreen({super.key});

  @override
  State<PurchaseHistoryScreen> createState() => _PurchaseHistoryScreenState();
}

class _PurchaseHistoryScreenState extends State<PurchaseHistoryScreen>
    with SingleTickerProviderStateMixin {
  static const _tabs = [
    (key: 'pending_pickup', label: '待取書'),
    (key: 'completed', label: '已完成'),
    (key: 'cancelled', label: '已取消'),
    (key: 'disputing', label: '申訴中'),
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
    final orders = await _api.fetchOrders(role: 'buyer', tab: _currentTab);
    if (!mounted) return;
    setState(() {
      _cache[_currentTab] = orders;
      _isLoading = false;
    });
  }

  Future<void> _cancelOrder(Order order) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '取消訂單',
      message: '確定要取消訂單 ${order.orderNo} 嗎？取消後書籍會回到商城重新販售。',
      confirmLabel: '取消訂單',
      cancelLabel: '返回',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    final error = await runBusy(context, () => _api.cancelOrder(order.orderId));
    if (!mounted) return;

    if (error != null) {
      showAppSnackBar(context, error, isError: true);
    } else {
      showAppSnackBar(context, '訂單已取消');
      _load();
    }
  }

  Future<void> _pickup(Order order) async {
    final c = AppColors.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('取書代碼', style: TextStyle(fontWeight: FontWeight.bold, color: c.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              order.pickupCode ?? '尚未產生',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: c.accent,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              order.cabinetName.isEmpty
                  ? '請在書櫃上輸入此代碼取書'
                  : '請至「${order.cabinetName}」輸入此代碼取書',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: c.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('關閉', style: TextStyle(color: c.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('我已完成取書',
                style: TextStyle(color: c.accent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final error = await runBusy(context, () => _api.updateOrderStatus(order.orderId, 'completed'));
    if (!mounted) return;

    if (error != null) {
      showAppSnackBar(context, error, isError: true);
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PickupSuccessScreen(order: order)),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final orders = _cache[_currentTab] ?? const <Order>[];

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          const AppHeader(title: '購買紀錄', icon: Icons.shopping_bag_outlined),
          AppTabBar(
            controller: _tabController,
            tabs: _tabs.map((t) => t.label).toList(),
          ),
          Expanded(
            child: SwitchIn(child: _isLoading
                ? const LoadingView()
                : RefreshIndicator(
                    color: c.accent,
                    onRefresh: _load,
                    child: orders.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 80),
                              EmptyView(icon: Icons.receipt_long_outlined, message: '此分類目前沒有訂單'),
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
      case 'pending_pickup':
        return OrderCard(
          order: order,
          showPickupWindow: true,
          actionLabel: order.isCancellable ? '取消訂單' : null,
          onAction: () => _cancelOrder(order),
          onShowQr: () => _pickup(order),
        );
      case 'completed':
        return OrderCard(
          order: order,
          actionLabel: '申請爭議',
          onAction: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => DisputeScreen(orderId: order.orderId)),
          ).then((_) => _load()),
        );
      default:
        return OrderCard(order: order);
    }
  }
}
