part of '../api_service.dart';

extension AdminSystemApi on ApiService {
  Future<(List<BackupRecord>, int)> fetchBackups() async {
    final res = await _send('GET', '/admin/backups');
    if (res == null || res['success'] != true) return (<BackupRecord>[], 14);
    return (_mapList(res, BackupRecord.fromJson), (res['keep'] as num?)?.toInt() ?? 14);
  }

  Future<String?> createBackup() async {
    final res = await _send('POST', '/admin/backups');
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.backupFailed);
  }

  Future<String?> deleteBackup(int backupId) async {
    final res = await _send('DELETE', '/admin/backups/$backupId');
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.couldNotDelete);
  }

  String backupDownloadUrl(int backupId) => '${ApiService.baseUrl}/admin/backups/$backupId/download';

  Future<(String?, String?)> restoreBackup(int backupId, String password) async {
    final res = await _send('POST', '/admin/backups/$backupId/restore', body: {'password': password});
    if (res == null) return (null, S.couldNotReachServer);
    if (res['success'] != true) return (null, res['message'] as String? ?? S.somethingWentWrongPleaseTryAgain);
    return ((res['data'] as Map?)?['safety_backup'] as String? ?? '', null);
  }

  Future<List<PendingDeletion>> fetchPendingDeletions() async {
    final res = await _send('GET', '/admin/deletions');
    return _mapList(res, PendingDeletion.fromJson);
  }

  Future<String?> cancelMemberDeletion(int userId) async {
    final res = await _send('POST', '/admin/deletions/$userId/cancel');
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.couldNotCancel);
  }

  Future<String?> purgeMember(int userId) async {
    final res = await _send('POST', '/admin/deletions/$userId/purge');
    if (res == null) return S.pleaseSignFirst;
    return res['success'] == true ? null : (res['message'] as String? ?? S.couldNotComplete);
  }

  Future<AdminOverview> fetchAdminOverview() async {
    final res = await _send('GET', '/admin/overview');
    if (res == null || res['success'] != true || res['data'] is! Map) return AdminOverview.empty;
    return AdminOverview.fromJson(Map<String, dynamic>.from(res['data']));
  }

  Future<AdminStats> fetchAdminStats({int days = 7}) async {
    final res = await _send('GET', '/admin/stats', query: {'days': '$days'});
    if (res == null || res['success'] != true || res['data'] is! Map) return AdminStats.empty;
    return AdminStats.fromJson(Map<String, dynamic>.from(res['data']));
  }

  Future<List<AdminOperationLog>> fetchAdminOperationLogs({String? targetType, String? keyword}) async {
    final res = await _send('GET', '/admin/operation-logs', query: {
      'limit': '100',
      if (targetType != null) 'target_type': targetType,
      if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
    });
    return _mapList(res, AdminOperationLog.fromJson);
  }

  Future<String?> undoAdminOperation(int logId) async {
    final res = await _send('POST', '/admin/operation-logs/$logId/undo');
    if (res == null) return S.couldNotReachServer;
    return res['success'] == true ? null : (res['message'] as String? ?? S.somethingWentWrongPleaseTryAgain);
  }
}
