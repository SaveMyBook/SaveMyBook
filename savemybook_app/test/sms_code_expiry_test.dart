import 'package:flutter_test/flutter_test.dart';
import 'package:savemybook_app/services/social_auth_service.dart';

import 'fake_auth_gateway.dart';

void main() {
  test('驗證碼寄出後 5 分鐘內可驗證，逾時即拒絕且不呼叫 Firebase', () async {
    var now = DateTime(2026, 9, 17, 10);
    final gateway = FakeAuthGateway();
    final controller = PhoneSignInController(gateway: gateway, clock: () => now);
    addTearDown(controller.dispose);

    await controller.send('+886912345678');
    expect(controller.stage, PhoneSignInStage.codeSent);
    expect(controller.codeRemaining, const Duration(minutes: 5));
    expect(controller.codeExpired, isFalse);

    now = now.add(const Duration(minutes: 4, seconds: 59));
    expect(controller.codeExpired, isFalse);
    expect(controller.codeRemaining, const Duration(seconds: 1));

    now = now.add(const Duration(seconds: 1));
    expect(controller.codeExpired, isTrue);
    expect(controller.canResend, isTrue, reason: '失效後不必等重送倒數即可重新傳送');

    final before = gateway.codeCount;
    final ok = await controller.submitCode('123456');
    expect(ok, isFalse);
    expect(controller.error, isNotNull);
    expect(gateway.codeCount, before, reason: '逾時的驗證碼不得送往 Firebase');
  });

  test('重新傳送後重新計算 5 分鐘', () async {
    var now = DateTime(2026, 9, 17, 10);
    final controller = PhoneSignInController(gateway: FakeAuthGateway(), clock: () => now);
    addTearDown(controller.dispose);

    await controller.send('+886912345678');
    now = now.add(const Duration(minutes: 6));
    expect(controller.codeExpired, isTrue);

    await controller.resend();
    expect(controller.codeExpired, isFalse);
    expect(controller.codeRemaining, const Duration(minutes: 5));
  });
}
