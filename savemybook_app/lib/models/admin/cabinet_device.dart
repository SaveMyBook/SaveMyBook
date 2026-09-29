import '../../utils/api_helpers.dart';
import '../cabinet.dart';

Map<String, dynamic>? _mapOf(Object? value) => value is Map ? Map<String, dynamic>.from(value) : null;

List<Map<String, dynamic>> _mapsOf(Object? value) =>
    value is List ? [for (final e in value) if (e is Map) Map<String, dynamic>.from(e)] : const [];

int? _intOrNull(Object? value) => value == null ? null : (value is num ? value.toInt() : int.tryParse('$value'));

String? _textOrNull(Object? value) {
  if (value == null) return null;
  final text = '$value';
  return text.isEmpty ? null : text;
}

List<String> _strings(Object? value) => value is List ? [for (final e in value) if (e != null) '$e'] : const [];

class AdminCabinetAccess {
  final String mode;
  final String? reason;
  final bool online;
  final bool openNow;

  const AdminCabinetAccess({required this.mode, this.reason, this.online = false, this.openNow = true});

  bool get isScan => mode == CabinetAccess.scan;

  bool get isManual => mode == CabinetAccess.manual;

  bool get isUnavailable => mode == CabinetAccess.unavailable;

  factory AdminCabinetAccess.fromJson(Map<String, dynamic> json) => AdminCabinetAccess(
    mode: json['mode'] as String? ?? CabinetAccess.manual,
    reason: _textOrNull(json['reason']),
    online: json['online'] == true,
    openNow: json['open_now'] != false,
  );
}

class AdminCabinetDeviceBrief {
  final String deviceNo;
  final String kind;
  final String status;
  final bool online;
  final DateTime? lastSeenAt;

  const AdminCabinetDeviceBrief({
    required this.deviceNo,
    required this.kind,
    required this.status,
    this.online = false,
    this.lastSeenAt,
  });

  bool get isPending => status == 'pending';

  static AdminCabinetDeviceBrief? fromJson(Object? json) {
    final map = _mapOf(json);
    if (map == null) return null;
    return AdminCabinetDeviceBrief(
      deviceNo: map['device_no'] as String? ?? '',
      kind: map['kind'] as String? ?? '',
      status: map['status'] as String? ?? '',
      online: map['online'] == true,
      lastSeenAt: parseDate(map['last_seen_at']),
    );
  }
}

class AdminCabinetDeviceInfo {
  static const kindSimulator = 'simulator';
  static const kindEsp32 = 'esp32';

  final String deviceNo;
  final String kind;
  final String status;
  final bool online;
  final DateTime? lastSeenAt;
  final DateTime? pairedAt;
  final String? firmware;
  final int doorCount;
  final bool hasDoorSensor;
  final int unlockPulseMs;
  final String? faultCode;

  const AdminCabinetDeviceInfo({
    required this.deviceNo,
    required this.kind,
    required this.status,
    this.online = false,
    this.lastSeenAt,
    this.pairedAt,
    this.firmware,
    this.doorCount = 4,
    this.hasDoorSensor = false,
    this.unlockPulseMs = 800,
    this.faultCode,
  });

  bool get isSimulator => kind == kindSimulator;

  factory AdminCabinetDeviceInfo.fromJson(Map<String, dynamic> json) => AdminCabinetDeviceInfo(
    deviceNo: json['device_no'] as String? ?? '',
    kind: json['kind'] as String? ?? '',
    status: json['status'] as String? ?? '',
    online: json['online'] == true,
    lastSeenAt: parseDate(json['last_seen_at']),
    pairedAt: parseDate(json['paired_at']),
    firmware: _textOrNull(json['firmware']),
    doorCount: _intOrNull(json['door_count']) ?? 4,
    hasDoorSensor: json['has_door_sensor'] == true,
    unlockPulseMs: _intOrNull(json['unlock_pulse_ms']) ?? 800,
    faultCode: _textOrNull(json['fault_code']),
  );
}

class AdminCabinetPairing {
  static final _codeSeparators = RegExp(r'[-\s]');
  static final _codeDigits = RegExp(r'^[0-9]{8}$');

  final String kind;
  final int doorCount;
  final bool hasDoorSensor;
  final String? firmware;
  final DateTime? expiresAt;

  const AdminCabinetPairing({required this.kind, this.doorCount = 4, this.hasDoorSensor = false, this.firmware, this.expiresAt});

  static String? codeOf(String raw) {
    final digits = raw.replaceAll(_codeSeparators, '');
    return _codeDigits.hasMatch(digits) ? digits : null;
  }

  factory AdminCabinetPairing.fromJson(Map<String, dynamic> json) => AdminCabinetPairing(
    kind: json['kind'] as String? ?? '',
    doorCount: _intOrNull(json['door_count']) ?? 4,
    hasDoorSensor: json['has_door_sensor'] == true,
    firmware: _textOrNull(json['firmware']),
    expiresAt: parseDate(json['expires_at']),
  );
}

class AdminCabinetPairResult {
  final String kind;
  final int doorCount;
  final bool hasDoorSensor;
  final String? firmware;
  final AdminCabinetDeviceSummary? summary;

  const AdminCabinetPairResult({required this.kind, this.doorCount = 4, this.hasDoorSensor = false, this.firmware, this.summary});

  factory AdminCabinetPairResult.fromJson(Map<String, dynamic> json) {
    final summary = _mapOf(json['summary']);
    return AdminCabinetPairResult(
      kind: json['kind'] as String? ?? '',
      doorCount: _intOrNull(json['door_count']) ?? 4,
      hasDoorSensor: json['has_door_sensor'] == true,
      firmware: _textOrNull(json['firmware']),
      summary: summary == null ? null : AdminCabinetDeviceSummary.fromJson(summary),
    );
  }
}

class AdminCabinetRemoteOpen {
  final String sessionNo;
  final String status;
  final int? remainingMs;

  const AdminCabinetRemoteOpen({required this.sessionNo, required this.status, this.remainingMs});

  bool get needsMatch => status == CabinetSession.matching;

  static AdminCabinetRemoteOpen? fromJson(Object? json) {
    final map = _mapOf(json);
    final sessionNo = _textOrNull(map?['session_no']);
    if (map == null || sessionNo == null) return null;
    return AdminCabinetRemoteOpen(
      sessionNo: sessionNo,
      status: map['status'] as String? ?? CabinetSession.matching,
      remainingMs: _intOrNull(map['remaining_ms']),
    );
  }
}

class AdminCabinetCheckCandidate {
  final int bookId;
  final String bookNo;
  final String title;
  final String kind;
  final int? orderId;

  const AdminCabinetCheckCandidate({
    required this.bookId,
    required this.bookNo,
    required this.title,
    required this.kind,
    this.orderId,
  });

  factory AdminCabinetCheckCandidate.fromJson(Map<String, dynamic> json) => AdminCabinetCheckCandidate(
    bookId: parseInt(json['book_id']),
    bookNo: json['book_no'] as String? ?? '',
    title: json['title'] as String? ?? '',
    kind: json['kind'] as String? ?? '',
    orderId: _intOrNull(json['order_id']),
  );
}

class AdminCabinetDoorCheck {
  final DateTime? at;
  final String reason;
  final String? sessionNo;
  final List<AdminCabinetCheckCandidate> candidates;

  const AdminCabinetDoorCheck({this.at, required this.reason, this.sessionNo, this.candidates = const []});

  factory AdminCabinetDoorCheck.fromJson(Map<String, dynamic> json) => AdminCabinetDoorCheck(
    at: parseDate(json['at']),
    reason: json['reason'] as String? ?? '',
    sessionNo: _textOrNull(json['session_no']),
    candidates: _mapsOf(json['candidates']).map(AdminCabinetCheckCandidate.fromJson).toList(),
  );
}

class AdminCabinetDoorItem {
  static const kindOrder = 'order';
  static const kindDeposit = 'deposit';
  static const kindOther = 'other';

  final String kind;
  final int bookId;
  final String bookNo;
  final String title;
  final int? orderId;
  final String? orderNo;
  final String? sellerNickname;
  final DateTime? placedAt;

  const AdminCabinetDoorItem({
    required this.kind,
    required this.bookId,
    required this.bookNo,
    required this.title,
    this.orderId,
    this.orderNo,
    this.sellerNickname,
    this.placedAt,
  });

  factory AdminCabinetDoorItem.fromJson(Map<String, dynamic> json) => AdminCabinetDoorItem(
    kind: json['kind'] as String? ?? kindOther,
    bookId: parseInt(json['book_id']),
    bookNo: json['book_no'] as String? ?? '',
    title: json['title'] as String? ?? '',
    orderId: _intOrNull(json['order_id']),
    orderNo: _textOrNull(json['order_no']),
    sellerNickname: _textOrNull(json['seller_nickname']),
    placedAt: parseDate(json['placed_at']),
  );
}

class AdminCabinetDoor {
  final int slotId;
  final String slotNo;
  final String label;
  final int channel;
  final String status;
  final String? faultCode;
  final String? sensor;
  final AdminCabinetDoorCheck? check;
  final List<AdminCabinetDoorItem> items;

  const AdminCabinetDoor({
    required this.slotId,
    required this.slotNo,
    required this.label,
    required this.channel,
    required this.status,
    this.faultCode,
    this.sensor,
    this.check,
    this.items = const [],
  });

  bool get needsCheck => check != null;

  bool get hasFault => faultCode != null;

  bool get isUnderMaintenance => status == 'maintenance';

  bool get hasContents => items.isNotEmpty;

  factory AdminCabinetDoor.fromJson(Map<String, dynamic> json) {
    final check = _mapOf(json['check']);
    return AdminCabinetDoor(
      slotId: parseInt(json['slot_id']),
      slotNo: json['slot_no'] as String? ?? '',
      label: json['label'] as String? ?? '',
      channel: parseInt(json['channel']),
      status: json['status'] as String? ?? 'empty',
      faultCode: _textOrNull(json['fault_code']),
      sensor: _textOrNull(json['sensor']),
      check: check == null ? null : AdminCabinetDoorCheck.fromJson(check),
      items: _mapsOf(json['items']).map(AdminCabinetDoorItem.fromJson).toList(),
    );
  }
}

class AdminCabinetUnplacedItem {
  final String kind;
  final int? orderId;
  final String? orderNo;
  final int bookId;
  final String bookNo;
  final String title;

  const AdminCabinetUnplacedItem({
    required this.kind,
    this.orderId,
    this.orderNo,
    required this.bookId,
    required this.bookNo,
    required this.title,
  });

  factory AdminCabinetUnplacedItem.fromJson(Map<String, dynamic> json) => AdminCabinetUnplacedItem(
    kind: json['kind'] as String? ?? '',
    orderId: _intOrNull(json['order_id']),
    orderNo: _textOrNull(json['order_no']),
    bookId: parseInt(json['book_id']),
    bookNo: json['book_no'] as String? ?? '',
    title: json['title'] as String? ?? '',
  );
}

class AdminCabinetDeviceSummary {
  final int cabinetId;
  final String cabinetName;
  final bool isActive;
  final bool isMaintenance;
  final String? openTime;
  final String? closeTime;
  final AdminCabinetAccess access;
  final bool simulatorEnabled;
  final String? kioskUrl;
  final AdminCabinetDeviceInfo? device;
  final AdminCabinetPairing? pairing;
  final String? activeSessionNo;
  final List<AdminCabinetDoor> doors;
  final List<AdminCabinetUnplacedItem> unplaced;

  const AdminCabinetDeviceSummary({
    required this.cabinetId,
    required this.cabinetName,
    this.isActive = true,
    this.isMaintenance = false,
    this.openTime,
    this.closeTime,
    required this.access,
    this.simulatorEnabled = false,
    this.kioskUrl,
    this.device,
    this.pairing,
    this.activeSessionNo,
    this.doors = const [],
    this.unplaced = const [],
  });

  String get openHours => formatTimeRange(openTime, closeTime);

  List<({int bookId, String title, int? orderId, String? orderNo})> placeableFor(AdminCabinetDoor door) {
    final seen = <int>{};
    return [
      for (final item in unplaced)
        if (seen.add(item.bookId)) (bookId: item.bookId, title: item.title, orderId: item.orderId, orderNo: item.orderNo),
      for (final candidate in door.check?.candidates ?? const <AdminCabinetCheckCandidate>[])
        if (seen.add(candidate.bookId)) (bookId: candidate.bookId, title: candidate.title, orderId: candidate.orderId, orderNo: null),
    ];
  }

  factory AdminCabinetDeviceSummary.fromJson(Map<String, dynamic> json) {
    final cabinet = _mapOf(json['cabinet']) ?? const {};
    final device = _mapOf(json['device']);
    final pairing = _mapOf(json['pairing']);
    return AdminCabinetDeviceSummary(
      cabinetId: parseInt(cabinet['cabinet_id']),
      cabinetName: cabinet['cabinet_name'] as String? ?? '',
      isActive: cabinet['is_active'] != false,
      isMaintenance: cabinet['is_maintenance'] == true,
      openTime: _textOrNull(cabinet['open_time']),
      closeTime: _textOrNull(cabinet['close_time']),
      access: AdminCabinetAccess.fromJson(_mapOf(json['access']) ?? const {}),
      simulatorEnabled: json['simulator_enabled'] == true,
      kioskUrl: _textOrNull(json['kiosk_url']),
      device: device == null ? null : AdminCabinetDeviceInfo.fromJson(device),
      pairing: pairing == null ? null : AdminCabinetPairing.fromJson(pairing),
      activeSessionNo: _textOrNull(json['active_session_no']),
      doors: _mapsOf(json['doors']).map(AdminCabinetDoor.fromJson).toList(),
      unplaced: _mapsOf(json['unplaced']).map(AdminCabinetUnplacedItem.fromJson).toList(),
    );
  }
}

class AdminCabinetUserBrief {
  final String userNo;
  final String nickname;

  const AdminCabinetUserBrief({required this.userNo, required this.nickname});

  static AdminCabinetUserBrief? fromJson(Object? json) {
    final map = _mapOf(json);
    if (map == null) return null;
    return AdminCabinetUserBrief(userNo: map['user_no'] as String? ?? '', nickname: map['nickname'] as String? ?? '');
  }
}

class AdminCabinetSessionRow {
  final String sessionNo;
  final String kind;
  final String status;
  final String? resultCode;
  final AdminCabinetUserBrief? user;
  final List<String> itemKinds;
  final List<String> doors;
  final String? locationStatus;
  final int? distanceM;
  final String? closeReason;
  final DateTime? createdAt;
  final DateTime? openedAt;
  final DateTime? finishedAt;

  const AdminCabinetSessionRow({
    required this.sessionNo,
    required this.kind,
    required this.status,
    this.resultCode,
    this.user,
    this.itemKinds = const [],
    this.doors = const [],
    this.locationStatus,
    this.distanceM,
    this.closeReason,
    this.createdAt,
    this.openedAt,
    this.finishedAt,
  });

  bool get isAdmin => kind == 'admin';

  factory AdminCabinetSessionRow.fromJson(Map<String, dynamic> json) => AdminCabinetSessionRow(
    sessionNo: json['session_no'] as String? ?? '',
    kind: json['kind'] as String? ?? 'user',
    status: json['status'] as String? ?? '',
    resultCode: _textOrNull(json['result_code']),
    user: AdminCabinetUserBrief.fromJson(json['user']),
    itemKinds: _strings(json['item_kinds']),
    doors: _strings(json['doors']),
    locationStatus: _textOrNull(json['location_status']),
    distanceM: _intOrNull(json['distance_m']),
    closeReason: _textOrNull(json['close_reason']),
    createdAt: parseDate(json['created_at']),
    openedAt: parseDate(json['opened_at']),
    finishedAt: parseDate(json['finished_at']),
  );
}

class AdminCabinetSessionItem extends CabinetSessionItem {
  final String? sellerNickname;
  final String? buyerNickname;

  const AdminCabinetSessionItem({
    required super.key,
    required super.kindCode,
    super.orderId,
    super.orderNo,
    super.books,
    super.doors,
    super.paused,
    super.note,
    super.selected,
    super.blocked,
    super.result,
    super.error,
    this.sellerNickname,
    this.buyerNickname,
  });

  factory AdminCabinetSessionItem.fromJson(Map<String, dynamic> json) {
    final item = CabinetSessionItem.fromJson(json);
    return AdminCabinetSessionItem(
      key: item.key,
      kindCode: item.kindCode,
      orderId: item.orderId,
      orderNo: item.orderNo,
      books: item.books,
      doors: item.doors,
      paused: item.paused,
      note: item.note,
      selected: item.selected,
      blocked: item.blocked,
      result: item.result,
      error: item.error,
      sellerNickname: _textOrNull(json['seller_nickname']),
      buyerNickname: _textOrNull(json['buyer_nickname']),
    );
  }
}

class AdminCabinetDoorTimeline {
  final String label;
  final String state;
  final DateTime? commandServedAt;
  final DateTime? openedAt;
  final DateTime? closedAt;
  final String? closeReason;

  const AdminCabinetDoorTimeline({
    required this.label,
    required this.state,
    this.commandServedAt,
    this.openedAt,
    this.closedAt,
    this.closeReason,
  });

  factory AdminCabinetDoorTimeline.fromJson(Map<String, dynamic> json) => AdminCabinetDoorTimeline(
    label: json['label'] as String? ?? '',
    state: json['state'] as String? ?? 'pending',
    commandServedAt: parseDate(json['command_served_at']),
    openedAt: parseDate(json['opened_at']),
    closedAt: parseDate(json['closed_at']),
    closeReason: _textOrNull(json['close_reason']),
  );
}

class AdminCabinetSessionEvent {
  final String type;
  final String source;
  final String? label;
  final Map<String, dynamic>? detail;
  final String? result;
  final DateTime? occurredAt;

  const AdminCabinetSessionEvent({
    required this.type,
    required this.source,
    this.label,
    this.detail,
    this.result,
    this.occurredAt,
  });

  factory AdminCabinetSessionEvent.fromJson(Map<String, dynamic> json) => AdminCabinetSessionEvent(
    type: json['type'] as String? ?? '',
    source: json['source'] as String? ?? '',
    label: _textOrNull(json['label']),
    detail: _mapOf(json['detail']),
    result: _textOrNull(json['result']),
    occurredAt: parseDate(json['occurred_at']),
  );
}

class AdminCabinetReview {
  final String? note;
  final DateTime? reviewedAt;
  final String? reviewerNickname;

  const AdminCabinetReview({this.note, this.reviewedAt, this.reviewerNickname});

  static AdminCabinetReview? fromJson(Object? json) {
    final map = _mapOf(json);
    if (map == null) return null;
    return AdminCabinetReview(
      note: _textOrNull(map['note']),
      reviewedAt: parseDate(map['reviewed_at']),
      reviewerNickname: _textOrNull(map['reviewer_nickname']),
    );
  }
}

class AdminCabinetSessionDetail {
  final String sessionNo;
  final String kind;
  final String status;
  final int version;
  final String? resultCode;
  final CabinetSessionResult? result;
  final AdminCabinetUserBrief? user;
  final CabinetBrief cabinet;
  final List<AdminCabinetSessionItem> items;
  final List<CabinetSessionDoor> doors;
  final int? remainingMs;
  final int? openMs;
  final String? notice;
  final String? locationStatus;
  final int? distanceM;
  final int? accuracyM;
  final String? closeReason;
  final DateTime? createdAt;
  final DateTime? startedAt;
  final DateTime? matchedAt;
  final DateTime? openedAt;
  final DateTime? closedAt;
  final DateTime? finishedAt;
  final String? adminReason;
  final bool adminForce;
  final List<AdminCabinetDoorTimeline> doorsTimeline;
  final List<AdminCabinetSessionEvent> events;
  final AdminCabinetReview? review;

  const AdminCabinetSessionDetail({
    required this.sessionNo,
    required this.kind,
    required this.status,
    this.version = 0,
    this.resultCode,
    this.result,
    this.user,
    required this.cabinet,
    this.items = const [],
    this.doors = const [],
    this.remainingMs,
    this.openMs,
    this.notice,
    this.locationStatus,
    this.distanceM,
    this.accuracyM,
    this.closeReason,
    this.createdAt,
    this.startedAt,
    this.matchedAt,
    this.openedAt,
    this.closedAt,
    this.finishedAt,
    this.adminReason,
    this.adminForce = false,
    this.doorsTimeline = const [],
    this.events = const [],
    this.review,
  });

  bool get isAdmin => kind == 'admin';

  bool get isActive => CabinetSession.activeStatuses.contains(status);

  bool get needsReview => status == CabinetSession.needsReviewStatus;

  bool get isSettled => CabinetSession.terminalStatuses.contains(status) || needsReview;

  bool get closeDoorFirst => notice == CabinetSession.noticeCloseDoorFirst;

  bool get canCommit => needsReview;

  bool get canDiscard => needsReview || const {CabinetSession.selecting, CabinetSession.matching, CabinetSession.opening}.contains(status);

  factory AdminCabinetSessionDetail.fromJson(Map<String, dynamic> json) => AdminCabinetSessionDetail(
    sessionNo: json['session_no'] as String? ?? '',
    kind: json['kind'] as String? ?? 'user',
    status: json['status'] as String? ?? '',
    version: parseInt(json['version']),
    resultCode: _textOrNull(json['result_code']),
    result: CabinetSessionResult.fromJson(json['result']),
    user: AdminCabinetUserBrief.fromJson(json['user']),
    cabinet: CabinetBrief.fromJson(_mapOf(json['cabinet']) ?? const {}),
    items: _mapsOf(json['items']).map(AdminCabinetSessionItem.fromJson).toList(),
    doors: _mapsOf(json['doors']).map(CabinetSessionDoor.fromJson).toList(),
    remainingMs: _intOrNull(json['remaining_ms']),
    openMs: _intOrNull(json['open_ms']),
    notice: _textOrNull(json['notice']),
    locationStatus: _textOrNull(json['location_status']),
    distanceM: _intOrNull(json['distance_m']),
    accuracyM: _intOrNull(json['accuracy_m']),
    closeReason: _textOrNull(json['close_reason']),
    createdAt: parseDate(json['created_at']),
    startedAt: parseDate(json['started_at']),
    matchedAt: parseDate(json['matched_at']),
    openedAt: parseDate(json['opened_at']),
    closedAt: parseDate(json['closed_at']),
    finishedAt: parseDate(json['finished_at']),
    adminReason: _textOrNull(json['admin_reason']),
    adminForce: json['admin_force'] == true,
    doorsTimeline: _mapsOf(json['doors_timeline']).map(AdminCabinetDoorTimeline.fromJson).toList(),
    events: _mapsOf(json['events']).map(AdminCabinetSessionEvent.fromJson).toList(),
    review: AdminCabinetReview.fromJson(json['review']),
  );
}

class AdminCabinetEventRow {
  final String type;
  final String source;
  final int? channel;
  final String? label;
  final String? deviceNo;
  final String? sessionNo;
  final int? orderId;
  final String? orderNo;
  final int? bookId;
  final String? bookNo;
  final AdminCabinetUserBrief? actor;
  final Map<String, dynamic>? detail;
  final String? result;
  final DateTime? occurredAt;
  final DateTime? receivedAt;

  const AdminCabinetEventRow({
    required this.type,
    required this.source,
    this.channel,
    this.label,
    this.deviceNo,
    this.sessionNo,
    this.orderId,
    this.orderNo,
    this.bookId,
    this.bookNo,
    this.actor,
    this.detail,
    this.result,
    this.occurredAt,
    this.receivedAt,
  });

  factory AdminCabinetEventRow.fromJson(Map<String, dynamic> json) => AdminCabinetEventRow(
    type: json['type'] as String? ?? '',
    source: json['source'] as String? ?? '',
    channel: _intOrNull(json['channel']),
    label: _textOrNull(json['label']),
    deviceNo: _textOrNull(json['device_no']),
    sessionNo: _textOrNull(json['session_no']),
    orderId: _intOrNull(json['order_id']),
    orderNo: _textOrNull(json['order_no']),
    bookId: _intOrNull(json['book_id']),
    bookNo: _textOrNull(json['book_no']),
    actor: AdminCabinetUserBrief.fromJson(json['actor']),
    detail: _mapOf(json['detail']),
    result: _textOrNull(json['result']),
    occurredAt: parseDate(json['occurred_at']),
    receivedAt: parseDate(json['received_at']),
  );
}

typedef AdminCabinetDoorBook = ({int bookId, String title});

class AdminCabinetManualReport {
  final String reportNo;
  final String kind;
  final String status;
  final String? targetStatus;
  final String? reason;
  final DateTime? createdAt;
  final DateTime? reviewedAt;
  final String? reviewNote;
  final AdminCabinetUserBrief? user;
  final int? orderId;
  final String? orderNo;
  final String? orderStatus;
  final int? bookId;
  final String? bookNo;
  final String? bookTitle;
  final List<String> titles;
  final bool requiresDoor;
  final List<AdminCabinetDoorBook> doorBooks;
  final String? reviewerNickname;

  const AdminCabinetManualReport({
    required this.reportNo,
    required this.kind,
    required this.status,
    this.targetStatus,
    this.reason,
    this.createdAt,
    this.reviewedAt,
    this.reviewNote,
    this.user,
    this.orderId,
    this.orderNo,
    this.orderStatus,
    this.bookId,
    this.bookNo,
    this.bookTitle,
    this.titles = const [],
    this.requiresDoor = false,
    this.doorBooks = const [],
    this.reviewerNickname,
  });

  bool get isPending => status == 'pending';

  factory AdminCabinetManualReport.fromJson(Map<String, dynamic> json) {
    final order = _mapOf(json['order']);
    final book = _mapOf(json['book']);
    return AdminCabinetManualReport(
      reportNo: json['report_no'] as String? ?? '',
      kind: json['kind'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      targetStatus: _textOrNull(json['target_status']),
      reason: _textOrNull(json['reason']),
      createdAt: parseDate(json['created_at']),
      reviewedAt: parseDate(json['reviewed_at']),
      reviewNote: _textOrNull(json['review_note']),
      user: AdminCabinetUserBrief.fromJson(json['user']),
      orderId: _intOrNull(order?['order_id']),
      orderNo: _textOrNull(order?['order_no']),
      orderStatus: _textOrNull(order?['status']),
      bookId: _intOrNull(book?['book_id']),
      bookNo: _textOrNull(book?['book_no']),
      bookTitle: _textOrNull(book?['title']),
      titles: _strings(json['titles']),
      requiresDoor: json['requires_door'] == true,
      doorBooks: [
        for (final book in _mapsOf(json['door_books']))
          if (parseInt(book['book_id']) > 0) (bookId: parseInt(book['book_id']), title: book['title'] as String? ?? ''),
      ],
      reviewerNickname: _textOrNull(json['reviewer_nickname']),
    );
  }
}
