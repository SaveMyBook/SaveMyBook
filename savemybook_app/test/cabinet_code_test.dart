import 'package:flutter_test/flutter_test.dart';

import 'package:savemybook_app/services/cabinet_code.dart';
import 'package:savemybook_app/services/deep_link_service.dart';

const _token = '3f9c0a5e1d2b4c6a8e0f1a2b3c4d5e6f';

void main() {
  group('parseCabinetCode', () {
    test('接受書櫃 QR Code，回傳小寫的挑戰碼', () {
      expect(parseCabinetCode('savemybook://k/$_token'), _token);
      expect(parseCabinetCode('savemybook://k/$_token/'), _token);
      expect(parseCabinetCode('  savemybook://k/$_token \n'), _token);
      expect(parseCabinetCode('SaveMyBook://K/${_token.toUpperCase()}'), _token);
    });

    test('長度、字元或路徑不符時回傳 null', () {
      expect(parseCabinetCode('savemybook://k/${_token.substring(1)}'), isNull);
      expect(parseCabinetCode('savemybook://k/${_token}0'), isNull);
      expect(parseCabinetCode('savemybook://k/${_token.replaceFirst('3', 'g')}'), isNull);
      expect(parseCabinetCode('savemybook://k/$_token?x=1'), isNull);
      expect(parseCabinetCode('savemybook://k/$_token//'), isNull);
      expect(parseCabinetCode('savemybook://kk/$_token'), isNull);
      expect(parseCabinetCode('https://api.savemybook.today/k/$_token'), isNull);
      expect(parseCabinetCode(''), isNull);
    });

    test('分享連結與授權連結不會被誤判為書櫃連結', () {
      expect(parseCabinetCode('savemybook://b/$_token'), isNull);
      expect(parseCabinetCode('savemybook://u/$_token'), isNull);
      expect(parseCabinetCode('https://api.savemybook.today/b/$_token'), isNull);
      expect(parseCabinetCode('savemybook://auth/oauth?code=abc'), isNull);
      expect(isCabinetCode('savemybook://k/$_token'), isTrue);
    });
  });

  group('DeepLinkService', () {
    setUp(() {
      DeepLinkService.reset();
      DeepLinkService.onCabinetLink = null;
      DeepLinkService.onBookLink = null;
      DeepLinkService.onProfileLink = null;
    });

    test('書櫃連結只開啟掃描頁，不交出連結中的碼，也不當成分享連結', () {
      var opened = 0;
      final books = <String>[];
      DeepLinkService.onCabinetLink = () => opened++;
      DeepLinkService.onBookLink = books.add;

      DeepLinkService.deliver('savemybook://k/$_token');

      expect(opened, 1);
      expect(books, isEmpty);
    });

    test('處理器尚未設定時暫存，設定後由 flushPending 送出一次', () {
      DeepLinkService.deliver('savemybook://k/$_token');
      var opened = 0;
      DeepLinkService.onCabinetLink = () => opened++;

      DeepLinkService.flushPending();
      DeepLinkService.flushPending();

      expect(opened, 1);
    });

    test('分享連結照舊交給書籍處理器', () {
      var opened = 0;
      final books = <String>[];
      DeepLinkService.onCabinetLink = () => opened++;
      DeepLinkService.onBookLink = books.add;

      DeepLinkService.deliver('savemybook://b/$_token');

      expect(opened, 0);
      expect(books, [_token]);
    });

    test('reset 會清掉尚未送出的書櫃連結', () {
      DeepLinkService.deliver('savemybook://k/$_token');
      DeepLinkService.reset();
      var opened = 0;
      DeepLinkService.onCabinetLink = () => opened++;

      DeepLinkService.flushPending();

      expect(opened, 0);
    });
  });
}
