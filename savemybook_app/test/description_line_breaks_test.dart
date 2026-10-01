import 'package:flutter_test/flutter_test.dart';

import 'package:savemybook_app/utils/api_helpers.dart';

void main() {
  test('簡介中字面的換行符號還原為真正的換行', () {
    expect(unescapeLineBreaks(r'第一段。\n\n第二段。\r\n第三段。'), '第一段。\n\n第二段。\n第三段。');
  });

  test('已是真正換行或沒有換行的簡介維持不變', () {
    expect(unescapeLineBreaks('第一段。\n第二段。'), '第一段。\n第二段。');
    expect(unescapeLineBreaks('沒有換行的簡介'), '沒有換行的簡介');
    expect(unescapeLineBreaks(null), isNull);
  });
}
