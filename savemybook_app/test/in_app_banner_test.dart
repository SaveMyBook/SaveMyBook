import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:savemybook_app/utils/app_theme.dart';
import 'package:savemybook_app/widgets/in_app_banner.dart';

void main() {
  late OverlayState overlay;

  Future<void> pumpHost(WidgetTester tester) async {
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(navigatorKey: key, theme: AppTheme.build(Brightness.light), home: const SizedBox()),
    );
    overlay = key.currentState!.overlay!;
  }

  tearDown(resetInAppBanners);

  testWidgets('同時收到兩則通知時依序顯示，第一則不會瞬間被蓋掉', (tester) async {
    await pumpHost(tester);
    showInAppBanner(overlay, title: '第一則', body: '內容一', groupKey: 'order:1');
    await tester.pump(const Duration(milliseconds: 100));
    showInAppBanner(overlay, title: '第二則', body: '內容二', groupKey: 'order:2');
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('第一則'), findsOneWidget);
    expect(find.text('第二則'), findsNothing);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('第一則'), findsNothing);
    expect(find.text('第二則'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('第二則'), findsNothing);
  });

  testWidgets('同一個對象的新通知直接更新目前的橫幅', (tester) async {
    await pumpHost(tester);
    showInAppBanner(overlay, title: '聊天室', body: '第一句', groupKey: 'chat_room:3');
    await tester.pump(const Duration(milliseconds: 300));
    showInAppBanner(overlay, title: '聊天室', body: '第二句', groupKey: 'chat_room:3');
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('第一句'), findsNothing);
    expect(find.text('第二句'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('第二句'), findsNothing);
  });
}
