import 'package:flutter/material.dart';
import '../../models/admin_models.dart';
import 'admin_order_detail_screen.dart';
import '../../services/api_service.dart';
import '../../utils/api_helpers.dart';
import '../../utils/app_colors.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_forms.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_tiles.dart';
import '../../widgets/state_views.dart';
import '../../i18n/strings.dart';

class AdminOrderScreen extends StatefulWidget {
  const AdminOrderScreen({super.key});

  @override
  State<AdminOrderScreen> createState() => _AdminOrderScreenState();
}

class _AdminOrderScreenState extends State<AdminOrderScreen> {
  List<({String key, String label})> get _filters => [
    (key: 'all', label: S.actionAll),
    (key: 'pending_deposit', label: S.orderPendingDeposit),
    (key: 'pending_pickup', label: S.orderBuyerDeposited),
    (key: 'completed', label: S.orderCompleted),
    (key: 'cancelled', label: S.orderCancelled),
    (key: 'refunding', label: S.orderRefunding),
  ];

  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();

  List<AdminOrder> _orders = [];
  String _filter = 'all';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final orders = await _api.fetchAdminOrders(
      keyword: _searchController.text.trim(),
      status: _filter,
    );
    if (!mounted) return;
    setState(() {
      _orders = orders;
      _isLoading = false;
    });
  }

  /// 點卡片先看詳情，不要直接跳改狀態的選單——那等於逼客服在看不到
  /// 時間軸、退款與申訴的情況下做決定。
  ///
  /// 回來一律重載：把「有沒有改過」當成回傳值傳回來的話，得關掉
  /// iOS 的左滑返回才收得到，代價比多打一次 API 大。
  Future<void> _openDetail(AdminOrder order) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminOrderDetailScreen(orderId: order.orderId, orderNo: order.orderNo),
      ),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          AppHeader(title: S.orders, icon: Icons.receipt_long_outlined),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: AppSearchField(
              controller: _searchController,
              hint: S.searchOrderNumberBuyerSeller,
              onSubmitted: (_) => _load(),
            ),
          ),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filters.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final f = _filters[i];
                final selected = _filter == f.key;
                return GestureDetector(
                  onTap: () {
                    setState(() => _filter = f.key);
                    _load();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? c.accent : c.categoryChip,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      f.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                        color: selected ? Colors.white : c.accent,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: SwitchIn(
              child: _isLoading
                  ? const LoadingView.list()
                  : RefreshIndicator(
                      color: c.accent,
                      onRefresh: _load,
                      child: SwitchIn(child: _orders.isEmpty
                          ? ListView(key: const ValueKey('empty'), 
                              children: [
                                SizedBox(height: 60),
                                EmptyView(
                                  icon: Icons.receipt_long_outlined,
                                  message: S.noOrdersMatch,
                                ),
                              ],
                            )
                          : ListView.builder(key: const ValueKey('items'), 
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                              itemCount: _orders.length,
                              itemBuilder: (_, i) => RevealOnScroll(
                                index: i,
                                child: _buildCard(_orders[i], c),
                              ),
                            )),
                    ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildCard(AdminOrder order, AppColors c) {
    final first = order.items.isEmpty ? null : order.items.first;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () => _openDetail(order),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.orderNo,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: c.textPrimary,
                  ),
                ),
              ),
              StatusBadge(label: order.statusText, color: c.orderStatusColor(order.status)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BookThumbnail(imageUrl: first?.imageUrl, width: 48, height: 62, radius: 8),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      first == null ? S.noItems : first.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: c.textPrimary,
                      ),
                    ),
                    if (order.items.length > 1)
                      Text(
                        S.p0ItemsTotal(order.items.length),
                        style: TextStyle(fontSize: 11, color: c.textHint),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      S.buyerP0SellerP12(order.buyerName, order.sellerName),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: c.textSecondary),
                    ),
                    if (order.cabinetName.isNotEmpty)
                      Text(
                        S.lockerP0(order.cabinetName),
                        style: TextStyle(fontSize: 12, color: c.textSecondary),
                      ),
                  ],
                ),
              ),
              Text(
                '\$${order.totalAmount.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: c.accent,
                ),
              ),
            ],
          ),
          if (order.cancelReason != null && order.cancelReason!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              S.cancellationReasonP0(order.cancelReason!),
              style: TextStyle(fontSize: 11, color: c.danger),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                formatDateTime(order.createdAt),
                style: TextStyle(fontSize: 11, color: c.textHint),
              ),
              const Spacer(),
              Icon(Icons.chevron_right_rounded, size: 18, color: c.iconInactive),
            ],
          ),
        ],
      ),
    );
  }
}
