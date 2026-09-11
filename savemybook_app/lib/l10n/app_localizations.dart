// 由 tool/gen_l10n.py 從 lib/l10n/*.arb 產生，請不要手動編輯。

import 'package:flutter/widgets.dart';

abstract class AppLocalizations {
  const AppLocalizations();

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
    Locale('ko'),
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  ];

  String get orderPendingPayment;
  String get orderPendingDeposit;
  String get orderDeposited;
  String get orderPendingPickup;
  String get orderCompleted;
  String get orderCancelled;
  String get orderRefunding;
  String get orderRefunded;
  String get orderBuyerPendingDeposit;
  String get orderBuyerDeposited;
  String get orderBuyerRefunding;
  String get orderFlowDeposit;
  String get orderFlowDeposited;
  String get orderFlowPickup;
  String get orderFlowCompleted;
  String get bookOnSale;
  String get bookReserved;
  String get bookSold;
  String get bookRemoved;
  String get conditionLikeNew;
  String get conditionGood;
  String get conditionFair;
  String get conditionPoor;
  String get conditionUnknown;
  String get photoCover;
  String get photoBack;
  String get photoBarcode;
  String get memberNormal;
  String get memberInactive;
  String get memberBlacklisted;
  String get roleBuyerSeller;
  String get roleAdmin;
  String get noLevel;
  String get reportPending;
  String get reportReviewing;
  String get reportResolved;
  String get reportDismissed;
  String get disputePending;
  String get disputeProcessing;
  String get disputeResolved;
  String get disputeRefundManual;
  String get disputeRefundAuto;
  String get disputeDismissed;
  String get disputeMediated;
  String get ticketOpen;
  String get ticketPending;
  String get ticketResolved;
  String get ticketClosed;
  String get ticketCatAccount;
  String get ticketCatTrade;
  String get ticketCatWallet;
  String get ticketCatCabinet;
  String get ticketCatBug;
  String get ticketCatOther;
  String get faqCatGeneral;
  String get faqCatAccount;
  String get faqCatTrade;
  String get faqCatWallet;
  String get faqCatCabinet;
  String get slotEmpty;
  String get slotOccupied;
  String get slotReserved;
  String get slotMaintenance;
  String get txnDeposit;
  String get txnWithdrawal;
  String get txnPurchase;
  String get txnSaleIncome;
  String get txnRefund;
  String get txnAdminAdjust;
  String get announceGeneral;
  String get announceMaintenance;
  String get announcePromotion;
  String get announcePolicy;
  String get loadFailed;
  String get updateFailed;
  String get saveFailed;
  String get networkError;
  String get unknownUser;
  String get deletedUser;
  String get actionConfirm;
  String get actionCancel;
  String get actionSave;
  String get actionDelete;
  String get actionEdit;
  String get actionSubmit;
  String get actionClose;
  String get actionBack;
  String get actionRetry;
  String get actionSelect;
  String get actionAll;
  String get actionSearch;
  String get appearance;
  String get appearanceLight;
  String get appearanceDark;
  String get appearanceSystem;
  String get appearanceHint;
  String get language;
  String get languageSystem;
  String get languageHint;
}

class _LEn extends AppLocalizations {
  const _LEn();

  @override
  String get orderPendingPayment => 'Awaiting payment';

  @override
  String get orderPendingDeposit => 'Awaiting drop-off';

  @override
  String get orderDeposited => 'Dropped off';

  @override
  String get orderPendingPickup => 'Ready for pickup';

  @override
  String get orderCompleted => 'Completed';

  @override
  String get orderCancelled => 'Cancelled';

  @override
  String get orderRefunding => 'Refunding';

  @override
  String get orderRefunded => 'Refunded';

  @override
  String get orderBuyerPendingDeposit => 'Waiting for seller drop-off';

  @override
  String get orderBuyerDeposited => 'Ready for pickup';

  @override
  String get orderBuyerRefunding => 'Under dispute';

  @override
  String get orderFlowDeposit => 'Seller drop-off';

  @override
  String get orderFlowDeposited => 'Placed in locker';

  @override
  String get orderFlowPickup => 'Buyer pickup';

  @override
  String get orderFlowCompleted => 'Transaction complete';

  @override
  String get bookOnSale => 'On sale';

  @override
  String get bookReserved => 'Reserved';

  @override
  String get bookSold => 'Sold';

  @override
  String get bookRemoved => 'Delisted';

  @override
  String get conditionLikeNew => 'Brand new';

  @override
  String get conditionGood => 'Like new';

  @override
  String get conditionFair => 'Good';

  @override
  String get conditionPoor => 'Acceptable';

  @override
  String get conditionUnknown => 'Unknown condition';

  @override
  String get photoCover => 'Front cover';

  @override
  String get photoBack => 'Back cover';

  @override
  String get photoBarcode => 'Barcode';

  @override
  String get memberNormal => 'Active';

  @override
  String get memberInactive => 'Suspended';

  @override
  String get memberBlacklisted => 'Blacklisted';

  @override
  String get roleBuyerSeller => 'Member';

  @override
  String get roleAdmin => 'Administrator';

  @override
  String get noLevel => 'No tier yet';

  @override
  String get reportPending => 'Pending';

  @override
  String get reportReviewing => 'Under review';

  @override
  String get reportResolved => 'Resolved';

  @override
  String get reportDismissed => 'Dismissed';

  @override
  String get disputePending => 'Awaiting review';

  @override
  String get disputeProcessing => 'In progress';

  @override
  String get disputeResolved => 'Decided';

  @override
  String get disputeRefundManual => 'Manual refund';

  @override
  String get disputeRefundAuto => 'Automatic refund';

  @override
  String get disputeDismissed => 'Dispute dismissed';

  @override
  String get disputeMediated => 'Settled by mediation';

  @override
  String get ticketOpen => 'Open';

  @override
  String get ticketPending => 'Replied by support';

  @override
  String get ticketResolved => 'Resolved';

  @override
  String get ticketClosed => 'Closed';

  @override
  String get ticketCatAccount => 'Account';

  @override
  String get ticketCatTrade => 'Transactions';

  @override
  String get ticketCatWallet => 'Coins';

  @override
  String get ticketCatCabinet => 'Lockers';

  @override
  String get ticketCatBug => 'Something is broken';

  @override
  String get ticketCatOther => 'Other';

  @override
  String get faqCatGeneral => 'General';

  @override
  String get faqCatAccount => 'Account';

  @override
  String get faqCatTrade => 'Transactions';

  @override
  String get faqCatWallet => 'Coins';

  @override
  String get faqCatCabinet => 'Lockers';

  @override
  String get slotEmpty => 'Empty';

  @override
  String get slotOccupied => 'In use';

  @override
  String get slotReserved => 'Reserved';

  @override
  String get slotMaintenance => 'Under maintenance';

  @override
  String get txnDeposit => 'Top-up';

  @override
  String get txnWithdrawal => 'Withdrawal';

  @override
  String get txnPurchase => 'Purchase';

  @override
  String get txnSaleIncome => 'Sale proceeds';

  @override
  String get txnRefund => 'Refund';

  @override
  String get txnAdminAdjust => 'Support adjustment';

  @override
  String get announceGeneral => 'General';

  @override
  String get announceMaintenance => 'Maintenance';

  @override
  String get announcePromotion => 'Promotion';

  @override
  String get announcePolicy => 'Policy';

  @override
  String get loadFailed => 'Could not load. Please try again.';

  @override
  String get updateFailed => 'Could not update. Please try again.';

  @override
  String get saveFailed => 'Could not save. Please try again.';

  @override
  String get networkError => 'No connection. Check your network.';

  @override
  String get unknownUser => 'Unknown user';

  @override
  String get deletedUser => 'Deleted user';

  @override
  String get actionConfirm => 'Confirm';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionSave => 'Save';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionEdit => 'Edit';

  @override
  String get actionSubmit => 'Submit';

  @override
  String get actionClose => 'Close';

  @override
  String get actionBack => 'Back';

  @override
  String get actionRetry => 'Retry';

  @override
  String get actionSelect => 'Select';

  @override
  String get actionAll => 'All';

  @override
  String get actionSearch => 'Search';

  @override
  String get appearance => 'Appearance';

  @override
  String get appearanceLight => 'Light';

  @override
  String get appearanceDark => 'Dark';

  @override
  String get appearanceSystem => 'Follow system';

  @override
  String get appearanceHint => 'Follow system switches automatically with your device setting.';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'Follow system';

  @override
  String get languageHint => 'Follow system uses your device language setting.';

}

class _LJa extends AppLocalizations {
  const _LJa();

  @override
  String get orderPendingPayment => '支払い待ち';

  @override
  String get orderPendingDeposit => '預け入れ待ち';

  @override
  String get orderDeposited => '預け入れ済み';

  @override
  String get orderPendingPickup => '受け取り待ち';

  @override
  String get orderCompleted => '完了';

  @override
  String get orderCancelled => 'キャンセル済み';

  @override
  String get orderRefunding => '返金処理中';

  @override
  String get orderRefunded => '返金済み';

  @override
  String get orderBuyerPendingDeposit => '出品者の預け入れ待ち';

  @override
  String get orderBuyerDeposited => '受け取り待ち';

  @override
  String get orderBuyerRefunding => '異議申立中';

  @override
  String get orderFlowDeposit => '出品者が預け入れ';

  @override
  String get orderFlowDeposited => 'ロッカーに預け入れ済み';

  @override
  String get orderFlowPickup => '購入者が受け取り';

  @override
  String get orderFlowCompleted => '取引完了';

  @override
  String get bookOnSale => '販売中';

  @override
  String get bookReserved => '予約済み';

  @override
  String get bookSold => '売却済み';

  @override
  String get bookRemoved => '出品停止';

  @override
  String get conditionLikeNew => '新品';

  @override
  String get conditionGood => 'ほぼ新品';

  @override
  String get conditionFair => '良好';

  @override
  String get conditionPoor => '可';

  @override
  String get conditionUnknown => '状態不明';

  @override
  String get photoCover => '表紙';

  @override
  String get photoBack => '裏表紙';

  @override
  String get photoBarcode => 'バーコード';

  @override
  String get memberNormal => '正常';

  @override
  String get memberInactive => '利用停止';

  @override
  String get memberBlacklisted => 'ブラックリスト';

  @override
  String get roleBuyerSeller => '一般会員';

  @override
  String get roleAdmin => '管理者';

  @override
  String get noLevel => 'ランク未設定';

  @override
  String get reportPending => '未対応';

  @override
  String get reportReviewing => '審査中';

  @override
  String get reportResolved => '対応済み';

  @override
  String get reportDismissed => '却下';

  @override
  String get disputePending => '受付待ち';

  @override
  String get disputeProcessing => '対応中';

  @override
  String get disputeResolved => '裁定済み';

  @override
  String get disputeRefundManual => '手動返金';

  @override
  String get disputeRefundAuto => '自動返金';

  @override
  String get disputeDismissed => '異議却下';

  @override
  String get disputeMediated => '調停により解決';

  @override
  String get ticketOpen => '未対応';

  @override
  String get ticketPending => 'サポートが返信済み';

  @override
  String get ticketResolved => '解決済み';

  @override
  String get ticketClosed => 'クローズ';

  @override
  String get ticketCatAccount => 'アカウントについて';

  @override
  String get ticketCatTrade => '取引について';

  @override
  String get ticketCatWallet => 'コインについて';

  @override
  String get ticketCatCabinet => 'ロッカーについて';

  @override
  String get ticketCatBug => '不具合';

  @override
  String get ticketCatOther => 'その他';

  @override
  String get faqCatGeneral => '一般';

  @override
  String get faqCatAccount => 'アカウント';

  @override
  String get faqCatTrade => '取引';

  @override
  String get faqCatWallet => 'コイン';

  @override
  String get faqCatCabinet => 'ロッカー';

  @override
  String get slotEmpty => '空き';

  @override
  String get slotOccupied => '使用中';

  @override
  String get slotReserved => '予約済み';

  @override
  String get slotMaintenance => 'メンテナンス中';

  @override
  String get txnDeposit => 'チャージ';

  @override
  String get txnWithdrawal => '出金';

  @override
  String get txnPurchase => '購入';

  @override
  String get txnSaleIncome => '売上';

  @override
  String get txnRefund => '返金';

  @override
  String get txnAdminAdjust => 'サポートによる調整';

  @override
  String get announceGeneral => 'お知らせ';

  @override
  String get announceMaintenance => 'メンテナンス';

  @override
  String get announcePromotion => 'キャンペーン';

  @override
  String get announcePolicy => 'ポリシー';

  @override
  String get loadFailed => '読み込みに失敗しました。しばらくしてからお試しください。';

  @override
  String get updateFailed => '更新に失敗しました。しばらくしてからお試しください。';

  @override
  String get saveFailed => '保存に失敗しました。しばらくしてからお試しください。';

  @override
  String get networkError => '接続できません。ネットワークをご確認ください。';

  @override
  String get unknownUser => '不明なユーザー';

  @override
  String get deletedUser => '削除されたユーザー';

  @override
  String get actionConfirm => 'OK';

  @override
  String get actionCancel => 'キャンセル';

  @override
  String get actionSave => '保存';

  @override
  String get actionDelete => '削除';

  @override
  String get actionEdit => '編集';

  @override
  String get actionSubmit => '送信';

  @override
  String get actionClose => '閉じる';

  @override
  String get actionBack => '戻る';

  @override
  String get actionRetry => '再試行';

  @override
  String get actionSelect => '選択してください';

  @override
  String get actionAll => 'すべて';

  @override
  String get actionSearch => '検索';

  @override
  String get appearance => '外観';

  @override
  String get appearanceLight => 'ライト';

  @override
  String get appearanceDark => 'ダーク';

  @override
  String get appearanceSystem => 'システムに合わせる';

  @override
  String get appearanceHint => '「システムに合わせる」を選ぶと、端末の設定に従って自動で切り替わります。';

  @override
  String get language => '言語';

  @override
  String get languageSystem => 'システムに合わせる';

  @override
  String get languageHint => '「システムに合わせる」を選ぶと、端末の言語設定に従って表示されます。';

}

class _LKo extends AppLocalizations {
  const _LKo();

  @override
  String get orderPendingPayment => '결제 대기';

  @override
  String get orderPendingDeposit => '보관 대기';

  @override
  String get orderDeposited => '보관 완료';

  @override
  String get orderPendingPickup => '수령 대기';

  @override
  String get orderCompleted => '완료';

  @override
  String get orderCancelled => '취소됨';

  @override
  String get orderRefunding => '환불 처리 중';

  @override
  String get orderRefunded => '환불 완료';

  @override
  String get orderBuyerPendingDeposit => '판매자 보관 대기';

  @override
  String get orderBuyerDeposited => '수령 대기';

  @override
  String get orderBuyerRefunding => '이의 제기 중';

  @override
  String get orderFlowDeposit => '판매자 보관';

  @override
  String get orderFlowDeposited => '보관함에 보관됨';

  @override
  String get orderFlowPickup => '구매자 수령';

  @override
  String get orderFlowCompleted => '거래 완료';

  @override
  String get bookOnSale => '판매 중';

  @override
  String get bookReserved => '예약됨';

  @override
  String get bookSold => '판매 완료';

  @override
  String get bookRemoved => '내림';

  @override
  String get conditionLikeNew => '새 상품';

  @override
  String get conditionGood => '거의 새것';

  @override
  String get conditionFair => '양호';

  @override
  String get conditionPoor => '보통';

  @override
  String get conditionUnknown => '상태 미상';

  @override
  String get photoCover => '표지';

  @override
  String get photoBack => '뒤표지';

  @override
  String get photoBarcode => '바코드';

  @override
  String get memberNormal => '정상';

  @override
  String get memberInactive => '이용 정지';

  @override
  String get memberBlacklisted => '블랙리스트';

  @override
  String get roleBuyerSeller => '일반 회원';

  @override
  String get roleAdmin => '관리자';

  @override
  String get noLevel => '등급 없음';

  @override
  String get reportPending => '대기 중';

  @override
  String get reportReviewing => '검토 중';

  @override
  String get reportResolved => '처리 완료';

  @override
  String get reportDismissed => '기각됨';

  @override
  String get disputePending => '접수 대기';

  @override
  String get disputeProcessing => '처리 중';

  @override
  String get disputeResolved => '판정 완료';

  @override
  String get disputeRefundManual => '수동 환불';

  @override
  String get disputeRefundAuto => '자동 환불';

  @override
  String get disputeDismissed => '이의 기각';

  @override
  String get disputeMediated => '중재로 종결';

  @override
  String get ticketOpen => '접수됨';

  @override
  String get ticketPending => '고객센터 답변 완료';

  @override
  String get ticketResolved => '해결됨';

  @override
  String get ticketClosed => '종료됨';

  @override
  String get ticketCatAccount => '계정 문의';

  @override
  String get ticketCatTrade => '거래 문의';

  @override
  String get ticketCatWallet => '코인 문의';

  @override
  String get ticketCatCabinet => '보관함 문의';

  @override
  String get ticketCatBug => '기능 오류';

  @override
  String get ticketCatOther => '기타';

  @override
  String get faqCatGeneral => '일반';

  @override
  String get faqCatAccount => '계정';

  @override
  String get faqCatTrade => '거래';

  @override
  String get faqCatWallet => '코인';

  @override
  String get faqCatCabinet => '보관함';

  @override
  String get slotEmpty => '비어 있음';

  @override
  String get slotOccupied => '사용 중';

  @override
  String get slotReserved => '예약됨';

  @override
  String get slotMaintenance => '점검 중';

  @override
  String get txnDeposit => '충전';

  @override
  String get txnWithdrawal => '출금';

  @override
  String get txnPurchase => '구매';

  @override
  String get txnSaleIncome => '판매 수익';

  @override
  String get txnRefund => '환불';

  @override
  String get txnAdminAdjust => '고객센터 조정';

  @override
  String get announceGeneral => '일반';

  @override
  String get announceMaintenance => '점검';

  @override
  String get announcePromotion => '이벤트';

  @override
  String get announcePolicy => '정책';

  @override
  String get loadFailed => '불러오지 못했습니다. 잠시 후 다시 시도해 주세요.';

  @override
  String get updateFailed => '업데이트하지 못했습니다. 잠시 후 다시 시도해 주세요.';

  @override
  String get saveFailed => '저장하지 못했습니다. 잠시 후 다시 시도해 주세요.';

  @override
  String get networkError => '연결할 수 없습니다. 네트워크를 확인해 주세요.';

  @override
  String get unknownUser => '알 수 없는 사용자';

  @override
  String get deletedUser => '삭제된 사용자';

  @override
  String get actionConfirm => '확인';

  @override
  String get actionCancel => '취소';

  @override
  String get actionSave => '저장';

  @override
  String get actionDelete => '삭제';

  @override
  String get actionEdit => '편집';

  @override
  String get actionSubmit => '제출';

  @override
  String get actionClose => '닫기';

  @override
  String get actionBack => '뒤로';

  @override
  String get actionRetry => '다시 시도';

  @override
  String get actionSelect => '선택해 주세요';

  @override
  String get actionAll => '전체';

  @override
  String get actionSearch => '검색';

  @override
  String get appearance => '화면 모드';

  @override
  String get appearanceLight => '라이트';

  @override
  String get appearanceDark => '다크';

  @override
  String get appearanceSystem => '시스템 설정 따르기';

  @override
  String get appearanceHint => '시스템 설정 따르기를 선택하면 기기 설정에 따라 자동으로 전환됩니다.';

  @override
  String get language => '언어';

  @override
  String get languageSystem => '시스템 설정 따르기';

  @override
  String get languageHint => '시스템 설정 따르기를 선택하면 기기 언어 설정에 따라 표시됩니다.';

}

class _LZh extends AppLocalizations {
  const _LZh();

  @override
  String get orderPendingPayment => '待付款';

  @override
  String get orderPendingDeposit => '待存書';

  @override
  String get orderDeposited => '已存書';

  @override
  String get orderPendingPickup => '待取書';

  @override
  String get orderCompleted => '已完成';

  @override
  String get orderCancelled => '已取消';

  @override
  String get orderRefunding => '退款中';

  @override
  String get orderRefunded => '已退款';

  @override
  String get orderBuyerPendingDeposit => '待賣家存書';

  @override
  String get orderBuyerDeposited => '待取書';

  @override
  String get orderBuyerRefunding => '申訴中';

  @override
  String get orderFlowDeposit => '待賣家存書';

  @override
  String get orderFlowDeposited => '已存入書櫃';

  @override
  String get orderFlowPickup => '待買家取書';

  @override
  String get orderFlowCompleted => '交易完成';

  @override
  String get bookOnSale => '販售中';

  @override
  String get bookReserved => '已預訂';

  @override
  String get bookSold => '已售出';

  @override
  String get bookRemoved => '已下架';

  @override
  String get conditionLikeNew => '全新';

  @override
  String get conditionGood => '近全新';

  @override
  String get conditionFair => '良好';

  @override
  String get conditionPoor => '尚可';

  @override
  String get conditionUnknown => '未知書況';

  @override
  String get photoCover => '封面';

  @override
  String get photoBack => '封底';

  @override
  String get photoBarcode => '條碼';

  @override
  String get memberNormal => '正常';

  @override
  String get memberInactive => '已停權';

  @override
  String get memberBlacklisted => '黑名單';

  @override
  String get roleBuyerSeller => '一般會員';

  @override
  String get roleAdmin => '管理員';

  @override
  String get noLevel => '尚未評級';

  @override
  String get reportPending => '待處理';

  @override
  String get reportReviewing => '審核中';

  @override
  String get reportResolved => '已處理';

  @override
  String get reportDismissed => '已駁回';

  @override
  String get disputePending => '待受理';

  @override
  String get disputeProcessing => '處理中';

  @override
  String get disputeResolved => '已裁決';

  @override
  String get disputeRefundManual => '人工退款';

  @override
  String get disputeRefundAuto => '自動退款';

  @override
  String get disputeDismissed => '駁回申訴';

  @override
  String get disputeMediated => '協調結案';

  @override
  String get ticketOpen => '待處理';

  @override
  String get ticketPending => '客服已回覆';

  @override
  String get ticketResolved => '已解決';

  @override
  String get ticketClosed => '已結案';

  @override
  String get ticketCatAccount => '帳號問題';

  @override
  String get ticketCatTrade => '交易問題';

  @override
  String get ticketCatWallet => '代幣問題';

  @override
  String get ticketCatCabinet => '書櫃問題';

  @override
  String get ticketCatBug => '功能異常';

  @override
  String get ticketCatOther => '其他';

  @override
  String get faqCatGeneral => '一般';

  @override
  String get faqCatAccount => '帳號';

  @override
  String get faqCatTrade => '交易';

  @override
  String get faqCatWallet => '代幣';

  @override
  String get faqCatCabinet => '書櫃';

  @override
  String get slotEmpty => '空置';

  @override
  String get slotOccupied => '使用中';

  @override
  String get slotReserved => '已預約';

  @override
  String get slotMaintenance => '維修中';

  @override
  String get txnDeposit => '儲值';

  @override
  String get txnWithdrawal => '提領';

  @override
  String get txnPurchase => '購書';

  @override
  String get txnSaleIncome => '售書收入';

  @override
  String get txnRefund => '退款';

  @override
  String get txnAdminAdjust => '客服調整';

  @override
  String get announceGeneral => '一般';

  @override
  String get announceMaintenance => '維護';

  @override
  String get announcePromotion => '活動';

  @override
  String get announcePolicy => '政策';

  @override
  String get loadFailed => '載入失敗，請稍後再試';

  @override
  String get updateFailed => '更新失敗，請稍後再試';

  @override
  String get saveFailed => '儲存失敗，請稍後再試';

  @override
  String get networkError => '無法連線，請檢查網路';

  @override
  String get unknownUser => '未知使用者';

  @override
  String get deletedUser => '已刪除的使用者';

  @override
  String get actionConfirm => '確定';

  @override
  String get actionCancel => '取消';

  @override
  String get actionSave => '儲存';

  @override
  String get actionDelete => '刪除';

  @override
  String get actionEdit => '編輯';

  @override
  String get actionSubmit => '送出';

  @override
  String get actionClose => '關閉';

  @override
  String get actionBack => '返回';

  @override
  String get actionRetry => '重試';

  @override
  String get actionSelect => '請選擇';

  @override
  String get actionAll => '全部';

  @override
  String get actionSearch => '搜尋';

  @override
  String get appearance => '外觀';

  @override
  String get appearanceLight => '淺色';

  @override
  String get appearanceDark => '深色';

  @override
  String get appearanceSystem => '跟隨系統';

  @override
  String get appearanceHint => '選擇「跟隨系統」時，會依裝置的深淺色設定自動切換';

  @override
  String get language => '語言';

  @override
  String get languageSystem => '跟隨系統';

  @override
  String get languageHint => '選擇「跟隨系統」時，會依裝置的語言設定顯示';

}

class _LZhHans extends AppLocalizations {
  const _LZhHans();

  @override
  String get orderPendingPayment => '待付款';

  @override
  String get orderPendingDeposit => '待存书';

  @override
  String get orderDeposited => '已存书';

  @override
  String get orderPendingPickup => '待取书';

  @override
  String get orderCompleted => '已完成';

  @override
  String get orderCancelled => '已取消';

  @override
  String get orderRefunding => '退款中';

  @override
  String get orderRefunded => '已退款';

  @override
  String get orderBuyerPendingDeposit => '待卖家存书';

  @override
  String get orderBuyerDeposited => '待取书';

  @override
  String get orderBuyerRefunding => '申诉中';

  @override
  String get orderFlowDeposit => '待卖家存书';

  @override
  String get orderFlowDeposited => '已存入书柜';

  @override
  String get orderFlowPickup => '待买家取书';

  @override
  String get orderFlowCompleted => '交易完成';

  @override
  String get bookOnSale => '销售中';

  @override
  String get bookReserved => '已预订';

  @override
  String get bookSold => '已售出';

  @override
  String get bookRemoved => '已下架';

  @override
  String get conditionLikeNew => '全新';

  @override
  String get conditionGood => '近全新';

  @override
  String get conditionFair => '良好';

  @override
  String get conditionPoor => '尚可';

  @override
  String get conditionUnknown => '未知书况';

  @override
  String get photoCover => '封面';

  @override
  String get photoBack => '封底';

  @override
  String get photoBarcode => '条码';

  @override
  String get memberNormal => '正常';

  @override
  String get memberInactive => '已停权';

  @override
  String get memberBlacklisted => '黑名单';

  @override
  String get roleBuyerSeller => '一般会员';

  @override
  String get roleAdmin => '管理员';

  @override
  String get noLevel => '尚未评级';

  @override
  String get reportPending => '待处理';

  @override
  String get reportReviewing => '审核中';

  @override
  String get reportResolved => '已处理';

  @override
  String get reportDismissed => '已驳回';

  @override
  String get disputePending => '待受理';

  @override
  String get disputeProcessing => '处理中';

  @override
  String get disputeResolved => '已裁决';

  @override
  String get disputeRefundManual => '人工退款';

  @override
  String get disputeRefundAuto => '自动退款';

  @override
  String get disputeDismissed => '驳回申诉';

  @override
  String get disputeMediated => '协调结案';

  @override
  String get ticketOpen => '待处理';

  @override
  String get ticketPending => '客服已回复';

  @override
  String get ticketResolved => '已解决';

  @override
  String get ticketClosed => '已结案';

  @override
  String get ticketCatAccount => '账号问题';

  @override
  String get ticketCatTrade => '交易问题';

  @override
  String get ticketCatWallet => '代币问题';

  @override
  String get ticketCatCabinet => '书柜问题';

  @override
  String get ticketCatBug => '功能异常';

  @override
  String get ticketCatOther => '其他';

  @override
  String get faqCatGeneral => '一般';

  @override
  String get faqCatAccount => '账号';

  @override
  String get faqCatTrade => '交易';

  @override
  String get faqCatWallet => '代币';

  @override
  String get faqCatCabinet => '书柜';

  @override
  String get slotEmpty => '空置';

  @override
  String get slotOccupied => '使用中';

  @override
  String get slotReserved => '已预约';

  @override
  String get slotMaintenance => '维修中';

  @override
  String get txnDeposit => '充值';

  @override
  String get txnWithdrawal => '提现';

  @override
  String get txnPurchase => '购书';

  @override
  String get txnSaleIncome => '售书收入';

  @override
  String get txnRefund => '退款';

  @override
  String get txnAdminAdjust => '客服调整';

  @override
  String get announceGeneral => '一般';

  @override
  String get announceMaintenance => '维护';

  @override
  String get announcePromotion => '活动';

  @override
  String get announcePolicy => '政策';

  @override
  String get loadFailed => '加载失败，请稍后再试';

  @override
  String get updateFailed => '更新失败，请稍后再试';

  @override
  String get saveFailed => '保存失败，请稍后再试';

  @override
  String get networkError => '无法连接，请检查网络';

  @override
  String get unknownUser => '未知用户';

  @override
  String get deletedUser => '已删除的用户';

  @override
  String get actionConfirm => '确定';

  @override
  String get actionCancel => '取消';

  @override
  String get actionSave => '保存';

  @override
  String get actionDelete => '删除';

  @override
  String get actionEdit => '编辑';

  @override
  String get actionSubmit => '提交';

  @override
  String get actionClose => '关闭';

  @override
  String get actionBack => '返回';

  @override
  String get actionRetry => '重试';

  @override
  String get actionSelect => '请选择';

  @override
  String get actionAll => '全部';

  @override
  String get actionSearch => '搜索';

  @override
  String get appearance => '外观';

  @override
  String get appearanceLight => '浅色';

  @override
  String get appearanceDark => '深色';

  @override
  String get appearanceSystem => '跟随系统';

  @override
  String get appearanceHint => '选择“跟随系统”时，会依设备的深浅色设置自动切换';

  @override
  String get language => '语言';

  @override
  String get languageSystem => '跟随系统';

  @override
  String get languageHint => '选择“跟随系统”时，会依设备的语言设置显示';

}

class _LZhHant extends AppLocalizations {
  const _LZhHant();

  @override
  String get orderPendingPayment => '待付款';

  @override
  String get orderPendingDeposit => '待存書';

  @override
  String get orderDeposited => '已存書';

  @override
  String get orderPendingPickup => '待取書';

  @override
  String get orderCompleted => '已完成';

  @override
  String get orderCancelled => '已取消';

  @override
  String get orderRefunding => '退款中';

  @override
  String get orderRefunded => '已退款';

  @override
  String get orderBuyerPendingDeposit => '待賣家存書';

  @override
  String get orderBuyerDeposited => '待取書';

  @override
  String get orderBuyerRefunding => '申訴中';

  @override
  String get orderFlowDeposit => '待賣家存書';

  @override
  String get orderFlowDeposited => '已存入書櫃';

  @override
  String get orderFlowPickup => '待買家取書';

  @override
  String get orderFlowCompleted => '交易完成';

  @override
  String get bookOnSale => '販售中';

  @override
  String get bookReserved => '已預訂';

  @override
  String get bookSold => '已售出';

  @override
  String get bookRemoved => '已下架';

  @override
  String get conditionLikeNew => '全新';

  @override
  String get conditionGood => '近全新';

  @override
  String get conditionFair => '良好';

  @override
  String get conditionPoor => '尚可';

  @override
  String get conditionUnknown => '未知書況';

  @override
  String get photoCover => '封面';

  @override
  String get photoBack => '封底';

  @override
  String get photoBarcode => '條碼';

  @override
  String get memberNormal => '正常';

  @override
  String get memberInactive => '已停權';

  @override
  String get memberBlacklisted => '黑名單';

  @override
  String get roleBuyerSeller => '一般會員';

  @override
  String get roleAdmin => '管理員';

  @override
  String get noLevel => '尚未評級';

  @override
  String get reportPending => '待處理';

  @override
  String get reportReviewing => '審核中';

  @override
  String get reportResolved => '已處理';

  @override
  String get reportDismissed => '已駁回';

  @override
  String get disputePending => '待受理';

  @override
  String get disputeProcessing => '處理中';

  @override
  String get disputeResolved => '已裁決';

  @override
  String get disputeRefundManual => '人工退款';

  @override
  String get disputeRefundAuto => '自動退款';

  @override
  String get disputeDismissed => '駁回申訴';

  @override
  String get disputeMediated => '協調結案';

  @override
  String get ticketOpen => '待處理';

  @override
  String get ticketPending => '客服已回覆';

  @override
  String get ticketResolved => '已解決';

  @override
  String get ticketClosed => '已結案';

  @override
  String get ticketCatAccount => '帳號問題';

  @override
  String get ticketCatTrade => '交易問題';

  @override
  String get ticketCatWallet => '代幣問題';

  @override
  String get ticketCatCabinet => '書櫃問題';

  @override
  String get ticketCatBug => '功能異常';

  @override
  String get ticketCatOther => '其他';

  @override
  String get faqCatGeneral => '一般';

  @override
  String get faqCatAccount => '帳號';

  @override
  String get faqCatTrade => '交易';

  @override
  String get faqCatWallet => '代幣';

  @override
  String get faqCatCabinet => '書櫃';

  @override
  String get slotEmpty => '空置';

  @override
  String get slotOccupied => '使用中';

  @override
  String get slotReserved => '已預約';

  @override
  String get slotMaintenance => '維修中';

  @override
  String get txnDeposit => '儲值';

  @override
  String get txnWithdrawal => '提領';

  @override
  String get txnPurchase => '購書';

  @override
  String get txnSaleIncome => '售書收入';

  @override
  String get txnRefund => '退款';

  @override
  String get txnAdminAdjust => '客服調整';

  @override
  String get announceGeneral => '一般';

  @override
  String get announceMaintenance => '維護';

  @override
  String get announcePromotion => '活動';

  @override
  String get announcePolicy => '政策';

  @override
  String get loadFailed => '載入失敗，請稍後再試';

  @override
  String get updateFailed => '更新失敗，請稍後再試';

  @override
  String get saveFailed => '儲存失敗，請稍後再試';

  @override
  String get networkError => '無法連線，請檢查網路';

  @override
  String get unknownUser => '未知使用者';

  @override
  String get deletedUser => '已刪除的使用者';

  @override
  String get actionConfirm => '確定';

  @override
  String get actionCancel => '取消';

  @override
  String get actionSave => '儲存';

  @override
  String get actionDelete => '刪除';

  @override
  String get actionEdit => '編輯';

  @override
  String get actionSubmit => '送出';

  @override
  String get actionClose => '關閉';

  @override
  String get actionBack => '返回';

  @override
  String get actionRetry => '重試';

  @override
  String get actionSelect => '請選擇';

  @override
  String get actionAll => '全部';

  @override
  String get actionSearch => '搜尋';

  @override
  String get appearance => '外觀';

  @override
  String get appearanceLight => '淺色';

  @override
  String get appearanceDark => '深色';

  @override
  String get appearanceSystem => '跟隨系統';

  @override
  String get appearanceHint => '選擇「跟隨系統」時，會依裝置的深淺色設定自動切換';

  @override
  String get language => '語言';

  @override
  String get languageSystem => '跟隨系統';

  @override
  String get languageHint => '選擇「跟隨系統」時，會依裝置的語言設定顯示';

}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales.any(
        (l) => l.languageCode == locale.languageCode,
      );

  @override
  Future<AppLocalizations> load(Locale locale) async {
    switch (_tagOf(locale)) {
      case 'en':
        return const _LEn();
      case 'ja':
        return const _LJa();
      case 'ko':
        return const _LKo();
      case 'zh_Hans':
        return const _LZhHans();
      case 'zh_Hant':
        return const _LZhHant();
      default:
        return const _LZh();
    }
  }

  /// 帶書寫系統時優先比對完整標籤；沒有對應的變體才退回語言本身。
  static String _tagOf(Locale locale) {
    final script = locale.scriptCode;
    if (script != null) {
      final full = '${locale.languageCode}_$script';
      if (AppLocalizations.supportedLocales.any(
          (l) => l.scriptCode == script && l.languageCode == locale.languageCode)) {
        return full;
      }
    }
    return locale.languageCode;
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
