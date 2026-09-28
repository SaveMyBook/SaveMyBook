part of '../api_service.dart';

typedef AdminCabinetPage<T> = ({List<T> items, bool hasMore, bool ok});

extension AdminCabinetDevicesApi on ApiService {
  static const cabinetAdminPageSize = 20;

  String? _adminCabinetError(Map<String, dynamic>? res) {
    if (res == null) return S.pleaseSignFirst;
    if (res['success'] == true) return null;
    if (res['code'] == 'VERIFICATION_CANCELLED') return '';
    return res['message'] as String? ?? S.somethingWentWrongPleaseTryAgain;
  }

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

  Future<({String? code, DateTime? expiresAt, String? error})> createCabinetPairingCode(
    int cabinetId, {
    required String kind,
    int doorCount = 4,
  }) async {
    final res = await _send('POST', '/admin/cabinets/$cabinetId/device/pairing-code', body: {'kind': kind, 'door_count': doorCount});
    final error = _adminCabinetError(res);
    if (error != null) return (code: null, expiresAt: null, error: error);
    final data = res!['data'] is Map ? res['data'] as Map : const {};
    return (code: data['code'] as String?, expiresAt: parseDate(data['expires_at']), error: null);
  }

  Future<String?> revokeCabinetDevice(int cabinetId, {String? reason}) async {
    final res = await _send('DELETE', '/admin/cabinets/$cabinetId/device', body: {
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    });
    return _adminCabinetError(res);
  }

  Future<({String? sessionNo, int? matchCode, int? remainingMs, String? error})> openCabinetDoor(
    int cabinetId,
    int slotId,
    String reason, {
    bool force = false,
  }) async {
    final res = await _send('POST', '${_cabinetDoorPath(cabinetId, slotId)}/open', body: {'reason': reason.trim(), 'force': force});
    final error = _adminCabinetError(res);
    if (error != null) return (sessionNo: null, matchCode: null, remainingMs: null, error: error);
    final data = res!['data'] is Map ? res['data'] as Map : const {};
    final match = data['match'];
    return (
      sessionNo: data['session_no'] as String?,
      matchCode: match is Map && match['code'] != null ? parseInt(match['code']) : null,
      remainingMs: data['remaining_ms'] == null ? null : parseInt(data['remaining_ms']),
      error: null,
    );
  }

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
    final res = await _send('GET', '/admin/cabinet-sessions/${Uri.encodeComponent(sessionNo)}');
    if (res == null || res['success'] != true || res['data'] is! Map) return null;
    return AdminCabinetSessionDetail.fromJson(Map<String, dynamic>.from(res['data'] as Map));
  }

  Future<String?> resolveCabinetSession(String sessionNo, {required bool commit, required String note}) async {
    final res = await _send('POST', '/admin/cabinet-sessions/${Uri.encodeComponent(sessionNo)}/resolve', body: {
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

  Future<String?> confirmCabinetManualReport(String reportNo, {String? note}) async {
    final res = await _send('POST', '/admin/cabinet-manual-reports/${Uri.encodeComponent(reportNo)}/confirm', body: {
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
    return _adminCabinetError(res);
  }

  Future<String?> rejectCabinetManualReport(String reportNo, {required String note}) async {
    final res = await _send('POST', '/admin/cabinet-manual-reports/${Uri.encodeComponent(reportNo)}/reject', body: {'note': note.trim()});
    return _adminCabinetError(res);
  }
}
