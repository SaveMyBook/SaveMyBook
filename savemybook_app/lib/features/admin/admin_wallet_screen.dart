import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/admin_models.dart';
import '../../services/api_service.dart';
import '../../utils/api_helpers.dart';
import '../../utils/app_colors.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/app_forms.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_tiles.dart';
import '../../widgets/state_views.dart';
import '../../utils/motion.dart';
import '../../i18n/strings.dart';
import '../../widgets/responsive.dart';
import 'admin_layout.dart';

String _coins(double value) =>
    value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(2);

String _when(DateTime? dt) {
  if (dt == null) return '';
  final relative = formatRelative(dt);
  final exact = formatDateTime(dt);
  return exact.startsWith(relative) ? exact : '$relative・$exact';
}

class AdminWalletScreen extends StatefulWidget {
  const AdminWalletScreen({super.key});

  @override
  State<AdminWalletScreen> createState() => _AdminWalletScreenState();
}

class _AdminWalletScreenState extends State<AdminWalletScreen> {
  List<({String key, String label})> get _filters => [
    (key: 'all', label: S.actionAll),
    (key: 'balance', label: S.balance3),
    (key: 'frozen', label: S.hold3),
    (key: 'empty', label: S.zeroBalance),
  ];

  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();

  List<AdminWallet> _wallets = [];
  bool _isLoading = true;
  bool _navigating = false;
  String _filter = 'all';
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
    final wallets = await _api.fetchAdminWallets(keyword: _searchController.text.trim());
    if (!mounted || seq != _loadSeq) return;
    setState(() {
      _wallets = wallets;
      _isLoading = false;
    });
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), _load);
  }

  List<AdminWallet> get _visible => switch (_filter) {
        'balance' => _wallets.where((w) => w.balance > 0).toList(),
        'frozen' => _wallets.where((w) => w.frozenAmount > 0).toList(),
        'empty' => _wallets.where((w) => w.balance <= 0).toList(),
        _ => _wallets,
      };

  Future<void> _openDetail(AdminWallet wallet) async {
    if (_navigating) return;
    _navigating = true;
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AdminWalletDetailScreen(userId: wallet.userId)),
      );
    } finally {
      _navigating = false;
    }
    if (mounted) _load(showLoading: false);
  }

  void _copyEmail(AdminWallet wallet) {
    if (wallet.email.isEmpty) return;
    Clipboard.setData(ClipboardData(text: wallet.email));
    HapticFeedback.selectionClick();
    showAppSnackBar(context, S.copied('Email'));
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final visible = _visible;
    final filtered = _searchController.text.trim().isNotEmpty || _filter != 'all';

    return Scaffold(
      backgroundColor: c.scaffold,
      body: AdminLayout(
        builder: (context, frame) => Column(
          children: [
            AppHeader(title: S.wallets, icon: Icons.account_balance_wallet_outlined),
            Padding(
              padding: frame.inset(const EdgeInsets.fromLTRB(16, 16, 16, 8)),
              child: AppSearchField(
                controller: _searchController,
                hint: S.searchDisplayNameEmail,
                onChanged: _onSearchChanged,
                onSubmitted: (_) => _load(),
              ),
            ),
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: frame.inset(const EdgeInsets.symmetric(horizontal: 16)),
                itemCount: _filters.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final f = _filters[i];
                  final selected = _filter == f.key;
                  return PressableScale(
                    scale: 0.94,
                    onTap: () => setState(() => _filter = f.key),
                    child: AnimatedContainer(
                      duration: Motion.micro,
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
                        onRefresh: () => _load(showLoading: false),
                        child: SwitchIn(
                          child: visible.isEmpty
                              ? ListView(
                                  key: const ValueKey('empty'),
                                  children: [
                                    const SizedBox(height: 60),
                                    EmptyView(
                                      icon: Icons.account_balance_wallet_outlined,
                                      message: S.noMembersMatch,
                                      actionLabel: filtered ? S.clearFilters : S.refresh,
                                      onAction: () {
                                        if (filtered) {
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
                                  padding: frame.inset(const EdgeInsets.fromLTRB(16, 12, 16, 24)),
                                  itemCount: visible.length,
                                  itemBuilder: (_, i) => RevealOnScroll(
                                    index: i,
                                    child: _buildCard(visible[i], c),
                                  ),
                                ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(AdminWallet wallet, AppColors c) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () => _openDetail(wallet),
      onLongPress: () => _copyEmail(wallet),
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
                if (wallet.frozenAmount > 0) ...[
                  const SizedBox(height: 4),
                  StatusBadge(
                    label: '${S.hold2} ${_coins(wallet.frozenAmount)}',
                    color: c.warning,
                    fontSize: 10,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _coins(wallet.balance),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: c.accent,
                    ),
                  ),
                ),
                Text(
                  S.faqCatWallet,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, color: c.textHint),
                ),
              ],
            ),
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
  static const double _maxAdjust = 1000000;

  final ApiService _api = ApiService();
  AdminWalletDetail? _detail;
  bool _isLoading = true;
  bool _isBusy = false;

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

  Future<void> _retry() async {
    setState(() => _isLoading = true);
    await _load();
  }

  String? _amountError(String text, {required bool isAdd}) {
    final raw = text.trim();
    if (raw.isEmpty) return S.enterAmountGreaterThan0;
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(raw)) return S.amountCanMost2DecimalPlaces;
    final value = double.tryParse(raw);
    if (value == null || value <= 0) return S.enterAmountGreaterThan0;
    if (value > _maxAdjust) return S.singleAdjustmentCanTExceed1;
    final balance = _detail?.wallet.balance;
    if (!isAdd && balance != null && value > balance + 1e-9) {
      return S.wouldMakeBalanceNegativeCurrentBalance(_coins(balance));
    }
    return null;
  }

  Future<void> _adjust({required bool isAdd}) async {
    if (_isBusy) return;
    final detail = _detail;
    if (detail == null) return;

    setState(() => _isBusy = true);
    try {
      await _runAdjust(detail, isAdd: isAdd);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _runAdjust(AdminWalletDetail detail, {required bool isAdd}) async {
    final c = AppColors.of(context);
    final amountController = TextEditingController();
    final reasonController = TextEditingController();
    String? amountError;
    String? reasonError;

    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: SingleChildScrollView(
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
                const SizedBox(height: 4),
                Text(
                  '${detail.wallet.nickname}・${S.balanceP0(_coins(detail.wallet.balance))}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: c.textSecondary),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: amountController,
                  hint: S.amountUp2Decimals,
                  errorText: amountError,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                    LengthLimitingTextInputFormatter(10),
                  ],
                  prefixText: isAdd ? '+ ' : '− ',
                  onChanged: (_) {
                    if (amountError != null) setSheetState(() => amountError = null);
                  },
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: reasonController,
                  hint: S.reasonAdjustmentRequired,
                  errorText: reasonError,
                  maxLines: 3,
                  maxLength: 200,
                  onChanged: (_) {
                    if (reasonError != null) setSheetState(() => reasonError = null);
                  },
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: isAdd ? S.add2 : S.deduct,
                  height: 46,
                  color: isAdd ? c.success : c.danger,
                  onPressed: () {
                    final aError = _amountError(amountController.text, isAdd: isAdd);
                    final rError =
                        reasonController.text.trim().isEmpty ? S.enterReasonAdjustment : null;
                    if (aError != null || rError != null) {
                      HapticFeedback.lightImpact();
                      setSheetState(() {
                        amountError = aError;
                        reasonError = rError;
                      });
                      return;
                    }
                    Navigator.pop(ctx, true);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (submitted != true || !mounted) return;

    final amount = double.parse(amountController.text.trim());
    final reason = reasonController.text.trim();
    final who = detail.wallet.nickname.isEmpty ? S.member2 : detail.wallet.nickname;
    final verb = isAdd ? S.add3 : S.deduct2;
    final after = detail.wallet.balance + (isAdd ? amount : -amount);

    final confirmed = await showConfirmDialog(
      context,
      title: isAdd ? S.confirmAddingCoins : S.confirmDeductingCoins,
      message: S.p0NbalanceAfterP1(S.p1P2CoinsP0NreasonP3(who, verb, _coins(amount), reason), _coins(after)),
      confirmLabel: S.confirm,
      isDestructive: !isAdd,
    );
    if (!confirmed || !mounted) return;

    final error = await runBusy(
      context,
      () => _api.adjustWallet(
        widget.userId,
        amount: isAdd ? amount : -amount,
        description: reason,
      ),
    );
    if (!mounted) return;

    if (error != null) {
      if (error.isNotEmpty && error != S.verificationCancelled) showAppSnackBar(context, error, isError: true);
    } else {
      HapticFeedback.mediumImpact();
      showAppSnackBar(context, S.balanceAdjusted);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final detail = _detail;

    return Scaffold(
      backgroundColor: c.scaffold,
      body: AdminLayout(
        builder: (context, frame) => Column(
          children: [
            AppHeader(title: S.memberWallets, icon: Icons.account_balance_wallet_outlined),
            Expanded(
              child: SwitchIn(
                child: _isLoading
                    ? const LoadingView.list()
                    : detail == null
                        ? ListView(
                            children: [
                              const SizedBox(height: 60),
                              EmptyView(
                                icon: Icons.person_off_outlined,
                                message: S.noDataMember,
                                actionLabel: S.refresh,
                                onAction: _retry,
                              ),
                            ],
                          )
                        : RefreshIndicator(
                            color: c.accent,
                            onRefresh: _load,
                            child: ListView(
                              padding: frame.inset(
                                const EdgeInsets.fromLTRB(20, 20, 20, 40),
                                maxWidth: frame.isExpanded ? 1120 : Breakpoints.readingMaxWidth,
                              ),
                              children: frame.isExpanded
                                  ? [
                                      AdminColumns(
                                        gap: 20,
                                        spacing: 0,
                                        columns: [
                                          [
                                            FadeSlideIn(child: _buildSummary(detail.wallet, c)),
                                            const SizedBox(height: 16),
                                            FadeSlideIn(index: 1, child: _buildActions(c)),
                                          ],
                                          _buildTxnSection(detail, c),
                                        ],
                                      ),
                                    ]
                                  : [
                                      FadeSlideIn(child: _buildSummary(detail.wallet, c)),
                                      const SizedBox(height: 16),
                                      FadeSlideIn(index: 1, child: _buildActions(c)),
                                      const SizedBox(height: 24),
                                      ..._buildTxnSection(detail, c),
                                    ],
                            ),
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(AdminWallet wallet, AppColors c) {
    final hasCents = wallet.balance != wallet.balance.roundToDouble();

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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: wallet.email.isEmpty
                          ? null
                          : () {
                              Clipboard.setData(ClipboardData(text: wallet.email));
                              showAppSnackBar(context, S.copied('Email'));
                            },
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              wallet.email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: c.textSecondary),
                            ),
                          ),
                          if (wallet.email.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.copy_rounded, size: 13, color: c.iconInactive),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: AnimatedCount(
              value: wallet.balance,
              decimals: hasCents ? 2 : 0,
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: c.accent,
              ),
            ),
          ),
          Text(S.balanceCoins, style: TextStyle(fontSize: 12, color: c.textHint)),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: S.hold2,
                  value: Text(
                    _coins(wallet.frozenAmount),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.warning),
                  ),
                ),
              ),
              const VerticalDivider1(),
              Expanded(
                child: StatTile(
                  label: S.total2,
                  value: Text(
                    _coins(wallet.totalIncome),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.success),
                  ),
                ),
              ),
              const VerticalDivider1(),
              Expanded(
                child: StatTile(
                  label: S.totalOut,
                  value: Text(
                    _coins(wallet.totalExpense),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.danger),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTxnSection(AdminWalletDetail detail, AppColors c) {
    return [
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
          RevealOnScroll(
            key: ValueKey(detail.transactions[i].txnId),
            index: i,
            child: _buildTxn(detail.transactions[i], c),
          ),
    ];
  }

  Widget _buildActions(AppColors c) {
    return Row(
      children: [
        Expanded(
          child: PrimaryButton(
            label: S.addCoins,
            icon: Icons.add_rounded,
            height: 46,
            color: c.success,
            onPressed: _isBusy ? null : () => _adjust(isAdd: true),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: PrimaryButton(
            label: S.deductCoins,
            icon: Icons.remove_rounded,
            height: 46,
            color: c.danger,
            onPressed: _isBusy ? null : () => _adjust(isAdd: false),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
                  _when(txn.createdAt),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, color: c.textHint),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 110),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${isPositive ? '+' : ''}${_coins(txn.amount)}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isPositive ? c.success : c.danger,
                    ),
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    S.balanceP0(_coins(txn.balanceAfter)),
                    style: TextStyle(fontSize: 10, color: c.textHint),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
