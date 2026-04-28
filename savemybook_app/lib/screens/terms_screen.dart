import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.scaffold,
      appBar: AppBar(
        backgroundColor: c.headerBg,
        title: const Text('服務條款', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Text(
          '''歡迎使用 SaveMyBook（以下簡稱「本平台」）。請您在註冊或使用本平台服務前，詳細閱讀以下服務條款：

1. 認知與接受條款
當您完成會員註冊手續或開始使用本平台服務時，即表示您已閱讀、瞭解並同意接受本服務條款之所有內容。如您不同意本條款之全部或部分內容，請勿使用本平台服務。

2. 使用者註冊與義務
您同意於註冊時提供正確、最新及完整的個人資料。若您提供任何錯誤或不實資料，本平台有權暫停或終止您的帳號，並拒絕您使用本服務。您有妥善保管帳號及密碼之義務，並對利用該密碼及帳號所進行的一切行為負完全責任。

3. 交易規則與智慧書櫃使用
本平台提供買賣雙方透過智慧書櫃進行實體書籍交易之媒合服務。
(1) 賣家上架書籍時，應如實填寫書況與相關資訊，並於訂單成立後，依約定期限將書籍放入指定之智慧書櫃。
(2) 買家應於收到取件通知後，於規定期限內前往指定智慧書櫃憑 QR Code 或取件碼取書。
(3) 若買賣任一方未於期限內完成放書或取書，系統將自動取消訂單，並可能影響未履行義務方之會員信用評分。

4. 費用與支付
本平台內之交易款項將透過電子錢包或指定的第三方支付服務處理。本平台可能依據交易金額收取一定比例之平台手續費，相關費率將於系統中另行公告。

5. 交易糾紛與退款
若買家取書後發現書籍狀況與賣家描述有重大落差，可於取件後 24 小時內透過系統發起「交易申訴」。本平台將介入仲裁，並視證據決定是否進行退款。經本平台仲裁確認需退款者，款項將退回買家之電子錢包。

6. 系統服務中斷
本平台系統可能會因例行性維護、升級或不可抗力之因素而發生服務中斷、延遲或資料遺失。本平台將盡力維持系統正常運作，但對上述情況所造成之不便或損害，不負賠償責任。

7. 智慧財產權
本平台上之所有內容（包含但不限於文字、圖片、標誌、商標及程式碼）之智慧財產權均屬本平台或相關權利人所有，未經事前書面同意，任何人不得逕自使用、重製或散布。

8. 條款修改與終止
本平台保留隨時修改本服務條款之權利。條款修改後將於系統內公告，不另行個別通知。繼續使用本服務即視為同意修改後之內容。本平台亦保留因違反本條款或其他正當理由，隨時終止您使用本服務之權利。''',
          style: TextStyle(color: c.textPrimary, fontSize: 15, height: 1.8),
        ),
      ),
    );
  }
}