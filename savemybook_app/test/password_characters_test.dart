import 'package:flutter_test/flutter_test.dart';
import 'package:savemybook_app/widgets/app_forms.dart';

void main() {
  test('密碼驗證拒絕非半形可見字元', () {
    expect(Validators.password('abc12345'), isNull);
    expect(Validators.password(r'Ab1!@#$%^&*()_+-=[]{}'), isNull);
    expect(Validators.password('密碼abc12345'), isNotNull);
    expect(Validators.password('abc 12345'), isNotNull);
    expect(Validators.password('ａｂｃ12345'), isNotNull);
    expect(Validators.password('abc12345😀'), isNotNull);
  });

  test('貼上含中文的內容時整筆拒絕並通知', () {
    var rejected = 0;
    final formatter = PasswordCharactersFormatter(onRejected: () => rejected++);
    const old = TextEditingValue(text: 'abc');

    final pasted = formatter.formatEditUpdate(old, const TextEditingValue(text: 'abc中文123'));
    expect(pasted.text, 'abc');
    expect(rejected, 1);

    final typed = formatter.formatEditUpdate(old, const TextEditingValue(text: 'abc1!'));
    expect(typed.text, 'abc1!');
    expect(rejected, 1);
  });
}
