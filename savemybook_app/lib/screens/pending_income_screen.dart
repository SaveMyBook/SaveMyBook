import 'package:flutter/material.dart';
import '../models/order.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../widgets/animations.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/app_header.dart';
import '../widgets/order_card.dart';
import '../widgets/state_views.dart';
import '../utils/motion.dart';
import 'order_detail_screen.dart';
import '../i18n/strings.dart';

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
  bool _cancelling = false;

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

  Future<void> _openDetail(Order order) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => OrderDetailScreen(order: order, asSeller: true)),
    );
    if (mounted) _load();
  }

  Future<void> _cancel(Order order) async {
    if (_cancelling) return;
    final confirmed = await showConfirmDialog(
      context,
      title: S.cancelOrder,
      message: S.pendingPayoutDisappearsBuyerNotified,
      confirmLabel: S.cancelOrder,
      cancelLabel: S.actionBack,
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    _cancelling = true;
    final error = await runBusy(context, () => _api.cancelOrder(order.orderId, reason: S.cancelledBySeller));
    _cancelling = false;
    if (!mounted) return;

    if (error != null) {
      showAppSnackBar(context, error, isError: true);
    } else {
      showAppSnackBar(context, S.orderCancelled2);
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
          AppHeader(title: S.pendingPayouts, icon: Icons.query_stats_rounded),
          Expanded(
            child: SwitchIn(child: _isLoading
                ? const LoadingView.list()
                : RefreshIndicator(
                    color: c.accent,
                    onRefresh: _load,
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(child: FadeSlideIn(child: _buildTotalCard(c))),
                        if (_orders.isEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.only(top: 40),
                              child: EmptyView(icon: Icons.savings_outlined, message: S.noPendingPayouts),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.all(16),
                            sliver: SaleCardGrid.sliver(
                              itemCount: _orders.length,
                              itemBuilder: (_, i) => RevealOnScroll(
                                index: i,
                                child: OrderCard(
                                  order: _orders[i],
                                  asSeller: true,
                                  onTap: () => _openDetail(_orders[i]),
                                  actionLabel: _orders[i].isCancellable ? S.cancelOrder : null,
                                  onAction: () => _cancel(_orders[i]),
                                ),
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
            Text(S.pendingAmount, style: TextStyle(fontSize: 14, color: c.textSecondary)),
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
            FittedBox(
              fit: BoxFit.scaleDown,
              child: AnimatedCount(
                value: _total,
                thousands: true,
                duration: Motion.count,
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: c.textPrimary),
              ),
            ),
            if (_orders.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(S.p0Orders2(_orders.length), style: TextStyle(fontSize: 12, color: c.textSecondary)),
            ],
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                S.coinsArriveOnceBuyerCollectsBook,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: c.textHint),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
