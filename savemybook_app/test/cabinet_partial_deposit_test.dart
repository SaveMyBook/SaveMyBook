import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:savemybook_app/features/cabinet/cabinet_flow_screen.dart';
import 'package:savemybook_app/features/cabinet/cabinet_messages.dart';
import 'package:savemybook_app/i18n/app_localizations.dart';
import 'package:savemybook_app/i18n/strings.dart';
import 'package:savemybook_app/models/cabinet.dart';
import 'package:savemybook_app/models/user.dart';
import 'package:savemybook_app/services/api_service.dart';
import 'package:savemybook_app/services/locale_provider.dart';
import 'package:savemybook_app/utils/app_theme.dart';

const _zhHant = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');
const _note = {'code': 'DEPOSIT_PARTIAL', 'message': '可用櫃門不足，本次僅能存入部分書籍，其餘書籍待有空櫃門時再存入'};

Map<String, dynamic> _orderItem({List<String?> doors = const [null, null], String result = 'pending', Map<String, Object>? note = _note}) => {
  'key': 'order:129',
  'kind': 'order_deposit',
  'order_id': 129,
  'order_no': 'SMB20260928143015123456',
  'books': [
    {'book_id': 56, 'title': '作業系統', 'image_url': null, 'door': doors[0]},
    {'book_id': 57, 'title': '計算機網路', 'image_url': null, 'door': doors[1]},
  ],
  'doors': [for (final door in doors) ?door],
  'paused': false,
  'note': note,
  'selected': true,
  'blocked': null,
  'result': result,
  'error': null,
};

Map<String, dynamic> _session({required String status, required Map<String, dynamic> item, Map<String, dynamic>? result}) => {
  'session_no': 'CS8MZQ41K',
  'status': status,
  'version': 5,
  'cabinet': {'cabinet_id': 3, 'cabinet_name': '北商大書櫃', 'address': '台北市中正區', 'open_time': '08:00', 'close_time': '22:00'},
  'location_status': 'granted',
  'distance_m': 12,
  'items': [item],
  'doors': const [],
  'remaining_ms': status == 'selecting' ? 52000 : null,
  'open_ms': null,
  'notice': null,
  'result': result,
  'created_at': '2026-09-29T10:00:00.000Z',
  'finished_at': status == 'completed' ? '2026-09-29T10:01:00.000Z' : null,
};

CabinetSessionItem _parse(Map<String, dynamic> item) => CabinetSessionItem.fromJson(item);

Widget _host(Widget home) => MaterialApp(
  locale: _zhHant,
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

Future<void> _pump(WidgetTester tester, Map<String, dynamic> session) async {
  tester.view.physicalSize = const Size(390, 844) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_host(CabinetFlowScreen(resume: CabinetSession.fromJson(session))));
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 5));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiService.resetGlobalState();
    ApiService.authToken = 'token';
    ApiService.currentUser = User.fromJson({'user_id': 1, 'nickname': '我', 'email': 'me@example.com', 'role': 'buyer_seller'});
  });

  tearDown(() {
    ApiService.authToken = null;
    ApiService.currentUser = null;
    S = AppLocalizations.fallback;
  });

  group('部分存書訊息', () {
    test('確認項目時說明本次僅能存入部分書籍；完成後顯示已在書櫃中的本數', () {
      S = AppLocalizations.fallback;
      final before = _parse(_orderItem());
      expect(before.isPartialDeposit, isTrue);
      expect(CabinetMessages.note(before.note!, item: before), '可用櫃門不足，本次僅能存入部分書籍，其餘書籍待有空櫃門時再存入');

      final done = _parse(_orderItem(doors: const ['A02', null], result: 'done'));
      expect(CabinetMessages.note(done.note!, item: done), '已存入 1 本，其餘書籍待有空櫃門時再存入');

      final failed = _parse(_orderItem(doors: const ['A02', null], result: 'failed'));
      expect(CabinetMessages.note(failed.note!, item: failed), '可用櫃門不足，本次僅能存入部分書籍，其餘書籍待有空櫃門時再存入');
    });

    test('部分存書完成時標題不提示已通知買家；全部存入時維持原標題', () {
      S = AppLocalizations.fallback;
      final partial = CabinetSession.fromJson(
        _session(status: 'completed', item: _orderItem(doors: const ['A02', null], result: 'done')),
      );
      expect(CabinetMessages.completedTitle(partial), S.dropOffComplete);
      final whole = CabinetSession.fromJson(
        _session(status: 'completed', item: _orderItem(doors: const ['A01', 'A02'], result: 'done', note: null)),
      );
      expect(CabinetMessages.completedTitle(whole), S.dropOffCompleteBuyerBeenNotified);
    });
  });

  testWidgets('確認項目畫面顯示部分存書提示', (tester) async {
    await http.runWithClient(() async {
      await _pump(tester, _session(status: 'selecting', item: _orderItem()));
      expect(find.text(S.orderDropOff), findsOneWidget);
      expect(find.text(S.depositPartialNotice), findsOneWidget);
      await _finish(tester);
    }, () => MockClient((request) async => http.Response(
      jsonEncode({'success': true, 'data': _session(status: 'selecting', item: _orderItem())}),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    )));
  });

  testWidgets('作業完成畫面：部分存書的項目顯示已存入本數與其餘書籍待存入', (tester) async {
    final session = _session(
      status: 'completed',
      item: _orderItem(doors: const ['A02', null], result: 'done'),
      result: {'outcome': 'completed', 'code': 'COMPLETED', 'message': '作業完成'},
    );
    await http.runWithClient(() async {
      await _pump(tester, session);
      expect(find.text(S.dropOffComplete), findsOneWidget);
      expect(find.text(S.dropOffCompleteBuyerBeenNotified), findsNothing);
      expect(find.text(S.depositedP0RemainingLater(1)), findsOneWidget);
      expect(find.text(S.orderCompleted), findsNothing);
      await _finish(tester);
    }, () => MockClient((request) async => http.Response(
      jsonEncode({'success': true, 'data': session}),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    )));
  });
}
