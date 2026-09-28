import 'package:flutter_test/flutter_test.dart';

import 'package:savemybook_app/models/ai.dart';

void main() {
  test('語意檢索狀態：解析模型與向量數，缺少欄位時視為未啟用', () {
    final ready = AiRetrievalStatus.fromJson({
      'ready': true,
      'provider': 'openai',
      'model': 'text-embedding-3-small',
      'counts': {'book': 120, 'knowledge': '8'},
    });
    expect(ready.ready, isTrue);
    expect(ready.provider, 'openai');
    expect(ready.books, 120);
    expect(ready.knowledge, 8);
    expect(ready.bookCoverage, isNull);
    expect(ready.lastSyncAt, isNull);
    expect(ready.lastError, isNull);
    expect(ready.syncPausedUntil, isNull);
    expect(ready.queryPausedUntil, isNull);

    final missing = AiRetrievalStatus.fromJson(null);
    expect(missing.ready, isFalse);
    expect(missing.provider, isNull);
    expect(AiSettingsBundle.fromJson(const {}).retrieval.ready, isFalse);
  });

  test('語意檢索狀態：解析涵蓋率、最近同步、最近錯誤與同步／查詢各自的暫停時間', () {
    final status = AiRetrievalStatus.fromJson({
      'ready': true,
      'counts': {'book': 120},
      'coverage': {
        'book': {'indexed': 99, 'total': 100},
        'knowledge': {'indexed': 0, 'total': 0},
      },
      'last_sync_at': '2026-09-28T02:10:00.000Z',
      'last_error': {'at': '2026-09-28T02:12:00.000Z', 'purpose': 'query', 'code': 'TIMEOUT', 'detail': '  '},
      'cooldown_until': {'sync': null, 'query': '2026-09-28T02:17:00.000Z'},
    });
    expect(status.bookCoverage!.indexed, 99);
    expect(status.bookCoverage!.ratio, closeTo(0.99, 1e-9));
    expect(status.knowledgeCoverage!.ratio, 1, reason: '沒有文件時視為完整');
    expect(status.lastSyncAt, DateTime.utc(2026, 9, 28, 2, 10));
    expect(status.lastError!.code, 'TIMEOUT');
    expect(status.lastError!.purpose, 'query');
    expect(status.lastError!.detail, isNull);
    expect(status.syncPausedUntil, isNull);
    expect(status.queryPausedUntil, DateTime.utc(2026, 9, 28, 2, 17));
  });
}
