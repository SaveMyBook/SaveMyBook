/// 後端代碼與畫面文字的唯一對照來源。
///
/// 同一個代碼在每個頁面必須顯示同一段文字，所以畫面裡不要自己寫 switch。
/// 之前訂單的 `deposited` 在買家端是「待取書」、後台是「已存書」、
/// 詳情頁又是「已存入書櫃」，就是各自為政造成的。
class AppLabels {
  const AppLabels._();

  // ---------- 訂單 ----------

  /// 中立說法，後台與賣家端使用。
  static const orderStatus = <String, String>{
    'pending_payment': '待付款',
    'pending_deposit': '待存書',
    'deposited': '已存書',
    'pending_pickup': '待取書',
    'completed': '已完成',
    'cancelled': '已取消',
    'refunding': '退款中',
    'refunded': '已退款',
  };

  /// 買家視角的例外。買家看到的是「對方要做什麼」與「我可以做什麼」，
  /// 其餘代碼沿用 [orderStatus]。
  static const _buyerOrderStatus = <String, String>{
    'pending_deposit': '待賣家存書',
    'deposited': '待取書',
    'refunding': '申訴中',
  };

  static String order(String code, {bool asBuyer = false}) {
    if (asBuyer) {
      final override = _buyerOrderStatus[code];
      if (override != null) return override;
    }
    return orderStatus[code] ?? code;
  }

  /// 訂單在進度條上會依序經過的節點。
  static const orderFlow = <({String status, String label})>[
    (status: 'pending_deposit', label: '待賣家存書'),
    (status: 'deposited', label: '已存入書櫃'),
    (status: 'pending_pickup', label: '待買家取書'),
    (status: 'completed', label: '交易完成'),
  ];

  // ---------- 書籍 ----------

  static const bookStatus = <String, String>{
    'on_sale': '販售中',
    'reserved': '已預訂',
    'sold': '已售出',
    'removed': '已下架',
  };

  static String book(String code) => bookStatus[code] ?? code;

  static const condition = <String, String>{
    'like_new': '全新',
    'good': '近全新',
    'fair': '良好',
    'poor': '尚可',
  };

  static String conditionOf(String code) => condition[code] ?? '未知書況';

  /// 上架與編輯共用的書況選項，順序即下拉選單的顯示順序。
  static const conditionOptions = <({String value, String label})>[
    (value: 'like_new', label: '全新'),
    (value: 'good', label: '近全新'),
    (value: 'fair', label: '良好'),
    (value: 'poor', label: '尚可'),
  ];

  /// 上架時三張固定照片的欄位名稱。
  static const photoSlots = <String>['封面', '背面', '條碼'];

  // ---------- 會員 ----------

  static const memberNormal = '正常';
  static const memberInactive = '已停權';
  static const memberBlacklisted = '黑名單';

  static String member({required bool isActive, required bool isBlacklisted}) {
    if (isBlacklisted) return memberBlacklisted;
    if (!isActive) return memberInactive;
    return memberNormal;
  }

  static const role = <String, String>{
    'buyer_seller': '一般會員',
    'admin': '管理員',
  };

  // ---------- 檢舉與爭議 ----------

  static const reportStatus = <String, String>{
    'pending': '待處理',
    'reviewing': '審核中',
    'resolved': '已處理',
    'dismissed': '已駁回',
  };

  static String report(String code) => reportStatus[code] ?? code;

  static const disputeStatus = <String, String>{
    'pending': '待受理',
    'processing': '處理中',
    'resolved': '已裁決',
  };

  static String dispute(String code) => disputeStatus[code] ?? code;

  static const disputeResult = <String, String>{
    'refund_manual': '人工退款',
    'refund_auto': '自動退款',
    'dismissed': '駁回',
    'mediated': '協調結案',
  };

  // ---------- 客服 ----------

  static const ticketStatus = <String, String>{
    'open': '待處理',
    'pending': '客服已回覆',
    'resolved': '已解決',
    'closed': '已結案',
  };

  static String ticket(String code) => ticketStatus[code] ?? code;

  static const ticketCategory = <String, String>{
    'account': '帳號問題',
    'trade': '交易問題',
    'wallet': '代幣問題',
    'cabinet': '書櫃問題',
    'bug': '功能異常',
    'other': '其他',
  };

  /// 常見問題的分類，用字比工單分類短，因為它只是區塊標題。
  static const faqCategory = <String, String>{
    'general': '一般',
    'account': '帳號',
    'trade': '交易',
    'wallet': '代幣',
    'cabinet': '書櫃',
  };

  // ---------- 書櫃 ----------

  static const slotStatus = <String, String>{
    'empty': '空置',
    'occupied': '使用中',
    'reserved': '已預約',
    'maintenance': '維修中',
  };

  static String slot(String code) => slotStatus[code] ?? code;

  // ---------- 錢包 ----------

  static const walletTxnType = <String, String>{
    'deposit': '儲值',
    'withdrawal': '提領',
    'purchase': '購書',
    'sale_income': '售書收入',
    'refund': '退款',
    'admin_adjust': '客服調整',
  };

  // ---------- 公告 ----------

  static const announcementType = <String, String>{
    'general': '一般',
    'maintenance': '維護',
    'promotion': '活動',
    'policy': '政策',
  };

  /// 管理員細部權限的名稱與說明，順序即設定頁的顯示順序。
  static const permission = <String, (String, String)>{
    'can_manage_members': ('會員管控', '停權、黑名單、身分'),
    'can_manage_levels': ('會員等級', '等級門檻與人工調整'),
    'can_manage_content': ('商品管理', '書籍與分類'),
    'can_manage_reports': ('檢舉審核', '處理商品檢舉'),
    'can_manage_orders': ('訂單管理', '查詢與調整訂單狀態'),
    'can_manage_transactions': ('交易仲裁', '申訴案件裁決'),
    'can_manage_wallets': ('錢包管理', '查詢與增減代幣'),
    'can_manage_cabinets': ('硬體維護', '書櫃與櫃位'),
    'can_manage_announcements': ('公告與文件', '公告、常見問題、法律文件'),
    'can_manage_support': ('客服工單', '回覆使用者問題'),
    'can_view_stats': ('營運報表', '檢視營收與成長數據'),
  };

  // ---------- 反覆出現的提示 ----------

  static const loadFailed = '載入失敗，請稍後再試';
  static const updateFailed = '更新失敗，請稍後再試';
  static const saveFailed = '儲存失敗，請稍後再試';
  static const networkError = '無法連線，請檢查網路';
  static const noLevel = '尚未評級';
}
