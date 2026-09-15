import '../../utils/api_helpers.dart';
import '../../i18n/strings.dart';

class LogChange {
  final String label;
  final String from;
  final String to;

  const LogChange({required this.label, required this.from, required this.to});

  factory LogChange.fromJson(Map<String, dynamic> json) => LogChange(
        label: json['label'] as String? ?? '',
        from: json['from'] as String? ?? '',
        to: json['to'] as String? ?? '',
      );
}

class AdminOperationLog {
  final int logId;
  final String logNo;
  final String action;
  final String? targetType;
  final int? targetId;
  final String? targetNo;

  final String summary;
  final List<LogChange> changes;
  final bool canUndo;
  final DateTime? revertedAt;
  final String adminName;
  final String? ipAddress;
  final DateTime? createdAt;

  AdminOperationLog({
    required this.logId,
    required this.action,
    required this.adminName,
    this.summary = '',
    this.changes = const [],
    this.canUndo = false,
    this.revertedAt,
    this.targetType,
    this.targetId,
    this.logNo = '',
    this.targetNo,
    this.ipAddress,
    this.createdAt,
  });

  bool get isReverted => revertedAt != null;

  factory AdminOperationLog.fromJson(Map<String, dynamic> json) {
    final admin = json['admin'] as Map<String, dynamic>?;
    final reverted = json['reverted'];

    return AdminOperationLog(
      logId: parseInt(json['log_id']),
      action: json['action'] as String? ?? '',
      targetType: json['target_type'] as String?,
      targetId: json['target_id'] == null ? null : parseInt(json['target_id']),
      logNo: json['log_no'] as String? ?? '',
      targetNo: json['target_no'] as String?,
      summary: json['summary'] as String? ?? json['detail'] as String? ?? '',
      changes: ((json['changes'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => LogChange.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      canUndo: json['can_undo'] == true,
      revertedAt: reverted is Map ? parseDate(reverted['at']) : null,
      adminName: admin?['nickname'] as String? ?? S.roleAdmin,
      ipAddress: json['ip_address'] as String?,
      createdAt: parseDate(json['created_at']),
    );
  }
}
