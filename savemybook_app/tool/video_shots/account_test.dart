// 系統簡介影片第二版「帳號會員」段落：flutter test tool/video_shots/account_test.dart
// 登入頁的社群登入與通行密鑰、es 的會員等級，以及設定頁在五種語言與深淺色主題下的真實畫面。

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:savemybook_app/features/account/member_level_screen.dart';
import 'package:savemybook_app/features/account/settings_screen.dart';
import 'package:savemybook_app/features/auth/login_screen.dart';
import 'package:savemybook_app/features/auth/social_sign_in.dart';
import 'package:savemybook_app/features/security/passkey_sign_in_button.dart';
import 'package:savemybook_app/i18n/app_localizations.dart';
import 'package:savemybook_app/i18n/strings.dart';
import 'package:savemybook_app/services/locale_provider.dart';
import 'package:savemybook_app/services/theme_provider.dart';
import 'package:savemybook_app/utils/app_colors.dart';
import 'package:savemybook_app/utils/app_theme.dart';

import '../manual_shots/manual_api.dart';
import 'video_host.dart';

final _ios = TargetPlatformVariant.only(TargetPlatform.iOS);

/// 會員等級：門檻 100／500／2000 點（複評版手冊 p260 表 12-16-2），名稱與權益同第 12 章截圖。
const _levels = [
  {'level_id': 1, 'level_name': '新手書友', 'min_points': 0, 'max_points': 99, 'benefits': '基本交易功能'},
  {'level_id': 2, 'level_name': '活躍書友', 'min_points': 100, 'max_points': 499, 'benefits': '享有推薦曝光加成'},
  {'level_id': 3, 'level_name': '資深書友', 'min_points': 500, 'max_points': 1999, 'benefits': '享有交易手續費折扣'},
  {'level_id': 4, 'level_name': '菁英書友', 'min_points': 2000, 'max_points': null, 'benefits': '享有全部VIP權益'},
];

/// es 完成劇情中《HTML & CSS》這筆購買訂單後的點數：每完成一筆購買訂單累積 10 點（手冊 p260 表 12-16-1）。
Map<String, dynamic> _levelInfo() => {
  'points': 10,
  'completed_orders': 1,
  'current_level': _levels[0],
  'next_level': _levels[1],
  'points_to_next': 90,
  'levels': _levels,
};

void _accountRoutes() {
  ManualApi.on('GET', '/auth/me', (_) => userJson(meId));
  ManualApi.on('GET', '/users/me/level', (_) => _levelInfo());
  ManualApi.on('GET', '/users/me/notification-settings', (_) => {'order': true, 'message': true, 'promotion': true});
  ManualApi.on('GET', '/auth/providers', (_) => {
    'social_enabled': true,
    'providers': [
      for (final id in ['google', 'apple', 'phone', 'line', 'discord']) {'id': id, 'enabled': true, 'signup': true, 'configured': true},
    ],
  });
  ManualApi.on('GET', '/auth/passkeys/status', (_) => {'enabled': true, 'rp_id': 'savemybook.today'});
}

// ───────────── 語言與主題 ─────────────

const _hant = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');

/// App 的五種介面語言（lib/services/locale_provider.dart），名稱為畫面檔名的後綴。
final _locales = <String, Locale>{
  'hant': _hant,
  'en': const Locale('en'),
  'ja': const Locale('ja'),
  'ko': const Locale('ko'),
  'hans': const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
};

/// 以指定語言與主題呈現 [child]：比照 lib/main.dart 的 MaterialApp（locale、theme 與全域 S 的指派）。
/// ManualApp 固定為繁體中文淺色，所以在它的頁面內再包一層，頁面推入與返回都在這層的導覽器內進行。
class _Shell extends StatelessWidget {
  final Locale locale;
  final Brightness brightness;
  final Widget child;

  const _Shell({required this.locale, required this.brightness, required this.child});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: LocaleProvider.supported,
      theme: AppTheme.build(brightness),
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
      onGenerateInitialRoutes: (_) => [
        PageRouteBuilder<void>(pageBuilder: (_, _, _) => const SizedBox.shrink()),
        MaterialPageRoute<void>(builder: (_) => child),
      ],
      onGenerateRoute: (_) => null,
    );
  }
}

// 韓文介面：App 字型 Noto Sans TC 沒有諺文，主題的後備字型為 Apple SD Gothic Neo（lib/utils/app_theme.dart）；
// 測試環境沒有系統字型，從本機 macOS 載入，否則諺文會畫成方框。
Future<void> _loadAppleSdGothicNeo() async {
  final file = File('/System/Library/Fonts/AppleSDGothicNeo.ttc');
  if (!file.existsSync()) throw StateError('找不到 Apple SD Gothic Neo');
  final ttc = file.readAsBytesSync();
  final count = ByteData.sublistView(ttc).getUint32(8);
  final loader = FontLoader('Apple SD Gothic Neo');
  for (var i = 0; i < count; i++) {
    loader.addFont(Future.value(ByteData.sublistView(_ttcFontFace(ttc, i))));
  }
  await loader.load();
}

/// 由 TTC 取出第 [index] 個字面，組成獨立的 TTF（表格依序重排、四位元組對齊）。
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

void main() {
  setUpAll(() async {
    await setUpManual();
    await _loadAppleSdGothicNeo();
  });
  setUp(failures.clear);
  tearDown(() {
    localeProvider.value = null;
    themeProvider.value = ThemeMode.system;
  });
  tearDownAll(writeJson);

  testWidgets('登入頁', variant: _ios, (tester) async {
    await videoShoot(
      tester,
      prefs: const {'last_login_email': meEmail},
      routes: _accountRoutes,
      home: LoginScreen.new,
      act: (tester) async {
        await settleReal(tester, const Duration(seconds: 2));
        await snapScreen(tester, 'v_acc_login');
        // 社群登入圖示：外框按鈕本身為透明底，連同登入頁的底色輸出成不透明的完整按鈕（不含下方的名稱文字）
        bool shape(RenderObject ro) => ro is RenderPhysicalShape;
        for (final id in ['google', 'apple', 'phone', 'line']) {
          final tile = find.byWidgetPredicate((w) => w is SocialSignInTile && w.provider == id);
          final button = find.descendant(of: tile, matching: find.byType(OutlinedButton));
          await cut(tester, 'cut_acc_$id', screen: 'v_acc_login', box: renderOf(tester, button, pick: shape), note: '登入頁的 $id 登入按鈕（含底色）');
        }
        final passkey = find.descendant(of: find.byType(PasskeySignInButton), matching: find.byType(OutlinedButton));
        await cut(tester, 'cut_acc_passkey', screen: 'v_acc_login', box: renderOf(tester, passkey, pick: shape), note: '使用通行密鑰登入（含底色）');
        await restoreTree(tester);
      },
    );
    expect(failures, isEmpty);
  });

  testWidgets('會員等級', variant: _ios, (tester) async {
    await videoShoot(
      tester,
      routes: _accountRoutes,
      home: MemberLevelScreen.new,
      act: (tester) async {
        await settleReal(tester, const Duration(seconds: 2));
        // 切到下一個等級「活躍書友」：卡片顯示距升級所需點數與 10 / 100 的進度
        tester.widget<PageView>(find.byType(PageView)).controller!.jumpToPage(1);
        await settleReal(tester, const Duration(seconds: 2));
        await snapScreen(tester, 'v_acc_level');
        // 狀態卡片：離文字最近、帶陰影的那一層 Container（往上還有整頁的漸層底與等級節點）
        final card = ancestorWhere(
          find.text(S.morePointsUnlock(90, '活躍書友')),
          (w) => w is Container && w.decoration is BoxDecoration && (w.decoration! as BoxDecoration).boxShadow != null,
        );
        await cut(tester, 'cut_acc_level_card', screen: 'v_acc_level', box: renderOf(tester, card, pick: isBoxDecoration), note: '再 90 點即可解鎖「活躍書友」，10 / 100');
        final points = find.ancestor(of: find.text(S.pointsFromCompletedOrders(10, 1)), matching: find.byType(Container)).first;
        await cut(tester, 'cut_acc_points', screen: 'v_acc_level', box: renderOf(tester, points, pick: isBoxDecoration), note: '目前累積 10 點，已完成 1 筆交易');
        await restoreTree(tester);
      },
    );
    expect(failures, isEmpty);
  });

  for (final (tag, locale) in _locales.entries.map((e) => (e.key, e.value))) {
    for (final dark in [false, true]) {
      final name = 'v_acc_settings_$tag${dark ? '_dark' : ''}';
      testWidgets('設定 $name', variant: _ios, (tester) async {
        localeProvider.value = locale;
        themeProvider.value = dark ? ThemeMode.dark : ThemeMode.light;
        await videoShoot(
          tester,
          routes: _accountRoutes,
          home: () => _Shell(locale: locale, brightness: dark ? Brightness.dark : Brightness.light, child: const SettingsScreen()),
          act: (tester) async {
            await settleReal(tester, const Duration(seconds: 2));
            await snapScreen(tester, name);
            if (dark) return;
            // 「語言」那一列：列本身為透明底，連同卡片的白底輸出；五種語言的位置相同，影片中原地浮出並隨畫面切換語言
            final row = ancestorWhere(find.text(S.language), (w) => w.runtimeType.toString() == '_SettingsRow');
            final card = AppColors.of(tester.element(find.byType(SettingsScreen))).card;
            await cut(tester, 'cut_acc_lang_$tag', screen: name, box: renderOf(tester, row), backdrop: card, note: '設定頁的語言列（${S.language}）');
            await restoreTree(tester);
          },
        );
        expect(failures, isEmpty);
      });
    }
  }
}
