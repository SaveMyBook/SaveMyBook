part of '../api_service.dart';

extension OrdersApi on ApiService {
  Future<List<Order>> fetchOrders({required String role, required String tab}) async {
    final res = await _send('GET', '/orders', query: {'role': role, 'tab': tab, 'limit': '50'});
    return _mapList(res, Order.fromJson);
  }

  Future<Order?> fetchOrderDetail(int orderId) async {
    final res = await _send('GET', '/orders/$orderId');
    if (res == null || res['success'] != true || res['data'] is! Map) return null;
    return Order.fromJson(Map<String, dynamic>.from(res['data']));
  }

  Future<String?> checkout(List<int> cartIds) async {
    final res = await _send('POST', '/orders/checkout', body: {'cart_ids': cartIds});
    if (res == null) return S.pleaseSignFirst;
    if (res['success'] != true) {
      return res['code'] == 'VERIFICATION_CANCELLED' ? '' : (res['message'] as String? ?? S.checkoutFailed);
    }
    unawaited(fetchCartBookIds());
    return null;
  }

  Future<String?> cancelOrder(int orderId, {String? reason}) async {
    final res = await _send('PATCH', '/orders/$orderId/cancel', body: {'reason': reason});
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.couldNotCancelOrder);
  }

  Future<String?> updateOrderStatus(int orderId, String status) async {
    final res = await _send('PATCH', '/orders/$orderId/status', body: {'status': status});
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.couldNotUpdateOrder);
  }

  Future<List<Map<String, dynamic>>> fetchCabinets({double? latitude, double? longitude}) async {
    final res = await _send('GET', '/cabinets', query: {
      if (latitude != null && longitude != null) 'lat': latitude.toStringAsFixed(6),
      if (latitude != null && longitude != null) 'lng': longitude.toStringAsFixed(6),
    });
    final data = res?['data'];
    if (res?['success'] != true || data is! List) return [];
    return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<List<String>> uploadFiles(List<String> filePaths) async {
    if (filePaths.isEmpty) return [];
    final res = await _sendMultipart('/uploads', [for (final path in filePaths) ('files', path)]);
    final urls = res?['data'] is Map ? res!['data']['urls'] : null;
    if (res?['success'] != true || urls is! List) return [];
    return urls.map((e) => e.toString()).toList();
  }

  Future<String?> submitDispute({required int orderId, required String reason, List<String>? evidenceUrls}) async {
    final res = await _send('POST', '/disputes', body: {
      'order_id': orderId,
      'reason': reason,
      'evidence_urls': evidenceUrls,
    });
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.couldNotSubmitDispute);
  }
}
