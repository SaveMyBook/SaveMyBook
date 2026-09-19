part of '../api_service.dart';

extension AdminCabinetsApi on ApiService {
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

  /// 回傳 null 代表成功，否則為錯誤訊息。
  Future<String?> setCabinetMaintenance(int cabinetId, bool on) async {
    final res = await _send('PATCH', '/admin/cabinets/$cabinetId/maintenance', body: {'is_maintenance': on});
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.couldNotSaveLocker);
  }

  Future<bool> updateSlotStatus(int cabinetId, int slotId, String status) async {
    final res = await _send('PATCH', '/admin/cabinets/$cabinetId/slots/$slotId', body: {'status': status});
    return res != null && res['success'] == true;
  }

  Future<List<MaintenanceLog>> fetchMaintenanceLogs() async {
    final res = await _send('GET', '/admin/maintenance-logs');
    return _mapList(res, MaintenanceLog.fromJson);
  }
}
