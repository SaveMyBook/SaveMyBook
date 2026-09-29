import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:savemybook_app/features/cabinet/cabinet_flow_controller.dart';
import 'package:savemybook_app/features/cabinet/cabinet_messages.dart';
import 'package:savemybook_app/i18n/app_localizations.dart';
import 'package:savemybook_app/i18n/strings.dart';
import 'package:savemybook_app/models/admin_models.dart';
import 'package:savemybook_app/models/cabinet.dart';
import 'package:savemybook_app/services/location_service.dart';
import 'package:savemybook_app/utils/cabinet_labels.dart';

CabinetApiError _error(String code, [Map<String, dynamic> extra = const {}, String message = '']) =>
    CabinetApiError(code: code, message: message, extra: extra);

class _FakeGeolocator extends GeolocatorPlatform {
  _FakeGeolocator({
    this.permission = LocationPermission.whileInUse,
    this.afterRequest = LocationPermission.whileInUse,
    this.serviceEnabled = true,
    this.position,
    this.accuracy = LocationAccuracyStatus.precise,
    this.upgraded = LocationAccuracyStatus.reduced,
  });

  LocationPermission permission;
  final LocationPermission afterRequest;
  final bool serviceEnabled;
  final Position? position;
  LocationAccuracyStatus accuracy;
  final LocationAccuracyStatus upgraded;
  int requests = 0;
  int lastKnownCalls = 0;
  final List<String> purposeKeys = [];
  LocationSettings? settings;

  @override
  Future<LocationAccuracyStatus> getLocationAccuracy() async => accuracy;

  @override
  Future<LocationAccuracyStatus> requestTemporaryFullAccuracy({required String purposeKey}) async {
    purposeKeys.add(purposeKey);
    return accuracy = upgraded;
  }

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    requests++;
    return permission = afterRequest;
  }

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<Position?> getLastKnownPosition({bool forceLocationManager = false}) async {
    lastKnownCalls++;
    return _position(DateTime(2026));
  }

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) async {
    settings = locationSettings;
    final p = position;
    if (p == null) throw _NoFix();
    return p;
  }
}

class _NoFix implements Exception {}

Position _position(DateTime at) => Position(
  latitude: 25.0421,
  longitude: 121.5254,
  timestamp: at,
  accuracy: 18,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

void main() {
  setUp(() => S = AppLocalizations.fallback);

  group('cabinetActionLabel', () {
    test('掃碼與停用的書櫃顯示掃碼文字，手動或沒有資料時沿用既有文字', () {
      const scan = CabinetAccess(mode: CabinetAccess.scan);
      const unavailable = CabinetAccess(mode: CabinetAccess.unavailable, reason: 'maintenance');
      const manual = CabinetAccess(mode: CabinetAccess.manual, reason: 'offline');

      expect(cabinetActionLabel(scan, CabinetAction.pickup), S.scanLockerCollect);
      expect(cabinetActionLabel(unavailable, CabinetAction.orderDeposit), S.scanLockerDropOff);
      expect(cabinetActionLabel(scan, CabinetAction.preDeposit), S.scanLockerDropOff);
      expect(cabinetActionLabel(scan, CabinetAction.retrieve), S.scanLockerRetrieve);
      expect(cabinetActionLabel(manual, CabinetAction.pickup), S.iCollected);
      expect(cabinetActionLabel(null, CabinetAction.orderDeposit), S.markAsDroppedOff);
      expect(cabinetActionLabel(manual, CabinetAction.preDeposit), S.dropOff);
      expect(cabinetActionLabel(null, CabinetAction.retrieve), S.retrieve);
    });
  });

  group('CabinetMessages.precheck', () {
    test('停用、維修與非營業時間在進入掃碼前擋下', () {
      expect(
        CabinetMessages.precheck(const CabinetAccess(mode: 'unavailable', reason: 'maintenance'), CabinetAction.pickup),
        S.lockerUnderMaintenance,
      );
      expect(CabinetMessages.precheck(const CabinetAccess(mode: 'unavailable', reason: 'inactive'), CabinetAction.pickup), S.lockerOutService);
      expect(
        CabinetMessages.precheck(
          const CabinetAccess(mode: 'scan', openNow: false, openTime: '08:00', closeTime: '22:00'),
          CabinetAction.retrieve,
        ),
        S.lockerClosedNowOpeningHoursP0('08:00~22:00'),
      );
    });

    test('櫃門不足只檢查存書；訂單已有櫃門時不擋', () {
      const full = CabinetAccess(mode: 'scan', availableDoors: 0, preDepositDoors: 0);
      expect(CabinetMessages.precheck(full, CabinetAction.orderDeposit), S.noDoorsAvailableMoment);
      expect(CabinetMessages.precheck(full, CabinetAction.orderDeposit, orderDoors: ['A02']), isNull);
      expect(CabinetMessages.precheck(full, CabinetAction.preDeposit), S.noDoorsAvailableMoment);
      expect(CabinetMessages.precheck(full, CabinetAction.pickup), isNull);
      expect(CabinetMessages.precheck(full, CabinetAction.retrieve), isNull);
      expect(CabinetMessages.precheck(const CabinetAccess(mode: 'scan', availableDoors: 1, preDepositDoors: 0), CabinetAction.orderDeposit), isNull);
      expect(CabinetMessages.precheck(const CabinetAccess(mode: 'manual', reason: 'offline'), CabinetAction.preDeposit), isNull);
      expect(CabinetMessages.precheck(null, CabinetAction.preDeposit), isNull);
    });
  });

  group('CabinetMessages.error', () {
    test('每個錯誤代碼都對應本地化文字', () {
      final expected = <String, String>{
        'CABINET_CODE_INVALID': S.notSavemybookLockerQrCode,
        'CABINET_CODE_EXPIRED': S.lockerQrCodeChangedScanCode,
        'CABINET_BUSY': S.lockerUsePleaseWaitScanAgain,
        'CABINET_OFFLINE': S.lockerOfflineTemporarilyUnavailable,
        'CABINET_MAINTENANCE': S.lockerUnderMaintenance,
        'CABINET_UNAVAILABLE': S.lockerOutService,
        'CABINET_CONTEXT_CHANGED': S.itemChangedRefreshTryAgain,
        'CABINET_NOTHING_TO_DO': S.noItemsHandleLocker,
        'CABINET_ACTIVE_SESSION': S.lockerTaskProgressFinishCancelFirst,
        'CABINET_NO_SELECTION': S.selectLeastOneItem,
        'CABINET_FULL': S.notEnoughDoorsAvailableSelectFewer,
        'PREDEPOSIT_LIMIT': S.reachedPreSaleDropOffLimit,
        'CABINET_ITEMS_CHANGED': S.someItemsChangedPleaseConfirmAgain,
        'CABINET_SESSION_NOT_FOUND': S.lockerTaskWasNotFound,
        'CABINET_SESSION_STATE': S.actionNotAvailableRightNow,
        'MATCH_CODE_INVALID': S.enterTwoDigits,
        'CABINET_LOCATION_REQUIRED': S.locationAccessRequiredUseLockerTurn,
        'CABINET_LOCATION_UNAVAILABLE': S.locationCouldNotConfirmedTurnLocation,
        'CABINET_SCAN_REQUIRED': S.lockerRequiresScanningScanQrCode,
        'ORDER_IN_CABINET_SESSION': S.orderBeingHandledLockerPleaseTry,
        'MANUAL_REPORT_PENDING': S.manualReportItemAlreadyAwaitingConfirmation,
        'RATE_LIMITED': S.tooManyRequestsPleaseTryAgain,
        CabinetApiError.network: S.networkError,
        CabinetApiError.signedOut: S.pleaseSignFirst,
      };
      for (final entry in expected.entries) {
        expect(CabinetMessages.error(_error(entry.key, const {}, '伺服器文字')), entry.value, reason: entry.key);
      }
    });

    test('帶參數的錯誤使用附帶欄位，取不到時退回伺服器文字', () {
      expect(
        CabinetMessages.error(_error('CABINET_CLOSED', {'open_time': '08:00', 'close_time': '22:00'})),
        S.lockerClosedNowOpeningHoursP0('08:00~22:00'),
      );
      expect(CabinetMessages.error(_error('CABINET_CLOSED', const {}, '伺服器文字')), '伺服器文字');
      expect(
        CabinetMessages.error(_error('CABINET_TOO_FAR', {'distance_m': 850})),
        S.aboutP0FromLockerPleaseUse(LocationService.formatDistance(850)),
      );
      expect(
        CabinetMessages.error(_error('CABINET_WRONG_CABINET', {'cabinet': {'cabinet_id': 3, 'cabinet_name': '北商大書櫃'}})),
        S.itemAssignedP0PleaseUseLocker('北商大書櫃'),
      );
      expect(CabinetMessages.error(_error('CABINET_COOLDOWN', {'retry_after_s': 452})), S.severalTasksLockerWereNotCompleted(8));
      expect(CabinetMessages.error(_error('CABINET_COOLDOWN', {'retry_after_s': 12})), S.severalTasksLockerWereNotCompleted(1));
      final open = _error('CABINET_SESSION_STATE', {'session': {'session_no': 'CS1', 'status': 'open', 'version': 3}});
      final opening = _error('CABINET_SESSION_STATE', {'session': {'session_no': 'CS1', 'status': 'opening', 'version': 3}});
      expect(CabinetMessages.error(open), S.doorOpenActionNotAvailable);
      expect(CabinetMessages.error(opening), S.actionNotAvailableRightNow);
      expect(CabinetMessages.closeError(open), S.taskBeingProcessedPleaseWait);
      expect(CabinetMessages.closeError(opening), S.actionNotAvailableRightNow);
      expect(CabinetMessages.closeError(_error('CABINET_SESSION_NOT_FOUND')), S.lockerTaskWasNotFound);
      expect(
        CabinetMessages.error(_error('CABINET_ITEM_BLOCKED', {
          'items': [
            {'key': 'order:1', 'kind': 'pickup', 'blocked': null},
            {'key': 'order:2', 'kind': 'pickup', 'blocked': {'code': 'DOOR_CHECK', 'message': '此項目的櫃門待客服確認，請聯絡客服'}},
          ],
        })),
        S.doorAwaitingCheckBySupportPlease,
      );
      expect(CabinetMessages.error(_error('SOMETHING_NEW', const {}, '伺服器文字')), '伺服器文字');
      expect(CabinetMessages.error(_error('SOMETHING_NEW')), S.somethingWentWrongPleaseTryAgain);
    });

    test('後台書櫃錯誤依代碼顯示，未對照的代碼退回伺服器文字', () {
      final expected = <String, String>{
        'DOOR_NOT_EMPTY': S.doorRecordedContentsAwaitingCheckComplete,
        'MATCH_CODE_INVALID': S.enterTwoDigits,
        'CABINET_SESSION_STATE': S.actionNotAvailableRightNow,
        'CABINET_SESSION_NOT_FOUND': S.lockerTaskWasNotFound,
        'PAIRING_CODE_INVALID': S.pairingCodeInvalidExpired,
        'RATE_LIMITED': S.tooManyRequestsPleaseTryAgain,
        CabinetApiError.network: S.networkError,
        CabinetApiError.signedOut: S.pleaseSignFirst,
      };
      for (final entry in expected.entries) {
        expect(CabinetMessages.admin(_error(entry.key, const {}, '伺服器文字')), entry.value, reason: entry.key);
      }
      expect(CabinetMessages.admin(_error('CABINET_COOLDOWN', {'retry_after_s': 452})), S.numberConfirmationWasNotCompletedSeveral(8));
      expect(CabinetMessages.admin(_error('CABINET_COOLDOWN', {'retry_after_s': 30})), S.numberConfirmationWasNotCompletedSeveral(1));
      final open = _error('CABINET_SESSION_STATE', {'session': {'session_no': 'CS1', 'status': 'open', 'version': 3}});
      expect(CabinetMessages.admin(open), S.doorOpenActionNotAvailable);
      expect(CabinetMessages.admin(open, closing: true), S.taskBeingProcessedPleaseWait);
      expect(CabinetMessages.admin(_error('DEVICE_OFFLINE', const {}, '伺服器文字')), '伺服器文字');
      expect(CabinetMessages.admin(_error('DEVICE_OFFLINE')), S.somethingWentWrongPleaseTryAgain);
      expect(CabinetMessages.pairError(_error('RATE_LIMITED')), S.tooManyAttemptsPleaseTryAgain);
      expect(CabinetMessages.pairError(_error('PAIRING_CODE_INVALID')), S.pairingCodeInvalidExpired);
    });

    test('其他書櫃的待辦項目以「、」連接', () {
      final error = _error('CABINET_NOTHING_TO_DO', {
        'other_cabinets': [
          {'cabinet_id': 5, 'cabinet_name': '師大書櫃', 'kinds': ['pickup']},
          {'cabinet_id': 6, 'cabinet_name': '台大書櫃', 'kinds': ['retrieval']},
        ],
      });
      expect(CabinetMessages.otherCabinets(error), S.itemsP0('師大書櫃、台大書櫃'));
      expect(CabinetMessages.otherCabinets(_error('CABINET_NOTHING_TO_DO')), isNull);
    });
  });

  group('作業結果、不可辦理原因與項目錯誤', () {
    CabinetSessionResult result(String code, [String outcome = 'failed']) => CabinetSessionResult(outcome: outcome, code: code, message: '伺服器文字');

    test('結果代碼對應本地化文字', () {
      expect(CabinetMessages.result(result('COMPLETED', 'completed')), S.taskComplete);
      expect(CabinetMessages.result(result('PARTIAL', 'partial')), S.someItemsWereNotCompleted);
      expect(CabinetMessages.result(result('ITEMS_FAILED', 'partial')), S.itemsCouldNotCompleted);
      expect(CabinetMessages.result(result('MATCH_FAILED')), S.numberDidNotMatchTaskBeen);
      expect(CabinetMessages.result(result('MATCH_TIMEOUT', 'expired')), S.numberWasNotConfirmedTimeTask);
      expect(CabinetMessages.result(result('SELECT_TIMEOUT', 'expired')), S.itemsWereNotConfirmedTimeTask);
      expect(CabinetMessages.result(result('DEVICE_NO_RESPONSE')), S.lockerDidNotRespondDoorWas);
      expect(CabinetMessages.result(result('CANCELLED_BY_USER', 'cancelled')), S.taskBeenCancelled);
      expect(CabinetMessages.result(result('CANCELLED_AFTER_OPEN', 'cancelled')), S.taskBeenCancelledNothingChanged);
      expect(CabinetMessages.result(result('DEVICE_NO_ACK', 'needs_review')), S.lockerDidNotConfirmDoorOpened);
      expect(CabinetMessages.result(result('DEVICE_LOST', 'needs_review')), S.thereWasLockerConnectionProblemSupport);
      expect(CabinetMessages.result(result('DEVICE_INTERRUPTED', 'needs_review')), S.lockerRestartedSupportConfirmTask);
      expect(CabinetMessages.result(result('ADMIN_RESOLVED_COMMIT', 'completed')), S.supportConfirmedTaskComplete);
      expect(CabinetMessages.result(result('ADMIN_RESOLVED_COMMIT', 'partial')), S.someItemsWereNotCompleted);
      expect(CabinetMessages.result(result('ADMIN_RESOLVED_DISCARD', 'cancelled')), S.supportConfirmedTaskWasNotCompleted);
      expect(CabinetMessages.result(result('ADMIN_CANCELLED', 'cancelled')), S.supportEndedTask);
      expect(CabinetMessages.result(result('NEW_CODE')), '伺服器文字');
      expect(CabinetMessages.result(null), '');
    });

    test('完成標題依所選項目的種類決定', () {
      CabinetSession of(List<String> kinds) => CabinetSession(
        sessionNo: 'CS1',
        status: 'completed',
        version: 1,
        cabinet: const CabinetBrief(cabinetId: 3, cabinetName: '北商大書櫃'),
        items: [
          for (final (i, kind) in kinds.indexed) CabinetSessionItem(key: 'k$i', kindCode: kind, selected: true),
          const CabinetSessionItem(key: 'unselected', kindCode: 'pickup'),
        ],
      );
      expect(CabinetMessages.completedTitle(of(['order_deposit', 'order_deposit'])), S.dropOffCompleteBuyerBeenNotified);
      expect(CabinetMessages.completedTitle(of(['pre_deposit'])), S.dropOffComplete);
      expect(CabinetMessages.completedTitle(of(['retrieval'])), S.retrievalComplete);
      expect(CabinetMessages.completedTitle(of(['pickup', 'retrieval'])), S.taskComplete);
    });

    test('不可辦理原因、項目錯誤與取回提示', () {
      expect(CabinetMessages.blocked(const CabinetNotice(code: 'DOOR_UNKNOWN')), S.doorCouldNotIdentifiedPleaseContact);
      expect(CabinetMessages.blocked(const CabinetNotice(code: 'DOOR_SHARED')), S.doorCouldNotIdentifiedPleaseContact);
      expect(CabinetMessages.blocked(const CabinetNotice(code: 'DOOR_FAULT')), S.doorFaultyPleaseContactSupport);
      expect(CabinetMessages.blocked(const CabinetNotice(code: 'DOOR_CHECK')), S.doorAwaitingCheckBySupportPlease);
      expect(CabinetMessages.blocked(const CabinetNotice(code: 'CABINET_FULL')), S.noDoorsAvailableMoment);
      expect(CabinetMessages.blocked(const CabinetNotice(code: 'PREDEPOSIT_LIMIT')), S.reachedPreSaleDropOffLimit);
      expect(CabinetMessages.itemError(const CabinetNotice(code: 'ITEM_CHANGED')), S.itemChanged);
      expect(CabinetMessages.itemError(const CabinetNotice(code: 'DOOR_FAILED')), S.doorDidNotOpen);
      expect(CabinetMessages.itemError(const CabinetNotice(code: 'DOOR_UNCONFIRMED')), S.doorOpeningNotConfirmedSupportCheck);
      expect(CabinetMessages.itemError(const CabinetNotice(code: 'DOOR_CONFLICT')), S.anotherItemDoorSupportCheck);
      expect(CabinetMessages.itemNotDone(S.itemChanged), S.notCompletedP0(S.itemChanged));
      expect(
        CabinetMessages.note(const CabinetNotice(code: 'MOVE_TO_ORDER_CABINET', message: '此書籍已售出，取回後請存入訂單指定的書櫃「師大書櫃」')),
        S.bookBeenSoldAfterRetrievingDrop('師大書櫃'),
      );
      expect(CabinetMessages.note(const CabinetNotice(code: 'MOVE_TO_ORDER_CABINET', message: '無書櫃名稱')), '無書櫃名稱');
      expect(CabinetMessages.door('A02'), S.doorP0('A02'));
    });

    test('先行存書的上限與櫃門不足只在群組說明一次；其他種類與櫃門問題仍逐筆說明', () {
      CabinetSessionItem item(String kind, String key, [String? code]) =>
          CabinetSessionItem(key: key, kindCode: kind, blocked: code == null ? null : CabinetNotice(code: code));
      final limit = item('pre_deposit', 'book:60', 'PREDEPOSIT_LIMIT');
      final full = item('pre_deposit', 'book:61', 'CABINET_FULL');
      expect(CabinetMessages.isSharedBlock(limit), isTrue);
      expect(CabinetMessages.isSharedBlock(full), isTrue);
      expect(CabinetMessages.isSharedBlock(item('pre_deposit', 'book:62')), isFalse);
      expect(CabinetMessages.isSharedBlock(item('order_deposit', 'order:1', 'CABINET_FULL')), isFalse);
      expect(CabinetMessages.isSharedBlock(item('retrieval', 'book:63', 'DOOR_FAULT')), isFalse);

      expect(CabinetMessages.sharedBlocks([limit, item('pre_deposit', 'book:64', 'PREDEPOSIT_LIMIT')]), [S.reachedPreSaleDropOffLimit]);
      expect(CabinetMessages.sharedBlocks([limit, full]), [S.reachedPreSaleDropOffLimit, S.noDoorsAvailableMoment]);
      expect(CabinetMessages.sharedBlocks([limit, item('pre_deposit', 'book:62')]), isEmpty, reason: '仍有可選的書時只顯示限一本的說明');
      expect(CabinetItemKind.preDeposit.isSingleChoice, isTrue);
      expect(CabinetItemKind.values.where((kind) => kind.isSingleChoice), [CabinetItemKind.preDeposit]);
    });

    test('部分完成的標題依結果代碼區分', () {
      CabinetSession of(String code) => CabinetSession(
        sessionNo: 'CS1',
        status: 'partial',
        version: 1,
        cabinet: const CabinetBrief(cabinetId: 3, cabinetName: '北商大書櫃'),
        items: const [],
        result: CabinetSessionResult(outcome: 'partial', code: code, message: ''),
      );
      expect(CabinetMessages.partialTitle(of('PARTIAL')), S.someItemsWereNotCompleted);
      expect(CabinetMessages.partialTitle(of('ITEMS_FAILED')), S.itemsCouldNotCompleted);
    });

    test('手動回報存書的櫃門不足與無法回報取回的說明', () {
      expect(CabinetMessages.manualError(_error('CABINET_FULL', const {}, '伺服器文字')), S.noDoorsAvailableMoment);
      expect(CabinetMessages.manualError(_error('PREDEPOSIT_LIMIT')), S.reachedPreSaleDropOffLimit);
      expect(CabinetMessages.manualError(_error('MANUAL_REPORT_PENDING')), S.manualReportItemAlreadyAwaitingConfirmation);
      expect(CabinetMessages.retrievalUnavailable(const CabinetAccess(mode: 'manual', reason: 'offline')), S.lockerOfflineTemporarilyUnavailable);
      expect(CabinetMessages.retrievalUnavailable(const CabinetAccess(mode: 'manual', reason: 'no_device')), S.retrievalNotAvailableLockerRightNow);
      expect(CabinetMessages.retrievalUnavailable(null), S.retrievalNotAvailableLockerRightNow);
    });

    test('手動回報的說明依開放原因區分', () {
      expect(CabinetMessages.manualNotice(const CabinetAccess(mode: 'manual', reason: 'offline')), S.lockerOfflineSoDoorCannotOpened);
      expect(CabinetMessages.manualNotice(const CabinetAccess(mode: 'manual', reason: 'fault')), S.lockerOutOrderSoDoorCannot);
      expect(CabinetMessages.manualNotice(const CabinetAccess(mode: 'manual', reason: 'no_device')), S.manualReportsTakeEffectAfterSupport);
      expect(CabinetMessages.manualNotice(null), S.manualReportsTakeEffectAfterSupport);
    });
  });

  group('CabinetLabels', () {
    test('代碼對應後台標籤，未知代碼直接顯示代碼', () {
      expect(CabinetLabels.status('needs_review'), S.awaitingReview);
      expect(CabinetLabels.status('open'), S.doorOpened);
      expect(CabinetLabels.kind('order_deposit'), S.orderDropOff);
      expect(CabinetLabels.closeReason('user_done'), S.donePhone);
      expect(CabinetLabels.closeReason('user_cancel'), S.cancelledPhone);
      expect(CabinetLabels.closeReason('sensor'), S.doorSensor);
      expect(CabinetLabels.closeReason(null), '');
      expect(CabinetLabels.event('fault_cleared'), S.faultResolved);
      expect(CabinetLabels.event('match_entered'), S.matchCodeEntered);
      expect(CabinetLabels.event('close_refused'), S.lockerRefusedEndDoorOpen);
      expect(CabinetLabels.matchResult(true), S.numberMatched);
      expect(CabinetLabels.matchResult(false), S.numberDidNotMatch);
      expect(CabinetLabels.event('brand_new_event'), 'brand_new_event');
      expect(CabinetLabels.fault('LOCK_NO_RELEASE'), S.lockDidNotRelease);
      expect(CabinetLabels.fault('X_UNKNOWN'), 'X_UNKNOWN');
      expect(CabinetLabels.checkReason('ADMIN_OPEN'), S.openedByStaff);
      expect(CabinetLabels.access('scan', null), S.scanningRequired);
      expect(CabinetLabels.access('manual', 'offline'), S.manualReportingAllowedP0(S.deviceOffline));
      expect(CabinetLabels.access('unavailable', 'inactive'), S.userAccessSuspendedP0(S.lockerInactive));
      expect(CabinetLabels.deviceKind('simulator'), S.simulator);
      expect(CabinetLabels.deviceKind('esp32'), S.physicalLocker);
      expect(CabinetLabels.deviceState(), S.noDevicePaired);
      expect(CabinetLabels.deviceState(status: 'pending'), S.awaitingPairing);
      expect(CabinetLabels.deviceState(status: 'active', online: true), S.online);
      expect(CabinetLabels.deviceState(status: 'active'), S.offline);
      expect(CabinetLabels.location('granted', 120), S.aboutP0Away(LocationService.formatDistance(120)));
      expect(CabinetLabels.location('denied', null), S.locationNotPermitted);
      expect(CabinetLabels.location('unavailable', 900), S.locationUnavailable);
      expect(CabinetLabels.location(null, null), '');
      expect(CabinetLabels.manualReportKind('deposit'), S.dropOffReport);
      expect(CabinetLabels.manualReportStatus('cancelled'), S.noLongerValid);
      expect(
        CabinetLabels.doorItem(const AdminCabinetDoorItem(kind: 'order', bookId: 1, bookNo: 'BK1', title: 'x', orderNo: 'SMB1')),
        S.order('SMB1'),
      );
      expect(CabinetLabels.doorItem(const AdminCabinetDoorItem(kind: 'deposit', bookId: 1, bookNo: 'BK1', title: 'x')), S.preSaleDropOff);
      expect(CabinetLabels.doorItem(const AdminCabinetDoorItem(kind: 'other', bookId: 1, bookNo: 'BK1', title: 'x')), S.awaitingRetrieval);
    });
  });

  test('新增的書櫃字串在六種語系都有譯文且參數一致', () {
    final table = [
      File('tool/i18n_table/b52_cabinet_scan.py').readAsStringSync(),
      File('tool/i18n_table/b53_cabinet_review.py').readAsStringSync(),
      File('tool/i18n_table/b54_cabinet_reverse.py').readAsStringSync(),
      File('tool/i18n_table/b55_cabinet_followup.py').readAsStringSync(),
    ].join('\n');
    final zh = jsonDecode(File('lib/i18n/app_zh.arb').readAsStringSync()) as Map<String, dynamic>;
    final byText = {for (final e in zh.entries) if (e.value is String) e.value as String: e.key};
    final keys = <String>{};
    for (final m in RegExp(r"^    '([^']+)': \(", multiLine: true).allMatches(table)) {
      var index = 0;
      final text = m.group(1)!.replaceAllMapped(RegExp(r'\$[A-Za-z_]+'), (_) => '{p${index++}}');
      final key = byText[text];
      expect(key, isNotNull, reason: text);
      keys.add(key!);
    }
    expect(keys.length, greaterThan(200));
    final placeholder = RegExp(r'\{p\d+\}');
    for (final locale in ['zh', 'zh_Hant', 'zh_Hans', 'en', 'ja', 'ko']) {
      final arb = jsonDecode(File('lib/i18n/app_$locale.arb').readAsStringSync()) as Map<String, dynamic>;
      for (final key in keys) {
        final value = arb[key];
        expect(value, isA<String>(), reason: '$locale $key');
        expect((value as String).trim(), isNotEmpty, reason: '$locale $key');
        expect(
          placeholder.allMatches(value).map((m) => m.group(0)).toSet(),
          placeholder.allMatches(zh[key] as String).map((m) => m.group(0)).toSet(),
          reason: '$locale $key',
        );
      }
    }
  });

  testWidgets('英文語系的參數字串正確代入', (tester) async {
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    expect(en.doorP0('A02'), 'Door A02');
    expect(en.placeTheseBooksDoorP0('A02'), 'Place these books in door A02');
    expect(en.severalTasksLockerWereNotCompleted(8), 'Several tasks at this locker were not completed. Try again in 8 minutes.');
    expect(en.numberConfirmationWasNotCompletedSeveral(8), 'Number confirmation was not completed several times. Try again in 8 minutes.');
  });

  group('定位為使用書櫃的必要條件', () {
    test('拒絕定位提供前往設定與重試，無法確認位置提供重試', () {
      final required = CabinetFlowError.of(_error(CabinetApiError.locationRequired, const {}, '伺服器文字'));
      expect(required.message, S.locationAccessRequiredUseLockerTurn);
      expect(required.actions, [CabinetFlowAction.openSettings, CabinetFlowAction.retry, CabinetFlowAction.close]);
      final unavailable = CabinetFlowError.of(_error(CabinetApiError.locationUnavailable, const {}, '伺服器文字'));
      expect(unavailable.message, S.locationCouldNotConfirmedTurnLocation);
      expect(unavailable.actions, [CabinetFlowAction.retry, CabinetFlowAction.close]);
      final imprecise = CabinetFlowError.of(const CabinetApiError(code: CabinetApiError.locationImprecise));
      expect(imprecise.message, S.preciseLocationRequiredUseLockerTurn);
      expect(imprecise.actions, [CabinetFlowAction.openSettings, CabinetFlowAction.retry, CabinetFlowAction.close]);
    });

    test('未取得當次定位時不建立作業', () async {
      final requests = <http.Request>[];
      for (final (location, code) in [
        (const FreshLocation(status: FreshLocation.denied), CabinetApiError.locationRequired),
        (const FreshLocation(status: FreshLocation.unavailable), CabinetApiError.locationUnavailable),
        (const FreshLocation(status: FreshLocation.imprecise), CabinetApiError.locationImprecise),
        (const FreshLocation(status: FreshLocation.granted), CabinetApiError.locationUnavailable),
      ]) {
        final flow = CabinetFlowController(locate: () async => location, changes: const Stream.empty());
        await http.runWithClient(
          () => flow.submitCode('savemybook://k/3f9c0a5e1d2b4c6a8e0f1a2b3c4d5e6f'),
          () => MockClient((request) async {
            requests.add(request);
            return http.Response('{}', 500);
          }),
        );
        expect(flow.step, CabinetFlowStep.error);
        expect(flow.error!.code, code);
        expect(flow.busy, isFalse);
        flow.dispose();
      }
      expect(requests, isEmpty);
    });
  });

  group('LocationService.fresh', () {
    late GeolocatorPlatform original;

    setUp(() => original = GeolocatorPlatform.instance);
    tearDown(() => GeolocatorPlatform.instance = original);

    test('從未詢問過權限時跳出詢問；拒絕後回報 denied', () async {
      final geo = _FakeGeolocator(permission: LocationPermission.denied, afterRequest: LocationPermission.denied);
      GeolocatorPlatform.instance = geo;
      final location = await LocationService.fresh();
      expect(geo.requests, 1);
      expect(location.status, FreshLocation.denied);
      expect(location.toJson(), {'location_status': 'denied'});
    });

    test('只允許大約位置時先要求精確位置；仍為大約位置時回報 imprecise，不送出座標', () async {
      final now = DateTime.utc(2026, 9, 28, 10, 30, 5);
      final android = _FakeGeolocator(accuracy: LocationAccuracyStatus.reduced, position: _position(now));
      GeolocatorPlatform.instance = android;
      final location = await LocationService.fresh(clock: () => now);
      expect(android.requests, 1, reason: 'Android 以再次要求權限讓使用者改為精確位置');
      expect(android.settings, isNull, reason: '不以大約位置取得座標');
      expect(location.status, FreshLocation.imprecise);
      expect(location.toJson(), {'location_status': 'unavailable'});

      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final denied = _FakeGeolocator(accuracy: LocationAccuracyStatus.reduced, position: _position(now));
        GeolocatorPlatform.instance = denied;
        expect(await LocationService.access(), LocationAccess.imprecise);
        expect(denied.purposeKeys, [LocationService.precisePurposeKey]);
        expect(denied.requests, 0);

        final allowed = _FakeGeolocator(accuracy: LocationAccuracyStatus.reduced, upgraded: LocationAccuracyStatus.precise, position: _position(now));
        GeolocatorPlatform.instance = allowed;
        expect((await LocationService.fresh(clock: () => now)).isGranted, isTrue);
        expect(allowed.purposeKeys, [LocationService.precisePurposeKey]);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    test('iOS 宣告要求精確位置的用途，定位說明包含確認位於書櫃旁', () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      expect(
        RegExp(r'<key>NSLocationTemporaryUsageDescriptionDictionary</key>\s*<dict>\s*<key>' + LocationService.precisePurposeKey + r'</key>\s*<string>[^<]+</string>')
            .hasMatch(plist),
        isTrue,
      );
      final usage = RegExp(r'<key>NSLocationWhenInUseUsageDescription</key>\s*<string>([^<]+)</string>').firstMatch(plist)!.group(1)!;
      expect(usage, contains('確認您位於書櫃旁'));
    });

    test('定位服務關閉時回報 unavailable', () async {
      GeolocatorPlatform.instance = _FakeGeolocator(serviceEnabled: false);
      expect((await LocationService.fresh()).status, FreshLocation.unavailable);
    });

    test('取不到當次定位時回報 unavailable，不退回最後已知位置', () async {
      final geo = _FakeGeolocator();
      GeolocatorPlatform.instance = geo;
      final location = await LocationService.fresh();
      expect(location.status, FreshLocation.unavailable);
      expect(geo.lastKnownCalls, 0);
    });

    test('成功時帶出精度與定位經過的毫秒數，並要求高精度', () async {
      final now = DateTime.utc(2026, 9, 28, 10, 30, 5);
      final geo = _FakeGeolocator(position: _position(now.subtract(const Duration(milliseconds: 1200))));
      GeolocatorPlatform.instance = geo;
      final location = await LocationService.fresh(clock: () => now);
      expect(geo.requests, 0);
      expect(geo.lastKnownCalls, 0);
      expect(geo.settings!.accuracy, LocationAccuracy.high);
      expect(geo.settings!.timeLimit, const Duration(seconds: 5));
      expect(location.isGranted, isTrue);
      expect(location.toJson(), {
        'location_status': 'granted',
        'location': {'lat': 25.0421, 'lng': 121.5254, 'accuracy_m': 18.0, 'age_ms': 1200},
      });
    });
  });
}
