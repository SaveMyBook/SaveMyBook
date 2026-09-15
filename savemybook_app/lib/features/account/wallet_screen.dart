import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/wallet.dart';
import '../../services/api_service.dart';
import '../../utils/api_helpers.dart';
import '../../utils/app_colors.dart';
import '../../utils/motion.dart';
import '../../widgets/responsive.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/app_header.dart';
import '../../widgets/state_views.dart';
import '../orders/dispute_screen.dart';
import '../orders/order_detail_screen.dart';
import '../selling/pending_income_screen.dart';
import '../../i18n/strings.dart';

enum _TxnFilter { all, income, expense }

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final ApiService _api = ApiService();
  Wallet _wallet = Wallet.empty;
  List<WalletTransaction> _transactions = [];
  bool _isLoading = true;
  _TxnFilter _filter = _TxnFilter.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      _api.fetchWallet(),
      _api.fetchWalletTransactions(),
    ]);
    if (!mounted) return;
    setState(() {
      _wallet = results[0] as Wallet;
      _transactions = results[1] as List<WalletTransaction>;
      _isLoading = false;
    });
  }

  List<WalletTransaction> get _visible => switch (_filter) {
        _TxnFilter.all => _transactions,
        _TxnFilter.income => _transactions.where((t) => t.isIncome).toList(),
        _TxnFilter.expense => _transactions.where((t) => !t.isIncome).toList(),
      };

  List<({DateTime month, List<WalletTransaction> items})> _groupByMonth(List<WalletTransaction> items) {
    final groups = <({DateTime month, List<WalletTransaction> items})>[];
    for (final t in items) {
      // createdAt 是 UTC，分月前必須先轉成本地時間，否則月初月底的紀錄會被歸到錯的月份。
      final local = t.createdAt?.toLocal();
      final month = local == null ? DateTime(0) : DateTime(local.year, local.month);
      if (groups.isEmpty || groups.last.month != month) {
        groups.add((month: month, items: <WalletTransaction>[]));
      }
      groups.last.items.add(t);
    }
    return groups;
  }

  String _monthLabel(DateTime month) {
    if (month.year == 0) return S.ticketCatOther;
    final now = DateTime.now();
    if (month.year == now.year && month.month == now.month) return S.month;
    return S.p0P1(month.year, month.month);
  }

  String _money(double value) => AnimatedCount.group(value.abs().toStringAsFixed(0));

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          AppHeader(title: S.coins, icon: Icons.monetization_on_outlined),
          Expanded(
            child: SwitchIn(
              child: _isLoading
                  ? const LoadingView.list(key: ValueKey('loading'))
                  : RefreshIndicator(
                      key: const ValueKey('content'),
                      color: c.accent,
                      onRefresh: _load,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          if (context.screenSize == ScreenSize.expanded && constraints.maxWidth >= 900) {
                            return _buildSplit(c, constraints);
                          }
                          final side = responsiveListPadding(constraints, horizontal: 20).left;

                          return CustomScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            slivers: [
                              SliverPadding(
                                padding: EdgeInsets.fromLTRB(side, 20, side, 0),
                                sliver: SliverToBoxAdapter(
                                  child: FadeSlideIn(child: _buildBalanceCard(c)),
                                ),
                              ),
                              SliverPadding(
                                padding: EdgeInsets.fromLTRB(side, 24, side, 4),
                                sliver: SliverToBoxAdapter(
                                  child: FadeSlideIn(index: 1, child: _buildTransactionsHeader(c)),
                                ),
                              ),
                              ..._buildGroups(c, side, side),
                              const SliverToBoxAdapter(child: SizedBox(height: 40)),
                            ],
                          );
                        },
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSplit(AppColors c, BoxConstraints constraints) {
    final padding = responsiveListPadding(constraints, maxWidth: Breakpoints.pageMaxWidth, horizontal: 20);
    final paneWidth = ((constraints.maxWidth - padding.horizontal) * 0.36).clamp(340.0, 400.0);
    final listLeft = padding.left + paneWidth + 24;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: listLeft,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(padding.left, 20, 24, 40),
            child: FadeSlideIn(child: _buildBalanceCard(c)),
          ),
        ),
        Expanded(
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(0, 20, padding.right, 4),
                sliver: SliverToBoxAdapter(
                  child: FadeSlideIn(index: 1, child: _buildTransactionsHeader(c)),
                ),
              ),
              ..._buildGroups(c, 0, padding.right),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildGroups(AppColors c, double left, double right) {
    final visible = _visible;
    if (visible.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 24),
            child: SwitchIn(
              child: EmptyView(
                key: ValueKey(_filter),
                icon: Icons.receipt_outlined,
                message: _transactions.isEmpty
                    ? S.noTransactionsYet
                    : _filter == _TxnFilter.income
                        ? S.noIncomeYet
                        : S.noSpendingYet,
              ),
            ),
          ),
        ),
      ];
    }

    var index = 0;
    return [
      for (final group in _groupByMonth(visible))
        SliverMainAxisGroup(
          slivers: [
            PinnedHeaderSliver(
              child: ColoredBox(
                color: c.scaffold,
                child: Padding(
                  padding: EdgeInsets.only(left: left, right: right),
                  child: MonthHeader(
                    label: _monthLabel(group.month),
                    trailing: _netLabel(group.items),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.only(left: left, right: right),
              sliver: SliverList.list(
                children: [
                  for (final t in group.items)
                    RevealOnScroll(index: index++, child: _buildTransaction(t, c)),
                ],
              ),
            ),
          ],
        ),
    ];
  }

  String _netLabel(List<WalletTransaction> items) {
    final net = items.fold<double>(0, (sum, t) => sum + t.amount);
    final sign = net > 0 ? '+' : (net < 0 ? '-' : '');
    return '$sign\$${_money(net)}';
  }

  Widget _buildTransactionsHeader(AppColors c) {
    final incomeCount = _transactions.where((t) => t.isIncome).length;
    final expenseCount = _transactions.length - incomeCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.transactions,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _filterChip(c, _TxnFilter.all, S.actionAll, _transactions.length),
            _filterChip(c, _TxnFilter.income, S.income, incomeCount),
            _filterChip(c, _TxnFilter.expense, S.spending, expenseCount),
          ],
        ),
      ],
    );
  }

  Widget _filterChip(AppColors c, _TxnFilter filter, String label, int count) {
    final selected = _filter == filter;
    return PressableScale(
      scale: 0.95,
      onTap: () {
        if (selected) return;
        HapticFeedback.selectionClick();
        setState(() => _filter = filter);
      },
      child: AnimatedContainer(
        duration: Motion.base,
        curve: Motion.standard,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? c.accent : c.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? c.accent : c.divider),
        ),
        child: Text(
          count > 0 ? '$label $count' : label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            color: selected ? Colors.white : c.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceCard(AppColors c) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      child: Column(
        children: [
          Text(S.balance, style: TextStyle(fontSize: 14, color: c.textSecondary)),
          const SizedBox(height: 12),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.accent.withValues(alpha: 0.08),
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
              value: _wallet.balance,
              thousands: true,
              duration: Motion.count,
              style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: c.textPrimary),
            ),
          ),
          if (_wallet.frozenAmount > 0) ...[
            const SizedBox(height: 4),
            Text(
              S.hold(_wallet.frozenAmount.toStringAsFixed(0)),
              style: TextStyle(fontSize: 12, color: c.warning),
            ),
          ],
          if (_wallet.pendingIncome > 0) ...[
            const SizedBox(height: 4),
            Text(
              '${S.pendingPayouts} \$${_money(_wallet.pendingIncome)}',
              style: TextStyle(fontSize: 12, color: c.textHint),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _summaryTile(c, S.totalIncome, _wallet.totalIncome, c.success, Icons.south_west_rounded)),
              const SizedBox(width: 10),
              Expanded(child: _summaryTile(c, S.totalSpending, _wallet.totalExpense, c.danger, Icons.north_east_rounded)),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: QuickActionButton(
                  icon: Icons.query_stats_rounded,
                  label: S.pendingPayouts,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PendingIncomeScreen()),
                    );
                    _load();
                  },
                ),
              ),
              Expanded(
                child: QuickActionButton(
                  icon: Icons.gavel_rounded,
                  label: S.dispute,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DisputeScreen()),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryTile(AppColors c, String label, double value, Color tint, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: tint),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: c.textSecondary),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: AnimatedCount(
                    value: value.abs(),
                    prefix: '\$',
                    thousands: true,
                    duration: Motion.count,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copy(String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    HapticFeedback.selectionClick();
    showAppSnackBar(context, S.copied(label));
  }

  void _showDetail(WalletTransaction t) {
    final c = AppColors.of(context);
    final tint = t.isIncome ? c.success : c.danger;
    final local = t.createdAt?.toLocal();

    Widget row(String label, String value, {bool copyable = false}) {
      return InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: copyable ? () => _copy(label, value) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 88,
                child: Text(label, style: TextStyle(fontSize: 13, color: c.textSecondary)),
              ),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary),
                ),
              ),
              if (copyable) ...[
                const SizedBox(width: 6),
                Icon(Icons.copy_rounded, size: 15, color: c.iconInactive),
              ],
            ],
          ),
        ),
      );
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.sheetBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: c.divider, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 18),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: tint.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(
                  switch (t.type) {
                    'transfer_in' => Icons.call_received_rounded,
                    'transfer_out' => Icons.call_made_rounded,
                    _ => t.isIncome ? Icons.south_west_rounded : Icons.north_east_rounded,
                  },
                  color: tint,
                ),
              ),
              const SizedBox(height: 10),
              Text(t.typeText, style: TextStyle(fontSize: 14, color: c.textSecondary)),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${t.isIncome ? '+' : '-'}\$${_money(t.amount)}',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: tint),
                ),
              ),
              const SizedBox(height: 12),
              Divider(color: c.divider),
              if (t.type != 'transfer_in' && t.type != 'transfer_out') row(S.item3, t.bookTitle),
              if (t.description.isNotEmpty) row(S.details, t.description),
              row(S.balanceAfter, '\$${_money(t.balanceAfter)}'),
              if (local != null) row(S.time, formatDateTime(local)),
              if (t.orderNo != null) row(S.orderNumber, t.orderNo!, copyable: true),
              if (t.txnNo.isNotEmpty) row(S.transactionId, t.txnNo, copyable: true),
              if (t.orderId != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final order = await runBusy(context, () => ApiService().fetchOrderDetail(t.orderId!));
                      if (!mounted) return;
                      if (order == null) {
                        showAppSnackBar(context, S.orderNotFound, isError: true);
                        return;
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OrderDetailScreen(order: order, asSeller: order.sellerId == ApiService.currentUser?.userId),
                        ),
                      );
                    },
                    icon: const Icon(Icons.receipt_long_rounded),
                    label: Text(S.viewOrder),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransaction(WalletTransaction t, AppColors c) {
    final tint = t.isIncome ? c.success : c.danger;
    final isTransfer = t.type == 'transfer_in' || t.type == 'transfer_out';

    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      onTap: () => _showDetail(t),
      onLongPress: () {
        if (t.orderNo != null) {
          _copy(S.orderNumber, t.orderNo!);
        } else if (t.txnNo.isNotEmpty) {
          _copy(S.transactionId, t.txnNo);
        }
      },
      child: Row(
        children: [
          if (isTransfer)
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: tint.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
              child: Icon(t.type == 'transfer_in' ? Icons.call_received_rounded : Icons.call_made_rounded, color: tint, size: 22),
            )
          else
            BookThumbnail(imageUrl: t.bookImageUrl, width: 46, height: 60, radius: 8),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isTransfer ? t.typeText : t.bookTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary),
                ),
                const SizedBox(height: 5),
                Text(
                  t.description.isEmpty ? t.typeText : t.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, height: 1.35, color: c.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 110),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${t.isIncome ? '+' : '-'}\$${_money(t.amount)}',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: tint),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  formatDate(t.createdAt?.toLocal()),
                  maxLines: 1,
                  style: TextStyle(fontSize: 11, color: c.textHint),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
