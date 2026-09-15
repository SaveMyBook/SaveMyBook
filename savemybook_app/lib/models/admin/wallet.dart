import '../../utils/api_helpers.dart';
import '../../utils/app_labels.dart';

class AdminWallet {
  final int userId;
  final String nickname;
  final String email;
  final String? avatarUrl;
  final double balance;
  final double frozenAmount;
  final double totalIncome;
  final double totalExpense;

  AdminWallet({
    required this.userId,
    required this.nickname,
    required this.email,
    required this.balance,
    required this.frozenAmount,
    required this.totalIncome,
    required this.totalExpense,
    this.avatarUrl,
  });

  factory AdminWallet.fromJson(Map<String, dynamic> json) {
    return AdminWallet(
      userId: parseInt(json['user_id']),
      nickname: json['nickname'] as String? ?? '',
      email: json['email'] as String? ?? '',
      avatarUrl: resolveAssetUrl(json['avatar_url']),
      balance: parseDouble(json['balance']),
      frozenAmount: parseDouble(json['frozen_amount']),
      totalIncome: parseDouble(json['total_income']),
      totalExpense: parseDouble(json['total_expense']),
    );
  }
}

class AdminWalletTxn {
  final int txnId;
  final String type;
  final double amount;
  final double balanceAfter;
  final String description;
  final DateTime? createdAt;

  AdminWalletTxn({
    required this.txnId,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    required this.description,
    this.createdAt,
  });

  String get typeText => AppLabels.walletTxnType[type] ?? type;

  factory AdminWalletTxn.fromJson(Map<String, dynamic> json) {
    return AdminWalletTxn(
      txnId: parseInt(json['txn_id']),
      type: json['type'] as String? ?? '',
      amount: parseDouble(json['amount']),
      balanceAfter: parseDouble(json['balance_after']),
      description: json['description'] as String? ?? '',
      createdAt: parseDate(json['created_at']),
    );
  }
}

class AdminWalletDetail {
  final AdminWallet wallet;
  final List<AdminWalletTxn> transactions;

  AdminWalletDetail({required this.wallet, required this.transactions});

  factory AdminWalletDetail.fromJson(Map<String, dynamic> json) {
    return AdminWalletDetail(
      wallet: AdminWallet.fromJson(json),
      transactions: ((json['transactions'] as List?) ?? const [])
          .map((e) => AdminWalletTxn.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}
