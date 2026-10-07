// 第 12 章第 18 節「後台管理入口導覽」與第 20 節「智慧書櫃據點設定（管理員）」：登入者 es 具管理員權限，手機版後台。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';

import 'package:savemybook_app/features/admin/admin_cabinet_deposit_screen.dart';
import 'package:savemybook_app/features/admin/admin_home_screen.dart';
import 'package:savemybook_app/features/admin/admin_operation_log_screen.dart';
import 'package:savemybook_app/features/home/home_screen.dart';
import 'package:savemybook_app/features/security/identity_verification_sheet.dart';
import 'package:savemybook_app/i18n/strings.dart';
import 'package:savemybook_app/models/user.dart';

import 'manual_api.dart';
import 'manual_host.dart';

const _s18 = '18. 後台管理入口導覽';
const _s18a = '18. 後台管理入口導覽/18-1';
const _s20 = '20. 智慧書櫃據點設定（管理員）';

final _ios = TargetPlatformVariant.only(TargetPlatform.iOS);

Map<String, dynamic> get _meJson => userJson(meId, extra: {'role': 'admin'});
User get _admin => User.fromJson(_meJson);

Map<String, dynamic> _person(int id) => {'user_id': id, 'nickname': realUsers[id]!.nickname};

void _adminBase({int disputes = 0, int tickets = 5}) {
  ManualApi.on('GET', '/auth/me', (_) => _meJson);
  ManualApi.on('GET', '/admin/overview', (_) => {
    'member_count': 8,
    'pending_report_count': 0,
    'pending_listing_review_count': 0,
    'open_risk_alert_count': 0,
    'pending_dispute_count': disputes,
    'active_cabinet_count': 5,
    'today_order_count': 8,
    'open_ticket_count': tickets,
  });
}

const _levels = [
  {'level_id': 1, 'level_name': '新手書友', 'min_points': 0, 'max_points': 99, 'benefits': '基本交易功能'},
  {'level_id': 2, 'level_name': '活躍書友', 'min_points': 100, 'max_points': 499, 'benefits': '享有推薦曝光加成'},
  {'level_id': 3, 'level_name': '資深書友', 'min_points': 500, 'max_points': 1999, 'benefits': '享有交易手續費折扣'},
  {'level_id': 4, 'level_name': '菁英書友', 'min_points': 2000, 'max_points': null, 'benefits': '享有全部VIP權益'},
];

String _title(int bookId) => bookJson(bookId)['title'] as String;

// ───────────── 書櫃 ─────────────

const _xinbei = 7;

Map<String, dynamic> _cabinet(
  int id, {
  required int total,
  Set<int> occupied = const {},
  bool slots = true,
  bool doors = false,
  Map<String, dynamic>? device,
  Map<String, dynamic> extra = const {},
}) {
  final rows = [
    if (slots)
      for (var n = 1; n <= total; n++)
        {
          'slot_id': id * 100 + n,
          'slot_number': 'A${n.toString().padLeft(2, '0')}',
          'status': occupied.contains(n) ? 'occupied' : 'empty',
          'updated_at': ago(days: 1),
          'lock_channel': doors ? n : null,
        },
  ];
  final empty = total - occupied.length;
  return {
    ...cabinetJson(id),
    'total_slots': total,
    'available_slots': empty,
    'is_active': true,
    'is_maintenance': false,
    'slot_summary': {'empty': empty, 'occupied': total - empty},
    'cabinet_slots': rows,
    'device': device,
    ...extra,
  };
}

List<Map<String, dynamic>> _cabinets({bool withNew = false, bool edited = false}) => [
  // 原圖中總統府的櫃位皆已使用且未列出櫃位
  _cabinet(1, total: 5, slots: false, occupied: {1, 2, 3, 4, 5}),
  _cabinet(2, total: 4),
  _cabinet(
    3,
    total: 4,
    occupied: {1, 3},
    doors: true,
    device: {'device_no': 'DV3K8PQ2M', 'kind': 'esp32', 'status': 'active', 'online': false, 'last_seen_at': ago(hours: 2)},
  ),
  _cabinet(4, total: 20, occupied: {1}),
  _cabinet(5, total: 20, occupied: {1}),
  if (withNew)
    _cabinet(
      _xinbei,
      total: 20,
      extra: {
        'open_time': edited ? '10:00:00' : null,
        'close_time': edited ? '00:00:00' : null,
      },
    ),
];

Map<String, dynamic> _nearbyPreview() => {
  'cabinet': {'latitude': 24.9827866, 'longitude': 121.4502229},
  'mrt': {
    'status': 'ok',
    'stations': [
      {'name': '海山', 'distance_m': 310},
    ],
  },
  'bus': {
    'status': 'ok',
    'stops': [
      for (final (name, d) in [('新北高工', 60), ('學府路一段', 140), ('土城國中', 230), ('海山捷運站', 300)])
        {'name': name, 'address': '', 'distance_m': d, 'routes': <Object>[]},
    ],
  },
  'youbike': {'status': 'ok', 'stations': <Object>[]},
  'parking_lots': {'status': 'ok', 'lots': <Object>[]},
  'road_speed': {'status': 'ok', 'sections': <Object>[]},
  'taxi_stands': {'status': 'ok', 'stands': <Object>[]},
  'roadside': {'status': 'ok', 'radius_m': 300, 'car': <Object>[], 'motorcycle': <Object>[]},
};

/// 新北高工現場的定位結果（使用目前位置）。
class _SchoolGeolocator extends GeolocatorPlatform {
  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async => LocationPermission.whileInUse;

  @override
  Future<LocationPermission> requestPermission() async => LocationPermission.whileInUse;

  @override
  Future<LocationAccuracyStatus> getLocationAccuracy() async => LocationAccuracyStatus.precise;

  @override
  Future<Position?> getLastKnownPosition({bool forceLocationManager = false}) async => _position;

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) async => _position;

  static Position get _position => Position(
    latitude: 24.9827866,
    longitude: 121.4502229,
    timestamp: DateTime.now(),
    accuracy: 35,
    altitude: 30,
    altitudeAccuracy: 5,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

// ───────────── 管理操作紀錄 ─────────────

Map<String, dynamic> _log(
  int id,
  String no, {
  required String action,
  required String type,
  required String targetNo,
  required String summary,
  required int admin,
  required String at,
  List<(String, String, String)> changes = const [],
  bool canUndo = false,
  String? revertedAt,
  String ip = '',
}) => {
  'log_id': id,
  'log_no': no,
  'action': action,
  'target_type': type,
  'target_id': id,
  'target_no': targetNo,
  'summary': summary,
  'changes': [
    for (final (label, from, to) in changes) {'label': label, 'from': from, 'to': to},
  ],
  'can_undo': canUndo,
  'reverted': revertedAt == null ? null : {'at': revertedAt, 'by': meId},
  'ip_address': ip.isEmpty ? null : ip,
  'created_at': at,
  'admin': admin == meId ? {'user_id': meId, 'nickname': meName} : _person(admin),
};

String _bookTime(int bookId, {int hours = 3, int minutes = 14}) =>
    DateTime.parse(bookJson(bookId)['created_at'] as String).add(Duration(hours: hours, minutes: minutes)).toIso8601String();

const _cbBeishang = 'CB3PPB252';
const _cbXinbei = 'CB20HGQ5Y';
const _cbCheng = 'CB5M2XQ7H';

List<Map<String, dynamic>> _bookLogs({bool undone = false}) => [
  if (undone)
    _log(
      120,
      'LG1Q7MZ4C',
      action: '還原：強制下架書籍',
      type: 'book',
      targetNo: 'BK202Z6N3',
      summary: '還原 LG10KQARJ「下架《${_title(109)}》」',
      admin: meId,
      at: ago(minutes: 0),
      changes: [('狀態', '已下架', '販售中'), ('下架原因', '書況與照片不符', '—')],
    ),
  _log(
    110,
    'LG10KQARJ',
    action: '強制下架書籍',
    type: 'book',
    targetNo: 'BK202Z6N3',
    summary: '下架《${_title(109)}》',
    admin: 16,
    at: ago(hours: 1, minutes: 13),
    changes: [('狀態', '販售中', '已下架'), ('下架原因', '—', '書況與照片不符')],
    canUndo: !undone,
    revertedAt: undone ? ago(minutes: 0) : null,
  ),
  _log(
    104,
    'LG13TMK6F',
    action: '核准 AI 審核書籍',
    type: 'book',
    targetNo: 'BK13TMK6F',
    summary: '核准《${_title(141)}》的上架審核，並通知賣家',
    admin: 7,
    at: _bookTime(141),
    changes: [('上架審核', '待審核', '已核准')],
  ),
  _log(
    103,
    'LG20S0DWY',
    action: '核准 AI 審核書籍',
    type: 'book',
    targetNo: 'BK20S0DWY',
    summary: '核准《${_title(148)}》的上架審核，並通知賣家',
    admin: 7,
    at: _bookTime(148, hours: 0, minutes: 5),
    changes: [('上架審核', '待審核', '已核准')],
  ),
  _log(
    102,
    'LG3P93WQF',
    action: '核准 AI 審核書籍',
    type: 'book',
    targetNo: 'BK3P93WQF',
    summary: '核准《${_title(137)}》的上架審核，並通知賣家',
    admin: 16,
    at: _bookTime(137, hours: 0, minutes: 7),
    changes: [('上架審核', '待審核', '已核准')],
  ),
  _log(
    101,
    'LG3W246RK',
    action: '核准 AI 審核書籍',
    type: 'book',
    targetNo: 'BK3W246RK',
    summary: '核准《${_title(139)}》的上架審核，並通知賣家',
    admin: 16,
    at: _bookTime(139, hours: 0, minutes: 2),
    changes: [('上架審核', '待審核', '已核准')],
  ),
];

List<Map<String, dynamic>> _cabinetLogs18() => [
  _log(
    208,
    'LG8RD2K5W',
    action: '撤銷書櫃裝置',
    type: 'cabinet',
    targetNo: _cbXinbei,
    summary: '撤銷「新北高工」的裝置 DV2Q85S3A',
    admin: 7,
    at: ago(minutes: 4),
    ip: '163.17.42.118',
  ),
  _log(
    207,
    'LG7MX3Q9T',
    action: '確認書櫃手動回報',
    type: 'cabinet',
    targetNo: _cbBeishang,
    summary: '確認「北商大臺北校區ｉ郵箱」的存書手動回報（訂單 SMB20261006233438118889），存放於櫃門 A02，說明：現場確認書籍已放入櫃門',
    admin: 7,
    at: ago(minutes: 5),
    ip: '163.17.42.118',
  ),
  _log(
    206,
    'LG6K2W8PA',
    action: '駁回書櫃手動回報',
    type: 'cabinet',
    targetNo: _cbBeishang,
    summary: '駁回「北商大臺北校區ｉ郵箱」的存書手動回報（訂單 SMB20261006233438118889），說明：回報之櫃門與現場不符',
    admin: 7,
    at: ago(minutes: 7),
    ip: '163.17.42.118',
  ),
  _log(
    205,
    'LG5H9ZC3E',
    action: '駁回書櫃手動回報',
    type: 'cabinet',
    targetNo: _cbBeishang,
    summary: '駁回「北商大臺北校區ｉ郵箱」的取書手動回報（訂單 SMB20260924234016166089），說明：櫃內仍有該書籍',
    admin: 10,
    at: ago(minutes: 8),
    ip: '163.17.42.27',
  ),
];

List<Map<String, dynamic>> _cabinetLogs20() => [
  _log(
    204,
    'LG4N8VB2S',
    action: '修改書櫃',
    type: 'cabinet',
    targetNo: _cbXinbei,
    summary: '修改書櫃「新北高工」的開始營業、結束營業',
    admin: meId,
    at: ago(minutes: 0),
    changes: [('開始營業', '—', '10:00'), ('結束營業', '—', '00:00')],
    canUndo: true,
  ),
  _log(
    203,
    'LG3C6TQ8L',
    action: '新增書櫃',
    type: 'cabinet',
    targetNo: _cbXinbei,
    summary: '新增書櫃「新北高工」（20 格），地址：236新北市土城區學府里學府路一段241號',
    admin: meId,
    at: ago(minutes: 3),
    canUndo: true,
    ip: '163.17.42.118',
  ),
  _log(
    202,
    'LG2B5RJ7X',
    action: '修改書櫃',
    type: 'cabinet',
    targetNo: _cbCheng,
    summary: '修改書櫃「程曦嘍」的名稱',
    admin: 10,
    at: ago(minutes: 11),
    changes: [('名稱', '青島東路書櫃', '程曦嘍')],
    canUndo: true,
  ),
  _log(
    201,
    'LG1A4PK6Z',
    action: '修改書櫃',
    type: 'cabinet',
    targetNo: _cbCheng,
    summary: '修改書櫃「程曦嘍」的啟用',
    admin: 10,
    at: ago(minutes: 11, hours: 0),
    changes: [('啟用', '否', '是')],
    canUndo: true,
  ),
  _log(
    200,
    'LG0Z3MH5D',
    action: '修改書櫃',
    type: 'cabinet',
    targetNo: 'CB2K7WD4N',
    summary: '修改書櫃「國立臺北商業大學」的開始營業、結束營業',
    admin: 7,
    at: ago(days: 2, hours: 3),
    changes: [('開始營業', '08:00', '00:00'), ('結束營業', '22:00', '23:59')],
    canUndo: true,
  ),
];

// ───────────── 存書列表 ─────────────

Map<String, dynamic> _deposit(
  int bookId, {
  required int cabinetId,
  required int days,
  required String at,
  String? door,
  bool paused = false,
  String status = 'on_sale',
}) {
  final b = bookJson(bookId);
  return {
    'book_id': bookId,
    'title': b['title'],
    'book_status': status,
    'image_url': coverOf(bookId),
    'seller': _person(b['seller_id'] as int),
    'cabinet': {'cabinet_id': cabinetId, 'cabinet_name': cabinetJson(cabinetId)['cabinet_name']},
    'deposited_at': at,
    'days_stored': days,
    'paused': paused,
    'escalated': false,
    'overdue': false,
    'door': door == null ? null : {'slot_id': cabinetId * 100 + int.parse(door.substring(1)), 'label': door},
  };
}

/// 原圖的待處理分頁為空，類型篩選列來自已處理的檢舉案件。
List<Map<String, dynamic>> _handledReports() => [
  {
    'report_id': 12,
    'target_type': 'message',
    'target_id': 3184,
    'reason': '要求於平台外匯款',
    'status': 'resolved',
    'admin_note': '已提醒對方依平台流程交易',
    'created_at': ago(days: 2, hours: 5),
    'resolved_at': ago(days: 2, hours: 1),
    'users_reports_reporter_idTousers': _person(16),
    'target': {
      'message_id': 3184,
      'sender_id': 11,
      'content': '可以直接匯款到我的帳戶嗎？這樣比較快',
      'message_type': 'text',
      'kind': 'text',
      'body': '可以直接匯款到我的帳戶嗎？這樣比較快',
      'created_at': ago(days: 2, hours: 6),
      'users': _person(11),
      'sender_no': 'MB4T8KQ2W',
    },
  },
  {
    'report_id': 11,
    'target_type': 'book',
    'target_id': 109,
    'reason': '書況與照片不符',
    'status': 'dismissed',
    'admin_note': '照片與書況相符',
    'created_at': ago(days: 4, hours: 3),
    'resolved_at': ago(days: 4),
    'users_reports_reporter_idTousers': _person(10),
    'target': {'title': _title(109), 'book_images': bookJson(109)['book_images']},
  },
];

/// 包含 [text] 的頁面捲動區（輸入框本身也有 Scrollable，須由標籤往上找）。
Finder _scrollOf(String text) => find.ancestor(of: find.text(text).first, matching: find.byType(Scrollable)).first;

// ListView.builder 的總長是估計值，捲到底後才知道實際長度，須重複到不再變動。
Future<void> _scrollToEnd(WidgetTester tester, Finder scrollable) async {
  final position = tester.state<ScrollableState>(scrollable).position;
  for (var i = 0; i < 6 && position.pixels < position.maxScrollExtent; i++) {
    position.jumpTo(position.maxScrollExtent);
    await tester.pump();
  }
  await settleReal(tester, const Duration(milliseconds: 800));
}

void main() {
  setUpAll(() async {
    await setUpManual();
    GeolocatorPlatform.instance = _SchoolGeolocator();
  });

  // ───────────── 18-1 ─────────────

  testWidgets('18-1 會員中心', variant: _ios, (tester) async {
    await shoot(
      tester,
      folder: _s18a,
      me: _admin,
      routes: () {
        _adminBase();
        ManualApi.on('GET', '/users/me/stats', (_) => {
          'balance': 9600,
          'book_count': 0,
          'favorite_count': 1,
          'unread_notification_count': 3,
          'cart_count': 0,
        });
        ManualApi.on('GET', '/notifications/unread-count', (_) => {
          'unread_count': 3,
          'by_category': {'trade': 2, 'chat': 0, 'account': 1, 'service': 0, 'promotion': 0},
        });
        ManualApi.on('GET', '/users/me/level', (_) => {
          'points': 0,
          'completed_orders': 0,
          'current_level': _levels[0],
          'next_level': _levels[1],
          'points_to_next': 100,
          'levels': _levels,
        });
      },
      home: HomeScreen.new,
      act: (tester, snap) async {
        await tapAndSettle(tester, find.text(S.member).last, duration: const Duration(seconds: 2));
        await snap('表12-18-1 會員中心');
      },
    );
  });

  testWidgets('18-1 管理後台', variant: _ios, (tester) async {
    await shoot(
      tester,
      folder: _s18a,
      me: _admin,
      routes: _adminBase,
      home: AdminHomeScreen.new,
      act: (tester, snap) async {
        await snap('表12-18-1 管理後台');
      },
    );
  });

  // ───────────── 18-2 ─────────────

  testWidgets('18-2 後台功能', variant: _ios, (tester) async {
    await shoot(
      tester,
      folder: _s18,
      me: _admin,
      routes: () {
        _adminBase(disputes: 1);
        ManualApi.on('GET', '/admin/reports', (_) => _handledReports());
      },
      home: AdminHomeScreen.new,
      act: (tester, snap) async {
        await scrollBy(tester, 128);
        await snap('表12-18-2 交易與商品管理');
        final list = tester.state<ScrollableState>(find.byType(Scrollable).first);
        await scrollBy(tester, list.position.maxScrollExtent - list.position.pixels);
        await snap('表12-18-2 硬體與營運、系統維運');
        await scrollBy(tester, -list.position.pixels + 128);
        await tapAndSettle(tester, find.text(S.moderation), duration: const Duration(seconds: 2));
        await snap('表12-18-2 內容審核');
      },
    );
  });

  // ───────────── 18-3、18-4 ─────────────

  testWidgets('18-3 管理操作紀錄與還原', variant: _ios, (tester) async {
    var undone = false;
    await shoot(
      tester,
      folder: _s18,
      me: _admin,
      routes: () {
        _adminBase(disputes: 1);
        ManualApi.on('GET', '/admin/operation-logs', (r) {
          final books = _bookLogs(undone: undone);
          return switch (r.query['target_type']) {
            'book' => books,
            null => [..._cabinetLogs18(), ...books],
            _ => <Object>[],
          };
        });
        ManualApi.on('POST', '/admin/operation-logs/:id/undo', (_) {
          undone = true;
          return {'log_id': 120};
        });
      },
      home: AdminOperationLogScreen.new,
      act: (tester, snap) async {
        await snap('表12-18-3 管理操作紀錄');

        await tapAndSettle(tester, find.text(S.books).first, duration: const Duration(seconds: 2));
        await snap('表12-18-3 依類別篩選');

        await tapAndSettle(tester, find.text(S.undoAction2).first);
        await snap('表12-18-3 還原此操作');

        await tapAndSettle(tester, find.text(S.actionCancel).last);
        final context = tester.element(find.byType(AdminOperationLogScreen));
        unawaited(showIdentityVerificationSheet(
          context,
          scope: 'admin',
          reason: S.enterSignPasswordRunAdminAction,
          hasPassword: true,
        ));
        await settleReal(tester, const Duration(seconds: 1));
        final field = find.descendant(of: find.byType(IdentityVerificationSheet), matching: find.byType(TextField));
        await tester.enterText(field, 'Savemybook2026');
        await settleReal(tester, const Duration(milliseconds: 500));
        await snap('表12-18-4 驗證身分');

        Navigator.of(tester.element(find.byType(IdentityVerificationSheet))).pop();
        await settleReal(tester, const Duration(seconds: 1));
        await tapAndSettle(tester, find.text(S.undoAction2).first);
        await tapAndSettle(tester, find.text(S.undo).last);
        await snap('表12-18-4 已還原');
      },
    );
  });

  // ───────────── 18-5、18-6 ─────────────

  testWidgets('18-5 存書列表與登記取出', variant: _ios, (tester) async {
    final cleared = <int>{};
    await shoot(
      tester,
      folder: _s18,
      me: _admin,
      routes: () {
        _adminBase(disputes: 1);
        ManualApi.on('GET', '/admin/cabinets', (_) => _cabinets(withNew: true));
        ManualApi.on('GET', '/admin/cabinets/deposits', (r) {
          if (r.query['overdue'] == 'true') return <Object>[];
          return [
            _deposit(128, cabinetId: 3, door: 'A01', days: 7, paused: true, at: todayAt(10, 4, daysAgo: 7)),
            _deposit(111, cabinetId: 5, door: 'A01', days: 5, at: todayAt(16, 43, daysAgo: 5)),
            _deposit(139, cabinetId: 4, days: 5, status: 'removed', at: todayAt(17, 18, daysAgo: 5)),
            _deposit(103, cabinetId: 3, door: 'A03', days: 0, status: 'removed', at: ago(minutes: 14)),
            _deposit(110, cabinetId: 3, door: 'A02', days: 0, status: 'removed', at: ago(minutes: 6)),
          ].where((d) => !cleared.contains(d['book_id'])).toList();
        });
        ManualApi.on('POST', '/admin/cabinets/deposits/:id/clear', (r) {
          cleared.add(int.parse(r.path.split('/')[4]));
          return <String, Object>{};
        });
      },
      home: AdminCabinetDepositScreen.new,
      act: (tester, snap) async {
        await snap('表12-18-5 存書列表');

        await tapAndSettle(tester, find.text(S.overdue), duration: const Duration(seconds: 2));
        await snap('表12-18-5 逾期篩選');

        await tapAndSettle(tester, find.text(S.actionAll), duration: const Duration(seconds: 2));
        await tapAndSettle(tester, find.text(S.recordRemoval).first);
        await snap('表12-18-6 登記取出');

        await tapAndSettle(tester, find.text(S.recordRemoval).last);
        await snap('表12-18-6 已登記取出');
      },
    );
  });

  // ───────────── 20-1 ～ 20-3 ─────────────

  testWidgets('20-1 新增與修改書櫃', variant: _ios, (tester) async {
    var created = false;
    var edited = false;
    await shoot(
      tester,
      folder: _s20,
      me: _admin,
      routes: () {
        _adminBase();
        ManualApi.on('GET', '/admin/cabinets', (_) => _cabinets(withNew: created, edited: edited));
        ManualApi.on('GET', '/admin/cabinets/nearby-preview', (_) => _nearbyPreview());
        ManualApi.on('POST', '/admin/cabinets', (_) {
          created = true;
          return {'cabinet_id': _xinbei};
        });
        ManualApi.on('PUT', '/admin/cabinets/:id', (_) {
          edited = true;
          return {'cabinet_id': _xinbei};
        });
      },
      home: AdminHomeScreen.new,
      act: (tester, snap) async {
        await scrollBy(tester, 413);
        await snap('表12-20-1 管理後台');

        await tapAndSettle(tester, find.text(S.lockerMonitor), duration: const Duration(seconds: 2));
        await snap('表12-20-1 書櫃監控');

        await tapAndSettle(tester, find.byIcon(Icons.add_rounded), duration: const Duration(seconds: 2));
        await snap('表12-20-1 新增書櫃');

        TextField fieldAt(int i) => tester.widget<TextField>(find.byType(TextField).at(i));
        fieldAt(0).controller!.text = '新北高工';
        fieldAt(1).controller!.text = '236新北市土城區學府里學府路一段241號';
        await settleReal(tester, const Duration(milliseconds: 300));
        await tapAndSettle(tester, find.text(S.useCurrentLocation), duration: const Duration(seconds: 2));
        // 等「已填入目前位置」提示消失
        await settleReal(tester, const Duration(seconds: 3));
        await snap('表12-20-2 使用目前位置');

        await _scrollToEnd(tester, _scrollOf(S.latitude));
        await snap('表12-20-2 附近交通預覽');

        await tapAndSettle(tester, find.text(S.createLocker), duration: const Duration(seconds: 2));
        await settleReal(tester, const Duration(seconds: 3));
        await _scrollToEnd(tester, _scrollOf('中華民國總統府'));
        await snap('表12-20-2 書櫃建立完成');

        await tapAndSettle(tester, find.byIcon(Icons.edit_outlined).last, duration: const Duration(seconds: 2));
        await _scrollToEnd(tester, _scrollOf(S.latitude));
        await snap('表12-20-3 修改書櫃');

        final fields = find.byType(TextField);
        final count = tester.widgetList(fields).length;
        tester.widget<TextField>(fields.at(count - 2)).controller!.text = '10:00';
        tester.widget<TextField>(fields.at(count - 1)).controller!.text = '00:00';
        await settleReal(tester, const Duration(milliseconds: 300));
        await tapAndSettle(tester, find.text(S.saveChanges));
        await snap('表12-20-3 書櫃已更新');
      },
    );
  });

  // ───────────── 20-4 ─────────────

  testWidgets('20-4 操作紀錄', variant: _ios, (tester) async {
    await shoot(
      tester,
      folder: _s20,
      me: _admin,
      routes: () {
        _adminBase();
        ManualApi.on('GET', '/admin/operation-logs', (r) => switch (r.query['target_type']) {
          null || 'cabinet' => _cabinetLogs20(),
          _ => <Object>[],
        });
      },
      home: AdminHomeScreen.new,
      act: (tester, snap) async {
        final list = tester.state<ScrollableState>(find.byType(Scrollable).first);
        await scrollBy(tester, list.position.maxScrollExtent);
        await snap('表12-20-4 管理後台');

        await tapAndSettle(tester, find.text(S.adminAuditLog), duration: const Duration(seconds: 2));
        await snap('表12-20-4 管理操作紀錄');
      },
    );
  });
}
