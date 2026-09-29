import '../i18n/strings.dart';
import '../models/admin/cabinet_device.dart';
import '../services/location_service.dart';

class CabinetLabels {
  const CabinetLabels._();

  static Map<String, String> get sessionStatus => {
    'selecting': S.confirmingItems,
    'matching': S.confirmingNumber,
    'opening': S.opening,
    'open': S.doorOpened,
    'completed': S.orderCompleted,
    'partial': S.partlyCompleted,
    'cancelled': S.orderCancelled,
    'failed': S.failed,
    'expired': S.timedOut,
    'needs_review': S.awaitingReview,
  };

  static String status(String code) => sessionStatus[code] ?? code;

  static Map<String, String> get sessionKind => {
    'pickup': S.collect,
    'order_deposit': S.orderDropOff,
    'pre_deposit': S.preSaleDropOff,
    'retrieval': S.retrieval,
    'admin': S.adminOpening,
  };

  static String kind(String code) => sessionKind[code] ?? code;

  static Map<String, String> get closeReasons => {
    'user_done': S.donePhone,
    'timeout': S.countdownEnded,
    'sensor': S.doorSensor,
    'user_cancel': S.cancelledPhone,
    'reboot': S.deviceRestarted,
    'admin': S.resolvedBySupport,
    'admin_discard': S.resolvedBySupport,
  };

  static String closeReason(String? code) => code == null ? '' : closeReasons[code] ?? code;

  static Map<String, String> get events => {
    'boot': S.deviceStarted,
    'match_entered': S.matchCodeEntered,
    'door_opened': S.doorOpened,
    'door_closed': S.doorClosed,
    'session_closed': S.taskCloseReported,
    'close_refused': S.lockerRefusedEndDoorOpen,
    'fault': S.fault,
    'fault_cleared': S.faultResolved,
    'door_forced': S.unexpectedDoorOpening,
    'connection_lost': S.connectionLost,
    'connection_restored': S.connectionRestored,
    'paired': S.paired,
    'revoked': S.deviceRevoked,
    'session_created': S.taskCreated,
    'session_finished': S.taskFinished,
    'scan_rejected': S.scanRejected,
    'admin_open': S.remoteOpening,
    'door_placed': S.contentsRecorded,
    'door_cleared': S.contentsRecordCleared,
    'review_resolved': S.resolvedBySupport,
    'device_cloned': S.credentialPossiblyCopied,
    'ip_changed': S.sourceIpChanged,
    'door_check_required': S.doorNeedsChecking,
    'door_check_cleared': S.doorChecked,
    'item_blocked': S.itemBlocked,
    'manual_report': S.manualReport,
    'manual_report_reviewed': S.manualReportReviewed,
    'overdue_review': S.overdueOrderHeld,
    'delist_review': S.delistedOrderHeld,
    'late_door_opened': S.doorOpenedAfterTask,
  };

  static String event(String type) => events[type] ?? type;

  static String matchResult(bool matched) => matched ? S.numberMatched : S.numberDidNotMatch;

  static Map<String, String> get faults => {
    'LOCK_NO_RELEASE': S.lockDidNotRelease,
    'DOOR_LEFT_OPEN': S.doorLeftOpen,
    'DOOR_FORCED': S.doorForcedOpen,
    'SENSOR_ERROR': S.sensorError,
    'POWER': S.powerProblem,
    'SCREEN': S.screenProblem,
  };

  static String fault(String code) => faults[code] ?? code;

  static Map<String, String> get checkReasons => {
    'CANCELLED_AFTER_OPEN': S.dropOffCancelledAfterDoorOpened,
    'DISCARDED_AFTER_OPEN': S.dropOffMarkedAsNotCompleted,
    'DOOR_CONFLICT': S.anotherItemWasAlreadyDoor,
    'DOOR_UNCONFIRMED': S.doorOpeningNotReported,
    'LATE_OPEN': S.doorReportedOpenAfterTaskEnded,
    'MANUAL_REPORT': S.manualReportDuringFault,
    'ADMIN_OPEN': S.openedByStaff,
    'ADMIN_COMPLETED': S.orderCompletedBySupportBeforePickup,
    'ITEM_FAILED_AFTER_OPEN': S.collectionRetrievalNotCompletedAfterDoor,
  };

  static String checkReason(String code) => checkReasons[code] ?? code;

  static Map<String, String> get revokeReasons => {
    'device': S.unpairedByDevice,
    'replaced': S.replacedByNewDevice,
    'cloned': S.credentialPossiblyCopied,
    'admin': S.revokedByAdministrator,
    'simulator_off': S.simulatorTurnedOff,
  };

  static String revokeReason(String code) => revokeReasons[code] ?? code;

  static Map<String, String> get accessReasons => {
    'no_device': S.noDevice,
    'offline': S.deviceOffline,
    'fault': S.deviceFault,
    'maintenance': S.underMaintenance,
    'inactive': S.lockerInactive,
  };

  static String accessReason(String? code) => code == null ? '' : accessReasons[code] ?? code;

  static String access(String mode, String? reason) => switch (mode) {
    'scan' => S.scanningRequired,
    'unavailable' => accessUnavailable(accessReason(reason)),
    _ => accessManual(accessReason(reason)),
  };

  static String accessManual(String reason) => S.manualReportingAllowedP0(reason);

  static String accessUnavailable(String reason) => S.userAccessSuspendedP0(reason);

  static String deviceKind(String kind) => kind == AdminCabinetDeviceInfo.kindSimulator ? S.simulator : S.physicalLocker;

  static String deviceState({String? status, bool online = false}) {
    if (status == null) return S.noDevicePaired;
    if (status == 'pending') return S.awaitingPairing;
    return online ? S.online : S.offline;
  }

  static String location(String? status, int? distanceM) {
    if (status == 'granted' && distanceM != null) return distance(LocationService.formatDistance(distanceM));
    if (status == 'denied') return S.locationNotPermitted;
    if (status == null) return '';
    return S.locationUnavailable;
  }

  static String distance(String value) => S.aboutP0Away(value);

  static String doorItem(AdminCabinetDoorItem item) => switch (item.kind) {
    AdminCabinetDoorItem.kindOrder => S.order(item.orderNo ?? ''),
    AdminCabinetDoorItem.kindDeposit => S.preSaleDropOff,
    _ => S.awaitingRetrieval,
  };

  static Map<String, String> get manualReportKinds => {
    'deposit': S.dropOffReport,
    'pickup': S.pickupReport,
    'retrieve': S.retrievalReport,
  };

  static String manualReportKind(String code) => manualReportKinds[code] ?? code;

  static Map<String, String> get manualReportStatuses => {
    'pending': S.awaitingReview,
    'confirmed': S.confirmed,
    'rejected': S.reportDismissed,
    'cancelled': S.noLongerValid,
  };

  static String manualReportStatus(String code) => manualReportStatuses[code] ?? code;
}
