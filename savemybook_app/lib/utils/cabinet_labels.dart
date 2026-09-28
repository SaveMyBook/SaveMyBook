import '../i18n/strings.dart';
import '../models/admin/cabinet_device.dart';
import '../services/location_service.dart';

class CabinetLabels {
  const CabinetLabels._();

  static Map<String, String> get sessionStatus => {
    'selecting': '確認項目中',
    'matching': '數字確認中',
    'opening': '開門中',
    'open': '櫃門開啟中',
    'completed': S.orderCompleted,
    'partial': '部分完成',
    'cancelled': S.orderCancelled,
    'failed': '失敗',
    'expired': S.timedOut,
    'needs_review': '待確認',
  };

  static String status(String code) => sessionStatus[code] ?? code;

  static Map<String, String> get sessionKind => {
    'pickup': S.collect,
    'order_deposit': '依訂單存書',
    'pre_deposit': '先行存書',
    'retrieval': '取回',
    'admin': '管理員開櫃',
  };

  static String kind(String code) => sessionKind[code] ?? code;

  static Map<String, String> get closeReasons => {
    'button': '書櫃按鈕',
    'timeout': '倒數結束',
    'sensor': '門磁感測',
    'cancel_button': '於書櫃取消',
    'reboot': '裝置重新啟動',
    'admin': '客服處理',
    'admin_discard': '客服處理',
  };

  static String closeReason(String? code) => code == null ? '' : closeReasons[code] ?? code;

  static Map<String, String> get events => {
    'boot': '裝置啟動',
    'match_selected': '點選數字',
    'door_opened': '櫃門已開啟',
    'door_closed': '櫃門已關閉',
    'session_closed': '作業結束回報',
    'session_cancel': '於書櫃取消',
    'fault': '故障',
    'fault_cleared': '故障排除',
    'door_forced': '櫃門異常開啟',
    'connection_lost': '連線中斷',
    'connection_restored': '恢復連線',
    'paired': '完成配對',
    'revoked': '已撤銷裝置',
    'session_created': '建立作業',
    'session_finished': '作業結束',
    'scan_rejected': '掃碼遭拒',
    'admin_open': '遠端開櫃',
    'door_placed': '已登記存放內容',
    'door_cleared': '已清空存放紀錄',
    'review_resolved': '客服處理',
    'device_cloned': '憑證疑遭複製',
    'ip_changed': '來源 IP 變更',
    'door_check_required': '櫃門待確認',
    'door_check_cleared': '櫃門確認完成',
    'item_blocked': '項目無法辦理',
    'manual_report': '手動回報',
    'manual_report_reviewed': '手動回報處理',
    'overdue_review': '逾期訂單待處理',
    'late_door_opened': '作業結束後開門',
  };

  static String event(String type) => events[type] ?? type;

  static Map<String, String> get faults => {
    'LOCK_NO_RELEASE': '電磁鎖未釋放',
    'DOOR_LEFT_OPEN': '櫃門未關閉',
    'DOOR_FORCED': '櫃門遭強制開啟',
    'SENSOR_ERROR': '感測器異常',
    'POWER': '電源異常',
    'SCREEN': '螢幕異常',
  };

  static String fault(String code) => faults[code] ?? code;

  static Map<String, String> get checkReasons => {
    'CANCELLED_AFTER_OPEN': '存書作業開門後取消',
    'DISCARDED_AFTER_OPEN': '客服確認未完成的存書作業',
    'DOOR_CONFLICT': '存書時門內已有其他項目',
    'DOOR_UNCONFIRMED': '未收到開門回報',
    'LATE_OPEN': '作業結束後回報開門',
    'MANUAL_REPORT': '故障期間的手動回報',
    'ADMIN_OPEN': '管理人員開啟過此櫃門',
    'ADMIN_COMPLETED': '客服將未取書的訂單改為完成',
  };

  static String checkReason(String code) => checkReasons[code] ?? code;

  static Map<String, String> get accessReasons => {
    'no_device': '未配對裝置',
    'offline': '裝置離線',
    'fault': '裝置故障',
    'maintenance': '書櫃維修中',
    'inactive': '書櫃已停用',
  };

  static String accessReason(String? code) => code == null ? '' : accessReasons[code] ?? code;

  static String access(String mode, String? reason) => switch (mode) {
    'scan' => '使用者須掃碼存取',
    'unavailable' => accessUnavailable(accessReason(reason)),
    _ => accessManual(accessReason(reason)),
  };

  static String accessManual(String reason) => '開放手動回報（$reason）';

  static String accessUnavailable(String reason) => '暫停使用者存取（$reason）';

  static String deviceKind(String kind) => kind == AdminCabinetDeviceInfo.kindSimulator ? '模擬書櫃' : '實體書櫃';

  static String deviceState({String? status, bool online = false}) {
    if (status == null) return '尚未配對裝置';
    if (status == 'pending') return '等待配對';
    return online ? '連線中' : '離線';
  }

  static String location(String? status, int? distanceM) {
    if (status == 'granted' && distanceM != null) return distance(LocationService.formatDistance(distanceM));
    if (status == 'denied') return '未授權定位';
    if (status == null) return '';
    return '無法取得定位';
  }

  static String distance(String value) => '距離約 $value';

  static String doorItem(AdminCabinetDoorItem item) => switch (item.kind) {
    AdminCabinetDoorItem.kindOrder => S.order(item.orderNo ?? ''),
    AdminCabinetDoorItem.kindDeposit => '先行存書',
    _ => '待取回',
  };

  static Map<String, String> get manualReportKinds => {
    'deposit': '存書',
    'pickup': S.collect,
    'retrieve': '取回',
  };

  static String manualReportKind(String code) => manualReportKinds[code] ?? code;

  static Map<String, String> get manualReportStatuses => {
    'pending': '待確認',
    'confirmed': '已確認',
    'rejected': '已駁回',
    'cancelled': '已失效',
  };

  static String manualReportStatus(String code) => manualReportStatuses[code] ?? code;
}
