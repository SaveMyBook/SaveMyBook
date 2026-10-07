import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:savemybook_app/features/chat/ai/ai_book_chat_screen.dart';
import 'package:savemybook_app/features/chat/blocked_users_screen.dart';
import 'package:savemybook_app/features/chat/chat_list_screen.dart';
import 'package:savemybook_app/features/chat/chat_room_screen.dart';
import 'package:savemybook_app/features/chat/groups/create_group_screen.dart';
import 'package:savemybook_app/features/chat/settings/chat_room_settings_screen.dart';
import 'package:savemybook_app/i18n/app_localizations.dart';
import 'package:savemybook_app/i18n/strings.dart';
import 'package:savemybook_app/models/ai.dart';
import 'package:savemybook_app/models/book.dart';
import 'package:savemybook_app/services/api_service.dart';
import 'package:savemybook_app/services/locale_provider.dart';
import 'package:savemybook_app/utils/app_theme.dart';

import '../layout_overflow_test.dart' as lt;

const _landscape = Size(1180, 820);
const _portrait = Size(820, 1180);
const _phone = Size(390, 844);

// 設定 B_SHOTS=<資料夾> 時另存截圖供目視檢查
final _shotsDir = Platform.environment['B_SHOTS'];

MockClient _api() => MockClient((request) async {
      if (request.url.path.endsWith('/chat/blocks')) {
        final users = [for (var i = 2; i < 7; i++) lt.user(i)];
        return http.Response(
          jsonEncode({'success': true, 'message': 'OK', 'data': users}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      final copy = http.Request(request.method, request.url)
        ..headers.addAll(request.headers)
        ..bodyBytes = request.bodyBytes;
      return http.Response.fromStream(await lt.fakeApi().send(copy));
    });

Widget _host(Widget home) => MaterialApp(
      theme: AppTheme.build(Brightness.dark),
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
        return child!;
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

int _shownRoom(WidgetTester tester) => tester.widget<ChatRoomScreen>(find.byType(ChatRoomScreen)).roomId;

List<AiBookChatItem> _aiItems() => [
      AiBookChatItem(id: 'u1', isUser: true, content: '想找統計學的入門教材', animate: false),
      AiBookChatItem(
        id: 'a1',
        isUser: false,
        content: '以下是符合條件的教材。',
        books: [for (var i = 1; i <= 6; i++) AiBookSuggestion(book: Book.fromJson(lt.book(i)), reason: '入門必讀')],
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

  testWidgets('橫向並排：列表與聊天室同時顯示，點另一個聊天切換右側，附加功能為彈出選單、轉帳為置中對話框', (tester) async {
    await _run(tester, _landscape, const ChatListScreen(), () async {
      expect(find.text(S.selectChat), findsOneWidget);
      await tester.tap(_room(3));
      await _settle(tester);
      expect(find.byType(ChatRoomScreen), findsOneWidget);
      expect(_shownRoom(tester), 3);
      expect(_room(1), findsOneWidget, reason: '列表仍在左側');
      expect(tester.getTopLeft(find.byType(ChatRoomScreen)).dx, greaterThan(370));
      expect(
        find.descendant(of: find.byType(ChatRoomScreen), matching: find.byIcon(Icons.arrow_back_rounded)),
        findsNothing,
        reason: '右側聊天室沒有上一頁',
      );
      await _snap(tester, 'chat_split_land');

      await tester.tap(_room(1));
      await _settle(tester);
      expect(find.byType(ChatRoomScreen), findsOneWidget);
      expect(_shownRoom(tester), 1);
      expect(_room(3), findsOneWidget);

      await tester.tap(find.descendant(of: find.byType(ChatRoomScreen), matching: find.byIcon(Icons.add_rounded)));
      await _settle(tester);
      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text(S.takePhoto), findsOneWidget);
      await _snap(tester, 'chat_attach_dialog');
      await tester.tapAt(const Offset(10, 10));
      await _settle(tester);
      expect(find.text(S.takePhoto), findsNothing);

      await tester.tap(find.descendant(of: find.byType(ChatRoomScreen), matching: find.byIcon(Icons.add_rounded)));
      await _settle(tester);
      // 彈出選單在最上層，聊天內容的轉帳卡片也有同樣的文字
      await tester.tap(find.text(S.transfer).last);
      await _settle(tester);
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text(S.confirmTransfer), findsOneWidget);
      await _snap(tester, 'chat_transfer_dialog');
      await tester.tapAt(const Offset(10, 10));
      await _settle(tester);
    });
  });

  testWidgets('直向單欄：點選聊天推入新頁面', (tester) async {
    await _run(tester, _portrait, const ChatListScreen(), () async {
      expect(find.text(S.selectChat), findsNothing);
      await _snap(tester, 'chat_list_port');
      await tester.tap(_room(1));
      await _settle(tester);
      expect(find.byType(ChatRoomScreen), findsOneWidget);
      expect(_room(3), findsNothing, reason: '聊天室蓋住列表');
      expect(tester.getSize(find.byType(ChatRoomScreen)).width, _portrait.width);
      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
      await _snap(tester, 'chat_room_port');
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await _settle(tester);
      expect(_room(3), findsOneWidget);
    });
  });

  testWidgets('手機的附加功能維持底部面板', (tester) async {
    await _run(tester, _phone, const ChatRoomScreen(roomId: 1), () async {
      await tester.tap(find.byIcon(Icons.add_rounded));
      await _settle(tester);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
    });
  });

  testWidgets('橫向直接開啟聊天室：訊息與輸入列撐滿欄位，不置中成窄欄', (tester) async {
    await _run(tester, _landscape, const ChatRoomScreen(roomId: 2), () async {
      final field = tester.getRect(find.byType(TextField));
      expect(field.left, lessThan(100));
      expect(field.right, greaterThan(_landscape.width - 100));
      await tester.tap(find.text(S.scamSafetyTips).first);
      await _settle(tester);
      expect(find.byType(Dialog), findsOneWidget);
      await _snap(tester, 'chat_fraud_tips_dialog');
      await tester.tapAt(const Offset(10, 10));
      await _settle(tester);
    });
  });

  for (final size in [_landscape, _portrait]) {
    testWidgets('AI 書籍顧問寬螢幕書卡多張並排 ${size.width.toInt()}', (tester) async {
      await _run(tester, size, AiBookChatScreen(initialItems: _aiItems()), () async {
        expect(find.byType(AiBookChatCard), findsNWidgets(6));
        final first = tester.getRect(find.byType(AiBookChatCard).first);
        final second = tester.getRect(find.byType(AiBookChatCard).at(1));
        expect(second.top, first.top, reason: '同一列並排');
        await _snap(tester, 'ai_chat_cards_${size.width.toInt()}');
      });
    });
  }

  testWidgets('聊天設定寬螢幕分兩欄，直向維持單欄', (tester) async {
    await _run(tester, _landscape, const ChatRoomSettingsScreen(roomId: 2), () async {
      final members = tester.getRect(find.text(S.inviteMembers));
      final mute = tester.getRect(find.text(S.muteNotifications));
      expect(members.left, greaterThan(mute.right), reason: '成員在右欄');
      await _snap(tester, 'chat_settings_group_land');
    });
    await _run(tester, _landscape, const ChatRoomSettingsScreen(roomId: 1), () async {
      await _snap(tester, 'chat_settings_direct_land');
    });
    await _run(tester, _portrait, const ChatRoomSettingsScreen(roomId: 2), () async {
      final members = tester.getRect(find.text(S.inviteMembers));
      final mute = tester.getRect(find.text(S.muteNotifications));
      expect(members.top, greaterThan(mute.bottom));
    });
  });

  testWidgets('建立群組寬螢幕：成員選擇與群組資料不擠在窄欄', (tester) async {
    await _run(tester, _landscape, const CreateGroupScreen(), () async {
      await _snap(tester, 'create_group_members_land');
      await tester.tap(find.text(lt.longName).first);
      await _settle(tester, 3);
      final next = find.ancestor(of: find.textContaining(S.next), matching: find.byType(ElevatedButton));
      expect(tester.getRect(next).width, lessThanOrEqualTo(480));
      await tester.tap(next);
      await _settle(tester, 5);
      final name = tester.getRect(find.byType(TextField));
      final avatar = tester.getRect(find.byIcon(Icons.groups_rounded));
      expect(name.left, greaterThan(avatar.right), reason: '頭像在左、欄位在右');
      await _snap(tester, 'create_group_profile_land');
    });
  });

  testWidgets('封鎖名單寬螢幕多欄', (tester) async {
    await _run(tester, _landscape, const BlockedUsersScreen(), () async {
      final unblock = find.text(S.unblock);
      expect(unblock, findsNWidgets(5));
      expect(tester.getRect(unblock.at(1)).top, tester.getRect(unblock.at(0)).top);
      await _snap(tester, 'blocked_users_land');
    });
  });
}
