import '../i18n/strings.dart';

class AppLabels {
  const AppLabels._();

  static Map<String, String> get orderStatus => {
        'pending_payment': S.orderPendingPayment,
        'pending_deposit': S.orderPendingDeposit,
        'deposited': S.orderDeposited,
        'pending_pickup': S.orderPendingPickup,
        'completed': S.orderCompleted,
        'cancelled': S.orderCancelled,
        'refunding': S.orderRefunding,
        'refunded': S.orderRefunded,
      };

  static Map<String, String> get _buyerOrderStatus => {
        'pending_deposit': S.orderBuyerPendingDeposit,
        'deposited': S.orderBuyerDeposited,
        'refunding': S.orderBuyerRefunding,
      };

  static String order(String code, {bool asBuyer = false}) {
    if (asBuyer) {
      final override = _buyerOrderStatus[code];
      if (override != null) return override;
    }
    return orderStatus[code] ?? code;
  }

  static List<({String status, String label})> get orderFlow => [
        (status: 'pending_deposit', label: S.orderFlowDeposit),
        (status: 'deposited', label: S.orderFlowDeposited),
        (status: 'pending_pickup', label: S.orderFlowPickup),
        (status: 'completed', label: S.orderFlowCompleted),
      ];

  static Map<String, String> get bookStatus => {
        'on_sale': S.bookOnSale,
        'reserved': S.bookReserved,
        'sold': S.bookSold,
        'removed': S.bookRemoved,
      };

  static String book(String code) => bookStatus[code] ?? code;

  static Map<String, String> get condition => {
        'like_new': S.conditionLikeNew,
        'good': S.conditionGood,
        'fair': S.conditionFair,
        'poor': S.conditionPoor,
      };

  static String conditionOf(String code) => condition[code] ?? S.conditionUnknown;

  static List<({String value, String label})> get conditionOptions => [
        (value: 'like_new', label: S.conditionLikeNew),
        (value: 'good', label: S.conditionGood),
        (value: 'fair', label: S.conditionFair),
        (value: 'poor', label: S.conditionPoor),
      ];

  static List<String> get photoSlots => [S.photoCover, S.photoBack, S.photoBarcode];

  static String member({required bool isActive, required bool isBlacklisted}) {
    if (isBlacklisted) return S.memberBlacklisted;
    if (!isActive) return S.memberInactive;
    return S.memberNormal;
  }

  static Map<String, String> get role => {
        'buyer_seller': S.roleBuyerSeller,
        'admin': S.roleAdmin,
      };

  static Map<String, String> get reportStatus => {
        'pending': S.reportPending,
        'reviewing': S.reportReviewing,
        'resolved': S.reportResolved,
        'dismissed': S.reportDismissed,
      };

  static String report(String code) => reportStatus[code] ?? code;

  static Map<String, String> get disputeStatus => {
        'pending': S.disputePending,
        'processing': S.disputeProcessing,
        'resolved': S.disputeResolved,
      };

  static String dispute(String code) => disputeStatus[code] ?? code;

  static Map<String, String> get disputeResult => {
        'refund_manual': S.disputeRefundManual,
        'refund_auto': S.disputeRefundAuto,
        'dismissed': S.disputeDismissed,
        'mediated': S.disputeMediated,
      };

  static Map<String, String> get ticketStatus => {
        'open': S.ticketOpen,
        'pending': S.ticketPending,
        'resolved': S.ticketResolved,
        'closed': S.ticketClosed,
      };

  static String ticket(String code) => ticketStatus[code] ?? code;

  static Map<String, String> get ticketCategory => {
        'account': S.ticketCatAccount,
        'trade': S.ticketCatTrade,
        'wallet': S.ticketCatWallet,
        'cabinet': S.ticketCatCabinet,
        'bug': S.ticketCatBug,
        'other': S.ticketCatOther,
      };

  static Map<String, String> get faqCategory => {
        'general': S.faqCatGeneral,
        'account': S.faqCatAccount,
        'trade': S.faqCatTrade,
        'wallet': S.faqCatWallet,
        'cabinet': S.faqCatCabinet,
      };

  static Map<String, String> get slotStatus => {
        'empty': S.slotEmpty,
        'occupied': S.slotOccupied,
        'reserved': S.slotReserved,
        'maintenance': S.slotMaintenance,
      };

  static String slot(String code) => slotStatus[code] ?? code;

  static Map<String, String> get walletTxnType => {
        'deposit': S.txnDeposit,
        'withdrawal': S.txnWithdrawal,
        'purchase': S.txnPurchase,
        'sale_income': S.txnSaleIncome,
        'refund': S.txnRefund,
        'admin_adjust': S.txnAdminAdjust,
      };

  static Map<String, String> get refundStatus => {
        'pending': S.awaitingRefund,
        'approved': S.approved,
        'rejected': S.declined,
        'completed': S.orderRefunded,
      };

  static Map<String, String> get announcementType => {
        'general': S.announceGeneral,
        'maintenance': S.announceMaintenance,
        'promotion': S.announcePromotion,
        'policy': S.announcePolicy,
      };

  static Map<String, (String, String)> get permission => {
    'can_manage_members': (S.memberControls, S.suspensionBlocklistRoles),
    'can_manage_levels': (S.membershipTier, S.tierThresholdsManualAdjustments),
    'can_manage_content': (S.listings, S.booksCategories),
    'can_manage_reports': (S.reportReview, S.handleListingReports2),
    'can_manage_orders': (S.orders, S.lookUpChangeOrderStatus),
    'can_manage_transactions': (S.disputeResolution, S.decideDisputeCases),
    'can_manage_wallets': (S.wallets, S.checkAdjustCoinBalances),
    'can_manage_cabinets': (S.hardware, S.lockersSlots),
    'can_manage_announcements': (S.announcementsDocuments, S.announcementsFaqLegalDocuments),
    'can_manage_support': (S.supportEnquiries, S.replyUserQuestions),
    'can_view_stats': (S.reports, S.ordersRevenueMemberGrowth),
    'can_manage_system': (S.systemOperations, S.databaseBackupDownloadOffByDefault),
  };

  static String get loadFailed => S.loadFailed;
  static String get updateFailed => S.updateFailed;
  static String get saveFailed => S.saveFailed;
  static String get networkError => S.networkError;
  static String get noLevel => S.noLevel;
  static String get unknownUser => S.unknownUser;
  static String get deletedUser => S.deletedUser;
}
