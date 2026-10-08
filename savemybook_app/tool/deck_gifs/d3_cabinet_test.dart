// 複評簡報 GIF（子任務 D3）：智慧書櫃手機端 4 段操作。
// flutter test tool/deck_gifs/d3_cabinet_test.dart（只拍一段可加 --plain-name cabinet_deposit）
// 畫格輸出到 scratchpad/deck_gif/d3/<名稱>/，再以 gif_kit.py build 合成 GIF。

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:savemybook_app/features/account/wallet_screen.dart';
import 'package:savemybook_app/features/cabinet/cabinet_flow_screen.dart';
import 'package:savemybook_app/features/cabinet/cabinet_guide_screen.dart';
import 'package:savemybook_app/features/cabinet/cabinet_scanner_view.dart';
import 'package:savemybook_app/features/orders/order_detail_screen.dart';
import 'package:savemybook_app/features/orders/order_history_screen.dart';
import 'package:savemybook_app/models/order.dart';
import 'package:savemybook_app/models/user.dart';
import 'package:savemybook_app/services/api_service.dart';
import 'package:savemybook_app/utils/api_helpers.dart';

import '../manual_shots/manual_api.dart';
import '../manual_shots/manual_host.dart';
import '../web_shots/covers.dart' show paintCameraScene;
import 'd3_data.dart';
import 'd3_host.dart';

final _ios = TargetPlatformVariant.only(TargetPlatform.iOS);

User get _seller => User.fromJson(userJson(sellerId));

Duration _cabinetDelay(ApiRequest r) {
  if (r.method != 'POST') return Duration.zero;
  if (r.path == '/cabinet-sessions') return const Duration(milliseconds: 700);
  if (r.path.endsWith('/start') || r.path.endsWith('/match')) return const Duration(milliseconds: 360);
  if (r.path.endsWith('/close')) return const Duration(milliseconds: 440);
  return Duration.zero;
}

/// 掃描畫面的相機影像：首次出現時依掃描框位置畫好，之後每格跟著頁面位置與淡入淡出更新。
class _Camera {
  _Camera({required this.bookInA01});

  final bool bookInA01;
  ui.Image? _image;

  void update(GifRec rec) {
    final tester = rec.tester;
    final scanner = find.byType(CabinetScannerView);
    if (scanner.evaluate().isEmpty) {
      Layers.set('camera', null);
      return;
    }
    final rect = tester.getRect(scanner);
    final frame = tester.getRect(find.byWidgetPredicate((w) => w is CustomPaint && w.painter is ScanFramePainter));
    _image ??= paintCameraScene(rect.size, frame.center - rect.topLeft, frame.width, name: cabinetName, bookInA01: bookInA01);
    for (final element in find.byType(CabinetPasteButton).evaluate()) {
      _hideText(element.renderObject!);
    }
    Layers.set(
      'camera',
      CameraOverlay(image: _image!, rect: rect, opacity: fadeOf(scanner.evaluate().first), drift: handheldDrift(rec.t)),
    );
  }

  // 「貼上 QR 內容」是除錯版才有的測試用按鈕，正式版沒有；把它的文字與圖示改為透明。
  static void _hideText(RenderObject node) {
    if (node is RenderParagraph) {
      final span = node.text;
      if (span is TextSpan && span.style?.color != const Color(0x00000000)) {
        node.text = TextSpan(
          text: span.text,
          children: span.children,
          style: (span.style ?? const TextStyle()).copyWith(color: const Color(0x00000000)),
        );
      }
    }
    node.visitChildren(_hideText);
  }
}

Finder get _matchField => find.descendant(of: find.byType(CabinetFlowScreen), matching: find.byType(TextField));

/// 書櫃作業共同流程：掃描 → 確認項目 → 開啟櫃門 → 輸入數字 → 櫃門已開啟 → 完成。
/// 按鍵類事件記在手指按下的那一格；畫面切換以 watch 記在新畫面第一次出現的那一格。
Future<void> _cabinetFlow(GifRec rec, FakeCabinet fake, StreamController<String> scans, {required String openLabel, required String verb}) async {
  final tester = rec.tester;
  rec.watch(find.byType(CabinetScannerView), '掃描畫面開始滑入（相機對準書櫃螢幕 QR Code）');
  rec.watch(find.text('正在確認書櫃'), '掃描成功，顯示「正在確認書櫃」');
  rec.watch(find.textContaining('內確認'), '確認$verb項目畫面出現（請於 1:00 內確認，淡入 0.28 秒）');
  rec.watch(find.text('請輸入書櫃螢幕上顯示的數字'), '輸入數字畫面出現（此時書櫃螢幕應顯示比對碼 25）');
  rec.watch(find.text('櫃門開啟中'), '比對成功，顯示「櫃門開啟中」（書櫃開門中）');
  rec.watch(find.text('櫃門已開啟'), '顯示「櫃門已開啟」與倒數 0:30（淡入 0.28 秒）');
  await rec.play(1100);
  rec.mark('按下「$openLabel」');
  await rec.press(find.text(openLabel));
  await rec.play(1300);
  rec.mark('掃描到 QR Code（相機畫面已停留約 1 秒）');
  scans.add(cabinetQr);
  await rec.play(760);
  await rec.play(1400);
  rec.mark('按下「開啟櫃門」');
  await rec.press(find.text('開啟櫃門'));
  await rec.play(400);
  await animateNumberPad(rec, show: true);
  await rec.play(360);
  rec.mark('按下數字鍵 2');
  await typeDigit(rec, '2', () => tester.enterText(_matchField, '2'));
  await rec.play(240);
  rec.mark('按下數字鍵 5');
  await typeDigit(rec, '5', () => tester.enterText(_matchField, matchCode));
  rec.mark('兩位數比對碼 25 輸入完成');
  await rec.play(400);
  rec.mark('按下「確認」');
  await rec.press(find.widgetWithText(ElevatedButton, '確認').hitTestable());
  await animateNumberPad(rec, show: false);
  await rec.play(400);
  fake.phase('open', FakeCabinet.openMs);
  await rec.play(1800);
  rec.mark('按下「完成」（書已放入／取出並關上櫃門）');
  await rec.press(find.widgetWithText(ElevatedButton, '完成').hitTestable());
}

ScrollableState _verticalList(WidgetTester tester) => tester.state<ScrollableState>(
  find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first,
);

/// 量出各區塊標題在清單中的捲動位置（清單為延遲建立，須先捲過去才找得到），量完捲回頂端。
Future<Map<String, double>> _measureSections(WidgetTester tester, List<String> titles) async {
  final list = _verticalList(tester);
  final top = tester.getTopLeft(find.byWidget(list.widget)).dy;
  final result = <String, double>{};
  for (final title in titles) {
    final finder = find.text(title);
    for (var i = 0; i < 30 && finder.evaluate().isEmpty; i++) {
      list.position.jumpTo(math.min(list.position.pixels + 250, list.position.maxScrollExtent));
      await tester.pump();
    }
    result[title] = list.position.pixels + tester.getTopLeft(finder.first).dy - top;
  }
  list.position.jumpTo(0);
  await settleReal(tester, const Duration(seconds: 1));
  return result;
}

void main() {
  setUpAll(setUpManual);

  testWidgets('cabinet_deposit', variant: _ios, (tester) async {
    final fake = FakeCabinet(tester, kind: 'order_deposit');
    final scans = StreamController<String>.broadcast();
    // ignore: invalid_use_of_visible_for_testing_member
    CabinetScannerView.debugScanInput = scans.stream;
    // ignore: invalid_use_of_visible_for_testing_member
    addTearDown(() => CabinetScannerView.debugScanInput = null);
    final camera = _Camera(bookInA01: false);
    await gifShoot(
      tester,
      name: 'cabinet_deposit',
      me: _seller,
      delay: _cabinetDelay,
      routes: () {
        ManualApi.on('GET', '/orders', (r) {
          final list = r.query['role'] == 'seller' && r.query['tab'] == OrderHistoryScreen.awaitingDeposit
              ? [storyOrder('pending_deposit')]
              : <Object>[];
          return ok(list, pagination: {'total': list.length, 'page': 1, 'limit': 50, 'total_pages': 1});
        });
        ManualApi.on('GET', '/orders/:id', (_) => storyOrder(fake.status == 'completed' ? 'deposited' : 'pending_deposit'));
        fake.routes();
      },
      home: () => const OrderHistoryScreen(role: OrderRole.seller, filter: OrderHistoryScreen.awaitingDeposit),
      act: (rec) async {
        rec.before.add(fake.push);
        rec.after.add(() => camera.update(rec));
        rec.mark('雪喵的銷售訂單（待存書）');
        rec.watch(find.text('存書完成，已通知買家取書'), '存書完成畫面出現（「存書完成，已通知買家取書」）');
        await _cabinetFlow(rec, fake, scans, openLabel: '掃描書櫃存書', verb: '存書');
        await rec.play(2160);
      },
    );
  });

  testWidgets('cabinet_pickup', variant: _ios, (tester) async {
    final fake = FakeCabinet(tester, kind: 'pickup');
    final scans = StreamController<String>.broadcast();
    // ignore: invalid_use_of_visible_for_testing_member
    CabinetScannerView.debugScanInput = scans.stream;
    // ignore: invalid_use_of_visible_for_testing_member
    addTearDown(() => CabinetScannerView.debugScanInput = null);
    final camera = _Camera(bookInA01: true);
    String? pickedUpAt;
    await gifShoot(
      tester,
      name: 'cabinet_pickup',
      delay: (r) => r.method == 'GET' && r.path == '/orders/$orderId' ? const Duration(milliseconds: 160) : _cabinetDelay(r),
      routes: () {
        ManualApi.on('GET', '/orders', (r) {
          final list = r.query['role'] == 'buyer' && r.query['tab'] == OrderHistoryScreen.awaitingPickup
              ? [storyOrder('deposited')]
              : <Object>[];
          return ok(list, pagination: {'total': list.length, 'page': 1, 'limit': 50, 'total_pages': 1});
        });
        ManualApi.on('GET', '/orders/:id', (_) {
          if (fake.status == 'completed') pickedUpAt ??= agoNow();
          return storyOrder('deposited', pickedUpAt: pickedUpAt);
        });
        fake.routes();
      },
      home: () => const OrderHistoryScreen(filter: OrderHistoryScreen.awaitingPickup),
      act: (rec) async {
        rec.before.add(fake.push);
        rec.after.add(() => camera.update(rec));
        rec.mark('es 的購買訂單（待取書）');
        rec.watch(find.text('取書完成'), '取書完成畫面開始滑入（提示確認書況後完成訂單，取書滿 24 小時未申請爭議自動完成）');
        await _cabinetFlow(rec, fake, scans, openLabel: '掃描書櫃取書', verb: '取書');
        await rec.play(2200);
      },
    );
  });

  testWidgets('cabinet_transit', variant: _ios, (tester) async {
    final cabinet = cabinetJson(cabinetId);
    // 「導航」會呼叫系統開啟地圖 App，測試環境沒有對應的平台實作。
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/url_launcher'),
      (call) async => true,
    );
    await gifShoot(
      tester,
      name: 'cabinet_transit',
      prefs: const {'transit.departure_station': departureStation},
      routes: () {
        ManualApi.on('GET', '/cabinets/:id/nearby', (_) => cabinetNearby());
        ManualApi.on('GET', '/cabinets/mrt-stations', (_) => {'stations': mrtStations});
        ManualApi.on('GET', '/cabinets/mrt-fares', (r) => mrtFares(r.query['from'] ?? departureStation));
      },
      home: () => CabinetGuideScreen(
        cabinetId: cabinetId,
        name: cabinet['cabinet_name'] as String,
        address: cabinet['address'] as String,
        openHours: formatTimeRange(cabinet['open_time'], cabinet['close_time']),
      ),
      act: (rec) async {
        // 清單項目重新建立時的淡入會在捲回頂端時閃爍，也會讓量到的位置偏移，拍攝期間關閉
        tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
        await tester.pump();
        final at = await _measureSections(tester, ['捷運', '公車', 'YouBike 2.0', '開車與計程車']);
        final list = _verticalList(tester);
        rec.mark('前往書櫃：書櫃名稱、地址、開放時間 00:00~23:59');
        await rec.play(1400);
        for (final (title, label, hold) in [
          ('捷運', '捷運：善導寺站 2 號出口、台北車站 M7 出口，海山出發票價 \$35', 1500),
          ('公車', '公車：捷運善導寺站即時到站', 1300),
          ('YouBike 2.0', 'YouBike 2.0：可借、可還車輛', 1300),
          ('開車與計程車', '開車與計程車：停車場空位', 1300),
        ]) {
          rec.mark('開始捲動到$title');
          await rec.scrollTo(list, at[title]! - 12, 680);
          rec.mark(label);
          await rec.play(hold);
        }
        await rec.scrollTo(list, 0, 860);
        rec.mark('回到頂端');
        await rec.play(320);
        rec.mark('按下「導航」');
        await rec.press(find.widgetWithText(ElevatedButton, '導航'), hold: 160);
        await rec.play(280);
      },
    );
  });

  testWidgets('order_complete', variant: _ios, (tester) async {
    final pickedUp = agoNow(minutes: 6);
    String? completedAt;
    var paid = false;
    var walletDelay = Duration.zero;
    Map<String, dynamic> order() => completedAt == null
        ? storyOrder('deposited', pickedUpAt: pickedUp)
        : storyOrder('completed', pickedUpAt: pickedUp, completedAt: completedAt);
    await gifShoot(
      tester,
      name: 'order_complete',
      delay: (r) {
        if (r.method == 'PATCH') return const Duration(milliseconds: 420);
        if (r.path.startsWith('/wallet')) return walletDelay;
        return Duration.zero;
      },
      routes: () {
        ManualApi.on('GET', '/orders/:id', (_) => order());
        ManualApi.on('PATCH', '/orders/:id/status', (_) {
          completedAt = agoNow();
          return order();
        });
        ManualApi.on('GET', '/wallet', (_) => wallet(paid: paid));
        ManualApi.on('GET', '/wallet/transactions', (_) => walletTransactions(paid: paid));
      },
      home: () => OrderDetailScreen(order: Order.fromJson(order())),
      act: (rec) async {
        rec.mark('es 的訂單詳情（已取書，待完成）');
        await rec.play(900);
        var list = _verticalList(tester);
        await rec.scrollTo(list, list.position.maxScrollExtent, 640);
        await rec.play(280);
        rec.mark('按下「完成訂單」');
        await rec.press(find.widgetWithText(ElevatedButton, '完成訂單'));
        await rec.play(1160);
        rec.mark('在確認對話框按下「完成訂單」');
        rec.watch(find.text('訂單已完成'), '顯示「訂單已完成」，訂單狀態改為已完成');
        await rec.press(find.text('完成訂單').hitTestable().last);
        await rec.play(900);
        list = _verticalList(tester);
        await rec.scrollTo(list, 0, 520);
        await rec.play(760);

        // 切換到賣家雪喵的手機：前一段最後畫面淡出
        final last = await rec.grab();
        Layers.set('fade', FadeImage(image: last, opacity: 1));
        ApiService.currentUser = _seller;
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(const ManualApp(home: WalletScreen()));
        await settleReal(tester, const Duration(seconds: 2));
        await waitForImages(tester);
        rec.mark('開始切換到雪喵的代幣中心（淡入 0.4 秒，畫面顯示待撥款項 \$250）');
        await rec.animate(400, (k) => Layers.set('fade', FadeImage(image: last, opacity: 1 - Curves.easeInOut.transform(k))));
        Layers.set('fade', null);
        await rec.play(560);

        const title = '訂單已完成';
        final body = '訂單 $orderNo 已完成，250 代幣已撥入您的錢包。';
        rec.mark('通知：訂單已完成，250 代幣已撥入您的錢包');
        await rec.animate(360, (k) {
          final top = -130 + (54 + 130) * Curves.easeOutCubic.transform(k);
          Layers.set('banner', IosBanner(title: title, body: body, top: top));
        });
        await rec.play(1300);

        // 下拉重新整理：款項入帳，餘額增加、待撥款項消失、交易紀錄新增「賣出」
        paid = true;
        walletDelay = const Duration(milliseconds: 520);
        const start = Offset(196, 420);
        rec.taps.add({'ms': rec.t, 'x': start.dx, 'y': start.dy});
        final gesture = await tester.startGesture(start);
        rec.mark('下拉重新整理');
        rec.watch(find.text('賣出'), '重新整理完成：交易紀錄出現「賣出 +\$250」，餘額開始由 9,194 跳動增加，待撥款項消失');
        rec.watch(find.text('9,444'), '餘額停在 9,444（款項入帳完成）');
        // 手指下拉 360 pt（600 毫秒），通知橫幅在前 320 毫秒收起
        var pulled = 0.0;
        await rec.animate(600, (k) async {
          await gesture.moveBy(Offset(0, 360 * k - pulled));
          pulled = 360 * k;
          final b = k * 600 / 320;
          if (b <= 1) {
            final top = 54 - (54 + 130) * Curves.easeInCubic.transform(b);
            Layers.set('banner', IosBanner(title: title, body: body, top: top));
          } else {
            Layers.set('banner', null);
          }
        });
        await gesture.up();
        await rec.play(2800);
      },
    );
  });
}
