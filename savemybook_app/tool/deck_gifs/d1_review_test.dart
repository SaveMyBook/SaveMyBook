// 複評簡報 GIF：管理員「上架審核」。AI 判定需人工確認的書：
//   1.《你不是月光，是被割光》（Gary 上架的真實書籍）：第 3 張實拍照片可見書背分類號標籤（525.68 8025），AI 判定疑似圖書館館藏。
//   2.《我的第一本俄語課本》（KJ 上架的真實書籍）：描述含 LINE 帳號，AI 判定疑似引導站外交易（審核清單中的下一筆）。
// 管理員展開照片與完整內容、點開條碼頁照片確認後，以「館藏或非正規來源」拒絕上架。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:savemybook_app/features/admin/admin_report_screen.dart';
import 'package:savemybook_app/i18n/strings.dart';
import 'package:savemybook_app/models/user.dart';

import '../manual_shots/manual_api.dart';
import '../manual_shots/manual_host.dart';
import 'd1_rec.dart';

final _ios = TargetPlatformVariant.only(TargetPlatform.iOS);

const _libraryBook = 132;
const _contactBook = 116;

Map<String, dynamic> get _adminJson => userJson(meId, extra: {'role': 'admin'});

Map<String, dynamic> _review(
  int bookId, {
  required List<String> reasons,
  required List<String> categories,
  required double confidence,
  required String at,
  Map<String, dynamic> extra = const {},
}) {
  final b = {...bookJson(bookId), ...extra};
  return {
    'book_id': bookId,
    'verdict': 'review',
    'reasons': reasons,
    'categories': categories,
    'status': 'pending',
    'provider': 'openai',
    'model': 'gpt-5-nano',
    'origin': 'ai',
    'confidence': confidence,
    'ai_opinion': null,
    'created_at': at,
    'book': b,
    'seller': {'user_id': b['seller_id'], 'nickname': realUsers[b['seller_id']]!.nickname},
  };
}

final _decided = <int>{};

// 卡片的「N 分鐘前」依真實時鐘計算，60 fps 錄製要一兩分鐘，拒絕後重建的卡片會從 31 跳成 33 分鐘；改用小時級的時間才不會在錄製中變動
String _minutesAgo(int minutes) => DateTime.now().toUtc().subtract(Duration(minutes: minutes)).toIso8601String();

List<Map<String, dynamic>> _reviews() => [
  if (!_decided.contains(_libraryBook))
    _review(
      _libraryBook,
      reasons: ['照片中可見書背分類號標籤（525.68 8025），疑似圖書館館藏書', '書況說明未提及書籍來源，建議人工確認'],
      categories: ['source'],
      confidence: 0.78,
      at: _minutesAgo(75),
    ),
  if (!_decided.contains(_contactBook))
    _review(
      _contactBook,
      reasons: ['描述含 LINE 帳號，可能引導買家至平台外聯繫與交易'],
      categories: ['contact'],
      confidence: 0.86,
      at: _minutesAgo(135),
      extra: {
        'description': '${bookJson(_contactBook)['description']}\n\n另附俄語單字卡，想看更多照片請加 LINE：ru_kj0601。',
      },
    ),
];

void _routes() {
  ManualApi.on('GET', '/auth/me', (_) => _adminJson);
  ManualApi.on('GET', '/admin/overview', (_) => {
    'member_count': 8,
    'pending_report_count': 0,
    'pending_listing_review_count': _reviews().length,
    'open_risk_alert_count': 0,
    'pending_dispute_count': 0,
    'active_cabinet_count': 5,
    'today_order_count': 8,
    'open_ticket_count': 5,
  });
  ManualApi.on('GET', '/admin/ai/reviews', (_) => _reviews());
  ManualApi.on('PATCH', '/admin/ai/reviews/:id', (r) {
    _decided.add(int.parse(r.path.split('/').last));
    return {'book_id': int.parse(r.path.split('/').last)};
  });
}

final _failures = <String>[];

void main() {
  setUpAll(setUpManual);

  testWidgets('ai_review', variant: _ios, (tester) async {
    _decided.clear();
    final rec = Rec('ai_review');
    await shoot(
      tester,
      folder: '_d1',
      me: User.fromJson(_adminJson),
      routes: _routes,
      home: () => const AdminReportScreen(initialTab: AdminReportScreen.listingReviewTab),
      act: (tester, _) async {
        try {
          await settleReal(tester, const Duration(seconds: 1));
          await waitForImages(tester);
          final expand = find.text(S.showPhotosFullDetails).first;

          // 先展開並開一次照片，讓照片載入快取，錄製時才不會逐張冒出
          await tester.tap(expand);
          await settleReal(tester, const Duration(seconds: 1));
          await waitForImages(tester);
          await tester.tap(_photo(2));
          await settleReal(tester, const Duration(seconds: 2));
          await waitForImages(tester);
          await settleReal(tester, const Duration(seconds: 1));
          await tester.tap(find.byIcon(Icons.close_rounded).last);
          await settleReal(tester, const Duration(seconds: 1));
          await tester.tap(find.text(S.collapse).first);
          await settleReal(tester, const Duration(seconds: 1));

          await rec.hold(tester, 900);
          await rec.tap(tester, find.text(S.showPhotosFullDetails).first);
          await rec.play(tester, 400);
          final list = tester.state<ScrollableState>(find.ancestor(of: find.text(S.reject).first, matching: find.byType(Scrollable)).first).position;
          unawaited(list.animateTo(150, duration: const Duration(milliseconds: 520), curve: Curves.easeInOutCubic));
          await rec.play(tester, 600);
          await rec.hold(tester, 500);

          await rec.tap(tester, _photo(2));
          await rec.play(tester, 400);
          await rec.hold(tester, 1100);
          await rec.tap(tester, find.byIcon(Icons.close_rounded).last);
          await rec.play(tester, 400);
          await rec.hold(tester, 300);

          await rec.tap(tester, find.text(S.reject).first);
          await rec.play(tester, 440);
          await rec.hold(tester, 500);
          await rec.tap(tester, find.text('館藏或非正規來源').last);
          await rec.play(tester, 400);
          await rec.hold(tester, 600);
          await rec.tap(tester, find.text(S.reject).last);
          await rec.play(tester, 1400);
          await rec.hold(tester, 700);
          rec.save();
        } catch (e, st) {
          _failures.add('$e');
          debugPrint('ACT FAILED: $e\n$st');
        }
      },
    );
    expect(_failures, isEmpty);
  });
}

/// 第一張審核卡展開後的第 [i] 張照片。
Finder _photo(int i) => find.descendant(
  of: find.byWidgetPredicate((w) => w is ListView && w.scrollDirection == Axis.horizontal),
  matching: find.byType(GestureDetector),
).at(i);
