import 'package:flutter/material.dart';
import '../models/wallet.dart';
import '../services/api_service.dart';
import '../utils/api_helpers.dart';
import '../utils/app_colors.dart';
import '../widgets/animations.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_header.dart';
import '../widgets/state_views.dart';
import 'dispute_screen.dart';
import 'pending_income_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          const AppHeader(title: '代幣中心', icon: Icons.monetization_on_outlined),
          Expanded(
            child: SwitchIn(child: _isLoading
                ? const LoadingView.list()
                : RefreshIndicator(
                    color: c.accent,
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                      children: [
                        _buildBalanceCard(c),
                        const SizedBox(height: 24),
                        Text(
                          '交易紀錄',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary),
                        ),
                        const SizedBox(height: 6),
                        Divider(color: c.divider),
                        const SizedBox(height: 8),
                        if (_transactions.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 40),
                            child: EmptyView(icon: Icons.receipt_outlined, message: '尚無交易紀錄'),
                          )
                        else
                          ..._transactions.map((t) => _buildTransaction(t, c)),
                      ],
                    ),
                  )),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(AppColors c) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Text('目前餘額', style: TextStyle(fontSize: 14, color: c.textSecondary)),
          const SizedBox(height: 14),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: c.accent, width: 3),
            ),
            child: Center(
              child: Text(
                '\$',
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: c.accent),
              ),
            ),
          ),
          const SizedBox(height: 10),
          AnimatedCount(
            value: _wallet.balance,
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: c.textPrimary),
          ),
          if (_wallet.frozenAmount > 0) ...[
            const SizedBox(height: 4),
            Text(
              '凍結中 \$${_wallet.frozenAmount.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 12, color: Colors.orangeAccent),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              QuickActionButton(
                icon: Icons.query_stats_rounded,
                label: '待定收益',
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PendingIncomeScreen()),
                  );
                  _load();
                },
              ),
              QuickActionButton(
                icon: Icons.gavel_rounded,
                label: '爭議處理',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DisputeScreen()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransaction(WalletTransaction t, AppColors c) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          BookThumbnail(imageUrl: t.bookImageUrl, width: 52, height: 66, radius: 8),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.bookTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary),
                ),
                const SizedBox(height: 6),
                Text(
                  t.description.isEmpty ? t.typeText : t.description,
                  style: TextStyle(fontSize: 12, color: c.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${t.isIncome ? '+' : '-'}\$${t.amount.abs().toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: t.isIncome ? c.success : c.danger,
                ),
              ),
              const SizedBox(height: 8),
              Text(formatDate(t.createdAt), style: TextStyle(fontSize: 11, color: c.textHint)),
            ],
          ),
        ],
      ),
    );
  }
}
