import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:savemybook_app/features/admin/admin_cabinet_edit_screen.dart';
import 'package:savemybook_app/features/cabinet/cabinet_guide_screen.dart';
import 'package:savemybook_app/i18n/app_localizations.dart';
import 'package:savemybook_app/i18n/strings.dart';
import 'package:savemybook_app/models/admin_models.dart';
import 'package:savemybook_app/models/transit.dart';
import 'package:savemybook_app/services/api_service.dart';
import 'package:savemybook_app/services/locale_provider.dart';
import 'package:savemybook_app/services/location_service.dart';
import 'package:savemybook_app/utils/app_theme.dart';

// 取自 API 以師大路測資回傳的內容（2026-10-02 data.taipei 資料）。
Map<String, dynamic> _nearby({bool youbikeDown = false, bool noLots = false, bool busDown = false}) => {
  'cabinet': {'latitude': 25.0245, 'longitude': 121.5288},
  'mrt': {
    'status': 'ok',
    'updated_at': '2026-10-02T12:29:04.970Z',
    'stations': [
      {
        'name': '台電大樓',
        'distance_m': 382,
        'nearest_exit': {'exit': '3', 'accessible': false, 'latitude': 25.021179, 'longitude': 121.527849, 'distance_m': 382},
        'accessible_exit': {'exit': '5', 'facility': 'elevator', 'latitude': 25.020758, 'longitude': 121.527739, 'distance_m': 430},
      },
      {
        'name': '古亭',
        'distance_m': 559,
        'nearest_exit': {'exit': '3', 'accessible': false, 'latitude': 25.0259191, 'longitude': 121.523477, 'distance_m': 559},
        'accessible_exit': null,
      },
    ],
  },
  'bus': busDown
      ? {'status': 'unavailable', 'stops': <Object>[], 'updated_at': null, 'realtime_available': false}
      : {
          'status': 'ok',
          'updated_at': '2026-10-02T13:02:00.000Z',
          'realtime_available': true,
          'stops': [
            {
              'name': '師大綜合大樓',
              'address': '和平東路一段184號同向(向東)',
              'latitude': 25.026362,
              'longitude': 121.529958,
              'distance_m': 238,
              'routes': [
                {'name': '復興幹線', 'direction': '建北站', 'status': 'arriving', 'minutes': 0},
                {'name': '235', 'direction': '交通部觀光署', 'status': 'minutes', 'minutes': 4},
                {'name': '18', 'direction': '捷運麟光站', 'status': 'minutes', 'minutes': 6},
                {'name': '672', 'direction': '民生社區活動中心', 'status': 'minutes', 'minutes': 14},
                {'name': '295副', 'direction': '富德', 'status': 'not_departed', 'minutes': null},
                {'name': '568', 'direction': '捷運麟光站', 'status': 'last_passed', 'minutes': null},
                {'name': '通勤7', 'direction': '臺大', 'status': 'no_service', 'minutes': null},
              ],
            },
          ],
        },
  'road_speed': {
    'status': 'ok',
    'updated_at': '2026-10-02T13:03:22.279Z',
    'sections': [
      {'road': '和平西路', 'between': '重慶南路-羅斯福路', 'speed_kph': 36, 'level': 'busy', 'distance_m': 290},
      {'road': '羅斯福路', 'between': '和平東路-辛亥路', 'speed_kph': 56, 'level': 'smooth', 'distance_m': 367},
    ],
  },
  'taxi_stands': {
    'status': 'ok',
    'updated_at': '2026-10-02T13:03:22.279Z',
    'stands': [
      {'name': '經濟部工業局', 'street': '信義路3段41-3號', 'spaces': 2, 'hours': '0~24', 'latitude': 25.033687, 'longitude': 121.535252, 'distance_m': 330},
    ],
  },
  'youbike': youbikeDown
      ? {'status': 'unavailable', 'stations': <Object>[], 'updated_at': null}
      : {
          'status': 'ok',
          'updated_at': '2026-10-02T11:50:04.000Z',
          'stations': [
            {'name': '臺灣師範大學(浦城街)', 'address': '浦城街1號對側', 'latitude': 25.02476, 'longitude': 121.52803, 'distance_m': 83, 'available_rent': 19, 'available_return': 0, 'total': 20, 'is_active': true},
            {'name': '臺灣師範大學(圖書館)', 'address': '和平東路一段129號前', 'latitude': 25.0266, 'longitude': 121.52973, 'distance_m': 252, 'available_rent': 22, 'available_return': 18, 'total': 40, 'is_active': false},
          ],
        },
  'parking_lots': {
    'status': 'ok',
    'updated_at': '2026-10-02T11:47:00.000Z',
    'realtime_available': true,
    'lots': noLots
        ? <Object>[]
        : [
            {
              'name': 'Times師大夜市',
              'address': '泰順街38巷25號旁',
              'tel': '0809008924',
              'fee': '小型車：計時 200元/時',
              'hours': '00:00:00-23:59:59',
              'latitude': 25.0246,
              'longitude': 121.5297,
              'distance_m': 78,
              'car': {'total': 18, 'available': 3},
              'motorcycle': {'total': 0, 'available': null},
            },
            {
              'name': '泰順街停車場',
              'address': '泰順街60巷26號空地',
              'tel': '',
              'fee': '',
              'hours': '',
              'latitude': 25.0223,
              'longitude': 121.5295,
              'distance_m': 249,
              'car': {'total': 5, 'available': null},
              'motorcycle': {'total': 0, 'available': null},
            },
          ],
  },
  'roadside': {
    'status': 'ok',
    'radius_m': 300,
    'layer_updated_at': '2026-08-27T09:32:00.000Z',
    'updated_at': '2026-10-02T11:45:10.000Z',
    'car': [
      {
        'name': '師大路C',
        'segment_id': '30540C0',
        'distance_m': 28,
        'latitude': 25.024494,
        'longitude': 121.52852,
        'spaces_nearby': 13,
        'accessible_nearby': 4,
        'live': {'total': 3, 'available': 1, 'fee': '40元', 'start': '07:00', 'end': '20:00', 'updated_at': '2026-10-02T11:45:10.000Z'},
      },
      {
        'name': '龍泉街5巷',
        'segment_id': '3055005',
        'distance_m': 184,
        'latitude': 25.026,
        'longitude': 121.529577,
        'spaces_nearby': 4,
        'accessible_nearby': 0,
        'live': {'total': 4, 'available': null, 'fee': '20元', 'start': '09:00', 'end': '17:00', 'updated_at': null},
      },
    ],
    'motorcycle': [
      {'name': '師大路A(機車)', 'distance_m': 34, 'latitude': 25.0246, 'longitude': 121.5286, 'spaces_nearby': 168, 'accessible_nearby': 0, 'has_parking_area': true},
    ],
  },
  'attribution': '資料來源：臺北市資料大平臺（data.taipei），依政府資料開放授權條款第 1 版使用',
  'sources': <Object>[],
};

const _stations = [
  {'name': '古亭', 'latitude': 25.026695, 'longitude': 121.522662},
  {'name': '台北車站', 'latitude': 25.046778, 'longitude': 121.517707},
  {'name': '台電大樓', 'latitude': 25.020553, 'longitude': 121.528111},
];

http.Response _ok(Object data) =>
    http.Response(jsonEncode({'success': true, 'data': data}), 200, headers: {'content-type': 'application/json; charset=utf-8'});

http.Response _fail(int status, String message) =>
    http.Response(jsonEncode({'success': false, 'message': message}), status, headers: {'content-type': 'application/json; charset=utf-8'});

Widget _host(Widget child) => MaterialApp(
  locale: const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  supportedLocales: LocaleProvider.supported,
  theme: AppTheme.build(Brightness.light),
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  builder: (context, inner) {
    S = AppLocalizations.of(context);
    return inner ?? const SizedBox.shrink();
  },
  home: child,
);

Future<void> _settle(WidgetTester tester, [int frames = 12]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _pump(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(390, 844) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_host(home));
  await _settle(tester);
}

class _Geolocator extends GeolocatorPlatform {
  LocationPermission permission = LocationPermission.whileInUse;
  LocationAccuracyStatus accuracyStatus = LocationAccuracyStatus.precise;
  double accuracy = 12;
  String? purposeKey;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async => permission;

  @override
  Future<LocationAccuracyStatus> getLocationAccuracy() async => accuracyStatus;

  @override
  Future<LocationAccuracyStatus> requestTemporaryFullAccuracy({required String purposeKey}) async {
    this.purposeKey = purposeKey;
    return accuracyStatus;
  }

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<Position?> getLastKnownPosition({bool forceLocationManager = false}) async => null;

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) async => Position(
    latitude: 25.0421,
    longitude: 121.5254,
    timestamp: DateTime.now(),
    accuracy: accuracy,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

void main() {
  late GeolocatorPlatform original;
  late _Geolocator location;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiService.authToken = 'token';
    original = GeolocatorPlatform.instance;
    location = _Geolocator();
    GeolocatorPlatform.instance = location;
  });

  tearDown(() {
    GeolocatorPlatform.instance = original;
    ApiService.authToken = null;
  });

  test('交通資訊模型：解析各區塊、未取得的區塊與沒有即時空位的路段', () {
    final data = TransitNearby.fromJson(_nearby(youbikeDown: true));
    expect(data.cabinet?.latitude, 25.0245);
    expect(data.mrt.items.map((s) => s.name), ['台電大樓', '古亭']);
    expect(data.mrt.items.first.accessibleExit?.exit, '5');
    expect(data.mrt.items.last.accessibleExit, isNull);
    expect(data.youbike.available, isFalse);
    expect(data.parkingLots.items.first.car.available, 3);
    expect(data.parkingLots.items.last.car.available, isNull);
    expect(data.parkingLots.items.first.motorcycle.exists, isFalse);
    expect(data.roadsideCar.first.live?.available, 1);
    expect(data.roadsideCar.last.live?.available, isNull);
    expect(data.roadsideMotorcycle.single.hasParkingArea, isTrue);
    expect(data.roadsideRadiusM, 300);
    expect(data.mrt.items.first.accessibleExit?.facility, AccessFacility.elevator);
    expect(data.bus.items.single.routes.map((r) => r.status), [
      BusStatus.arriving, BusStatus.minutes, BusStatus.minutes, BusStatus.minutes, BusStatus.notDeparted, BusStatus.lastPassed, BusStatus.noService,
    ]);
    expect(data.roadSpeed.items.first.level, TrafficLevel.busy);
    expect(data.taxiStands.items.single.spaces, 2);
  });

  test('捷運出口文字：單一出口與無障礙電梯、坡道', () {
    expect(mrtExitLabel(''), S.singleExit);
    expect(mrtExitLabel('M6'), S.mrtExitP0('M6'));
    MrtExit exit(String no, AccessFacility? facility) => MrtExit(exit: no, accessible: true, facility: facility, distanceM: 0);
    expect(mrtAccessLabel(exit('5', AccessFacility.elevator)), S.accessibleElevatorP0('5'));
    expect(mrtAccessLabel(exit('', AccessFacility.ramp)), S.accessibleRamp);
    expect(mrtAccessLabel(exit('2', null)), S.accessibleExitP0('2'));
    expect(mrtAccessLabel(exit('', null)), isNull);
  });

  group('前往書櫃頁', () {
    testWidgets('顯示捷運出口、YouBike、停車場與路邊停車，起站沿用上次選擇並查詢票價', (tester) async {
      SharedPreferences.setMockInitialValues({'transit.departure_station': '台北車站'});
      final requests = <Uri>[];
      await http.runWithClient(() async {
        await _pump(tester, const CabinetGuideScreen(cabinetId: 3, name: '師大書櫃', address: '臺北市大安區師大路', openHours: '08:00~22:00'));

        expect(find.text('師大書櫃'), findsOneWidget);
        expect(find.text(S.navigate), findsOneWidget);
        expect(find.text('台電大樓站'), findsOneWidget);
        expect(find.text('${S.mrtExitP0('3')}・${S.accessibleElevatorP0('5')}'), findsOneWidget);
        expect(find.text(S.mrtExitP0('3')), findsOneWidget, reason: '古亭站沒有無障礙出口資料時只列最近出口');
        expect(find.text(S.departFromP0('台北車站')), findsOneWidget);
        expect(find.text('${S.fullFareP0(20)}・${S.concessionFareP0(8)}'), findsNWidgets(2));
        expect(find.text('${S.fareToP0('台電大樓站')}・${S.aboutP0Km('4.4')}'), findsOneWidget);

        await tester.scrollUntilVisible(find.text('師大綜合大樓'), 200);
        expect(find.text(S.busArriving), findsOneWidget);
        expect(find.text(S.towardsP0('交通部觀光署')), findsOneWidget);
        expect(find.text(S.busMinutesP0(4)), findsOneWidget);
        expect(find.text(S.busLastPassed), findsNothing, reason: '超過 5 條路線時先收合');
        await tester.ensureVisible(find.text(S.showAllRoutesP0(7)));
        await tester.pump();
        await tester.tap(find.text(S.showAllRoutesP0(7)));
        await _settle(tester);
        expect(find.text(S.busLastPassed), findsOneWidget);
        expect(find.text(S.busNoService), findsOneWidget);
        expect(find.text(S.collapse), findsOneWidget);

        await tester.scrollUntilVisible(find.text('臺灣師範大學(浦城街)'), 200);
        expect(find.text(S.rentReturnP0P1(19, 0)), findsOneWidget);
        expect(find.text(S.stationSuspended), findsOneWidget);

        await tester.scrollUntilVisible(find.text('羅斯福路（和平東路-辛亥路）'), 200);
        expect(find.text(S.drivingAndTaxi), findsOneWidget);
        expect(find.text('${S.speedP0(36)}・${S.trafficBusy}'), findsOneWidget);
        expect(find.text('${S.speedP0(56)}・${S.trafficSmooth}'), findsOneWidget);

        await tester.scrollUntilVisible(find.text('Times師大夜市'), 200);
        expect(find.text(S.carP0(S.vacantOfTotalP0P1(3, 18))), findsOneWidget);
        expect(find.text(S.carP0(S.totalSpacesP0(5))), findsOneWidget);

        await tester.ensureVisible(find.text(S.roadsideParking));
        await tester.pump();
        await tester.tap(find.text(S.roadsideParking));
        await _settle(tester);
        await tester.scrollUntilVisible(find.text('師大路A(機車)'), 200);
        expect(find.text('師大路C'), findsOneWidget);
        expect(find.text([S.spacesNearbyP0(13), S.accessibleSpacesP0(4), S.liveVacancyP0P1(1, 3)].join('・')), findsOneWidget);
        expect(find.text('${S.chargeHoursP0P1('07:00', '20:00')}・40元'), findsOneWidget);
        expect(find.text([S.spacesNearbyP0(4), S.noLiveVacancy].join('・')), findsOneWidget);
        expect(find.text([S.spacesNearbyP0(168), S.motorcycleAreaNearby].join('・')), findsOneWidget);
        await tester.ensureVisible(find.text(S.taxiStands));
        await tester.pump();
        await tester.tap(find.text(S.taxiStands));
        await _settle(tester);
        await tester.scrollUntilVisible(find.text('經濟部工業局'), 200);
        expect(find.text('${S.taxiSpacesP0(2)}・${S.taxiHoursP0('0~24')}'), findsOneWidget);

        await tester.scrollUntilVisible(find.text(S.transitAttribution), 200);
        expect(find.text(S.transitAttribution), findsOneWidget);
      }, () => MockClient((request) async {
        requests.add(request.url);
        if (request.url.path == '/api/cabinets/3/nearby') return _ok(_nearby());
        if (request.url.path == '/api/cabinets/mrt-fares') {
          return _ok({
            'fares': [
              {'from': '台北車站', 'to': '台電大樓', 'fare': 20, 'concession_fare': 8, 'distance_km': 4.38},
              {'from': '台北車站', 'to': '古亭', 'fare': 20, 'concession_fare': 8, 'distance_km': 3.5},
            ],
          });
        }
        return _fail(404, 'not found');
      }));

      final fare = requests.singleWhere((u) => u.path == '/api/cabinets/mrt-fares');
      expect(fare.queryParameters, {'from': '台北車站', 'to': '台電大樓,古亭'});
      expect(requests.where((u) => u.path == '/api/cabinets/mrt-stations'), isEmpty, reason: '已有上次選擇的起站，不必再取車站清單');
    });

    testWidgets('沒有選過起站時，在手機上以定位找出最近的車站，不把位置送到伺服器', (tester) async {
      final requests = <Uri>[];
      await http.runWithClient(() async {
        await _pump(tester, const CabinetGuideScreen(cabinetId: 3, name: '師大書櫃'));
        expect(find.text(S.departFromP0('台北車站')), findsOneWidget);
      }, () => MockClient((request) async {
        requests.add(request.url);
        if (request.url.path == '/api/cabinets/3/nearby') return _ok(_nearby());
        if (request.url.path == '/api/cabinets/mrt-stations') return _ok({'stations': _stations});
        if (request.url.path == '/api/cabinets/mrt-fares') return _ok({'fares': <Object>[]});
        return _fail(404, 'not found');
      }));

      expect(requests.firstWhere((u) => u.path == '/api/cabinets/mrt-fares').queryParameters['from'], '台北車站');
      for (final uri in requests) {
        expect(uri.queryParameters.keys, isNot(contains('lat')));
        expect(uri.toString(), isNot(contains('25.0421')));
      }
    });

    testWidgets('單一區塊無法取得或範圍內沒有資料時顯示說明；整頁載入失敗可重試', (tester) async {
      var fail = true;
      await http.runWithClient(() async {
        await _pump(tester, const CabinetGuideScreen(cabinetId: 3, name: '師大書櫃'));
        expect(find.text('系統發生錯誤'), findsOneWidget);

        fail = false;
        await tester.tap(find.text(S.retry));
        await _settle(tester);
        await tester.scrollUntilVisible(find.text(S.transitDataUnavailable).first, 200);
        expect(find.text(S.transitDataUnavailable), findsNWidgets(2), reason: '公車與 YouBike 各自顯示無法取得');
        await tester.scrollUntilVisible(find.text(S.noParkingLotsWithinP0(S.p0M(800))), 200);
        expect(find.text(S.noParkingLotsWithinP0(S.p0M(800))), findsOneWidget);
      }, () => MockClient((request) async {
        if (request.url.path == '/api/cabinets/3/nearby') {
          return fail ? _fail(500, '系統發生錯誤') : _ok(_nearby(youbikeDown: true, noLots: true, busDown: true));
        }
        if (request.url.path == '/api/cabinets/mrt-stations') return _ok({'stations': _stations});
        return _ok({'fares': <Object>[]});
      }));
    });
  });

  group('新增書櫃：取得目前座標', () {
    Cabinet cabinet() => Cabinet(
      cabinetId: 3,
      cabinetName: '師大書櫃',
      address: '臺北市大安區師大路',
      latitude: 25.0245,
      longitude: 121.5288,
      totalSlots: 4,
      availableSlots: 4,
      isActive: true,
    );

    Future<List<Uri>> run(WidgetTester tester, Future<void> Function() body) async {
      final requests = <Uri>[];
      await http.runWithClient(body, () => MockClient((request) async {
        requests.add(request.url);
        if (request.url.path == '/api/admin/cabinets/nearby-preview') return _ok(_nearby());
        return _fail(404, 'not found');
      }));
      return requests;
    }

    testWidgets('編輯時預覽座標附近的交通資訊；使用目前位置填入座標與精確度並重新預覽', (tester) async {
      final requests = await run(tester, () async {
        await _pump(tester, AdminCabinetEditScreen(cabinet: cabinet()));
        expect(find.text(S.nearestMrtP0P1('台電大樓站', transitDistance(382))), findsOneWidget);
        expect(find.text(S.roadsideNearP0('師大路C、師大路A(機車)、龍泉街5巷')), findsOneWidget);
        expect(find.text([S.busStopsP0(1), S.youbikeStationsP0(2), S.parkingLotsP0(2)].join('・')), findsOneWidget);

        await tester.tap(find.text(S.useCurrentLocation));
        await _settle(tester, 15);
        expect(find.widgetWithText(TextField, '25.0421000'), findsOneWidget);
        expect(find.widgetWithText(TextField, '121.5254000'), findsOneWidget);
        expect(find.text(S.locationAccuracyP0(12)), findsOneWidget);
        expect(location.purposeKey, isNull, reason: '已是精確位置時不必申請暫時完整精確度');

        await tester.enterText(find.widgetWithText(TextField, '25.0421000'), '25.0421');
        await _settle(tester, 10);
        expect(find.text(S.locationAccuracyP0(12)), findsNothing, reason: '手動改過座標後精確度不再適用');
      });

      final previews = requests.where((u) => u.path == '/api/admin/cabinets/nearby-preview').toList();
      expect(previews.first.queryParameters, {'lat': '25.0245000', 'lng': '121.5288000'});
      expect(previews.map((u) => u.queryParameters['lat']), contains('25.0421000'));
    });

    testWidgets('定位誤差超過 50 公尺時提示重新定位；只允許大約位置時說明須開啟精確位置', (tester) async {
      location.accuracy = 80;
      await run(tester, () async {
        await _pump(tester, const AdminCabinetEditScreen());
        expect(find.text(S.nearbyPreviewHint), findsOneWidget);

        await tester.tap(find.text(S.useCurrentLocation));
        await _settle(tester, 15);
        expect(find.text('${S.locationAccuracyP0(80)}，${S.locationAccuracyLow}'), findsOneWidget);

        location.accuracyStatus = LocationAccuracyStatus.reduced;
        await tester.tap(find.text(S.useCurrentLocation));
        await _settle(tester, 15);
        expect(location.purposeKey, LocationService.setupPurposeKey);
        expect(find.text(S.preciseLocationRequiredCabinetSetup), findsOneWidget);
      });
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });
}
