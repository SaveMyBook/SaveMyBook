import '../utils/api_helpers.dart';

Map<String, dynamic>? _mapOf(Object? value) => value is Map ? Map<String, dynamic>.from(value) : null;

List<Map<String, dynamic>> _mapsOf(Object? value) =>
    value is List ? [for (final e in value) if (e is Map) Map<String, dynamic>.from(e)] : const [];

int? _intOrNull(Object? value) => value == null ? null : (value is num ? value.toInt() : int.tryParse('$value'));

double? _doubleOrNull(Object? value) => value == null ? null : (value is num ? value.toDouble() : double.tryParse('$value'));

String? _textOrNull(Object? value) {
  if (value == null) return null;
  final text = '$value';
  return text.isEmpty ? null : text;
}

List<String> _strings(Object? value) => value is List ? [for (final e in value) if (e != null) '$e'] : const [];

class CabinetAccess {
  static const scan = 'scan';
  static const manual = 'manual';
  static const unavailable = 'unavailable';

  final String mode;
  final String? reason;
  final bool openNow;
  final String? openTime;
  final String? closeTime;
  final int? availableDoors;
  final int? preDepositDoors;

  const CabinetAccess({
    required this.mode,
    this.reason,
    this.openNow = true,
    this.openTime,
    this.closeTime,
    this.availableDoors,
    this.preDepositDoors,
  });

  bool get isScan => mode == scan;

  bool get isManual => mode == manual;

  bool get isUnavailable => mode == unavailable;

  String get openHours => formatTimeRange(openTime, closeTime);

  static CabinetAccess? fromJson(Object? json) {
    final map = _mapOf(json);
    if (map == null || map['mode'] is! String) return null;
    return CabinetAccess(
      mode: map['mode'] as String,
      reason: _textOrNull(map['reason']),
      openNow: map['open_now'] != false,
      openTime: _textOrNull(map['open_time']),
      closeTime: _textOrNull(map['close_time']),
      availableDoors: _intOrNull(map['available_doors']),
      preDepositDoors: _intOrNull(map['pre_deposit_doors']),
    );
  }
}

class CabinetLocation {
  final int cabinetId;
  final String cabinetName;
  final String door;
  final bool retrievable;
  final CabinetAccess? access;

  const CabinetLocation({
    required this.cabinetId,
    required this.cabinetName,
    required this.door,
    this.retrievable = false,
    this.access,
  });

  static CabinetLocation? fromJson(Object? json) {
    final map = _mapOf(json);
    if (map == null) return null;
    return CabinetLocation(
      cabinetId: parseInt(map['cabinet_id']),
      cabinetName: map['cabinet_name'] as String? ?? '',
      door: map['door'] as String? ?? '',
      retrievable: map['retrievable'] == true,
      access: CabinetAccess.fromJson(map['access']),
    );
  }
}

class CabinetManualReport {
  static const kindDeposit = 'deposit';
  static const kindPickup = 'pickup';
  static const kindRetrieve = 'retrieve';

  final String reportNo;
  final String kind;
  final String status;
  final String? targetStatus;
  final String? reason;
  final DateTime? createdAt;
  final DateTime? reviewedAt;
  final String? reviewNote;

  const CabinetManualReport({
    required this.reportNo,
    required this.kind,
    required this.status,
    this.targetStatus,
    this.reason,
    this.createdAt,
    this.reviewedAt,
    this.reviewNote,
  });

  bool get isPending => status == 'pending';

  static CabinetManualReport? fromJson(Object? json) {
    final map = _mapOf(json);
    if (map == null || map['report_no'] is! String) return null;
    return CabinetManualReport(
      reportNo: map['report_no'] as String,
      kind: map['kind'] as String? ?? '',
      status: map['status'] as String? ?? 'pending',
      targetStatus: _textOrNull(map['target_status']),
      reason: _textOrNull(map['reason']),
      createdAt: parseDate(map['created_at']),
      reviewedAt: parseDate(map['reviewed_at']),
      reviewNote: _textOrNull(map['review_note']),
    );
  }
}

class CabinetContext {
  final String type;
  final int id;

  const CabinetContext.order(int orderId) : type = 'order', id = orderId;

  const CabinetContext.book(int bookId) : type = 'book', id = bookId;

  bool get isOrder => type == 'order';

  Map<String, dynamic> toJson() => {'type': type, 'id': id};

  @override
  bool operator ==(Object other) => other is CabinetContext && other.type == type && other.id == id;

  @override
  int get hashCode => Object.hash(type, id);
}

enum CabinetItemKind {
  pickup('pickup'),
  orderDeposit('order_deposit'),
  preDeposit('pre_deposit'),
  retrieval('retrieval');

  final String code;
  const CabinetItemKind(this.code);

  bool get isDeposit => this == orderDeposit || this == preDeposit;

  static CabinetItemKind? of(String? code) {
    for (final kind in values) {
      if (kind.code == code) return kind;
    }
    return null;
  }
}

class CabinetNotice {
  final String code;
  final String message;

  const CabinetNotice({required this.code, this.message = ''});

  static CabinetNotice? fromJson(Object? json) {
    final map = _mapOf(json);
    if (map == null || map['code'] == null) return null;
    return CabinetNotice(code: '${map['code']}', message: map['message'] as String? ?? '');
  }
}

class CabinetSessionBook {
  final int bookId;
  final String title;
  final String? imageUrl;
  final String? door;

  const CabinetSessionBook({required this.bookId, required this.title, this.imageUrl, this.door});

  factory CabinetSessionBook.fromJson(Map<String, dynamic> json) => CabinetSessionBook(
    bookId: parseInt(json['book_id']),
    title: json['title'] as String? ?? '',
    imageUrl: resolveAssetUrl(json['image_url']),
    door: _textOrNull(json['door']),
  );
}

class CabinetSessionItem {
  final String key;
  final String kindCode;
  final int? orderId;
  final String? orderNo;
  final List<CabinetSessionBook> books;
  final List<String> doors;
  final bool paused;
  final CabinetNotice? note;
  final bool selected;
  final CabinetNotice? blocked;
  final String result;
  final CabinetNotice? error;

  const CabinetSessionItem({
    required this.key,
    required this.kindCode,
    this.orderId,
    this.orderNo,
    this.books = const [],
    this.doors = const [],
    this.paused = false,
    this.note,
    this.selected = false,
    this.blocked,
    this.result = 'pending',
    this.error,
  });

  CabinetItemKind? get kind => CabinetItemKind.of(kindCode);

  bool get isBlocked => blocked != null;

  bool get isDone => result == 'done';

  bool get isFailed => result == 'failed';

  factory CabinetSessionItem.fromJson(Map<String, dynamic> json) => CabinetSessionItem(
    key: json['key'] as String? ?? '',
    kindCode: json['kind'] as String? ?? '',
    orderId: _intOrNull(json['order_id']),
    orderNo: _textOrNull(json['order_no']),
    books: _mapsOf(json['books']).map(CabinetSessionBook.fromJson).toList(),
    doors: _strings(json['doors']),
    paused: json['paused'] == true,
    note: CabinetNotice.fromJson(json['note']),
    selected: json['selected'] == true,
    blocked: CabinetNotice.fromJson(json['blocked']),
    result: json['result'] as String? ?? 'pending',
    error: CabinetNotice.fromJson(json['error']),
  );
}

class CabinetSessionDoor {
  final String label;
  final String state;

  const CabinetSessionDoor({required this.label, required this.state});

  factory CabinetSessionDoor.fromJson(Map<String, dynamic> json) =>
      CabinetSessionDoor(label: json['label'] as String? ?? '', state: json['state'] as String? ?? 'pending');
}

class CabinetBrief {
  final int cabinetId;
  final String cabinetName;
  final String address;
  final double? latitude;
  final double? longitude;
  final String? openTime;
  final String? closeTime;
  final int? availableDoors;
  final List<String> kinds;

  const CabinetBrief({
    required this.cabinetId,
    required this.cabinetName,
    this.address = '',
    this.latitude,
    this.longitude,
    this.openTime,
    this.closeTime,
    this.availableDoors,
    this.kinds = const [],
  });

  String get openHours => formatTimeRange(openTime, closeTime);

  bool get hasCoordinates => latitude != null && longitude != null && !(latitude == 0 && longitude == 0);

  factory CabinetBrief.fromJson(Map<String, dynamic> json) => CabinetBrief(
    cabinetId: parseInt(json['cabinet_id']),
    cabinetName: json['cabinet_name'] as String? ?? '',
    address: json['address'] as String? ?? '',
    latitude: _doubleOrNull(json['latitude']),
    longitude: _doubleOrNull(json['longitude']),
    openTime: _textOrNull(json['open_time']),
    closeTime: _textOrNull(json['close_time']),
    availableDoors: _intOrNull(json['available_doors']),
    kinds: _strings(json['kinds']),
  );
}

class CabinetSessionResult {
  final String outcome;
  final String code;
  final String message;

  const CabinetSessionResult({required this.outcome, required this.code, this.message = ''});

  static CabinetSessionResult? fromJson(Object? json) {
    final map = _mapOf(json);
    if (map == null) return null;
    return CabinetSessionResult(
      outcome: map['outcome'] as String? ?? '',
      code: map['code'] as String? ?? '',
      message: map['message'] as String? ?? '',
    );
  }
}

class CabinetSession {
  static const selecting = 'selecting';
  static const matching = 'matching';
  static const opening = 'opening';
  static const open = 'open';
  static const completed = 'completed';
  static const partial = 'partial';
  static const cancelled = 'cancelled';
  static const failed = 'failed';
  static const expired = 'expired';
  static const needsReviewStatus = 'needs_review';

  static const activeStatuses = {selecting, matching, opening, open};
  static const terminalStatuses = {completed, partial, cancelled, failed, expired};

  final String sessionNo;
  final String status;
  final int version;
  final CabinetBrief cabinet;
  final String? locationStatus;
  final int? distanceM;
  final List<CabinetSessionItem> items;
  final int? matchCode;
  final List<CabinetSessionDoor> doors;
  final int? remainingMs;
  final int? openMs;
  final CabinetSessionResult? result;
  final DateTime? createdAt;
  final DateTime? finishedAt;

  const CabinetSession({
    required this.sessionNo,
    required this.status,
    required this.version,
    required this.cabinet,
    this.locationStatus,
    this.distanceM,
    this.items = const [],
    this.matchCode,
    this.doors = const [],
    this.remainingMs,
    this.openMs,
    this.result,
    this.createdAt,
    this.finishedAt,
  });

  bool get isActive => activeStatuses.contains(status);

  bool get isTerminal => terminalStatuses.contains(status);

  bool get needsReview => status == needsReviewStatus;

  bool get isSettled => isTerminal || needsReview;

  bool get locationGranted => locationStatus == 'granted';

  List<String> get selectedKeys => [for (final item in items) if (item.selected && !item.isBlocked) item.key];

  List<CabinetSessionItem> get selectedItems => [for (final item in items) if (item.selected) item];

  List<CabinetSessionItem> itemsAtDoor(String label) =>
      [for (final item in items) if (item.selected && item.doors.contains(label)) item];

  factory CabinetSession.fromJson(Map<String, dynamic> json) => CabinetSession(
    sessionNo: json['session_no'] as String? ?? '',
    status: json['status'] as String? ?? '',
    version: parseInt(json['version']),
    cabinet: CabinetBrief.fromJson(_mapOf(json['cabinet']) ?? const {}),
    locationStatus: _textOrNull(json['location_status']),
    distanceM: _intOrNull(json['distance_m']),
    items: _mapsOf(json['items']).map(CabinetSessionItem.fromJson).toList(),
    matchCode: _intOrNull(_mapOf(json['match'])?['code']),
    doors: _mapsOf(json['doors']).map(CabinetSessionDoor.fromJson).toList(),
    remainingMs: _intOrNull(json['remaining_ms']),
    openMs: _intOrNull(json['open_ms']),
    result: CabinetSessionResult.fromJson(json['result']),
    createdAt: parseDate(json['created_at']),
    finishedAt: parseDate(json['finished_at']),
  );

  static CabinetSession? tryParse(Object? json) {
    final map = _mapOf(json);
    if (map == null || map['session_no'] is! String || map['status'] is! String) return null;
    try {
      return CabinetSession.fromJson(map);
    } catch (_) {
      return null;
    }
  }
}

class CabinetApiError {
  static const network = 'NETWORK';
  static const signedOut = 'SIGNED_OUT';

  final String code;
  final String message;
  final int? status;

  final Map<String, dynamic> extra;

  const CabinetApiError({required this.code, this.message = '', this.status, this.extra = const {}});

  factory CabinetApiError.fromResponse(Map<String, dynamic> res) {
    final extra = Map<String, dynamic>.from(res)..removeWhere((k, _) => const {'success', 'code', 'message', 'status'}.contains(k));
    return CabinetApiError(
      code: res['code'] as String? ?? '',
      message: res['message'] as String? ?? '',
      status: _intOrNull(res['status']),
      extra: extra,
    );
  }

  bool get isNetwork => code == network;

  bool get manualAllowed => extra['manual_allowed'] == true;

  int? get distanceM => _intOrNull(extra['distance_m']);

  int? get retryAfterS => _intOrNull(extra['retry_after_s']);

  String? get sessionNo => _textOrNull(extra['session_no']);

  String? get openTime => _textOrNull(extra['open_time']);

  String? get closeTime => _textOrNull(extra['close_time']);

  int? get availableDoors => _intOrNull(extra['available_doors']);

  int? get requiredDoors => _intOrNull(extra['required_doors']);

  CabinetBrief? get cabinet {
    final map = _mapOf(extra['cabinet']);
    return map == null ? null : CabinetBrief.fromJson(map);
  }

  List<CabinetBrief> get otherCabinets => _mapsOf(extra['other_cabinets']).map(CabinetBrief.fromJson).toList();

  List<CabinetSessionItem> get items => _mapsOf(extra['items']).map(CabinetSessionItem.fromJson).toList();

  CabinetSession? get session => CabinetSession.tryParse(extra['session']);
}
