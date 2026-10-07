import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:savemybook_app/i18n/app_localizations.dart';
import 'package:savemybook_app/i18n/strings.dart';
import 'package:savemybook_app/services/locale_provider.dart';
import 'package:savemybook_app/utils/app_theme.dart';
import 'package:savemybook_app/widgets/adaptive_sheet.dart';
import 'package:savemybook_app/widgets/master_detail.dart';

Widget _host(Widget child) => MaterialApp(
      theme: AppTheme.build(Brightness.light),
      locale: const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      supportedLocales: LocaleProvider.supported,
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
      home: child,
    );

class _List extends StatelessWidget {
  final List<Object?> results;
  const _List(this.results);

  @override
  Widget build(BuildContext context) {
    final selected = MasterDetail.selectedId(context);
    return Scaffold(
      body: ListView(
        children: [
          for (final id in [1, 2])
            ListTile(
              title: Text('item $id${selected == id ? ' *' : ''}'),
              onTap: () async => results.add(await MasterDetail.open<String>(context, _Detail(id), id: id)),
            ),
        ],
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  final int id;
  const _Detail(this.id);

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Column(
          children: [
            Text('detail $id'),
            TextButton(onPressed: () => Navigator.pop(context, 'done $id'), child: const Text('pop')),
            TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const Scaffold(body: Text('inner')))),
              child: const Text('push'),
            ),
            TextButton(
              onPressed: () => showAppModalSheet(context: context, builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, children: [const SheetHandle(), Text(isDialogSheet(ctx) ? 'dialog' : 'sheet')])),
              child: const Text('sheet'),
            ),
          ],
        ),
      );
}

void main() {
  void size(WidgetTester tester, Size s) {
    tester.view
      ..physicalSize = s
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('寬螢幕並排：右側顯示內容並標示選取，內容頁 pop 回到提示並回傳結果，內頁推入留在右側', (tester) async {
    size(tester, const Size(1180, 820));
    final results = <Object?>[];
    await tester.pumpWidget(_host(MasterDetail(master: _List(results))));
    await tester.pumpAndSettle();
    expect(find.text(S.selectItemToView), findsOneWidget);
    await tester.tap(find.text('item 1'));
    await tester.pumpAndSettle();
    expect(find.text('detail 1'), findsOneWidget);
    expect(find.text('item 1 *'), findsOneWidget);
    expect(find.text('item 2'), findsOneWidget, reason: '列表仍在');

    await tester.tap(find.text('push'));
    await tester.pumpAndSettle();
    expect(find.text('inner'), findsOneWidget);
    expect(find.text('item 2'), findsOneWidget, reason: '內頁推入在右側，列表仍在');
    Navigator.of(tester.element(find.text('inner'))).pop();
    await tester.pumpAndSettle();
    expect(find.text('detail 1'), findsOneWidget);

    await tester.tap(find.text('item 2'));
    await tester.pumpAndSettle();
    expect(find.text('detail 2'), findsOneWidget);
    expect(results, [null], reason: '被取代的內容回傳 null');

    await tester.tap(find.text('pop'));
    await tester.pumpAndSettle();
    expect(results, [null, 'done 2']);
    expect(find.text(S.selectItemToView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('寬度不足：開啟內容改為推入新頁面；底部面板維持手機樣式', (tester) async {
    size(tester, const Size(390, 844));
    final results = <Object?>[];
    await tester.pumpWidget(_host(MasterDetail(master: _List(results))));
    await tester.pumpAndSettle();
    expect(find.text(S.selectItemToView), findsNothing);
    await tester.tap(find.text('item 1'));
    await tester.pumpAndSettle();
    expect(find.text('detail 1'), findsOneWidget);
    expect(find.text('item 2'), findsNothing);
    await tester.tap(find.text('sheet'));
    await tester.pumpAndSettle();
    expect(find.text('sheet'), findsNWidgets(2));
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await tester.tap(find.text('pop'));
    await tester.pumpAndSettle();
    expect(results, ['done 1']);
  });

  testWidgets('寬螢幕的面板以置中對話框呈現', (tester) async {
    size(tester, const Size(1180, 820));
    await tester.pumpWidget(_host(MasterDetail(master: _List([]))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('item 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('sheet'));
    await tester.pumpAndSettle();
    expect(find.text('dialog'), findsOneWidget);
    expect(find.byType(Dialog), findsOneWidget);
  });
}
