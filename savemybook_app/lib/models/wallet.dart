import '../utils/api_helpers.dart';
import '../i18n/strings.dart';

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
  final int? orderId;
  final String? orderNo;

  WalletTransaction({
    required this.txnId,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    required this.description,
    required this.bookTitle,
    this.bookImageUrl,
    this.createdAt,
    this.orderId,
    this.orderNo,
  });

  // 退款時向賣家收回貨款的紀錄類型也是 refund，但金額是負的，只能依正負判斷。
  bool get isIncome => amount > 0;

  String get typeText {
    switch (type) {
      case 'deposit': return S.txnDeposit;
      case 'withdrawal': return S.txnWithdrawal;
      case 'purchase': return S.purchase;
      case 'sale_income': return S.sale;
      case 'refund': return S.txnRefund;
      case 'admin_adjust': return S.systemAdjustment;
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
      bookTitle: book?['title'] as String? ?? order?['order_no'] as String? ?? S.faqCatTrade,
      bookImageUrl: images.isEmpty ? null : resolveAssetUrl((images.first as Map)['image_url']),
      createdAt: parseDate(json['created_at']),
      orderId: order?['order_id'] == null ? null : parseInt(order!['order_id']),
      orderNo: order?['order_no'] as String?,
    );
  }
}
