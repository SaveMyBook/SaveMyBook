import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:savemybook_app/features/chat/ai/ai_book_chat_screen.dart';
import 'package:savemybook_app/features/chat/chat_list_screen.dart';
import 'package:savemybook_app/features/chat/chat_room_screen.dart';
import 'package:savemybook_app/features/chat/groups/create_group_screen.dart';
import 'package:savemybook_app/features/chat/settings/chat_room_settings_screen.dart';
import 'package:savemybook_app/i18n/app_localizations.dart';
import 'package:savemybook_app/i18n/strings.dart';
import 'package:savemybook_app/models/ai.dart';
import 'package:savemybook_app/models/book.dart';
import 'package:savemybook_app/services/ai_status.dart';
import 'package:savemybook_app/services/api_service.dart';
import 'package:savemybook_app/services/locale_provider.dart';
import 'package:savemybook_app/utils/app_theme.dart';
import 'package:savemybook_app/widgets/adaptive_sheet.dart';
import 'package:savemybook_app/widgets/app_header.dart';
import 'package:savemybook_app/widgets/state_views.dart';

import '../layout_overflow_test.dart' as lt;

const _landscape = Size(1180, 820);
const _portrait = Size(820, 1180);
const _phone = Size(390, 844);

// 設定 G4_SHOTS=<資料夾> 時另存截圖供目視檢查；G4_THEME=light 改淺色
final _shotsDir = Platform.environment['G4_SHOTS'];
final _brightness = Platform.environment['G4_THEME'] == 'light' ? Brightness.light : Brightness.dark;

MockClient _api() => MockClient((request) async {
      final copy = http.Request(request.method, request.url)
        ..headers.addAll(request.headers)
        ..bodyBytes = request.bodyBytes;
      return http.Response.fromStream(await lt.fakeApi().send(copy));
    });

Widget _host(Widget home) => MaterialApp(
      theme: AppTheme.build(_brightness),
      locale: const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      supportedLocales: LocaleProvider.supported,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        S = AppLocalizations.of(context);
        return PointerAnchor(child: child!);
      },
      home: home,
    );

Future<void> _loadFonts() async {
  final manifest = jsonDecode(await rootBundle.loadString('FontManifest.json')) as List<dynamic>;
  final noto = <Future<ByteData>>[];
  for (final family in manifest.cast<Map<String, dynamic>>()) {
    final name = family['family'] as String;
    final loader = FontLoader(name);
    for (final font in (family['fonts'] as List).cast<Map<String, dynamic>>()) {
      final data = rootBundle.load(font['asset'] as String);
      loader.addFont(data);
      if (name == 'NotoSansTC') noto.add(data);
    }
    await loader.load();
  }
  for (final alias in ['Roboto', 'CupertinoSystemText', 'CupertinoSystemDisplay']) {
    final loader = FontLoader(alias);
    for (final data in noto) {
      loader.addFont(data);
    }
    await loader.load();
  }
}

Future<void> _snap(WidgetTester tester, String name) async {
  final dir = _shotsDir;
  if (dir == null) return;
  final view = tester.binding.renderViews.first;
  await tester.runAsync(() async {
    final layer = view.debugLayer! as OffsetLayer;
    final image = await layer.toImage(view.paintBounds);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    Directory(dir).createSync(recursive: true);
    File('$dir/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
  });
}

Future<void> _settle(WidgetTester tester, [int frames = 10]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> _run(WidgetTester tester, Size size, Widget home, Future<void> Function() body) async {
  tester.view
    ..physicalSize = size * 2
    ..devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final errors = <String>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.exceptionAsString();
    if (!text.contains('NetworkImageLoadException') && !text.contains('HTTP request failed')) errors.add(text.split('\n').first);
  };
  Object? failure;
  StackTrace? stack;
  await http.runWithClient(() async {
    await tester.pumpWidget(_host(home));
    await _settle(tester);
    try {
      await body();
    } catch (e, st) {
      failure = e;
      stack = st;
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  }, _api);
  FlutterError.onError = previous;
  if (failure != null) Error.throwWithStackTrace(failure!, stack!);
  expect(errors, isEmpty, reason: '版面溢出或元件例外');
}

Finder _room(int id) => find.byKey(ValueKey('swipe_$id'));

Finder _inRoom(Finder matching) => find.descendant(of: find.byType(ChatRoomScreen), matching: matching);

Finder get _popoverOrSheet => find.byWidgetPredicate((w) => w is BottomSheet || w is Dialog);

Color _rowColor(WidgetTester tester, int id) =>
    tester.widget<Material>(find.descendant(of: _room(id), matching: find.byType(Material)).first).color!;

List<AiBookChatItem> _aiItems() => [
      AiBookChatItem(id: 'u1', isUser: true, content: '想找統計學的入門教材', animate: false),
      AiBookChatItem(
        id: 'a1',
        isUser: false,
        content: '以下是符合條件的教材。',
        books: [for (var i = 1; i <= 4; i++) AiBookSuggestion(book: Book.fromJson(lt.book(i)), reason: '入門必讀')],
        animate: false,
      ),
    ];

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    ApiService.authToken = 'test-token';
    ApiService.currentUser = lt.testUser;
    if (_shotsDir != null) await _loadFonts();
  });

  testWidgets('橫向並排：列表為一列一筆、選取有底色，聊天室頁首與列表工具列等高相連', (tester) async {
    await _run(tester, _landscape, const ChatListScreen(), () async {
      expect(find.descendant(of: _room(1), matching: find.byType(AppCard)), findsNothing, reason: '平板不用手機的卡片');
      final idle = _rowColor(tester, 3);
      await tester.tap(_room(3));
      await _settle(tester);
      expect(find.byType(ChatRoomScreen), findsOneWidget);
      expect(_rowColor(tester, 3), isNot(idle), reason: '選取項目有底色');
      expect(_rowColor(tester, 1), idle);

      final toolbars = find.byType(TabletToolbar);
      expect(toolbars, findsNWidgets(2));
      final list = tester.getRect(toolbars.first);
      final room = tester.getRect(_inRoom(find.byType(TabletToolbar)));
      expect(room.left, greaterThan(list.right - 1));
      expect(room.top, list.top);
      expect(room.height, list.height, reason: '兩欄工具列等高相連');
      expect(_inRoom(find.byIcon(Icons.arrow_back_ios_new_rounded)), findsNothing, reason: '右側聊天室沒有上一頁');
      expect(_inRoom(find.byIcon(Icons.more_horiz_rounded)), findsOneWidget);
      await _snap(tester, 'split_land');

      // 訊息撐滿右欄，不再置中成一條窄欄
      final pane = tester.getRect(find.byType(ChatRoomScreen));
      final field = tester.getRect(_inRoom(find.byType(TextField)));
      expect(field.left - pane.left, lessThan(90));
      expect(pane.right - field.right, lessThan(90));
    });
  });

  testWidgets('右鍵開啟聊天室選單（彈出於指標旁），可直接釘選或取消', (tester) async {
    await _run(tester, _landscape, const ChatListScreen(), () async {
      final at = tester.getCenter(_room(1));
      await tester.tapAt(at, buttons: kSecondaryButton);
      await _settle(tester, 4);
      expect(find.text(S.openChat), findsOneWidget);
      expect(find.text(S.unpin), findsOneWidget, reason: '聊天室 1 已釘選');
      expect(find.text(S.deleteChat), findsOneWidget);
      expect(_popoverOrSheet, findsNothing, reason: '不是底部面板也不是置中對話框');
      final menu = tester.getRect(find.text(S.openChat));
      expect((menu.center.dy - at.dy).abs(), lessThan(200), reason: '選單在指標附近');
      await _snap(tester, 'room_context_menu');
      await tester.tap(find.text(S.unpin));
      await _settle(tester, 4);
      expect(find.text(S.openChat), findsNothing);

      await tester.tapAt(tester.getCenter(_room(2)), buttons: kSecondaryButton);
      await _settle(tester, 4);
      expect(find.text(S.leaveGroup), findsOneWidget, reason: '群組顯示退出群組');
      await tester.tap(find.text(S.openChat));
      await _settle(tester);
      expect(tester.widget<ChatRoomScreen>(find.byType(ChatRoomScreen)).roomId, 2);
    });
  });

  testWidgets('訊息右鍵選單與附加功能彈出選單', (tester) async {
    await _run(tester, _landscape, const ChatListScreen(), () async {
      await tester.tap(_room(3));
      await _settle(tester);

      // 文字訊息在轉帳卡片上方，先往上捲讓它出現在畫面內
      await tester.drag(_inRoom(find.byType(CustomScrollView)), const Offset(0, 500));
      await _settle(tester, 4);
      final message = _inRoom(find.textContaining('fairly long chat message', findRichText: true)).first;
      await tester.tapAt(tester.getCenter(message), buttons: kSecondaryButton);
      await _settle(tester, 4);
      expect(find.text(S.reply), findsOneWidget);
      expect(find.text(S.copy), findsOneWidget);
      expect(_popoverOrSheet, findsNothing);
      await _snap(tester, 'message_context_menu');
      await tester.tapAt(const Offset(10, 700));
      await _settle(tester, 4);
      expect(find.text(S.reply), findsNothing);

      // 聊天室 1 有對方資料，附加功能才有轉帳
      await tester.tap(_room(1));
      await _settle(tester);
      final plus = tester.getRect(_inRoom(find.byIcon(Icons.add_rounded)));
      await tester.tap(_inRoom(find.byIcon(Icons.add_rounded)));
      await _settle(tester, 4);
      expect(_popoverOrSheet, findsNothing, reason: '平板以彈出選單呈現');
      final photo = tester.getRect(find.text(S.takePhoto));
      expect(photo.bottom, lessThan(plus.top), reason: '選單在按鈕上方');
      expect(photo.left, greaterThan(plus.left));
      expect(photo.left, lessThan(plus.left + 90), reason: '選單對齊按鈕');
      await _snap(tester, 'attach_popover');

      // 彈出選單在最上層，聊天內容的轉帳卡片也有同樣的文字
      await tester.tap(find.text(S.transfer).last);
      await _settle(tester);
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text(S.confirmTransfer), findsOneWidget);
      await _snap(tester, 'transfer_dialog');
      await tester.tapAt(const Offset(10, 10));
      await _settle(tester);
    });
  });

  testWidgets('防詐須知在點選的連結旁彈出，不是置中對話框', (tester) async {
    await _run(tester, _landscape, const ChatRoomScreen(roomId: 2), () async {
      final link = tester.getRect(find.text(S.scamSafetyTips).first);
      await tester.tap(find.text(S.scamSafetyTips).first);
      await _settle(tester, 4);
      expect(_popoverOrSheet, findsNothing);
      final title = tester.getRect(find.text(S.scamSafetyTips).last);
      expect(title.top, greaterThan(link.bottom), reason: '說明出現在連結下方');
      expect(title.left, lessThan(link.left + 300));
      await _snap(tester, 'fraud_tips_popover');
      await tester.tapAt(const Offset(1100, 780));
      await _settle(tester, 4);
      expect(find.text(S.scamSafetyTips), findsWidgets);
    });
  });

  testWidgets('直向單欄：列表一列一筆，點選推入聊天室，頁首為工具列並有返回鍵', (tester) async {
    await _run(tester, _portrait, const ChatListScreen(), () async {
      expect(find.text(S.selectChat), findsNothing);
      expect(find.descendant(of: _room(1), matching: find.byType(AppCard)), findsNothing);
      await _snap(tester, 'list_port');
      await tester.tap(_room(2));
      await _settle(tester);
      expect(_room(3), findsNothing, reason: '聊天室蓋住列表');
      expect(_inRoom(find.byType(TabletToolbar)), findsOneWidget);
      expect(_inRoom(find.text(S.membersP0(7))), findsOneWidget, reason: '群組在名稱下方顯示成員數');
      await _snap(tester, 'room_port');
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await _settle(tester);
      expect(_room(3), findsOneWidget);
    });
  });

  testWidgets('實體鍵盤：Enter 送出、Shift+Enter 不送出', (tester) async {
    await _run(tester, _landscape, const ChatRoomScreen(roomId: 1), () async {
      await _snap(tester, 'room_full_land');
      final field = find.byType(TextField);
      final rect = tester.getRect(field);
      expect(rect.left, lessThan(100), reason: '輸入列撐滿聊天欄位');
      expect(rect.right, greaterThan(_landscape.width - 100));
      await tester.tap(field);
      await tester.enterText(field, '請問明天可以取書嗎');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(tester.widget<TextField>(field).controller!.text, '請問明天可以取書嗎');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await _settle(tester, 4);
      expect(tester.widget<TextField>(field).controller!.text, isEmpty, reason: 'Enter 送出後清空輸入框');
    });
  });

  testWidgets('AI 書籍顧問：Enter 送出、Shift+Enter 換行，輸入列與工具列同底色', (tester) async {
    AiStatus.debugSet(const AiStatusInfo(bookChat: true, consented: true, providersInUse: ['DeepSeek']));
    addTearDown(() => AiStatus.debugSet(AiStatusInfo.none));
    await _run(tester, _landscape, AiBookChatScreen(initialItems: _aiItems()), () async {
      await _snap(tester, 'ai_land');
      final field = find.byType(TextField);
      await tester.tap(field);
      await tester.enterText(field, '統計學');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      final controller = tester.widget<TextField>(field).controller!;
      expect(controller.text, '統計學\n');
      controller.text = '統計學\n入門';
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await _settle(tester, 4);
      expect(controller.text, isEmpty);
      expect(find.text('統計學\n入門'), findsOneWidget);
    });
  });

  testWidgets('建立群組在平板以表單視窗開啟，主要按鈕在工具列右側', (tester) async {
    await _run(tester, _landscape, const ChatListScreen(), () async {
      await tester.tap(find.byIcon(Icons.group_add_outlined));
      await _settle(tester);
      final sheet = find.ancestor(of: find.byType(CreateGroupScreen), matching: find.byType(Dialog));
      expect(sheet, findsOneWidget);
      expect(tester.getSize(find.byType(CreateGroupScreen)).width, lessThanOrEqualTo(600));
      expect(find.byIcon(Icons.close_rounded), findsOneWidget, reason: '第一步以關閉鍵取代返回鍵');
      final next = find.ancestor(of: find.text(S.next), matching: find.byType(ElevatedButton));
      expect(next, findsOneWidget);
      expect(tester.widget<ElevatedButton>(next).onPressed, isNull);
      final toolbar = tester.getRect(find.descendant(of: sheet, matching: find.byType(TabletToolbar)));
      expect(tester.getRect(next).center.dy, lessThan(toolbar.bottom), reason: '按鈕在工具列內');
      await _snap(tester, 'create_group_sheet');

      await tester.tap(find.descendant(of: find.byType(CreateGroupScreen), matching: find.text(lt.longName)).first);
      await _settle(tester, 3);
      final next1 = find.ancestor(of: find.text('${S.next}（1）'), matching: find.byType(ElevatedButton));
      await tester.tap(next1);
      await _settle(tester, 5);
      expect(find.text(S.groupDetails), findsOneWidget);
      final back = find.descendant(of: find.byType(CreateGroupScreen), matching: find.byIcon(Icons.arrow_back_ios_new_rounded));
      expect(back, findsOneWidget, reason: '第二步可返回上一步');
      final create = find.ancestor(of: find.text(S.createGroup), matching: find.byType(ElevatedButton));
      expect(create, findsOneWidget, reason: '只有工具列上的按鈕，底部沒有整排按鈕');
      expect(tester.getSize(create).width, lessThan(200));
      await _snap(tester, 'create_group_sheet_profile');

      await tester.tap(back);
      await _settle(tester, 5);
      expect(find.text(S.selectMembers), findsOneWidget);
      // 已選成員的標籤也有關閉圖示，工具列的關閉鍵排在最前面
      await tester.tap(find.byIcon(Icons.close_rounded).first);
      await _settle(tester);
      expect(find.byType(CreateGroupScreen), findsNothing);
    });
  });

  testWidgets('聊天設定橫向截圖', (tester) async {
    await _run(tester, _landscape, const ChatRoomSettingsScreen(roomId: 2), () async {
      await _snap(tester, 'settings_land');
    });
  });

  testWidgets('手機維持卡片列表、長按預覽與底部面板', (tester) async {
    await _run(tester, _phone, const ChatListScreen(), () async {
      expect(find.descendant(of: _room(1), matching: find.byType(AppCard)), findsOneWidget);
      await tester.tap(find.byIcon(Icons.group_add_outlined));
      await _settle(tester);
      expect(find.byType(CreateGroupScreen), findsOneWidget);
      expect(find.byType(Dialog), findsNothing, reason: '手機推入新頁面');
    });
    await _run(tester, _phone, const ChatRoomScreen(roomId: 1), () async {
      await tester.tap(find.byIcon(Icons.add_rounded));
      await _settle(tester);
      expect(find.byType(BottomSheet), findsOneWidget);
    });
  });
}
