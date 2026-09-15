import '../../utils/api_helpers.dart';

class BackupRecord {
  final int backupId;
  final String fileName;
  final int sizeBytes;
  final String triggerBy;
  final String status;
  final String? detail;
  final DateTime? createdAt;
  final String adminName;

  final bool available;

  const BackupRecord({
    required this.backupId,
    required this.fileName,
    required this.sizeBytes,
    required this.triggerBy,
    required this.status,
    required this.available,
    this.detail,
    this.createdAt,
    this.adminName = '',
  });

  bool get isSuccess => status == 'success';
  bool get isManual => triggerBy == 'manual';
  bool get isPreRestore => triggerBy == 'pre_restore';

  String get sizeText {
    if (sizeBytes <= 0) return '—';
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = sizeBytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit += 1;
    }
    return '${value.toStringAsFixed(unit == 0 ? 0 : 1)} ${units[unit]}';
  }

  factory BackupRecord.fromJson(Map<String, dynamic> json) {
    final admin = json['admin'] as Map<String, dynamic>?;
    return BackupRecord(
      backupId: parseInt(json['backup_id']),
      fileName: json['file_name'] as String? ?? '',
      sizeBytes: parseInt(json['size_bytes']),
      triggerBy: json['trigger_by'] as String? ?? 'schedule',
      status: json['status'] as String? ?? 'success',
      detail: json['detail'] as String?,
      createdAt: parseDate(json['created_at']),
      adminName: admin?['nickname'] as String? ?? '',
      available: json['available'] == true,
    );
  }
}
