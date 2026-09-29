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

  Future<({List<ReportedMessage> before, List<ReportedMessage> after})?> fetchReportMessageContext(int reportId) async {
    final res = await _send('GET', '/admin/reports/$reportId/message-context');
    final data = res?['success'] == true ? res!['data'] : null;
    if (data is! Map) return null;
    List<ReportedMessage> list(Object? raw) => [
          for (final item in raw is List ? raw : const [])
            if (item is Map) ReportedMessage.fromJson(Map<String, dynamic>.from(item)),
        ];
    return (before: list(data['before']), after: list(data['after']));
  }

  Future<List<ChatRiskAlert>> fetchChatRiskAlerts({String status = 'open'}) async {
    final res = await _send('GET', '/admin/chat-risk-alerts', query: {'status': status});
    return _mapList(res, ChatRiskAlert.fromJson);
  }

  Future<String?> handleChatRiskAlert(int alertId, {required bool dismiss}) async {
    final res = await _send('PATCH', '/admin/chat-risk-alerts/$alertId', body: {'action': dismiss ? 'dismiss' : 'resolve'});
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.actionFailed);
  }

  Future<List<DisputeCase>> fetchAdminDisputes({String? status}) async {
    final res = await _send('GET', '/admin/disputes', query: {'status': ?status});
    return _mapList(res, DisputeCase.fromJson);
  }

  /// 最近一次保存的分析結果，不呼叫模型；尚未分析時結果為 null。
  Future<(DisputeAnalysis?, String?)> fetchDisputeAnalysis(int disputeId) async {
    final res = await _send('GET', '/admin/disputes/$disputeId/ai-analysis');
    if (res == null) return (null, S.pleaseSignFirst);
    if (res['success'] != true) return (null, res['message'] as String? ?? S.loadFailed);
    final data = res['data'];
    return (data is Map ? DisputeAnalysis.fromJson(Map<String, dynamic>.from(data)) : null, null);
  }

  Future<String?> rateDisputeAnalysis(int disputeId, {required String analysisNo, required bool helpful}) async {
    final res = await _send('PATCH', '/admin/disputes/$disputeId/ai-analysis', body: {'analysis_no': analysisNo, 'helpful': helpful});
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.actionFailed);
  }

  Future<(DisputeAnalysis?, String?, String?)> analyzeDispute(int disputeId) async {
    final res = await _send('POST', '/admin/disputes/$disputeId/ai-analysis');
    if (res == null) return (null, S.pleaseSignFirst, null);
    if (res['success'] != true || res['data'] is! Map) {
      return (null, res['message'] as String? ?? S.loadFailed, res['code'] as String?);
    }
    return (DisputeAnalysis.fromJson(Map<String, dynamic>.from(res['data'])), null, null);
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

  Future<({String? error, bool hidden, String? status, bool? isApproved})> setBookStatusAsAdmin(
    int bookId,
    String status, {
    String? reason,
  }) async {
    final res = await _send('PATCH', '/admin/books/$bookId', body: {
      'status': status,
      'reason': reason,
    });
    if (res == null) return (error: S.pleaseSignFirst, hidden: false, status: null, isApproved: null);
    if (res['success'] != true) {
      return (error: res['message'] as String? ?? S.actionFailed, hidden: false, status: null, isApproved: null);
    }
    final data = res['data'] is Map ? Map<String, dynamic>.from(res['data'] as Map) : const <String, dynamic>{};
    return (
      error: null,
      hidden: data['hidden'] == true,
      status: data['status'] as String?,
      isApproved: data['is_approved'] is bool ? data['is_approved'] as bool : null,
    );
  }

  Future<String?> deleteBookAsAdmin(int bookId, {String? reason}) async {
    final trimmed = reason?.trim();
    final res = await _send(
      'DELETE',
      '/admin/books/$bookId',
      body: trimmed == null || trimmed.isEmpty ? null : {'reason': trimmed},
    );
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.couldNotDelete);
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
