part of '../api_service.dart';

class CabinetDepositPage {
  final List<CabinetDeposit> items;
  final bool hasMore;
  final bool ok;

  const CabinetDepositPage({required this.items, required this.hasMore, this.ok = true});

  static const failed = CabinetDepositPage(items: [], hasMore: false, ok: false);
}

extension AdminCabinetsApi on ApiService {
  static const cabinetDepositPageSize = 20;

  Future<List<Cabinet>> fetchAdminCabinets() async {
    final res = await _send('GET', '/admin/cabinets');
    return _mapList(res, Cabinet.fromJson);
  }

  Future<String?> saveCabinet({
    int? cabinetId,
    required String name,
    required String address,
    required double latitude,
    required double longitude,
    int totalSlots = 20,
    String? openTime,
    String? closeTime,
    bool? isActive,
  }) async {
    final body = {
      'cabinet_name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      if (cabinetId == null) 'total_slots': totalSlots,
      'open_time': ?openTime,
      'close_time': ?closeTime,
      'is_active': ?isActive,
    };
    final res = cabinetId == null
        ? await _send('POST', '/admin/cabinets', body: body)
        : await _send('PUT', '/admin/cabinets/$cabinetId', body: body);
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.couldNotSaveLocker);
  }

  Future<String?> setCabinetMaintenance(int cabinetId, bool on) async {
    final res = await _send('PATCH', '/admin/cabinets/$cabinetId/maintenance', body: {'is_maintenance': on});
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.couldNotSaveLocker);
  }

  Future<bool> updateSlotStatus(int cabinetId, int slotId, String status) async {
    final res = await _send('PATCH', '/admin/cabinets/$cabinetId/slots/$slotId', body: {'status': status});
    return res != null && res['success'] == true;
  }

  Future<CabinetDepositPage> fetchCabinetDeposits({bool overdue = false, int? cabinetId, int page = 1}) async {
    final res = await _send('GET', '/admin/cabinets/deposits', query: {
      if (overdue) 'overdue': 'true',
      if (cabinetId != null) 'cabinet_id': '$cabinetId',
      'page': '$page',
      'limit': '$cabinetDepositPageSize',
    });
    if (res == null || res['success'] != true) return CabinetDepositPage.failed;
    final pagination = res['pagination'];
    final totalPages = pagination is Map ? parseInt(pagination['total_pages']) : page;
    return CabinetDepositPage(items: _mapList(res, CabinetDeposit.fromJson), hasMore: page < totalPages);
  }

  Future<String?> clearCabinetDeposit(int bookId) async {
    final res = await _send('POST', '/admin/cabinets/deposits/$bookId/clear');
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.somethingWentWrongPleaseTryAgain);
  }

  Future<List<MaintenanceLog>> fetchMaintenanceLogs() async {
    final res = await _send('GET', '/admin/maintenance-logs');
    return _mapList(res, MaintenanceLog.fromJson);
  }
}
