import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/order.dart';
import '../services/api_service.dart';
import '../utils/api_helpers.dart';
import '../utils/app_colors.dart';
import '../widgets/animations.dart';
import '../widgets/app_header.dart';
import '../widgets/app_tiles.dart';
import '../widgets/state_views.dart';
import 'book_detail_screen.dart';
import '../utils/app_labels.dart';

class OrderDetailScreen extends StatefulWidget {
  final Order order;

  final bool asSeller;

  const OrderDetailScreen({super.key, required this.order, this.asSeller = false});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  static const _flow = AppLabels.orderFlow;

  final ApiService _api = ApiService();
  late Order _order = widget.order;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final detail = await _api.fetchOrderDetail(widget.order.orderId);
    if (!mounted) return;
    setState(() {
      if (detail != null) _order = detail;
      _isLoading = false;
    });
  }

  int get _flowIndex {
    final index = _flow.indexWhere((f) => f.status == _order.status);
    if (_order.status == 'completed') return _flow.length - 1;
    return index;
  }

  bool get _isClosed =>
      _order.status == 'cancelled' ||
      _order.status == 'refunded' ||
      _order.status == 'refunding';


  Future<void> _copy(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    HapticFeedback.selectionClick();
    showAppSnackBar(context, '已複製$label');
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          const AppHeader(title: '訂單詳情', icon: Icons.receipt_long_outlined),
          Expanded(
            child: RefreshIndicator(
              color: c.accent,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                children: [
                  FadeSlideIn(child: _buildStatusCard(c)),
                  const SizedBox(height: 14),
                  if (!_isClosed) ...[
                    FadeSlideIn(index: 1, child: _buildFlowCard(c)),
                    const SizedBox(height: 14),
                  ],
                  FadeSlideIn(index: 2, child: _buildItemsCard(c)),
                  const SizedBox(height: 14),
                  FadeSlideIn(index: 3, child: _buildPickupCard(c)),
                  const SizedBox(height: 14),
                  FadeSlideIn(index: 4, child: _buildInfoCard(c)),
                  if (_isLoading) ...[
                    const SizedBox(height: 20),
                    Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: c.iconInactive),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(AppColors c) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: c.orderStatusColor(_order.status).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _isClosed ? Icons.info_outline_rounded : Icons.local_shipping_outlined,
              color: c.orderStatusColor(_order.status),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _order.statusText,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: c.orderStatusColor(_order.status),
                  ),
                ),
                const SizedBox(height: 2),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onLongPress: () => _copy(_order.orderNo, '訂單編號'),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          '訂單編號 ${_order.orderNo}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: c.textSecondary),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.copy_rounded, size: 12, color: c.iconInactive),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlowCard(AppColors c) {
    final current = _flowIndex;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeading(title: '訂單進度'),
          const SizedBox(height: 16),
          for (var i = 0; i < _flow.length; i++)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    AnimatedContainer(
                      duration: Duration(milliseconds: 300 + i * 80),
                      curve: Curves.easeOut,
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: i <= current ? c.accent : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: i <= current ? c.accent : c.divider,
                          width: 2,
                        ),
                      ),
                      child: i <= current
                          ? const Icon(Icons.check_rounded, size: 11, color: Colors.white)
                          : null,
                    ),
                    if (i != _flow.length - 1)
                      Container(
                        width: 2,
                        height: 26,
                        color: i < current ? c.accent : c.divider,
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(
                    _flow[i].label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: i == current ? FontWeight.bold : FontWeight.normal,
                      color: i <= current ? c.textPrimary : c.textHint,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildItemsCard(AppColors c) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(title: '商品明細（${_order.items.length}）'),
          const SizedBox(height: 12),
          if (_order.items.isEmpty)
            Text('這筆訂單沒有品項資料。', style: TextStyle(fontSize: 13, color: c.textHint))
          else
            for (final item in _order.items) ...[
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => BookDetailScreen(book: item.book)),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      BookThumbnail(
                        imageUrl: item.book.hasImage ? item.book.imageUrl : null,
                        width: 52,
                        height: 68,
                        radius: 8,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              item.book.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: c.textPrimary,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '單價 \$${item.unitPrice.toStringAsFixed(0)} × ${item.quantity}',
                              style: TextStyle(fontSize: 12, color: c.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '\$${item.subtotal.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: c.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          Divider(color: c.divider, height: 20),
          Row(
            children: [
              Text('訂單金額', style: TextStyle(fontSize: 14, color: c.textSecondary)),
              const Spacer(),
              Text(
                '\$${_order.totalAmount.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: c.accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPickupCard(AppColors c) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeading(title: '取書資訊'),
          const SizedBox(height: 12),
          InfoLine(
            icon: Icons.storage_rounded,
            label: '書櫃',
            value: _order.cabinetName.isEmpty ? '尚未指定' : _order.cabinetName,
          ),
          InfoLine(
            icon: Icons.location_on_outlined,
            label: '地址',
            value: _order.cabinetAddress.isEmpty ? '尚未指定' : _order.cabinetAddress,
          ),
          InfoLine(
            icon: Icons.schedule_rounded,
            label: '開放時間',
            value: _order.cabinetOpenHours.isEmpty ? '未提供' : _order.cabinetOpenHours,
          ),
          InfoLine(
            icon: Icons.grid_view_rounded,
            label: '櫃位',
            value: _order.slotNumber.isEmpty ? '尚未配位' : _order.slotNumber,
          ),
          if (!widget.asSeller && _order.pickupCode != null && _order.pickupCode!.isNotEmpty)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onLongPress: () => _copy(_order.pickupCode!, '取書碼'),
              child: InfoLine(
                icon: Icons.pin_rounded,
                label: '取書碼',
                value: _order.pickupCode!,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(AppColors c) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeading(title: '交易資訊'),
          const SizedBox(height: 12),
          InfoLine(
            icon: widget.asSeller ? Icons.person_outline_rounded : Icons.storefront_outlined,
            label: widget.asSeller ? '買家' : '賣家',
            value: widget.asSeller
                ? (_order.buyerName.isEmpty ? '—' : _order.buyerName)
                : (_order.sellerName.isEmpty ? '—' : _order.sellerName),
          ),
          InfoLine(
            icon: Icons.event_outlined,
            label: '成立時間',
            value: formatDateTime(_order.createdAt),
          ),
          if (_order.hasOpenDispute)
            InfoLine(
              icon: Icons.gavel_rounded,
              label: '爭議',
              value: '此訂單有進行中的申訴案件',
            ),
        ],
      ),
    );
  }
}
