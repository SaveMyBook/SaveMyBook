part of '../api_service.dart';

class CabinetResult {
  final CabinetSession? session;
  final CabinetApiError? error;

  const CabinetResult.success(CabinetSession this.session) : error = null;

  const CabinetResult.failure(CabinetApiError this.error) : session = null;

  bool get ok => session != null;
}

class CabinetManualResult {
  final String? error;
  final String? code;
  final CabinetManualReport? report;
  final bool restored;

  const CabinetManualResult({this.error, this.code, this.report, this.restored = false});

  bool get ok => error == null;

  bool get pending => report?.isPending == true;

  bool get scanRequired => code == 'CABINET_SCAN_REQUIRED';
}

extension CabinetApi on ApiService {
  static const cabinetPayloadPrefix = 'savemybook://k/';

  CabinetResult _cabinetResult(Map<String, dynamic>? res) {
    if (res == null) {
      return CabinetResult.failure(CabinetApiError(code: CabinetApiError.signedOut, message: S.pleaseSignFirst));
    }
    if (res['success'] == true) {
      final session = CabinetSession.tryParse(res['data']);
      if (session != null) return CabinetResult.success(session);
      return CabinetResult.failure(CabinetApiError(code: '', message: S.somethingWentWrongPleaseTryAgain));
    }
    if (res['code'] == CabinetApiError.network) {
      return CabinetResult.failure(CabinetApiError(code: CabinetApiError.network, message: S.networkError));
    }
    return CabinetResult.failure(CabinetApiError.fromResponse(res));
  }

  String _sessionPath(String sessionNo) => '/cabinet-sessions/${Uri.encodeComponent(sessionNo)}';

  Future<CabinetResult> createCabinetSession({
    required String code,
    CabinetContext? context,
    required FreshLocation location,
  }) async {
    final token = parseCabinetCode(code);
    if (token == null) {
      return CabinetResult.failure(CabinetApiError(code: 'CABINET_CODE_INVALID', message: '此 QR Code 並非 SaveMyBook 書櫃 QR Code'));
    }
    final res = await _send('POST', '/cabinet-sessions', body: {
      'code': '$cabinetPayloadPrefix$token',
      if (context != null) 'context': context.toJson(),
      ...location.toJson(),
    });
    return _cabinetResult(res);
  }

  Future<CabinetResult> startCabinetSession(String sessionNo, List<String> keys) async {
    final res = await _send('POST', '${_sessionPath(sessionNo)}/start', body: {'keys': keys});
    return _cabinetResult(res);
  }

  Future<CabinetResult> fetchCabinetSession(String sessionNo) async {
    final res = await _send('GET', _sessionPath(sessionNo));
    return _cabinetResult(res);
  }

  Future<CabinetResult> cancelCabinetSession(String sessionNo) async {
    final res = await _send('POST', '${_sessionPath(sessionNo)}/cancel');
    return _cabinetResult(res);
  }

  Future<CabinetSession?> fetchActiveCabinetSession() async {
    final res = await _send('GET', '/cabinet-sessions/active');
    if (res == null || res['success'] != true) return null;
    return CabinetSession.tryParse(res['data']);
  }

  CabinetManualResult _manualResult(Map<String, dynamic>? res) {
    if (res == null) return CabinetManualResult(error: S.pleaseSignFirst);
    if (res['success'] != true) {
      return CabinetManualResult(
        error: res['message'] as String? ?? S.somethingWentWrongPleaseTryAgain,
        code: res['code'] as String?,
      );
    }
    final data = res['data'] is Map ? Map<String, dynamic>.from(res['data'] as Map) : const <String, dynamic>{};
    final report = CabinetManualReport.fromJson(data['manual_report']);
    return CabinetManualResult(report: report?.isPending == true ? report : null, restored: data['restored'] == true);
  }

  Future<CabinetManualResult> reportOrderManually(int orderId, String status) async {
    final res = await _send('PATCH', '/orders/$orderId/status', body: {'status': status});
    return _manualResult(res);
  }

  Future<CabinetManualResult> reportBookDepositManually(int bookId) async {
    final res = await _send('POST', '/books/$bookId/deposit');
    return _manualResult(res);
  }

  Future<CabinetManualResult> reportBookRetrievalManually(int bookId) async {
    final res = await _send('POST', '/books/$bookId/retrieve');
    return _manualResult(res);
  }
}
