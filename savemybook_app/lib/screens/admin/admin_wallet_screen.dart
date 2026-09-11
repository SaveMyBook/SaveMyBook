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
import '../../utils/motion.dart';
import '../../i18n/strings.dart';

class AdminWalletScreen extends StatefulWidget {
  const AdminWalletScreen({super.key});

  @override
  State<AdminWalletScreen> createState() => _AdminWalletScreenState();
}

class _AdminWalletScreenState extends State<AdminWalletScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();

  List<AdminWallet> _wallets = [];
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
    final wallets = await _api.fetchAdminWallets(keyword: _searchController.text.trim());
    if (!mounted) return;
    setState(() {
      _wallets = wallets;
      _isLoading = false;
    });
  }

  Future<void> _openDetail(AdminWallet wallet) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AdminWalletDetailScreen(userId: wallet.userId)),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          AppHeader(title: S.wallets, icon: Icons.account_balance_wallet_outlined),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: AppSearchField(
              controller: _searchController,
              hint: S.searchDisplayNameEmail,
              onSubmitted: (_) => _load(),
            ),
          ),
          Expanded(
            child: SwitchIn(
              child: _isLoading
                  ? const LoadingView.list()
                  : RefreshIndicator(
                      color: c.accent,
                      onRefresh: _load,
                      child: SwitchIn(child: _wallets.isEmpty
                          ? ListView(key: const ValueKey('empty'), 
                              children: [
                                SizedBox(height: 60),
                                EmptyView(
                                  icon: Icons.account_balance_wallet_outlined,
                                  message: S.noMembersMatch,
                                ),
                              ],
                            )
                          : ListView.builder(key: const ValueKey('items'), 
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                              itemCount: _wallets.length,
                              itemBuilder: (_, i) => RevealOnScroll(
                                index: i,
                                child: _buildCard(_wallets[i], c),
                              ),
                            )),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(AdminWallet wallet, AppColors c) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () => _openDetail(wallet),
      child: Row(
        children: [
          UserAvatar(imageUrl: wallet.avatarUrl, radius: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  wallet.nickname,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  wallet.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: c.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                wallet.balance.toStringAsFixed(0),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: c.accent,
                ),
              ),
              Text(S.faqCatWallet, style: TextStyle(fontSize: 10, color: c.textHint)),
            ],
          ),
          Icon(Icons.chevron_right_rounded, color: c.iconInactive),
        ],
      ),
    );
  }
}

class AdminWalletDetailScreen extends StatefulWidget {
  final int userId;

  const AdminWalletDetailScreen({super.key, required this.userId});

  @override
  State<AdminWalletDetailScreen> createState() => _AdminWalletDetailScreenState();
}

class _AdminWalletDetailScreenState extends State<AdminWalletDetailScreen> {
  final ApiService _api = ApiService();
  AdminWalletDetail? _detail;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final detail = await _api.fetchAdminWalletDetail(widget.userId);
    if (!mounted) return;
    setState(() {
      _detail = detail;
      _isLoading = false;
    });
  }

  Future<void> _adjust({required bool isAdd}) async {
    final c = AppColors.of(context);
    final amountController = TextEditingController();
    final reasonController = TextEditingController();

    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isAdd ? S.addCoins : S.deductCoins,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.textPrimary),
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: amountController,
              hint: S.amountPositiveWholeNumber,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: reasonController,
              hint: S.reasonAdjustmentRequired,
              maxLines: 3,
              maxLength: 200,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isAdd ? c.success : c.danger,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  isAdd ? S.add2 : S.deduct,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (submitted != true || !mounted) return;

    final raw = double.tryParse(amountController.text.trim());
    final reason = reasonController.text.trim();

    if (raw == null || raw <= 0) {
      showAppSnackBar(context, S.enterAmountGreaterThan0, isError: true);
      return;
    }
    if (reason.isEmpty) {
      showAppSnackBar(context, S.enterReasonAdjustment, isError: true);
      return;
    }

    final who = _detail?.wallet.nickname ?? S.member2;
    final verb = isAdd ? S.add3 : S.deduct2;

    final confirmed = await showConfirmDialog(
      context,
      title: isAdd ? S.confirmAddingCoins : S.confirmDeductingCoins,
      message: S.p1P2CoinsP0NreasonP3(who, verb, raw.toStringAsFixed(0), reason),
      confirmLabel: S.confirm,
      isDestructive: !isAdd,
    );
    if (!confirmed || !mounted) return;

    final error = await runBusy(
      context,
      () => _api.adjustWallet(
        widget.userId,
        amount: isAdd ? raw : -raw,
        description: reason,
      ),
    );
    if (!mounted) return;

    if (error != null) {
      showAppSnackBar(context, error, isError: true);
    } else {
      showAppSnackBar(context, S.balanceAdjusted);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final detail = _detail;

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          AppHeader(title: S.memberWallets, icon: Icons.account_balance_wallet_outlined),
          Expanded(
            child: SwitchIn(
              child: _isLoading
                  ? const LoadingView.list()
                  : detail == null
                      ? EmptyView(
                          icon: Icons.person_off_outlined,
                          message: S.noDataMember,
                        )
                      : RefreshIndicator(
                          color: c.accent,
                          onRefresh: _load,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                            children: [
                              _buildSummary(detail.wallet, c),
                              const SizedBox(height: 16),
                              _buildActions(c),
                              const SizedBox(height: 24),
                              Text(
                                S.transactions3,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: c.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (detail.transactions.isEmpty)
                                Text(
                                  S.memberNoTransactionsYet,
                                  style: TextStyle(fontSize: 13, color: c.textHint),
                                )
                              else
                                for (var i = 0; i < detail.transactions.length; i++)
                                  FadeSlideIn(
                                    index: i,
                                    child: _buildTxn(detail.transactions[i], c),
                                  ),
                            ],
                          ),
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(AdminWallet wallet, AppColors c) {
    return AppCard(
      child: Column(
        children: [
          Row(
            children: [
              UserAvatar(imageUrl: wallet.avatarUrl, radius: 26, enablePreview: true),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      wallet.nickname,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      wallet.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: c.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          AnimatedCount(
            value: wallet.balance,
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: c.accent,
            ),
          ),
          Text(S.balanceCoins, style: TextStyle(fontSize: 12, color: c.textHint)),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              StatTile(
                label: S.hold2,
                value: Text(
                  wallet.frozenAmount.toStringAsFixed(0),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.warning),
                ),
              ),
              const VerticalDivider1(),
              StatTile(
                label: S.total2,
                value: Text(
                  wallet.totalIncome.toStringAsFixed(0),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.success),
                ),
              ),
              const VerticalDivider1(),
              StatTile(
                label: S.totalOut,
                value: Text(
                  wallet.totalExpense.toStringAsFixed(0),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.danger),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActions(AppColors c) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 46,
            child: ElevatedButton.icon(
              onPressed: () => _adjust(isAdd: true),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(S.addCoins),
              style: ElevatedButton.styleFrom(
                backgroundColor: c.success,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 46,
            child: ElevatedButton.icon(
              onPressed: () => _adjust(isAdd: false),
              icon: const Icon(Icons.remove_rounded, size: 18),
              label: Text(S.deductCoins),
              style: ElevatedButton.styleFrom(
                backgroundColor: c.danger,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTxn(AdminWalletTxn txn, AppColors c) {
    final isPositive = txn.amount >= 0;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          AnimatedContainer(
        duration: Motion.base,
        curve: Motion.standard,

            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: (isPositive ? c.success : c.danger).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isPositive ? Icons.south_west_rounded : Icons.north_east_rounded,
              size: 17,
              color: isPositive ? c.success : c.danger,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  txn.typeText,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: c.textPrimary,
                  ),
                ),
                if (txn.description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    txn.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: c.textSecondary, height: 1.4),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  formatDateTime(txn.createdAt),
                  style: TextStyle(fontSize: 10, color: c.textHint),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${isPositive ? '+' : ''}${txn.amount.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isPositive ? c.success : c.danger,
                ),
              ),
              Text(
                S.balanceP0(txn.balanceAfter.toStringAsFixed(0)),
                style: TextStyle(fontSize: 10, color: c.textHint),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
