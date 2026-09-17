import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:savemybook_app/features/admin/admin_level_edit_screen.dart';
import 'package:savemybook_app/features/admin/admin_level_screen.dart';
import 'package:savemybook_app/features/admin/level_rules.dart';
import 'package:savemybook_app/i18n/app_localizations.dart';
import 'package:savemybook_app/i18n/strings.dart';
import 'package:savemybook_app/models/admin_models.dart';
import 'package:savemybook_app/models/user.dart';
import 'package:savemybook_app/services/api_service.dart';
import 'package:savemybook_app/services/locale_provider.dart';
import 'package:savemybook_app/utils/app_theme.dart';

Map<String, dynamic> _json(int id, String name, int min, {int members = 0, String benefits = ''}) =>
    {'level_id': id, 'level_name': name, 'min_points': min, 'benefits': benefits, 'member_count': members};

AdminLevel _level(int id, String name, int min, {int members = 0}) =>
    AdminLevel.fromJson(_json(id, name, min, members: members));

final _levels = [
  _level(1, '一般會員', 0, members: 30),
  _level(2, '白銀會員', 100, members: 12),
  _level(3, '黃金會員', 500, members: 4),
];

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
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

void main() {
  group('LevelRules', () {
    test('名稱不可空白或與其他等級重複（不分大小寫），編輯時可保留原名', () {
      final levels = [..._levels, _level(4, 'VIP', 900)];
      expect(LevelRules.nameError('  ', levels), S.enterTierName);
      expect(LevelRules.nameError(' 白銀會員 ', levels), S.tierNamedP0AlreadyExists('白銀會員'));
      expect(LevelRules.nameError('vip', levels), isNotNull);
      expect(LevelRules.nameError('白銀會員', levels, editingId: 2), isNull);
      expect(LevelRules.nameError('鑽石會員', levels), isNull);
    });

    test('門檻須為不重複的整數，且保留 0 點的起始等級', () {
      expect(LevelRules.pointsError('', _levels), S.enterPointsThreshold);
      expect(LevelRules.pointsError('100000001', _levels), S.thresholdCannotExceedP0(LevelRules.maxPoints));
      expect(LevelRules.pointsError('500', _levels), S.p0AlreadyUsesP1PtsEach('黃金會員', 500));
      expect(LevelRules.pointsError('500', _levels, editingId: 3), isNull);
      expect(LevelRules.pointsError('300', _levels), isNull);
      expect(LevelRules.pointsError('50', _levels, editingId: 1), S.startingTierMustBegin0Pts);
      expect(LevelRules.pointsError('50', const []), S.startingTierMustBegin0Pts);
      expect(LevelRules.pointsError('0', const []), isNull);
    });

    test('起始等級與第一個等級的門檻鎖定為 0 點', () {
      expect(LevelRules.isThresholdLocked(const []), isTrue);
      expect(LevelRules.isThresholdLocked(_levels, editingId: 1), isTrue);
      expect(LevelRules.isThresholdLocked(_levels, editingId: 2), isFalse);
      expect(LevelRules.isThresholdLocked(_levels), isFalse);
    });

    test('預覽階梯依草稿門檻排序並推算點數區間', () {
      final ladder = LevelRules.ladder(_levels, name: '青銅會員', points: 50);
      expect(ladder.map((s) => s.name), ['一般會員', '青銅會員', '白銀會員', '黃金會員']);
      expect(ladder.map((s) => s.maxPoints), [49, 99, 499, null]);
      expect(ladder[1].isDraft, isTrue);

      final moved = LevelRules.ladder(_levels, editingId: 2, name: '白銀會員', points: 800);
      expect(moved.map((s) => s.name), ['一般會員', '黃金會員', '白銀會員']);
      expect(LevelRules.rangeLabel(0, 99), S.p0P1Pts(0, 99));
      expect(LevelRules.rangeLabel(500, null), S.p0Pts(500));
    });

    test('刪除：起始等級不可刪，其他等級的會員改列較低等級', () {
      expect(LevelRules.deleteBlockReason(_levels[0], _levels), S.startingTierCannotDeletedSetAnother);
      expect(LevelRules.deleteBlockReason(_levels[0], [_levels[0]]), isNull);
      expect(LevelRules.deleteBlockReason(_levels[2], _levels), isNull);
      expect(LevelRules.fallbackAfterDelete(_levels[2], _levels)?.name, '白銀會員');
      expect(LevelRules.fallbackAfterDelete(_levels[1], _levels)?.name, '一般會員');
    });

    test('調整順序時門檻依位置保留', () {
      final reordered = [_levels[0], _levels[2], _levels[1]];
      final changes = LevelRules.reorderChanges(_levels, reordered);
      expect(changes.map((c) => '${c.level.name}:${c.from}->${c.to}'), ['黃金會員:500->100', '白銀會員:100->500']);
      expect(LevelRules.reorderChanges(_levels, _levels), isEmpty);
    });
  });

  group('後台會員等級畫面', () {
    late List<String> requests;
    late List<Map<String, dynamic>> bodies;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      ApiService.authToken = 'token';
      ApiService.currentUser = User.fromJson({'user_id': 9, 'nickname': 'A', 'email': 'a@x.com', 'role': 'admin'});
      requests = [];
      bodies = [];
    });

    MockClient api() => MockClient((req) async {
          requests.add('${req.method} ${req.url.path.replaceFirst('/api', '')}');
          if (req.body.isNotEmpty) bodies.add(jsonDecode(req.body) as Map<String, dynamic>);
          Object? data;
          if (req.method == 'GET') {
            data = [
              _json(1, '一般會員', 0, members: 30),
              _json(2, '白銀會員', 100, members: 12, benefits: '免運\n專屬客服'),
              _json(3, '黃金會員', 500, members: 4),
            ];
          } else if (req.method == 'DELETE') {
            data = {'moved_members': 12, 'moved_to': '一般會員'};
          }
          return http.Response(jsonEncode({'success': true, 'data': data}), 200,
              headers: {'content-type': 'application/json'});
        });

    testWidgets('總覽顯示各等級人數與區間；刪除前說明會員改列的等級', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(_host(const AdminLevelScreen()));
        await _settle(tester);

        expect(find.text('46 ${S.members4}', findRichText: true), findsOneWidget);
        expect(find.text(S.p0P1Pts(100, 499)), findsOneWidget);
        expect(find.text(S.p0Pts(500)), findsOneWidget);
        expect(find.text('免運・專屬客服'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.more_horiz_rounded).at(0));
        await _settle(tester);
        await tester.tap(find.text(S.actionDelete).last);
        await _settle(tester);
        expect(requests.where((r) => r.startsWith('DELETE')), isEmpty, reason: '起始等級不可刪除');
        expect(find.text(S.startingTierCannotDeletedSetAnother), findsOneWidget);

        await tester.pump(const Duration(seconds: 4));
        await tester.tap(find.byIcon(Icons.more_horiz_rounded).at(1));
        await _settle(tester);
        await tester.tap(find.text(S.actionDelete).last);
        await _settle(tester);
        expect(
          find.text(S.p0CurrentlyP1MembersAfterDeletion('白銀會員', 12, '一般會員')),
          findsOneWidget,
        );
        await tester.tap(find.text(S.actionDelete).last);
        await _settle(tester);
        expect(requests, contains('DELETE /admin/levels/2'));
        await tester.pump(const Duration(seconds: 4));
      }, api);
    });

    testWidgets('編輯頁：即時檢查重名與門檻，預覽會員看到的樣式，未儲存離開需確認', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(_host(Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AdminLevelEditScreen(levels: _levels)),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        )));
        await tester.pump();
        await tester.tap(find.text('open'));
        await _settle(tester);

        final fields = find.byType(TextField);
        await tester.enterText(fields.at(0), '黃金會員');
        await tester.enterText(fields.at(1), '100');
        await tester.enterText(fields.at(2), '生日禮\n免運');
        await _settle(tester);

        expect(find.text(S.tierNamedP0AlreadyExists('黃金會員')), findsOneWidget);
        expect(find.text(S.p0AlreadyUsesP1PtsEach('白銀會員', 100)), findsOneWidget);
        expect(find.text('生日禮'), findsOneWidget, reason: '預覽即時顯示福利');

        await tester.tap(find.text(S.actionSave));
        await _settle(tester);
        expect(requests.where((r) => r.startsWith('POST')), isEmpty);

        await tester.enterText(fields.at(0), '鑽石會員');
        await tester.enterText(fields.at(1), '2000');
        await _settle(tester);
        expect(find.text(S.p0Pts(2000)), findsWidgets);

        await Navigator.of(tester.element(find.byType(AdminLevelEditScreen))).maybePop();
        await _settle(tester);
        expect(find.text(S.discardChanges), findsOneWidget);
        await tester.tap(find.text(S.keepEditing));
        await _settle(tester);

        await tester.ensureVisible(find.text(S.actionSave));
        await tester.tap(find.text(S.actionSave));
        await _settle(tester);
        expect(requests, contains('POST /admin/levels'));
        expect(bodies.last, {'level_name': '鑽石會員', 'min_points': 2000, 'benefits': '生日禮\n免運'});
        expect(find.byType(AdminLevelEditScreen), findsNothing);
      }, api);
    });
  });
}
