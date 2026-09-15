part of '../api_service.dart';

extension StatusApi on ApiService {
  Future<ServerStatus?> fetchServerStatus() async {
    final res = await _send('GET', '/status');
    if (res == null) return null;
    if (res['success'] != true) {
      return res['code'] == 'ROUTE_NOT_FOUND' ? const ServerStatus(reachable: true, apiRevision: 0) : null;
    }
    final data = res['data'];
    if (data is! Map) return null;
    return ServerStatus(
      reachable: true,
      apiRevision: parseInt(data['api_revision']),
      commit: data['commit'] as String?,
      pendingMigrations: (data['pending_migrations'] as List? ?? const []).map((e) => '$e').toList(),
    );
  }

  Future<String?> fetchRestoreState() async {
    final res = await _send('GET', '/status');
    final data = res?['data'];
    if (data is! Map) return null;
    return (data['restore'] as Map?)?['state'] as String?;
  }
}
