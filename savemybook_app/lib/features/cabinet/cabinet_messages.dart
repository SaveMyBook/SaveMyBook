import '../../i18n/strings.dart';
import '../../models/cabinet.dart';
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
    CabinetAction.pickup => '掃描書櫃取書',
    CabinetAction.orderDeposit || CabinetAction.preDeposit => '掃描書櫃存書',
    CabinetAction.retrieve => '掃描書櫃取回',
  };
}

class CabinetMessages {
  const CabinetMessages._();

  static final _quotedName = RegExp(r'「([^」]+)」');

  static String closedHours(String hours) => '目前非書櫃營業時間，營業時間為 $hours';

  static String doorUnavailable(String? reason) => reason == 'maintenance' ? '此書櫃維修中，暫停服務' : '此書櫃暫停服務';

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
    return noDoor ? '書櫃目前沒有可用的櫃門' : null;
  }

  static String manualNotice(CabinetAccess? access) => switch (access?.reason) {
    'offline' => '書櫃目前連線中斷，無法以掃碼開啟櫃門。請依客服指示放入或取出書籍後再回報，回報經客服確認後生效。',
    'fault' => '書櫃目前故障，無法以掃碼開啟櫃門。請依客服指示放入或取出書籍後再回報，回報經客服確認後生效。',
    _ => '手動回報經客服確認後生效。',
  };

  static String error(CabinetApiError error) {
    switch (error.code) {
      case CabinetApiError.network:
        return S.networkError;
      case CabinetApiError.signedOut:
        return S.pleaseSignFirst;
      case 'CABINET_CODE_INVALID':
        return '此 QR Code 並非 SaveMyBook 書櫃 QR Code';
      case 'CABINET_CODE_EXPIRED':
        return '書櫃 QR Code 已更新，請重新掃描書櫃螢幕上的 QR Code';
      case 'CABINET_BUSY':
        return '書櫃使用中，請稍候再掃描';
      case 'CABINET_OFFLINE':
        return '書櫃目前連線中斷，暫時無法使用';
      case 'CABINET_MAINTENANCE':
        return doorUnavailable('maintenance');
      case 'CABINET_UNAVAILABLE':
        return doorUnavailable(null);
      case 'CABINET_CLOSED':
        final hours = formatTimeRange(error.openTime, error.closeTime);
        if (hours.isNotEmpty) return closedHours(hours);
      case 'CABINET_TOO_FAR':
        final meters = error.distanceM;
        if (meters != null) return tooFar(LocationService.formatDistance(meters));
      case 'CABINET_WRONG_CABINET':
        final name = error.cabinet?.cabinetName;
        if (name != null && name.isNotEmpty) return wrongCabinet(name);
      case 'CABINET_CONTEXT_CHANGED':
        return '項目狀態已變更，請重新整理後再試';
      case 'CABINET_NOTHING_TO_DO':
        return '您在此書櫃沒有待辦理的項目';
      case 'CABINET_ITEM_BLOCKED':
        for (final item in error.items) {
          final blocked = item.blocked;
          if (blocked != null) return CabinetMessages.blocked(blocked);
        }
      case 'CABINET_ACTIVE_SESSION':
        return '您有進行中的書櫃作業，請先完成或取消';
      case 'CABINET_NO_SELECTION':
        return '請至少選擇一個項目';
      case 'CABINET_FULL':
        return '此書櫃可用的櫃門不足，請減少存書項目或稍後再試';
      case 'PREDEPOSIT_LIMIT':
        return blocked(const CabinetNotice(code: 'PREDEPOSIT_LIMIT'));
      case 'CABINET_ITEMS_CHANGED':
        return '部分項目狀態已變更，請重新確認';
      case 'CABINET_SESSION_NOT_FOUND':
        return '找不到此書櫃作業';
      case 'CABINET_SESSION_STATE':
        final status = error.session?.status;
        return status == CabinetSession.opening || status == CabinetSession.open ? '櫃門已開啟，請於書櫃螢幕操作' : '目前無法執行此操作';
      case 'CABINET_SCAN_REQUIRED':
        return '此書櫃已啟用掃碼存取，請至書櫃掃描 QR Code 辦理';
      case 'CABINET_COOLDOWN':
        final seconds = error.retryAfterS ?? 60;
        return cooldown(seconds <= 60 ? 1 : (seconds / 60).ceil());
      case 'ORDER_IN_CABINET_SESSION':
        return '此訂單正於書櫃辦理中，請稍後再試';
      case 'MANUAL_REPORT_PENDING':
        return '此項目已有待客服確認的手動回報';
    }
    return error.message.isNotEmpty ? error.message : S.somethingWentWrongPleaseTryAgain;
  }

  static String tooFar(String distance) => '您目前的位置距離書櫃約 $distance，請於書櫃旁操作';

  static String wrongCabinet(String name) => '此項目的指定書櫃為「$name」，請至該書櫃辦理';

  static String cooldown(int minutes) => '您在此書櫃的作業多次未完成，請於 $minutes 分鐘後再試';

  static String? otherCabinets(CabinetApiError error) {
    final names = [for (final c in error.otherCabinets) if (c.cabinetName.isNotEmpty) c.cabinetName];
    if (names.isEmpty) return null;
    return otherCabinetsAt(names.join('、'));
  }

  static String otherCabinetsAt(String names) => '您的待辦項目位於：$names';

  static String result(CabinetSessionResult? result) {
    if (result == null) return '';
    return switch (result.code) {
      'COMPLETED' => '作業完成',
      'PARTIAL' || 'ITEMS_FAILED' => '部分項目未完成',
      'MATCH_FAILED' => '數字不符，本次作業已取消',
      'MATCH_TIMEOUT' => '未於時限內完成數字確認，本次作業已取消',
      'SELECT_TIMEOUT' => '未於時限內確認項目，本次作業已取消',
      'DEVICE_NO_RESPONSE' => '書櫃未回應，櫃門未開啟，請稍後再試',
      'CANCELLED_BY_USER' => '本次作業已取消',
      'CANCELLED_AT_CABINET' => '已於書櫃取消，狀態未變更',
      'DEVICE_NO_ACK' => '未收到書櫃的開門回報，本次作業待客服確認',
      'DEVICE_LOST' => '書櫃連線異常，本次作業待客服確認',
      'DEVICE_INTERRUPTED' => '書櫃重新啟動，本次作業待客服確認',
      'ADMIN_RESOLVED_COMMIT' => result.outcome == CabinetSession.partial ? '部分項目未完成' : '客服已確認本次作業完成',
      'ADMIN_RESOLVED_DISCARD' => '客服已確認本次作業未完成，狀態未變更',
      'ADMIN_CANCELLED' => '客服已結束本次作業',
      _ => result.message,
    };
  }

  static String completedTitle(CabinetSession session) {
    final kinds = {for (final item in session.selectedItems) item.kind};
    if (kinds.length == 1) {
      switch (kinds.first) {
        case CabinetItemKind.orderDeposit:
          return '存書完成，已通知買家取書';
        case CabinetItemKind.preDeposit:
          return '存書完成';
        case CabinetItemKind.retrieval:
          return '取回完成';
        default:
          break;
      }
    }
    return '作業完成';
  }

  static String blocked(CabinetNotice notice) => switch (notice.code) {
    'DOOR_UNKNOWN' || 'DOOR_SHARED' => '無法確認櫃門，請聯絡客服',
    'DOOR_FAULT' => '櫃門故障，請聯絡客服',
    'DOOR_CHECK' => '櫃門待客服確認，請聯絡客服',
    'CABINET_FULL' => '書櫃目前沒有可用的櫃門',
    'PREDEPOSIT_LIMIT' => '您在此書櫃的先行存書已達上限，請待售出或取回後再存入',
    _ => notice.message,
  };

  static String itemError(CabinetNotice notice) => switch (notice.code) {
    'ITEM_CHANGED' => '項目狀態已變更',
    'DOOR_FAILED' => '櫃門未能開啟',
    'DOOR_UNCONFIRMED' => '未收到櫃門開啟回報，待客服確認',
    'DOOR_CONFLICT' => '櫃門內有其他項目，待客服確認',
    _ => notice.message,
  };

  static String itemNotDone(String reason) => '未完成：$reason';

  static String note(CabinetNotice notice) {
    if (notice.code != 'MOVE_TO_ORDER_CABINET') return notice.message;
    final name = _quotedName.firstMatch(notice.message)?.group(1);
    return name == null ? notice.message : moveTo(name);
  }

  static String moveTo(String name) => '此書籍已售出，取回後請存入「$name」';

  static String door(String label) => '櫃門 $label';
}
