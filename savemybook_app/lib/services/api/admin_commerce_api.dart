part of '../api_service.dart';

extension AdminCommerceApi on ApiService {
  Future<List<ReportCase>> fetchAdminReports({String? status}) async {
    final res = await _send('GET', '/admin/reports', query: {'status': ?status});
    return _mapList(res, ReportCase.fromJson);
  }

  Future<String?> resolveReport(int reportId, {required String status, String? adminNote, bool removeTarget = false}) async {
    final res = await _send('PATCH', '/admin/reports/$reportId', body: {
      'status': status,
      'admin_note': adminNote,
      'remove_target': removeTarget,
    });
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.couldNotProcessReport);
  }

  Future<List<DisputeCase>> fetchAdminDisputes({String? status}) async {
    final res = await _send('GET', '/admin/disputes', query: {'status': ?status});
    return _mapList(res, DisputeCase.fromJson);
  }

  Future<String?> arbitrateDispute(int disputeId, {required String result, String? adminNote}) async {
    final res = await _send('PATCH', '/admin/disputes/$disputeId', body: {
      'result': result,
      'admin_note': adminNote,
    });
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.couldNotRecordDecision);
  }

  Future<List<AdminOrder>> fetchAdminOrders({String keyword = '', String? status}) async {
    final res = await _send('GET', '/admin/orders', query: {
      if (keyword.isNotEmpty) 'keyword': keyword,
      if (status != null && status != 'all') 'status': status,
      'limit': '50',
    });
    return _mapList(res, AdminOrder.fromJson);
  }

  Future<String?> updateOrderStatusAsAdmin(int orderId, String status, {String? note}) async {
    final res = await _send('PATCH', '/admin/orders/$orderId', body: {
      'status': status,
      'note': note,
    });
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.updateFailed2);
  }

  Future<String?> updateAdminBook(int bookId, Map<String, dynamic> fields) async {
    final res = await _send('PUT', '/admin/books/$bookId', body: fields);
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.updateFailed);
  }

  Future<AdminOrderDetail?> fetchAdminOrder(int orderId) async {
    final res = await _send('GET', '/admin/orders/$orderId');
    if (res == null || res['success'] != true || res['data'] is! Map) return null;
    return AdminOrderDetail.fromJson(Map<String, dynamic>.from(res['data']));
  }

  Future<List<AdminBook>> fetchAdminBooks({String keyword = '', String? status}) async {
    final res = await _send('GET', '/admin/books', query: {
      if (keyword.isNotEmpty) 'keyword': keyword,
      if (status != null && status != 'all') 'status': status,
      'limit': '50',
    });
    return _mapList(res, AdminBook.fromJson);
  }

  Future<String?> setBookStatusAsAdmin(int bookId, String status, {String? reason}) async {
    final res = await _send('PATCH', '/admin/books/$bookId', body: {
      'status': status,
      'reason': reason,
    });
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.actionFailed);
  }

  Future<List<AdminCategory>> fetchAdminCategories() async {
    final res = await _send('GET', '/admin/categories');
    return _mapList(res, AdminCategory.fromJson);
  }

  Future<String?> saveCategory({int? categoryId, required String name, int sortOrder = 0}) async {
    final body = {'category_name': name, 'sort_order': sortOrder};
    final res = categoryId == null
        ? await _send('POST', '/admin/categories', body: body)
        : await _send('PUT', '/admin/categories/$categoryId', body: body);
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.couldNotSave2);
  }

  Future<String?> reorderCategories(List<int> orderedIds) async {
    final res = await _send('PUT', '/admin/categories/reorder', body: {'order': orderedIds});
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.couldNotReorder);
  }

  Future<String?> deleteCategory(int categoryId) async {
    final res = await _send('DELETE', '/admin/categories/$categoryId');
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.couldNotDelete);
  }
}
