import 'package:flutter_test/flutter_test.dart';

import 'package:savemybook_app/features/admin/ai/ai_labels.dart';
import 'package:savemybook_app/i18n/strings.dart';

void main() {
  test('上架審核類別：每個伺服器類別都有中文名稱，未知類別不顯示英文代碼', () {
    for (final id in ['not_book', 'prohibited', 'adult', 'contact', 'misleading', 'price', 'source']) {
      expect(AiLabels.reviewCategory(id), isNot(id), reason: id);
    }
    expect(AiLabels.reviewCategory('source'), '館藏或非正規來源');
    expect(AiLabels.reviewCategory('something_new'), S.ticketCatOther);
  });
}
