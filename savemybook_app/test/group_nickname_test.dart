import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:savemybook_app/features/chat/settings/chat_room_settings_screen.dart';
import 'package:savemybook_app/i18n/app_localizations.dart';
import 'package:savemybook_app/i18n/strings.dart';
import 'package:savemybook_app/models/user.dart';
import 'package:savemybook_app/services/api_service.dart';
import 'package:savemybook_app/services/locale_provider.dart';
import 'package:savemybook_app/utils/app_theme.dart';

Map<String, dynamic> _member(int id, String nickname, {String role = 'member', String? alias}) => {
  'user_id': id,
  'nickname': nickname,
  'avatar_url': null,
  'alias': alias,
  'group_nickname': alias,
  'role': role,
  'joined_at': '2026-09-01T00:00:00.000Z',
};

Map<String, dynamic> _room({required String myRole, String? myAlias}) => {
  'room_id': 2,
  'type': 'group',
  'name': '讀書會',
  'avatar_url': null,
  'created_by': 3,
  'my_role': myRole,
  'members': [_member(1, '我自己', role: myRole, alias: myAlias), _member(2, '甲'), _member(3, '團主', role: 'owner')],
  'partner': null,
  'muted': false,
  'pinned': false,
};

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

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiService.authToken = 'token';
    ApiService.currentUser = User.fromJson({
      'user_id': 1,
      'nickname': '我自己',
      'email': 'me@example.com',
      'role': 'buyer_seller',
      'created_at': '2026-09-01T00:00:00.000Z',
    });
  });

  testWidgets('一般成員可設定自己的群組暱稱，但不能設定其他成員', (tester) async {
    tester.view.physicalSize = const Size(390, 1400) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final requests = <String>[];
    Object? sentBody;
    String? myAlias;

    await http.runWithClient(
      () async {
        await tester.pumpWidget(_host(const ChatRoomSettingsScreen(roomId: 2)));
        await _settle(tester);

        await tester.tap(find.text('我自己'));
        await _settle(tester);
        expect(find.text('我在群組的暱稱'), findsOneWidget);
        expect(find.text('群組內所有成員皆會看到此暱稱'), findsOneWidget);
        await tester.enterText(find.byType(TextField).last, '讀書會小幫手');
        await tester.tap(find.text(S.actionSave).last);
        await _settle(tester);

        expect(requests, contains('PUT /api/chat/groups/2/members/1/nickname'));
        expect(sentBody, {'nickname': '讀書會小幫手'});
        expect(find.text('讀書會小幫手'), findsOneWidget);

        await tester.pump(const Duration(seconds: 4));
        await tester.tap(find.text('甲'));
        await _settle(tester);
        expect(find.text('設定群組暱稱'), findsNothing);
        expect(find.text(S.setNickname), findsNothing);
        await tester.pump(const Duration(seconds: 4));
      },
      () => MockClient((request) async {
        requests.add('${request.method} ${request.url.path}');
        if (request.method == 'PUT') {
          sentBody = jsonDecode(request.body);
          myAlias = (sentBody as Map)['nickname'] as String?;
        }
        return http.Response(
          jsonEncode({'success': true, 'data': _room(myRole: 'member', myAlias: myAlias)}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
  });

  testWidgets('管理員可從成員選單設定其他成員的群組暱稱', (tester) async {
    tester.view.physicalSize = const Size(390, 1400) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await http.runWithClient(
      () async {
        await tester.pumpWidget(_host(const ChatRoomSettingsScreen(roomId: 2)));
        await _settle(tester);
        await tester.tap(find.text('甲'));
        await _settle(tester);
        expect(find.text('設定群組暱稱'), findsOneWidget);
        await tester.tap(find.text('設定群組暱稱'));
        await _settle(tester);
        expect(find.text('群組內所有成員皆會看到此暱稱'), findsOneWidget);
        await tester.pump(const Duration(seconds: 4));
      },
      () => MockClient(
        (request) async => http.Response(
          jsonEncode({'success': true, 'data': _room(myRole: 'owner')}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
  });
}
