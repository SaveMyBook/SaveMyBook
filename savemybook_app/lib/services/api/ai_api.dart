part of '../api_service.dart';

extension AiApi on ApiService {
  AiResult<T> _aiFail<T>(Map<String, dynamic>? res, String fallback) {
    if (res == null) return AiResult.fail(S.pleaseSignFirst);
    return AiResult.fail(res['message'] as String? ?? fallback, code: res['code'] as String?, timedOut: res['timeout'] == true);
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
    final res = await _send('PUT', '/ai/consent', body: {'granted': granted, if (granted) 'notice_version': aiConsentNoticeVersion});
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

  Future<AiResult<AiSupportReply>> sendAiSupportMessage(String content, {required String clientId, String? locale}) async {
    final res = await _send('POST', '/ai/support/messages', body: {'content': content, 'client_id': clientId, 'locale': ?locale});
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

  Future<AiResult<AiBookChatReply>> sendAiBookChatMessage(String content, {required String clientId}) async {
    final res = await _send('POST', '/ai/book-chat/messages', body: {'content': content, 'client_id': clientId});
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
    AiConditionRequest? condition,
  }) async {
    final prepared = await AiImagePrep.prepareAll(imagePaths.take(4));
    String? text(String? value) => value != null && value.trim().isNotEmpty ? value.trim() : null;
    final res = await _sendMultipart(
      '/ai/listing-assist',
      [for (final path in prepared) ('images', path)],
      fields: {
        if (isbn != null && isbn.isNotEmpty) 'isbn': isbn,
        if (title != null && title.isNotEmpty) 'title': title,
        if (conditionNote != null && conditionNote.isNotEmpty) 'condition_note': conditionNote,
        if (condition != null) ...{
          'mode': 'condition',
          if (text(condition.author) != null) 'author': text(condition.author)!,
          if (text(condition.publisher) != null) 'publisher': text(condition.publisher)!,
          if (text(condition.publishDate) != null) 'publish_date': text(condition.publishDate)!,
          if (condition.categoryId != null) 'category_id': '${condition.categoryId}',
          if (condition.originalPrice != null) 'original_price': '${condition.originalPrice}',
          if (text(condition.followupToken) != null) 'followup_token': text(condition.followupToken)!,
        },
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

  Future<AiRecommendations?> fetchAiRecommendations({int limit = 12, Iterable<int> viewedIds = const []}) async {
    final query = <String, String>{'limit': '$limit'};
    final ids = viewedIds.where((id) => id > 0).take(20);
    if (ids.isNotEmpty) query['viewed_ids'] = ids.join(',');
    final res = await _send('GET', '/ai/recommendations', query: query);
    if (res == null || res['success'] != true) return null;
    return AiRecommendations.fromJson(res);
  }

  Future<AiResult<AiMessageFeedback?>> rateAiMessage(String feature, String messageNo, {String? rating, String? reason}) async {
    final path = feature == 'book_chat' ? '/ai/book-chat/messages' : '/ai/support/messages';
    final res = await _send('PUT', '$path/${Uri.encodeComponent(messageNo)}/feedback', body: {'rating': rating, 'reason': reason});
    if (res == null || res['success'] != true) return _aiFail(res, S.actionFailed);
    return AiResult.ok(AiMessageFeedback.fromJson(_dataMap(res)?['feedback']));
  }

  Future<void> logRecommendationClick(int bookId) async {
    if (ApiService.authToken == null) return;
    await _send('POST', '/ai/recommendations/clicks', body: {'book_id': bookId});
  }

  Future<String?> dismissRecommendation(int bookId) async {
    final res = await _send('POST', '/ai/recommendations/dismissals', body: {'book_id': bookId});
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.actionFailed);
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

  Future<AiResult<AiTestResult>> testAiProvider(String provider, {String? model}) async {
    final res = await _send('POST', '/admin/ai/test', body: {
      'provider': provider,
      if (model != null && model.trim().isNotEmpty) 'model': model.trim(),
    });
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

  Future<AiResult<AiDecisionReport>> fetchAiDecisions(String period) async {
    final res = await _send('GET', '/admin/ai/decisions', query: {'period': period});
    if (res == null || res['success'] != true) return _aiFail(res, S.loadFailed);
    final data = _dataMap(res);
    if (data == null) return AiResult.fail(S.loadFailed);
    return AiResult.ok(AiDecisionReport.fromJson(data));
  }

  Future<AiResult<AiQualityReport>> fetchAiQuality(String period) async {
    final res = await _send('GET', '/admin/ai/quality', query: {'period': period});
    if (res == null || res['success'] != true) return _aiFail(res, S.loadFailed);
    final data = _dataMap(res);
    if (data == null) return AiResult.fail(S.loadFailed);
    return AiResult.ok(AiQualityReport.fromJson(data));
  }

  Future<AiResult<List<AiReviewItem>>> fetchAiReviews({String status = 'pending'}) async {
    final res = await _send('GET', '/admin/ai/reviews', query: {'status': status});
    if (res == null || res['success'] != true) return _aiFail(res, S.loadFailed);
    return AiResult.ok(_mapList(res, AiReviewItem.fromJson));
  }

  Future<AiResult<bool>> clearIsbnCache(String isbn) async {
    final res = await _send('DELETE', '/admin/ai/isbn-cache/${Uri.encodeComponent(isbn)}');
    if (res == null || res['success'] != true) return _aiFail(res, S.actionFailed);
    return AiResult.ok(_dataMap(res)?['removed'] == true);
  }

  Future<String?> decideAiReview(int bookId, {required bool approve, String? note, String? category, bool unfounded = false}) async {
    final res = await _send('PATCH', '/admin/ai/reviews/$bookId', body: {
      'decision': approve ? 'approve' : 'reject',
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      if (!approve && category != null) 'category': category,
      if (approve && unfounded) 'unfounded': true,
    });
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.actionFailed);
  }
}
