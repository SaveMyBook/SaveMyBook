import 'package:flutter/material.dart';
import '../models/order.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../widgets/animations.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/app_header.dart';
import '../widgets/order_card.dart';
import '../widgets/state_views.dart';

class PendingIncomeScreen extends StatefulWidget {
  const PendingIncomeScreen({super.key});

  @override
  State<PendingIncomeScreen> createState() => _PendingIncomeScreenState();
}

class _PendingIncomeScreenState extends State<PendingIncomeScreen> {
  final ApiService _api = ApiService();
  List<Order> _orders = [];
  double _total = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await _api.fetchPendingIncome();
    if (!mounted) return;
    setState(() {
      _orders = result.orders;
      _total = result.total;
      _isLoading = false;
    });
  }

  Future<void> _cancel(Order order) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '取消訂單',
      message: '取消後這筆待定收益會一併消失，買家也會收到通知。',
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

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          const AppHeader(title: '待定收益', icon: Icons.query_stats_rounded),
          Expanded(
            child: SwitchIn(child: _isLoading
                ? const LoadingView()
                : RefreshIndicator(
                    color: c.accent,
                    onRefresh: _load,
                    child: CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(child: _buildTotalCard(c)),
                        if (_orders.isEmpty)
                          const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.only(top: 40),
                              child: EmptyView(icon: Icons.savings_outlined, message: '目前沒有待撥款的訂單'),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.all(16),
                            sliver: SliverGrid(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 0.55,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (_, i) => FadeSlideIn(
                                  index: i,
                                  child: OrderCard(
                                    order: _orders[i],
                                    actionLabel: _orders[i].isCancellable ? '取消訂單' : null,
                                    onAction: () => _cancel(_orders[i]),
                                  ),
                                ),
                                childCount: _orders.length,
                              ),
                            ),
                          ),
                      ],
                    ),
                  )),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalCard(AppColors c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      child: AppCard(
        padding: const EdgeInsets.symmetric(vertical: 22),
        child: Column(
          children: [
            Text('待定收益金額', style: TextStyle(fontSize: 14, color: c.textSecondary)),
            const SizedBox(height: 12),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: c.accent, width: 3),
              ),
              child: Center(
                child: Text(
                  '\$',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: c.accent),
                ),
              ),
            ),
            const SizedBox(height: 10),
            AnimatedCount(
              value: _total,
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: c.textPrimary),
            ),
            const SizedBox(height: 6),
            Text('買家完成取書後會自動撥入代幣餘額',
                style: TextStyle(fontSize: 12, color: c.textHint)),
          ],
        ),
      ),
    );
  }
}
