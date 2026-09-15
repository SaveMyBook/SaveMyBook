part of '../api_service.dart';

extension WalletApi on ApiService {
  Future<Wallet> fetchWallet() async {
    final res = await _send('GET', '/wallet');
    if (res == null || res['success'] != true || res['data'] is! Map) return Wallet.empty;
    return Wallet.fromJson(Map<String, dynamic>.from(res['data']));
  }

  Future<List<WalletTransaction>> fetchWalletTransactions() async {
    final res = await _send('GET', '/wallet/transactions', query: {'limit': '50'});
    return _mapList(res, WalletTransaction.fromJson);
  }

  Future<({List<Order> orders, double total})> fetchPendingIncome() async {
    final res = await _send('GET', '/wallet/pending');
    final orders = _mapList(res, Order.fromJson);
    final total = double.tryParse('${res?['total_amount'] ?? 0}') ?? 0;
    return (orders: orders, total: total);
  }
}
