part of '../api_service.dart';

extension AiApi on ApiService {
  AiResult<T> _aiFail<T>(Map<String, dynamic>? res, String fallback) {
    if (res == null) return AiResult.fail(S.pleaseSignFirst);
    return AiResult.fail(res['message'] as String? ?? fallback, code: res['code'] as String?);
  }

  Map<String, dynamic>? _dataMap(Map<String, dynamic>? res) {
    final data = res?['data'];
    return data is Map ? Map<String, dynamic>.from(data) : null;
  }

  Future<AiStatusInfo?> fetchAiStatus() async {
    if (ApiService.authToken == null) return null;
    final res = await _send('GET', '/ai/status');
    if (res == null || res['success'] != true) return res == null ? null : AiStatusInfo.none;
    final data = _dataMap(res);
    return data == null ? AiStatusInfo.none : AiStatusInfo.fromJson(data);
  }

  Future<AiResult<AiStatusInfo>> setAiConsent(bool granted) async {
    final res = await _send('PUT', '/ai/consent', body: {'granted': granted});
    if (res == null || res['success'] != true) return _aiFail(res, S.actionFailed);
    final data = _dataMap(res);
    return AiResult.ok(data == null ? AiStatusInfo.none : AiStatusInfo.fromJson(data));
  }

  Future<AiResult<AiSupportSession?>> fetchAiSupportSession() async {
    final res = await _send('GET', '/ai/support/session');
    if (res == null || res['success'] != true) return _aiFail(res, S.loadFailed);
    final data = _dataMap(res);
    return AiResult.ok(data == null ? null : AiSupportSession.fromJson(data));
  }

  Future<AiResult<AiSupportReply>> sendAiSupportMessage(String content) async {
    final res = await _send('POST', '/ai/support/messages', body: {'content': content});
    if (res == null || res['success'] != true) return _aiFail(res, S.couldNotSend);
    final data = _dataMap(res);
    if (data == null) return AiResult.fail(S.couldNotSend);
    return AiResult.ok(AiSupportReply.fromJson(data));
  }

  Future<AiResult<int>> escalateAiSupport({String? subject}) async {
    final res = await _send('POST', '/ai/support/session/escalate', body: {if (subject != null && subject.isNotEmpty) 'subject': subject});
    if (res == null || res['success'] != true) return _aiFail(res, S.actionFailed);
    final ticketId = parseInt(_dataMap(res)?['ticket_id']);
    return ticketId > 0 ? AiResult.ok(ticketId) : AiResult.fail(S.actionFailed);
  }

  Future<String?> closeAiSupportSession() async {
    final res = await _send('POST', '/ai/support/session/close');
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.actionFailed);
  }

  Future<AiResult<AiBookChatSession?>> fetchAiBookChatSession() async {
    final res = await _send('GET', '/ai/book-chat/session');
    if (res == null || res['success'] != true) return _aiFail(res, S.loadFailed);
    final data = _dataMap(res);
    return AiResult.ok(data == null ? null : AiBookChatSession.fromJson(data));
  }

  Future<AiResult<AiBookChatReply>> sendAiBookChatMessage(String content) async {
    final res = await _send('POST', '/ai/book-chat/messages', body: {'content': content});
    if (res == null || res['success'] != true) return _aiFail(res, S.couldNotSend);
    final data = _dataMap(res);
    if (data == null) return AiResult.fail(S.couldNotSend);
    return AiResult.ok(AiBookChatReply.fromJson(data));
  }

  Future<String?> closeAiBookChatSession() async {
    final res = await _send('POST', '/ai/book-chat/session/close');
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.actionFailed);
  }

  Future<AiResult<AiListingAssist>> requestListingAssist({
    String? isbn,
    String? title,
    String? conditionNote,
    List<String> imagePaths = const [],
  }) async {
    final prepared = await AiImagePrep.prepareAll(imagePaths.take(4));
    final res = await _sendMultipart(
      '/ai/listing-assist',
      [for (final path in prepared) ('images', path)],
      fields: {
        if (isbn != null && isbn.isNotEmpty) 'isbn': isbn,
        if (title != null && title.isNotEmpty) 'title': title,
        if (conditionNote != null && conditionNote.isNotEmpty) 'condition_note': conditionNote,
      },
    );
    for (final path in prepared) {
      if (!imagePaths.contains(path)) File(path).delete().ignore();
    }
    if (res == null || res['success'] != true) return _aiFail(res, S.somethingWentWrongPleaseTryAgain);
    final data = _dataMap(res);
    if (data == null) return AiResult.fail(S.somethingWentWrongPleaseTryAgain);
    return AiResult.ok(AiListingAssist.fromJson(data));
  }

  Future<AiRecommendations?> fetchAiRecommendations({int limit = 12}) async {
    final res = await _send('GET', '/ai/recommendations', query: {'limit': '$limit'});
    if (res == null || res['success'] != true) return null;
    return AiRecommendations.fromJson(res);
  }

  Future<AiResult<AiSettingsBundle>> fetchAiSettings() async {
    final res = await _send('GET', '/admin/ai/settings');
    if (res == null || res['success'] != true) return _aiFail(res, S.loadFailed);
    final data = _dataMap(res);
    if (data == null) return AiResult.fail(S.loadFailed);
    return AiResult.ok(AiSettingsBundle.fromJson(data));
  }

  Future<AiResult<AiSettingsBundle>> saveAiSettings(AiSettings settings) async {
    final res = await _send('PUT', '/admin/ai/settings', body: {'settings': settings.toJson()});
    if (res == null || res['success'] != true) return _aiFail(res, S.somethingWentWrongPleaseTryAgain);
    final data = _dataMap(res);
    return AiResult.ok(data == null ? null : AiSettingsBundle.fromJson(data));
  }

  Future<AiResult<AiTestResult>> testAiProvider(String provider) async {
    final res = await _send('POST', '/admin/ai/test', body: {'provider': provider});
    if (res == null || res['success'] != true) return _aiFail(res, S.somethingWentWrongPleaseTryAgain);
    final data = _dataMap(res);
    if (data == null) return AiResult.fail(S.somethingWentWrongPleaseTryAgain);
    return AiResult.ok(AiTestResult.fromJson(data));
  }

  Future<AiResult<AiUsageReport>> fetchAiUsage(String period) async {
    final res = await _send('GET', '/admin/ai/usage', query: {'period': period});
    if (res == null || res['success'] != true) return _aiFail(res, S.loadFailed);
    final data = _dataMap(res);
    if (data == null) return AiResult.fail(S.loadFailed);
    return AiResult.ok(AiUsageReport.fromJson(data));
  }

  Future<AiResult<List<AiReviewItem>>> fetchAiReviews({String status = 'pending'}) async {
    final res = await _send('GET', '/admin/ai/reviews', query: {'status': status});
    if (res == null || res['success'] != true) return _aiFail(res, S.loadFailed);
    return AiResult.ok(_mapList(res, AiReviewItem.fromJson));
  }

  Future<String?> decideAiReview(int bookId, {required bool approve, String? note}) async {
    final res = await _send('PATCH', '/admin/ai/reviews/$bookId', body: {
      'decision': approve ? 'approve' : 'reject',
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.actionFailed);
  }
}
