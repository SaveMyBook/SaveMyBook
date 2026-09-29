part of '../api_service.dart';

typedef AdminCabinetPage<T> = ({List<T> items, bool hasMore, bool ok});

typedef AdminCabinetSessionAction = ({AdminCabinetSessionDetail? detail, CabinetApiError? error});

extension AdminCabinetDevicesApi on ApiService {
  static const cabinetAdminPageSize = 20;

  String? _adminCabinetError(Map<String, dynamic>? res) {
    if (res == null) return S.pleaseSignFirst;
    if (res['success'] == true) return null;
    if (res['code'] == 'VERIFICATION_CANCELLED') return '';
    return res['message'] as String? ?? S.somethingWentWrongPleaseTryAgain;
  }

  CabinetApiError? _adminCabinetFailure(Map<String, dynamic>? res) {
    if (res == null) return CabinetApiError(code: CabinetApiError.signedOut, message: S.pleaseSignFirst);
    if (res['success'] == true) return null;
    if (res['code'] == CabinetApiError.network) return CabinetApiError(code: CabinetApiError.network, message: S.networkError);
    return CabinetApiError.fromResponse(res);
  }

  CabinetApiError get _adminCabinetMalformed => CabinetApiError(code: '', message: S.somethingWentWrongPleaseTryAgain);

  Map<String, dynamic>? _adminCabinetData(Map<String, dynamic>? res) =>
      res?['data'] is Map ? Map<String, dynamic>.from(res!['data'] as Map) : null;

  AdminCabinetPage<T> _adminCabinetPage<T>(Map<String, dynamic>? res, int page, T Function(Map<String, dynamic>) build) {
    if (res == null || res['success'] != true) return (items: <T>[], hasMore: false, ok: false);
    final pagination = res['pagination'];
    final totalPages = pagination is Map ? parseInt(pagination['total_pages']) : page;
    return (items: _mapList(res, build), hasMore: page < totalPages, ok: true);
  }

  String _cabinetDoorPath(int cabinetId, int slotId) => '/admin/cabinets/$cabinetId/doors/$slotId';

  Future<AdminCabinetDeviceSummary?> fetchCabinetDevice(int cabinetId) async {
    final res = await _send('GET', '/admin/cabinets/$cabinetId/device');
    if (res == null || res['success'] != true || res['data'] is! Map) return null;
    return AdminCabinetDeviceSummary.fromJson(Map<String, dynamic>.from(res['data'] as Map));
  }

  Future<({AdminCabinetPairResult? paired, CabinetApiError? error})> pairCabinetDevice(
    int cabinetId,
    String code, {
    String? verifyToken,
  }) async {
    final res = await _send(
      'POST',
      '/admin/cabinets/$cabinetId/device/pair',
      body: {'code': AdminCabinetPairing.codeOf(code) ?? code.trim()},
      extraHeaders: verifyToken == null ? null : {'X-Verify-Token': verifyToken},
    );
    final error = _adminCabinetFailure(res);
    if (error != null) return (paired: null, error: error);
    final data = _adminCabinetData(res);
    if (data == null) return (paired: null, error: _adminCabinetMalformed);
    return (paired: AdminCabinetPairResult.fromJson(data), error: null);
  }

  Future<String?> revokeCabinetDevice(int cabinetId, {String? reason}) async {
    final res = await _send('DELETE', '/admin/cabinets/$cabinetId/device', body: {
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    });
    return _adminCabinetError(res);
  }

  Future<({AdminCabinetRemoteOpen? opened, CabinetApiError? error})> openCabinetDoor(
    int cabinetId,
    int slotId,
    String reason, {
    bool force = false,
  }) async {
    final res = await _send('POST', '${_cabinetDoorPath(cabinetId, slotId)}/open', body: {'reason': reason.trim(), 'force': force});
    final error = _adminCabinetFailure(res);
    if (error != null) return (opened: null, error: error);
    final opened = AdminCabinetRemoteOpen.fromJson(res!['data']);
    if (opened == null) return (opened: null, error: _adminCabinetMalformed);
    return (opened: opened, error: null);
  }

  String _adminSessionPath(String sessionNo) => '/admin/cabinet-sessions/${Uri.encodeComponent(sessionNo)}';

  AdminCabinetSessionAction _adminSessionAction(Map<String, dynamic>? res) {
    final error = _adminCabinetFailure(res);
    if (error != null) return (detail: null, error: error);
    final data = _adminCabinetData(res);
    if (data == null) return (detail: null, error: _adminCabinetMalformed);
    return (detail: AdminCabinetSessionDetail.fromJson(data), error: null);
  }

  Future<AdminCabinetSessionAction> matchRemoteCabinetSession(String sessionNo, String code) async {
    if (!CabinetSession.isMatchCode(code)) {
      return (detail: null, error: CabinetApiError(code: CabinetApiError.matchCodeInvalid, message: S.enterTwoDigits));
    }
    return _adminSessionAction(await _send('POST', '${_adminSessionPath(sessionNo)}/match', body: {'code': code}));
  }

  Future<AdminCabinetSessionAction> closeRemoteCabinetSession(String sessionNo) async =>
      _adminSessionAction(await _send('POST', '${_adminSessionPath(sessionNo)}/close'));

  Future<String?> placeCabinetDoorItems(int cabinetId, int slotId, {int? orderId, List<int>? bookIds}) async {
    final res = await _send('POST', '${_cabinetDoorPath(cabinetId, slotId)}/place', body: {
      'order_id': ?orderId,
      if (orderId == null) 'book_ids': bookIds ?? const <int>[],
    });
    return _adminCabinetError(res);
  }

  Future<String?> confirmCabinetDoor(int cabinetId, int slotId, {String? note}) async {
    final res = await _send('POST', '${_cabinetDoorPath(cabinetId, slotId)}/check-clear', body: {
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
    return _adminCabinetError(res);
  }

  Future<String?> clearCabinetDoor(int cabinetId, int slotId, {required bool removed, required String reason}) async {
    final res = await _send('POST', '${_cabinetDoorPath(cabinetId, slotId)}/clear', body: {
      'mode': removed ? 'removed' : 'correct',
      'reason': reason.trim(),
    });
    return _adminCabinetError(res);
  }

  Future<String?> clearCabinetFault(int cabinetId, {int? slotId}) async {
    final path = slotId == null ? '/admin/cabinets/$cabinetId/device/fault-clear' : '${_cabinetDoorPath(cabinetId, slotId)}/fault-clear';
    return _adminCabinetError(await _send('POST', path));
  }

  Future<AdminCabinetPage<AdminCabinetSessionRow>> fetchCabinetSessions(int cabinetId, {String? status, int page = 1}) async {
    final res = await _send('GET', '/admin/cabinets/$cabinetId/sessions', query: {
      'status': ?status,
      'page': '$page',
      'limit': '$cabinetAdminPageSize',
    });
    return _adminCabinetPage(res, page, AdminCabinetSessionRow.fromJson);
  }

  Future<AdminCabinetSessionDetail?> fetchCabinetSessionDetail(String sessionNo) async {
    final res = await _send('GET', _adminSessionPath(sessionNo));
    if (res == null || res['success'] != true || res['data'] is! Map) return null;
    return AdminCabinetSessionDetail.fromJson(Map<String, dynamic>.from(res['data'] as Map));
  }

  Future<String?> resolveCabinetSession(String sessionNo, {required bool commit, required String note}) async {
    final res = await _send('POST', '${_adminSessionPath(sessionNo)}/resolve', body: {
      'action': commit ? 'commit' : 'discard',
      'note': note.trim(),
    });
    return _adminCabinetError(res);
  }

  Future<AdminCabinetPage<AdminCabinetEventRow>> fetchCabinetEvents(int cabinetId, {String? type, int page = 1}) async {
    final res = await _send('GET', '/admin/cabinets/$cabinetId/events', query: {
      'type': ?type,
      'page': '$page',
      'limit': '$cabinetAdminPageSize',
    });
    return _adminCabinetPage(res, page, AdminCabinetEventRow.fromJson);
  }

  Future<AdminCabinetPage<AdminCabinetManualReport>> fetchCabinetManualReports(
    int cabinetId, {
    String status = 'pending',
    int page = 1,
  }) async {
    final res = await _send('GET', '/admin/cabinets/$cabinetId/manual-reports', query: {
      'status': status,
      'page': '$page',
      'limit': '$cabinetAdminPageSize',
    });
    return _adminCabinetPage(res, page, AdminCabinetManualReport.fromJson);
  }

  Future<String?> confirmCabinetManualReport(String reportNo, {String? note, int? slotId}) async {
    final res = await _send('POST', '/admin/cabinet-manual-reports/${Uri.encodeComponent(reportNo)}/confirm', body: {
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      'slot_id': ?slotId,
    });
    return _adminCabinetError(res);
  }

  Future<String?> rejectCabinetManualReport(String reportNo, {required String note}) async {
    final res = await _send('POST', '/admin/cabinet-manual-reports/${Uri.encodeComponent(reportNo)}/reject', body: {'note': note.trim()});
    return _adminCabinetError(res);
  }
}
