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

    final missing = AiRetrievalStatus.fromJson(null);
    expect(missing.ready, isFalse);
    expect(missing.provider, isNull);
    expect(AiSettingsBundle.fromJson(const {}).retrieval.ready, isFalse);
  });
}
