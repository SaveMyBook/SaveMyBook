// 第 12 章使用手冊截圖的共用拍攝流程：淺色模式、iPhone 393×852（輸出 1179×2556，與原實機截圖相同），
// 資料由 manual_api.dart 提供，圖片由本機的真實照片供應，iOS 系統畫面（鍵盤、彈窗、分享面板等）以 manual_system_ui.dart 模擬。
// 狀態列與 Home 指示條由 um_statusbar.py 於輸出後補上。

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:http/http.dart' as http;
// ignore: depend_on_referenced_packages
import 'package:local_auth_platform_interface/local_auth_platform_interface.dart';
import 'package:marquee/marquee.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:savemybook_app/i18n/app_localizations.dart';
import 'package:savemybook_app/i18n/strings.dart';
import 'package:savemybook_app/models/user.dart';
import 'package:savemybook_app/services/api_service.dart';
import 'package:savemybook_app/services/biometric_service.dart';
import 'package:savemybook_app/services/locale_provider.dart';
import 'package:savemybook_app/services/passkey_service.dart';
import 'package:savemybook_app/services/recently_viewed.dart';
import 'package:savemybook_app/services/theme_provider.dart';
import 'package:savemybook_app/utils/app_theme.dart';

import '../web_shots/covers.dart' show loadAppFonts;
import 'manual_api.dart';

final _env = Platform.environment;

/// 真實照片（由正式站下載並縮至 900px 的 JPEG），檔名為路徑去掉開頭斜線、斜線換底線。
final manualDataDir = _env['MANUAL_DATA'] ??
    '/private/tmp/claude-501/-Users-xukaijun-Desktop-SaveMyBook-savemybook-app/f52b6347-17b0-4b79-95e7-263531604b33/scratchpad/manual_data';

/// 輸出根目錄，底下為「<節號>. <節名>」資料夾。
final manualOutDir = _env['MANUAL_OUT'] ?? '${Directory.current.path}/../documents/使用手冊截圖_淺色';

const logicalSize = Size(393, 852);
const pixelRatio = 3.0;
const topInset = 59.0;
const bottomInset = 34.0;

/// iOS 鍵盤（含候選字列）在 393 寬 iPhone 上的高度。
const keyboardHeight = 336.0;

final navigatorKey = GlobalKey<NavigatorState>();

/// 疊在 App 最上層的模擬畫面（系統彈窗、分享面板、相機畫面、鍵盤等）。
final systemOverlay = ValueNotifier<List<Widget>>(const []);

typedef Snap = Future<void> Function(String file);

class ManualApp extends StatelessWidget {
  final Widget home;

  const ManualApp({super.key, required this.home});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      locale: const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant', countryCode: 'TW'),
      supportedLocales: LocaleProvider.supported,
      theme: AppTheme.build(Brightness.light),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        S = AppLocalizations.of(context);
        return Stack(
          children: [
            child ?? const SizedBox.shrink(),
            // 疊加層不在頁面的 Material 底下，沒有這層時文字會繼承 Flutter 的錯誤樣式（w900 粗體）
            Positioned.fill(
              child: Material(
                type: MaterialType.transparency,
                textStyle: const TextStyle(fontFamily: 'NotoSansTC', fontWeight: FontWeight.w400, color: Colors.black, fontSize: 15),
                child: ValueListenableBuilder<List<Widget>>(
                  valueListenable: systemOverlay,
                  builder: (context, layers, _) => Stack(children: layers),
                ),
              ),
            ),
          ],
        );
      },
      // 畫面在 App 內多半是推入的頁面；直接當根頁面時 AppHeader 會因沒有上一頁而隱藏返回鍵
      onGenerateInitialRoutes: (_) => [
        PageRouteBuilder<void>(pageBuilder: (_, _, _) => const SizedBox.shrink()),
        MaterialPageRoute<void>(builder: (_) => home),
      ],
      onGenerateRoute: (_) => null,
    );
  }
}

// App 字型 Noto Sans TC 缺部分簡體與異體字（例如書名中的「乐」「书」），主題的後備字型為 PingFang SC；
// 測試環境沒有系統字型，從本機 macOS 的 PingFang.ttc 取出 SC 字面載入，否則會畫成方框。
Future<void> _loadPingFangFallback() async {
  const path = '/System/Library/AssetsV2/com_apple_MobileAsset_Font8/86ba2c91f017a3749571a82f2c6d890ac7ffb2fb.asset/AssetData/PingFang.ttc';
  final file = File(path);
  if (!file.existsSync()) return;
  final ttc = file.readAsBytesSync();
  final loader = FontLoader('PingFang SC');
  // 第 3、7、11 個字面為 PingFang SC 的 Regular、Medium、Semibold
  for (final index in [3, 7, 11]) {
    loader.addFont(Future.value(ByteData.sublistView(_ttcFontFace(ttc, index))));
  }
  await loader.load();
}

Uint8List _ttcFontFace(Uint8List ttc, int index) {
  final src = ByteData.sublistView(ttc);
  final offset = src.getUint32(12 + 4 * index);
  final count = src.getUint16(offset + 4);
  final header = 12 + 16 * count;
  final tables = [
    for (var i = 0; i < count; i++)
      (record: offset + 12 + 16 * i, start: src.getUint32(offset + 20 + 16 * i), length: src.getUint32(offset + 24 + 16 * i)),
  ];
  final size = tables.fold(header, (sum, t) => sum + ((t.length + 3) & ~3));
  final out = Uint8List(size);
  final dst = ByteData.sublistView(out);
  out.setRange(0, 12, ttc, offset);
  var pos = header;
  for (final (i, t) in tables.indexed) {
    out.setRange(12 + 16 * i, 20 + 16 * i, ttc, t.record);
    dst.setUint32(20 + 16 * i, pos);
    dst.setUint32(24 + 16 * i, t.length);
    out.setRange(pos, pos + t.length, ttc, t.start);
    pos += (t.length + 3) & ~3;
  }
  return out;
}

/// 每節的測試在 setUpAll 呼叫一次。
Future<void> setUpManual() async {
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({});
  await loadAppFonts();
  await _loadPingFangFallback();
  PasskeyService.client = _FakePasskeyClient();
  PasskeyService.resetCache();
  LocalAuthPlatform.instance = _FakeBiometrics();
  GeolocatorPlatform.instance = _FakeGeolocator();
  themeProvider = await ThemeProvider.init();
  localeProvider = await LocaleProvider.init();
}

/// 拍一個畫面：[home] 為起始頁（[root] 為 true 時當作 App 的第一頁，沒有上一頁），[act] 內操作後呼叫 snap 輸出。
/// [folder] 為「<節號>. <節名>」，snap 的參數為不含副檔名的檔名（例如「表12-2-1 首頁書籍列表」）。
Future<void> shoot(
  WidgetTester tester, {
  required String folder,
  required Widget Function() home,
  required Future<void> Function(WidgetTester tester, Snap snap) act,
  Map<String, Object> prefs = const {},
  Map<String, String> secureStorage = const {},
  bool loggedIn = true,
  User? me,
  void Function()? routes,
}) async {
  final errors = <String>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (details) => errors.add(details.exceptionAsString().split('\n').first);

  tester.view
    ..physicalSize = logicalSize * pixelRatio
    ..devicePixelRatio = pixelRatio
    ..padding = const FakeViewPadding(top: topInset * pixelRatio, bottom: bottomInset * pixelRatio)
    ..viewPadding = const FakeViewPadding(top: topInset * pixelRatio, bottom: bottomInset * pixelRatio);
  addTearDown(tester.view.reset);

  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({'biometric_login_enabled': true, ...prefs});
  await RecentlyViewed.clear();
  await BiometricService.load();
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (call) async => secureStorage[(call.arguments as Map?)?['key']],
  );
  ApiService.authToken = loggedIn ? 'manual-token' : null;
  ApiService.currentUser = loggedIn ? (me ?? User.fromJson(userJson(meId))) : null;
  systemOverlay.value = const [];
  ManualApi.reset();
  routes?.call();
  debugNetworkImageHttpClientProvider = () => _PhotoClient();
  // flutter test 預設把陰影畫成硬邊（導覽列、按鈕下方會出現灰色粗框），截圖時改畫真實陰影
  debugDisableShadows = false;

  Future<void> snap(String file) async {
    await settle(tester, const Duration(milliseconds: 600));
    await waitForImages(tester);
    await settle(tester, const Duration(milliseconds: 300));
    await capture(tester, folder, file);
  }

  // act 內出錯時也要還原，否則測試框架檢查到未還原的除錯設定會卡住直到逾時
  try {
    await http.runWithClient(() async {
      await tester.pumpWidget(ManualApp(home: home()));
      await settleReal(tester, const Duration(seconds: 2));
      await act(tester, snap);
      systemOverlay.value = const [];
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    }, ManualApi.client);
  } finally {
    systemOverlay.value = const [];
    debugNetworkImageHttpClientProvider = null;
    debugDisableShadows = true;
    hideKeyboard(tester);
    FlutterError.onError = previous;
  }
  expect(errors, isEmpty, reason: '畫面有例外或版面溢出');
}

/// 以假時間推進動畫。
Future<void> settle(WidgetTester tester, Duration duration) async {
  final steps = duration.inMilliseconds ~/ 100;
  for (var i = 0; i < steps; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// 同時讓真實非同步工作（API 回應、圖片解碼）完成。
Future<void> settleReal(WidgetTester tester, Duration duration) async {
  final steps = duration.inMilliseconds ~/ 100;
  for (var i = 0; i < steps; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> waitForImages(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate().toList()) {
      final provider = (element.widget as Image).image;
      try {
        await precacheImage(provider, element, onError: (_, _) {});
      } catch (_) {}
    }
  });
  await tester.pump();
}

Future<void> scrollBy(WidgetTester tester, double pixels, {Finder? scrollable}) async {
  final state = tester.state<ScrollableState>(scrollable ?? find.byType(Scrollable).first);
  state.position.jumpTo(state.position.pixels + pixels);
  await settleReal(tester, const Duration(milliseconds: 800));
}

Future<void> tapAndSettle(WidgetTester tester, Finder finder, {Duration duration = const Duration(seconds: 1)}) async {
  await tester.tap(finder);
  await settleReal(tester, duration);
}

/// 顯示模擬的 iOS 注音鍵盤：App 依鍵盤高度縮減可用空間，鍵盤畫在最上層。
void showKeyboard(WidgetTester tester, {List<String> candidates = const []}) {
  tester.view
    ..viewInsets = const FakeViewPadding(bottom: keyboardHeight * pixelRatio)
    ..padding = const FakeViewPadding(top: topInset * pixelRatio);
  systemOverlay.value = [
    ...systemOverlay.value,
    Positioned(left: 0, right: 0, bottom: 0, height: keyboardHeight, child: IosKeyboard(candidates: candidates)),
  ];
}

void hideKeyboard(WidgetTester tester) {
  tester.view
    ..viewInsets = FakeViewPadding.zero
    ..padding = const FakeViewPadding(top: topInset * pixelRatio, bottom: bottomInset * pixelRatio);
  systemOverlay.value = [for (final w in systemOverlay.value) if (w is! Positioned || w.child is! IosKeyboard) w];
}

// flutter test 固定使用測試字型，未指定字型家族的文字會畫成方框；截圖前改以 App 字型重新排版。
void _applyAppFontToUnstyledText(WidgetTester tester) {
  void visit(RenderObject node) {
    if (node is RenderParagraph) {
      final span = node.text;
      if (span is TextSpan && span.style?.fontFamily == null) {
        node.text = TextSpan(
          text: span.text,
          children: span.children,
          style: (span.style ?? const TextStyle()).copyWith(fontFamily: 'NotoSansTC'),
          recognizer: span.recognizer,
          semanticsLabel: span.semanticsLabel,
          locale: span.locale,
          spellOut: span.spellOut,
        );
      }
    }
    node.visitChildren(visit);
  }

  for (final view in tester.binding.renderViews) {
    visit(view);
  }
  tester.binding.rootPipelineOwner
    ..flushLayout()
    ..flushCompositingBits()
    ..flushPaint();
}

Future<void> capture(WidgetTester tester, String folder, String file) async {
  // 過長書名以跑馬燈捲動，截圖時固定在開頭；jumpTo 會中止捲動動畫，補一個不推進時間的畫格讓畫面重建
  final marquees = find.descendant(of: find.byType(Marquee), matching: find.byType(Scrollable)).evaluate().toList();
  for (final element in marquees) {
    (element as StatefulElement).state is ScrollableState ? (element.state as ScrollableState).position.jumpTo(0) : null;
  }
  if (marquees.isNotEmpty) await tester.pump();
  _applyAppFontToUnstyledText(tester);
  final view = tester.binding.renderViews.first;
  await tester.runAsync(() async {
    final layer = view.debugLayer! as OffsetLayer;
    final image = await layer.toImage(view.paintBounds);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final dir = Directory('$manualOutDir/$folder')..createSync(recursive: true);
    File('${dir.path}/$file.PNG').writeAsBytesSync(data!.buffer.asUint8List());
  });
}

/// 本機真實照片的路徑；找不到時為 null。
File? photoFile(String urlOrPath) {
  final path = Uri.parse(urlOrPath).path.replaceFirst(RegExp(r'^/'), '');
  final base = path.replaceAll('/', '_');
  final stem = base.contains('.') ? base.substring(0, base.lastIndexOf('.')) : base;
  final file = File('$manualDataDir/img/$stem.jpg');
  return file.existsSync() ? file : null;
}

class _PhotoClient implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _PhotoRequest(url);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PhotoRequest implements HttpClientRequest {
  final Uri url;

  _PhotoRequest(this.url);

  @override
  final HttpHeaders headers = _NoHeaders();

  @override
  Future<HttpClientResponse> close() async {
    final file = photoFile(url.toString());
    return _PhotoResponse(file == null ? null : file.readAsBytesSync());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoHeaders implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PhotoResponse extends Stream<List<int>> implements HttpClientResponse {
  final Uint8List? bytes;

  _PhotoResponse(this.bytes);

  @override
  int get statusCode => bytes == null ? 404 : 200;

  @override
  int get contentLength => bytes?.length ?? 0;

  @override
  HttpClientResponseCompressionState get compressionState => HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      Stream<List<int>>.fromIterable([if (bytes != null) bytes!])
          .listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePasskeyClient implements PasskeyClient {
  @override
  Future<bool> isSupported() async => true;

  @override
  Future<Map<String, dynamic>> create(Map<String, dynamic> options) async => throw const PasskeyClientException.cancelled();

  @override
  Future<Map<String, dynamic>> get(Map<String, dynamic> options, {bool immediate = true}) async =>
      throw const PasskeyClientException.cancelled();

  @override
  Future<void> forget({required String rpId, required String credentialId}) async {}
}

class _FakeBiometrics extends LocalAuthPlatform {
  @override
  Future<bool> isDeviceSupported() async => true;

  @override
  Future<bool> deviceSupportsBiometrics() async => true;

  @override
  Future<List<BiometricType>> getEnrolledBiometrics() async => [BiometricType.face];
}

class _FakeGeolocator extends GeolocatorPlatform {
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

  // 國立臺北商業大學附近
  static final _position = Position(
    latitude: 25.0425,
    longitude: 121.5254,
    timestamp: DateTime.now(),
    accuracy: 8,
    altitude: 12,
    altitudeAccuracy: 3,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

/// 模擬的 iOS 淺色注音鍵盤（含候選字列）。尺寸取自 iPhone 實機截圖（393 寬、鍵盤高 336pt）。
class IosKeyboard extends StatelessWidget {
  final List<String> candidates;

  const IosKeyboard({super.key, this.candidates = const []});

  static const _rows = [
    (3.33, ['ㄅ', 'ㄉ', 'ˇ', 'ˋ', 'ㄓ', 'ˊ', '˙', 'ㄚ', 'ㄞ', 'ㄢ', 'ㄦ']),
    (15.0, ['ㄆ', 'ㄊ', 'ㄍ', 'ㄐ', 'ㄔ', 'ㄗ', 'ㄧ', 'ㄛ', 'ㄟ', 'ㄣ']),
    (26.0, ['ㄇ', 'ㄋ', 'ㄎ', 'ㄑ', 'ㄕ', 'ㄘ', 'ㄨ', 'ㄜ', 'ㄠ', 'ㄤ']),
    (3.33, ['ㄈ', 'ㄌ', 'ㄏ', 'ㄒ', 'ㄖ', 'ㄙ', 'ㄩ', 'ㄝ', 'ㄡ', 'ㄥ', '⌫']),
  ];
  static const _rowTops = [52.3, 95.0, 137.3, 179.0];
  static const _keyWidth = 29.33;
  static const _keyGap = 6.33;
  static const _keyHeight = 33.5;

  static const _background = Color(0xFFD0D3D9);
  static const _special = Color(0xFFACB1BB);
  static const _shadow = Color(0xFF898A8D);

  @override
  Widget build(BuildContext context) {
    const text = TextStyle(fontFamily: 'NotoSansTC', color: Colors.black, decoration: TextDecoration.none);
    Widget key(double left, double top, double width, double height, {String? label, IconData? icon, bool special = false, double size = 22}) =>
        Positioned(
          left: left,
          top: top,
          width: width,
          height: height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: special ? _special : Colors.white,
              borderRadius: BorderRadius.circular(5),
              boxShadow: const [BoxShadow(color: _shadow, offset: Offset(0, 1))],
            ),
            child: Center(
              child: icon != null
                  ? Icon(icon, size: size, color: Colors.black)
                  : Text(label ?? '', style: text.copyWith(fontSize: size, height: 1.1)),
            ),
          ),
        );
    return ColoredBox(
      color: _background,
      child: Stack(
        children: [
          // 候選字列
          Positioned(
            left: 12,
            top: 0,
            height: 49,
            right: 54,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: SizedBox(
                height: 49,
                child: Row(
                  children: [
                    for (final c in candidates) ...[
                      Text(c, style: text.copyWith(fontSize: 19)),
                      const SizedBox(width: 21.5),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const Positioned(left: 347.7, top: 8, width: 1, height: 33, child: ColoredBox(color: Color(0x33000000))),
          const Positioned(left: 357, top: 9, child: Icon(Icons.keyboard_arrow_down_rounded, size: 32, color: Colors.black)),
          for (final (r, (left, keys)) in _rows.indexed)
            for (final (i, k) in keys.indexed)
              k == '⌫'
                  ? key(left + i * (_keyWidth + _keyGap), _rowTops[r], _keyWidth, _keyHeight,
                      icon: Icons.backspace_outlined, special: true, size: 20)
                  : key(left + i * (_keyWidth + _keyGap), _rowTops[r], _keyWidth, _keyHeight, label: k),
          key(3.33, 221.3, 42.3, 35.3, label: '123', special: true, size: 17),
          key(51.7, 221.3, 43.3, 35.3, icon: Icons.emoji_emotions, special: true, size: 25),
          key(100, 221.3, 192, 35.3, label: '空格', size: 17),
          key(297.7, 221.3, 92.3, 35.3, label: '換行', special: true, size: 17),
          const Positioned(left: 27, top: 281, child: Icon(Icons.language, size: 29, color: Color(0xFF1C1C1E))),
          const Positioned(left: 336, top: 281, child: Icon(Icons.mic_none_rounded, size: 30, color: Color(0xFF1C1C1E))),
        ],
      ),
    );
  }
}

/// 模擬的 iOS 26 系統提示框（淺色）：大圓角、文字靠左、膠囊按鈕；[actions] 最後一個為藍色建議動作。
class IosAlert extends StatelessWidget {
  final String title;
  final String? message;
  final List<String> actions;

  const IosAlert({super.key, required this.title, this.message, this.actions = const ['好']});

  @override
  Widget build(BuildContext context) {
    const text = TextStyle(fontFamily: 'NotoSansTC', decoration: TextDecoration.none, color: Colors.black);
    Widget button(String label, bool primary) => Container(
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: primary ? const Color(0xFF0A84FF) : const Color(0xFFE9E9EB), borderRadius: BorderRadius.circular(24)),
      child: Text(label, style: text.copyWith(fontSize: 17, fontWeight: FontWeight.w600, color: primary ? Colors.white : Colors.black)),
    );
    return ColoredBox(
      color: const Color(0x33000000),
      child: Center(
        child: Container(
          width: 300,
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F7F8),
            borderRadius: BorderRadius.circular(34),
            boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 40, offset: Offset(0, 12))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: text.copyWith(fontSize: 18, fontWeight: FontWeight.w700, height: 1.3)),
              if (message != null) ...[
                const SizedBox(height: 6),
                Text(message!, style: text.copyWith(fontSize: 15, height: 1.4, color: const Color(0xFF3C3C43))),
              ],
              const SizedBox(height: 20),
              if (actions.length == 2)
                Row(
                  children: [
                    Expanded(child: button(actions[0], false)),
                    const SizedBox(width: 10),
                    Expanded(child: button(actions[1], true)),
                  ],
                )
              else
                for (final (i, a) in actions.indexed) ...[
                  if (i > 0) const SizedBox(height: 10),
                  button(a, i == actions.length - 1),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 模擬的 iOS 26 通行密鑰面板（儲存或登入），比照實機：右上關閉鈕、Face ID 與 App 圖示、粗體標題、藍色與白色膠囊按鈕。
/// iPhone 的系統語言為英文，文字比照實機截圖使用英文。
class IosPasskeySheet extends StatelessWidget {
  final String title;
  final String message;
  final String primary;
  final String secondary;

  const IosPasskeySheet({super.key, required this.title, required this.message, required this.primary, required this.secondary});

  @override
  Widget build(BuildContext context) {
    const text = TextStyle(fontFamily: 'NotoSansTC', decoration: TextDecoration.none, color: Colors.black);
    return ColoredBox(
      color: const Color(0x1F000000),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          margin: const EdgeInsets.fromLTRB(9, 0, 9, 9),
          padding: const EdgeInsets.fromLTRB(30, 16, 16, 26),
          decoration: BoxDecoration(
            color: const Color(0xFFEDEDF0),
            borderRadius: BorderRadius.circular(48),
            boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 30, offset: Offset(0, -2))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Color(0x1A000000), blurRadius: 6)],
                  ),
                  child: const Icon(Icons.close_rounded, size: 26, color: Colors.black),
                ),
              ),
              const SizedBox(
                width: 80,
                height: 76,
                child: Stack(
                  children: [
                    Positioned(left: 0, top: 0, width: 54, height: 54, child: CustomPaint(painter: _FaceIdGlyph(color: Color(0xFF0A84FF)))),
                    Positioned(left: 34, top: 34, width: 40, height: 40, child: _AppIconBadge()),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(title, style: text.copyWith(fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(right: 14),
                // 中文字型會把彎引號排成全形，系統面板的英文改用直引號
                child: Text(message.replaceAll(RegExp('[“”]'), '"'), style: text.copyWith(fontSize: 17, height: 1.35)),
              ),
              const SizedBox(height: 26),
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Column(
                  children: [
                    Container(
                      height: 50,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: const Color(0xFF3A8DFF), borderRadius: BorderRadius.circular(25)),
                      child: Text(primary, style: text.copyWith(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white)),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 50,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25)),
                      child: Text(secondary, style: text.copyWith(fontSize: 17, color: const Color(0xFF0A84FF))),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppIconBadge extends StatelessWidget {
  const _AppIconBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF6E8696),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: const Icon(Icons.menu_book_rounded, size: 22, color: Colors.white),
    );
  }
}

/// 模擬的 Face ID 驗證提示（畫面中央的方框）。
class IosFaceIdHud extends StatelessWidget {
  final String label;

  const IosFaceIdHud({super.key, this.label = 'Face ID'});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 160,
        height: 160,
        decoration: BoxDecoration(color: const Color(0xF2E9E9EB), borderRadius: BorderRadius.circular(26)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 64, height: 64, child: CustomPaint(painter: _FaceIdGlyph())),
            const SizedBox(height: 14),
            Text(
              label,
              style: const TextStyle(fontFamily: 'NotoSansTC', fontSize: 15, color: Colors.black, decoration: TextDecoration.none),
            ),
          ],
        ),
      ),
    );
  }
}

class _FaceIdGlyph extends CustomPainter {
  final Color color;

  const _FaceIdGlyph({this.color = const Color(0xFF1C1C1E)});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;
    final s = size.width;
    final c = s * 0.28;
    for (final (dx, dy) in [(0.0, 0.0), (1.0, 0.0), (0.0, 1.0), (1.0, 1.0)]) {
      final x = dx * s;
      final y = dy * s;
      final sx = dx == 0 ? 1 : -1;
      final sy = dy == 0 ? 1 : -1;
      final path = Path()
        ..moveTo(x, y + sy * c)
        ..lineTo(x, y + sy * 8)
        ..quadraticBezierTo(x, y, x + sx * 8, y)
        ..lineTo(x + sx * c, y);
      canvas.drawPath(path, p);
    }
    canvas.drawLine(Offset(s * 0.34, s * 0.36), Offset(s * 0.34, s * 0.44), p);
    canvas.drawLine(Offset(s * 0.66, s * 0.36), Offset(s * 0.66, s * 0.44), p);
    final nose = Path()
      ..moveTo(s * 0.5, s * 0.36)
      ..lineTo(s * 0.5, s * 0.56)
      ..lineTo(s * 0.45, s * 0.56);
    canvas.drawPath(nose, p);
    canvas.drawArc(Rect.fromCenter(center: Offset(s * 0.5, s * 0.6), width: s * 0.36, height: s * 0.2), 0.3, 2.54, false, p);
  }

  @override
  bool shouldRepaint(_FaceIdGlyph oldDelegate) => false;
}

/// 模擬的 iOS 底部系統面板（通行密鑰、Apple 登入、分享等共用外框）。
class IosSheet extends StatelessWidget {
  final Widget child;
  final double? height;

  const IosSheet({super.key, required this.child, this.height});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0x33000000),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: height,
          margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          decoration: BoxDecoration(color: const Color(0xFFF2F2F7), borderRadius: BorderRadius.circular(36)),
          clipBehavior: Clip.antiAlias,
          child: DefaultTextStyle(
            style: const TextStyle(fontFamily: 'NotoSansTC', color: Colors.black, decoration: TextDecoration.none, fontSize: 15),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 模擬的 iOS 分享面板：上方為分享內容預覽，下方為 App 列與動作清單。
class IosShareSheet extends StatelessWidget {
  final String title;
  final String subtitle;
  final File? thumbnail;

  const IosShareSheet({super.key, required this.title, required this.subtitle, this.thumbnail});

  @override
  Widget build(BuildContext context) {
    const apps = [
      ('AirDrop', Color(0xFF1E90FF), Icons.wifi_tethering),
      ('訊息', Color(0xFF34C759), Icons.chat_bubble),
      ('郵件', Color(0xFF1A8CFF), Icons.mail),
      ('LINE', Color(0xFF06C755), Icons.chat),
      ('備忘錄', Color(0xFFFFCC00), Icons.edit_note),
    ];
    const actions = [('拷貝', Icons.copy_rounded), ('加入閱讀列表', Icons.menu_book_outlined), ('加入書籤', Icons.bookmark_border)];
    return IosSheet(
      height: 520,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: thumbnail == null ? const ColoredBox(color: Color(0xFFD1D1D6)) : Image.file(thumbnail!, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E93))),
                    ],
                  ),
                ),
                Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(color: Color(0xFFE3E3E8), shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF8E8E93)),
                ),
              ],
            ),
          ),
          Container(height: 0.5, color: const Color(0x4D3C3C43)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final (name, color, icon) in apps)
                  Column(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
                        child: Icon(icon, color: Colors.white, size: 30),
                      ),
                      const SizedBox(height: 6),
                      Text(name, style: const TextStyle(fontSize: 11)),
                    ],
                  ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                for (final (i, (label, icon)) in actions.indexed) ...[
                  if (i > 0) Container(height: 0.5, margin: const EdgeInsets.only(left: 16), color: const Color(0x4D3C3C43)),
                  SizedBox(
                    height: 48,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(children: [Text(label, style: const TextStyle(fontSize: 17)), const Spacer(), Icon(icon, size: 22)]),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 讀取真實照片為 ui.Image（相機畫面等需要直接繪圖時使用）。
Future<ui.Image?> loadPhoto(WidgetTester tester, String urlOrPath) async {
  final file = photoFile(urlOrPath);
  if (file == null) return null;
  return tester.runAsync(() async {
    final codec = await ui.instantiateImageCodec(file.readAsBytesSync());
    return (await codec.getNextFrame()).image;
  });
}

/// 方便除錯：輸出本張截圖期間 App 呼叫過的 API。
String apiLog() => const JsonEncoder.withIndent('  ').convert([
  for (final r in ManualApi.log) '${r.method} ${r.path}${r.query.isEmpty ? '' : '?${Uri(queryParameters: r.query).query}'}',
]);
