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

import 'package:savemybook_app/features/books/book_detail_screen.dart';
import 'package:savemybook_app/features/cabinet/cabinet_guide_screen.dart';
import 'package:savemybook_app/features/cabinet/cabinet_scanner_view.dart';
import 'package:savemybook_app/features/orders/widgets/sticky_pane.dart';
import 'package:savemybook_app/features/selling/ai_listing_assist.dart';
import 'package:savemybook_app/features/selling/edit_book_screen.dart';
import 'package:savemybook_app/features/selling/sell_book_detail_screen.dart';
import 'package:savemybook_app/features/selling/sell_book_screen.dart';
import 'package:savemybook_app/i18n/app_localizations.dart';
import 'package:savemybook_app/i18n/strings.dart';
import 'package:savemybook_app/models/ai.dart';
import 'package:savemybook_app/models/book.dart';
import 'package:savemybook_app/services/api_service.dart';
import 'package:savemybook_app/services/locale_provider.dart';
import 'package:savemybook_app/services/theme_provider.dart';
import 'package:savemybook_app/utils/app_theme.dart';
import 'package:savemybook_app/widgets/animations.dart';
import 'package:savemybook_app/widgets/app_buttons.dart';
import 'package:savemybook_app/widgets/state_views.dart';

import '../layout_overflow_test.dart' as fixture;

const _landscape = Size(1180, 820);
const _portrait = Size(820, 1180);
const _sizes = [_landscape, _portrait];
final _shotDir = Platform.environment['D_SHOTS'];

Map<String, dynamic> _nearby() => {
  'cabinet': {'latitude': 25.0245, 'longitude': 121.5288},
  'mrt': {
    'status': 'ok',
    'updated_at': '2026-10-02T12:29:04.970Z',
    'stations': [
      {
        'name': '台電大樓',
        'distance_m': 382,
        'nearest_exit': {'exit': '3', 'accessible': false, 'latitude': 25.021179, 'longitude': 121.527849, 'distance_m': 382},
        'accessible_exit': {'exit': '5', 'facility': 'elevator', 'latitude': 25.020758, 'longitude': 121.527739, 'distance_m': 430},
      },
    ],
  },
  'bus': {
    'status': 'ok',
    'updated_at': '2026-10-02T13:02:00.000Z',
    'realtime_available': true,
    'stops': [
      {
        'name': '師大綜合大樓',
        'address': '和平東路一段184號同向(向東)',
        'latitude': 25.026362,
        'longitude': 121.529958,
        'distance_m': 238,
        'routes': [
          {'name': '復興幹線', 'direction': '建北站', 'status': 'arriving', 'minutes': 0},
          {'name': '235', 'direction': '交通部觀光署', 'status': 'minutes', 'minutes': 4},
        ],
      },
    ],
  },
  'road_speed': {'status': 'ok', 'updated_at': null, 'sections': <Object>[]},
  'taxi_stands': {'status': 'ok', 'updated_at': null, 'stands': <Object>[]},
  'youbike': {
    'status': 'ok',
    'updated_at': '2026-10-02T11:50:04.000Z',
    'stations': [
      {'name': '臺灣師範大學(浦城街)', 'address': '浦城街1號對側', 'latitude': 25.02476, 'longitude': 121.52803, 'distance_m': 83, 'available_rent': 19, 'available_return': 0, 'total': 20, 'is_active': true},
    ],
  },
  'parking_lots': {'status': 'ok', 'updated_at': null, 'realtime_available': false, 'lots': <Object>[]},
  'roadside': {'status': 'ok', 'radius_m': 300, 'layer_updated_at': null, 'updated_at': null, 'car': <Object>[], 'motorcycle': <Object>[]},
  'attribution': '資料來源：臺北市資料大平臺（data.taipei）',
  'sources': <Object>[],
};

MockClient _api() {
  final base = fixture.fakeApi();
  return MockClient((request) async {
    if (request.url.path == '/api/cabinets/3/nearby') {
      return http.Response(jsonEncode({'success': true, 'data': _nearby()}), 200, headers: {'content-type': 'application/json; charset=utf-8'});
    }
    final copy = http.Request(request.method, request.url)
      ..headers.addAll(request.headers)
      ..bodyBytes = request.bodyBytes;
    return base.send(copy).then(http.Response.fromStream);
  });
}

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

Future<void> _shot(WidgetTester tester, String name) async {
  final dir = _shotDir;
  if (dir == null) return;
  await tester.runAsync(() async {
    final view = tester.binding.renderViews.first;
    final layer = view.debugLayer! as OffsetLayer;
    final image = await layer.toImage(view.paintBounds);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File('$dir/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

String _label(Size size) => '${size.width.toInt()}x${size.height.toInt()}';

Future<void> _check(
  WidgetTester tester,
  String name,
  Size size,
  Widget Function() screen,
  Future<void> Function(WidgetTester tester, Size size) verify,
) async {
  ApiService.authToken = 'test-token';
  ApiService.currentUser = fixture.testUser;
  final errors = <String>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.exceptionAsString();
    if (text.contains('NetworkImageLoadException') || text.contains('HTTP request failed')) return;
    errors.add(text.split('\n').first);
  };
  tester.view
    ..physicalSize = size * 2
    ..devicePixelRatio = 2
    ..padding = const FakeViewPadding(top: 48, bottom: 40)
    ..viewPadding = const FakeViewPadding(top: 48, bottom: 40);
  addTearDown(tester.view.reset);

  Object? failure;
  await http.runWithClient(() async {
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      supportedLocales: LocaleProvider.supported,
      theme: AppTheme.build(Brightness.dark),
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
      home: screen(),
    ));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    try {
      await verify(tester, size);
    } catch (e) {
      failure = e;
    }
    await _shot(tester, '${name}_${_label(size)}');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  }, _api);

  FlutterError.onError = previous;
  if (failure != null) fail('$failure');
  expect(errors.toSet(), isEmpty, reason: '版面溢出或元件例外');
}

Rect _rect(WidgetTester tester, Finder finder) => tester.getRect(finder.first);

void _expectCentered(WidgetTester tester, Finder finder, Size size) {
  final rect = _rect(tester, finder);
  expect((rect.center.dx - size.width / 2).abs(), lessThan(1), reason: '按鈕應水平置中');
}

Book _book() => Book.fromJson(fixture.book(5));

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    themeProvider = await ThemeProvider.init();
    localeProvider = await LocaleProvider.init();
    if (_shotDir != null) await _loadFonts();
  });

  for (final size in _sizes) {
    final label = _label(size);

    testWidgets('商品詳情 $label：封面在左完整顯示、資訊與購買按鈕在右', (tester) async {
      await _check(tester, 'book_detail', size, () => BookDetailScreen(book: _book()), (tester, size) async {
        if (size == _landscape) expect(find.byType(StickyPane), findsOneWidget);
        final gallery = _rect(tester, find.byWidgetPredicate((w) => w is Hero && w.tag == 'book_image_${_book().bookId}'));
        expect(gallery.width, inInclusiveRange(180, 520));
        final title = _rect(tester, find.descendant(of: find.byType(SingleChildScrollView), matching: find.text(fixture.longTitle)));
        expect(title.left, greaterThan(gallery.right));
        final chat = _rect(tester, find.widgetWithText(OutlinedButton, S.messageSeller));
        expect(chat.left, greaterThan(gallery.right));
      });
    });

    testWidgets('上架第 1 步 $label', (tester) async {
      await _check(tester, 'sell_step1', size, () => const SellBookScreen(), (tester, size) async {
        final isbn = _rect(tester, find.text('ISBN'));
        final title = _rect(tester, find.text('${S.title} *'));
        final next = _rect(tester, find.widgetWithText(PrimaryButton, S.next));
        if (size == _landscape) {
          expect(title.left, greaterThan(isbn.right), reason: '寬螢幕應分左右兩欄');
          expect(next.left, greaterThan(size.width / 2 - 100));
        } else {
          expect(title.left, isbn.left);
        }
        expect(next.width, lessThanOrEqualTo(640));
      });
    });

    testWidgets('上架第 2 步 $label', (tester) async {
      await _check(
        tester,
        'sell_step2',
        size,
        () => const SellBookDetailScreen(
          isbn: '9789571234567',
          title: '統計學概論',
          author: '林志明',
          publisher: '智識出版',
          publishDate: '2022-02-01',
          description: '',
          categoryId: 1,
        ),
        (tester, size) async {
          final photos = _rect(tester, find.text('${S.bookPhotos} *'));
          final condition = _rect(tester, find.text('${S.condition} *'));
          final submit = _rect(tester, find.widgetWithText(PrimaryButton, S.listBook));
          if (size == _landscape) {
            expect(condition.left, greaterThan(photos.left + 300), reason: '寬螢幕照片在左、欄位在右');
          } else {
            expect(condition.top, greaterThan(photos.bottom));
          }
          expect(submit.width, lessThanOrEqualTo(640));
        },
      );
    });

    testWidgets('編輯書籍 $label', (tester) async {
      await _check(tester, 'edit_book', size, () => EditBookScreen(book: _book()), (tester, size) async {
        final isbn = _rect(tester, find.text('ISBN'));
        final next = _rect(tester, find.widgetWithText(PrimaryButton, S.next));
        if (size == _landscape) {
          final preview = _rect(tester, find.byWidgetPredicate((w) => w is BookThumbnail && w.width == 150));
          expect(isbn.left, greaterThan(preview.right));
        }
        expect(next.width, lessThanOrEqualTo(640));
      });
    });

    testWidgets('編輯書籍第 2 步 $label', (tester) async {
      await _check(tester, 'edit_book_detail', size, fixture.screens['EditBookDetailDeposited']!, (tester, size) async {
        final save = _rect(tester, find.widgetWithText(PrimaryButton, S.saveChanges));
        expect(save.width, lessThanOrEqualTo(640));
      });
    });

    testWidgets('書籍管理 $label：一列一筆', (tester) async {
      await _check(tester, 'book_manage', size, fixture.screens['BookManageSeller']!, (tester, size) async {
        final rows = find.byType(RevealOnScroll).evaluate().toList();
        expect(rows.length, greaterThanOrEqualTo(2));
        final lefts = {for (final e in rows) tester.getRect(find.byWidget(e.widget)).left.round()};
        expect(lefts, hasLength(1));
      });
    });

    for (final name in ['CabinetConfirm', 'CabinetMatch', 'CabinetOpen', 'CabinetResultDone', 'CabinetResultPartial', 'CabinetError']) {
      testWidgets('書櫃作業 $name $label：內容置中於卡片、按鈕不拉滿', (tester) async {
        await _check(tester, 'cabinet_${name.substring(7).toLowerCase()}', size, fixture.screens[name]!, (tester, size) async {
          final button = find.byType(PrimaryButton);
          final rect = _rect(tester, button);
          expect(rect.width, lessThanOrEqualTo(492));
          _expectCentered(tester, button, size);
          if (name == 'CabinetMatch' || name == 'CabinetResultDone') {
            expect(rect.bottom, lessThan(size.height - 120), reason: '內容較少時卡片應垂直置中，不貼齊底部');
          }
        });
      });
    }

    testWidgets('書櫃掃描 $label：掃描框放大', (tester) async {
      await _check(tester, 'cabinet_scan', size, () => Scaffold(body: CabinetScannerView(onScan: (_) {}, scanInput: const Stream.empty())), (
        tester,
        size,
      ) async {
        final frame = _rect(tester, find.byWidgetPredicate((w) => w is CustomPaint && w.painter is ScanFramePainter));
        expect(frame.width, greaterThan(300));
        expect(frame.center.dx, closeTo(size.width / 2, 1));
      });
    });

    testWidgets('前往書櫃 $label：左右兩欄', (tester) async {
      await _check(
        tester,
        'cabinet_guide',
        size,
        () => const CabinetGuideScreen(cabinetId: 3, name: '圖書館大廳', address: '臺北市大安區學府路 102 號', openHours: '08:00~22:00'),
        (tester, size) async {
          final mrt = _rect(tester, find.text(S.transitMrt));
          final bus = _rect(tester, find.text(S.transitBus));
          final youbike = _rect(tester, find.text(S.transitYoubike));
          expect(bus.left, greaterThan(mrt.left + 200));
          expect(bus.top, lessThan(mrt.top));
          expect(youbike.left, mrt.left);
        },
      );
    });

    testWidgets('AI 建議 $label：以置中對話框呈現，按鈕固定在底部', (tester) async {
      final result = AiListingAssist.fromJson({
        'fields': {
          'title': '統計學概論',
          'author': '林志明',
          'publisher': '智識出版',
          'publish_date': '2022-02',
          'isbn': '9789571234567',
          'description': '從資料蒐集、敘述統計到推論統計，循序說明統計學的核心概念。' * 6,
        },
        'condition': {'level': 'good', 'reasons': ['封面有輕微磨損', '內頁乾淨無筆記']},
        'price': {'suggested': 280, 'min': 220, 'max': 320, 'reasons': ['近期成交價約 250 至 300']},
      });
      await _check(
        tester,
        'ai_sheet',
        size,
        () => Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showAiListingResultSheet(
                  context,
                  result: result,
                  targets: const AiListingTargets(
                    fields: {'title': '', 'author': '', 'publisher': '', 'publish_date': '', 'isbn': '', 'description': ''},
                    supportsCondition: true,
                    supportsPrice: true,
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        (tester, size) async {
          await tester.tap(find.text('open'));
          for (var i = 0; i < 6; i++) {
            await tester.pump(const Duration(milliseconds: 200));
          }
          expect(find.byType(Dialog), findsOneWidget);
          expect(find.byType(BottomSheet), findsNothing);
          final dialog = _rect(tester, find.descendant(of: find.byType(Dialog), matching: find.byType(Material)));
          expect(dialog.width, lessThanOrEqualTo(600));
          final apply = _rect(tester, find.textContaining(S.apply));
          expect(apply.bottom, lessThan(dialog.bottom));
          expect(apply.bottom, greaterThan(dialog.bottom - 80));
          if (size == _landscape) {
            final list = tester.state<ScrollableState>(find.descendant(of: find.byType(Dialog), matching: find.byType(Scrollable)).first);
            expect(list.position.maxScrollExtent, greaterThan(0), reason: '內容超出時在對話框內捲動');
          }
        },
      );
    });
  }
}
