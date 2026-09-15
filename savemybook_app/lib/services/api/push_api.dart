part of '../api_service.dart';

extension PushApi on ApiService {
  Future<List<PushDeviceInfo>?> fetchPushDevices() async {
    final res = await _send('GET', '/push/devices');
    if (res == null || res['success'] != true) return null;
    return _mapList(res, PushDeviceInfo.fromJson);
  }

  Future<String?> registerPushDevice(String token, String platform) async {
    final res = await _send('POST', '/push/devices', body: {'token': token, 'platform': platform});
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.somethingWentWrongPleaseTryAgain);
  }

  Future<(String?, String?)> sendTestPush() async {
    final res = await _send('POST', '/push/test');
    if (res == null) return (null, S.couldNotReachServer);
    final message = res['message'] as String?;
    return res['success'] == true ? (message ?? '', null) : (null, message ?? S.somethingWentWrongPleaseTryAgain);
  }

  Future<bool> unregisterPushDevice(String token) async {
    final res = await _send('DELETE', '/push/devices', body: {'token': token});
    return res != null && res['success'] == true;
  }
}
