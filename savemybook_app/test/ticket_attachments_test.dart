import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:savemybook_app/features/account/support_ticket_screen.dart';
import 'package:savemybook_app/features/account/ticket_attachments.dart';
import 'package:savemybook_app/i18n/app_localizations.dart';
import 'package:savemybook_app/i18n/strings.dart';
import 'package:savemybook_app/models/support.dart';
import 'package:savemybook_app/models/user.dart';
import 'package:savemybook_app/services/api_service.dart';
import 'package:savemybook_app/services/locale_provider.dart';
import 'package:savemybook_app/utils/app_theme.dart';
import 'package:savemybook_app/widgets/image_viewer.dart';

class _FakeUploads {
  final pending = <String, Completer<(String?, String?)>>{};
  final progress = <String, ValueChanged<double>>{};
  final calls = <String>[];

  Future<(String?, String?)> upload(String path, ValueChanged<double> onProgress) {
    calls.add(path);
    progress[path] = onProgress;
    return (pending[path] = Completer()).future;
  }

  void succeed(String path) => pending[path]!.complete(('/uploads/support/${path.split('/').last}', null));
  void fail(String path, [String message = '上傳失敗']) => pending[path]!.complete((null, message));
}

Future<String?> _identity(String path) async => path;

Future<int> _size(String path) async => 2048;

Finder _label(String text) => find.byWidgetPredicate((w) => w is Semantics && w.properties.label == text);

Future<void> _flush() => Future<void>.delayed(Duration.zero);

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

const _now = '2026-09-17T08:00:00.000Z';

void main() {
  group('TicketAttachmentController', () {
    test('逐張上傳並回報進度，網址依加入順序排列', () async {
      final uploads = _FakeUploads();
      final controller = TicketAttachmentController(uploader: uploads.upload, preparer: _identity, sizeOf: _size);
      final progress = <double>[];
      controller.addListener(() {
        if (controller.items.isNotEmpty) progress.add(controller.items.first.progress);
      });

      final done = controller.add(['/tmp/a.jpg', '/tmp/b.jpg']);
      await _flush();
      await _flush();
      expect(controller.isUploading, isTrue);
      expect(controller.isReady, isFalse);

      uploads.progress['/tmp/a.jpg']!(0.5);
      expect(progress, contains(0.5));

      uploads.succeed('/tmp/b.jpg');
      uploads.succeed('/tmp/a.jpg');
      await done;

      expect(controller.isReady, isTrue);
      expect(controller.urls, ['/uploads/support/a.jpg', '/uploads/support/b.jpg']);
      controller.dispose();
    });

    test('上傳失敗可重試，移除後不再列入', () async {
      final uploads = _FakeUploads();
      final controller = TicketAttachmentController(uploader: uploads.upload, preparer: _identity, sizeOf: _size);

      final done = controller.add(['/tmp/a.jpg', '/tmp/b.jpg']);
      await _flush();
      await _flush();
      uploads.fail('/tmp/a.jpg', '網路異常');
      uploads.succeed('/tmp/b.jpg');
      await done;

      final failed = controller.items.first;
      expect(failed.state, TicketAttachmentState.failed);
      expect(failed.error, '網路異常');
      expect(controller.hasFailed, isTrue);
      expect(controller.isReady, isFalse);

      final retry = controller.retry(failed);
      await _flush();
      await _flush();
      expect(failed.state, TicketAttachmentState.uploading);
      uploads.succeed('/tmp/a.jpg');
      await retry;
      expect(controller.isReady, isTrue);

      controller.remove(controller.items.last);
      expect(controller.urls, ['/uploads/support/a.jpg']);
      controller.dispose();
    });

    test('上傳中移除的圖片完成後不會被加回', () async {
      final uploads = _FakeUploads();
      final controller = TicketAttachmentController(uploader: uploads.upload, preparer: _identity, sizeOf: _size);
      final done = controller.add(['/tmp/a.jpg']);
      await _flush();
      await _flush();
      controller.remove(controller.items.single);
      uploads.succeed('/tmp/a.jpg');
      await done;
      expect(controller.items, isEmpty);
      expect(controller.urls, isEmpty);
      controller.dispose();
    });

    test('每則訊息最多 4 張，無法處理或超過 10 MB 的圖片標示失敗且不上傳', () async {
      final uploads = _FakeUploads();
      final controller = TicketAttachmentController(
        uploader: uploads.upload,
        preparer: (path) async => path.endsWith('.heic') ? null : path,
        sizeOf: (path) async => path == '4.jpg' ? TicketAttachmentController.maxBytes + 1 : 10,
      );
      unawaited(controller.add(['1.jpg', '2.jpg', '3.heic', '4.jpg', '5.jpg', '6.jpg']));
      await _flush();
      await _flush();

      expect(controller.items.length, TicketAttachmentController.maxCount);
      expect(controller.remaining, 0);
      expect(uploads.calls, ['1.jpg', '2.jpg']);
      final heic = controller.items[2];
      expect(heic.state, TicketAttachmentState.failed);
      expect(heic.error, S.imageCouldNotRead);
      expect(controller.items[3].error, S.imagesMust10MbSmaller);
      controller.dispose();
    });
  });

  group('客服工單畫面', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      ApiService.authToken = 'token';
      ApiService.currentUser = User.fromJson({'user_id': 1, 'nickname': '會員', 'email': 'a@x.com', 'role': 'buyer_seller'});
    });

    testWidgets('提出問題：可移除圖片，送出時帶上已上傳的附件', (tester) async {
      final uploads = _FakeUploads();
      final controller = TicketAttachmentController(uploader: uploads.upload, preparer: _identity, sizeOf: _size);
      final sent = <Map<String, dynamic>>[];

      await http.runWithClient(() async {
        await tester.pumpWidget(_host(NewTicketScreen(attachments: controller)));
        await tester.pump(const Duration(milliseconds: 600));

        unawaited(controller.add(['/nonexistent/a.jpg', '/nonexistent/b.jpg']));
        await tester.pump();
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsNWidgets(2));

        uploads.succeed('/nonexistent/a.jpg');
        uploads.fail('/nonexistent/b.jpg');
        await tester.pump();
        await tester.pump();
        expect(_label(S.retryUploadingImageP0(2)), findsOneWidget);

        await tester.enterText(find.byType(TextField).at(0), '無法取件');
        await tester.enterText(find.byType(TextField).at(1), '取件碼輸入後櫃門沒有開啟');
        await tester.pump();

        await tester.tap(find.text(S.actionSubmit));
        await tester.pump();
        expect(sent, isEmpty, reason: '仍有失敗的圖片時不可送出');

        await tester.tap(_label(S.removeImageP0(2)));
        await tester.pump();
        expect(controller.items.length, 1);

        await tester.ensureVisible(find.text(S.actionSubmit));
        await tester.tap(find.text(S.actionSubmit));
        await tester.pump(const Duration(milliseconds: 300));
        expect(sent.single['attachments'], ['/uploads/support/a.jpg']);
        await tester.pump(const Duration(seconds: 3));
      }, () => MockClient((req) async {
            if (req.method == 'POST' && req.url.path == '/api/support/tickets') {
              sent.add(jsonDecode(req.body) as Map<String, dynamic>);
            }
            return http.Response(jsonEncode({'success': true, 'data': {'ticket_id': 3}}), 201,
                headers: {'content-type': 'application/json'});
          }));
    });

    testWidgets('對話顯示附件縮圖，點擊開啟全螢幕檢視；可只傳圖片回覆', (tester) async {
      final uploads = _FakeUploads();
      final controller = TicketAttachmentController(uploader: uploads.upload, preparer: _identity, sizeOf: _size);
      final replies = <Map<String, dynamic>>[];
      final ticket = {
        'ticket_id': 7,
        'subject': '櫃門無法開啟',
        'category': 'cabinet',
        'status': 'pending',
        'message_count': 2,
        'updated_at': _now,
        'messages': [
          {
            'message_id': 1,
            'content': '如附圖',
            'is_staff': false,
            'created_at': _now,
            'sender': {'user_id': 1, 'nickname': '會員'},
            'attachments': [
              {'url': '/api/support/attachments/1-a.jpg?exp=1&sig=x'},
              {'url': '/api/support/attachments/1-b.jpg?exp=1&sig=y'},
            ],
          },
        ],
      };

      await http.runWithClient(() async {
        await tester.pumpWidget(_host(TicketDetailScreen(ticketId: 7, attachments: controller)));
        await tester.pump(const Duration(milliseconds: 600));

        final message = SupportTicket.fromJson(ticket).messages.single;
        expect(message.attachments.first, startsWith('https://'));
        await tester.pump(const Duration(seconds: 2));
        expect(_label(S.viewImageP0(1)), findsOneWidget);
        expect(_label(S.viewImageP0(2)), findsOneWidget);

        await tester.tap(_label(S.viewImageP0(2)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        final viewer = tester.widget<ImageViewer>(find.byType(ImageViewer));
        expect(viewer.imageUrls, message.attachments);
        expect(viewer.initialIndex, 1);
        expect(viewer.allowSave, isTrue);
        Navigator.of(tester.element(find.byType(ImageViewer))).pop();
        await tester.pump(const Duration(milliseconds: 400));

        unawaited(controller.add(['/nonexistent/c.jpg']));
        await tester.pump();
        await tester.pump();
        uploads.succeed('/nonexistent/c.jpg');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        await tester.tap(find.byIcon(Icons.send_rounded));
        await tester.pump(const Duration(milliseconds: 300));
        expect(replies.single, {'content': '', 'attachments': ['/uploads/support/c.jpg']});
        expect(controller.items, isEmpty);
        await tester.pump(const Duration(seconds: 3));
      }, () => MockClient((req) async {
            if (req.method == 'POST') replies.add(jsonDecode(req.body) as Map<String, dynamic>);
            final data = req.method == 'GET' ? ticket : null;
            return http.Response(jsonEncode({'success': true, 'data': data}), 200,
                headers: {'content-type': 'application/json'});
          }));
    });
  });
}
