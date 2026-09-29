import '../../i18n/strings.dart';
import '../../models/cabinet.dart';
import '../../models/order.dart';
import '../../services/location_service.dart';
import '../../utils/api_helpers.dart';

enum CabinetAction { pickup, orderDeposit, preDeposit, retrieve }

String cabinetActionLabel(CabinetAccess? access, CabinetAction action) {
  if (access == null || access.isManual) {
    return switch (action) {
      CabinetAction.pickup => S.iCollected,
      CabinetAction.orderDeposit => S.markAsDroppedOff,
      CabinetAction.preDeposit => S.dropOff,
      CabinetAction.retrieve => S.retrieve,
    };
  }
  return switch (action) {
    CabinetAction.pickup => S.scanLockerCollect,
    CabinetAction.orderDeposit || CabinetAction.preDeposit => S.scanLockerDropOff,
    CabinetAction.retrieve => S.scanLockerRetrieve,
  };
}

class CabinetMessages {
  const CabinetMessages._();

  static final _quotedName = RegExp(r'「([^」]+)」');

  static const capacityCodes = {'PREDEPOSIT_LIMIT', 'CABINET_FULL'};

  static String closedHours(String hours) => S.lockerClosedNowOpeningHoursP0(hours);

  static String doorUnavailable(String? reason) => reason == 'maintenance' ? S.lockerUnderMaintenance : S.lockerOutService;

  static String? precheck(CabinetAccess? access, CabinetAction action, {List<String> orderDoors = const []}) {
    if (access == null) return null;
    if (access.isUnavailable) return doorUnavailable(access.reason);
    if (!access.isScan) return null;
    if (!access.openNow && access.openHours.isNotEmpty) return closedHours(access.openHours);
    final noDoor = switch (action) {
      CabinetAction.orderDeposit => orderDoors.isEmpty && access.availableDoors == 0,
      CabinetAction.preDeposit => access.preDepositDoors == 0,
      _ => false,
    };
    return noDoor ? S.noDoorsAvailableMoment : null;
  }

  static String retrievalUnavailable(CabinetAccess? access) =>
      access?.reason == 'offline' ? S.lockerOfflineTemporarilyUnavailable : S.retrievalNotAvailableLockerRightNow;

  static String manualNotice(CabinetAccess? access) => switch (access?.reason) {
    'offline' => S.lockerOfflineSoDoorCannotOpened,
    'fault' => S.lockerOutOrderSoDoorCannot,
    _ => S.manualReportsTakeEffectAfterSupport,
  };

  static String error(CabinetApiError error) {
    switch (error.code) {
      case CabinetApiError.network:
        return S.networkError;
      case CabinetApiError.signedOut:
        return S.pleaseSignFirst;
      case 'CABINET_CODE_INVALID':
        return S.notSavemybookLockerQrCode;
      case 'CABINET_CODE_EXPIRED':
        return S.lockerQrCodeChangedScanCode;
      case 'CABINET_BUSY':
        return S.lockerUsePleaseWaitScanAgain;
      case 'CABINET_OFFLINE':
        return S.lockerOfflineTemporarilyUnavailable;
      case 'CABINET_MAINTENANCE':
        return doorUnavailable('maintenance');
      case 'CABINET_UNAVAILABLE':
        return doorUnavailable(null);
      case 'CABINET_CLOSED':
        final hours = formatTimeRange(error.openTime, error.closeTime);
        if (hours.isNotEmpty) return closedHours(hours);
      case CabinetApiError.locationRequired:
        return S.locationAccessRequiredUseLockerTurn;
      case CabinetApiError.locationUnavailable:
        return S.locationCouldNotConfirmedTurnLocation;
      case CabinetApiError.locationImprecise:
        return S.preciseLocationRequiredUseLockerTurn;
      case 'CABINET_TOO_FAR':
        final meters = error.distanceM;
        if (meters != null) return tooFar(LocationService.formatDistance(meters));
      case 'CABINET_WRONG_CABINET':
        final name = error.cabinet?.cabinetName;
        if (name != null && name.isNotEmpty) return wrongCabinet(name);
      case 'CABINET_CONTEXT_CHANGED':
        return S.itemChangedRefreshTryAgain;
      case 'CABINET_NOTHING_TO_DO':
        return S.noItemsHandleLocker;
      case 'CABINET_ITEM_BLOCKED':
        for (final item in error.items) {
          final blocked = item.blocked;
          if (blocked != null) return CabinetMessages.blocked(blocked);
        }
      case 'CABINET_ACTIVE_SESSION':
        return S.lockerTaskProgressFinishCancelFirst;
      case 'CABINET_NO_SELECTION':
        return S.selectLeastOneItem;
      case 'CABINET_FULL':
        return S.notEnoughDoorsAvailableSelectFewer;
      case 'PREDEPOSIT_LIMIT':
        return blocked(const CabinetNotice(code: 'PREDEPOSIT_LIMIT'));
      case 'CABINET_ITEMS_CHANGED':
        return S.someItemsChangedPleaseConfirmAgain;
      case 'CABINET_SESSION_NOT_FOUND':
        return S.lockerTaskWasNotFound;
      case 'CABINET_SESSION_STATE':
        return sessionState(error);
      case CabinetApiError.matchCodeInvalid:
        return S.enterTwoDigits;
      case 'CABINET_SCAN_REQUIRED':
        return S.lockerRequiresScanningScanQrCode;
      case 'CABINET_COOLDOWN':
        return cooldown(_minutes(error.retryAfterS));
      case 'ORDER_IN_CABINET_SESSION':
        return S.orderBeingHandledLockerPleaseTry;
      case 'MANUAL_REPORT_PENDING':
        return S.manualReportItemAlreadyAwaitingConfirmation;
      case 'RATE_LIMITED':
        return S.tooManyRequestsPleaseTryAgain;
    }
    return error.message.isNotEmpty ? error.message : S.somethingWentWrongPleaseTryAgain;
  }

  static String manualError(CabinetApiError error) => error.code == 'CABINET_FULL' ? S.noDoorsAvailableMoment : CabinetMessages.error(error);

  static int _minutes(int? seconds) {
    final value = seconds ?? 60;
    return value <= 60 ? 1 : (value / 60).ceil();
  }

  // 作業詳情不含關門時間：開門狀態下 close 被拒只會是書櫃已回報關門，其他操作被拒則是櫃門仍開著。
  static String sessionState(CabinetApiError error, {bool closing = false}) {
    if (error.session?.status != CabinetSession.open) return S.actionNotAvailableRightNow;
    return closing ? S.taskBeingProcessedPleaseWait : S.doorOpenActionNotAvailable;
  }

  static String closeError(CabinetApiError error) =>
      error.code == 'CABINET_SESSION_STATE' ? sessionState(error, closing: true) : CabinetMessages.error(error);

  static String admin(CabinetApiError error, {bool closing = false}) {
    switch (error.code) {
      case CabinetApiError.network:
        return S.networkError;
      case CabinetApiError.signedOut:
        return S.pleaseSignFirst;
      case 'CABINET_COOLDOWN':
        return adminCooldown(_minutes(error.retryAfterS));
      case 'DOOR_NOT_EMPTY':
        return S.doorRecordedContentsAwaitingCheckComplete;
      case CabinetApiError.matchCodeInvalid:
        return S.enterTwoDigits;
      case 'CABINET_SESSION_STATE':
        return sessionState(error, closing: closing);
      case 'CABINET_SESSION_NOT_FOUND':
        return S.lockerTaskWasNotFound;
      case 'PAIRING_CODE_INVALID':
        return S.pairingCodeInvalidExpired;
      case 'RATE_LIMITED':
        return S.tooManyRequestsPleaseTryAgain;
    }
    return error.message.isNotEmpty ? error.message : S.somethingWentWrongPleaseTryAgain;
  }

  static String pairError(CabinetApiError error) => error.code == 'RATE_LIMITED' ? S.tooManyAttemptsPleaseTryAgain : admin(error);

  static String adminCooldown(int minutes) => S.numberConfirmationWasNotCompletedSeveral(minutes);

  static String tooFar(String distance) => S.aboutP0FromLockerPleaseUse(distance);

  static String wrongCabinet(String name) => S.itemAssignedP0PleaseUseLocker(name);

  static String cooldown(int minutes) => S.severalTasksLockerWereNotCompleted(minutes);

  static String? otherCabinets(CabinetApiError error) {
    final names = [for (final c in error.otherCabinets) if (c.cabinetName.isNotEmpty) c.cabinetName];
    if (names.isEmpty) return null;
    return otherCabinetsAt(names.join('、'));
  }

  static String otherCabinetsAt(String names) => S.itemsP0(names);

  static String result(CabinetSessionResult? result) {
    if (result == null) return '';
    return switch (result.code) {
      'COMPLETED' => S.taskComplete,
      'PARTIAL' => S.someItemsWereNotCompleted,
      'ITEMS_FAILED' => S.itemsCouldNotCompleted,
      'MATCH_FAILED' => S.numberDidNotMatchTaskBeen,
      'MATCH_TIMEOUT' => S.numberWasNotConfirmedTimeTask,
      'SELECT_TIMEOUT' => S.itemsWereNotConfirmedTimeTask,
      'DEVICE_NO_RESPONSE' => S.lockerDidNotRespondDoorWas,
      'CANCELLED_BY_USER' => S.taskBeenCancelled,
      'CANCELLED_AFTER_OPEN' => S.taskBeenCancelledNothingChanged,
      'DEVICE_NO_ACK' => S.lockerDidNotConfirmDoorOpened,
      'DEVICE_LOST' => S.thereWasLockerConnectionProblemSupport,
      'DEVICE_INTERRUPTED' => S.lockerRestartedSupportConfirmTask,
      'ADMIN_RESOLVED_COMMIT' => result.outcome == CabinetSession.partial ? S.someItemsWereNotCompleted : S.supportConfirmedTaskComplete,
      'ADMIN_RESOLVED_DISCARD' => S.supportConfirmedTaskWasNotCompleted,
      'ADMIN_CANCELLED' => S.supportEndedTask,
      _ => result.message,
    };
  }

  static String partialTitle(CabinetSession session) =>
      session.result?.code == 'ITEMS_FAILED' ? S.itemsCouldNotCompleted : S.someItemsWereNotCompleted;

  static String completedTitle(CabinetSession session) {
    final kinds = {for (final item in session.selectedItems) item.kind};
    if (kinds.length == 1) {
      switch (kinds.first) {
        case CabinetItemKind.orderDeposit:
          return session.selectedItems.any((item) => item.isPartialDeposit) ? S.dropOffComplete : S.dropOffCompleteBuyerBeenNotified;
        case CabinetItemKind.preDeposit:
          return S.dropOffComplete;
        case CabinetItemKind.retrieval:
          return S.retrievalComplete;
        default:
          break;
      }
    }
    return S.taskComplete;
  }

  // 先行存書的上限與可用櫃門不足是整組共同的限制，於群組上方說明一次，不逐筆重複。
  static bool isSharedBlock(CabinetSessionItem item) =>
      item.kind == CabinetItemKind.preDeposit && capacityCodes.contains(item.blocked?.code);

  static List<String> sharedBlocks(List<CabinetSessionItem> items) {
    if (items.any((item) => !item.isBlocked)) return const [];
    return {for (final item in items) if (isSharedBlock(item)) blocked(item.blocked!)}.toList();
  }

  static String blocked(CabinetNotice notice) => switch (notice.code) {
    'DOOR_UNKNOWN' || 'DOOR_SHARED' => S.doorCouldNotIdentifiedPleaseContact,
    'DOOR_FAULT' => S.doorFaultyPleaseContactSupport,
    'DOOR_CHECK' => S.doorAwaitingCheckBySupportPlease,
    'CABINET_FULL' => S.noDoorsAvailableMoment,
    'PREDEPOSIT_LIMIT' => S.reachedPreSaleDropOffLimit,
    _ => notice.message,
  };

  static String itemError(CabinetNotice notice) => switch (notice.code) {
    'ITEM_CHANGED' => S.itemChanged,
    'DOOR_FAILED' => S.doorDidNotOpen,
    'DOOR_UNCONFIRMED' => S.doorOpeningNotConfirmedSupportCheck,
    'DOOR_CONFLICT' => S.anotherItemDoorSupportCheck,
    _ => notice.message,
  };

  static String itemNotDone(String reason) => S.notCompletedP0(reason);

  static String note(CabinetNotice notice, {CabinetSessionItem? item}) {
    if (notice.code == CabinetSessionItem.notePartialDeposit) {
      final stored = item?.booksWithDoor ?? 0;
      return item != null && item.isDone && stored > 0 ? S.depositedP0RemainingLater(stored) : S.depositPartialNotice;
    }
    if (notice.code != 'MOVE_TO_ORDER_CABINET') return notice.message;
    final name = _quotedName.firstMatch(notice.message)?.group(1);
    return name == null ? notice.message : moveTo(name);
  }

  static String moveTo(String name) => S.bookBeenSoldAfterRetrievingDrop(name);

  static String door(String label) => S.doorP0(label);

  static String placementLabel(Order order) => order.doors.isNotEmpty ? S.door : S.slot;

  static String orderPlacement(Order order) {
    if (order.doors.isNotEmpty) return door(order.doorLabel);
    return order.slotNumber.isEmpty ? '' : S.slot2(order.slotNumber);
  }
}
