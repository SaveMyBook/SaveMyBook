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

  Future<Order?> fetchOrderDetailByNo(String orderNo) async {
    final res = await _send('GET', '/orders/by-no/${Uri.encodeComponent(orderNo)}');
    if (res == null || res['success'] != true || res['data'] is! Map) return null;
    return Order.fromJson(Map<String, dynamic>.from(res['data']));
  }

  Future<({String? error, bool readyForPickup})> checkout(List<int> cartIds) =>
      _placeOrder('/orders/checkout', {'cart_ids': cartIds});

  Future<({String? error, bool readyForPickup})> buyNow(int bookId) =>
      _placeOrder('/orders/buy-now', {'book_id': bookId});

  Future<({String? error, bool readyForPickup})> _placeOrder(String path, Map<String, Object?> body) async {
    final res = await _send('POST', path, body: body);
    if (res == null) return (error: S.pleaseSignFirst, readyForPickup: false);
    if (res['success'] != true) {
      final error = switch (res['code']) {
        'VERIFICATION_CANCELLED' => '',
        'ORDER_BOOK_LIMIT' => S.orderBookLimitP0(res['max_books'] ?? Order.maxBooks),
        _ => res['message'] as String? ?? S.checkoutFailed,
      };
      return (error: error, readyForPickup: false);
    }
    unawaited(fetchCartBookIds());
    final data = res['data'];
    final orders = data is List ? data : [data];
    final ready = orders.isNotEmpty && orders.every((o) => o is Map && o['status'] == 'deposited');
    return (error: null, readyForPickup: ready);
  }

  Future<String?> cancelOrder(int orderId, {String? reason}) async {
    final res = await _send('PATCH', '/orders/$orderId/cancel', body: {'reason': reason});
    if (res == null) return S.pleaseSignFirst;
    if (res['success'] == true) return null;
    if (res['code'] == 'ORDER_IN_CABINET_SESSION') return S.orderBeingHandledLockerPleaseTry;
    return res['message'] as String? ?? S.couldNotCancelOrder;
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

  Future<String?> submitDispute({required String orderNo, required String reason, List<String>? evidenceUrls}) async {
    final res = await _send('POST', '/disputes', body: {
      'order_no': orderNo,
      'reason': reason,
      'evidence_urls': evidenceUrls,
    });
    if (res == null) return S.pleaseSignFirst;
    if (res['success'] == true) return null;
    if (res['code'] == 'ORDER_IN_CABINET_SESSION') return S.orderBeingHandledLockerPleaseTry;
    return res['message'] as String? ?? S.couldNotSubmitDispute;
  }
}
