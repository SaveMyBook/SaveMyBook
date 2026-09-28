import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:savemybook_app/features/account/account_privacy_screen.dart';
import 'package:savemybook_app/features/account/ai_consent_sheet.dart';
import 'package:savemybook_app/features/account/ai_support_screen.dart';
import 'package:savemybook_app/features/selling/ai_listing_assist.dart';
import 'package:savemybook_app/features/admin/ai/ai_settings_form.dart';
import 'package:savemybook_app/features/admin/ai/ai_settings_tab.dart';
import 'package:savemybook_app/i18n/app_localizations.dart';
import 'package:savemybook_app/i18n/strings.dart';
import 'package:savemybook_app/models/ai.dart';
import 'package:savemybook_app/models/book.dart';
import 'package:savemybook_app/services/ai_status.dart';
import 'package:savemybook_app/services/api_service.dart';
import 'package:savemybook_app/services/locale_provider.dart';
import 'package:savemybook_app/utils/app_theme.dart';
import 'package:savemybook_app/widgets/app_buttons.dart';

import 'layout_overflow_test.dart' as lt;

void main() {
  group('AiSettings serialization', () {
    test('missing document falls back to contract defaults', () {
      final s = AiSettings.fromJson(const {});
      expect(s.enabled, isFalse);
      expect(s.defaultProvider, 'deepseek');
      expect(s.providers['gemini']!.searchFreePerMonth, 5000);
      expect(s.features['listing_assist']!.provider, 'gemini');
      expect(s.features['listing_assist']!.webSearch, isTrue);
      expect(s.features['moderation']!.action, 'review');
      expect(s.monthlyBudgetUsd, 10);
      expect(s.dailyPerUser, {'support': 30, 'listing_assist': 15, 'recommend': 5, 'book_chat': 20});
    });

    test('round-trips through toJson and keeps explicit nulls', () {
      final source = lt.aiSettingsData()['settings'] as Map<String, dynamic>;
      final s = AiSettings.fromJson(source);
      final json = s.toJson();
      expect(json['default_provider'], 'gemini');
      expect((json['features'] as Map)['support'], {'enabled': true, 'provider': null});
      expect((json['features'] as Map)['listing_assist'], {'enabled': true, 'provider': 'openai', 'web_search': true});
      expect((json['features'] as Map)['moderation'], {'enabled': true, 'provider': 'deepseek', 'action': 'block'});
      expect(((json['limits'] as Map)['daily_per_user'] as Map)['recommend'], 0);
      expect(AiSettings.fromJson(jsonDecode(jsonEncode(json)) as Map<String, dynamic>).fingerprint, s.fingerprint);
    });

    test('invalid values are sanitized', () {
      final s = AiSettings.fromJson({
        'default_provider': 'claude',
        'features': {
          'support': {'provider': 'unknown'},
          'moderation': {'action': 'delete'},
        },
        'providers': {
          'openai': {'model': '', 'input_per_m': -3},
        },
      });
      expect(s.defaultProvider, 'deepseek');
      expect(s.features['support']!.provider, isNull);
      expect(s.features['moderation']!.action, 'review');
      expect(s.providers['openai']!.model, 'gpt-5-nano');
      expect(s.providers['openai']!.inputPerM, 0);
      expect(s.effectiveProvider('support'), 'deepseek');
    });
  });

  group('AiSettingsForm dirty tracking', () {
    late AiSettingsForm form;
    setUp(() => form = AiSettingsForm(AiSettings.fromJson(lt.aiSettingsData()['settings'] as Map<String, dynamic>)));

    test('typing the same numeric value is not a change', () {
      expect(form.isDirty, isFalse);
      expect(form.setText('gemini.output_per_m', '1.50'), isNull);
      expect(form.isDirty, isFalse);
      expect(form.setText('gemini.output_per_m', '1.6'), isNull);
      expect(form.isDirty, isTrue);
      expect(form.changedSections, ['providers.gemini']);
      form.setText('gemini.output_per_m', '1.5');
      expect(form.isDirty, isFalse);
    });

    test('invalid input marks dirty without touching the draft', () {
      final before = form.draft.fingerprint;
      expect(form.setText('budget', 'abc'), 'format');
      expect(form.setText('limit.support', '10001'), 'range');
      expect(form.setText('openai.model', 'gpt 5'), 'format');
      expect(form.setText('deepseek.model', ''), 'required');
      expect(form.hasErrors, isTrue);
      expect(form.errorCount, 4);
      expect(form.isDirty, isTrue);
      expect(form.draft.fingerprint, before);
      form.reset();
      expect(form.isDirty, isFalse);
      expect(form.hasErrors, isFalse);
    });

    test('structural updates, markSaved and resetProvider', () {
      form.update(form.draft.copyWith(enabled: false));
      form.update(form.draft.withFeature('support', form.draft.features['support']!.copyWith(provider: () => 'openai')));
      expect(form.changedSections, containsAll(['enabled', 'features.support']));
      final saved = form.draft;
      form.markSaved(saved);
      expect(form.isDirty, isFalse);
      expect(form.saved.features['support']!.provider, 'openai');

      form.setText('openai.input_per_m', 'x');
      form.resetProvider('openai');
      expect(form.hasErrors, isFalse);
      expect(form.draft.providers['openai']!.inputPerM, 0.05);
      expect(form.textFor('openai.output_per_m'), '0.4');
      expect(form.isDirty, isTrue);
    });

    test('text formatting drops trailing zeros', () {
      expect(AiSettingsForm.formatNumber(0.0028), '0.0028');
      expect(AiSettingsForm.formatNumber(14.0), '14');
      expect(AiSettingsForm.formatNumber(1.5), '1.5');
      expect(form.textFor('budget'), '12345');
      expect(form.textFor('limit.recommend'), '0');
    });
  });

  group('usage chart mapping', () {
    test('stacks features in a fixed order and fills rounding gaps', () {
      final data = AiCostChartData.from([
        const AiDailyUsage(date: '2026-09-01', requests: 3, costUsd: 0.5, byFeature: {'moderation': 0.1, 'support': 0.2}),
        const AiDailyUsage(date: '2026-09-02'),
        const AiDailyUsage(date: '2026-09-03', requests: 1, costUsd: 1.7, byFeature: {'listing_assist': 1.7, 'test': 0}),
      ]);
      expect(data.columns, hasLength(3));
      expect(data.columns[0].segments.map((s) => s.feature), ['support', 'moderation', 'other']);
      expect(data.columns[0].segments.last.value, closeTo(0.2, 1e-9));
      expect(data.columns[1].total, 0);
      expect(data.columns[1].segments, isEmpty);
      expect(data.columns[2].segments.map((s) => s.feature), ['listing_assist']);
      expect(data.features, ['support', 'listing_assist', 'moderation', 'other']);
      expect(data.peak, 1.7);
      expect(data.axisMax, 2);
      expect(data.isEmpty, isFalse);
    });

    test('segment sum never exceeds reported total', () {
      final data = AiCostChartData.from([
        const AiDailyUsage(date: '2026-09-01', costUsd: 0.3, byFeature: {'support': 0.2, 'recommend': 0.15}),
      ]);
      expect(data.columns.single.total, closeTo(0.35, 1e-9));
      expect(data.columns.single.segments.map((s) => s.feature), ['support', 'recommend']);
    });

    test('axis ceiling and label density', () {
      expect(AiCostChartData.niceCeiling(0), 1);
      expect(AiCostChartData.niceCeiling(0.0042), 0.005);
      expect(AiCostChartData.niceCeiling(0.011), 0.02);
      expect(AiCostChartData.niceCeiling(23), 25);
      expect(AiCostChartData.niceCeiling(100), 100);
      expect(AiCostChartData.niceCeiling(375), 500);

      final month = AiCostChartData.from([
        for (var i = 1; i <= 30; i++) AiDailyUsage(date: '2026-09-${i.toString().padLeft(2, '0')}', costUsd: i.toDouble()),
      ]);
      final labels = month.labelIndices(maxLabels: 7);
      expect(labels.first, 0);
      expect(labels.last, 29);
      expect(labels.length, lessThanOrEqualTo(7));
      expect(AiCostChartData.from(const []).isEmpty, isTrue);
      expect(AiCostChartData.from(const []).labelIndices(), isEmpty);
    });

    test('usage report parses and sorts breakdowns by cost', () {
      final report = AiUsageReport.fromJson(lt.aiUsageData());
      expect(report.summary.requests, 1234567);
      expect(report.summary.totalTokens, 9876543210 + 123456789);
      expect(report.byFeature.first.costUsd, greaterThanOrEqualTo(report.byFeature.last.costUsd));
      expect(report.byProvider.first.provider, 'deepseek');
      expect(report.daily, hasLength(30));
      expect(report.topUsers.first.publicId, isNotEmpty);
      expect(report.pendingReviews, 9999);
    });
  });

  group('formatting', () {
    test('USD keeps precision for tiny costs', () {
      expect(formatUsd(0), 'US\$0');
      expect(formatUsd(0.0042), 'US\$0.0042');
      expect(formatUsd(0.00004), '<US\$0.0001');
      expect(formatUsd(0.123), 'US\$0.123');
      expect(formatUsd(0.5), 'US\$0.50');
      expect(formatUsd(12.3456), 'US\$12.35');
      expect(formatUsd(1234.5), 'US\$1,235');
      expect(formatUsd(1500, compact: true), 'US\$1.5k');
      expect(formatUsdPrice(0.0028), 'US\$0.0028');
      expect(formatUsdPrice(0.14), 'US\$0.14');
      expect(formatUsdPrice(1.5), 'US\$1.50');
      expect(formatTokens(9876543210), '9.88B');
      expect(formatTokens(12345), '12.3K');
      expect(formatTokens(999), '999');
    });
  });

  group('listing responses', () {
    test('rejected listing reasons come from the message when not structured', () {
      final outcome = ListingOutcome.fromResponse(
        {'success': false, 'code': 'LISTING_REJECTED', 'message': '此商品未通過上架審核：非書籍商品、含站外聯絡方式'},
        fallbackError: 'x',
      );
      expect(outcome.isRejected, isTrue);
      expect(outcome.reasons, ['非書籍商品', '含站外聯絡方式']);
    });

    test('pending review is detected at top level or inside data', () {
      expect(ListingOutcome.fromResponse({'success': true, 'moderation': {'status': 'pending_review', 'reasons': ['a']}}, fallbackError: 'x').pendingReview, isTrue);
      expect(ListingOutcome.fromResponse({'success': true, 'data': {'moderation': {'status': 'pending_review'}}}, fallbackError: 'x').pendingReview, isTrue);
      expect(ListingOutcome.fromResponse({'success': true, 'data': {'book_id': 1}}, fallbackError: 'x').pendingReview, isFalse);
    });

    test('book review status and listing assist parsing', () {
      final book = Book.fromJson({...lt.book(1), 'review_status': 'pending', 'is_approved': false});
      expect(book.isPendingReview, isTrue);
      final result = lt.aiAssistResult();
      expect(result.fields.keys, containsAll(['title', 'isbn']));
      expect(result.category!.categoryId, 2);
      expect(result.sources.last.host, 'books.com.tw');
      final empty = AiListingAssist.fromJson({'fields': {'title': ''}, 'category': null, 'price': {'suggested': 0}});
      expect(empty.isEmpty, isTrue);
    });

    test('recommendations are grouped by basis and skip unknown books', () {
      final rec = AiRecommendations.fromJson({
        'data': [
          {'book': lt.book(3), 'reason': 'Same author as a favorite'},
          {'book': lt.book(4), 'reason': null},
          {'book': lt.book(5), 'reason': null},
          {'reason': 'missing book'},
        ],
        'groups': [
          {'kind': 'book', 'relation': 'favorite', 'book_id': 9, 'title': 'Norwegian Wood', 'book_ids': [3, 4]},
          {'kind': 'more', 'book_ids': [5, 99]},
        ],
        'meta': {'source': 'ai'},
      });
      expect(rec.books.map((b) => b.bookId), [3, 4, 5]);
      expect(rec.groups.map((g) => g.kind), ['book', 'more']);
      expect(rec.groups.first.relation, 'favorite');
      expect(rec.groups.first.title, 'Norwegian Wood');
      expect(rec.groups.last.books.map((b) => b.bookId), [5]);
      expect(rec.source, 'ai');
    });

    test('recommendations without groups fall back to one group', () {
      final rec = AiRecommendations.fromJson({
        'data': [
          {'book': lt.book(3)},
        ],
      });
      expect(rec.groups.single.kind, 'more');
      expect(rec.groups.single.books.single.bookId, 3);
    });
  });

  testWidgets('settings tab shows the save bar only while there are unsaved changes and sends the full document', (tester) async {
    SharedPreferences.setMockInitialValues({});
    ApiService.authToken = 't';
    Map<String, dynamic>? sent;
    final client = MockClient((req) async {
      final path = req.url.path.replaceFirst('/api', '');
      Object? data;
      if (path == '/admin/ai/settings' && req.method == 'GET') data = lt.aiSettingsData();
      if (path == '/admin/ai/settings' && req.method == 'PUT') {
        sent = jsonDecode(req.body) as Map<String, dynamic>;
        data = {...lt.aiSettingsData(), 'settings': sent!['settings']};
      }
      return http.Response(jsonEncode({'success': true, 'data': data}), 200, headers: {'content-type': 'application/json'});
    });

    Future<void> settle([int n = 10]) async {
      for (var i = 0; i < n; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    tester.view.physicalSize = const Size(1180, 820) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final dirtyLog = <bool>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
        locale: const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
        supportedLocales: LocaleProvider.supported,
        theme: AppTheme.build(Brightness.light),
        localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
        builder: (context, child) {
          S = AppLocalizations.of(context);
          return child!;
        },
        home: Scaffold(body: AiSettingsTab(onDirtyChanged: dirtyLog.add)),
      ));
      await settle();
      expect(find.byType(PrimaryButton), findsNothing);

      await tester.tap(find.byType(Switch).first);
      await settle(4);
      expect(find.byType(PrimaryButton), findsOneWidget);
      expect(dirtyLog, [true]);

      await tester.tap(find.byType(Switch).first);
      await settle(4);
      expect(dirtyLog, [true, false]);
      expect(find.byType(PrimaryButton), findsNothing);

      await tester.tap(find.byType(Switch).first);
      await settle(4);
      await tester.tap(find.byType(PrimaryButton));
      await settle();
      expect(sent, isNotNull);
      final settings = sent!['settings'] as Map<String, dynamic>;
      expect(settings['enabled'], isFalse);
      expect(settings.keys, containsAll(['default_provider', 'providers', 'features', 'limits']));
      expect(dirtyLog.last, isFalse);
      expect(find.byType(PrimaryButton), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 3));
    }, () => client);
  });

  group('usage accuracy', () {
    test('content-blocked and quota errors are not retryable', () {
      expect(const AiResult<int>.fail('x', code: 'AI_CONTENT_BLOCKED').isContentBlocked, isTrue);
      expect(const AiResult<int>.fail('x', code: 'AI_CONTENT_BLOCKED').canRetry, isFalse);
      expect(const AiResult<int>.fail('x', code: 'AI_DAILY_LIMIT').canRetry, isFalse);
      expect(const AiResult<int>.fail('x', code: 'AI_PROVIDER_ERROR').canRetry, isTrue);
      expect(const AiResult<int>.fail('x', code: 'NETWORK').canRetry, isTrue);
    });

    test('connection test parses each check and stays compatible with older responses', () {
      final result = AiTestResult.fromJson({
        'ok': false,
        'provider': 'deepseek',
        'model': 'deepseek-chat',
        'latency_ms': 820,
        'error': 'JSON：回應格式不正確',
        'checks': [
          {'name': 'text', 'status': 'ok', 'latency_ms': 820, 'error': null},
          {'name': 'json', 'status': 'failed', 'latency_ms': 15, 'error': '回應格式不正確'},
          {'name': 'image', 'status': 'skipped', 'latency_ms': 0},
          'bad',
        ],
      });
      expect(result.checks.map((c) => c.name), ['text', 'json', 'image']);
      expect(result.checks[0].ok, isTrue);
      expect(result.checks[1].ok, isFalse);
      expect(result.checks[1].error, '回應格式不正確');
      expect(result.checks[2].skipped, isTrue);
      expect(AiTestResult.fromJson({'ok': true, 'latency_ms': 5}).checks, isEmpty);
    });

    test('provider usage parses p95 latency and every feature has a stacking position', () {
      final usage = AiProviderUsage.fromJson({'provider': 'gemini', 'model': 'm', 'avg_latency_ms': 840, 'p95_latency_ms': 1900});
      expect(usage.avgLatencyMs, 840);
      expect(usage.p95LatencyMs, 1900);
      final failedOnly = AiProviderUsage.fromJson({'provider': 'gemini', 'model': 'm', 'avg_latency_ms': null, 'p95_latency_ms': null});
      expect(failedOnly.avgLatencyMs, isNull);
      expect(failedOnly.p95LatencyMs, isNull);

      final data = AiCostChartData.from([
        const AiDailyUsage(date: '2026-09-01', costUsd: 0.6, byFeature: {'admin_assist': 0.1, 'enrich': 0.1, 'book_chat_pick': 0.2, 'book_chat': 0.2}),
      ]);
      expect(data.features, ['book_chat', 'book_chat_pick', 'enrich', 'admin_assist']);
    });

    Widget settingsApp() => MaterialApp(
          locale: const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
          supportedLocales: LocaleProvider.supported,
          theme: AppTheme.build(Brightness.light),
          localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
          builder: (context, child) {
            S = AppLocalizations.of(context);
            return child!;
          },
          home: const Scaffold(body: AiSettingsTab(initialAdvancedOpen: true)),
        );

    testWidgets('connection test sends the unsaved model name and shows each check', (tester) async {
      SharedPreferences.setMockInitialValues({});
      ApiService.authToken = 't';
      final tests = <Map<String, dynamic>>[];
      final client = MockClient((req) async {
        final path = req.url.path.replaceFirst('/api', '');
        Object? data;
        if (path == '/admin/ai/settings') data = lt.aiSettingsData();
        if (path == '/admin/ai/test') {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          tests.add(body);
          data = {
            'ok': false,
            'provider': body['provider'],
            'model': body['model'],
            'latency_ms': 820,
            'reply': '連線成功',
            'error': 'JSON：回應格式不正確',
            'checks': [
              {'name': 'text', 'status': 'ok', 'latency_ms': 820, 'error': null},
              {'name': 'json', 'status': 'failed', 'latency_ms': 15, 'error': '回應格式不正確'},
              {'name': 'image', 'status': 'ok', 'latency_ms': 900, 'error': null},
            ],
          };
        }
        return http.Response(jsonEncode({'success': true, 'data': data}), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      });

      Future<void> settle([int n = 10]) async {
        for (var i = 0; i < n; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      tester.view.physicalSize = const Size(1180, 820) * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await http.runWithClient(() async {
        await tester.pumpWidget(settingsApp());
        await settle();

        final modelField = find.byWidgetPredicate((w) => w is TextField && w.controller?.text == 'gemini-3.1-flash-lite');
        await tester.scrollUntilVisible(modelField, 300, scrollable: find.byType(Scrollable).first);
        await tester.enterText(modelField, 'gemini-9-preview');
        await settle(3);

        final scrollable = find.byType(Scrollable).first;
        Future<void> tapGeminiTest() async {
          await tester.drag(scrollable, const Offset(0, 5000));
          await settle(3);
          await tester.tap(find.text(S.test).at(1));
        }

        await tapGeminiTest();
        await settle();
        expect(tests, [
          {'provider': 'gemini', 'model': 'gemini-9-preview'},
        ]);
        expect(find.byKey(const ValueKey('test-check-text')), findsOneWidget);
        expect(find.byKey(const ValueKey('test-check-json')), findsOneWidget);
        expect(find.byKey(const ValueKey('test-check-image')), findsOneWidget);
        expect(find.text('JSON：回應格式不正確'), findsOneWidget);

        await tester.scrollUntilVisible(find.byWidgetPredicate((w) => w is TextField && w.controller?.text == 'gemini-9-preview'), 300, scrollable: scrollable);
        await tester.enterText(find.byWidgetPredicate((w) => w is TextField && w.controller?.text == 'gemini-9-preview'), '');
        await settle(3);
        await tapGeminiTest();
        await settle(4);
        expect(tests, hasLength(1), reason: '模型名稱不合法時不送出測試');
        expect(find.text(S.pleaseFixHighlightedFields), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 3));
      }, () => client);
    });

    testWidgets('listing assist hides retry when the provider blocked the content', (tester) async {
      SharedPreferences.setMockInitialValues({});
      ApiService.authToken = 't';
      tester.view.physicalSize = const Size(390, 844) * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      var code = 'AI_CONTENT_BLOCKED';
      final client = MockClient((req) async => http.Response(
            jsonEncode({'success': false, 'code': code, 'message': code == 'AI_CONTENT_BLOCKED' ? '此內容無法由 AI 處理，請調整內容後再試' : 'AI 服務暫時無法使用，請稍後再試'}),
            code == 'AI_CONTENT_BLOCKED' ? 422 : 502,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ));

      Future<void> settle([int n = 8]) async {
        for (var i = 0; i < n; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      Widget sheet() => MaterialApp(
            locale: const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
            supportedLocales: LocaleProvider.supported,
            theme: AppTheme.build(Brightness.light),
            localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
            builder: (context, child) {
              S = AppLocalizations.of(context);
              return child!;
            },
            home: Scaffold(
              body: AiAssistProgressSheet(steps: const ['a', 'b'], run: () => ApiService().requestListingAssist(isbn: '9789573317241')),
            ),
          );

      await http.runWithClient(() async {
        await tester.pumpWidget(sheet());
        await settle();
        expect(find.text('此內容無法由 AI 處理，請調整內容後再試'), findsOneWidget);
        expect(find.text(S.retry), findsNothing);

        code = 'AI_PROVIDER_ERROR';
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(sheet());
        await settle();
        expect(find.text(S.retry), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 3));
      }, () => client);
    });
  });

  group('AI consent', () {
    test('status parses consent and providers', () {
      final status = AiStatusInfo.fromJson({
        'support': true,
        'consented': true,
        'providers_in_use': ['DeepSeek', '', 3, 'Google Gemini'],
      });
      expect(status.consented, isTrue);
      expect(status.providersInUse, ['DeepSeek', 'Google Gemini']);
      expect(AiStatusInfo.fromJson(const {}).consented, isFalse);
      expect(status.copyWith(consented: false).providersInUse, ['DeepSeek', 'Google Gemini']);
      expect(const AiResult<int>.fail('x', code: 'AI_CONSENT_REQUIRED').needsConsent, isTrue);
    });

    test('status parses re-consent state and the embedding provider', () {
      final status = AiStatusInfo.fromJson({
        'support': true,
        'consented': false,
        'consent_outdated': true,
        'providers_in_use': ['DeepSeek', 'OpenAI'],
        'embedding_provider': 'OpenAI',
      });
      expect(status.consentOutdated, isTrue);
      expect(status.embeddingProvider, 'OpenAI');
      expect(status.copyWith(consented: true).consentOutdated, isFalse);
      expect(status.copyWith(consented: true).embeddingProvider, 'OpenAI');
      expect(status.copyWith(consented: false).consentOutdated, isTrue);
      expect(AiStatusInfo.fromJson(const {'embedding_provider': ' '}).embeddingProvider, isNull);
      expect(AiStatusInfo.fromJson(const {}).consentOutdated, isFalse);
    });

    Widget app(Widget home) => MaterialApp(
          locale: const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
          supportedLocales: LocaleProvider.supported,
          theme: AppTheme.build(Brightness.light),
          localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
          builder: (context, child) {
            S = AppLocalizations.of(context);
            return child!;
          },
          home: home,
        );

    ({MockClient client, List<String> requests, List<Map<String, dynamic>> consents}) consentApi() {
      final requests = <String>[];
      final consents = <Map<String, dynamic>>[];
      final client = MockClient((req) async {
        final path = req.url.path.replaceFirst('/api', '');
        requests.add('${req.method} $path');
        Object? data;
        if (path == '/ai/consent') {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          consents.add(body);
          data = {'support': true, 'listing_assist': true, 'recommend': true, 'consented': body['granted'], 'providers_in_use': ['DeepSeek']};
        }
        if (path == '/ai/support/messages') {
          data = {
            'session_id': 1,
            'user_message': {'message_id': 1, 'role': 'user', 'content': 'q', 'created_at': lt.now},
            'reply': {'message_id': 2, 'role': 'assistant', 'content': '您好', 'created_at': lt.now},
            'suggest_handoff': false,
          };
        }
        return http.Response(jsonEncode({'success': true, 'data': data}), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      });
      return (client: client, requests: requests, consents: consents);
    }

    Future<void> settle(WidgetTester tester, [int n = 8]) async {
      for (var i = 0; i < n; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> pumpSheet(WidgetTester tester, AiStatusInfo status) async {
      tester.view.physicalSize = const Size(390, 2400) * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(Scaffold(body: AiConsentSheet(status: status))));
      await tester.pump();
    }

    testWidgets('consent sheet lists the data each feature sends, every recipient, retention and withdrawal', (tester) async {
      await pumpSheet(tester, const AiStatusInfo(
        support: true,
        listingAssist: true,
        recommend: true,
        bookChat: true,
        providersInUse: ['DeepSeek', 'Google Gemini', 'OpenAI'],
        embeddingProvider: 'OpenAI',
      ));
      for (final (label, detail) in [
        (S.aiSupport, S.messagesConversationHistoryEnterPlusOwn),
        (S.aiBookAdvisor, S.requestsConversationHistoryEnter),
        (S.listingAssist, S.isbnTitleConditionNotesPhotosSelect),
        (S.recommendations, S.bookDetailsFromSavedItemsPurchase),
      ]) {
        expect(find.text(label), findsOneWidget);
        expect(find.text(detail), findsOneWidget);
      }
      for (final item in ['訂單', '預約', '上架書籍', '審核原因', '錢包餘額', '客服工單']) {
        expect(S.messagesConversationHistoryEnterPlusOwn, contains(item));
      }
      for (final item in ['收藏', '購買紀錄', '購物車', '最近瀏覽']) {
        expect(S.bookDetailsFromSavedItemsPurchase, contains(item));
      }
      expect(find.text('DeepSeek、Google Gemini、OpenAI'), findsOneWidget);
      expect(find.text(S.questionsRequestsBookDetailsAlsoConverted('OpenAI')), findsOneWidget);
      expect(find.text(S.aiSupportBookAdvisorConversationsKept), findsOneWidget);
      expect(S.aiSupportBookAdvisorConversationsKept, contains('90 天'));
      expect(find.text(S.canTurnOffAiDataProcessing), findsOneWidget);
      expect(find.text(S.aiDataProcessingNoticeBeenUpdated), findsNothing);
    });

    testWidgets('consent sheet lists every feature the consent covers even when only one is open, and explains a re-consent', (tester) async {
      await pumpSheet(tester, const AiStatusInfo(listingAssist: true, consentOutdated: true, providersInUse: ['DeepSeek']));
      for (final (label, detail) in [
        (S.aiSupport, S.messagesConversationHistoryEnterPlusOwn),
        (S.aiBookAdvisor, S.requestsConversationHistoryEnter),
        (S.listingAssist, S.isbnTitleConditionNotesPhotosSelect),
        (S.recommendations, S.bookDetailsFromSavedItemsPurchase),
      ]) {
        expect(find.text(label), findsOneWidget);
        expect(find.text(detail), findsOneWidget);
      }
      expect(find.text(S.aiDataProcessingNoticeBeenUpdated), findsOneWidget);
      expect(find.text(S.questionsRequestsBookDetailsAlsoConverted('OpenAI')), findsNothing);
    });

    test('a consent rejected mid-session is re-read from the server so the sheet can explain an updated notice', () async {
      ApiService.authToken = 't';
      final client = MockClient((req) async => http.Response(
            jsonEncode({'success': true, 'data': {'support': true, 'consented': false, 'consent_outdated': true, 'providers_in_use': ['DeepSeek']}}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ));
      await http.runWithClient(() async {
        AiStatus.debugSet(const AiStatusInfo(support: true, consented: true, providersInUse: ['DeepSeek']));
        await AiStatus.markConsentRevoked();
        expect(AiStatus.value.consented, isFalse);
        expect(AiStatus.value.consentOutdated, isTrue);
      }, () => client);

      final offline = MockClient((req) async => throw http.ClientException('offline'));
      await http.runWithClient(() async {
        AiStatus.debugSet(const AiStatusInfo(support: true, consented: true, providersInUse: ['DeepSeek']));
        await AiStatus.markConsentRevoked();
        expect(AiStatus.value.consented, isFalse);
        expect(AiStatus.value.consentOutdated, isTrue, reason: '無法向伺服器確認時，先前已同意即視為說明已更新');
      }, () => offline);
      AiStatus.debugSet(AiStatusInfo.none);
      ApiService.authToken = null;
    });

    testWidgets('an outdated consent can still be turned off, which deletes conversations without agreeing again first', (tester) async {
      final consents = <Map<String, dynamic>>[];
      final client = MockClient((req) async {
        final path = req.url.path.replaceFirst('/api', '');
        Object? data = <String, Object?>{};
        if (path == '/ai/status') data = {'support': true, 'consented': false, 'consent_outdated': true, 'providers_in_use': ['DeepSeek']};
        if (path == '/users/me/deletion') data = {'pending': false, 'grace_days': 30};
        if (path == '/ai/consent') {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          consents.add(body);
          data = {'support': true, 'consented': body['granted'], 'consent_outdated': false, 'providers_in_use': ['DeepSeek']};
        }
        return http.Response(jsonEncode({'success': true, 'data': data}), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      });
      SharedPreferences.setMockInitialValues({});
      ApiService.authToken = 't';
      tester.view.physicalSize = const Size(390, 844) * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await http.runWithClient(() async {
        await tester.pumpWidget(app(const AccountPrivacyScreen()));
        await settle(tester);
        expect(find.text(S.aiDataProcessing), findsOneWidget);
        expect(find.text(S.consentRequiredAgain), findsOneWidget);
        expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

        await tester.tap(find.byType(Switch));
        await settle(tester);
        expect(find.byType(AiConsentSheet), findsNothing);
        expect(find.text(S.turnOffAiDataProcessing), findsOneWidget);
        await tester.tap(find.text(S.turnOff));
        await settle(tester);
        expect(consents, [
          {'granted': false},
        ]);
        expect(AiStatus.value.consentOutdated, isFalse);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 3));
      }, () => client);
      AiStatus.debugSet(AiStatusInfo.none);
    });

    testWidgets('consent can be withdrawn while every AI feature is unavailable, for example when the budget is used up', (tester) async {
      final consents = <Map<String, dynamic>>[];
      final client = MockClient((req) async {
        final path = req.url.path.replaceFirst('/api', '');
        Object? data = <String, Object?>{};
        if (path == '/ai/status') data = {'support': false, 'listing_assist': false, 'recommend': false, 'book_chat': false, 'consented': true, 'providers_in_use': <String>[]};
        if (path == '/users/me/deletion') data = {'pending': false, 'grace_days': 30};
        if (path == '/ai/consent') {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          consents.add(body);
          data = {'consented': body['granted'], 'providers_in_use': <String>[]};
        }
        return http.Response(jsonEncode({'success': true, 'data': data}), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      });
      SharedPreferences.setMockInitialValues({});
      ApiService.authToken = 't';
      tester.view.physicalSize = const Size(390, 844) * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await http.runWithClient(() async {
        await tester.pumpWidget(app(const AccountPrivacyScreen()));
        await settle(tester);
        expect(AiStatus.value.any, isFalse);
        expect(find.text(S.aiDataProcessing), findsOneWidget);
        expect(find.text(S.consentRequiredAgain), findsNothing);

        await tester.tap(find.byType(Switch));
        await settle(tester);
        await tester.tap(find.text(S.turnOff));
        await settle(tester);
        expect(consents, [
          {'granted': false},
        ]);
        expect(find.text(S.aiDataProcessing), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 3));
      }, () => client);
      AiStatus.debugSet(AiStatusInfo.none);
    });

    testWidgets('turning off AI data processing asks for confirmation before deleting conversations', (tester) async {
      SharedPreferences.setMockInitialValues({});
      ApiService.authToken = 't';
      tester.view.physicalSize = const Size(390, 844) * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final consents = <Map<String, dynamic>>[];
      final client = MockClient((req) async {
        final path = req.url.path.replaceFirst('/api', '');
        Object? data = <String, Object?>{};
        if (path == '/ai/status') data = {'support': true, 'consented': true, 'providers_in_use': ['DeepSeek']};
        if (path == '/users/me/deletion') data = {'pending': false, 'grace_days': 30};
        if (path == '/ai/consent') {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          consents.add(body);
          data = {'support': true, 'consented': body['granted'], 'providers_in_use': ['DeepSeek']};
        }
        return http.Response(jsonEncode({'success': true, 'data': data}), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      });

      await http.runWithClient(() async {
        await tester.pumpWidget(app(const AccountPrivacyScreen()));
        await settle(tester);
        expect(AiStatus.value.consented, isTrue);

        await tester.tap(find.byType(Switch));
        await settle(tester);
        expect(find.text(S.turnOffAiDataProcessing), findsOneWidget);
        expect(find.text(S.aiFeaturesStopAiSupportBook), findsOneWidget);
        await tester.tap(find.text(S.actionCancel));
        await settle(tester);
        expect(consents, isEmpty);
        expect(AiStatus.value.consented, isTrue);

        await tester.tap(find.byType(Switch));
        await settle(tester);
        await tester.tap(find.text(S.turnOff));
        await settle(tester);
        expect(consents, [
          {'granted': false},
        ]);
        expect(AiStatus.value.consented, isFalse);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 3));
      }, () => client);
      AiStatus.debugSet(AiStatusInfo.none);
    });

    testWidgets('support asks for consent before sending and does not call the API until the user agrees', (tester) async {
      SharedPreferences.setMockInitialValues({});
      ApiService.authToken = 't';
      tester.view.physicalSize = const Size(390, 844) * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final api = consentApi();

      await http.runWithClient(() async {
        await tester.pumpWidget(app(const AiSupportScreen()));
        AiStatus.debugSet(const AiStatusInfo(support: true, providersInUse: ['DeepSeek']));
        await settle(tester);

        await tester.tap(find.text(S.howDoIListBook));
        await settle(tester);
        expect(find.byType(AiConsentSheet), findsOneWidget);
        expect(find.text('DeepSeek'), findsOneWidget);
        expect(api.requests.where((r) => r.contains('/ai/support/messages')), isEmpty);

        await tester.tap(find.text(S.decline));
        await settle(tester);
        expect(find.byType(AiConsentSheet), findsNothing);
        expect(api.requests.where((r) => r.contains('/ai/support/messages') || r.contains('/ai/consent')), isEmpty);
        expect(AiStatus.value.consented, isFalse);

        await tester.tap(find.text(S.howDoIListBook));
        await settle(tester);
        expect(find.byType(AiConsentSheet), findsOneWidget);
        await tester.tap(find.text(S.agreeContinue));
        await settle(tester, 12);
        expect(api.consents, [
          {'granted': true, 'notice_version': aiConsentNoticeVersion},
        ]);
        expect(aiConsentNoticeVersion, 2);
        expect(AiStatus.value.consented, isTrue);
        expect(api.requests.where((r) => r == 'POST /ai/support/messages').length, 1);
        expect(api.requests.indexOf('PUT /ai/consent'), lessThan(api.requests.indexOf('POST /ai/support/messages')));

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 3));
      }, () => api.client);
      AiStatus.debugSet(AiStatusInfo.none);
    });

    testWidgets('listing assist asks for consent and skips the request when declined', (tester) async {
      SharedPreferences.setMockInitialValues({});
      ApiService.authToken = 't';
      tester.view.physicalSize = const Size(390, 844) * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final api = consentApi();
      AiListingAssist? result;
      var finished = false;

      await http.runWithClient(() async {
        await tester.pumpWidget(app(Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () async {
                  result = await runAiListingAssist(context, isbn: '9789573317241');
                  finished = true;
                },
                child: const Text('run'),
              ),
            ),
          ),
        )));
        AiStatus.debugSet(const AiStatusInfo(listingAssist: true, providersInUse: ['Google Gemini']));
        await settle(tester, 2);

        await tester.tap(find.text('run'));
        await settle(tester);
        expect(find.byType(AiConsentSheet), findsOneWidget);
        expect(find.text('Google Gemini'), findsOneWidget);
        expect(find.byType(AiAssistProgressSheet), findsNothing);

        await tester.tap(find.text(S.decline));
        await settle(tester);
        expect(finished, isTrue);
        expect(result, isNull);
        expect(find.byType(AiAssistProgressSheet), findsNothing);
        expect(api.requests, isEmpty);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 3));
      }, () => api.client);
      AiStatus.debugSet(AiStatusInfo.none);
    });
  });
}
