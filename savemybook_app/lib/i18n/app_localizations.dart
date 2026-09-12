// 由 tool/gen_l10n.py 從 lib/i18n/*.arb 產生，請不要手動編輯。

import 'package:flutter/widgets.dart';

abstract class AppLocalizations {
  const AppLocalizations();

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  /// 還沒有 Localizations 可用時的預設值，讓 S 永遠有值。
  static const AppLocalizations fallback = _LZh();

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
  String get verifySignSavemybook;
  String get maintenance;
  String get promotions;
  String get policyUpdate;
  String get announcement;
  String get item;
  String get member;
  String get message;
  String get noLongerExists;
  String get uncategorised;
  String get general;
  String get untitled;
  String get noDescriptionYet;
  String get locationNotProvided;
  String seller3(Object p0);
  String get unknownAuthor;
  String get unknownPublisher;
  String get noIsbn;
  String get user;
  String get noMessagesYet;
  String get photo;
  String item2(Object p0);
  String get purchase;
  String get sale;
  String get systemAdjustment;
  String get preparingData;
  String get mySavemybookData;
  String get exportedChooseWhereSave;
  String get exportedButSharingCouldNotOpen;
  String get regenerateShareLink;
  String get oldLinkQrCodeStopWorking;
  String get regenerate;
  String get newLinkCreatedOldOneNo;
  String get deleteAccount;
  String get accountPermanentlyDisabled30DaysSign;
  String get personalDataErasedButCompletedOrders;
  String get peopleTradedWithDoNotLose;
  String get actionContinue;
  String get verify;
  String get enterPasswordConfirm;
  String get password;
  String get requestDeletion;
  String get receivedSignAgainWithin30Days;
  String get deletionCancelledAccountActiveAgain;
  String get account;
  String get data;
  String get exportMyData;
  String get profileBooksOrdersTransactionsJson;
  String get oldLinkQrCodeStopWorking2;
  String get cancelAccountDeletion;
  String get restoreAccountStopCountdown;
  String get canChangeMindWithin30Days;
  String get deletionPending;
  String daysLeftCanCancelAnyTime(Object p0);
  String get signOut;
  String get type;
  String get content;
  String get backupFailed;
  String get myBooks;
  String get notProvided;
  String get openingHours;
  String get address;
  String get saveChanges;
  String get enable;
  String get termsService;
  String get privacyPolicy;
  String get aboutUs;
  String get admin;
  String get confirm;
  String get membershipTier;
  String get phone;
  String get violationConfirmed;
  String get scanBarcode;
  String get lineUpBarcodeSpineWithFrame;
  String get signAddItemsCart;
  String bookCannotPurchased(Object p0);
  String get addedCart;
  String get sellerInformationNotFound;
  String get signContactSeller;
  String get signStartChat;
  String get signReport;
  String get cannotReportOwnListing;
  String get reportListing;
  String get describeProblemLeast5Characters;
  String get reasonNeedsLeast5Characters;
  String get reportSubmittedWeLookInto;
  String get publisher;
  String get author;
  String get listed;
  String get searchTitleAuthorPublisher;
  String get share;
  String get report;
  String get about;
  String pickup(Object p0);
  String get messageSeller;
  String get listing;
  String get addCart;
  String get bookBeenReportedUnderReviewStays;
  String get violationWasConfirmedBookPleaseCheck;
  String get reportDismissed2;
  String get bookWasReportedButNoViolation;
  String get delist;
  String removedFromShopBuyersNoLonger(Object p0);
  String get delist2;
  String get delistedRelistFromDelistedTab;
  String get couldNotDelistPleaseTryAgain;
  String listedAgain(Object p0);
  String get notListedAnyBooksYet;
  String get noBooksCategory;
  String get listFirstBook;
  String get relist;
  String get removeFromCart;
  String removeFromCart2(Object p0);
  String get remove;
  String get couldNotRemoveRestored;
  String get couldNotRemovePleaseTryAgain;
  String get selectBooksWantCheckOut;
  String notEnoughCoinsOrderNeedsBut(Object p0, Object p1);
  String get confirmCheckout;
  String booksTotal(Object p0, Object p1);
  String balanceAfterPaymentCoins(Object p0);
  String get orderPlacedSellerDropBookOff;
  String get cart;
  String get cartEmpty;
  String get selectAll;
  String items(Object p0);
  String get deselect;
  String get select;
  String coinsShort(Object p0);
  String get total;
  String selected(Object p0);
  String balance2(Object p0);
  String get selectBookFirst;
  String get checkOut;
  String get notEnoughCoins;
  String get weak;
  String get fair;
  String get strong;
  String get enterCurrentPassword;
  String get enterNewPassword;
  String get newPasswordMustDifferent;
  String get enterNewPasswordAgain;
  String get passwordsDoNotMatch;
  String get passwordUpdated;
  String get changePassword;
  String get useLeast8CharactersWithBoth;
  String get currentPassword;
  String get newPassword;
  String get confirmNewPassword;
  String get updatePassword;
  String get deleteChat;
  String allMessagesWithDeletedBothCannot(Object p0);
  String get chatDeleted;
  String get couldNotDeleteRestored;
  String get chatMuted;
  String get chatUnmuted;
  String get noUnreadMessages;
  String get markAllAsRead;
  String markAllUnreadMessagesAsRead(Object p0);
  String get markAllRead;
  String get allMarkedAsRead;
  String get somethingWentWrongPleaseTryAgain;
  String get chats;
  String get noConversationsYet;
  String get unmute;
  String get mute;
  String get messagesLimited500Characters;
  String get messageCouldNotSent;
  String get chat;
  String get sendFirstMessage;
  String get messageCopied;
  String get iQuestionAboutBook;
  String get bookNoLongerListed;
  String get writeMessage;
  String get enterOrderNumberDisputing;
  String get describeDispute;
  String get useLeast10CharactersSoSupport;
  String get submitDispute;
  String get orderEntersDisputeProcessPaymentSeller;
  String paymentHoldRequested(Object p0);
  String get disputeSubmittedSupportContact;
  String get dispute;
  String get requestPaymentHold;
  String get paymentSellerHeldUntilSupportDecides;
  String get submitDispute2;
  String get orderNumber;
  String get eGSmb20260910123456789;
  String get whatHappened;
  String get describeProblemEGConditionDoes;
  String get submit;
  String get uploadPhotos;
  String get canAttachUp6Photos;
  String get up5;
  String get couldNotReplacePhotoPleaseTry;
  String get keepLeastOnePhoto;
  String get photoDeleted;
  String get couldNotDeletePhotoPleaseTry;
  String get canUp10Photos;
  String get deletePhoto;
  String get cannotUndoneContinue;
  String get photoMissingDataRefreshTryAgain;
  String get enterPrice;
  String get priceMustGreaterThan0;
  String get priceCannotExceed999999;
  String get chooseLockerLocation;
  String missingTheseThreeRequired(Object p0);
  String get bookUpdated;
  String get editBook;
  String get condition;
  String get customPrice;
  String get enterPrice2;
  String get lockerLocation;
  String get chooseLocker;
  String get bookPhotos;
  String get morePhotos;
  String get add;
  String get enterTitle;
  String get titleLimited255Characters;
  String get isbn1013Digits;
  String get chooseCategory;
  String get k1013Digits;
  String get title;
  String get actionRequired;
  String get author2;
  String get optional;
  String get publisher2;
  String get publicationDate;
  String get tapPickPublicationDate;
  String get pickPublicationDate;
  String get pickCategory;
  String get next;
  String get uploading;
  String get profilePhotoUpdated;
  String get couldNotUploadPhoto;
  String get changeDisplayName;
  String get enterDisplayName;
  String get displayNameCannotBlank;
  String get displayNames250Characters;
  String get invalidPhoneNumberEG0912345678;
  String get profileUpdated;
  String get editProfile;
  String get bio;
  String get tellPeopleAboutYourself;
  String get email;
  String get emailCannotChanged;
  String get dateBirth;
  String get tapPickDateBirth;
  String get pickDateBirth;
  String get savedBooks;
  String get notSavedAnyBooksYet;
  String get helpCentre;
  String get searchQuestions;
  String get noQuestionsYet;
  String get noMatchingQuestions;
  String get newest;
  String get popular;
  String get priceLowHigh;
  String get priceHighLow;
  String get reachedEnd;
  String get guest;
  String hi(Object p0);
  String get noBooksMatchFilters;
  String get couldNotReadPhoto;
  String get croppingFailedPleaseTryAgain;
  String get adjustPhoto;
  String get reset;
  String get usePhoto;
  String get documentNotBeenCreatedYet;
  String lastUpdated(Object p0);
  String get biometrics;
  String get sessionExpiredPleaseEnterPasswordAgain;
  String turnSign(Object p0);
  String nextTimeOpenAppCanUnlock(Object p0);
  String get notNow;
  String get enterEmail;
  String get emailAddressNotValid;
  String get enterPassword;
  String get noAccountWithEmail;
  String noAccountCreateOneNow(Object p0);
  String get signUp;
  String get tryAgain;
  String get sign;
  String signWith(Object p0);
  String get noAccountYetSignUp;
  String get membershipTiersNotSetUpYet;
  String get currentTier;
  String get unlocked;
  String get locked;
  String get aboveTier;
  String get reachedTopTier;
  String unlocked2(Object p0);
  String morePointsUnlock(Object p0, Object p1);
  String benefits(Object p0);
  String get noBenefitsBeenDescribedTierYet;
  String pointsFromCompletedOrders(Object p0, Object p1);
  String get noNotificationsClear;
  String get clearAllNotifications;
  String notificationsDeletedCannotUndone(Object p0);
  String get clearAll;
  String get allNotificationsCleared;
  String get couldNotClearPleaseTryAgain;
  String get noUnreadNotifications;
  String markAllUnreadNotificationsAsRead(Object p0);
  String get openChat;
  String get viewOrder;
  String get openMyBooks;
  String get notifications;
  String get noNotifications;
  String copied(Object p0);
  String get orderDetails;
  String order(Object p0);
  String get orderProgress;
  String items2(Object p0);
  String get orderNoItemDetails;
  String msg4(Object p0, Object p1);
  String get orderTotal;
  String get pickupDetails;
  String get notAssigned;
  String get slot;
  String get notAssignedYet;
  String get pickupCode;
  String get transaction;
  String get buyer;
  String get seller;
  String get placed;
  String get dispute2;
  String get orderOpenDispute;
  String get cancelOrder;
  String get pendingPayoutDisappearsBuyerNotified;
  String get cancelledBySeller;
  String get orderCancelled2;
  String get pendingPayouts;
  String get noPendingPayouts;
  String get pendingAmount;
  String get coinsArriveOnceBuyerCollectsBook;
  String get scanned;
  String get scanAgain;
  String get collectBook;
  String get pointPickupQrCode;
  String get holdSteady;
  String get bookCollected;
  String get thanksUsingSavemybookHappyReading;
  String collected(Object p0);
  String order2(Object p0);
  String get signingOut;
  String get myAccount;
  String get personNotWrittenBioYet;
  String get topTierReached;
  String morePointsReach(Object p0, Object p1);
  String get myCoins;
  String get shareProfile;
  String get purchases;
  String get sales;
  String get settings;
  String get signOut2;
  String get needSignAgainKeepUsingApp;
  String cancelOrderBookReturnsShop(Object p0);
  String get pickupCode2;
  String get notGeneratedYet;
  String get enterCodeLockerCollect;
  String enterCodeCollect(Object p0);
  String get iCollected;
  String get noOrdersTab;
  String get openDispute;
  String get displayNameNeedsLeast2Characters;
  String get displayNameLimited50Characters;
  String get enterPasswordAgain;
  String get passwordsDoNotMatch2;
  String get pleaseReadAcceptTermsServicePrivacy;
  String get accountCreatedSignWith;
  String get iReadAccept;
  String get and;
  String get createAccount;
  String get joinSavemybook;
  String get signUpBuySellUseSmart;
  String get displayName;
  String get nameOthersSee;
  String get emailSignWith;
  String get least8CharactersWithLettersNumbers;
  String get confirmPassword;
  String get enterPasswordAgain2;
  String get alreadyAccountGoBackSign;
  String get markAsDroppedOff;
  String get droppedOff;
  String get markedAsDroppedOff;
  String get buyerNotifiedBookReturnsShop;
  String get dropOffPickupCode;
  String get enterCodeLocker;
  String get noRecentSearches;
  String get recentSearches;
  String get clearAll2;
  String get searchTitleAuthorIsbn;
  String get photoLimitReached;
  String get canUploadUp10Photos;
  String get photosMissing;
  String missingTheseThreeRequired2(Object p0);
  String get missingInformation;
  String get enterOwnPrice;
  String get invalidPrice;
  String get priceMustGreaterThan02;
  String get priceCannotExceed99999;
  String get chooseLockerLocation2;
  String get listed2;
  String get unknownError;
  String get couldNotListBook;
  String serverError(Object p0);
  String get connectionProblem;
  String get couldNotReachServerUploadTimed;
  String get listBook;
  String get detailsPhotos;
  String get loading;
  String get unknownLocker;
  String get enterTitle2;
  String get chooseCategory2;
  String get bookDetailsFilledAutomatically;
  String get bookDetailsFilledFromBackupSource;
  String get noSourceIsbnPleaseEnterDetails;
  String get day;
  String get tapIconRightScan;
  String get description;
  String get sellBook;
  String get myShop;
  String get sellerNoBooksSale;
  String get loading2;
  String sale2(Object p0);
  String get verifyEnableQuickSign;
  String sign2(Object p0);
  String get quickSignTurnedOff;
  String get appearance2;
  String get signMethod;
  String get helpSupport;
  String get contactUs;
  String get aboutSavemybook;
  String get settingsPrivacy;
  String sign3(Object p0);
  String unlockWithWhenOpenApp(Object p0);
  String get scanProfileQrCode;
  String get lineUpTheirQrCodeWith;
  String get notSavemybookProfileQrCode;
  String get ownQrCode;
  String get couldNotStartChatPleaseTry;
  String get linkCopied;
  String addMeSavemybook(Object p0);
  String addMeSavemybook2(Object p0, Object p1);
  String get sharingCouldNotOpenSoLink;
  String get savedPhotos;
  String get couldNotSaveCheckPhotoLibrary;
  String get scanTheirQrCode;
  String get copyLink;
  String get askQuestion;
  String get noEnquiriesYet;
  String get enterSubject;
  String get addMoreDetailSoSupportCan;
  String get sentSupportReplySoon;
  String get subject;
  String get sumUpOneLine;
  String get whatHappenedIncludeOrderNumberIf;
  String get close;
  String get notAbleReplyAfterClosing;
  String get enquiryClosed;
  String get changeStatus;
  String get statusUpdated;
  String get enquiry;
  String get enquiryNotFound;
  String get support;
  String get writeReply;
  String get coins;
  String get transactions;
  String get noTransactionsYet;
  String get balance;
  String hold(Object p0);
  String requestFailed2(Object p0);
  String get couldNotReachServer;
  String get couldNotReachServerCheckConnection;
  String get signFailed;
  String get signFailedPleaseTryAgain;
  String get signUpFailed;
  String get pleaseSignFirst;
  String get couldNotRelist;
  String get couldNotRemoveFromSaved;
  String get couldNotSave;
  String get couldNotAddCart;
  String get checkoutFailed;
  String get couldNotCancelOrder;
  String get couldNotUpdateOrder;
  String get couldNotSubmitDispute;
  String get couldNotSubmitReport;
  String get updateFailed2;
  String get couldNotChangePassword;
  String get requestFailed;
  String get couldNotCancel;
  String get couldNotDelete;
  String get couldNotComplete;
  String get couldNotSaveAnnouncement;
  String get couldNotSend;
  String get actionFailed;
  String get couldNotSave2;
  String get documentUpdated;
  String get couldNotAdjust;
  String get couldNotProcessReport;
  String get couldNotRecordDecision;
  String get couldNotReorder;
  String get couldNotSaveLocker;
  String get fingerprint;
  String get iris;
  String get verifyIdentityContinue;
  String get couldNotOpenPhotosCheckPermission;
  String get choosePhotoSource;
  String get takePhoto;
  String get chooseFromPhotos;
  String get couldNotOpenCameraCheckPermission;
  String get justNow;
  String minAgo(Object p0);
  String hAgo(Object p0);
  String dAgo(Object p0);
  String get pickDate;
  String get pickDate2;
  String msg5(Object p0, Object p1, Object p2);
  String get passwordsNeedLeast8Characters;
  String get passwordsMustIncludeLetter;
  String get passwordsMustIncludeNumber;
  String get seller2;
  String get home;
  String get alerts;
  String get collect;
  String get couldNotLoadPhoto;
  String slot2(Object p0);
  String confirmPutLocker(Object p0);
  String get enterTitleContent;
  String get titleCannotExceed255Characters;
  String get contentNeedsLeast5Characters;
  String get publishAnnouncement;
  String get everyUserSeeAnnouncementOncePublished;
  String get publish;
  String get announcementPublished;
  String get draftSaved;
  String get editAnnouncement;
  String get newAnnouncement;
  String get title2;
  String get announcementTitle;
  String get writeAnnouncement;
  String get publishNow;
  String get leaveOffSaveAsDraft;
  String get saveDraft;
  String get deleteAnnouncement;
  String deleteP0CannotUndone(Object p0);
  String get announcementDeleted;
  String get couldNotDeleteTryAgainLater;
  String get announcements;
  String get noAnnouncementsYetTapAddOne;
  String get published;
  String get draft;
  String get audienceEveryone;
  String get backUpNow;
  String get wholeDatabaseExportedCompressedWithLot;
  String get startBackup;
  String get backingUpDatabase;
  String get backupComplete;
  String get backupDeleted;
  String get databaseBackups;
  String backedUpDailyNewestP0Kept(Object p0);
  String get olderBackupsBeyondCountRemovedAutomatically;
  String get noBackupsYetSchedulerRunsOnce;
  String get deleteBackup;
  String p0NNtheFileItsRecord(Object p0);
  String get manual;
  String get scheduled;
  String get download;
  String get downloadBackup;
  String fetchBackupComputerWithAuthorisationHeader(Object p0, Object p1);
  String get copyLink2;
  String get downloadLinkCopied;
  String get forceDelist;
  String get reasonDelistingSellerNotified;
  String get delist3;
  String get relist2;
  String putP0BackStore(Object p0);
  String get relisted;
  String get searchTitleIsbnSeller;
  String get noBooksMatch;
  String sellerP0P1(Object p0, Object p1);
  String isbnP0P1Views(Object p0, Object p1);
  String p0ReportsAwaitingReview(Object p0);
  String get enterLockerNameAddress;
  String get enterValidLatitudeLongitude;
  String get latitudeMustBetween9090;
  String get longitudeMustBetween180180;
  String get slotCountMustBetween1100;
  String get closingTime;
  String p0MustLookLikeHhMm(Object p0);
  String get fillBothOpeningClosingTimes;
  String get lockerUpdated;
  String get lockerAdded;
  String get editLocker;
  String get newLocker;
  String get lockerName;
  String get latitude;
  String get longitude;
  String get slotCount;
  String get createLocker;
  String get disable;
  String onceDisabledP0NoLongerAppears(Object p0);
  String onceEnabledP0AvailableSellersAgain(Object p0);
  String get lockerDisabled;
  String get lockerEnabled;
  String slotP0(Object p0);
  String get slotStatusUpdated;
  String get lockerMonitor;
  String get searchLockerNameAddress;
  String get noLockersMatch;
  String get disabled;
  String freeSlotsP0P1(Object p0, Object p1);
  String get newCategory;
  String get editCategory;
  String get categoryName;
  String get enterCategoryName;
  String get categoryAdded;
  String get categoryUpdated;
  String get deleteCategory;
  String deleteP0CannotUndone2(Object p0);
  String get categoryDeleted;
  String get categories;
  String get noCategoriesYet;
  String p0BooksUse(Object p0);
  String get legalDocuments;
  String get notCreatedYet;
  String updatedP0(Object p0);
  String p0Characters(Object p0);
  String p0SectionsP1Characters(Object p0, Object p1);
  String get deleteSection;
  String get contentsSectionRemovedWith;
  String p0ItsContentsRemoved(Object p0);
  String get discardChanges;
  String get documentUnsavedChangesTheyLostIf;
  String get discard;
  String get keepEditing;
  String get bothTitleContentRequired;
  String sectionP0NoTitleYet(Object p0);
  String updateP0(Object p0);
  String get documentBindingEveryUserSubmittingReplaces;
  String get yesUpdate;
  String get notifyEveryUser;
  String get updateNotify;
  String get updateOnly;
  String get sections;
  String get plainText;
  String get preview;
  String get documentTitle;
  String get preamble;
  String get unnumberedOpeningTextLeaveEmptyIf;
  String get articles;
  String get numberedAutomatically;
  String get noArticlesYetAddFirstOne;
  String get addSection;
  String get untitledSection;
  String get sectionTitle;
  String get bodySectionSingleLineBreaksKept;
  String get emptyLineStartsParagraphParagraphWhose;
  String get howUsersSee;
  String get noContentYet;
  String get unsaved;
  String get upDate;
  String get newQuestion;
  String get editQuestion;
  String get question;
  String get answer;
  String get showHelpCentre;
  String get bothQuestionAnswerRequired;
  String get added;
  String get updated;
  String get deleteQuestion;
  String deleteP0(Object p0);
  String get deleted;
  String get faq;
  String get noQuestionsYet2;
  String get dragHandleRightReorder;
  String get hidden;
  String get cancelDeletionRequest;
  String p0SAccountReturnsNormalCountdown(Object p0);
  String get cancelDeletion;
  String get deletionRequestCancelled;
  String get anonymiseNow;
  String eraseP0SPersonalDataDisable(Object p0);
  String get doNow;
  String get anonymised;
  String get pendingDeletions;
  String get noDeletionRequestsPending;
  String get dueSoon;
  String p0DaysLeft(Object p0);
  String requestedP0ScheduledP1(Object p0, Object p1);
  String get disputeResolution;
  String orderP0P1(Object p0, Object p1);
  String reasonP0(Object p0);
  String get decisionNoteOptional;
  String get submitDecision;
  String get decisionRecorded;
  String get resolveDispute;
  String get noDisputesKind;
  String orderNumberP0(Object p0);
  String buyerP0SellerP1(Object p0, Object p1);
  String filedByP0(Object p0);
  String get handle;
  String get transactions2;
  String get orders;
  String get lookUpOrdersAdjustStatusBy;
  String get disputeListDecisions;
  String get listings;
  String get allBooksForceDelisting;
  String get moderation;
  String get handleListingReports;
  String get addReorderDeleteBookCategories;
  String get members;
  String get memberControls;
  String get memberListSuspensionBlocklist;
  String get membershipTiers;
  String get tierThresholdsBenefits;
  String get wallets;
  String get checkBalancesAddDeductCoinsBy;
  String get hardwareOperations;
  String get lockerSlotStatus;
  String get maintenanceLog;
  String get lockerOperationHistory;
  String get reports;
  String get ordersRevenueMemberGrowth;
  String get announcements2;
  String get supportEnquiries;
  String get replyQuestionsFromUsers;
  String get faqShownHelpCentre;
  String get termsPrivacyPolicyAbout;
  String get adminAuditLog;
  String get auditTrailAdminChanges;
  String get systemOperations;
  String get dailyBackupsManualRunsDownloads;
  String get deletionRequestsInsideGracePeriodCancel;
  String get members2;
  String get todaySOrders;
  String get openCases;
  String get activeLockers;
  String get newTier;
  String get editTier;
  String get tierName;
  String get minimumPoints;
  String get maximumPointsLeaveEmptyNoCap;
  String get benefitsSeparatedByCommasLineBreaks;
  String get enterTierName;
  String get maximumPointsMustExceedMinimum;
  String get tierAdded;
  String get tierUpdated;
  String get deleteTier;
  String deleteP0MembersTierDropNext(Object p0);
  String get tierDeleted;
  String get noMembershipTiersSetUp;
  String p0PointsUp(Object p0);
  String p0P1Points(Object p0, Object p1);
  String get noBenefitsDescribedYet;
  String get noMaintenanceRecords;
  String get noFurtherDetail;
  String get operator;
  String get unknown;
  String get time;
  String get recordNumber;
  String operatorP0(Object p0);
  String get suspendAccount;
  String get reinstateAccount;
  String get addBlocklist;
  String get removeFromBlocklist;
  String p0SignedOutImmediatelyCanNo(Object p0);
  String p0AbleSignAgain(Object p0);
  String get accountStatusUpdated;
  String get removeAdmin;
  String get makeAdmin;
  String p0LosesEveryAdminPermissionImmediately(Object p0);
  String p0GainsAccessAdminAreaWith(Object p0);
  String get roleUpdated;
  String manualP0P1(Object p0, Object p1);
  String get adjustMembershipTier;
  String currentlyP0PointsAutomaticP1P2(Object p0, Object p1, Object p2);
  String p0P1Points2(Object p0, Object p1);
  String get adjustPointsManually;
  String get backAutomatic;
  String get backAutomatic2;
  String get pointAdjustment;
  String get positiveAddsNegativeDeductsEG;
  String get apply;
  String get enterNonZeroWholeNumber;
  String get pointsAdjusted;
  String get tierAdjusted;
  String get permissionGranted;
  String get permissionRevoked;
  String get grantAllPermissions;
  String get revokeAllPermissions;
  String p0AbleUseEveryAdminFeature(Object p0);
  String p0ReachAdminAreaButUnable(Object p0);
  String get allPermissionsGranted;
  String get allPermissionsRevoked;
  String get memberSettings;
  String get noDataMember;
  String get listings2;
  String get completedTrades;
  String get joined;
  String get accountStatus;
  String get ownAccountStatusPermissionsCannotChanged;
  String get accountEnabled;
  String get canSignUseAppNormally;
  String get suspendedSignedOutImmediatelyAfterSigning;
  String get blocked;
  String get blockedNoFeaturesAvailable;
  String get notBlocked;
  String get role;
  String p0PointsAutomaticP1P2(Object p0, Object p1, Object p2);
  String get memberSTierBeenAdjustedBy;
  String get adjustTier;
  String get adminPermissions;
  String get all;
  String get allOff;
  String get reinstateAccount2;
  String get suspendAccount2;
  String runP1P0(Object p0, Object p1);
  String updatedP0SStatus(Object p0);
  String get fullSettingsTierPermissions;
  String get members3;
  String get searchDisplayNameEmail;
  String get noMembersMatch;
  String get sales2;
  String get created;
  String get noActivityYet;
  String get changeOrderStatus;
  String orderP0(Object p0);
  String get reasonChange;
  String get sentBuyerAsWellOptional;
  String get applyChange;
  String get orderStatusUpdated;
  String get searchOrderNumberBuyerSeller;
  String get noOrdersMatch;
  String get noItems;
  String p0ItemsTotal(Object p0);
  String buyerP0SellerP12(Object p0, Object p1);
  String lockerP0(Object p0);
  String cancellationReasonP0(Object p0);
  String get reviewReport;
  String reportedP0P1(Object p0, Object p1);
  String reasonP02(Object p0);
  String get handlingNoteOptional;
  String get delistListingAsWell;
  String get dismissReport;
  String get reportHandled;
  String get noReportsKind;
  String reportedByP0(Object p0);
  String get review;
  String noteP0(Object p0);
  String get last7Days;
  String get last30Days;
  String get ordersPerDay;
  String get revenuePerDay;
  String get newMembersPerDay;
  String get newOrders;
  String get newMembers;
  String get newListings;
  String get completedRevenue;
  String p0Orders(Object p0);
  String peakP0(Object p0);
  String get topCategoriesByListings;
  String get replied;
  String get noEnquiriesCategory;
  String get addCoins;
  String get deductCoins;
  String get amountPositiveWholeNumber;
  String get reasonAdjustmentRequired;
  String get add2;
  String get deduct;
  String get enterAmountGreaterThan0;
  String get enterReasonAdjustment;
  String get member2;
  String get add3;
  String get deduct2;
  String get confirmAddingCoins;
  String get confirmDeductingCoins;
  String p1P2CoinsP0NreasonP3(Object p0, Object p1, Object p2, Object p3);
  String get balanceAdjusted;
  String get memberWallets;
  String get transactions3;
  String get memberNoTransactionsYet;
  String get balanceCoins;
  String get hold2;
  String get total2;
  String get totalOut;
  String balanceP0(Object p0);
  String get suspensionBlocklistRoles;
  String get tierThresholdsManualAdjustments;
  String get booksCategories;
  String get reportReview;
  String get handleListingReports2;
  String get lookUpChangeOrderStatus;
  String get decideDisputeCases;
  String get checkAdjustCoinBalances;
  String get hardware;
  String get lockersSlots;
  String get announcementsDocuments;
  String get announcementsFaqLegalDocuments;
  String get replyUserQuestions;
  String get databaseBackupDownloadOffByDefault;
  String p0Locker(Object p0);
  String everyActiveMemberReceivesP0Updated(Object p0);
  String get orderPlaced;
  String get paid;
  String get sellerDroppedOff;
  String get buyerCollected;
  String get completed;
  String get editBookDetails;
  String sellerP0TheyNotifiedSave(Object p0);
  String get priceCoins;
  String get k1013Digits2;
  String get category;
  String get description2;
  String get titleRequired;
  String get nothingChanged;
  String get resetPassword;
  String p0SCurrentPasswordStopsWorking(Object p0);
  String get generateTemporaryPassword;
  String get temporaryPassword;
  String p0SPasswordBeenResetPassword(Object p0);
  String get remindThemChangeSettingsChangePassword;
  String get temporaryPasswordCopied;
  String get copy;
  String get cannotResetAnotherAdminSPassword;
  String get generateTemporaryPasswordHandOver;
  String get orderNumberCopied;
  String get orderNotFound;
  String get paidWithCoins;
  String get bankTransfer;
  String get notPaidYet;
  String get progress;
  String get notYet;
  String get buyerSeller;
  String get items3;
  String get bookDeleted;
  String get notAssignedYet2;
  String get pickupCodeCopied;
  String get walletActivity;
  String balanceP02(Object p0);
  String get refunds;
  String requestedP0NotProcessedYet(Object p0);
  String processedP0(Object p0);
  String get disputes;
  String filedP0(Object p0);
  String decidedP0(Object p0);
  String createdP0(Object p0);
  String get shareBook;
  String get shareAnotherApp;
  String get approved;
  String get awaitingRefund;
  String get declined;
  String get changeOwnPasswordGoSettingsChange;
  String get memberNotAdminSoThereNo;
  String get you;
  String isbnMust1013DigitsOne(Object p0);
  String get screenUnsavedChangesTheyLostIf;
  String stillNeededP0(Object p0);
  String photosP0(Object p0);
  String get confirmListing;
  String get lookingUpBook;
  String get scan;
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

  @override
  String get verifySignSavemybook => 'Verify to sign in to SaveMyBook';

  @override
  String get maintenance => 'Maintenance';

  @override
  String get promotions => 'Promotions';

  @override
  String get policyUpdate => 'Policy update';

  @override
  String get announcement => 'Announcement';

  @override
  String get item => 'Item';

  @override
  String get member => 'Member';

  @override
  String get message => 'Message';

  @override
  String get noLongerExists => '(no longer exists)';

  @override
  String get uncategorised => 'Uncategorised';

  @override
  String get general => 'General';

  @override
  String get untitled => 'Untitled';

  @override
  String get noDescriptionYet => 'No description yet';

  @override
  String get locationNotProvided => 'Location not provided';

  @override
  String seller3(Object p0) => 'Seller: ${p0}';

  @override
  String get unknownAuthor => 'Unknown author';

  @override
  String get unknownPublisher => 'Unknown publisher';

  @override
  String get noIsbn => 'No ISBN';

  @override
  String get user => 'User';

  @override
  String get noMessagesYet => 'No messages yet';

  @override
  String get photo => '[Photo]';

  @override
  String item2(Object p0) => '[Item] ${p0}';

  @override
  String get purchase => 'Purchase';

  @override
  String get sale => 'Sale';

  @override
  String get systemAdjustment => 'System adjustment';

  @override
  String get preparingData => 'Preparing your data';

  @override
  String get mySavemybookData => 'My SaveMyBook data';

  @override
  String get exportedChooseWhereSave => 'Exported. Choose where to save it.';

  @override
  String get exportedButSharingCouldNotOpen => 'Exported, but sharing could not open';

  @override
  String get regenerateShareLink => 'Regenerate share link';

  @override
  String get oldLinkQrCodeStopWorking => 'The old link and QR code stop working immediately, and anyone you already shared with will no longer be able to open it. Regenerate?';

  @override
  String get regenerate => 'Regenerate';

  @override
  String get newLinkCreatedOldOneNo => 'New link created. The old one no longer works.';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get accountPermanentlyDisabled30DaysSign => 'Your account will be permanently disabled in 30 days. Sign in again before then to cancel.\n\n';

  @override
  String get personalDataErasedButCompletedOrders => 'Your personal data is erased, but completed orders and transaction records are kept so ';

  @override
  String get peopleTradedWithDoNotLose => 'the people you traded with do not lose their records.';

  @override
  String get actionContinue => 'Continue';

  @override
  String get verify => 'Verify it is you';

  @override
  String get enterPasswordConfirm => 'Enter your password to confirm this is you.';

  @override
  String get password => 'Password';

  @override
  String get requestDeletion => 'Request deletion';

  @override
  String get receivedSignAgainWithin30Days => 'Received. Sign in again within 30 days to cancel.';

  @override
  String get deletionCancelledAccountActiveAgain => 'Deletion cancelled. Your account is active again.';

  @override
  String get account => 'Account';

  @override
  String get data => 'Your data';

  @override
  String get exportMyData => 'Export my data';

  @override
  String get profileBooksOrdersTransactionsJson => 'Profile, books, orders and transactions in JSON';

  @override
  String get oldLinkQrCodeStopWorking2 => 'The old link and QR code stop working immediately';

  @override
  String get cancelAccountDeletion => 'Cancel account deletion';

  @override
  String get restoreAccountStopCountdown => 'Restore the account and stop the countdown';

  @override
  String get canChangeMindWithin30Days => 'You can change your mind within 30 days';

  @override
  String get deletionPending => 'Deletion pending';

  @override
  String daysLeftCanCancelAnyTime(Object p0) => '${p0} days left. You can cancel any time before then; after that your data is erased for good.';

  @override
  String get signOut => 'Sign out';

  @override
  String get type => 'Type';

  @override
  String get content => 'Content';

  @override
  String get backupFailed => 'Backup failed';

  @override
  String get myBooks => 'My books';

  @override
  String get notProvided => 'Not provided';

  @override
  String get openingHours => 'Opening hours';

  @override
  String get address => 'Address';

  @override
  String get saveChanges => 'Save changes';

  @override
  String get enable => 'Enable';

  @override
  String get termsService => 'Terms of Service';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get aboutUs => 'About us';

  @override
  String get admin => 'Admin';

  @override
  String get confirm => 'Confirm';

  @override
  String get membershipTier => 'Membership tier';

  @override
  String get phone => 'Phone';

  @override
  String get violationConfirmed => 'Violation confirmed';

  @override
  String get scanBarcode => 'Scan barcode';

  @override
  String get lineUpBarcodeSpineWithFrame => 'Line up the barcode on the spine with the frame';

  @override
  String get signAddItemsCart => 'Sign in to add items to your cart';

  @override
  String bookCannotPurchased(Object p0) => 'This book is ${p0} and cannot be purchased';

  @override
  String get addedCart => 'Added to cart';

  @override
  String get sellerInformationNotFound => 'Seller information not found';

  @override
  String get signContactSeller => 'Sign in to contact the seller';

  @override
  String get signStartChat => 'Sign in to start a chat';

  @override
  String get signReport => 'Sign in to report';

  @override
  String get cannotReportOwnListing => 'You cannot report your own listing';

  @override
  String get reportListing => 'Report this listing';

  @override
  String get describeProblemLeast5Characters => 'Describe the problem (at least 5 characters)';

  @override
  String get reasonNeedsLeast5Characters => 'Your reason needs at least 5 characters';

  @override
  String get reportSubmittedWeLookInto => 'Report submitted. We will look into it.';

  @override
  String get publisher => 'Publisher: ';

  @override
  String get author => 'Author: ';

  @override
  String get listed => 'Listed: ';

  @override
  String get searchTitleAuthorPublisher => 'Search title, author or publisher...';

  @override
  String get share => 'Share';

  @override
  String get report => 'Report';

  @override
  String get about => 'About: ';

  @override
  String pickup(Object p0) => 'Pickup at ${p0}';

  @override
  String get messageSeller => 'Message seller';

  @override
  String get listing => 'This is your listing';

  @override
  String get addCart => 'Add to cart';

  @override
  String get bookBeenReportedUnderReviewStays => 'This book has been reported and is under review. It stays on sale in the meantime.';

  @override
  String get violationWasConfirmedBookPleaseCheck => 'A violation was confirmed for this book. Please check that the listing follows our guidelines.';

  @override
  String get reportDismissed2 => 'Report dismissed';

  @override
  String get bookWasReportedButNoViolation => 'This book was reported but no violation was found. Your listing is unaffected.';

  @override
  String get delist => 'Delist';

  @override
  String removedFromShopBuyersNoLonger(Object p0) => '“${p0}” will be removed from the shop and buyers will no longer see it.';

  @override
  String get delist2 => 'Delist';

  @override
  String get delistedRelistFromDelistedTab => 'Delisted. Relist it from the Delisted tab.';

  @override
  String get couldNotDelistPleaseTryAgain => 'Could not delist. Please try again.';

  @override
  String listedAgain(Object p0) => '“${p0}” is listed again';

  @override
  String get notListedAnyBooksYet => 'You have not listed any books yet';

  @override
  String get noBooksCategory => 'No books in this category';

  @override
  String get listFirstBook => 'List your first book';

  @override
  String get relist => 'Relist';

  @override
  String get removeFromCart => 'Remove from cart';

  @override
  String removeFromCart2(Object p0) => 'Remove “${p0}” from your cart?';

  @override
  String get remove => 'Remove';

  @override
  String get couldNotRemoveRestored => 'Could not remove. Restored.';

  @override
  String get couldNotRemovePleaseTryAgain => 'Could not remove. Please try again.';

  @override
  String get selectBooksWantCheckOut => 'Select the books you want to check out';

  @override
  String notEnoughCoinsOrderNeedsBut(Object p0, Object p1) => 'Not enough coins. This order needs ${p0} but you have ${p1}.';

  @override
  String get confirmCheckout => 'Confirm checkout';

  @override
  String booksTotal(Object p0, Object p1) => '${p0} books, ${p1} in total.\n';

  @override
  String balanceAfterPaymentCoins(Object p0) => 'Your balance after payment will be ${p0} coins.';

  @override
  String get orderPlacedSellerDropBookOff => 'Order placed. The seller will drop the book off.';

  @override
  String get cart => 'Cart';

  @override
  String get cartEmpty => 'Your cart is empty';

  @override
  String get selectAll => 'Select all';

  @override
  String items(Object p0) => '${p0} items';

  @override
  String get deselect => 'Deselect';

  @override
  String get select => 'Select';

  @override
  String coinsShort(Object p0) => '${p0} coins short';

  @override
  String get total => 'Total';

  @override
  String selected(Object p0) => '${p0} selected';

  @override
  String balance2(Object p0) => 'Balance ${p0}';

  @override
  String get selectBookFirst => 'Select a book first';

  @override
  String get checkOut => 'Check out';

  @override
  String get notEnoughCoins => 'Not enough coins';

  @override
  String get weak => 'Weak';

  @override
  String get fair => 'Fair';

  @override
  String get strong => 'Strong';

  @override
  String get enterCurrentPassword => 'Enter your current password';

  @override
  String get enterNewPassword => 'Enter a new password';

  @override
  String get newPasswordMustDifferent => 'The new password must be different';

  @override
  String get enterNewPasswordAgain => 'Enter the new password again';

  @override
  String get passwordsDoNotMatch => 'The passwords do not match';

  @override
  String get passwordUpdated => 'Password updated';

  @override
  String get changePassword => 'Change password';

  @override
  String get useLeast8CharactersWithBoth => 'Use at least 8 characters with both letters and numbers.';

  @override
  String get currentPassword => 'Current password';

  @override
  String get newPassword => 'New password';

  @override
  String get confirmNewPassword => 'Confirm new password';

  @override
  String get updatePassword => 'Update password';

  @override
  String get deleteChat => 'Delete chat';

  @override
  String allMessagesWithDeletedBothCannot(Object p0) => 'All messages with ${p0} are deleted for both of you. This cannot be undone.';

  @override
  String get chatDeleted => 'Chat deleted';

  @override
  String get couldNotDeleteRestored => 'Could not delete. Restored.';

  @override
  String get chatMuted => 'Chat muted';

  @override
  String get chatUnmuted => 'Chat unmuted';

  @override
  String get noUnreadMessages => 'No unread messages';

  @override
  String get markAllAsRead => 'Mark all as read';

  @override
  String markAllUnreadMessagesAsRead(Object p0) => 'Mark all ${p0} unread messages as read? This cannot be undone.';

  @override
  String get markAllRead => 'Mark all read';

  @override
  String get allMarkedAsRead => 'All marked as read';

  @override
  String get somethingWentWrongPleaseTryAgain => 'Something went wrong. Please try again.';

  @override
  String get chats => 'Chats';

  @override
  String get noConversationsYet => 'No conversations yet';

  @override
  String get unmute => 'Unmute';

  @override
  String get mute => 'Mute';

  @override
  String get messagesLimited500Characters => 'Messages are limited to 500 characters';

  @override
  String get messageCouldNotSent => 'Message could not be sent';

  @override
  String get chat => 'Chat';

  @override
  String get sendFirstMessage => 'Send the first message';

  @override
  String get messageCopied => 'Message copied';

  @override
  String get iQuestionAboutBook => 'I have a question about this book';

  @override
  String get bookNoLongerListed => 'This book is no longer listed';

  @override
  String get writeMessage => 'Write a message…';

  @override
  String get enterOrderNumberDisputing => 'Enter the order number you are disputing';

  @override
  String get describeDispute => 'Describe the dispute';

  @override
  String get useLeast10CharactersSoSupport => 'Use at least 10 characters so support can assess it';

  @override
  String get submitDispute => 'Submit dispute';

  @override
  String get orderEntersDisputeProcessPaymentSeller => 'The order enters the dispute process and payment to the seller is held until support decides.';

  @override
  String paymentHoldRequested(Object p0) => '[Payment hold requested] ${p0}';

  @override
  String get disputeSubmittedSupportContact => 'Dispute submitted. Support will contact you.';

  @override
  String get dispute => 'Dispute';

  @override
  String get requestPaymentHold => 'Request payment hold';

  @override
  String get paymentSellerHeldUntilSupportDecides => 'Payment to the seller is held until support decides';

  @override
  String get submitDispute2 => 'Submit a dispute';

  @override
  String get orderNumber => 'Order number';

  @override
  String get eGSmb20260910123456789 => 'e.g. SMB20260910123456789';

  @override
  String get whatHappened => 'What happened';

  @override
  String get describeProblemEGConditionDoes => 'Describe the problem, e.g. the condition does not match the listing…';

  @override
  String get submit => 'Submit';

  @override
  String get uploadPhotos => 'Upload photos';

  @override
  String get canAttachUp6Photos => 'You can attach up to 6 photos';

  @override
  String get up5 => 'Up to 5';

  @override
  String get couldNotReplacePhotoPleaseTry => 'Could not replace the photo. Please try again.';

  @override
  String get keepLeastOnePhoto => 'Keep at least one photo';

  @override
  String get photoDeleted => 'Photo deleted';

  @override
  String get couldNotDeletePhotoPleaseTry => 'Could not delete the photo. Please try again.';

  @override
  String get canUp10Photos => 'You can have up to 10 photos';

  @override
  String get deletePhoto => 'Delete photo';

  @override
  String get cannotUndoneContinue => 'This cannot be undone. Continue?';

  @override
  String get photoMissingDataRefreshTryAgain => 'This photo is missing data. Refresh and try again.';

  @override
  String get enterPrice => 'Enter a price';

  @override
  String get priceMustGreaterThan0 => 'Price must be greater than 0';

  @override
  String get priceCannotExceed999999 => 'Price cannot exceed 999,999';

  @override
  String get chooseLockerLocation => 'Choose a locker location';

  @override
  String missingTheseThreeRequired(Object p0) => 'Missing: ${p0}. These three are required.';

  @override
  String get bookUpdated => 'Book updated';

  @override
  String get editBook => 'Edit book';

  @override
  String get condition => 'Condition';

  @override
  String get customPrice => 'Custom price';

  @override
  String get enterPrice2 => 'Enter your price';

  @override
  String get lockerLocation => 'Locker location';

  @override
  String get chooseLocker => 'Choose a locker';

  @override
  String get bookPhotos => 'Book photos';

  @override
  String get morePhotos => 'More photos';

  @override
  String get add => 'Add';

  @override
  String get enterTitle => 'Enter the title';

  @override
  String get titleLimited255Characters => 'The title is limited to 255 characters';

  @override
  String get isbn1013Digits => 'An ISBN is 10 or 13 digits';

  @override
  String get chooseCategory => 'Choose a category';

  @override
  String get k1013Digits => '10 or 13 digits';

  @override
  String get title => 'Title';

  @override
  String get actionRequired => 'Required';

  @override
  String get author2 => 'Author';

  @override
  String get optional => 'Optional';

  @override
  String get publisher2 => 'Publisher';

  @override
  String get publicationDate => 'Publication date';

  @override
  String get tapPickPublicationDate => 'Tap to pick a publication date';

  @override
  String get pickPublicationDate => 'Pick a publication date';

  @override
  String get pickCategory => 'Pick a category';

  @override
  String get next => 'Next';

  @override
  String get uploading => 'Uploading…';

  @override
  String get profilePhotoUpdated => 'Profile photo updated';

  @override
  String get couldNotUploadPhoto => 'Could not upload the photo';

  @override
  String get changeDisplayName => 'Change display name';

  @override
  String get enterDisplayName => 'Enter a display name';

  @override
  String get displayNameCannotBlank => 'Display name cannot be blank';

  @override
  String get displayNames250Characters => 'Display names are 2 to 50 characters';

  @override
  String get invalidPhoneNumberEG0912345678 => 'Invalid phone number, e.g. 0912345678';

  @override
  String get profileUpdated => 'Profile updated';

  @override
  String get editProfile => 'Edit profile';

  @override
  String get bio => 'Bio';

  @override
  String get tellPeopleAboutYourself => 'Tell people about yourself';

  @override
  String get email => 'Email';

  @override
  String get emailCannotChanged => 'Email cannot be changed';

  @override
  String get dateBirth => 'Date of birth';

  @override
  String get tapPickDateBirth => 'Tap to pick your date of birth';

  @override
  String get pickDateBirth => 'Pick your date of birth';

  @override
  String get savedBooks => 'Saved books';

  @override
  String get notSavedAnyBooksYet => 'You have not saved any books yet';

  @override
  String get helpCentre => 'Help centre';

  @override
  String get searchQuestions => 'Search questions';

  @override
  String get noQuestionsYet => 'No questions yet';

  @override
  String get noMatchingQuestions => 'No matching questions';

  @override
  String get newest => 'Newest';

  @override
  String get popular => 'Popular';

  @override
  String get priceLowHigh => 'Price: low to high';

  @override
  String get priceHighLow => 'Price: high to low';

  @override
  String get reachedEnd => 'You have reached the end';

  @override
  String get guest => 'Guest';

  @override
  String hi(Object p0) => 'Hi, ${p0}';

  @override
  String get noBooksMatchFilters => 'No books match your filters';

  @override
  String get couldNotReadPhoto => 'Could not read this photo';

  @override
  String get croppingFailedPleaseTryAgain => 'Cropping failed. Please try again.';

  @override
  String get adjustPhoto => 'Adjust photo';

  @override
  String get reset => 'Reset';

  @override
  String get usePhoto => 'Use this photo';

  @override
  String get documentNotBeenCreatedYet => 'This document has not been created yet';

  @override
  String lastUpdated(Object p0) => 'Last updated ${p0}';

  @override
  String get biometrics => 'Biometrics';

  @override
  String get sessionExpiredPleaseEnterPasswordAgain => 'Your session expired. Please enter your password again.';

  @override
  String turnSign(Object p0) => 'Turn on ${p0} sign-in?';

  @override
  String nextTimeOpenAppCanUnlock(Object p0) => 'Next time you open the app you can unlock with ${p0} instead of typing your password.';

  @override
  String get notNow => 'Not now';

  @override
  String get enterEmail => 'Enter your email';

  @override
  String get emailAddressNotValid => 'That email address is not valid';

  @override
  String get enterPassword => 'Enter your password';

  @override
  String get noAccountWithEmail => 'No account with that email';

  @override
  String noAccountCreateOneNow(Object p0) => 'No account for “${p0}”. Create one now?';

  @override
  String get signUp => 'Sign up';

  @override
  String get tryAgain => 'Try again';

  @override
  String get sign => 'Sign in';

  @override
  String signWith(Object p0) => 'Sign in with ${p0}';

  @override
  String get noAccountYetSignUp => 'No account yet? Sign up';

  @override
  String get membershipTiersNotSetUpYet => 'Membership tiers are not set up yet';

  @override
  String get currentTier => 'Your current tier';

  @override
  String get unlocked => 'Unlocked';

  @override
  String get locked => 'Locked';

  @override
  String get aboveTier => 'You are above this tier';

  @override
  String get reachedTopTier => 'You have reached the top tier';

  @override
  String unlocked2(Object p0) => '“${p0}” unlocked';

  @override
  String morePointsUnlock(Object p0, Object p1) => '${p0} more points to unlock “${p1}”';

  @override
  String benefits(Object p0) => '${p0} benefits';

  @override
  String get noBenefitsBeenDescribedTierYet => 'No benefits have been described for this tier yet.';

  @override
  String pointsFromCompletedOrders(Object p0, Object p1) => '${p0} points from ${p1} completed orders';

  @override
  String get noNotificationsClear => 'No notifications to clear';

  @override
  String get clearAllNotifications => 'Clear all notifications';

  @override
  String notificationsDeletedCannotUndone(Object p0) => '${p0} notifications will be deleted. This cannot be undone.';

  @override
  String get clearAll => 'Clear all';

  @override
  String get allNotificationsCleared => 'All notifications cleared';

  @override
  String get couldNotClearPleaseTryAgain => 'Could not clear. Please try again.';

  @override
  String get noUnreadNotifications => 'No unread notifications';

  @override
  String markAllUnreadNotificationsAsRead(Object p0) => 'Mark all ${p0} unread notifications as read? This cannot be undone.';

  @override
  String get openChat => 'Open chat';

  @override
  String get viewOrder => 'View order';

  @override
  String get openMyBooks => 'Open my books';

  @override
  String get notifications => 'Notifications';

  @override
  String get noNotifications => 'No notifications';

  @override
  String copied(Object p0) => '${p0} copied';

  @override
  String get orderDetails => 'Order details';

  @override
  String order(Object p0) => 'Order ${p0}';

  @override
  String get orderProgress => 'Order progress';

  @override
  String items2(Object p0) => 'Items (${p0})';

  @override
  String get orderNoItemDetails => 'This order has no item details.';

  @override
  String msg4(Object p0, Object p1) => '${p0} × ${p1}';

  @override
  String get orderTotal => 'Order total';

  @override
  String get pickupDetails => 'Pickup details';

  @override
  String get notAssigned => 'Not assigned';

  @override
  String get slot => 'Slot';

  @override
  String get notAssignedYet => 'Not assigned yet';

  @override
  String get pickupCode => 'Pickup code';

  @override
  String get transaction => 'Transaction';

  @override
  String get buyer => 'Buyer';

  @override
  String get seller => 'Seller';

  @override
  String get placed => 'Placed';

  @override
  String get dispute2 => 'Dispute';

  @override
  String get orderOpenDispute => 'This order has an open dispute';

  @override
  String get cancelOrder => 'Cancel order';

  @override
  String get pendingPayoutDisappearsBuyerNotified => 'The pending payout disappears and the buyer is notified.';

  @override
  String get cancelledBySeller => 'Cancelled by seller';

  @override
  String get orderCancelled2 => 'Order cancelled';

  @override
  String get pendingPayouts => 'Pending payouts';

  @override
  String get noPendingPayouts => 'No pending payouts';

  @override
  String get pendingAmount => 'Pending amount';

  @override
  String get coinsArriveOnceBuyerCollectsBook => 'Coins arrive once the buyer collects the book';

  @override
  String get scanned => 'Scanned';

  @override
  String get scanAgain => 'Scan again';

  @override
  String get collectBook => 'Collect a book';

  @override
  String get pointPickupQrCode => 'Point at the pickup QR code';

  @override
  String get holdSteady => 'Hold steady';

  @override
  String get bookCollected => 'Book collected';

  @override
  String get thanksUsingSavemybookHappyReading => 'Thanks for using SaveMyBook. Happy reading!';

  @override
  String collected(Object p0) => '“${p0}” collected';

  @override
  String order2(Object p0) => 'Order ${p0}';

  @override
  String get signingOut => 'Signing out…';

  @override
  String get myAccount => 'My account';

  @override
  String get personNotWrittenBioYet => 'This person has not written a bio yet';

  @override
  String get topTierReached => 'Top tier reached';

  @override
  String morePointsReach(Object p0, Object p1) => '${p0} more points to reach “${p1}”';

  @override
  String get myCoins => 'My coins';

  @override
  String get shareProfile => 'Share profile';

  @override
  String get purchases => 'Purchases';

  @override
  String get sales => 'Sales';

  @override
  String get settings => 'Settings';

  @override
  String get signOut2 => 'Sign out?';

  @override
  String get needSignAgainKeepUsingApp => 'You will need to sign in again to keep using the app.';

  @override
  String cancelOrderBookReturnsShop(Object p0) => 'Cancel order ${p0}? The book returns to the shop.';

  @override
  String get pickupCode2 => 'Pickup code';

  @override
  String get notGeneratedYet => 'Not generated yet';

  @override
  String get enterCodeLockerCollect => 'Enter this code on the locker to collect';

  @override
  String enterCodeCollect(Object p0) => 'Enter this code at ${p0} to collect';

  @override
  String get iCollected => 'I have collected it';

  @override
  String get noOrdersTab => 'No orders in this tab';

  @override
  String get openDispute => 'Open a dispute';

  @override
  String get displayNameNeedsLeast2Characters => 'Display name needs at least 2 characters';

  @override
  String get displayNameLimited50Characters => 'Display name is limited to 50 characters';

  @override
  String get enterPasswordAgain => 'Enter your password again';

  @override
  String get passwordsDoNotMatch2 => 'The passwords do not match';

  @override
  String get pleaseReadAcceptTermsServicePrivacy => 'Please read and accept the Terms of Service and Privacy Policy';

  @override
  String get accountCreatedSignWith => 'Account created. Sign in with it.';

  @override
  String get iReadAccept => 'I have read and accept the ';

  @override
  String get and => ' and ';

  @override
  String get createAccount => 'Create account';

  @override
  String get joinSavemybook => 'Join SaveMyBook';

  @override
  String get signUpBuySellUseSmart => 'Sign up to buy, sell and use the smart lockers';

  @override
  String get displayName => 'Display name';

  @override
  String get nameOthersSee => 'The name others will see';

  @override
  String get emailSignWith => 'The email you sign in with';

  @override
  String get least8CharactersWithLettersNumbers => 'At least 8 characters with letters and numbers';

  @override
  String get confirmPassword => 'Confirm password';

  @override
  String get enterPasswordAgain2 => 'Enter your password again';

  @override
  String get alreadyAccountGoBackSign => 'Already have an account? Go back to sign in';

  @override
  String get markAsDroppedOff => 'Mark as dropped off';

  @override
  String get droppedOff => 'Dropped off';

  @override
  String get markedAsDroppedOff => 'Marked as dropped off';

  @override
  String get buyerNotifiedBookReturnsShop => 'The buyer is notified and the book returns to the shop.';

  @override
  String get dropOffPickupCode => 'Drop-off / pickup code';

  @override
  String get enterCodeLocker => 'Enter this code on the locker';

  @override
  String get noRecentSearches => 'No recent searches';

  @override
  String get recentSearches => 'Recent searches';

  @override
  String get clearAll2 => 'Clear all';

  @override
  String get searchTitleAuthorIsbn => 'Search title, author or ISBN...';

  @override
  String get photoLimitReached => 'Photo limit reached';

  @override
  String get canUploadUp10Photos => 'You can upload up to 10 photos.';

  @override
  String get photosMissing => 'Photos missing';

  @override
  String missingTheseThreeRequired2(Object p0) => 'Missing: ${p0}. These three are required.';

  @override
  String get missingInformation => 'Missing information';

  @override
  String get enterOwnPrice => 'Enter your own price.';

  @override
  String get invalidPrice => 'Invalid price';

  @override
  String get priceMustGreaterThan02 => 'The price must be greater than 0.';

  @override
  String get priceCannotExceed99999 => 'The price cannot exceed 99,999.';

  @override
  String get chooseLockerLocation2 => 'Choose a locker location.';

  @override
  String get listed2 => 'Listed!';

  @override
  String get unknownError => 'Unknown error';

  @override
  String get couldNotListBook => 'Could not list the book';

  @override
  String serverError(Object p0) => 'Server error: ${p0}';

  @override
  String get connectionProblem => 'Connection problem';

  @override
  String get couldNotReachServerUploadTimed => 'Could not reach the server or the upload timed out. Check your connection.';

  @override
  String get listBook => 'List this book';

  @override
  String get detailsPhotos => 'Details and photos';

  @override
  String get loading => 'Loading...';

  @override
  String get unknownLocker => 'Unknown locker';

  @override
  String get enterTitle2 => 'Enter the title';

  @override
  String get chooseCategory2 => 'Choose a category';

  @override
  String get bookDetailsFilledAutomatically => 'Book details filled in automatically.';

  @override
  String get bookDetailsFilledFromBackupSource => 'Book details filled in from the backup source.';

  @override
  String get noSourceIsbnPleaseEnterDetails => 'No source has this ISBN. Please enter the details manually.';

  @override
  String get day => 'Day';

  @override
  String get tapIconRightScan => 'Tap the icon on the right to scan';

  @override
  String get description => 'Description';

  @override
  String get sellBook => 'Sell a book';

  @override
  String get myShop => 'My shop';

  @override
  String get sellerNoBooksSale => 'This seller has no books on sale';

  @override
  String get loading2 => 'Loading…';

  @override
  String sale2(Object p0) => '${p0} on sale';

  @override
  String get verifyEnableQuickSign => 'Verify to enable quick sign-in';

  @override
  String sign2(Object p0) => '${p0} sign-in is on';

  @override
  String get quickSignTurnedOff => 'Quick sign-in turned off';

  @override
  String get appearance2 => 'Appearance';

  @override
  String get signMethod => 'Sign-in method';

  @override
  String get helpSupport => 'Help and support';

  @override
  String get contactUs => 'Contact us';

  @override
  String get aboutSavemybook => 'About SaveMyBook';

  @override
  String get settingsPrivacy => 'Settings and privacy';

  @override
  String sign3(Object p0) => '${p0} sign-in';

  @override
  String unlockWithWhenOpenApp(Object p0) => 'Unlock with ${p0} when you open the app';

  @override
  String get scanProfileQrCode => 'Scan a profile QR code';

  @override
  String get lineUpTheirQrCodeWith => 'Line up their QR code with the frame';

  @override
  String get notSavemybookProfileQrCode => 'That is not a SaveMyBook profile QR code';

  @override
  String get ownQrCode => 'That is your own QR code';

  @override
  String get couldNotStartChatPleaseTry => 'Could not start the chat. Please try again.';

  @override
  String get linkCopied => 'Link copied';

  @override
  String addMeSavemybook(Object p0) => 'Add me on SaveMyBook: ${p0}';

  @override
  String addMeSavemybook2(Object p0, Object p1) => 'Add me on SaveMyBook (${p0}): ${p1}';

  @override
  String get sharingCouldNotOpenSoLink => 'Sharing could not open, so the link was copied instead';

  @override
  String get savedPhotos => 'Saved to your photos';

  @override
  String get couldNotSaveCheckPhotoLibrary => 'Could not save. Check photo library permission.';

  @override
  String get scanTheirQrCode => 'Scan their QR code';

  @override
  String get copyLink => 'Copy link';

  @override
  String get askQuestion => 'Ask a question';

  @override
  String get noEnquiriesYet => 'No enquiries yet';

  @override
  String get enterSubject => 'Enter a subject';

  @override
  String get addMoreDetailSoSupportCan => 'Add more detail so support can help';

  @override
  String get sentSupportReplySoon => 'Sent. Support will reply soon.';

  @override
  String get subject => 'Subject';

  @override
  String get sumUpOneLine => 'Sum it up in one line';

  @override
  String get whatHappenedIncludeOrderNumberIf => 'What happened? Include the order number if you have one.';

  @override
  String get close => 'Close';

  @override
  String get notAbleReplyAfterClosing => 'You will not be able to reply after closing.';

  @override
  String get enquiryClosed => 'Enquiry closed';

  @override
  String get changeStatus => 'Change status';

  @override
  String get statusUpdated => 'Status updated';

  @override
  String get enquiry => 'Enquiry';

  @override
  String get enquiryNotFound => 'Enquiry not found';

  @override
  String get support => 'Support';

  @override
  String get writeReply => 'Write a reply…';

  @override
  String get coins => 'Coins';

  @override
  String get transactions => 'Transactions';

  @override
  String get noTransactionsYet => 'No transactions yet';

  @override
  String get balance => 'Balance';

  @override
  String hold(Object p0) => '${p0} on hold';

  @override
  String requestFailed2(Object p0) => 'Request failed (${p0})';

  @override
  String get couldNotReachServer => 'Could not reach the server';

  @override
  String get couldNotReachServerCheckConnection => 'Could not reach the server. Check your connection.';

  @override
  String get signFailed => 'Sign-in failed';

  @override
  String get signFailedPleaseTryAgain => 'Sign-in failed. Please try again.';

  @override
  String get signUpFailed => 'Sign-up failed';

  @override
  String get pleaseSignFirst => 'Please sign in first';

  @override
  String get couldNotRelist => 'Could not relist';

  @override
  String get couldNotRemoveFromSaved => 'Could not remove from saved';

  @override
  String get couldNotSave => 'Could not save';

  @override
  String get couldNotAddCart => 'Could not add to cart';

  @override
  String get checkoutFailed => 'Checkout failed';

  @override
  String get couldNotCancelOrder => 'Could not cancel the order';

  @override
  String get couldNotUpdateOrder => 'Could not update the order';

  @override
  String get couldNotSubmitDispute => 'Could not submit the dispute';

  @override
  String get couldNotSubmitReport => 'Could not submit the report';

  @override
  String get updateFailed2 => 'Update failed';

  @override
  String get couldNotChangePassword => 'Could not change the password';

  @override
  String get requestFailed => 'Request failed';

  @override
  String get couldNotCancel => 'Could not cancel';

  @override
  String get couldNotDelete => 'Could not delete';

  @override
  String get couldNotComplete => 'Could not complete';

  @override
  String get couldNotSaveAnnouncement => 'Could not save the announcement';

  @override
  String get couldNotSend => 'Could not send';

  @override
  String get actionFailed => 'Action failed';

  @override
  String get couldNotSave2 => 'Could not save';

  @override
  String get documentUpdated => 'Document updated';

  @override
  String get couldNotAdjust => 'Could not adjust';

  @override
  String get couldNotProcessReport => 'Could not process the report';

  @override
  String get couldNotRecordDecision => 'Could not record the decision';

  @override
  String get couldNotReorder => 'Could not reorder';

  @override
  String get couldNotSaveLocker => 'Could not save the locker';

  @override
  String get fingerprint => 'Fingerprint';

  @override
  String get iris => 'Iris';

  @override
  String get verifyIdentityContinue => 'Verify your identity to continue';

  @override
  String get couldNotOpenPhotosCheckPermission => 'Could not open your photos. Check the permission.';

  @override
  String get choosePhotoSource => 'Choose a photo source';

  @override
  String get takePhoto => 'Take a photo';

  @override
  String get chooseFromPhotos => 'Choose from photos';

  @override
  String get couldNotOpenCameraCheckPermission => 'Could not open the camera. Check the permission.';

  @override
  String get justNow => 'Just now';

  @override
  String minAgo(Object p0) => '${p0} min ago';

  @override
  String hAgo(Object p0) => '${p0} h ago';

  @override
  String dAgo(Object p0) => '${p0} d ago';

  @override
  String get pickDate => 'Pick a date';

  @override
  String get pickDate2 => 'Pick a date';

  @override
  String msg5(Object p0, Object p1, Object p2) => '${p1}/${p2}/${p0}';

  @override
  String get passwordsNeedLeast8Characters => 'Passwords need at least 8 characters';

  @override
  String get passwordsMustIncludeLetter => 'Passwords must include a letter';

  @override
  String get passwordsMustIncludeNumber => 'Passwords must include a number';

  @override
  String get seller2 => 'Seller: ';

  @override
  String get home => 'Home';

  @override
  String get alerts => 'Alerts';

  @override
  String get collect => 'Collect';

  @override
  String get couldNotLoadPhoto => 'Could not load this photo';

  @override
  String slot2(Object p0) => 'Slot ${p0}';

  @override
  String confirmPutLocker(Object p0) => 'Confirm you have put “${p0}” in the locker?';

  @override
  String get enterTitleContent => 'Enter a title and content';

  @override
  String get titleCannotExceed255Characters => 'Title cannot exceed 255 characters';

  @override
  String get contentNeedsLeast5Characters => 'Content needs at least 5 characters';

  @override
  String get publishAnnouncement => 'Publish announcement';

  @override
  String get everyUserSeeAnnouncementOncePublished => 'Every user will see this announcement once published. Continue?';

  @override
  String get publish => 'Publish';

  @override
  String get announcementPublished => 'Announcement published';

  @override
  String get draftSaved => 'Draft saved';

  @override
  String get editAnnouncement => 'Edit announcement';

  @override
  String get newAnnouncement => 'New announcement';

  @override
  String get title2 => 'Title';

  @override
  String get announcementTitle => 'Announcement title';

  @override
  String get writeAnnouncement => 'Write the announcement';

  @override
  String get publishNow => 'Publish now';

  @override
  String get leaveOffSaveAsDraft => 'Leave off to save as a draft';

  @override
  String get saveDraft => 'Save draft';

  @override
  String get deleteAnnouncement => 'Delete announcement';

  @override
  String deleteP0CannotUndone(Object p0) => 'Delete "${p0}"? This cannot be undone.';

  @override
  String get announcementDeleted => 'Announcement deleted';

  @override
  String get couldNotDeleteTryAgainLater => 'Could not delete. Try again later.';

  @override
  String get announcements => 'Announcements';

  @override
  String get noAnnouncementsYetTapAddOne => 'No announcements yet. Tap + to add one.';

  @override
  String get published => 'Published';

  @override
  String get draft => 'Draft';

  @override
  String get audienceEveryone => 'Audience: everyone';

  @override
  String get backUpNow => 'Back up now';

  @override
  String get wholeDatabaseExportedCompressedWithLot => 'The whole database is exported and compressed. With a lot of data this can take tens of seconds; stay on this screen until it finishes.';

  @override
  String get startBackup => 'Start backup';

  @override
  String get backingUpDatabase => 'Backing up the database';

  @override
  String get backupComplete => 'Backup complete';

  @override
  String get backupDeleted => 'Backup deleted';

  @override
  String get databaseBackups => 'Database backups';

  @override
  String backedUpDailyNewestP0Kept(Object p0) => 'Backed up daily, newest ${p0} kept';

  @override
  String get olderBackupsBeyondCountRemovedAutomatically => 'Older backups beyond that count are removed automatically. A backup contains personal data for the whole site, so keep downloads secure. Every download is written to the audit log.';

  @override
  String get noBackupsYetSchedulerRunsOnce => 'No backups yet. The scheduler runs once a day, or use the button above to create one now.';

  @override
  String get deleteBackup => 'Delete backup';

  @override
  String p0NNtheFileItsRecord(Object p0) => '${p0}\n\nThe file and its record are both removed. This cannot be undone.';

  @override
  String get manual => 'Manual';

  @override
  String get scheduled => 'Scheduled';

  @override
  String get download => 'Download';

  @override
  String get downloadBackup => 'Download backup';

  @override
  String fetchBackupComputerWithAuthorisationHeader(Object p0, Object p1) => 'Fetch the backup on a computer, with your authorisation header:\n\n${p0}\n\nFile size ${p1}.';

  @override
  String get copyLink2 => 'Copy link';

  @override
  String get downloadLinkCopied => 'Download link copied';

  @override
  String get forceDelist => 'Force delist';

  @override
  String get reasonDelistingSellerNotified => 'Reason for delisting; the seller is notified';

  @override
  String get delist3 => 'Delist';

  @override
  String get relist2 => 'Relist';

  @override
  String putP0BackStore(Object p0) => 'Put "${p0}" back in the store?';

  @override
  String get relisted => 'Relisted';

  @override
  String get searchTitleIsbnSeller => 'Search title, ISBN or seller';

  @override
  String get noBooksMatch => 'No books match';

  @override
  String sellerP0P1(Object p0, Object p1) => 'Seller ${p0} | ${p1}';

  @override
  String isbnP0P1Views(Object p0, Object p1) => 'ISBN ${p0} | ${p1} views';

  @override
  String p0ReportsAwaitingReview(Object p0) => '${p0} reports awaiting review';

  @override
  String get enterLockerNameAddress => 'Enter a locker name and address';

  @override
  String get enterValidLatitudeLongitude => 'Enter a valid latitude and longitude';

  @override
  String get latitudeMustBetween9090 => 'Latitude must be between -90 and 90';

  @override
  String get longitudeMustBetween180180 => 'Longitude must be between -180 and 180';

  @override
  String get slotCountMustBetween1100 => 'Slot count must be between 1 and 100';

  @override
  String get closingTime => 'Closing time';

  @override
  String p0MustLookLikeHhMm(Object p0) => '${p0} must look like HH:mm, e.g. 09:00';

  @override
  String get fillBothOpeningClosingTimes => 'Fill in both opening and closing times';

  @override
  String get lockerUpdated => 'Locker updated';

  @override
  String get lockerAdded => 'Locker added';

  @override
  String get editLocker => 'Edit locker';

  @override
  String get newLocker => 'New locker';

  @override
  String get lockerName => 'Locker name';

  @override
  String get latitude => 'Latitude';

  @override
  String get longitude => 'Longitude';

  @override
  String get slotCount => 'Slot count';

  @override
  String get createLocker => 'Create locker';

  @override
  String get disable => 'Disable';

  @override
  String onceDisabledP0NoLongerAppears(Object p0) => 'Once disabled, "${p0}" no longer appears in the seller drop-off list.';

  @override
  String onceEnabledP0AvailableSellersAgain(Object p0) => 'Once enabled, "${p0}" is available to sellers again.';

  @override
  String get lockerDisabled => 'Locker disabled';

  @override
  String get lockerEnabled => 'Locker enabled';

  @override
  String slotP0(Object p0) => 'Slot ${p0}';

  @override
  String get slotStatusUpdated => 'Slot status updated';

  @override
  String get lockerMonitor => 'Locker monitor';

  @override
  String get searchLockerNameAddress => 'Search locker name or address';

  @override
  String get noLockersMatch => 'No lockers match';

  @override
  String get disabled => 'Disabled';

  @override
  String freeSlotsP0P1(Object p0, Object p1) => 'Free slots: ${p0} / ${p1}';

  @override
  String get newCategory => 'New category';

  @override
  String get editCategory => 'Edit category';

  @override
  String get categoryName => 'Category name';

  @override
  String get enterCategoryName => 'Enter a category name';

  @override
  String get categoryAdded => 'Category added';

  @override
  String get categoryUpdated => 'Category updated';

  @override
  String get deleteCategory => 'Delete category';

  @override
  String deleteP0CannotUndone2(Object p0) => 'Delete "${p0}"? This cannot be undone.';

  @override
  String get categoryDeleted => 'Category deleted';

  @override
  String get categories => 'Categories';

  @override
  String get noCategoriesYet => 'No categories yet';

  @override
  String p0BooksUse(Object p0) => '${p0} books in use';

  @override
  String get legalDocuments => 'Legal documents';

  @override
  String get notCreatedYet => 'Not created yet';

  @override
  String updatedP0(Object p0) => 'Updated ${p0}';

  @override
  String p0Characters(Object p0) => '${p0} characters';

  @override
  String p0SectionsP1Characters(Object p0, Object p1) => '${p0} sections | ${p1} characters';

  @override
  String get deleteSection => 'Delete section';

  @override
  String get contentsSectionRemovedWith => 'The contents of this section are removed with it.';

  @override
  String p0ItsContentsRemoved(Object p0) => '"${p0}" and its contents are removed.';

  @override
  String get discardChanges => 'Discard changes?';

  @override
  String get documentUnsavedChangesTheyLostIf => 'This document has unsaved changes. They are lost if you leave.';

  @override
  String get discard => 'Discard';

  @override
  String get keepEditing => 'Keep editing';

  @override
  String get bothTitleContentRequired => 'Both title and content are required';

  @override
  String sectionP0NoTitleYet(Object p0) => 'Section ${p0} has no title yet';

  @override
  String updateP0(Object p0) => 'Update ${p0}?';

  @override
  String get documentBindingEveryUserSubmittingReplaces => 'This document is binding on every user. Submitting replaces the current version immediately.';

  @override
  String get yesUpdate => 'Yes, update it';

  @override
  String get notifyEveryUser => 'Notify every user?';

  @override
  String get updateNotify => 'Update and notify';

  @override
  String get updateOnly => 'Update only';

  @override
  String get sections => 'Sections';

  @override
  String get plainText => 'Plain text';

  @override
  String get preview => 'Preview';

  @override
  String get documentTitle => 'Document title';

  @override
  String get preamble => 'Preamble';

  @override
  String get unnumberedOpeningTextLeaveEmptyIf => 'Unnumbered opening text. Leave empty if there is none.';

  @override
  String get articles => 'Articles';

  @override
  String get numberedAutomatically => 'Numbered automatically';

  @override
  String get noArticlesYetAddFirstOne => 'No articles yet. Add the first one below.';

  @override
  String get addSection => 'Add section';

  @override
  String get untitledSection => 'Untitled section';

  @override
  String get sectionTitle => 'Section title';

  @override
  String get bodySectionSingleLineBreaksKept => 'The body of this section. Single line breaks are kept as-is; an empty line starts a new paragraph.';

  @override
  String get emptyLineStartsParagraphParagraphWhose => 'An empty line starts a paragraph. A paragraph whose first line reads "1. Title" becomes a section when you switch back.';

  @override
  String get howUsersSee => 'How users see it';

  @override
  String get noContentYet => 'No content yet';

  @override
  String get unsaved => 'Unsaved';

  @override
  String get upDate => 'Up to date';

  @override
  String get newQuestion => 'New question';

  @override
  String get editQuestion => 'Edit question';

  @override
  String get question => 'Question';

  @override
  String get answer => 'Answer';

  @override
  String get showHelpCentre => 'Show in the help centre';

  @override
  String get bothQuestionAnswerRequired => 'Both question and answer are required';

  @override
  String get added => 'Added';

  @override
  String get updated => 'Updated';

  @override
  String get deleteQuestion => 'Delete question';

  @override
  String deleteP0(Object p0) => 'Delete "${p0}"?';

  @override
  String get deleted => 'Deleted';

  @override
  String get faq => 'FAQ';

  @override
  String get noQuestionsYet2 => 'No questions yet';

  @override
  String get dragHandleRightReorder => 'Drag the handle on the right to reorder';

  @override
  String get hidden => 'Hidden';

  @override
  String get cancelDeletionRequest => 'Cancel deletion request';

  @override
  String p0SAccountReturnsNormalCountdown(Object p0) => '${p0}\'s account returns to normal and the countdown stops.';

  @override
  String get cancelDeletion => 'Cancel deletion';

  @override
  String get deletionRequestCancelled => 'Deletion request cancelled';

  @override
  String get anonymiseNow => 'Anonymise now';

  @override
  String eraseP0SPersonalDataDisable(Object p0) => 'Erase ${p0}\'s personal data and disable the account now, without waiting for the grace period.\n\nOrders and transaction records are kept, but the display name becomes \\"Deleted user\\". This cannot be undone.';

  @override
  String get doNow => 'Do it now';

  @override
  String get anonymised => 'Anonymised';

  @override
  String get pendingDeletions => 'Pending deletions';

  @override
  String get noDeletionRequestsPending => 'No deletion requests pending';

  @override
  String get dueSoon => 'Due soon';

  @override
  String p0DaysLeft(Object p0) => '${p0} days left';

  @override
  String requestedP0ScheduledP1(Object p0, Object p1) => 'Requested ${p0}, scheduled for ${p1}';

  @override
  String get disputeResolution => 'Dispute resolution';

  @override
  String orderP0P1(Object p0, Object p1) => 'Order ${p0} | \\\$${p1}';

  @override
  String reasonP0(Object p0) => 'Reason: ${p0}';

  @override
  String get decisionNoteOptional => 'Decision note (optional)';

  @override
  String get submitDecision => 'Submit decision';

  @override
  String get decisionRecorded => 'Decision recorded';

  @override
  String get resolveDispute => 'Resolve dispute';

  @override
  String get noDisputesKind => 'No disputes of this kind';

  @override
  String orderNumberP0(Object p0) => 'Order number: ${p0}';

  @override
  String buyerP0SellerP1(Object p0, Object p1) => 'Buyer: ${p0} | Seller: ${p1}';

  @override
  String filedByP0(Object p0) => 'Filed by: ${p0}';

  @override
  String get handle => 'Handle';

  @override
  String get transactions2 => 'Transactions';

  @override
  String get orders => 'Orders';

  @override
  String get lookUpOrdersAdjustStatusBy => 'Look up orders and adjust status by hand';

  @override
  String get disputeListDecisions => 'Dispute list and decisions';

  @override
  String get listings => 'Listings';

  @override
  String get allBooksForceDelisting => 'All books, force delisting';

  @override
  String get moderation => 'Moderation';

  @override
  String get handleListingReports => 'Handle listing reports';

  @override
  String get addReorderDeleteBookCategories => 'Add, reorder and delete book categories';

  @override
  String get members => 'Members';

  @override
  String get memberControls => 'Member controls';

  @override
  String get memberListSuspensionBlocklist => 'Member list, suspension and blocklist';

  @override
  String get membershipTiers => 'Membership tiers';

  @override
  String get tierThresholdsBenefits => 'Tier thresholds and benefits';

  @override
  String get wallets => 'Wallets';

  @override
  String get checkBalancesAddDeductCoinsBy => 'Check balances, add or deduct coins by hand';

  @override
  String get hardwareOperations => 'Hardware and operations';

  @override
  String get lockerSlotStatus => 'Locker and slot status';

  @override
  String get maintenanceLog => 'Maintenance log';

  @override
  String get lockerOperationHistory => 'Locker operation history';

  @override
  String get reports => 'Reports';

  @override
  String get ordersRevenueMemberGrowth => 'Orders, revenue and member growth';

  @override
  String get announcements2 => 'Announcements';

  @override
  String get supportEnquiries => 'Support enquiries';

  @override
  String get replyQuestionsFromUsers => 'Reply to questions from users';

  @override
  String get faqShownHelpCentre => 'FAQ shown in the help centre';

  @override
  String get termsPrivacyPolicyAbout => 'Terms, privacy policy and about';

  @override
  String get adminAuditLog => 'Admin audit log';

  @override
  String get auditTrailAdminChanges => 'Audit trail of admin changes';

  @override
  String get systemOperations => 'System operations';

  @override
  String get dailyBackupsManualRunsDownloads => 'Daily backups, manual runs and downloads';

  @override
  String get deletionRequestsInsideGracePeriodCancel => 'Deletion requests inside the grace period; cancel or run them now';

  @override
  String get members2 => 'Members';

  @override
  String get todaySOrders => 'Today\'s orders';

  @override
  String get openCases => 'Open cases';

  @override
  String get activeLockers => 'Active lockers';

  @override
  String get newTier => 'New tier';

  @override
  String get editTier => 'Edit tier';

  @override
  String get tierName => 'Tier name';

  @override
  String get minimumPoints => 'Minimum points';

  @override
  String get maximumPointsLeaveEmptyNoCap => 'Maximum points (leave empty for no cap)';

  @override
  String get benefitsSeparatedByCommasLineBreaks => 'Benefits, separated by commas or line breaks; each is listed on the membership page';

  @override
  String get enterTierName => 'Enter a tier name';

  @override
  String get maximumPointsMustExceedMinimum => 'Maximum points must exceed the minimum';

  @override
  String get tierAdded => 'Tier added';

  @override
  String get tierUpdated => 'Tier updated';

  @override
  String get deleteTier => 'Delete tier';

  @override
  String deleteP0MembersTierDropNext(Object p0) => 'Delete "${p0}"? Members on this tier drop to the next tier they qualify for.';

  @override
  String get tierDeleted => 'Tier deleted';

  @override
  String get noMembershipTiersSetUp => 'No membership tiers set up';

  @override
  String p0PointsUp(Object p0) => '${p0} points and up';

  @override
  String p0P1Points(Object p0, Object p1) => '${p0} - ${p1} points';

  @override
  String get noBenefitsDescribedYet => 'No benefits described yet';

  @override
  String get noMaintenanceRecords => 'No maintenance records';

  @override
  String get noFurtherDetail => '(no further detail)';

  @override
  String get operator => 'Operator';

  @override
  String get unknown => '(unknown)';

  @override
  String get time => 'Time';

  @override
  String get recordNumber => 'Record number';

  @override
  String operatorP0(Object p0) => 'Operator: ${p0}';

  @override
  String get suspendAccount => 'Suspend this account';

  @override
  String get reinstateAccount => 'Reinstate this account';

  @override
  String get addBlocklist => 'Add to blocklist';

  @override
  String get removeFromBlocklist => 'Remove from blocklist';

  @override
  String p0SignedOutImmediatelyCanNo(Object p0) => '${p0} is signed out immediately and can no longer use any part of the app.';

  @override
  String p0AbleSignAgain(Object p0) => '${p0} will be able to sign in again.';

  @override
  String get accountStatusUpdated => 'Account status updated';

  @override
  String get removeAdmin => 'Remove admin';

  @override
  String get makeAdmin => 'Make admin';

  @override
  String p0LosesEveryAdminPermissionImmediately(Object p0) => '${p0} loses every admin permission immediately.';

  @override
  String p0GainsAccessAdminAreaWith(Object p0) => '${p0} gains access to the admin area with all permissions by default; you can adjust them one by one afterwards.';

  @override
  String get roleUpdated => 'Role updated';

  @override
  String manualP0P1(Object p0, Object p1) => ', manual ${p0}${p1}';

  @override
  String get adjustMembershipTier => 'Adjust membership tier';

  @override
  String currentlyP0PointsAutomaticP1P2(Object p0, Object p1, Object p2) => 'Currently ${p0} points (automatic ${p1}${p2})';

  @override
  String p0P1Points2(Object p0, Object p1) => '${p0} (${p1} points)';

  @override
  String get adjustPointsManually => 'Adjust points manually';

  @override
  String get backAutomatic => 'Back to automatic';

  @override
  String get backAutomatic2 => 'Back on automatic';

  @override
  String get pointAdjustment => 'Point adjustment';

  @override
  String get positiveAddsNegativeDeductsEG => 'Positive adds, negative deducts, e.g. -50';

  @override
  String get apply => 'Apply';

  @override
  String get enterNonZeroWholeNumber => 'Enter a non-zero whole number';

  @override
  String get pointsAdjusted => 'Points adjusted';

  @override
  String get tierAdjusted => 'Tier adjusted';

  @override
  String get permissionGranted => 'Permission granted';

  @override
  String get permissionRevoked => 'Permission revoked';

  @override
  String get grantAllPermissions => 'Grant all permissions';

  @override
  String get revokeAllPermissions => 'Revoke all permissions';

  @override
  String p0AbleUseEveryAdminFeature(Object p0) => '${p0} will be able to use every admin feature.';

  @override
  String p0ReachAdminAreaButUnable(Object p0) => '${p0} will reach the admin area but be unable to use anything in it.';

  @override
  String get allPermissionsGranted => 'All permissions granted';

  @override
  String get allPermissionsRevoked => 'All permissions revoked';

  @override
  String get memberSettings => 'Member settings';

  @override
  String get noDataMember => 'No data for this member';

  @override
  String get listings2 => 'Listings';

  @override
  String get completedTrades => 'Completed trades';

  @override
  String get joined => 'Joined';

  @override
  String get accountStatus => 'Account status';

  @override
  String get ownAccountStatusPermissionsCannotChanged => 'This is your own account; status and permissions cannot be changed here.';

  @override
  String get accountEnabled => 'Account enabled';

  @override
  String get canSignUseAppNormally => 'Can sign in and use the app normally';

  @override
  String get suspendedSignedOutImmediatelyAfterSigning => 'Suspended; signed out immediately after signing in';

  @override
  String get blocked => 'Blocked';

  @override
  String get blockedNoFeaturesAvailable => 'Blocked; no features are available';

  @override
  String get notBlocked => 'Not blocked';

  @override
  String get role => 'Role';

  @override
  String p0PointsAutomaticP1P2(Object p0, Object p1, Object p2) => '${p0} points (automatic ${p1}${p2})';

  @override
  String get memberSTierBeenAdjustedBy => 'This member\'s tier has been adjusted by hand and no longer follows trades alone.';

  @override
  String get adjustTier => 'Adjust tier';

  @override
  String get adminPermissions => 'Admin permissions';

  @override
  String get all => 'All on';

  @override
  String get allOff => 'All off';

  @override
  String get reinstateAccount2 => 'Reinstate account';

  @override
  String get suspendAccount2 => 'Suspend account';

  @override
  String runP1P0(Object p0, Object p1) => 'Run "${p0}" on "${p1}"?';

  @override
  String updatedP0SStatus(Object p0) => 'Updated ${p0}\'s status';

  @override
  String get fullSettingsTierPermissions => 'Full settings (tier, permissions)';

  @override
  String get members3 => 'Members';

  @override
  String get searchDisplayNameEmail => 'Search display name or email';

  @override
  String get noMembersMatch => 'No members match';

  @override
  String get sales2 => 'Sales';

  @override
  String get created => 'Created';

  @override
  String get noActivityYet => 'No activity yet';

  @override
  String get changeOrderStatus => 'Change order status';

  @override
  String orderP0(Object p0) => 'Order ${p0}';

  @override
  String get reasonChange => 'Reason for the change';

  @override
  String get sentBuyerAsWellOptional => 'Sent to the buyer as well (optional)';

  @override
  String get applyChange => 'Apply change';

  @override
  String get orderStatusUpdated => 'Order status updated';

  @override
  String get searchOrderNumberBuyerSeller => 'Search order number, buyer or seller';

  @override
  String get noOrdersMatch => 'No orders match';

  @override
  String get noItems => '(no items)';

  @override
  String p0ItemsTotal(Object p0) => 'and ${p0} items in total';

  @override
  String buyerP0SellerP12(Object p0, Object p1) => 'Buyer ${p0} | Seller ${p1}';

  @override
  String lockerP0(Object p0) => 'Locker: ${p0}';

  @override
  String cancellationReasonP0(Object p0) => 'Cancellation reason: ${p0}';

  @override
  String get reviewReport => 'Review report';

  @override
  String reportedP0P1(Object p0, Object p1) => 'Reported ${p0}: ${p1}';

  @override
  String reasonP02(Object p0) => 'Reason: ${p0}';

  @override
  String get handlingNoteOptional => 'Handling note (optional)';

  @override
  String get delistListingAsWell => 'Delist the listing as well';

  @override
  String get dismissReport => 'Dismiss report';

  @override
  String get reportHandled => 'Report handled';

  @override
  String get noReportsKind => 'No reports of this kind';

  @override
  String reportedByP0(Object p0) => 'Reported by: ${p0}';

  @override
  String get review => 'Review';

  @override
  String noteP0(Object p0) => 'Note: ${p0}';

  @override
  String get last7Days => 'Last 7 days';

  @override
  String get last30Days => 'Last 30 days';

  @override
  String get ordersPerDay => 'Orders per day';

  @override
  String get revenuePerDay => 'Revenue per day';

  @override
  String get newMembersPerDay => 'New members per day';

  @override
  String get newOrders => 'New orders';

  @override
  String get newMembers => 'New members';

  @override
  String get newListings => 'New listings';

  @override
  String get completedRevenue => 'Completed revenue';

  @override
  String p0Orders(Object p0) => '${p0} orders';

  @override
  String peakP0(Object p0) => 'Peak ${p0}';

  @override
  String get topCategoriesByListings => 'Top categories by listings';

  @override
  String get replied => 'Replied';

  @override
  String get noEnquiriesCategory => 'No enquiries in this category';

  @override
  String get addCoins => 'Add coins';

  @override
  String get deductCoins => 'Deduct coins';

  @override
  String get amountPositiveWholeNumber => 'Amount (positive whole number)';

  @override
  String get reasonAdjustmentRequired => 'Reason for the adjustment (required)';

  @override
  String get add2 => 'Add';

  @override
  String get deduct => 'Deduct';

  @override
  String get enterAmountGreaterThan0 => 'Enter an amount greater than 0';

  @override
  String get enterReasonAdjustment => 'Enter a reason for the adjustment';

  @override
  String get member2 => 'this member';

  @override
  String get add3 => 'add';

  @override
  String get deduct2 => 'deduct';

  @override
  String get confirmAddingCoins => 'Confirm adding coins';

  @override
  String get confirmDeductingCoins => 'Confirm deducting coins';

  @override
  String p1P2CoinsP0NreasonP3(Object p0, Object p1, Object p2, Object p3) => 'This will ${p0} ${p1} coins for ${p2}.\nReason: ${p3}';

  @override
  String get balanceAdjusted => 'Balance adjusted';

  @override
  String get memberWallets => 'Member wallets';

  @override
  String get transactions3 => 'Transactions';

  @override
  String get memberNoTransactionsYet => 'This member has no transactions yet.';

  @override
  String get balanceCoins => 'Balance (coins)';

  @override
  String get hold2 => 'On hold';

  @override
  String get total2 => 'Total in';

  @override
  String get totalOut => 'Total out';

  @override
  String balanceP0(Object p0) => 'Balance ${p0}';

  @override
  String get suspensionBlocklistRoles => 'Suspension, blocklist, roles';

  @override
  String get tierThresholdsManualAdjustments => 'Tier thresholds and manual adjustments';

  @override
  String get booksCategories => 'Books and categories';

  @override
  String get reportReview => 'Report review';

  @override
  String get handleListingReports2 => 'Handle listing reports';

  @override
  String get lookUpChangeOrderStatus => 'Look up and change order status';

  @override
  String get decideDisputeCases => 'Decide dispute cases';

  @override
  String get checkAdjustCoinBalances => 'Check and adjust coin balances';

  @override
  String get hardware => 'Hardware';

  @override
  String get lockersSlots => 'Lockers and slots';

  @override
  String get announcementsDocuments => 'Announcements and documents';

  @override
  String get announcementsFaqLegalDocuments => 'Announcements, FAQ, legal documents';

  @override
  String get replyUserQuestions => 'Reply to user questions';

  @override
  String get databaseBackupDownloadOffByDefault => 'Database backup and download; off by default';

  @override
  String p0Locker(Object p0) => '${p0} locker';

  @override
  String everyActiveMemberReceivesP0Updated(Object p0) => 'Every active member receives a "${p0} updated" notification.';

  @override
  String get orderPlaced => 'Order placed';

  @override
  String get paid => 'Paid';

  @override
  String get sellerDroppedOff => 'Seller dropped off';

  @override
  String get buyerCollected => 'Buyer collected';

  @override
  String get completed => 'Completed';

  @override
  String get editBookDetails => 'Edit book details';

  @override
  String sellerP0TheyNotifiedSave(Object p0) => 'Seller ${p0} — they are notified on save';

  @override
  String get priceCoins => 'Price (coins)';

  @override
  String get k1013Digits2 => '10 or 13 digits';

  @override
  String get category => 'Category';

  @override
  String get description2 => 'Description';

  @override
  String get titleRequired => 'A title is required';

  @override
  String get nothingChanged => 'Nothing changed';

  @override
  String get resetPassword => 'Reset password';

  @override
  String p0SCurrentPasswordStopsWorking(Object p0) => '${p0}\'s current password stops working immediately; they must sign in with the temporary password generated next.\n\nThe password is generated by the system — you cannot choose it.';

  @override
  String get generateTemporaryPassword => 'Generate a temporary password';

  @override
  String get temporaryPassword => 'Temporary password';

  @override
  String p0SPasswordBeenResetPassword(Object p0) => '${p0}\'s password has been reset. This password is shown once only — it cannot be viewed again after closing.';

  @override
  String get remindThemChangeSettingsChangePassword => 'Remind them to change it at Settings → Change password right after signing in.';

  @override
  String get temporaryPasswordCopied => 'Temporary password copied';

  @override
  String get copy => 'Copy';

  @override
  String get cannotResetAnotherAdminSPassword => 'You cannot reset another admin\'s password';

  @override
  String get generateTemporaryPasswordHandOver => 'Generate a temporary password to hand over';

  @override
  String get orderNumberCopied => 'Order number copied';

  @override
  String get orderNotFound => 'Order not found';

  @override
  String get paidWithCoins => 'Paid with coins';

  @override
  String get bankTransfer => 'Bank transfer';

  @override
  String get notPaidYet => 'Not paid yet';

  @override
  String get progress => 'Progress';

  @override
  String get notYet => 'Not yet';

  @override
  String get buyerSeller => 'Buyer and seller';

  @override
  String get items3 => 'Items';

  @override
  String get bookDeleted => '(book deleted)';

  @override
  String get notAssignedYet2 => 'Not assigned yet';

  @override
  String get pickupCodeCopied => 'Pickup code copied';

  @override
  String get walletActivity => 'Wallet activity';

  @override
  String balanceP02(Object p0) => 'Balance ${p0}';

  @override
  String get refunds => 'Refunds';

  @override
  String requestedP0NotProcessedYet(Object p0) => 'Requested ${p0}, not processed yet';

  @override
  String processedP0(Object p0) => 'Processed ${p0}';

  @override
  String get disputes => 'Disputes';

  @override
  String filedP0(Object p0) => 'Filed ${p0}';

  @override
  String decidedP0(Object p0) => 'Decided ${p0}';

  @override
  String createdP0(Object p0) => 'Created ${p0}';

  @override
  String get shareBook => 'Share this book';

  @override
  String get shareAnotherApp => 'Share to another app';

  @override
  String get approved => 'Approved';

  @override
  String get awaitingRefund => 'Awaiting refund';

  @override
  String get declined => 'Declined';

  @override
  String get changeOwnPasswordGoSettingsChange => 'To change your own password, go to Settings → Change password';

  @override
  String get memberNotAdminSoThereNo => 'This member is not an admin, so there are no admin permissions to set. Change their role above first.';

  @override
  String get you => 'You';

  @override
  String isbnMust1013DigitsOne(Object p0) => 'ISBN must be 10 or 13 digits; this one has ${p0}';

  @override
  String get screenUnsavedChangesTheyLostIf => 'This screen has unsaved changes. They are lost if you leave.';

  @override
  String stillNeededP0(Object p0) => 'Still needed: ${p0}';

  @override
  String photosP0(Object p0) => 'Photos: ${p0}';

  @override
  String get confirmListing => 'Confirm listing';

  @override
  String get lookingUpBook => 'Looking up the book';

  @override
  String get scan => 'Scan';

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

  @override
  String get verifySignSavemybook => 'SaveMyBook にログインするため認証します';

  @override
  String get maintenance => 'メンテナンス';

  @override
  String get promotions => 'キャンペーン';

  @override
  String get policyUpdate => 'ポリシー更新';

  @override
  String get announcement => 'お知らせ';

  @override
  String get item => '商品';

  @override
  String get member => '会員';

  @override
  String get message => 'メッセージ';

  @override
  String get noLongerExists => '(対象は存在しません)';

  @override
  String get uncategorised => '未分類';

  @override
  String get general => '一般書籍';

  @override
  String get untitled => 'タイトルなし';

  @override
  String get noDescriptionYet => '紹介文はまだありません';

  @override
  String get locationNotProvided => '場所の記載なし';

  @override
  String seller3(Object p0) => '出品者：${p0}';

  @override
  String get unknownAuthor => '著者不明';

  @override
  String get unknownPublisher => '出版社不明';

  @override
  String get noIsbn => 'ISBN なし';

  @override
  String get user => 'ユーザー';

  @override
  String get noMessagesYet => 'メッセージはまだありません';

  @override
  String get photo => '[画像]';

  @override
  String item2(Object p0) => '[商品] ${p0}';

  @override
  String get purchase => '購入';

  @override
  String get sale => '売却';

  @override
  String get systemAdjustment => 'システム調整';

  @override
  String get preparingData => 'データを準備しています';

  @override
  String get mySavemybookData => 'SaveMyBook のマイデータ';

  @override
  String get exportedChooseWhereSave => 'エクスポートしました。保存先を選んでください。';

  @override
  String get exportedButSharingCouldNotOpen => 'エクスポートしましたが、共有を開けませんでした';

  @override
  String get regenerateShareLink => '共有リンクを再生成';

  @override
  String get oldLinkQrCodeStopWorking => '古いリンクと QR コードはすぐに無効になり、すでに共有した相手は開けなくなります。再生成しますか？';

  @override
  String get regenerate => '再生成';

  @override
  String get newLinkCreatedOldOneNo => '新しいリンクを作成しました。古いリンクは無効です。';

  @override
  String get deleteAccount => 'アカウントを削除';

  @override
  String get accountPermanentlyDisabled30DaysSign => 'アカウントは 30 日後に完全に無効化されます。それまでに再度ログインすればキャンセルできます。\n\n';

  @override
  String get personalDataErasedButCompletedOrders => '無効化後は個人情報が削除されますが、完了した注文と取引履歴は保持されます。';

  @override
  String get peopleTradedWithDoNotLose => '取引相手の記録が欠けないようにするためです。';

  @override
  String get actionContinue => '続ける';

  @override
  String get verify => '本人確認';

  @override
  String get enterPasswordConfirm => 'ご本人の操作であることを確認するため、パスワードを入力してください。';

  @override
  String get password => 'パスワード';

  @override
  String get requestDeletion => '削除を申請';

  @override
  String get receivedSignAgainWithin30Days => '受け付けました。30 日以内に再ログインすればキャンセルできます。';

  @override
  String get deletionCancelledAccountActiveAgain => '削除をキャンセルしました。アカウントは通常どおり使えます。';

  @override
  String get account => 'アカウント設定';

  @override
  String get data => 'あなたのデータ';

  @override
  String get exportMyData => 'データをエクスポート';

  @override
  String get profileBooksOrdersTransactionsJson => 'プロフィール・書籍・注文・取引履歴を JSON 形式で';

  @override
  String get oldLinkQrCodeStopWorking2 => '古いリンクと QR コードはすぐに無効になります';

  @override
  String get cancelAccountDeletion => 'アカウント削除をキャンセル';

  @override
  String get restoreAccountStopCountdown => 'アカウントを復元し、カウントダウンを止めます';

  @override
  String get canChangeMindWithin30Days => '30 日以内なら取り消せます';

  @override
  String get deletionPending => '削除カウントダウン中';

  @override
  String daysLeftCanCancelAnyTime(Object p0) => '残り ${p0} 日です。それまではいつでもキャンセルできますが、期限を過ぎると個人情報は完全に削除されます。';

  @override
  String get signOut => 'ログアウト';

  @override
  String get type => '種類';

  @override
  String get content => '本文';

  @override
  String get backupFailed => 'バックアップに失敗しました';

  @override
  String get myBooks => '書籍管理';

  @override
  String get notProvided => '未設定';

  @override
  String get openingHours => '開放時間';

  @override
  String get address => '住所';

  @override
  String get saveChanges => '変更を保存';

  @override
  String get enable => '有効化';

  @override
  String get termsService => '利用規約';

  @override
  String get privacyPolicy => 'プライバシーポリシー';

  @override
  String get aboutUs => '運営者について';

  @override
  String get admin => '管理画面';

  @override
  String get confirm => '確認';

  @override
  String get membershipTier => '会員ランク';

  @override
  String get phone => '電話番号';

  @override
  String get violationConfirmed => '違反が認定されました';

  @override
  String get scanBarcode => 'バーコードをスキャン';

  @override
  String get lineUpBarcodeSpineWithFrame => '背表紙のバーコードを枠に合わせてください';

  @override
  String get signAddItemsCart => 'カートに追加するにはログインしてください';

  @override
  String bookCannotPurchased(Object p0) => 'この本は${p0}のため購入できません';

  @override
  String get addedCart => 'カートに追加しました';

  @override
  String get sellerInformationNotFound => '出品者情報が見つかりません';

  @override
  String get signContactSeller => '出品者に連絡するにはログインしてください';

  @override
  String get signStartChat => 'チャットを開始するにはログインしてください';

  @override
  String get signReport => '報告するにはログインしてください';

  @override
  String get cannotReportOwnListing => '自分の出品は報告できません';

  @override
  String get reportListing => 'この商品を報告';

  @override
  String get describeProblemLeast5Characters => '問題の内容を記入してください（5 文字以上）';

  @override
  String get reasonNeedsLeast5Characters => '報告理由は 5 文字以上で入力してください';

  @override
  String get reportSubmittedWeLookInto => '報告を送信しました。順次対応します。';

  @override
  String get publisher => '出版社：';

  @override
  String get author => '著者：';

  @override
  String get listed => '出品日：';

  @override
  String get searchTitleAuthorPublisher => 'タイトル・著者・出版社で検索…';

  @override
  String get share => '共有';

  @override
  String get report => '報告';

  @override
  String get about => '紹介：';

  @override
  String pickup(Object p0) => '受け取り場所：${p0}';

  @override
  String get messageSeller => '出品者に相談';

  @override
  String get listing => 'あなたの出品です';

  @override
  String get addCart => 'カートに追加';

  @override
  String get bookBeenReportedUnderReviewStays => 'この本は報告を受け審査中です。審査中も販売は継続されます。';

  @override
  String get violationWasConfirmedBookPleaseCheck => 'この本は違反が認定されました。コミュニティガイドラインに沿っているかご確認ください。';

  @override
  String get reportDismissed2 => '報告は却下されました';

  @override
  String get bookWasReportedButNoViolation => 'この本は報告されましたが違反は認められませんでした。出品に影響はありません。';

  @override
  String get delist => '出品を取り消す';

  @override
  String removedFromShopBuyersNoLonger(Object p0) => '「${p0}」はショップから外され、購入者には表示されなくなります。';

  @override
  String get delist2 => '出品停止';

  @override
  String get delistedRelistFromDelistedTab => '出品を停止しました。「出品停止」タブから再出品できます。';

  @override
  String get couldNotDelistPleaseTryAgain => '出品停止に失敗しました。しばらくしてからお試しください。';

  @override
  String listedAgain(Object p0) => '「${p0}」を再出品しました';

  @override
  String get notListedAnyBooksYet => 'まだ book を出品していません';

  @override
  String get noBooksCategory => 'このカテゴリーに書籍はありません';

  @override
  String get listFirstBook => '最初の 1 冊を出品する';

  @override
  String get relist => '再出品';

  @override
  String get removeFromCart => 'カートから削除';

  @override
  String removeFromCart2(Object p0) => '「${p0}」をカートから削除しますか？';

  @override
  String get remove => '削除';

  @override
  String get couldNotRemoveRestored => '削除できませんでした。元に戻しました。';

  @override
  String get couldNotRemovePleaseTryAgain => '削除に失敗しました。しばらくしてからお試しください。';

  @override
  String get selectBooksWantCheckOut => 'お会計する本を選んでください';

  @override
  String notEnoughCoinsOrderNeedsBut(Object p0, Object p1) => 'コインが足りません。この注文には ${p0} 必要ですが、残高は ${p1} です。';

  @override
  String get confirmCheckout => 'お会計を確定';

  @override
  String booksTotal(Object p0, Object p1) => '${p0} 冊、合計 ${p1}。\n';

  @override
  String balanceAfterPaymentCoins(Object p0) => 'お支払い後の残高は ${p0} コインになります。';

  @override
  String get orderPlacedSellerDropBookOff => 'ご注文が完了しました。出品者の預け入れをお待ちください。';

  @override
  String get cart => 'カート';

  @override
  String get cartEmpty => 'カートは空です';

  @override
  String get selectAll => 'すべて選択';

  @override
  String items(Object p0) => '${p0} 点';

  @override
  String get deselect => '選択を解除';

  @override
  String get select => '選択';

  @override
  String coinsShort(Object p0) => 'あと ${p0} コイン不足';

  @override
  String get total => '合計';

  @override
  String selected(Object p0) => '${p0} 点';

  @override
  String balance2(Object p0) => '残高 ${p0}';

  @override
  String get selectBookFirst => '本を選んでください';

  @override
  String get checkOut => 'お会計';

  @override
  String get notEnoughCoins => 'コインが足りません';

  @override
  String get weak => '弱い';

  @override
  String get fair => '普通';

  @override
  String get strong => '強い';

  @override
  String get enterCurrentPassword => '現在のパスワードを入力してください';

  @override
  String get enterNewPassword => '新しいパスワードを入力してください';

  @override
  String get newPasswordMustDifferent => '新しいパスワードは現在のものと同じにできません';

  @override
  String get enterNewPasswordAgain => '新しいパスワードをもう一度入力してください';

  @override
  String get passwordsDoNotMatch => '入力された新しいパスワードが一致しません';

  @override
  String get passwordUpdated => 'パスワードを更新しました';

  @override
  String get changePassword => 'パスワード変更';

  @override
  String get useLeast8CharactersWithBoth => '8 文字以上で、英字と数字の両方を含めてください。';

  @override
  String get currentPassword => '現在のパスワード';

  @override
  String get newPassword => '新しいパスワード';

  @override
  String get confirmNewPassword => '新しいパスワード（確認）';

  @override
  String get updatePassword => 'パスワードを更新';

  @override
  String get deleteChat => 'チャットを削除';

  @override
  String allMessagesWithDeletedBothCannot(Object p0) => '${p0} とのメッセージがすべて削除され、双方とも見られなくなります。元に戻せません。';

  @override
  String get chatDeleted => 'チャットを削除しました';

  @override
  String get couldNotDeleteRestored => '削除できませんでした。元に戻しました。';

  @override
  String get chatMuted => 'このチャットをミュートしました';

  @override
  String get chatUnmuted => 'ミュートを解除しました';

  @override
  String get noUnreadMessages => '未読メッセージはありません';

  @override
  String get markAllAsRead => 'すべて既読にする';

  @override
  String markAllUnreadMessagesAsRead(Object p0) => '未読メッセージ ${p0} 件をすべて既読にしますか？元に戻せません。';

  @override
  String get markAllRead => 'すべて既読';

  @override
  String get allMarkedAsRead => 'すべて既読にしました';

  @override
  String get somethingWentWrongPleaseTryAgain => '処理に失敗しました。しばらくしてからお試しください。';

  @override
  String get chats => 'チャット';

  @override
  String get noConversationsYet => 'まだ会話がありません';

  @override
  String get unmute => 'ミュート解除';

  @override
  String get mute => 'ミュート';

  @override
  String get messagesLimited500Characters => 'メッセージは 500 文字までです';

  @override
  String get messageCouldNotSent => 'メッセージを送信できませんでした';

  @override
  String get chat => 'チャット';

  @override
  String get sendFirstMessage => '最初のメッセージを送ってみましょう';

  @override
  String get messageCopied => 'メッセージをコピーしました';

  @override
  String get iQuestionAboutBook => 'この本について質問があります';

  @override
  String get bookNoLongerListed => 'この本は出品停止されています';

  @override
  String get writeMessage => 'メッセージを入力…';

  @override
  String get enterOrderNumberDisputing => '異議を申し立てる注文番号を入力してください';

  @override
  String get describeDispute => '異議の内容を記入してください';

  @override
  String get useLeast10CharactersSoSupport => 'サポートが判断できるよう 10 文字以上で記入してください';

  @override
  String get submitDispute => '異議を申し立てる';

  @override
  String get orderEntersDisputeProcessPaymentSeller => '注文は異議申立の手続きに入り、サポートが判断するまで出品者への支払いは保留されます。';

  @override
  String paymentHoldRequested(Object p0) => '[支払い保留の申請] ${p0}';

  @override
  String get disputeSubmittedSupportContact => '異議を申し立てました。サポートからご連絡します。';

  @override
  String get dispute => '異議申立';

  @override
  String get requestPaymentHold => '支払い保留を申請';

  @override
  String get paymentSellerHeldUntilSupportDecides => 'サポートが判断するまで出品者への支払いは保留されます';

  @override
  String get submitDispute2 => '異議を申し立てる';

  @override
  String get orderNumber => '注文番号';

  @override
  String get eGSmb20260910123456789 => '例：SMB20260910123456789';

  @override
  String get whatHappened => '異議の内容';

  @override
  String get describeProblemEGConditionDoes => '発生した問題を記入してください。例：状態が説明と異なる…';

  @override
  String get submit => '申請を送信';

  @override
  String get uploadPhotos => '画像をアップロード';

  @override
  String get canAttachUp6Photos => '添付できる写真は 6 枚までです';

  @override
  String get up5 => '5 枚まで';

  @override
  String get couldNotReplacePhotoPleaseTry => '写真を差し替えられませんでした。しばらくしてからお試しください。';

  @override
  String get keepLeastOnePhoto => '写真は 1 枚以上必要です';

  @override
  String get photoDeleted => '写真を削除しました';

  @override
  String get couldNotDeletePhotoPleaseTry => '写真を削除できませんでした。しばらくしてからお試しください。';

  @override
  String get canUp10Photos => '写真は 10 枚までです';

  @override
  String get deletePhoto => '写真を削除';

  @override
  String get cannotUndoneContinue => '削除すると元に戻せません。よろしいですか？';

  @override
  String get photoMissingDataRefreshTryAgain => 'この写真のデータが不完全です。更新してからお試しください。';

  @override
  String get enterPrice => '価格を入力してください';

  @override
  String get priceMustGreaterThan0 => '価格は 0 より大きい必要があります';

  @override
  String get priceCannotExceed999999 => '価格は 999,999 以下にしてください';

  @override
  String get chooseLockerLocation => '保管場所を選んでください';

  @override
  String missingTheseThreeRequired(Object p0) => '不足しています：${p0}。この 3 枚は必須です。';

  @override
  String get bookUpdated => '書籍を更新しました';

  @override
  String get editBook => '書籍を編集';

  @override
  String get condition => '状態';

  @override
  String get customPrice => '価格を指定';

  @override
  String get enterPrice2 => '販売価格を入力';

  @override
  String get lockerLocation => '保管場所';

  @override
  String get chooseLocker => 'ロッカーを選択';

  @override
  String get bookPhotos => '書籍の写真';

  @override
  String get morePhotos => '追加の写真';

  @override
  String get add => '追加';

  @override
  String get enterTitle => 'タイトルを入力してください';

  @override
  String get titleLimited255Characters => 'タイトルは 255 文字までです';

  @override
  String get isbn1013Digits => 'ISBN は 10 桁または 13 桁です';

  @override
  String get chooseCategory => 'カテゴリーを選んでください';

  @override
  String get k1013Digits => '10 桁または 13 桁';

  @override
  String get title => 'タイトル';

  @override
  String get actionRequired => '必須';

  @override
  String get author2 => '著者';

  @override
  String get optional => '任意';

  @override
  String get publisher2 => '出版社';

  @override
  String get publicationDate => '発行日';

  @override
  String get tapPickPublicationDate => 'タップして発行日を選択';

  @override
  String get pickPublicationDate => '発行日を選択';

  @override
  String get pickCategory => 'カテゴリーを選択';

  @override
  String get next => '次へ';

  @override
  String get uploading => 'アップロード中…';

  @override
  String get profilePhotoUpdated => 'プロフィール写真を更新しました';

  @override
  String get couldNotUploadPhoto => 'プロフィール写真をアップロードできませんでした';

  @override
  String get changeDisplayName => '表示名を変更';

  @override
  String get enterDisplayName => '表示名を入力してください';

  @override
  String get displayNameCannotBlank => '表示名は空にできません';

  @override
  String get displayNames250Characters => '表示名は 2〜50 文字で入力してください';

  @override
  String get invalidPhoneNumberEG0912345678 => '電話番号の形式が正しくありません。例：0912345678';

  @override
  String get profileUpdated => 'プロフィールを更新しました';

  @override
  String get editProfile => 'プロフィールを編集';

  @override
  String get bio => '自己紹介';

  @override
  String get tellPeopleAboutYourself => '自己紹介を書いてみましょう';

  @override
  String get email => 'メールアドレス';

  @override
  String get emailCannotChanged => 'メールアドレスは変更できません';

  @override
  String get dateBirth => '生年月日';

  @override
  String get tapPickDateBirth => 'タップして生年月日を選択';

  @override
  String get pickDateBirth => '生年月日を選択';

  @override
  String get savedBooks => '保存した本';

  @override
  String get notSavedAnyBooksYet => 'まだ本を保存していません';

  @override
  String get helpCentre => 'ヘルプセンター';

  @override
  String get searchQuestions => '質問を検索';

  @override
  String get noQuestionsYet => 'よくある質問はまだありません';

  @override
  String get noMatchingQuestions => '該当する質問がありません';

  @override
  String get newest => '新着順';

  @override
  String get popular => '人気順';

  @override
  String get priceLowHigh => '価格の安い順';

  @override
  String get priceHighLow => '価格の高い順';

  @override
  String get reachedEnd => 'これ以上はありません';

  @override
  String get guest => 'ゲスト';

  @override
  String hi(Object p0) => 'こんにちは、${p0} さん';

  @override
  String get noBooksMatchFilters => '条件に合う書籍がありません';

  @override
  String get couldNotReadPhoto => 'この写真を読み込めませんでした';

  @override
  String get croppingFailedPleaseTryAgain => 'トリミングに失敗しました。もう一度お試しください。';

  @override
  String get adjustPhoto => '写真を調整';

  @override
  String get reset => 'リセット';

  @override
  String get usePhoto => 'この写真を使う';

  @override
  String get documentNotBeenCreatedYet => 'この文書はまだ作成されていません';

  @override
  String lastUpdated(Object p0) => '最終更新：${p0}';

  @override
  String get biometrics => '生体認証';

  @override
  String get sessionExpiredPleaseEnterPasswordAgain => 'ログイン情報の有効期限が切れました。パスワードを再入力してください。';

  @override
  String turnSign(Object p0) => '${p0} でのログインを有効にしますか？';

  @override
  String nextTimeOpenAppCanUnlock(Object p0) => '次回アプリを開くときは、パスワードの代わりに ${p0} で解除できます。';

  @override
  String get notNow => '後で';

  @override
  String get enterEmail => 'メールアドレスを入力してください';

  @override
  String get emailAddressNotValid => 'メールアドレスの形式が正しくありません';

  @override
  String get enterPassword => 'パスワードを入力してください';

  @override
  String get noAccountWithEmail => 'このアカウントは登録されていません';

  @override
  String noAccountCreateOneNow(Object p0) => '「${p0}」のアカウントが見つかりません。今すぐ作成しますか？';

  @override
  String get signUp => '新規登録へ';

  @override
  String get tryAgain => '入力し直す';

  @override
  String get sign => 'ログイン';

  @override
  String signWith(Object p0) => '${p0} でログイン';

  @override
  String get noAccountYetSignUp => 'アカウントをお持ちでないですか？新規登録';

  @override
  String get membershipTiersNotSetUpYet => '会員ランクはまだ設定されていません';

  @override
  String get currentTier => '現在のランク';

  @override
  String get unlocked => '解除済み';

  @override
  String get locked => '未解除';

  @override
  String get aboveTier => 'このランクは達成済みです';

  @override
  String get reachedTopTier => '最高ランクに到達しています';

  @override
  String unlocked2(Object p0) => '「${p0}」を達成しました';

  @override
  String morePointsUnlock(Object p0, Object p1) => 'あと ${p0} ポイントで「${p1}」を達成';

  @override
  String benefits(Object p0) => '${p0} の特典';

  @override
  String get noBenefitsBeenDescribedTierYet => 'このランクの特典はまだ設定されていません。';

  @override
  String pointsFromCompletedOrders(Object p0, Object p1) => '${p1} 件の取引で ${p0} ポイント';

  @override
  String get noNotificationsClear => '消去する通知はありません';

  @override
  String get clearAllNotifications => 'すべての通知を消去';

  @override
  String notificationsDeletedCannotUndone(Object p0) => '通知 ${p0} 件を削除します。元に戻せません。';

  @override
  String get clearAll => 'すべて消去';

  @override
  String get allNotificationsCleared => 'すべての通知を消去しました';

  @override
  String get couldNotClearPleaseTryAgain => '消去に失敗しました。しばらくしてからお試しください。';

  @override
  String get noUnreadNotifications => '未読の通知はありません';

  @override
  String markAllUnreadNotificationsAsRead(Object p0) => '未読の通知 ${p0} 件をすべて既読にしますか？元に戻せません。';

  @override
  String get openChat => 'チャットを開く';

  @override
  String get viewOrder => '注文を見る';

  @override
  String get openMyBooks => '書籍管理を開く';

  @override
  String get notifications => '通知';

  @override
  String get noNotifications => '通知はありません';

  @override
  String copied(Object p0) => '${p0} をコピーしました';

  @override
  String get orderDetails => '注文の詳細';

  @override
  String order(Object p0) => '注文番号 ${p0}';

  @override
  String get orderProgress => '注文の進捗';

  @override
  String items2(Object p0) => '商品明細（${p0}）';

  @override
  String get orderNoItemDetails => 'この注文には商品情報がありません。';

  @override
  String msg4(Object p0, Object p1) => '単価 ${p0} × ${p1}';

  @override
  String get orderTotal => '注文金額';

  @override
  String get pickupDetails => '受け取り情報';

  @override
  String get notAssigned => '未指定';

  @override
  String get slot => 'ロッカー番号';

  @override
  String get notAssignedYet => 'まだ割り当てられていません';

  @override
  String get pickupCode => '受け取りコード';

  @override
  String get transaction => '取引情報';

  @override
  String get buyer => '購入者';

  @override
  String get seller => '出品者';

  @override
  String get placed => '注文日時';

  @override
  String get dispute2 => '異議申立';

  @override
  String get orderOpenDispute => 'この注文には進行中の異議申立があります';

  @override
  String get cancelOrder => '注文をキャンセル';

  @override
  String get pendingPayoutDisappearsBuyerNotified => '保留中の収益は取り消され、購入者にも通知されます。';

  @override
  String get cancelledBySeller => '出品者によるキャンセル';

  @override
  String get orderCancelled2 => '注文をキャンセルしました';

  @override
  String get pendingPayouts => '保留中の収益';

  @override
  String get noPendingPayouts => '保留中の収益はありません';

  @override
  String get pendingAmount => '保留中の金額';

  @override
  String get coinsArriveOnceBuyerCollectsBook => '購入者が受け取ると自動的にコインが入金されます';

  @override
  String get scanned => 'スキャン完了';

  @override
  String get scanAgain => 'もう一度スキャン';

  @override
  String get collectBook => '本を受け取る';

  @override
  String get pointPickupQrCode => '受け取り用 QR コードに合わせてください';

  @override
  String get holdSteady => '手ぶれにご注意ください';

  @override
  String get bookCollected => '受け取り完了';

  @override
  String get thanksUsingSavemybookHappyReading => 'ご利用ありがとうございます。よい読書を！';

  @override
  String collected(Object p0) => '「${p0}」を受け取りました';

  @override
  String order2(Object p0) => '注文番号：${p0}';

  @override
  String get signingOut => 'ログアウト中…';

  @override
  String get myAccount => 'マイページ';

  @override
  String get personNotWrittenBioYet => 'まだ自己紹介がありません';

  @override
  String get topTierReached => '最高ランク達成';

  @override
  String morePointsReach(Object p0, Object p1) => 'あと ${p0} ポイントで「${p1}」へ';

  @override
  String get myCoins => 'マイコイン';

  @override
  String get shareProfile => 'プロフィールを共有';

  @override
  String get purchases => '購入履歴';

  @override
  String get sales => '販売履歴';

  @override
  String get settings => '設定';

  @override
  String get signOut2 => 'ログアウトしますか？';

  @override
  String get needSignAgainKeepUsingApp => '再度ご利用いただくにはログインが必要です。';

  @override
  String cancelOrderBookReturnsShop(Object p0) => '注文 ${p0} をキャンセルしますか？本は再びショップに並びます。';

  @override
  String get pickupCode2 => '受け取りコード';

  @override
  String get notGeneratedYet => 'まだ発行されていません';

  @override
  String get enterCodeLockerCollect => 'ロッカーでこのコードを入力して受け取ってください';

  @override
  String enterCodeCollect(Object p0) => '「${p0}」でこのコードを入力して受け取ってください';

  @override
  String get iCollected => '受け取りました';

  @override
  String get noOrdersTab => 'このタブに注文はありません';

  @override
  String get openDispute => '異議を申し立てる';

  @override
  String get displayNameNeedsLeast2Characters => '表示名は 2 文字以上必要です';

  @override
  String get displayNameLimited50Characters => '表示名は 50 文字までです';

  @override
  String get enterPasswordAgain => 'パスワードをもう一度入力してください';

  @override
  String get passwordsDoNotMatch2 => '入力されたパスワードが一致しません';

  @override
  String get pleaseReadAcceptTermsServicePrivacy => '利用規約とプライバシーポリシーをお読みのうえ同意してください';

  @override
  String get accountCreatedSignWith => 'アカウントを作成しました。ログインしてください。';

  @override
  String get iReadAccept => '同意します：';

  @override
  String get and => ' と ';

  @override
  String get createAccount => 'アカウントを作成';

  @override
  String get joinSavemybook => 'SaveMyBook に登録';

  @override
  String get signUpBuySellUseSmart => '登録すると本の売買とスマートロッカーが使えます';

  @override
  String get displayName => '表示名';

  @override
  String get nameOthersSee => '他の人に表示される名前';

  @override
  String get emailSignWith => 'ログインに使うメールアドレス';

  @override
  String get least8CharactersWithLettersNumbers => '8 文字以上、英字と数字を含む';

  @override
  String get confirmPassword => 'パスワード（確認）';

  @override
  String get enterPasswordAgain2 => 'パスワードをもう一度';

  @override
  String get alreadyAccountGoBackSign => 'すでにアカウントをお持ちですか？戻ってログイン';

  @override
  String get markAsDroppedOff => '預け入れ完了';

  @override
  String get droppedOff => '預け入れ済み';

  @override
  String get markedAsDroppedOff => '預け入れ完了にしました';

  @override
  String get buyerNotifiedBookReturnsShop => '購入者に通知され、本は再びショップに並びます。';

  @override
  String get dropOffPickupCode => '預け入れ・受け取りコード';

  @override
  String get enterCodeLocker => 'ロッカーでこのコードを入力してください';

  @override
  String get noRecentSearches => '検索履歴はありません';

  @override
  String get recentSearches => '最近の検索';

  @override
  String get clearAll2 => 'すべて消去';

  @override
  String get searchTitleAuthorIsbn => 'タイトル・著者・ISBN で検索…';

  @override
  String get photoLimitReached => '写真の上限です';

  @override
  String get canUploadUp10Photos => 'アップロードできる写真は 10 枚までです。';

  @override
  String get photosMissing => '写真が足りません';

  @override
  String missingTheseThreeRequired2(Object p0) => '不足しています：${p0}。この 3 枚は必須です。';

  @override
  String get missingInformation => '入力が不足しています';

  @override
  String get enterOwnPrice => '価格を入力してください。';

  @override
  String get invalidPrice => '価格が正しくありません';

  @override
  String get priceMustGreaterThan02 => '価格は 0 より大きくしてください。';

  @override
  String get priceCannotExceed99999 => '価格は 99,999 以下にしてください。';

  @override
  String get chooseLockerLocation2 => '保管場所を選んでください。';

  @override
  String get listed2 => '出品しました！';

  @override
  String get unknownError => '不明なエラー';

  @override
  String get couldNotListBook => '出品に失敗しました';

  @override
  String serverError(Object p0) => 'サーバーエラー：${p0}';

  @override
  String get connectionProblem => '接続エラー';

  @override
  String get couldNotReachServerUploadTimed => 'サーバーに接続できないか、アップロードがタイムアウトしました。通信状況をご確認ください。';

  @override
  String get listBook => '出品を確定';

  @override
  String get detailsPhotos => '詳細と写真';

  @override
  String get loading => '読み込み中...';

  @override
  String get unknownLocker => '不明なロッカー';

  @override
  String get enterTitle2 => 'タイトルを入力してください';

  @override
  String get chooseCategory2 => 'カテゴリーを選んでください';

  @override
  String get bookDetailsFilledAutomatically => '書籍情報を自動入力しました。';

  @override
  String get bookDetailsFilledFromBackupSource => '予備のデータベースから書籍情報を取得しました。';

  @override
  String get noSourceIsbnPleaseEnterDetails => 'どのデータベースにもこの ISBN が見つかりません。手動で入力してください。';

  @override
  String get day => '日';

  @override
  String get tapIconRightScan => '右のアイコンをタップしてスキャン';

  @override
  String get description => '書籍の紹介';

  @override
  String get sellBook => '本を売る';

  @override
  String get myShop => 'マイショップ';

  @override
  String get sellerNoBooksSale => 'この出品者に販売中の本はありません';

  @override
  String get loading2 => '読み込み中…';

  @override
  String sale2(Object p0) => '販売中 ${p0} 冊';

  @override
  String get verifyEnableQuickSign => 'クイックログインを有効にするため認証します';

  @override
  String sign2(Object p0) => '${p0} でのログインを有効にしました';

  @override
  String get quickSignTurnedOff => 'クイックログインをオフにしました';

  @override
  String get appearance2 => '表示設定';

  @override
  String get signMethod => 'ログイン方法';

  @override
  String get helpSupport => 'ヘルプとサポート';

  @override
  String get contactUs => 'お問い合わせ';

  @override
  String get aboutSavemybook => 'SaveMyBook について';

  @override
  String get settingsPrivacy => '設定とプライバシー';

  @override
  String sign3(Object p0) => '${p0} でログイン';

  @override
  String unlockWithWhenOpenApp(Object p0) => 'アプリを開くときに ${p0} で解除';

  @override
  String get scanProfileQrCode => 'プロフィール QR コードをスキャン';

  @override
  String get lineUpTheirQrCodeWith => '相手の QR コードを枠に合わせてください';

  @override
  String get notSavemybookProfileQrCode => 'これは SaveMyBook のプロフィール QR コードではありません';

  @override
  String get ownQrCode => 'これはご自身の QR コードです';

  @override
  String get couldNotStartChatPleaseTry => 'チャットを開始できませんでした。しばらくしてからお試しください。';

  @override
  String get linkCopied => 'リンクをコピーしました';

  @override
  String addMeSavemybook(Object p0) => 'SaveMyBook で私を追加：${p0}';

  @override
  String addMeSavemybook2(Object p0, Object p1) => 'SaveMyBook で私を追加（${p0}）：${p1}';

  @override
  String get sharingCouldNotOpenSoLink => '共有を開けなかったため、リンクをコピーしました';

  @override
  String get savedPhotos => '写真に保存しました';

  @override
  String get couldNotSaveCheckPhotoLibrary => '保存できませんでした。写真へのアクセス許可をご確認ください。';

  @override
  String get scanTheirQrCode => '相手の QR コードをスキャン';

  @override
  String get copyLink => 'リンクをコピー';

  @override
  String get askQuestion => '問い合わせる';

  @override
  String get noEnquiriesYet => 'お問い合わせ履歴はありません';

  @override
  String get enterSubject => '件名を入力してください';

  @override
  String get addMoreDetailSoSupportCan => 'サポートが判断できるようもう少し詳しくご記入ください';

  @override
  String get sentSupportReplySoon => '送信しました。サポートよりご返信します。';

  @override
  String get subject => '件名';

  @override
  String get sumUpOneLine => '一言で問題を教えてください';

  @override
  String get whatHappenedIncludeOrderNumberIf => '何が起きましたか？注文番号があればご記入ください。';

  @override
  String get close => 'クローズ';

  @override
  String get notAbleReplyAfterClosing => 'クローズすると返信できなくなります。';

  @override
  String get enquiryClosed => 'お問い合わせをクローズしました';

  @override
  String get changeStatus => 'ステータスを変更';

  @override
  String get statusUpdated => 'ステータスを更新しました';

  @override
  String get enquiry => 'お問い合わせ';

  @override
  String get enquiryNotFound => 'お問い合わせが見つかりません';

  @override
  String get support => 'サポート';

  @override
  String get writeReply => '返信を入力…';

  @override
  String get coins => 'コイン';

  @override
  String get transactions => '取引履歴';

  @override
  String get noTransactionsYet => '取引履歴はありません';

  @override
  String get balance => '現在の残高';

  @override
  String hold(Object p0) => '保留中 ${p0}';

  @override
  String requestFailed2(Object p0) => 'リクエストに失敗しました（${p0}）';

  @override
  String get couldNotReachServer => 'サーバーに接続できません';

  @override
  String get couldNotReachServerCheckConnection => 'サーバーに接続できません。通信状況をご確認ください。';

  @override
  String get signFailed => 'ログインに失敗しました';

  @override
  String get signFailedPleaseTryAgain => 'ログインに失敗しました。しばらくしてからお試しください。';

  @override
  String get signUpFailed => '登録に失敗しました';

  @override
  String get pleaseSignFirst => 'ログインしてください';

  @override
  String get couldNotRelist => '再出品に失敗しました';

  @override
  String get couldNotRemoveFromSaved => '保存を解除できませんでした';

  @override
  String get couldNotSave => '保存できませんでした';

  @override
  String get couldNotAddCart => 'カートに追加できませんでした';

  @override
  String get checkoutFailed => 'お会計に失敗しました';

  @override
  String get couldNotCancelOrder => '注文をキャンセルできませんでした';

  @override
  String get couldNotUpdateOrder => '注文状況を更新できませんでした';

  @override
  String get couldNotSubmitDispute => '異議を申し立てられませんでした';

  @override
  String get couldNotSubmitReport => '報告を送信できませんでした';

  @override
  String get updateFailed2 => '更新に失敗しました';

  @override
  String get couldNotChangePassword => 'パスワードを変更できませんでした';

  @override
  String get requestFailed => '申請に失敗しました';

  @override
  String get couldNotCancel => 'キャンセルできませんでした';

  @override
  String get couldNotDelete => '削除できませんでした';

  @override
  String get couldNotComplete => '実行できませんでした';

  @override
  String get couldNotSaveAnnouncement => 'お知らせを保存できませんでした';

  @override
  String get couldNotSend => '送信できませんでした';

  @override
  String get actionFailed => '処理に失敗しました';

  @override
  String get couldNotSave2 => '保存できませんでした';

  @override
  String get documentUpdated => '文書を更新しました';

  @override
  String get couldNotAdjust => '調整できませんでした';

  @override
  String get couldNotProcessReport => '報告を処理できませんでした';

  @override
  String get couldNotRecordDecision => '裁定を保存できませんでした';

  @override
  String get couldNotReorder => '並べ替えに失敗しました';

  @override
  String get couldNotSaveLocker => 'ロッカーを保存できませんでした';

  @override
  String get fingerprint => '指紋';

  @override
  String get iris => '虹彩';

  @override
  String get verifyIdentityContinue => '続けるには認証してください';

  @override
  String get couldNotOpenPhotosCheckPermission => '写真を開けませんでした。アクセス許可をご確認ください。';

  @override
  String get choosePhotoSource => '写真の取得方法を選択';

  @override
  String get takePhoto => '写真を撮る';

  @override
  String get chooseFromPhotos => '写真から選ぶ';

  @override
  String get couldNotOpenCameraCheckPermission => 'カメラを開けませんでした。アクセス許可をご確認ください。';

  @override
  String get justNow => 'たった今';

  @override
  String minAgo(Object p0) => '${p0} 分前';

  @override
  String hAgo(Object p0) => '${p0} 時間前';

  @override
  String dAgo(Object p0) => '${p0} 日前';

  @override
  String get pickDate => '日付を選択してください';

  @override
  String get pickDate2 => '日付を選択';

  @override
  String msg5(Object p0, Object p1, Object p2) => '${p0} 年 ${p1} 月 ${p2} 日';

  @override
  String get passwordsNeedLeast8Characters => 'パスワードは 8 文字以上必要です';

  @override
  String get passwordsMustIncludeLetter => 'パスワードに英字を含めてください';

  @override
  String get passwordsMustIncludeNumber => 'パスワードに数字を含めてください';

  @override
  String get seller2 => '出品者：';

  @override
  String get home => 'ホーム';

  @override
  String get alerts => '通知';

  @override
  String get collect => '受け取り';

  @override
  String get couldNotLoadPhoto => 'この写真を読み込めませんでした';

  @override
  String slot2(Object p0) => 'ロッカー番号：${p0}';

  @override
  String confirmPutLocker(Object p0) => '「${p0}」をロッカーに預け入れましたか？';

  @override
  String get enterTitleContent => 'タイトルと本文を入力してください';

  @override
  String get titleCannotExceed255Characters => 'タイトルは255文字までです';

  @override
  String get contentNeedsLeast5Characters => '本文は5文字以上必要です';

  @override
  String get publishAnnouncement => 'お知らせを公開';

  @override
  String get everyUserSeeAnnouncementOncePublished => '公開すると全ユーザーに表示されます。よろしいですか？';

  @override
  String get publish => '公開';

  @override
  String get announcementPublished => 'お知らせを公開しました';

  @override
  String get draftSaved => '下書きを保存しました';

  @override
  String get editAnnouncement => 'お知らせを編集';

  @override
  String get newAnnouncement => 'お知らせを作成';

  @override
  String get title2 => 'タイトル';

  @override
  String get announcementTitle => 'お知らせのタイトル';

  @override
  String get writeAnnouncement => 'お知らせの本文を入力';

  @override
  String get publishNow => 'すぐに公開';

  @override
  String get leaveOffSaveAsDraft => 'オフのままなら下書きとして保存';

  @override
  String get saveDraft => '下書きを保存';

  @override
  String get deleteAnnouncement => 'お知らせを削除';

  @override
  String deleteP0CannotUndone(Object p0) => '「${p0}」を削除しますか？元に戻せません。';

  @override
  String get announcementDeleted => 'お知らせを削除しました';

  @override
  String get couldNotDeleteTryAgainLater => '削除できませんでした。後でもう一度お試しください。';

  @override
  String get announcements => 'お知らせ';

  @override
  String get noAnnouncementsYetTapAddOne => 'お知らせはまだありません。右上の＋から追加できます。';

  @override
  String get published => '公開中';

  @override
  String get draft => '下書き';

  @override
  String get audienceEveryone => '対象：全ユーザー';

  @override
  String get backUpNow => '今すぐバックアップ';

  @override
  String get wholeDatabaseExportedCompressedWithLot => 'データベース全体を書き出して圧縮します。データ量が多いと数十秒かかることがあります。完了するまでこの画面を離れないでください。';

  @override
  String get startBackup => 'バックアップを開始';

  @override
  String get backingUpDatabase => 'データベースをバックアップ中';

  @override
  String get backupComplete => 'バックアップが完了しました';

  @override
  String get backupDeleted => 'バックアップを削除しました';

  @override
  String get databaseBackups => 'データベースのバックアップ';

  @override
  String backedUpDailyNewestP0Kept(Object p0) => '毎日自動バックアップ、最新${p0}';

  @override
  String get olderBackupsBeyondCountRemovedAutomatically => '保持件数を超えた古いバックアップは自動的に削除されます。バックアップにはサイト全体の個人情報が含まれるため、ダウンロードしたファイルは厳重に管理してください。ダウンロードはすべて操作ログに記録されます。';

  @override
  String get noBackupsYetSchedulerRunsOnce => 'バックアップはまだありません。スケジュールが1日1回実行されます。上のボタンですぐに作成することもできます。';

  @override
  String get deleteBackup => 'バックアップを削除';

  @override
  String p0NNtheFileItsRecord(Object p0) => '${p0}\n\nファイルと記録の両方が削除されます。元に戻せません。';

  @override
  String get manual => '手動';

  @override
  String get scheduled => 'スケジュール';

  @override
  String get download => 'ダウンロード';

  @override
  String get downloadBackup => 'バックアップをダウンロード';

  @override
  String fetchBackupComputerWithAuthorisationHeader(Object p0, Object p1) => 'バックアップはパソコンで、認証ヘッダーを付けて取得してください：\n\n${p0}\n\nファイルサイズ ${p1}。';

  @override
  String get copyLink2 => 'URLをコピー';

  @override
  String get downloadLinkCopied => 'ダウンロードURLをコピーしました';

  @override
  String get forceDelist => '強制的に出品停止';

  @override
  String get reasonDelistingSellerNotified => '出品停止の理由（出品者に通知されます）';

  @override
  String get delist3 => '出品停止する';

  @override
  String get relist2 => '再出品';

  @override
  String putP0BackStore(Object p0) => '『${p0}』をストアに戻しますか？';

  @override
  String get relisted => '再出品しました';

  @override
  String get searchTitleIsbnSeller => 'タイトル・ISBN・出品者で検索';

  @override
  String get noBooksMatch => '該当する本が見つかりません';

  @override
  String sellerP0P1(Object p0, Object p1) => '出品者 ${p0}｜${p1}';

  @override
  String isbnP0P1Views(Object p0, Object p1) => 'ISBN ${p0}｜閲覧 ${p1}';

  @override
  String p0ReportsAwaitingReview(Object p0) => '未処理の報告が${p0}';

  @override
  String get enterLockerNameAddress => 'ロッカー名と住所を入力してください';

  @override
  String get enterValidLatitudeLongitude => '正しい緯度・経度を入力してください';

  @override
  String get latitudeMustBetween9090 => '緯度は -90〜90 の範囲です';

  @override
  String get longitudeMustBetween180180 => '経度は -180〜180 の範囲です';

  @override
  String get slotCountMustBetween1100 => '棚の数は 1〜100 の範囲です';

  @override
  String get closingTime => '閉鎖時刻';

  @override
  String p0MustLookLikeHhMm(Object p0) => '${p0} HH:mm 形式で入力してください（例：09:00）';

  @override
  String get fillBothOpeningClosingTimes => '開放時刻と閉鎖時刻は両方入力してください';

  @override
  String get lockerUpdated => 'ロッカーを更新しました';

  @override
  String get lockerAdded => 'ロッカーを追加しました';

  @override
  String get editLocker => 'ロッカーを編集';

  @override
  String get newLocker => 'ロッカーを追加';

  @override
  String get lockerName => 'ロッカー名';

  @override
  String get latitude => '緯度';

  @override
  String get longitude => '経度';

  @override
  String get slotCount => '棚の数';

  @override
  String get createLocker => 'ロッカーを作成';

  @override
  String get disable => '無効化';

  @override
  String onceDisabledP0NoLongerAppears(Object p0) => '無効にすると「${p0}」は出品者の預け入れ先一覧に表示されなくなります。';

  @override
  String onceEnabledP0AvailableSellersAgain(Object p0) => '有効にすると「${p0}」を出品者が再び選べるようになります。';

  @override
  String get lockerDisabled => 'ロッカーを無効にしました';

  @override
  String get lockerEnabled => 'ロッカーを有効にしました';

  @override
  String slotP0(Object p0) => '棚 ${p0}';

  @override
  String get slotStatusUpdated => '棚の状態を更新しました';

  @override
  String get lockerMonitor => 'ロッカー監視';

  @override
  String get searchLockerNameAddress => 'ロッカー名・住所で検索';

  @override
  String get noLockersMatch => '該当するロッカーがありません';

  @override
  String get disabled => '無効';

  @override
  String freeSlotsP0P1(Object p0, Object p1) => '空き：${p0} / ${p1}';

  @override
  String get newCategory => 'カテゴリーを追加';

  @override
  String get editCategory => 'カテゴリーを編集';

  @override
  String get categoryName => 'カテゴリー名';

  @override
  String get enterCategoryName => 'カテゴリー名を入力してください';

  @override
  String get categoryAdded => 'カテゴリーを追加しました';

  @override
  String get categoryUpdated => 'カテゴリーを更新しました';

  @override
  String get deleteCategory => 'カテゴリーを削除';

  @override
  String deleteP0CannotUndone2(Object p0) => '「${p0}」を削除しますか？元に戻せません。';

  @override
  String get categoryDeleted => 'カテゴリーを削除しました';

  @override
  String get categories => 'カテゴリー管理';

  @override
  String get noCategoriesYet => 'カテゴリーがありません';

  @override
  String p0BooksUse(Object p0) => '${p0}';

  @override
  String get legalDocuments => '規約・ポリシー';

  @override
  String get notCreatedYet => '未作成';

  @override
  String updatedP0(Object p0) => '最終更新 ${p0}';

  @override
  String p0Characters(Object p0) => '${p0}';

  @override
  String p0SectionsP1Characters(Object p0, Object p1) => '${p0}・${p1}';

  @override
  String get deleteSection => '章を削除';

  @override
  String get contentsSectionRemovedWith => 'この章の内容も一緒に削除されます。';

  @override
  String p0ItsContentsRemoved(Object p0) => '「${p0}」とその内容が削除されます。';

  @override
  String get discardChanges => '変更を破棄しますか？';

  @override
  String get documentUnsavedChangesTheyLostIf => 'この文書には未保存の変更があります。離れると失われます。';

  @override
  String get discard => '破棄';

  @override
  String get keepEditing => '編集を続ける';

  @override
  String get bothTitleContentRequired => 'タイトルと本文の両方が必要です';

  @override
  String sectionP0NoTitleYet(Object p0) => '第${p0}';

  @override
  String updateP0(Object p0) => '${p0}？';

  @override
  String get documentBindingEveryUserSubmittingReplaces => 'この文書は全ユーザーに効力を持ちます。送信すると現在の版が直ちに置き換わります。';

  @override
  String get yesUpdate => '更新する';

  @override
  String get notifyEveryUser => '全ユーザーに通知しますか？';

  @override
  String get updateNotify => '更新して通知';

  @override
  String get updateOnly => '更新のみ';

  @override
  String get sections => '章立て';

  @override
  String get plainText => 'プレーンテキスト';

  @override
  String get preview => 'プレビュー';

  @override
  String get documentTitle => '文書のタイトル';

  @override
  String get preamble => '前文';

  @override
  String get unnumberedOpeningTextLeaveEmptyIf => '番号を付けない冒頭の説明文です。なければ空のままで構いません。';

  @override
  String get articles => '条文';

  @override
  String get numberedAutomatically => '番号は自動で付きます';

  @override
  String get noArticlesYetAddFirstOne => '条文がまだありません。下のボタンで最初の章を追加してください。';

  @override
  String get addSection => '章を追加';

  @override
  String get untitledSection => '無題の章';

  @override
  String get sectionTitle => '章のタイトル';

  @override
  String get bodySectionSingleLineBreaksKept => 'この章の本文です。単一の改行はそのまま表示され、空行で段落が変わります。';

  @override
  String get emptyLineStartsParagraphParagraphWhose => '空行で段落を分けます。1行目が「1. タイトル」の段落は、章立てモードに戻したときに1つの章として認識されます。';

  @override
  String get howUsersSee => 'ユーザーに見える表示';

  @override
  String get noContentYet => '内容がありません';

  @override
  String get unsaved => '未保存';

  @override
  String get upDate => '最新の状態です';

  @override
  String get newQuestion => '質問を追加';

  @override
  String get editQuestion => '質問を編集';

  @override
  String get question => '質問';

  @override
  String get answer => '回答';

  @override
  String get showHelpCentre => 'ヘルプセンターに表示';

  @override
  String get bothQuestionAnswerRequired => '質問と回答の両方が必要です';

  @override
  String get added => '追加しました';

  @override
  String get updated => '更新しました';

  @override
  String get deleteQuestion => '質問を削除';

  @override
  String deleteP0(Object p0) => '「${p0}」を削除しますか？';

  @override
  String get deleted => '削除しました';

  @override
  String get faq => 'よくある質問';

  @override
  String get noQuestionsYet2 => '質問がまだありません';

  @override
  String get dragHandleRightReorder => '右のハンドルをドラッグで並べ替え';

  @override
  String get hidden => '非表示';

  @override
  String get cancelDeletionRequest => '削除申請を取り消す';

  @override
  String p0SAccountReturnsNormalCountdown(Object p0) => '${p0}、カウントダウンが止まります。';

  @override
  String get cancelDeletion => '削除を取り消す';

  @override
  String get deletionRequestCancelled => '削除申請を取り消しました';

  @override
  String get anonymiseNow => '今すぐ匿名化';

  @override
  String eraseP0SPersonalDataDisable(Object p0) => '猶予期間の終了を待たず、${p0}。\n\n注文と取引記録は残りますが、表示名は「削除されたユーザー」になります。元に戻せません。';

  @override
  String get doNow => '今すぐ実行';

  @override
  String get anonymised => '匿名化が完了しました';

  @override
  String get pendingDeletions => '削除待ちのアカウント';

  @override
  String get noDeletionRequestsPending => '処理待ちの削除申請はありません';

  @override
  String get dueSoon => 'まもなく実行';

  @override
  String p0DaysLeft(Object p0) => '残り${p0}';

  @override
  String requestedP0ScheduledP1(Object p0, Object p1) => '${p0}、${p1}';

  @override
  String get disputeResolution => '取引の裁定';

  @override
  String orderP0P1(Object p0, Object p1) => '注文 ${p0}｜\\\$${p1}';

  @override
  String reasonP0(Object p0) => '申し立て理由：${p0}';

  @override
  String get decisionNoteOptional => '裁定の説明（任意）';

  @override
  String get submitDecision => '裁定を送信';

  @override
  String get decisionRecorded => '裁定を記録しました';

  @override
  String get resolveDispute => '取引を裁定';

  @override
  String get noDisputesKind => 'この種類の申し立てはありません';

  @override
  String orderNumberP0(Object p0) => '注文番号：${p0}';

  @override
  String buyerP0SellerP1(Object p0, Object p1) => '購入者：${p0}｜出品者：${p1}';

  @override
  String filedByP0(Object p0) => '申立人：${p0}';

  @override
  String get handle => '対応';

  @override
  String get transactions2 => '取引管理';

  @override
  String get orders => '注文管理';

  @override
  String get lookUpOrdersAdjustStatusBy => '注文の検索と手動でのステータス変更';

  @override
  String get disputeListDecisions => '申し立て一覧と裁定';

  @override
  String get listings => '商品管理';

  @override
  String get allBooksForceDelisting => '全書籍、強制的な出品停止';

  @override
  String get moderation => 'コンテンツ審査';

  @override
  String get handleListingReports => '商品の報告対応';

  @override
  String get addReorderDeleteBookCategories => 'カテゴリーの追加・並べ替え・削除';

  @override
  String get members => '会員管理';

  @override
  String get memberControls => '会員の管理';

  @override
  String get memberListSuspensionBlocklist => '会員一覧・利用停止・ブロック';

  @override
  String get membershipTiers => '会員ランク管理';

  @override
  String get tierThresholdsBenefits => 'ランクの基準と特典の設定';

  @override
  String get wallets => 'ウォレット管理';

  @override
  String get checkBalancesAddDeductCoinsBy => '残高の確認、コインの手動増減';

  @override
  String get hardwareOperations => 'ハードウェアと運用';

  @override
  String get lockerSlotStatus => 'ロッカーと棚の状態';

  @override
  String get maintenanceLog => 'メンテナンス記録';

  @override
  String get lockerOperationHistory => 'ロッカー関連の操作履歴';

  @override
  String get reports => '運用レポート';

  @override
  String get ordersRevenueMemberGrowth => '注文・売上・会員の推移';

  @override
  String get announcements2 => 'お知らせ管理';

  @override
  String get supportEnquiries => 'お問い合わせ';

  @override
  String get replyQuestionsFromUsers => 'ユーザーからの質問に回答';

  @override
  String get faqShownHelpCentre => 'ヘルプセンターのよくある質問';

  @override
  String get termsPrivacyPolicyAbout => '利用規約・プライバシーポリシー・運営者情報';

  @override
  String get adminAuditLog => '管理操作の記録';

  @override
  String get auditTrailAdminChanges => '管理者による変更の監査証跡';

  @override
  String get systemOperations => 'システム運用';

  @override
  String get dailyBackupsManualRunsDownloads => '毎日の自動バックアップ、手動実行とダウンロード';

  @override
  String get deletionRequestsInsideGracePeriodCancel => '猶予期間中の削除申請。取り消しも即時実行もできます';

  @override
  String get members2 => '会員数';

  @override
  String get todaySOrders => '本日の注文';

  @override
  String get openCases => '未処理の案件';

  @override
  String get activeLockers => '稼働中のロッカー';

  @override
  String get newTier => 'ランクを追加';

  @override
  String get editTier => 'ランクを編集';

  @override
  String get tierName => 'ランク名';

  @override
  String get minimumPoints => '最低ポイント';

  @override
  String get maximumPointsLeaveEmptyNoCap => '最高ポイント（空欄で上限なし）';

  @override
  String get benefitsSeparatedByCommasLineBreaks => '特典。読点か改行で区切ると、会員ランクのページに1件ずつ表示されます';

  @override
  String get enterTierName => 'ランク名を入力してください';

  @override
  String get maximumPointsMustExceedMinimum => '最高ポイントは最低ポイントより大きくしてください';

  @override
  String get tierAdded => 'ランクを追加しました';

  @override
  String get tierUpdated => 'ランクを更新しました';

  @override
  String get deleteTier => 'ランクを削除';

  @override
  String deleteP0MembersTierDropNext(Object p0) => '「${p0}」を削除しますか？このランクの会員は、条件を満たす次のランクに下がります。';

  @override
  String get tierDeleted => 'ランクを削除しました';

  @override
  String get noMembershipTiersSetUp => '会員ランクが未設定です';

  @override
  String p0PointsUp(Object p0) => '${p0}';

  @override
  String p0P1Points(Object p0, Object p1) => '${p0}〜${p1}';

  @override
  String get noBenefitsDescribedYet => '特典の説明が未入力です';

  @override
  String get noMaintenanceRecords => 'メンテナンス記録はありません';

  @override
  String get noFurtherDetail => '（補足なし）';

  @override
  String get operator => '操作者';

  @override
  String get unknown => '（不明）';

  @override
  String get time => '日時';

  @override
  String get recordNumber => '記録番号';

  @override
  String operatorP0(Object p0) => '操作者：${p0}';

  @override
  String get suspendAccount => 'このアカウントを利用停止';

  @override
  String get reinstateAccount => 'このアカウントを復帰';

  @override
  String get addBlocklist => 'ブロックリストに追加';

  @override
  String get removeFromBlocklist => 'ブロックリストから削除';

  @override
  String p0SignedOutImmediatelyCanNo(Object p0) => '${p0}、アプリのいかなる機能も使えなくなります。';

  @override
  String p0AbleSignAgain(Object p0) => '${p0}。';

  @override
  String get accountStatusUpdated => 'アカウントの状態を更新しました';

  @override
  String get removeAdmin => '管理者を解除';

  @override
  String get makeAdmin => '管理者にする';

  @override
  String p0LosesEveryAdminPermissionImmediately(Object p0) => '${p0}。';

  @override
  String p0GainsAccessAdminAreaWith(Object p0) => '${p0}、既定ではすべての権限を持ちます。あとから個別に調整できます。';

  @override
  String get roleUpdated => '役割を更新しました';

  @override
  String manualP0P1(Object p0, Object p1) => '、手動 ${p0}${p1}';

  @override
  String get adjustMembershipTier => '会員ランクを調整';

  @override
  String currentlyP0PointsAutomaticP1P2(Object p0, Object p1, Object p2) => '現在${p0}（自動 ${p1}${p2}）';

  @override
  String p0P1Points2(Object p0, Object p1) => '${p0}（${p1}）';

  @override
  String get adjustPointsManually => 'ポイントを手動で増減';

  @override
  String get backAutomatic => '自動計算に戻す';

  @override
  String get backAutomatic2 => '自動計算に戻しました';

  @override
  String get pointAdjustment => 'ポイントの増減';

  @override
  String get positiveAddsNegativeDeductsEG => '正の数で加算、負の数で減算（例：-50）';

  @override
  String get apply => '適用';

  @override
  String get enterNonZeroWholeNumber => '0以外の整数を入力してください';

  @override
  String get pointsAdjusted => 'ポイントを調整しました';

  @override
  String get tierAdjusted => 'ランクを調整しました';

  @override
  String get permissionGranted => '権限を付与しました';

  @override
  String get permissionRevoked => '権限を取り消しました';

  @override
  String get grantAllPermissions => 'すべての権限を付与';

  @override
  String get revokeAllPermissions => 'すべての権限を取り消し';

  @override
  String p0AbleUseEveryAdminFeature(Object p0) => '${p0}。';

  @override
  String p0ReachAdminAreaButUnable(Object p0) => '${p0}、どの機能も使えなくなります。';

  @override
  String get allPermissionsGranted => 'すべての権限を付与しました';

  @override
  String get allPermissionsRevoked => 'すべての権限を取り消しました';

  @override
  String get memberSettings => '会員の設定';

  @override
  String get noDataMember => 'この会員のデータが見つかりません';

  @override
  String get listings2 => '出品数';

  @override
  String get completedTrades => '取引完了数';

  @override
  String get joined => '登録日';

  @override
  String get accountStatus => 'アカウントの状態';

  @override
  String get ownAccountStatusPermissionsCannotChanged => 'これはあなた自身のアカウントです。ここから状態や権限は変更できません。';

  @override
  String get accountEnabled => 'アカウント有効';

  @override
  String get canSignUseAppNormally => '通常どおりログインして利用できます';

  @override
  String get suspendedSignedOutImmediatelyAfterSigning => '利用停止中。ログインしても直ちにログアウトされます';

  @override
  String get blocked => 'ブロック中';

  @override
  String get blockedNoFeaturesAvailable => 'ブロック済み。いかなる機能も利用できません';

  @override
  String get notBlocked => 'ブロックなし';

  @override
  String get role => '役割';

  @override
  String p0PointsAutomaticP1P2(Object p0, Object p1, Object p2) => '${p0}（自動 ${p1}${p2}）';

  @override
  String get memberSTierBeenAdjustedBy => 'この会員のランクは手動で調整されており、取引だけで自動計算されてはいません。';

  @override
  String get adjustTier => 'ランクを調整';

  @override
  String get adminPermissions => '管理権限';

  @override
  String get all => 'すべて有効';

  @override
  String get allOff => 'すべて無効';

  @override
  String get reinstateAccount2 => 'アカウントを復帰';

  @override
  String get suspendAccount2 => 'アカウントを利用停止';

  @override
  String runP1P0(Object p0, Object p1) => '「${p0}」に対して「${p1}」を実行しますか？';

  @override
  String updatedP0SStatus(Object p0) => '${p0}';

  @override
  String get fullSettingsTierPermissions => '詳細設定（ランク・権限）';

  @override
  String get members3 => '会員一覧';

  @override
  String get searchDisplayNameEmail => '表示名・メールで検索';

  @override
  String get noMembersMatch => '該当する会員がいません';

  @override
  String get sales2 => '販売';

  @override
  String get created => '作成日';

  @override
  String get noActivityYet => '操作記録はまだありません';

  @override
  String get changeOrderStatus => '注文ステータスを変更';

  @override
  String orderP0(Object p0) => '注文 ${p0}';

  @override
  String get reasonChange => '変更の説明';

  @override
  String get sentBuyerAsWellOptional => '購入者にも通知されます（任意）';

  @override
  String get applyChange => '変更を確定';

  @override
  String get orderStatusUpdated => '注文ステータスを更新しました';

  @override
  String get searchOrderNumberBuyerSeller => '注文番号・購入者・出品者で検索';

  @override
  String get noOrdersMatch => '該当する注文がありません';

  @override
  String get noItems => '（商品なし）';

  @override
  String p0ItemsTotal(Object p0) => 'ほか全${p0}';

  @override
  String buyerP0SellerP12(Object p0, Object p1) => '購入者 ${p0}｜出品者 ${p1}';

  @override
  String lockerP0(Object p0) => 'ロッカー：${p0}';

  @override
  String cancellationReasonP0(Object p0) => 'キャンセル理由：${p0}';

  @override
  String get reviewReport => '報告を審査';

  @override
  String reportedP0P1(Object p0, Object p1) => '報告された${p0}：${p1}';

  @override
  String reasonP02(Object p0) => '違反理由：${p0}';

  @override
  String get handlingNoteOptional => '対応メモ（任意）';

  @override
  String get delistListingAsWell => '同時に商品を出品停止';

  @override
  String get dismissReport => '報告を却下';

  @override
  String get reportHandled => '報告を処理しました';

  @override
  String get noReportsKind => 'この種類の報告はありません';

  @override
  String reportedByP0(Object p0) => '報告者：${p0}';

  @override
  String get review => '審査';

  @override
  String noteP0(Object p0) => 'メモ：${p0}';

  @override
  String get last7Days => '過去7日間';

  @override
  String get last30Days => '過去30日間';

  @override
  String get ordersPerDay => '1日あたりの注文数';

  @override
  String get revenuePerDay => '1日あたりの成約金額';

  @override
  String get newMembersPerDay => '1日あたりの新規会員';

  @override
  String get newOrders => '新規注文';

  @override
  String get newMembers => '新規会員';

  @override
  String get newListings => '新規出品';

  @override
  String get completedRevenue => '成約済み金額';

  @override
  String p0Orders(Object p0) => '${p0}';

  @override
  String peakP0(Object p0) => '最大 ${p0}';

  @override
  String get topCategoriesByListings => '人気カテゴリー（出品数順）';

  @override
  String get replied => '返信済み';

  @override
  String get noEnquiriesCategory => 'このカテゴリーにお問い合わせはありません';

  @override
  String get addCoins => 'コインを追加';

  @override
  String get deductCoins => 'コインを差し引く';

  @override
  String get amountPositiveWholeNumber => '金額（正の整数）';

  @override
  String get reasonAdjustmentRequired => '調整の理由（必須）';

  @override
  String get add2 => '追加する';

  @override
  String get deduct => '差し引く';

  @override
  String get enterAmountGreaterThan0 => '0より大きい金額を入力してください';

  @override
  String get enterReasonAdjustment => '調整の理由を入力してください';

  @override
  String get member2 => 'この会員';

  @override
  String get add3 => '追加';

  @override
  String get deduct2 => '差し引き';

  @override
  String get confirmAddingCoins => 'コインの追加を確認';

  @override
  String get confirmDeductingCoins => 'コインの差し引きを確認';

  @override
  String p1P2CoinsP0NreasonP3(Object p0, Object p1, Object p2, Object p3) => '${p0}${p1}${p2}。\n理由：${p3}';

  @override
  String get balanceAdjusted => '残高を調整しました';

  @override
  String get memberWallets => '会員のウォレット';

  @override
  String get transactions3 => '取引明細';

  @override
  String get memberNoTransactionsYet => 'この会員の取引明細はまだありません。';

  @override
  String get balanceCoins => '現在の残高（コイン）';

  @override
  String get hold2 => '保留中';

  @override
  String get total2 => '累計収入';

  @override
  String get totalOut => '累計支出';

  @override
  String balanceP0(Object p0) => '残高 ${p0}';

  @override
  String get suspensionBlocklistRoles => '利用停止・ブロック・役割';

  @override
  String get tierThresholdsManualAdjustments => 'ランクの基準と手動調整';

  @override
  String get booksCategories => '書籍とカテゴリー';

  @override
  String get reportReview => '報告の審査';

  @override
  String get handleListingReports2 => '商品の報告に対応';

  @override
  String get lookUpChangeOrderStatus => '注文の検索とステータス変更';

  @override
  String get decideDisputeCases => '申し立て案件の裁定';

  @override
  String get checkAdjustCoinBalances => 'コインの確認と増減';

  @override
  String get hardware => 'ハードウェア保守';

  @override
  String get lockersSlots => 'ロッカーと棚';

  @override
  String get announcementsDocuments => 'お知らせと文書';

  @override
  String get announcementsFaqLegalDocuments => 'お知らせ・よくある質問・規約';

  @override
  String get replyUserQuestions => 'ユーザーの質問に回答';

  @override
  String get databaseBackupDownloadOffByDefault => 'データベースのバックアップとダウンロード（既定では無効）';

  @override
  String p0Locker(Object p0) => 'ロッカーを${p0}';

  @override
  String everyActiveMemberReceivesP0Updated(Object p0) => '有効な会員全員に「${p0}が更新されました」という通知が届きます。';

  @override
  String get orderPlaced => '注文成立';

  @override
  String get paid => '支払い';

  @override
  String get sellerDroppedOff => '出品者が預け入れ';

  @override
  String get buyerCollected => '購入者が受け取り';

  @override
  String get completed => '完了';

  @override
  String get editBookDetails => '書籍情報を編集';

  @override
  String sellerP0TheyNotifiedSave(Object p0) => '出品者 ${p0}・保存時に通知されます';

  @override
  String get priceCoins => '価格（コイン）';

  @override
  String get k1013Digits2 => '10桁または13桁';

  @override
  String get category => 'カテゴリー';

  @override
  String get description2 => '商品説明';

  @override
  String get titleRequired => 'タイトルは必須です';

  @override
  String get nothingChanged => '変更はありません';

  @override
  String get resetPassword => 'パスワードをリセット';

  @override
  String p0SCurrentPasswordStopsWorking(Object p0) => '${p0}の現在のパスワードは直ちに使えなくなり、次に発行される仮パスワードでログインすることになります。\n\nパスワードはシステムが生成します。指定はできません。';

  @override
  String get generateTemporaryPassword => '仮パスワードを発行';

  @override
  String get temporaryPassword => '仮パスワード';

  @override
  String p0SPasswordBeenResetPassword(Object p0) => '${p0}のパスワードをリセットしました。このパスワードは一度きりの表示で、閉じると二度と確認できません。';

  @override
  String get remindThemChangeSettingsChangePassword => 'ログイン後すぐに「設定 → パスワード変更」で変更するよう伝えてください。';

  @override
  String get temporaryPasswordCopied => '仮パスワードをコピーしました';

  @override
  String get copy => 'コピー';

  @override
  String get cannotResetAnotherAdminSPassword => '他の管理者のパスワードはリセットできません';

  @override
  String get generateTemporaryPasswordHandOver => '仮パスワードを発行して本人に渡します';

  @override
  String get orderNumberCopied => '注文番号をコピーしました';

  @override
  String get orderNotFound => 'この注文が見つかりません';

  @override
  String get paidWithCoins => 'コイン払い';

  @override
  String get bankTransfer => '銀行振込';

  @override
  String get notPaidYet => '未払い';

  @override
  String get progress => '進行状況';

  @override
  String get notYet => '未到達';

  @override
  String get buyerSeller => '取引相手';

  @override
  String get items3 => '商品';

  @override
  String get bookDeleted => '（書籍は削除済み）';

  @override
  String get notAssignedYet2 => '未割り当て';

  @override
  String get pickupCodeCopied => '受け取りコードをコピーしました';

  @override
  String get walletActivity => 'ウォレットの動き';

  @override
  String balanceP02(Object p0) => '残高 ${p0}';

  @override
  String get refunds => '返金記録';

  @override
  String requestedP0NotProcessedYet(Object p0) => '${p0}に申請、未処理';

  @override
  String processedP0(Object p0) => '${p0}に処理';

  @override
  String get disputes => '申し立て';

  @override
  String filedP0(Object p0) => '${p0}に申請';

  @override
  String decidedP0(Object p0) => '${p0}に裁定';

  @override
  String createdP0(Object p0) => '${p0}に作成';

  @override
  String get shareBook => 'この本を共有';

  @override
  String get shareAnotherApp => '他のアプリで共有';

  @override
  String get approved => '承認済み';

  @override
  String get awaitingRefund => '返金待ち';

  @override
  String get declined => '返金不可';

  @override
  String get changeOwnPasswordGoSettingsChange => '自分のパスワードは「設定 → パスワード変更」から変更してください';

  @override
  String get memberNotAdminSoThereNo => 'この会員は管理者ではないため、設定できる管理権限がありません。先に上で役割を管理者に変更してください。';

  @override
  String get you => '自分';

  @override
  String isbnMust1013DigitsOne(Object p0) => 'ISBNは10桁か13桁です。現在は${p0}桁です';

  @override
  String get screenUnsavedChangesTheyLostIf => 'この画面には未保存の変更があります。離れると失われます。';

  @override
  String stillNeededP0(Object p0) => 'あと ${p0}';

  @override
  String photosP0(Object p0) => '写真：${p0}枚';

  @override
  String get confirmListing => '出品を確認';

  @override
  String get lookingUpBook => '書籍情報を検索中';

  @override
  String get scan => 'スキャン';

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

  @override
  String get verifySignSavemybook => 'SaveMyBook에 로그인하려면 인증하세요';

  @override
  String get maintenance => '시스템 점검';

  @override
  String get promotions => '이벤트 혜택';

  @override
  String get policyUpdate => '정책 변경';

  @override
  String get announcement => '일반 공지';

  @override
  String get item => '상품';

  @override
  String get member => '회원';

  @override
  String get message => '메시지';

  @override
  String get noLongerExists => '(대상이 존재하지 않음)';

  @override
  String get uncategorised => '미분류';

  @override
  String get general => '일반 도서';

  @override
  String get untitled => '제목 없음';

  @override
  String get noDescriptionYet => '아직 소개가 없습니다';

  @override
  String get locationNotProvided => '위치 정보 없음';

  @override
  String seller3(Object p0) => '판매자: ${p0}';

  @override
  String get unknownAuthor => '작자 미상';

  @override
  String get unknownPublisher => '출판사 미상';

  @override
  String get noIsbn => 'ISBN 없음';

  @override
  String get user => '사용자';

  @override
  String get noMessagesYet => '아직 메시지가 없습니다';

  @override
  String get photo => '[사진]';

  @override
  String item2(Object p0) => '[상품] ${p0}';

  @override
  String get purchase => '구매';

  @override
  String get sale => '판매';

  @override
  String get systemAdjustment => '시스템 조정';

  @override
  String get preparingData => '데이터를 준비하고 있습니다';

  @override
  String get mySavemybookData => '내 SaveMyBook 데이터';

  @override
  String get exportedChooseWhereSave => '내보냈습니다. 저장 위치를 선택하세요.';

  @override
  String get exportedButSharingCouldNotOpen => '내보냈지만 공유를 열 수 없습니다';

  @override
  String get regenerateShareLink => '공유 링크 재생성';

  @override
  String get oldLinkQrCodeStopWorking => '기존 링크와 QR 코드가 즉시 무효화되며, 이미 공유한 사람은 더 이상 열 수 없습니다. 재생성할까요?';

  @override
  String get regenerate => '재생성';

  @override
  String get newLinkCreatedOldOneNo => '새 링크를 만들었습니다. 기존 링크는 무효입니다.';

  @override
  String get deleteAccount => '계정 삭제';

  @override
  String get accountPermanentlyDisabled30DaysSign => '계정은 30일 후 영구 비활성화됩니다. 그 전에 다시 로그인하면 취소할 수 있습니다.\n\n';

  @override
  String get personalDataErasedButCompletedOrders => '비활성화 후 개인정보는 삭제되지만, 완료된 주문과 거래 기록은 보관됩니다. ';

  @override
  String get peopleTradedWithDoNotLose => '거래 상대방의 기록이 누락되지 않도록 하기 위함입니다.';

  @override
  String get actionContinue => '계속';

  @override
  String get verify => '본인 확인';

  @override
  String get enterPasswordConfirm => '본인 확인을 위해 비밀번호를 입력하세요.';

  @override
  String get password => '비밀번호';

  @override
  String get requestDeletion => '삭제 신청';

  @override
  String get receivedSignAgainWithin30Days => '접수되었습니다. 30일 이내에 다시 로그인하면 취소할 수 있습니다.';

  @override
  String get deletionCancelledAccountActiveAgain => '삭제를 취소했습니다. 계정이 정상으로 돌아왔습니다.';

  @override
  String get account => '계정 관리';

  @override
  String get data => '내 데이터';

  @override
  String get exportMyData => '내 데이터 내보내기';

  @override
  String get profileBooksOrdersTransactionsJson => '프로필, 도서, 주문, 거래 내역을 JSON으로';

  @override
  String get oldLinkQrCodeStopWorking2 => '기존 링크와 QR 코드가 즉시 무효화됩니다';

  @override
  String get cancelAccountDeletion => '계정 삭제 취소';

  @override
  String get restoreAccountStopCountdown => '계정을 복구하고 카운트다운을 중지합니다';

  @override
  String get canChangeMindWithin30Days => '30일 이내에는 취소할 수 있습니다';

  @override
  String get deletionPending => '삭제 대기 중';

  @override
  String daysLeftCanCancelAnyTime(Object p0) => '${p0}일 남았습니다. 그 전에는 언제든 취소할 수 있으며, 기한이 지나면 개인정보가 영구 삭제됩니다.';

  @override
  String get signOut => '로그아웃';

  @override
  String get type => '유형';

  @override
  String get content => '내용';

  @override
  String get backupFailed => '백업 실패';

  @override
  String get myBooks => '도서 관리';

  @override
  String get notProvided => '제공되지 않음';

  @override
  String get openingHours => '운영 시간';

  @override
  String get address => '주소';

  @override
  String get saveChanges => '변경 사항 저장';

  @override
  String get enable => '활성화';

  @override
  String get termsService => '이용약관';

  @override
  String get privacyPolicy => '개인정보 처리방침';

  @override
  String get aboutUs => '회사 소개';

  @override
  String get admin => '관리자';

  @override
  String get confirm => '확인';

  @override
  String get membershipTier => '회원 등급';

  @override
  String get phone => '전화번호';

  @override
  String get violationConfirmed => '위반 인정';

  @override
  String get scanBarcode => '바코드 스캔';

  @override
  String get lineUpBarcodeSpineWithFrame => '책등의 바코드를 프레임에 맞춰 주세요';

  @override
  String get signAddItemsCart => '장바구니에 담으려면 로그인하세요';

  @override
  String bookCannotPurchased(Object p0) => '이 책은 ${p0} 상태여서 구매할 수 없습니다';

  @override
  String get addedCart => '장바구니에 담았습니다';

  @override
  String get sellerInformationNotFound => '판매자 정보를 찾을 수 없습니다';

  @override
  String get signContactSeller => '판매자에게 연락하려면 로그인하세요';

  @override
  String get signStartChat => '채팅을 시작하려면 로그인하세요';

  @override
  String get signReport => '신고하려면 로그인하세요';

  @override
  String get cannotReportOwnListing => '본인의 상품은 신고할 수 없습니다';

  @override
  String get reportListing => '이 상품 신고';

  @override
  String get describeProblemLeast5Characters => '문제를 설명해 주세요 (5자 이상)';

  @override
  String get reasonNeedsLeast5Characters => '신고 사유는 5자 이상 입력해 주세요';

  @override
  String get reportSubmittedWeLookInto => '신고를 접수했습니다. 최대한 빨리 처리하겠습니다.';

  @override
  String get publisher => '출판사: ';

  @override
  String get author => '저자: ';

  @override
  String get listed => '등록일: ';

  @override
  String get searchTitleAuthorPublisher => '제목, 저자, 출판사 검색...';

  @override
  String get share => '공유';

  @override
  String get report => '신고';

  @override
  String get about => '소개: ';

  @override
  String pickup(Object p0) => '수령 장소: ${p0}';

  @override
  String get messageSeller => '판매자와 대화';

  @override
  String get listing => '내 상품입니다';

  @override
  String get addCart => '장바구니 담기';

  @override
  String get bookBeenReportedUnderReviewStays => '이 책은 신고되어 검토 중입니다. 검토 중에도 정상 판매됩니다.';

  @override
  String get violationWasConfirmedBookPleaseCheck => '이 책은 위반이 인정되었습니다. 커뮤니티 가이드라인에 맞는지 확인해 주세요.';

  @override
  String get reportDismissed2 => '신고가 기각되었습니다';

  @override
  String get bookWasReportedButNoViolation => '이 책은 신고되었으나 위반이 확인되지 않았습니다. 판매에는 영향이 없습니다.';

  @override
  String get delist => '판매 중단';

  @override
  String removedFromShopBuyersNoLonger(Object p0) => '“${p0}”이(가) 상점에서 내려가 구매자에게 더 이상 표시되지 않습니다.';

  @override
  String get delist2 => '내리기';

  @override
  String get delistedRelistFromDelistedTab => '판매를 중단했습니다. ‘내림’ 탭에서 다시 올릴 수 있습니다.';

  @override
  String get couldNotDelistPleaseTryAgain => '판매 중단에 실패했습니다. 잠시 후 다시 시도해 주세요.';

  @override
  String listedAgain(Object p0) => '“${p0}”을(를) 다시 등록했습니다';

  @override
  String get notListedAnyBooksYet => '아직 등록한 도서가 없습니다';

  @override
  String get noBooksCategory => '이 분류에 도서가 없습니다';

  @override
  String get listFirstBook => '첫 도서 등록하기';

  @override
  String get relist => '다시 올리기';

  @override
  String get removeFromCart => '장바구니에서 빼기';

  @override
  String removeFromCart2(Object p0) => '“${p0}”을(를) 장바구니에서 뺄까요?';

  @override
  String get remove => '삭제';

  @override
  String get couldNotRemoveRestored => '삭제하지 못해 되돌렸습니다.';

  @override
  String get couldNotRemovePleaseTryAgain => '삭제하지 못했습니다. 잠시 후 다시 시도해 주세요.';

  @override
  String get selectBooksWantCheckOut => '결제할 도서를 선택해 주세요';

  @override
  String notEnoughCoinsOrderNeedsBut(Object p0, Object p1) => '코인이 부족합니다. 이 주문에는 ${p0}이(가) 필요하지만 잔액은 ${p1}입니다.';

  @override
  String get confirmCheckout => '결제 확인';

  @override
  String booksTotal(Object p0, Object p1) => '도서 ${p0}권, 합계 ${p1}.\n';

  @override
  String balanceAfterPaymentCoins(Object p0) => '결제 후 잔액은 ${p0} 코인입니다.';

  @override
  String get orderPlacedSellerDropBookOff => '주문이 완료되었습니다. 판매자의 보관을 기다려 주세요.';

  @override
  String get cart => '장바구니';

  @override
  String get cartEmpty => '장바구니가 비어 있습니다';

  @override
  String get selectAll => '전체 선택';

  @override
  String items(Object p0) => '${p0}개 상품';

  @override
  String get deselect => '선택 해제';

  @override
  String get select => '선택';

  @override
  String coinsShort(Object p0) => '${p0} 코인 부족';

  @override
  String get total => '합계';

  @override
  String selected(Object p0) => '${p0}개';

  @override
  String balance2(Object p0) => '잔액 ${p0}';

  @override
  String get selectBookFirst => '먼저 도서를 선택하세요';

  @override
  String get checkOut => '결제';

  @override
  String get notEnoughCoins => '코인이 부족합니다';

  @override
  String get weak => '약함';

  @override
  String get fair => '보통';

  @override
  String get strong => '강함';

  @override
  String get enterCurrentPassword => '현재 비밀번호를 입력하세요';

  @override
  String get enterNewPassword => '새 비밀번호를 입력하세요';

  @override
  String get newPasswordMustDifferent => '새 비밀번호는 현재 비밀번호와 달라야 합니다';

  @override
  String get enterNewPasswordAgain => '새 비밀번호를 다시 입력하세요';

  @override
  String get passwordsDoNotMatch => '입력한 새 비밀번호가 일치하지 않습니다';

  @override
  String get passwordUpdated => '비밀번호를 변경했습니다';

  @override
  String get changePassword => '비밀번호 변경';

  @override
  String get useLeast8CharactersWithBoth => '영문과 숫자를 모두 포함해 8자 이상으로 입력하세요.';

  @override
  String get currentPassword => '현재 비밀번호';

  @override
  String get newPassword => '새 비밀번호';

  @override
  String get confirmNewPassword => '새 비밀번호 확인';

  @override
  String get updatePassword => '비밀번호 변경';

  @override
  String get deleteChat => '채팅 삭제';

  @override
  String allMessagesWithDeletedBothCannot(Object p0) => '${p0}님과 주고받은 모든 메시지가 양쪽 모두에서 삭제됩니다. 되돌릴 수 없습니다.';

  @override
  String get chatDeleted => '채팅을 삭제했습니다';

  @override
  String get couldNotDeleteRestored => '삭제하지 못해 되돌렸습니다.';

  @override
  String get chatMuted => '이 채팅을 음소거했습니다';

  @override
  String get chatUnmuted => '음소거를 해제했습니다';

  @override
  String get noUnreadMessages => '읽지 않은 메시지가 없습니다';

  @override
  String get markAllAsRead => '모두 읽음으로 표시';

  @override
  String markAllUnreadMessagesAsRead(Object p0) => '읽지 않은 메시지 ${p0}건을 모두 읽음으로 표시할까요? 되돌릴 수 없습니다.';

  @override
  String get markAllRead => '모두 읽음';

  @override
  String get allMarkedAsRead => '모두 읽음으로 표시했습니다';

  @override
  String get somethingWentWrongPleaseTryAgain => '작업에 실패했습니다. 잠시 후 다시 시도해 주세요.';

  @override
  String get chats => '채팅';

  @override
  String get noConversationsYet => '아직 대화가 없습니다';

  @override
  String get unmute => '음소거 해제';

  @override
  String get mute => '음소거';

  @override
  String get messagesLimited500Characters => '메시지는 500자까지 입력할 수 있습니다';

  @override
  String get messageCouldNotSent => '메시지를 보내지 못했습니다';

  @override
  String get chat => '채팅';

  @override
  String get sendFirstMessage => '첫 메시지를 보내 보세요';

  @override
  String get messageCopied => '메시지를 복사했습니다';

  @override
  String get iQuestionAboutBook => '이 책에 대해 문의합니다';

  @override
  String get bookNoLongerListed => '이 책은 더 이상 판매하지 않습니다';

  @override
  String get writeMessage => '메시지 입력…';

  @override
  String get enterOrderNumberDisputing => '이의를 제기할 주문 번호를 입력하세요';

  @override
  String get describeDispute => '이의 내용을 입력해 주세요';

  @override
  String get useLeast10CharactersSoSupport => '고객센터가 판단할 수 있도록 10자 이상 입력해 주세요';

  @override
  String get submitDispute => '이의 제기';

  @override
  String get orderEntersDisputeProcessPaymentSeller => '주문이 이의 처리 절차로 넘어가며, 고객센터가 판정할 때까지 판매자 정산이 보류됩니다.';

  @override
  String paymentHoldRequested(Object p0) => '[정산 보류 요청] ${p0}';

  @override
  String get disputeSubmittedSupportContact => '이의를 접수했습니다. 고객센터에서 연락드리겠습니다.';

  @override
  String get dispute => '이의 처리';

  @override
  String get requestPaymentHold => '정산 보류 요청';

  @override
  String get paymentSellerHeldUntilSupportDecides => '고객센터가 판정할 때까지 판매자 정산이 보류됩니다';

  @override
  String get submitDispute2 => '이의 제기하기';

  @override
  String get orderNumber => '주문 번호';

  @override
  String get eGSmb20260910123456789 => '예: SMB20260910123456789';

  @override
  String get whatHappened => '이의 내용';

  @override
  String get describeProblemEGConditionDoes => '문제 상황을 적어 주세요. 예: 상태가 설명과 다름…';

  @override
  String get submit => '신청 보내기';

  @override
  String get uploadPhotos => '사진 업로드';

  @override
  String get canAttachUp6Photos => '증빙 사진은 최대 6장까지 첨부할 수 있습니다';

  @override
  String get up5 => '최대 5장';

  @override
  String get couldNotReplacePhotoPleaseTry => '사진을 교체하지 못했습니다. 잠시 후 다시 시도해 주세요.';

  @override
  String get keepLeastOnePhoto => '사진은 최소 한 장 필요합니다';

  @override
  String get photoDeleted => '사진을 삭제했습니다';

  @override
  String get couldNotDeletePhotoPleaseTry => '사진을 삭제하지 못했습니다. 잠시 후 다시 시도해 주세요.';

  @override
  String get canUp10Photos => '사진은 최대 10장까지 가능합니다';

  @override
  String get deletePhoto => '사진 삭제';

  @override
  String get cannotUndoneContinue => '삭제하면 되돌릴 수 없습니다. 계속할까요?';

  @override
  String get photoMissingDataRefreshTryAgain => '이 사진의 데이터가 불완전합니다. 새로고침 후 다시 시도하세요.';

  @override
  String get enterPrice => '가격을 입력하세요';

  @override
  String get priceMustGreaterThan0 => '가격은 0보다 커야 합니다';

  @override
  String get priceCannotExceed999999 => '가격은 999,999를 넘을 수 없습니다';

  @override
  String get chooseLockerLocation => '보관 위치를 선택하세요';

  @override
  String missingTheseThreeRequired(Object p0) => '누락: ${p0}. 이 세 장은 필수입니다.';

  @override
  String get bookUpdated => '도서를 수정했습니다';

  @override
  String get editBook => '도서 편집';

  @override
  String get condition => '상태';

  @override
  String get customPrice => '직접 입력';

  @override
  String get enterPrice2 => '판매 가격 입력';

  @override
  String get lockerLocation => '보관 위치';

  @override
  String get chooseLocker => '보관함 선택';

  @override
  String get bookPhotos => '도서 사진';

  @override
  String get morePhotos => '추가 사진';

  @override
  String get add => '추가';

  @override
  String get enterTitle => '제목을 입력하세요';

  @override
  String get titleLimited255Characters => '제목은 255자까지 입력할 수 있습니다';

  @override
  String get isbn1013Digits => 'ISBN은 10자리 또는 13자리입니다';

  @override
  String get chooseCategory => '분류를 선택하세요';

  @override
  String get k1013Digits => '10자리 또는 13자리';

  @override
  String get title => '제목';

  @override
  String get actionRequired => '필수';

  @override
  String get author2 => '저자';

  @override
  String get optional => '선택';

  @override
  String get publisher2 => '출판사';

  @override
  String get publicationDate => '출간일';

  @override
  String get tapPickPublicationDate => '눌러서 출간일 선택';

  @override
  String get pickPublicationDate => '출간일 선택';

  @override
  String get pickCategory => '분류 선택';

  @override
  String get next => '다음';

  @override
  String get uploading => '업로드 중…';

  @override
  String get profilePhotoUpdated => '프로필 사진을 변경했습니다';

  @override
  String get couldNotUploadPhoto => '프로필 사진을 업로드하지 못했습니다';

  @override
  String get changeDisplayName => '닉네임 변경';

  @override
  String get enterDisplayName => '닉네임을 입력하세요';

  @override
  String get displayNameCannotBlank => '닉네임은 비워 둘 수 없습니다';

  @override
  String get displayNames250Characters => '닉네임은 2~50자로 입력하세요';

  @override
  String get invalidPhoneNumberEG0912345678 => '전화번호 형식이 올바르지 않습니다. 예: 0912345678';

  @override
  String get profileUpdated => '프로필을 수정했습니다';

  @override
  String get editProfile => '프로필 편집';

  @override
  String get bio => '소개';

  @override
  String get tellPeopleAboutYourself => '자신을 소개해 보세요';

  @override
  String get email => '이메일';

  @override
  String get emailCannotChanged => '이메일은 변경할 수 없습니다';

  @override
  String get dateBirth => '생년월일';

  @override
  String get tapPickDateBirth => '눌러서 생년월일 선택';

  @override
  String get pickDateBirth => '생년월일 선택';

  @override
  String get savedBooks => '저장한 도서';

  @override
  String get notSavedAnyBooksYet => '아직 저장한 도서가 없습니다';

  @override
  String get helpCentre => '고객센터';

  @override
  String get searchQuestions => '질문 검색';

  @override
  String get noQuestionsYet => '아직 자주 묻는 질문이 없습니다';

  @override
  String get noMatchingQuestions => '일치하는 질문이 없습니다';

  @override
  String get newest => '최신순';

  @override
  String get popular => '인기순';

  @override
  String get priceLowHigh => '가격 낮은순';

  @override
  String get priceHighLow => '가격 높은순';

  @override
  String get reachedEnd => '마지막입니다';

  @override
  String get guest => '게스트';

  @override
  String hi(Object p0) => '안녕하세요, ${p0}님';

  @override
  String get noBooksMatchFilters => '조건에 맞는 도서가 없습니다';

  @override
  String get couldNotReadPhoto => '이 사진을 읽을 수 없습니다';

  @override
  String get croppingFailedPleaseTryAgain => '자르기에 실패했습니다. 다시 시도해 주세요.';

  @override
  String get adjustPhoto => '사진 조정';

  @override
  String get reset => '초기화';

  @override
  String get usePhoto => '이 사진 사용';

  @override
  String get documentNotBeenCreatedYet => '이 문서는 아직 작성되지 않았습니다';

  @override
  String lastUpdated(Object p0) => '마지막 업데이트: ${p0}';

  @override
  String get biometrics => '생체 인증';

  @override
  String get sessionExpiredPleaseEnterPasswordAgain => '로그인 정보가 만료되었습니다. 비밀번호를 다시 입력해 주세요.';

  @override
  String turnSign(Object p0) => '${p0} 로그인을 켤까요?';

  @override
  String nextTimeOpenAppCanUnlock(Object p0) => '다음에 앱을 열 때 비밀번호 대신 ${p0}(으)로 잠금을 해제할 수 있습니다.';

  @override
  String get notNow => '나중에';

  @override
  String get enterEmail => '이메일을 입력하세요';

  @override
  String get emailAddressNotValid => '이메일 형식이 올바르지 않습니다';

  @override
  String get enterPassword => '비밀번호를 입력하세요';

  @override
  String get noAccountWithEmail => '등록되지 않은 계정입니다';

  @override
  String noAccountCreateOneNow(Object p0) => '“${p0}” 계정을 찾을 수 없습니다. 지금 만들까요?';

  @override
  String get signUp => '가입하러 가기';

  @override
  String get tryAgain => '다시 입력';

  @override
  String get sign => '로그인';

  @override
  String signWith(Object p0) => '${p0}(으)로 로그인';

  @override
  String get noAccountYetSignUp => '계정이 없으신가요? 가입하기';

  @override
  String get membershipTiersNotSetUpYet => '회원 등급이 아직 설정되지 않았습니다';

  @override
  String get currentTier => '현재 등급';

  @override
  String get unlocked => '달성함';

  @override
  String get locked => '미달성';

  @override
  String get aboveTier => '이 등급보다 높습니다';

  @override
  String get reachedTopTier => '최고 등급에 도달했습니다';

  @override
  String unlocked2(Object p0) => '“${p0}” 달성';

  @override
  String morePointsUnlock(Object p0, Object p1) => '${p0}점 더 모으면 “${p1}” 달성';

  @override
  String benefits(Object p0) => '${p0} 혜택';

  @override
  String get noBenefitsBeenDescribedTierYet => '이 등급의 혜택이 아직 설정되지 않았습니다.';

  @override
  String pointsFromCompletedOrders(Object p0, Object p1) => '거래 ${p1}건으로 ${p0}점';

  @override
  String get noNotificationsClear => '지울 알림이 없습니다';

  @override
  String get clearAllNotifications => '모든 알림 지우기';

  @override
  String notificationsDeletedCannotUndone(Object p0) => '알림 ${p0}건을 삭제합니다. 되돌릴 수 없습니다.';

  @override
  String get clearAll => '모두 지우기';

  @override
  String get allNotificationsCleared => '모든 알림을 지웠습니다';

  @override
  String get couldNotClearPleaseTryAgain => '지우지 못했습니다. 잠시 후 다시 시도해 주세요.';

  @override
  String get noUnreadNotifications => '읽지 않은 알림이 없습니다';

  @override
  String markAllUnreadNotificationsAsRead(Object p0) => '읽지 않은 알림 ${p0}건을 모두 읽음으로 표시할까요? 되돌릴 수 없습니다.';

  @override
  String get openChat => '채팅 열기';

  @override
  String get viewOrder => '주문 보기';

  @override
  String get openMyBooks => '도서 관리 열기';

  @override
  String get notifications => '알림';

  @override
  String get noNotifications => '알림이 없습니다';

  @override
  String copied(Object p0) => '${p0}을(를) 복사했습니다';

  @override
  String get orderDetails => '주문 상세';

  @override
  String order(Object p0) => '주문 번호 ${p0}';

  @override
  String get orderProgress => '주문 진행';

  @override
  String items2(Object p0) => '상품 내역 (${p0})';

  @override
  String get orderNoItemDetails => '이 주문에는 상품 정보가 없습니다.';

  @override
  String msg4(Object p0, Object p1) => '단가 ${p0} × ${p1}';

  @override
  String get orderTotal => '주문 금액';

  @override
  String get pickupDetails => '수령 정보';

  @override
  String get notAssigned => '미지정';

  @override
  String get slot => '보관함';

  @override
  String get notAssignedYet => '아직 배정되지 않음';

  @override
  String get pickupCode => '수령 코드';

  @override
  String get transaction => '거래 정보';

  @override
  String get buyer => '구매자';

  @override
  String get seller => '판매자';

  @override
  String get placed => '주문 일시';

  @override
  String get dispute2 => '이의';

  @override
  String get orderOpenDispute => '이 주문에는 진행 중인 이의가 있습니다';

  @override
  String get cancelOrder => '주문 취소';

  @override
  String get pendingPayoutDisappearsBuyerNotified => '대기 중인 정산이 사라지고 구매자에게도 알림이 갑니다.';

  @override
  String get cancelledBySeller => '판매자 취소';

  @override
  String get orderCancelled2 => '주문을 취소했습니다';

  @override
  String get pendingPayouts => '대기 중인 정산';

  @override
  String get noPendingPayouts => '대기 중인 정산이 없습니다';

  @override
  String get pendingAmount => '대기 금액';

  @override
  String get coinsArriveOnceBuyerCollectsBook => '구매자가 수령하면 코인이 자동 지급됩니다';

  @override
  String get scanned => '스캔 완료';

  @override
  String get scanAgain => '다시 스캔';

  @override
  String get collectBook => '도서 수령';

  @override
  String get pointPickupQrCode => '수령용 QR 코드를 맞춰 주세요';

  @override
  String get holdSteady => '흔들리지 않게 유지하세요';

  @override
  String get bookCollected => '수령 완료';

  @override
  String get thanksUsingSavemybookHappyReading => '이용해 주셔서 감사합니다. 즐거운 독서 되세요!';

  @override
  String collected(Object p0) => '“${p0}” 수령 완료';

  @override
  String order2(Object p0) => '주문 번호: ${p0}';

  @override
  String get signingOut => '로그아웃 중…';

  @override
  String get myAccount => '마이페이지';

  @override
  String get personNotWrittenBioYet => '아직 소개가 없습니다';

  @override
  String get topTierReached => '최고 등급 달성';

  @override
  String morePointsReach(Object p0, Object p1) => '${p0}점 더 모으면 “${p1}”';

  @override
  String get myCoins => '내 코인';

  @override
  String get shareProfile => '프로필 공유';

  @override
  String get purchases => '구매 내역';

  @override
  String get sales => '판매 내역';

  @override
  String get settings => '설정';

  @override
  String get signOut2 => '로그아웃할까요?';

  @override
  String get needSignAgainKeepUsingApp => '계속 사용하려면 다시 로그인해야 합니다.';

  @override
  String cancelOrderBookReturnsShop(Object p0) => '주문 ${p0}을(를) 취소할까요? 도서는 다시 판매됩니다.';

  @override
  String get pickupCode2 => '수령 코드';

  @override
  String get notGeneratedYet => '아직 발급되지 않음';

  @override
  String get enterCodeLockerCollect => '보관함에서 이 코드를 입력해 수령하세요';

  @override
  String enterCodeCollect(Object p0) => '“${p0}”에서 이 코드를 입력해 수령하세요';

  @override
  String get iCollected => '수령을 완료했습니다';

  @override
  String get noOrdersTab => '이 탭에는 주문이 없습니다';

  @override
  String get openDispute => '이의 제기';

  @override
  String get displayNameNeedsLeast2Characters => '닉네임은 2자 이상이어야 합니다';

  @override
  String get displayNameLimited50Characters => '닉네임은 50자까지 가능합니다';

  @override
  String get enterPasswordAgain => '비밀번호를 다시 입력하세요';

  @override
  String get passwordsDoNotMatch2 => '입력한 비밀번호가 일치하지 않습니다';

  @override
  String get pleaseReadAcceptTermsServicePrivacy => '이용약관과 개인정보 처리방침을 읽고 동의해 주세요';

  @override
  String get accountCreatedSignWith => '계정을 만들었습니다. 로그인해 주세요.';

  @override
  String get iReadAccept => '다음에 동의합니다: ';

  @override
  String get and => ' 및 ';

  @override
  String get createAccount => '계정 만들기';

  @override
  String get joinSavemybook => 'SaveMyBook 가입';

  @override
  String get signUpBuySellUseSmart => '가입하면 도서 매매와 스마트 보관함을 이용할 수 있습니다';

  @override
  String get displayName => '닉네임';

  @override
  String get nameOthersSee => '다른 사람에게 보이는 이름';

  @override
  String get emailSignWith => '로그인에 사용할 이메일';

  @override
  String get least8CharactersWithLettersNumbers => '영문과 숫자를 포함해 8자 이상';

  @override
  String get confirmPassword => '비밀번호 확인';

  @override
  String get enterPasswordAgain2 => '비밀번호 다시 입력';

  @override
  String get alreadyAccountGoBackSign => '이미 계정이 있으신가요? 돌아가서 로그인';

  @override
  String get markAsDroppedOff => '보관 완료';

  @override
  String get droppedOff => '보관함에 넣음';

  @override
  String get markedAsDroppedOff => '보관 완료로 표시했습니다';

  @override
  String get buyerNotifiedBookReturnsShop => '구매자에게 알림이 가고 도서는 다시 판매됩니다.';

  @override
  String get dropOffPickupCode => '보관·수령 코드';

  @override
  String get enterCodeLocker => '보관함에서 이 코드를 입력하세요';

  @override
  String get noRecentSearches => '최근 검색이 없습니다';

  @override
  String get recentSearches => '최근 검색';

  @override
  String get clearAll2 => '모두 지우기';

  @override
  String get searchTitleAuthorIsbn => '제목, 저자, ISBN 검색...';

  @override
  String get photoLimitReached => '사진이 가득 찼습니다';

  @override
  String get canUploadUp10Photos => '사진은 최대 10장까지 업로드할 수 있습니다.';

  @override
  String get photosMissing => '사진이 부족합니다';

  @override
  String missingTheseThreeRequired2(Object p0) => '누락: ${p0}. 이 세 장은 필수입니다.';

  @override
  String get missingInformation => '입력이 부족합니다';

  @override
  String get enterOwnPrice => '가격을 입력해 주세요.';

  @override
  String get invalidPrice => '가격이 올바르지 않습니다';

  @override
  String get priceMustGreaterThan02 => '가격은 0보다 커야 합니다.';

  @override
  String get priceCannotExceed99999 => '가격은 99,999를 넘을 수 없습니다.';

  @override
  String get chooseLockerLocation2 => '보관 위치를 선택해 주세요.';

  @override
  String get listed2 => '등록되었습니다!';

  @override
  String get unknownError => '알 수 없는 오류';

  @override
  String get couldNotListBook => '등록에 실패했습니다';

  @override
  String serverError(Object p0) => '서버 오류: ${p0}';

  @override
  String get connectionProblem => '연결 오류';

  @override
  String get couldNotReachServerUploadTimed => '서버에 연결할 수 없거나 업로드가 시간 초과되었습니다. 네트워크를 확인해 주세요.';

  @override
  String get listBook => '등록 완료';

  @override
  String get detailsPhotos => '상세 정보와 사진';

  @override
  String get loading => '불러오는 중...';

  @override
  String get unknownLocker => '알 수 없는 보관함';

  @override
  String get enterTitle2 => '제목을 입력하세요';

  @override
  String get chooseCategory2 => '분류를 선택하세요';

  @override
  String get bookDetailsFilledAutomatically => '도서 정보를 자동으로 채웠습니다.';

  @override
  String get bookDetailsFilledFromBackupSource => '보조 데이터베이스에서 도서 정보를 가져왔습니다.';

  @override
  String get noSourceIsbnPleaseEnterDetails => '어떤 데이터베이스에도 이 ISBN이 없습니다. 직접 입력해 주세요.';

  @override
  String get day => '일';

  @override
  String get tapIconRightScan => '오른쪽 아이콘을 눌러 스캔';

  @override
  String get description => '도서 소개';

  @override
  String get sellBook => '도서 판매';

  @override
  String get myShop => '내 상점';

  @override
  String get sellerNoBooksSale => '이 판매자는 판매 중인 도서가 없습니다';

  @override
  String get loading2 => '불러오는 중…';

  @override
  String sale2(Object p0) => '판매 중 ${p0}권';

  @override
  String get verifyEnableQuickSign => '빠른 로그인을 켜려면 인증하세요';

  @override
  String sign2(Object p0) => '${p0} 로그인을 켰습니다';

  @override
  String get quickSignTurnedOff => '빠른 로그인을 껐습니다';

  @override
  String get appearance2 => '화면 설정';

  @override
  String get signMethod => '로그인 방식';

  @override
  String get helpSupport => '도움말 및 지원';

  @override
  String get contactUs => '문의하기';

  @override
  String get aboutSavemybook => 'SaveMyBook 정보';

  @override
  String get settingsPrivacy => '설정 및 개인정보';

  @override
  String sign3(Object p0) => '${p0} 로그인';

  @override
  String unlockWithWhenOpenApp(Object p0) => '앱을 열 때 ${p0}(으)로 잠금 해제';

  @override
  String get scanProfileQrCode => '프로필 QR 코드 스캔';

  @override
  String get lineUpTheirQrCodeWith => '상대방의 QR 코드를 프레임에 맞춰 주세요';

  @override
  String get notSavemybookProfileQrCode => 'SaveMyBook 프로필 QR 코드가 아닙니다';

  @override
  String get ownQrCode => '본인의 QR 코드입니다';

  @override
  String get couldNotStartChatPleaseTry => '채팅을 시작하지 못했습니다. 잠시 후 다시 시도해 주세요.';

  @override
  String get linkCopied => '링크를 복사했습니다';

  @override
  String addMeSavemybook(Object p0) => 'SaveMyBook에서 나를 추가: ${p0}';

  @override
  String addMeSavemybook2(Object p0, Object p1) => 'SaveMyBook에서 나를 추가 (${p0}): ${p1}';

  @override
  String get sharingCouldNotOpenSoLink => '공유를 열 수 없어 링크를 복사했습니다';

  @override
  String get savedPhotos => '사진에 저장했습니다';

  @override
  String get couldNotSaveCheckPhotoLibrary => '저장하지 못했습니다. 사진 접근 권한을 확인해 주세요.';

  @override
  String get scanTheirQrCode => '상대방 QR 코드 스캔';

  @override
  String get copyLink => '링크 복사';

  @override
  String get askQuestion => '문의하기';

  @override
  String get noEnquiriesYet => '문의 내역이 없습니다';

  @override
  String get enterSubject => '제목을 입력하세요';

  @override
  String get addMoreDetailSoSupportCan => '고객센터가 파악할 수 있도록 좀 더 자세히 적어 주세요';

  @override
  String get sentSupportReplySoon => '보냈습니다. 고객센터가 곧 답변드립니다.';

  @override
  String get subject => '제목';

  @override
  String get sumUpOneLine => '한 줄로 요약해 주세요';

  @override
  String get whatHappenedIncludeOrderNumberIf => '무슨 일이 있었나요? 주문 번호가 있다면 함께 적어 주세요.';

  @override
  String get close => '종료';

  @override
  String get notAbleReplyAfterClosing => '종료하면 더 이상 답변할 수 없습니다.';

  @override
  String get enquiryClosed => '문의를 종료했습니다';

  @override
  String get changeStatus => '상태 변경';

  @override
  String get statusUpdated => '상태를 변경했습니다';

  @override
  String get enquiry => '문의';

  @override
  String get enquiryNotFound => '문의를 찾을 수 없습니다';

  @override
  String get support => '고객센터';

  @override
  String get writeReply => '답변 입력…';

  @override
  String get coins => '코인';

  @override
  String get transactions => '거래 내역';

  @override
  String get noTransactionsYet => '거래 내역이 없습니다';

  @override
  String get balance => '현재 잔액';

  @override
  String hold(Object p0) => '보류 ${p0}';

  @override
  String requestFailed2(Object p0) => '요청 실패 (${p0})';

  @override
  String get couldNotReachServer => '서버에 연결할 수 없습니다';

  @override
  String get couldNotReachServerCheckConnection => '서버에 연결할 수 없습니다. 네트워크를 확인해 주세요.';

  @override
  String get signFailed => '로그인에 실패했습니다';

  @override
  String get signFailedPleaseTryAgain => '로그인에 실패했습니다. 잠시 후 다시 시도해 주세요.';

  @override
  String get signUpFailed => '가입에 실패했습니다';

  @override
  String get pleaseSignFirst => '먼저 로그인해 주세요';

  @override
  String get couldNotRelist => '다시 등록하지 못했습니다';

  @override
  String get couldNotRemoveFromSaved => '저장 해제에 실패했습니다';

  @override
  String get couldNotSave => '저장하지 못했습니다';

  @override
  String get couldNotAddCart => '장바구니에 담지 못했습니다';

  @override
  String get checkoutFailed => '결제에 실패했습니다';

  @override
  String get couldNotCancelOrder => '주문을 취소하지 못했습니다';

  @override
  String get couldNotUpdateOrder => '주문 상태를 변경하지 못했습니다';

  @override
  String get couldNotSubmitDispute => '이의를 접수하지 못했습니다';

  @override
  String get couldNotSubmitReport => '신고를 보내지 못했습니다';

  @override
  String get updateFailed2 => '업데이트에 실패했습니다';

  @override
  String get couldNotChangePassword => '비밀번호를 변경하지 못했습니다';

  @override
  String get requestFailed => '신청에 실패했습니다';

  @override
  String get couldNotCancel => '취소하지 못했습니다';

  @override
  String get couldNotDelete => '삭제하지 못했습니다';

  @override
  String get couldNotComplete => '실행하지 못했습니다';

  @override
  String get couldNotSaveAnnouncement => '공지를 저장하지 못했습니다';

  @override
  String get couldNotSend => '보내지 못했습니다';

  @override
  String get actionFailed => '작업에 실패했습니다';

  @override
  String get couldNotSave2 => '저장하지 못했습니다';

  @override
  String get documentUpdated => '문서를 수정했습니다';

  @override
  String get couldNotAdjust => '조정하지 못했습니다';

  @override
  String get couldNotProcessReport => '신고를 처리하지 못했습니다';

  @override
  String get couldNotRecordDecision => '판정을 저장하지 못했습니다';

  @override
  String get couldNotReorder => '정렬하지 못했습니다';

  @override
  String get couldNotSaveLocker => '보관함을 저장하지 못했습니다';

  @override
  String get fingerprint => '지문';

  @override
  String get iris => '홍채';

  @override
  String get verifyIdentityContinue => '계속하려면 인증해 주세요';

  @override
  String get couldNotOpenPhotosCheckPermission => '사진을 열 수 없습니다. 권한을 확인해 주세요.';

  @override
  String get choosePhotoSource => '사진 가져올 방법 선택';

  @override
  String get takePhoto => '사진 촬영';

  @override
  String get chooseFromPhotos => '앨범에서 선택';

  @override
  String get couldNotOpenCameraCheckPermission => '카메라를 열 수 없습니다. 권한을 확인해 주세요.';

  @override
  String get justNow => '방금';

  @override
  String minAgo(Object p0) => '${p0}분 전';

  @override
  String hAgo(Object p0) => '${p0}시간 전';

  @override
  String dAgo(Object p0) => '${p0}일 전';

  @override
  String get pickDate => '날짜를 선택하세요';

  @override
  String get pickDate2 => '날짜 선택';

  @override
  String msg5(Object p0, Object p1, Object p2) => '${p0}년 ${p1}월 ${p2}일';

  @override
  String get passwordsNeedLeast8Characters => '비밀번호는 8자 이상이어야 합니다';

  @override
  String get passwordsMustIncludeLetter => '비밀번호에 영문을 포함해 주세요';

  @override
  String get passwordsMustIncludeNumber => '비밀번호에 숫자를 포함해 주세요';

  @override
  String get seller2 => '판매자: ';

  @override
  String get home => '홈';

  @override
  String get alerts => '알림';

  @override
  String get collect => '수령';

  @override
  String get couldNotLoadPhoto => '이 사진을 불러올 수 없습니다';

  @override
  String slot2(Object p0) => '보관함 ${p0}';

  @override
  String confirmPutLocker(Object p0) => '“${p0}”을(를) 보관함에 넣으셨나요?';

  @override
  String get enterTitleContent => '제목과 내용을 입력하세요';

  @override
  String get titleCannotExceed255Characters => '제목은 255자를 넘을 수 없습니다';

  @override
  String get contentNeedsLeast5Characters => '내용은 최소 5자 이상이어야 합니다';

  @override
  String get publishAnnouncement => '공지 게시';

  @override
  String get everyUserSeeAnnouncementOncePublished => '게시하면 모든 사용자에게 표시됩니다. 계속할까요?';

  @override
  String get publish => '게시';

  @override
  String get announcementPublished => '공지를 게시했습니다';

  @override
  String get draftSaved => '초안을 저장했습니다';

  @override
  String get editAnnouncement => '공지 편집';

  @override
  String get newAnnouncement => '공지 작성';

  @override
  String get title2 => '제목';

  @override
  String get announcementTitle => '공지 제목';

  @override
  String get writeAnnouncement => '공지 내용을 입력';

  @override
  String get publishNow => '즉시 게시';

  @override
  String get leaveOffSaveAsDraft => '끄면 초안으로만 저장됩니다';

  @override
  String get saveDraft => '초안 저장';

  @override
  String get deleteAnnouncement => '공지 삭제';

  @override
  String deleteP0CannotUndone(Object p0) => '"${p0}"을(를) 삭제할까요? 되돌릴 수 없습니다.';

  @override
  String get announcementDeleted => '공지를 삭제했습니다';

  @override
  String get couldNotDeleteTryAgainLater => '삭제하지 못했습니다. 잠시 후 다시 시도하세요.';

  @override
  String get announcements => '공지사항';

  @override
  String get noAnnouncementsYetTapAddOne => '공지가 없습니다. 오른쪽 위 +로 추가하세요.';

  @override
  String get published => '게시됨';

  @override
  String get draft => '초안';

  @override
  String get audienceEveryone => '대상: 전체 사용자';

  @override
  String get backUpNow => '지금 백업';

  @override
  String get wholeDatabaseExportedCompressedWithLot => '데이터베이스 전체를 내보내 압축합니다. 데이터가 많으면 수십 초가 걸릴 수 있으니 완료될 때까지 이 화면을 벗어나지 마세요.';

  @override
  String get startBackup => '백업 시작';

  @override
  String get backingUpDatabase => '데이터베이스 백업 중';

  @override
  String get backupComplete => '백업이 완료되었습니다';

  @override
  String get backupDeleted => '백업을 삭제했습니다';

  @override
  String get databaseBackups => '데이터베이스 백업';

  @override
  String backedUpDailyNewestP0Kept(Object p0) => '매일 자동 백업, 최신 ${p0} 보관';

  @override
  String get olderBackupsBeyondCountRemovedAutomatically => '보관 수를 넘은 오래된 백업은 자동으로 삭제됩니다. 백업 파일에는 사이트 전체의 개인정보가 들어 있으므로 내려받은 뒤에는 안전하게 보관하세요. 모든 다운로드는 감사 로그에 기록됩니다.';

  @override
  String get noBackupsYetSchedulerRunsOnce => '백업 기록이 없습니다. 스케줄러가 하루에 한 번 실행되며, 위 버튼으로 지금 바로 만들 수도 있습니다.';

  @override
  String get deleteBackup => '백업 삭제';

  @override
  String p0NNtheFileItsRecord(Object p0) => '${p0}\n\n파일과 기록이 함께 삭제되며 되돌릴 수 없습니다.';

  @override
  String get manual => '수동';

  @override
  String get scheduled => '예약';

  @override
  String get download => '다운로드';

  @override
  String get downloadBackup => '백업 다운로드';

  @override
  String fetchBackupComputerWithAuthorisationHeader(Object p0, Object p1) => '백업 파일은 컴퓨터에서 인증 헤더를 함께 보내 받으세요:\n\n${p0}\n\n파일 크기 ${p1}.';

  @override
  String get copyLink2 => 'URL 복사';

  @override
  String get downloadLinkCopied => '다운로드 URL을 복사했습니다';

  @override
  String get forceDelist => '강제 내리기';

  @override
  String get reasonDelistingSellerNotified => '내리는 이유 (판매자에게 전달됩니다)';

  @override
  String get delist3 => '내리기';

  @override
  String get relist2 => '다시 등록';

  @override
  String putP0BackStore(Object p0) => '"${p0}"을(를) 스토어에 다시 올릴까요?';

  @override
  String get relisted => '다시 등록했습니다';

  @override
  String get searchTitleIsbnSeller => '제목, ISBN, 판매자 검색';

  @override
  String get noBooksMatch => '조건에 맞는 책이 없습니다';

  @override
  String sellerP0P1(Object p0, Object p1) => '판매자 ${p0} | ${p1}';

  @override
  String isbnP0P1Views(Object p0, Object p1) => 'ISBN ${p0} | 조회 ${p1}';

  @override
  String p0ReportsAwaitingReview(Object p0) => '처리 대기 중인 신고 ${p0}';

  @override
  String get enterLockerNameAddress => '보관함 이름과 주소를 입력하세요';

  @override
  String get enterValidLatitudeLongitude => '올바른 위도와 경도를 입력하세요';

  @override
  String get latitudeMustBetween9090 => '위도는 -90 ~ 90 사이여야 합니다';

  @override
  String get longitudeMustBetween180180 => '경도는 -180 ~ 180 사이여야 합니다';

  @override
  String get slotCountMustBetween1100 => '칸 수는 1 ~ 100 사이여야 합니다';

  @override
  String get closingTime => '마감 시간';

  @override
  String p0MustLookLikeHhMm(Object p0) => '${p0}(는) HH:mm 형식이어야 합니다. 예: 09:00';

  @override
  String get fillBothOpeningClosingTimes => '개방 시간과 마감 시간을 모두 입력하세요';

  @override
  String get lockerUpdated => '보관함을 수정했습니다';

  @override
  String get lockerAdded => '보관함을 추가했습니다';

  @override
  String get editLocker => '보관함 편집';

  @override
  String get newLocker => '보관함 추가';

  @override
  String get lockerName => '보관함 이름';

  @override
  String get latitude => '위도';

  @override
  String get longitude => '경도';

  @override
  String get slotCount => '칸 수';

  @override
  String get createLocker => '보관함 만들기';

  @override
  String get disable => '비활성화';

  @override
  String onceDisabledP0NoLongerAppears(Object p0) => '비활성화하면 "${p0}"은(는) 판매자의 보관 위치 목록에 더 이상 표시되지 않습니다.';

  @override
  String onceEnabledP0AvailableSellersAgain(Object p0) => '활성화하면 "${p0}"을(를) 판매자가 다시 선택할 수 있습니다.';

  @override
  String get lockerDisabled => '보관함을 비활성화했습니다';

  @override
  String get lockerEnabled => '보관함을 활성화했습니다';

  @override
  String slotP0(Object p0) => '${p0} 칸';

  @override
  String get slotStatusUpdated => '칸 상태를 변경했습니다';

  @override
  String get lockerMonitor => '보관함 모니터';

  @override
  String get searchLockerNameAddress => '보관함 이름 또는 주소 검색';

  @override
  String get noLockersMatch => '조건에 맞는 보관함이 없습니다';

  @override
  String get disabled => '비활성';

  @override
  String freeSlotsP0P1(Object p0, Object p1) => '남은 칸: ${p0} / ${p1}';

  @override
  String get newCategory => '카테고리 추가';

  @override
  String get editCategory => '카테고리 편집';

  @override
  String get categoryName => '카테고리 이름';

  @override
  String get enterCategoryName => '카테고리 이름을 입력하세요';

  @override
  String get categoryAdded => '카테고리를 추가했습니다';

  @override
  String get categoryUpdated => '카테고리를 수정했습니다';

  @override
  String get deleteCategory => '카테고리 삭제';

  @override
  String deleteP0CannotUndone2(Object p0) => '"${p0}"을(를) 삭제할까요? 되돌릴 수 없습니다.';

  @override
  String get categoryDeleted => '카테고리를 삭제했습니다';

  @override
  String get categories => '카테고리 관리';

  @override
  String get noCategoriesYet => '카테고리가 없습니다';

  @override
  String p0BooksUse(Object p0) => '${p0} 사용 중';

  @override
  String get legalDocuments => '약관 및 정책';

  @override
  String get notCreatedYet => '아직 작성되지 않음';

  @override
  String updatedP0(Object p0) => '최종 수정 ${p0}';

  @override
  String p0Characters(Object p0) => '${p0}';

  @override
  String p0SectionsP1Characters(Object p0, Object p1) => '${p0} 조항 | ${p1}';

  @override
  String get deleteSection => '조항 삭제';

  @override
  String get contentsSectionRemovedWith => '이 조항의 내용도 함께 삭제됩니다.';

  @override
  String p0ItsContentsRemoved(Object p0) => '"${p0}"과(와) 그 내용이 함께 삭제됩니다.';

  @override
  String get discardChanges => '변경 사항을 버릴까요?';

  @override
  String get documentUnsavedChangesTheyLostIf => '이 문서에 저장하지 않은 변경 사항이 있습니다. 나가면 사라집니다.';

  @override
  String get discard => '버리기';

  @override
  String get keepEditing => '계속 편집';

  @override
  String get bothTitleContentRequired => '제목과 내용을 모두 입력해야 합니다';

  @override
  String sectionP0NoTitleYet(Object p0) => '${p0} 조항에 제목이 없습니다';

  @override
  String updateP0(Object p0) => '${p0}(를) 업데이트할까요?';

  @override
  String get documentBindingEveryUserSubmittingReplaces => '이 문서는 모든 사용자에게 효력이 있습니다. 제출하면 현재 버전이 즉시 대체됩니다.';

  @override
  String get yesUpdate => '업데이트합니다';

  @override
  String get notifyEveryUser => '모든 사용자에게 알릴까요?';

  @override
  String get updateNotify => '업데이트 후 알림';

  @override
  String get updateOnly => '업데이트만';

  @override
  String get sections => '조항';

  @override
  String get plainText => '일반 텍스트';

  @override
  String get preview => '미리보기';

  @override
  String get documentTitle => '문서 제목';

  @override
  String get preamble => '머리말';

  @override
  String get unnumberedOpeningTextLeaveEmptyIf => '번호를 붙이지 않는 도입부 문구입니다. 없으면 비워 두세요.';

  @override
  String get articles => '조항';

  @override
  String get numberedAutomatically => '번호는 자동으로 매겨집니다';

  @override
  String get noArticlesYetAddFirstOne => '조항이 없습니다. 아래에서 첫 번째 조항을 추가하세요.';

  @override
  String get addSection => '조항 추가';

  @override
  String get untitledSection => '제목 없는 조항';

  @override
  String get sectionTitle => '조항 제목';

  @override
  String get bodySectionSingleLineBreaksKept => '이 조항의 본문입니다. 한 번의 줄바꿈은 그대로 표시되고, 빈 줄은 문단을 나눕니다.';

  @override
  String get emptyLineStartsParagraphParagraphWhose => '빈 줄로 문단을 나눕니다. 첫 줄이 "1. 제목" 형태인 문단은 조항 모드로 돌아갈 때 하나의 조항으로 인식됩니다.';

  @override
  String get howUsersSee => '사용자에게 보이는 모습';

  @override
  String get noContentYet => '내용이 없습니다';

  @override
  String get unsaved => '저장 안 됨';

  @override
  String get upDate => '최신 상태입니다';

  @override
  String get newQuestion => '질문 추가';

  @override
  String get editQuestion => '질문 편집';

  @override
  String get question => '질문';

  @override
  String get answer => '답변';

  @override
  String get showHelpCentre => '고객센터에 표시';

  @override
  String get bothQuestionAnswerRequired => '질문과 답변을 모두 입력해야 합니다';

  @override
  String get added => '추가했습니다';

  @override
  String get updated => '수정했습니다';

  @override
  String get deleteQuestion => '질문 삭제';

  @override
  String deleteP0(Object p0) => '"${p0}"을(를) 삭제할까요?';

  @override
  String get deleted => '삭제했습니다';

  @override
  String get faq => '자주 묻는 질문';

  @override
  String get noQuestionsYet2 => '질문이 없습니다';

  @override
  String get dragHandleRightReorder => '오른쪽 손잡이를 끌어 순서를 바꿉니다';

  @override
  String get hidden => '숨김';

  @override
  String get cancelDeletionRequest => '삭제 신청 취소';

  @override
  String p0SAccountReturnsNormalCountdown(Object p0) => '${p0} 님의 계정이 정상으로 돌아가고 카운트다운이 멈춥니다.';

  @override
  String get cancelDeletion => '삭제 취소';

  @override
  String get deletionRequestCancelled => '삭제 신청을 취소했습니다';

  @override
  String get anonymiseNow => '지금 익명화';

  @override
  String eraseP0SPersonalDataDisable(Object p0) => '유예 기간이 끝나기를 기다리지 않고 ${p0} 님의 개인정보를 지우고 계정을 비활성화합니다.\n\n주문과 거래 기록은 남지만 표시 이름은 "삭제된 사용자"로 바뀝니다. 되돌릴 수 없습니다.';

  @override
  String get doNow => '지금 실행';

  @override
  String get anonymised => '익명화를 완료했습니다';

  @override
  String get pendingDeletions => '삭제 대기 계정';

  @override
  String get noDeletionRequestsPending => '처리 대기 중인 삭제 신청이 없습니다';

  @override
  String get dueSoon => '곧 실행';

  @override
  String p0DaysLeft(Object p0) => '${p0} 남음';

  @override
  String requestedP0ScheduledP1(Object p0, Object p1) => '${p0} 신청, ${p1} 실행 예정';

  @override
  String get disputeResolution => '거래 중재';

  @override
  String orderP0P1(Object p0, Object p1) => '주문 ${p0} | \\\$${p1}';

  @override
  String reasonP0(Object p0) => '이의 사유: ${p0}';

  @override
  String get decisionNoteOptional => '판정 설명 (선택)';

  @override
  String get submitDecision => '판정 제출';

  @override
  String get decisionRecorded => '판정을 기록했습니다';

  @override
  String get resolveDispute => '거래 중재';

  @override
  String get noDisputesKind => '해당 유형의 이의가 없습니다';

  @override
  String orderNumberP0(Object p0) => '주문 번호: ${p0}';

  @override
  String buyerP0SellerP1(Object p0, Object p1) => '구매자: ${p0} | 판매자: ${p1}';

  @override
  String filedByP0(Object p0) => '신청인: ${p0}';

  @override
  String get handle => '처리';

  @override
  String get transactions2 => '거래 관리';

  @override
  String get orders => '주문 관리';

  @override
  String get lookUpOrdersAdjustStatusBy => '주문 조회 및 수동 상태 변경';

  @override
  String get disputeListDecisions => '이의 목록 및 판정';

  @override
  String get listings => '상품 관리';

  @override
  String get allBooksForceDelisting => '전체 도서, 강제 내리기';

  @override
  String get moderation => '콘텐츠 심사';

  @override
  String get handleListingReports => '상품 신고 처리';

  @override
  String get addReorderDeleteBookCategories => '카테고리 추가, 정렬, 삭제';

  @override
  String get members => '회원 관리';

  @override
  String get memberControls => '회원 관리';

  @override
  String get memberListSuspensionBlocklist => '회원 목록, 정지, 차단 목록';

  @override
  String get membershipTiers => '회원 등급 관리';

  @override
  String get tierThresholdsBenefits => '등급 기준과 혜택 설정';

  @override
  String get wallets => '지갑 관리';

  @override
  String get checkBalancesAddDeductCoinsBy => '잔액 조회, 코인 수동 증감';

  @override
  String get hardwareOperations => '하드웨어 및 운영';

  @override
  String get lockerSlotStatus => '보관함 및 칸 상태';

  @override
  String get maintenanceLog => '정비 기록';

  @override
  String get lockerOperationHistory => '보관함 관련 작업 기록';

  @override
  String get reports => '운영 리포트';

  @override
  String get ordersRevenueMemberGrowth => '주문, 매출, 회원 증가';

  @override
  String get announcements2 => '공지 관리';

  @override
  String get supportEnquiries => '고객 문의';

  @override
  String get replyQuestionsFromUsers => '사용자 문의에 답변';

  @override
  String get faqShownHelpCentre => '고객센터의 자주 묻는 질문';

  @override
  String get termsPrivacyPolicyAbout => '이용약관, 개인정보 처리방침, 소개';

  @override
  String get adminAuditLog => '관리 작업 기록';

  @override
  String get auditTrailAdminChanges => '관리자 변경 감사 기록';

  @override
  String get systemOperations => '시스템 운영';

  @override
  String get dailyBackupsManualRunsDownloads => '매일 자동 백업, 수동 실행 및 다운로드';

  @override
  String get deletionRequestsInsideGracePeriodCancel => '유예 기간 중인 삭제 신청. 취소하거나 즉시 실행할 수 있습니다';

  @override
  String get members2 => '회원 수';

  @override
  String get todaySOrders => '오늘 주문';

  @override
  String get openCases => '처리 대기 건';

  @override
  String get activeLockers => '운영 중 보관함';

  @override
  String get newTier => '등급 추가';

  @override
  String get editTier => '등급 편집';

  @override
  String get tierName => '등급 이름';

  @override
  String get minimumPoints => '최소 포인트';

  @override
  String get maximumPointsLeaveEmptyNoCap => '최대 포인트 (비우면 상한 없음)';

  @override
  String get benefitsSeparatedByCommasLineBreaks => '혜택. 쉼표나 줄바꿈으로 구분하면 회원 등급 페이지에 하나씩 표시됩니다';

  @override
  String get enterTierName => '등급 이름을 입력하세요';

  @override
  String get maximumPointsMustExceedMinimum => '최대 포인트는 최소 포인트보다 커야 합니다';

  @override
  String get tierAdded => '등급을 추가했습니다';

  @override
  String get tierUpdated => '등급을 수정했습니다';

  @override
  String get deleteTier => '등급 삭제';

  @override
  String deleteP0MembersTierDropNext(Object p0) => '"${p0}"을(를) 삭제할까요? 이 등급의 회원은 조건에 맞는 다음 등급으로 내려갑니다.';

  @override
  String get tierDeleted => '등급을 삭제했습니다';

  @override
  String get noMembershipTiersSetUp => '회원 등급이 설정되지 않았습니다';

  @override
  String p0PointsUp(Object p0) => '${p0} 이상';

  @override
  String p0P1Points(Object p0, Object p1) => '${p0} ~ ${p1}';

  @override
  String get noBenefitsDescribedYet => '혜택 설명이 없습니다';

  @override
  String get noMaintenanceRecords => '정비 기록이 없습니다';

  @override
  String get noFurtherDetail => '(추가 설명 없음)';

  @override
  String get operator => '작업자';

  @override
  String get unknown => '(알 수 없음)';

  @override
  String get time => '시각';

  @override
  String get recordNumber => '기록 번호';

  @override
  String operatorP0(Object p0) => '작업자: ${p0}';

  @override
  String get suspendAccount => '이 계정 정지';

  @override
  String get reinstateAccount => '이 계정 복구';

  @override
  String get addBlocklist => '차단 목록에 추가';

  @override
  String get removeFromBlocklist => '차단 목록에서 제거';

  @override
  String p0SignedOutImmediatelyCanNo(Object p0) => '${p0} 님은 즉시 로그아웃되며 앱의 어떤 기능도 사용할 수 없습니다.';

  @override
  String p0AbleSignAgain(Object p0) => '${p0} 님은 다시 로그인할 수 있습니다.';

  @override
  String get accountStatusUpdated => '계정 상태를 변경했습니다';

  @override
  String get removeAdmin => '관리자 해제';

  @override
  String get makeAdmin => '관리자로 지정';

  @override
  String p0LosesEveryAdminPermissionImmediately(Object p0) => '${p0} 님은 모든 관리자 권한을 즉시 잃습니다.';

  @override
  String p0GainsAccessAdminAreaWith(Object p0) => '${p0} 님이 관리자 화면에 접근할 수 있게 되며, 기본적으로 모든 권한을 가집니다. 이후 항목별로 조정할 수 있습니다.';

  @override
  String get roleUpdated => '역할을 변경했습니다';

  @override
  String manualP0P1(Object p0, Object p1) => ', 수동 ${p0}${p1}';

  @override
  String get adjustMembershipTier => '회원 등급 조정';

  @override
  String currentlyP0PointsAutomaticP1P2(Object p0, Object p1, Object p2) => '현재 ${p0} (자동 ${p1}${p2})';

  @override
  String p0P1Points2(Object p0, Object p1) => '${p0} (${p1})';

  @override
  String get adjustPointsManually => '포인트 수동 조정';

  @override
  String get backAutomatic => '자동 계산으로 되돌리기';

  @override
  String get backAutomatic2 => '자동 계산으로 되돌렸습니다';

  @override
  String get pointAdjustment => '포인트 증감';

  @override
  String get positiveAddsNegativeDeductsEG => '양수는 추가, 음수는 차감. 예: -50';

  @override
  String get apply => '적용';

  @override
  String get enterNonZeroWholeNumber => '0이 아닌 정수를 입력하세요';

  @override
  String get pointsAdjusted => '포인트를 조정했습니다';

  @override
  String get tierAdjusted => '등급을 조정했습니다';

  @override
  String get permissionGranted => '권한을 부여했습니다';

  @override
  String get permissionRevoked => '권한을 회수했습니다';

  @override
  String get grantAllPermissions => '모든 권한 부여';

  @override
  String get revokeAllPermissions => '모든 권한 회수';

  @override
  String p0AbleUseEveryAdminFeature(Object p0) => '${p0} 님이 관리자 화면의 모든 기능을 사용할 수 있게 됩니다.';

  @override
  String p0ReachAdminAreaButUnable(Object p0) => '${p0} 님은 관리자 화면에 들어가도 아무 기능도 사용할 수 없습니다.';

  @override
  String get allPermissionsGranted => '모든 권한을 부여했습니다';

  @override
  String get allPermissionsRevoked => '모든 권한을 회수했습니다';

  @override
  String get memberSettings => '회원 설정';

  @override
  String get noDataMember => '이 회원의 데이터를 찾을 수 없습니다';

  @override
  String get listings2 => '등록 도서';

  @override
  String get completedTrades => '완료 거래';

  @override
  String get joined => '가입일';

  @override
  String get accountStatus => '계정 상태';

  @override
  String get ownAccountStatusPermissionsCannotChanged => '본인 계정입니다. 여기서는 상태와 권한을 변경할 수 없습니다.';

  @override
  String get accountEnabled => '계정 활성';

  @override
  String get canSignUseAppNormally => '정상적으로 로그인해 사용할 수 있습니다';

  @override
  String get suspendedSignedOutImmediatelyAfterSigning => '정지됨. 로그인해도 즉시 로그아웃됩니다';

  @override
  String get blocked => '차단됨';

  @override
  String get blockedNoFeaturesAvailable => '차단되어 어떤 기능도 사용할 수 없습니다';

  @override
  String get notBlocked => '차단 안 됨';

  @override
  String get role => '역할';

  @override
  String p0PointsAutomaticP1P2(Object p0, Object p1, Object p2) => '${p0} (자동 ${p1}${p2})';

  @override
  String get memberSTierBeenAdjustedBy => '이 회원의 등급은 수동으로 조정되어 거래만으로 자동 계산되지 않습니다.';

  @override
  String get adjustTier => '등급 조정';

  @override
  String get adminPermissions => '관리자 권한';

  @override
  String get all => '모두 켜기';

  @override
  String get allOff => '모두 끄기';

  @override
  String get reinstateAccount2 => '계정 복구';

  @override
  String get suspendAccount2 => '계정 정지';

  @override
  String runP1P0(Object p0, Object p1) => '"${p0}"에 대해 "${p1}"을(를) 실행할까요?';

  @override
  String updatedP0SStatus(Object p0) => '${p0} 님의 상태를 변경했습니다';

  @override
  String get fullSettingsTierPermissions => '전체 설정 (등급, 권한)';

  @override
  String get members3 => '회원 목록';

  @override
  String get searchDisplayNameEmail => '닉네임 또는 이메일 검색';

  @override
  String get noMembersMatch => '조건에 맞는 회원이 없습니다';

  @override
  String get sales2 => '판매';

  @override
  String get created => '생성일';

  @override
  String get noActivityYet => '작업 기록이 없습니다';

  @override
  String get changeOrderStatus => '주문 상태 변경';

  @override
  String orderP0(Object p0) => '주문 ${p0}';

  @override
  String get reasonChange => '변경 사유';

  @override
  String get sentBuyerAsWellOptional => '구매자에게도 전달됩니다 (선택)';

  @override
  String get applyChange => '변경 확정';

  @override
  String get orderStatusUpdated => '주문 상태를 변경했습니다';

  @override
  String get searchOrderNumberBuyerSeller => '주문 번호, 구매자, 판매자 검색';

  @override
  String get noOrdersMatch => '조건에 맞는 주문이 없습니다';

  @override
  String get noItems => '(항목 없음)';

  @override
  String p0ItemsTotal(Object p0) => '외 총 ${p0}';

  @override
  String buyerP0SellerP12(Object p0, Object p1) => '구매자 ${p0} | 판매자 ${p1}';

  @override
  String lockerP0(Object p0) => '보관함: ${p0}';

  @override
  String cancellationReasonP0(Object p0) => '취소 사유: ${p0}';

  @override
  String get reviewReport => '신고 심사';

  @override
  String reportedP0P1(Object p0, Object p1) => '신고된 ${p0}: ${p1}';

  @override
  String reasonP02(Object p0) => '위반 사유: ${p0}';

  @override
  String get handlingNoteOptional => '처리 메모 (선택)';

  @override
  String get delistListingAsWell => '해당 상품도 함께 내리기';

  @override
  String get dismissReport => '신고 기각';

  @override
  String get reportHandled => '신고를 처리했습니다';

  @override
  String get noReportsKind => '해당 유형의 신고가 없습니다';

  @override
  String reportedByP0(Object p0) => '신고자: ${p0}';

  @override
  String get review => '심사';

  @override
  String noteP0(Object p0) => '메모: ${p0}';

  @override
  String get last7Days => '최근 7일';

  @override
  String get last30Days => '최근 30일';

  @override
  String get ordersPerDay => '일별 주문 수';

  @override
  String get revenuePerDay => '일별 거래 금액';

  @override
  String get newMembersPerDay => '일별 신규 회원';

  @override
  String get newOrders => '신규 주문';

  @override
  String get newMembers => '신규 회원';

  @override
  String get newListings => '신규 등록 도서';

  @override
  String get completedRevenue => '완료 거래액';

  @override
  String p0Orders(Object p0) => '${p0}';

  @override
  String peakP0(Object p0) => '최고 ${p0}';

  @override
  String get topCategoriesByListings => '인기 카테고리 (등록 수 기준)';

  @override
  String get replied => '답변함';

  @override
  String get noEnquiriesCategory => '이 분류에 문의가 없습니다';

  @override
  String get addCoins => '코인 추가';

  @override
  String get deductCoins => '코인 차감';

  @override
  String get amountPositiveWholeNumber => '금액 (양의 정수)';

  @override
  String get reasonAdjustmentRequired => '조정 사유 (필수)';

  @override
  String get add2 => '추가';

  @override
  String get deduct => '차감';

  @override
  String get enterAmountGreaterThan0 => '0보다 큰 금액을 입력하세요';

  @override
  String get enterReasonAdjustment => '조정 사유를 입력하세요';

  @override
  String get member2 => '이 회원';

  @override
  String get add3 => '추가';

  @override
  String get deduct2 => '차감';

  @override
  String get confirmAddingCoins => '코인 추가 확인';

  @override
  String get confirmDeductingCoins => '코인 차감 확인';

  @override
  String p1P2CoinsP0NreasonP3(Object p0, Object p1, Object p2, Object p3) => '${p0} 님에게 ${p1} ${p2}.\n사유: ${p3}';

  @override
  String get balanceAdjusted => '잔액을 조정했습니다';

  @override
  String get memberWallets => '회원 지갑';

  @override
  String get transactions3 => '거래 내역';

  @override
  String get memberNoTransactionsYet => '이 회원의 거래 내역이 아직 없습니다.';

  @override
  String get balanceCoins => '현재 잔액 (코인)';

  @override
  String get hold2 => '보류 중';

  @override
  String get total2 => '누적 수입';

  @override
  String get totalOut => '누적 지출';

  @override
  String balanceP0(Object p0) => '잔액 ${p0}';

  @override
  String get suspensionBlocklistRoles => '정지, 차단 목록, 역할';

  @override
  String get tierThresholdsManualAdjustments => '등급 기준과 수동 조정';

  @override
  String get booksCategories => '도서와 카테고리';

  @override
  String get reportReview => '신고 심사';

  @override
  String get handleListingReports2 => '상품 신고 처리';

  @override
  String get lookUpChangeOrderStatus => '주문 조회 및 상태 변경';

  @override
  String get decideDisputeCases => '이의 사건 판정';

  @override
  String get checkAdjustCoinBalances => '코인 조회 및 증감';

  @override
  String get hardware => '하드웨어 유지보수';

  @override
  String get lockersSlots => '보관함과 칸';

  @override
  String get announcementsDocuments => '공지와 문서';

  @override
  String get announcementsFaqLegalDocuments => '공지, 자주 묻는 질문, 약관';

  @override
  String get replyUserQuestions => '사용자 질문에 답변';

  @override
  String get databaseBackupDownloadOffByDefault => '데이터베이스 백업 및 다운로드, 기본값은 꺼짐';

  @override
  String p0Locker(Object p0) => '보관함 ${p0}';

  @override
  String everyActiveMemberReceivesP0Updated(Object p0) => '활성 회원 전원에게 "${p0}이(가) 업데이트되었습니다" 알림이 전송됩니다.';

  @override
  String get orderPlaced => '주문 생성';

  @override
  String get paid => '결제';

  @override
  String get sellerDroppedOff => '판매자 보관';

  @override
  String get buyerCollected => '구매자 수령';

  @override
  String get completed => '완료';

  @override
  String get editBookDetails => '도서 정보 편집';

  @override
  String sellerP0TheyNotifiedSave(Object p0) => '판매자 ${p0} · 저장하면 알림이 갑니다';

  @override
  String get priceCoins => '가격 (코인)';

  @override
  String get k1013Digits2 => '10자리 또는 13자리';

  @override
  String get category => '카테고리';

  @override
  String get description2 => '상품 설명';

  @override
  String get titleRequired => '제목은 필수입니다';

  @override
  String get nothingChanged => '변경 사항이 없습니다';

  @override
  String get resetPassword => '비밀번호 재설정';

  @override
  String p0SCurrentPasswordStopsWorking(Object p0) => '${p0} 님의 현재 비밀번호는 즉시 사용할 수 없게 되며, 다음에 발급되는 임시 비밀번호로 로그인해야 합니다.\n\n비밀번호는 시스템이 생성하며 직접 지정할 수 없습니다.';

  @override
  String get generateTemporaryPassword => '임시 비밀번호 발급';

  @override
  String get temporaryPassword => '임시 비밀번호';

  @override
  String p0SPasswordBeenResetPassword(Object p0) => '${p0} 님의 비밀번호를 재설정했습니다. 이 비밀번호는 한 번만 표시되며 닫으면 다시 볼 수 없습니다.';

  @override
  String get remindThemChangeSettingsChangePassword => '로그인 후 바로 설정 → 비밀번호 변경에서 바꾸도록 안내하세요.';

  @override
  String get temporaryPasswordCopied => '임시 비밀번호를 복사했습니다';

  @override
  String get copy => '복사';

  @override
  String get cannotResetAnotherAdminSPassword => '다른 관리자의 비밀번호는 재설정할 수 없습니다';

  @override
  String get generateTemporaryPasswordHandOver => '임시 비밀번호를 발급해 전달합니다';

  @override
  String get orderNumberCopied => '주문 번호를 복사했습니다';

  @override
  String get orderNotFound => '주문을 찾을 수 없습니다';

  @override
  String get paidWithCoins => '코인 결제';

  @override
  String get bankTransfer => '계좌 이체';

  @override
  String get notPaidYet => '미결제';

  @override
  String get progress => '진행 상황';

  @override
  String get notYet => '아직 아님';

  @override
  String get buyerSeller => '거래 당사자';

  @override
  String get items3 => '항목';

  @override
  String get bookDeleted => '(삭제된 도서)';

  @override
  String get notAssignedYet2 => '미배정';

  @override
  String get pickupCodeCopied => '수령 코드를 복사했습니다';

  @override
  String get walletActivity => '지갑 변동';

  @override
  String balanceP02(Object p0) => '잔액 ${p0}';

  @override
  String get refunds => '환불 기록';

  @override
  String requestedP0NotProcessedYet(Object p0) => '${p0} 신청, 미처리';

  @override
  String processedP0(Object p0) => '${p0} 처리';

  @override
  String get disputes => '이의 제기';

  @override
  String filedP0(Object p0) => '${p0} 신청';

  @override
  String decidedP0(Object p0) => '${p0} 판정';

  @override
  String createdP0(Object p0) => '${p0} 생성';

  @override
  String get shareBook => '이 책 공유';

  @override
  String get shareAnotherApp => '다른 앱으로 공유';

  @override
  String get approved => '승인됨';

  @override
  String get awaitingRefund => '환불 대기';

  @override
  String get declined => '환불 거절';

  @override
  String get changeOwnPasswordGoSettingsChange => '본인 비밀번호는 설정 → 비밀번호 변경에서 바꾸세요';

  @override
  String get memberNotAdminSoThereNo => '이 회원은 관리자가 아니므로 설정할 관리자 권한이 없습니다. 위에서 역할을 관리자로 먼저 변경하세요.';

  @override
  String get you => '본인';

  @override
  String isbnMust1013DigitsOne(Object p0) => 'ISBN은 10자리 또는 13자리여야 합니다. 현재 ${p0}자리입니다';

  @override
  String get screenUnsavedChangesTheyLostIf => '이 화면에 저장하지 않은 변경 사항이 있습니다. 나가면 사라집니다.';

  @override
  String stillNeededP0(Object p0) => '남은 항목: ${p0}';

  @override
  String photosP0(Object p0) => '사진: ${p0}장';

  @override
  String get confirmListing => '등록 확인';

  @override
  String get lookingUpBook => '도서 정보 조회 중';

  @override
  String get scan => '스캔';

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

  @override
  String get verifySignSavemybook => '驗證身分以登入 SaveMyBook';

  @override
  String get maintenance => '系統維護';

  @override
  String get promotions => '活動優惠';

  @override
  String get policyUpdate => '政策更新';

  @override
  String get announcement => '一般公告';

  @override
  String get item => '商品';

  @override
  String get member => '會員';

  @override
  String get message => '訊息';

  @override
  String get noLongerExists => '(對象已不存在)';

  @override
  String get uncategorised => '未分類';

  @override
  String get general => '一般書籍';

  @override
  String get untitled => '無書名';

  @override
  String get noDescriptionYet => '暫無簡介';

  @override
  String get locationNotProvided => '地點未提供';

  @override
  String seller3(Object p0) => '賣家：${p0}';

  @override
  String get unknownAuthor => '未知作者';

  @override
  String get unknownPublisher => '未知出版社';

  @override
  String get noIsbn => '未提供 ISBN';

  @override
  String get user => '使用者';

  @override
  String get noMessagesYet => '尚無訊息';

  @override
  String get photo => '[圖片]';

  @override
  String item2(Object p0) => '[商品] ${p0}';

  @override
  String get purchase => '購買';

  @override
  String get sale => '賣出';

  @override
  String get systemAdjustment => '系統調整';

  @override
  String get preparingData => '正在整理您的資料';

  @override
  String get mySavemybookData => '我的 SaveMyBook 資料';

  @override
  String get exportedChooseWhereSave => '已匯出，請選擇儲存位置';

  @override
  String get exportedButSharingCouldNotOpen => '匯出完成，但無法開啟分享';

  @override
  String get regenerateShareLink => '重新產生分享連結';

  @override
  String get oldLinkQrCodeStopWorking => '舊的連結與 QR Code 會立即失效，已經分享出去的人將無法再開啟。確定要重新產生嗎？';

  @override
  String get regenerate => '重新產生';

  @override
  String get newLinkCreatedOldOneNo => '已產生新連結，舊連結已失效';

  @override
  String get deleteAccount => '刪除帳號';

  @override
  String get accountPermanentlyDisabled30DaysSign => '帳號將在 30 天後永久停用，期間內重新登入即可取消。\n\n';

  @override
  String get personalDataErasedButCompletedOrders => '停用後個人資料會被清除，但已完成的訂單與交易紀錄會保留，';

  @override
  String get peopleTradedWithDoNotLose => '交易對象的紀錄才不會出現缺漏。';

  @override
  String get actionContinue => '繼續';

  @override
  String get verify => '確認身分';

  @override
  String get enterPasswordConfirm => '請輸入密碼以確認這是本人的操作。';

  @override
  String get password => '密碼';

  @override
  String get requestDeletion => '申請刪除';

  @override
  String get receivedSignAgainWithin30Days => '已受理，30 天內重新登入即可取消';

  @override
  String get deletionCancelledAccountActiveAgain => '已取消刪除，帳號恢復正常';

  @override
  String get account => '帳號管理';

  @override
  String get data => '你的資料';

  @override
  String get exportMyData => '匯出我的資料';

  @override
  String get profileBooksOrdersTransactionsJson => '個人檔案、書籍、訂單與交易紀錄，JSON 格式';

  @override
  String get oldLinkQrCodeStopWorking2 => '舊的連結與 QR Code 會立即失效';

  @override
  String get cancelAccountDeletion => '取消刪除帳號';

  @override
  String get restoreAccountStopCountdown => '恢復帳號，停止刪除倒數';

  @override
  String get canChangeMindWithin30Days => '30 天緩衝期內可以反悔';

  @override
  String get deletionPending => '刪除倒數中';

  @override
  String daysLeftCanCancelAnyTime(Object p0) => '還有 ${p0} 天。在這之前隨時可以取消，逾期後個人資料將被清除且無法復原。';

  @override
  String get signOut => '登出';

  @override
  String get type => '類型';

  @override
  String get content => '內容';

  @override
  String get backupFailed => '備份失敗';

  @override
  String get myBooks => '書籍管理';

  @override
  String get notProvided => '未提供';

  @override
  String get openingHours => '開放時間';

  @override
  String get address => '地址';

  @override
  String get saveChanges => '儲存變更';

  @override
  String get enable => '啟用';

  @override
  String get termsService => '服務條款';

  @override
  String get privacyPolicy => '隱私權政策';

  @override
  String get aboutUs => '關於我們';

  @override
  String get admin => '管理後台';

  @override
  String get confirm => '確認';

  @override
  String get membershipTier => '會員等級';

  @override
  String get phone => '電話';

  @override
  String get violationConfirmed => '違規成立';

  @override
  String get scanBarcode => '掃描條碼';

  @override
  String get lineUpBarcodeSpineWithFrame => '請將書背條碼對準框內';

  @override
  String get signAddItemsCart => '請先登入才能加入購物車';

  @override
  String bookCannotPurchased(Object p0) => '這本書目前${p0}，無法購買';

  @override
  String get addedCart => '已加入購物車';

  @override
  String get sellerInformationNotFound => '找不到賣家資訊';

  @override
  String get signContactSeller => '請先登入才能聯絡賣家';

  @override
  String get signStartChat => '無法建立聊天室，請先登入';

  @override
  String get signReport => '請先登入才能檢舉';

  @override
  String get cannotReportOwnListing => '無法檢舉自己上架的商品';

  @override
  String get reportListing => '檢舉此商品';

  @override
  String get describeProblemLeast5Characters => '請說明違規原因（至少 5 個字）';

  @override
  String get reasonNeedsLeast5Characters => '請至少填寫 5 個字的檢舉原因';

  @override
  String get reportSubmittedWeLookInto => '檢舉已送出，我們會盡快處理';

  @override
  String get publisher => '出版社：';

  @override
  String get author => '作者：';

  @override
  String get listed => '上架日期：';

  @override
  String get searchTitleAuthorPublisher => '搜尋書名、作者、出版社...';

  @override
  String get share => '分享';

  @override
  String get report => '檢舉';

  @override
  String get about => '簡介：';

  @override
  String pickup(Object p0) => '取書地點：${p0}';

  @override
  String get messageSeller => '與賣家聊聊';

  @override
  String get listing => '這是你的書';

  @override
  String get addCart => '加入購物車';

  @override
  String get bookBeenReportedUnderReviewStays => '這本書被檢舉，平台正在審核，期間仍可正常販售。';

  @override
  String get violationWasConfirmedBookPleaseCheck => '這本書經審核違規成立，請確認商品內容是否符合社群規範。';

  @override
  String get reportDismissed2 => '檢舉已駁回';

  @override
  String get bookWasReportedButNoViolation => '這本書曾被檢舉，經審核未違規，不影響上架。';

  @override
  String get delist => '取消上架';

  @override
  String removedFromShopBuyersNoLonger(Object p0) => '《${p0}》將從商城下架，買家不會再看到它。';

  @override
  String get delist2 => '下架';

  @override
  String get delistedRelistFromDelistedTab => '已下架，可在「已下架」分頁重新上架';

  @override
  String get couldNotDelistPleaseTryAgain => '下架失敗，請稍後再試';

  @override
  String listedAgain(Object p0) => '《${p0}》已重新上架';

  @override
  String get notListedAnyBooksYet => '你還沒有上架任何書籍';

  @override
  String get noBooksCategory => '這個分類目前沒有書籍';

  @override
  String get listFirstBook => '去上架第一本書';

  @override
  String get relist => '重新上架';

  @override
  String get removeFromCart => '移出購物車';

  @override
  String removeFromCart2(Object p0) => '要把《${p0}》從購物車移除嗎？';

  @override
  String get remove => '移除';

  @override
  String get couldNotRemoveRestored => '移除失敗，已還原';

  @override
  String get couldNotRemovePleaseTryAgain => '移除失敗，請稍後再試';

  @override
  String get selectBooksWantCheckOut => '請先選擇要結帳的書籍';

  @override
  String notEnoughCoinsOrderNeedsBut(Object p0, Object p1) => '代幣不足，這筆訂單需要 ${p0}，目前只有 ${p1}';

  @override
  String get confirmCheckout => '確認結帳';

  @override
  String booksTotal(Object p0, Object p1) => '共 ${p0} 本書，總金額 \\\$${p1}。\n';

  @override
  String balanceAfterPaymentCoins(Object p0) => '扣款後餘額為 ${p0} 代幣。';

  @override
  String get orderPlacedSellerDropBookOff => '結帳成功，請等待賣家存書';

  @override
  String get cart => '購物車';

  @override
  String get cartEmpty => '購物車是空的';

  @override
  String get selectAll => '全選';

  @override
  String items(Object p0) => '${p0} 件商品';

  @override
  String get deselect => '取消選取';

  @override
  String get select => '選取';

  @override
  String coinsShort(Object p0) => '還差 ${p0} 代幣';

  @override
  String get total => '合計';

  @override
  String selected(Object p0) => '${p0} 件';

  @override
  String balance2(Object p0) => '餘額 ${p0}';

  @override
  String get selectBookFirst => '請先選書';

  @override
  String get checkOut => '結帳';

  @override
  String get notEnoughCoins => '代幣不足';

  @override
  String get weak => '偏弱';

  @override
  String get fair => '普通';

  @override
  String get strong => '很強';

  @override
  String get enterCurrentPassword => '請輸入目前密碼';

  @override
  String get enterNewPassword => '請輸入新密碼';

  @override
  String get newPasswordMustDifferent => '新密碼不可與目前密碼相同';

  @override
  String get enterNewPasswordAgain => '請再輸入一次新密碼';

  @override
  String get passwordsDoNotMatch => '兩次輸入的新密碼不一致';

  @override
  String get passwordUpdated => '密碼已更新';

  @override
  String get changePassword => '更改密碼';

  @override
  String get useLeast8CharactersWithBoth => '密碼需要至少 8 碼，並同時包含英文與數字。';

  @override
  String get currentPassword => '目前密碼';

  @override
  String get newPassword => '新密碼';

  @override
  String get confirmNewPassword => '確認新密碼';

  @override
  String get updatePassword => '更新密碼';

  @override
  String get deleteChat => '刪除聊天室';

  @override
  String allMessagesWithDeletedBothCannot(Object p0) => '會一併刪除與 ${p0} 的所有訊息，雙方都看不到了。此動作無法復原。';

  @override
  String get chatDeleted => '已刪除聊天室';

  @override
  String get couldNotDeleteRestored => '刪除失敗，已還原';

  @override
  String get chatMuted => '已靜音這個聊天室';

  @override
  String get chatUnmuted => '已取消靜音';

  @override
  String get noUnreadMessages => '沒有未讀訊息';

  @override
  String get markAllAsRead => '全部標為已讀';

  @override
  String markAllUnreadMessagesAsRead(Object p0) => '要把 ${p0} 則未讀訊息全部標為已讀嗎？此動作無法復原。';

  @override
  String get markAllRead => '全部已讀';

  @override
  String get allMarkedAsRead => '已全部標為已讀';

  @override
  String get somethingWentWrongPleaseTryAgain => '操作失敗，請稍後再試';

  @override
  String get chats => '聊天室';

  @override
  String get noConversationsYet => '還沒有任何對話';

  @override
  String get unmute => '取消靜音';

  @override
  String get mute => '靜音';

  @override
  String get messagesLimited500Characters => '訊息長度不可超過 500 字';

  @override
  String get messageCouldNotSent => '訊息傳送失敗';

  @override
  String get chat => '聊天';

  @override
  String get sendFirstMessage => '開始你們的第一則訊息吧';

  @override
  String get messageCopied => '已複製訊息';

  @override
  String get iQuestionAboutBook => '想詢問這本書';

  @override
  String get bookNoLongerListed => '這本書已經下架了';

  @override
  String get writeMessage => '輸入訊息…';

  @override
  String get enterOrderNumberDisputing => '請填寫要申訴的訂單編號';

  @override
  String get describeDispute => '請填寫爭議說明';

  @override
  String get useLeast10CharactersSoSupport => '爭議說明請至少填寫 10 個字，方便客服判斷';

  @override
  String get submitDispute => '送出爭議申請';

  @override
  String get orderEntersDisputeProcessPaymentSeller => '送出後這筆訂單會進入申訴流程，款項會暫停撥給賣家，直到客服裁決。';

  @override
  String paymentHoldRequested(Object p0) => '[申請凍結款項] ${p0}';

  @override
  String get disputeSubmittedSupportContact => '爭議申請已送出，客服會盡快與你聯繫';

  @override
  String get dispute => '爭議處理';

  @override
  String get requestPaymentHold => '申請凍結款項';

  @override
  String get paymentSellerHeldUntilSupportDecides => '送出後款項會暫停撥給賣家，直到客服裁決';

  @override
  String get submitDispute2 => '提交爭議申請';

  @override
  String get orderNumber => '訂單編號';

  @override
  String get eGSmb20260910123456789 => '例如 SMB20260910123456789';

  @override
  String get whatHappened => '爭議說明';

  @override
  String get describeProblemEGConditionDoes => '請描述發生的問題，例如書況與商品描述不符…';

  @override
  String get submit => '送出申請';

  @override
  String get uploadPhotos => '上傳圖片';

  @override
  String get canAttachUp6Photos => '最多只能上傳 6 張佐證照片';

  @override
  String get up5 => '最多 5 張';

  @override
  String get couldNotReplacePhotoPleaseTry => '無法替換原本的照片，請稍後再試';

  @override
  String get keepLeastOnePhoto => '至少要保留一張照片';

  @override
  String get photoDeleted => '已刪除照片';

  @override
  String get couldNotDeletePhotoPleaseTry => '刪除圖片失敗，請稍後再試';

  @override
  String get canUp10Photos => '最多只能有 10 張照片';

  @override
  String get deletePhoto => '刪除照片';

  @override
  String get cannotUndoneContinue => '刪除後無法復原，確定嗎？';

  @override
  String get photoMissingDataRefreshTryAgain => '這張照片的資料不完整，請重新整理後再試';

  @override
  String get enterPrice => '請填寫價格';

  @override
  String get priceMustGreaterThan0 => '價格必須大於 0';

  @override
  String get priceCannotExceed999999 => '價格不可超過 999,999';

  @override
  String get chooseLockerLocation => '請選擇存放區域';

  @override
  String missingTheseThreeRequired(Object p0) => '還缺少：${p0}，這三張是必填的';

  @override
  String get bookUpdated => '書籍已更新';

  @override
  String get editBook => '編輯書籍';

  @override
  String get condition => '書況';

  @override
  String get customPrice => '自訂價格';

  @override
  String get enterPrice2 => '請輸入售價';

  @override
  String get lockerLocation => '存放區域';

  @override
  String get chooseLocker => '請選擇書櫃';

  @override
  String get bookPhotos => '書籍照片';

  @override
  String get morePhotos => '補充照片';

  @override
  String get add => '加入';

  @override
  String get enterTitle => '請填寫書名';

  @override
  String get titleLimited255Characters => '書名不可超過 255 個字元';

  @override
  String get isbn1013Digits => 'ISBN 應為 10 碼或 13 碼';

  @override
  String get chooseCategory => '請選擇書籍分類';

  @override
  String get k1013Digits => '10 或 13 碼';

  @override
  String get title => '書名';

  @override
  String get actionRequired => '必填';

  @override
  String get author2 => '作者';

  @override
  String get optional => '選填';

  @override
  String get publisher2 => '出版社';

  @override
  String get publicationDate => '出版日期';

  @override
  String get tapPickPublicationDate => '點擊選擇出版日期';

  @override
  String get pickPublicationDate => '選擇出版日期';

  @override
  String get pickCategory => '選擇分類';

  @override
  String get next => '下一步';

  @override
  String get uploading => '上傳中…';

  @override
  String get profilePhotoUpdated => '頭像已更新';

  @override
  String get couldNotUploadPhoto => '頭像上傳失敗';

  @override
  String get changeDisplayName => '修改暱稱';

  @override
  String get enterDisplayName => '請輸入暱稱';

  @override
  String get displayNameCannotBlank => '暱稱不可空白';

  @override
  String get displayNames250Characters => '暱稱長度需介於 2 ~ 50 個字元';

  @override
  String get invalidPhoneNumberEG0912345678 => '電話格式不正確，例：0912345678';

  @override
  String get profileUpdated => '個人檔案已更新';

  @override
  String get editProfile => '編輯個人檔案';

  @override
  String get bio => '個人簡介';

  @override
  String get tellPeopleAboutYourself => '介紹一下自己吧';

  @override
  String get email => '信箱';

  @override
  String get emailCannotChanged => '信箱無法修改';

  @override
  String get dateBirth => '生日';

  @override
  String get tapPickDateBirth => '點擊選擇生日';

  @override
  String get pickDateBirth => '選擇生日';

  @override
  String get savedBooks => '收藏書籍';

  @override
  String get notSavedAnyBooksYet => '還沒有收藏任何書籍';

  @override
  String get helpCentre => '幫助中心';

  @override
  String get searchQuestions => '搜尋問題';

  @override
  String get noQuestionsYet => '目前還沒有常見問題';

  @override
  String get noMatchingQuestions => '找不到相關問題';

  @override
  String get newest => '最新上架';

  @override
  String get popular => '熱門推薦';

  @override
  String get priceLowHigh => '價格由低到高';

  @override
  String get priceHighLow => '價格由高到低';

  @override
  String get reachedEnd => '您已滑到底部';

  @override
  String get guest => '訪客';

  @override
  String hi(Object p0) => '哈囉, ${p0}';

  @override
  String get noBooksMatchFilters => '目前沒有符合條件的書籍';

  @override
  String get couldNotReadPhoto => '無法讀取這張照片';

  @override
  String get croppingFailedPleaseTryAgain => '裁切失敗，請再試一次';

  @override
  String get adjustPhoto => '調整照片';

  @override
  String get reset => '重設';

  @override
  String get usePhoto => '使用這張';

  @override
  String get documentNotBeenCreatedYet => '這份文件尚未建立';

  @override
  String lastUpdated(Object p0) => '最後更新：${p0}';

  @override
  String get biometrics => '生物辨識';

  @override
  String get sessionExpiredPleaseEnterPasswordAgain => '登入資訊已失效，請重新輸入密碼';

  @override
  String turnSign(Object p0) => '啟用 ${p0} 登入？';

  @override
  String nextTimeOpenAppCanUnlock(Object p0) => '下次開啟 App 就能直接用 ${p0} 解鎖，不用再輸入密碼。';

  @override
  String get notNow => '暫時不要';

  @override
  String get enterEmail => '請輸入 Email';

  @override
  String get emailAddressNotValid => 'Email 格式不正確';

  @override
  String get enterPassword => '請輸入密碼';

  @override
  String get noAccountWithEmail => '此帳號尚未註冊';

  @override
  String noAccountCreateOneNow(Object p0) => '找不到「${p0}」這個帳號。要現在建立一個嗎？';

  @override
  String get signUp => '前往註冊';

  @override
  String get tryAgain => '重新輸入';

  @override
  String get sign => '登入';

  @override
  String signWith(Object p0) => '使用 ${p0} 登入';

  @override
  String get noAccountYetSignUp => '還沒有帳號？立即註冊';

  @override
  String get membershipTiersNotSetUpYet => '尚未設定會員等級制度';

  @override
  String get currentTier => '您目前的級別';

  @override
  String get unlocked => '已解鎖';

  @override
  String get locked => '尚未解鎖';

  @override
  String get aboveTier => '您已高於此級別';

  @override
  String get reachedTopTier => '您已達到最高級別';

  @override
  String unlocked2(Object p0) => '已解鎖「${p0}」';

  @override
  String morePointsUnlock(Object p0, Object p1) => '再 ${p0} 點即可解鎖「${p1}」';

  @override
  String benefits(Object p0) => '${p0}級別獎勵';

  @override
  String get noBenefitsBeenDescribedTierYet => '尚未設定此等級的權益說明。';

  @override
  String pointsFromCompletedOrders(Object p0, Object p1) => '目前累積 ${p0} 點，已完成 ${p1} 筆交易';

  @override
  String get noNotificationsClear => '沒有通知可以清除';

  @override
  String get clearAllNotifications => '清除全部通知';

  @override
  String notificationsDeletedCannotUndone(Object p0) => '會刪除 ${p0} 則通知，無法復原。';

  @override
  String get clearAll => '全部清除';

  @override
  String get allNotificationsCleared => '已清除全部通知';

  @override
  String get couldNotClearPleaseTryAgain => '清除失敗，請稍後再試';

  @override
  String get noUnreadNotifications => '沒有未讀的通知';

  @override
  String markAllUnreadNotificationsAsRead(Object p0) => '要把 ${p0} 則未讀通知全部標為已讀嗎？此動作無法復原。';

  @override
  String get openChat => '前往聊天室';

  @override
  String get viewOrder => '查看訂單';

  @override
  String get openMyBooks => '前往書籍管理';

  @override
  String get notifications => '通知中心';

  @override
  String get noNotifications => '目前沒有任何通知';

  @override
  String copied(Object p0) => '已複製${p0}';

  @override
  String get orderDetails => '訂單詳情';

  @override
  String order(Object p0) => '訂單編號 ${p0}';

  @override
  String get orderProgress => '訂單進度';

  @override
  String items2(Object p0) => '商品明細（${p0}）';

  @override
  String get orderNoItemDetails => '這筆訂單沒有品項資料。';

  @override
  String msg4(Object p0, Object p1) => '單價 \\\$${p0} × ${p1}';

  @override
  String get orderTotal => '訂單金額';

  @override
  String get pickupDetails => '取書資訊';

  @override
  String get notAssigned => '尚未指定';

  @override
  String get slot => '櫃位';

  @override
  String get notAssignedYet => '尚未配位';

  @override
  String get pickupCode => '取書碼';

  @override
  String get transaction => '交易資訊';

  @override
  String get buyer => '買家';

  @override
  String get seller => '賣家';

  @override
  String get placed => '成立時間';

  @override
  String get dispute2 => '爭議';

  @override
  String get orderOpenDispute => '此訂單有進行中的申訴案件';

  @override
  String get cancelOrder => '取消訂單';

  @override
  String get pendingPayoutDisappearsBuyerNotified => '取消後這筆待定收益會一併消失，買家也會收到通知。';

  @override
  String get cancelledBySeller => '賣家取消';

  @override
  String get orderCancelled2 => '訂單已取消';

  @override
  String get pendingPayouts => '待定收益';

  @override
  String get noPendingPayouts => '目前沒有待撥款的訂單';

  @override
  String get pendingAmount => '待定收益金額';

  @override
  String get coinsArriveOnceBuyerCollectsBook => '買家完成取書後會自動撥入代幣餘額';

  @override
  String get scanned => '掃描成功';

  @override
  String get scanAgain => '繼續掃描';

  @override
  String get collectBook => '我要取書';

  @override
  String get pointPickupQrCode => '對準取書 QR Code';

  @override
  String get holdSteady => '對準勿搖晃';

  @override
  String get bookCollected => '取書完成';

  @override
  String get thanksUsingSavemybookHappyReading => '感謝你的使用，祝閱讀愉快！';

  @override
  String collected(Object p0) => '《${p0}》已完成取書';

  @override
  String order2(Object p0) => '訂單編號：${p0}';

  @override
  String get signingOut => '登出中…';

  @override
  String get myAccount => '會員中心';

  @override
  String get personNotWrittenBioYet => '這個人很懶，什麼都沒留下';

  @override
  String get topTierReached => '已達到最高級別';

  @override
  String morePointsReach(Object p0, Object p1) => '再 ${p0} 點升級為「${p1}」';

  @override
  String get myCoins => '我的代幣';

  @override
  String get shareProfile => '分享檔案';

  @override
  String get purchases => '購買紀錄';

  @override
  String get sales => '銷售紀錄';

  @override
  String get settings => '設定';

  @override
  String get signOut2 => '確認登出';

  @override
  String get needSignAgainKeepUsingApp => '登出後需要重新輸入帳號密碼才能繼續使用。';

  @override
  String cancelOrderBookReturnsShop(Object p0) => '確定要取消訂單 ${p0} 嗎？取消後書籍會回到商城重新販售。';

  @override
  String get pickupCode2 => '取書代碼';

  @override
  String get notGeneratedYet => '尚未產生';

  @override
  String get enterCodeLockerCollect => '請在書櫃上輸入此代碼取書';

  @override
  String enterCodeCollect(Object p0) => '請至「${p0}」輸入此代碼取書';

  @override
  String get iCollected => '我已完成取書';

  @override
  String get noOrdersTab => '此分類目前沒有訂單';

  @override
  String get openDispute => '申請爭議';

  @override
  String get displayNameNeedsLeast2Characters => '暱稱至少 2 個字元';

  @override
  String get displayNameLimited50Characters => '暱稱不可超過 50 個字元';

  @override
  String get enterPasswordAgain => '請再輸入一次密碼';

  @override
  String get passwordsDoNotMatch2 => '兩次輸入的密碼不一致';

  @override
  String get pleaseReadAcceptTermsServicePrivacy => '請先閱讀並同意服務條款與隱私權政策';

  @override
  String get accountCreatedSignWith => '註冊成功，請使用新帳號登入';

  @override
  String get iReadAccept => '我已閱讀並同意 ';

  @override
  String get and => ' 與 ';

  @override
  String get createAccount => '建立帳號';

  @override
  String get joinSavemybook => '加入 SaveMyBook';

  @override
  String get signUpBuySellUseSmart => '註冊後就能買書、賣書與使用智慧書櫃';

  @override
  String get displayName => '暱稱';

  @override
  String get nameOthersSee => '其他人會看到的名字';

  @override
  String get emailSignWith => '用來登入的信箱';

  @override
  String get least8CharactersWithLettersNumbers => '至少 8 碼，需含英文與數字';

  @override
  String get confirmPassword => '確認密碼';

  @override
  String get enterPasswordAgain2 => '再輸入一次密碼';

  @override
  String get alreadyAccountGoBackSign => '已經有帳號了？返回上一頁登入';

  @override
  String get markAsDroppedOff => '完成存書';

  @override
  String get droppedOff => '已放入書櫃';

  @override
  String get markedAsDroppedOff => '已標記為完成存書';

  @override
  String get buyerNotifiedBookReturnsShop => '取消後買家會收到通知，書籍會回到商城重新販售。';

  @override
  String get dropOffPickupCode => '存書／取書代碼';

  @override
  String get enterCodeLocker => '請在書櫃上輸入此代碼';

  @override
  String get noRecentSearches => '還沒有搜尋紀錄';

  @override
  String get recentSearches => '最近搜尋';

  @override
  String get clearAll2 => '清除全部';

  @override
  String get searchTitleAuthorIsbn => '搜尋書名、作者、ISBN...';

  @override
  String get photoLimitReached => '照片已滿';

  @override
  String get canUploadUp10Photos => '最多只能上傳 10 張照片。';

  @override
  String get photosMissing => '照片不足';

  @override
  String missingTheseThreeRequired2(Object p0) => '還缺少：${p0}。這三張是必填的。';

  @override
  String get missingInformation => '資料不齊全';

  @override
  String get enterOwnPrice => '請輸入自訂價格。';

  @override
  String get invalidPrice => '價格不正確';

  @override
  String get priceMustGreaterThan02 => '售價必須大於 0 元。';

  @override
  String get priceCannotExceed99999 => '售價不可超過 99999 元。';

  @override
  String get chooseLockerLocation2 => '請選擇存放區域。';

  @override
  String get listed2 => '上架成功！';

  @override
  String get unknownError => '未知錯誤';

  @override
  String get couldNotListBook => '上架失敗';

  @override
  String serverError(Object p0) => '伺服器回應錯誤：${p0}';

  @override
  String get connectionProblem => '連線異常';

  @override
  String get couldNotReachServerUploadTimed => '無法連線至伺服器或上傳超時，請檢查網路狀態。';

  @override
  String get listBook => '確認完成上架';

  @override
  String get detailsPhotos => '詳細資訊與照片';

  @override
  String get loading => '載入中...';

  @override
  String get unknownLocker => '未知機櫃';

  @override
  String get enterTitle2 => '請輸入書名';

  @override
  String get chooseCategory2 => '請選擇分類';

  @override
  String get bookDetailsFilledAutomatically => '已自動帶入書籍資訊！';

  @override
  String get bookDetailsFilledFromBackupSource => '已透過備援系統帶入書籍資訊！';

  @override
  String get noSourceIsbnPleaseEnterDetails => '各系統皆找不到此 ISBN，請嘗試手動輸入';

  @override
  String get day => '日';

  @override
  String get tapIconRightScan => '可點擊右側圖示掃描';

  @override
  String get description => '書籍簡介';

  @override
  String get sellBook => '我要賣書';

  @override
  String get myShop => '我的賣場';

  @override
  String get sellerNoBooksSale => '這位賣家目前沒有販售中的書籍';

  @override
  String get loading2 => '載入中…';

  @override
  String sale2(Object p0) => '販售中 ${p0} 本';

  @override
  String get verifyEnableQuickSign => '驗證身分以啟用快速登入';

  @override
  String sign2(Object p0) => '已啟用 ${p0} 登入';

  @override
  String get quickSignTurnedOff => '已關閉快速登入';

  @override
  String get appearance2 => '外觀設定';

  @override
  String get signMethod => '登入方式';

  @override
  String get helpSupport => '說明與支援';

  @override
  String get contactUs => '聯絡我們';

  @override
  String get aboutSavemybook => '關於 SaveMyBook';

  @override
  String get settingsPrivacy => '設定與隱私';

  @override
  String sign3(Object p0) => '${p0} 登入';

  @override
  String unlockWithWhenOpenApp(Object p0) => '開啟 App 時用 ${p0} 解鎖';

  @override
  String get scanProfileQrCode => '掃描個人 QR Code';

  @override
  String get lineUpTheirQrCodeWith => '將對方的 QR Code 放入框內';

  @override
  String get notSavemybookProfileQrCode => '這不是 SaveMyBook 的個人 QR Code';

  @override
  String get ownQrCode => '這是你自己的 QR Code';

  @override
  String get couldNotStartChatPleaseTry => '無法建立聊天室，請稍後再試';

  @override
  String get linkCopied => '已複製連結';

  @override
  String addMeSavemybook(Object p0) => '在 SaveMyBook 上加我：${p0}';

  @override
  String addMeSavemybook2(Object p0, Object p1) => '在 SaveMyBook 上加我（${p0}）：${p1}';

  @override
  String get sharingCouldNotOpenSoLink => '無法開啟分享，已幫你複製連結';

  @override
  String get savedPhotos => '已儲存到相簿';

  @override
  String get couldNotSaveCheckPhotoLibrary => '儲存失敗，請確認已允許相簿權限';

  @override
  String get scanTheirQrCode => '掃描對方的 QR Code';

  @override
  String get copyLink => '複製連結';

  @override
  String get askQuestion => '提出問題';

  @override
  String get noEnquiriesYet => '還沒有任何問題紀錄';

  @override
  String get enterSubject => '請填寫主旨';

  @override
  String get addMoreDetailSoSupportCan => '請多描述一點，方便客服判斷';

  @override
  String get sentSupportReplySoon => '已送出，客服會盡快回覆';

  @override
  String get subject => '主旨';

  @override
  String get sumUpOneLine => '一句話描述問題';

  @override
  String get whatHappenedIncludeOrderNumberIf => '發生什麼事？有訂單編號的話一併附上';

  @override
  String get close => '結案';

  @override
  String get notAbleReplyAfterClosing => '結案後就不能再回覆了。';

  @override
  String get enquiryClosed => '工單已結案';

  @override
  String get changeStatus => '調整工單狀態';

  @override
  String get statusUpdated => '已更新狀態';

  @override
  String get enquiry => '工單';

  @override
  String get enquiryNotFound => '找不到這張工單';

  @override
  String get support => '客服';

  @override
  String get writeReply => '輸入回覆…';

  @override
  String get coins => '代幣中心';

  @override
  String get transactions => '交易紀錄';

  @override
  String get noTransactionsYet => '尚無交易紀錄';

  @override
  String get balance => '目前餘額';

  @override
  String hold(Object p0) => '凍結中 \\\$${p0}';

  @override
  String requestFailed2(Object p0) => '請求失敗（${p0}）';

  @override
  String get couldNotReachServer => '無法連線至伺服器';

  @override
  String get couldNotReachServerCheckConnection => '無法連線至伺服器，請檢查網路';

  @override
  String get signFailed => '登入失敗';

  @override
  String get signFailedPleaseTryAgain => '登入失敗，請稍後再試';

  @override
  String get signUpFailed => '註冊失敗';

  @override
  String get pleaseSignFirst => '請先登入';

  @override
  String get couldNotRelist => '重新上架失敗';

  @override
  String get couldNotRemoveFromSaved => '取消收藏失敗';

  @override
  String get couldNotSave => '收藏失敗';

  @override
  String get couldNotAddCart => '加入購物車失敗';

  @override
  String get checkoutFailed => '結帳失敗';

  @override
  String get couldNotCancelOrder => '取消訂單失敗';

  @override
  String get couldNotUpdateOrder => '更新訂單狀態失敗';

  @override
  String get couldNotSubmitDispute => '送出爭議申請失敗';

  @override
  String get couldNotSubmitReport => '送出檢舉失敗';

  @override
  String get updateFailed2 => '更新失敗';

  @override
  String get couldNotChangePassword => '更改密碼失敗';

  @override
  String get requestFailed => '申請失敗';

  @override
  String get couldNotCancel => '取消失敗';

  @override
  String get couldNotDelete => '刪除失敗';

  @override
  String get couldNotComplete => '執行失敗';

  @override
  String get couldNotSaveAnnouncement => '儲存公告失敗';

  @override
  String get couldNotSend => '送出失敗';

  @override
  String get actionFailed => '操作失敗';

  @override
  String get couldNotSave2 => '儲存失敗';

  @override
  String get documentUpdated => '已更新文件';

  @override
  String get couldNotAdjust => '調整失敗';

  @override
  String get couldNotProcessReport => '處理檢舉失敗';

  @override
  String get couldNotRecordDecision => '裁決失敗';

  @override
  String get couldNotReorder => '排序失敗';

  @override
  String get couldNotSaveLocker => '儲存書櫃失敗';

  @override
  String get fingerprint => '指紋';

  @override
  String get iris => '虹膜';

  @override
  String get verifyIdentityContinue => '請驗證身分以繼續';

  @override
  String get couldNotOpenPhotosCheckPermission => '無法開啟相簿，請確認已授權';

  @override
  String get choosePhotoSource => '選擇照片來源';

  @override
  String get takePhoto => '拍照';

  @override
  String get chooseFromPhotos => '從相簿選擇';

  @override
  String get couldNotOpenCameraCheckPermission => '無法開啟相機，請確認已授權';

  @override
  String get justNow => '剛剛';

  @override
  String minAgo(Object p0) => '${p0} 分鐘前';

  @override
  String hAgo(Object p0) => '${p0} 小時前';

  @override
  String dAgo(Object p0) => '${p0} 天前';

  @override
  String get pickDate => '請選擇日期';

  @override
  String get pickDate2 => '選擇日期';

  @override
  String msg5(Object p0, Object p1, Object p2) => '${p0} 年 ${p1} 月 ${p2} 日';

  @override
  String get passwordsNeedLeast8Characters => '密碼長度至少 8 個字元';

  @override
  String get passwordsMustIncludeLetter => '密碼需包含英文字母';

  @override
  String get passwordsMustIncludeNumber => '密碼需包含數字';

  @override
  String get seller2 => '賣家：';

  @override
  String get home => '首頁';

  @override
  String get alerts => '通知';

  @override
  String get collect => '取書';

  @override
  String get couldNotLoadPhoto => '無法載入這張照片';

  @override
  String slot2(Object p0) => '櫃號：${p0}';

  @override
  String confirmPutLocker(Object p0) => '確認已把《${p0}》放入書櫃了嗎？';

  @override
  String get enterTitleContent => '請填寫標題與內容';

  @override
  String get titleCannotExceed255Characters => '標題不可超過 255 個字元';

  @override
  String get contentNeedsLeast5Characters => '內容至少 5 個字元';

  @override
  String get publishAnnouncement => '發布推播';

  @override
  String get everyUserSeeAnnouncementOncePublished => '發布後全體使用者都會看到這則公告，確定發布嗎？';

  @override
  String get publish => '發布';

  @override
  String get announcementPublished => '公告已發布';

  @override
  String get draftSaved => '草稿已儲存';

  @override
  String get editAnnouncement => '編輯推播';

  @override
  String get newAnnouncement => '新增推播';

  @override
  String get title2 => '標題';

  @override
  String get announcementTitle => '公告標題';

  @override
  String get writeAnnouncement => '輸入推播內容';

  @override
  String get publishNow => '立即發布';

  @override
  String get leaveOffSaveAsDraft => '關閉時只會存成草稿';

  @override
  String get saveDraft => '儲存草稿';

  @override
  String get deleteAnnouncement => '刪除公告';

  @override
  String deleteP0CannotUndone(Object p0) => '確定要刪除「${p0}」嗎？此操作無法復原。';

  @override
  String get announcementDeleted => '公告已刪除';

  @override
  String get couldNotDeleteTryAgainLater => '刪除失敗，請稍後再試';

  @override
  String get announcements => '系統公告';

  @override
  String get noAnnouncementsYetTapAddOne => '尚無公告，點右上角新增';

  @override
  String get published => '已發布';

  @override
  String get draft => '草稿';

  @override
  String get audienceEveryone => '對象：全體使用者';

  @override
  String get backUpNow => '立即備份';

  @override
  String get wholeDatabaseExportedCompressedWithLot => '將匯出整個資料庫並壓縮保存。資料量大時可能需要數十秒，期間請不要離開這個畫面。';

  @override
  String get startBackup => '開始備份';

  @override
  String get backingUpDatabase => '正在備份資料庫';

  @override
  String get backupComplete => '備份完成';

  @override
  String get backupDeleted => '已刪除備份';

  @override
  String get databaseBackups => '資料庫備份';

  @override
  String backedUpDailyNewestP0Kept(Object p0) => '每日自動備份，保留最新 ${p0} 份';

  @override
  String get olderBackupsBeyondCountRemovedAutomatically => '超出份數的舊備份會自動清除。備份檔含全站個人資料，下載後請妥善保管，每次下載都會記入操作紀錄。';

  @override
  String get noBackupsYetSchedulerRunsOnce => '尚無備份紀錄。排程每天會自動跑一次，也可以按上方按鈕立刻產生一份。';

  @override
  String get deleteBackup => '刪除備份';

  @override
  String p0NNtheFileItsRecord(Object p0) => '${p0}\n\n檔案與紀錄會一併移除，無法復原。';

  @override
  String get manual => '手動';

  @override
  String get scheduled => '排程';

  @override
  String get download => '下載';

  @override
  String get downloadBackup => '下載備份';

  @override
  String fetchBackupComputerWithAuthorisationHeader(Object p0, Object p1) => '備份檔請在電腦上取回，並帶上你的授權標頭：\n\n${p0}\n\n檔案大小 ${p1}。';

  @override
  String get copyLink2 => '複製網址';

  @override
  String get downloadLinkCopied => '已複製下載網址';

  @override
  String get forceDelist => '強制下架';

  @override
  String get reasonDelistingSellerNotified => '下架原因，會通知賣家';

  @override
  String get delist3 => '確認下架';

  @override
  String get relist2 => '恢復上架';

  @override
  String putP0BackStore(Object p0) => '要讓《${p0}》重新出現在商城嗎？';

  @override
  String get relisted => '已恢復上架';

  @override
  String get searchTitleIsbnSeller => '搜尋書名、ISBN 或賣家';

  @override
  String get noBooksMatch => '找不到符合條件的書籍';

  @override
  String sellerP0P1(Object p0, Object p1) => '賣家 ${p0}｜${p1}';

  @override
  String isbnP0P1Views(Object p0, Object p1) => 'ISBN ${p0}｜瀏覽 ${p1}';

  @override
  String p0ReportsAwaitingReview(Object p0) => '有 ${p0} 筆待處理檢舉';

  @override
  String get enterLockerNameAddress => '請填寫書櫃名稱與地址';

  @override
  String get enterValidLatitudeLongitude => '請填寫正確的經緯度';

  @override
  String get latitudeMustBetween9090 => '緯度必須介於 -90 ~ 90';

  @override
  String get longitudeMustBetween180180 => '經度必須介於 -180 ~ 180';

  @override
  String get slotCountMustBetween1100 => '櫃位數量必須介於 1 ~ 100';

  @override
  String get closingTime => '關閉時間';

  @override
  String p0MustLookLikeHhMm(Object p0) => '${p0}格式應為 HH:mm，例：09:00';

  @override
  String get fillBothOpeningClosingTimes => '開放與關閉時間請一起填寫';

  @override
  String get lockerUpdated => '書櫃已更新';

  @override
  String get lockerAdded => '書櫃已新增';

  @override
  String get editLocker => '修改書櫃';

  @override
  String get newLocker => '新增書櫃';

  @override
  String get lockerName => '書櫃名稱';

  @override
  String get latitude => '緯度';

  @override
  String get longitude => '經度';

  @override
  String get slotCount => '櫃位數量';

  @override
  String get createLocker => '建立書櫃';

  @override
  String get disable => '停用';

  @override
  String onceDisabledP0NoLongerAppears(Object p0) => '停用後「${p0}」不會再出現在賣家的存放區域選單中。';

  @override
  String onceEnabledP0AvailableSellersAgain(Object p0) => '啟用後「${p0}」會重新開放給賣家選擇。';

  @override
  String get lockerDisabled => '書櫃已停用';

  @override
  String get lockerEnabled => '書櫃已啟用';

  @override
  String slotP0(Object p0) => '櫃位 ${p0}';

  @override
  String get slotStatusUpdated => '櫃位狀態已更新';

  @override
  String get lockerMonitor => '書櫃監控';

  @override
  String get searchLockerNameAddress => '搜尋書櫃名稱或地址';

  @override
  String get noLockersMatch => '沒有符合條件的書櫃';

  @override
  String get disabled => '已停用';

  @override
  String freeSlotsP0P1(Object p0, Object p1) => '剩餘空間：${p0} / ${p1}';

  @override
  String get newCategory => '新增分類';

  @override
  String get editCategory => '編輯分類';

  @override
  String get categoryName => '分類名稱';

  @override
  String get enterCategoryName => '請輸入分類名稱';

  @override
  String get categoryAdded => '已新增分類';

  @override
  String get categoryUpdated => '已更新分類';

  @override
  String get deleteCategory => '刪除分類';

  @override
  String deleteP0CannotUndone2(Object p0) => '要刪除「${p0}」嗎？此動作無法復原。';

  @override
  String get categoryDeleted => '已刪除分類';

  @override
  String get categories => '分類管理';

  @override
  String get noCategoriesYet => '尚無分類';

  @override
  String p0BooksUse(Object p0) => '${p0} 本書使用中';

  @override
  String get legalDocuments => '法律文件';

  @override
  String get notCreatedYet => '尚未建立';

  @override
  String updatedP0(Object p0) => '最後更新 ${p0}';

  @override
  String p0Characters(Object p0) => '${p0} 字';

  @override
  String p0SectionsP1Characters(Object p0, Object p1) => '${p0} 章・${p1} 字';

  @override
  String get deleteSection => '刪除章節';

  @override
  String get contentsSectionRemovedWith => '這一章的內容會一併移除。';

  @override
  String p0ItsContentsRemoved(Object p0) => '「${p0}」與其內容會一併移除。';

  @override
  String get discardChanges => '捨棄變更？';

  @override
  String get documentUnsavedChangesTheyLostIf => '這份文件有尚未儲存的修改，離開後會遺失。';

  @override
  String get discard => '捨棄';

  @override
  String get keepEditing => '繼續編輯';

  @override
  String get bothTitleContentRequired => '標題與內容都要填寫';

  @override
  String sectionP0NoTitleYet(Object p0) => '第 ${p0} 章還沒有標題';

  @override
  String updateP0(Object p0) => '確認更新${p0}？';

  @override
  String get documentBindingEveryUserSubmittingReplaces => '這份文件對所有使用者都有效力，送出後會立刻取代目前的版本。';

  @override
  String get yesUpdate => '我確認要更新';

  @override
  String get notifyEveryUser => '要通知所有使用者嗎？';

  @override
  String get updateNotify => '更新並通知';

  @override
  String get updateOnly => '只更新不通知';

  @override
  String get sections => '章節';

  @override
  String get plainText => '純文字';

  @override
  String get preview => '預覽';

  @override
  String get documentTitle => '文件標題';

  @override
  String get preamble => '前言';

  @override
  String get unnumberedOpeningTextLeaveEmptyIf => '開頭不編號的說明文字，沒有的話可以留空。';

  @override
  String get articles => '條文';

  @override
  String get numberedAutomatically => '編號自動產生';

  @override
  String get noArticlesYetAddFirstOne => '還沒有條文。按下方新增第一章。';

  @override
  String get addSection => '新增章節';

  @override
  String get untitledSection => '未命名章節';

  @override
  String get sectionTitle => '章節標題';

  @override
  String get bodySectionSingleLineBreaksKept => '這一章的內容。單行換行會照樣呈現，空一行代表另起一段。';

  @override
  String get emptyLineStartsParagraphParagraphWhose => '空一行分段。首行寫「1. 標題」的段落，切回章節模式時會被認成一章。';

  @override
  String get howUsersSee => '使用者看到的樣子';

  @override
  String get noContentYet => '尚無內容';

  @override
  String get unsaved => '尚未儲存';

  @override
  String get upDate => '已是最新版本';

  @override
  String get newQuestion => '新增問題';

  @override
  String get editQuestion => '編輯問題';

  @override
  String get question => '問題';

  @override
  String get answer => '答案';

  @override
  String get showHelpCentre => '顯示在幫助中心';

  @override
  String get bothQuestionAnswerRequired => '問題與答案都要填寫';

  @override
  String get added => '已新增';

  @override
  String get updated => '已更新';

  @override
  String get deleteQuestion => '刪除問題';

  @override
  String deleteP0(Object p0) => '要刪除「${p0}」嗎？';

  @override
  String get deleted => '已刪除';

  @override
  String get faq => '常見問題';

  @override
  String get noQuestionsYet2 => '尚無常見問題';

  @override
  String get dragHandleRightReorder => '拖曳右側把手可調整順序';

  @override
  String get hidden => '已隱藏';

  @override
  String get cancelDeletionRequest => '取消刪除申請';

  @override
  String p0SAccountReturnsNormalCountdown(Object p0) => '${p0} 的帳號會恢復正常，刪除倒數停止。';

  @override
  String get cancelDeletion => '取消刪除';

  @override
  String get deletionRequestCancelled => '已取消該會員的刪除申請';

  @override
  String get anonymiseNow => '立即執行匿名化';

  @override
  String eraseP0SPersonalDataDisable(Object p0) => '不等緩衝期結束，立刻清除 ${p0} 的個人資料並停用帳號。\n\n訂單與交易紀錄會保留，但暱稱會變成「已刪除的使用者」。此操作無法復原。';

  @override
  String get doNow => '立即執行';

  @override
  String get anonymised => '已完成匿名化';

  @override
  String get pendingDeletions => '待刪除帳號';

  @override
  String get noDeletionRequestsPending => '目前沒有待處理的刪除申請';

  @override
  String get dueSoon => '即將執行';

  @override
  String p0DaysLeft(Object p0) => '剩 ${p0} 天';

  @override
  String requestedP0ScheduledP1(Object p0, Object p1) => '申請於 ${p0}，預計 ${p1} 執行';

  @override
  String get disputeResolution => '交易仲裁';

  @override
  String orderP0P1(Object p0, Object p1) => '訂單 ${p0}｜\\\$${p1}';

  @override
  String reasonP0(Object p0) => '申訴理由：${p0}';

  @override
  String get decisionNoteOptional => '裁決說明（選填）';

  @override
  String get submitDecision => '送出裁決';

  @override
  String get decisionRecorded => '已完成裁決';

  @override
  String get resolveDispute => '仲裁交易';

  @override
  String get noDisputesKind => '目前沒有此類申訴案件';

  @override
  String orderNumberP0(Object p0) => '訂單編號：${p0}';

  @override
  String buyerP0SellerP1(Object p0, Object p1) => '買家：${p0}｜賣家：${p1}';

  @override
  String filedByP0(Object p0) => '申訴人：${p0}';

  @override
  String get handle => '處理';

  @override
  String get transactions2 => '交易管理';

  @override
  String get orders => '訂單管理';

  @override
  String get lookUpOrdersAdjustStatusBy => '查詢訂單、人工調整狀態';

  @override
  String get disputeListDecisions => '申訴列表與裁決';

  @override
  String get listings => '商品管理';

  @override
  String get allBooksForceDelisting => '全站書籍、強制下架';

  @override
  String get moderation => '內容審核';

  @override
  String get handleListingReports => '商品檢舉處理';

  @override
  String get addReorderDeleteBookCategories => '新增、排序與刪除書籍分類';

  @override
  String get members => '會員管理';

  @override
  String get memberControls => '會員管控';

  @override
  String get memberListSuspensionBlocklist => '會員列表、停權與黑名單';

  @override
  String get membershipTiers => '會員等級管理';

  @override
  String get tierThresholdsBenefits => '等級門檻與權益設定';

  @override
  String get wallets => '錢包管理';

  @override
  String get checkBalancesAddDeductCoinsBy => '查詢餘額、人工增減代幣';

  @override
  String get hardwareOperations => '硬體與營運';

  @override
  String get lockerSlotStatus => '書櫃與櫃位狀態';

  @override
  String get maintenanceLog => '維修紀錄';

  @override
  String get lockerOperationHistory => '書櫃相關操作紀錄';

  @override
  String get reports => '營運報表';

  @override
  String get ordersRevenueMemberGrowth => '訂單、營收與會員成長';

  @override
  String get announcements2 => '推播管理';

  @override
  String get supportEnquiries => '客服工單';

  @override
  String get replyQuestionsFromUsers => '回覆使用者提出的問題';

  @override
  String get faqShownHelpCentre => '幫助中心的常見問題';

  @override
  String get termsPrivacyPolicyAbout => '服務條款、隱私權政策、關於我們';

  @override
  String get adminAuditLog => '管理操作紀錄';

  @override
  String get auditTrailAdminChanges => '管理員異動的稽核軌跡';

  @override
  String get systemOperations => '系統維運';

  @override
  String get dailyBackupsManualRunsDownloads => '每日自動備份、手動觸發與下載';

  @override
  String get deletionRequestsInsideGracePeriodCancel => '緩衝期內的刪除申請，可代為取消或立即執行';

  @override
  String get members2 => '會員數';

  @override
  String get todaySOrders => '今日訂單';

  @override
  String get openCases => '待處理案件';

  @override
  String get activeLockers => '啟用書櫃';

  @override
  String get newTier => '新增等級';

  @override
  String get editTier => '編輯等級';

  @override
  String get tierName => '等級名稱';

  @override
  String get minimumPoints => '最低點數';

  @override
  String get maximumPointsLeaveEmptyNoCap => '最高點數（留空 = 無上限）';

  @override
  String get benefitsSeparatedByCommasLineBreaks => '權益，用頓號或換行分隔，會在會員等級頁逐條顯示';

  @override
  String get enterTierName => '請輸入等級名稱';

  @override
  String get maximumPointsMustExceedMinimum => '最高點數必須大於最低點數';

  @override
  String get tierAdded => '已新增等級';

  @override
  String get tierUpdated => '已更新等級';

  @override
  String get deleteTier => '刪除等級';

  @override
  String deleteP0MembersTierDropNext(Object p0) => '要刪除「${p0}」嗎？已在這個等級的會員會退到下一個符合的等級。';

  @override
  String get tierDeleted => '已刪除等級';

  @override
  String get noMembershipTiersSetUp => '尚未設定會員等級';

  @override
  String p0PointsUp(Object p0) => '${p0} 點以上';

  @override
  String p0P1Points(Object p0, Object p1) => '${p0} ~ ${p1} 點';

  @override
  String get noBenefitsDescribedYet => '尚未填寫權益說明';

  @override
  String get noMaintenanceRecords => '目前沒有維修紀錄';

  @override
  String get noFurtherDetail => '（無額外說明）';

  @override
  String get operator => '操作人';

  @override
  String get unknown => '（未知）';

  @override
  String get time => '時間';

  @override
  String get recordNumber => '紀錄編號';

  @override
  String operatorP0(Object p0) => '操作人：${p0}';

  @override
  String get suspendAccount => '停權此帳號';

  @override
  String get reinstateAccount => '恢復此帳號';

  @override
  String get addBlocklist => '加入黑名單';

  @override
  String get removeFromBlocklist => '移出黑名單';

  @override
  String p0SignedOutImmediatelyCanNo(Object p0) => '${p0} 會立刻被登出，且無法再使用 App 的任何功能。';

  @override
  String p0AbleSignAgain(Object p0) => '${p0} 將可以重新登入使用。';

  @override
  String get accountStatusUpdated => '已更新帳號狀態';

  @override
  String get removeAdmin => '取消管理員';

  @override
  String get makeAdmin => '設為管理員';

  @override
  String p0LosesEveryAdminPermissionImmediately(Object p0) => '${p0} 將立刻失去所有後台權限。';

  @override
  String p0GainsAccessAdminAreaWith(Object p0) => '${p0} 將可以進入管理後台，預設擁有全部權限，可再逐項調整。';

  @override
  String get roleUpdated => '已更新身分';

  @override
  String manualP0P1(Object p0, Object p1) => '、手動 ${p0}${p1}';

  @override
  String get adjustMembershipTier => '調整會員等級';

  @override
  String currentlyP0PointsAutomaticP1P2(Object p0, Object p1, Object p2) => '目前 ${p0} 點（自動 ${p1}${p2}）';

  @override
  String p0P1Points2(Object p0, Object p1) => '${p0}（${p1} 點）';

  @override
  String get adjustPointsManually => '手動加減點數';

  @override
  String get backAutomatic => '恢復自動計算';

  @override
  String get backAutomatic2 => '已恢復自動計算';

  @override
  String get pointAdjustment => '加減點數';

  @override
  String get positiveAddsNegativeDeductsEG => '正數增加、負數扣除，例如 -50';

  @override
  String get apply => '套用';

  @override
  String get enterNonZeroWholeNumber => '請輸入非零的整數';

  @override
  String get pointsAdjusted => '已調整點數';

  @override
  String get tierAdjusted => '已調整等級';

  @override
  String get permissionGranted => '已開放權限';

  @override
  String get permissionRevoked => '已收回權限';

  @override
  String get grantAllPermissions => '開放全部權限';

  @override
  String get revokeAllPermissions => '收回全部權限';

  @override
  String p0AbleUseEveryAdminFeature(Object p0) => '${p0} 將可以使用後台所有功能。';

  @override
  String p0ReachAdminAreaButUnable(Object p0) => '${p0} 進入後台後將無法使用任何功能。';

  @override
  String get allPermissionsGranted => '已開放全部權限';

  @override
  String get allPermissionsRevoked => '已收回全部權限';

  @override
  String get memberSettings => '會員設定';

  @override
  String get noDataMember => '找不到這位會員的資料';

  @override
  String get listings2 => '上架書籍';

  @override
  String get completedTrades => '完成交易';

  @override
  String get joined => '加入日期';

  @override
  String get accountStatus => '帳號狀態';

  @override
  String get ownAccountStatusPermissionsCannotChanged => '這是你自己的帳號，無法在這裡調整狀態與權限。';

  @override
  String get accountEnabled => '啟用帳號';

  @override
  String get canSignUseAppNormally => '可以正常登入使用';

  @override
  String get suspendedSignedOutImmediatelyAfterSigning => '已停權，登入後會被立刻登出';

  @override
  String get blocked => '列入黑名單';

  @override
  String get blockedNoFeaturesAvailable => '已封鎖，無法使用任何功能';

  @override
  String get notBlocked => '未封鎖';

  @override
  String get role => '身分';

  @override
  String p0PointsAutomaticP1P2(Object p0, Object p1, Object p2) => '${p0} 點（自動 ${p1}${p2}）';

  @override
  String get memberSTierBeenAdjustedBy => '這位會員的等級目前有人工調整，不完全依交易自動計算。';

  @override
  String get adjustTier => '調整等級';

  @override
  String get adminPermissions => '後台權限';

  @override
  String get all => '全開';

  @override
  String get allOff => '全關';

  @override
  String get reinstateAccount2 => '恢復帳號';

  @override
  String get suspendAccount2 => '停權帳號';

  @override
  String runP1P0(Object p0, Object p1) => '確定要對「${p0}」執行「${p1}」嗎？';

  @override
  String updatedP0SStatus(Object p0) => '已更新 ${p0} 的狀態';

  @override
  String get fullSettingsTierPermissions => '完整設定（等級、權限）';

  @override
  String get members3 => '會員列表';

  @override
  String get searchDisplayNameEmail => '搜尋暱稱或 Email';

  @override
  String get noMembersMatch => '找不到符合條件的會員';

  @override
  String get sales2 => '銷售';

  @override
  String get created => '創建日期';

  @override
  String get noActivityYet => '尚無操作紀錄';

  @override
  String get changeOrderStatus => '調整訂單狀態';

  @override
  String orderP0(Object p0) => '訂單 ${p0}';

  @override
  String get reasonChange => '調整說明';

  @override
  String get sentBuyerAsWellOptional => '會一併通知買家（選填）';

  @override
  String get applyChange => '確認調整';

  @override
  String get orderStatusUpdated => '訂單狀態已更新';

  @override
  String get searchOrderNumberBuyerSeller => '搜尋訂單編號或買賣家';

  @override
  String get noOrdersMatch => '找不到符合條件的訂單';

  @override
  String get noItems => '（無品項）';

  @override
  String p0ItemsTotal(Object p0) => '等 ${p0} 項';

  @override
  String buyerP0SellerP12(Object p0, Object p1) => '買家 ${p0}｜賣家 ${p1}';

  @override
  String lockerP0(Object p0) => '書櫃：${p0}';

  @override
  String cancellationReasonP0(Object p0) => '取消原因：${p0}';

  @override
  String get reviewReport => '審核檢舉';

  @override
  String reportedP0P1(Object p0, Object p1) => '被檢舉${p0}：${p1}';

  @override
  String reasonP02(Object p0) => '違規原因：${p0}';

  @override
  String get handlingNoteOptional => '處理備註（選填）';

  @override
  String get delistListingAsWell => '同時將該商品下架';

  @override
  String get dismissReport => '駁回檢舉';

  @override
  String get reportHandled => '檢舉已處理';

  @override
  String get noReportsKind => '目前沒有此類檢舉案件';

  @override
  String reportedByP0(Object p0) => '檢舉人：${p0}';

  @override
  String get review => '審核';

  @override
  String noteP0(Object p0) => '備註：${p0}';

  @override
  String get last7Days => '近 7 天';

  @override
  String get last30Days => '近 30 天';

  @override
  String get ordersPerDay => '每日訂單量';

  @override
  String get revenuePerDay => '每日成交金額';

  @override
  String get newMembersPerDay => '每日新增會員';

  @override
  String get newOrders => '新增訂單';

  @override
  String get newMembers => '新增會員';

  @override
  String get newListings => '新上架書籍';

  @override
  String get completedRevenue => '已完成交易額';

  @override
  String p0Orders(Object p0) => '${p0} 筆';

  @override
  String peakP0(Object p0) => '最高 ${p0}';

  @override
  String get topCategoriesByListings => '熱門分類（依上架數）';

  @override
  String get replied => '已回覆';

  @override
  String get noEnquiriesCategory => '此分類目前沒有工單';

  @override
  String get addCoins => '增加代幣';

  @override
  String get deductCoins => '扣除代幣';

  @override
  String get amountPositiveWholeNumber => '金額（正整數）';

  @override
  String get reasonAdjustmentRequired => '調整原因（必填）';

  @override
  String get add2 => '確認增加';

  @override
  String get deduct => '確認扣除';

  @override
  String get enterAmountGreaterThan0 => '請輸入大於 0 的金額';

  @override
  String get enterReasonAdjustment => '請填寫調整原因';

  @override
  String get member2 => '這位會員';

  @override
  String get add3 => '增加';

  @override
  String get deduct2 => '扣除';

  @override
  String get confirmAddingCoins => '確認增加代幣';

  @override
  String get confirmDeductingCoins => '確認扣除代幣';

  @override
  String p1P2CoinsP0NreasonP3(Object p0, Object p1, Object p2, Object p3) => '將為 ${p0} ${p1} ${p2} 代幣。\n原因：${p3}';

  @override
  String get balanceAdjusted => '已調整餘額';

  @override
  String get memberWallets => '會員錢包';

  @override
  String get transactions3 => '帳務紀錄';

  @override
  String get memberNoTransactionsYet => '此會員尚無帳務紀錄。';

  @override
  String get balanceCoins => '目前餘額（代幣）';

  @override
  String get hold2 => '凍結中';

  @override
  String get total2 => '累積收入';

  @override
  String get totalOut => '累積支出';

  @override
  String balanceP0(Object p0) => '餘 ${p0}';

  @override
  String get suspensionBlocklistRoles => '停權、黑名單、身分';

  @override
  String get tierThresholdsManualAdjustments => '等級門檻與人工調整';

  @override
  String get booksCategories => '書籍與分類';

  @override
  String get reportReview => '檢舉審核';

  @override
  String get handleListingReports2 => '處理商品檢舉';

  @override
  String get lookUpChangeOrderStatus => '查詢與調整訂單狀態';

  @override
  String get decideDisputeCases => '申訴案件裁決';

  @override
  String get checkAdjustCoinBalances => '查詢與增減代幣';

  @override
  String get hardware => '硬體維護';

  @override
  String get lockersSlots => '書櫃與櫃位';

  @override
  String get announcementsDocuments => '公告與文件';

  @override
  String get announcementsFaqLegalDocuments => '公告、常見問題、法律文件';

  @override
  String get replyUserQuestions => '回覆使用者問題';

  @override
  String get databaseBackupDownloadOffByDefault => '資料庫備份與下載，預設關閉';

  @override
  String p0Locker(Object p0) => '${p0}書櫃';

  @override
  String everyActiveMemberReceivesP0Updated(Object p0) => '每一位啟用中的會員都會收到一則「${p0}已更新」的通知。';

  @override
  String get orderPlaced => '成立訂單';

  @override
  String get paid => '付款';

  @override
  String get sellerDroppedOff => '賣家放書';

  @override
  String get buyerCollected => '買家取書';

  @override
  String get completed => '完成';

  @override
  String get editBookDetails => '編輯書籍資料';

  @override
  String sellerP0TheyNotifiedSave(Object p0) => '賣家 ${p0}・儲存後會通知他';

  @override
  String get priceCoins => '售價（代幣）';

  @override
  String get k1013Digits2 => '10 或 13 位數字';

  @override
  String get category => '分類';

  @override
  String get description2 => '商品描述';

  @override
  String get titleRequired => '書名必填';

  @override
  String get nothingChanged => '沒有變更';

  @override
  String get resetPassword => '重設密碼';

  @override
  String p0SCurrentPasswordStopsWorking(Object p0) => '${p0} 目前的密碼會立刻失效，必須改用接下來產生的臨時密碼登入。\n\n密碼由系統產生，你不能自己指定。';

  @override
  String get generateTemporaryPassword => '產生臨時密碼';

  @override
  String get temporaryPassword => '臨時密碼';

  @override
  String p0SPasswordBeenResetPassword(Object p0) => '${p0} 的密碼已重設。這組密碼只會出現這一次，關掉後無法再查看。';

  @override
  String get remindThemChangeSettingsChangePassword => '請提醒對方登入後立刻到「設定 → 更改密碼」改掉。';

  @override
  String get temporaryPasswordCopied => '已複製臨時密碼';

  @override
  String get copy => '複製';

  @override
  String get cannotResetAnotherAdminSPassword => '不能重設其他管理員的密碼';

  @override
  String get generateTemporaryPasswordHandOver => '產生一組臨時密碼交給使用者';

  @override
  String get orderNumberCopied => '已複製訂單編號';

  @override
  String get orderNotFound => '找不到這筆訂單';

  @override
  String get paidWithCoins => '代幣支付';

  @override
  String get bankTransfer => '銀行轉帳';

  @override
  String get notPaidYet => '尚未付款';

  @override
  String get progress => '流程';

  @override
  String get notYet => '尚未發生';

  @override
  String get buyerSeller => '買賣雙方';

  @override
  String get items3 => '品項';

  @override
  String get bookDeleted => '（書籍已刪除）';

  @override
  String get notAssignedYet2 => '尚未指派';

  @override
  String get pickupCodeCopied => '已複製取書碼';

  @override
  String get walletActivity => '錢包異動';

  @override
  String balanceP02(Object p0) => '餘 ${p0}';

  @override
  String get refunds => '退款紀錄';

  @override
  String requestedP0NotProcessedYet(Object p0) => '申請於 ${p0}，尚未處理';

  @override
  String processedP0(Object p0) => '處理於 ${p0}';

  @override
  String get disputes => '申訴';

  @override
  String filedP0(Object p0) => '申請於 ${p0}';

  @override
  String decidedP0(Object p0) => '裁決於 ${p0}';

  @override
  String createdP0(Object p0) => '建立於 ${p0}';

  @override
  String get shareBook => '分享書籍';

  @override
  String get shareAnotherApp => '分享到其他 App';

  @override
  String get approved => '已核准';

  @override
  String get awaitingRefund => '待退款';

  @override
  String get declined => '不予退款';

  @override
  String get changeOwnPasswordGoSettingsChange => '要改自己的密碼請到「設定 → 更改密碼」';

  @override
  String get memberNotAdminSoThereNo => '這位會員不是管理員，沒有後台權限可以設定。先在上方把身分改成管理員。';

  @override
  String get you => '你自己';

  @override
  String isbnMust1013DigitsOne(Object p0) => 'ISBN 要 10 或 13 碼，目前 ${p0} 碼';

  @override
  String get screenUnsavedChangesTheyLostIf => '這個畫面有尚未儲存的修改，離開後會遺失。';

  @override
  String stillNeededP0(Object p0) => '還差：${p0}';

  @override
  String photosP0(Object p0) => '照片：${p0} 張';

  @override
  String get confirmListing => '確認上架';

  @override
  String get lookingUpBook => '查詢書籍資料中';

  @override
  String get scan => '掃描';

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

  @override
  String get verifySignSavemybook => '验证身分以登录 SaveMyBook';

  @override
  String get maintenance => '系统维护';

  @override
  String get promotions => '活动优惠';

  @override
  String get policyUpdate => '政策更新';

  @override
  String get announcement => '一般公告';

  @override
  String get item => '商品';

  @override
  String get member => '会员';

  @override
  String get message => '消息';

  @override
  String get noLongerExists => '(对象已不存在)';

  @override
  String get uncategorised => '未分类';

  @override
  String get general => '一般书籍';

  @override
  String get untitled => '无书名';

  @override
  String get noDescriptionYet => '暂无简介';

  @override
  String get locationNotProvided => '地点未提供';

  @override
  String seller3(Object p0) => '卖家：${p0}';

  @override
  String get unknownAuthor => '未知作者';

  @override
  String get unknownPublisher => '未知出版社';

  @override
  String get noIsbn => '未提供 ISBN';

  @override
  String get user => '用户';

  @override
  String get noMessagesYet => '尚无消息';

  @override
  String get photo => '[图片]';

  @override
  String item2(Object p0) => '[商品] ${p0}';

  @override
  String get purchase => '购买';

  @override
  String get sale => '卖出';

  @override
  String get systemAdjustment => '系统调整';

  @override
  String get preparingData => '正在整理您的数据';

  @override
  String get mySavemybookData => '我的 SaveMyBook 数据';

  @override
  String get exportedChooseWhereSave => '已导出，请选择保存位置';

  @override
  String get exportedButSharingCouldNotOpen => '导出完成，但无法打开分享';

  @override
  String get regenerateShareLink => '重新生成分享链接';

  @override
  String get oldLinkQrCodeStopWorking => '旧的链接与二维码会立即失效，已经分享出去的人将无法再打开。确定要重新生成吗？';

  @override
  String get regenerate => '重新生成';

  @override
  String get newLinkCreatedOldOneNo => '已生成新链接，旧链接已失效';

  @override
  String get deleteAccount => '删除账号';

  @override
  String get accountPermanentlyDisabled30DaysSign => '账号将在 30 天后永久停用，期间内重新登录即可取消。\n\n';

  @override
  String get personalDataErasedButCompletedOrders => '停用后个人资料会被清除，但已完成的订单与交易记录会保留，';

  @override
  String get peopleTradedWithDoNotLose => '交易对象的记录才不会出现缺漏。';

  @override
  String get actionContinue => '继续';

  @override
  String get verify => '确认身分';

  @override
  String get enterPasswordConfirm => '请输入密码以确认这是本人的操作。';

  @override
  String get password => '密码';

  @override
  String get requestDeletion => '申请删除';

  @override
  String get receivedSignAgainWithin30Days => '已受理，30 天内重新登录即可取消';

  @override
  String get deletionCancelledAccountActiveAgain => '已取消删除，账号恢复正常';

  @override
  String get account => '账号管理';

  @override
  String get data => '你的数据';

  @override
  String get exportMyData => '导出我的数据';

  @override
  String get profileBooksOrdersTransactionsJson => '个人资料、书籍、订单与交易记录，JSON 格式';

  @override
  String get oldLinkQrCodeStopWorking2 => '旧的链接与二维码会立即失效';

  @override
  String get cancelAccountDeletion => '取消删除账号';

  @override
  String get restoreAccountStopCountdown => '恢复账号，停止删除倒数';

  @override
  String get canChangeMindWithin30Days => '30 天缓冲期内可以反悔';

  @override
  String get deletionPending => '删除倒数中';

  @override
  String daysLeftCanCancelAnyTime(Object p0) => '还有 ${p0} 天。在这之前随时可以取消，逾期后个人资料将被清除且无法恢复。';

  @override
  String get signOut => '退出登录';

  @override
  String get type => '类型';

  @override
  String get content => '内容';

  @override
  String get backupFailed => '备份失败';

  @override
  String get myBooks => '书籍管理';

  @override
  String get notProvided => '未提供';

  @override
  String get openingHours => '开放时间';

  @override
  String get address => '地址';

  @override
  String get saveChanges => '保存更改';

  @override
  String get enable => '启用';

  @override
  String get termsService => '服务条款';

  @override
  String get privacyPolicy => '隐私权政策';

  @override
  String get aboutUs => '关于我们';

  @override
  String get admin => '管理后台';

  @override
  String get confirm => '确认';

  @override
  String get membershipTier => '会员等级';

  @override
  String get phone => '电话';

  @override
  String get violationConfirmed => '违规成立';

  @override
  String get scanBarcode => '扫描条码';

  @override
  String get lineUpBarcodeSpineWithFrame => '请将书脊条码对准框内';

  @override
  String get signAddItemsCart => '请先登录才能加入购物车';

  @override
  String bookCannotPurchased(Object p0) => '这本书目前${p0}，无法购买';

  @override
  String get addedCart => '已加入购物车';

  @override
  String get sellerInformationNotFound => '找不到卖家信息';

  @override
  String get signContactSeller => '请先登录才能联系卖家';

  @override
  String get signStartChat => '无法创建聊天室，请先登录';

  @override
  String get signReport => '请先登录才能举报';

  @override
  String get cannotReportOwnListing => '无法举报自己上架的商品';

  @override
  String get reportListing => '举报此商品';

  @override
  String get describeProblemLeast5Characters => '请说明违规原因（至少 5 个字）';

  @override
  String get reasonNeedsLeast5Characters => '请至少填写 5 个字的举报原因';

  @override
  String get reportSubmittedWeLookInto => '举报已送出，我们会尽快处理';

  @override
  String get publisher => '出版社：';

  @override
  String get author => '作者：';

  @override
  String get listed => '上架日期：';

  @override
  String get searchTitleAuthorPublisher => '搜索书名、作者、出版社...';

  @override
  String get share => '分享';

  @override
  String get report => '举报';

  @override
  String get about => '简介：';

  @override
  String pickup(Object p0) => '取书地点：${p0}';

  @override
  String get messageSeller => '与卖家聊聊';

  @override
  String get listing => '这是你的书';

  @override
  String get addCart => '加入购物车';

  @override
  String get bookBeenReportedUnderReviewStays => '这本书被举报，平台正在审核，期间仍可正常销售。';

  @override
  String get violationWasConfirmedBookPleaseCheck => '这本书经审核违规成立，请确认商品内容是否符合社区规范。';

  @override
  String get reportDismissed2 => '举报已驳回';

  @override
  String get bookWasReportedButNoViolation => '这本书曾被举报，经审核未违规，不影响上架。';

  @override
  String get delist => '取消上架';

  @override
  String removedFromShopBuyersNoLonger(Object p0) => '《${p0}》将从商城下架，买家不会再看到它。';

  @override
  String get delist2 => '下架';

  @override
  String get delistedRelistFromDelistedTab => '已下架，可在“已下架”页签重新上架';

  @override
  String get couldNotDelistPleaseTryAgain => '下架失败，请稍后再试';

  @override
  String listedAgain(Object p0) => '《${p0}》已重新上架';

  @override
  String get notListedAnyBooksYet => '你还没有上架任何书籍';

  @override
  String get noBooksCategory => '这个分类目前没有书籍';

  @override
  String get listFirstBook => '去上架第一本书';

  @override
  String get relist => '重新上架';

  @override
  String get removeFromCart => '移出购物车';

  @override
  String removeFromCart2(Object p0) => '要把《${p0}》从购物车移除吗？';

  @override
  String get remove => '移除';

  @override
  String get couldNotRemoveRestored => '移除失败，已还原';

  @override
  String get couldNotRemovePleaseTryAgain => '移除失败，请稍后再试';

  @override
  String get selectBooksWantCheckOut => '请先选择要结算的书籍';

  @override
  String notEnoughCoinsOrderNeedsBut(Object p0, Object p1) => '代币不足，这笔订单需要 ${p0}，目前只有 ${p1}';

  @override
  String get confirmCheckout => '确认结算';

  @override
  String booksTotal(Object p0, Object p1) => '共 ${p0} 本书，总金额 ${p1}。\n';

  @override
  String balanceAfterPaymentCoins(Object p0) => '扣款后余额为 ${p0} 代币。';

  @override
  String get orderPlacedSellerDropBookOff => '结算成功，请等待卖家存书';

  @override
  String get cart => '购物车';

  @override
  String get cartEmpty => '购物车是空的';

  @override
  String get selectAll => '全选';

  @override
  String items(Object p0) => '${p0} 件商品';

  @override
  String get deselect => '取消选取';

  @override
  String get select => '选取';

  @override
  String coinsShort(Object p0) => '还差 ${p0} 代币';

  @override
  String get total => '合计';

  @override
  String selected(Object p0) => '${p0} 件';

  @override
  String balance2(Object p0) => '余额 ${p0}';

  @override
  String get selectBookFirst => '请先选书';

  @override
  String get checkOut => '结算';

  @override
  String get notEnoughCoins => '代币不足';

  @override
  String get weak => '偏弱';

  @override
  String get fair => '普通';

  @override
  String get strong => '很强';

  @override
  String get enterCurrentPassword => '请输入当前密码';

  @override
  String get enterNewPassword => '请输入新密码';

  @override
  String get newPasswordMustDifferent => '新密码不可与当前密码相同';

  @override
  String get enterNewPasswordAgain => '请再输入一次新密码';

  @override
  String get passwordsDoNotMatch => '两次输入的新密码不一致';

  @override
  String get passwordUpdated => '密码已更新';

  @override
  String get changePassword => '更改密码';

  @override
  String get useLeast8CharactersWithBoth => '密码需要至少 8 位，并同时包含英文与数字。';

  @override
  String get currentPassword => '当前密码';

  @override
  String get newPassword => '新密码';

  @override
  String get confirmNewPassword => '确认新密码';

  @override
  String get updatePassword => '更新密码';

  @override
  String get deleteChat => '删除聊天室';

  @override
  String allMessagesWithDeletedBothCannot(Object p0) => '会一并删除与 ${p0} 的所有消息，双方都看不到了。此动作无法恢复。';

  @override
  String get chatDeleted => '已删除聊天室';

  @override
  String get couldNotDeleteRestored => '删除失败，已还原';

  @override
  String get chatMuted => '已静音这个聊天室';

  @override
  String get chatUnmuted => '已取消静音';

  @override
  String get noUnreadMessages => '没有未读消息';

  @override
  String get markAllAsRead => '全部标为已读';

  @override
  String markAllUnreadMessagesAsRead(Object p0) => '要把 ${p0} 条未读消息全部标为已读吗？此动作无法恢复。';

  @override
  String get markAllRead => '全部已读';

  @override
  String get allMarkedAsRead => '已全部标为已读';

  @override
  String get somethingWentWrongPleaseTryAgain => '操作失败，请稍后再试';

  @override
  String get chats => '聊天室';

  @override
  String get noConversationsYet => '还没有任何对话';

  @override
  String get unmute => '取消静音';

  @override
  String get mute => '静音';

  @override
  String get messagesLimited500Characters => '消息长度不可超过 500 字';

  @override
  String get messageCouldNotSent => '消息发送失败';

  @override
  String get chat => '聊天';

  @override
  String get sendFirstMessage => '开始你们的第一条消息吧';

  @override
  String get messageCopied => '已复制消息';

  @override
  String get iQuestionAboutBook => '想询问这本书';

  @override
  String get bookNoLongerListed => '这本书已经下架了';

  @override
  String get writeMessage => '输入消息…';

  @override
  String get enterOrderNumberDisputing => '请填写要申诉的订单编号';

  @override
  String get describeDispute => '请填写争议说明';

  @override
  String get useLeast10CharactersSoSupport => '争议说明请至少填写 10 个字，方便客服判断';

  @override
  String get submitDispute => '提交争议申请';

  @override
  String get orderEntersDisputeProcessPaymentSeller => '提交后这笔订单会进入申诉流程，款项会暂停拨给卖家，直到客服裁决。';

  @override
  String paymentHoldRequested(Object p0) => '[申请冻结款项] ${p0}';

  @override
  String get disputeSubmittedSupportContact => '争议申请已提交，客服会尽快与你联系';

  @override
  String get dispute => '争议处理';

  @override
  String get requestPaymentHold => '申请冻结款项';

  @override
  String get paymentSellerHeldUntilSupportDecides => '提交后款项会暂停拨给卖家，直到客服裁决';

  @override
  String get submitDispute2 => '提交争议申请';

  @override
  String get orderNumber => '订单编号';

  @override
  String get eGSmb20260910123456789 => '例如 SMB20260910123456789';

  @override
  String get whatHappened => '争议说明';

  @override
  String get describeProblemEGConditionDoes => '请描述发生的问题，例如书况与商品描述不符…';

  @override
  String get submit => '提交申请';

  @override
  String get uploadPhotos => '上传图片';

  @override
  String get canAttachUp6Photos => '最多只能上传 6 张佐证照片';

  @override
  String get up5 => '最多 5 张';

  @override
  String get couldNotReplacePhotoPleaseTry => '无法替换原本的照片，请稍后再试';

  @override
  String get keepLeastOnePhoto => '至少要保留一张照片';

  @override
  String get photoDeleted => '已删除照片';

  @override
  String get couldNotDeletePhotoPleaseTry => '删除图片失败，请稍后再试';

  @override
  String get canUp10Photos => '最多只能有 10 张照片';

  @override
  String get deletePhoto => '删除照片';

  @override
  String get cannotUndoneContinue => '删除后无法恢复，确定吗？';

  @override
  String get photoMissingDataRefreshTryAgain => '这张照片的数据不完整，请刷新后再试';

  @override
  String get enterPrice => '请填写价格';

  @override
  String get priceMustGreaterThan0 => '价格必须大于 0';

  @override
  String get priceCannotExceed999999 => '价格不可超过 999,999';

  @override
  String get chooseLockerLocation => '请选择存放区域';

  @override
  String missingTheseThreeRequired(Object p0) => '还缺少：${p0}，这三张是必填的';

  @override
  String get bookUpdated => '书籍已更新';

  @override
  String get editBook => '编辑书籍';

  @override
  String get condition => '书况';

  @override
  String get customPrice => '自定价格';

  @override
  String get enterPrice2 => '请输入售价';

  @override
  String get lockerLocation => '存放区域';

  @override
  String get chooseLocker => '请选择书柜';

  @override
  String get bookPhotos => '书籍照片';

  @override
  String get morePhotos => '补充照片';

  @override
  String get add => '加入';

  @override
  String get enterTitle => '请填写书名';

  @override
  String get titleLimited255Characters => '书名不可超过 255 个字符';

  @override
  String get isbn1013Digits => 'ISBN 应为 10 位或 13 位';

  @override
  String get chooseCategory => '请选择书籍分类';

  @override
  String get k1013Digits => '10 或 13 位';

  @override
  String get title => '书名';

  @override
  String get actionRequired => '必填';

  @override
  String get author2 => '作者';

  @override
  String get optional => '选填';

  @override
  String get publisher2 => '出版社';

  @override
  String get publicationDate => '出版日期';

  @override
  String get tapPickPublicationDate => '点击选择出版日期';

  @override
  String get pickPublicationDate => '选择出版日期';

  @override
  String get pickCategory => '选择分类';

  @override
  String get next => '下一步';

  @override
  String get uploading => '上传中…';

  @override
  String get profilePhotoUpdated => '头像已更新';

  @override
  String get couldNotUploadPhoto => '头像上传失败';

  @override
  String get changeDisplayName => '修改昵称';

  @override
  String get enterDisplayName => '请输入昵称';

  @override
  String get displayNameCannotBlank => '昵称不可空白';

  @override
  String get displayNames250Characters => '昵称长度需介于 2 ~ 50 个字符';

  @override
  String get invalidPhoneNumberEG0912345678 => '电话格式不正确，例：0912345678';

  @override
  String get profileUpdated => '个人资料已更新';

  @override
  String get editProfile => '编辑个人资料';

  @override
  String get bio => '个人简介';

  @override
  String get tellPeopleAboutYourself => '介绍一下自己吧';

  @override
  String get email => '邮箱';

  @override
  String get emailCannotChanged => '邮箱无法修改';

  @override
  String get dateBirth => '生日';

  @override
  String get tapPickDateBirth => '点击选择生日';

  @override
  String get pickDateBirth => '选择生日';

  @override
  String get savedBooks => '收藏书籍';

  @override
  String get notSavedAnyBooksYet => '还没有收藏任何书籍';

  @override
  String get helpCentre => '帮助中心';

  @override
  String get searchQuestions => '搜索问题';

  @override
  String get noQuestionsYet => '目前还没有常见问题';

  @override
  String get noMatchingQuestions => '找不到相关问题';

  @override
  String get newest => '最新上架';

  @override
  String get popular => '热门推荐';

  @override
  String get priceLowHigh => '价格由低到高';

  @override
  String get priceHighLow => '价格由高到低';

  @override
  String get reachedEnd => '您已滑到底部';

  @override
  String get guest => '访客';

  @override
  String hi(Object p0) => '哈啰, ${p0}';

  @override
  String get noBooksMatchFilters => '目前没有符合条件的书籍';

  @override
  String get couldNotReadPhoto => '无法读取这张照片';

  @override
  String get croppingFailedPleaseTryAgain => '裁剪失败，请再试一次';

  @override
  String get adjustPhoto => '调整照片';

  @override
  String get reset => '重置';

  @override
  String get usePhoto => '使用这张';

  @override
  String get documentNotBeenCreatedYet => '这份文件尚未建立';

  @override
  String lastUpdated(Object p0) => '最后更新：${p0}';

  @override
  String get biometrics => '生物识别';

  @override
  String get sessionExpiredPleaseEnterPasswordAgain => '登录信息已失效，请重新输入密码';

  @override
  String turnSign(Object p0) => '启用 ${p0} 登录？';

  @override
  String nextTimeOpenAppCanUnlock(Object p0) => '下次打开 App 就能直接用 ${p0} 解锁，不用再输入密码。';

  @override
  String get notNow => '暂时不要';

  @override
  String get enterEmail => '请输入 Email';

  @override
  String get emailAddressNotValid => 'Email 格式不正确';

  @override
  String get enterPassword => '请输入密码';

  @override
  String get noAccountWithEmail => '此账号尚未注册';

  @override
  String noAccountCreateOneNow(Object p0) => '找不到“${p0}”这个账号。要现在创建一个吗？';

  @override
  String get signUp => '前往注册';

  @override
  String get tryAgain => '重新输入';

  @override
  String get sign => '登录';

  @override
  String signWith(Object p0) => '使用 ${p0} 登录';

  @override
  String get noAccountYetSignUp => '还没有账号？立即注册';

  @override
  String get membershipTiersNotSetUpYet => '尚未设定会员等级制度';

  @override
  String get currentTier => '您当前的级别';

  @override
  String get unlocked => '已解锁';

  @override
  String get locked => '尚未解锁';

  @override
  String get aboveTier => '您已高于此级别';

  @override
  String get reachedTopTier => '您已达到最高级别';

  @override
  String unlocked2(Object p0) => '已解锁“${p0}”';

  @override
  String morePointsUnlock(Object p0, Object p1) => '再 ${p0} 点即可解锁“${p1}”';

  @override
  String benefits(Object p0) => '${p0}级别奖励';

  @override
  String get noBenefitsBeenDescribedTierYet => '尚未设定此等级的权益说明。';

  @override
  String pointsFromCompletedOrders(Object p0, Object p1) => '目前累积 ${p0} 点，已完成 ${p1} 笔交易';

  @override
  String get noNotificationsClear => '没有通知可以清除';

  @override
  String get clearAllNotifications => '清除全部通知';

  @override
  String notificationsDeletedCannotUndone(Object p0) => '会删除 ${p0} 条通知，无法恢复。';

  @override
  String get clearAll => '全部清除';

  @override
  String get allNotificationsCleared => '已清除全部通知';

  @override
  String get couldNotClearPleaseTryAgain => '清除失败，请稍后再试';

  @override
  String get noUnreadNotifications => '没有未读的通知';

  @override
  String markAllUnreadNotificationsAsRead(Object p0) => '要把 ${p0} 条未读通知全部标为已读吗？此动作无法恢复。';

  @override
  String get openChat => '前往聊天室';

  @override
  String get viewOrder => '查看订单';

  @override
  String get openMyBooks => '前往书籍管理';

  @override
  String get notifications => '通知中心';

  @override
  String get noNotifications => '目前没有任何通知';

  @override
  String copied(Object p0) => '已复制${p0}';

  @override
  String get orderDetails => '订单详情';

  @override
  String order(Object p0) => '订单编号 ${p0}';

  @override
  String get orderProgress => '订单进度';

  @override
  String items2(Object p0) => '商品明细（${p0}）';

  @override
  String get orderNoItemDetails => '这笔订单没有品项数据。';

  @override
  String msg4(Object p0, Object p1) => '单价 ${p0} × ${p1}';

  @override
  String get orderTotal => '订单金额';

  @override
  String get pickupDetails => '取书信息';

  @override
  String get notAssigned => '尚未指定';

  @override
  String get slot => '柜位';

  @override
  String get notAssignedYet => '尚未配位';

  @override
  String get pickupCode => '取书码';

  @override
  String get transaction => '交易信息';

  @override
  String get buyer => '买家';

  @override
  String get seller => '卖家';

  @override
  String get placed => '成立时间';

  @override
  String get dispute2 => '争议';

  @override
  String get orderOpenDispute => '此订单有进行中的申诉案件';

  @override
  String get cancelOrder => '取消订单';

  @override
  String get pendingPayoutDisappearsBuyerNotified => '取消后这笔待定收益会一并消失，买家也会收到通知。';

  @override
  String get cancelledBySeller => '卖家取消';

  @override
  String get orderCancelled2 => '订单已取消';

  @override
  String get pendingPayouts => '待定收益';

  @override
  String get noPendingPayouts => '目前没有待拨款的订单';

  @override
  String get pendingAmount => '待定收益金额';

  @override
  String get coinsArriveOnceBuyerCollectsBook => '买家完成取书后会自动拨入代币余额';

  @override
  String get scanned => '扫描成功';

  @override
  String get scanAgain => '继续扫描';

  @override
  String get collectBook => '我要取书';

  @override
  String get pointPickupQrCode => '对准取书二维码';

  @override
  String get holdSteady => '对准勿摇晃';

  @override
  String get bookCollected => '取书完成';

  @override
  String get thanksUsingSavemybookHappyReading => '感谢你的使用，祝阅读愉快！';

  @override
  String collected(Object p0) => '《${p0}》已完成取书';

  @override
  String order2(Object p0) => '订单编号：${p0}';

  @override
  String get signingOut => '退出登录中…';

  @override
  String get myAccount => '会员中心';

  @override
  String get personNotWrittenBioYet => '这个人很懒，什么都没留下';

  @override
  String get topTierReached => '已达到最高级别';

  @override
  String morePointsReach(Object p0, Object p1) => '再 ${p0} 点升级为“${p1}”';

  @override
  String get myCoins => '我的代币';

  @override
  String get shareProfile => '分享档案';

  @override
  String get purchases => '购买记录';

  @override
  String get sales => '销售记录';

  @override
  String get settings => '设置';

  @override
  String get signOut2 => '确认退出登录';

  @override
  String get needSignAgainKeepUsingApp => '退出后需要重新输入账号密码才能继续使用。';

  @override
  String cancelOrderBookReturnsShop(Object p0) => '确定要取消订单 ${p0} 吗？取消后书籍会回到商城重新销售。';

  @override
  String get pickupCode2 => '取书代码';

  @override
  String get notGeneratedYet => '尚未生成';

  @override
  String get enterCodeLockerCollect => '请在书柜上输入此代码取书';

  @override
  String enterCodeCollect(Object p0) => '请至“${p0}”输入此代码取书';

  @override
  String get iCollected => '我已完成取书';

  @override
  String get noOrdersTab => '此分类目前没有订单';

  @override
  String get openDispute => '申请争议';

  @override
  String get displayNameNeedsLeast2Characters => '昵称至少 2 个字符';

  @override
  String get displayNameLimited50Characters => '昵称不可超过 50 个字符';

  @override
  String get enterPasswordAgain => '请再输入一次密码';

  @override
  String get passwordsDoNotMatch2 => '两次输入的密码不一致';

  @override
  String get pleaseReadAcceptTermsServicePrivacy => '请先阅读并同意服务条款与隐私权政策';

  @override
  String get accountCreatedSignWith => '注册成功，请使用新账号登录';

  @override
  String get iReadAccept => '我已阅读并同意 ';

  @override
  String get and => ' 与 ';

  @override
  String get createAccount => '创建账号';

  @override
  String get joinSavemybook => '加入 SaveMyBook';

  @override
  String get signUpBuySellUseSmart => '注册后就能买书、卖书与使用智能书柜';

  @override
  String get displayName => '昵称';

  @override
  String get nameOthersSee => '其他人会看到的名字';

  @override
  String get emailSignWith => '用来登录的邮箱';

  @override
  String get least8CharactersWithLettersNumbers => '至少 8 位，需含英文与数字';

  @override
  String get confirmPassword => '确认密码';

  @override
  String get enterPasswordAgain2 => '再输入一次密码';

  @override
  String get alreadyAccountGoBackSign => '已经有账号了？返回上一页登录';

  @override
  String get markAsDroppedOff => '完成存书';

  @override
  String get droppedOff => '已放入书柜';

  @override
  String get markedAsDroppedOff => '已标记为完成存书';

  @override
  String get buyerNotifiedBookReturnsShop => '取消后买家会收到通知，书籍会回到商城重新销售。';

  @override
  String get dropOffPickupCode => '存书／取书代码';

  @override
  String get enterCodeLocker => '请在书柜上输入此代码';

  @override
  String get noRecentSearches => '还没有搜索记录';

  @override
  String get recentSearches => '最近搜索';

  @override
  String get clearAll2 => '清除全部';

  @override
  String get searchTitleAuthorIsbn => '搜索书名、作者、ISBN...';

  @override
  String get photoLimitReached => '照片已满';

  @override
  String get canUploadUp10Photos => '最多只能上传 10 张照片。';

  @override
  String get photosMissing => '照片不足';

  @override
  String missingTheseThreeRequired2(Object p0) => '还缺少：${p0}。这三张是必填的。';

  @override
  String get missingInformation => '资料不齐全';

  @override
  String get enterOwnPrice => '请输入自定价格。';

  @override
  String get invalidPrice => '价格不正确';

  @override
  String get priceMustGreaterThan02 => '售价必须大于 0 元。';

  @override
  String get priceCannotExceed99999 => '售价不可超过 99999 元。';

  @override
  String get chooseLockerLocation2 => '请选择存放区域。';

  @override
  String get listed2 => '上架成功！';

  @override
  String get unknownError => '未知错误';

  @override
  String get couldNotListBook => '上架失败';

  @override
  String serverError(Object p0) => '服务器响应错误：${p0}';

  @override
  String get connectionProblem => '连接异常';

  @override
  String get couldNotReachServerUploadTimed => '无法连接至服务器或上传超时，请检查网络状态。';

  @override
  String get listBook => '确认完成上架';

  @override
  String get detailsPhotos => '详细信息与照片';

  @override
  String get loading => '加载中...';

  @override
  String get unknownLocker => '未知机柜';

  @override
  String get enterTitle2 => '请输入书名';

  @override
  String get chooseCategory2 => '请选择分类';

  @override
  String get bookDetailsFilledAutomatically => '已自动带入书籍信息！';

  @override
  String get bookDetailsFilledFromBackupSource => '已通过备援系统带入书籍信息！';

  @override
  String get noSourceIsbnPleaseEnterDetails => '各系统皆找不到此 ISBN，请尝试手动输入';

  @override
  String get day => '日';

  @override
  String get tapIconRightScan => '可点击右侧图标扫描';

  @override
  String get description => '书籍简介';

  @override
  String get sellBook => '我要卖书';

  @override
  String get myShop => '我的卖场';

  @override
  String get sellerNoBooksSale => '这位卖家目前没有销售中的书籍';

  @override
  String get loading2 => '加载中…';

  @override
  String sale2(Object p0) => '销售中 ${p0} 本';

  @override
  String get verifyEnableQuickSign => '验证身分以启用快速登录';

  @override
  String sign2(Object p0) => '已启用 ${p0} 登录';

  @override
  String get quickSignTurnedOff => '已关闭快速登录';

  @override
  String get appearance2 => '外观设置';

  @override
  String get signMethod => '登录方式';

  @override
  String get helpSupport => '说明与支持';

  @override
  String get contactUs => '联系我们';

  @override
  String get aboutSavemybook => '关于 SaveMyBook';

  @override
  String get settingsPrivacy => '设置与隐私';

  @override
  String sign3(Object p0) => '${p0} 登录';

  @override
  String unlockWithWhenOpenApp(Object p0) => '打开 App 时用 ${p0} 解锁';

  @override
  String get scanProfileQrCode => '扫描个人二维码';

  @override
  String get lineUpTheirQrCodeWith => '将对方的二维码放入框内';

  @override
  String get notSavemybookProfileQrCode => '这不是 SaveMyBook 的个人二维码';

  @override
  String get ownQrCode => '这是你自己的二维码';

  @override
  String get couldNotStartChatPleaseTry => '无法创建聊天室，请稍后再试';

  @override
  String get linkCopied => '已复制链接';

  @override
  String addMeSavemybook(Object p0) => '在 SaveMyBook 上加我：${p0}';

  @override
  String addMeSavemybook2(Object p0, Object p1) => '在 SaveMyBook 上加我（${p0}）：${p1}';

  @override
  String get sharingCouldNotOpenSoLink => '无法打开分享，已帮你复制链接';

  @override
  String get savedPhotos => '已保存到相册';

  @override
  String get couldNotSaveCheckPhotoLibrary => '保存失败，请确认已允许相册权限';

  @override
  String get scanTheirQrCode => '扫描对方的二维码';

  @override
  String get copyLink => '复制链接';

  @override
  String get askQuestion => '提出问题';

  @override
  String get noEnquiriesYet => '还没有任何问题记录';

  @override
  String get enterSubject => '请填写主旨';

  @override
  String get addMoreDetailSoSupportCan => '请多描述一点，方便客服判断';

  @override
  String get sentSupportReplySoon => '已提交，客服会尽快回复';

  @override
  String get subject => '主旨';

  @override
  String get sumUpOneLine => '一句话描述问题';

  @override
  String get whatHappenedIncludeOrderNumberIf => '发生什么事？有订单编号的话一并附上';

  @override
  String get close => '结案';

  @override
  String get notAbleReplyAfterClosing => '结案后就不能再回复了。';

  @override
  String get enquiryClosed => '工单已结案';

  @override
  String get changeStatus => '调整工单状态';

  @override
  String get statusUpdated => '已更新状态';

  @override
  String get enquiry => '工单';

  @override
  String get enquiryNotFound => '找不到这张工单';

  @override
  String get support => '客服';

  @override
  String get writeReply => '输入回复…';

  @override
  String get coins => '代币中心';

  @override
  String get transactions => '交易记录';

  @override
  String get noTransactionsYet => '尚无交易记录';

  @override
  String get balance => '当前余额';

  @override
  String hold(Object p0) => '冻结中 ${p0}';

  @override
  String requestFailed2(Object p0) => '请求失败（${p0}）';

  @override
  String get couldNotReachServer => '无法连接至服务器';

  @override
  String get couldNotReachServerCheckConnection => '无法连接至服务器，请检查网络';

  @override
  String get signFailed => '登录失败';

  @override
  String get signFailedPleaseTryAgain => '登录失败，请稍后再试';

  @override
  String get signUpFailed => '注册失败';

  @override
  String get pleaseSignFirst => '请先登录';

  @override
  String get couldNotRelist => '重新上架失败';

  @override
  String get couldNotRemoveFromSaved => '取消收藏失败';

  @override
  String get couldNotSave => '收藏失败';

  @override
  String get couldNotAddCart => '加入购物车失败';

  @override
  String get checkoutFailed => '结算失败';

  @override
  String get couldNotCancelOrder => '取消订单失败';

  @override
  String get couldNotUpdateOrder => '更新订单状态失败';

  @override
  String get couldNotSubmitDispute => '提交争议申请失败';

  @override
  String get couldNotSubmitReport => '提交举报失败';

  @override
  String get updateFailed2 => '更新失败';

  @override
  String get couldNotChangePassword => '更改密码失败';

  @override
  String get requestFailed => '申请失败';

  @override
  String get couldNotCancel => '取消失败';

  @override
  String get couldNotDelete => '删除失败';

  @override
  String get couldNotComplete => '执行失败';

  @override
  String get couldNotSaveAnnouncement => '保存公告失败';

  @override
  String get couldNotSend => '提交失败';

  @override
  String get actionFailed => '操作失败';

  @override
  String get couldNotSave2 => '保存失败';

  @override
  String get documentUpdated => '已更新文件';

  @override
  String get couldNotAdjust => '调整失败';

  @override
  String get couldNotProcessReport => '处理举报失败';

  @override
  String get couldNotRecordDecision => '裁决失败';

  @override
  String get couldNotReorder => '排序失败';

  @override
  String get couldNotSaveLocker => '保存书柜失败';

  @override
  String get fingerprint => '指纹';

  @override
  String get iris => '虹膜';

  @override
  String get verifyIdentityContinue => '请验证身分以继续';

  @override
  String get couldNotOpenPhotosCheckPermission => '无法打开相册，请确认已授权';

  @override
  String get choosePhotoSource => '选择照片来源';

  @override
  String get takePhoto => '拍照';

  @override
  String get chooseFromPhotos => '从相册选择';

  @override
  String get couldNotOpenCameraCheckPermission => '无法打开相机，请确认已授权';

  @override
  String get justNow => '刚刚';

  @override
  String minAgo(Object p0) => '${p0} 分钟前';

  @override
  String hAgo(Object p0) => '${p0} 小时前';

  @override
  String dAgo(Object p0) => '${p0} 天前';

  @override
  String get pickDate => '请选择日期';

  @override
  String get pickDate2 => '选择日期';

  @override
  String msg5(Object p0, Object p1, Object p2) => '${p0} 年 ${p1} 月 ${p2} 日';

  @override
  String get passwordsNeedLeast8Characters => '密码长度至少 8 个字符';

  @override
  String get passwordsMustIncludeLetter => '密码需包含英文字母';

  @override
  String get passwordsMustIncludeNumber => '密码需包含数字';

  @override
  String get seller2 => '卖家：';

  @override
  String get home => '首页';

  @override
  String get alerts => '通知';

  @override
  String get collect => '取书';

  @override
  String get couldNotLoadPhoto => '无法加载这张照片';

  @override
  String slot2(Object p0) => '柜号：${p0}';

  @override
  String confirmPutLocker(Object p0) => '确认已把《${p0}》放入书柜了吗？';

  @override
  String get enterTitleContent => '请填写标题与内容';

  @override
  String get titleCannotExceed255Characters => '标题不可超过 255 个字符';

  @override
  String get contentNeedsLeast5Characters => '内容至少 5 个字符';

  @override
  String get publishAnnouncement => '发布推送';

  @override
  String get everyUserSeeAnnouncementOncePublished => '发布后全体用户都会看到这则公告，确定发布吗？';

  @override
  String get publish => '发布';

  @override
  String get announcementPublished => '公告已发布';

  @override
  String get draftSaved => '草稿已保存';

  @override
  String get editAnnouncement => '编辑推送';

  @override
  String get newAnnouncement => '新增推送';

  @override
  String get title2 => '标题';

  @override
  String get announcementTitle => '公告标题';

  @override
  String get writeAnnouncement => '输入推送内容';

  @override
  String get publishNow => '立即发布';

  @override
  String get leaveOffSaveAsDraft => '关闭时只会存成草稿';

  @override
  String get saveDraft => '保存草稿';

  @override
  String get deleteAnnouncement => '删除公告';

  @override
  String deleteP0CannotUndone(Object p0) => '确定要删除“${p0}”吗？此操作无法撤销。';

  @override
  String get announcementDeleted => '公告已删除';

  @override
  String get couldNotDeleteTryAgainLater => '删除失败，请稍后再试';

  @override
  String get announcements => '系统公告';

  @override
  String get noAnnouncementsYetTapAddOne => '尚无公告，点右上角新增';

  @override
  String get published => '已发布';

  @override
  String get draft => '草稿';

  @override
  String get audienceEveryone => '对象：全体用户';

  @override
  String get backUpNow => '立即备份';

  @override
  String get wholeDatabaseExportedCompressedWithLot => '将导出整个数据库并压缩保存。数据量大时可能需要数十秒，期间请不要离开这个界面。';

  @override
  String get startBackup => '开始备份';

  @override
  String get backingUpDatabase => '正在备份数据库';

  @override
  String get backupComplete => '备份完成';

  @override
  String get backupDeleted => '已删除备份';

  @override
  String get databaseBackups => '数据库备份';

  @override
  String backedUpDailyNewestP0Kept(Object p0) => '每日自动备份，保留最新 ${p0} 份';

  @override
  String get olderBackupsBeyondCountRemovedAutomatically => '超出份数的旧备份会自动清除。备份文件含全站个人资料，下载后请妥善保管，每次下载都会记入操作记录。';

  @override
  String get noBackupsYetSchedulerRunsOnce => '尚无备份记录。排程每天会自动跑一次，也可以按上方按钮立刻生成一份。';

  @override
  String get deleteBackup => '删除备份';

  @override
  String p0NNtheFileItsRecord(Object p0) => '${p0}\n\n文件与记录会一并移除，无法恢复。';

  @override
  String get manual => '手动';

  @override
  String get scheduled => '排程';

  @override
  String get download => '下载';

  @override
  String get downloadBackup => '下载备份';

  @override
  String fetchBackupComputerWithAuthorisationHeader(Object p0, Object p1) => '备份文件请在电脑上取回，并带上你的授权标头：\n\n${p0}\n\n文件大小 ${p1}。';

  @override
  String get copyLink2 => '复制网址';

  @override
  String get downloadLinkCopied => '已复制下载网址';

  @override
  String get forceDelist => '强制下架';

  @override
  String get reasonDelistingSellerNotified => '下架原因，会通知卖家';

  @override
  String get delist3 => '确认下架';

  @override
  String get relist2 => '恢复上架';

  @override
  String putP0BackStore(Object p0) => '要让《${p0}》重新出现在商城吗？';

  @override
  String get relisted => '已恢复上架';

  @override
  String get searchTitleIsbnSeller => '搜索书名、ISBN 或卖家';

  @override
  String get noBooksMatch => '找不到符合条件的书籍';

  @override
  String sellerP0P1(Object p0, Object p1) => '卖家 ${p0}｜${p1}';

  @override
  String isbnP0P1Views(Object p0, Object p1) => 'ISBN ${p0}｜浏览 ${p1}';

  @override
  String p0ReportsAwaitingReview(Object p0) => '有 ${p0} 笔待处理举报';

  @override
  String get enterLockerNameAddress => '请填写书柜名称与地址';

  @override
  String get enterValidLatitudeLongitude => '请填写正确的经纬度';

  @override
  String get latitudeMustBetween9090 => '纬度必须介于 -90 ~ 90';

  @override
  String get longitudeMustBetween180180 => '经度必须介于 -180 ~ 180';

  @override
  String get slotCountMustBetween1100 => '柜位数量必须介于 1 ~ 100';

  @override
  String get closingTime => '关闭时间';

  @override
  String p0MustLookLikeHhMm(Object p0) => '${p0} HH:mm，例：09:00';

  @override
  String get fillBothOpeningClosingTimes => '开放与关闭时间请一起填写';

  @override
  String get lockerUpdated => '书柜已更新';

  @override
  String get lockerAdded => '书柜已新增';

  @override
  String get editLocker => '修改书柜';

  @override
  String get newLocker => '新增书柜';

  @override
  String get lockerName => '书柜名称';

  @override
  String get latitude => '纬度';

  @override
  String get longitude => '经度';

  @override
  String get slotCount => '柜位数量';

  @override
  String get createLocker => '创建书柜';

  @override
  String get disable => '停用';

  @override
  String onceDisabledP0NoLongerAppears(Object p0) => '停用后“${p0}”不会再出现在卖家的存放区域菜单中。';

  @override
  String onceEnabledP0AvailableSellersAgain(Object p0) => '启用后“${p0}”会重新开放给卖家选择。';

  @override
  String get lockerDisabled => '书柜已停用';

  @override
  String get lockerEnabled => '书柜已启用';

  @override
  String slotP0(Object p0) => '柜位 ${p0}';

  @override
  String get slotStatusUpdated => '柜位状态已更新';

  @override
  String get lockerMonitor => '书柜监控';

  @override
  String get searchLockerNameAddress => '搜索书柜名称或地址';

  @override
  String get noLockersMatch => '没有符合条件的书柜';

  @override
  String get disabled => '已停用';

  @override
  String freeSlotsP0P1(Object p0, Object p1) => '剩余空间：${p0} / ${p1}';

  @override
  String get newCategory => '新增分类';

  @override
  String get editCategory => '编辑分类';

  @override
  String get categoryName => '分类名称';

  @override
  String get enterCategoryName => '请输入分类名称';

  @override
  String get categoryAdded => '已新增分类';

  @override
  String get categoryUpdated => '已更新分类';

  @override
  String get deleteCategory => '删除分类';

  @override
  String deleteP0CannotUndone2(Object p0) => '要删除“${p0}”吗？此操作无法撤销。';

  @override
  String get categoryDeleted => '已删除分类';

  @override
  String get categories => '分类管理';

  @override
  String get noCategoriesYet => '尚无分类';

  @override
  String p0BooksUse(Object p0) => '${p0} 本书使用中';

  @override
  String get legalDocuments => '法律文件';

  @override
  String get notCreatedYet => '尚未创建';

  @override
  String updatedP0(Object p0) => '最后更新 ${p0}';

  @override
  String p0Characters(Object p0) => '${p0} 字';

  @override
  String p0SectionsP1Characters(Object p0, Object p1) => '${p0} 章・${p1} 字';

  @override
  String get deleteSection => '删除章节';

  @override
  String get contentsSectionRemovedWith => '这一章的内容会一并移除。';

  @override
  String p0ItsContentsRemoved(Object p0) => '“${p0}”与其内容会一并移除。';

  @override
  String get discardChanges => '舍弃更改？';

  @override
  String get documentUnsavedChangesTheyLostIf => '这份文件有尚未保存的修改，离开后会丢失。';

  @override
  String get discard => '舍弃';

  @override
  String get keepEditing => '继续编辑';

  @override
  String get bothTitleContentRequired => '标题与内容都要填写';

  @override
  String sectionP0NoTitleYet(Object p0) => '第 ${p0} 章还没有标题';

  @override
  String updateP0(Object p0) => '确认更新${p0}？';

  @override
  String get documentBindingEveryUserSubmittingReplaces => '这份文件对所有用户都有效力，提交后会立刻取代当前版本。';

  @override
  String get yesUpdate => '我确认要更新';

  @override
  String get notifyEveryUser => '要通知所有用户吗？';

  @override
  String get updateNotify => '更新并通知';

  @override
  String get updateOnly => '只更新不通知';

  @override
  String get sections => '章节';

  @override
  String get plainText => '纯文本';

  @override
  String get preview => '预览';

  @override
  String get documentTitle => '文件标题';

  @override
  String get preamble => '前言';

  @override
  String get unnumberedOpeningTextLeaveEmptyIf => '开头不编号的说明文字，没有的话可以留空。';

  @override
  String get articles => '条文';

  @override
  String get numberedAutomatically => '编号自动生成';

  @override
  String get noArticlesYetAddFirstOne => '还没有条文。按下方新增第一章。';

  @override
  String get addSection => '新增章节';

  @override
  String get untitledSection => '未命名章节';

  @override
  String get sectionTitle => '章节标题';

  @override
  String get bodySectionSingleLineBreaksKept => '这一章的内容。单行换行会照样呈现，空一行代表另起一段。';

  @override
  String get emptyLineStartsParagraphParagraphWhose => '空一行分段。首行写“1. 标题”的段落，切回章节模式时会被认成一章。';

  @override
  String get howUsersSee => '用户看到的样子';

  @override
  String get noContentYet => '尚无内容';

  @override
  String get unsaved => '尚未保存';

  @override
  String get upDate => '已是最新版本';

  @override
  String get newQuestion => '新增问题';

  @override
  String get editQuestion => '编辑问题';

  @override
  String get question => '问题';

  @override
  String get answer => '答案';

  @override
  String get showHelpCentre => '显示在帮助中心';

  @override
  String get bothQuestionAnswerRequired => '问题与答案都要填写';

  @override
  String get added => '已新增';

  @override
  String get updated => '已更新';

  @override
  String get deleteQuestion => '删除问题';

  @override
  String deleteP0(Object p0) => '要删除“${p0}”吗？';

  @override
  String get deleted => '已删除';

  @override
  String get faq => '常见问题';

  @override
  String get noQuestionsYet2 => '尚无常见问题';

  @override
  String get dragHandleRightReorder => '拖拽右侧把手可调整顺序';

  @override
  String get hidden => '已隐藏';

  @override
  String get cancelDeletionRequest => '取消删除申请';

  @override
  String p0SAccountReturnsNormalCountdown(Object p0) => '${p0} 的账号会恢复正常，删除倒计时停止。';

  @override
  String get cancelDeletion => '取消删除';

  @override
  String get deletionRequestCancelled => '已取消该会员的删除申请';

  @override
  String get anonymiseNow => '立即执行匿名化';

  @override
  String eraseP0SPersonalDataDisable(Object p0) => '不等缓冲期结束，立刻清除 ${p0} 的个人资料并停用账号。\n\n订单与交易记录会保留，但昵称会变成“已删除的用户”。此操作无法撤销。';

  @override
  String get doNow => '立即执行';

  @override
  String get anonymised => '已完成匿名化';

  @override
  String get pendingDeletions => '待删除账号';

  @override
  String get noDeletionRequestsPending => '目前没有待处理的删除申请';

  @override
  String get dueSoon => '即将执行';

  @override
  String p0DaysLeft(Object p0) => '剩 ${p0} 天';

  @override
  String requestedP0ScheduledP1(Object p0, Object p1) => '申请于 ${p0}，预计 ${p1} 执行';

  @override
  String get disputeResolution => '交易仲裁';

  @override
  String orderP0P1(Object p0, Object p1) => '订单 ${p0}｜\\\$${p1}';

  @override
  String reasonP0(Object p0) => '申诉理由：${p0}';

  @override
  String get decisionNoteOptional => '裁决说明（选填）';

  @override
  String get submitDecision => '提交裁决';

  @override
  String get decisionRecorded => '已完成裁决';

  @override
  String get resolveDispute => '仲裁交易';

  @override
  String get noDisputesKind => '目前没有此类申诉案件';

  @override
  String orderNumberP0(Object p0) => '订单编号：${p0}';

  @override
  String buyerP0SellerP1(Object p0, Object p1) => '买家：${p0}｜卖家：${p1}';

  @override
  String filedByP0(Object p0) => '申诉人：${p0}';

  @override
  String get handle => '处理';

  @override
  String get transactions2 => '交易管理';

  @override
  String get orders => '订单管理';

  @override
  String get lookUpOrdersAdjustStatusBy => '查询订单、人工调整状态';

  @override
  String get disputeListDecisions => '申诉列表与裁决';

  @override
  String get listings => '商品管理';

  @override
  String get allBooksForceDelisting => '全站书籍、强制下架';

  @override
  String get moderation => '内容审核';

  @override
  String get handleListingReports => '商品举报处理';

  @override
  String get addReorderDeleteBookCategories => '新增、排序与删除图书分类';

  @override
  String get members => '会员管理';

  @override
  String get memberControls => '会员管控';

  @override
  String get memberListSuspensionBlocklist => '会员列表、停权与黑名单';

  @override
  String get membershipTiers => '会员等级管理';

  @override
  String get tierThresholdsBenefits => '等级门槛与权益设置';

  @override
  String get wallets => '钱包管理';

  @override
  String get checkBalancesAddDeductCoinsBy => '查询余额、人工增减代币';

  @override
  String get hardwareOperations => '硬件与运营';

  @override
  String get lockerSlotStatus => '书柜与柜位状态';

  @override
  String get maintenanceLog => '维修记录';

  @override
  String get lockerOperationHistory => '书柜相关操作记录';

  @override
  String get reports => '运营报表';

  @override
  String get ordersRevenueMemberGrowth => '订单、营收与会员增长';

  @override
  String get announcements2 => '推送管理';

  @override
  String get supportEnquiries => '客服工单';

  @override
  String get replyQuestionsFromUsers => '回复用户提出的问题';

  @override
  String get faqShownHelpCentre => '帮助中心的常见问题';

  @override
  String get termsPrivacyPolicyAbout => '服务条款、隐私政策、关于我们';

  @override
  String get adminAuditLog => '管理操作记录';

  @override
  String get auditTrailAdminChanges => '管理员变更的审计轨迹';

  @override
  String get systemOperations => '系统运维';

  @override
  String get dailyBackupsManualRunsDownloads => '每日自动备份、手动触发与下载';

  @override
  String get deletionRequestsInsideGracePeriodCancel => '缓冲期内的删除申请，可代为取消或立即执行';

  @override
  String get members2 => '会员数';

  @override
  String get todaySOrders => '今日订单';

  @override
  String get openCases => '待处理案件';

  @override
  String get activeLockers => '启用书柜';

  @override
  String get newTier => '新增等级';

  @override
  String get editTier => '编辑等级';

  @override
  String get tierName => '等级名称';

  @override
  String get minimumPoints => '最低点数';

  @override
  String get maximumPointsLeaveEmptyNoCap => '最高点数（留空 = 无上限）';

  @override
  String get benefitsSeparatedByCommasLineBreaks => '权益，用顿号或换行分隔，会在会员等级页逐条显示';

  @override
  String get enterTierName => '请输入等级名称';

  @override
  String get maximumPointsMustExceedMinimum => '最高点数必须大于最低点数';

  @override
  String get tierAdded => '已新增等级';

  @override
  String get tierUpdated => '已更新等级';

  @override
  String get deleteTier => '删除等级';

  @override
  String deleteP0MembersTierDropNext(Object p0) => '要删除“${p0}”吗？已在这个等级的会员会退到下一个符合的等级。';

  @override
  String get tierDeleted => '已删除等级';

  @override
  String get noMembershipTiersSetUp => '尚未设置会员等级';

  @override
  String p0PointsUp(Object p0) => '${p0} 点以上';

  @override
  String p0P1Points(Object p0, Object p1) => '${p0} ~ ${p1} 点';

  @override
  String get noBenefitsDescribedYet => '尚未填写权益说明';

  @override
  String get noMaintenanceRecords => '目前没有维修记录';

  @override
  String get noFurtherDetail => '（无额外说明）';

  @override
  String get operator => '操作人';

  @override
  String get unknown => '（未知）';

  @override
  String get time => '时间';

  @override
  String get recordNumber => '记录编号';

  @override
  String operatorP0(Object p0) => '操作人：${p0}';

  @override
  String get suspendAccount => '停权此账号';

  @override
  String get reinstateAccount => '恢复此账号';

  @override
  String get addBlocklist => '加入黑名单';

  @override
  String get removeFromBlocklist => '移出黑名单';

  @override
  String p0SignedOutImmediatelyCanNo(Object p0) => '${p0} 会立刻被登出，且无法再使用 App 的任何功能。';

  @override
  String p0AbleSignAgain(Object p0) => '${p0} 将可以重新登录使用。';

  @override
  String get accountStatusUpdated => '已更新账号状态';

  @override
  String get removeAdmin => '取消管理员';

  @override
  String get makeAdmin => '设为管理员';

  @override
  String p0LosesEveryAdminPermissionImmediately(Object p0) => '${p0} 将立刻失去所有后台权限。';

  @override
  String p0GainsAccessAdminAreaWith(Object p0) => '${p0} 将可以进入管理后台，默认拥有全部权限，可再逐项调整。';

  @override
  String get roleUpdated => '已更新身份';

  @override
  String manualP0P1(Object p0, Object p1) => '、手动 ${p0}${p1}';

  @override
  String get adjustMembershipTier => '调整会员等级';

  @override
  String currentlyP0PointsAutomaticP1P2(Object p0, Object p1, Object p2) => '当前 ${p0} 点（自动 ${p1}${p2}）';

  @override
  String p0P1Points2(Object p0, Object p1) => '${p0}（${p1} 点）';

  @override
  String get adjustPointsManually => '手动加减点数';

  @override
  String get backAutomatic => '恢复自动计算';

  @override
  String get backAutomatic2 => '已恢复自动计算';

  @override
  String get pointAdjustment => '加减点数';

  @override
  String get positiveAddsNegativeDeductsEG => '正数增加、负数扣除，例如 -50';

  @override
  String get apply => '应用';

  @override
  String get enterNonZeroWholeNumber => '请输入非零的整数';

  @override
  String get pointsAdjusted => '已调整点数';

  @override
  String get tierAdjusted => '已调整等级';

  @override
  String get permissionGranted => '已开放权限';

  @override
  String get permissionRevoked => '已收回权限';

  @override
  String get grantAllPermissions => '开放全部权限';

  @override
  String get revokeAllPermissions => '收回全部权限';

  @override
  String p0AbleUseEveryAdminFeature(Object p0) => '${p0} 将可以使用后台所有功能。';

  @override
  String p0ReachAdminAreaButUnable(Object p0) => '${p0} 进入后台后将无法使用任何功能。';

  @override
  String get allPermissionsGranted => '已开放全部权限';

  @override
  String get allPermissionsRevoked => '已收回全部权限';

  @override
  String get memberSettings => '会员设置';

  @override
  String get noDataMember => '找不到这位会员的资料';

  @override
  String get listings2 => '上架图书';

  @override
  String get completedTrades => '完成交易';

  @override
  String get joined => '加入日期';

  @override
  String get accountStatus => '账号状态';

  @override
  String get ownAccountStatusPermissionsCannotChanged => '这是你自己的账号，无法在这里调整状态与权限。';

  @override
  String get accountEnabled => '启用账号';

  @override
  String get canSignUseAppNormally => '可以正常登录使用';

  @override
  String get suspendedSignedOutImmediatelyAfterSigning => '已停权，登录后会被立刻登出';

  @override
  String get blocked => '列入黑名单';

  @override
  String get blockedNoFeaturesAvailable => '已封锁，无法使用任何功能';

  @override
  String get notBlocked => '未封锁';

  @override
  String get role => '身份';

  @override
  String p0PointsAutomaticP1P2(Object p0, Object p1, Object p2) => '${p0} 点（自动 ${p1}${p2}）';

  @override
  String get memberSTierBeenAdjustedBy => '这位会员的等级目前有人工调整，不完全依交易自动计算。';

  @override
  String get adjustTier => '调整等级';

  @override
  String get adminPermissions => '后台权限';

  @override
  String get all => '全开';

  @override
  String get allOff => '全关';

  @override
  String get reinstateAccount2 => '恢复账号';

  @override
  String get suspendAccount2 => '停权账号';

  @override
  String runP1P0(Object p0, Object p1) => '确定要对“${p0}”执行“${p1}”吗？';

  @override
  String updatedP0SStatus(Object p0) => '已更新 ${p0} 的状态';

  @override
  String get fullSettingsTierPermissions => '完整设置（等级、权限）';

  @override
  String get members3 => '会员列表';

  @override
  String get searchDisplayNameEmail => '搜索昵称或邮箱';

  @override
  String get noMembersMatch => '找不到符合条件的会员';

  @override
  String get sales2 => '销售';

  @override
  String get created => '创建日期';

  @override
  String get noActivityYet => '尚无操作记录';

  @override
  String get changeOrderStatus => '调整订单状态';

  @override
  String orderP0(Object p0) => '订单 ${p0}';

  @override
  String get reasonChange => '调整说明';

  @override
  String get sentBuyerAsWellOptional => '会一并通知买家（选填）';

  @override
  String get applyChange => '确认调整';

  @override
  String get orderStatusUpdated => '订单状态已更新';

  @override
  String get searchOrderNumberBuyerSeller => '搜索订单编号或买卖家';

  @override
  String get noOrdersMatch => '找不到符合条件的订单';

  @override
  String get noItems => '（无品项）';

  @override
  String p0ItemsTotal(Object p0) => '等 ${p0} 项';

  @override
  String buyerP0SellerP12(Object p0, Object p1) => '买家 ${p0}｜卖家 ${p1}';

  @override
  String lockerP0(Object p0) => '书柜：${p0}';

  @override
  String cancellationReasonP0(Object p0) => '取消原因：${p0}';

  @override
  String get reviewReport => '审核举报';

  @override
  String reportedP0P1(Object p0, Object p1) => '被举报${p0}：${p1}';

  @override
  String reasonP02(Object p0) => '违规原因：${p0}';

  @override
  String get handlingNoteOptional => '处理备注（选填）';

  @override
  String get delistListingAsWell => '同时将该商品下架';

  @override
  String get dismissReport => '驳回举报';

  @override
  String get reportHandled => '举报已处理';

  @override
  String get noReportsKind => '目前没有此类举报案件';

  @override
  String reportedByP0(Object p0) => '举报人：${p0}';

  @override
  String get review => '审核';

  @override
  String noteP0(Object p0) => '备注：${p0}';

  @override
  String get last7Days => '近 7 天';

  @override
  String get last30Days => '近 30 天';

  @override
  String get ordersPerDay => '每日订单量';

  @override
  String get revenuePerDay => '每日成交金额';

  @override
  String get newMembersPerDay => '每日新增会员';

  @override
  String get newOrders => '新增订单';

  @override
  String get newMembers => '新增会员';

  @override
  String get newListings => '新上架图书';

  @override
  String get completedRevenue => '已完成交易额';

  @override
  String p0Orders(Object p0) => '${p0} 笔';

  @override
  String peakP0(Object p0) => '最高 ${p0}';

  @override
  String get topCategoriesByListings => '热门分类（按上架数）';

  @override
  String get replied => '已回复';

  @override
  String get noEnquiriesCategory => '此分类目前没有工单';

  @override
  String get addCoins => '增加代币';

  @override
  String get deductCoins => '扣除代币';

  @override
  String get amountPositiveWholeNumber => '金额（正整数）';

  @override
  String get reasonAdjustmentRequired => '调整原因（必填）';

  @override
  String get add2 => '确认增加';

  @override
  String get deduct => '确认扣除';

  @override
  String get enterAmountGreaterThan0 => '请输入大于 0 的金额';

  @override
  String get enterReasonAdjustment => '请填写调整原因';

  @override
  String get member2 => '这位会员';

  @override
  String get add3 => '增加';

  @override
  String get deduct2 => '扣除';

  @override
  String get confirmAddingCoins => '确认增加代币';

  @override
  String get confirmDeductingCoins => '确认扣除代币';

  @override
  String p1P2CoinsP0NreasonP3(Object p0, Object p1, Object p2, Object p3) => '将为 ${p0} ${p1} ${p2} 代币。\n原因：${p3}';

  @override
  String get balanceAdjusted => '已调整余额';

  @override
  String get memberWallets => '会员钱包';

  @override
  String get transactions3 => '账务记录';

  @override
  String get memberNoTransactionsYet => '此会员尚无账务记录。';

  @override
  String get balanceCoins => '当前余额（代币）';

  @override
  String get hold2 => '冻结中';

  @override
  String get total2 => '累计收入';

  @override
  String get totalOut => '累计支出';

  @override
  String balanceP0(Object p0) => '余 ${p0}';

  @override
  String get suspensionBlocklistRoles => '停权、黑名单、身份';

  @override
  String get tierThresholdsManualAdjustments => '等级门槛与人工调整';

  @override
  String get booksCategories => '图书与分类';

  @override
  String get reportReview => '举报审核';

  @override
  String get handleListingReports2 => '处理商品举报';

  @override
  String get lookUpChangeOrderStatus => '查询与调整订单状态';

  @override
  String get decideDisputeCases => '申诉案件裁决';

  @override
  String get checkAdjustCoinBalances => '查询与增减代币';

  @override
  String get hardware => '硬件维护';

  @override
  String get lockersSlots => '书柜与柜位';

  @override
  String get announcementsDocuments => '公告与文件';

  @override
  String get announcementsFaqLegalDocuments => '公告、常见问题、法律文件';

  @override
  String get replyUserQuestions => '回复用户问题';

  @override
  String get databaseBackupDownloadOffByDefault => '数据库备份与下载，默认关闭';

  @override
  String p0Locker(Object p0) => '${p0}书柜';

  @override
  String everyActiveMemberReceivesP0Updated(Object p0) => '每一位启用中的会员都会收到一则“${p0}已更新”的通知。';

  @override
  String get orderPlaced => '成立订单';

  @override
  String get paid => '付款';

  @override
  String get sellerDroppedOff => '卖家放书';

  @override
  String get buyerCollected => '买家取书';

  @override
  String get completed => '完成';

  @override
  String get editBookDetails => '编辑书籍资料';

  @override
  String sellerP0TheyNotifiedSave(Object p0) => '卖家 ${p0}・保存后会通知他';

  @override
  String get priceCoins => '售价（代币）';

  @override
  String get k1013Digits2 => '10 或 13 位数字';

  @override
  String get category => '分类';

  @override
  String get description2 => '商品描述';

  @override
  String get titleRequired => '书名必填';

  @override
  String get nothingChanged => '没有变更';

  @override
  String get resetPassword => '重置密码';

  @override
  String p0SCurrentPasswordStopsWorking(Object p0) => '${p0} 当前的密码会立刻失效，必须改用接下来生成的临时密码登录。\n\n密码由系统生成，你不能自己指定。';

  @override
  String get generateTemporaryPassword => '生成临时密码';

  @override
  String get temporaryPassword => '临时密码';

  @override
  String p0SPasswordBeenResetPassword(Object p0) => '${p0} 的密码已重置。这组密码只会出现这一次，关闭后无法再查看。';

  @override
  String get remindThemChangeSettingsChangePassword => '请提醒对方登录后立刻到“设置 → 更改密码”改掉。';

  @override
  String get temporaryPasswordCopied => '已复制临时密码';

  @override
  String get copy => '复制';

  @override
  String get cannotResetAnotherAdminSPassword => '不能重置其他管理员的密码';

  @override
  String get generateTemporaryPasswordHandOver => '生成一组临时密码交给用户';

  @override
  String get orderNumberCopied => '已复制订单编号';

  @override
  String get orderNotFound => '找不到这笔订单';

  @override
  String get paidWithCoins => '代币支付';

  @override
  String get bankTransfer => '银行转账';

  @override
  String get notPaidYet => '尚未付款';

  @override
  String get progress => '流程';

  @override
  String get notYet => '尚未发生';

  @override
  String get buyerSeller => '买卖双方';

  @override
  String get items3 => '品项';

  @override
  String get bookDeleted => '（书籍已删除）';

  @override
  String get notAssignedYet2 => '尚未指派';

  @override
  String get pickupCodeCopied => '已复制取书码';

  @override
  String get walletActivity => '钱包变动';

  @override
  String balanceP02(Object p0) => '余 ${p0}';

  @override
  String get refunds => '退款记录';

  @override
  String requestedP0NotProcessedYet(Object p0) => '申请于 ${p0}，尚未处理';

  @override
  String processedP0(Object p0) => '处理于 ${p0}';

  @override
  String get disputes => '申诉';

  @override
  String filedP0(Object p0) => '申请于 ${p0}';

  @override
  String decidedP0(Object p0) => '裁决于 ${p0}';

  @override
  String createdP0(Object p0) => '创建于 ${p0}';

  @override
  String get shareBook => '分享书籍';

  @override
  String get shareAnotherApp => '分享到其他 App';

  @override
  String get approved => '已核准';

  @override
  String get awaitingRefund => '待退款';

  @override
  String get declined => '不予退款';

  @override
  String get changeOwnPasswordGoSettingsChange => '要改自己的密码请到“设置 → 更改密码”';

  @override
  String get memberNotAdminSoThereNo => '这位会员不是管理员，没有后台权限可以设置。先在上方把身份改成管理员。';

  @override
  String get you => '你自己';

  @override
  String isbnMust1013DigitsOne(Object p0) => 'ISBN 要 10 或 13 位，目前 ${p0} 位';

  @override
  String get screenUnsavedChangesTheyLostIf => '这个界面有尚未保存的修改，离开后会丢失。';

  @override
  String stillNeededP0(Object p0) => '还差：${p0}';

  @override
  String photosP0(Object p0) => '照片：${p0} 张';

  @override
  String get confirmListing => '确认上架';

  @override
  String get lookingUpBook => '查询书籍资料中';

  @override
  String get scan => '扫描';

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

  @override
  String get verifySignSavemybook => '驗證身分以登入 SaveMyBook';

  @override
  String get maintenance => '系統維護';

  @override
  String get promotions => '活動優惠';

  @override
  String get policyUpdate => '政策更新';

  @override
  String get announcement => '一般公告';

  @override
  String get item => '商品';

  @override
  String get member => '會員';

  @override
  String get message => '訊息';

  @override
  String get noLongerExists => '(對象已不存在)';

  @override
  String get uncategorised => '未分類';

  @override
  String get general => '一般書籍';

  @override
  String get untitled => '無書名';

  @override
  String get noDescriptionYet => '暫無簡介';

  @override
  String get locationNotProvided => '地點未提供';

  @override
  String seller3(Object p0) => '賣家：${p0}';

  @override
  String get unknownAuthor => '未知作者';

  @override
  String get unknownPublisher => '未知出版社';

  @override
  String get noIsbn => '未提供 ISBN';

  @override
  String get user => '使用者';

  @override
  String get noMessagesYet => '尚無訊息';

  @override
  String get photo => '[圖片]';

  @override
  String item2(Object p0) => '[商品] ${p0}';

  @override
  String get purchase => '購買';

  @override
  String get sale => '賣出';

  @override
  String get systemAdjustment => '系統調整';

  @override
  String get preparingData => '正在整理您的資料';

  @override
  String get mySavemybookData => '我的 SaveMyBook 資料';

  @override
  String get exportedChooseWhereSave => '已匯出，請選擇儲存位置';

  @override
  String get exportedButSharingCouldNotOpen => '匯出完成，但無法開啟分享';

  @override
  String get regenerateShareLink => '重新產生分享連結';

  @override
  String get oldLinkQrCodeStopWorking => '舊的連結與 QR Code 會立即失效，已經分享出去的人將無法再開啟。確定要重新產生嗎？';

  @override
  String get regenerate => '重新產生';

  @override
  String get newLinkCreatedOldOneNo => '已產生新連結，舊連結已失效';

  @override
  String get deleteAccount => '刪除帳號';

  @override
  String get accountPermanentlyDisabled30DaysSign => '帳號將在 30 天後永久停用，期間內重新登入即可取消。\n\n';

  @override
  String get personalDataErasedButCompletedOrders => '停用後個人資料會被清除，但已完成的訂單與交易紀錄會保留，';

  @override
  String get peopleTradedWithDoNotLose => '交易對象的紀錄才不會出現缺漏。';

  @override
  String get actionContinue => '繼續';

  @override
  String get verify => '確認身分';

  @override
  String get enterPasswordConfirm => '請輸入密碼以確認這是本人的操作。';

  @override
  String get password => '密碼';

  @override
  String get requestDeletion => '申請刪除';

  @override
  String get receivedSignAgainWithin30Days => '已受理，30 天內重新登入即可取消';

  @override
  String get deletionCancelledAccountActiveAgain => '已取消刪除，帳號恢復正常';

  @override
  String get account => '帳號管理';

  @override
  String get data => '你的資料';

  @override
  String get exportMyData => '匯出我的資料';

  @override
  String get profileBooksOrdersTransactionsJson => '個人檔案、書籍、訂單與交易紀錄，JSON 格式';

  @override
  String get oldLinkQrCodeStopWorking2 => '舊的連結與 QR Code 會立即失效';

  @override
  String get cancelAccountDeletion => '取消刪除帳號';

  @override
  String get restoreAccountStopCountdown => '恢復帳號，停止刪除倒數';

  @override
  String get canChangeMindWithin30Days => '30 天緩衝期內可以反悔';

  @override
  String get deletionPending => '刪除倒數中';

  @override
  String daysLeftCanCancelAnyTime(Object p0) => '還有 ${p0} 天。在這之前隨時可以取消，逾期後個人資料將被清除且無法復原。';

  @override
  String get signOut => '登出';

  @override
  String get type => '類型';

  @override
  String get content => '內容';

  @override
  String get backupFailed => '備份失敗';

  @override
  String get myBooks => '書籍管理';

  @override
  String get notProvided => '未提供';

  @override
  String get openingHours => '開放時間';

  @override
  String get address => '地址';

  @override
  String get saveChanges => '儲存變更';

  @override
  String get enable => '啟用';

  @override
  String get termsService => '服務條款';

  @override
  String get privacyPolicy => '隱私權政策';

  @override
  String get aboutUs => '關於我們';

  @override
  String get admin => '管理後台';

  @override
  String get confirm => '確認';

  @override
  String get membershipTier => '會員等級';

  @override
  String get phone => '電話';

  @override
  String get violationConfirmed => '違規成立';

  @override
  String get scanBarcode => '掃描條碼';

  @override
  String get lineUpBarcodeSpineWithFrame => '請將書背條碼對準框內';

  @override
  String get signAddItemsCart => '請先登入才能加入購物車';

  @override
  String bookCannotPurchased(Object p0) => '這本書目前${p0}，無法購買';

  @override
  String get addedCart => '已加入購物車';

  @override
  String get sellerInformationNotFound => '找不到賣家資訊';

  @override
  String get signContactSeller => '請先登入才能聯絡賣家';

  @override
  String get signStartChat => '無法建立聊天室，請先登入';

  @override
  String get signReport => '請先登入才能檢舉';

  @override
  String get cannotReportOwnListing => '無法檢舉自己上架的商品';

  @override
  String get reportListing => '檢舉此商品';

  @override
  String get describeProblemLeast5Characters => '請說明違規原因（至少 5 個字）';

  @override
  String get reasonNeedsLeast5Characters => '請至少填寫 5 個字的檢舉原因';

  @override
  String get reportSubmittedWeLookInto => '檢舉已送出，我們會盡快處理';

  @override
  String get publisher => '出版社：';

  @override
  String get author => '作者：';

  @override
  String get listed => '上架日期：';

  @override
  String get searchTitleAuthorPublisher => '搜尋書名、作者、出版社...';

  @override
  String get share => '分享';

  @override
  String get report => '檢舉';

  @override
  String get about => '簡介：';

  @override
  String pickup(Object p0) => '取書地點：${p0}';

  @override
  String get messageSeller => '與賣家聊聊';

  @override
  String get listing => '這是你的書';

  @override
  String get addCart => '加入購物車';

  @override
  String get bookBeenReportedUnderReviewStays => '這本書被檢舉，平台正在審核，期間仍可正常販售。';

  @override
  String get violationWasConfirmedBookPleaseCheck => '這本書經審核違規成立，請確認商品內容是否符合社群規範。';

  @override
  String get reportDismissed2 => '檢舉已駁回';

  @override
  String get bookWasReportedButNoViolation => '這本書曾被檢舉，經審核未違規，不影響上架。';

  @override
  String get delist => '取消上架';

  @override
  String removedFromShopBuyersNoLonger(Object p0) => '《${p0}》將從商城下架，買家不會再看到它。';

  @override
  String get delist2 => '下架';

  @override
  String get delistedRelistFromDelistedTab => '已下架，可在「已下架」分頁重新上架';

  @override
  String get couldNotDelistPleaseTryAgain => '下架失敗，請稍後再試';

  @override
  String listedAgain(Object p0) => '《${p0}》已重新上架';

  @override
  String get notListedAnyBooksYet => '你還沒有上架任何書籍';

  @override
  String get noBooksCategory => '這個分類目前沒有書籍';

  @override
  String get listFirstBook => '去上架第一本書';

  @override
  String get relist => '重新上架';

  @override
  String get removeFromCart => '移出購物車';

  @override
  String removeFromCart2(Object p0) => '要把《${p0}》從購物車移除嗎？';

  @override
  String get remove => '移除';

  @override
  String get couldNotRemoveRestored => '移除失敗，已還原';

  @override
  String get couldNotRemovePleaseTryAgain => '移除失敗，請稍後再試';

  @override
  String get selectBooksWantCheckOut => '請先選擇要結帳的書籍';

  @override
  String notEnoughCoinsOrderNeedsBut(Object p0, Object p1) => '代幣不足，這筆訂單需要 ${p0}，目前只有 ${p1}';

  @override
  String get confirmCheckout => '確認結帳';

  @override
  String booksTotal(Object p0, Object p1) => '共 ${p0} 本書，總金額 \\\$${p1}。\n';

  @override
  String balanceAfterPaymentCoins(Object p0) => '扣款後餘額為 ${p0} 代幣。';

  @override
  String get orderPlacedSellerDropBookOff => '結帳成功，請等待賣家存書';

  @override
  String get cart => '購物車';

  @override
  String get cartEmpty => '購物車是空的';

  @override
  String get selectAll => '全選';

  @override
  String items(Object p0) => '${p0} 件商品';

  @override
  String get deselect => '取消選取';

  @override
  String get select => '選取';

  @override
  String coinsShort(Object p0) => '還差 ${p0} 代幣';

  @override
  String get total => '合計';

  @override
  String selected(Object p0) => '${p0} 件';

  @override
  String balance2(Object p0) => '餘額 ${p0}';

  @override
  String get selectBookFirst => '請先選書';

  @override
  String get checkOut => '結帳';

  @override
  String get notEnoughCoins => '代幣不足';

  @override
  String get weak => '偏弱';

  @override
  String get fair => '普通';

  @override
  String get strong => '很強';

  @override
  String get enterCurrentPassword => '請輸入目前密碼';

  @override
  String get enterNewPassword => '請輸入新密碼';

  @override
  String get newPasswordMustDifferent => '新密碼不可與目前密碼相同';

  @override
  String get enterNewPasswordAgain => '請再輸入一次新密碼';

  @override
  String get passwordsDoNotMatch => '兩次輸入的新密碼不一致';

  @override
  String get passwordUpdated => '密碼已更新';

  @override
  String get changePassword => '更改密碼';

  @override
  String get useLeast8CharactersWithBoth => '密碼需要至少 8 碼，並同時包含英文與數字。';

  @override
  String get currentPassword => '目前密碼';

  @override
  String get newPassword => '新密碼';

  @override
  String get confirmNewPassword => '確認新密碼';

  @override
  String get updatePassword => '更新密碼';

  @override
  String get deleteChat => '刪除聊天室';

  @override
  String allMessagesWithDeletedBothCannot(Object p0) => '會一併刪除與 ${p0} 的所有訊息，雙方都看不到了。此動作無法復原。';

  @override
  String get chatDeleted => '已刪除聊天室';

  @override
  String get couldNotDeleteRestored => '刪除失敗，已還原';

  @override
  String get chatMuted => '已靜音這個聊天室';

  @override
  String get chatUnmuted => '已取消靜音';

  @override
  String get noUnreadMessages => '沒有未讀訊息';

  @override
  String get markAllAsRead => '全部標為已讀';

  @override
  String markAllUnreadMessagesAsRead(Object p0) => '要把 ${p0} 則未讀訊息全部標為已讀嗎？此動作無法復原。';

  @override
  String get markAllRead => '全部已讀';

  @override
  String get allMarkedAsRead => '已全部標為已讀';

  @override
  String get somethingWentWrongPleaseTryAgain => '操作失敗，請稍後再試';

  @override
  String get chats => '聊天室';

  @override
  String get noConversationsYet => '還沒有任何對話';

  @override
  String get unmute => '取消靜音';

  @override
  String get mute => '靜音';

  @override
  String get messagesLimited500Characters => '訊息長度不可超過 500 字';

  @override
  String get messageCouldNotSent => '訊息傳送失敗';

  @override
  String get chat => '聊天';

  @override
  String get sendFirstMessage => '開始你們的第一則訊息吧';

  @override
  String get messageCopied => '已複製訊息';

  @override
  String get iQuestionAboutBook => '想詢問這本書';

  @override
  String get bookNoLongerListed => '這本書已經下架了';

  @override
  String get writeMessage => '輸入訊息…';

  @override
  String get enterOrderNumberDisputing => '請填寫要申訴的訂單編號';

  @override
  String get describeDispute => '請填寫爭議說明';

  @override
  String get useLeast10CharactersSoSupport => '爭議說明請至少填寫 10 個字，方便客服判斷';

  @override
  String get submitDispute => '送出爭議申請';

  @override
  String get orderEntersDisputeProcessPaymentSeller => '送出後這筆訂單會進入申訴流程，款項會暫停撥給賣家，直到客服裁決。';

  @override
  String paymentHoldRequested(Object p0) => '[申請凍結款項] ${p0}';

  @override
  String get disputeSubmittedSupportContact => '爭議申請已送出，客服會盡快與你聯繫';

  @override
  String get dispute => '爭議處理';

  @override
  String get requestPaymentHold => '申請凍結款項';

  @override
  String get paymentSellerHeldUntilSupportDecides => '送出後款項會暫停撥給賣家，直到客服裁決';

  @override
  String get submitDispute2 => '提交爭議申請';

  @override
  String get orderNumber => '訂單編號';

  @override
  String get eGSmb20260910123456789 => '例如 SMB20260910123456789';

  @override
  String get whatHappened => '爭議說明';

  @override
  String get describeProblemEGConditionDoes => '請描述發生的問題，例如書況與商品描述不符…';

  @override
  String get submit => '送出申請';

  @override
  String get uploadPhotos => '上傳圖片';

  @override
  String get canAttachUp6Photos => '最多只能上傳 6 張佐證照片';

  @override
  String get up5 => '最多 5 張';

  @override
  String get couldNotReplacePhotoPleaseTry => '無法替換原本的照片，請稍後再試';

  @override
  String get keepLeastOnePhoto => '至少要保留一張照片';

  @override
  String get photoDeleted => '已刪除照片';

  @override
  String get couldNotDeletePhotoPleaseTry => '刪除圖片失敗，請稍後再試';

  @override
  String get canUp10Photos => '最多只能有 10 張照片';

  @override
  String get deletePhoto => '刪除照片';

  @override
  String get cannotUndoneContinue => '刪除後無法復原，確定嗎？';

  @override
  String get photoMissingDataRefreshTryAgain => '這張照片的資料不完整，請重新整理後再試';

  @override
  String get enterPrice => '請填寫價格';

  @override
  String get priceMustGreaterThan0 => '價格必須大於 0';

  @override
  String get priceCannotExceed999999 => '價格不可超過 999,999';

  @override
  String get chooseLockerLocation => '請選擇存放區域';

  @override
  String missingTheseThreeRequired(Object p0) => '還缺少：${p0}，這三張是必填的';

  @override
  String get bookUpdated => '書籍已更新';

  @override
  String get editBook => '編輯書籍';

  @override
  String get condition => '書況';

  @override
  String get customPrice => '自訂價格';

  @override
  String get enterPrice2 => '請輸入售價';

  @override
  String get lockerLocation => '存放區域';

  @override
  String get chooseLocker => '請選擇書櫃';

  @override
  String get bookPhotos => '書籍照片';

  @override
  String get morePhotos => '補充照片';

  @override
  String get add => '加入';

  @override
  String get enterTitle => '請填寫書名';

  @override
  String get titleLimited255Characters => '書名不可超過 255 個字元';

  @override
  String get isbn1013Digits => 'ISBN 應為 10 碼或 13 碼';

  @override
  String get chooseCategory => '請選擇書籍分類';

  @override
  String get k1013Digits => '10 或 13 碼';

  @override
  String get title => '書名';

  @override
  String get actionRequired => '必填';

  @override
  String get author2 => '作者';

  @override
  String get optional => '選填';

  @override
  String get publisher2 => '出版社';

  @override
  String get publicationDate => '出版日期';

  @override
  String get tapPickPublicationDate => '點擊選擇出版日期';

  @override
  String get pickPublicationDate => '選擇出版日期';

  @override
  String get pickCategory => '選擇分類';

  @override
  String get next => '下一步';

  @override
  String get uploading => '上傳中…';

  @override
  String get profilePhotoUpdated => '頭像已更新';

  @override
  String get couldNotUploadPhoto => '頭像上傳失敗';

  @override
  String get changeDisplayName => '修改暱稱';

  @override
  String get enterDisplayName => '請輸入暱稱';

  @override
  String get displayNameCannotBlank => '暱稱不可空白';

  @override
  String get displayNames250Characters => '暱稱長度需介於 2 ~ 50 個字元';

  @override
  String get invalidPhoneNumberEG0912345678 => '電話格式不正確，例：0912345678';

  @override
  String get profileUpdated => '個人檔案已更新';

  @override
  String get editProfile => '編輯個人檔案';

  @override
  String get bio => '個人簡介';

  @override
  String get tellPeopleAboutYourself => '介紹一下自己吧';

  @override
  String get email => '信箱';

  @override
  String get emailCannotChanged => '信箱無法修改';

  @override
  String get dateBirth => '生日';

  @override
  String get tapPickDateBirth => '點擊選擇生日';

  @override
  String get pickDateBirth => '選擇生日';

  @override
  String get savedBooks => '收藏書籍';

  @override
  String get notSavedAnyBooksYet => '還沒有收藏任何書籍';

  @override
  String get helpCentre => '幫助中心';

  @override
  String get searchQuestions => '搜尋問題';

  @override
  String get noQuestionsYet => '目前還沒有常見問題';

  @override
  String get noMatchingQuestions => '找不到相關問題';

  @override
  String get newest => '最新上架';

  @override
  String get popular => '熱門推薦';

  @override
  String get priceLowHigh => '價格由低到高';

  @override
  String get priceHighLow => '價格由高到低';

  @override
  String get reachedEnd => '您已滑到底部';

  @override
  String get guest => '訪客';

  @override
  String hi(Object p0) => '哈囉, ${p0}';

  @override
  String get noBooksMatchFilters => '目前沒有符合條件的書籍';

  @override
  String get couldNotReadPhoto => '無法讀取這張照片';

  @override
  String get croppingFailedPleaseTryAgain => '裁切失敗，請再試一次';

  @override
  String get adjustPhoto => '調整照片';

  @override
  String get reset => '重設';

  @override
  String get usePhoto => '使用這張';

  @override
  String get documentNotBeenCreatedYet => '這份文件尚未建立';

  @override
  String lastUpdated(Object p0) => '最後更新：${p0}';

  @override
  String get biometrics => '生物辨識';

  @override
  String get sessionExpiredPleaseEnterPasswordAgain => '登入資訊已失效，請重新輸入密碼';

  @override
  String turnSign(Object p0) => '啟用 ${p0} 登入？';

  @override
  String nextTimeOpenAppCanUnlock(Object p0) => '下次開啟 App 就能直接用 ${p0} 解鎖，不用再輸入密碼。';

  @override
  String get notNow => '暫時不要';

  @override
  String get enterEmail => '請輸入 Email';

  @override
  String get emailAddressNotValid => 'Email 格式不正確';

  @override
  String get enterPassword => '請輸入密碼';

  @override
  String get noAccountWithEmail => '此帳號尚未註冊';

  @override
  String noAccountCreateOneNow(Object p0) => '找不到「${p0}」這個帳號。要現在建立一個嗎？';

  @override
  String get signUp => '前往註冊';

  @override
  String get tryAgain => '重新輸入';

  @override
  String get sign => '登入';

  @override
  String signWith(Object p0) => '使用 ${p0} 登入';

  @override
  String get noAccountYetSignUp => '還沒有帳號？立即註冊';

  @override
  String get membershipTiersNotSetUpYet => '尚未設定會員等級制度';

  @override
  String get currentTier => '您目前的級別';

  @override
  String get unlocked => '已解鎖';

  @override
  String get locked => '尚未解鎖';

  @override
  String get aboveTier => '您已高於此級別';

  @override
  String get reachedTopTier => '您已達到最高級別';

  @override
  String unlocked2(Object p0) => '已解鎖「${p0}」';

  @override
  String morePointsUnlock(Object p0, Object p1) => '再 ${p0} 點即可解鎖「${p1}」';

  @override
  String benefits(Object p0) => '${p0}級別獎勵';

  @override
  String get noBenefitsBeenDescribedTierYet => '尚未設定此等級的權益說明。';

  @override
  String pointsFromCompletedOrders(Object p0, Object p1) => '目前累積 ${p0} 點，已完成 ${p1} 筆交易';

  @override
  String get noNotificationsClear => '沒有通知可以清除';

  @override
  String get clearAllNotifications => '清除全部通知';

  @override
  String notificationsDeletedCannotUndone(Object p0) => '會刪除 ${p0} 則通知，無法復原。';

  @override
  String get clearAll => '全部清除';

  @override
  String get allNotificationsCleared => '已清除全部通知';

  @override
  String get couldNotClearPleaseTryAgain => '清除失敗，請稍後再試';

  @override
  String get noUnreadNotifications => '沒有未讀的通知';

  @override
  String markAllUnreadNotificationsAsRead(Object p0) => '要把 ${p0} 則未讀通知全部標為已讀嗎？此動作無法復原。';

  @override
  String get openChat => '前往聊天室';

  @override
  String get viewOrder => '查看訂單';

  @override
  String get openMyBooks => '前往書籍管理';

  @override
  String get notifications => '通知中心';

  @override
  String get noNotifications => '目前沒有任何通知';

  @override
  String copied(Object p0) => '已複製${p0}';

  @override
  String get orderDetails => '訂單詳情';

  @override
  String order(Object p0) => '訂單編號 ${p0}';

  @override
  String get orderProgress => '訂單進度';

  @override
  String items2(Object p0) => '商品明細（${p0}）';

  @override
  String get orderNoItemDetails => '這筆訂單沒有品項資料。';

  @override
  String msg4(Object p0, Object p1) => '單價 \\\$${p0} × ${p1}';

  @override
  String get orderTotal => '訂單金額';

  @override
  String get pickupDetails => '取書資訊';

  @override
  String get notAssigned => '尚未指定';

  @override
  String get slot => '櫃位';

  @override
  String get notAssignedYet => '尚未配位';

  @override
  String get pickupCode => '取書碼';

  @override
  String get transaction => '交易資訊';

  @override
  String get buyer => '買家';

  @override
  String get seller => '賣家';

  @override
  String get placed => '成立時間';

  @override
  String get dispute2 => '爭議';

  @override
  String get orderOpenDispute => '此訂單有進行中的申訴案件';

  @override
  String get cancelOrder => '取消訂單';

  @override
  String get pendingPayoutDisappearsBuyerNotified => '取消後這筆待定收益會一併消失，買家也會收到通知。';

  @override
  String get cancelledBySeller => '賣家取消';

  @override
  String get orderCancelled2 => '訂單已取消';

  @override
  String get pendingPayouts => '待定收益';

  @override
  String get noPendingPayouts => '目前沒有待撥款的訂單';

  @override
  String get pendingAmount => '待定收益金額';

  @override
  String get coinsArriveOnceBuyerCollectsBook => '買家完成取書後會自動撥入代幣餘額';

  @override
  String get scanned => '掃描成功';

  @override
  String get scanAgain => '繼續掃描';

  @override
  String get collectBook => '我要取書';

  @override
  String get pointPickupQrCode => '對準取書 QR Code';

  @override
  String get holdSteady => '對準勿搖晃';

  @override
  String get bookCollected => '取書完成';

  @override
  String get thanksUsingSavemybookHappyReading => '感謝你的使用，祝閱讀愉快！';

  @override
  String collected(Object p0) => '《${p0}》已完成取書';

  @override
  String order2(Object p0) => '訂單編號：${p0}';

  @override
  String get signingOut => '登出中…';

  @override
  String get myAccount => '會員中心';

  @override
  String get personNotWrittenBioYet => '這個人很懶，什麼都沒留下';

  @override
  String get topTierReached => '已達到最高級別';

  @override
  String morePointsReach(Object p0, Object p1) => '再 ${p0} 點升級為「${p1}」';

  @override
  String get myCoins => '我的代幣';

  @override
  String get shareProfile => '分享檔案';

  @override
  String get purchases => '購買紀錄';

  @override
  String get sales => '銷售紀錄';

  @override
  String get settings => '設定';

  @override
  String get signOut2 => '確認登出';

  @override
  String get needSignAgainKeepUsingApp => '登出後需要重新輸入帳號密碼才能繼續使用。';

  @override
  String cancelOrderBookReturnsShop(Object p0) => '確定要取消訂單 ${p0} 嗎？取消後書籍會回到商城重新販售。';

  @override
  String get pickupCode2 => '取書代碼';

  @override
  String get notGeneratedYet => '尚未產生';

  @override
  String get enterCodeLockerCollect => '請在書櫃上輸入此代碼取書';

  @override
  String enterCodeCollect(Object p0) => '請至「${p0}」輸入此代碼取書';

  @override
  String get iCollected => '我已完成取書';

  @override
  String get noOrdersTab => '此分類目前沒有訂單';

  @override
  String get openDispute => '申請爭議';

  @override
  String get displayNameNeedsLeast2Characters => '暱稱至少 2 個字元';

  @override
  String get displayNameLimited50Characters => '暱稱不可超過 50 個字元';

  @override
  String get enterPasswordAgain => '請再輸入一次密碼';

  @override
  String get passwordsDoNotMatch2 => '兩次輸入的密碼不一致';

  @override
  String get pleaseReadAcceptTermsServicePrivacy => '請先閱讀並同意服務條款與隱私權政策';

  @override
  String get accountCreatedSignWith => '註冊成功，請使用新帳號登入';

  @override
  String get iReadAccept => '我已閱讀並同意 ';

  @override
  String get and => ' 與 ';

  @override
  String get createAccount => '建立帳號';

  @override
  String get joinSavemybook => '加入 SaveMyBook';

  @override
  String get signUpBuySellUseSmart => '註冊後就能買書、賣書與使用智慧書櫃';

  @override
  String get displayName => '暱稱';

  @override
  String get nameOthersSee => '其他人會看到的名字';

  @override
  String get emailSignWith => '用來登入的信箱';

  @override
  String get least8CharactersWithLettersNumbers => '至少 8 碼，需含英文與數字';

  @override
  String get confirmPassword => '確認密碼';

  @override
  String get enterPasswordAgain2 => '再輸入一次密碼';

  @override
  String get alreadyAccountGoBackSign => '已經有帳號了？返回上一頁登入';

  @override
  String get markAsDroppedOff => '完成存書';

  @override
  String get droppedOff => '已放入書櫃';

  @override
  String get markedAsDroppedOff => '已標記為完成存書';

  @override
  String get buyerNotifiedBookReturnsShop => '取消後買家會收到通知，書籍會回到商城重新販售。';

  @override
  String get dropOffPickupCode => '存書／取書代碼';

  @override
  String get enterCodeLocker => '請在書櫃上輸入此代碼';

  @override
  String get noRecentSearches => '還沒有搜尋紀錄';

  @override
  String get recentSearches => '最近搜尋';

  @override
  String get clearAll2 => '清除全部';

  @override
  String get searchTitleAuthorIsbn => '搜尋書名、作者、ISBN...';

  @override
  String get photoLimitReached => '照片已滿';

  @override
  String get canUploadUp10Photos => '最多只能上傳 10 張照片。';

  @override
  String get photosMissing => '照片不足';

  @override
  String missingTheseThreeRequired2(Object p0) => '還缺少：${p0}。這三張是必填的。';

  @override
  String get missingInformation => '資料不齊全';

  @override
  String get enterOwnPrice => '請輸入自訂價格。';

  @override
  String get invalidPrice => '價格不正確';

  @override
  String get priceMustGreaterThan02 => '售價必須大於 0 元。';

  @override
  String get priceCannotExceed99999 => '售價不可超過 99999 元。';

  @override
  String get chooseLockerLocation2 => '請選擇存放區域。';

  @override
  String get listed2 => '上架成功！';

  @override
  String get unknownError => '未知錯誤';

  @override
  String get couldNotListBook => '上架失敗';

  @override
  String serverError(Object p0) => '伺服器回應錯誤：${p0}';

  @override
  String get connectionProblem => '連線異常';

  @override
  String get couldNotReachServerUploadTimed => '無法連線至伺服器或上傳超時，請檢查網路狀態。';

  @override
  String get listBook => '確認完成上架';

  @override
  String get detailsPhotos => '詳細資訊與照片';

  @override
  String get loading => '載入中...';

  @override
  String get unknownLocker => '未知機櫃';

  @override
  String get enterTitle2 => '請輸入書名';

  @override
  String get chooseCategory2 => '請選擇分類';

  @override
  String get bookDetailsFilledAutomatically => '已自動帶入書籍資訊！';

  @override
  String get bookDetailsFilledFromBackupSource => '已透過備援系統帶入書籍資訊！';

  @override
  String get noSourceIsbnPleaseEnterDetails => '各系統皆找不到此 ISBN，請嘗試手動輸入';

  @override
  String get day => '日';

  @override
  String get tapIconRightScan => '可點擊右側圖示掃描';

  @override
  String get description => '書籍簡介';

  @override
  String get sellBook => '我要賣書';

  @override
  String get myShop => '我的賣場';

  @override
  String get sellerNoBooksSale => '這位賣家目前沒有販售中的書籍';

  @override
  String get loading2 => '載入中…';

  @override
  String sale2(Object p0) => '販售中 ${p0} 本';

  @override
  String get verifyEnableQuickSign => '驗證身分以啟用快速登入';

  @override
  String sign2(Object p0) => '已啟用 ${p0} 登入';

  @override
  String get quickSignTurnedOff => '已關閉快速登入';

  @override
  String get appearance2 => '外觀設定';

  @override
  String get signMethod => '登入方式';

  @override
  String get helpSupport => '說明與支援';

  @override
  String get contactUs => '聯絡我們';

  @override
  String get aboutSavemybook => '關於 SaveMyBook';

  @override
  String get settingsPrivacy => '設定與隱私';

  @override
  String sign3(Object p0) => '${p0} 登入';

  @override
  String unlockWithWhenOpenApp(Object p0) => '開啟 App 時用 ${p0} 解鎖';

  @override
  String get scanProfileQrCode => '掃描個人 QR Code';

  @override
  String get lineUpTheirQrCodeWith => '將對方的 QR Code 放入框內';

  @override
  String get notSavemybookProfileQrCode => '這不是 SaveMyBook 的個人 QR Code';

  @override
  String get ownQrCode => '這是你自己的 QR Code';

  @override
  String get couldNotStartChatPleaseTry => '無法建立聊天室，請稍後再試';

  @override
  String get linkCopied => '已複製連結';

  @override
  String addMeSavemybook(Object p0) => '在 SaveMyBook 上加我：${p0}';

  @override
  String addMeSavemybook2(Object p0, Object p1) => '在 SaveMyBook 上加我（${p0}）：${p1}';

  @override
  String get sharingCouldNotOpenSoLink => '無法開啟分享，已幫你複製連結';

  @override
  String get savedPhotos => '已儲存到相簿';

  @override
  String get couldNotSaveCheckPhotoLibrary => '儲存失敗，請確認已允許相簿權限';

  @override
  String get scanTheirQrCode => '掃描對方的 QR Code';

  @override
  String get copyLink => '複製連結';

  @override
  String get askQuestion => '提出問題';

  @override
  String get noEnquiriesYet => '還沒有任何問題紀錄';

  @override
  String get enterSubject => '請填寫主旨';

  @override
  String get addMoreDetailSoSupportCan => '請多描述一點，方便客服判斷';

  @override
  String get sentSupportReplySoon => '已送出，客服會盡快回覆';

  @override
  String get subject => '主旨';

  @override
  String get sumUpOneLine => '一句話描述問題';

  @override
  String get whatHappenedIncludeOrderNumberIf => '發生什麼事？有訂單編號的話一併附上';

  @override
  String get close => '結案';

  @override
  String get notAbleReplyAfterClosing => '結案後就不能再回覆了。';

  @override
  String get enquiryClosed => '工單已結案';

  @override
  String get changeStatus => '調整工單狀態';

  @override
  String get statusUpdated => '已更新狀態';

  @override
  String get enquiry => '工單';

  @override
  String get enquiryNotFound => '找不到這張工單';

  @override
  String get support => '客服';

  @override
  String get writeReply => '輸入回覆…';

  @override
  String get coins => '代幣中心';

  @override
  String get transactions => '交易紀錄';

  @override
  String get noTransactionsYet => '尚無交易紀錄';

  @override
  String get balance => '目前餘額';

  @override
  String hold(Object p0) => '凍結中 \\\$${p0}';

  @override
  String requestFailed2(Object p0) => '請求失敗（${p0}）';

  @override
  String get couldNotReachServer => '無法連線至伺服器';

  @override
  String get couldNotReachServerCheckConnection => '無法連線至伺服器，請檢查網路';

  @override
  String get signFailed => '登入失敗';

  @override
  String get signFailedPleaseTryAgain => '登入失敗，請稍後再試';

  @override
  String get signUpFailed => '註冊失敗';

  @override
  String get pleaseSignFirst => '請先登入';

  @override
  String get couldNotRelist => '重新上架失敗';

  @override
  String get couldNotRemoveFromSaved => '取消收藏失敗';

  @override
  String get couldNotSave => '收藏失敗';

  @override
  String get couldNotAddCart => '加入購物車失敗';

  @override
  String get checkoutFailed => '結帳失敗';

  @override
  String get couldNotCancelOrder => '取消訂單失敗';

  @override
  String get couldNotUpdateOrder => '更新訂單狀態失敗';

  @override
  String get couldNotSubmitDispute => '送出爭議申請失敗';

  @override
  String get couldNotSubmitReport => '送出檢舉失敗';

  @override
  String get updateFailed2 => '更新失敗';

  @override
  String get couldNotChangePassword => '更改密碼失敗';

  @override
  String get requestFailed => '申請失敗';

  @override
  String get couldNotCancel => '取消失敗';

  @override
  String get couldNotDelete => '刪除失敗';

  @override
  String get couldNotComplete => '執行失敗';

  @override
  String get couldNotSaveAnnouncement => '儲存公告失敗';

  @override
  String get couldNotSend => '送出失敗';

  @override
  String get actionFailed => '操作失敗';

  @override
  String get couldNotSave2 => '儲存失敗';

  @override
  String get documentUpdated => '已更新文件';

  @override
  String get couldNotAdjust => '調整失敗';

  @override
  String get couldNotProcessReport => '處理檢舉失敗';

  @override
  String get couldNotRecordDecision => '裁決失敗';

  @override
  String get couldNotReorder => '排序失敗';

  @override
  String get couldNotSaveLocker => '儲存書櫃失敗';

  @override
  String get fingerprint => '指紋';

  @override
  String get iris => '虹膜';

  @override
  String get verifyIdentityContinue => '請驗證身分以繼續';

  @override
  String get couldNotOpenPhotosCheckPermission => '無法開啟相簿，請確認已授權';

  @override
  String get choosePhotoSource => '選擇照片來源';

  @override
  String get takePhoto => '拍照';

  @override
  String get chooseFromPhotos => '從相簿選擇';

  @override
  String get couldNotOpenCameraCheckPermission => '無法開啟相機，請確認已授權';

  @override
  String get justNow => '剛剛';

  @override
  String minAgo(Object p0) => '${p0} 分鐘前';

  @override
  String hAgo(Object p0) => '${p0} 小時前';

  @override
  String dAgo(Object p0) => '${p0} 天前';

  @override
  String get pickDate => '請選擇日期';

  @override
  String get pickDate2 => '選擇日期';

  @override
  String msg5(Object p0, Object p1, Object p2) => '${p0} 年 ${p1} 月 ${p2} 日';

  @override
  String get passwordsNeedLeast8Characters => '密碼長度至少 8 個字元';

  @override
  String get passwordsMustIncludeLetter => '密碼需包含英文字母';

  @override
  String get passwordsMustIncludeNumber => '密碼需包含數字';

  @override
  String get seller2 => '賣家：';

  @override
  String get home => '首頁';

  @override
  String get alerts => '通知';

  @override
  String get collect => '取書';

  @override
  String get couldNotLoadPhoto => '無法載入這張照片';

  @override
  String slot2(Object p0) => '櫃號：${p0}';

  @override
  String confirmPutLocker(Object p0) => '確認已把《${p0}》放入書櫃了嗎？';

  @override
  String get enterTitleContent => '請填寫標題與內容';

  @override
  String get titleCannotExceed255Characters => '標題不可超過 255 個字元';

  @override
  String get contentNeedsLeast5Characters => '內容至少 5 個字元';

  @override
  String get publishAnnouncement => '發布推播';

  @override
  String get everyUserSeeAnnouncementOncePublished => '發布後全體使用者都會看到這則公告，確定發布嗎？';

  @override
  String get publish => '發布';

  @override
  String get announcementPublished => '公告已發布';

  @override
  String get draftSaved => '草稿已儲存';

  @override
  String get editAnnouncement => '編輯推播';

  @override
  String get newAnnouncement => '新增推播';

  @override
  String get title2 => '標題';

  @override
  String get announcementTitle => '公告標題';

  @override
  String get writeAnnouncement => '輸入推播內容';

  @override
  String get publishNow => '立即發布';

  @override
  String get leaveOffSaveAsDraft => '關閉時只會存成草稿';

  @override
  String get saveDraft => '儲存草稿';

  @override
  String get deleteAnnouncement => '刪除公告';

  @override
  String deleteP0CannotUndone(Object p0) => '確定要刪除「${p0}」嗎？此操作無法復原。';

  @override
  String get announcementDeleted => '公告已刪除';

  @override
  String get couldNotDeleteTryAgainLater => '刪除失敗，請稍後再試';

  @override
  String get announcements => '系統公告';

  @override
  String get noAnnouncementsYetTapAddOne => '尚無公告，點右上角新增';

  @override
  String get published => '已發布';

  @override
  String get draft => '草稿';

  @override
  String get audienceEveryone => '對象：全體使用者';

  @override
  String get backUpNow => '立即備份';

  @override
  String get wholeDatabaseExportedCompressedWithLot => '將匯出整個資料庫並壓縮保存。資料量大時可能需要數十秒，期間請不要離開這個畫面。';

  @override
  String get startBackup => '開始備份';

  @override
  String get backingUpDatabase => '正在備份資料庫';

  @override
  String get backupComplete => '備份完成';

  @override
  String get backupDeleted => '已刪除備份';

  @override
  String get databaseBackups => '資料庫備份';

  @override
  String backedUpDailyNewestP0Kept(Object p0) => '每日自動備份，保留最新 ${p0} 份';

  @override
  String get olderBackupsBeyondCountRemovedAutomatically => '超出份數的舊備份會自動清除。備份檔含全站個人資料，下載後請妥善保管，每次下載都會記入操作紀錄。';

  @override
  String get noBackupsYetSchedulerRunsOnce => '尚無備份紀錄。排程每天會自動跑一次，也可以按上方按鈕立刻產生一份。';

  @override
  String get deleteBackup => '刪除備份';

  @override
  String p0NNtheFileItsRecord(Object p0) => '${p0}\n\n檔案與紀錄會一併移除，無法復原。';

  @override
  String get manual => '手動';

  @override
  String get scheduled => '排程';

  @override
  String get download => '下載';

  @override
  String get downloadBackup => '下載備份';

  @override
  String fetchBackupComputerWithAuthorisationHeader(Object p0, Object p1) => '備份檔請在電腦上取回，並帶上你的授權標頭：\n\n${p0}\n\n檔案大小 ${p1}。';

  @override
  String get copyLink2 => '複製網址';

  @override
  String get downloadLinkCopied => '已複製下載網址';

  @override
  String get forceDelist => '強制下架';

  @override
  String get reasonDelistingSellerNotified => '下架原因，會通知賣家';

  @override
  String get delist3 => '確認下架';

  @override
  String get relist2 => '恢復上架';

  @override
  String putP0BackStore(Object p0) => '要讓《${p0}》重新出現在商城嗎？';

  @override
  String get relisted => '已恢復上架';

  @override
  String get searchTitleIsbnSeller => '搜尋書名、ISBN 或賣家';

  @override
  String get noBooksMatch => '找不到符合條件的書籍';

  @override
  String sellerP0P1(Object p0, Object p1) => '賣家 ${p0}｜${p1}';

  @override
  String isbnP0P1Views(Object p0, Object p1) => 'ISBN ${p0}｜瀏覽 ${p1}';

  @override
  String p0ReportsAwaitingReview(Object p0) => '有 ${p0} 筆待處理檢舉';

  @override
  String get enterLockerNameAddress => '請填寫書櫃名稱與地址';

  @override
  String get enterValidLatitudeLongitude => '請填寫正確的經緯度';

  @override
  String get latitudeMustBetween9090 => '緯度必須介於 -90 ~ 90';

  @override
  String get longitudeMustBetween180180 => '經度必須介於 -180 ~ 180';

  @override
  String get slotCountMustBetween1100 => '櫃位數量必須介於 1 ~ 100';

  @override
  String get closingTime => '關閉時間';

  @override
  String p0MustLookLikeHhMm(Object p0) => '${p0}格式應為 HH:mm，例：09:00';

  @override
  String get fillBothOpeningClosingTimes => '開放與關閉時間請一起填寫';

  @override
  String get lockerUpdated => '書櫃已更新';

  @override
  String get lockerAdded => '書櫃已新增';

  @override
  String get editLocker => '修改書櫃';

  @override
  String get newLocker => '新增書櫃';

  @override
  String get lockerName => '書櫃名稱';

  @override
  String get latitude => '緯度';

  @override
  String get longitude => '經度';

  @override
  String get slotCount => '櫃位數量';

  @override
  String get createLocker => '建立書櫃';

  @override
  String get disable => '停用';

  @override
  String onceDisabledP0NoLongerAppears(Object p0) => '停用後「${p0}」不會再出現在賣家的存放區域選單中。';

  @override
  String onceEnabledP0AvailableSellersAgain(Object p0) => '啟用後「${p0}」會重新開放給賣家選擇。';

  @override
  String get lockerDisabled => '書櫃已停用';

  @override
  String get lockerEnabled => '書櫃已啟用';

  @override
  String slotP0(Object p0) => '櫃位 ${p0}';

  @override
  String get slotStatusUpdated => '櫃位狀態已更新';

  @override
  String get lockerMonitor => '書櫃監控';

  @override
  String get searchLockerNameAddress => '搜尋書櫃名稱或地址';

  @override
  String get noLockersMatch => '沒有符合條件的書櫃';

  @override
  String get disabled => '已停用';

  @override
  String freeSlotsP0P1(Object p0, Object p1) => '剩餘空間：${p0} / ${p1}';

  @override
  String get newCategory => '新增分類';

  @override
  String get editCategory => '編輯分類';

  @override
  String get categoryName => '分類名稱';

  @override
  String get enterCategoryName => '請輸入分類名稱';

  @override
  String get categoryAdded => '已新增分類';

  @override
  String get categoryUpdated => '已更新分類';

  @override
  String get deleteCategory => '刪除分類';

  @override
  String deleteP0CannotUndone2(Object p0) => '要刪除「${p0}」嗎？此動作無法復原。';

  @override
  String get categoryDeleted => '已刪除分類';

  @override
  String get categories => '分類管理';

  @override
  String get noCategoriesYet => '尚無分類';

  @override
  String p0BooksUse(Object p0) => '${p0} 本書使用中';

  @override
  String get legalDocuments => '法律文件';

  @override
  String get notCreatedYet => '尚未建立';

  @override
  String updatedP0(Object p0) => '最後更新 ${p0}';

  @override
  String p0Characters(Object p0) => '${p0} 字';

  @override
  String p0SectionsP1Characters(Object p0, Object p1) => '${p0} 章・${p1} 字';

  @override
  String get deleteSection => '刪除章節';

  @override
  String get contentsSectionRemovedWith => '這一章的內容會一併移除。';

  @override
  String p0ItsContentsRemoved(Object p0) => '「${p0}」與其內容會一併移除。';

  @override
  String get discardChanges => '捨棄變更？';

  @override
  String get documentUnsavedChangesTheyLostIf => '這份文件有尚未儲存的修改，離開後會遺失。';

  @override
  String get discard => '捨棄';

  @override
  String get keepEditing => '繼續編輯';

  @override
  String get bothTitleContentRequired => '標題與內容都要填寫';

  @override
  String sectionP0NoTitleYet(Object p0) => '第 ${p0} 章還沒有標題';

  @override
  String updateP0(Object p0) => '確認更新${p0}？';

  @override
  String get documentBindingEveryUserSubmittingReplaces => '這份文件對所有使用者都有效力，送出後會立刻取代目前的版本。';

  @override
  String get yesUpdate => '我確認要更新';

  @override
  String get notifyEveryUser => '要通知所有使用者嗎？';

  @override
  String get updateNotify => '更新並通知';

  @override
  String get updateOnly => '只更新不通知';

  @override
  String get sections => '章節';

  @override
  String get plainText => '純文字';

  @override
  String get preview => '預覽';

  @override
  String get documentTitle => '文件標題';

  @override
  String get preamble => '前言';

  @override
  String get unnumberedOpeningTextLeaveEmptyIf => '開頭不編號的說明文字，沒有的話可以留空。';

  @override
  String get articles => '條文';

  @override
  String get numberedAutomatically => '編號自動產生';

  @override
  String get noArticlesYetAddFirstOne => '還沒有條文。按下方新增第一章。';

  @override
  String get addSection => '新增章節';

  @override
  String get untitledSection => '未命名章節';

  @override
  String get sectionTitle => '章節標題';

  @override
  String get bodySectionSingleLineBreaksKept => '這一章的內容。單行換行會照樣呈現，空一行代表另起一段。';

  @override
  String get emptyLineStartsParagraphParagraphWhose => '空一行分段。首行寫「1. 標題」的段落，切回章節模式時會被認成一章。';

  @override
  String get howUsersSee => '使用者看到的樣子';

  @override
  String get noContentYet => '尚無內容';

  @override
  String get unsaved => '尚未儲存';

  @override
  String get upDate => '已是最新版本';

  @override
  String get newQuestion => '新增問題';

  @override
  String get editQuestion => '編輯問題';

  @override
  String get question => '問題';

  @override
  String get answer => '答案';

  @override
  String get showHelpCentre => '顯示在幫助中心';

  @override
  String get bothQuestionAnswerRequired => '問題與答案都要填寫';

  @override
  String get added => '已新增';

  @override
  String get updated => '已更新';

  @override
  String get deleteQuestion => '刪除問題';

  @override
  String deleteP0(Object p0) => '要刪除「${p0}」嗎？';

  @override
  String get deleted => '已刪除';

  @override
  String get faq => '常見問題';

  @override
  String get noQuestionsYet2 => '尚無常見問題';

  @override
  String get dragHandleRightReorder => '拖曳右側把手可調整順序';

  @override
  String get hidden => '已隱藏';

  @override
  String get cancelDeletionRequest => '取消刪除申請';

  @override
  String p0SAccountReturnsNormalCountdown(Object p0) => '${p0} 的帳號會恢復正常，刪除倒數停止。';

  @override
  String get cancelDeletion => '取消刪除';

  @override
  String get deletionRequestCancelled => '已取消該會員的刪除申請';

  @override
  String get anonymiseNow => '立即執行匿名化';

  @override
  String eraseP0SPersonalDataDisable(Object p0) => '不等緩衝期結束，立刻清除 ${p0} 的個人資料並停用帳號。\n\n訂單與交易紀錄會保留，但暱稱會變成「已刪除的使用者」。此操作無法復原。';

  @override
  String get doNow => '立即執行';

  @override
  String get anonymised => '已完成匿名化';

  @override
  String get pendingDeletions => '待刪除帳號';

  @override
  String get noDeletionRequestsPending => '目前沒有待處理的刪除申請';

  @override
  String get dueSoon => '即將執行';

  @override
  String p0DaysLeft(Object p0) => '剩 ${p0} 天';

  @override
  String requestedP0ScheduledP1(Object p0, Object p1) => '申請於 ${p0}，預計 ${p1} 執行';

  @override
  String get disputeResolution => '交易仲裁';

  @override
  String orderP0P1(Object p0, Object p1) => '訂單 ${p0}｜\\\$${p1}';

  @override
  String reasonP0(Object p0) => '申訴理由：${p0}';

  @override
  String get decisionNoteOptional => '裁決說明（選填）';

  @override
  String get submitDecision => '送出裁決';

  @override
  String get decisionRecorded => '已完成裁決';

  @override
  String get resolveDispute => '仲裁交易';

  @override
  String get noDisputesKind => '目前沒有此類申訴案件';

  @override
  String orderNumberP0(Object p0) => '訂單編號：${p0}';

  @override
  String buyerP0SellerP1(Object p0, Object p1) => '買家：${p0}｜賣家：${p1}';

  @override
  String filedByP0(Object p0) => '申訴人：${p0}';

  @override
  String get handle => '處理';

  @override
  String get transactions2 => '交易管理';

  @override
  String get orders => '訂單管理';

  @override
  String get lookUpOrdersAdjustStatusBy => '查詢訂單、人工調整狀態';

  @override
  String get disputeListDecisions => '申訴列表與裁決';

  @override
  String get listings => '商品管理';

  @override
  String get allBooksForceDelisting => '全站書籍、強制下架';

  @override
  String get moderation => '內容審核';

  @override
  String get handleListingReports => '商品檢舉處理';

  @override
  String get addReorderDeleteBookCategories => '新增、排序與刪除書籍分類';

  @override
  String get members => '會員管理';

  @override
  String get memberControls => '會員管控';

  @override
  String get memberListSuspensionBlocklist => '會員列表、停權與黑名單';

  @override
  String get membershipTiers => '會員等級管理';

  @override
  String get tierThresholdsBenefits => '等級門檻與權益設定';

  @override
  String get wallets => '錢包管理';

  @override
  String get checkBalancesAddDeductCoinsBy => '查詢餘額、人工增減代幣';

  @override
  String get hardwareOperations => '硬體與營運';

  @override
  String get lockerSlotStatus => '書櫃與櫃位狀態';

  @override
  String get maintenanceLog => '維修紀錄';

  @override
  String get lockerOperationHistory => '書櫃相關操作紀錄';

  @override
  String get reports => '營運報表';

  @override
  String get ordersRevenueMemberGrowth => '訂單、營收與會員成長';

  @override
  String get announcements2 => '推播管理';

  @override
  String get supportEnquiries => '客服工單';

  @override
  String get replyQuestionsFromUsers => '回覆使用者提出的問題';

  @override
  String get faqShownHelpCentre => '幫助中心的常見問題';

  @override
  String get termsPrivacyPolicyAbout => '服務條款、隱私權政策、關於我們';

  @override
  String get adminAuditLog => '管理操作紀錄';

  @override
  String get auditTrailAdminChanges => '管理員異動的稽核軌跡';

  @override
  String get systemOperations => '系統維運';

  @override
  String get dailyBackupsManualRunsDownloads => '每日自動備份、手動觸發與下載';

  @override
  String get deletionRequestsInsideGracePeriodCancel => '緩衝期內的刪除申請，可代為取消或立即執行';

  @override
  String get members2 => '會員數';

  @override
  String get todaySOrders => '今日訂單';

  @override
  String get openCases => '待處理案件';

  @override
  String get activeLockers => '啟用書櫃';

  @override
  String get newTier => '新增等級';

  @override
  String get editTier => '編輯等級';

  @override
  String get tierName => '等級名稱';

  @override
  String get minimumPoints => '最低點數';

  @override
  String get maximumPointsLeaveEmptyNoCap => '最高點數（留空 = 無上限）';

  @override
  String get benefitsSeparatedByCommasLineBreaks => '權益，用頓號或換行分隔，會在會員等級頁逐條顯示';

  @override
  String get enterTierName => '請輸入等級名稱';

  @override
  String get maximumPointsMustExceedMinimum => '最高點數必須大於最低點數';

  @override
  String get tierAdded => '已新增等級';

  @override
  String get tierUpdated => '已更新等級';

  @override
  String get deleteTier => '刪除等級';

  @override
  String deleteP0MembersTierDropNext(Object p0) => '要刪除「${p0}」嗎？已在這個等級的會員會退到下一個符合的等級。';

  @override
  String get tierDeleted => '已刪除等級';

  @override
  String get noMembershipTiersSetUp => '尚未設定會員等級';

  @override
  String p0PointsUp(Object p0) => '${p0} 點以上';

  @override
  String p0P1Points(Object p0, Object p1) => '${p0} ~ ${p1} 點';

  @override
  String get noBenefitsDescribedYet => '尚未填寫權益說明';

  @override
  String get noMaintenanceRecords => '目前沒有維修紀錄';

  @override
  String get noFurtherDetail => '（無額外說明）';

  @override
  String get operator => '操作人';

  @override
  String get unknown => '（未知）';

  @override
  String get time => '時間';

  @override
  String get recordNumber => '紀錄編號';

  @override
  String operatorP0(Object p0) => '操作人：${p0}';

  @override
  String get suspendAccount => '停權此帳號';

  @override
  String get reinstateAccount => '恢復此帳號';

  @override
  String get addBlocklist => '加入黑名單';

  @override
  String get removeFromBlocklist => '移出黑名單';

  @override
  String p0SignedOutImmediatelyCanNo(Object p0) => '${p0} 會立刻被登出，且無法再使用 App 的任何功能。';

  @override
  String p0AbleSignAgain(Object p0) => '${p0} 將可以重新登入使用。';

  @override
  String get accountStatusUpdated => '已更新帳號狀態';

  @override
  String get removeAdmin => '取消管理員';

  @override
  String get makeAdmin => '設為管理員';

  @override
  String p0LosesEveryAdminPermissionImmediately(Object p0) => '${p0} 將立刻失去所有後台權限。';

  @override
  String p0GainsAccessAdminAreaWith(Object p0) => '${p0} 將可以進入管理後台，預設擁有全部權限，可再逐項調整。';

  @override
  String get roleUpdated => '已更新身分';

  @override
  String manualP0P1(Object p0, Object p1) => '、手動 ${p0}${p1}';

  @override
  String get adjustMembershipTier => '調整會員等級';

  @override
  String currentlyP0PointsAutomaticP1P2(Object p0, Object p1, Object p2) => '目前 ${p0} 點（自動 ${p1}${p2}）';

  @override
  String p0P1Points2(Object p0, Object p1) => '${p0}（${p1} 點）';

  @override
  String get adjustPointsManually => '手動加減點數';

  @override
  String get backAutomatic => '恢復自動計算';

  @override
  String get backAutomatic2 => '已恢復自動計算';

  @override
  String get pointAdjustment => '加減點數';

  @override
  String get positiveAddsNegativeDeductsEG => '正數增加、負數扣除，例如 -50';

  @override
  String get apply => '套用';

  @override
  String get enterNonZeroWholeNumber => '請輸入非零的整數';

  @override
  String get pointsAdjusted => '已調整點數';

  @override
  String get tierAdjusted => '已調整等級';

  @override
  String get permissionGranted => '已開放權限';

  @override
  String get permissionRevoked => '已收回權限';

  @override
  String get grantAllPermissions => '開放全部權限';

  @override
  String get revokeAllPermissions => '收回全部權限';

  @override
  String p0AbleUseEveryAdminFeature(Object p0) => '${p0} 將可以使用後台所有功能。';

  @override
  String p0ReachAdminAreaButUnable(Object p0) => '${p0} 進入後台後將無法使用任何功能。';

  @override
  String get allPermissionsGranted => '已開放全部權限';

  @override
  String get allPermissionsRevoked => '已收回全部權限';

  @override
  String get memberSettings => '會員設定';

  @override
  String get noDataMember => '找不到這位會員的資料';

  @override
  String get listings2 => '上架書籍';

  @override
  String get completedTrades => '完成交易';

  @override
  String get joined => '加入日期';

  @override
  String get accountStatus => '帳號狀態';

  @override
  String get ownAccountStatusPermissionsCannotChanged => '這是你自己的帳號，無法在這裡調整狀態與權限。';

  @override
  String get accountEnabled => '啟用帳號';

  @override
  String get canSignUseAppNormally => '可以正常登入使用';

  @override
  String get suspendedSignedOutImmediatelyAfterSigning => '已停權，登入後會被立刻登出';

  @override
  String get blocked => '列入黑名單';

  @override
  String get blockedNoFeaturesAvailable => '已封鎖，無法使用任何功能';

  @override
  String get notBlocked => '未封鎖';

  @override
  String get role => '身分';

  @override
  String p0PointsAutomaticP1P2(Object p0, Object p1, Object p2) => '${p0} 點（自動 ${p1}${p2}）';

  @override
  String get memberSTierBeenAdjustedBy => '這位會員的等級目前有人工調整，不完全依交易自動計算。';

  @override
  String get adjustTier => '調整等級';

  @override
  String get adminPermissions => '後台權限';

  @override
  String get all => '全開';

  @override
  String get allOff => '全關';

  @override
  String get reinstateAccount2 => '恢復帳號';

  @override
  String get suspendAccount2 => '停權帳號';

  @override
  String runP1P0(Object p0, Object p1) => '確定要對「${p0}」執行「${p1}」嗎？';

  @override
  String updatedP0SStatus(Object p0) => '已更新 ${p0} 的狀態';

  @override
  String get fullSettingsTierPermissions => '完整設定（等級、權限）';

  @override
  String get members3 => '會員列表';

  @override
  String get searchDisplayNameEmail => '搜尋暱稱或 Email';

  @override
  String get noMembersMatch => '找不到符合條件的會員';

  @override
  String get sales2 => '銷售';

  @override
  String get created => '創建日期';

  @override
  String get noActivityYet => '尚無操作紀錄';

  @override
  String get changeOrderStatus => '調整訂單狀態';

  @override
  String orderP0(Object p0) => '訂單 ${p0}';

  @override
  String get reasonChange => '調整說明';

  @override
  String get sentBuyerAsWellOptional => '會一併通知買家（選填）';

  @override
  String get applyChange => '確認調整';

  @override
  String get orderStatusUpdated => '訂單狀態已更新';

  @override
  String get searchOrderNumberBuyerSeller => '搜尋訂單編號或買賣家';

  @override
  String get noOrdersMatch => '找不到符合條件的訂單';

  @override
  String get noItems => '（無品項）';

  @override
  String p0ItemsTotal(Object p0) => '等 ${p0} 項';

  @override
  String buyerP0SellerP12(Object p0, Object p1) => '買家 ${p0}｜賣家 ${p1}';

  @override
  String lockerP0(Object p0) => '書櫃：${p0}';

  @override
  String cancellationReasonP0(Object p0) => '取消原因：${p0}';

  @override
  String get reviewReport => '審核檢舉';

  @override
  String reportedP0P1(Object p0, Object p1) => '被檢舉${p0}：${p1}';

  @override
  String reasonP02(Object p0) => '違規原因：${p0}';

  @override
  String get handlingNoteOptional => '處理備註（選填）';

  @override
  String get delistListingAsWell => '同時將該商品下架';

  @override
  String get dismissReport => '駁回檢舉';

  @override
  String get reportHandled => '檢舉已處理';

  @override
  String get noReportsKind => '目前沒有此類檢舉案件';

  @override
  String reportedByP0(Object p0) => '檢舉人：${p0}';

  @override
  String get review => '審核';

  @override
  String noteP0(Object p0) => '備註：${p0}';

  @override
  String get last7Days => '近 7 天';

  @override
  String get last30Days => '近 30 天';

  @override
  String get ordersPerDay => '每日訂單量';

  @override
  String get revenuePerDay => '每日成交金額';

  @override
  String get newMembersPerDay => '每日新增會員';

  @override
  String get newOrders => '新增訂單';

  @override
  String get newMembers => '新增會員';

  @override
  String get newListings => '新上架書籍';

  @override
  String get completedRevenue => '已完成交易額';

  @override
  String p0Orders(Object p0) => '${p0} 筆';

  @override
  String peakP0(Object p0) => '最高 ${p0}';

  @override
  String get topCategoriesByListings => '熱門分類（依上架數）';

  @override
  String get replied => '已回覆';

  @override
  String get noEnquiriesCategory => '此分類目前沒有工單';

  @override
  String get addCoins => '增加代幣';

  @override
  String get deductCoins => '扣除代幣';

  @override
  String get amountPositiveWholeNumber => '金額（正整數）';

  @override
  String get reasonAdjustmentRequired => '調整原因（必填）';

  @override
  String get add2 => '確認增加';

  @override
  String get deduct => '確認扣除';

  @override
  String get enterAmountGreaterThan0 => '請輸入大於 0 的金額';

  @override
  String get enterReasonAdjustment => '請填寫調整原因';

  @override
  String get member2 => '這位會員';

  @override
  String get add3 => '增加';

  @override
  String get deduct2 => '扣除';

  @override
  String get confirmAddingCoins => '確認增加代幣';

  @override
  String get confirmDeductingCoins => '確認扣除代幣';

  @override
  String p1P2CoinsP0NreasonP3(Object p0, Object p1, Object p2, Object p3) => '將為 ${p0} ${p1} ${p2} 代幣。\n原因：${p3}';

  @override
  String get balanceAdjusted => '已調整餘額';

  @override
  String get memberWallets => '會員錢包';

  @override
  String get transactions3 => '帳務紀錄';

  @override
  String get memberNoTransactionsYet => '此會員尚無帳務紀錄。';

  @override
  String get balanceCoins => '目前餘額（代幣）';

  @override
  String get hold2 => '凍結中';

  @override
  String get total2 => '累積收入';

  @override
  String get totalOut => '累積支出';

  @override
  String balanceP0(Object p0) => '餘 ${p0}';

  @override
  String get suspensionBlocklistRoles => '停權、黑名單、身分';

  @override
  String get tierThresholdsManualAdjustments => '等級門檻與人工調整';

  @override
  String get booksCategories => '書籍與分類';

  @override
  String get reportReview => '檢舉審核';

  @override
  String get handleListingReports2 => '處理商品檢舉';

  @override
  String get lookUpChangeOrderStatus => '查詢與調整訂單狀態';

  @override
  String get decideDisputeCases => '申訴案件裁決';

  @override
  String get checkAdjustCoinBalances => '查詢與增減代幣';

  @override
  String get hardware => '硬體維護';

  @override
  String get lockersSlots => '書櫃與櫃位';

  @override
  String get announcementsDocuments => '公告與文件';

  @override
  String get announcementsFaqLegalDocuments => '公告、常見問題、法律文件';

  @override
  String get replyUserQuestions => '回覆使用者問題';

  @override
  String get databaseBackupDownloadOffByDefault => '資料庫備份與下載，預設關閉';

  @override
  String p0Locker(Object p0) => '${p0}書櫃';

  @override
  String everyActiveMemberReceivesP0Updated(Object p0) => '每一位啟用中的會員都會收到一則「${p0}已更新」的通知。';

  @override
  String get orderPlaced => '成立訂單';

  @override
  String get paid => '付款';

  @override
  String get sellerDroppedOff => '賣家放書';

  @override
  String get buyerCollected => '買家取書';

  @override
  String get completed => '完成';

  @override
  String get editBookDetails => '編輯書籍資料';

  @override
  String sellerP0TheyNotifiedSave(Object p0) => '賣家 ${p0}・儲存後會通知他';

  @override
  String get priceCoins => '售價（代幣）';

  @override
  String get k1013Digits2 => '10 或 13 位數字';

  @override
  String get category => '分類';

  @override
  String get description2 => '商品描述';

  @override
  String get titleRequired => '書名必填';

  @override
  String get nothingChanged => '沒有變更';

  @override
  String get resetPassword => '重設密碼';

  @override
  String p0SCurrentPasswordStopsWorking(Object p0) => '${p0} 目前的密碼會立刻失效，必須改用接下來產生的臨時密碼登入。\n\n密碼由系統產生，你不能自己指定。';

  @override
  String get generateTemporaryPassword => '產生臨時密碼';

  @override
  String get temporaryPassword => '臨時密碼';

  @override
  String p0SPasswordBeenResetPassword(Object p0) => '${p0} 的密碼已重設。這組密碼只會出現這一次，關掉後無法再查看。';

  @override
  String get remindThemChangeSettingsChangePassword => '請提醒對方登入後立刻到「設定 → 更改密碼」改掉。';

  @override
  String get temporaryPasswordCopied => '已複製臨時密碼';

  @override
  String get copy => '複製';

  @override
  String get cannotResetAnotherAdminSPassword => '不能重設其他管理員的密碼';

  @override
  String get generateTemporaryPasswordHandOver => '產生一組臨時密碼交給使用者';

  @override
  String get orderNumberCopied => '已複製訂單編號';

  @override
  String get orderNotFound => '找不到這筆訂單';

  @override
  String get paidWithCoins => '代幣支付';

  @override
  String get bankTransfer => '銀行轉帳';

  @override
  String get notPaidYet => '尚未付款';

  @override
  String get progress => '流程';

  @override
  String get notYet => '尚未發生';

  @override
  String get buyerSeller => '買賣雙方';

  @override
  String get items3 => '品項';

  @override
  String get bookDeleted => '（書籍已刪除）';

  @override
  String get notAssignedYet2 => '尚未指派';

  @override
  String get pickupCodeCopied => '已複製取書碼';

  @override
  String get walletActivity => '錢包異動';

  @override
  String balanceP02(Object p0) => '餘 ${p0}';

  @override
  String get refunds => '退款紀錄';

  @override
  String requestedP0NotProcessedYet(Object p0) => '申請於 ${p0}，尚未處理';

  @override
  String processedP0(Object p0) => '處理於 ${p0}';

  @override
  String get disputes => '申訴';

  @override
  String filedP0(Object p0) => '申請於 ${p0}';

  @override
  String decidedP0(Object p0) => '裁決於 ${p0}';

  @override
  String createdP0(Object p0) => '建立於 ${p0}';

  @override
  String get shareBook => '分享書籍';

  @override
  String get shareAnotherApp => '分享到其他 App';

  @override
  String get approved => '已核准';

  @override
  String get awaitingRefund => '待退款';

  @override
  String get declined => '不予退款';

  @override
  String get changeOwnPasswordGoSettingsChange => '要改自己的密碼請到「設定 → 更改密碼」';

  @override
  String get memberNotAdminSoThereNo => '這位會員不是管理員，沒有後台權限可以設定。先在上方把身分改成管理員。';

  @override
  String get you => '你自己';

  @override
  String isbnMust1013DigitsOne(Object p0) => 'ISBN 要 10 或 13 碼，目前 ${p0} 碼';

  @override
  String get screenUnsavedChangesTheyLostIf => '這個畫面有尚未儲存的修改，離開後會遺失。';

  @override
  String stillNeededP0(Object p0) => '還差：${p0}';

  @override
  String photosP0(Object p0) => '照片：${p0} 張';

  @override
  String get confirmListing => '確認上架';

  @override
  String get lookingUpBook => '查詢書籍資料中';

  @override
  String get scan => '掃描';

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
