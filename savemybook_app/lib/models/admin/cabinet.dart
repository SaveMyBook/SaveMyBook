import '../../utils/api_helpers.dart';
import '../../utils/app_labels.dart';
import 'cabinet_device.dart';

class CabinetSlot {
  final int slotId;
  final String slotNumber;
  final String status;
  final DateTime? updatedAt;
  final int? lockChannel;
  final String? faultCode;
  final DateTime? checkRequiredAt;

  CabinetSlot({
    required this.slotId,
    required this.slotNumber,
    required this.status,
    this.updatedAt,
    this.lockChannel,
    this.faultCode,
    this.checkRequiredAt,
  });

  String get statusText => AppLabels.slot(status);

  bool get isDoor => lockChannel != null;

  bool get needsCheck => checkRequiredAt != null;

  factory CabinetSlot.fromJson(Map<String, dynamic> json) {
    return CabinetSlot(
      slotId: parseInt(json['slot_id']),
      slotNumber: json['slot_number'] as String? ?? '',
      status: json['status'] as String? ?? 'empty',
      updatedAt: parseDate(json['updated_at']),
      lockChannel: json['lock_channel'] == null ? null : parseInt(json['lock_channel']),
      faultCode: json['fault_code'] as String?,
      checkRequiredAt: parseDate(json['check_required_at']),
    );
  }
}

class Cabinet {
  final int cabinetId;
  final String cabinetName;
  final String address;
  final double latitude;
  final double longitude;
  final int totalSlots;
  final int availableSlots;
  final bool isActive;
  /// 整台書櫃維修中：暫停開放賣家選擇，與停用不同，既有設定與訂單都保留。
  final bool isMaintenance;
  final String openHours;
  final List<CabinetSlot> slots;
  final Map<String, int> slotSummary;
  final AdminCabinetDeviceBrief? device;

  Cabinet({
    required this.cabinetId,
    required this.cabinetName,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.totalSlots,
    required this.availableSlots,
    required this.isActive,
    this.isMaintenance = false,
    this.openHours = '',
    this.slots = const [],
    this.slotSummary = const {},
    this.device,
  });

  List<CabinetSlot> get doors => [for (final slot in slots) if (slot.isDoor) slot];

  factory Cabinet.fromJson(Map<String, dynamic> json) {
    final summary = (json['slot_summary'] as Map<String, dynamic>?) ?? const {};
    return Cabinet(
      cabinetId: parseInt(json['cabinet_id']),
      cabinetName: json['cabinet_name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      latitude: parseDouble(json['latitude']),
      longitude: parseDouble(json['longitude']),
      totalSlots: parseInt(json['total_slots']),
      availableSlots: parseInt(json['available_slots']),
      isActive: json['is_active'] != false,
      isMaintenance: json['is_maintenance'] == true,
      openHours: formatTimeRange(json['open_time'], json['close_time']),
      slots: ((json['cabinet_slots'] as List?) ?? const [])
          .map((e) => CabinetSlot.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      slotSummary: summary.map((k, v) => MapEntry(k, parseInt(v))),
      device: AdminCabinetDeviceBrief.fromJson(json['device']),
    );
  }
}

class MaintenanceLog {
  final int logId;
  final String logNo;
  final String action;
  final String? detail;
  final String adminName;
  final DateTime? createdAt;

  MaintenanceLog({
    required this.logId,
    this.logNo = '',
    required this.action,
    required this.adminName,
    this.detail,
    this.createdAt,
  });

  factory MaintenanceLog.fromJson(Map<String, dynamic> json) {
    return MaintenanceLog(
      logId: parseInt(json['log_id']),
      logNo: json['log_no'] as String? ?? '',
      action: json['action'] as String? ?? '',
      detail: json['detail'] as String?,
      adminName: (json['users'] as Map<String, dynamic>?)?['nickname'] as String? ?? '',
      createdAt: parseDate(json['created_at']),
    );
  }
}

class CabinetDeposit {
  final int bookId;
  final String title;
  final String bookStatus;
  final String? imageUrl;
  final String sellerName;
  final bool sellerDeleted;
  final int? cabinetId;
  final String cabinetName;
  final DateTime? depositedAt;
  final int daysStored;
  final bool paused;
  final bool escalated;
  final bool overdue;
  final int? doorSlotId;
  final String? doorLabel;

  CabinetDeposit({
    required this.bookId,
    required this.title,
    this.bookStatus = 'on_sale',
    this.imageUrl,
    this.sellerName = '',
    this.sellerDeleted = false,
    this.cabinetId,
    this.cabinetName = '',
    this.depositedAt,
    this.daysStored = 0,
    this.paused = false,
    this.escalated = false,
    this.overdue = false,
    this.doorSlotId,
    this.doorLabel,
  });

  factory CabinetDeposit.fromJson(Map<String, dynamic> json) {
    final seller = json['seller'] as Map<String, dynamic>?;
    final cabinet = json['cabinet'] as Map<String, dynamic>?;
    final door = json['door'] is Map ? Map<String, dynamic>.from(json['door'] as Map) : null;
    return CabinetDeposit(
      bookId: parseInt(json['book_id']),
      title: json['title'] as String? ?? '',
      bookStatus: json['book_status'] as String? ?? 'on_sale',
      imageUrl: resolveAssetUrl(json['image_url']),
      sellerName: seller?['nickname'] as String? ?? '',
      sellerDeleted: seller?['deleted'] == true,
      cabinetId: cabinet?['cabinet_id'] == null ? null : parseInt(cabinet!['cabinet_id']),
      cabinetName: cabinet?['cabinet_name'] as String? ?? '',
      depositedAt: parseDate(json['deposited_at'])?.toLocal(),
      daysStored: parseInt(json['days_stored']),
      paused: json['paused'] == true,
      escalated: json['escalated'] == true,
      overdue: json['overdue'] == true,
      doorSlotId: door?['slot_id'] == null ? null : parseInt(door!['slot_id']),
      doorLabel: door?['label'] as String?,
    );
  }
}
