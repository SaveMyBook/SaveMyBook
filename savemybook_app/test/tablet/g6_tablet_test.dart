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

import 'package:savemybook_app/features/account/ai_support_screen.dart';
import 'package:savemybook_app/features/account/help_center_screen.dart';
import 'package:savemybook_app/features/account/support_ticket_screen.dart';
import 'package:savemybook_app/features/account/wallet_screen.dart';
import 'package:savemybook_app/features/home/announcement_screen.dart';
import 'package:savemybook_app/features/home/notification_screen.dart';
import 'package:savemybook_app/features/orders/cart_screen.dart';
import 'package:savemybook_app/features/orders/dispute_screen.dart';
import 'package:savemybook_app/features/orders/my_reservations_screen.dart';
import 'package:savemybook_app/features/orders/order_detail_screen.dart';
import 'package:savemybook_app/features/orders/order_history_screen.dart';
import 'package:savemybook_app/features/orders/widgets/order_record_card.dart';
import 'package:savemybook_app/features/orders/widgets/payment_success_dialog.dart';
import 'package:savemybook_app/features/orders/widgets/tablet_controls.dart';
import 'package:savemybook_app/i18n/app_localizations.dart';
import 'package:savemybook_app/i18n/strings.dart';
import 'package:savemybook_app/models/ai.dart';
import 'package:savemybook_app/models/user.dart';
import 'package:savemybook_app/services/api_service.dart';
import 'package:savemybook_app/services/locale_provider.dart';
import 'package:savemybook_app/services/theme_provider.dart';
import 'package:savemybook_app/utils/app_colors.dart';
import 'package:savemybook_app/utils/app_theme.dart';
import 'package:savemybook_app/widgets/adaptive_sheet.dart';
import 'package:savemybook_app/widgets/app_buttons.dart';
import 'package:savemybook_app/widgets/app_header.dart';

import '../../tool/web_shots/covers.dart' show loadAppFonts, seedCoverCache;
import '../../tool/web_shots/demo_data.dart';

// G6_SHOTS=<資料夾> 時另存截圖供目視檢查；G6_THEME=dark 為深色模式
final _env = Platform.environment;
final _shots = _env['G6_SHOTS'];
final _dark = _env['G6_THEME'] == 'dark';

const _landscape = Size(1180, 820);
const _portrait = Size(820, 1180);
const _sizes = {'landscape': _landscape, 'portrait': _portrait};

final _rootKey = GlobalKey<NavigatorState>();
final _requests = <String>[];

http.Response _json(Object? data) => http.Response(
      jsonEncode({
        'success': true,
        'message': 'OK',
        'data': data,
        if (data is List) 'pagination': {'total': data.length, 'page': 1, 'limit': 20, 'total_pages': 1},
      }),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Map<String, dynamic> _ticket(int id, String subject, {List<Map<String, dynamic>> messages = const []}) => {
      'ticket_id': id,
      'subject': subject,
      'category': 'cabinet',
      'status': 'open',
      'message_count': messages.length,
      'last_message': '請協助確認櫃門狀態。',
      'created_at': ago(days: id),
      'updated_at': ago(hours: id),
      'messages': messages,
    };

Object? _extra(String method, String path) => switch ('$method $path') {
      'GET /cart' => [
          {'cart_id': 1, 'books': bookOf(5).toJson()},
          {'cart_id': 2, 'books': bookOf(12).toJson()},
          {'cart_id': 3, 'books': bookOf(10).toJson()},
          {'cart_id': 4, 'books': bookOf(3).toJson(extra: {'status': 'sold'})},
        ],
      'GET /support/tickets' => [_ticket(1, '櫃門無法開啟'), _ticket(2, '代幣儲值未入帳')],
      'GET /support/tickets/1' => _ticket(1, '櫃門無法開啟', messages: [
          {'message_id': 1, 'content': '掃描後櫃門沒有打開。', 'is_staff': false, 'created_at': ago(hours: 2), 'sender': {'nickname': '海嫄'}},
          {'message_id': 2, 'content': '已為您遠端開啟櫃門，請再試一次。', 'is_staff': true, 'created_at': ago(hours: 1), 'sender': {'nickname': '客服'}},
        ]),
      'GET /support/faqs' => [
          {'faq_id': 1, 'category': 'cabinet', 'question': '如何從書櫃取書？', 'answer': '於開放時間至書櫃掃描螢幕上的 QR Code，輸入比對碼後開啟櫃門。'},
          {'faq_id': 2, 'category': 'cabinet', 'question': '櫃門沒有打開怎麼辦？', 'answer': '請確認網路連線後重新掃描，仍無法開啟請聯絡客服。'},
          {'faq_id': 3, 'category': 'wallet', 'question': '代幣可以提領嗎？', 'answer': '代幣僅供站內交易使用。'},
          {'faq_id': 4, 'category': 'account', 'question': '如何變更暱稱？', 'answer': '至會員中心的個人資料頁面修改。'},
        ],
      'GET /orders/count' => {'count': 2},
      'GET /users/me/level' => <String, Object>{},
      _ => null,
    };

final _demo = demoApi();

MockClient _api() => MockClient((request) async {
      final path = request.url.path.replaceFirst('/api', '');
      _requests.add('${request.method} $path');
      final extra = _extra(request.method, path);
      if (extra != null) return _json(extra);
      final copy = http.Request(request.method, request.url)
        ..headers.addAll(request.headers)
        ..bodyBytes = request.bodyBytes;
      return http.Response.fromStream(await _demo.send(copy));
    });

/// 模擬平板外框：左側保留側邊欄的寬度，頁面放在分頁自己的 Navigator 內（第一頁沒有上一頁）。
class _TabFrame extends StatelessWidget {
  final Widget child;

  const _TabFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final width = MediaQuery.sizeOf(context).width;
    return Row(
      children: [
        Container(
          width: width >= 1024 ? 264 : 88,
          decoration: BoxDecoration(color: c.card, border: Border(right: BorderSide(color: c.divider))),
        ),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeLeft: true,
            child: Navigator(onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => child)),
          ),
        ),
      ],
    );
  }
}

Widget _app(Widget home) => MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: _rootKey,
      locale: const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      supportedLocales: LocaleProvider.supported,
      theme: AppTheme.build(_dark ? Brightness.dark : Brightness.light),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        S = AppLocalizations.of(context);
        return PointerAnchor(child: child ?? const SizedBox.shrink());
      },
      home: _TabFrame(child: home),
    );

Future<void> _settle(WidgetTester tester, [int steps = 10]) async {
  for (var i = 0; i < steps; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// 以示範資料開啟分頁第一頁，執行 [body] 後卸載；過程中的版面溢出與例外一律視為失敗。
Future<void> _run(WidgetTester tester, Size size, Widget home, Future<void> Function() body) async {
  tester.view
    ..physicalSize = size * 2
    ..devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  ApiService.authToken = 'demo-token';
  ApiService.currentUser = User.fromJson(user(meId));
  ApiService.aiStatus.value = const AiStatusInfo(support: true, consented: true);
  _requests.clear();
  if (_shots != null) seedCoverCache();

  final errors = <String>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.exceptionAsString();
    if (text.contains('NetworkImageLoadException') || text.contains('HTTP request failed')) return;
    errors.add(text.split('\n').first);
  };
  try {
    await http.runWithClient(() async {
      await tester.pumpWidget(_app(home));
      await _settle(tester, 20);
      await body();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    }, _api);
  } finally {
    FlutterError.onError = previous;
  }
  expect(errors, isEmpty, reason: '版面溢出或元件例外');
}

Future<void> _capture(WidgetTester tester, String name) async {
  final dir = _shots;
  if (dir == null) return;
  await _settle(tester, 6);
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

Future<void> _rightClick(WidgetTester tester, Finder finder) async {
  await tester.tap(finder, buttons: kSecondaryButton);
  await _settle(tester, 6);
}

Future<void> _dismiss(WidgetTester tester) async {
  _rootKey.currentState!.pop();
  await _settle(tester, 6);
}

Color _fill(WidgetTester tester, Finder item) =>
    tester.widget<Material>(find.descendant(of: item, matching: find.byType(Material)).first).color!;

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    themeProvider = await ThemeProvider.init();
    localeProvider = await LocaleProvider.init();
    if (_shots != null) await loadAppFonts();
  });

  group('訂單紀錄', () {
    testWidgets('橫向：精簡列與詳情並排，選取列有底色，篩選放不下時改為下拉選單', (tester) async {
      await _run(tester, _landscape, const OrderHistoryScreen(), () async {
        expect(find.byType(OrderRecordRow), findsNWidgets(2));
        expect(find.byType(OrderRecordCard), findsNothing);
        await _capture(tester, 'order_history_landscape');

        await tester.tap(find.text('統計學概論').first);
        await _settle(tester);
        expect(find.byType(OrderDetailScreen), findsOneWidget);
        final rows = tester.widgetList<OrderRecordRow>(find.byType(OrderRecordRow)).toList();
        expect(rows.where((r) => r.selected), hasLength(1));
        final selected = find.byWidgetPredicate((w) => w is OrderRecordRow && w.selected);
        final c = AppColors.of(tester.element(selected));
        expect(_fill(tester, selected), tabletSelectionColor(c));

        final detail = tester.getRect(find.byType(OrderDetailScreen));
        final scan = find.descendant(of: find.byType(OrderDetailScreen), matching: find.byType(CompactActionButton));
        expect(scan, findsWidgets, reason: '操作按鈕放在狀態卡片內');
        expect(find.descendant(of: find.byType(OrderDetailScreen), matching: find.byType(PrimaryButton)), findsNothing);
        expect(tester.getSize(scan.last).width, lessThan(detail.width / 2), reason: '按鈕寬度依內容');
        await _capture(tester, 'order_history_detail_landscape');

        await _rightClick(tester, find.text('管理學：理論與實務').first);
        expect(find.text(S.viewOrder), findsOneWidget, reason: '右鍵開啟操作選單');
        await _capture(tester, 'order_history_menu_landscape');
        await _dismiss(tester);

        expect(find.text(S.orderCompleted), findsNothing, reason: '左欄放不下分段控制時改為下拉選單');
        await tester.tap(find.byIcon(Icons.filter_list_rounded));
        await _settle(tester, 6);
        await tester.tap(find.text(S.orderCompleted).last);
        await _settle(tester);
        expect(find.text(bookOf(12).title), findsOneWidget);
      });
    });

    testWidgets('直向：單欄分段控制，列內資訊橫向排列，點選推入詳情', (tester) async {
      await _run(tester, _portrait, const OrderHistoryScreen(), () async {
        for (final filter in OrderHistoryScreen.filtersOf(OrderRole.buyer)) {
          expect(find.text(OrderHistoryScreen.filterLabel(OrderRole.buyer, filter)), findsWidgets);
        }
        final row = tester.getRect(find.byType(OrderRecordRow).first);
        final button = tester.getRect(find.descendant(of: find.byType(OrderRecordRow).first, matching: find.byType(CompactActionButton)));
        expect(button.center.dy, closeTo(row.center.dy, 4), reason: '按鈕與資訊同一列');
        expect(button.right, closeTo(row.right - 14, 1));
        await _capture(tester, 'order_history_portrait');

        await tester.tap(find.text('統計學概論').first);
        await _settle(tester);
        expect(find.byType(OrderRecordRow), findsNothing);
        final scan = tester.getRect(find.byType(CompactActionButton).last);
        final progress = tester.getRect(find.text(S.orderProgress));
        expect(scan.bottom, lessThan(progress.top), reason: '操作按鈕在狀態卡片內，不在頁面底部');
        await _capture(tester, 'order_detail_portrait');
      });
    });
  });

  for (final MapEntry(key: label, value: size) in _sizes.entries) {
    testWidgets('我的預約 $label：一列一筆填滿寬度，按鈕依內容寬度靠右', (tester) async {
      await _run(tester, size, const MyReservationsScreen(), () async {
        final buy = find.text(S.buyNow);
        expect(buy, findsNWidgets(2));
        final a = tester.getRect(buy.first);
        final b = tester.getRect(buy.last);
        expect(b.top, greaterThan(a.bottom), reason: '一列一筆');
        final button = tester.getRect(find.ancestor(of: buy.first, matching: find.byType(CompactActionButton)));
        expect(button.width, lessThan(200));
        final item = tester.getRect(find.ancestor(of: buy.first, matching: find.byType(TabletListItem)));
        expect(button.right, closeTo(item.right - 14, 1));
        expect(find.byTooltip(S.messageSeller), findsNWidgets(2));
        await _capture(tester, 'reservations_$label');

        await _rightClick(tester, find.text('線性代數'));
        expect(find.text(S.cancelReservation2), findsNWidgets(3), reason: '選單內含取消預約');
        await _dismiss(tester);
      });
    });

    testWidgets('通知中心 $label：左側分類清單，右側一列一筆', (tester) async {
      await _run(tester, size, const NotificationScreen(embedded: true), () async {
        expect(find.byKey(const ValueKey('notification_sidebar')), findsOneWidget);
        expect(find.byType(TabBar), findsNothing, reason: '不用手機的分頁標籤');
        final first = tester.getRect(find.text('書籍已存入書櫃'));
        final second = tester.getRect(find.text('款項已撥入錢包'));
        expect(second.top, greaterThan(first.bottom));
        final sidebar = tester.getRect(find.byKey(const ValueKey('notification_sidebar')));
        expect(first.left, greaterThan(sidebar.right));
        expect(find.byTooltip(S.markAllRead), findsOneWidget);
        await _capture(tester, 'notifications_$label');

        await _rightClick(tester, find.text('書籍已存入書櫃'));
        expect(find.text(S.markAsRead), findsOneWidget);
        await _capture(tester, 'notifications_menu_$label');
        await _dismiss(tester);

        await tester.tap(find.byKey(const ValueKey('notification_category_account')));
        await _settle(tester);
        expect(find.text('書籍已存入書櫃'), findsNothing);

        await tester.tap(find.byKey(const ValueKey('notification_announcements')));
        await _settle(tester);
        expect(find.byType(AnnouncementList), findsOneWidget);
        expect(find.byTooltip(S.markAllRead), findsNothing);
      });
    });

    testWidgets('購物車 $label：依賣家分組，結帳摘要固定在右側', (tester) async {
      await _run(tester, size, const CartScreen(), () async {
        final panel = find.byKey(const ValueKey('checkout_panel'));
        expect(panel, findsOneWidget);
        final item = tester.getRect(find.text(bookOf(5).title));
        final checkout = tester.getRect(find.text(S.checkOut));
        expect(checkout.left, greaterThan(item.right), reason: '摘要在清單右側');
        expect(find.byTooltip(S.remove), findsNWidgets(4));
        await _capture(tester, 'cart_$label');

        final before = tester.getRect(find.text(S.checkOut));
        await tester.drag(find.text(bookOf(5).title), const Offset(0, -300));
        await _settle(tester, 4);
        expect(tester.getRect(find.text(S.checkOut)), before, reason: '清單捲動時摘要不動');

        await _rightClick(tester, find.text(bookOf(10).title));
        expect(find.text(S.deselect), findsWidgets);
        await _dismiss(tester);
      });
    });

    testWidgets('代幣中心 $label：交易紀錄以分段控制篩選', (tester) async {
      await _run(tester, size, const WalletScreen(), () async {
        final segments = find.byWidgetPredicate((w) => w.runtimeType.toString().startsWith('SegmentedFilter'));
        expect(segments, findsOneWidget);
        expect(tester.getSize(segments).width, lessThanOrEqualTo(420));
        expect(find.text(S.pendingPayouts), findsWidgets);
        await _capture(tester, 'wallet_$label');
        await tester.tap(find.text('${S.income} 2'));
        await _settle(tester);
        expect(find.text('統計學概論'), findsNothing, reason: '只顯示收入');
      });
    });
  }

  testWidgets('AI 客服：轉接客服人員在工具列，實體鍵盤 Enter 送出、Shift+Enter 不送出', (tester) async {
    await _run(tester, _landscape, const AiSupportScreen(), () async {
      expect(find.descendant(of: find.byType(TabletToolbar), matching: find.text(S.talkPerson)), findsOneWidget);
      await _capture(tester, 'ai_support_landscape');

      final field = find.byType(TextField);
      await tester.tap(field);
      await tester.enterText(field, '書櫃在哪裡？');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await _settle(tester, 4);
      expect(tester.widget<TextField>(field).controller!.text, '書櫃在哪裡？');

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await _settle(tester);
      expect(tester.widget<TextField>(field).controller!.text, isEmpty);
      expect(find.text('書櫃在哪裡？'), findsOneWidget);
      expect(_requests, contains('POST /ai/support/messages'));
    });
  });

  testWidgets('客服工單：提問放在工具列，回覆以 Enter 送出', (tester) async {
    await _run(tester, _landscape, const SupportTicketScreen(), () async {
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.byTooltip(S.askQuestion), findsOneWidget);
      await tester.tap(find.text('櫃門無法開啟').first);
      await _settle(tester);
      expect(find.byType(TicketDetailScreen), findsOneWidget);
      await _capture(tester, 'support_tickets_landscape');

      final field = find.descendant(of: find.byType(TicketDetailScreen), matching: find.byType(TextField));
      await tester.tap(field);
      await tester.enterText(field, '已經可以開啟，謝謝。');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await _settle(tester);
      expect(_requests, contains('POST /support/tickets/1/messages'));
    });
  });

  testWidgets('客服中心：橫向左側搜尋與聯絡入口、右側常見問題', (tester) async {
    await _run(tester, _landscape, const HelpCenterScreen(), () async {
      final contact = tester.getRect(find.byKey(const ValueKey('help_contact_support')));
      final faq = tester.getRect(find.text('如何從書櫃取書？'));
      expect(faq.left, greaterThan(contact.right));
      await _capture(tester, 'help_center_landscape');
    });
  });

  for (final MapEntry(key: label, value: size) in _sizes.entries) {
    testWidgets('爭議表單 $label：送出按鈕靠右、寬度依內容', (tester) async {
      await _run(tester, size, const DisputeScreen(orderNo: 'ODNMX0225'), () async {
        final submit = tester.getRect(find.byType(PrimaryButton));
        expect(submit.width, lessThan(300));
        final field = tester.getRect(find.byType(TextField).first);
        expect(submit.right, closeTo(field.right, 24), reason: '與表單右緣對齊');
        await _capture(tester, 'dispute_$label');
      });
    });

    testWidgets('付款成功 $label：對話框寬度合宜', (tester) async {
      await _run(tester, size, const Scaffold(body: SizedBox.expand()), () async {
        showPaymentSuccess(_rootKey.currentContext!, total: 280, readyForPickup: true);
        await _settle(tester);
        final card = find.ancestor(of: find.text(S.paymentSuccessful), matching: find.byType(Material)).first;
        expect(tester.getSize(card).width, lessThanOrEqualTo(400));
        await _capture(tester, 'payment_success_$label');
        await _dismiss(tester);
      });
    });
  }
}
