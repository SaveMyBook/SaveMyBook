import '../utils/api_helpers.dart';

class Wallet {
  final double balance;
  final double frozenAmount;
  final double totalIncome;
  final double totalExpense;
  final double pendingIncome;

  Wallet({
    required this.balance,
    required this.frozenAmount,
    required this.totalIncome,
    required this.totalExpense,
    required this.pendingIncome,
  });

  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      balance: parseDouble(json['balance']),
      frozenAmount: parseDouble(json['frozen_amount']),
      totalIncome: parseDouble(json['total_income']),
      totalExpense: parseDouble(json['total_expense']),
      pendingIncome: parseDouble(json['pending_income']),
    );
  }

  static Wallet get empty => Wallet(
        balance: 0,
        frozenAmount: 0,
        totalIncome: 0,
        totalExpense: 0,
        pendingIncome: 0,
      );
}

class WalletTransaction {
  final int txnId;
  final String type;
  final double amount;
  final double balanceAfter;
  final String description;
  final String bookTitle;
  final String? bookImageUrl;
  final DateTime? createdAt;

  WalletTransaction({
    required this.txnId,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    required this.description,
    required this.bookTitle,
    this.bookImageUrl,
    this.createdAt,
  });

  bool get isIncome => type == 'sale_income' || type == 'deposit' || type == 'refund';

  String get typeText {
    switch (type) {
      case 'deposit': return '儲值';
      case 'withdrawal': return '提領';
      case 'purchase': return '購買';
      case 'sale_income': return '賣出';
      case 'refund': return '退款';
      case 'admin_adjust': return '系統調整';
      default: return type;
    }
  }

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    final order = json['orders'] as Map<String, dynamic>?;
    final items = (order?['order_items'] as List?) ?? const [];
    final book = items.isEmpty ? null : (items.first as Map)['books'] as Map?;
    final images = (book?['book_images'] as List?) ?? const [];

    return WalletTransaction(
      txnId: parseInt(json['txn_id']),
      type: json['type'] as String? ?? 'sale_income',
      amount: parseDouble(json['amount']),
      balanceAfter: parseDouble(json['balance_after']),
      description: json['description'] as String? ?? '',
      bookTitle: book?['title'] as String? ?? order?['order_no'] as String? ?? '交易',
      bookImageUrl: images.isEmpty ? null : resolveAssetUrl((images.first as Map)['image_url']),
      createdAt: parseDate(json['created_at']),
    );
  }
}
