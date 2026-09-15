part of '../api_service.dart';

extension AdminSupportApi on ApiService {
  Future<List<FaqItem>> fetchAdminFaqs() async {
    final res = await _send('GET', '/admin/faqs');
    return _mapList(res, FaqItem.fromJson);
  }

  Future<String?> saveFaq({
    int? faqId,
    required String category,
    required String question,
    required String answer,
    int sortOrder = 0,
    bool isVisible = true,
  }) async {
    final body = {
      'category': category,
      'question': question,
      'answer': answer,
      'sort_order': sortOrder,
      'is_visible': isVisible,
    };
    final res = faqId == null
        ? await _send('POST', '/admin/faqs', body: body)
        : await _send('PUT', '/admin/faqs/$faqId', body: body);
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.couldNotSave2);
  }

  Future<String?> reorderFaqs(List<int> orderedIds) async {
    final res = await _send('PUT', '/admin/faqs/reorder', body: {'order': orderedIds});
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.couldNotReorder);
  }

  Future<String?> deleteFaq(int faqId) async {
    final res = await _send('DELETE', '/admin/faqs/$faqId');
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.couldNotDelete);
  }

  Future<List<SupportTicket>> fetchAdminTickets({String? status}) async {
    final res = await _send('GET', '/admin/tickets', query: {
      if (status != null && status != 'all') 'status': status,
    });
    return _mapList(res, SupportTicket.fromJson);
  }

  Future<String?> updateTicketStatus(int ticketId, String status) async {
    final res = await _send('PATCH', '/admin/tickets/$ticketId/status', body: {'status': status});
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.updateFailed2);
  }
}
