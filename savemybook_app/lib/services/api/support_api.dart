part of '../api_service.dart';

extension SupportApi on ApiService {
  Future<List<FaqItem>> fetchFaqs() async {
    final res = await _send('GET', '/support/faqs');
    return _mapList(res, FaqItem.fromJson);
  }

  Future<List<SupportTicket>> fetchMyTickets() async {
    final res = await _send('GET', '/support/tickets');
    return _mapList(res, SupportTicket.fromJson);
  }

  Future<SupportTicket?> fetchTicket(int ticketId) async {
    final res = await _send('GET', '/support/tickets/$ticketId');
    if (res == null || res['success'] != true || res['data'] is! Map) return null;
    return SupportTicket.fromJson(Map<String, dynamic>.from(res['data']));
  }

  Future<String?> createTicket({
    required String subject,
    required String category,
    required String content,
    List<String> attachments = const [],
  }) async {
    final res = await _send('POST', '/support/tickets', body: {
      'subject': subject,
      'category': category,
      'content': content,
      if (attachments.isNotEmpty) 'attachments': attachments,
    });
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.couldNotSend);
  }

  Future<String?> replyTicket(int ticketId, String content, {List<String> attachments = const []}) async {
    final res = await _send('POST', '/support/tickets/$ticketId/messages', body: {
      'content': content,
      if (attachments.isNotEmpty) 'attachments': attachments,
    });
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.couldNotSend);
  }

  Future<(String?, String?)> uploadSupportImage(String filePath, {ValueChanged<double>? onProgress}) async {
    final res = await _sendMultipart('/uploads/support-image', [('file', filePath)], onProgress: onProgress);
    final url = res?['data'] is Map ? res!['data']['url'] as String? : null;
    return url == null ? (null, res?['message'] as String? ?? S.uploadFailedTryAgainLater) : (url, null);
  }

  Future<String?> closeTicket(int ticketId) async {
    final res = await _send('PATCH', '/support/tickets/$ticketId/close');
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.actionFailed);
  }
}
