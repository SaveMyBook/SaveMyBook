import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_scanner/mobile_scanner.dart' show MobileScanner;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:savemybook_app/features/books/book_detail_screen.dart';
import 'package:savemybook_app/features/cabinet/cabinet_entry.dart';
import 'package:savemybook_app/features/cabinet/cabinet_flow_controller.dart';
import 'package:savemybook_app/features/cabinet/cabinet_flow_screen.dart';
import 'package:savemybook_app/features/cabinet/cabinet_resume.dart';
import 'package:savemybook_app/features/cabinet/cabinet_scanner_view.dart';
import 'package:savemybook_app/features/orders/order_detail_screen.dart';
import 'package:savemybook_app/features/orders/pickup_book_screen.dart';
import 'package:savemybook_app/features/orders/pickup_success_screen.dart';
import 'package:savemybook_app/features/orders/purchase_history_screen.dart';
import 'package:savemybook_app/features/selling/book_deposit_actions.dart' show delistMessage;
import 'package:savemybook_app/features/selling/book_manage_screen.dart';
import 'package:savemybook_app/features/selling/sales_history_screen.dart';
import 'package:savemybook_app/i18n/app_localizations.dart';
import 'package:savemybook_app/i18n/strings.dart';
import 'package:savemybook_app/models/book.dart';
import 'package:savemybook_app/models/cabinet.dart';
import 'package:savemybook_app/models/order.dart';
import 'package:savemybook_app/models/user.dart';
import 'package:savemybook_app/services/api_service.dart';
import 'package:savemybook_app/services/deep_link_service.dart';
import 'package:savemybook_app/services/locale_provider.dart';
import 'package:savemybook_app/services/location_service.dart';
import 'package:savemybook_app/services/realtime_service.dart';
import 'package:savemybook_app/utils/api_helpers.dart';
import 'package:savemybook_app/utils/app_theme.dart';
import 'package:savemybook_app/widgets/animations.dart';
import 'package:savemybook_app/widgets/app_buttons.dart';
import 'package:savemybook_app/widgets/app_forms.dart';
import 'package:savemybook_app/widgets/app_header.dart';
import 'package:savemybook_app/widgets/app_select.dart';

const _token = '3f9c0a5e1d2b4c6a8e0f1a2b3c4d5e6f';
const _code = 'savemybook://k/$_token';
const _sessionNo = 'CS8MZQ41K';
const _zhHant = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');

Map<String, dynamic> _sessionBook(int id, String title, {String? door = 'A02'}) =>
    {'book_id': id, 'title': title, 'image_url': null, 'door': door};

Map<String, dynamic> _item(
  String kind, {
  String? key,
  int? orderId,
  List<Map<String, dynamic>>? books,
  List<String> doors = const ['A02'],
  bool selected = true,
  Map<String, dynamic>? blocked,
  Map<String, dynamic>? note,
  bool paused = false,
  String result = 'pending',
  Map<String, dynamic>? error,
}) {
  final byOrder = kind == 'pickup' || kind == 'order_deposit';
  final id = orderId ?? (byOrder ? 128 : 55);
  return {
    'key': key ?? (byOrder ? 'order:$id' : 'book:$id'),
    'kind': kind,
    'order_id': byOrder ? id : null,
    'order_no': byOrder ? 'SMB20260928143015123456' : null,
    'books': books ?? [_sessionBook(55, '資料庫系統概論', door: doors.isEmpty ? null : doors.first)],
    'doors': doors,
    'paused': paused,
    'note': note,
    'selected': selected,
    'blocked': blocked,
    'result': result,
    'error': error,
  };
}

Map<String, dynamic> _session({
  String status = 'selecting',
  int version = 1,
  List<Map<String, dynamic>>? items,
  List<Map<String, dynamic>> doors = const [],
  int? remainingMs = 52000,
  int? openMs,
  Map<String, dynamic>? result,
  String? notice,
  String locationStatus = 'granted',
}) => {
  'session_no': _sessionNo,
  'status': status,
  'version': version,
  'cabinet': {
    'cabinet_id': 3,
    'cabinet_name': '北商大書櫃',
    'address': '臺北市中正區濟南路一段 321 號',
    'latitude': 25.0421,
    'longitude': 121.5254,
    'open_time': '08:00',
    'close_time': '22:00',
    'available_doors': 2,
  },
  'location_status': locationStatus,
  'distance_m': 35,
  'items': items ?? [_item('pickup')],
  'doors': doors,
  'remaining_ms': remainingMs,
  'open_ms': openMs,
  'notice': notice,
  'result': result,
  'created_at': '2026-09-28T10:30:00.000Z',
  'finished_at': null,
};

Map<String, dynamic> _result(String outcome, String code) => {'outcome': outcome, 'code': code, 'message': '伺服器訊息'};

Map<String, dynamic> _access(String mode, {String? reason, bool openNow = true, int? doors = 2, int? preDeposit = 1}) => {
  'mode': mode,
  'reason': reason,
  'open_now': openNow,
  'open_time': '08:00',
  'close_time': '22:00',
  'available_doors': doors,
  'pre_deposit_doors': preDeposit,
};

Map<String, dynamic> _manualReport(String kind) => {
  'report_no': 'MR4K2Q8ZT',
  'kind': kind,
  'status': 'pending',
  'target_status': kind == 'deposit' ? null : 'picked_up',
  'reason': 'no_device',
  'created_at': '2026-09-28T10:30:00.000Z',
  'reviewed_at': null,
  'review_note': null,
};

const _cabinetJson = {'cabinet_id': 3, 'cabinet_name': '台大書櫃', 'address': '臺北市大安區羅斯福路四段1號'};

Map<String, dynamic> _order({
  int id = 128,
  String status = 'deposited',
  Map<String, dynamic>? access,
  List<String> doors = const ['A02'],
  Map<String, dynamic>? report,
}) => {
  'order_id': id,
  'order_no': 'SMB20260928143015123456',
  'buyer_id': 1,
  'seller_id': 2,
  'total_amount': 180,
  'status': status,
  'cabinet_id': 3,
  'created_at': '2026-09-28T10:00:00.000Z',
  'picked_up_at': null,
  'order_items': [
    {'item_id': 1, 'book_id': 55, 'quantity': 1, 'unit_price': 180, 'subtotal': 180, 'books': _book(55, '資料庫系統概論', sellerId: 2)},
  ],
  'smart_cabinets': _cabinetJson,
  'users_orders_buyer_idTousers': {'user_id': 1, 'nickname': '買家'},
  'users_orders_seller_idTousers': {'user_id': 2, 'nickname': '賣家'},
  'transaction_disputes': <Object>[],
  'doors': doors,
  'cabinet_access': access,
  'manual_report': report,
};

Map<String, dynamic> _book(
  int id,
  String title, {
  int sellerId = 1,
  String status = 'on_sale',
  Map<String, dynamic>? access,
  Map<String, dynamic>? deposit,
  Map<String, dynamic>? location,
  Map<String, dynamic>? report,
}) => {
  'book_id': id,
  'seller_id': sellerId,
  'title': title,
  'price': 180,
  'status': status,
  'is_approved': true,
  'cabinet_id': 3,
  'smart_cabinets': _cabinetJson,
  'book_images': <Object>[],
  'users': {'user_id': sellerId, 'nickname': '賣家'},
  'in_cabinet': deposit != null,
  'deposit': deposit,
  'cabinet_access': access,
  'location': location,
  'manual_report': report,
};

http.Response _ok(Object? data, [int status = 200, Map<String, Object?> extra = const {}]) => http.Response(
  jsonEncode({'success': true, 'data': data, ...extra}),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

http.Response _fail(String code, int status, [Map<String, dynamic> extra = const {}, String message = '伺服器訊息']) => http.Response(
  jsonEncode({'success': false, 'code': code, 'message': message, ...extra}),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

class _Api {
  final List<String> calls = [];
  final Map<String, Object?> bodies = {};
  Map<String, dynamic>? current;
  Map<String, dynamic>? active;
  FutureOr<http.Response> Function(http.Request request)? onCreate;
  FutureOr<http.Response> Function(http.Request request)? onStart;
  FutureOr<http.Response> Function(http.Request request)? onCancel;
  FutureOr<http.Response> Function(http.Request request)? onMatch;
  FutureOr<http.Response> Function(http.Request request)? onClose;
  FutureOr<http.Response?> Function(http.Request request)? other;

  List<String> get writes => [for (final c in calls) if (!c.startsWith('GET ')) c];

  MockClient get client => MockClient((request) async {
    final path = request.url.path;
    final key = '${request.method} $path';
    calls.add(key);
    if (request.body.isNotEmpty) bodies[key] = jsonDecode(request.body);
    if (key == 'POST /api/cabinet-sessions') return onCreate!(request);
    if (key == 'GET /api/cabinet-sessions/active') return _ok(active);
    if (path.endsWith('/start')) return onStart!(request);
    if (path.endsWith('/cancel')) return onCancel!(request);
    if (path.endsWith('/match')) return onMatch!(request);
    if (path.endsWith('/close')) return onClose!(request);
    if (path.startsWith('/api/cabinet-sessions/')) {
      return current == null ? _fail('CABINET_SESSION_NOT_FOUND', 404) : _ok(current);
    }
    final handled = await other?.call(request);
    return handled ?? _ok(<Object>[]);
  });
}

class _Geolocator extends GeolocatorPlatform {
  LocationPermission permission = LocationPermission.whileInUse;
  LocationAccuracyStatus accuracy = LocationAccuracyStatus.precise;
  bool serviceEnabled = true;
  int appSettings = 0;
  int locationSettings = 0;
  int requests = 0;
  int checks = 0;

  @override
  Future<LocationPermission> checkPermission() async {
    checks++;
    return permission;
  }

  @override
  Future<LocationPermission> requestPermission() async {
    requests++;
    return permission;
  }

  @override
  Future<LocationAccuracyStatus> getLocationAccuracy() async => accuracy;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) async => Position(
    latitude: 25.0421,
    longitude: 121.5254,
    timestamp: DateTime.now(),
    accuracy: 12,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );

  @override
  Future<bool> openAppSettings() async {
    appSettings++;
    return true;
  }

  @override
  Future<bool> openLocationSettings() async {
    locationSettings++;
    return true;
  }
}

const _located = {'location_status': 'granted', 'location': {'lat': 25.0421, 'lng': 121.5254, 'accuracy_m': 12.0}};

Map<String, dynamic> _withoutAge(Object? body) {
  final map = Map<String, dynamic>.from(body! as Map);
  final location = map['location'];
  if (location is Map) {
    expect(location['age_ms'], isA<int>());
    map['location'] = Map<String, dynamic>.from(location)..remove('age_ms');
  }
  return map;
}

class _Launcher extends StatelessWidget {
  final String? code;
  final ValueChanged<CabinetFlowOutcome> onDone;

  const _Launcher({required this.onDone, this.code});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () async => onDone(await openCabinetFlow(context, code: code)),
        child: const Text('open'),
      ),
    ),
  );
}

Widget _host(Widget home, {Locale locale = _zhHant, GlobalKey<NavigatorState>? navigatorKey}) => MaterialApp(
  navigatorKey: navigatorKey,
  locale: locale,
  supportedLocales: const [...LocaleProvider.supported, Locale('zh')],
  theme: AppTheme.build(Brightness.light),
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  builder: (context, child) {
    S = AppLocalizations.of(context);
    return child ?? const SizedBox.shrink();
  },
  home: home,
);

Future<void> _settle(WidgetTester tester, [int frames = 10]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  Size size = const Size(390, 844),
  Locale locale = _zhHant,
  GlobalKey<NavigatorState>? navigatorKey,
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_host(home, locale: locale, navigatorKey: navigatorKey));
  await _settle(tester);
}

Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 5));
}

void _push(Map<String, dynamic> session) => RealtimeService.instance.handleCabinetSession({'session': session});

List<String> _buttonLabels(WidgetTester tester) => [
  ...tester.widgetList<PrimaryButton>(find.byType(PrimaryButton)).map((b) => b.label),
  ...tester.widgetList<SecondaryButton>(find.byType(SecondaryButton)).map((b) => b.label),
];

PrimaryButton _primary(WidgetTester tester, String label) =>
    tester.widgetList<PrimaryButton>(find.byType(PrimaryButton)).singleWhere((b) => b.label == label);

SecondaryButton _secondary(WidgetTester tester, String label) =>
    tester.widgetList<SecondaryButton>(find.byType(SecondaryButton)).singleWhere((b) => b.label == label);

void _signIn({int id = 1}) {
  ApiService.authToken = 'token';
  ApiService.currentUser = User.fromJson({'user_id': id, 'nickname': '我', 'email': 'me@example.com', 'role': 'buyer_seller'});
}

void main() {
  late StreamController<String> scans;
  late GeolocatorPlatform geolocator;
  late _Geolocator location;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiService.resetGlobalState();
    _signIn();
    geolocator = GeolocatorPlatform.instance;
    location = _Geolocator();
    GeolocatorPlatform.instance = location;
    scans = StreamController<String>.broadcast();
    CabinetScannerView.debugScanInput = scans.stream;
  });

  tearDown(() {
    CabinetScannerView.debugScanInput = null;
    GeolocatorPlatform.instance = geolocator;
    CabinetResume.navigatorKey = null;
    DeepLinkService.onCabinetLink = null;
    DeepLinkService.reset();
    ApiService.authToken = null;
    ApiService.currentUser = null;
    unawaited(scans.close());
  });

  group('流程畫面', () {
    testWidgets('取書：掃碼、確認項目、輸入比對碼、開門後按完成，最後顯示取書成功', (tester) async {
      final api = _Api()
        ..onCreate = ((_) => _ok(_session(), 201))
        ..onStart = ((_) => _ok(_session(status: 'matching', version: 2, doors: [{'label': 'A02', 'state': 'pending'}])))
        ..onMatch = ((_) => _ok(_session(status: 'opening', version: 3, doors: [{'label': 'A02', 'state': 'pending'}])))
        ..onClose = ((_) => _ok(_session(status: 'open', version: 5, remainingMs: 21000, openMs: 30000, doors: [{'label': 'A02', 'state': 'open'}])))
        ..other = ((request) => request.url.path == '/api/orders/128' ? _ok(_order()) : null);
      CabinetFlowOutcome? outcome;

      await http.runWithClient(() async {
        await _pump(tester, _Launcher(onDone: (value) => outcome = value));
        await tester.tap(find.text('open'));
        await _settle(tester);
        expect(find.text(S.scanLockerQrCode), findsOneWidget);
        expect(find.text(S.pointQrCodeLockerScreen), findsOneWidget);

        scans.add(_code);
        await _settle(tester);
        expect(_withoutAge(api.bodies['POST /api/cabinet-sessions']), {'code': _code, ..._located});
        expect(find.text(S.confirmLockerTask), findsOneWidget);
        expect(find.text('北商大書櫃'), findsOneWidget);
        expect(find.text(S.collect), findsOneWidget);
        expect(find.text('資料庫系統概論'), findsOneWidget);
        expect(find.text(S.order('SMB20260928143015123456')), findsOneWidget);
        expect(find.text(S.doorP0('A02')), findsOneWidget);
        expect(find.textContaining(RegExp(r'0:5\d')), findsOneWidget);

        await tester.tap(find.text(S.openDoor));
        await _settle(tester);
        expect(api.bodies['POST /api/cabinet-sessions/$_sessionNo/start'], {'keys': ['order:128']});
        expect(find.text(S.enterNumberShownLockerScreen), findsOneWidget);
        expect(find.text(S.ifSomeoneTellsNumberAsksEnter), findsOneWidget);
        expect(find.text(S.doorP0('A02')), findsOneWidget);
        expect(_buttonLabels(tester), [S.confirm, S.cancelTask]);
        expect(_primary(tester, S.confirm).onPressed, isNull);

        await tester.enterText(find.byType(TextField), '3');
        await tester.pump();
        expect(_primary(tester, S.confirm).onPressed, isNull, reason: '未滿兩位數字不能確認');
        await tester.enterText(find.byType(TextField), '3a7');
        await tester.pump();
        expect(find.text('3'), findsOneWidget);
        expect(find.text('7'), findsOneWidget);
        expect(_primary(tester, S.confirm).onPressed, isNotNull);
        expect(api.writes.where((c) => c.endsWith('/match')), isEmpty, reason: '須按確認才送出');

        api.current = _session(status: 'matching', version: 2, doors: [{'label': 'A02', 'state': 'pending'}]);
        await tester.tap(find.text(S.confirm));
        await _settle(tester, 20);
        expect(api.bodies['POST /api/cabinet-sessions/$_sessionNo/match'], {'code': '37'});
        expect(api.calls.where((c) => c == 'GET /api/cabinet-sessions/$_sessionNo'), isNotEmpty);
        expect(find.text(S.openingDoor), findsOneWidget, reason: '輪詢取得較舊的版本不會讓畫面倒退');

        _push(_session(status: 'matching', version: 2));
        await tester.pump(Duration.zero);
        expect(find.text(S.openingDoor), findsOneWidget, reason: '較舊的版本不會讓畫面倒退');

        _push(_session(status: 'open', version: 4, remainingMs: 24300, openMs: 30000, doors: [{'label': 'A02', 'state': 'open'}]));
        await tester.pump(Duration.zero);
        expect(find.text(S.doorOpened), findsOneWidget);
        await _settle(tester);
        expect(find.text(S.takeBooksFromDoorP0('A02')), findsOneWidget);
        expect(find.text(S.cancelTapCancelBeforeClosingDoor), findsOneWidget);
        expect(_buttonLabels(tester), [S.finish, S.actionCancel]);

        await tester.tap(find.text(S.finish));
        await _settle(tester, 3);
        expect(api.bodies['POST /api/cabinet-sessions/$_sessionNo/close'], {'outcome': 'completed'});
        expect(_primary(tester, S.finish).isLoading, isTrue, reason: '等待書櫃結束作業');
        expect(_secondary(tester, S.actionCancel).onPressed, isNull);

        _push(
          _session(
            status: 'completed',
            version: 6,
            items: [_item('pickup', result: 'done')],
            remainingMs: null,
            result: _result('completed', 'COMPLETED'),
          ),
        );
        await tester.pump(Duration.zero);
        expect(find.byType(DrawnCheck), findsNothing, reason: '取書成功頁開啟前不顯示一般的完成畫面');
        expect(find.text(S.taskComplete), findsNothing);
        await _settle(tester, 20);
        expect(find.byType(PickupSuccessScreen), findsOneWidget);
        expect(api.calls, contains('GET /api/orders/128'));
        expect(outcome, CabinetFlowOutcome.completed);
        await _finish(tester);
      }, () => api.client);
    });

    testWidgets('每個錯誤代碼顯示對應的文字與動作', (tester) async {
      final api = _Api();
      await http.runWithClient(() async {
        await _pump(tester, const SizedBox.shrink());
        final closed = S.lockerClosedNowOpeningHoursP0(formatTimeRange('08:00', '22:00'));
        final cases = <(String, int, Map<String, dynamic>, bool, String, String?, List<String>)>[
          ('CABINET_CODE_EXPIRED', 410, {}, false, S.lockerQrCodeChangedScanCode, null, [S.rescan, S.actionClose]),
          ('CABINET_BUSY', 409, {}, false, S.lockerUsePleaseWaitScanAgain, null, [S.rescan, S.actionClose]),
          ('CABINET_OFFLINE', 409, {'manual_allowed': true}, true, S.lockerOfflineTemporarilyUnavailable, null, [S.rescan, S.reportManually, S.actionClose]),
          ('CABINET_OFFLINE', 409, {'manual_allowed': true}, false, S.lockerOfflineTemporarilyUnavailable, null, [S.rescan, S.actionClose]),
          ('CABINET_OFFLINE', 409, {'manual_allowed': false}, true, S.lockerOfflineTemporarilyUnavailable, null, [S.rescan, S.actionClose]),
          ('CABINET_MAINTENANCE', 409, {}, false, S.lockerUnderMaintenance, null, [S.actionClose]),
          ('CABINET_UNAVAILABLE', 409, {}, false, S.lockerOutService, null, [S.actionClose]),
          ('CABINET_CLOSED', 409, {'open_time': '08:00', 'close_time': '22:00'}, false, closed, null, [S.actionClose]),
          ('CABINET_TOO_FAR', 403, {'distance_m': 850}, false, S.aboutP0FromLockerPleaseUse(LocationService.formatDistance(850)), null, [S.rescan, S.actionClose]),
          (
            'CABINET_WRONG_CABINET',
            409,
            {'cabinet': {'cabinet_id': 4, 'cabinet_name': '師大書櫃', 'address': '臺北市大安區和平東路一段 162 號', 'latitude': 25.026, 'longitude': 121.527}},
            true,
            S.itemAssignedP0PleaseUseLocker('師大書櫃'),
            '臺北市大安區和平東路一段 162 號',
            [S.openMap, S.rescan, S.actionClose],
          ),
          (
            'CABINET_NOTHING_TO_DO',
            404,
            {'other_cabinets': [{'cabinet_id': 4, 'cabinet_name': '師大書櫃', 'address': '', 'kinds': ['pickup']}, {'cabinet_id': 5, 'cabinet_name': '政大書櫃', 'address': '', 'kinds': ['pickup']}]},
            false,
            S.noItemsHandleLocker,
            S.itemsP0('師大書櫃、政大書櫃'),
            [S.viewPurchases, S.rescan, S.actionClose],
          ),
          (
            'CABINET_NOTHING_TO_DO',
            404,
            {'other_cabinets': [{'cabinet_id': 4, 'cabinet_name': '師大書櫃', 'address': '', 'kinds': ['pre_deposit', 'retrieval']}]},
            false,
            S.noItemsHandleLocker,
            S.itemsP0('師大書櫃'),
            [S.viewSales, S.rescan, S.actionClose],
          ),
          ('CABINET_NOTHING_TO_DO', 404, {'other_cabinets': <Object>[]}, false, S.noItemsHandleLocker, null, [S.rescan, S.actionClose]),
          (
            'CABINET_ITEM_BLOCKED',
            409,
            {'items': [_item('pickup', blocked: {'code': 'DOOR_FAULT', 'message': '此項目的櫃門故障，請聯絡客服'})]},
            false,
            S.doorFaultyPleaseContactSupport,
            null,
            [S.contactSupport, S.actionClose],
          ),
          (
            'CABINET_ITEM_BLOCKED',
            409,
            {'items': [_item('pre_deposit', key: 'book:60', blocked: {'code': 'PREDEPOSIT_LIMIT', 'message': ''})]},
            false,
            S.reachedPreSaleDropOffLimit,
            null,
            [S.rescan, S.actionClose],
          ),
          ('CABINET_ACTIVE_SESSION', 409, {'session_no': _sessionNo}, false, S.lockerTaskProgressFinishCancelFirst, null, [S.continueTask, S.actionClose]),
          ('CABINET_CONTEXT_CHANGED', 409, {}, true, S.itemChangedRefreshTryAgain, null, [S.actionClose]),
          ('CABINET_COOLDOWN', 429, {'retry_after_s': 540}, false, S.severalTasksLockerWereNotCompleted(9), null, [S.actionClose]),
          ('CABINET_LOCATION_REQUIRED', 403, {}, false, S.locationAccessRequiredUseLockerTurn, null, [S.openSettings, S.retry, S.actionClose]),
          ('CABINET_LOCATION_UNAVAILABLE', 403, {}, false, S.locationCouldNotConfirmedTurnLocation, null, [S.retry, S.actionClose]),
          ('SOMETHING_NEW', 409, {}, false, '伺服器訊息', null, [S.actionClose]),
        ];

        for (final (code, status, extra, withContext, text, detail, buttons) in cases) {
          api.onCreate = (_) => _fail(code, status, extra);
          await tester.pumpWidget(const SizedBox.shrink());
          await _pump(tester, CabinetFlowScreen(code: _code, cabinetContext: withContext ? const CabinetContext.order(128) : null));
          expect(find.text(text), findsOneWidget, reason: code);
          if (detail != null) expect(find.text(detail), findsOneWidget, reason: code);
          expect(_buttonLabels(tester), buttons, reason: '$code $extra');
        }

        api.calls.clear();
        await tester.pumpWidget(const SizedBox.shrink());
        await _pump(tester, const CabinetFlowScreen(code: 'https://example.com/pay?id=1'));
        expect(find.text(S.notSavemybookLockerQrCode), findsOneWidget);
        expect(_buttonLabels(tester), [S.rescan, S.actionClose]);
        expect(api.calls, isEmpty, reason: '不是書櫃 QR Code 時不送出請求');

        api.onCreate = (_) => throw http.ClientException('offline');
        await tester.pumpWidget(const SizedBox.shrink());
        await _pump(tester, const CabinetFlowScreen(code: _code));
        expect(find.text(S.networkError), findsOneWidget);
        expect(_buttonLabels(tester), [S.retry, S.actionClose]);
        expect(api.calls, contains('GET /api/cabinet-sessions/active'));
        await _finish(tester);
      }, () => api.client);
    });

    testWidgets('定位：開啟相機前先確認權限，拒絕或只允許大約位置時提供前往設定，無法取得位置時提供重試，確認後才掃描', (tester) async {
      final api = _Api()..onCreate = ((_) => _ok(_session(), 201));
      await http.runWithClient(() async {
        location.permission = LocationPermission.deniedForever;
        await _pump(tester, const CabinetFlowScreen());
        expect(location.checks, greaterThan(0));
        expect(find.byType(CabinetScannerView), findsNothing, reason: '未取得定位權限前不開啟相機');
        expect(find.text(S.locationAccessRequiredUseLockerTurn), findsOneWidget);
        expect(_buttonLabels(tester), [S.openSettings, S.retry, S.actionClose]);
        await tester.tap(find.text(S.openSettings));
        await _settle(tester, 2);
        expect(location.appSettings, 1);

        location
          ..permission = LocationPermission.whileInUse
          ..accuracy = LocationAccuracyStatus.reduced;
        final requests = location.requests;
        await tester.tap(find.text(S.retry));
        await _settle(tester);
        expect(location.requests, requests + 1, reason: '只允許大約位置時先要求精確位置');
        expect(find.byType(CabinetScannerView), findsNothing);
        expect(find.text(S.preciseLocationRequiredUseLockerTurn), findsOneWidget);
        expect(_buttonLabels(tester), [S.openSettings, S.retry, S.actionClose]);
        await tester.tap(find.text(S.openSettings));
        await _settle(tester, 2);
        expect(location.appSettings, 2);

        location
          ..accuracy = LocationAccuracyStatus.precise
          ..serviceEnabled = false;
        await tester.tap(find.text(S.retry));
        await _settle(tester);
        expect(find.byType(CabinetScannerView), findsNothing);
        expect(find.text(S.locationCouldNotConfirmedTurnLocation), findsOneWidget);
        expect(_buttonLabels(tester), [S.retry, S.actionClose]);

        location.serviceEnabled = true;
        await tester.tap(find.text(S.retry));
        await _settle(tester);
        expect(find.byType(CabinetScannerView), findsOneWidget);
        expect(api.calls, isEmpty, reason: '掃描前不送出任何請求');

        scans.add(_code);
        await _settle(tester);
        expect(_withoutAge(api.bodies['POST /api/cabinet-sessions']), {'code': _code, ..._located});
        expect(find.text(S.openDoor), findsOneWidget);
        await _finish(tester);
      }, () => api.client);
    });

    testWidgets('定位：掃描後才被拒絕時，重試改為重新確認權限並掃描，不重送已掃描的 QR Code', (tester) async {
      final api = _Api()..onCreate = ((_) => _ok(_session(), 201));
      await http.runWithClient(() async {
        location.permission = LocationPermission.denied;
        await _pump(tester, const CabinetFlowScreen(code: _code));
        expect(find.text(S.locationAccessRequiredUseLockerTurn), findsOneWidget);
        expect(api.calls, isEmpty);

        location.permission = LocationPermission.whileInUse;
        await tester.tap(find.text(S.retry));
        await _settle(tester);
        expect(find.byType(CabinetScannerView), findsOneWidget);
        expect(api.calls, isEmpty, reason: '不重送可能已逾時的 QR Code');
        await _finish(tester);
      }, () => api.client);
    });

    testWidgets('網路錯誤：掃描後 15 秒內重試重送同一個 QR Code，超過後改為重新掃描', (tester) async {
      var now = DateTime(2026, 9, 28, 10, 30);
      final api = _Api()..onCreate = ((_) => throw http.ClientException('offline'));
      await http.runWithClient(() async {
        await _pump(tester, CabinetFlowScreen(code: _code, controller: CabinetFlowController(clock: () => now)));
        expect(find.text(S.networkError), findsOneWidget);
        expect(api.writes, ['POST /api/cabinet-sessions']);

        now = now.add(const Duration(seconds: 10));
        await tester.tap(find.text(S.retry));
        await _settle(tester);
        expect(api.writes, ['POST /api/cabinet-sessions', 'POST /api/cabinet-sessions']);
        expect(find.text(S.networkError), findsOneWidget);

        now = now.add(CabinetFlowController.codeReuseWindow + const Duration(seconds: 1));
        await tester.tap(find.text(S.retry));
        await _settle(tester);
        expect(api.writes.length, 2, reason: 'QR Code 可能已逾時，不再重送');
        expect(find.byType(CabinetScannerView), findsOneWidget);
        await _finish(tester);
      }, () => api.client);
    });

    testWidgets('建立作業時網路錯誤或 QR Code 已更新，先接續進行中的作業', (tester) async {
      final api = _Api()..onCreate = ((_) => throw http.ClientException('offline'));
      await http.runWithClient(() async {
        api.active = _session(status: 'matching', version: 2);
        await _pump(tester, const CabinetFlowScreen(code: _code));
        expect(find.text(S.enterNumberShownLockerScreen), findsOneWidget);
        expect(find.text(S.networkError), findsNothing);

        api
          ..onCreate = ((_) => _fail('CABINET_CODE_EXPIRED', 410))
          ..active = _session();
        await tester.pumpWidget(const SizedBox.shrink());
        await _pump(tester, const CabinetFlowScreen(code: _code));
        expect(find.text(S.openDoor), findsOneWidget);
        expect(find.text(S.lockerQrCodeChangedScanCode), findsNothing);

        api.active = _session(status: 'needs_review', version: 6, remainingMs: null, result: _result('needs_review', 'DEVICE_LOST'));
        await tester.pumpWidget(const SizedBox.shrink());
        await _pump(tester, const CabinetFlowScreen(code: _code));
        expect(find.text(S.lockerQrCodeChangedScanCode), findsOneWidget, reason: '待確認的作業不接續');
        await _finish(tester);
      }, () => api.client);
    });

    testWidgets('已有進行中作業時可繼續作業', (tester) async {
      final api = _Api()..onCreate = ((_) => _fail('CABINET_ACTIVE_SESSION', 409, {'session_no': _sessionNo}));
      await http.runWithClient(() async {
        api.current = _session(status: 'matching', version: 3);
        await _pump(tester, const CabinetFlowScreen(code: _code));
        await tester.tap(find.text(S.continueTask));
        await _settle(tester);
        expect(api.calls, contains('GET /api/cabinet-sessions/$_sessionNo'));
        expect(find.text(S.enterNumberShownLockerScreen), findsOneWidget);
        await _finish(tester);
      }, () => api.client);
    });

    testWidgets('確認項目：分組顯示、不可辦理的項目不能勾選，取回以整扇櫃門勾選', (tester) async {
      final session = _session(
        items: [
          _item('pickup', blocked: {'code': 'DOOR_CHECK', 'message': ''}),
          _item('order_deposit', orderId: 129, doors: const [], books: [_sessionBook(56, '作業系統', door: null), _sessionBook(57, '計算機網路', door: null)]),
          _item('pre_deposit', key: 'book:60', books: [_sessionBook(60, '演算法', door: null)], doors: const [], selected: false),
          _item('retrieval', key: 'book:61', books: [_sessionBook(61, '編譯器設計', door: 'A03')], doors: const ['A03'], selected: false, paused: true),
          _item(
            'retrieval',
            key: 'book:62',
            books: [_sessionBook(62, '離散數學', door: 'A03')],
            doors: const ['A03'],
            selected: false,
            note: {'code': 'MOVE_TO_ORDER_CABINET', 'message': '此書籍已售出，取回後請存入訂單指定的書櫃「師大書櫃」'},
          ),
        ],
      );
      final api = _Api()
        ..onStart = ((_) => _ok(_session(status: 'matching', version: 2)));
      await http.runWithClient(() async {
        await _pump(tester, CabinetFlowScreen(resume: CabinetSession.fromJson(session)), size: const Size(390, 1600));
        expect(find.text(S.collect), findsOneWidget);
        expect(find.text(S.orderDropOff), findsOneWidget);
        expect(find.text(S.preSaleDropOff), findsOneWidget);
        expect(find.text(S.retrieveBooks), findsOneWidget);
        expect(find.text(S.doorAwaitingCheckBySupportPlease), findsOneWidget);
        expect(find.text(S.booksSameDoorRetrievedTogether), findsOneWidget);
        expect(find.text(S.salesPaused), findsOneWidget);
        expect(find.text(S.bookBeenSoldAfterRetrievingDrop('師大書櫃')), findsOneWidget);
        expect(find.text('作業系統'), findsOneWidget);
        expect(find.text('計算機網路'), findsOneWidget);

        final checkboxes = tester.widgetList<Checkbox>(find.byType(Checkbox)).toList();
        expect(checkboxes.map((c) => c.value), [false, true, false, false, false]);
        expect(checkboxes.first.onChanged, isNull);

        await tester.tap(find.text('編譯器設計'));
        await _settle(tester, 3);
        expect(tester.widgetList<Checkbox>(find.byType(Checkbox)).map((c) => c.value), [false, true, false, true, true]);

        await tester.tap(find.text(S.openDoor));
        await _settle(tester);
        expect(api.bodies['POST /api/cabinet-sessions/$_sessionNo/start'], {'keys': ['order:129', 'book:61', 'book:62']});
        await _finish(tester);
      }, () => api.client);
    });

    testWidgets('開始時櫃門不足或項目已變更，留在確認步驟並顯示說明', (tester) async {
      final session = _session(items: [_item('pre_deposit', key: 'book:60', doors: const [], books: [_sessionBook(60, '演算法', door: null)])]);
      final api = _Api()..onStart = ((_) => _fail('CABINET_FULL', 409, {'available_doors': 1, 'required_doors': 2}));
      await http.runWithClient(() async {
        await _pump(tester, CabinetFlowScreen(resume: CabinetSession.fromJson(session)));
        await tester.tap(find.text(S.openDoor));
        await _settle(tester);
        expect(find.text(S.notEnoughDoorsAvailableSelectFewer), findsOneWidget);
        expect(find.text(S.openDoor), findsOneWidget);

        final changed = _session(
          version: 2,
          items: [
            _item('pre_deposit', key: 'book:60', doors: const [], books: [_sessionBook(60, '演算法', door: null)], blocked: {'code': 'PREDEPOSIT_LIMIT', 'message': ''}),
          ],
        );
        api.onStart = (_) => _fail('CABINET_ITEMS_CHANGED', 409, {'session': changed});
        await tester.tap(find.text(S.openDoor));
        await _settle(tester);
        expect(find.text(S.someItemsChangedPleaseConfirmAgain), findsOneWidget);
        expect(find.text(S.reachedPreSaleDropOffLimit), findsOneWidget);
        expect(_primary(tester, S.openDoor).onPressed, isNull, reason: '已不可辦理的項目自動取消勾選');
        await _finish(tester);
      }, () => api.client);
    });

    testWidgets('確認與比對步驟可取消作業，取消後關閉畫面', (tester) async {
      final api = _Api()
        ..onCreate = ((_) => _ok(_session(), 201))
        ..onCancel = ((_) => _ok(_session(status: 'cancelled', version: 2, remainingMs: null, result: _result('cancelled', 'CANCELLED_BY_USER'))));
      CabinetFlowOutcome? outcome;
      await http.runWithClient(() async {
        await _pump(tester, _Launcher(code: _code, onDone: (value) => outcome = value));
        await tester.tap(find.text('open'));
        await _settle(tester);
        await tester.tap(find.text(S.cancelTask));
        await _settle(tester);
        expect(api.writes, ['POST /api/cabinet-sessions', 'POST /api/cabinet-sessions/$_sessionNo/cancel']);
        expect(find.byType(CabinetFlowScreen), findsNothing);
        expect(outcome, CabinetFlowOutcome.cancelled);
        await _finish(tester);
      }, () => api.client);
    });

    testWidgets('比對步驟可取消作業；取消或開始時作業已進入下一步，改顯示該步驟', (tester) async {
      final api = _Api()
        ..onCreate = ((_) => _ok(_session(), 201))
        ..onStart = ((_) => _ok(_session(status: 'matching', version: 2)))
        ..onCancel = ((_) => _ok(_session(status: 'cancelled', version: 3, remainingMs: null, result: _result('cancelled', 'CANCELLED_BY_USER'))));
      CabinetFlowOutcome? outcome;
      await http.runWithClient(() async {
        await _pump(tester, _Launcher(code: _code, onDone: (value) => outcome = value));
        await tester.tap(find.text('open'));
        await _settle(tester);
        await tester.tap(find.text(S.openDoor));
        await _settle(tester);
        expect(find.text(S.enterNumberShownLockerScreen), findsOneWidget);
        await tester.tap(find.text(S.cancelTask));
        await _settle(tester);
        expect(api.writes, [
          'POST /api/cabinet-sessions',
          'POST /api/cabinet-sessions/$_sessionNo/start',
          'POST /api/cabinet-sessions/$_sessionNo/cancel',
        ]);
        expect(find.byType(CabinetFlowScreen), findsNothing);
        expect(outcome, CabinetFlowOutcome.cancelled);

        api.onCancel = (_) => _fail('CABINET_SESSION_STATE', 409, {
          'session': _session(status: 'opening', version: 3, doors: [{'label': 'A02', 'state': 'pending'}]),
        });
        await tester.tap(find.text('open'));
        await _settle(tester);
        await tester.tap(find.text(S.openDoor));
        await _settle(tester);
        await tester.tap(find.text(S.cancelTask));
        await _settle(tester);
        expect(find.byType(CabinetFlowScreen), findsOneWidget);
        expect(find.text(S.openingDoor), findsOneWidget);
        expect(find.text(S.cancelTask), findsNothing);
        _push(_session(status: 'opening', version: 4, remainingMs: 0, doors: [{'label': 'A02', 'state': 'pending'}]));
        await tester.pump(Duration.zero);
        await tester.tap(find.byIcon(Icons.arrow_back_rounded));
        await _settle(tester);
        expect(outcome, CabinetFlowOutcome.started);

        api.onStart = (_) => _fail('CABINET_SESSION_STATE', 409, {'session': _session(status: 'matching', version: 2)});
        await tester.tap(find.text('open'));
        await _settle(tester);
        await tester.tap(find.text(S.openDoor));
        await _settle(tester);
        expect(find.text(S.enterNumberShownLockerScreen), findsOneWidget);
        expect(_buttonLabels(tester), [S.confirm, S.cancelTask]);
        await _finish(tester);
      }, () => api.client);
    });

    testWidgets('確認書櫃期間離開畫面，作業建立後隨即取消', (tester) async {
      final created = Completer<http.Response>();
      final api = _Api()
        ..onCreate = ((_) => created.future)
        ..onCancel = ((_) => _ok(_session(status: 'cancelled', version: 2, remainingMs: null, result: _result('cancelled', 'CANCELLED_BY_USER'))));
      await http.runWithClient(() async {
        await _pump(tester, _Launcher(code: _code, onDone: (_) {}));
        await tester.tap(find.text('open'));
        await _settle(tester);
        expect(find.text(S.checkingLocker), findsOneWidget);
        await tester.tap(find.byIcon(Icons.arrow_back_rounded));
        await _settle(tester);
        expect(find.byType(CabinetFlowScreen), findsNothing);
        expect(api.writes, ['POST /api/cabinet-sessions']);

        created.complete(_ok(_session(), 201));
        await _settle(tester);
        expect(api.writes, ['POST /api/cabinet-sessions', 'POST /api/cabinet-sessions/$_sessionNo/cancel']);
        await _finish(tester);
      }, () => api.client);
    });

    testWidgets('推播未送達時，以輪詢取得作業的下一個狀態', (tester) async {
      final api = _Api()..current = _session(status: 'matching', version: 2);
      await http.runWithClient(() async {
        await _pump(
          tester,
          CabinetFlowScreen(
            resume: CabinetSession.fromJson(api.current!),
            controller: CabinetFlowController(changes: const Stream.empty()),
          ),
        );
        expect(find.text(S.enterNumberShownLockerScreen), findsOneWidget);

        api.current = _session(status: 'opening', version: 3, doors: [{'label': 'A02', 'state': 'pending'}]);
        await tester.pump(const Duration(milliseconds: 2100));
        await tester.pump();
        expect(find.text(S.openingDoor), findsOneWidget);

        api.current = _session(status: 'open', version: 4, remainingMs: 20000, openMs: 30000, doors: [{'label': 'A02', 'state': 'open'}]);
        await tester.pump(const Duration(milliseconds: 1100));
        await tester.pump();
        expect(find.text(S.doorOpened), findsOneWidget);
        await _finish(tester);
      }, () => api.client);
    });

    testWidgets('比對：格式不符時保留畫面重新輸入，送出期間停用按鈕，數字不符時顯示結果', (tester) async {
      final matched = Completer<http.Response>();
      final matching = _session(status: 'matching', version: 2, doors: [{'label': 'A02', 'state': 'pending'}]);
      final api = _Api()
        ..current = matching
        ..onMatch = ((_) => _fail('MATCH_CODE_INVALID', 400, {}, '請輸入兩位數字'));
      await http.runWithClient(() async {
        await _pump(tester, CabinetFlowScreen(resume: CabinetSession.fromJson(matching)));
        await tester.enterText(find.byType(TextField), '37');
        await tester.pump();
        await tester.tap(find.text(S.confirm));
        await _settle(tester);
        expect(api.bodies['POST /api/cabinet-sessions/$_sessionNo/match'], {'code': '37'});
        expect(find.text(S.enterNumberShownLockerScreen), findsOneWidget);
        expect(find.text(S.enterTwoDigits), findsOneWidget);
        expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
        expect(_primary(tester, S.confirm).onPressed, isNull);

        api.onMatch = (_) => matched.future;
        await tester.enterText(find.byType(TextField), '52');
        await tester.pump();
        await tester.tap(find.text(S.confirm));
        await _settle(tester, 2);
        expect(find.text(S.enterTwoDigits), findsNothing);
        expect(_primary(tester, S.confirm).isLoading, isTrue);
        expect(_secondary(tester, S.cancelTask).onPressed, isNull);
        expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);

        matched.complete(_ok(_session(status: 'failed', version: 3, remainingMs: null, result: _result('failed', 'MATCH_FAILED'))));
        await _settle(tester);
        expect(find.text(S.numberDidNotMatchTaskBeen), findsOneWidget);
        expect(_buttonLabels(tester), [S.rescan, S.finish]);
        expect(find.byType(TextField), findsNothing);
        expect(api.writes.where((c) => c.endsWith('/match')).length, 2);
        await _finish(tester);
      }, () => api.client);
    });

    testWidgets('比對：倒數結束後不能送出，逾時或已比對時改顯示作業狀態', (tester) async {
      final matching = _session(status: 'matching', version: 2);
      final expired = _session(status: 'expired', version: 4, remainingMs: null, result: _result('expired', 'MATCH_TIMEOUT'));
      final api = _Api()
        ..current = matching
        ..onMatch = ((_) => _fail('CABINET_SESSION_STATE', 409, {'session': expired}, '目前無法執行此操作'));
      await http.runWithClient(() async {
        await _pump(tester, CabinetFlowScreen(resume: CabinetSession.fromJson(matching)));
        await tester.enterText(find.byType(TextField), '37');
        await tester.pump();
        await tester.tap(find.text(S.confirm));
        await _settle(tester);
        expect(find.text(S.numberWasNotConfirmedTimeTask), findsOneWidget);
        expect(find.text(S.actionNotAvailableRightNow), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
        api.current = matching;
        await _pump(tester, CabinetFlowScreen(resume: CabinetSession.fromJson(matching)));
        await tester.enterText(find.byType(TextField), '37');
        await tester.pump();
        expect(_primary(tester, S.confirm).onPressed, isNotNull);
        final ended = _session(status: 'matching', version: 3, remainingMs: 0);
        api.current = ended;
        _push(ended);
        await tester.pump(Duration.zero);
        expect(find.text(S.p0SRemaining(0)), findsOneWidget);
        expect(_primary(tester, S.confirm).onPressed, isNull, reason: '倒數結束後不能送出');
        expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);

        api.current = expired;
        await _settle(tester, 25);
        expect(find.text(S.numberWasNotConfirmedTimeTask), findsOneWidget);
        expect(api.writes.where((c) => c.endsWith('/match')).length, 1);
        await _finish(tester);
      }, () => api.client);
    });

    testWidgets('開門後：完成與取消送出結束要求，書櫃拒絕時提示先關上櫃門，可改按另一個按鈕', (tester) async {
      Map<String, dynamic> opened(int version, {String? notice}) => _session(
        status: 'open',
        version: version,
        remainingMs: 20000,
        openMs: 30000,
        notice: notice,
        doors: [{'label': 'A02', 'state': 'open'}],
      );
      final closed = Completer<http.Response>();
      final api = _Api()
        ..current = opened(4)
        ..onClose = ((_) => closed.future);
      CabinetFlowOutcome? outcome;
      await http.runWithClient(() async {
        await _pump(tester, CabinetFlowScreen(resume: CabinetSession.fromJson(opened(4)), onOutcome: (value) => outcome = value));
        expect(_buttonLabels(tester), [S.finish, S.actionCancel]);
        expect(find.text(S.closeDoorFirst), findsNothing);

        await tester.tap(find.text(S.finish));
        await _settle(tester, 2);
        expect(api.bodies['POST /api/cabinet-sessions/$_sessionNo/close'], {'outcome': 'completed'});
        expect(_primary(tester, S.finish).isLoading, isTrue);
        expect(_secondary(tester, S.actionCancel).onPressed, isNull);

        api.current = opened(5);
        closed.complete(_ok(opened(5)));
        await _settle(tester, 3);
        expect(_primary(tester, S.finish).isLoading, isTrue, reason: '等待書櫃結束作業');
        expect(_secondary(tester, S.actionCancel).onPressed, isNull);

        api.current = opened(6, notice: 'CLOSE_DOOR_FIRST');
        _push(api.current!);
        await tester.pump(Duration.zero);
        expect(find.text(S.closeDoorFirst), findsOneWidget);
        expect(find.text(S.onceDoorClosedTaskEndAutomatically), findsOneWidget);
        expect(_primary(tester, S.finish).isLoading, isFalse);
        expect(_secondary(tester, S.actionCancel).onPressed, isNotNull);

        api
          ..current = opened(7)
          ..onClose = ((_) => _ok(opened(7)));
        await tester.tap(find.text(S.actionCancel));
        await _settle(tester, 3);
        expect(api.bodies['POST /api/cabinet-sessions/$_sessionNo/close'], {'outcome': 'cancelled'});
        expect(find.text(S.closeDoorFirst), findsNothing);
        expect(_secondary(tester, S.actionCancel).isLoading, isTrue);
        expect(outcome, CabinetFlowOutcome.started);

        _push(_session(status: 'cancelled', version: 8, remainingMs: null, result: _result('cancelled', 'CANCELLED_AFTER_OPEN')));
        await _settle(tester);
        expect(find.text(S.taskBeenCancelledNothingChanged), findsOneWidget);
        expect(_buttonLabels(tester), [S.rescan, S.finish]);
        expect(outcome, CabinetFlowOutcome.cancelled);
        expect(api.writes.where((c) => c.endsWith('/cancel')), isEmpty);
        await _finish(tester);
      }, () => api.client);
    });

    testWidgets('開門後：書櫃正在提交時顯示處理中，倒數結束後不能再送出', (tester) async {
      Map<String, dynamic> opened(int version, {int remainingMs = 20000}) => _session(
        status: 'open',
        version: version,
        remainingMs: remainingMs,
        openMs: 30000,
        doors: [{'label': 'A02', 'state': 'open'}],
      );
      final api = _Api()
        ..current = opened(5)
        ..onClose = ((_) => _fail('CABINET_SESSION_STATE', 409, {'session': opened(5)}, '本次作業處理中，請稍候'));
      await http.runWithClient(() async {
        await _pump(tester, CabinetFlowScreen(resume: CabinetSession.fromJson(opened(4))));
        await tester.tap(find.text(S.actionCancel));
        await _settle(tester, 3);
        expect(find.text(S.taskBeingProcessedPleaseWait), findsOneWidget);
        expect(_secondary(tester, S.actionCancel).isLoading, isFalse);

        api.current = opened(6, remainingMs: 0);
        _push(api.current!);
        await tester.pump(Duration.zero);
        expect(_primary(tester, S.finish).onPressed, isNull);
        expect(_secondary(tester, S.actionCancel).onPressed, isNull);
        await _finish(tester);
      }, () => api.client);
    });

    testWidgets('開門步驟依櫃門狀態顯示：未能開啟與開啟中的櫃門不顯示操作指示', (tester) async {
      final api = _Api();
      await http.runWithClient(() async {
        await _pump(
          tester,
          CabinetFlowScreen(
            resume: CabinetSession.fromJson(
              _session(
                status: 'open',
                version: 4,
                remainingMs: 40000,
                openMs: 45000,
                doors: [
                  {'label': 'A02', 'state': 'open'},
                  {'label': 'A03', 'state': 'failed'},
                  {'label': 'A04', 'state': 'pending'},
                ],
                items: [
                  _item(
                    'order_deposit',
                    books: [_sessionBook(55, '資料庫系統概論', door: 'A02'), _sessionBook(56, '作業系統', door: 'A03'), _sessionBook(57, '計算機網路', door: 'A04')],
                    doors: const ['A02', 'A03', 'A04'],
                  ),
                ],
              ),
            ),
          ),
          size: const Size(390, 1200),
        );
        expect(find.text(S.placeTheseBooksDoorP0('A02')), findsOneWidget);
        expect(find.text(S.placeTheseBooksDoorP0('A03')), findsNothing);
        expect(find.text(S.placeTheseBooksDoorP0('A04')), findsNothing);
        expect(find.text(S.doorP0('A03')), findsOneWidget);
        expect(find.text(S.doorDidNotOpen), findsOneWidget);
        expect(find.text(S.doorP0('A04')), findsOneWidget);
        expect(find.text(S.openingDoor), findsOneWidget);
        expect(find.text('作業系統'), findsOneWidget);
        await _finish(tester);
      }, () => api.client);
    });

    testWidgets('沒有待辦項目時，依其他書櫃的項目開啟購買紀錄或銷售紀錄', (tester) async {
      final api = _Api()
        ..onCreate = ((_) => _fail('CABINET_NOTHING_TO_DO', 404, {
          'other_cabinets': [{'cabinet_id': 4, 'cabinet_name': '師大書櫃', 'address': '', 'kinds': ['order_deposit']}],
        }));
      await http.runWithClient(() async {
        _signIn(id: 2);
        await _pump(tester, const CabinetFlowScreen(code: _code));
        await tester.tap(find.text(S.viewSales));
        await _settle(tester);
        expect(find.byType(SalesHistoryScreen), findsOneWidget);
        expect(tester.widget<SalesHistoryScreen>(find.byType(SalesHistoryScreen)).initialTab, 'pending_deposit');
        await _finish(tester);
      }, () => api.client);
    });

    testWidgets('在確認步驟返回時取消作業；開門期間不能返回，倒數結束後返回不取消', (tester) async {
      final api = _Api()
        ..onCreate = ((_) => _ok(_session(), 201))
        ..onCancel = ((_) => _ok(_session(status: 'cancelled', version: 2, remainingMs: null, result: _result('cancelled', 'CANCELLED_BY_USER'))));
      await http.runWithClient(() async {
        await _pump(tester, _Launcher(code: _code, onDone: (_) {}));
        await tester.tap(find.text('open'));
        await _settle(tester);
        await tester.tap(find.byIcon(Icons.arrow_back_rounded));
        await _settle(tester);
        expect(find.byType(CabinetFlowScreen), findsNothing);
        expect(api.writes, ['POST /api/cabinet-sessions', 'POST /api/cabinet-sessions/$_sessionNo/cancel']);

        api.calls.clear();
        api.current = _session(status: 'open', version: 4, remainingMs: 20000, openMs: 30000, doors: [{'label': 'A02', 'state': 'open'}]);
        await tester.pumpWidget(const SizedBox.shrink());
        await _pump(tester, _Launcher(onDone: (_) {}));
        final state = tester.state<NavigatorState>(find.byType(Navigator));
        unawaited(state.push(MaterialPageRoute<void>(builder: (_) => CabinetFlowScreen(resume: CabinetSession.fromJson(api.current!)))));
        await _settle(tester);
        expect(find.text(S.doorOpened), findsOneWidget);
        expect(find.byIcon(Icons.arrow_back_rounded), findsNothing, reason: '開門期間只能以完成或取消結束');
        await tester.binding.handlePopRoute();
        await _settle(tester);
        expect(find.byType(CabinetFlowScreen), findsOneWidget, reason: '系統返回也不離開');

        _push(_session(status: 'open', version: 5, remainingMs: 0, openMs: 30000, doors: [{'label': 'A02', 'state': 'open'}]));
        await tester.pump(Duration.zero);
        await tester.tap(find.byIcon(Icons.arrow_back_rounded));
        await _settle(tester);
        expect(find.byType(CabinetFlowScreen), findsNothing, reason: '倒數結束後可離開');
        expect(api.writes, isEmpty);
        await _finish(tester);
      }, () => api.client);
    });

    testWidgets('結果：失敗、待客服確認與部分完成', (tester) async {
      final api = _Api();
      await http.runWithClient(() async {
        await _pump(
          tester,
          CabinetFlowScreen(
            resume: CabinetSession.fromJson(_session(status: 'failed', version: 4, remainingMs: null, result: _result('failed', 'MATCH_FAILED'))),
          ),
        );
        expect(find.text(S.numberDidNotMatchTaskBeen), findsOneWidget);
        expect(_buttonLabels(tester), [S.rescan, S.finish]);

        await tester.pumpWidget(const SizedBox.shrink());
        await _pump(
          tester,
          CabinetFlowScreen(
            resume: CabinetSession.fromJson(
              _session(status: 'needs_review', version: 5, remainingMs: null, result: _result('needs_review', 'DEVICE_NO_ACK')),
            ),
          ),
        );
        expect(find.text(S.lockerDidNotConfirmDoorOpened), findsOneWidget);
        expect(_buttonLabels(tester), [S.finish, S.contactSupport]);

        await tester.pumpWidget(const SizedBox.shrink());
        await _pump(
          tester,
          CabinetFlowScreen(
            resume: CabinetSession.fromJson(
              _session(
                status: 'partial',
                version: 7,
                remainingMs: null,
                result: _result('partial', 'PARTIAL'),
                items: [
                  _item('order_deposit', result: 'done'),
                  _item('pre_deposit', key: 'book:60', books: [_sessionBook(60, '演算法', door: 'A03')], result: 'failed', error: {'code': 'DOOR_FAILED', 'message': ''}),
                ],
              ),
            ),
          ),
        );
        expect(find.text(S.someItemsWereNotCompleted), findsOneWidget);
        expect(find.text(S.orderCompleted), findsOneWidget);
        expect(find.text(S.notCompletedP0(S.doorDidNotOpen)), findsOneWidget);
        expect(_buttonLabels(tester), [S.finish]);

        await tester.pumpWidget(const SizedBox.shrink());
        await _pump(
          tester,
          CabinetFlowScreen(
            resume: CabinetSession.fromJson(
              _session(
                status: 'partial',
                version: 7,
                remainingMs: null,
                result: _result('partial', 'ITEMS_FAILED'),
                items: [
                  _item('pickup', result: 'failed', error: {'code': 'DOOR_UNCONFIRMED', 'message': ''}),
                ],
              ),
            ),
          ),
        );
        expect(find.text(S.itemsCouldNotCompleted), findsOneWidget);
        expect(find.text(S.someItemsWereNotCompleted), findsNothing);
        expect(find.text(S.notCompletedP0(S.doorOpeningNotConfirmedSupportCheck)), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await _pump(
          tester,
          CabinetFlowScreen(
            resume: CabinetSession.fromJson(
              _session(status: 'completed', version: 7, remainingMs: null, result: _result('completed', 'COMPLETED'), items: [_item('order_deposit', result: 'done')]),
            ),
          ),
        );
        expect(find.text(S.dropOffCompleteBuyerBeenNotified), findsOneWidget);
        expect(find.byType(PickupSuccessScreen), findsNothing);
        await _finish(tester);
      }, () => api.client);
    });
  });

  group('接續與深層連結', () {
    testWidgets('有開門中的作業時開啟流程畫面；待客服確認時不開啟，且不重複開啟', (tester) async {
      final key = GlobalKey<NavigatorState>();
      final api = _Api();
      await http.runWithClient(() async {
        await _pump(tester, const Scaffold(body: SizedBox.expand()), navigatorKey: key);
        CabinetResume.navigatorKey = key;

        api.active = _session(status: 'needs_review', version: 6, remainingMs: null, result: _result('needs_review', 'DEVICE_LOST'));
        unawaited(CabinetResume.check());
        await _settle(tester);
        expect(find.byType(CabinetFlowScreen), findsNothing);

        api.active = _session(status: 'open', version: 4, remainingMs: 20000, openMs: 30000, doors: [{'label': 'A02', 'state': 'open'}]);
        api.current = api.active;
        unawaited(CabinetResume.check());
        await _settle(tester);
        expect(find.byType(CabinetFlowScreen), findsOneWidget);
        expect(find.text(S.takeBooksFromDoorP0('A02')), findsOneWidget);

        unawaited(CabinetResume.check());
        await _settle(tester);
        expect(find.byType(CabinetFlowScreen), findsOneWidget);
        await _finish(tester);
      }, () => api.client);
    });

    testWidgets('取書分頁開著相機時，由連結或接續開啟的流程畫面會先釋放取書分頁的相機，關閉後恢復', (tester) async {
      final messenger = tester.binding.defaultBinaryMessenger;
      const method = MethodChannel('dev.steenbakker.mobile_scanner/scanner/method');
      const events = MethodChannel('dev.steenbakker.mobile_scanner/scanner/event');
      messenger.setMockMethodCallHandler(method, (call) async => switch (call.method) {
        'state' => 1,
        'start' => {'textureId': 1, 'numberOfCameras': 1, 'currentTorchState': -1, 'size': {'width': 1280.0, 'height': 720.0}},
        _ => null,
      });
      messenger.setMockMethodCallHandler(events, (_) async => null);
      addTearDown(() {
        messenger.setMockMethodCallHandler(method, null);
        messenger.setMockMethodCallHandler(events, null);
      });
      CabinetScannerView.debugScanInput = null;
      final key = GlobalKey<NavigatorState>();
      final api = _Api();
      Finder scannersIn(Type type) => find.descendant(of: find.byType(type, skipOffstage: false), matching: find.byType(MobileScanner, skipOffstage: false));
      await http.runWithClient(() async {
        await _pump(tester, const Scaffold(body: PickupBookScreen(isActive: true)), navigatorKey: key);
        CabinetResume.navigatorKey = key;
        expect(scannersIn(PickupBookScreen), findsOneWidget);

        CabinetResume.openScanner();
        await _settle(tester);
        expect(find.byType(CabinetFlowScreen), findsOneWidget);
        expect(scannersIn(CabinetFlowScreen), findsOneWidget);
        expect(scannersIn(PickupBookScreen), findsNothing);

        await tester.tap(find.byIcon(Icons.arrow_back_rounded));
        await _settle(tester);
        expect(find.byType(CabinetFlowScreen), findsNothing);
        expect(scannersIn(PickupBookScreen), findsOneWidget);

        api.active = _session(status: 'open', version: 4, remainingMs: 20000, openMs: 30000, doors: [{'label': 'A02', 'state': 'open'}]);
        api.current = api.active;
        unawaited(CabinetResume.check());
        await _settle(tester);
        expect(find.byType(CabinetFlowScreen), findsOneWidget);
        expect(scannersIn(PickupBookScreen), findsNothing);
        await _finish(tester);
      }, () => api.client);
    });

    testWidgets('系統相機的書櫃連結只開啟掃描步驟，不建立作業', (tester) async {
      final key = GlobalKey<NavigatorState>();
      final api = _Api();
      await http.runWithClient(() async {
        await _pump(tester, const Scaffold(body: SizedBox.expand()), navigatorKey: key);
        CabinetResume.navigatorKey = key;
        DeepLinkService.onCabinetLink = CabinetResume.openScanner;
        DeepLinkService.deliver(_code);
        await _settle(tester);
        expect(find.byType(CabinetFlowScreen), findsOneWidget);
        expect(find.text(S.pointQrCodeLockerScreen), findsOneWidget);
        expect(api.calls, isEmpty);
        await _finish(tester);
      }, () => api.client);
    });
  });

  group('入口', () {
    testWidgets('訂單詳情（買家）：依存取模式顯示掃碼或手動文字，停用與維修時只顯示訊息', (tester) async {
      var order = _order(access: _access('scan'));
      final api = _Api()..other = ((request) => request.url.path == '/api/orders/128' ? _ok(order) : null);
      await http.runWithClient(() async {
        await _pump(tester, OrderDetailScreen(order: Order.fromJson(order)), size: const Size(390, 1600));
        expect(find.text(S.scanLockerCollect), findsOneWidget);
        expect(find.text('A02'), findsOneWidget);
        expect(find.text('${S.door}：'), findsOneWidget);
        expect(find.text('${S.slot}：'), findsNothing);
        await tester.tap(find.text(S.scanLockerCollect));
        await _settle(tester);
        expect(find.byType(CabinetFlowScreen), findsOneWidget);
        await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
        await _settle(tester);

        order = _order(access: _access('unavailable', reason: 'maintenance'));
        await tester.pumpWidget(const SizedBox.shrink());
        await _pump(tester, OrderDetailScreen(order: Order.fromJson(order)), size: const Size(390, 1600));
        await tester.tap(find.text(S.scanLockerCollect));
        await _settle(tester);
        expect(find.byType(CabinetFlowScreen), findsNothing);
        expect(find.text(S.lockerUnderMaintenance), findsOneWidget);

        order = _order(access: _access('scan', openNow: false));
        await tester.pumpWidget(const SizedBox.shrink());
        await _pump(tester, OrderDetailScreen(order: Order.fromJson(order)), size: const Size(390, 1600));
        await tester.tap(find.text(S.scanLockerCollect));
        await _settle(tester);
        expect(find.byType(CabinetFlowScreen), findsNothing);
        expect(find.text(S.lockerClosedNowOpeningHoursP0(formatTimeRange('08:00', '22:00'))), findsOneWidget);

        order = _order(access: _access('manual', reason: 'no_device'));
        await tester.pumpWidget(const SizedBox.shrink());
        await _pump(tester, OrderDetailScreen(order: Order.fromJson(order)), size: const Size(390, 1600));
        expect(find.text(S.iCollected), findsOneWidget);
        await _finish(tester);
      }, () => api.client);
    });

    testWidgets('書櫃離線時改為手動回報，送出後待客服確認並停用同一動作', (tester) async {
      var order = _order(access: _access('scan'));
      final api = _Api()
        ..onCreate = ((_) => _fail('CABINET_OFFLINE', 409, {'manual_allowed': true}))
        ..other = ((request) {
          if (request.url.path == '/api/orders/128') return _ok(order);
          if (request.url.path == '/api/orders/128/status') {
            order = _order(access: _access('manual', reason: 'offline'), report: _manualReport('pickup'));
            return _ok(order, 202, {'message': '已送出手動回報，待客服確認後生效'});
          }
          return null;
        });
      await http.runWithClient(() async {
        await _pump(tester, OrderDetailScreen(order: Order.fromJson(order)), size: const Size(390, 1600));
        await tester.tap(find.text(S.scanLockerCollect));
        await _settle(tester);
        scans.add(_code);
        await _settle(tester);
        expect(_withoutAge(api.bodies['POST /api/cabinet-sessions']), {'code': _code, 'context': {'type': 'order', 'id': 128}, ..._located});
        await tester.tap(find.text(S.reportManually));
        await _settle(tester);
        expect(find.byType(CabinetFlowScreen), findsNothing);
        expect(find.textContaining(S.lockerOfflineSoDoorCannotOpened), findsOneWidget);
        expect(find.textContaining(S.confirmTakenBookFromLocker), findsOneWidget);
        expect(find.textContaining(S.confirmVeTakenBookFromLocker), findsNothing, reason: '待客服確認的回報不說明確認後的後續動作');
        await tester.tap(find.text(S.confirm));
        await _settle(tester);
        expect(api.bodies['PATCH /api/orders/128/status'], {'status': 'picked_up'});
        expect(find.text(S.reportSubmittedTakesEffectAfterSupport), findsOneWidget);
        expect(find.byType(PickupSuccessScreen), findsNothing);
        expect(find.text(S.manualReportAwaitingConfirmation), findsOneWidget);
        expect(_primary(tester, S.iCollected).onPressed, isNull);
        await _finish(tester);
      }, () => api.client);
    });

    testWidgets('手動回報時伺服器判定須掃碼，改開掃碼流程', (tester) async {
      final order = _order(access: _access('manual', reason: 'no_device'));
      final api = _Api()
        ..other = ((request) {
          if (request.url.path == '/api/orders/128') return _ok(order);
          if (request.url.path == '/api/orders/128/status') return _fail('CABINET_SCAN_REQUIRED', 409, {'cabinet_id': 3});
          return null;
        });
      await http.runWithClient(() async {
        await _pump(tester, OrderDetailScreen(order: Order.fromJson(order)), size: const Size(390, 1600));
        await tester.tap(find.text(S.iCollected));
        await _settle(tester);
        expect(find.textContaining(S.manualReportsTakeEffectAfterSupport), findsOneWidget);
        await tester.tap(find.text(S.confirm));
        await _settle(tester);
        expect(find.byType(CabinetFlowScreen), findsOneWidget);
        expect(find.text(S.pointQrCodeLockerScreen), findsOneWidget);
        await _finish(tester);
      }, () => api.client);
    });

    testWidgets('訂單詳情（賣家）：待存書訂單提供存書按鈕', (tester) async {
      final order = _order(status: 'pending_deposit', access: _access('scan'), doors: const []);
      final api = _Api()..other = ((request) => request.url.path == '/api/orders/128' ? _ok(order) : null);
      await http.runWithClient(() async {
        _signIn(id: 2);
        await _pump(tester, OrderDetailScreen(order: Order.fromJson(order), asSeller: true), size: const Size(390, 1600));
        expect(find.text(S.scanLockerDropOff), findsOneWidget);
        await tester.tap(find.text(S.scanLockerDropOff));
        await _settle(tester);
        expect(find.byType(CabinetFlowScreen), findsOneWidget);
        await _finish(tester);
      }, () => api.client);
    });

    testWidgets('購買紀錄與銷售紀錄：卡片文字依存取模式，櫃門不足時只顯示訊息', (tester) async {
      final api = _Api()
        ..other = ((request) {
          if (request.url.path != '/api/orders') return null;
          return switch (request.url.queryParameters['tab']) {
            'pending_pickup' => _ok([_order(access: _access('scan'))]),
            'pending_deposit' => _ok([_order(id: 130, status: 'pending_deposit', access: _access('scan', doors: 0), doors: const [])]),
            _ => _ok(<Object>[]),
          };
        });
      await http.runWithClient(() async {
        await _pump(tester, const PurchaseHistoryScreen());
        expect(find.text(S.scanLockerCollect), findsOneWidget);
        expect(find.text(S.doorP0('A02')), findsOneWidget);

        _signIn(id: 2);
        await tester.pumpWidget(const SizedBox.shrink());
        await _pump(tester, const SalesHistoryScreen());
        expect(find.text(S.scanLockerDropOff), findsOneWidget);
        await tester.tap(find.text(S.scanLockerDropOff));
        await _settle(tester);
        expect(find.byType(CabinetFlowScreen), findsNothing);
        expect(find.text(S.noDoorsAvailableMoment), findsOneWidget);
        await _finish(tester);
      }, () => api.client);
    });

    testWidgets('書籍管理與書籍詳情：實際存放於書櫃的書提供取回，先行存書額度用完時只顯示訊息', (tester) async {
      final located = _book(
        1,
        '編譯器設計',
        status: 'removed',
        access: _access('scan'),
        location: {'cabinet_id': 4, 'cabinet_name': '師大書櫃', 'door': 'A03', 'retrievable': true, 'access': _access('scan')},
      );
      final onSale = _book(2, '演算法', access: _access('scan', preDeposit: 0));
      final api = _Api()
        ..other = ((request) {
          final path = request.url.path;
          if (path == '/api/books/1') return _ok(located);
          if (path == '/api/books/2') return _ok(onSale);
          if (path.endsWith('/books')) return _ok([located, onSale]);
          return null;
        });
      await http.runWithClient(() async {
        await _pump(tester, const BookManageScreen(), size: const Size(390, 1400));
        expect(find.text(S.scanLockerRetrieve), findsOneWidget);
        expect(find.text('師大書櫃・${S.doorP0('A03')}'), findsOneWidget);
        expect(find.text(S.relist), findsNothing);
        expect(find.text(S.scanLockerDropOff), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await _pump(tester, BookDetailScreen(book: Book.fromJson(onSale)), size: const Size(390, 1600));
        await tester.tap(find.text(S.scanLockerDropOff));
        await _settle(tester);
        expect(find.byType(CabinetFlowScreen), findsNothing);
        expect(find.text(S.noDoorsAvailableMoment), findsOneWidget);
        await _finish(tester);
      }, () => api.client);
    });

    testWidgets('書籍頁：手動存書送出後待客服確認，按鈕停用', (tester) async {
      var book = _book(1, '小王子', access: _access('manual', reason: 'no_device', doors: null, preDeposit: null));
      final api = _Api()
        ..other = ((request) {
          final path = request.url.path;
          if (path == '/api/books/1/deposit') {
            book = {...book, 'manual_report': _manualReport('deposit')};
            return _ok({'book_id': 1, 'in_cabinet': false, 'deposit': null, 'manual_report': _manualReport('deposit')}, 202, {'message': '已送出手動回報，待客服確認後生效'});
          }
          if (path == '/api/books/1') return _ok(book);
          return null;
        });
      await http.runWithClient(() async {
        await _pump(tester, BookDetailScreen(book: Book.fromJson(book)), size: const Size(390, 1600));
        await tester.tap(find.text(S.dropOff));
        await _settle(tester);
        expect(find.textContaining(S.manualReportsTakeEffectAfterSupport), findsOneWidget);
        await tester.tap(find.text(S.dropOff).last);
        await _settle(tester);
        expect(api.writes, ['POST /api/books/1/deposit']);
        expect(find.text(S.reportSubmittedTakesEffectAfterSupport), findsOneWidget);
        expect(find.text(S.manualReportAwaitingConfirmation), findsOneWidget);
        expect(tester.widget<SmallActionButton>(find.widgetWithText(SmallActionButton, S.dropOff)).onTap, isNull);
        await _finish(tester);
      }, () => api.client);
    });

    testWidgets('開門後離開流程畫面，訂單詳情重新載入', (tester) async {
      final order = _order(access: _access('scan'));
      final api = _Api()
        ..onCreate = ((_) => _ok(_session(), 201))
        ..onStart = ((_) => _ok(_session(status: 'opening', version: 2, doors: [{'label': 'A02', 'state': 'pending'}])))
        ..other = ((request) => request.url.path == '/api/orders/128' ? _ok(order) : null);
      int loads() => api.calls.where((c) => c == 'GET /api/orders/128').length;
      await http.runWithClient(() async {
        await _pump(tester, OrderDetailScreen(order: Order.fromJson(order)), size: const Size(390, 1600));
        await tester.tap(find.text(S.scanLockerCollect));
        await _settle(tester);
        scans.add(_code);
        await _settle(tester);
        await tester.tap(find.text(S.openDoor));
        await _settle(tester);
        expect(find.text(S.openingDoor), findsOneWidget);
        expect(tester.widget<AppHeader>(find.descendant(of: find.byType(CabinetFlowScreen), matching: find.byType(AppHeader))).showBack, isFalse);
        _push(_session(status: 'opening', version: 3, remainingMs: 0, doors: [{'label': 'A02', 'state': 'pending'}]));
        await tester.pump(Duration.zero);
        final before = loads();
        await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
        await _settle(tester);
        expect(find.byType(CabinetFlowScreen), findsNothing);
        expect(api.writes.where((c) => c.endsWith('/cancel')), isEmpty);
        expect(loads(), greaterThan(before));
        await _finish(tester);
      }, () => api.client);
    });

    testWidgets('手動回報存書時櫃門不足，顯示書櫃目前沒有可用的櫃門', (tester) async {
      final book = _book(1, '小王子', access: _access('manual', reason: 'offline', doors: null, preDeposit: null));
      final api = _Api()
        ..other = ((request) {
          final path = request.url.path;
          if (path == '/api/books/1/deposit') {
            return _fail('CABINET_FULL', 409, {'available_doors': 0, 'required_doors': 1}, '此書櫃可用的櫃門不足，請減少存書項目或稍後再試');
          }
          if (path == '/api/books/1') return _ok(book);
          return null;
        });
      await http.runWithClient(() async {
        await _pump(tester, BookDetailScreen(book: Book.fromJson(book)), size: const Size(390, 1600));
        await tester.tap(find.text(S.dropOff));
        await _settle(tester);
        expect(find.textContaining(S.confirmP0BeenPlacedP1('小王子', '台大書櫃')), findsOneWidget);
        await tester.tap(find.text(S.dropOff).last);
        await _settle(tester);
        expect(find.text(S.noDoorsAvailableMoment), findsOneWidget);
        expect(find.text(S.notEnoughDoorsAvailableSelectFewer), findsNothing);
        await _finish(tester);
      }, () => api.client);
    });

    testWidgets('僅有存放位置、未登記存書的書，書櫃非掃碼模式時不送出取回回報', (tester) async {
      Map<String, dynamic> located(String reason) => _book(
        1,
        '編譯器設計',
        status: 'removed',
        access: _access('manual', reason: reason),
        location: {'cabinet_id': 3, 'cabinet_name': '台大書櫃', 'door': 'A03', 'retrievable': true, 'access': _access('manual', reason: reason)},
      );
      var book = located('offline');
      final api = _Api()..other = ((request) => request.url.path == '/api/books/1' ? _ok(book) : null);
      await http.runWithClient(() async {
        await _pump(tester, BookDetailScreen(book: Book.fromJson(book)), size: const Size(390, 1600));
        await tester.tap(find.text(S.retrieve));
        await _settle(tester);
        expect(find.text(S.lockerOfflineTemporarilyUnavailable), findsOneWidget);
        expect(find.byType(AlertDialog), findsNothing);

        book = located('no_device');
        await tester.pumpWidget(const SizedBox.shrink());
        await _pump(tester, BookDetailScreen(book: Book.fromJson(book)), size: const Size(390, 1600));
        await tester.tap(find.text(S.retrieve));
        await _settle(tester);
        expect(find.text(S.retrievalNotAvailableLockerRightNow), findsOneWidget);
        expect(api.writes, isEmpty);
        await _finish(tester);
      }, () => api.client);
    });

    testWidgets('取消上架的確認文字依取回方式說明', (tester) async {
      await _pump(tester, const SizedBox.shrink());
      final location = {'cabinet_id': 3, 'cabinet_name': '台大書櫃', 'door': 'A03', 'retrievable': true};
      final scan = Book.fromJson(_book(1, '小王子', access: _access('scan'), location: {...location, 'access': _access('scan')}));
      final manual = Book.fromJson(_book(1, '小王子', access: _access('manual', reason: 'no_device'), location: {...location, 'access': _access('manual', reason: 'no_device')}));
      final plain = Book.fromJson(_book(1, '小王子'));
      expect(delistMessage(scan), S.onceDelistedP0NoLongerAppear('小王子'));
      expect(delistMessage(manual), S.onceDelistedP0NoLongerAppear2('小王子'));
      expect(delistMessage(plain), S.removedFromShopBuyersNoLonger('小王子'));
    });

    testWidgets('取書分頁：掃到書櫃碼開啟流程，掃到其他內容時說明並非書櫃 QR Code', (tester) async {
      final api = _Api()..onCreate = ((_) => _ok(_session(), 201));
      final input = StreamController<String>.broadcast();
      await http.runWithClient(() async {
        await _pump(tester, Scaffold(body: PickupBookScreen(isActive: true, scanInput: input.stream)));
        expect(find.text(S.pointQrCodeLockerScreen), findsOneWidget);
        expect(find.text(S.collectBook), findsOneWidget);

        input.add('https://example.com/pay?id=1');
        await _settle(tester);
        expect(find.text(S.notSavemybookLockerQrCode), findsOneWidget);
        expect(find.text('https://example.com/pay?id=1'), findsNothing);
        expect(find.text(S.copy), findsNothing);
        expect(find.byType(AlertDialog), findsOneWidget);
        await tester.tap(find.text(S.rescan));
        await _settle(tester);

        input.add(_code);
        await _settle(tester);
        expect(find.byType(CabinetFlowScreen), findsOneWidget);
        expect(_withoutAge(api.bodies['POST /api/cabinet-sessions']), {'code': _code, ..._located});
        expect(find.text(S.openDoor), findsOneWidget);
        await _finish(tester);
      }, () => api.client);
      await input.close();
    });

    testWidgets('刊登表單：可用格位為 0 的書櫃仍可選取', (tester) async {
      final api = _Api()
        ..other = ((request) => request.url.path == '/api/cabinets'
            ? _ok([
                {..._cabinetJson, 'cabinet_id': 3, 'available_slots': 0},
                {..._cabinetJson, 'cabinet_id': 4, 'cabinet_name': '師大書櫃', 'available_slots': 3},
              ])
            : null);
      int? picked;
      await http.runWithClient(() async {
        await _pump(
          tester,
          Scaffold(
            body: CabinetSelectField(value: null, autoSelectNearest: true, onChanged: (cabinet, _) => picked = CabinetSelectField.idOf(cabinet ?? const {})),
          ),
        );
        final select = tester.widget<AppSelect<int>>(find.byType(AppSelect<int>));
        expect(select.options.map((o) => o.enabled), [true, true]);
        expect(picked, 3);
        await _finish(tester);
      }, () => api.client);
    });
  });

  testWidgets('流程畫面各步驟在 320×568 的六種語系都不溢出', (tester) async {
    const locales = [
      Locale('zh'),
      _zhHant,
      Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
      Locale('en'),
      Locale('ja'),
      Locale('ko'),
    ];
    final longTitle = 'The Extraordinarily Long Title of a Second-hand Book About Everything';
    final screens = <String, Widget Function()>{
      'scan': () => CabinetFlowScreen(scanInput: const Stream.empty()),
      'location': () => CabinetFlowScreen(controller: CabinetFlowController()..fail(const CabinetApiError(code: CabinetApiError.locationRequired))),
      'imprecise': () => CabinetFlowScreen(controller: CabinetFlowController()..fail(const CabinetApiError(code: CabinetApiError.locationImprecise))),
      'confirm': () => CabinetFlowScreen(
        resume: CabinetSession.fromJson(
          _session(
            locationStatus: 'unavailable',
            items: [
              _item('pickup', books: [_sessionBook(55, longTitle), _sessionBook(56, longTitle)], doors: const ['A01', 'A02']),
              _item('pre_deposit', key: 'book:60', doors: const [], books: [_sessionBook(60, longTitle, door: null)], blocked: {'code': 'PREDEPOSIT_LIMIT', 'message': ''}),
              _item(
                'retrieval',
                key: 'book:61',
                books: [_sessionBook(61, longTitle, door: 'A03')],
                doors: const ['A03'],
                paused: true,
                note: {'code': 'MOVE_TO_ORDER_CABINET', 'message': '此書籍已售出，取回後請存入訂單指定的書櫃「National Taiwan University Main Library Smart Locker」'},
              ),
            ],
          ),
        ),
      ),
      'match': () => CabinetFlowScreen(
        resume: CabinetSession.fromJson(_session(status: 'matching', version: 2, doors: [{'label': 'A01', 'state': 'pending'}, {'label': 'A02', 'state': 'pending'}])),
      ),
      'opening': () => CabinetFlowScreen(resume: CabinetSession.fromJson(_session(status: 'opening', version: 3, doors: [{'label': 'A02', 'state': 'pending'}]))),
      'open-refused': () => CabinetFlowScreen(
        resume: CabinetSession.fromJson(
          _session(
            status: 'open',
            version: 6,
            remainingMs: 40000,
            openMs: 45000,
            notice: 'CLOSE_DOOR_FIRST',
            doors: [{'label': 'A01', 'state': 'open'}],
            items: [_item('pickup', books: [_sessionBook(55, longTitle, door: 'A01')], doors: const ['A01'])],
          ),
        ),
      ),
      'open': () => CabinetFlowScreen(
        resume: CabinetSession.fromJson(
          _session(
            status: 'open',
            version: 4,
            remainingMs: 44000,
            openMs: 45000,
            doors: [{'label': 'A01', 'state': 'open'}, {'label': 'A02', 'state': 'open'}],
            items: [
              _item('order_deposit', books: [_sessionBook(55, longTitle, door: 'A01'), _sessionBook(56, longTitle, door: 'A02')], doors: const ['A01', 'A02']),
            ],
          ),
        ),
      ),
      'partial': () => CabinetFlowScreen(
        resume: CabinetSession.fromJson(
          _session(
            status: 'partial',
            version: 7,
            remainingMs: null,
            result: _result('partial', 'ITEMS_FAILED'),
            items: [
              _item('order_deposit', books: [_sessionBook(55, longTitle)], result: 'failed', error: {'code': 'DOOR_UNCONFIRMED', 'message': ''}),
              _item('retrieval', key: 'book:61', books: [_sessionBook(61, longTitle, door: 'A03')], doors: const ['A03'], result: 'done'),
            ],
          ),
        ),
      ),
      'review': () => CabinetFlowScreen(
        resume: CabinetSession.fromJson(_session(status: 'needs_review', version: 6, remainingMs: null, result: _result('needs_review', 'DEVICE_INTERRUPTED'))),
      ),
      'error': () => CabinetFlowScreen(
        controller: CabinetFlowController()
          ..fail(
            const CabinetApiError(
              code: 'CABINET_WRONG_CABINET',
              extra: {
                'cabinet': {'cabinet_id': 4, 'cabinet_name': 'National Taiwan University Main Library Smart Locker', 'address': 'No. 1, Sec. 4, Roosevelt Rd., Da’an Dist., Taipei City 106319', 'latitude': 25.0, 'longitude': 121.5},
              },
            ),
          ),
      ),
    };
    final api = _Api();
    final problems = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      final text = details.exceptionAsString();
      if (text.contains('overflowed')) {
        problems.add(text.split('\n').first);
      } else if (!text.contains('NetworkImageLoadException')) {
        problems.add('[例外] ${text.split('\n').first}');
      }
    };
    try {
      await http.runWithClient(() async {
        for (final locale in locales) {
          for (final entry in screens.entries) {
            final before = problems.length;
            await tester.pumpWidget(const SizedBox.shrink());
            await _pump(tester, entry.value(), size: const Size(320, 568), locale: locale);
            for (var i = before; i < problems.length; i++) {
              problems[i] = '${entry.key} ${locale.toLanguageTag()}: ${problems[i]}';
            }
          }
        }
        await _finish(tester);
      }, () => api.client);
    } finally {
      FlutterError.onError = previous;
    }
    expect(problems, isEmpty);
  });
}
