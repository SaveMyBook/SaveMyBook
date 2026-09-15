part of '../api_service.dart';

extension ReportsApi on ApiService {
  Future<Map<int, String>> fetchReportStatusForMyBooks() async {
    final res = await _send('GET', '/reports/against-me');
    if (res == null || res['success'] != true || res['data'] is! List) return {};

    const priority = {'resolved': 4, 'pending': 3, 'reviewing': 3, 'dismissed': 1};
    final result = <int, String>{};

    for (final item in res['data'] as List) {
      if (item is! Map) continue;
      final bookId = parseInt(item['target_id']);
      final status = item['status'] as String? ?? 'pending';
      final current = result[bookId];
      if (current == null || (priority[status] ?? 0) > (priority[current] ?? 0)) {
        result[bookId] = status;
      }
    }
    return result;
  }

  Future<String?> submitReport({
    required String targetType,
    required int targetId,
    required String reason,
  }) async {
    final res = await _send('POST', '/reports', body: {
      'target_type': targetType,
      'target_id': targetId,
      'reason': reason,
    });
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.couldNotSubmitReport);
  }
}
