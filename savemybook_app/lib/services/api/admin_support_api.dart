part of '../api_service.dart';

extension AdminSupportApi on ApiService {
  /// 由 AI 客服轉接的工單預填常見問題；其他工單回傳錯誤訊息。
  Future<(FaqDraft?, String?)> fetchFaqDraft(int ticketId) async {
    final res = await _send('GET', '/admin/tickets/$ticketId/faq-draft');
    if (res == null) return (null, S.pleaseSignFirst);
    final data = res['data'];
    if (res['success'] != true || data is! Map) return (null, res['message'] as String? ?? S.loadFailed);
    return (FaqDraft.fromJson(Map<String, dynamic>.from(data)), null);
  }

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
    int? sourceTicketId,
  }) async {
    final body = {
      'category': category,
      'question': question,
      'answer': answer,
      'sort_order': sortOrder,
      'is_visible': isVisible,
      if (faqId == null && sourceTicketId != null) 'source_ticket_id': sourceTicketId,
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
