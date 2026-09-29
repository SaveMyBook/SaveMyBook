import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:savemybook_app/features/admin/admin_dispute_screen.dart';
import 'package:savemybook_app/features/admin/admin_image_strip.dart';
import 'package:savemybook_app/features/admin/reported_message_panel.dart';
import 'package:savemybook_app/i18n/app_localizations.dart';
import 'package:savemybook_app/i18n/strings.dart';
import 'package:savemybook_app/models/admin_models.dart';
import 'package:savemybook_app/services/api_service.dart';
import 'package:savemybook_app/services/locale_provider.dart';
import 'package:savemybook_app/utils/api_helpers.dart';
import 'package:savemybook_app/utils/app_theme.dart';

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

http.Response _json(Object body) =>
    http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json; charset=utf-8'});

Map<String, dynamic> _message(int id, {String kind = 'text', String? body, String nickname = '傳送者'}) => {
  'message_id': id,
  'sender_id': 7,
  'content': body ?? (kind == 'recalled' ? '[recalled]' : ''),
  'message_type': kind == 'image' ? 'image' : (kind == 'text' ? 'text' : 'system'),
  'kind': kind,
  'body': body,
  'payload': null,
  'created_at': '2026-09-29T02:00:00.000Z',
  'edited_at': null,
  'users': {'user_id': 7, 'nickname': nickname, 'avatar_url': null},
  'sender_no': 'MB3KER74B',
};

Map<String, dynamic> _dispute({List<Object?>? evidence}) => {
  'dispute_id': 1,
  'order_id': 2,
  'reason': '書況與描述不符',
  'status': 'pending',
  'created_at': '2026-09-29T02:00:00.000Z',
  'users_transaction_disputes_applicant_idTousers': {'user_id': 3, 'nickname': '買家'},
  'orders': {
    'order_id': 2,
    'order_no': 'SMB20260929000001',
    'total_amount': 120,
    'users_orders_buyer_idTousers': {'user_id': 3, 'nickname': '買家'},
    'users_orders_seller_idTousers': {'user_id': 4, 'nickname': '賣家'},
    'order_items': <Object>[],
  },
  'evidence_images': ?evidence,
};

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUp(() => ApiService.authToken = 'token');

  test('爭議案件解析佐證照片為完整網址，略過空值；舊版回應沒有此欄位時為空清單', () {
    final dispute = DisputeCase.fromJson(_dispute(evidence: ['/uploads/evidence/a.jpg', null, '', '/uploads/evidence/b.png']));
    expect(dispute.evidenceImages, [resolveAssetUrl('/uploads/evidence/a.jpg'), resolveAssetUrl('/uploads/evidence/b.png')]);
    expect(DisputeCase.fromJson(_dispute()).evidenceImages, isEmpty);
  });

  test('訊息檢舉以訊息內容為標題，圖片訊息以圖片為縮圖，收回與刪除的訊息顯示中性文字', () {
    ReportCase report(Map<String, dynamic>? target) => ReportCase.fromJson({
      'report_id': 1,
      'target_type': 'message',
      'target_id': 5,
      'reason': '訊息內容不當',
      'status': 'pending',
      'target': target,
    });

    final text = report(_message(5, body: '請改用站外匯款'));
    expect(text.targetTitle, '請改用站外匯款');
    expect(text.message?.senderNo, 'MB3KER74B');
    expect(text.targetImageUrl, isNull);

    final image = report(_message(5, kind: 'image', body: '/uploads/chat/c.jpg'));
    expect(image.targetImageUrl, resolveAssetUrl('/uploads/chat/c.jpg'));

    final recalled = report(_message(5, kind: 'recalled'));
    expect(recalled.message?.message.isRecalled, isTrue);
    expect(recalled.targetTitle, S.messageUnsent);

    final gone = report(null);
    expect(gone.message, isNull);
    expect(gone.targetTitle, S.noLongerExists);
  });

  testWidgets('被檢舉訊息標示傳送者與加密編號，並載入前後文；收回的訊息顯示中性提示，圖片訊息顯示圖片', (tester) async {
    final requests = <String>[];
    await http.runWithClient(
      () async {
        await tester.pumpWidget(_host(Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ReportedMessagePanel(reportId: 4, message: ReportedMessage.fromJson(_message(5, body: '請改用站外匯款'))),
          ),
        )));
        await _settle(tester);
      },
      () => MockClient((request) async {
        requests.add('${request.method} ${request.url.path}');
        return _json({
          'success': true,
          'data': {
            'before': [_message(3, body: '請問這本書還在嗎', nickname: '檢舉人'), _message(4, kind: 'recalled')],
            'after': [_message(6, kind: 'image', body: '/uploads/chat/d.jpg')],
          },
        });
      }),
    );

    expect(requests, ['GET /api/admin/reports/4/message-context']);
    expect(find.text('被檢舉訊息'), findsOneWidget);
    expect(find.text('請改用站外匯款'), findsOneWidget);
    expect(find.textContaining('傳送者・MB3KER74B'), findsOneWidget);
    expect(find.text('請問這本書還在嗎'), findsOneWidget);
    expect(find.text('訊息已收回'), findsOneWidget);
    expect(find.byType(AdminImageStrip), findsOneWidget);
    expect(find.textContaining('#'), findsNothing, reason: '不顯示流水號');
  });

  testWidgets('爭議案件列出申請方上傳的佐證照片', (tester) async {
    await http.runWithClient(
      () async {
        await tester.pumpWidget(_host(const AdminDisputeScreen()));
        await _settle(tester);
      },
      () => MockClient((request) async => _json({
            'success': true,
            'data': [_dispute(evidence: ['/uploads/evidence/a.jpg', '/uploads/evidence/b.png'])],
          })),
    );

    expect(find.text('佐證照片'), findsOneWidget);
    final strip = tester.widget<AdminImageStrip>(find.byType(AdminImageStrip));
    expect(strip.urls, [resolveAssetUrl('/uploads/evidence/a.jpg'), resolveAssetUrl('/uploads/evidence/b.png')]);
  });
}
