import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
// ignore: depend_on_referenced_packages
import 'package:local_auth_platform_interface/local_auth_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:savemybook_app/features/account/account_privacy_screen.dart';
import 'package:savemybook_app/features/account/tablet_list.dart';
import 'package:savemybook_app/features/admin/admin_home_screen.dart';
import 'package:savemybook_app/features/auth/auth_wide_card.dart';
import 'package:savemybook_app/features/orders/order_history_screen.dart';
import 'package:savemybook_app/features/account/ai_consent_sheet.dart';
import 'package:savemybook_app/features/account/app_permissions_screen.dart';
import 'package:savemybook_app/features/account/change_password_screen.dart';
import 'package:savemybook_app/features/account/edit_profile_screen.dart';
import 'package:savemybook_app/features/account/legal_doc_screen.dart';
import 'package:savemybook_app/features/account/member_level_screen.dart';
import 'package:savemybook_app/features/account/profile_screen.dart';
import 'package:savemybook_app/features/account/settings_screen.dart';
import 'package:savemybook_app/features/account/share_profile_screen.dart';
import 'package:savemybook_app/features/auth/legal_consent_screen.dart';
import 'package:savemybook_app/features/auth/login_screen.dart';
import 'package:savemybook_app/features/auth/phone_sign_in_screen.dart';
import 'package:savemybook_app/features/auth/register_screen.dart';
import 'package:savemybook_app/features/auth/social_profile_screen.dart';
import 'package:savemybook_app/features/security/login_devices_screen.dart';
import 'package:savemybook_app/features/security/payment_pin_screen.dart';
import 'package:savemybook_app/features/security/security_center_screen.dart';
import 'package:savemybook_app/features/security/set_password_screen.dart';
import 'package:savemybook_app/i18n/app_localizations.dart';
import 'package:savemybook_app/i18n/strings.dart';
import 'package:savemybook_app/models/ai.dart';
import 'package:savemybook_app/models/auth_social.dart';
import 'package:savemybook_app/models/support.dart';
import 'package:savemybook_app/models/user.dart';
import 'package:savemybook_app/services/api_service.dart';
import 'package:savemybook_app/services/biometric_service.dart';
import 'package:savemybook_app/services/locale_provider.dart';
import 'package:savemybook_app/services/passkey_service.dart';
import 'package:savemybook_app/services/theme_provider.dart';
import 'package:savemybook_app/utils/app_colors.dart';
import 'package:savemybook_app/utils/app_theme.dart';
import 'package:savemybook_app/widgets/adaptive_sheet.dart';
import 'package:savemybook_app/widgets/app_buttons.dart';
import 'package:savemybook_app/widgets/app_header.dart';
import 'package:savemybook_app/widgets/master_detail.dart';
import 'package:savemybook_app/widgets/state_views.dart';

import '../../tool/web_shots/covers.dart' show loadAppFonts;
import '../../tool/web_shots/demo_data.dart';

// G3_SHOTS=<資料夾> 時另存截圖供目視檢查；G3_THEME=dark 為深色模式；G3_SIZES 指定尺寸（phone,landscape,portrait）；
// G3_ONLY 只拍指定畫面；G3_ANDROID=1 改用 Android 平台；G3_DUMP=1 印出例外詳情
final _env = Platform.environment;
final _shots = _env['G3_SHOTS'];
final _dark = _env['G3_THEME'] == 'dark';
final _sizes = (_env['G3_SIZES'] ?? 'phone,landscape,portrait').split(',');
final _only = _env['G3_ONLY']?.split(',');

const _landscape = Size(1180, 820);
const _portrait = Size(820, 1180);
const _phone = Size(390, 844);

const _sizeNames = {'phone': _phone, 'landscape': _landscape, 'portrait': _portrait};

final _rootKey = GlobalKey<NavigatorState>();

http.Response _json(Object? data) => http.Response(
      jsonEncode({
        'success': true,
        'message': 'OK',
        'data': data,
        if (data is List) 'pagination': {'total': data.length, 'page': 1, 'limit': 20, 'total_pages': 1},
      }),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

const _terms = '歡迎使用本系統，使用前請詳閱以下條款。\n\n'
    '第一條　總則\n本條款規範會員使用本系統各項服務之權利與義務。會員於註冊時即表示已閱讀、瞭解並同意接受本條款之所有內容。\n\n'
    '第二條　會員帳號\n會員應妥善保管帳號與密碼，不得轉讓或出借予他人使用。如發現帳號遭盜用，應立即通知本系統。\n\n'
    '第三條　書櫃使用\n會員應依畫面指示存取書籍，並於存放期限內完成取書。逾期未取之書籍，將依本系統規定辦理。\n\n'
    '第四條　交易\n買賣雙方應遵守誠信原則，書況描述應與實際相符。';

var _asAdmin = false;

Object? _extra(String method, String path) => switch ('$method $path') {
      'GET /auth/me' when _asAdmin => {...user(meId), 'role': 'admin'},
      'GET /users/me/level' => {
          'points': 1260,
          'completed_orders': 18,
          'current_level': {'level_id': 2, 'level_name': '銀卡會員', 'min_points': 500, 'max_points': 1999, 'benefits': '每筆訂單回饋 1% 代幣\n專屬客服'},
          'next_level': {'level_id': 3, 'level_name': '金卡會員', 'min_points': 2000, 'max_points': 4999, 'benefits': ''},
          'points_to_next': 740,
          'levels': [
            {'level_id': 1, 'level_name': '一般會員', 'min_points': 0, 'max_points': 499, 'benefits': '可使用智慧書櫃存取書籍'},
            {'level_id': 2, 'level_name': '銀卡會員', 'min_points': 500, 'max_points': 1999, 'benefits': '每筆訂單回饋 1% 代幣\n專屬客服'},
            {'level_id': 3, 'level_name': '金卡會員', 'min_points': 2000, 'max_points': 4999, 'benefits': '每筆訂單回饋 2% 代幣\n專屬客服\n書櫃存放期限延長 3 天'},
            {'level_id': 4, 'level_name': '白金會員', 'min_points': 5000, 'max_points': null, 'benefits': '每筆訂單回饋 3% 代幣\n專屬客服\n書櫃存放期限延長 7 天\n新功能搶先體驗'},
          ],
        },
      'GET /users/me/notification-settings' => {'order': true, 'message': true, 'promotion': false},
      'GET /users/me/deletion' => {'pending': false, 'grace_days': 30},
      'GET /users/me/qrcode' => {'user_id': meId, 'nickname': '海嫄', 'qr_data': 'https://api.savemybook.today/u/0123456789abcdef0123456789abcdef'},
      'GET /support/legal/terms' => {'doc_id': 1, 'doc_key': 'terms', 'title': '服務條款', 'content': _terms, 'version': 3, 'updated_at': '2026-09-01T08:00:00Z'},
      'GET /orders/count' => {'count': 1},
      _ => null,
    };

final _demo = demoApi();

MockClient _api() => MockClient((request) async {
      final path = request.url.path.replaceFirst('/api', '');
      final extra = _extra(request.method, path);
      if (extra != null) return _json(extra);
      final copy = http.Request(request.method, request.url)
        ..headers.addAll(request.headers)
        ..bodyBytes = request.bodyBytes;
      return http.Response.fromStream(await _demo.send(copy));
    });

/// 模擬平板外框：左側保留側邊欄的寬度，頁面放在分頁自己的 Navigator 內（第一頁沒有上一頁）。
class _TabFrame extends StatelessWidget {
  final Widget child;

  const _TabFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final width = MediaQuery.sizeOf(context).width;
    if (width < 600) return child;
    return Row(
      children: [
        Container(
          width: width >= 1024 ? 264 : 88,
          decoration: BoxDecoration(color: c.card, border: Border(right: BorderSide(color: c.divider))),
        ),
        Expanded(
          child: Navigator(onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => child)),
        ),
      ],
    );
  }
}

class _DialogHost extends StatefulWidget {
  final Future<Object?> Function(BuildContext context) show;

  const _DialogHost({required this.show});

  @override
  State<_DialogHost> createState() => _DialogHostState();
}

class _DialogHostState extends State<_DialogHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.show(context);
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox.expand());
}

/// [pushed] 為 true 時畫面推入在空白頁之上（有上一頁）；[tab] 為 true 時當作平板分頁的第一頁。
Widget _app(Widget home, {bool pushed = false, bool tab = false}) => MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: _rootKey,
      locale: const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      supportedLocales: LocaleProvider.supported,
      theme: AppTheme.build(_dark ? Brightness.dark : Brightness.light),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        S = AppLocalizations.of(context);
        return PointerAnchor(child: child ?? const SizedBox.shrink());
      },
      onGenerateInitialRoutes: (_) => [
        if (pushed) PageRouteBuilder<void>(pageBuilder: (_, _, _) => const SizedBox.shrink()),
        MaterialPageRoute<void>(builder: (_) => tab ? _TabFrame(child: home) : home),
      ],
      onGenerateRoute: (_) => null,
    );

Future<void> _settle(WidgetTester tester, [int steps = 10]) async {
  for (var i = 0; i < steps; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// 以示範資料開啟畫面，執行 [body] 後卸載；過程中的版面溢出與例外一律視為失敗。
Future<void> _run(
  WidgetTester tester,
  Size size,
  Widget home,
  Future<void> Function() body, {
  bool pushed = false,
  bool tab = false,
}) async {
  tester.view
    ..physicalSize = size * 2
    ..devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({'biometric_login_enabled': true});
  await BiometricService.load();
  ApiService.authToken = 'demo-token';
  ApiService.currentUser = User.fromJson(user(meId));

  final errors = <String>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.exceptionAsString();
    if (text.contains('NetworkImageLoadException') || text.contains('HTTP request failed')) return;
    if (_env['G3_DUMP'] != null) debugPrint(details.toString());
    errors.add(text.split('\n').first);
  };
  try {
    await http.runWithClient(() async {
      await tester.pumpWidget(_app(home, pushed: pushed, tab: tab));
      await _settle(tester, 20);
      await body();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    }, _api);
  } finally {
    FlutterError.onError = previous;
  }
  expect(errors, isEmpty, reason: '版面溢出或元件例外');
}

// flutter test 固定使用測試字型，未指定字型家族的文字會畫成方框；平板截圖前改以 App 字型重新排版（手機截圖維持原樣以便與修改前比對）
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

Future<void> _capture(WidgetTester tester, String name) async {
  final dir = _shots;
  if (dir == null) return;
  await _settle(tester, 6);
  if (tester.view.physicalSize.width / tester.view.devicePixelRatio >= 600) _applyAppFontToUnstyledText(tester);
  await tester.runAsync(() async {
    final view = tester.binding.renderViews.first;
    final layer = view.debugLayer! as OffsetLayer;
    final image = await layer.toImage(view.paintBounds);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    Directory(dir).createSync(recursive: true);
    File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
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

final _legalDocs = [
  LegalDoc.fromJson({'doc_id': 1, 'doc_key': 'terms', 'title': '服務條款', 'content': _terms, 'version': 3, 'updated_at': '2026-09-01T08:00:00Z'}),
];

Future<void> _tap(WidgetTester tester, Finder finder) async {
  if (finder.hitTestable().evaluate().isEmpty) {
    await tester.scrollUntilVisible(finder.hitTestable(), 200, scrollable: find.byType(Scrollable).first);
    await tester.pump();
  }
  await tester.tap(finder.hitTestable().first);
  await _settle(tester, 12);
}

typedef _Shot = ({Widget Function() home, bool tab, Future<void> Function(WidgetTester tester)? act});

_Shot _shot(Widget Function() home, {bool tab = false, Future<void> Function(WidgetTester tester)? act}) => (home: home, tab: tab, act: act);

/// 截圖用的畫面：名稱、畫面、平板上是否為分頁第一頁、開啟後的操作（有操作的只拍平板）。
final _screens = <String, _Shot>{
  'profile': _shot(() => const ProfileScreen(), tab: true),
  'profile_level': _shot(() => const ProfileScreen(), tab: true, act: (t) => _tap(t, find.text(S.membershipTier))),
  'profile_security': _shot(() => const ProfileScreen(), tab: true, act: (t) => _tap(t, find.text(S.accountSecurity))),
  'profile_privacy': _shot(() => const ProfileScreen(), tab: true, act: (t) => _tap(t, find.text(S.account))),
  'profile_permissions': _shot(() => const ProfileScreen(), tab: true, act: (t) => _tap(t, find.text(S.appPermissions))),
  'profile_help': _shot(() => const ProfileScreen(), tab: true, act: (t) => _tap(t, find.text(S.helpCentre2))),
  'settings': _shot(() => const SettingsScreen(), tab: true),
  'settings_terms': _shot(() => const SettingsScreen(), tab: true, act: (t) => _tap(t, find.text(S.termsService))),
  'settings_theme': _shot(() => const SettingsScreen(), tab: true, act: (t) => _tap(t, find.text(S.appearance))),
  'settings_palette': _shot(() => const SettingsScreen(), tab: true, act: (t) => _tap(t, find.text(S.themeColour))),
  'member_level': _shot(() => const MemberLevelScreen()),
  'edit_profile': _shot(() => const EditProfileScreen()),
  'account_privacy': _shot(() => const AccountPrivacyScreen()),
  'app_permissions': _shot(() => const AppPermissionsScreen()),
  'legal_doc': _shot(() => const LegalDocScreen(docKey: 'terms', fallbackTitle: '服務條款')),
  'share_profile': _shot(() => const ShareProfileScreen()),
  'change_password': _shot(() => const ChangePasswordScreen()),
  'set_password': _shot(() => const SetPasswordScreen()),
  'payment_pin': _shot(() => const PaymentPinScreen()),
  'login_devices': _shot(() => const LoginDevicesScreen()),
  'security': _shot(() => const SecurityCenterScreen()),
  'login': _shot(() => const LoginScreen()),
  'register': _shot(() => const RegisterScreen()),
  'phone_sign_in': _shot(() => const PhoneSignInScreen()),
  'social_profile': _shot(() => const SocialProfileScreen(provider: AuthProviders.phone)),
  'legal_consent': _shot(() => LegalConsentScreen(documents: _legalDocs)),
  'ai_consent': _shot(
    () => _DialogHost(
      show: (context) => showAiConsentSheet(
        context,
        status: const AiStatusInfo(support: true, listingAssist: true, recommend: true, bookChat: true, providersInUse: ['OpenAI'], embeddingProvider: 'OpenAI'),
      ),
    ),
  ),
};

const _rootScreens = {'login', 'register', 'phone_sign_in', 'social_profile', 'legal_consent', 'ai_consent'};

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    if (_shots != null) await loadAppFonts();
    PasskeyService.client = _FakePasskeyClient();
    PasskeyService.resetCache();
    LocalAuthPlatform.instance = _FakeBiometrics();
    themeProvider = await ThemeProvider.init();
    localeProvider = await LocaleProvider.init();
  });

  group('會員中心', () {
    testWidgets('平板橫向：左欄帳戶清單、右欄預設為個人資料，點選項目在右欄開啟且沒有上一頁', (tester) async {
      await _run(tester, _landscape, const ProfileScreen(), () async {
        expect(MasterDetail.isSplit(tester.element(find.byType(TabletMasterColumn))), isTrue);
        expect(find.byType(QuickActionButton), findsNothing, reason: '平板不再顯示手機的四個捷徑圖示');
        expect(find.text(S.orderHistory), findsNothing, reason: '橫向側邊欄已列出訂單紀錄');
        expect(find.text(S.settings), findsNothing);
        expect(find.byType(EditProfileScreen), findsOneWidget, reason: '右欄預設選取第一項');
        final list = tester.getRect(find.byType(TabletMasterColumn));
        expect(tester.getRect(find.byType(EditProfileScreen)).left, greaterThan(list.right - 1));
        expect(find.descendant(of: find.byType(EditProfileScreen), matching: find.text(S.actionSave)), findsOneWidget, reason: '儲存在工具列');

        await _tap(tester, find.text(S.accountSecurity));
        expect(find.byType(SecurityCenterScreen), findsOneWidget);
        expect(find.byType(EditProfileScreen), findsNothing);
        expect(find.byType(TabletMasterColumn), findsOneWidget, reason: '左欄仍在');
        expect(
          find.descendant(of: find.byType(SecurityCenterScreen), matching: find.byIcon(Icons.arrow_back_ios_new_rounded)),
          findsNothing,
          reason: '右欄的根頁面沒有上一頁',
        );
        final row = find.ancestor(of: find.text(S.accountSecurity), matching: find.byType(TabletListRow));
        expect(tester.widget<TabletListRow>(row).selected, isTrue);

        await _tap(tester, find.text(S.membershipTier));
        expect(find.byType(MemberLevelScreen), findsOneWidget);
        expect(find.byType(PageView), findsNothing, reason: '平板的會員等級不用左右滑動的卡片');
      }, tab: true);
    });

    testWidgets('平板橫向：個人資料有未儲存的變更時，切換項目前先確認', (tester) async {
      await _run(tester, _landscape, const ProfileScreen(), () async {
        await tester.enterText(find.descendant(of: find.byType(EditProfileScreen), matching: find.byType(TextField)).first, '新的簡介');
        await _settle(tester, 2);
        await _tap(tester, find.text(S.accountSecurity));
        expect(find.text(S.discardChanges), findsOneWidget);
        await _tap(tester, find.text(S.keepEditing));
        expect(find.byType(EditProfileScreen), findsOneWidget);
        expect(find.byType(SecurityCenterScreen), findsNothing);
      }, tab: true);
    });

    testWidgets('平板橫向：右欄儲存個人資料後留在原頁', (tester) async {
      await _run(tester, _landscape, const ProfileScreen(), () async {
        await tester.enterText(find.descendant(of: find.byType(EditProfileScreen), matching: find.byType(TextField)).first, '新的簡介');
        await _settle(tester, 2);
        await _tap(tester, find.descendant(of: find.byType(EditProfileScreen), matching: find.text(S.actionSave)));
        expect(find.byType(EditProfileScreen), findsOneWidget);
        expect(find.text(S.selectItemToView), findsNothing);
      }, tab: true);
    });

    testWidgets('平板直向：置中的單欄清單，點選項目推入新頁面', (tester) async {
      await _run(tester, _portrait, const ProfileScreen(), () async {
        expect(find.byType(EditProfileScreen), findsNothing);
        final row = tester.getRect(find.ancestor(of: find.text(S.accountSecurity), matching: find.byType(TabletListRow)));
        expect(row.width, lessThanOrEqualTo(640));
        expect(row.center.dx, closeTo(88 + (_portrait.width - 88) / 2, 1));
        // 直向側邊欄為圖示列，帳戶頁提供訂單紀錄、收藏、書籍管理與設定的捷徑
        for (final label in [S.orderHistory, S.saved, S.myBooks, S.settings]) {
          expect(find.text(label), findsOneWidget, reason: label);
        }
        await _tap(tester, find.text(S.accountSecurity));
        expect(find.byType(SecurityCenterScreen), findsOneWidget);
        expect(find.byType(TabletMasterColumn).hitTestable(), findsNothing);
        expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
      }, tab: true);
    });

    testWidgets('平板：待取書開啟訂單紀錄並套用篩選；管理後台以全螢幕開啟', (tester) async {
      await _run(tester, _landscape, const ProfileScreen(), () async {
        await _tap(tester, find.text(S.pickUp));
        final orders = tester.widget<OrderHistoryScreen>(find.byType(OrderHistoryScreen));
        expect(orders.filter, OrderHistoryScreen.awaitingPickup);
      }, tab: true);

      _asAdmin = true;
      addTearDown(() => _asAdmin = false);
      ApiService.currentUser = User.fromJson({...user(meId), 'role': 'admin'});
      tester.view
        ..physicalSize = _landscape * 2
        ..devicePixelRatio = 2;
      await http.runWithClient(() async {
        await tester.pumpWidget(_app(const ProfileScreen(), tab: true));
        await _settle(tester, 12);
        await _tap(tester, find.text(S.admin));
        expect(find.byType(AdminHomeScreen), findsOneWidget);
        expect(tester.getRect(find.byType(AdminHomeScreen)).left, 0, reason: '蓋住 App 的側邊欄');
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 5));
      }, _api);
    });
  });

  group('設定', () {
    testWidgets('平板橫向：左欄列出所有設定，子頁面在右欄開啟', (tester) async {
      await _run(tester, _landscape, const SettingsScreen(), () async {
        expect(find.byType(AccountPrivacyScreen), findsOneWidget, reason: '右欄預設顯示第一個子頁面');
        await _tap(tester, find.text(S.termsService));
        expect(find.byType(LegalDocScreen), findsOneWidget);
        expect(find.byType(TabletMasterColumn), findsOneWidget);
        expect(tester.getRect(find.byType(LegalDocScreen)).left, greaterThan(tester.getRect(find.byType(TabletMasterColumn)).right - 1));
      }, tab: true);
    });

    testWidgets('平板：外觀以彈出選單在點選位置旁選擇，主題色彈出選單不需要完成按鈕', (tester) async {
      await _run(tester, _landscape, const SettingsScreen(), () async {
        final row = tester.getRect(find.ancestor(of: find.text(S.appearance), matching: find.byType(TabletListRow)));
        await _tap(tester, find.text(S.appearance));
        expect(find.byType(BottomSheet), findsNothing);
        expect(find.byType(Dialog), findsNothing);
        final option = tester.getRect(find.text(S.appearanceDark).last);
        expect(option.top, greaterThan(row.top), reason: '彈出選單在點選位置下方');
        expect((option.center.dx - row.center.dx).abs(), lessThan(320), reason: '彈出選單在點選的列附近');
        await _tap(tester, find.text(S.appearanceDark).last);
        expect(themeProvider.value, ThemeMode.dark);
        await themeProvider.setMode(ThemeMode.system);
        await _settle(tester, 4);

        await _tap(tester, find.text(S.themeColour));
        expect(find.byType(BottomSheet), findsNothing);
        expect(find.text(S.completed), findsNothing);
        Navigator.of(_rootKey.currentContext!).pop();
        await _settle(tester, 4);
      }, tab: true);
    });

    testWidgets('平板直向：置中的分組清單，子頁面推入新頁面', (tester) async {
      await _run(tester, _portrait, const SettingsScreen(), () async {
        expect(find.byType(AccountPrivacyScreen), findsNothing);
        final row = tester.getRect(find.ancestor(of: find.text(S.appearance), matching: find.byType(TabletListRow)));
        expect(row.width, lessThanOrEqualTo(640));
        await _tap(tester, find.text(S.termsService));
        expect(find.byType(LegalDocScreen), findsOneWidget);
        expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
      }, tab: true);
    });
  });

  testWidgets('手機設定：iOS 樣式的通知開關在載入設定後不會出錯', (tester) async {
    await _run(tester, _phone, const SettingsScreen(), () async {
      expect(find.text(S.orderProgress), findsOneWidget);
    }, pushed: true);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('會員等級：平板使用工具列與卡片版面，點選等級切換內容', (tester) async {
    for (final size in [_landscape, _portrait]) {
      await _run(tester, size, const MemberLevelScreen(), () async {
        expect(find.byType(TabletToolbar), findsOneWidget);
        expect(find.byIcon(Icons.arrow_back_rounded), findsNothing, reason: '不再使用手機的白色返回鍵');
        expect(find.byType(PageView), findsNothing);
        expect(find.text('銀卡會員'), findsWidgets);
        await tester.tap(find.byIcon(Icons.workspace_premium_rounded).first);
        await _settle(tester, 8);
        expect(find.text(S.benefits('金卡會員')), findsOneWidget);
      }, pushed: true);
    }
  });

  testWidgets('表單與對話框的主要按鈕在平板不撐滿寬度', (tester) async {
    await _run(tester, _landscape, const ChangePasswordScreen(), () async {
      expect(tester.getSize(find.byType(PrimaryButton)).width, lessThan(320));
    }, pushed: true);
    await _run(tester, _landscape, _screens['ai_consent']!.home(), () async {
      expect(find.byType(Dialog), findsOneWidget);
      expect(tester.getSize(find.widgetWithText(PrimaryButton, S.agreeContinue)).width, lessThan(320));
    });
    await _run(tester, _phone, const ChangePasswordScreen(), () async {
      expect(tester.getSize(find.byType(PrimaryButton)).width, greaterThan(300));
    }, pushed: true);
  });

  testWidgets('App 權限：平板的全部允許按鈕靠右且寬度依文字', (tester) async {
    await _run(tester, _landscape, const AppPermissionsScreen(), () async {
      final button = tester.getRect(find.ancestor(of: find.text(S.allowAll), matching: find.byWidgetPredicate((w) => w is ButtonStyleButton)));
      final list = tester.getRect(find.byType(AppCard).first);
      expect(button.width, lessThan(300));
      expect(button.right, closeTo(list.right, 1));
    }, pushed: true);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('登入相關頁面：平板橫向保留品牌區塊，直向與手機維持原樣', (tester) async {
    await _run(tester, _landscape, const RegisterScreen(), () async {
      expect(find.byType(AuthBrandPanel), findsOneWidget);
      expect(tester.getRect(find.byType(TabletToolbar)).left, greaterThan(_landscape.width / 3), reason: '工具列只在右側頁面');
    }, pushed: true);
    await _run(tester, _landscape, const PhoneSignInScreen(), () async {
      expect(find.byType(AuthBrandPanel), findsOneWidget);
    }, pushed: true);
    await _run(tester, _portrait, const RegisterScreen(), () async {
      expect(find.byType(AuthBrandPanel), findsNothing);
    }, pushed: true);
    await _run(tester, _phone, const RegisterScreen(), () async {
      expect(find.byType(AuthBrandPanel), findsNothing);
      expect(find.byType(TabletToolbar), findsNothing);
    }, pushed: true);
  });

  group('截圖', () {
    for (final entry in _screens.entries) {
      for (final sizeName in _sizes) {
        final size = _sizeNames[sizeName]!;
        final name = entry.key;
        if (!(_only?.contains(name) ?? true)) continue;
        final shot = entry.value;
        if (shot.act != null && size == _phone) continue;
        testWidgets('$name $sizeName', (tester) async {
          final root = _rootScreens.contains(name);
          // 手機一律推入在空白頁之上（與既有截圖相同）；平板的分頁畫面當作分頁第一頁
          final asTab = size != _phone && shot.tab;
          await _run(tester, size, shot.home(), () async {
            await shot.act?.call(tester);
            await _capture(tester, '${name}_$sizeName');
          }, pushed: !root && !asTab, tab: asTab);
        }, skip: _shots == null, variant: TargetPlatformVariant.only(_env['G3_ANDROID'] == null ? TargetPlatform.iOS : TargetPlatform.android));
      }
    }
  });
}
