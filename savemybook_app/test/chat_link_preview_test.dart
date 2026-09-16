import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:savemybook_app/features/chat/media/chat_network_image.dart';
import 'package:savemybook_app/features/chat/widgets/chat_link_preview.dart';
import 'package:savemybook_app/models/chat.dart';
import 'package:savemybook_app/models/link_preview.dart';
import 'package:savemybook_app/services/api_service.dart';
import 'package:savemybook_app/utils/app_theme.dart';
import 'package:savemybook_app/widgets/state_views.dart';

const bookToken = '0123456789abcdef0123456789abcdef';

final webWithImage = LinkPreview.tryParse({
  'url': 'https://blog.example.com/pricing',
  'site_name': '書店部落格',
  'title': '二手書交易指南',
  'description': '如何為舊書訂出合理價格',
  'image_url': '/api/chat/link-preview/image?u=abc.def',
  'kind': 'web',
})!;

final webWithoutImage = LinkPreview.tryParse({
  'url': 'https://docs.example.com/notes',
  'site_name': 'docs.example.com',
  'title': '讀書會筆記',
  'description': null,
  'image_url': null,
  'kind': 'web',
})!;

final bookPreview = LinkPreview.tryParse({
  'url': 'https://api.savemybook.today/b/$bookToken',
  'site_name': '救「舊」我的書',
  'title': '深入淺出統計學',
  'description': '王大明',
  'image_url': '/uploads/books/cover.jpg',
  'kind': 'book',
  'price': 350,
})!;

Widget host(Widget child, {Brightness brightness = Brightness.light}) => MaterialApp(
      theme: AppTheme.build(brightness),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  setUp(() {
    LinkPreviewStore.clear();
    ApiService.authToken = 'test-token';
  });

  group('firstUrl', () {
    test('picks the first web link and ignores phone numbers', () {
      expect(LinkPreviewStore.firstUrl('電話 0912-345-678，網址 https://a.example.com/x 與 https://b.example.com'), 'https://a.example.com/x');
      expect(LinkPreviewStore.firstUrl('0912345678'), isNull);
      expect(LinkPreviewStore.firstUrl('沒有連結'), isNull);
    });

    test('adds https to www links and trims trailing punctuation', () {
      expect(LinkPreviewStore.firstUrl('看看 www.example.com/page.'), 'https://www.example.com/page');
      expect(LinkPreviewStore.firstUrl('(https://example.com/a)'), 'https://example.com/a');
      expect(LinkPreviewStore.firstUrl('https://en.wikipedia.org/wiki/Foo_(bar)'), 'https://en.wikipedia.org/wiki/Foo_(bar)');
      expect(LinkPreviewStore.firstUrl('請看https://example.com/a，謝謝'), 'https://example.com/a');
      expect(LinkPreviewStore.firstUrl('https://example.com/a。'), 'https://example.com/a');
    });

    test('skips links inside mentions and hosts without a dot', () {
      const text = '@https://x.example.com hi https://y.example.com';
      expect(LinkPreviewStore.firstUrl(text, mentions: const [ChatMention(userId: 2, start: 0, length: 22)]), 'https://y.example.com');
      expect(LinkPreviewStore.firstUrl('http://localhost/abc'), isNull);
    });
  });

  group('LinkPreviewStore', () {
    test('merges concurrent loads and caches settled results including null', () async {
      var calls = 0;
      final gate = Completer<void>();
      LinkPreviewStore.fetcher = (url) async {
        calls++;
        await gate.future;
        return (preview: url.contains('none') ? null : webWithImage, settled: true);
      };
      final a = LinkPreviewStore.load('https://blog.example.com/pricing');
      final b = LinkPreviewStore.load('https://blog.example.com/pricing');
      gate.complete();
      expect((await a)?.title, webWithImage.title);
      expect((await b)?.title, webWithImage.title);
      expect(calls, 1);
      expect(LinkPreviewStore.has('https://blog.example.com/pricing'), isTrue);

      expect(await LinkPreviewStore.load('https://none.example.com'), isNull);
      expect(await LinkPreviewStore.load('https://none.example.com'), isNull);
      expect(calls, 2);
    });

    test('does not cache failures and waits before retrying', () async {
      var calls = 0;
      LinkPreviewStore.fetcher = (url) async {
        calls++;
        return (preview: null, settled: false);
      };
      expect(await LinkPreviewStore.load('https://down.example.com'), isNull);
      expect(await LinkPreviewStore.load('https://down.example.com'), isNull);
      expect(LinkPreviewStore.has('https://down.example.com'), isFalse);
      expect(calls, 1);
    });

    test('API client maps responses to settled and unsettled results', () async {
      Future<({LinkPreview? preview, bool settled})> call(int status, Object body) => http.runWithClient(
            () => ApiService().fetchLinkPreview('https://blog.example.com/pricing'),
            () => MockClient((request) async {
              expect(request.url.path, '/api/chat/link-preview');
              expect(request.url.queryParameters['url'], 'https://blog.example.com/pricing');
              return http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});
            }),
          );

      final ok = await call(200, {'success': true, 'data': {'url': 'https://blog.example.com/pricing', 'site_name': 'x', 'title': 'T', 'kind': 'web'}});
      expect(ok.settled, isTrue);
      expect(ok.preview?.title, 'T');
      final none = await call(200, {'success': true, 'data': null});
      expect((none.settled, none.preview), (true, null));
      final limited = await call(429, {'success': false, 'code': 'RATE_LIMITED', 'message': 'x'});
      expect(limited.settled, isFalse);
    });
  });

  group('LinkPreview model', () {
    test('parses book token and resolves asset urls', () {
      expect(bookPreview.isBook, isTrue);
      expect(bookPreview.bookToken, bookToken);
      expect(bookPreview.imageUrl, 'https://api.savemybook.today/uploads/books/cover.jpg');
      expect(webWithImage.imageUrl, 'https://api.savemybook.today/api/chat/link-preview/image?u=abc.def');
      expect(webWithImage.isBook, isFalse);
      expect(LinkPreview.tryParse({'url': 'https://x.example.com', 'title': ''}), isNull);
      expect(LinkPreview.tryParse(null), isNull);
    });
  });

  group('card', () {
    testWidgets('web preview with image loads the proxied image with credentials', (tester) async {
      await tester.pumpWidget(host(ChatLinkPreviewView(preview: webWithImage, isMine: false, width: 260)));
      expect(find.text('書店部落格'), findsOneWidget);
      expect(find.text('二手書交易指南'), findsOneWidget);
      expect(find.text('如何為舊書訂出合理價格'), findsOneWidget);
      final image = tester.widget<ChatNetworkImage>(find.byType(ChatNetworkImage));
      expect(image.headers, {'Authorization': 'Bearer test-token'});
      expect(tester.widget<AspectRatio>(find.byType(AspectRatio)).aspectRatio, 1.91);
      expect(tester.getSize(find.byType(ChatLinkPreviewView)).width, 260);
    });

    testWidgets('web preview without image shows text only', (tester) async {
      await tester.pumpWidget(host(ChatLinkPreviewView(preview: webWithoutImage, isMine: true, width: 260)));
      expect(find.byType(ChatNetworkImage), findsNothing);
      expect(find.text('讀書會筆記'), findsOneWidget);
    });

    testWidgets('book preview shows cover, title and price', (tester) async {
      await tester.pumpWidget(host(ChatLinkPreviewView(preview: bookPreview, isMine: false, width: 260)));
      expect(find.byType(BookThumbnail), findsOneWidget);
      expect(find.text('深入淺出統計學'), findsOneWidget);
      expect(find.text('\$350'), findsOneWidget);
      expect(find.byType(ChatNetworkImage), findsNothing);
    });

    testWidgets('null preview renders nothing', (tester) async {
      LinkPreviewStore.fetcher = (url) async => (preview: null, settled: true);
      await tester.pumpWidget(host(const ChatLinkPreviewCard(url: 'https://none.example.com', isMine: false, width: 260)));
      await tester.pumpAndSettle();
      expect(find.byType(ChatLinkPreviewView), findsNothing);
      expect(tester.getSize(find.byType(ChatLinkPreviewCard)), Size.zero);
    });

    testWidgets('expands once loaded and reuses the cache without refetching', (tester) async {
      var calls = 0;
      LinkPreviewStore.fetcher = (url) async {
        calls++;
        return (preview: webWithoutImage, settled: true);
      };
      await tester.pumpWidget(host(const ChatLinkPreviewCard(url: 'https://docs.example.com/notes', isMine: false, width: 260)));
      expect(find.byType(ChatLinkPreviewView), findsNothing);
      await tester.pumpAndSettle();
      expect(find.byType(ChatLinkPreviewView), findsOneWidget);

      await tester.pumpWidget(host(const SizedBox()));
      await tester.pumpWidget(host(const ChatLinkPreviewCard(url: 'https://docs.example.com/notes', isMine: false, width: 260)));
      expect(find.byType(ChatLinkPreviewView), findsOneWidget, reason: '快取命中時應立即顯示');
      expect(calls, 1);
    });

    testWidgets('tapping a web preview opens the link in the in-app browser', (tester) async {
      LinkPreviewStore.fetcher = (url) async => (preview: webWithoutImage, settled: true);
      Uri? opened;
      ChatLinkPreviewCard.openUrl = (uri) async {
        opened = uri;
        return true;
      };
      await tester.pumpWidget(host(const ChatLinkPreviewCard(url: 'https://docs.example.com/notes', isMine: false, width: 260)));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ChatLinkPreviewView));
      await tester.pumpAndSettle();
      expect(opened, Uri.parse('https://docs.example.com/notes'));
    });

    testWidgets('tapping a removed book shows a notice instead of opening', (tester) async {
      LinkPreviewStore.fetcher = (url) async => (preview: bookPreview, settled: true);
      String? requested;
      await http.runWithClient(() async {
        await tester.pumpWidget(host(ChatLinkPreviewCard(url: bookPreview.url, isMine: true, width: 260)));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(ChatLinkPreviewView));
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }, () => MockClient((request) async {
            requested = request.url.path;
            return http.Response(jsonEncode({'success': false, 'message': '找不到此書籍'}), 404, headers: {'content-type': 'application/json'});
          }));
      expect(requested, '/api/books/share/$bookToken');
      expect(find.byType(ChatLinkPreviewView), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
