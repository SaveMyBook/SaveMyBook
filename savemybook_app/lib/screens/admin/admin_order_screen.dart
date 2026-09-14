import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/admin_models.dart';
import 'admin_order_detail_screen.dart';
import '../../services/api_service.dart';
import '../../utils/api_helpers.dart';
import '../../utils/app_colors.dart';
import '../../utils/motion.dart';
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
    (key: 'refunding', label: S.orderRefunding),
    (key: 'refunded', label: S.orderRefunded),
    (key: 'cancelled', label: S.orderCancelled),
  ];

  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();

  List<AdminOrder> _orders = [];
  String _filter = 'all';
  bool _isLoading = true;
  bool _navigating = false;
  int _loadSeq = 0;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool showLoading = true}) async {
    _debounce?.cancel();
    final seq = ++_loadSeq;
    if (showLoading) setState(() => _isLoading = true);
    final orders = await _api.fetchAdminOrders(
      keyword: _searchController.text.trim(),
      status: _filter,
    );
    if (!mounted || seq != _loadSeq) return;
    setState(() {
      _orders = orders;
      _isLoading = false;
    });
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), _load);
  }

  void _setFilter(String key) {
    if (_filter == key) return;
    setState(() => _filter = key);
    _load();
  }

  Future<void> _openDetail(AdminOrder order) async {
    if (_navigating) return;
    _navigating = true;
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AdminOrderDetailScreen(orderId: order.orderId, orderNo: order.orderNo),
        ),
      );
    } finally {
      _navigating = false;
    }
    if (mounted) _load(showLoading: false);
  }

  void _copyOrderNo(AdminOrder order) {
    Clipboard.setData(ClipboardData(text: order.orderNo));
    HapticFeedback.selectionClick();
    showAppSnackBar(context, S.orderNumberCopied);
  }

  static String _when(DateTime? dt) {
    if (dt == null) return '';
    final relative = formatRelative(dt);
    final exact = formatDateTime(dt);
    return exact.startsWith(relative) ? exact : '$relative・$exact';
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final hasQuery = _searchController.text.trim().isNotEmpty || _filter != 'all';

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
              onChanged: _onSearchChanged,
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
                return PressableScale(
                  scale: 0.94,
                  onTap: () => _setFilter(f.key),
                  child: AnimatedContainer(
                    duration: Motion.micro,
                    curve: Motion.standard,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? c.accent : c.categoryChip,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      f.label,
                      maxLines: 1,
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
                      onRefresh: () => _load(showLoading: false),
                      child: SwitchIn(
                        child: _orders.isEmpty
                            ? ListView(
                                key: const ValueKey('empty'),
                                children: [
                                  const SizedBox(height: 60),
                                  EmptyView(
                                    icon: Icons.receipt_long_outlined,
                                    message: S.noOrdersMatch,
                                    actionLabel: hasQuery ? S.clearFilters : S.refresh,
                                    onAction: () {
                                      if (hasQuery) {
                                        _searchController.clear();
                                        _filter = 'all';
                                      }
                                      _load();
                                    },
                                  ),
                                ],
                              )
                            : ListView.builder(
                                key: ValueKey('items_$_filter'),
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                                itemCount: _orders.length,
                                itemBuilder: (_, i) => RevealOnScroll(
                                  index: i,
                                  child: _buildCard(_orders[i], c),
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

  Widget _buildCard(AdminOrder order, AppColors c) {
    final first = order.items.isEmpty ? null : order.items.first;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () => _openDetail(order),
      onLongPress: () => _copyOrderNo(order),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        order.orderNo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: c.textPrimary,
                        ),
                      ),
                    ),
                    PressableScale(
                      onTap: () => _copyOrderNo(order),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Icon(Icons.copy_rounded, size: 14, color: c.iconInactive),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: c.textSecondary),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 96),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    '\$${order.totalAmount.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: c.accent,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (order.cancelReason != null && order.cancelReason!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              S.cancellationReasonP0(order.cancelReason!),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: c.danger),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  _when(order.createdAt),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: c.textHint),
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 18, color: c.iconInactive),
            ],
          ),
        ],
      ),
    );
  }
}
