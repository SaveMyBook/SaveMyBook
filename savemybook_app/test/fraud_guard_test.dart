import 'package:flutter_test/flutter_test.dart';

import 'package:savemybook_app/features/chat/fraud_guard.dart';

void main() {
  test('偵測私下匯款、站外交易與站外聯絡方式', () {
    expect(FraudGuard.detect('可以先匯款給我嗎'), FraudSignal.payment);
    expect(FraudGuard.detect('郵局帳號 0001234 5678901'), FraudSignal.payment);
    expect(FraudGuard.detect('我們私下轉帳比較快'), FraudSignal.payment);
    expect(FraudGuard.detect('不用透過平台啦，直接約'), FraudSignal.offsite);
    expect(FraudGuard.detect('加我 LINE 比較方便'), FraudSignal.contact);
    expect(FraudGuard.detect('我的 line id: book123'), FraudSignal.contact);
    expect(FraudGuard.detect('打給我 0912-345-678'), FraudSignal.contact);
    expect(FraudGuard.detect('寄信到 abc@gmail.com'), FraudSignal.contact);
  });

  test('一般對話與 App 內轉帳用語不提醒', () {
    for (final text in [
      '請問書況如何？',
      '我用聊天室轉帳給你',
      '訂單 SMB20260924190300123456 已付款',
      '這本書 2024 年出版，共 320 頁',
      '@小明 你覺得呢',
      '明天下午可以去書櫃取書',
    ]) {
      expect(FraudGuard.detect(text), isNull, reason: text);
    }
  });
}
