import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:savemybook_app/features/chat/media/chat_network_image.dart';
import 'package:savemybook_app/utils/api_helpers.dart';
import 'package:savemybook_app/widgets/app_asset_image.dart';
import 'package:savemybook_app/widgets/app_tiles.dart';
import 'package:savemybook_app/widgets/state_views.dart';

/// NetworkImage 只認 debugNetworkImageHttpClientProvider，不受 HttpOverrides 影響，
/// 因此三種情境（404、逾時、成功）都得從這裡注入。
class _FakeHttpClient implements HttpClient {
  final int statusCode;
  final Object? failure;
  int requests = 0;

  _FakeHttpClient({this.statusCode = 404, this.failure});

  @override
  bool autoUncompress = true;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    requests++;
    final error = failure;
    if (error != null) throw error;
    return _FakeHttpClientRequest(url, statusCode);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError('${invocation.memberName}');
}

class _FakeHttpClientRequest implements HttpClientRequest {
  final Uri _url;
  final int _statusCode;

  _FakeHttpClientRequest(this._url, this._statusCode);

  @override
  Uri get uri => _url;

  @override
  final HttpHeaders headers = _FakeHttpHeaders();

  @override
  Future<HttpClientResponse> close() async => _FakeHttpClientResponse(_statusCode);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError('${invocation.memberName}');
}

class _FakeHttpClientResponse implements HttpClientResponse {
  @override
  final int statusCode;

  _FakeHttpClientResponse(this.statusCode);

  @override
  int get contentLength => 0;

  @override
  HttpClientResponseCompressionState get compressionState => HttpClientResponseCompressionState.notCompressed;

  @override
  final HttpHeaders headers = _FakeHttpHeaders();

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.value(Uint8List(0))
        .listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  // NetworkImage 在非 200 時會先 drain 再丟 NetworkImageLoadException；
  // 少了這個實作，錯誤就會變成別的型別而讀不到狀態碼。
  @override
  Future<E> drain<E>([E? futureValue]) async => futureValue as E;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError('${invocation.memberName}');
}

class _FakeHttpHeaders implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

/// debugNetworkImageHttpClientProvider 必須在測試主體結束前還原，
/// flutter_test 會在 tearDown 之前就檢查 painting 的 debug 變數。
Future<void> _withImageClient(_FakeHttpClient client, Future<void> Function() body) async {
  debugNetworkImageHttpClientProvider = () => client;
  try {
    await body();
  } finally {
    debugNetworkImageHttpClientProvider = null;
  }
}

void main() {
  group('resolveAssetUrl', () {
    test('相對路徑接上 API 主機，且不因缺前導斜線而拼錯', () {
      expect(resolveAssetUrl('/uploads/avatars/a.jpg'), '$kApiHost/uploads/avatars/a.jpg');
      expect(resolveAssetUrl('uploads/avatars/a.jpg'), '$kApiHost/uploads/avatars/a.jpg');
      expect(resolveAssetUrl('//uploads/avatars/a.jpg'), 'https://uploads/avatars/a.jpg');
      expect(resolveAssetUrl('  /uploads/books/b.jpg  '), '$kApiHost/uploads/books/b.jpg');
    });

    test('絕對網址與 data URI 原樣保留', () {
      expect(resolveAssetUrl('https://cdn.example.com/a.png'), 'https://cdn.example.com/a.png');
      expect(resolveAssetUrl('http://cdn.example.com/a.png'), 'http://cdn.example.com/a.png');
      expect(resolveAssetUrl('data:image/png;base64,AAAA'), 'data:image/png;base64,AAAA');
    });

    test('空值與非字串內容一律回傳 null', () {
      expect(resolveAssetUrl(null), isNull);
      expect(resolveAssetUrl(''), isNull);
      expect(resolveAssetUrl('   '), isNull);
      expect(resolveAssetUrl('null'), isNull);
      expect(resolveAssetUrl(<String, dynamic>{'image_url': '/uploads/a.jpg'}), isNull);
      expect(resolveAssetUrl(<String>['/uploads/a.jpg']), isNull);
    });
  });

  group('isPermanentImageError', () {
    test('4xx 視為永久性，5xx 與連線錯誤視為暫時性', () {
      final uri = Uri.parse('$kApiHost/uploads/books/a.jpg');
      expect(isPermanentImageError(NetworkImageLoadException(statusCode: 404, uri: uri)), isTrue);
      expect(isPermanentImageError(NetworkImageLoadException(statusCode: 403, uri: uri)), isTrue);
      expect(isPermanentImageError(NetworkImageLoadException(statusCode: 503, uri: uri)), isFalse);
      expect(isPermanentImageError(const SocketException('timeout')), isFalse);
    });
  });

  testWidgets('資產缺失：AppAssetImage 顯示同尺寸替代圖而不丟例外', (tester) async {
    await tester.pumpWidget(_host(
      const AppAssetImage(
        asset: 'assets/images/this-file-does-not-exist.png',
        width: 48,
        height: 48,
        fallbackIcon: Icons.menu_book_rounded,
      ),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.menu_book_rounded), findsOneWidget);
    expect(tester.getSize(find.byType(AppAssetImage)), const Size(48, 48));
  });

  testWidgets('網路 404：AppNetworkImage 顯示替代圖、不自動重試也不給重試入口', (tester) async {
    final client = _FakeHttpClient(statusCode: 404);
    await _withImageClient(client, () async {
      await tester.pumpWidget(_host(
        const SizedBox(
          width: 240,
          height: 240,
          child: AppNetworkImage(url: 'https://api.savemybook.today/uploads/books/missing.jpg'),
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.menu_book_rounded), findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsNothing);

      // 自動重試視窗（3 秒 + 10 秒）全部走完仍不得再打伺服器。
      await tester.pump(const Duration(seconds: 20));
      expect(client.requests, 1);
    });
  });

  testWidgets('網路逾時：AppNetworkImage 有限次自動重試後停在可重試的替代圖', (tester) async {
    final client = _FakeHttpClient(failure: const SocketException('timeout'));
    await _withImageClient(client, () async {
      await tester.pumpWidget(_host(
        const SizedBox(
          width: 240,
          height: 240,
          child: AppNetworkImage(url: 'https://api.savemybook.today/uploads/books/slow.jpg'),
        ),
      ));
      await tester.pumpAndSettle();
      expect(client.requests, 1);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(client.requests, 2);

      await tester.pump(const Duration(seconds: 11));
      await tester.pumpAndSettle();
      expect(client.requests, 3);

      // 第三次之後必須停手，不能無限重試。
      await tester.pump(const Duration(seconds: 60));
      await tester.pumpAndSettle();
      expect(client.requests, 3);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byIcon(Icons.refresh_rounded));
      await tester.pumpAndSettle();
      expect(client.requests, 4);

      await tester.pump(const Duration(seconds: 60));
      await tester.pumpAndSettle();
    });
  });

  testWidgets('大頭貼 404：UserAvatar 退回預設人像且不再重試', (tester) async {
    final client = _FakeHttpClient(statusCode: 404);
    await _withImageClient(client, () async {
      await tester.pumpWidget(_host(
        const UserAvatar(imageUrl: 'https://api.savemybook.today/uploads/avatars/gone.jpg', radius: 24),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.person), findsOneWidget);

      await tester.pump(const Duration(seconds: 30));
      expect(client.requests, 1);
    });
  });

  testWidgets('聊天圖片 404：ChatNetworkImage 顯示替代圖且不提供重試', (tester) async {
    final client = _FakeHttpClient(statusCode: 404);
    await _withImageClient(client, () async {
      await tester.pumpWidget(_host(
        const ChatNetworkImage(
          url: 'https://api.savemybook.today/uploads/chat/gone.jpg',
          width: 140,
          height: 104,
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsNothing);
    });
  });
}
