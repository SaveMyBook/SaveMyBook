part of '../api_service.dart';

extension LegalApi on ApiService {
  Future<List<LegalDoc>> fetchLegalDocList() async {
    final res = await _send('GET', '/support/legal');
    return _mapList(res, LegalDoc.fromJson);
  }

  Future<List<LegalDoc>?> fetchPendingConsents() async {
    final res = await _send('GET', '/users/me/legal-consents/pending');
    if (res == null || res['success'] != true) return null;
    return _mapList(res, LegalDoc.fromJson);
  }

  Future<String?> acceptLegalDoc(LegalDoc doc) async {
    final res = await _send('POST', '/users/me/legal-consents', body: {'doc_key': doc.key, 'version': doc.version});
    if (res == null) return S.networkError;
    return res['success'] == true ? null : (res['message'] as String? ?? S.somethingWentWrongPleaseTryAgain);
  }

  Future<LegalDoc?> fetchLegalDoc(String key) async {
    final res = await _send('GET', '/support/legal/$key');
    if (res == null || res['success'] != true || res['data'] is! Map) return null;
    return LegalDoc.fromJson(Map<String, dynamic>.from(res['data']));
  }

  Future<List<LegalDoc>> fetchAdminLegalDocs() async {
    final res = await _send('GET', '/admin/legal');
    return _mapList(res, LegalDoc.fromJson);
  }

  Future<({String? error, String message})> saveLegalDoc(
    String key, {
    required String title,
    required String content,
    bool major = false,
  }) async {
    final res = await _send('PUT', '/admin/legal/$key', body: {
      'title': title,
      'content': content,
      'major': major,
    });
    if (res == null) return (error: S.pleaseSignFirst, message: '');
    if (res['success'] != true) {
      return (error: res['message'] as String? ?? S.couldNotSave2, message: '');
    }
    return (error: null, message: res['message'] as String? ?? S.documentUpdated);
  }
}
