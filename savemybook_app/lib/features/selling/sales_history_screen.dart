import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/book.dart';
import '../../models/order.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/app_header.dart';
import '../orders/widgets/order_card.dart';
import '../../widgets/state_views.dart';
import '../books/book_detail_screen.dart';
import '../orders/order_detail_screen.dart';
import '../../i18n/strings.dart';

class SalesHistoryScreen extends StatefulWidget {
  final String? initialTab;

  const SalesHistoryScreen({super.key, this.initialTab});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> with SingleTickerProviderStateMixin {
  List<({String key, String label})> get _tabs => [
    (key: 'pending_deposit', label: S.orderPendingDeposit),
    (key: 'deposited', label: S.orderDeposited),
    (key: 'on_sale', label: S.bookOnSale),
    (key: 'cancelled', label: S.orderCancelled),
    (key: 'completed', label: S.orderCompleted),
  ];

  final ApiService _api = ApiService();
  late final TabController _tabController;
  final Map<String, List<Object>> _cache = {};
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
    final List<Object> items;
    // 販售中只放上架中、尚未成立訂單的書；已成立訂單的書在待存書與已存書分頁。
    if (tab == 'on_sale') {
      items = (await _api.fetchMyBooks()).where((b) => b.status == 'on_sale').toList();
    } else {
      items = await _api.fetchOrders(role: 'seller', tab: tab);
    }
    if (!mounted || _requestIds[tab] != requestId) return;
    setState(() {
      _cache[tab] = items;
    });
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

  Future<void> _delist(Book book) async {
    if (_busy) return;
    final confirmed = await showConfirmDialog(
      context,
      title: S.delist,
      message: S.removedFromShopBuyersNoLonger(book.title),
      confirmLabel: S.delist2,
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    _busy = true;
    final ok = await runBusy(context, () => _api.removeBook(book.bookId));
    _busy = false;
    if (!mounted) return;

    if (ok != true) {
      showAppSnackBar(context, S.couldNotDelistPleaseTryAgain, isError: true);
    } else {
      HapticFeedback.lightImpact();
      showAppSnackBar(context, S.p0Delisted(book.title));
    }
    _load();
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

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final items = _cache[_currentTab];

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          AppHeader(
            title: S.sales,
            icon: Icons.inventory_2_outlined,
            bottom: AppTabBar(controller: _tabController, tabs: _tabs.map((t) => t.label).toList()),
          ),
          Expanded(
            child: SwipeTabs(
              controller: _tabController,
              child: SwitchIn(
                child: items == null
                    ? LoadingView.grid(key: ValueKey('loading_$_currentTab'))
                    : items.isEmpty
                    ? RefreshableCenter(
                        key: ValueKey('empty_$_currentTab'),
                        onRefresh: _load,
                        child: EmptyView(icon: Icons.sell_outlined, message: S.noOrdersTab),
                      )
                    : RefreshIndicator(
                        key: ValueKey('list_$_currentTab'),
                        color: c.accent,
                        onRefresh: _load,
                        child: SaleCardGrid(
                          itemCount: items.length,
                          itemBuilder: (_, i) => RevealOnScroll(index: i, child: _buildCard(items[i])),
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
    await Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailScreen(order: order, asSeller: true)));
    _load();
  }

  Future<void> _openBook(Book book) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => BookDetailScreen(book: book)));
    _load();
  }

  Widget _buildCard(Object item) {
    if (item is Book) {
      return ListingCard(
        book: item,
        onTap: () => _openBook(item),
        actionLabel: item.isHeld ? null : S.delist,
        onAction: () => _delist(item),
      );
    }
    final order = item as Order;
    switch (_currentTab) {
      case 'pending_deposit':
        return OrderCard(
          order: order,
          asSeller: true,
          onTap: () => _openDetail(order),
          showPickupWindow: true,
          actionLabel: S.markAsDroppedOff,
          onAction: () => _markDeposited(order),
          secondaryLabel: order.isCancellable ? S.cancelOrder : null,
          onSecondary: () => _cancelOrder(order),
        );
      default:
        return OrderCard(order: order, asSeller: true, onTap: () => _openDetail(order));
    }
  }
}
