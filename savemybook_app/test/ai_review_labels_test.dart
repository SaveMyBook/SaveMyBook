import 'package:flutter_test/flutter_test.dart';

import 'package:savemybook_app/features/admin/ai/ai_labels.dart';
import 'package:savemybook_app/i18n/strings.dart';
import 'package:savemybook_app/models/ai.dart';

void main() {
  test('上架審核類別：每個伺服器類別都有中文名稱，未知類別不顯示英文代碼', () {
    for (final id in ['not_book', 'prohibited', 'adult', 'contact', 'misleading', 'price', 'source']) {
      expect(AiLabels.reviewCategory(id), isNot(id), reason: id);
    }
    expect(AiLabels.reviewCategory('source'), '館藏或非正規來源');
    expect(AiLabels.reviewCategory('something_new'), S.ticketCatOther);
  });

  test('用量功能：書目補齊、爭議分析與書籍顧問選書都有專屬名稱，不歸入「其他」', () {
    expect(AiLabels.feature(AiFeatures.enrich), '書籍資料補齊');
    expect(AiLabels.feature(AiFeatures.adminAssist), '爭議分析');
    expect(AiLabels.feature(AiFeatures.bookChatPick), '書籍顧問選書');
    for (final id in [AiFeatures.enrich, AiFeatures.adminAssist, AiFeatures.bookChatPick]) {
      expect(AiLabels.feature(id), isNot(S.ticketCatOther), reason: id);
    }
    expect(AiLabels.feature('future_feature'), S.ticketCatOther);
  });

  test('錯誤代碼：預算用盡與內容遭阻擋顯示中文說明', () {
    expect(AiLabels.errorCode('BUDGET_EXCEEDED'), '本月預算已用盡');
    expect(AiLabels.errorCode('AI_CONTENT_BLOCKED'), AiLabels.errorCode('BLOCKED'));
    expect(AiLabels.errorCode('BLOCKED'), '內容遭服務安全機制拒絕');
  });

  test('連線測試項目名稱', () {
    expect(AiLabels.testCheck(AiTestCheck.text), '純文字');
    expect(AiLabels.testCheck(AiTestCheck.json), 'JSON');
    expect(AiLabels.testCheck(AiTestCheck.image), '圖片辨識');
  });
}
