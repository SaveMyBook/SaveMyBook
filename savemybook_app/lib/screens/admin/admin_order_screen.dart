import 'package:flutter/material.dart';
import '../../models/admin_models.dart';
import '../../services/api_service.dart';
import '../../utils/api_helpers.dart';
import '../../utils/app_colors.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/app_forms.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_tiles.dart';
import '../../widgets/state_views.dart';
import '../../utils/app_labels.dart';
import '../../i18n/strings.dart';

class AdminOrderScreen extends StatefulWidget {
  const AdminOrderScreen({super.key});

  @override
  State<AdminOrderScreen> createState() => _AdminOrderScreenState();
}

class _AdminOrderScreenState extends State<AdminOrderScreen> {
  static const _filters = [
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

  Future<void> _changeStatus(AdminOrder order) async {
    final c = AppColors.of(context);

    final status = await showOptionSheet<String>(
      context,
      title: '調整訂單狀態',
      subtitle: '訂單 ${order.orderNo}',
      options: AppLabels.orderStatus.entries
          .map((e) => SheetOption(
                value: e.key,
                label: e.value,
                selected: e.key == order.status,
                color: e.key == 'cancelled' ? c.danger : null,
              ))
          .toList(),
    );
    if (status == null || status == order.status || !mounted) return;

    final note = await showTextInputDialog(
      context,
      title: '調整說明',
      hint: '會一併通知買家（選填）',
      confirmLabel: '確認調整',
    );
    if (!mounted) return;

    final error = await runBusy(
      context,
      () => _api.updateOrderStatusAsAdmin(order.orderId, status, note: note),
    );
    if (!mounted) return;

    if (error != null) {
      showAppSnackBar(context, error, isError: true);
    } else {
      showAppSnackBar(context, '訂單狀態已更新');
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
          const AppHeader(title: '訂單管理', icon: Icons.receipt_long_outlined),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: AppSearchField(
              controller: _searchController,
              hint: '搜尋訂單編號或買賣家',
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
                              children: const [
                                SizedBox(height: 60),
                                EmptyView(
                                  icon: Icons.receipt_long_outlined,
                                  message: '找不到符合條件的訂單',
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
      onTap: () => _changeStatus(order),
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
                      first == null ? '（無品項）' : first.title,
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
                        '等 ${order.items.length} 項',
                        style: TextStyle(fontSize: 11, color: c.textHint),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      '買家 ${order.buyerName}｜賣家 ${order.sellerName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: c.textSecondary),
                    ),
                    if (order.cabinetName.isNotEmpty)
                      Text(
                        '書櫃：${order.cabinetName}',
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
              '取消原因：${order.cancelReason}',
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
