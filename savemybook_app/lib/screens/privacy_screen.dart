import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.scaffold,
      appBar: AppBar(
        backgroundColor: c.headerBg,
        title: const Text('隱私權政策', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Text(
          '''SaveMyBook（以下簡稱「本平台」）非常重視您的隱私權。為讓您安心使用本平台之各項服務，特此向您說明我們的隱私權保護政策：

1. 隱私權保護政策的適用範圍
隱私權保護政策內容，包括本平台如何處理在您使用網站服務時收集到的個人識別資料。隱私權保護政策不適用於本平台以外的相關連結網站，也不適用於非本平台所委託或參與管理的人員。

2. 個人資料的蒐集、處理及利用方式
(1) 當您註冊本平台帳號、使用各項服務或參與活動時，我們將視業務或活動性質請您提供必要的個人資料，包含但不限於：電子郵件、暱稱、手機號碼等。
(2) 在您使用定位功能尋找附近智慧書櫃時，本平台會請求存取您的 GPS 位置資訊。該資訊僅即時用於計算距離，不會被永久儲存或追蹤您的行蹤。
(3) 您的交易紀錄、書籍資訊、聊天紀錄與錢包餘額等將儲存於我們的資料庫中，以提供完整的平台服務。

3. 資料之保護
本平台主機均設有防火牆、防毒系統等相關的各項資訊安全設備及必要的安全防護措施，保護您的個人資料。所有傳輸過程皆採用 SSL 加密技術，您的密碼亦經不可逆的雜湊演算法處理，確保資料安全。

4. 網站對外的相關連結
本平台的網頁提供其他網站的網路連結，您也可經由本平台所提供的連結，點選進入其他網站。但該連結網站不適用本平台的隱私權保護政策。

5. 與第三人共用個人資料之政策
本平台絕不會提供、交換、出租或出售任何您的個人資料給其他個人、團體、私人企業或公務機關，但有法律依據或合約義務者，不在此限。包含：
(1) 經由您書面同意。
(2) 法律明文規定。
(3) 為免除您生命、身體、自由或財產上之危險。
(4) 當您在平台上的行為違反服務條款或可能損害或妨礙平台權益時，經研析揭露您的個人資料是為了辨識、聯絡或採取法律行動所必要者。

6. Cookie 之使用
為了提供您最佳的服務，本平台會在您的裝置中放置並取用我們的 Cookie。若您不願接受 Cookie 的寫入，您可在裝置設定中拒絕，但可能會導至部分功能無法正常執行。

7. 您的權利
您隨時可於本平台的「會員中心」中查閱或修改您的個人資料。若您希望刪除帳號及相關個人數據，請透過客服管道與我們聯繫，我們將依法於合理期間內處理您的請求。

8. 隱私權保護政策之修正
本平台隱私權保護政策將因應需求隨時進行修正，修正後的條款將刊登於網站上。''',
          style: TextStyle(color: c.textPrimary, fontSize: 15, height: 1.8),
        ),
      ),
    );
  }
}