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
  String get language;
  String get languageSystem;
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
  String get cancelAccountDeletion;
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
  String get messageSeller;
  String get listing;
  String get addCart;
  String get bookBeenReportedUnderReviewStays;
  String get violationWasConfirmedBookPleaseCheck;
  String get delist;
  String removedFromShopBuyersNoLonger(Object p0);
  String get delist2;
  String get couldNotDelistPleaseTryAgain;
  String listedAgain(Object p0);
  String get notListedAnyBooksYet;
  String get noBooksCategory;
  String get relist;
  String get remove;
  String get couldNotRemoveRestored;
  String get selectBooksWantCheckOut;
  String notEnoughCoinsOrderNeedsBut(Object p0, Object p1);
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
  String get submitDispute2;
  String get orderNumber;
  String get eGSmb20260910123456789;
  String get whatHappened;
  String get describeProblemEGConditionDoes;
  String get submit;
  String get uploadPhotos;
  String get canAttachUp6Photos;
  String get keepLeastOnePhoto;
  String get photoDeleted;
  String get couldNotDeletePhotoPleaseTry;
  String get canUp10Photos;
  String get deletePhoto;
  String get cannotUndoneContinue;
  String get photoMissingDataRefreshTryAgain;
  String get enterPrice;
  String get priceMustGreaterThan0;
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
  String collected(Object p0);
  String order2(Object p0);
  String get signingOut;
  String get myAccount;
  String get personNotWrittenBioYet;
  String get topTierReached;
  String morePointsReach(Object p0, Object p1);
  String get purchases;
  String get sales;
  String get settings;
  String get signOut2;
  String cancelOrderBookReturnsShop(Object p0);
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
  String get displayName;
  String get emailSignWith;
  String get least8CharactersWithLettersNumbers;
  String get confirmPassword;
  String get enterPasswordAgain2;
  String get alreadyAccountGoBackSign;
  String get markAsDroppedOff;
  String get droppedOff;
  String get markedAsDroppedOff;
  String get buyerNotifiedBookReturnsShop;
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
  String get listBook;
  String get detailsPhotos;
  String get loading;
  String get unknownLocker;
  String get enterTitle2;
  String get chooseCategory2;
  String get bookDetailsFilledAutomatically;
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
  String sign3(Object p0);
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
  String sectionP0NoTitleYet(Object p0);
  String get sections;
  String get plainText;
  String get preview;
  String get documentTitle;
  String get preamble;
  String get unnumberedOpeningTextLeaveEmptyIf;
  String get articles;
  String get noArticlesYetAddFirstOne;
  String get addSection;
  String get untitledSection;
  String get sectionTitle;
  String get bodySectionSingleLineBreaksKept;
  String get howUsersSee;
  String get noContentYet;
  String get unsaved;
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
  String get listings;
  String get moderation;
  String get handleListingReports;
  String get members;
  String get memberControls;
  String get membershipTiers;
  String get wallets;
  String get hardwareOperations;
  String get maintenanceLog;
  String get reports;
  String get ordersRevenueMemberGrowth;
  String get supportEnquiries;
  String get adminAuditLog;
  String get systemOperations;
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
  String get buyerSPaymentGoesBackTheir;
  String get orderReturnsWhereWasBeforeDispute;
  String get orderWasAlreadyRefundedBuyerCannot;
  String get completedOrderCanOnlyChangedRefund;
  String confirmingPaysP0TokensSellerMarks(Object p0);
  String confirmingTakesP0TokensBackFrom(Object p0);
  String get ifBuyerNotBeenRefundedYet;
  String confirmingRefundsBuyerSP0Tokens(Object p0);
  String get donTPermissionYourselfSoCan;
  String get notificationsTurnedOff;
  String get openSettings;
  String get sendTestNotification;
  String get arrives10SecondsGoHomeScreen;
  String get systemNotificationSettings;
  String get pushNotificationsNotSetUpBuild;
  String get notificationsTurnedOffAllowAppSend;
  String get restoreBackup;
  String wholeDatabaseGoBackP0Orders(Object p0);
  String get password2;
  String get startRestore;
  String get backingUpCurrentState;
  String databaseRestoredPreviousStateWasBacked(Object p0);
  String restoreFailedDatabaseMayUnchangedPartly(Object p0);
  String get autoBackupBeforeRestore;
  String get restoreBackup2;
  String get restoringDatabase;
  String p0SecondsSoFarKeepApp(Object p0);
  String get majorUpdate2;
  String get minorEdit;
  String get books;
  String get orders2;
  String get wallets2;
  String get announcements3;
  String get legal;
  String get backups;
  String get undoAction;
  String p0NNtheDataGoesBack(Object p0);
  String get undo;
  String get undone;
  String get searchActionsEGNicknameBook;
  String viewP0Changes(Object p0);
  String get undoAction2;
  String get noAnnouncements;
  String get canTContinueWithoutAccepting;
  String needAcceptLatestP0UseP1(Object p0);
  String get goBack;
  String p0BeenUpdated(Object p0);
  String readLatestVersionUpdatedP0Accept(Object p0);
  String get scrollEndContinue;
  String get iVeReadAccept;
  String get decline;
  String get viewDetails;
  String get notFoundMayBeenDeletedRemoved;
  String get chatMessages;
  String get promotions2;
  String get supportRepliesPasswordResetsPolicyUpdates;
  String get notFilled;
  String get canTChanged;
  String get voice;
  String get reservation;
  String get messageUnsent;
  String get confirmBeforeExportingData;
  String get exportFailedPleaseTryAgainLater;
  String get refresh;
  String get clearFilters;
  String get expired;
  String get verificationCancelled;
  String get openingClosingTimesCanTSame;
  String slotCurrentlyP0MayOrderProgress(Object p0, Object p1);
  String get active;
  String get categoryWithNameAlreadyExists;
  String orderP0ClosedAsP1P2(Object p0, Object p1, Object p2);
  String orderP0ClosedAsP1Can(Object p0, Object p1);
  String get clearSearch;
  String get enterMinimumPoints;
  String pointsRangeOverlapsWithP0P1(Object p0, Object p1);
  String noTierCoversP0P1Points(Object p0, Object p1);
  String p0TakenDownRightAwayOther(Object p0);
  String get searchReportedItemReporterReason;
  String get couldnTLoadStatisticsRightNow;
  String get searchSubjectMemberMessage;
  String get balance3;
  String get hold3;
  String get zeroBalance;
  String get amountCanMost2DecimalPlaces;
  String get singleAdjustmentCanTExceed1;
  String wouldMakeBalanceNegativeCurrentBalance(Object p0);
  String get amountUp2Decimals;
  String p0NbalanceAfterP1(Object p0, Object p1);
  String get cameraAccessOff;
  String get couldNotStartCamera;
  String allowP0UseCameraSettingsThen(Object p0);
  String get closeScreenTryAgain;
  String get couldnTGetLocationCheckLocation;
  String get bookReservedAnotherBuyerCanT;
  String reservedAnotherBuyerUntilP0(Object p0);
  String sellerHoldingUntilP0(Object p0);
  String get checkOutBeforeHoldEndsOther;
  String get copyAddress;
  String p0Away(Object p0);
  String get locating;
  String get showDistance;
  String get reserved;
  String get goCheckout;
  String get cart2;
  String get buyNow;
  String p0Delisted(Object p0);
  String noBooksMatchP0(Object p0);
  String p0BooksP1Views(Object p0, Object p1);
  String get searchTitleAuthorIsbn2;
  String removedP0(Object p0);
  String removedP0Items(Object p0);
  String get paymentSuccessful;
  String p0BooksSplitIntoP1Orders(Object p0, Object p1);
  String get keepBrowsing;
  String get reload;
  String get browseBooks;
  String p0Sellers(Object p0);
  String unavailableP0(Object p0);
  String get removeAll;
  String get goWallet;
  String fromP0SellersCheckoutCreatesP1(Object p0, Object p1);
  String get otherDevicesNeedSignAgainWith;
  String get searchChats;
  String get noMatchingChats;
  String get read;
  String get chatNotFound;
  String get messagesCanUp2000Characters;
  String get canTSendRightNowPlease;
  String get reserveBook;
  String get quickReplies;
  String get imagesMust10MbSmaller;
  String get recordingFailedPleaseTryAgain;
  String get voiceMessageTooLargePleaseRecord;
  String get microphoneAllowedPressHoldAgainRecord;
  String get microphoneAccessNeededRecordTurnSettings;
  String get couldnTStartRecordingPleaseTry;
  String get selectText;
  String get unsend;
  String get resend;
  String get unsendMessage;
  String get neitherAbleSeeMessageSContent;
  String get reportMessage;
  String get reservationSentWaitingSeller;
  String get acceptReservation;
  String p0HeldThemP1HoursNo(Object p0, Object p1);
  String get accept;
  String get reservationAccepted;
  String get declineReservation;
  String get decline2;
  String get reservationDeclined;
  String get cancelReservation;
  String p0NoLongerHeld(Object p0);
  String get cancelReservation2;
  String get reservationCanceled;
  String get notNow2;
  String get couldnTLoadConversationPleaseTry;
  String get accountCanTReceiveMessagesRight;
  String get holdMicTalkReleaseSend;
  String get startConversation;
  String p0New(Object p0);
  String get connectionUnstableMessagesCanTSent;
  String get retry;
  String get stillAvailable;
  String get couldLowerPriceBit;
  String get whenCanPutLocker;
  String get unsentMessage;
  String get theyUnsentMessage;
  String get reservationDetailsArenTAvailableRight;
  String get sending;
  String get couldNotUploadPhotosPleaseTry;
  String get bookDetailsUpdatedButPhotosCouldn;
  String get sNotIsbnBarcodeScanOne;
  String get couldnTLoadCategoriesTapRetry;
  String removedP0FromSaved(Object p0);
  String get recentlyViewedCleared;
  String clearP0(Object p0);
  String get picked;
  String get recentlyViewed;
  String get clear;
  String get notificationDeleted;
  String get pleasePutBookAssignedLockerSoon;
  String get weLlLetKnowWhenSeller;
  String get waitingBuyerCollect;
  String get transactionCompleteThank;
  String get confirmVeTakenBookFromLocker;
  String p0Orders2(Object p0);
  String p0ReadyPickup(Object p0);
  String get pickUp;
  String get saved;
  String get accountSecurity;
  String get searchHistoryCleared;
  String get trendingBooks;
  String get signOutDevice;
  String signOutP0(Object p0);
  String get deviceSignedOutRightAwayStop;
  String get deviceSignedOut;
  String get signOutAllDevicesIncludingOne;
  String get signOutAllOtherDevices;
  String get everyDeviceIncludingOneSignedOut;
  String get everyDeviceExceptOneSignedOut;
  String signedOutP0OtherDevices(Object p0);
  String get unknownDevice;
  String get couldnTLoadDevices;
  String get device;
  String get otherDevices;
  String otherDevicesP0(Object p0);
  String get noOtherDevicesSigned;
  String get signedDevices;
  String get activeNow;
  String lastActiveP0(Object p0);
  String signedP0(Object p0);
  String get biometricPayment;
  String get paymentPinMust6Digits;
  String get pinTooEasyGuessTryAnother;
  String get enterPasswordResetPaymentPin;
  String get confirmSBeforeSettingPaymentPin;
  String get pinsDonTMatchStartAgain;
  String get paymentPinReset;
  String get paymentPinSet;
  String get verifyingIdentity;
  String get enterAgainConfirm;
  String get set6DigitPaymentPin;
  String get enterSamePinAgain;
  String get avoidRepeatedSequentialPatternedDigits;
  String get resetPaymentPin;
  String get paymentPin;
  String stepP02(Object p0);
  String get setPaymentPinFirst;
  String get setPaymentPinFirstSoFallback;
  String get setUpNow;
  String get biometricPaymentTurnedOff;
  String get verifyTurnBiometricPayment;
  String p0PaymentsTurned(Object p0);
  String get securitySettingsUnavailableRightNowMay;
  String payWithP0(Object p0);
  String get accountWellProtected;
  String get accountCouldSafer;
  String get setPaymentPinTurnBiometricPayment;
  String tooManyAttemptsLockedUntilP0(Object p0);
  String get notSetRequiredBeforeCheckout;
  String get change;
  String get forgotPaymentPin;
  String p0Devices(Object p0);
  String get restoredUnfinishedListing;
  String get isbnSCheckDigitInvalidPlease;
  String get draftSavedAutomatically;
  String get continueUnfinishedListing;
  String clearedP0MbCache(Object p0);
  String get cacheCleared;
  String get storage;
  String get clearCache;
  String get couldNotLoadNotificationSettings;
  String get month;
  String p0P1(Object p0, Object p1);
  String get noIncomeYet;
  String get noSpendingYet;
  String get income;
  String get spending;
  String get totalIncome;
  String get totalSpending;
  String get item3;
  String get details;
  String get balanceAfter;
  String get transactionId;
  String get sessionExpiredPleaseSignAgain;
  String get serviceTemporarilyUnavailableTryAgainLater;
  String get uploadFailedTryAgainLater;
  String get nearby;
  String p0M(Object p0);
  String p0Km(Object p0);
  String get iphoneDidnTReceiveApnsToken;
  String get firebaseDidnTIssuePushToken;
  String couldnTGetPushTokenP0(Object p0);
  String couldnTRegisterPushTokenWith(Object p0);
  String get protectCoinsCheckoutRequires6Digit;
  String confirmPaymentP0Coins(Object p0);
  String get enterPasswordContinue;
  String get verifyS;
  String get amount;
  String p0Coins(Object p0);
  String get enterPaymentPin;
  String get enterPaymentPinContinue;
  String get paymentPinResetEnterAgain;
  String get usePasswordInstead;
  String get couldnTGetLocationLockersShown;
  String p0SlotsFree(Object p0);
  String openP0(Object p0);
  String get nearest;
  String get noFreeSlots;
  String get turnLocationSortByDistance;
  String get lockerNoFreeSlotsRightNow;
  String get turn;
  String get noLockersAvailable;
  String get noMatchingOptions;
  String get undo2;
  String copiedP0(Object p0);
  String get typing;
  String get today;
  String get yesterday;
  String p0P12(Object p0, Object p1);
  String p1P2P0(Object p0, Object p1, Object p2);
  String get releaseCancel;
  String get awaitingReply;
  String heldUntilP0(Object p0);
  String get declined2;
  String get closed;
  String get theyWantReserveBook;
  String get sentReservationRequest;
  String holdP0H(Object p0);
  String get holdPeriod;
  String get messageSellerOptional;
  String get sendRequest;
  String p0Hours(Object p0);
  String p0P1DigitsEntered(Object p0, Object p1);
  String get buildSProvisioningProfileDoesnT;
  String get checkPhoneOnlinePushNotificationsAdded;
  String iphoneFailedRegisterPushNotificationsWith(Object p0, Object p1);
  String get serverNotBeenUpdatedSupportFeature;
  String get someFeaturesTemporarilyUnavailableWhileServer;
  String serverRunningOutdatedApiRevisionP0(Object p0, Object p1);
  String databaseMigrationsNotYetRunP0(Object p0);
  String serverVersionP0(Object p0);
  String get runNpmRunVerifyApiDirectory;
  String get serverUpdateRequired;
  String versionP0(Object p0);
  String get requiresUserConsent;
  String get unsavedDraft;
  String get allBooks;
  String get results;
  String get sortBy;
  String get themeColour;
  String get forestGreen;
  String get oceanBlue;
  String get lavender;
  String get terracotta;
  String get amber;
  String get rose;
  String get graphite;
  String get mistBlue;
  String get draftRestored;
  String get convertSections;
  String get currentContentDoesNotFullyMatch;
  String get convert;
  String get keepPlainText;
  String get noSectionHeadingsDetectedFullText;
  String deletedP0(Object p0);
  String get renameSection;
  String get editContent;
  String get rename;
  String get addSectionBelow;
  String get moveUp;
  String get moveDown;
  String get enterDocumentTitle;
  String get enterDocumentContent;
  String p0NowVersionP1(Object p0, Object p1);
  String versionP0P1(Object p0, Object p1);
  String unsavedDraftFromP0Found(Object p0);
  String get documentWasUpdatedAfterDraftWas;
  String get discardDraft;
  String get restoreDraft;
  String get sectionTitleRequired;
  String get documentSFormatDoesNotFully;
  String get enterPasteFullTextHere;
  String get noSectionHeadingsDetected;
  String p0SectionsDetected(Object p0);
  String get paragraphWhoseFirstLine1Title;
  String get sectionNumbersMustStart1Increase;
  String get blankLineStartsNewParagraphSingle;
  String get whenSwitchingSectionsAskedConfirmAny;
  String get howSectionHeadingsDetected;
  String get titleEdited;
  String p0Added(Object p0);
  String p0Removed(Object p0);
  String p0Edited(Object p0);
  String get sectionsReordered;
  String get preambleEdited;
  String get contentEdited;
  String p0Characters2(Object p0);
  String p0Characters3(Object p0);
  String get formattingAdjusted;
  String get createdAsVersion1;
  String staysVersionP0(Object p0);
  String versionP0P12(Object p0, Object p1);
  String get substantiveChangesRightsObligationsTermsAll;
  String get substantiveContentChangesAllUsersNotified;
  String saveP0(Object p0);
  String get summaryChanges;
  String get updateType;
  String get fixingTyposFormattingUsersNotNotified;
  String get contentUnchangedTitleOnlyChangeCannot;
  String get notificationsSentImmediatelyAfterSubmittingCannot;
  String get publishNotify;
  String sectionP0(Object p0);
  String get goSection;
  String get sectionContent;
  String get previous;
  String get next2;
  String get unableGenerateProfileQrCodeTry;
  String get myQrCode;
  String get markAsRead;
  String get unblock;
  String afterUnblockingP0CanSendMessages(Object p0);
  String get userUnblocked;
  String get unableLoadBlockedUsers;
  String get notBlockedAnyUsers;
  String get blockedUsers;
  String get blockUser;
  String afterBlockP0NeitherCanSend(Object p0);
  String get block;
  String get userBlocked;
  String get moreOptions;
  String get blockedUser;
  String get originalMessageNotFound;
  String get you2;
  String get viewProfile;
  String get reply;
  String get bookLockerScanQrCodeLocker;
  String get originalMessageUnavailable;
  String get cancelReply;
  String get unreadMessages;
  String get selectChat;
  String get appPermissions;
  String get noPermissionsRequiredDevice;
  String get allowAll;
  String get camera;
  String get photosRead;
  String get photosSave;
  String get microphone;
  String get location;
  String get orderUpdatesChatMessagesAnnouncements;
  String get scanBarcodesTakeBookPhotos;
  String get chooseBookPhotosProfilePicturesChat;
  String get saveQrCodesPhotos;
  String get recordVoiceMessagesChats;
  String get showNearestSmartLockersTheirDistance;
  String get quickSignPaymentConfirmation;
  String get allowed;
  String get limited;
  String get notAllowed;
  String get restricted;
  String get denied;
  String get allow;
  String get homeRecommendations;
  String get leaveGroup;
  String leaveP0(Object p0);
  String get leave;
  String get leftGroup;
  String get unpin;
  String get pin;
  String get you3;
  String get canOnlyEditMessagesSentWithin;
  String p0UnsentMessage(Object p0);
  String readByP0(Object p0);
  String get transferDetailsUnavailable;
  String get couldNotCreateGroup;
  String get groupDetails;
  String get selectMembers;
  String get groupName;
  String membersP0(Object p0);
  String get createGroup;
  String get inviteMembers;
  String get invite;
  String canSelectUpP0People(Object p0);
  String get noChatsChooseFrom;
  String get noMatchingPeople;
  String get searchByName;
  String get chatPinned;
  String get unpinned;
  String get setNickname;
  String get onlyVisible;
  String get nicknameRemoved;
  String get nicknameUpdated;
  String get enterGroupName;
  String get groupNameUpdated;
  String get groupPhotoUpdated;
  String get groupReachedMemberLimit;
  String invitedP0Members(Object p0);
  String get removeMember;
  String removeP0FromGroup(Object p0);
  String get memberRemoved;
  String get chatSettings;
  String get muteNotifications;
  String get pinChat;
  String get me;
  String requestedFromP0(Object p0);
  String p0RequestedPaymentFrom(Object p0);
  String p0RequestedPaymentFromP1(Object p0, Object p1);
  String sentP0(Object p0);
  String p0SentCoins(Object p0);
  String p0SentCoinsP1(Object p0, Object p1);
  String get expired2;
  String get payNow;
  String get cancelRequest;
  String get request;
  String get transfer;
  String dueP0(Object p0);
  String transferP0(Object p0);
  String sentP0CoinsP1(Object p0, Object p1);
  String get confirmPayment;
  String payP0CoinsP1(Object p0, Object p1);
  String get declineRequest;
  String declineP1CoinRequestFromP0(Object p0, Object p1);
  String cancelRequestP0P1Coins(Object p0, Object p1);
  String payRequestFromP0(Object p0);
  String get paymentCompleted;
  String get requestDeclined;
  String get requestCanceled;
  String get selectPayer;
  String get selectRecipient;
  String get sendRequest2;
  String get confirmTransfer;
  String get payer;
  String get recipient;
  String limitPerTransferP0Coins(Object p0);
  String insufficientBalanceP0Coins(Object p0);
  String balanceP0Coins(Object p0);
  String get noteOptional;
  String get editMessage;
  String get cancelEditing;
  String get send;
  String get switchKeyboard;
  String get voiceMessage;
  String get edited;
  String get maximumRecordingLengthReached;
  String get recordingTooShort;
  String p0SRemaining(Object p0);
  String get releaseSend;
  String get recording;
  String get tapHoldRecord;
  String get stopRecording;
  String get preview2;
  String get startRecording;
  String get microphoneUnavailable;
  String get paymentRequest;
  String get transfer2;
  String get transfer3;
  String get transferOut;
  String get deleteBook;
  String p0PermanentlyDeletedCannotRestoredSeller(Object p0);
  String get reasonDeletionOptional;
  String get bookDeleted2;
  String get rotate;
  String get mentioned;
  String get saveImage;
  String get everyone;
  String get mentionMembers;
  String get removeAdminRole;
  String makeP0Admin(Object p0);
  String removeAdminRoleFromP0(Object p0);
  String get remove2;
  String p0NowAdmin(Object p0);
  String removedAdminRoleFromP0(Object p0);
  String photosP02(Object p0);
  String get savedDownloads;
  String get couldNotSaveImage;
  String savingImagesP0P1(Object p0, Object p1);
  String get savingImage;
  String get passwordsCanOnlyContainEnglishLetters;
  String get aiSupport;
  String get howDoIListBook;
  String get howDoIPickUpFrom;
  String get howDoIRequestRefund;
  String get howDoWalletCoinsWork;
  String get talkPerson;
  String get supportRequestCreatedFromConversationOur;
  String get transfer4;
  String get creatingSupportRequest;
  String get transferredSupportTeam;
  String get newConversation;
  String get currentConversationEnd;
  String get copied2;
  String get howCanWeHelp;
  String get failedSend;
  String get ourSupportTeamCanHelpWith;
  String get contactSupport;
  String get typeQuestion;
  String get aiFeatures;
  String get aiSettingsNotSavedChangesLost;
  String get usage;
  String reviewP0(Object p0);
  String get dailyCost;
  String get noCostPeriod;
  String get peakDay;
  String p0Requests(Object p0);
  String get listingAssist;
  String get recommendations;
  String get listingReview;
  String get connectionTest;
  String get today2;
  String get k7Days;
  String get k30Days;
  String get notBookUnrelatedItem;
  String get prohibitedPiratedContent;
  String get adultContent;
  String get offPlatformDealContactInfo;
  String get misleadingDescription;
  String get unusualPrice;
  String get providerError;
  String get timedOut;
  String get noApiKey;
  String get rateLimited;
  String get invalidApiKey;
  String get invalidResponseFormat;
  String get rejectListing;
  String get noteOptionalSentSeller;
  String get reject;
  String get listingApproved;
  String get listingRejected;
  String get noListingsAwaitingReview;
  String get likelyViolation;
  String get needsReview;
  String get rejected;
  String get approve;
  String get pleaseFixHighlightedFields;
  String get aiSettingsSaved;
  String get invalidFormat;
  String enter0P0(Object p0);
  String get databaseNotBeenUpdatedAiYet;
  String get defaultModel;
  String get features;
  String get on;
  String get noProviderApiKeysSetSo;
  String p0NoApiKeyCannotSelected(Object p0);
  String get input;
  String get output;
  String get per1mTokens;
  String get vision;
  String get webSearch;
  String get testing;
  String get test;
  String connectedP0Ms(Object p0);
  String get connectionFailed;
  String get keySet;
  String get noKey;
  String get model;
  String defaultP0(Object p0);
  String p0NoApiKey(Object p0);
  String p0DoesNotSupportWebSearch(Object p0);
  String get searchNotBilledSeparately;
  String firstP0SearchesFreeEachMonth(Object p0, Object p1);
  String p0Per1000SearchesPlus(Object p0);
  String get suspiciousListings;
  String get holdReview;
  String get rejectClearViolations;
  String get budgetLimits;
  String get monthlyBudgetUsd;
  String get k0MeansNoCap;
  String get dailyLimitPerMember;
  String get k0MeansUnlimited;
  String get advanced;
  String get resetDefault;
  String get modelId;
  String get priceUsPer1mTokens;
  String get cachedInput;
  String get searchPriceUsPer1000;
  String get freeSearchesPerMonth;
  String p0FieldsInvalid(Object p0);
  String p0UnsavedChanges(Object p0);
  String get unsavedChanges;
  String get month2;
  String budgetP0(Object p0);
  String get noMonthlyBudget;
  String projectedP0(Object p0);
  String get periodCost;
  String get requests;
  String p0Searches(Object p0);
  String p0OutP1(Object p0, Object p1);
  String get errors;
  String errorRateP0(Object p0);
  String p0ListingsAwaitingReview(Object p0);
  String get byFeature;
  String get noDataYet;
  String errorsP0(Object p0);
  String p0Calls(Object p0);
  String get byModel;
  String p0CallsP1Ms(Object p0, Object p1);
  String get topMembers;
  String p0Uses(Object p0);
  String get recentErrors;
  String get noErrors;
  String get fillWithAi;
  String get summary;
  String get lookingUpBookDetails;
  String get searchingWeb;
  String get analyzingPhotos;
  String get suggestingCategoryConditionPrice;
  String get couldNotGetAiSuggestions;
  String get done;
  String get aiAnalyzing;
  String get aiSuggestions;
  String get noSuggestionsApply;
  String get bookDetails;
  String get suggestedPrice;
  String rangeP0P1(Object p0, Object p1);
  String listPriceP0(Object p0);
  String applyP0(Object p0);
  String currentP0(Object p0);
  String get sameAsCurrent;
  String get listingNotApproved;
  String get editListing;
  String get submittedReview;
  String get goSaleOnceApprovedNotifiedResult;
  String get got;
  String get aiFeaturesNotAvailableRightNow;
  String get bookUnderReviewGoSaleOnce;
  String get notApproved;
  String get bookDidNotPassListingReview;
  String get enterIsbnTitleFirst;
  String appliedP0AiSuggestions(Object p0);
  String get addBookPhotosFirst;
  String get nothingFoundFillCheckIsbnTitle;
  String appliedP0AiSuggestions2(Object p0);
  String get aiDataProcessingEnabled;
  String get aiDataProcessingTurnedOff;
  String get aiDataProcessing;
  String get messagesEnterStatusOrdersReservations;
  String get isbnTitleConditionNotesPhotosSelect;
  String get bookDetailsFromFavoritesPurchaseHistory;
  String get aiDataProcessing2;
  String get whenUseAiFeaturesWeShare;
  String get dataShared;
  String get recipients;
  String get purpose;
  String get usedOnlyGenerateSupportRepliesPrepare;
  String get withdrawingConsent;
  String get canTurnOffAiDataProcessing;
  String get agreeContinue;
  String get insufficientQuotaPlanNotEnabled;
  String get modelNotFound;
  String get invalidRequestParameters;
  String get couldNotConnectService;
  String get blockedByProviderSafetySystem;
  String get responseExceededOutputLimit;
  String get serverProcessingError;
  String get aiBookAdvisor;
  String get requiresDatabaseUpdate013;
  String get mysteryNovelMyCommute;
  String get programmingBooksBeginners;
  String get booksUnder200Coins;
  String get popularLiteraryFictionRightNow;
  String get tellMeWhatBookLooking;
  String get describeBookLooking;
  String get tellMeWhatWantReadI;
  String get subtitle;
  String get monthOnly;
  String get yearOnly;
  String get msg;
  String get additionalInformation;
  String get readFull;
  String get pages;
  String get simplifiedChinese;
  String get chinese;
  String get english;
  String get japanese;
  String get korean;
  String p0Pages(Object p0);
  String get collapse;
  String get setPasswordFirst;
  String get setPassword;
  String get signMethodSettingsSaved;
  String get signMethodSettingsUnsavedLeavingDiscards;
  String get serverNotRunDatabaseUpdate014;
  String get signChannels;
  String get socialSmsSign;
  String get whenOffSignPageHidesThese;
  String get notConfigured;
  String get allowCreatingNewAccountsWithMethod;
  String get unsavedChanges2;
  String get taiwan;
  String get hongKong;
  String get macau;
  String get china;
  String get japan;
  String get southKorea;
  String get singapore;
  String get malaysia;
  String get unitedStatesCanada;
  String get unitedKingdom;
  String get australia;
  String get countryCode;
  String get enterValidMobileNumber;
  String get couldNotSendCodePleaseTry;
  String get linkMobileNumber;
  String get signWithMobileNumber;
  String get k6DigitCodeSentNumberMessage;
  String get mobileNumber;
  String get sendCode;
  String get codeIncorrectPleaseEnterAgain;
  String get codeBeenSentAgain;
  String get enterCode;
  String get enterSmsCode;
  String codeWasSentP0(Object p0);
  String canResendP0S(Object p0);
  String get resendCode;
  String get completeAccountDetails;
  String get p0DidNotProvideEmailAddress;
  String signWithP0(Object p0);
  String get signWith2;
  String get creatingAccountWithMethodsAboveMeans;
  String get emailAlreadyRegistered;
  String get signWithPasswordThenLinkMethod;
  String get signWithPassword;
  String get accountNoPasswordYet;
  String get passwordSet;
  String get canNowSignWithEmailPassword;
  String get passwordRequiredBeforeCanUnlinkSign;
  String get changingSignMethodsRequiresIdentityVerification;
  String get later;
  String p0Linked(Object p0);
  String unlinkP0(Object p0);
  String get noLongerAbleSignWayCan;
  String get unlink;
  String p0Unlinked(Object p0);
  String get socialSmsSignNotAvailableRight;
  String get noSignMethodAvailableLink;
  String get noPasswordSet;
  String linkedP0(Object p0);
  String get link;
  String get emailAlreadyRegisteredSignWithPassword;
  String get provideEmailAddressCreateAccount;
  String get signMethodOnlyExistingAccounts;
  String get signMethodNotAvailableRightNow;
  String get credentialDoesNotMatchSelectedSign;
  String get signMethodLinkedAnotherAccount;
  String get accountAlreadyLinkedSignMethod;
  String get onlySignMethodAccountSetPassword;
  String get socialSignUnavailableServerNotFinished;
  String get credentialInvalidExpiredPleaseTryAgain;
  String get accountAlreadyPasswordUseChangePassword;
  String get signLinkExpiredPleaseTryAgain;
  String get signResultExpiredPleaseTryAgain;
  String get thirdPartySignServiceUnavailablePlease;
  String get couldNotCompleteSignPleaseTry;
  String get accountNotLinkedSignMethod;
  String get mobileNumberFormatNotValid;
  String get verificationTimedOutRequestNewCode;
  String get codeExpiredRequestNewOne;
  String get tooManyAttemptsPleaseTryAgain;
  String get smsSendingLimitBeenReachedPlease;
  String get smsVerificationNotSetUpDevice;
  String get couldNotCompleteSmsVerificationPlease;
  String get allowSigningLinkingWithMethod;
  String get appNeverStoresPasswordUsedOnly;
  String get verifyWithBiometricsInstead;
  String get accountWasCreatedWithSocialPhone;
  String get setSignPassword;
  String get enterSignPasswordRunAdminAction;
  String p1P0MethodsEnabled(Object p0, Object p1);
  String get masterSwitchOffSoEveryMethod;
  String get signLinkingDirectSignUpAllowed;
  String credentialsNotSetPleaseConfigureP0(Object p0);
  String get whenOffMethodHiddenFromSign;
  String get whenOffOnlyAccountsAlreadyLinked;
  String get signMethodNotLinkedAccount;
  String p0AccountNotLinkedAnySavemybook(Object p0);
  String get iAlreadyAccountSignFirst;
  String get createNewAccountWithIdentity;
  String signExistingAccountFirstThenLink(Object p0);
  String get signMethodNotLinkedAnyAccount;
  String get verifyIdentityWithPasskeyContinue;
  String get verifyWithPasskeyInstead;
  String get passkeys;
  String get verifyWithFaceIdFingerprintScreen;
  String get verifyWithPasskey;
  String get useSignPasswordInstead;
  String get signWithPasskey;
  String get passkeyAdded;
  String get screenLock;
  String fromNowCanSignVerifyIdentity(Object p0);
  String get deletePasskey;
  String get noLongerAbleSignVerifyIdentity;
  String get passkeyDeleted;
  String get signVerifyIdentityWithFaceId;
  String get addPasskey;
  String get notUsedYet;
  String lastUsedFormatdateItemLastusedat(Object p0);
  String createdCreated(Object p0);
  String get noPasskeyAvailableDeviceUsePassword;
  String get passkeyAlreadyRegisteredDevice;
  String get signGoogleAccountTurnPasswordManager;
  String get setUpScreenLockPasswordManager;
  String get deviceDoesNotSupportPasskeysUse;
  String get passkeysTemporarilyUnavailableBecauseAppWebsite;
  String get requestTimedOutPleaseTryAgain;
  String get passkeyRequestFailedUsePasswordInstead;
  String get verifyIdentityBeforeAddingPasskey;
  String get couldNotListPleaseTryAgain;
  String downloadLinkValidOnceP0P1(Object p0, Object p1);
  String get sources;
  String get unableOpenLink;
  String get helpCentre2;
  String get preferences;
  String get privacy;
  String get about2;
  String clearP0Notifications(Object p0);
  String p1NotificationsP0DeletedCannotUndone(Object p0, Object p1);
  String p0NotificationsCleared(Object p0);
  String markAllP1UnreadNotificationsP0(Object p0, Object p1);
  String get offers;
  String get noTransactionNotifications;
  String get noChatNotifications;
  String get noAccountNotifications;
  String get noSupportNotifications;
  String get noOfferNotifications;
  String get images;
  String get imagesStillUploadingPleaseWaitBefore;
  String get someImagesFailedUploadRetryRemove;
  String get attachImages;
  String get imageCouldNotRead;
  String get up4ImagesPerMessage;
  String retryUploadingImageP0(Object p0);
  String removeImageP0(Object p0);
  String get addImages;
  String viewImageP0(Object p0);
  String get eGGoldMember;
  String get pointsThreshold;
  String get pts;
  String get tierBenefits;
  String get oneBenefitPerLine;
  String get newTier2;
  String get whatMembersSee;
  String get noThresholdSet;
  String get tierOrder;
  String get noBenefitsSet;
  String p0CurrentlyP1MembersAfterDeletion(Object p0, Object p1, Object p2);
  String noMembersCurrentlyP0OtherTiers(Object p0);
  String tierDeletedP0MembersMovedP1(Object p0, Object p1);
  String get changeTierOrder;
  String get thresholdsStayWithTheirPositionThese;
  String p0P1P2Pts(Object p0, Object p1, Object p2);
  String get tierOrderUpdated;
  String p0Members(Object p0);
  String get tiers;
  String get members4;
  String get memberDistribution;
  String get moreActions;
  String get dragReorder;
  String p0Pts(Object p0);
  String p0P1Pts(Object p0, Object p1);
  String tierNamedP0AlreadyExists(Object p0);
  String get enterPointsThreshold;
  String get thresholdMustWholeNumber0More;
  String thresholdCannotExceedP0(Object p0);
  String p0AlreadyUsesP1PtsEach(Object p0, Object p1);
  String get startingTierMustBegin0Pts;
  String get startingTierCannotDeletedSetAnother;
  String get signLink;
  String get signAccount;
  String emailAlreadyRegisteredSignLinkName(Object p0);
  String signLinkNameCanThenSign(Object p0, Object p1);
  String get noPasskeyDevice;
  String get signWithPasskeyAnotherDeviceSecurity;
  String get useAnotherDevice;
  String get usePassword;
  String get icloudKeychain;
  String get googlePasswordManager;
  String get synced;
  String get notSynced;
  String get alreadyPasskey;
  String get enterName;
  String get passkeySavedIcloudKeychainWorksEvery;
  String get passkeySavedGooglePasswordManagerWorks;
  String get passkeySavedDeviceSPasswordManager;
  String get addAgain;
  String get codeExpiredPleaseRequestNewOne;
  String codeValidP0(Object p0);
  String get basicSettings;
  String get eGBirthdayVoucher;
  String get benefitDetails;
  String get addBenefit;
  String get bookNoLongerExistsBeenRemoved;
  String get myNicknameGroup;
  String get setGroupNickname;
  String get allGroupMembersSeeNickname;
  String get markLockerMaintenance;
  String get endLockerMaintenance;
  String maintenanceHidesP0FromSellers(Object p0);
  String endingMaintenanceP0AvailableAgain(Object p0);
  String get lockerMarkedMaintenance;
  String get lockerMaintenanceEnded;
  String get semanticIndex;
  String get semanticSearch;
  String p0BooksP1HelpArticlesIndexed(Object p0, Object p1);
  String get noOpenaiGeminiKeyConfiguredOnly;
  String get databaseNotBeenUpdated020Only;
  String get hybridSearchKeywordSemantic;
  String get keywordSearchOnly;
  String get paymentReleasedWalletWhenBuyerCompletes;
  String get completeOrderAfterCheckingBookCompletes;
  String get completeOrder;
  String get onceCompleteOrderPaymentReleasedSeller;
  String get orderCompleted2;
  String get noReservedBooks;
  String heldUntilP02(Object p0);
  String heldUntilP03(Object p0);
  String get awaitingBuyerConfirmation;
  String get awaitingCompletion;
  String get libraryCopyUnofficialSource;
  String p0CannotEdit(Object p0);
  String get buyNow2;
  String get suggestRefund;
  String get suggestDismissal;
  String get needsMoreInformation;
  String get aiAnalysis;
  String get analyze;
  String get analyzeAgain;
  String get aiAnalysisReferenceOnlyDecideBased;
  String p0P1Confidence(Object p0, Object p1);
  String get aiSummary;
  String get autoFilled;
  String get similarBooks;
  String get doNotPayTransferMoneyOutside;
  String get pleaseCompleteDealAppWeCannot;
  String get personSharedOutsideContactDetailsWatch;
  String get mostRelevant;
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
  String get orderRefunding => 'Under review';

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
  String get orderFlowPickup => 'Picked up by buyer';

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
  String get language => 'Language';

  @override
  String get languageSystem => 'Follow system';

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
  String get accountPermanentlyDisabled30DaysSign => 'Your account will be deleted in 30 days. Sign in again before then to cancel. Your personal data will be erased; completed orders and transaction records will be kept.';

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
  String get cancelAccountDeletion => 'Cancel account deletion';

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
  String get signStartChat => 'Sign in to contact the seller';

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
  String get reportSubmittedWeLookInto => 'Report submitted';

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
  String get messageSeller => 'Message seller';

  @override
  String get listing => 'This is your listing';

  @override
  String get addCart => 'Add to cart';

  @override
  String get bookBeenReportedUnderReviewStays => 'This book has been reported and is under review.';

  @override
  String get violationWasConfirmedBookPleaseCheck => 'A violation was confirmed for this book. Please edit the listing.';

  @override
  String get delist => 'Delist';

  @override
  String removedFromShopBuyersNoLonger(Object p0) => '“${p0}” will be removed from the shop and buyers will no longer see it.';

  @override
  String get delist2 => 'Delist';

  @override
  String get couldNotDelistPleaseTryAgain => 'Could not delist. Please try again.';

  @override
  String listedAgain(Object p0) => '“${p0}” is listed again';

  @override
  String get notListedAnyBooksYet => 'You have not listed any books yet';

  @override
  String get noBooksCategory => 'No books in this category';

  @override
  String get relist => 'Relist';

  @override
  String get remove => 'Remove';

  @override
  String get couldNotRemoveRestored => 'Could not remove. Restored.';

  @override
  String get selectBooksWantCheckOut => 'Select the books you want to check out';

  @override
  String notEnoughCoinsOrderNeedsBut(Object p0, Object p1) => 'Not enough coins. This order needs ${p0} but you have ${p1}.';

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
  String markAllUnreadMessagesAsRead(Object p0) => 'Mark all ${p0} unread messages as read?';

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
  String get messageCouldNotSent => 'Message could not be sent';

  @override
  String get chat => 'Chat';

  @override
  String get sendFirstMessage => 'Send the first message';

  @override
  String get messageCopied => 'Message copied';

  @override
  String get iQuestionAboutBook => 'Book enquiry';

  @override
  String get bookNoLongerListed => 'This book is no longer listed';

  @override
  String get writeMessage => 'Write a message…';

  @override
  String get enterOrderNumberDisputing => 'Enter the order number you are disputing';

  @override
  String get describeDispute => 'Describe the dispute';

  @override
  String get useLeast10CharactersSoSupport => 'The description must be at least 10 characters';

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
  String get submitDispute2 => 'Submit a dispute';

  @override
  String get orderNumber => 'Order number';

  @override
  String get eGSmb20260910123456789 => 'e.g. SMB20260910123456789';

  @override
  String get whatHappened => 'What happened';

  @override
  String get describeProblemEGConditionDoes => 'Describe the problem';

  @override
  String get submit => 'Submit';

  @override
  String get uploadPhotos => 'Upload photos';

  @override
  String get canAttachUp6Photos => 'You can attach up to 6 photos';

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
  String get photoMissingDataRefreshTryAgain => 'Unable to process this photo. Refresh and try again.';

  @override
  String get enterPrice => 'Enter a price';

  @override
  String get priceMustGreaterThan0 => 'Price must be greater than 0';

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
  String get tapPickPublicationDate => 'Select publication date';

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
  String get tellPeopleAboutYourself => 'Enter a bio';

  @override
  String get email => 'Email';

  @override
  String get emailCannotChanged => 'Email cannot be changed';

  @override
  String get dateBirth => 'Date of birth';

  @override
  String get tapPickDateBirth => 'Select date of birth';

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
  String hi(Object p0) => 'Hello, ${p0}';

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
  String get documentNotBeenCreatedYet => 'No content available';

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
  String get emailAddressNotValid => 'Invalid email address';

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
  String get membershipTiersNotSetUpYet => 'Membership tiers are not available';

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
  String get noBenefitsBeenDescribedTierYet => 'This tier has no additional benefits';

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
  String markAllUnreadNotificationsAsRead(Object p0) => 'Mark all ${p0} unread notifications as read?';

  @override
  String get openChat => 'Open chat';

  @override
  String get viewOrder => 'View order';

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
  String get orderNoItemDetails => 'No item details';

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
  String get notAssignedYet => 'No slot assigned yet';

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
  String get coinsArriveOnceBuyerCollectsBook => 'Paid automatically after the buyer collects the book';

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
  String collected(Object p0) => '“${p0}” collected';

  @override
  String order2(Object p0) => 'Order ${p0}';

  @override
  String get signingOut => 'Signing out…';

  @override
  String get myAccount => 'My account';

  @override
  String get personNotWrittenBioYet => 'No bio yet';

  @override
  String get topTierReached => 'Top tier reached';

  @override
  String morePointsReach(Object p0, Object p1) => '${p0} more points to reach “${p1}”';

  @override
  String get purchases => 'Purchases';

  @override
  String get sales => 'Sales';

  @override
  String get settings => 'Settings';

  @override
  String get signOut2 => 'Sign out?';

  @override
  String cancelOrderBookReturnsShop(Object p0) => 'Cancel order ${p0}? The book returns to the shop.';

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
  String get joinSavemybook => 'Create account';

  @override
  String get displayName => 'Display name';

  @override
  String get emailSignWith => 'Email';

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
  String get priceCannotExceed99999 => 'The price cannot exceed 99,999 coins.';

  @override
  String get chooseLockerLocation2 => 'Choose a locker location.';

  @override
  String get listed2 => 'Listed successfully';

  @override
  String get unknownError => 'Unknown error';

  @override
  String get couldNotListBook => 'Could not list the book';

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
  String get noSourceIsbnPleaseEnterDetails => 'No source has this ISBN. Please enter the details manually.';

  @override
  String get day => 'Day';

  @override
  String get tapIconRightScan => 'Enter ISBN';

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
  String sign3(Object p0) => '${p0} sign-in';

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
  String addMeSavemybook(Object p0) => 'My SaveMyBook profile: ${p0}';

  @override
  String addMeSavemybook2(Object p0, Object p1) => '${p0}\'s SaveMyBook profile: ${p1}';

  @override
  String get sharingCouldNotOpenSoLink => 'Sharing is unavailable. The link has been copied.';

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
  String get addMoreDetailSoSupportCan => 'Add more detail to the description';

  @override
  String get sentSupportReplySoon => 'Sent. Support will reply soon.';

  @override
  String get subject => 'Subject';

  @override
  String get sumUpOneLine => 'Brief summary of the issue';

  @override
  String get whatHappenedIncludeOrderNumberIf => 'Describe the issue and include the order number, if any.';

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
  String slot2(Object p0) => 'Slot: ${p0}';

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
  String get writeAnnouncement => 'Enter announcement content';

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
  String get noAnnouncementsYetTapAddOne => 'No announcements yet';

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
  String get noBackupsYetSchedulerRunsOnce => 'No backups yet';

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
  String sectionP0NoTitleYet(Object p0) => 'Section ${p0} has no title yet';

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
  String get noArticlesYetAddFirstOne => 'No articles yet';

  @override
  String get addSection => 'Add section';

  @override
  String get untitledSection => 'Untitled section';

  @override
  String get sectionTitle => 'Section title';

  @override
  String get bodySectionSingleLineBreaksKept => 'The body of this section. Single line breaks are kept as-is; an empty line starts a new paragraph.';

  @override
  String get howUsersSee => 'How users see it';

  @override
  String get noContentYet => 'No content yet';

  @override
  String get unsaved => 'Unsaved';

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
  String orderP0P1(Object p0, Object p1) => 'Order ${p0} | \$${p1}';

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
  String get listings => 'Listings';

  @override
  String get moderation => 'Moderation';

  @override
  String get handleListingReports => 'Handle listing reports';

  @override
  String get members => 'Members';

  @override
  String get memberControls => 'Member controls';

  @override
  String get membershipTiers => 'Membership tiers';

  @override
  String get wallets => 'Wallets';

  @override
  String get hardwareOperations => 'Hardware and operations';

  @override
  String get maintenanceLog => 'Maintenance log';

  @override
  String get reports => 'Reports';

  @override
  String get ordersRevenueMemberGrowth => 'Orders, revenue and member growth';

  @override
  String get supportEnquiries => 'Support enquiries';

  @override
  String get adminAuditLog => 'Admin audit log';

  @override
  String get systemOperations => 'System operations';

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
  String get memberSTierBeenAdjustedBy => 'This member\'s tier has been adjusted manually and is not based solely on trades.';

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
  String get remindThemChangeSettingsChangePassword => 'Remind them to change it in Settings › Change password right after signing in.';

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
  String get changeOwnPasswordGoSettingsChange => 'To change your own password, go to Settings › Change password';

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

  @override
  String get buyerSPaymentGoesBackTheir => 'The buyer\'s payment goes back to their wallet. If the seller was already paid, that amount is taken back first.';

  @override
  String get orderReturnsWhereWasBeforeDispute => 'The order returns to where it was before the dispute. If it was already picked up, the seller is paid.';

  @override
  String get orderWasAlreadyRefundedBuyerCannot => 'This order was already refunded to the buyer and cannot go back to in progress or completed';

  @override
  String get completedOrderCanOnlyChangedRefund => 'A completed order can only be changed to "Refund in progress" or "Refunded"';

  @override
  String confirmingPaysP0TokensSellerMarks(Object p0) => 'Confirming pays ${p0} tokens to the seller and marks the books as sold.';

  @override
  String confirmingTakesP0TokensBackFrom(Object p0) => 'Confirming takes ${p0} tokens back from the seller and refunds the buyer. The seller\'s balance may go negative.';

  @override
  String get ifBuyerNotBeenRefundedYet => 'If the buyer has not been refunded yet, the refund is issued now.';

  @override
  String confirmingRefundsBuyerSP0Tokens(Object p0) => 'Confirming refunds the buyer\'s ${p0} tokens and puts reserved books back on sale.';

  @override
  String get donTPermissionYourselfSoCan => 'You don\'t have this permission yourself, so you can\'t grant it to others.';

  @override
  String get notificationsTurnedOff => 'Notifications are turned off';

  @override
  String get openSettings => 'Open Settings';

  @override
  String get sendTestNotification => 'Send a test notification';

  @override
  String get arrives10SecondsGoHomeScreen => 'Arrives in 10 seconds. Go to the Home Screen or lock your phone after sending.';

  @override
  String get systemNotificationSettings => 'System notification settings';

  @override
  String get pushNotificationsNotSetUpBuild => 'Push notifications are not set up in this build. Add the Firebase config files and rebuild.';

  @override
  String get notificationsTurnedOffAllowAppSend => 'Notifications are turned off. Allow this app to send notifications in system settings.';

  @override
  String get restoreBackup => 'Restore this backup?';

  @override
  String wholeDatabaseGoBackP0Orders(Object p0) => 'The whole database will go back to ${p0}. Orders, messages, member data and activity logs after that point will be lost.\n\nThe current state is backed up automatically first, so you can restore that backup if this was a mistake. The service pauses during the restore, usually for a few seconds to a few minutes.\n\nEnter your password to confirm:';

  @override
  String get password2 => 'Password';

  @override
  String get startRestore => 'Start restore';

  @override
  String get backingUpCurrentState => 'Backing up the current state…';

  @override
  String databaseRestoredPreviousStateWasBacked(Object p0) => 'Database restored. The previous state was backed up as ${p0}';

  @override
  String restoreFailedDatabaseMayUnchangedPartly(Object p0) => 'Restore failed. The database may be unchanged or partly restored. Check the activity log and consider restoring ${p0}';

  @override
  String get autoBackupBeforeRestore => 'Auto backup before restore';

  @override
  String get restoreBackup2 => 'Restore this backup';

  @override
  String get restoringDatabase => 'Restoring the database';

  @override
  String p0SecondsSoFarKeepApp(Object p0) => '${p0} seconds so far. Keep the app open; the service resumes automatically when it finishes.';

  @override
  String get majorUpdate2 => 'Major update';

  @override
  String get minorEdit => 'Minor edit';

  @override
  String get books => 'Books';

  @override
  String get orders2 => 'Orders';

  @override
  String get wallets2 => 'Wallets';

  @override
  String get announcements3 => 'Announcements';

  @override
  String get legal => 'Legal';

  @override
  String get backups => 'Backups';

  @override
  String get undoAction => 'Undo this action?';

  @override
  String p0NNtheDataGoesBack(Object p0) => '"${p0}"\n\nThe data goes back to how it was before this action. Notifications already sent are not recalled. If the data was changed again afterwards, the undo is refused.';

  @override
  String get undo => 'Undo';

  @override
  String get undone => 'Undone';

  @override
  String get searchActionsEGNicknameBook => 'Search actions, e.g. a nickname or book title';

  @override
  String viewP0Changes(Object p0) => 'View ${p0} changes';

  @override
  String get undoAction2 => 'Undo this action';

  @override
  String get noAnnouncements => 'No announcements';

  @override
  String get canTContinueWithoutAccepting => 'You can\'t continue without accepting';

  @override
  String needAcceptLatestP0UseP1(Object p0) => 'If you do not accept "${p0}", you will be signed out.';

  @override
  String get goBack => 'Go back';

  @override
  String p0BeenUpdated(Object p0) => '"${p0}" has been updated';

  @override
  String readLatestVersionUpdatedP0Accept(Object p0) => 'Updated ${p0}';

  @override
  String get scrollEndContinue => 'Scroll to the end to continue';

  @override
  String get iVeReadAccept => 'I\'ve read and accept';

  @override
  String get decline => 'Decline';

  @override
  String get viewDetails => 'View details';

  @override
  String get notFoundMayBeenDeletedRemoved => 'This content is no longer available';

  @override
  String get chatMessages => 'Chat messages';

  @override
  String get promotions2 => 'Promotions';

  @override
  String get supportRepliesPasswordResetsPolicyUpdates => 'Support replies, account security and system announcements cannot be turned off.';

  @override
  String get notFilled => 'Not filled in';

  @override
  String get canTChanged => 'Can\'t be changed';

  @override
  String get voice => '[Voice]';

  @override
  String get reservation => 'Reservation';

  @override
  String get messageUnsent => 'Message unsent';

  @override
  String get confirmBeforeExportingData => 'Confirm it is you before exporting your data';

  @override
  String get exportFailedPleaseTryAgainLater => 'Export failed. Please try again later';

  @override
  String get refresh => 'Refresh';

  @override
  String get clearFilters => 'Clear filters';

  @override
  String get expired => 'Expired';

  @override
  String get verificationCancelled => 'Verification cancelled';

  @override
  String get openingClosingTimesCanTSame => 'Opening and closing times can’t be the same';

  @override
  String slotCurrentlyP0MayOrderProgress(Object p0, Object p1) => 'This slot is currently "${p0}" and may have an order in progress. Changing it to "${p1}" may stop the buyer or seller from dropping off or collecting the book.';

  @override
  String get active => 'Active';

  @override
  String get categoryWithNameAlreadyExists => 'A category with this name already exists';

  @override
  String orderP0ClosedAsP1P2(Object p0, Object p1, Object p2) => 'Order ${p0} will be closed as "${p1}" and ${p2} coins will be returned to the buyer. This can’t be changed after submitting.';

  @override
  String orderP0ClosedAsP1Can(Object p0, Object p1) => 'Order ${p0} will be closed as "${p1}". This can’t be changed after submitting.';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get enterMinimumPoints => 'Enter the minimum points';

  @override
  String pointsRangeOverlapsWithP0P1(Object p0, Object p1) => 'Points range overlaps with "${p0}" (${p1})';

  @override
  String noTierCoversP0P1Points(Object p0, Object p1) => 'No tier covers ${p0}–${p1} points';

  @override
  String p0TakenDownRightAwayOther(Object p0) => '"${p0}" will be taken down right away and other members will no longer be able to see or buy it.';

  @override
  String get searchReportedItemReporterReason => 'Search reported item, reporter or reason';

  @override
  String get couldnTLoadStatisticsRightNow => 'Couldn’t load statistics right now';

  @override
  String get searchSubjectMemberMessage => 'Search subject, member or message';

  @override
  String get balance3 => 'Has balance';

  @override
  String get hold3 => 'On hold';

  @override
  String get zeroBalance => 'Zero balance';

  @override
  String get amountCanMost2DecimalPlaces => 'Amount can have at most 2 decimal places';

  @override
  String get singleAdjustmentCanTExceed1 => 'A single adjustment can’t exceed 1,000,000';

  @override
  String wouldMakeBalanceNegativeCurrentBalance(Object p0) => 'This would make the balance negative. Current balance: ${p0}';

  @override
  String get amountUp2Decimals => 'Amount (up to 2 decimals)';

  @override
  String p0NbalanceAfterP1(Object p0, Object p1) => '${p0}\nBalance after: ${p1}';

  @override
  String get cameraAccessOff => 'Camera access is off';

  @override
  String get couldNotStartCamera => 'Could not start the camera';

  @override
  String allowP0UseCameraSettingsThen(Object p0) => 'Allow ${p0} to use the camera in Settings, then try again.';

  @override
  String get closeScreenTryAgain => 'Close this screen and try again.';

  @override
  String get couldnTGetLocationCheckLocation => 'Couldn\'t get your location. Check that location services and permission are on.';

  @override
  String get bookReservedAnotherBuyerCanT => 'This book is reserved for another buyer and can\'t be added to your cart right now';

  @override
  String reservedAnotherBuyerUntilP0(Object p0) => 'Reserved for another buyer until ${p0}';

  @override
  String sellerHoldingUntilP0(Object p0) => 'The seller is holding it for you until ${p0}';

  @override
  String get checkOutBeforeHoldEndsOther => 'Check out before the hold expires';

  @override
  String get copyAddress => 'Copy address';

  @override
  String p0Away(Object p0) => '${p0} away';

  @override
  String get locating => 'Locating…';

  @override
  String get showDistance => 'Show distance';

  @override
  String get reserved => 'Reserved';

  @override
  String get goCheckout => 'Go to checkout';

  @override
  String get cart2 => 'In cart';

  @override
  String get buyNow => 'Buy now';

  @override
  String p0Delisted(Object p0) => '"${p0}" delisted';

  @override
  String noBooksMatchP0(Object p0) => 'No books match "${p0}"';

  @override
  String p0BooksP1Views(Object p0, Object p1) => '${p0} books · ${p1} views';

  @override
  String get searchTitleAuthorIsbn2 => 'Search title, author or ISBN';

  @override
  String removedP0(Object p0) => 'Removed "${p0}"';

  @override
  String removedP0Items(Object p0) => 'Removed ${p0} items';

  @override
  String get paymentSuccessful => 'Payment successful';

  @override
  String p0BooksSplitIntoP1Orders(Object p0, Object p1) => '${p0} books, split into ${p1} orders by seller';

  @override
  String get keepBrowsing => 'Keep browsing';

  @override
  String get reload => 'Reload';

  @override
  String get browseBooks => 'Browse books';

  @override
  String p0Sellers(Object p0) => '${p0} sellers';

  @override
  String unavailableP0(Object p0) => 'Unavailable (${p0})';

  @override
  String get removeAll => 'Remove all';

  @override
  String get goWallet => 'Go to wallet';

  @override
  String fromP0SellersCheckoutCreatesP1(Object p0, Object p1) => 'From ${p0} sellers; checkout creates ${p1} separate orders';

  @override
  String get otherDevicesNeedSignAgainWith => 'Your other devices will need to sign in again with the new password.';

  @override
  String get searchChats => 'Search chats';

  @override
  String get noMatchingChats => 'No matching chats';

  @override
  String get read => 'Read';

  @override
  String get chatNotFound => 'Chat not found';

  @override
  String get messagesCanUp2000Characters => 'Messages can be up to 2000 characters';

  @override
  String get canTSendRightNowPlease => 'Can\'t send right now. Please try again later';

  @override
  String get reserveBook => 'Reserve this book';

  @override
  String get quickReplies => 'Quick replies';

  @override
  String get imagesMust10MbSmaller => 'Images must be 10 MB or smaller';

  @override
  String get recordingFailedPleaseTryAgain => 'Recording failed. Please try again';

  @override
  String get voiceMessageTooLargePleaseRecord => 'Voice message is too large. Please record a shorter one';

  @override
  String get microphoneAllowedPressHoldAgainRecord => 'Microphone allowed. Press and hold again to record';

  @override
  String get microphoneAccessNeededRecordTurnSettings => 'Microphone access is needed to record. Turn it on in Settings';

  @override
  String get couldnTStartRecordingPleaseTry => 'Couldn\'t start recording. Please try again later';

  @override
  String get selectText => 'Select text';

  @override
  String get unsend => 'Unsend';

  @override
  String get resend => 'Resend';

  @override
  String get unsendMessage => 'Unsend this message?';

  @override
  String get neitherAbleSeeMessageSContent => 'Neither of you will be able to see this message\'s content.';

  @override
  String get reportMessage => 'Report this message';

  @override
  String get reservationSentWaitingSeller => 'Reservation sent. Waiting for the seller';

  @override
  String get acceptReservation => 'Accept reservation?';

  @override
  String p0HeldThemP1HoursNo(Object p0, Object p1) => '"${p0}" will be held for them for ${p1} hours. No one else can buy it during that time.';

  @override
  String get accept => 'Accept';

  @override
  String get reservationAccepted => 'Reservation accepted';

  @override
  String get declineReservation => 'Decline reservation?';

  @override
  String get decline2 => 'Decline';

  @override
  String get reservationDeclined => 'Reservation declined';

  @override
  String get cancelReservation => 'Cancel reservation?';

  @override
  String p0NoLongerHeld(Object p0) => '"${p0}" will no longer be held.';

  @override
  String get cancelReservation2 => 'Cancel reservation';

  @override
  String get reservationCanceled => 'Reservation canceled';

  @override
  String get notNow2 => 'Not now';

  @override
  String get couldnTLoadConversationPleaseTry => 'Couldn\'t load the conversation. Please try again later';

  @override
  String get accountCanTReceiveMessagesRight => 'This account can\'t receive messages right now';

  @override
  String get holdMicTalkReleaseSend => 'Recording too short';

  @override
  String get startConversation => 'This is the start of your conversation';

  @override
  String p0New(Object p0) => '${p0} new';

  @override
  String get connectionUnstableMessagesCanTSent => 'Connection is unstable. Messages can\'t be sent for now';

  @override
  String get retry => 'Retry';

  @override
  String get stillAvailable => 'Is this still available?';

  @override
  String get couldLowerPriceBit => 'Is the price negotiable?';

  @override
  String get whenCanPutLocker => 'When will the book be placed in the locker?';

  @override
  String get unsentMessage => 'You unsent a message';

  @override
  String get theyUnsentMessage => 'The other user unsent a message';

  @override
  String get reservationDetailsArenTAvailableRight => 'Reservation details aren\'t available right now';

  @override
  String get sending => 'Sending';

  @override
  String get couldNotUploadPhotosPleaseTry => 'Could not upload the photos. Please try again later';

  @override
  String get bookDetailsUpdatedButPhotosCouldn => 'Book details updated, but photos couldn\'t be uploaded. Please try again later.';

  @override
  String get sNotIsbnBarcodeScanOne => 'That\'s not an ISBN barcode. Scan the one starting with 978 or 979 on the back cover.';

  @override
  String get couldnTLoadCategoriesTapRetry => 'Couldn\'t load categories. Tap to retry';

  @override
  String removedP0FromSaved(Object p0) => 'Removed "${p0}" from saved';

  @override
  String get recentlyViewedCleared => 'Recently viewed cleared';

  @override
  String clearP0(Object p0) => 'Clear (${p0})';

  @override
  String get picked => 'Picked for you';

  @override
  String get recentlyViewed => 'Recently viewed';

  @override
  String get clear => 'Clear';

  @override
  String get notificationDeleted => 'Notification deleted';

  @override
  String get pleasePutBookAssignedLockerSoon => 'Please put the book in the assigned locker soon';

  @override
  String get weLlLetKnowWhenSeller => 'You will be notified when the seller drops off the book';

  @override
  String get waitingBuyerCollect => 'Waiting for the buyer to collect';

  @override
  String get transactionCompleteThank => 'Transaction complete';

  @override
  String get confirmVeTakenBookFromLocker => 'Confirm that you have taken the book from the locker. After checking its condition, complete the order in Purchases.';

  @override
  String p0Orders2(Object p0) => '${p0} orders';

  @override
  String p0ReadyPickup(Object p0) => '${p0} ready for pickup';

  @override
  String get pickUp => 'To pick up';

  @override
  String get saved => 'Saved';

  @override
  String get accountSecurity => 'Account security';

  @override
  String get searchHistoryCleared => 'Search history cleared';

  @override
  String get trendingBooks => 'Trending books';

  @override
  String get signOutDevice => 'Sign out this device?';

  @override
  String signOutP0(Object p0) => 'Sign out "${p0}"?';

  @override
  String get deviceSignedOutRightAwayStop => 'That device will be signed out immediately.';

  @override
  String get deviceSignedOut => 'Device signed out';

  @override
  String get signOutAllDevicesIncludingOne => 'Sign out all devices (including this one)';

  @override
  String get signOutAllOtherDevices => 'Sign out all other devices';

  @override
  String get everyDeviceIncludingOneSignedOut => 'All devices, including this one, will be signed out immediately.';

  @override
  String get everyDeviceExceptOneSignedOut => 'All devices except this one will be signed out immediately.';

  @override
  String signedOutP0OtherDevices(Object p0) => 'Signed out of ${p0} other devices';

  @override
  String get unknownDevice => 'Unknown device';

  @override
  String get couldnTLoadDevices => 'Couldn\'t load your devices';

  @override
  String get device => 'This device';

  @override
  String get otherDevices => 'Other devices';

  @override
  String otherDevicesP0(Object p0) => 'Other devices (${p0})';

  @override
  String get noOtherDevicesSigned => 'No other devices are signed in';

  @override
  String get signedDevices => 'Signed-in devices';

  @override
  String get activeNow => 'Active now';

  @override
  String lastActiveP0(Object p0) => 'Last active ${p0}';

  @override
  String signedP0(Object p0) => 'Signed in ${p0}';

  @override
  String get biometricPayment => 'Biometric payment on';

  @override
  String get paymentPinMust6Digits => 'Payment PIN must be 6 digits';

  @override
  String get pinTooEasyGuessTryAnother => 'This PIN is too easy to guess. Please choose another.';

  @override
  String get enterPasswordResetPaymentPin => 'Enter your password to reset your payment PIN';

  @override
  String get confirmSBeforeSettingPaymentPin => 'Confirm it\'s you before setting a payment PIN';

  @override
  String get pinsDonTMatchStartAgain => 'The PINs don\'t match. Start again';

  @override
  String get paymentPinReset => 'Payment PIN reset';

  @override
  String get paymentPinSet => 'Payment PIN set';

  @override
  String get verifyingIdentity => 'Verifying your identity…';

  @override
  String get enterAgainConfirm => 'Enter it again to confirm';

  @override
  String get set6DigitPaymentPin => 'Set a 6-digit payment PIN';

  @override
  String get enterSamePinAgain => 'Enter the same PIN again';

  @override
  String get avoidRepeatedSequentialPatternedDigits => 'Avoid repeated, sequential or patterned digits';

  @override
  String get resetPaymentPin => 'Reset payment PIN';

  @override
  String get paymentPin => 'Payment PIN';

  @override
  String stepP02(Object p0) => 'Step ${p0} of 2';

  @override
  String get setPaymentPinFirst => 'Set a payment PIN first';

  @override
  String get setPaymentPinFirstSoFallback => 'Set a payment PIN first so you have a fallback';

  @override
  String get setUpNow => 'Set up now';

  @override
  String get biometricPaymentTurnedOff => 'Biometric payment turned off';

  @override
  String get verifyTurnBiometricPayment => 'Verify to turn on biometric payment';

  @override
  String p0PaymentsTurned(Object p0) => '${p0} payments turned on';

  @override
  String get securitySettingsUnavailableRightNowMay => 'Unable to load security settings';

  @override
  String payWithP0(Object p0) => 'Pay with ${p0}';

  @override
  String get accountWellProtected => 'Your account is well protected';

  @override
  String get accountCouldSafer => 'Account security can be improved';

  @override
  String get setPaymentPinTurnBiometricPayment => 'Payment PIN not set';

  @override
  String tooManyAttemptsLockedUntilP0(Object p0) => 'Too many attempts. Locked until ${p0}';

  @override
  String get notSetRequiredBeforeCheckout => 'Not set';

  @override
  String get change => 'Change';

  @override
  String get forgotPaymentPin => 'Forgot payment PIN';

  @override
  String p0Devices(Object p0) => '${p0} devices';

  @override
  String get restoredUnfinishedListing => 'Restored your unfinished listing';

  @override
  String get isbnSCheckDigitInvalidPlease => 'This ISBN\'s check digit is invalid. Please check it again.';

  @override
  String get draftSavedAutomatically => 'Draft saved automatically';

  @override
  String get continueUnfinishedListing => 'Continue your unfinished listing';

  @override
  String clearedP0MbCache(Object p0) => 'Cleared ${p0} MB of cache';

  @override
  String get cacheCleared => 'Cache cleared';

  @override
  String get storage => 'Storage';

  @override
  String get clearCache => 'Clear cache';

  @override
  String get couldNotLoadNotificationSettings => 'Could not load notification settings';

  @override
  String get month => 'This month';

  @override
  String p0P1(Object p0, Object p1) => '${p0}/${p1}';

  @override
  String get noIncomeYet => 'No income yet';

  @override
  String get noSpendingYet => 'No spending yet';

  @override
  String get income => 'Income';

  @override
  String get spending => 'Spending';

  @override
  String get totalIncome => 'Total income';

  @override
  String get totalSpending => 'Total spending';

  @override
  String get item3 => 'Item';

  @override
  String get details => 'Details';

  @override
  String get balanceAfter => 'Balance after';

  @override
  String get transactionId => 'Transaction ID';

  @override
  String get sessionExpiredPleaseSignAgain => 'Your session expired. Please sign in again';

  @override
  String get serviceTemporarilyUnavailableTryAgainLater => 'Service temporarily unavailable. Try again later';

  @override
  String get uploadFailedTryAgainLater => 'Upload failed. Try again later';

  @override
  String get nearby => 'Nearby';

  @override
  String p0M(Object p0) => '${p0} m';

  @override
  String p0Km(Object p0) => '${p0} km';

  @override
  String get iphoneDidnTReceiveApnsToken => 'This iPhone didn\'t receive an APNs token. Make sure Push Notifications is added under Signing & Capabilities in Xcode, then reinstall the app with the same Apple developer account.';

  @override
  String get firebaseDidnTIssuePushToken => 'Firebase didn\'t issue a push token. Check that GoogleService-Info.plist matches the app\'s bundle ID';

  @override
  String couldnTGetPushTokenP0(Object p0) => 'Couldn\'t get a push token: ${p0}';

  @override
  String couldnTRegisterPushTokenWith(Object p0) => 'Couldn\'t register the push token with the server: ${p0}';

  @override
  String get protectCoinsCheckoutRequires6Digit => 'Set a 6-digit payment PIN before checking out.';

  @override
  String confirmPaymentP0Coins(Object p0) => 'Confirm payment of ${p0} coins';

  @override
  String get enterPasswordContinue => 'Enter your password to continue';

  @override
  String get verifyS => 'Verify it\'s you';

  @override
  String get amount => 'Amount';

  @override
  String p0Coins(Object p0) => '${p0} coins';

  @override
  String get enterPaymentPin => 'Enter payment PIN';

  @override
  String get enterPaymentPinContinue => 'Enter your payment PIN to continue';

  @override
  String get paymentPinResetEnterAgain => 'Payment PIN reset. Enter it again';

  @override
  String get usePasswordInstead => 'Use password instead';

  @override
  String get couldnTGetLocationLockersShown => 'Unable to get your location';

  @override
  String p0SlotsFree(Object p0) => '${p0} slots free';

  @override
  String openP0(Object p0) => 'Open ${p0}';

  @override
  String get nearest => 'Nearest';

  @override
  String get noFreeSlots => 'No free slots';

  @override
  String get turnLocationSortByDistance => 'Turn on location to sort by distance';

  @override
  String get lockerNoFreeSlotsRightNow => 'This locker has no free slots right now';

  @override
  String get turn => 'Turn on';

  @override
  String get noLockersAvailable => 'No lockers available';

  @override
  String get noMatchingOptions => 'No matching options';

  @override
  String get undo2 => 'Undo';

  @override
  String copiedP0(Object p0) => 'Copied "${p0}"';

  @override
  String get typing => 'Typing…';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String p0P12(Object p0, Object p1) => '${p0}/${p1}';

  @override
  String p1P2P0(Object p0, Object p1, Object p2) => '${p0}/${p1}/${p2}';

  @override
  String get releaseCancel => 'Release to cancel';

  @override
  String get awaitingReply => 'Awaiting reply';

  @override
  String heldUntilP0(Object p0) => 'Held until ${p0}';

  @override
  String get declined2 => 'Declined';

  @override
  String get closed => 'Closed';

  @override
  String get theyWantReserveBook => 'Reservation request for your book';

  @override
  String get sentReservationRequest => 'You sent a reservation request';

  @override
  String holdP0H(Object p0) => 'Hold for ${p0} h';

  @override
  String get holdPeriod => 'Hold period';

  @override
  String get messageSellerOptional => 'Message to the seller (optional)';

  @override
  String get sendRequest => 'Send request';

  @override
  String p0Hours(Object p0) => '${p0} hours';

  @override
  String p0P1DigitsEntered(Object p0, Object p1) => '${p0} of ${p1} digits entered';

  @override
  String get buildSProvisioningProfileDoesnT => 'This build\'s provisioning profile doesn\'t include push notifications. In Xcode, check Runner › Signing & Capabilities has Push Notifications, then delete and reinstall the app.';

  @override
  String get checkPhoneOnlinePushNotificationsAdded => 'Check that the phone is online and that Push Notifications is added under Runner › Signing & Capabilities in Xcode.';

  @override
  String iphoneFailedRegisterPushNotificationsWith(Object p0, Object p1) => 'iPhone failed to register for push notifications with Apple: ${p0}\n${p1}';

  @override
  String get serverNotBeenUpdatedSupportFeature => 'This feature is temporarily unavailable. Please try again later.';

  @override
  String get someFeaturesTemporarilyUnavailableWhileServer => 'Some features are temporarily unavailable';

  @override
  String serverRunningOutdatedApiRevisionP0(Object p0, Object p1) => 'The server is running an outdated API (revision ${p0}; the app requires ${p1}). Update the code on the server and restart the API.';

  @override
  String databaseMigrationsNotYetRunP0(Object p0) => 'Database migrations not yet run: ${p0}';

  @override
  String serverVersionP0(Object p0) => 'Server version: ${p0}';

  @override
  String get runNpmRunVerifyApiDirectory => 'Run npm run verify in the API directory on the server to check the full deployment status.';

  @override
  String get serverUpdateRequired => 'Server update required';

  @override
  String versionP0(Object p0) => 'Version ${p0}';

  @override
  String get requiresUserConsent => 'Requires user consent';

  @override
  String get unsavedDraft => 'Unsaved draft';

  @override
  String get allBooks => 'All books';

  @override
  String get results => 'Results';

  @override
  String get sortBy => 'Sort by';

  @override
  String get themeColour => 'Theme colour';

  @override
  String get forestGreen => 'Forest green';

  @override
  String get oceanBlue => 'Ocean blue';

  @override
  String get lavender => 'Lavender';

  @override
  String get terracotta => 'Terracotta';

  @override
  String get amber => 'Amber';

  @override
  String get rose => 'Rose';

  @override
  String get graphite => 'Graphite';

  @override
  String get mistBlue => 'Mist blue';

  @override
  String get draftRestored => 'Draft restored';

  @override
  String get convertSections => 'Convert to sections';

  @override
  String get currentContentDoesNotFullyMatch => 'The current content does not fully match the section format. After conversion, section numbers will be regenerated in order using the "1. Title" format, and paragraphs not recognized as headings will be merged into the preamble or the preceding section.\n\nTo keep the original format, continue editing and saving in plain text.';

  @override
  String get convert => 'Convert';

  @override
  String get keepPlainText => 'Keep plain text';

  @override
  String get noSectionHeadingsDetectedFullText => 'No section headings detected. The full text has been placed in the preamble.';

  @override
  String deletedP0(Object p0) => 'Deleted "${p0}"';

  @override
  String get renameSection => 'Rename section';

  @override
  String get editContent => 'Edit content';

  @override
  String get rename => 'Rename';

  @override
  String get addSectionBelow => 'Add section below';

  @override
  String get moveUp => 'Move up';

  @override
  String get moveDown => 'Move down';

  @override
  String get enterDocumentTitle => 'Enter the document title';

  @override
  String get enterDocumentContent => 'Enter the document content';

  @override
  String p0NowVersionP1(Object p0, Object p1) => '${p0} (now version ${p1})';

  @override
  String versionP0P1(Object p0, Object p1) => 'Version ${p0} · ${p1}';

  @override
  String unsavedDraftFromP0Found(Object p0) => 'Unsaved draft from ${p0} found';

  @override
  String get documentWasUpdatedAfterDraftWas => 'This document was updated after the draft was created. Restoring will replace the current content with the draft.';

  @override
  String get discardDraft => 'Discard draft';

  @override
  String get restoreDraft => 'Restore draft';

  @override
  String get sectionTitleRequired => 'Section title required';

  @override
  String get documentSFormatDoesNotFully => 'This document’s format does not fully match the section structure, so it has been opened in plain text to preserve the original formatting.';

  @override
  String get enterPasteFullTextHere => 'Enter or paste the full text here.';

  @override
  String get noSectionHeadingsDetected => 'No section headings detected';

  @override
  String p0SectionsDetected(Object p0) => '${p0} sections detected';

  @override
  String get paragraphWhoseFirstLine1Title => 'A paragraph whose first line is "1. Title", "一、Title" or "第一條 Title" is treated as a section heading.';

  @override
  String get sectionNumbersMustStart1Increase => 'Section numbers must start at 1 and increase in order; otherwise the paragraph is treated as part of the previous section.';

  @override
  String get blankLineStartsNewParagraphSingle => 'A blank line starts a new paragraph. Single line breaks are kept as is.';

  @override
  String get whenSwitchingSectionsAskedConfirmAny => 'When switching to Sections, you will be asked to confirm any format changes first.';

  @override
  String get howSectionHeadingsDetected => 'How section headings are detected';

  @override
  String get titleEdited => 'Title edited';

  @override
  String p0Added(Object p0) => '${p0} added';

  @override
  String p0Removed(Object p0) => '${p0} removed';

  @override
  String p0Edited(Object p0) => '${p0} edited';

  @override
  String get sectionsReordered => 'Sections reordered';

  @override
  String get preambleEdited => 'Preamble edited';

  @override
  String get contentEdited => 'Content edited';

  @override
  String p0Characters2(Object p0) => '+${p0} characters';

  @override
  String p0Characters3(Object p0) => '${p0} characters';

  @override
  String get formattingAdjusted => 'Formatting adjusted';

  @override
  String get createdAsVersion1 => 'Created as version 1';

  @override
  String staysVersionP0(Object p0) => 'Stays at version ${p0}';

  @override
  String versionP0P12(Object p0, Object p1) => 'Version ${p0} → ${p1}';

  @override
  String get substantiveChangesRightsObligationsTermsAll => 'For substantive changes to rights, obligations or terms. All users will be notified and must review and accept the document the next time they open the app.';

  @override
  String get substantiveContentChangesAllUsersNotified => 'For substantive content changes. All users will be notified.';

  @override
  String saveP0(Object p0) => 'Save "${p0}"';

  @override
  String get summaryChanges => 'Summary of changes';

  @override
  String get updateType => 'Update type';

  @override
  String get fixingTyposFormattingUsersNotNotified => 'For fixing typos or formatting. Users are not notified.';

  @override
  String get contentUnchangedTitleOnlyChangeCannot => 'The content is unchanged. A title-only change cannot be a major update.';

  @override
  String get notificationsSentImmediatelyAfterSubmittingCannot => 'Notifications will be sent immediately after submitting. This cannot be undone.';

  @override
  String get publishNotify => 'Publish and notify';

  @override
  String sectionP0(Object p0) => 'Section ${p0}';

  @override
  String get goSection => 'Go to section';

  @override
  String get sectionContent => 'Section content';

  @override
  String get previous => 'Previous';

  @override
  String get next2 => 'Next';

  @override
  String get unableGenerateProfileQrCodeTry => 'Unable to generate your profile QR code. Try again later.';

  @override
  String get myQrCode => 'My QR code';

  @override
  String get markAsRead => 'Mark as read';

  @override
  String get unblock => 'Unblock';

  @override
  String afterUnblockingP0CanSendMessages(Object p0) => 'After unblocking, you and "${p0}" can send messages to each other again.';

  @override
  String get userUnblocked => 'User unblocked';

  @override
  String get unableLoadBlockedUsers => 'Unable to load blocked users';

  @override
  String get notBlockedAnyUsers => 'You have not blocked any users';

  @override
  String get blockedUsers => 'Blocked users';

  @override
  String get blockUser => 'Block user';

  @override
  String afterBlockP0NeitherCanSend(Object p0) => 'After you block "${p0}", neither of you can send messages to the other.';

  @override
  String get block => 'Block';

  @override
  String get userBlocked => 'User blocked';

  @override
  String get moreOptions => 'More options';

  @override
  String get blockedUser => 'You have blocked this user';

  @override
  String get originalMessageNotFound => 'Original message not found';

  @override
  String get you2 => 'You';

  @override
  String get viewProfile => 'View profile';

  @override
  String get reply => 'Reply';

  @override
  String get bookLockerScanQrCodeLocker => 'The book is in the locker. Scan the QR code on the locker to collect it.';

  @override
  String get originalMessageUnavailable => 'Original message unavailable';

  @override
  String get cancelReply => 'Cancel reply';

  @override
  String get unreadMessages => 'Unread messages';

  @override
  String get selectChat => 'Select a chat';

  @override
  String get appPermissions => 'App permissions';

  @override
  String get noPermissionsRequiredDevice => 'No permissions are required on this device';

  @override
  String get allowAll => 'Allow all';

  @override
  String get camera => 'Camera';

  @override
  String get photosRead => 'Photos (read)';

  @override
  String get photosSave => 'Photos (save)';

  @override
  String get microphone => 'Microphone';

  @override
  String get location => 'Location';

  @override
  String get orderUpdatesChatMessagesAnnouncements => 'Order updates, chat messages and announcements';

  @override
  String get scanBarcodesTakeBookPhotos => 'Scan barcodes and take book photos';

  @override
  String get chooseBookPhotosProfilePicturesChat => 'Choose book photos, profile pictures and chat images';

  @override
  String get saveQrCodesPhotos => 'Save QR codes to Photos';

  @override
  String get recordVoiceMessagesChats => 'Record voice messages in chats';

  @override
  String get showNearestSmartLockersTheirDistance => 'Show the nearest smart lockers and their distance';

  @override
  String get quickSignPaymentConfirmation => 'Quick sign-in and payment confirmation';

  @override
  String get allowed => 'Allowed';

  @override
  String get limited => 'Limited';

  @override
  String get notAllowed => 'Not allowed';

  @override
  String get restricted => 'Restricted by the system';

  @override
  String get denied => 'Denied';

  @override
  String get allow => 'Allow';

  @override
  String get homeRecommendations => 'Home recommendations';

  @override
  String get leaveGroup => 'Leave group';

  @override
  String leaveP0(Object p0) => 'Leave "${p0}"?';

  @override
  String get leave => 'Leave';

  @override
  String get leftGroup => 'Left the group';

  @override
  String get unpin => 'Unpin';

  @override
  String get pin => 'Pin';

  @override
  String get you3 => 'You';

  @override
  String get canOnlyEditMessagesSentWithin => 'You can only edit messages sent within the last 15 minutes';

  @override
  String p0UnsentMessage(Object p0) => '${p0} unsent a message';

  @override
  String readByP0(Object p0) => 'Read by ${p0}';

  @override
  String get transferDetailsUnavailable => 'Transfer details are unavailable';

  @override
  String get couldNotCreateGroup => 'Could not create the group';

  @override
  String get groupDetails => 'Group details';

  @override
  String get selectMembers => 'Select members';

  @override
  String get groupName => 'Group name';

  @override
  String membersP0(Object p0) => 'Members ${p0}';

  @override
  String get createGroup => 'Create group';

  @override
  String get inviteMembers => 'Invite members';

  @override
  String get invite => 'Invite';

  @override
  String canSelectUpP0People(Object p0) => 'You can select up to ${p0} people';

  @override
  String get noChatsChooseFrom => 'No chats to choose from';

  @override
  String get noMatchingPeople => 'No matching people';

  @override
  String get searchByName => 'Search by name';

  @override
  String get chatPinned => 'Chat pinned';

  @override
  String get unpinned => 'Unpinned';

  @override
  String get setNickname => 'Set nickname';

  @override
  String get onlyVisible => 'Only visible to you';

  @override
  String get nicknameRemoved => 'Nickname removed';

  @override
  String get nicknameUpdated => 'Nickname updated';

  @override
  String get enterGroupName => 'Enter a group name';

  @override
  String get groupNameUpdated => 'Group name updated';

  @override
  String get groupPhotoUpdated => 'Group photo updated';

  @override
  String get groupReachedMemberLimit => 'This group has reached the member limit';

  @override
  String invitedP0Members(Object p0) => 'Invited ${p0} members';

  @override
  String get removeMember => 'Remove member';

  @override
  String removeP0FromGroup(Object p0) => 'Remove "${p0}" from the group?';

  @override
  String get memberRemoved => 'Member removed';

  @override
  String get chatSettings => 'Chat settings';

  @override
  String get muteNotifications => 'Mute notifications';

  @override
  String get pinChat => 'Pin chat';

  @override
  String get me => 'Me';

  @override
  String requestedFromP0(Object p0) => 'Requested from ${p0}';

  @override
  String p0RequestedPaymentFrom(Object p0) => '${p0} requested payment from you';

  @override
  String p0RequestedPaymentFromP1(Object p0, Object p1) => '${p0} requested payment from ${p1}';

  @override
  String sentP0(Object p0) => 'Sent to ${p0}';

  @override
  String p0SentCoins(Object p0) => '${p0} sent you coins';

  @override
  String p0SentCoinsP1(Object p0, Object p1) => '${p0} sent coins to ${p1}';

  @override
  String get expired2 => 'Expired';

  @override
  String get payNow => 'Pay now';

  @override
  String get cancelRequest => 'Cancel request';

  @override
  String get request => 'Request';

  @override
  String get transfer => 'Transfer';

  @override
  String dueP0(Object p0) => 'Due ${p0}';

  @override
  String transferP0(Object p0) => 'Transfer to ${p0}';

  @override
  String sentP0CoinsP1(Object p0, Object p1) => 'Sent ${p0} coins to ${p1}';

  @override
  String get confirmPayment => 'Confirm payment';

  @override
  String payP0CoinsP1(Object p0, Object p1) => 'Pay ${p0} coins to ${p1}';

  @override
  String get declineRequest => 'Decline request';

  @override
  String declineP1CoinRequestFromP0(Object p0, Object p1) => 'Decline the ${p0}-coin request from ${p1}';

  @override
  String cancelRequestP0P1Coins(Object p0, Object p1) => 'Cancel the request to ${p0} for ${p1} coins';

  @override
  String payRequestFromP0(Object p0) => 'Pay the request from ${p0}';

  @override
  String get paymentCompleted => 'Payment completed';

  @override
  String get requestDeclined => 'Request declined';

  @override
  String get requestCanceled => 'Request canceled';

  @override
  String get selectPayer => 'Select a payer';

  @override
  String get selectRecipient => 'Select a recipient';

  @override
  String get sendRequest2 => 'Send request';

  @override
  String get confirmTransfer => 'Confirm transfer';

  @override
  String get payer => 'Payer';

  @override
  String get recipient => 'Recipient';

  @override
  String limitPerTransferP0Coins(Object p0) => 'Limit per transfer: ${p0} coins';

  @override
  String insufficientBalanceP0Coins(Object p0) => 'Insufficient balance (${p0} coins)';

  @override
  String balanceP0Coins(Object p0) => 'Balance ${p0} coins';

  @override
  String get noteOptional => 'Note (optional)';

  @override
  String get editMessage => 'Edit message';

  @override
  String get cancelEditing => 'Cancel editing';

  @override
  String get send => 'Send';

  @override
  String get switchKeyboard => 'Switch to keyboard';

  @override
  String get voiceMessage => 'Voice message';

  @override
  String get edited => 'Edited';

  @override
  String get maximumRecordingLengthReached => 'Maximum recording length reached';

  @override
  String get recordingTooShort => 'Recording is too short';

  @override
  String p0SRemaining(Object p0) => '${p0} s remaining';

  @override
  String get releaseSend => 'Release to send';

  @override
  String get recording => 'Recording';

  @override
  String get tapHoldRecord => 'Tap or hold to record';

  @override
  String get stopRecording => 'Stop recording';

  @override
  String get preview2 => 'Preview';

  @override
  String get startRecording => 'Start recording';

  @override
  String get microphoneUnavailable => 'Microphone unavailable';

  @override
  String get paymentRequest => '[Payment request]';

  @override
  String get transfer2 => '[Transfer]';

  @override
  String get transfer3 => 'Transfer in';

  @override
  String get transferOut => 'Transfer out';

  @override
  String get deleteBook => 'Delete book';

  @override
  String p0PermanentlyDeletedCannotRestoredSeller(Object p0) => '"${p0}" will be permanently deleted and cannot be restored. The seller will be notified.';

  @override
  String get reasonDeletionOptional => 'Reason for deletion (optional)';

  @override
  String get bookDeleted2 => 'Book deleted';

  @override
  String get rotate => 'Rotate';

  @override
  String get mentioned => '[Mentioned you]';

  @override
  String get saveImage => 'Save image';

  @override
  String get everyone => 'Everyone';

  @override
  String get mentionMembers => 'Mention members';

  @override
  String get removeAdminRole => 'Remove admin role';

  @override
  String makeP0Admin(Object p0) => 'Make ${p0} an admin?';

  @override
  String removeAdminRoleFromP0(Object p0) => 'Remove the admin role from ${p0}?';

  @override
  String get remove2 => 'Remove';

  @override
  String p0NowAdmin(Object p0) => '${p0} is now an admin';

  @override
  String removedAdminRoleFromP0(Object p0) => 'Removed the admin role from ${p0}';

  @override
  String photosP02(Object p0) => '[${p0} photos]';

  @override
  String get savedDownloads => 'Saved to Downloads';

  @override
  String get couldNotSaveImage => 'Could not save the image';

  @override
  String savingImagesP0P1(Object p0, Object p1) => 'Saving images ${p0} / ${p1}';

  @override
  String get savingImage => 'Saving image';

  @override
  String get passwordsCanOnlyContainEnglishLetters => 'Passwords can only contain English letters, numbers and standard symbols';

  @override
  String get aiSupport => 'AI support';

  @override
  String get howDoIListBook => 'How do I list a book?';

  @override
  String get howDoIPickUpFrom => 'How do I collect a book from a locker?';

  @override
  String get howDoIRequestRefund => 'How do I request a refund?';

  @override
  String get howDoWalletCoinsWork => 'How are coins used?';

  @override
  String get talkPerson => 'Contact a support agent';

  @override
  String get supportRequestCreatedFromConversationOur => 'You will be connected to a support agent, who will receive this conversation';

  @override
  String get transfer4 => 'Transfer';

  @override
  String get creatingSupportRequest => 'Connecting to support';

  @override
  String get transferredSupportTeam => 'Transferred to a support agent';

  @override
  String get newConversation => 'New conversation';

  @override
  String get currentConversationEnd => 'The current conversation will end';

  @override
  String get copied2 => 'Copied';

  @override
  String get howCanWeHelp => 'How can we help?';

  @override
  String get failedSend => 'Failed to send';

  @override
  String get ourSupportTeamCanHelpWith => 'Our support team can help with this';

  @override
  String get contactSupport => 'Contact support';

  @override
  String get typeQuestion => 'Type your question';

  @override
  String get aiFeatures => 'AI features';

  @override
  String get aiSettingsNotSavedChangesLost => 'AI settings are not saved. Changes will be lost if you leave.';

  @override
  String get usage => 'Usage';

  @override
  String reviewP0(Object p0) => 'Review ${p0}';

  @override
  String get dailyCost => 'Daily cost';

  @override
  String get noCostPeriod => 'No cost in this period';

  @override
  String get peakDay => 'Peak day';

  @override
  String p0Requests(Object p0) => '${p0} requests';

  @override
  String get listingAssist => 'Listing assist';

  @override
  String get recommendations => 'Recommendations';

  @override
  String get listingReview => 'Listing review';

  @override
  String get connectionTest => 'Connection test';

  @override
  String get today2 => 'Today';

  @override
  String get k7Days => '7 days';

  @override
  String get k30Days => '30 days';

  @override
  String get notBookUnrelatedItem => 'Not a book or unrelated item';

  @override
  String get prohibitedPiratedContent => 'Prohibited or pirated content';

  @override
  String get adultContent => 'Adult content';

  @override
  String get offPlatformDealContactInfo => 'Off-platform deal or contact info';

  @override
  String get misleadingDescription => 'Misleading description';

  @override
  String get unusualPrice => 'Unusual price';

  @override
  String get providerError => 'Provider error';

  @override
  String get timedOut => 'Timed out';

  @override
  String get noApiKey => 'No API key';

  @override
  String get rateLimited => 'Rate limited';

  @override
  String get invalidApiKey => 'Invalid API key';

  @override
  String get invalidResponseFormat => 'Invalid response format';

  @override
  String get rejectListing => 'Reject listing';

  @override
  String get noteOptionalSentSeller => 'Note (optional, sent to the seller)';

  @override
  String get reject => 'Reject';

  @override
  String get listingApproved => 'Listing approved';

  @override
  String get listingRejected => 'Listing rejected';

  @override
  String get noListingsAwaitingReview => 'No listings awaiting review';

  @override
  String get likelyViolation => 'Likely violation';

  @override
  String get needsReview => 'Needs review';

  @override
  String get rejected => 'Rejected';

  @override
  String get approve => 'Approve';

  @override
  String get pleaseFixHighlightedFields => 'Please fix the highlighted fields';

  @override
  String get aiSettingsSaved => 'AI settings saved';

  @override
  String get invalidFormat => 'Invalid format';

  @override
  String enter0P0(Object p0) => 'Enter 0 to ${p0}';

  @override
  String get databaseNotBeenUpdatedAiYet => 'The database has not been updated for AI yet. Saved settings will not take effect until it is.';

  @override
  String get defaultModel => 'Default model';

  @override
  String get features => 'Features';

  @override
  String get on => 'On';

  @override
  String get noProviderApiKeysSetSo => 'No provider API keys are set, so AI features cannot run';

  @override
  String p0NoApiKeyCannotSelected(Object p0) => '${p0} has no API key and cannot be selected';

  @override
  String get input => 'Input';

  @override
  String get output => 'Output';

  @override
  String get per1mTokens => 'per 1M tokens';

  @override
  String get vision => 'Vision';

  @override
  String get webSearch => 'Web search';

  @override
  String get testing => 'Testing';

  @override
  String get test => 'Test';

  @override
  String connectedP0Ms(Object p0) => 'Connected・${p0} ms';

  @override
  String get connectionFailed => 'Connection failed';

  @override
  String get keySet => 'Key set';

  @override
  String get noKey => 'No key';

  @override
  String get model => 'Model';

  @override
  String defaultP0(Object p0) => 'Default (${p0})';

  @override
  String p0NoApiKey(Object p0) => '${p0} has no API key';

  @override
  String p0DoesNotSupportWebSearch(Object p0) => '${p0} does not support web search';

  @override
  String get searchNotBilledSeparately => 'Search is not billed separately';

  @override
  String firstP0SearchesFreeEachMonth(Object p0, Object p1) => 'First ${p0} searches free each month, then ${p1} per 1,000';

  @override
  String p0Per1000SearchesPlus(Object p0) => '${p0} per 1,000 searches, plus tokens for search content';

  @override
  String get suspiciousListings => 'Suspicious listings';

  @override
  String get holdReview => 'Hold for review';

  @override
  String get rejectClearViolations => 'Reject clear violations';

  @override
  String get budgetLimits => 'Budget and limits';

  @override
  String get monthlyBudgetUsd => 'Monthly budget (USD)';

  @override
  String get k0MeansNoCap => '0 means no cap';

  @override
  String get dailyLimitPerMember => 'Daily limit per member';

  @override
  String get k0MeansUnlimited => '0 means unlimited';

  @override
  String get advanced => 'Advanced';

  @override
  String get resetDefault => 'Reset to default';

  @override
  String get modelId => 'Model ID';

  @override
  String get priceUsPer1mTokens => 'Price (US\$ per 1M tokens)';

  @override
  String get cachedInput => 'Cached input';

  @override
  String get searchPriceUsPer1000 => 'Search price (US\$ per 1,000)';

  @override
  String get freeSearchesPerMonth => 'Free searches per month';

  @override
  String p0FieldsInvalid(Object p0) => '${p0} fields are invalid';

  @override
  String p0UnsavedChanges(Object p0) => '${p0} unsaved changes';

  @override
  String get unsavedChanges => 'You have unsaved changes';

  @override
  String get month2 => 'This month';

  @override
  String budgetP0(Object p0) => 'Budget ${p0}';

  @override
  String get noMonthlyBudget => 'No monthly budget';

  @override
  String projectedP0(Object p0) => 'Projected ${p0}';

  @override
  String get periodCost => 'Period cost';

  @override
  String get requests => 'Requests';

  @override
  String p0Searches(Object p0) => '${p0} searches';

  @override
  String p0OutP1(Object p0, Object p1) => 'In ${p0}・Out ${p1}';

  @override
  String get errors => 'Errors';

  @override
  String errorRateP0(Object p0) => 'Error rate ${p0}%';

  @override
  String p0ListingsAwaitingReview(Object p0) => '${p0} listings awaiting review';

  @override
  String get byFeature => 'By feature';

  @override
  String get noDataYet => 'No data yet';

  @override
  String errorsP0(Object p0) => 'Errors ${p0}';

  @override
  String p0Calls(Object p0) => '${p0} calls';

  @override
  String get byModel => 'By model';

  @override
  String p0CallsP1Ms(Object p0, Object p1) => '${p0} calls・${p1} ms';

  @override
  String get topMembers => 'Top members';

  @override
  String p0Uses(Object p0) => '${p0} uses';

  @override
  String get recentErrors => 'Recent errors';

  @override
  String get noErrors => 'No errors';

  @override
  String get fillWithAi => 'Fill with AI';

  @override
  String get summary => 'Summary';

  @override
  String get lookingUpBookDetails => 'Looking up book details';

  @override
  String get searchingWeb => 'Searching the web';

  @override
  String get analyzingPhotos => 'Analyzing photos';

  @override
  String get suggestingCategoryConditionPrice => 'Suggesting category, condition and price';

  @override
  String get couldNotGetAiSuggestions => 'Could not get AI suggestions';

  @override
  String get done => 'Done';

  @override
  String get aiAnalyzing => 'AI is analyzing';

  @override
  String get aiSuggestions => 'AI suggestions';

  @override
  String get noSuggestionsApply => 'No suggestions to apply';

  @override
  String get bookDetails => 'Book details';

  @override
  String get suggestedPrice => 'Suggested price';

  @override
  String rangeP0P1(Object p0, Object p1) => 'Range \$${p0}–\$${p1}';

  @override
  String listPriceP0(Object p0) => 'List price \$${p0}';

  @override
  String applyP0(Object p0) => 'Apply ${p0}';

  @override
  String currentP0(Object p0) => 'Current: ${p0}';

  @override
  String get sameAsCurrent => 'Same as current';

  @override
  String get listingNotApproved => 'Listing not approved';

  @override
  String get editListing => 'Edit listing';

  @override
  String get submittedReview => 'Submitted for review';

  @override
  String get goSaleOnceApprovedNotifiedResult => 'It will go on sale once approved';

  @override
  String get got => 'OK';

  @override
  String get aiFeaturesNotAvailableRightNow => 'AI features are not available right now';

  @override
  String get bookUnderReviewGoSaleOnce => 'This book is under review and will go on sale once approved';

  @override
  String get notApproved => 'Not approved';

  @override
  String get bookDidNotPassListingReview => 'This book did not pass listing review';

  @override
  String get enterIsbnTitleFirst => 'Enter an ISBN or title first';

  @override
  String appliedP0AiSuggestions(Object p0) => 'Applied ${p0} AI suggestions';

  @override
  String get addBookPhotosFirst => 'Add book photos first';

  @override
  String get nothingFoundFillCheckIsbnTitle => 'Nothing found to fill in. Check the ISBN or title.';

  @override
  String appliedP0AiSuggestions2(Object p0) => 'Applied ${p0} AI suggestions';

  @override
  String get aiDataProcessingEnabled => 'AI data processing enabled';

  @override
  String get aiDataProcessingTurnedOff => 'AI data processing turned off';

  @override
  String get aiDataProcessing => 'AI data processing';

  @override
  String get messagesEnterStatusOrdersReservations => 'Messages you enter and the status of your orders and reservations';

  @override
  String get isbnTitleConditionNotesPhotosSelect => 'ISBN, title, condition notes and the photos you select';

  @override
  String get bookDetailsFromFavoritesPurchaseHistory => 'Book details from your favorites and purchase history';

  @override
  String get aiDataProcessing2 => 'AI data processing';

  @override
  String get whenUseAiFeaturesWeShare => 'When you use AI features, we share the following data with third-party AI providers for processing.';

  @override
  String get dataShared => 'Data shared';

  @override
  String get recipients => 'Recipients';

  @override
  String get purpose => 'Purpose';

  @override
  String get usedOnlyGenerateSupportRepliesPrepare => 'Used only to generate support replies, prepare listing details and recommend books. Never used for advertising or tracking.';

  @override
  String get withdrawingConsent => 'Withdrawing consent';

  @override
  String get canTurnOffAiDataProcessing => 'You can turn off "AI data processing" at any time in Settings › Account. The data above will no longer be shared once it is turned off.';

  @override
  String get agreeContinue => 'Agree';

  @override
  String get insufficientQuotaPlanNotEnabled => 'Insufficient quota or plan not enabled';

  @override
  String get modelNotFound => 'Model not found';

  @override
  String get invalidRequestParameters => 'Invalid request parameters';

  @override
  String get couldNotConnectService => 'Could not connect to the service';

  @override
  String get blockedByProviderSafetySystem => 'Blocked by the provider safety system';

  @override
  String get responseExceededOutputLimit => 'Response exceeded the output limit';

  @override
  String get serverProcessingError => 'Server processing error';

  @override
  String get aiBookAdvisor => 'AI book advisor';

  @override
  String get requiresDatabaseUpdate013 => 'Requires database update 013';

  @override
  String get mysteryNovelMyCommute => 'Mystery novels for commuting';

  @override
  String get programmingBooksBeginners => 'Programming books for beginners';

  @override
  String get booksUnder200Coins => 'Books under 200 coins';

  @override
  String get popularLiteraryFictionRightNow => 'Popular literary fiction right now';

  @override
  String get tellMeWhatBookLooking => 'Describe the book you are looking for';

  @override
  String get describeBookLooking => 'Describe the book you are looking for';

  @override
  String get tellMeWhatWantReadI => 'Book recommendations based on your needs';

  @override
  String get subtitle => 'Subtitle';

  @override
  String get monthOnly => 'Month only';

  @override
  String get yearOnly => 'Year only';

  @override
  String get msg => '繁體中文';

  @override
  String get additionalInformation => 'Additional information';

  @override
  String get readFull => 'Read in full';

  @override
  String get pages => 'Pages';

  @override
  String get simplifiedChinese => 'Simplified Chinese';

  @override
  String get chinese => 'Chinese';

  @override
  String get english => 'English';

  @override
  String get japanese => 'Japanese';

  @override
  String get korean => 'Korean';

  @override
  String p0Pages(Object p0) => '${p0} pages';

  @override
  String get collapse => 'Collapse';

  @override
  String get setPasswordFirst => 'Set a password first';

  @override
  String get setPassword => 'Set password';

  @override
  String get signMethodSettingsSaved => 'Sign-in method settings saved';

  @override
  String get signMethodSettingsUnsavedLeavingDiscards => 'Sign-in method settings are not saved. Changes will be lost if you leave.';

  @override
  String get serverNotRunDatabaseUpdate014 => 'The server has not run database update 014, so the settings cannot take effect yet.';

  @override
  String get signChannels => 'Sign-in channels';

  @override
  String get socialSmsSign => 'Social and SMS sign-in';

  @override
  String get whenOffSignPageHidesThese => 'When off, the sign-in page hides these methods; linked accounts can still sign in with a password.';

  @override
  String get notConfigured => 'Not configured';

  @override
  String get allowCreatingNewAccountsWithMethod => 'Allow new accounts with this method';

  @override
  String get unsavedChanges2 => 'Unsaved changes';

  @override
  String get taiwan => 'Republic of China (Taiwan)';

  @override
  String get hongKong => 'Hong Kong';

  @override
  String get macau => 'Macau';

  @override
  String get china => 'People\'s Republic of China';

  @override
  String get japan => 'Japan';

  @override
  String get southKorea => 'South Korea';

  @override
  String get singapore => 'Singapore';

  @override
  String get malaysia => 'Malaysia';

  @override
  String get unitedStatesCanada => 'United States / Canada';

  @override
  String get unitedKingdom => 'United Kingdom';

  @override
  String get australia => 'Australia';

  @override
  String get countryCode => 'Country code';

  @override
  String get enterValidMobileNumber => 'Enter a valid mobile number';

  @override
  String get couldNotSendCodePleaseTry => 'Could not send the code. Please try again later.';

  @override
  String get linkMobileNumber => 'Link mobile number';

  @override
  String get signWithMobileNumber => 'Sign in with a mobile number';

  @override
  String get k6DigitCodeSentNumberMessage => 'A 6-digit code will be sent to this number.';

  @override
  String get mobileNumber => 'Mobile number';

  @override
  String get sendCode => 'Send code';

  @override
  String get codeIncorrectPleaseEnterAgain => 'The code is incorrect. Please enter it again.';

  @override
  String get codeBeenSentAgain => 'The code has been sent again';

  @override
  String get enterCode => 'Enter the code';

  @override
  String get enterSmsCode => 'Enter the SMS code';

  @override
  String codeWasSentP0(Object p0) => 'The code was sent to ${p0}';

  @override
  String canResendP0S(Object p0) => 'You can resend in ${p0} s';

  @override
  String get resendCode => 'Resend the code';

  @override
  String get completeAccountDetails => 'Complete your account details';

  @override
  String get p0DidNotProvideEmailAddress => 'Enter your email to complete sign-up.';

  @override
  String signWithP0(Object p0) => 'Sign in with ${p0}';

  @override
  String get signWith2 => 'Or sign in with';

  @override
  String get creatingAccountWithMethodsAboveMeans => 'Creating an account with the methods above means you accept the Terms of Service and the Privacy Policy.';

  @override
  String get emailAlreadyRegistered => 'This email is already registered';

  @override
  String get signWithPasswordThenLinkMethod => 'Sign in with your password, then link it in Account security › Sign-in methods.';

  @override
  String get signWithPassword => 'Sign in with a password';

  @override
  String get accountNoPasswordYet => 'This account has no password yet';

  @override
  String get passwordSet => 'Password set';

  @override
  String get canNowSignWithEmailPassword => 'Other devices must sign in again.';

  @override
  String get passwordRequiredBeforeCanUnlinkSign => 'Use at least 8 characters, including letters and numbers.';

  @override
  String get changingSignMethodsRequiresIdentityVerification => 'Set a password before changing sign-in methods.';

  @override
  String get later => 'Not now';

  @override
  String p0Linked(Object p0) => '${p0} linked';

  @override
  String unlinkP0(Object p0) => 'Unlink ${p0}';

  @override
  String get noLongerAbleSignWayCan => 'You will no longer be able to sign in this way.';

  @override
  String get unlink => 'Unlink';

  @override
  String p0Unlinked(Object p0) => '${p0} unlinked';

  @override
  String get socialSmsSignNotAvailableRight => 'Social and SMS sign-in are not available right now.';

  @override
  String get noSignMethodAvailableLink => 'No sign-in method is available to link.';

  @override
  String get noPasswordSet => 'No password set';

  @override
  String linkedP0(Object p0) => 'Linked on ${p0}';

  @override
  String get link => 'Link';

  @override
  String get emailAlreadyRegisteredSignWithPassword => 'This email is already registered. Sign in with your password first, then link this method under Account security.';

  @override
  String get provideEmailAddressCreateAccount => 'Provide an email address to create an account';

  @override
  String get signMethodOnlyExistingAccounts => 'This sign-in method is only for existing accounts';

  @override
  String get signMethodNotAvailableRightNow => 'This sign-in method is not available right now';

  @override
  String get credentialDoesNotMatchSelectedSign => 'Sign-in failed. Please try again.';

  @override
  String get signMethodLinkedAnotherAccount => 'This sign-in method is linked to another account';

  @override
  String get accountAlreadyLinkedSignMethod => 'This account is already linked to this sign-in method';

  @override
  String get onlySignMethodAccountSetPassword => 'This is the only sign-in method on the account. Set a password or link another method first.';

  @override
  String get socialSignUnavailableServerNotFinished => 'Social sign-in is temporarily unavailable. Please try again later.';

  @override
  String get credentialInvalidExpiredPleaseTryAgain => 'Sign-in timed out. Please try again.';

  @override
  String get accountAlreadyPasswordUseChangePassword => 'This account already has a password. Use Change password instead.';

  @override
  String get signLinkExpiredPleaseTryAgain => 'The sign-in link has expired. Please try again.';

  @override
  String get signResultExpiredPleaseTryAgain => 'Sign-in timed out. Please try again.';

  @override
  String get thirdPartySignServiceUnavailablePlease => 'The third-party sign-in service is unavailable. Please try again later.';

  @override
  String get couldNotCompleteSignPleaseTry => 'Could not complete the sign-in. Please try again.';

  @override
  String get accountNotLinkedSignMethod => 'This account is not linked to this sign-in method';

  @override
  String get mobileNumberFormatNotValid => 'The mobile number format is not valid';

  @override
  String get verificationTimedOutRequestNewCode => 'The verification timed out. Request a new code.';

  @override
  String get codeExpiredRequestNewOne => 'The code has expired. Request a new one.';

  @override
  String get tooManyAttemptsPleaseTryAgain => 'Too many attempts. Please try again later.';

  @override
  String get smsSendingLimitBeenReachedPlease => 'The SMS sending limit has been reached. Please try again later.';

  @override
  String get smsVerificationNotSetUpDevice => 'SMS verification is not available on this device. Use another sign-in method.';

  @override
  String get couldNotCompleteSmsVerificationPlease => 'Could not complete SMS verification. Please try again later.';

  @override
  String get allowSigningLinkingWithMethod => 'Allow signing in and linking with this method';

  @override
  String get appNeverStoresPasswordUsedOnly => 'This app never stores your password; it is used only for this verification.';

  @override
  String get verifyWithBiometricsInstead => 'Verify with biometrics instead';

  @override
  String get accountWasCreatedWithSocialPhone => 'This account has no sign-in password. Set one first.';

  @override
  String get setSignPassword => 'Set a sign-in password';

  @override
  String get enterSignPasswordRunAdminAction => 'Verify with your sign-in password or a passkey to run this admin action';

  @override
  String p1P0MethodsEnabled(Object p0, Object p1) => '${p0} of ${p1} methods are enabled';

  @override
  String get masterSwitchOffSoEveryMethod => 'The master switch is off, so every method is disabled';

  @override
  String get signLinkingDirectSignUpAllowed => 'Sign-in, linking and direct sign-up are allowed';

  @override
  String credentialsNotSetPleaseConfigureP0(Object p0) => 'Credentials are not set. Please configure ${p0} on the server';

  @override
  String get whenOffMethodHiddenFromSign => 'When off, this method is hidden from the sign-in page and Account security';

  @override
  String get whenOffOnlyAccountsAlreadyLinked => 'When off, only accounts already linked to this method can use it';

  @override
  String get signMethodNotLinkedAccount => 'This sign-in method is not linked to an account';

  @override
  String p0AccountNotLinkedAnySavemybook(Object p0) => 'This ${p0} account is not linked to a SaveMyBook account.';

  @override
  String get iAlreadyAccountSignFirst => 'Sign in to an existing account and link';

  @override
  String get createNewAccountWithIdentity => 'Create a new account';

  @override
  String signExistingAccountFirstThenLink(Object p0) => 'Sign in to your existing account first, then link ${p0} in Account security › Sign-in methods.';

  @override
  String get signMethodNotLinkedAnyAccount => 'This sign-in method is not linked to any account';

  @override
  String get verifyIdentityWithPasskeyContinue => 'Verify your identity with a passkey to continue';

  @override
  String get verifyWithPasskeyInstead => 'Verify with a passkey instead';

  @override
  String get passkeys => 'Passkeys';

  @override
  String get verifyWithFaceIdFingerprintScreen => 'Verify with Face ID, fingerprint or the screen lock on this device. No password needed.';

  @override
  String get verifyWithPasskey => 'Verify with passkey';

  @override
  String get useSignPasswordInstead => 'Use sign-in password instead';

  @override
  String get signWithPasskey => 'Sign in with a passkey';

  @override
  String get passkeyAdded => 'Passkey added';

  @override
  String get screenLock => 'your screen lock';

  @override
  String fromNowCanSignVerifyIdentity(Object p0) => 'From now on you can sign in and verify your identity with ${p0} instead of entering your password.';

  @override
  String get deletePasskey => 'Delete passkey';

  @override
  String get noLongerAbleSignVerifyIdentity => 'You will no longer be able to sign in or verify your identity with this passkey. The passkey saved on your device is not removed; you can delete it in the system password settings.';

  @override
  String get passkeyDeleted => 'Passkey deleted';

  @override
  String get signVerifyIdentityWithFaceId => 'Sign in and verify your identity with Face ID, fingerprint or screen lock instead of a password. Passkeys are stored only on your devices and in your password manager.';

  @override
  String get addPasskey => 'Add a passkey';

  @override
  String get notUsedYet => 'Not used yet';

  @override
  String lastUsedFormatdateItemLastusedat(Object p0) => 'Last used ${p0}';

  @override
  String createdCreated(Object p0) => 'Created ${p0}';

  @override
  String get noPasskeyAvailableDeviceUsePassword => 'No passkey is available on this device. Use your password instead.';

  @override
  String get passkeyAlreadyRegisteredDevice => 'A passkey is already registered on this device.';

  @override
  String get signGoogleAccountTurnPasswordManager => 'Sign in to a Google account and turn on a password manager on this device, or use your password instead.';

  @override
  String get setUpScreenLockPasswordManager => 'Set up a screen lock or password manager on this device to create a passkey.';

  @override
  String get deviceDoesNotSupportPasskeysUse => 'This device does not support passkeys. Use your password instead.';

  @override
  String get passkeysTemporarilyUnavailableBecauseAppWebsite => 'Passkeys are currently unavailable. Use your password instead.';

  @override
  String get requestTimedOutPleaseTryAgain => 'The request timed out. Please try again.';

  @override
  String get passkeyRequestFailedUsePasswordInstead => 'The passkey request failed. Use your password instead.';

  @override
  String get verifyIdentityBeforeAddingPasskey => 'Verify your identity before adding a passkey';

  @override
  String get couldNotListPleaseTryAgain => 'Could not list the book. Please try again later.';

  @override
  String downloadLinkValidOnceP0P1(Object p0, Object p1) => 'This download link is valid for 5 minutes and can be used only once. Do not share it.\n\n${p0}\n\nFile size: ${p1}';

  @override
  String get sources => 'Sources';

  @override
  String get unableOpenLink => 'Unable to open the link.';

  @override
  String get helpCentre2 => 'Help centre';

  @override
  String get preferences => 'Preferences';

  @override
  String get privacy => 'Privacy';

  @override
  String get about2 => 'About';

  @override
  String clearP0Notifications(Object p0) => 'Clear ${p0} notifications';

  @override
  String p1NotificationsP0DeletedCannotUndone(Object p0, Object p1) => 'All ${p0} notifications (${p1}) will be deleted. This cannot be undone.';

  @override
  String p0NotificationsCleared(Object p0) => '${p0} notifications cleared';

  @override
  String markAllP1UnreadNotificationsP0(Object p0, Object p1) => 'Mark all unread ${p0} notifications (${p1}) as read?';

  @override
  String get offers => 'Offers';

  @override
  String get noTransactionNotifications => 'No transaction notifications';

  @override
  String get noChatNotifications => 'No chat notifications';

  @override
  String get noAccountNotifications => 'No account notifications';

  @override
  String get noSupportNotifications => 'No support notifications';

  @override
  String get noOfferNotifications => 'No offer notifications';

  @override
  String get images => 'Images';

  @override
  String get imagesStillUploadingPleaseWaitBefore => 'Images are still uploading. Please wait before sending.';

  @override
  String get someImagesFailedUploadRetryRemove => 'Some images failed to upload. Retry or remove them before sending.';

  @override
  String get attachImages => 'Attach images';

  @override
  String get imageCouldNotRead => 'This image could not be read';

  @override
  String get up4ImagesPerMessage => 'Up to 4 images per message';

  @override
  String retryUploadingImageP0(Object p0) => 'Retry uploading image ${p0}';

  @override
  String removeImageP0(Object p0) => 'Remove image ${p0}';

  @override
  String get addImages => 'Add images';

  @override
  String viewImageP0(Object p0) => 'View image ${p0}';

  @override
  String get eGGoldMember => 'e.g. Gold member';

  @override
  String get pointsThreshold => 'Points threshold';

  @override
  String get pts => 'pts';

  @override
  String get tierBenefits => 'Tier benefits';

  @override
  String get oneBenefitPerLine => 'One benefit per line';

  @override
  String get newTier2 => 'New tier';

  @override
  String get whatMembersSee => 'What members see';

  @override
  String get noThresholdSet => 'No threshold set';

  @override
  String get tierOrder => 'Tier order';

  @override
  String get noBenefitsSet => 'No benefits set';

  @override
  String p0CurrentlyP1MembersAfterDeletion(Object p0, Object p1, Object p2) => '“${p0}” currently has ${p1} members. After deletion they will move to “${p2}”.';

  @override
  String noMembersCurrentlyP0OtherTiers(Object p0) => 'No members are currently in “${p0}”. Other tiers are not affected.';

  @override
  String tierDeletedP0MembersMovedP1(Object p0, Object p1) => 'Tier deleted. ${p0} members moved to “${p1}”';

  @override
  String get changeTierOrder => 'Change tier order';

  @override
  String get thresholdsStayWithTheirPositionThese => 'Thresholds stay with their position. These tiers will get new thresholds:';

  @override
  String p0P1P2Pts(Object p0, Object p1, Object p2) => '“${p0}” ${p1} → ${p2} pts';

  @override
  String get tierOrderUpdated => 'Tier order updated';

  @override
  String p0Members(Object p0) => '${p0} members';

  @override
  String get tiers => 'tiers';

  @override
  String get members4 => 'members';

  @override
  String get memberDistribution => 'Member distribution';

  @override
  String get moreActions => 'More actions';

  @override
  String get dragReorder => 'Drag to reorder';

  @override
  String p0Pts(Object p0) => '${p0}+ pts';

  @override
  String p0P1Pts(Object p0, Object p1) => '${p0}–${p1} pts';

  @override
  String tierNamedP0AlreadyExists(Object p0) => 'A tier named “${p0}” already exists';

  @override
  String get enterPointsThreshold => 'Enter a points threshold';

  @override
  String get thresholdMustWholeNumber0More => 'The threshold must be a whole number of 0 or more';

  @override
  String thresholdCannotExceedP0(Object p0) => 'The threshold cannot exceed ${p0}';

  @override
  String p0AlreadyUsesP1PtsEach(Object p0, Object p1) => '“${p0}” already uses ${p1} pts. Each tier needs a different threshold';

  @override
  String get startingTierMustBegin0Pts => 'The starting tier must begin at 0 pts';

  @override
  String get startingTierCannotDeletedSetAnother => 'The starting tier cannot be deleted. Set another tier’s threshold to 0 pts first';

  @override
  String get signLink => 'Sign in and link';

  @override
  String get signAccount => 'Sign in to your account';

  @override
  String emailAlreadyRegisteredSignLinkName(Object p0) => 'This email is already registered. Sign in to link ${p0}.';

  @override
  String signLinkNameCanThenSign(Object p0, Object p1) => 'Sign in to link ${p0}. You can then sign in with ${p1} directly.';

  @override
  String get noPasskeyDevice => 'No passkey on this device';

  @override
  String get signWithPasskeyAnotherDeviceSecurity => 'Sign in with a passkey on another device or a security key, or use your password.';

  @override
  String get useAnotherDevice => 'Use another device';

  @override
  String get usePassword => 'Use password';

  @override
  String get icloudKeychain => 'iCloud Keychain';

  @override
  String get googlePasswordManager => 'Google Password Manager';

  @override
  String get synced => 'Synced';

  @override
  String get notSynced => 'Not synced';

  @override
  String get alreadyPasskey => 'You already have a passkey';

  @override
  String get enterName => 'Enter a name';

  @override
  String get passkeySavedIcloudKeychainWorksEvery => 'Your passkey is saved in iCloud Keychain and works on every device signed in to the same Apple Account, so there is no need to add it again. To create another one, tap "Add again" and choose a different password manager or a security key in the system window.';

  @override
  String get passkeySavedGooglePasswordManagerWorks => 'Your passkey is saved in Google Password Manager and works on every device signed in to the same Google Account, so there is no need to add it again. To create another one, tap "Add again" and choose a different password manager or a security key in the system window.';

  @override
  String get passkeySavedDeviceSPasswordManager => 'Your passkey is saved in this device\'s password manager and works on every device signed in to the same account, so there is no need to add it again. To create another one, tap "Add again" and choose a different password manager or a security key in the system window.';

  @override
  String get addAgain => 'Add again';

  @override
  String get codeExpiredPleaseRequestNewOne => 'This code has expired. Please request a new one.';

  @override
  String codeValidP0(Object p0) => 'Code valid for ${p0}';

  @override
  String get basicSettings => 'Basic settings';

  @override
  String get eGBirthdayVoucher => 'e.g. Birthday voucher';

  @override
  String get benefitDetails => 'Benefit details';

  @override
  String get addBenefit => 'Add benefit';

  @override
  String get bookNoLongerExistsBeenRemoved => 'This book no longer exists or has been removed.';

  @override
  String get myNicknameGroup => 'My nickname in this group';

  @override
  String get setGroupNickname => 'Set group nickname';

  @override
  String get allGroupMembersSeeNickname => 'All group members will see this nickname.';

  @override
  String get markLockerMaintenance => 'Mark under maintenance';

  @override
  String get endLockerMaintenance => 'End maintenance';

  @override
  String maintenanceHidesP0FromSellers(Object p0) => 'While under maintenance, "${p0}" is hidden from the seller drop-off list. Existing orders are not affected.';

  @override
  String endingMaintenanceP0AvailableAgain(Object p0) => 'Once maintenance ends, "${p0}" is available to sellers again.';

  @override
  String get lockerMarkedMaintenance => 'Locker marked under maintenance';

  @override
  String get lockerMaintenanceEnded => 'Locker maintenance ended';

  @override
  String get semanticIndex => 'Semantic index';

  @override
  String get semanticSearch => 'Semantic search';

  @override
  String p0BooksP1HelpArticlesIndexed(Object p0, Object p1) => '${p0} books and ${p1} help articles indexed';

  @override
  String get noOpenaiGeminiKeyConfiguredOnly => 'No OpenAI or Gemini key is configured. Only keyword search is in use.';

  @override
  String get databaseNotBeenUpdated020Only => 'The database has not been updated (020). Only keyword search is in use.';

  @override
  String get hybridSearchKeywordSemantic => 'Hybrid search (keyword + semantic)';

  @override
  String get keywordSearchOnly => 'Keyword search only';

  @override
  String get paymentReleasedWalletWhenBuyerCompletes => 'Payment is released to your wallet when the buyer completes the order or 24 hours after pickup';

  @override
  String get completeOrderAfterCheckingBookCompletes => 'Complete the order after checking the book. It completes automatically 24 hours after pickup if no dispute is opened';

  @override
  String get completeOrder => 'Complete order';

  @override
  String get onceCompleteOrderPaymentReleasedSeller => 'Once you complete the order, the payment is released to the seller and you can no longer open a dispute.';

  @override
  String get orderCompleted2 => 'Order completed';

  @override
  String get noReservedBooks => 'No reserved books';

  @override
  String heldUntilP02(Object p0) => 'Held until ${p0}';

  @override
  String heldUntilP03(Object p0) => 'Held until ${p0}';

  @override
  String get awaitingBuyerConfirmation => 'Awaiting buyer confirmation';

  @override
  String get awaitingCompletion => 'Awaiting completion';

  @override
  String get libraryCopyUnofficialSource => 'Library copy or unofficial source';

  @override
  String p0CannotEdit(Object p0) => '${p0} · Cannot edit';

  @override
  String get buyNow2 => 'Buy now';

  @override
  String get suggestRefund => 'Suggest refund';

  @override
  String get suggestDismissal => 'Suggest dismissal';

  @override
  String get needsMoreInformation => 'Needs more information';

  @override
  String get aiAnalysis => 'AI analysis';

  @override
  String get analyze => 'Analyze';

  @override
  String get analyzeAgain => 'Analyze again';

  @override
  String get aiAnalysisReferenceOnlyDecideBased => 'The AI analysis is for reference only. Decide based on the actual evidence.';

  @override
  String p0P1Confidence(Object p0, Object p1) => '${p0} · ${p1}% confidence';

  @override
  String get aiSummary => 'AI summary';

  @override
  String get autoFilled => 'Auto-filled';

  @override
  String get similarBooks => 'Similar books';

  @override
  String get doNotPayTransferMoneyOutside => 'Do not pay or transfer money outside the app. Off-platform payments are not protected.';

  @override
  String get pleaseCompleteDealAppWeCannot => 'Please complete the deal in the app. We cannot help with disputes over off-platform deals.';

  @override
  String get personSharedOutsideContactDetailsWatch => 'This person shared outside contact details. Watch out for scams and complete the deal in the app.';

  @override
  String get mostRelevant => 'Most relevant';

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
  String get orderRefunding => '審査中';

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
  String get orderFlowPickup => '購入者が受け取り済み';

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
  String get language => '言語';

  @override
  String get languageSystem => 'システムに合わせる';

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
  String get accountPermanentlyDisabled30DaysSign => 'アカウントは 30 日後に削除されます。期間内に再ログインするとキャンセルできます。削除後は個人データが消去されますが、完了した注文と取引記録は保持されます。';

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
  String get cancelAccountDeletion => 'アカウント削除をキャンセル';

  @override
  String get deletionPending => '削除待ち';

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
  String get signStartChat => '出品者に連絡するにはログインしてください';

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
  String get reportSubmittedWeLookInto => '報告を送信しました';

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
  String get messageSeller => '出品者に相談';

  @override
  String get listing => 'あなたの出品です';

  @override
  String get addCart => 'カートに追加';

  @override
  String get bookBeenReportedUnderReviewStays => 'この本は報告を受け、審査中です。';

  @override
  String get violationWasConfirmedBookPleaseCheck => 'この本は違反が確認されました。出品内容を修正してください。';

  @override
  String get delist => '出品を取り消す';

  @override
  String removedFromShopBuyersNoLonger(Object p0) => '「${p0}」はショップから外され、購入者には表示されなくなります。';

  @override
  String get delist2 => '出品停止';

  @override
  String get couldNotDelistPleaseTryAgain => '出品停止に失敗しました。しばらくしてからお試しください。';

  @override
  String listedAgain(Object p0) => '「${p0}」を再出品しました';

  @override
  String get notListedAnyBooksYet => 'まだ本を出品していません';

  @override
  String get noBooksCategory => 'このカテゴリーに書籍はありません';

  @override
  String get relist => '再出品';

  @override
  String get remove => '削除';

  @override
  String get couldNotRemoveRestored => '削除できませんでした。元に戻しました。';

  @override
  String get selectBooksWantCheckOut => 'お会計する本を選んでください';

  @override
  String notEnoughCoinsOrderNeedsBut(Object p0, Object p1) => 'コインが足りません。この注文には ${p0} 必要ですが、残高は ${p1} です。';

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
  String markAllUnreadMessagesAsRead(Object p0) => '未読メッセージ ${p0} 件をすべて既読にしますか？';

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
  String get messageCouldNotSent => 'メッセージを送信できませんでした';

  @override
  String get chat => 'チャット';

  @override
  String get sendFirstMessage => '最初のメッセージを送信してください';

  @override
  String get messageCopied => 'メッセージをコピーしました';

  @override
  String get iQuestionAboutBook => '本に関するお問い合わせ';

  @override
  String get bookNoLongerListed => 'この本は出品停止されています';

  @override
  String get writeMessage => 'メッセージを入力…';

  @override
  String get enterOrderNumberDisputing => '異議を申し立てる注文番号を入力してください';

  @override
  String get describeDispute => '異議の内容を記入してください';

  @override
  String get useLeast10CharactersSoSupport => '説明は 10 文字以上必要です';

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
  String get submitDispute2 => '異議を申し立てる';

  @override
  String get orderNumber => '注文番号';

  @override
  String get eGSmb20260910123456789 => '例：SMB20260910123456789';

  @override
  String get whatHappened => '異議の内容';

  @override
  String get describeProblemEGConditionDoes => '発生した問題を入力してください';

  @override
  String get submit => '申請を送信';

  @override
  String get uploadPhotos => '画像をアップロード';

  @override
  String get canAttachUp6Photos => '添付できる写真は 6 枚までです';

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
  String get photoMissingDataRefreshTryAgain => 'この写真を処理できません。更新してからお試しください。';

  @override
  String get enterPrice => '価格を入力してください';

  @override
  String get priceMustGreaterThan0 => '価格は 0 より大きい必要があります';

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
  String get tapPickPublicationDate => '発行日を選択';

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
  String get tellPeopleAboutYourself => '自己紹介を入力してください';

  @override
  String get email => 'メールアドレス';

  @override
  String get emailCannotChanged => 'メールアドレスは変更できません';

  @override
  String get dateBirth => '生年月日';

  @override
  String get tapPickDateBirth => '生年月日を選択';

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
  String get documentNotBeenCreatedYet => '内容はありません';

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
  String get membershipTiersNotSetUpYet => '会員ランクは現在提供されていません';

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
  String get noBenefitsBeenDescribedTierYet => 'このランクには追加特典はありません';

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
  String markAllUnreadNotificationsAsRead(Object p0) => '未読の通知 ${p0} 件をすべて既読にしますか？';

  @override
  String get openChat => 'チャットを開く';

  @override
  String get viewOrder => '注文を見る';

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
  String get orderNoItemDetails => '商品明細はありません';

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
  String get notAssignedYet => 'ロッカー未割り当て';

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
  String get coinsArriveOnceBuyerCollectsBook => '購入者の受け取り後に自動入金';

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
  String collected(Object p0) => '「${p0}」を受け取りました';

  @override
  String order2(Object p0) => '注文番号：${p0}';

  @override
  String get signingOut => 'ログアウト中…';

  @override
  String get myAccount => 'マイページ';

  @override
  String get personNotWrittenBioYet => '自己紹介は未入力です';

  @override
  String get topTierReached => '最高ランク達成';

  @override
  String morePointsReach(Object p0, Object p1) => 'あと ${p0} ポイントで「${p1}」へ';

  @override
  String get purchases => '購入履歴';

  @override
  String get sales => '販売履歴';

  @override
  String get settings => '設定';

  @override
  String get signOut2 => 'ログアウトしますか？';

  @override
  String cancelOrderBookReturnsShop(Object p0) => '注文 ${p0} をキャンセルしますか？本は再びショップに並びます。';

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
  String get joinSavemybook => 'アカウント登録';

  @override
  String get displayName => '表示名';

  @override
  String get emailSignWith => 'メールアドレス';

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
  String get priceCannotExceed99999 => '価格は 99,999 コイン以下にしてください。';

  @override
  String get chooseLockerLocation2 => '保管場所を選んでください。';

  @override
  String get listed2 => '出品しました';

  @override
  String get unknownError => '不明なエラー';

  @override
  String get couldNotListBook => '出品に失敗しました';

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
  String get noSourceIsbnPleaseEnterDetails => 'どのデータベースにもこの ISBN が見つかりません。手動で入力してください。';

  @override
  String get day => '日';

  @override
  String get tapIconRightScan => 'ISBN を入力';

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
  String sign3(Object p0) => '${p0} でログイン';

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
  String addMeSavemybook(Object p0) => 'SaveMyBook のプロフィール：${p0}';

  @override
  String addMeSavemybook2(Object p0, Object p1) => '${p0} さんの SaveMyBook プロフィール：${p1}';

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
  String get addMoreDetailSoSupportCan => '問題の説明を追記してください';

  @override
  String get sentSupportReplySoon => '送信しました。サポートよりご返信します。';

  @override
  String get subject => '件名';

  @override
  String get sumUpOneLine => '問題の概要';

  @override
  String get whatHappenedIncludeOrderNumberIf => '問題の内容をご記入ください。注文番号がある場合は併せてご記入ください。';

  @override
  String get close => 'クローズ';

  @override
  String get notAbleReplyAfterClosing => 'クローズすると返信できなくなります。';

  @override
  String get enquiryClosed => 'お問い合わせを終了しました';

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
  String get noAnnouncementsYetTapAddOne => 'お知らせはありません';

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
  String get noBackupsYetSchedulerRunsOnce => 'バックアップはありません';

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
  String sectionP0NoTitleYet(Object p0) => '第${p0}';

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
  String get noArticlesYetAddFirstOne => '条文はありません';

  @override
  String get addSection => '章を追加';

  @override
  String get untitledSection => '無題の章';

  @override
  String get sectionTitle => '章のタイトル';

  @override
  String get bodySectionSingleLineBreaksKept => 'この章の本文です。単一の改行はそのまま表示され、空行で段落が変わります。';

  @override
  String get howUsersSee => 'ユーザーに見える表示';

  @override
  String get noContentYet => '内容がありません';

  @override
  String get unsaved => '未保存';

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
  String orderP0P1(Object p0, Object p1) => '注文 ${p0}｜\$${p1}';

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
  String get listings => '商品管理';

  @override
  String get moderation => 'コンテンツ審査';

  @override
  String get handleListingReports => '商品の報告対応';

  @override
  String get members => '会員管理';

  @override
  String get memberControls => '会員の管理';

  @override
  String get membershipTiers => '会員ランク管理';

  @override
  String get wallets => 'ウォレット管理';

  @override
  String get hardwareOperations => 'ハードウェアと運用';

  @override
  String get maintenanceLog => 'メンテナンス記録';

  @override
  String get reports => '運用レポート';

  @override
  String get ordersRevenueMemberGrowth => '注文・売上・会員の推移';

  @override
  String get supportEnquiries => 'お問い合わせ';

  @override
  String get adminAuditLog => '管理操作の記録';

  @override
  String get systemOperations => 'システム運用';

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
  String get searchDisplayNameEmail => '表示名・メールアドレスで検索';

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
  String get remindThemChangeSettingsChangePassword => 'ログイン後すぐに「設定 › パスワード変更」で変更するよう伝えてください。';

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
  String get changeOwnPasswordGoSettingsChange => '自分のパスワードは「設定 › パスワード変更」から変更してください';

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

  @override
  String get buyerSPaymentGoesBackTheir => '買い手の支払いはウォレットに返金されます。売り手に代金が支払い済みの場合は先に回収します。';

  @override
  String get orderReturnsWhereWasBeforeDispute => '注文は申し立て前の状態に戻り、取引を続けます。受け取り済みだった場合は売り手に代金を支払います。';

  @override
  String get orderWasAlreadyRefundedBuyerCannot => 'この注文は買い手に返金済みのため、進行中や完了には戻せません';

  @override
  String get completedOrderCanOnlyChangedRefund => '完了した注文は「返金処理中」か「返金済み」にしか変更できません';

  @override
  String confirmingPaysP0TokensSellerMarks(Object p0) => '確定すると売り手に ${p0} トークンを支払い、本を売却済みにします。';

  @override
  String confirmingTakesP0TokensBackFrom(Object p0) => '確定すると売り手から ${p0} トークンを回収し、買い手に返金します。売り手の残高が不足する場合はマイナスになります。';

  @override
  String get ifBuyerNotBeenRefundedYet => 'まだ返金されていない場合は、買い手に返金します。';

  @override
  String confirmingRefundsBuyerSP0Tokens(Object p0) => '確定すると買い手が支払った ${p0} トークンを返金し、取り置き中の本を再出品します。';

  @override
  String get donTPermissionYourselfSoCan => '自分がこの権限を持っていないため、他の人に付与できません。';

  @override
  String get notificationsTurnedOff => '通知がオフになっています';

  @override
  String get openSettings => '設定を開く';

  @override
  String get sendTestNotification => 'テスト通知を送信';

  @override
  String get arrives10SecondsGoHomeScreen => '10秒後に届きます。送信後はホーム画面に戻るか、端末をロックしてください。';

  @override
  String get systemNotificationSettings => 'システムの通知設定';

  @override
  String get pushNotificationsNotSetUpBuild => 'このビルドではプッシュ通知が設定されていません。Firebaseの設定ファイルを追加して再ビルドしてください。';

  @override
  String get notificationsTurnedOffAllowAppSend => '通知がオフになっています。システム設定でこのアプリの通知を許可してください。';

  @override
  String get restoreBackup => 'このバックアップに復元しますか？';

  @override
  String wholeDatabaseGoBackP0Orders(Object p0) => 'データベース全体が ${p0} の状態に戻ります。それ以降の注文、メッセージ、会員データ、操作履歴はすべて失われます。\n\n復元前に現在の状態が自動でバックアップされるので、誤った場合はそのバックアップに戻せます。復元中はサービスが停止し、通常は数十秒から数分かかります。\n\n確認のためログインパスワードを入力してください：';

  @override
  String get password2 => 'ログインパスワード';

  @override
  String get startRestore => '復元を開始';

  @override
  String get backingUpCurrentState => '現在の状態をバックアップしています…';

  @override
  String databaseRestoredPreviousStateWasBacked(Object p0) => 'データベースを復元しました。復元前の状態は ${p0} にバックアップされています';

  @override
  String restoreFailedDatabaseMayUnchangedPartly(Object p0) => '復元に失敗しました。データベースは元のままか一部だけ復元された可能性があります。操作履歴を確認し、${p0} への復元を検討してください';

  @override
  String get autoBackupBeforeRestore => '復元前の自動バックアップ';

  @override
  String get restoreBackup2 => 'このバックアップに復元';

  @override
  String get restoringDatabase => 'データベースを復元しています';

  @override
  String p0SecondsSoFarKeepApp(Object p0) => '${p0} 秒経過しました。アプリを閉じないでください。完了すると自動でサービスが再開します。';

  @override
  String get majorUpdate2 => '重要な更新';

  @override
  String get minorEdit => '軽微な修正';

  @override
  String get books => '本';

  @override
  String get orders2 => '注文';

  @override
  String get wallets2 => 'ウォレット';

  @override
  String get announcements3 => 'お知らせ';

  @override
  String get legal => '規約';

  @override
  String get backups => 'バックアップ';

  @override
  String get undoAction => 'この操作を取り消しますか？';

  @override
  String p0NNtheDataGoesBack(Object p0) => '「${p0}」\n\nデータは操作前の状態に戻ります。送信済みの通知は取り消されません。その後さらに変更されていた場合、取り消しはできません。';

  @override
  String get undo => '取り消す';

  @override
  String get undone => '取り消し済み';

  @override
  String get searchActionsEGNicknameBook => '操作内容を検索（例：会員名や書名）';

  @override
  String viewP0Changes(Object p0) => '${p0} 件の変更を表示';

  @override
  String get undoAction2 => 'この操作を取り消す';

  @override
  String get noAnnouncements => 'お知らせはありません';

  @override
  String get canTContinueWithoutAccepting => '同意しないと利用を続けられません';

  @override
  String needAcceptLatestP0UseP1(Object p0) => '「${p0}」に同意しない場合はログアウトします。';

  @override
  String get goBack => '戻る';

  @override
  String p0BeenUpdated(Object p0) => '「${p0}」が更新されました';

  @override
  String readLatestVersionUpdatedP0Accept(Object p0) => '${p0} 更新';

  @override
  String get scrollEndContinue => '最後までスクロールしてください';

  @override
  String get iVeReadAccept => '読んで同意しました';

  @override
  String get decline => '同意しない';

  @override
  String get viewDetails => '詳細を見る';

  @override
  String get notFoundMayBeenDeletedRemoved => 'このコンテンツは存在しません';

  @override
  String get chatMessages => 'チャットメッセージ';

  @override
  String get promotions2 => 'キャンペーン';

  @override
  String get supportRepliesPasswordResetsPolicyUpdates => 'サポートの返信、アカウントセキュリティ、システムのお知らせはオフにできません。';

  @override
  String get notFilled => '未入力';

  @override
  String get canTChanged => '変更不可';

  @override
  String get voice => '[音声]';

  @override
  String get reservation => '予約';

  @override
  String get messageUnsent => 'メッセージの送信を取り消しました';

  @override
  String get confirmBeforeExportingData => 'データを書き出す前に本人確認をしてください';

  @override
  String get exportFailedPleaseTryAgainLater => '書き出しに失敗しました。しばらくしてからお試しください';

  @override
  String get refresh => '再読み込み';

  @override
  String get clearFilters => '絞り込みを解除';

  @override
  String get expired => '期限切れ';

  @override
  String get verificationCancelled => '認証をキャンセルしました';

  @override
  String get openingClosingTimesCanTSame => '開始時刻と終了時刻を同じにはできません';

  @override
  String slotCurrentlyP0MayOrderProgress(Object p0, Object p1) => 'この区画は現在「${p0}」で、進行中の注文があるかもしれません。「${p1}」に変更すると、購入者や出品者が本を預けたり受け取ったりできなくなる可能性があります。';

  @override
  String get active => '稼働中';

  @override
  String get categoryWithNameAlreadyExists => '同じ名前のカテゴリがすでにあります';

  @override
  String orderP0ClosedAsP1P2(Object p0, Object p1, Object p2) => '注文 ${p0} を「${p1}」で解決し、${p2} コインを購入者に返金します。送信後は変更できません。';

  @override
  String orderP0ClosedAsP1Can(Object p0, Object p1) => '注文 ${p0} を「${p1}」で解決します。送信後は変更できません。';

  @override
  String get clearSearch => '検索をクリア';

  @override
  String get enterMinimumPoints => '最低ポイントを入力してください';

  @override
  String pointsRangeOverlapsWithP0P1(Object p0, Object p1) => 'ポイント範囲が「${p0}」（${p1}）と重なっています';

  @override
  String noTierCoversP0P1Points(Object p0, Object p1) => '${p0}–${p1} ポイントに該当するランクがありません';

  @override
  String p0TakenDownRightAwayOther(Object p0) => '「${p0}」はすぐに非公開になり、ほかの会員は閲覧・購入できなくなります。';

  @override
  String get searchReportedItemReporterReason => '通報対象・通報者・理由で検索';

  @override
  String get couldnTLoadStatisticsRightNow => '統計データを取得できませんでした';

  @override
  String get searchSubjectMemberMessage => '件名・会員・メッセージで検索';

  @override
  String get balance3 => '残高あり';

  @override
  String get hold3 => '保留中あり';

  @override
  String get zeroBalance => '残高 0';

  @override
  String get amountCanMost2DecimalPlaces => '金額は小数点以下2桁までです';

  @override
  String get singleAdjustmentCanTExceed1 => '1回の調整は 1,000,000 までです';

  @override
  String wouldMakeBalanceNegativeCurrentBalance(Object p0) => '差し引くと残高がマイナスになります。現在の残高：${p0}';

  @override
  String get amountUp2Decimals => '金額（小数点以下2桁まで）';

  @override
  String p0NbalanceAfterP1(Object p0, Object p1) => '${p0}\n調整後の残高：${p1}';

  @override
  String get cameraAccessOff => 'カメラを使用できません';

  @override
  String get couldNotStartCamera => 'カメラを起動できませんでした';

  @override
  String allowP0UseCameraSettingsThen(Object p0) => '設定で ${p0} のカメラへのアクセスを許可してから、もう一度お試しください。';

  @override
  String get closeScreenTryAgain => 'この画面を閉じてもう一度お試しください。';

  @override
  String get couldnTGetLocationCheckLocation => '現在地を取得できません。位置情報サービスと権限がオンか確認してください';

  @override
  String get bookReservedAnotherBuyerCanT => 'この本は他の購入者が予約中のため、今はカートに追加できません';

  @override
  String reservedAnotherBuyerUntilP0(Object p0) => '他の購入者が ${p0} まで予約中';

  @override
  String sellerHoldingUntilP0(Object p0) => '出品者が ${p0} まであなたのために取り置き中';

  @override
  String get checkOutBeforeHoldEndsOther => '保留期限内に購入手続きを完了してください';

  @override
  String get copyAddress => '住所をコピー';

  @override
  String p0Away(Object p0) => 'ここから ${p0}';

  @override
  String get locating => '位置を取得中…';

  @override
  String get showDistance => '距離を表示';

  @override
  String get reserved => '予約済み';

  @override
  String get goCheckout => '購入手続きへ';

  @override
  String get cart2 => 'カートに追加済み';

  @override
  String get buyNow => '今すぐ購入';

  @override
  String p0Delisted(Object p0) => '『${p0}』を出品停止しました';

  @override
  String noBooksMatchP0(Object p0) => '「${p0}」に一致する本はありません';

  @override
  String p0BooksP1Views(Object p0, Object p1) => '${p0} 冊 · 閲覧 ${p1} 回';

  @override
  String get searchTitleAuthorIsbn2 => '書名・著者・ISBN で検索';

  @override
  String removedP0(Object p0) => '「${p0}」を削除しました';

  @override
  String removedP0Items(Object p0) => '${p0} 点を削除しました';

  @override
  String get paymentSuccessful => '支払いが完了しました';

  @override
  String p0BooksSplitIntoP1Orders(Object p0, Object p1) => '計 ${p0} 冊、出品者ごとに ${p1} 件の注文に分けました';

  @override
  String get keepBrowsing => '買い物を続ける';

  @override
  String get reload => '再読み込み';

  @override
  String get browseBooks => '本を探す';

  @override
  String p0Sellers(Object p0) => '出品者 ${p0} 人';

  @override
  String unavailableP0(Object p0) => '購入できません（${p0}）';

  @override
  String get removeAll => 'すべて削除';

  @override
  String get goWallet => 'ウォレットへ';

  @override
  String fromP0SellersCheckoutCreatesP1(Object p0, Object p1) => '出品者 ${p0} 人の商品です。購入後 ${p1} 件の注文に分かれます';

  @override
  String get otherDevicesNeedSignAgainWith => '他の端末では新しいパスワードで再ログインが必要です。';

  @override
  String get searchChats => 'チャット相手を検索';

  @override
  String get noMatchingChats => '該当するチャットがありません';

  @override
  String get read => '既読';

  @override
  String get chatNotFound => 'チャットが見つかりません';

  @override
  String get messagesCanUp2000Characters => 'メッセージは2000文字までです';

  @override
  String get canTSendRightNowPlease => '現在送信できません。しばらくしてから再度お試しください';

  @override
  String get reserveBook => 'この本を予約';

  @override
  String get quickReplies => 'クイック返信';

  @override
  String get imagesMust10MbSmaller => '画像は10MB以下にしてください';

  @override
  String get recordingFailedPleaseTryAgain => '録音に失敗しました。もう一度お試しください';

  @override
  String get voiceMessageTooLargePleaseRecord => '音声ファイルが大きすぎます。短く録音してください';

  @override
  String get microphoneAllowedPressHoldAgainRecord => 'マイクを許可しました。もう一度長押しして録音してください';

  @override
  String get microphoneAccessNeededRecordTurnSettings => '録音にはマイクへのアクセスが必要です。設定で許可してください';

  @override
  String get couldnTStartRecordingPleaseTry => '録音を開始できません。しばらくしてから再度お試しください';

  @override
  String get selectText => 'テキストを選択';

  @override
  String get unsend => '送信取消';

  @override
  String get resend => '再送信';

  @override
  String get unsendMessage => 'このメッセージの送信を取り消しますか？';

  @override
  String get neitherAbleSeeMessageSContent => '取り消すと、お互いにこのメッセージの内容が見えなくなります。';

  @override
  String get reportMessage => 'このメッセージを報告';

  @override
  String get reservationSentWaitingSeller => '予約を送信しました。出品者の返信をお待ちください';

  @override
  String get acceptReservation => '予約を承認しますか？';

  @override
  String p0HeldThemP1HoursNo(Object p0, Object p1) => '「${p0}」を相手のために${p1}時間取り置きします。その間、他の人は購入できません。';

  @override
  String get accept => '承認';

  @override
  String get reservationAccepted => '予約を承認しました';

  @override
  String get declineReservation => '予約をお断りしますか？';

  @override
  String get decline2 => 'お断り';

  @override
  String get reservationDeclined => '予約をお断りしました';

  @override
  String get cancelReservation => '予約をキャンセルしますか？';

  @override
  String p0NoLongerHeld(Object p0) => 'キャンセルすると「${p0}」の取り置きは解除されます。';

  @override
  String get cancelReservation2 => '予約をキャンセル';

  @override
  String get reservationCanceled => '予約をキャンセルしました';

  @override
  String get notNow2 => '戻る';

  @override
  String get couldnTLoadConversationPleaseTry => '会話を読み込めません。しばらくしてから再度お試しください';

  @override
  String get accountCanTReceiveMessagesRight => '相手のアカウントは現在メッセージを受け取れません';

  @override
  String get holdMicTalkReleaseSend => '録音が短すぎます';

  @override
  String get startConversation => 'ここから会話が始まります';

  @override
  String p0New(Object p0) => '新着 ${p0} 件';

  @override
  String get connectionUnstableMessagesCanTSent => '接続が不安定なため、現在メッセージを送信できません';

  @override
  String get retry => '再試行';

  @override
  String get stillAvailable => 'こちらの本はまだ購入可能ですか？';

  @override
  String get couldLowerPriceBit => '価格のご相談は可能ですか？';

  @override
  String get whenCanPutLocker => 'ロッカーへの預け入れはいつ頃になりますか？';

  @override
  String get unsentMessage => 'メッセージの送信を取り消しました';

  @override
  String get theyUnsentMessage => '相手がメッセージの送信を取り消しました';

  @override
  String get reservationDetailsArenTAvailableRight => '予約情報を表示できません';

  @override
  String get sending => '送信中';

  @override
  String get couldNotUploadPhotosPleaseTry => '証拠写真のアップロードに失敗しました。しばらくしてからお試しください';

  @override
  String get bookDetailsUpdatedButPhotosCouldn => '書籍情報は更新しましたが、写真をアップロードできませんでした。後でもう一度お試しください';

  @override
  String get sNotIsbnBarcodeScanOne => 'ISBN バーコードではありません。裏表紙の 978 または 979 で始まるバーコードを読み取ってください';

  @override
  String get couldnTLoadCategoriesTapRetry => 'カテゴリを読み込めませんでした。タップして再試行';

  @override
  String removedP0FromSaved(Object p0) => '「${p0}」を保存済みから外しました';

  @override
  String get recentlyViewedCleared => '最近見た本を消去しました';

  @override
  String clearP0(Object p0) => 'クリア（${p0}）';

  @override
  String get picked => 'あなたへのおすすめ';

  @override
  String get recentlyViewed => '最近見た本';

  @override
  String get clear => 'クリア';

  @override
  String get notificationDeleted => '通知を削除しました';

  @override
  String get pleasePutBookAssignedLockerSoon => 'できるだけ早く指定のロッカーに本を入れてください';

  @override
  String get weLlLetKnowWhenSeller => '出品者が本を入れたら受け取りをお知らせします';

  @override
  String get waitingBuyerCollect => '購入者の受け取り待ち';

  @override
  String get transactionCompleteThank => '取引完了';

  @override
  String get confirmVeTakenBookFromLocker => 'ロッカーから書籍を取り出したことを確認してください。状態に問題がなければ、購入履歴で注文を完了してください。';

  @override
  String p0Orders2(Object p0) => '注文 ${p0} 件';

  @override
  String p0ReadyPickup(Object p0) => '受け取り可能 ${p0} 件';

  @override
  String get pickUp => '受取待ち';

  @override
  String get saved => 'お気に入り';

  @override
  String get accountSecurity => 'アカウントのセキュリティ';

  @override
  String get searchHistoryCleared => '検索履歴を消去しました';

  @override
  String get trendingBooks => '人気の本';

  @override
  String get signOutDevice => 'この端末をログアウトしますか？';

  @override
  String signOutP0(Object p0) => '「${p0}」をログアウトしますか？';

  @override
  String get deviceSignedOutRightAwayStop => 'その端末はすぐにログアウトされます。';

  @override
  String get deviceSignedOut => 'この端末をログアウトしました';

  @override
  String get signOutAllDevicesIncludingOne => 'すべての端末からログアウト（この端末を含む）';

  @override
  String get signOutAllOtherDevices => 'ほかのすべての端末からログアウト';

  @override
  String get everyDeviceIncludingOneSignedOut => 'この端末を含むすべての端末がすぐにログアウトされます。';

  @override
  String get everyDeviceExceptOneSignedOut => 'この端末以外のすべての端末がすぐにログアウトされます。';

  @override
  String signedOutP0OtherDevices(Object p0) => '他の ${p0} 台の端末からログアウトしました';

  @override
  String get unknownDevice => '不明な端末';

  @override
  String get couldnTLoadDevices => '端末を読み込めませんでした';

  @override
  String get device => 'この端末';

  @override
  String get otherDevices => '他の端末';

  @override
  String otherDevicesP0(Object p0) => '他の端末（${p0}）';

  @override
  String get noOtherDevicesSigned => '他の端末はログインしていません';

  @override
  String get signedDevices => 'ログイン中の端末';

  @override
  String get activeNow => '使用中';

  @override
  String lastActiveP0(Object p0) => '最終利用 ${p0}';

  @override
  String signedP0(Object p0) => '${p0} にログイン';

  @override
  String get biometricPayment => '生体認証での支払い：オン';

  @override
  String get paymentPinMust6Digits => '取引パスワードは 6 桁の数字にしてください';

  @override
  String get pinTooEasyGuessTryAnother => '取引パスワードが単純すぎます。別の番号にしてください';

  @override
  String get enterPasswordResetPaymentPin => 'ログインパスワードを入力すると取引パスワードを再設定できます';

  @override
  String get confirmSBeforeSettingPaymentPin => '取引パスワードを設定する前に本人確認をしてください';

  @override
  String get pinsDonTMatchStartAgain => '2 回の入力が一致しません。もう一度設定してください';

  @override
  String get paymentPinReset => '取引パスワードを再設定しました';

  @override
  String get paymentPinSet => '取引パスワードを設定しました';

  @override
  String get verifyingIdentity => '本人確認中…';

  @override
  String get enterAgainConfirm => '確認のためもう一度入力';

  @override
  String get set6DigitPaymentPin => '6 桁の取引パスワードを設定';

  @override
  String get enterSamePinAgain => 'もう一度同じパスワードを入力してください';

  @override
  String get avoidRepeatedSequentialPatternedDigits => '同じ数字・連続・繰り返しは使えません';

  @override
  String get resetPaymentPin => '取引パスワードを再設定';

  @override
  String get paymentPin => '取引パスワード';

  @override
  String stepP02(Object p0) => 'ステップ ${p0} / 2';

  @override
  String get setPaymentPinFirst => '先に取引パスワードを設定してください';

  @override
  String get setPaymentPinFirstSoFallback => '先に取引パスワードを設定してください。認証に失敗したときの代わりになります';

  @override
  String get setUpNow => '今すぐ設定';

  @override
  String get biometricPaymentTurnedOff => '生体認証での支払いをオフにしました';

  @override
  String get verifyTurnBiometricPayment => '生体認証での支払いをオンにするため認証します';

  @override
  String p0PaymentsTurned(Object p0) => '${p0} での支払いをオンにしました';

  @override
  String get securitySettingsUnavailableRightNowMay => 'セキュリティ設定を読み込めません';

  @override
  String payWithP0(Object p0) => '${p0} で支払う';

  @override
  String get accountWellProtected => 'アカウントはしっかり保護されています';

  @override
  String get accountCouldSafer => 'セキュリティを強化できます';

  @override
  String get setPaymentPinTurnBiometricPayment => '取引パスワードが未設定です';

  @override
  String tooManyAttemptsLockedUntilP0(Object p0) => '失敗回数が多すぎます。${p0} までロック中';

  @override
  String get notSetRequiredBeforeCheckout => '未設定';

  @override
  String get change => '変更';

  @override
  String get forgotPaymentPin => '取引パスワードを忘れた';

  @override
  String p0Devices(Object p0) => '${p0} 台';

  @override
  String get restoredUnfinishedListing => '前回の入力内容を復元しました';

  @override
  String get isbnSCheckDigitInvalidPlease => 'ISBN のチェックディジットが正しくありません。もう一度確認してください';

  @override
  String get draftSavedAutomatically => '下書きを自動保存しました';

  @override
  String get continueUnfinishedListing => '前回の出品を続ける';

  @override
  String clearedP0MbCache(Object p0) => '${p0} MB のキャッシュを削除しました';

  @override
  String get cacheCleared => 'キャッシュを削除しました';

  @override
  String get storage => 'ストレージ';

  @override
  String get clearCache => 'キャッシュを削除';

  @override
  String get couldNotLoadNotificationSettings => '通知設定を読み込めません';

  @override
  String get month => '今月';

  @override
  String p0P1(Object p0, Object p1) => '${p0}年${p1}月';

  @override
  String get noIncomeYet => '収入の記録はありません';

  @override
  String get noSpendingYet => '支出の記録はありません';

  @override
  String get income => '収入';

  @override
  String get spending => '支出';

  @override
  String get totalIncome => '累計収入';

  @override
  String get totalSpending => '累計支出';

  @override
  String get item3 => '項目';

  @override
  String get details => '説明';

  @override
  String get balanceAfter => '取引後残高';

  @override
  String get transactionId => '取引番号';

  @override
  String get sessionExpiredPleaseSignAgain => 'ログインの有効期限が切れました。もう一度ログインしてください';

  @override
  String get serviceTemporarilyUnavailableTryAgainLater => 'サービスは一時的に利用できません。しばらくしてからお試しください';

  @override
  String get uploadFailedTryAgainLater => 'アップロードに失敗しました。しばらくしてからお試しください';

  @override
  String get nearby => '付近';

  @override
  String p0M(Object p0) => '${p0} m';

  @override
  String p0Km(Object p0) => '${p0} km';

  @override
  String get iphoneDidnTReceiveApnsToken => 'iPhone が APNs トークンを取得できませんでした。Xcode の Signing & Capabilities に Push Notifications が追加されているか確認し、同じ Apple デベロッパーアカウントでアプリを再インストールしてください。';

  @override
  String get firebaseDidnTIssuePushToken => 'Firebase がプッシュトークンを発行しませんでした。GoogleService-Info.plist とアプリの Bundle ID が一致しているか確認してください';

  @override
  String couldnTGetPushTokenP0(Object p0) => 'プッシュトークンを取得できませんでした：${p0}';

  @override
  String couldnTRegisterPushTokenWith(Object p0) => 'プッシュトークンをサーバーに登録できませんでした：${p0}';

  @override
  String get protectCoinsCheckoutRequires6Digit => '決済の前に 6 桁の取引パスワードを設定してください。';

  @override
  String confirmPaymentP0Coins(Object p0) => '${p0} コインの支払いを確認';

  @override
  String get enterPasswordContinue => '続けるにはログインパスワードを入力してください';

  @override
  String get verifyS => '本人確認';

  @override
  String get amount => '支払い金額';

  @override
  String p0Coins(Object p0) => '${p0} コイン';

  @override
  String get enterPaymentPin => '取引パスワードを入力';

  @override
  String get enterPaymentPinContinue => '続けるには取引パスワードを入力してください';

  @override
  String get paymentPinResetEnterAgain => '取引パスワードを再設定しました。もう一度入力してください';

  @override
  String get usePasswordInstead => 'ログインパスワードを使う';

  @override
  String get couldnTGetLocationLockersShown => '現在地を取得できません';

  @override
  String p0SlotsFree(Object p0) => '空き ${p0} 区画';

  @override
  String openP0(Object p0) => '営業 ${p0}';

  @override
  String get nearest => '最寄り';

  @override
  String get noFreeSlots => '空きがありません';

  @override
  String get turnLocationSortByDistance => '位置情報をオンにすると距離順に並びます';

  @override
  String get lockerNoFreeSlotsRightNow => 'このロッカーは現在空きがありません';

  @override
  String get turn => 'オンにする';

  @override
  String get noLockersAvailable => '利用できるロッカーがありません';

  @override
  String get noMatchingOptions => '一致する項目がありません';

  @override
  String get undo2 => '元に戻す';

  @override
  String copiedP0(Object p0) => '「${p0}」をコピーしました';

  @override
  String get typing => '入力中…';

  @override
  String get today => '今日';

  @override
  String get yesterday => '昨日';

  @override
  String p0P12(Object p0, Object p1) => '${p0}月${p1}日';

  @override
  String p1P2P0(Object p0, Object p1, Object p2) => '${p0}年${p1}月${p2}日';

  @override
  String get releaseCancel => '指を離すとキャンセル';

  @override
  String get awaitingReply => '返信待ち';

  @override
  String heldUntilP0(Object p0) => '${p0}まで取り置き';

  @override
  String get declined2 => 'お断り済み';

  @override
  String get closed => '終了';

  @override
  String get theyWantReserveBook => 'あなたの本に予約リクエストが届いています';

  @override
  String get sentReservationRequest => '予約リクエストを送信しました';

  @override
  String holdP0H(Object p0) => '${p0}時間取り置き';

  @override
  String get holdPeriod => '取り置き期間';

  @override
  String get messageSellerOptional => '出品者へのメッセージ（任意）';

  @override
  String get sendRequest => '予約を送信';

  @override
  String p0Hours(Object p0) => '${p0}時間';

  @override
  String p0P1DigitsEntered(Object p0, Object p1) => '入力済み ${p0} / ${p1} 桁';

  @override
  String get buildSProvisioningProfileDoesnT => 'このビルドのプロビジョニングプロファイルにプッシュ通知の権限がありません。Xcode の Runner › Signing & Capabilities に Push Notifications があるか確認し、アプリを削除して再インストールしてください。';

  @override
  String get checkPhoneOnlinePushNotificationsAdded => '端末がネットワークに接続されていること、Xcode の Runner › Signing & Capabilities に Push Notifications があることを確認してください。';

  @override
  String iphoneFailedRegisterPushNotificationsWith(Object p0, Object p1) => 'iPhone の Apple へのプッシュ通知登録に失敗しました：${p0}\n${p1}';

  @override
  String get serverNotBeenUpdatedSupportFeature => 'この機能は一時的に利用できません。しばらくしてからお試しください。';

  @override
  String get someFeaturesTemporarilyUnavailableWhileServer => '一部の機能は一時的に利用できません';

  @override
  String serverRunningOutdatedApiRevisionP0(Object p0, Object p1) => 'サーバーの API バージョンが古すぎます（現在 ${p0}、アプリには ${p1} が必要）。サーバーのコードを更新し、API を再起動してください。';

  @override
  String databaseMigrationsNotYetRunP0(Object p0) => '未実行のデータベース移行：${p0}';

  @override
  String serverVersionP0(Object p0) => 'サーバーの現在のバージョン：${p0}';

  @override
  String get runNpmRunVerifyApiDirectory => 'サーバーの API ディレクトリで npm run verify を実行すると、デプロイ状況をすべて確認できます。';

  @override
  String get serverUpdateRequired => 'サーバーの更新が必要です';

  @override
  String versionP0(Object p0) => 'バージョン ${p0}';

  @override
  String get requiresUserConsent => 'ユーザーの同意が必要';

  @override
  String get unsavedDraft => '未保存の下書きあり';

  @override
  String get allBooks => 'すべての本';

  @override
  String get results => '絞り込み結果';

  @override
  String get sortBy => '並べ替え';

  @override
  String get themeColour => 'テーマカラー';

  @override
  String get forestGreen => 'フォレストグリーン';

  @override
  String get oceanBlue => 'オーシャンブルー';

  @override
  String get lavender => 'ラベンダー';

  @override
  String get terracotta => 'テラコッタ';

  @override
  String get amber => 'アンバー';

  @override
  String get rose => 'ローズ';

  @override
  String get graphite => 'グラファイト';

  @override
  String get mistBlue => 'ミストブルー';

  @override
  String get draftRestored => '下書きを復元しました';

  @override
  String get convertSections => '章モードに変換';

  @override
  String get currentContentDoesNotFullyMatch => '現在の内容は章の書式に完全には対応していません。変換すると章番号が順番に振り直され「1. タイトル」形式に統一されます。見出しとして認識されない段落は前文または直前の章の本文に統合されます。\n\n元の書式を保持する場合は、テキストモードで編集・保存してください。';

  @override
  String get convert => '変換';

  @override
  String get keepPlainText => 'テキストのまま';

  @override
  String get noSectionHeadingsDetectedFullText => '章見出しが検出されなかったため、全文を前文に配置しました';

  @override
  String deletedP0(Object p0) => '「${p0}」を削除しました';

  @override
  String get renameSection => '章の名前を変更';

  @override
  String get editContent => '内容を編集';

  @override
  String get rename => '名前を変更';

  @override
  String get addSectionBelow => '下に章を追加';

  @override
  String get moveUp => '上へ移動';

  @override
  String get moveDown => '下へ移動';

  @override
  String get enterDocumentTitle => '文書のタイトルを入力してください';

  @override
  String get enterDocumentContent => '文書の内容を入力してください';

  @override
  String p0NowVersionP1(Object p0, Object p1) => '${p0}（現在はバージョン ${p1}）';

  @override
  String versionP0P1(Object p0, Object p1) => 'バージョン ${p0}・${p1}';

  @override
  String unsavedDraftFromP0Found(Object p0) => '${p0} の未保存の下書きがあります';

  @override
  String get documentWasUpdatedAfterDraftWas => '下書きの作成後に文書が更新されています。復元すると現在の内容が下書きで置き換えられます。';

  @override
  String get discardDraft => '下書きを破棄';

  @override
  String get restoreDraft => '下書きを復元';

  @override
  String get sectionTitleRequired => '章タイトル未入力';

  @override
  String get documentSFormatDoesNotFully => 'この文書の書式は章構成に完全には対応していないため、元の書式を保持するためにテキストモードで開きました。';

  @override
  String get enterPasteFullTextHere => 'ここに全文を入力または貼り付けてください。';

  @override
  String get noSectionHeadingsDetected => '章見出しが検出されません';

  @override
  String p0SectionsDetected(Object p0) => '${p0} 件の章を検出しました';

  @override
  String get paragraphWhoseFirstLine1Title => '段落の1行目が「1. タイトル」「一、タイトル」「第一條 タイトル」の場合、章見出しとして扱います。';

  @override
  String get sectionNumbersMustStart1Increase => '章番号は 1 から順に増える必要があります。そうでない場合は直前の章の本文として扱います。';

  @override
  String get blankLineStartsNewParagraphSingle => '空行で段落を区切ります。1行の改行はそのまま表示されます。';

  @override
  String get whenSwitchingSectionsAskedConfirmAny => '章モードに切り替える際、書式の調整が必要な場合は事前に確認します。';

  @override
  String get howSectionHeadingsDetected => '章見出しの判定方法';

  @override
  String get titleEdited => 'タイトルを変更';

  @override
  String p0Added(Object p0) => '${p0} 章を追加';

  @override
  String p0Removed(Object p0) => '${p0} 章を削除';

  @override
  String p0Edited(Object p0) => '${p0} 章を変更';

  @override
  String get sectionsReordered => '章の順序を変更';

  @override
  String get preambleEdited => '前文を変更';

  @override
  String get contentEdited => '内容を変更';

  @override
  String p0Characters2(Object p0) => '文字数 +${p0}';

  @override
  String p0Characters3(Object p0) => '文字数 ${p0}';

  @override
  String get formattingAdjusted => '書式の調整';

  @override
  String get createdAsVersion1 => 'バージョン 1 として作成';

  @override
  String staysVersionP0(Object p0) => 'バージョン ${p0} のまま';

  @override
  String versionP0P12(Object p0, Object p1) => 'バージョン ${p0} → ${p1}';

  @override
  String get substantiveChangesRightsObligationsTermsAll => '権利義務や規約内容の実質的な変更向け。すべてのユーザーに通知し、次回アプリ起動時に再度確認・同意していただきます。';

  @override
  String get substantiveContentChangesAllUsersNotified => '内容の実質的な変更向け。すべてのユーザーに通知します。';

  @override
  String saveP0(Object p0) => '「${p0}」を保存';

  @override
  String get summaryChanges => '変更の概要';

  @override
  String get updateType => '更新の種類';

  @override
  String get fixingTyposFormattingUsersNotNotified => '誤字の修正や書式の調整向け。ユーザーには通知しません。';

  @override
  String get contentUnchangedTitleOnlyChangeCannot => '内容に変更がありません。タイトルのみの変更は重要な更新にできません。';

  @override
  String get notificationsSentImmediatelyAfterSubmittingCannot => '送信後すぐに通知が送られます。この操作は取り消せません。';

  @override
  String get publishNotify => '公開して通知';

  @override
  String sectionP0(Object p0) => '第 ${p0} 章';

  @override
  String get goSection => '章へ移動';

  @override
  String get sectionContent => '章の内容';

  @override
  String get previous => '前の章';

  @override
  String get next2 => '次の章';

  @override
  String get unableGenerateProfileQrCodeTry => 'プロフィール QR コードを生成できません。しばらくしてからお試しください。';

  @override
  String get myQrCode => 'マイ QR コード';

  @override
  String get markAsRead => '既読にする';

  @override
  String get unblock => 'ブロックを解除';

  @override
  String afterUnblockingP0CanSendMessages(Object p0) => 'ブロックを解除すると、「${p0}」と再びメッセージをやり取りできます。';

  @override
  String get userUnblocked => 'ブロックを解除しました';

  @override
  String get unableLoadBlockedUsers => 'ブロックリストを読み込めません';

  @override
  String get notBlockedAnyUsers => 'ブロック中のユーザーはいません';

  @override
  String get blockedUsers => 'ブロックリスト';

  @override
  String get blockUser => 'ユーザーをブロック';

  @override
  String afterBlockP0NeitherCanSend(Object p0) => '「${p0}」をブロックすると、お互いにメッセージを送信できなくなります。';

  @override
  String get block => 'ブロック';

  @override
  String get userBlocked => 'ユーザーをブロックしました';

  @override
  String get moreOptions => 'その他のオプション';

  @override
  String get blockedUser => 'このユーザーをブロックしています';

  @override
  String get originalMessageNotFound => '元のメッセージが見つかりません';

  @override
  String get you2 => 'あなた';

  @override
  String get viewProfile => 'プロフィールを表示';

  @override
  String get reply => '返信';

  @override
  String get bookLockerScanQrCodeLocker => '本はロッカーに預けられました。ロッカー本体の QR コードを読み取って受け取ってください。';

  @override
  String get originalMessageUnavailable => '元のメッセージは表示できません';

  @override
  String get cancelReply => '返信をキャンセル';

  @override
  String get unreadMessages => 'ここから未読メッセージ';

  @override
  String get selectChat => 'チャットを選択してください';

  @override
  String get appPermissions => 'アプリの権限';

  @override
  String get noPermissionsRequiredDevice => 'このデバイスで許可が必要な項目はありません';

  @override
  String get allowAll => 'すべて許可';

  @override
  String get camera => 'カメラ';

  @override
  String get photosRead => '写真（読み取り）';

  @override
  String get photosSave => '写真（保存）';

  @override
  String get microphone => 'マイク';

  @override
  String get location => '位置情報';

  @override
  String get orderUpdatesChatMessagesAnnouncements => '注文の進捗、チャットメッセージ、お知らせ';

  @override
  String get scanBarcodesTakeBookPhotos => 'バーコードの読み取りと本の写真撮影';

  @override
  String get chooseBookPhotosProfilePicturesChat => '本の写真、プロフィール画像、チャット画像の選択';

  @override
  String get saveQrCodesPhotos => 'QR コードを写真に保存';

  @override
  String get recordVoiceMessagesChats => 'チャットのボイスメッセージを録音';

  @override
  String get showNearestSmartLockersTheirDistance => '最寄りのスマートロッカーと距離を表示';

  @override
  String get quickSignPaymentConfirmation => 'すばやいサインインと支払いの確認';

  @override
  String get allowed => '許可済み';

  @override
  String get limited => '一部許可';

  @override
  String get notAllowed => '未許可';

  @override
  String get restricted => 'システムにより制限';

  @override
  String get denied => '拒否済み';

  @override
  String get allow => '許可';

  @override
  String get homeRecommendations => 'ホームのおすすめ';

  @override
  String get leaveGroup => 'グループを退会';

  @override
  String leaveP0(Object p0) => '「${p0}」を退会しますか？';

  @override
  String get leave => '退会';

  @override
  String get leftGroup => 'グループを退会しました';

  @override
  String get unpin => 'ピン留めを解除';

  @override
  String get pin => 'ピン留め';

  @override
  String get you3 => 'あなた';

  @override
  String get canOnlyEditMessagesSentWithin => '編集できるのは送信から 15 分以内のメッセージのみです';

  @override
  String p0UnsentMessage(Object p0) => '${p0} がメッセージの送信を取り消しました';

  @override
  String readByP0(Object p0) => '既読 ${p0}';

  @override
  String get transferDetailsUnavailable => '送金情報を表示できません';

  @override
  String get couldNotCreateGroup => 'グループを作成できませんでした';

  @override
  String get groupDetails => 'グループ情報';

  @override
  String get selectMembers => 'メンバーを選択';

  @override
  String get groupName => 'グループ名';

  @override
  String membersP0(Object p0) => 'メンバー ${p0}';

  @override
  String get createGroup => 'グループを作成';

  @override
  String get inviteMembers => 'メンバーを招待';

  @override
  String get invite => '招待';

  @override
  String canSelectUpP0People(Object p0) => '最大 ${p0} 人まで選択できます';

  @override
  String get noChatsChooseFrom => '選択できるトーク相手がいません';

  @override
  String get noMatchingPeople => '該当する相手がいません';

  @override
  String get searchByName => '名前で検索';

  @override
  String get chatPinned => 'トークをピン留めしました';

  @override
  String get unpinned => 'ピン留めを解除しました';

  @override
  String get setNickname => 'ニックネームを設定';

  @override
  String get onlyVisible => '自分にのみ表示';

  @override
  String get nicknameRemoved => 'ニックネームを削除しました';

  @override
  String get nicknameUpdated => 'ニックネームを更新しました';

  @override
  String get enterGroupName => 'グループ名を入力してください';

  @override
  String get groupNameUpdated => 'グループ名を更新しました';

  @override
  String get groupPhotoUpdated => 'グループ画像を更新しました';

  @override
  String get groupReachedMemberLimit => 'グループのメンバー数が上限に達しています';

  @override
  String invitedP0Members(Object p0) => '${p0} 人を招待しました';

  @override
  String get removeMember => 'メンバーを削除';

  @override
  String removeP0FromGroup(Object p0) => '「${p0}」をグループから削除しますか？';

  @override
  String get memberRemoved => 'メンバーを削除しました';

  @override
  String get chatSettings => 'トーク設定';

  @override
  String get muteNotifications => '通知をミュート';

  @override
  String get pinChat => 'トークをピン留め';

  @override
  String get me => '自分';

  @override
  String requestedFromP0(Object p0) => '${p0} に請求';

  @override
  String p0RequestedPaymentFrom(Object p0) => '${p0} からの請求';

  @override
  String p0RequestedPaymentFromP1(Object p0, Object p1) => '${p0} が ${p1} に請求';

  @override
  String sentP0(Object p0) => '${p0} に送金';

  @override
  String p0SentCoins(Object p0) => '${p0} からの送金';

  @override
  String p0SentCoinsP1(Object p0, Object p1) => '${p0} が ${p1} に送金';

  @override
  String get expired2 => '期限切れ';

  @override
  String get payNow => '今すぐ支払う';

  @override
  String get cancelRequest => '請求を取り消す';

  @override
  String get request => '請求';

  @override
  String get transfer => '送金';

  @override
  String dueP0(Object p0) => '期限 ${p0}';

  @override
  String transferP0(Object p0) => '${p0} に送金';

  @override
  String sentP0CoinsP1(Object p0, Object p1) => '${p0} に ${p1} コインを送金しました';

  @override
  String get confirmPayment => '支払いの確認';

  @override
  String payP0CoinsP1(Object p0, Object p1) => '${p0} に ${p1} コインを支払います';

  @override
  String get declineRequest => '請求をお断り';

  @override
  String declineP1CoinRequestFromP0(Object p0, Object p1) => '${p0} からの ${p1} コインの請求をお断りします';

  @override
  String cancelRequestP0P1Coins(Object p0, Object p1) => '${p0} への ${p1} コインの請求を取り消します';

  @override
  String payRequestFromP0(Object p0) => '${p0} からの請求を支払う';

  @override
  String get paymentCompleted => '支払いが完了しました';

  @override
  String get requestDeclined => '請求をお断りしました';

  @override
  String get requestCanceled => '請求を取り消しました';

  @override
  String get selectPayer => '支払う人を選択してください';

  @override
  String get selectRecipient => '受取人を選択してください';

  @override
  String get sendRequest2 => '請求を送信';

  @override
  String get confirmTransfer => '送金を確定';

  @override
  String get payer => '支払う人';

  @override
  String get recipient => '受取人';

  @override
  String limitPerTransferP0Coins(Object p0) => '1回の上限 ${p0} コイン';

  @override
  String insufficientBalanceP0Coins(Object p0) => '残高不足（${p0} コイン）';

  @override
  String balanceP0Coins(Object p0) => '残高 ${p0} コイン';

  @override
  String get noteOptional => 'メモ（任意）';

  @override
  String get editMessage => 'メッセージを編集';

  @override
  String get cancelEditing => '編集をキャンセル';

  @override
  String get send => '送信';

  @override
  String get switchKeyboard => 'キーボードに切り替え';

  @override
  String get voiceMessage => 'ボイスメッセージ';

  @override
  String get edited => '編集済み';

  @override
  String get maximumRecordingLengthReached => '録音時間の上限に達しました';

  @override
  String get recordingTooShort => '録音時間が短すぎます';

  @override
  String p0SRemaining(Object p0) => '残り ${p0} 秒';

  @override
  String get releaseSend => '指を離すと送信します';

  @override
  String get recording => '録音中';

  @override
  String get tapHoldRecord => 'タップまたは長押しで録音';

  @override
  String get stopRecording => '録音を停止';

  @override
  String get preview2 => '試聴';

  @override
  String get startRecording => '録音を開始';

  @override
  String get microphoneUnavailable => 'マイクを使用できません';

  @override
  String get paymentRequest => '[請求]';

  @override
  String get transfer2 => '[送金]';

  @override
  String get transfer3 => '受け取り';

  @override
  String get transferOut => '送金';

  @override
  String get deleteBook => '書籍を削除';

  @override
  String p0PermanentlyDeletedCannotRestoredSeller(Object p0) => '「${p0}」は完全に削除され、元に戻せません。出品者に通知されます。';

  @override
  String get reasonDeletionOptional => '削除理由（任意）';

  @override
  String get bookDeleted2 => '書籍を削除しました';

  @override
  String get rotate => '回転';

  @override
  String get mentioned => '[メンション]';

  @override
  String get saveImage => '画像を保存';

  @override
  String get everyone => '全員';

  @override
  String get mentionMembers => 'メンバーをメンション';

  @override
  String get removeAdminRole => '管理者権限を解除';

  @override
  String makeP0Admin(Object p0) => '${p0} を管理者にしますか？';

  @override
  String removeAdminRoleFromP0(Object p0) => '${p0} の管理者権限を解除しますか？';

  @override
  String get remove2 => '解除';

  @override
  String p0NowAdmin(Object p0) => '${p0} を管理者にしました';

  @override
  String removedAdminRoleFromP0(Object p0) => '${p0} の管理者権限を解除しました';

  @override
  String photosP02(Object p0) => '[写真 ${p0} 枚]';

  @override
  String get savedDownloads => '「ダウンロード」に保存しました';

  @override
  String get couldNotSaveImage => '画像を保存できませんでした';

  @override
  String savingImagesP0P1(Object p0, Object p1) => '画像を保存中 ${p0} / ${p1}';

  @override
  String get savingImage => '画像を保存中';

  @override
  String get passwordsCanOnlyContainEnglishLetters => 'パスワードには英字、数字、半角記号のみ使用できます';

  @override
  String get aiSupport => 'AI サポート';

  @override
  String get howDoIListBook => '本を出品するには？';

  @override
  String get howDoIPickUpFrom => 'ロッカーで本を受け取るには？';

  @override
  String get howDoIRequestRefund => '返金を申請するには？';

  @override
  String get howDoWalletCoinsWork => 'コインの使い方は？';

  @override
  String get talkPerson => 'サポート担当者に接続';

  @override
  String get supportRequestCreatedFromConversationOur => 'サポート担当者に接続し、現在の会話内容を共有します';

  @override
  String get transfer4 => '切り替える';

  @override
  String get creatingSupportRequest => 'サポートに接続しています';

  @override
  String get transferredSupportTeam => 'サポート担当者に接続しました';

  @override
  String get newConversation => '新しい会話';

  @override
  String get currentConversationEnd => '現在の会話は終了します';

  @override
  String get copied2 => 'コピーしました';

  @override
  String get howCanWeHelp => 'どのようなご用件でしょうか？';

  @override
  String get failedSend => '送信できませんでした';

  @override
  String get ourSupportTeamCanHelpWith => 'この件は担当者による対応をおすすめします';

  @override
  String get contactSupport => 'サポートに連絡';

  @override
  String get typeQuestion => '質問を入力';

  @override
  String get aiFeatures => 'AI 機能';

  @override
  String get aiSettingsNotSavedChangesLost => 'AI 設定が保存されていません。移動すると変更は失われます';

  @override
  String get usage => '利用状況';

  @override
  String reviewP0(Object p0) => '審査 ${p0}';

  @override
  String get dailyCost => '日別の費用';

  @override
  String get noCostPeriod => 'この期間の費用はありません';

  @override
  String get peakDay => '1 日の最高';

  @override
  String p0Requests(Object p0) => 'リクエスト ${p0} 件';

  @override
  String get listingAssist => '出品アシスト';

  @override
  String get recommendations => 'おすすめ';

  @override
  String get listingReview => '出品審査';

  @override
  String get connectionTest => '接続テスト';

  @override
  String get today2 => '今日';

  @override
  String get k7Days => '7 日間';

  @override
  String get k30Days => '30 日間';

  @override
  String get notBookUnrelatedItem => '書籍以外・無関係な商品';

  @override
  String get prohibitedPiratedContent => '禁止・海賊版コンテンツ';

  @override
  String get adultContent => '成人向けコンテンツ';

  @override
  String get offPlatformDealContactInfo => '外部取引・連絡先の記載';

  @override
  String get misleadingDescription => '不正確な説明';

  @override
  String get unusualPrice => '価格が異常';

  @override
  String get providerError => 'プロバイダーエラー';

  @override
  String get timedOut => 'タイムアウト';

  @override
  String get noApiKey => 'API キー未設定';

  @override
  String get rateLimited => 'レート制限';

  @override
  String get invalidApiKey => 'API キーが無効';

  @override
  String get invalidResponseFormat => '応答形式エラー';

  @override
  String get rejectListing => '出品を却下';

  @override
  String get noteOptionalSentSeller => 'メモ（任意・出品者に通知されます）';

  @override
  String get reject => '却下';

  @override
  String get listingApproved => '出品を承認しました';

  @override
  String get listingRejected => '出品を却下しました';

  @override
  String get noListingsAwaitingReview => '審査待ちの出品はありません';

  @override
  String get likelyViolation => '違反の疑い';

  @override
  String get needsReview => '要確認';

  @override
  String get rejected => '却下済み';

  @override
  String get approve => '承認';

  @override
  String get pleaseFixHighlightedFields => 'エラーのある項目を修正してください';

  @override
  String get aiSettingsSaved => 'AI 設定を保存しました';

  @override
  String get invalidFormat => '形式が正しくありません';

  @override
  String enter0P0(Object p0) => '0〜${p0} を入力してください';

  @override
  String get databaseNotBeenUpdatedAiYet => 'データベースの AI 用アップデートが未完了のため、保存した設定はまだ反映されません';

  @override
  String get defaultModel => 'デフォルトモデル';

  @override
  String get features => '機能';

  @override
  String get on => 'オン';

  @override
  String get noProviderApiKeysSetSo => 'プロバイダーの API キーが設定されていないため、AI 機能は使えません';

  @override
  String p0NoApiKeyCannotSelected(Object p0) => '${p0} は API キーが未設定のため選択できません';

  @override
  String get input => '入力';

  @override
  String get output => '出力';

  @override
  String get per1mTokens => '100 万トークンあたり';

  @override
  String get vision => '画像認識';

  @override
  String get webSearch => 'ウェブ検索';

  @override
  String get testing => 'テスト中';

  @override
  String get test => '接続テスト';

  @override
  String connectedP0Ms(Object p0) => '接続成功・${p0} ms';

  @override
  String get connectionFailed => '接続に失敗しました';

  @override
  String get keySet => 'キー設定済み';

  @override
  String get noKey => 'キー未設定';

  @override
  String get model => '使用モデル';

  @override
  String defaultP0(Object p0) => 'デフォルト（${p0}）';

  @override
  String p0NoApiKey(Object p0) => '${p0} は API キーが未設定です';

  @override
  String p0DoesNotSupportWebSearch(Object p0) => '${p0} はウェブ検索に対応していません';

  @override
  String get searchNotBilledSeparately => '検索は別途課金されません';

  @override
  String firstP0SearchesFreeEachMonth(Object p0, Object p1) => '毎月 ${p0} 回まで無料、以降 1,000 回ごとに ${p1}';

  @override
  String p0Per1000SearchesPlus(Object p0) => '1,000 回ごとに ${p0}、検索内容のトークンは別途';

  @override
  String get suspiciousListings => '疑わしい出品の扱い';

  @override
  String get holdReview => '審査に回す';

  @override
  String get rejectClearViolations => '明らかな違反は却下';

  @override
  String get budgetLimits => '予算と上限';

  @override
  String get monthlyBudgetUsd => '月間予算（USD）';

  @override
  String get k0MeansNoCap => '0 は上限なし';

  @override
  String get dailyLimitPerMember => '会員ごとの 1 日の上限回数';

  @override
  String get k0MeansUnlimited => '0 は無制限';

  @override
  String get advanced => '詳細設定';

  @override
  String get resetDefault => 'デフォルトに戻す';

  @override
  String get modelId => 'モデル ID';

  @override
  String get priceUsPer1mTokens => '単価（US\$ / 100 万トークン）';

  @override
  String get cachedInput => 'キャッシュ入力';

  @override
  String get searchPriceUsPer1000 => '検索単価（US\$ / 1,000 回）';

  @override
  String get freeSearchesPerMonth => '毎月の無料検索回数';

  @override
  String p0FieldsInvalid(Object p0) => '${p0} 件の項目にエラーがあります';

  @override
  String p0UnsavedChanges(Object p0) => '未保存の変更が ${p0} 件あります';

  @override
  String get unsavedChanges => '未保存の変更があります';

  @override
  String get month2 => '今月の費用';

  @override
  String budgetP0(Object p0) => '予算 ${p0}';

  @override
  String get noMonthlyBudget => '月間予算未設定';

  @override
  String projectedP0(Object p0) => '月末予測 ${p0}';

  @override
  String get periodCost => '期間の費用';

  @override
  String get requests => 'リクエスト数';

  @override
  String p0Searches(Object p0) => '検索 ${p0} 回';

  @override
  String p0OutP1(Object p0, Object p1) => '入力 ${p0}・出力 ${p1}';

  @override
  String get errors => 'エラー';

  @override
  String errorRateP0(Object p0) => 'エラー率 ${p0}%';

  @override
  String p0ListingsAwaitingReview(Object p0) => '審査待ちの出品 ${p0} 件';

  @override
  String get byFeature => '機能別';

  @override
  String get noDataYet => 'データがありません';

  @override
  String errorsP0(Object p0) => 'エラー ${p0}';

  @override
  String p0Calls(Object p0) => '${p0} 回';

  @override
  String get byModel => 'モデル別';

  @override
  String p0CallsP1Ms(Object p0, Object p1) => '${p0} 回・${p1} ms';

  @override
  String get topMembers => '利用の多い会員';

  @override
  String p0Uses(Object p0) => '${p0} 回利用';

  @override
  String get recentErrors => '最近のエラー';

  @override
  String get noErrors => 'エラーはありません';

  @override
  String get fillWithAi => 'AI で入力';

  @override
  String get summary => '内容紹介';

  @override
  String get lookingUpBookDetails => '書籍情報を検索';

  @override
  String get searchingWeb => 'ウェブで補足情報を検索';

  @override
  String get analyzingPhotos => '写真を分析';

  @override
  String get suggestingCategoryConditionPrice => 'カテゴリ・状態・価格を判定';

  @override
  String get couldNotGetAiSuggestions => 'AI の提案を取得できませんでした';

  @override
  String get done => '分析完了';

  @override
  String get aiAnalyzing => 'AI が分析中';

  @override
  String get aiSuggestions => 'AI の提案';

  @override
  String get noSuggestionsApply => '反映できる提案はありません';

  @override
  String get bookDetails => '書籍情報';

  @override
  String get suggestedPrice => '推奨価格';

  @override
  String rangeP0P1(Object p0, Object p1) => '推奨範囲 \$${p0}〜\$${p1}';

  @override
  String listPriceP0(Object p0) => '定価 \$${p0}';

  @override
  String applyP0(Object p0) => '${p0} 件を反映';

  @override
  String currentP0(Object p0) => '現在：${p0}';

  @override
  String get sameAsCurrent => '現在と同じ';

  @override
  String get listingNotApproved => '出品審査に通りませんでした';

  @override
  String get editListing => '内容を修正';

  @override
  String get submittedReview => '審査に回しました';

  @override
  String get goSaleOnceApprovedNotifiedResult => '承認後に販売が開始されます';

  @override
  String get got => 'OK';

  @override
  String get aiFeaturesNotAvailableRightNow => 'AI 機能は現在ご利用いただけません';

  @override
  String get bookUnderReviewGoSaleOnce => 'この書籍は審査中です。承認されると販売が開始されます';

  @override
  String get notApproved => '審査不合格';

  @override
  String get bookDidNotPassListingReview => 'この書籍は出品審査に通りませんでした';

  @override
  String get enterIsbnTitleFirst => '先に ISBN または書名を入力してください';

  @override
  String appliedP0AiSuggestions(Object p0) => 'AI の提案を ${p0} 件反映しました';

  @override
  String get addBookPhotosFirst => '先に書籍の写真を追加してください';

  @override
  String get nothingFoundFillCheckIsbnTitle => '反映できる情報が見つかりません。ISBN または書名を確認してください';

  @override
  String appliedP0AiSuggestions2(Object p0) => 'AI の提案を ${p0} 件反映しました';

  @override
  String get aiDataProcessingEnabled => 'AI によるデータ処理に同意しました';

  @override
  String get aiDataProcessingTurnedOff => 'AI によるデータ処理を停止しました';

  @override
  String get aiDataProcessing => 'AI によるデータ処理';

  @override
  String get messagesEnterStatusOrdersReservations => '入力したメッセージ、ご自身の注文と予約の状況';

  @override
  String get isbnTitleConditionNotesPhotosSelect => 'ISBN、書名、状態の説明、選択した写真';

  @override
  String get bookDetailsFromFavoritesPurchaseHistory => 'お気に入りと購入履歴に含まれる書籍情報';

  @override
  String get aiDataProcessing2 => 'AI によるデータ処理について';

  @override
  String get whenUseAiFeaturesWeShare => 'AI 機能をご利用の際、以下のデータを第三者の AI サービス事業者に提供して処理します。';

  @override
  String get dataShared => '提供するデータ';

  @override
  String get recipients => '提供先';

  @override
  String get purpose => '利用目的';

  @override
  String get usedOnlyGenerateSupportRepliesPrepare => 'サポートの回答、出品情報の整理、書籍のおすすめにのみ使用し、広告やトラッキングには使用しません。';

  @override
  String get withdrawingConsent => '同意の撤回';

  @override
  String get canTurnOffAiDataProcessing => '「設定 › アカウント設定」の「AI によるデータ処理」はいつでもオフにできます。オフにすると上記のデータは提供されなくなります。';

  @override
  String get agreeContinue => '同意する';

  @override
  String get insufficientQuotaPlanNotEnabled => 'クォータ不足またはプラン未有効';

  @override
  String get modelNotFound => 'モデル名が存在しません';

  @override
  String get invalidRequestParameters => 'リクエストパラメータが不正です';

  @override
  String get couldNotConnectService => 'サービスに接続できません';

  @override
  String get blockedByProviderSafetySystem => 'サービスの安全機能により拒否されました';

  @override
  String get responseExceededOutputLimit => '応答が出力上限を超えました';

  @override
  String get serverProcessingError => 'サーバー処理エラー';

  @override
  String get aiBookAdvisor => 'AI ブックアドバイザー';

  @override
  String get requiresDatabaseUpdate013 => 'データベース更新 013 が必要です';

  @override
  String get mysteryNovelMyCommute => '通勤中に読めるミステリー小説';

  @override
  String get programmingBooksBeginners => '入門者向けのプログラミング書';

  @override
  String get booksUnder200Coins => '200 コイン以内の本';

  @override
  String get popularLiteraryFictionRightNow => '最近人気の文芸小説';

  @override
  String get tellMeWhatBookLooking => 'お探しの本の内容を入力してください';

  @override
  String get describeBookLooking => 'お探しの本を入力してください';

  @override
  String get tellMeWhatWantReadI => 'ご希望に合わせて本をおすすめします';

  @override
  String get subtitle => 'サブタイトル';

  @override
  String get monthOnly => '月まで確認';

  @override
  String get yearOnly => '年まで確認';

  @override
  String get msg => '繁體中文';

  @override
  String get additionalInformation => 'その他の情報';

  @override
  String get readFull => '全文を表示';

  @override
  String get pages => 'ページ数';

  @override
  String get simplifiedChinese => '簡体字中国語';

  @override
  String get chinese => '中国語';

  @override
  String get english => '英語';

  @override
  String get japanese => '日本語';

  @override
  String get korean => '韓国語';

  @override
  String p0Pages(Object p0) => '${p0} ページ';

  @override
  String get collapse => '折りたたむ';

  @override
  String get setPasswordFirst => 'まずパスワードを設定してください';

  @override
  String get setPassword => 'パスワードを設定';

  @override
  String get signMethodSettingsSaved => 'ログイン方法の設定を保存しました';

  @override
  String get signMethodSettingsUnsavedLeavingDiscards => 'ログイン方法の設定は保存されていません。移動すると変更は失われます。';

  @override
  String get serverNotRunDatabaseUpdate014 => 'サーバーでデータベース更新 014 が未実行のため、設定はまだ反映されません。';

  @override
  String get signChannels => 'ログイン方法の一覧';

  @override
  String get socialSmsSign => 'ソーシャル・SMS ログイン';

  @override
  String get whenOffSignPageHidesThese => 'オフにするとログイン画面に表示されません。連携済みの利用者はパスワードでログインできます。';

  @override
  String get notConfigured => '未設定';

  @override
  String get allowCreatingNewAccountsWithMethod => 'この方法での新規登録を許可';

  @override
  String get unsavedChanges2 => '未保存の変更';

  @override
  String get taiwan => '中華民国（台湾）';

  @override
  String get hongKong => '香港';

  @override
  String get macau => 'マカオ';

  @override
  String get china => '中華人民共和国';

  @override
  String get japan => '日本';

  @override
  String get southKorea => '韓国';

  @override
  String get singapore => 'シンガポール';

  @override
  String get malaysia => 'マレーシア';

  @override
  String get unitedStatesCanada => 'アメリカ／カナダ';

  @override
  String get unitedKingdom => 'イギリス';

  @override
  String get australia => 'オーストラリア';

  @override
  String get countryCode => '国番号';

  @override
  String get enterValidMobileNumber => '正しい携帯電話番号を入力してください';

  @override
  String get couldNotSendCodePleaseTry => '認証コードを送信できませんでした。しばらくしてからお試しください。';

  @override
  String get linkMobileNumber => '携帯電話番号を連携';

  @override
  String get signWithMobileNumber => '携帯電話番号でログイン';

  @override
  String get k6DigitCodeSentNumberMessage => 'この番号に 6 桁の認証コードを送信します。';

  @override
  String get mobileNumber => '携帯電話番号';

  @override
  String get sendCode => '認証コードを送信';

  @override
  String get codeIncorrectPleaseEnterAgain => '認証コードが正しくありません。もう一度入力してください。';

  @override
  String get codeBeenSentAgain => '認証コードを再送しました';

  @override
  String get enterCode => '認証コードを入力';

  @override
  String get enterSmsCode => 'SMS の認証コードを入力';

  @override
  String codeWasSentP0(Object p0) => '認証コードを ${p0} に送信しました';

  @override
  String canResendP0S(Object p0) => '${p0} 秒後に再送できます';

  @override
  String get resendCode => '認証コードを再送';

  @override
  String get completeAccountDetails => 'アカウント情報の入力';

  @override
  String get p0DidNotProvideEmailAddress => '登録を完了するにはメールアドレスを入力してください。';

  @override
  String signWithP0(Object p0) => '${p0} でログイン';

  @override
  String get signWith2 => 'または次の方法でログイン';

  @override
  String get creatingAccountWithMethodsAboveMeans => '上記の方法でアカウントを作成すると、利用規約とプライバシーポリシーに同意したものとみなされます。';

  @override
  String get emailAlreadyRegistered => 'このメールアドレスは登録済みです';

  @override
  String get signWithPasswordThenLinkMethod => 'パスワードでログインし、「アカウントセキュリティ › ログイン方法」で連携してください。';

  @override
  String get signWithPassword => 'パスワードでログイン';

  @override
  String get accountNoPasswordYet => 'このアカウントはパスワード未設定です';

  @override
  String get passwordSet => 'パスワードを設定しました';

  @override
  String get canNowSignWithEmailPassword => '他の端末は再ログインが必要です。';

  @override
  String get passwordRequiredBeforeCanUnlinkSign => '8 文字以上で、英字と数字を含めてください。';

  @override
  String get changingSignMethodsRequiresIdentityVerification => 'ログイン方法を変更する前に、パスワードを設定してください。';

  @override
  String get later => '今は設定しない';

  @override
  String p0Linked(Object p0) => '${p0} を連携しました';

  @override
  String unlinkP0(Object p0) => '${p0} の連携を解除';

  @override
  String get noLongerAbleSignWayCan => '連携を解除すると、この方法ではログインできなくなります。';

  @override
  String get unlink => '連携を解除';

  @override
  String p0Unlinked(Object p0) => '${p0} の連携を解除しました';

  @override
  String get socialSmsSignNotAvailableRight => 'ソーシャル・SMS ログインは現在利用できません。';

  @override
  String get noSignMethodAvailableLink => '連携できるログイン方法はありません。';

  @override
  String get noPasswordSet => 'パスワード未設定';

  @override
  String linkedP0(Object p0) => '${p0} に連携';

  @override
  String get link => '連携';

  @override
  String get emailAlreadyRegisteredSignWithPassword => 'このメールアドレスは登録済みです。パスワードでログインしてから、アカウントセキュリティで連携してください。';

  @override
  String get provideEmailAddressCreateAccount => 'アカウント作成にはメールアドレスが必要です';

  @override
  String get signMethodOnlyExistingAccounts => 'このログイン方法は既存アカウント専用です';

  @override
  String get signMethodNotAvailableRightNow => 'このログイン方法は現在利用できません';

  @override
  String get credentialDoesNotMatchSelectedSign => 'ログインに失敗しました。もう一度お試しください。';

  @override
  String get signMethodLinkedAnotherAccount => 'このログイン方法は他のアカウントに連携されています';

  @override
  String get accountAlreadyLinkedSignMethod => 'このアカウントはすでにこのログイン方法と連携しています';

  @override
  String get onlySignMethodAccountSetPassword => 'これはこのアカウント唯一のログイン方法です。先にパスワードを設定するか、他の方法を連携してください。';

  @override
  String get socialSignUnavailableServerNotFinished => 'ソーシャルログインは一時的に利用できません。しばらくしてからお試しください。';

  @override
  String get credentialInvalidExpiredPleaseTryAgain => 'ログインがタイムアウトしました。もう一度お試しください。';

  @override
  String get accountAlreadyPasswordUseChangePassword => 'このアカウントはパスワード設定済みです。パスワードの変更をご利用ください。';

  @override
  String get signLinkExpiredPleaseTryAgain => 'ログインリンクの有効期限が切れました。もう一度お試しください。';

  @override
  String get signResultExpiredPleaseTryAgain => 'ログインがタイムアウトしました。もう一度お試しください。';

  @override
  String get thirdPartySignServiceUnavailablePlease => '外部のログインサービスが利用できません。しばらくしてからお試しください。';

  @override
  String get couldNotCompleteSignPleaseTry => 'ログインを完了できませんでした。もう一度お試しください。';

  @override
  String get accountNotLinkedSignMethod => 'このアカウントはこのログイン方法と連携していません';

  @override
  String get mobileNumberFormatNotValid => '携帯電話番号の形式が正しくありません';

  @override
  String get verificationTimedOutRequestNewCode => '認証がタイムアウトしました。認証コードを再取得してください。';

  @override
  String get codeExpiredRequestNewOne => '認証コードの有効期限が切れました。再取得してください。';

  @override
  String get tooManyAttemptsPleaseTryAgain => '試行回数が多すぎます。しばらくしてからお試しください。';

  @override
  String get smsSendingLimitBeenReachedPlease => 'SMS の送信回数が上限に達しました。しばらくしてからお試しください。';

  @override
  String get smsVerificationNotSetUpDevice => 'この端末では SMS 認証を利用できません。別のログイン方法をご利用ください。';

  @override
  String get couldNotCompleteSmsVerificationPlease => 'SMS 認証を完了できませんでした。しばらくしてからお試しください。';

  @override
  String get allowSigningLinkingWithMethod => 'この方法でのログインと連携を許可';

  @override
  String get appNeverStoresPasswordUsedOnly => 'このアプリはパスワードを保存しません。今回の認証にのみ使用します。';

  @override
  String get verifyWithBiometricsInstead => '生体認証で確認する';

  @override
  String get accountWasCreatedWithSocialPhone => 'このアカウントはログインパスワードが未設定です。先に設定してください。';

  @override
  String get setSignPassword => 'ログインパスワードを設定';

  @override
  String get enterSignPasswordRunAdminAction => 'この管理操作を実行するには、ログインパスワードまたはパスキーで本人確認を行ってください';

  @override
  String p1P0MethodsEnabled(Object p0, Object p1) => '全 ${p0} 種類のうち ${p1} 種類が有効';

  @override
  String get masterSwitchOffSoEveryMethod => '総合スイッチがオフのため、すべての方法が無効です';

  @override
  String get signLinkingDirectSignUpAllowed => 'ログイン・連携・新規登録が可能';

  @override
  String credentialsNotSetPleaseConfigureP0(Object p0) => '認証情報が未設定です。サーバーで ${p0} を設定してください';

  @override
  String get whenOffMethodHiddenFromSign => 'オフにするとログイン画面とアカウントセキュリティに表示されません';

  @override
  String get whenOffOnlyAccountsAlreadyLinked => 'オフにすると連携済みのアカウントのみ利用できます';

  @override
  String get signMethodNotLinkedAccount => 'このログイン方法はアカウントに連携されていません';

  @override
  String p0AccountNotLinkedAnySavemybook(Object p0) => 'この ${p0} アカウントは SaveMyBook アカウントと連携されていません。';

  @override
  String get iAlreadyAccountSignFirst => '既存のアカウントにログインして連携';

  @override
  String get createNewAccountWithIdentity => '新しいアカウントを作成';

  @override
  String signExistingAccountFirstThenLink(Object p0) => '先に既存のアカウントでログインし、「アカウントセキュリティ › ログイン方法」で ${p0} を連携してください。';

  @override
  String get signMethodNotLinkedAnyAccount => 'このログイン方法はどのアカウントとも連携されていません';

  @override
  String get verifyIdentityWithPasskeyContinue => '続行するにはパスキーで本人確認を行ってください';

  @override
  String get verifyWithPasskeyInstead => 'パスキーで確認する';

  @override
  String get passkeys => 'パスキー';

  @override
  String get verifyWithFaceIdFingerprintScreen => 'このデバイスの Face ID、指紋、画面ロックで確認します。パスワードは不要です。';

  @override
  String get verifyWithPasskey => 'パスキーで確認';

  @override
  String get useSignPasswordInstead => 'ログインパスワードで確認する';

  @override
  String get signWithPasskey => 'パスキーでログイン';

  @override
  String get passkeyAdded => 'パスキーを追加しました';

  @override
  String get screenLock => '画面ロック';

  @override
  String fromNowCanSignVerifyIdentity(Object p0) => '今後はパスワードを入力せずに、${p0} でログインと本人確認ができます。';

  @override
  String get deletePasskey => 'パスキーを削除';

  @override
  String get noLongerAbleSignVerifyIdentity => '削除すると、このパスキーでログインや本人確認ができなくなります。デバイスに保存されたパスキーは削除されないため、システムのパスワード設定から削除してください。';

  @override
  String get passkeyDeleted => 'パスキーを削除しました';

  @override
  String get signVerifyIdentityWithFaceId => 'パスワードの代わりに Face ID、指紋、画面ロックでログインと本人確認ができます。パスキーはお使いのデバイスとパスワード マネージャーにのみ保存されます。';

  @override
  String get addPasskey => 'パスキーを追加';

  @override
  String get notUsedYet => '未使用';

  @override
  String lastUsedFormatdateItemLastusedat(Object p0) => '最終使用 ${p0}';

  @override
  String createdCreated(Object p0) => '作成日 ${p0}';

  @override
  String get noPasskeyAvailableDeviceUsePassword => 'このデバイスで使用できるパスキーがありません。パスワードをご利用ください。';

  @override
  String get passkeyAlreadyRegisteredDevice => 'このデバイスには既にパスキーが登録されています。';

  @override
  String get signGoogleAccountTurnPasswordManager => 'このデバイスで Google アカウントにログインしてパスワード マネージャーを有効にするか、パスワードをご利用ください。';

  @override
  String get setUpScreenLockPasswordManager => 'パスキーを作成するには、このデバイスで画面ロックまたはパスワード マネージャーを設定してください。';

  @override
  String get deviceDoesNotSupportPasskeysUse => 'このデバイスはパスキーに対応していません。パスワードをご利用ください。';

  @override
  String get passkeysTemporarilyUnavailableBecauseAppWebsite => '現在パスキーは利用できません。パスワードをご利用ください。';

  @override
  String get requestTimedOutPleaseTryAgain => '操作がタイムアウトしました。もう一度お試しください。';

  @override
  String get passkeyRequestFailedUsePasswordInstead => 'パスキーの操作に失敗しました。パスワードをご利用ください。';

  @override
  String get verifyIdentityBeforeAddingPasskey => 'パスキーを追加する前に本人確認を行ってください';

  @override
  String get couldNotListPleaseTryAgain => '出品に失敗しました。しばらくしてからお試しください。';

  @override
  String downloadLinkValidOnceP0P1(Object p0, Object p1) => 'このダウンロードリンクは 5 分間有効で、1 回のみ使用できます。共有しないでください。\n\n${p0}\n\nファイルサイズ：${p1}';

  @override
  String get sources => '情報源';

  @override
  String get unableOpenLink => 'リンクを開けませんでした。';

  @override
  String get helpCentre2 => 'サポートセンター';

  @override
  String get preferences => '環境設定';

  @override
  String get privacy => 'プライバシー';

  @override
  String get about2 => '概要';

  @override
  String clearP0Notifications(Object p0) => '${p0}の通知を消去';

  @override
  String p1NotificationsP0DeletedCannotUndone(Object p0, Object p1) => '${p0}の通知 ${p1} 件を削除します。この操作は元に戻せません。';

  @override
  String p0NotificationsCleared(Object p0) => '${p0}の通知を消去しました';

  @override
  String markAllP1UnreadNotificationsP0(Object p0, Object p1) => '${p0}の未読通知 ${p1} 件をすべて既読にしますか？';

  @override
  String get offers => 'お得情報';

  @override
  String get noTransactionNotifications => '取引に関する通知はありません';

  @override
  String get noChatNotifications => 'チャットに関する通知はありません';

  @override
  String get noAccountNotifications => 'アカウントに関する通知はありません';

  @override
  String get noSupportNotifications => 'サポートに関する通知はありません';

  @override
  String get noOfferNotifications => 'お得情報に関する通知はありません';

  @override
  String get images => '画像';

  @override
  String get imagesStillUploadingPleaseWaitBefore => '画像をアップロード中です。完了してから送信してください。';

  @override
  String get someImagesFailedUploadRetryRemove => '一部の画像をアップロードできませんでした。再試行するか削除してから送信してください。';

  @override
  String get attachImages => '画像を添付';

  @override
  String get imageCouldNotRead => 'この画像を読み込めません';

  @override
  String get up4ImagesPerMessage => '1 件のメッセージに添付できる画像は 4 枚までです';

  @override
  String retryUploadingImageP0(Object p0) => '画像 ${p0} を再アップロード';

  @override
  String removeImageP0(Object p0) => '画像 ${p0} を削除';

  @override
  String get addImages => '画像を追加';

  @override
  String viewImageP0(Object p0) => '画像 ${p0} を表示';

  @override
  String get eGGoldMember => '例：ゴールド会員';

  @override
  String get pointsThreshold => '必要ポイント';

  @override
  String get pts => 'pt';

  @override
  String get tierBenefits => 'ランク特典';

  @override
  String get oneBenefitPerLine => '1 行に 1 つの特典';

  @override
  String get newTier2 => '新しいランク';

  @override
  String get whatMembersSee => '会員に表示される内容';

  @override
  String get noThresholdSet => 'しきい値が未設定です';

  @override
  String get tierOrder => 'ランクの順序';

  @override
  String get noBenefitsSet => '特典が未設定です';

  @override
  String p0CurrentlyP1MembersAfterDeletion(Object p0, Object p1, Object p2) => '「${p0}」には現在 ${p1} 人の会員がいます。削除すると「${p2}」に移動します。';

  @override
  String noMembersCurrentlyP0OtherTiers(Object p0) => '現在「${p0}」に属する会員はいません。削除しても他のランクに影響はありません。';

  @override
  String tierDeletedP0MembersMovedP1(Object p0, Object p1) => 'ランクを削除しました。${p0} 人の会員が「${p1}」に移動しました';

  @override
  String get changeTierOrder => 'ランクの順序を変更';

  @override
  String get thresholdsStayWithTheirPositionThese => 'しきい値は位置ごとに保持されます。次のランクのしきい値が変わります：';

  @override
  String p0P1P2Pts(Object p0, Object p1, Object p2) => '「${p0}」${p1} → ${p2} pt';

  @override
  String get tierOrderUpdated => 'ランクの順序を更新しました';

  @override
  String p0Members(Object p0) => '会員 ${p0} 人';

  @override
  String get tiers => 'ランク';

  @override
  String get members4 => '人の会員';

  @override
  String get memberDistribution => '会員の分布';

  @override
  String get moreActions => 'その他の操作';

  @override
  String get dragReorder => 'ドラッグして並べ替え';

  @override
  String p0Pts(Object p0) => '${p0} pt 以上';

  @override
  String p0P1Pts(Object p0, Object p1) => '${p0}–${p1} pt';

  @override
  String tierNamedP0AlreadyExists(Object p0) => '「${p0}」という名前のランクは既にあります';

  @override
  String get enterPointsThreshold => 'しきい値を入力してください';

  @override
  String get thresholdMustWholeNumber0More => 'しきい値は 0 以上の整数で入力してください';

  @override
  String thresholdCannotExceedP0(Object p0) => 'しきい値は ${p0} 以下にしてください';

  @override
  String p0AlreadyUsesP1PtsEach(Object p0, Object p1) => '「${p0}」が既に ${p1} pt を使用しています。ランクごとに異なるしきい値が必要です';

  @override
  String get startingTierMustBegin0Pts => '最初のランクのしきい値は 0 pt にしてください';

  @override
  String get startingTierCannotDeletedSetAnother => '最初のランクは削除できません。先に別のランクのしきい値を 0 pt にしてください';

  @override
  String get signLink => 'ログインして連携';

  @override
  String get signAccount => '既存のアカウントにログイン';

  @override
  String emailAlreadyRegisteredSignLinkName(Object p0) => 'このメールアドレスは登録済みです。ログインすると ${p0} が連携されます。';

  @override
  String signLinkNameCanThenSign(Object p0, Object p1) => 'ログインすると ${p0} が連携され、次回から ${p1} でログインできます。';

  @override
  String get noPasskeyDevice => 'このデバイスに使用できるパスキーがありません';

  @override
  String get signWithPasskeyAnotherDeviceSecurity => '別のデバイスのパスキーまたはセキュリティキーでログインするか、パスワードをご利用ください。';

  @override
  String get useAnotherDevice => '別のデバイスを使用';

  @override
  String get usePassword => 'パスワードを使用';

  @override
  String get icloudKeychain => 'iCloud キーチェーン';

  @override
  String get googlePasswordManager => 'Google パスワード マネージャー';

  @override
  String get synced => '同期済み';

  @override
  String get notSynced => '未同期';

  @override
  String get alreadyPasskey => '使用できるパスキーがあります';

  @override
  String get enterName => '名前を入力してください';

  @override
  String get passkeySavedIcloudKeychainWorksEvery => 'パスキーは iCloud キーチェーンに保存されており、同じ Apple アカウントでサインインしているすべてのデバイスで使用できるため、再度追加する必要はありません。別のパスキーを作成するには「もう一度追加」をタップし、システムの画面で別のパスワード マネージャーまたはセキュリティキーを選択してください。';

  @override
  String get passkeySavedGooglePasswordManagerWorks => 'パスキーは Google パスワード マネージャーに保存されており、同じ Google アカウントでログインしているすべてのデバイスで使用できるため、再度追加する必要はありません。別のパスキーを作成するには「もう一度追加」をタップし、システムの画面で別のパスワード マネージャーまたはセキュリティキーを選択してください。';

  @override
  String get passkeySavedDeviceSPasswordManager => 'パスキーはこのデバイスのパスワード マネージャーに保存されており、同じアカウントでログインしているすべてのデバイスで使用できるため、再度追加する必要はありません。別のパスキーを作成するには「もう一度追加」をタップし、システムの画面で別のパスワード マネージャーまたはセキュリティキーを選択してください。';

  @override
  String get addAgain => 'もう一度追加';

  @override
  String get codeExpiredPleaseRequestNewOne => '認証コードの有効期限が切れました。再送信してください。';

  @override
  String codeValidP0(Object p0) => '認証コードの有効時間 ${p0}';

  @override
  String get basicSettings => '基本設定';

  @override
  String get eGBirthdayVoucher => '例：誕生日クーポン';

  @override
  String get benefitDetails => '特典の内容';

  @override
  String get addBenefit => '特典を追加';

  @override
  String get bookNoLongerExistsBeenRemoved => 'この書籍は存在しないか、出品が取り下げられています。';

  @override
  String get myNicknameGroup => 'このグループでのニックネーム';

  @override
  String get setGroupNickname => 'グループ内のニックネームを設定';

  @override
  String get allGroupMembersSeeNickname => 'このニックネームはグループの全メンバーに表示されます。';

  @override
  String get markLockerMaintenance => 'メンテナンス中にする';

  @override
  String get endLockerMaintenance => 'メンテナンス終了';

  @override
  String maintenanceHidesP0FromSellers(Object p0) => 'メンテナンス中は「${p0}」が出品者の預け入れ先一覧に表示されなくなります。既存の注文には影響しません。';

  @override
  String endingMaintenanceP0AvailableAgain(Object p0) => 'メンテナンスを終了すると「${p0}」を出品者が再び選べるようになります。';

  @override
  String get lockerMarkedMaintenance => 'ロッカーをメンテナンス中にしました';

  @override
  String get lockerMaintenanceEnded => 'ロッカーのメンテナンスを終了しました';

  @override
  String get semanticIndex => 'セマンティックインデックス';

  @override
  String get semanticSearch => 'セマンティック検索';

  @override
  String p0BooksP1HelpArticlesIndexed(Object p0, Object p1) => '書籍 ${p0} 件、サポート情報 ${p1} 件を登録済み';

  @override
  String get noOpenaiGeminiKeyConfiguredOnly => 'OpenAI または Gemini のキーが未設定のため、キーワード検索のみを使用しています。';

  @override
  String get databaseNotBeenUpdated020Only => 'データベースが未更新（020）のため、キーワード検索のみを使用しています。';

  @override
  String get hybridSearchKeywordSemantic => 'ハイブリッド検索（キーワード＋意味）';

  @override
  String get keywordSearchOnly => 'キーワード検索のみ';

  @override
  String get paymentReleasedWalletWhenBuyerCompletes => '購入者が注文を完了するか、受け取りから 24 時間後に代金がウォレットに入金されます';

  @override
  String get completeOrderAfterCheckingBookCompletes => '書籍の状態を確認したら注文を完了してください。受け取りから 24 時間以内に申し立てがなければ自動的に完了します';

  @override
  String get completeOrder => '注文を完了';

  @override
  String get onceCompleteOrderPaymentReleasedSeller => '注文を完了すると代金が出品者に支払われ、以後は紛争を申し立てられません。';

  @override
  String get orderCompleted2 => '注文が完了しました';

  @override
  String get noReservedBooks => '予約中の書籍はありません';

  @override
  String heldUntilP02(Object p0) => '${p0} まで確保中';

  @override
  String heldUntilP03(Object p0) => '${p0} まで確保中';

  @override
  String get awaitingBuyerConfirmation => '購入者の確認待ち';

  @override
  String get awaitingCompletion => '完了待ち';

  @override
  String get libraryCopyUnofficialSource => '図書館蔵書・非正規入手の疑い';

  @override
  String p0CannotEdit(Object p0) => '${p0}・編集できません';

  @override
  String get buyNow2 => '今すぐ購入';

  @override
  String get suggestRefund => '返金を推奨';

  @override
  String get suggestDismissal => '却下を推奨';

  @override
  String get needsMoreInformation => '追加情報が必要';

  @override
  String get aiAnalysis => 'AI 分析';

  @override
  String get analyze => '分析する';

  @override
  String get analyzeAgain => '再分析';

  @override
  String get aiAnalysisReferenceOnlyDecideBased => 'AI 分析は参考情報です。実際の証拠に基づいて判断してください。';

  @override
  String p0P1Confidence(Object p0, Object p1) => '${p0}・確信度 ${p1}%';

  @override
  String get aiSummary => 'AI 要約';

  @override
  String get autoFilled => '自動入力';

  @override
  String get similarBooks => '似ている本';

  @override
  String get doNotPayTransferMoneyOutside => 'アプリ外での送金・振込はしないでください。プラットフォームの保護対象外です。';

  @override
  String get pleaseCompleteDealAppWeCannot => 'アプリ内で取引してください。アプリ外の取引トラブルには対応できません。';

  @override
  String get personSharedOutsideContactDetailsWatch => '相手がアプリ外の連絡先を送ってきました。詐欺に注意し、アプリ内で取引を完了してください。';

  @override
  String get mostRelevant => '関連度順';

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
  String get orderRefunding => '심사 중';

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
  String get orderFlowPickup => '구매자 수령 완료';

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
  String get language => '언어';

  @override
  String get languageSystem => '시스템 설정 따르기';

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
  String get accountPermanentlyDisabled30DaysSign => '계정은 30일 후 삭제되며, 기간 내에 다시 로그인하면 취소됩니다. 삭제 후 개인 정보는 지워지며 완료된 주문과 거래 기록은 보존됩니다.';

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
  String get cancelAccountDeletion => '계정 삭제 취소';

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
  String get signStartChat => '판매자에게 연락하려면 로그인하세요';

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
  String get reportSubmittedWeLookInto => '신고가 접수되었습니다';

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
  String get messageSeller => '판매자와 대화';

  @override
  String get listing => '내 상품입니다';

  @override
  String get addCart => '장바구니 담기';

  @override
  String get bookBeenReportedUnderReviewStays => '이 책은 신고되어 검토 중입니다.';

  @override
  String get violationWasConfirmedBookPleaseCheck => '이 책은 위반이 확인되었습니다. 상품 내용을 수정하세요.';

  @override
  String get delist => '판매 중단';

  @override
  String removedFromShopBuyersNoLonger(Object p0) => '“${p0}”이(가) 상점에서 내려가 구매자에게 더 이상 표시되지 않습니다.';

  @override
  String get delist2 => '내리기';

  @override
  String get couldNotDelistPleaseTryAgain => '판매 중단에 실패했습니다. 잠시 후 다시 시도해 주세요.';

  @override
  String listedAgain(Object p0) => '“${p0}”을(를) 다시 등록했습니다';

  @override
  String get notListedAnyBooksYet => '아직 등록한 도서가 없습니다';

  @override
  String get noBooksCategory => '이 분류에 도서가 없습니다';

  @override
  String get relist => '다시 올리기';

  @override
  String get remove => '삭제';

  @override
  String get couldNotRemoveRestored => '삭제하지 못해 되돌렸습니다.';

  @override
  String get selectBooksWantCheckOut => '결제할 도서를 선택해 주세요';

  @override
  String notEnoughCoinsOrderNeedsBut(Object p0, Object p1) => '코인이 부족합니다. 이 주문에는 ${p0}이(가) 필요하지만 잔액은 ${p1}입니다.';

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
  String markAllUnreadMessagesAsRead(Object p0) => '읽지 않은 메시지 ${p0}건을 모두 읽음으로 표시할까요?';

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
  String get messageCouldNotSent => '메시지를 보내지 못했습니다';

  @override
  String get chat => '채팅';

  @override
  String get sendFirstMessage => '첫 메시지를 보내세요';

  @override
  String get messageCopied => '메시지를 복사했습니다';

  @override
  String get iQuestionAboutBook => '도서 문의';

  @override
  String get bookNoLongerListed => '이 책은 더 이상 판매하지 않습니다';

  @override
  String get writeMessage => '메시지 입력…';

  @override
  String get enterOrderNumberDisputing => '이의를 제기할 주문 번호를 입력하세요';

  @override
  String get describeDispute => '이의 내용을 입력해 주세요';

  @override
  String get useLeast10CharactersSoSupport => '설명은 10자 이상이어야 합니다';

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
  String get submitDispute2 => '이의 제기하기';

  @override
  String get orderNumber => '주문 번호';

  @override
  String get eGSmb20260910123456789 => '예: SMB20260910123456789';

  @override
  String get whatHappened => '이의 내용';

  @override
  String get describeProblemEGConditionDoes => '발생한 문제를 설명해 주세요';

  @override
  String get submit => '신청 보내기';

  @override
  String get uploadPhotos => '사진 업로드';

  @override
  String get canAttachUp6Photos => '증빙 사진은 최대 6장까지 첨부할 수 있습니다';

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
  String get photoMissingDataRefreshTryAgain => '이 사진을 처리할 수 없습니다. 새로고침 후 다시 시도하세요.';

  @override
  String get enterPrice => '가격을 입력하세요';

  @override
  String get priceMustGreaterThan0 => '가격은 0보다 커야 합니다';

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
  String get tapPickPublicationDate => '출간일 선택';

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
  String get tellPeopleAboutYourself => '소개를 입력하세요';

  @override
  String get email => '이메일';

  @override
  String get emailCannotChanged => '이메일은 변경할 수 없습니다';

  @override
  String get dateBirth => '생년월일';

  @override
  String get tapPickDateBirth => '생년월일 선택';

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
  String get documentNotBeenCreatedYet => '내용이 없습니다';

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
  String get membershipTiersNotSetUpYet => '현재 회원 등급이 제공되지 않습니다';

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
  String get noBenefitsBeenDescribedTierYet => '이 등급에는 추가 혜택이 없습니다';

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
  String markAllUnreadNotificationsAsRead(Object p0) => '읽지 않은 알림 ${p0}건을 모두 읽음으로 표시할까요?';

  @override
  String get openChat => '채팅 열기';

  @override
  String get viewOrder => '주문 보기';

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
  String get orderNoItemDetails => '상품 내역 없음';

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
  String get notAssignedYet => '보관함 미배정';

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
  String get coinsArriveOnceBuyerCollectsBook => '구매자 수령 후 자동 지급';

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
  String collected(Object p0) => '“${p0}” 수령 완료';

  @override
  String order2(Object p0) => '주문 번호: ${p0}';

  @override
  String get signingOut => '로그아웃 중…';

  @override
  String get myAccount => '마이페이지';

  @override
  String get personNotWrittenBioYet => '소개가 없습니다';

  @override
  String get topTierReached => '최고 등급 달성';

  @override
  String morePointsReach(Object p0, Object p1) => '${p0}점 더 모으면 “${p1}”';

  @override
  String get purchases => '구매 내역';

  @override
  String get sales => '판매 내역';

  @override
  String get settings => '설정';

  @override
  String get signOut2 => '로그아웃할까요?';

  @override
  String cancelOrderBookReturnsShop(Object p0) => '주문 ${p0}을(를) 취소할까요? 도서는 다시 판매됩니다.';

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
  String get joinSavemybook => '계정 가입';

  @override
  String get displayName => '닉네임';

  @override
  String get emailSignWith => '이메일';

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
  String get priceCannotExceed99999 => '가격은 99,999 코인을 넘을 수 없습니다.';

  @override
  String get chooseLockerLocation2 => '보관 위치를 선택해 주세요.';

  @override
  String get listed2 => '등록되었습니다';

  @override
  String get unknownError => '알 수 없는 오류';

  @override
  String get couldNotListBook => '등록에 실패했습니다';

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
  String get noSourceIsbnPleaseEnterDetails => '어떤 데이터베이스에도 이 ISBN이 없습니다. 직접 입력해 주세요.';

  @override
  String get day => '일';

  @override
  String get tapIconRightScan => 'ISBN 입력';

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
  String sign3(Object p0) => '${p0} 로그인';

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
  String addMeSavemybook(Object p0) => 'SaveMyBook 프로필: ${p0}';

  @override
  String addMeSavemybook2(Object p0, Object p1) => '${p0}님의 SaveMyBook 프로필: ${p1}';

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
  String get addMoreDetailSoSupportCan => '문제 설명을 보충해 주세요';

  @override
  String get sentSupportReplySoon => '보냈습니다. 고객센터가 곧 답변드립니다.';

  @override
  String get subject => '제목';

  @override
  String get sumUpOneLine => '한 줄로 요약해 주세요';

  @override
  String get whatHappenedIncludeOrderNumberIf => '문제 내용을 입력해 주세요. 주문 번호가 있다면 함께 입력해 주세요.';

  @override
  String get close => '종료';

  @override
  String get notAbleReplyAfterClosing => '종료하면 더 이상 답변할 수 없습니다.';

  @override
  String get enquiryClosed => '문의가 종료되었습니다';

  @override
  String get changeStatus => '상태 변경';

  @override
  String get statusUpdated => '상태를 변경했습니다';

  @override
  String get enquiry => '문의 내역';

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
  String slot2(Object p0) => '보관함: ${p0}';

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
  String get noAnnouncementsYetTapAddOne => '공지가 없습니다';

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
  String get noBackupsYetSchedulerRunsOnce => '백업 기록이 없습니다';

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
  String sectionP0NoTitleYet(Object p0) => '${p0} 조항에 제목이 없습니다';

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
  String get noArticlesYetAddFirstOne => '조항이 없습니다';

  @override
  String get addSection => '조항 추가';

  @override
  String get untitledSection => '제목 없는 조항';

  @override
  String get sectionTitle => '조항 제목';

  @override
  String get bodySectionSingleLineBreaksKept => '이 조항의 본문입니다. 한 번의 줄바꿈은 그대로 표시되고, 빈 줄은 문단을 나눕니다.';

  @override
  String get howUsersSee => '사용자에게 보이는 모습';

  @override
  String get noContentYet => '내용이 없습니다';

  @override
  String get unsaved => '저장 안 됨';

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
  String orderP0P1(Object p0, Object p1) => '주문 ${p0} | \$${p1}';

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
  String get listings => '상품 관리';

  @override
  String get moderation => '콘텐츠 심사';

  @override
  String get handleListingReports => '상품 신고 처리';

  @override
  String get members => '회원 관리';

  @override
  String get memberControls => '회원 관리';

  @override
  String get membershipTiers => '회원 등급 관리';

  @override
  String get wallets => '지갑 관리';

  @override
  String get hardwareOperations => '하드웨어 및 운영';

  @override
  String get maintenanceLog => '정비 기록';

  @override
  String get reports => '운영 리포트';

  @override
  String get ordersRevenueMemberGrowth => '주문, 매출, 회원 증가';

  @override
  String get supportEnquiries => '고객 문의';

  @override
  String get adminAuditLog => '관리 작업 기록';

  @override
  String get systemOperations => '시스템 운영';

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
  String get remindThemChangeSettingsChangePassword => '로그인 후 바로 설정 › 비밀번호 변경에서 바꾸도록 안내하세요.';

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
  String get changeOwnPasswordGoSettingsChange => '본인 비밀번호는 설정 › 비밀번호 변경에서 바꾸세요';

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

  @override
  String get buyerSPaymentGoesBackTheir => '구매자의 결제 금액이 지갑으로 환불됩니다. 판매자에게 이미 대금이 지급됐다면 먼저 회수합니다.';

  @override
  String get orderReturnsWhereWasBeforeDispute => '주문이 이의 제기 전 상태로 돌아가 거래를 계속합니다. 이미 수령했다면 판매자에게 대금을 지급합니다.';

  @override
  String get orderWasAlreadyRefundedBuyerCannot => '이 주문은 이미 구매자에게 환불되어 진행 중이나 완료로 되돌릴 수 없습니다';

  @override
  String get completedOrderCanOnlyChangedRefund => '완료된 주문은 "환불 처리 중" 또는 "환불 완료"로만 변경할 수 있습니다';

  @override
  String confirmingPaysP0TokensSellerMarks(Object p0) => '확인하면 판매자에게 ${p0} 토큰을 지급하고 책을 판매 완료로 표시합니다.';

  @override
  String confirmingTakesP0TokensBackFrom(Object p0) => '확인하면 판매자에게서 ${p0} 토큰을 회수해 구매자에게 환불합니다. 판매자 잔액이 부족하면 마이너스가 됩니다.';

  @override
  String get ifBuyerNotBeenRefundedYet => '아직 환불되지 않았다면 구매자에게 환불합니다.';

  @override
  String confirmingRefundsBuyerSP0Tokens(Object p0) => '확인하면 구매자가 결제한 ${p0} 토큰을 환불하고 예약 중인 책을 다시 판매합니다.';

  @override
  String get donTPermissionYourselfSoCan => '본인에게 이 권한이 없어서 다른 사람에게 부여할 수 없습니다.';

  @override
  String get notificationsTurnedOff => '알림이 꺼져 있습니다';

  @override
  String get openSettings => '설정 열기';

  @override
  String get sendTestNotification => '테스트 알림 보내기';

  @override
  String get arrives10SecondsGoHomeScreen => '10초 후 도착합니다. 보낸 뒤 홈 화면으로 가거나 휴대폰을 잠그세요.';

  @override
  String get systemNotificationSettings => '시스템 알림 설정';

  @override
  String get pushNotificationsNotSetUpBuild => '이 빌드에는 푸시 알림이 설정되어 있지 않습니다. Firebase 설정 파일을 추가하고 다시 빌드하세요.';

  @override
  String get notificationsTurnedOffAllowAppSend => '알림이 꺼져 있습니다. 시스템 설정에서 이 앱의 알림을 허용하세요.';

  @override
  String get restoreBackup => '이 백업으로 복원할까요?';

  @override
  String wholeDatabaseGoBackP0Orders(Object p0) => '전체 데이터베이스가 ${p0} 상태로 돌아갑니다. 그 이후의 주문, 메시지, 회원 데이터, 작업 기록은 모두 사라집니다.\n\n복원 전에 현재 상태를 자동으로 백업하므로 잘못 복원했다면 그 백업으로 되돌릴 수 있습니다. 복원하는 동안 서비스가 중단되며 보통 수십 초에서 몇 분 걸립니다.\n\n확인을 위해 로그인 비밀번호를 입력하세요:';

  @override
  String get password2 => '로그인 비밀번호';

  @override
  String get startRestore => '복원 시작';

  @override
  String get backingUpCurrentState => '현재 상태를 백업하는 중…';

  @override
  String databaseRestoredPreviousStateWasBacked(Object p0) => '데이터베이스를 복원했습니다. 복원 전 상태는 ${p0}에 백업되어 있습니다';

  @override
  String restoreFailedDatabaseMayUnchangedPartly(Object p0) => '복원에 실패했습니다. 데이터베이스가 그대로이거나 일부만 복원되었을 수 있습니다. 작업 기록을 확인하고 ${p0} 복원을 고려하세요';

  @override
  String get autoBackupBeforeRestore => '복원 전 자동 백업';

  @override
  String get restoreBackup2 => '이 백업으로 복원';

  @override
  String get restoringDatabase => '데이터베이스 복원 중';

  @override
  String p0SecondsSoFarKeepApp(Object p0) => '${p0}초 지났습니다. 앱을 닫지 마세요. 완료되면 서비스가 자동으로 재개됩니다.';

  @override
  String get majorUpdate2 => '중요한 업데이트';

  @override
  String get minorEdit => '사소한 수정';

  @override
  String get books => '도서';

  @override
  String get orders2 => '주문';

  @override
  String get wallets2 => '지갑';

  @override
  String get announcements3 => '공지';

  @override
  String get legal => '약관';

  @override
  String get backups => '백업';

  @override
  String get undoAction => '이 작업을 되돌릴까요?';

  @override
  String p0NNtheDataGoesBack(Object p0) => '"${p0}"\n\n데이터가 작업 전 상태로 돌아갑니다. 이미 보낸 알림은 회수되지 않습니다. 그 뒤에 데이터가 다시 수정되었다면 되돌릴 수 없습니다.';

  @override
  String get undo => '되돌리기';

  @override
  String get undone => '되돌림';

  @override
  String get searchActionsEGNicknameBook => '작업 내용 검색 (예: 닉네임, 책 제목)';

  @override
  String viewP0Changes(Object p0) => '변경 ${p0}건 보기';

  @override
  String get undoAction2 => '이 작업 되돌리기';

  @override
  String get noAnnouncements => '공지가 없습니다';

  @override
  String get canTContinueWithoutAccepting => '동의하지 않으면 계속 사용할 수 없습니다';

  @override
  String needAcceptLatestP0UseP1(Object p0) => '"${p0}"에 동의하지 않으면 로그아웃됩니다.';

  @override
  String get goBack => '돌아가기';

  @override
  String p0BeenUpdated(Object p0) => '"${p0}"이(가) 업데이트되었습니다';

  @override
  String readLatestVersionUpdatedP0Accept(Object p0) => '${p0} 업데이트';

  @override
  String get scrollEndContinue => '끝까지 스크롤해 주세요';

  @override
  String get iVeReadAccept => '읽었으며 동의합니다';

  @override
  String get decline => '동의하지 않음';

  @override
  String get viewDetails => '자세히 보기';

  @override
  String get notFoundMayBeenDeletedRemoved => '이 콘텐츠는 더 이상 존재하지 않습니다';

  @override
  String get chatMessages => '채팅 메시지';

  @override
  String get promotions2 => '프로모션';

  @override
  String get supportRepliesPasswordResetsPolicyUpdates => '고객센터 답변, 계정 보안, 시스템 공지 알림은 끌 수 없습니다.';

  @override
  String get notFilled => '미입력';

  @override
  String get canTChanged => '변경 불가';

  @override
  String get voice => '[음성]';

  @override
  String get reservation => '예약';

  @override
  String get messageUnsent => '메시지를 회수했습니다';

  @override
  String get confirmBeforeExportingData => '데이터를 내보내기 전에 본인 확인을 해 주세요';

  @override
  String get exportFailedPleaseTryAgainLater => '내보내기에 실패했습니다. 잠시 후 다시 시도해 주세요';

  @override
  String get refresh => '새로 고침';

  @override
  String get clearFilters => '필터 지우기';

  @override
  String get expired => '만료됨';

  @override
  String get verificationCancelled => '인증을 취소했습니다';

  @override
  String get openingClosingTimesCanTSame => '시작 시간과 종료 시간은 같을 수 없습니다';

  @override
  String slotCurrentlyP0MayOrderProgress(Object p0, Object p1) => '이 칸은 현재 "${p0}" 상태이며 진행 중인 주문이 있을 수 있습니다. "${p1}"(으)로 바꾸면 구매자나 판매자가 책을 넣거나 찾지 못할 수 있습니다.';

  @override
  String get active => '사용 중';

  @override
  String get categoryWithNameAlreadyExists => '같은 이름의 카테고리가 이미 있습니다';

  @override
  String orderP0ClosedAsP1P2(Object p0, Object p1, Object p2) => '주문 ${p0}이(가) "${p1}"(으)로 종결되고 ${p2} 코인이 구매자에게 환불됩니다. 제출 후에는 변경할 수 없습니다.';

  @override
  String orderP0ClosedAsP1Can(Object p0, Object p1) => '주문 ${p0}이(가) "${p1}"(으)로 종결됩니다. 제출 후에는 변경할 수 없습니다.';

  @override
  String get clearSearch => '검색 지우기';

  @override
  String get enterMinimumPoints => '최소 포인트를 입력하세요';

  @override
  String pointsRangeOverlapsWithP0P1(Object p0, Object p1) => '포인트 범위가 "${p0}"(${p1})과(와) 겹칩니다';

  @override
  String noTierCoversP0P1Points(Object p0, Object p1) => '${p0}–${p1}포인트에 해당하는 등급이 없습니다';

  @override
  String p0TakenDownRightAwayOther(Object p0) => '"${p0}"이(가) 즉시 판매 중지되며 다른 회원은 더 이상 보거나 구매할 수 없습니다.';

  @override
  String get searchReportedItemReporterReason => '신고 대상, 신고자 또는 사유 검색';

  @override
  String get couldnTLoadStatisticsRightNow => '통계를 불러올 수 없습니다';

  @override
  String get searchSubjectMemberMessage => '제목, 회원 또는 메시지 검색';

  @override
  String get balance3 => '잔액 있음';

  @override
  String get hold3 => '보류 금액 있음';

  @override
  String get zeroBalance => '잔액 0';

  @override
  String get amountCanMost2DecimalPlaces => '금액은 소수점 이하 두 자리까지만 입력할 수 있습니다';

  @override
  String get singleAdjustmentCanTExceed1 => '한 번에 1,000,000을 초과해 조정할 수 없습니다';

  @override
  String wouldMakeBalanceNegativeCurrentBalance(Object p0) => '차감하면 잔액이 마이너스가 됩니다. 현재 잔액: ${p0}';

  @override
  String get amountUp2Decimals => '금액(소수점 이하 두 자리까지)';

  @override
  String p0NbalanceAfterP1(Object p0, Object p1) => '${p0}\n조정 후 잔액: ${p1}';

  @override
  String get cameraAccessOff => '카메라를 사용할 수 없습니다';

  @override
  String get couldNotStartCamera => '카메라를 시작하지 못했습니다';

  @override
  String allowP0UseCameraSettingsThen(Object p0) => '설정에서 ${p0}의 카메라 접근을 허용한 뒤 다시 시도해 주세요.';

  @override
  String get closeScreenTryAgain => '이 화면을 닫고 다시 시도해 주세요.';

  @override
  String get couldnTGetLocationCheckLocation => '현재 위치를 가져올 수 없습니다. 위치 서비스와 권한이 켜져 있는지 확인하세요';

  @override
  String get bookReservedAnotherBuyerCanT => '다른 구매자가 예약한 책이라 지금은 장바구니에 담을 수 없습니다';

  @override
  String reservedAnotherBuyerUntilP0(Object p0) => '다른 구매자가 ${p0}까지 예약함';

  @override
  String sellerHoldingUntilP0(Object p0) => '판매자가 ${p0}까지 회원님을 위해 보관 중';

  @override
  String get checkOutBeforeHoldEndsOther => '보관 기한 내에 결제를 완료하세요';

  @override
  String get copyAddress => '주소 복사';

  @override
  String p0Away(Object p0) => '${p0} 거리';

  @override
  String get locating => '위치 확인 중…';

  @override
  String get showDistance => '거리 보기';

  @override
  String get reserved => '예약됨';

  @override
  String get goCheckout => '결제하러 가기';

  @override
  String get cart2 => '장바구니에 있음';

  @override
  String get buyNow => '지금 구매';

  @override
  String p0Delisted(Object p0) => '《${p0}》 판매를 중지했습니다';

  @override
  String noBooksMatchP0(Object p0) => '"${p0}"과(와) 일치하는 책이 없습니다';

  @override
  String p0BooksP1Views(Object p0, Object p1) => '${p0}권 · 조회 ${p1}회';

  @override
  String get searchTitleAuthorIsbn2 => '제목, 저자, ISBN 검색';

  @override
  String removedP0(Object p0) => '"${p0}"을(를) 삭제했습니다';

  @override
  String removedP0Items(Object p0) => '상품 ${p0}개를 삭제했습니다';

  @override
  String get paymentSuccessful => '결제 완료';

  @override
  String p0BooksSplitIntoP1Orders(Object p0, Object p1) => '총 ${p0}권, 판매자별로 ${p1}건의 주문으로 나눴습니다';

  @override
  String get keepBrowsing => '계속 둘러보기';

  @override
  String get reload => '다시 불러오기';

  @override
  String get browseBooks => '둘러보기';

  @override
  String p0Sellers(Object p0) => '판매자 ${p0}명';

  @override
  String unavailableP0(Object p0) => '구매 불가 (${p0})';

  @override
  String get removeAll => '모두 삭제';

  @override
  String get goWallet => '지갑으로 이동';

  @override
  String fromP0SellersCheckoutCreatesP1(Object p0, Object p1) => '판매자 ${p0}명의 상품으로, 결제 후 ${p1}건의 주문으로 나뉩니다';

  @override
  String get otherDevicesNeedSignAgainWith => '다른 기기에서는 새 비밀번호로 다시 로그인해야 합니다.';

  @override
  String get searchChats => '대화 상대 검색';

  @override
  String get noMatchingChats => '일치하는 대화가 없습니다';

  @override
  String get read => '읽음';

  @override
  String get chatNotFound => '채팅방을 찾을 수 없습니다';

  @override
  String get messagesCanUp2000Characters => '메시지는 최대 2000자까지 가능합니다';

  @override
  String get canTSendRightNowPlease => '지금은 보낼 수 없습니다. 잠시 후 다시 시도해 주세요';

  @override
  String get reserveBook => '이 책 예약하기';

  @override
  String get quickReplies => '빠른 답장';

  @override
  String get imagesMust10MbSmaller => '이미지는 10MB 이하여야 합니다';

  @override
  String get recordingFailedPleaseTryAgain => '녹음에 실패했습니다. 다시 시도해 주세요';

  @override
  String get voiceMessageTooLargePleaseRecord => '음성 파일이 너무 큽니다. 더 짧게 녹음해 주세요';

  @override
  String get microphoneAllowedPressHoldAgainRecord => '마이크 사용이 허용되었습니다. 다시 길게 눌러 녹음하세요';

  @override
  String get microphoneAccessNeededRecordTurnSettings => '녹음하려면 마이크 권한이 필요합니다. 설정에서 허용해 주세요';

  @override
  String get couldnTStartRecordingPleaseTry => '녹음을 시작할 수 없습니다. 잠시 후 다시 시도해 주세요';

  @override
  String get selectText => '텍스트 선택';

  @override
  String get unsend => '보내기 취소';

  @override
  String get resend => '다시 보내기';

  @override
  String get unsendMessage => '이 메시지를 보내기 취소할까요?';

  @override
  String get neitherAbleSeeMessageSContent => '취소하면 두 사람 모두 이 메시지 내용을 볼 수 없습니다.';

  @override
  String get reportMessage => '이 메시지 신고하기';

  @override
  String get reservationSentWaitingSeller => '예약을 보냈습니다. 판매자의 답변을 기다리는 중입니다';

  @override
  String get acceptReservation => '예약을 수락할까요?';

  @override
  String p0HeldThemP1HoursNo(Object p0, Object p1) => '《${p0}》을(를) 상대방을 위해 ${p1}시간 동안 보류합니다. 그동안 다른 사람은 구매할 수 없습니다.';

  @override
  String get accept => '수락';

  @override
  String get reservationAccepted => '예약을 수락했습니다';

  @override
  String get declineReservation => '예약을 거절할까요?';

  @override
  String get decline2 => '거절';

  @override
  String get reservationDeclined => '예약을 거절했습니다';

  @override
  String get cancelReservation => '예약을 취소할까요?';

  @override
  String p0NoLongerHeld(Object p0) => '취소하면 《${p0}》은(는) 더 이상 보류되지 않습니다.';

  @override
  String get cancelReservation2 => '예약 취소';

  @override
  String get reservationCanceled => '예약을 취소했습니다';

  @override
  String get notNow2 => '나중에';

  @override
  String get couldnTLoadConversationPleaseTry => '대화를 불러올 수 없습니다. 잠시 후 다시 시도해 주세요';

  @override
  String get accountCanTReceiveMessagesRight => '상대방 계정은 현재 메시지를 받을 수 없습니다';

  @override
  String get holdMicTalkReleaseSend => '녹음 시간이 너무 짧습니다';

  @override
  String get startConversation => '대화가 여기서 시작됩니다';

  @override
  String p0New(Object p0) => '새 메시지 ${p0}개';

  @override
  String get connectionUnstableMessagesCanTSent => '연결이 불안정하여 지금은 메시지를 보낼 수 없습니다';

  @override
  String get retry => '다시 시도';

  @override
  String get stillAvailable => '아직 판매 중인가요?';

  @override
  String get couldLowerPriceBit => '가격 협의가 가능한가요?';

  @override
  String get whenCanPutLocker => '보관함 입고 예정일은 언제인가요?';

  @override
  String get unsentMessage => '메시지 전송을 취소했습니다';

  @override
  String get theyUnsentMessage => '상대방이 메시지 전송을 취소했습니다';

  @override
  String get reservationDetailsArenTAvailableRight => '예약 정보를 표시할 수 없습니다';

  @override
  String get sending => '전송 중';

  @override
  String get couldNotUploadPhotosPleaseTry => '증빙 사진 업로드에 실패했습니다. 잠시 후 다시 시도해 주세요';

  @override
  String get bookDetailsUpdatedButPhotosCouldn => '도서 정보는 수정되었지만 사진을 올리지 못했습니다. 잠시 후 다시 시도해 주세요';

  @override
  String get sNotIsbnBarcodeScanOne => 'ISBN 바코드가 아닙니다. 뒤표지의 978 또는 979로 시작하는 바코드를 스캔해 주세요';

  @override
  String get couldnTLoadCategoriesTapRetry => '카테고리를 불러오지 못했습니다. 탭하여 다시 시도';

  @override
  String removedP0FromSaved(Object p0) => '"${p0}"을(를) 저장 목록에서 뺐습니다';

  @override
  String get recentlyViewedCleared => '최근 본 항목을 지웠습니다';

  @override
  String clearP0(Object p0) => '지우기 (${p0})';

  @override
  String get picked => '추천 도서';

  @override
  String get recentlyViewed => '최근 본 책';

  @override
  String get clear => '지우기';

  @override
  String get notificationDeleted => '알림을 삭제했습니다';

  @override
  String get pleasePutBookAssignedLockerSoon => '지정된 보관함에 책을 빨리 넣어 주세요';

  @override
  String get weLlLetKnowWhenSeller => '판매자가 책을 넣으면 수령 안내를 보내 드립니다';

  @override
  String get waitingBuyerCollect => '구매자의 수령을 기다리는 중';

  @override
  String get transactionCompleteThank => '거래 완료';

  @override
  String get confirmVeTakenBookFromLocker => '보관함에서 도서를 꺼냈는지 확인해 주세요. 도서 상태를 확인한 후 구매 내역에서 주문을 완료해 주세요.';

  @override
  String p0Orders2(Object p0) => '주문 ${p0}건';

  @override
  String p0ReadyPickup(Object p0) => '수령 가능 ${p0}건';

  @override
  String get pickUp => '픽업 대기';

  @override
  String get saved => '찜';

  @override
  String get accountSecurity => '계정 보안';

  @override
  String get searchHistoryCleared => '검색 기록을 지웠습니다';

  @override
  String get trendingBooks => '인기 도서';

  @override
  String get signOutDevice => '이 기기를 로그아웃할까요?';

  @override
  String signOutP0(Object p0) => '"${p0}"을(를) 로그아웃할까요?';

  @override
  String get deviceSignedOutRightAwayStop => '해당 기기는 즉시 로그아웃됩니다.';

  @override
  String get deviceSignedOut => '기기를 로그아웃했습니다';

  @override
  String get signOutAllDevicesIncludingOne => '모든 기기 로그아웃(이 기기 포함)';

  @override
  String get signOutAllOtherDevices => '다른 모든 기기 로그아웃';

  @override
  String get everyDeviceIncludingOneSignedOut => '이 기기를 포함한 모든 기기가 즉시 로그아웃됩니다.';

  @override
  String get everyDeviceExceptOneSignedOut => '이 기기를 제외한 모든 기기가 즉시 로그아웃됩니다.';

  @override
  String signedOutP0OtherDevices(Object p0) => '다른 기기 ${p0}대에서 로그아웃했습니다';

  @override
  String get unknownDevice => '알 수 없는 기기';

  @override
  String get couldnTLoadDevices => '기기 목록을 불러오지 못했습니다';

  @override
  String get device => '이 기기';

  @override
  String get otherDevices => '다른 기기';

  @override
  String otherDevicesP0(Object p0) => '다른 기기 (${p0})';

  @override
  String get noOtherDevicesSigned => '로그인된 다른 기기가 없습니다';

  @override
  String get signedDevices => '로그인된 기기';

  @override
  String get activeNow => '현재 사용 중';

  @override
  String lastActiveP0(Object p0) => '마지막 사용 ${p0}';

  @override
  String signedP0(Object p0) => '${p0} 로그인';

  @override
  String get biometricPayment => '생체 인증 결제 사용 중';

  @override
  String get paymentPinMust6Digits => '결제 비밀번호는 6자리 숫자여야 합니다';

  @override
  String get pinTooEasyGuessTryAnother => '결제 비밀번호가 너무 쉽습니다. 다른 번호를 사용하세요';

  @override
  String get enterPasswordResetPaymentPin => '로그인 비밀번호를 입력하면 결제 비밀번호를 다시 설정할 수 있습니다';

  @override
  String get confirmSBeforeSettingPaymentPin => '결제 비밀번호를 설정하기 전에 본인 확인이 필요합니다';

  @override
  String get pinsDonTMatchStartAgain => '두 번 입력한 비밀번호가 다릅니다. 다시 설정하세요';

  @override
  String get paymentPinReset => '결제 비밀번호를 재설정했습니다';

  @override
  String get paymentPinSet => '결제 비밀번호를 설정했습니다';

  @override
  String get verifyingIdentity => '본인 확인 중…';

  @override
  String get enterAgainConfirm => '확인을 위해 한 번 더 입력하세요';

  @override
  String get set6DigitPaymentPin => '6자리 결제 비밀번호 설정';

  @override
  String get enterSamePinAgain => '같은 비밀번호를 한 번 더 입력하세요';

  @override
  String get avoidRepeatedSequentialPatternedDigits => '같은 숫자, 연속 숫자, 반복 패턴은 사용할 수 없습니다';

  @override
  String get resetPaymentPin => '결제 비밀번호 재설정';

  @override
  String get paymentPin => '결제 비밀번호';

  @override
  String stepP02(Object p0) => '단계 ${p0} / 2';

  @override
  String get setPaymentPinFirst => '먼저 결제 비밀번호를 설정하세요';

  @override
  String get setPaymentPinFirstSoFallback => '먼저 결제 비밀번호를 설정하세요. 인증에 실패했을 때 대체 수단이 됩니다';

  @override
  String get setUpNow => '지금 설정';

  @override
  String get biometricPaymentTurnedOff => '생체 인증 결제를 껐습니다';

  @override
  String get verifyTurnBiometricPayment => '생체 인증 결제를 켜려면 인증하세요';

  @override
  String p0PaymentsTurned(Object p0) => '${p0} 결제를 켰습니다';

  @override
  String get securitySettingsUnavailableRightNowMay => '보안 설정을 불러올 수 없습니다';

  @override
  String payWithP0(Object p0) => '${p0}(으)로 결제';

  @override
  String get accountWellProtected => '계정이 안전하게 보호되고 있습니다';

  @override
  String get accountCouldSafer => '계정 보안을 강화할 수 있습니다';

  @override
  String get setPaymentPinTurnBiometricPayment => '결제 비밀번호가 설정되지 않았습니다';

  @override
  String tooManyAttemptsLockedUntilP0(Object p0) => '시도 횟수 초과. ${p0}까지 잠김';

  @override
  String get notSetRequiredBeforeCheckout => '설정되지 않음';

  @override
  String get change => '변경';

  @override
  String get forgotPaymentPin => '결제 비밀번호를 잊음';

  @override
  String p0Devices(Object p0) => '${p0}대';

  @override
  String get restoredUnfinishedListing => '작성 중이던 내용을 불러왔습니다';

  @override
  String get isbnSCheckDigitInvalidPlease => 'ISBN 체크 숫자가 올바르지 않습니다. 다시 확인해 주세요';

  @override
  String get draftSavedAutomatically => '임시 저장되었습니다';

  @override
  String get continueUnfinishedListing => '작성 중이던 판매 글 이어서 쓰기';

  @override
  String clearedP0MbCache(Object p0) => '캐시 ${p0}를 삭제했습니다';

  @override
  String get cacheCleared => '캐시를 삭제했습니다';

  @override
  String get storage => '저장 공간';

  @override
  String get clearCache => '캐시 삭제';

  @override
  String get couldNotLoadNotificationSettings => '알림 설정을 불러올 수 없습니다';

  @override
  String get month => '이번 달';

  @override
  String p0P1(Object p0, Object p1) => '${p0}년 ${p1}월';

  @override
  String get noIncomeYet => '수입 내역이 없습니다';

  @override
  String get noSpendingYet => '지출 내역이 없습니다';

  @override
  String get income => '수입';

  @override
  String get spending => '지출';

  @override
  String get totalIncome => '누적 수입';

  @override
  String get totalSpending => '누적 지출';

  @override
  String get item3 => '항목';

  @override
  String get details => '설명';

  @override
  String get balanceAfter => '거래 후 잔액';

  @override
  String get transactionId => '거래 번호';

  @override
  String get sessionExpiredPleaseSignAgain => '로그인이 만료되었습니다. 다시 로그인하세요';

  @override
  String get serviceTemporarilyUnavailableTryAgainLater => '서비스를 일시적으로 사용할 수 없습니다. 잠시 후 다시 시도하세요';

  @override
  String get uploadFailedTryAgainLater => '업로드에 실패했습니다. 잠시 후 다시 시도하세요';

  @override
  String get nearby => '근처';

  @override
  String p0M(Object p0) => '${p0}';

  @override
  String p0Km(Object p0) => '${p0}';

  @override
  String get iphoneDidnTReceiveApnsToken => 'iPhone이 APNs 토큰을 받지 못했습니다. Xcode의 Signing & Capabilities에 Push Notifications가 추가되었는지 확인하고 같은 Apple 개발자 계정으로 앱을 다시 설치하세요.';

  @override
  String get firebaseDidnTIssuePushToken => 'Firebase가 푸시 토큰을 발급하지 않았습니다. GoogleService-Info.plist와 앱의 Bundle ID가 일치하는지 확인하세요';

  @override
  String couldnTGetPushTokenP0(Object p0) => '푸시 토큰을 가져오지 못했습니다: ${p0}';

  @override
  String couldnTRegisterPushTokenWith(Object p0) => '푸시 토큰을 서버에 등록하지 못했습니다: ${p0}';

  @override
  String get protectCoinsCheckoutRequires6Digit => '결제 전에 6자리 결제 비밀번호를 설정하세요.';

  @override
  String confirmPaymentP0Coins(Object p0) => '${p0} 코인 결제 확인';

  @override
  String get enterPasswordContinue => '계속하려면 로그인 비밀번호를 입력하세요';

  @override
  String get verifyS => '본인 확인';

  @override
  String get amount => '결제 금액';

  @override
  String p0Coins(Object p0) => '${p0} 코인';

  @override
  String get enterPaymentPin => '결제 비밀번호 입력';

  @override
  String get enterPaymentPinContinue => '계속하려면 결제 비밀번호를 입력하세요';

  @override
  String get paymentPinResetEnterAgain => '결제 비밀번호를 재설정했습니다. 다시 입력하세요';

  @override
  String get usePasswordInstead => '로그인 비밀번호 사용';

  @override
  String get couldnTGetLocationLockersShown => '현재 위치를 가져올 수 없습니다';

  @override
  String p0SlotsFree(Object p0) => '빈 칸 ${p0}개';

  @override
  String openP0(Object p0) => '운영 ${p0}';

  @override
  String get nearest => '가장 가까움';

  @override
  String get noFreeSlots => '빈 칸 없음';

  @override
  String get turnLocationSortByDistance => '위치를 켜면 거리순으로 정렬됩니다';

  @override
  String get lockerNoFreeSlotsRightNow => '이 보관함은 현재 빈 칸이 없습니다';

  @override
  String get turn => '위치 켜기';

  @override
  String get noLockersAvailable => '이용 가능한 보관함이 없습니다';

  @override
  String get noMatchingOptions => '일치하는 항목이 없습니다';

  @override
  String get undo2 => '실행 취소';

  @override
  String copiedP0(Object p0) => '"${p0}"을(를) 복사했습니다';

  @override
  String get typing => '입력 중…';

  @override
  String get today => '오늘';

  @override
  String get yesterday => '어제';

  @override
  String p0P12(Object p0, Object p1) => '${p0}월 ${p1}일';

  @override
  String p1P2P0(Object p0, Object p1, Object p2) => '${p0}년 ${p1}월 ${p2}일';

  @override
  String get releaseCancel => '손을 떼면 취소';

  @override
  String get awaitingReply => '답변 대기';

  @override
  String heldUntilP0(Object p0) => '${p0}까지 보류';

  @override
  String get declined2 => '거절됨';

  @override
  String get closed => '종료됨';

  @override
  String get theyWantReserveBook => '회원님의 도서에 예약 요청이 도착했습니다';

  @override
  String get sentReservationRequest => '예약 요청을 보냈습니다';

  @override
  String holdP0H(Object p0) => '${p0}시간 보류';

  @override
  String get holdPeriod => '보류 기간';

  @override
  String get messageSellerOptional => '판매자에게 전할 말 (선택)';

  @override
  String get sendRequest => '예약 보내기';

  @override
  String p0Hours(Object p0) => '${p0}시간';

  @override
  String p0P1DigitsEntered(Object p0, Object p1) => '${p0} / ${p1}자리 입력됨';

  @override
  String get buildSProvisioningProfileDoesnT => '이 빌드의 프로비저닝 프로필에 푸시 알림 권한이 없습니다. Xcode의 Runner › Signing & Capabilities에 Push Notifications가 있는지 확인한 뒤 앱을 삭제하고 다시 설치하세요.';

  @override
  String get checkPhoneOnlinePushNotificationsAdded => '휴대폰이 네트워크에 연결되어 있는지, Xcode의 Runner › Signing & Capabilities에 Push Notifications가 있는지 확인하세요.';

  @override
  String iphoneFailedRegisterPushNotificationsWith(Object p0, Object p1) => 'iPhone의 Apple 푸시 알림 등록에 실패했습니다: ${p0}\n${p1}';

  @override
  String get serverNotBeenUpdatedSupportFeature => '이 기능은 일시적으로 사용할 수 없습니다. 잠시 후 다시 시도하세요.';

  @override
  String get someFeaturesTemporarilyUnavailableWhileServer => '일부 기능을 일시적으로 사용할 수 없습니다';

  @override
  String serverRunningOutdatedApiRevisionP0(Object p0, Object p1) => '서버의 API 버전이 오래되었습니다(현재 ${p0}, 앱에 필요한 버전 ${p1}). 서버 코드를 업데이트하고 API를 재시작하세요.';

  @override
  String databaseMigrationsNotYetRunP0(Object p0) => '아직 실행하지 않은 데이터베이스 마이그레이션: ${p0}';

  @override
  String serverVersionP0(Object p0) => '서버 현재 버전: ${p0}';

  @override
  String get runNpmRunVerifyApiDirectory => '서버의 API 디렉터리에서 npm run verify를 실행하면 전체 배포 상태를 확인할 수 있습니다.';

  @override
  String get serverUpdateRequired => '서버 업데이트 필요';

  @override
  String versionP0(Object p0) => '버전 ${p0}';

  @override
  String get requiresUserConsent => '사용자 동의 필요';

  @override
  String get unsavedDraft => '저장되지 않은 임시 저장본';

  @override
  String get allBooks => '전체 도서';

  @override
  String get results => '필터 결과';

  @override
  String get sortBy => '정렬 기준';

  @override
  String get themeColour => '테마 색상';

  @override
  String get forestGreen => '포레스트 그린';

  @override
  String get oceanBlue => '오션 블루';

  @override
  String get lavender => '라벤더';

  @override
  String get terracotta => '테라코타';

  @override
  String get amber => '앰버';

  @override
  String get rose => '로즈';

  @override
  String get graphite => '그래파이트';

  @override
  String get mistBlue => '미스트 블루';

  @override
  String get draftRestored => '임시 저장본을 복원했습니다';

  @override
  String get convertSections => '장 모드로 변환';

  @override
  String get currentContentDoesNotFullyMatch => '현재 내용이 장 서식과 완전히 일치하지 않습니다. 변환하면 장 번호가 순서대로 다시 생성되어 "1. 제목" 형식으로 통일되며, 제목으로 인식되지 않은 단락은 서문 또는 이전 장 본문에 합쳐집니다.\n\n원래 서식을 유지하려면 일반 텍스트 모드에서 계속 편집하고 저장하세요.';

  @override
  String get convert => '변환';

  @override
  String get keepPlainText => '일반 텍스트 유지';

  @override
  String get noSectionHeadingsDetectedFullText => '감지된 장 제목이 없어 전체 내용을 서문에 배치했습니다';

  @override
  String deletedP0(Object p0) => '"${p0}"을(를) 삭제했습니다';

  @override
  String get renameSection => '장 이름 변경';

  @override
  String get editContent => '내용 편집';

  @override
  String get rename => '이름 변경';

  @override
  String get addSectionBelow => '아래에 장 추가';

  @override
  String get moveUp => '위로 이동';

  @override
  String get moveDown => '아래로 이동';

  @override
  String get enterDocumentTitle => '문서 제목을 입력하세요';

  @override
  String get enterDocumentContent => '문서 내용을 입력하세요';

  @override
  String p0NowVersionP1(Object p0, Object p1) => '${p0} (현재 버전 ${p1})';

  @override
  String versionP0P1(Object p0, Object p1) => '버전 ${p0} · ${p1}';

  @override
  String unsavedDraftFromP0Found(Object p0) => '${p0}에 저장되지 않은 임시 저장본이 있습니다';

  @override
  String get documentWasUpdatedAfterDraftWas => '임시 저장본 생성 후 문서가 업데이트되었습니다. 복원하면 현재 내용이 임시 저장본으로 대체됩니다.';

  @override
  String get discardDraft => '임시 저장본 삭제';

  @override
  String get restoreDraft => '임시 저장본 복원';

  @override
  String get sectionTitleRequired => '장 제목을 입력하세요';

  @override
  String get documentSFormatDoesNotFully => '이 문서의 서식이 장 구조와 완전히 일치하지 않아 원래 서식을 유지하기 위해 일반 텍스트 모드로 열었습니다.';

  @override
  String get enterPasteFullTextHere => '여기에 전체 내용을 입력하거나 붙여 넣으세요.';

  @override
  String get noSectionHeadingsDetected => '감지된 장 제목이 없습니다';

  @override
  String p0SectionsDetected(Object p0) => '장 ${p0}개 감지됨';

  @override
  String get paragraphWhoseFirstLine1Title => '단락의 첫 줄이 "1. 제목", "一、제목" 또는 "第一條 제목"이면 장 제목으로 처리합니다.';

  @override
  String get sectionNumbersMustStart1Increase => '장 번호는 1부터 순서대로 증가해야 하며, 그렇지 않으면 이전 장의 본문으로 처리됩니다.';

  @override
  String get blankLineStartsNewParagraphSingle => '빈 줄은 단락을 구분하며, 한 줄 줄바꿈은 그대로 표시됩니다.';

  @override
  String get whenSwitchingSectionsAskedConfirmAny => '장 모드로 전환할 때 서식 조정이 필요하면 먼저 확인을 요청합니다.';

  @override
  String get howSectionHeadingsDetected => '장 제목 인식 방식';

  @override
  String get titleEdited => '제목 수정됨';

  @override
  String p0Added(Object p0) => '${p0}개 장 추가';

  @override
  String p0Removed(Object p0) => '${p0}개 장 삭제';

  @override
  String p0Edited(Object p0) => '${p0}개 장 수정';

  @override
  String get sectionsReordered => '장 순서 변경됨';

  @override
  String get preambleEdited => '서문 수정됨';

  @override
  String get contentEdited => '내용 수정됨';

  @override
  String p0Characters2(Object p0) => '글자 수 +${p0}';

  @override
  String p0Characters3(Object p0) => '글자 수 ${p0}';

  @override
  String get formattingAdjusted => '서식 조정';

  @override
  String get createdAsVersion1 => '버전 1로 생성';

  @override
  String staysVersionP0(Object p0) => '버전 ${p0} 유지';

  @override
  String versionP0P12(Object p0, Object p1) => '버전 ${p0} → ${p1}';

  @override
  String get substantiveChangesRightsObligationsTermsAll => '권리·의무 또는 약관 내용의 실질적인 변경에 사용합니다. 모든 사용자에게 알리며, 사용자는 다음에 앱을 열 때 다시 확인하고 동의해야 합니다.';

  @override
  String get substantiveContentChangesAllUsersNotified => '내용의 실질적인 변경에 사용합니다. 모든 사용자에게 알립니다.';

  @override
  String saveP0(Object p0) => '"${p0}" 저장';

  @override
  String get summaryChanges => '변경 요약';

  @override
  String get updateType => '업데이트 방식';

  @override
  String get fixingTyposFormattingUsersNotNotified => '오타 수정이나 서식 조정에 사용합니다. 사용자에게 알리지 않습니다.';

  @override
  String get contentUnchangedTitleOnlyChangeCannot => '내용이 변경되지 않았습니다. 제목만 변경한 경우 주요 업데이트로 지정할 수 없습니다.';

  @override
  String get notificationsSentImmediatelyAfterSubmittingCannot => '제출 즉시 알림이 발송되며 취소할 수 없습니다.';

  @override
  String get publishNotify => '게시 및 알림';

  @override
  String sectionP0(Object p0) => '제${p0}장';

  @override
  String get goSection => '장으로 이동';

  @override
  String get sectionContent => '장 내용';

  @override
  String get previous => '이전 장';

  @override
  String get next2 => '다음 장';

  @override
  String get unableGenerateProfileQrCodeTry => '프로필 QR 코드를 생성할 수 없습니다. 잠시 후 다시 시도하세요.';

  @override
  String get myQrCode => '내 QR 코드';

  @override
  String get markAsRead => '읽음으로 표시';

  @override
  String get unblock => '차단 해제';

  @override
  String afterUnblockingP0CanSendMessages(Object p0) => '차단을 해제하면 "${p0}" 님과 다시 메시지를 주고받을 수 있습니다.';

  @override
  String get userUnblocked => '차단을 해제했습니다';

  @override
  String get unableLoadBlockedUsers => '차단 목록을 불러올 수 없습니다';

  @override
  String get notBlockedAnyUsers => '차단한 사용자가 없습니다';

  @override
  String get blockedUsers => '차단 목록';

  @override
  String get blockUser => '사용자 차단';

  @override
  String afterBlockP0NeitherCanSend(Object p0) => '"${p0}" 님을 차단하면 서로 메시지를 보낼 수 없습니다.';

  @override
  String get block => '차단';

  @override
  String get userBlocked => '사용자를 차단했습니다';

  @override
  String get moreOptions => '더보기';

  @override
  String get blockedUser => '이 사용자를 차단했습니다';

  @override
  String get originalMessageNotFound => '원본 메시지를 찾을 수 없습니다';

  @override
  String get you2 => '나';

  @override
  String get viewProfile => '프로필 보기';

  @override
  String get reply => '답장';

  @override
  String get bookLockerScanQrCodeLocker => '책이 보관함에 보관되었습니다. 보관함 기기의 QR 코드를 스캔해 수령하세요.';

  @override
  String get originalMessageUnavailable => '원본 메시지를 표시할 수 없습니다';

  @override
  String get cancelReply => '답장 취소';

  @override
  String get unreadMessages => '여기부터 읽지 않은 메시지';

  @override
  String get selectChat => '채팅을 선택하세요';

  @override
  String get appPermissions => '앱 권한';

  @override
  String get noPermissionsRequiredDevice => '이 기기에서 허용이 필요한 항목이 없습니다';

  @override
  String get allowAll => '모두 허용';

  @override
  String get camera => '카메라';

  @override
  String get photosRead => '사진 (읽기)';

  @override
  String get photosSave => '사진 (저장)';

  @override
  String get microphone => '마이크';

  @override
  String get location => '위치';

  @override
  String get orderUpdatesChatMessagesAnnouncements => '주문 진행 상황, 채팅 메시지 및 공지';

  @override
  String get scanBarcodesTakeBookPhotos => '바코드 스캔 및 책 사진 촬영';

  @override
  String get chooseBookPhotosProfilePicturesChat => '책 사진, 프로필 사진 및 채팅 이미지 선택';

  @override
  String get saveQrCodesPhotos => 'QR 코드를 사진에 저장';

  @override
  String get recordVoiceMessagesChats => '채팅 음성 메시지 녹음';

  @override
  String get showNearestSmartLockersTheirDistance => '가장 가까운 스마트 보관함과 거리 표시';

  @override
  String get quickSignPaymentConfirmation => '빠른 로그인 및 결제 확인';

  @override
  String get allowed => '허용됨';

  @override
  String get limited => '일부 허용';

  @override
  String get notAllowed => '허용 안 됨';

  @override
  String get restricted => '시스템에 의해 제한됨';

  @override
  String get denied => '거부됨';

  @override
  String get allow => '허용';

  @override
  String get homeRecommendations => '홈 추천 영역';

  @override
  String get leaveGroup => '그룹 나가기';

  @override
  String leaveP0(Object p0) => '"${p0}"에서 나갈까요?';

  @override
  String get leave => '나가기';

  @override
  String get leftGroup => '그룹에서 나갔습니다';

  @override
  String get unpin => '고정 해제';

  @override
  String get pin => '고정';

  @override
  String get you3 => '나';

  @override
  String get canOnlyEditMessagesSentWithin => '보낸 지 15분 이내의 메시지만 수정할 수 있습니다';

  @override
  String p0UnsentMessage(Object p0) => '${p0} 님이 메시지를 취소했습니다';

  @override
  String readByP0(Object p0) => '${p0}명 읽음';

  @override
  String get transferDetailsUnavailable => '송금 정보를 표시할 수 없습니다';

  @override
  String get couldNotCreateGroup => '그룹을 만들 수 없습니다';

  @override
  String get groupDetails => '그룹 정보';

  @override
  String get selectMembers => '멤버 선택';

  @override
  String get groupName => '그룹 이름';

  @override
  String membersP0(Object p0) => '멤버 ${p0}';

  @override
  String get createGroup => '그룹 만들기';

  @override
  String get inviteMembers => '멤버 초대';

  @override
  String get invite => '초대';

  @override
  String canSelectUpP0People(Object p0) => '최대 ${p0}명까지 선택할 수 있습니다';

  @override
  String get noChatsChooseFrom => '선택할 수 있는 대화 상대가 없습니다';

  @override
  String get noMatchingPeople => '일치하는 사람이 없습니다';

  @override
  String get searchByName => '이름 검색';

  @override
  String get chatPinned => '채팅을 고정했습니다';

  @override
  String get unpinned => '고정을 해제했습니다';

  @override
  String get setNickname => '별명 설정';

  @override
  String get onlyVisible => '나에게만 표시';

  @override
  String get nicknameRemoved => '별명을 삭제했습니다';

  @override
  String get nicknameUpdated => '별명을 변경했습니다';

  @override
  String get enterGroupName => '그룹 이름을 입력하세요';

  @override
  String get groupNameUpdated => '그룹 이름을 변경했습니다';

  @override
  String get groupPhotoUpdated => '그룹 사진을 변경했습니다';

  @override
  String get groupReachedMemberLimit => '그룹 멤버 수가 한도에 도달했습니다';

  @override
  String invitedP0Members(Object p0) => '${p0}명을 초대했습니다';

  @override
  String get removeMember => '멤버 내보내기';

  @override
  String removeP0FromGroup(Object p0) => '"${p0}" 님을 그룹에서 내보낼까요?';

  @override
  String get memberRemoved => '멤버를 내보냈습니다';

  @override
  String get chatSettings => '채팅 설정';

  @override
  String get muteNotifications => '알림 끄기';

  @override
  String get pinChat => '채팅 고정';

  @override
  String get me => '나';

  @override
  String requestedFromP0(Object p0) => '${p0} 님에게 송금 요청';

  @override
  String p0RequestedPaymentFrom(Object p0) => '${p0} 님이 송금을 요청했습니다';

  @override
  String p0RequestedPaymentFromP1(Object p0, Object p1) => '${p0} 님이 ${p1} 님에게 송금 요청';

  @override
  String sentP0(Object p0) => '${p0} 님에게 송금';

  @override
  String p0SentCoins(Object p0) => '${p0} 님이 송금했습니다';

  @override
  String p0SentCoinsP1(Object p0, Object p1) => '${p0} 님이 ${p1} 님에게 송금';

  @override
  String get expired2 => '만료됨';

  @override
  String get payNow => '지금 결제';

  @override
  String get cancelRequest => '요청 취소';

  @override
  String get request => '송금 요청';

  @override
  String get transfer => '송금';

  @override
  String dueP0(Object p0) => '기한 ${p0}';

  @override
  String transferP0(Object p0) => '${p0} 님에게 송금';

  @override
  String sentP0CoinsP1(Object p0, Object p1) => '${p0} 님에게 ${p1} 코인을 송금했습니다';

  @override
  String get confirmPayment => '결제 확인';

  @override
  String payP0CoinsP1(Object p0, Object p1) => '${p0} 님에게 ${p1} 코인을 결제합니다';

  @override
  String get declineRequest => '요청 거절';

  @override
  String declineP1CoinRequestFromP0(Object p0, Object p1) => '${p0} 님의 ${p1} 코인 요청을 거절합니다';

  @override
  String cancelRequestP0P1Coins(Object p0, Object p1) => '${p0} 님에게 요청한 ${p1} 코인을 취소합니다';

  @override
  String payRequestFromP0(Object p0) => '${p0} 님의 요청 결제';

  @override
  String get paymentCompleted => '결제를 완료했습니다';

  @override
  String get requestDeclined => '요청을 거절했습니다';

  @override
  String get requestCanceled => '요청을 취소했습니다';

  @override
  String get selectPayer => '결제자를 선택하세요';

  @override
  String get selectRecipient => '받는 사람을 선택하세요';

  @override
  String get sendRequest2 => '요청 보내기';

  @override
  String get confirmTransfer => '송금 확인';

  @override
  String get payer => '결제자';

  @override
  String get recipient => '받는 사람';

  @override
  String limitPerTransferP0Coins(Object p0) => '1회 한도 ${p0} 코인';

  @override
  String insufficientBalanceP0Coins(Object p0) => '잔액 부족(${p0} 코인)';

  @override
  String balanceP0Coins(Object p0) => '잔액 ${p0} 코인';

  @override
  String get noteOptional => '메모(선택)';

  @override
  String get editMessage => '메시지 편집';

  @override
  String get cancelEditing => '편집 취소';

  @override
  String get send => '전송';

  @override
  String get switchKeyboard => '키보드로 전환';

  @override
  String get voiceMessage => '음성 메시지';

  @override
  String get edited => '수정됨';

  @override
  String get maximumRecordingLengthReached => '최대 녹음 시간에 도달했습니다';

  @override
  String get recordingTooShort => '녹음 시간이 너무 짧습니다';

  @override
  String p0SRemaining(Object p0) => '${p0}초 남음';

  @override
  String get releaseSend => '손을 떼면 전송됩니다';

  @override
  String get recording => '녹음 중';

  @override
  String get tapHoldRecord => '탭하거나 길게 눌러 녹음';

  @override
  String get stopRecording => '녹음 중지';

  @override
  String get preview2 => '미리 듣기';

  @override
  String get startRecording => '녹음 시작';

  @override
  String get microphoneUnavailable => '마이크를 사용할 수 없습니다';

  @override
  String get paymentRequest => '[송금 요청]';

  @override
  String get transfer2 => '[송금]';

  @override
  String get transfer3 => '받은 송금';

  @override
  String get transferOut => '보낸 송금';

  @override
  String get deleteBook => '도서 삭제';

  @override
  String p0PermanentlyDeletedCannotRestoredSeller(Object p0) => '"${p0}"이(가) 영구 삭제되며 복구할 수 없습니다. 판매자에게 알림이 전송됩니다.';

  @override
  String get reasonDeletionOptional => '삭제 사유(선택)';

  @override
  String get bookDeleted2 => '도서를 삭제했습니다';

  @override
  String get rotate => '회전';

  @override
  String get mentioned => '[나를 언급]';

  @override
  String get saveImage => '이미지 저장';

  @override
  String get everyone => '모두';

  @override
  String get mentionMembers => '멤버 언급';

  @override
  String get removeAdminRole => '관리자 권한 해제';

  @override
  String makeP0Admin(Object p0) => '${p0} 님을 관리자로 지정하시겠습니까?';

  @override
  String removeAdminRoleFromP0(Object p0) => '${p0} 님의 관리자 권한을 해제하시겠습니까?';

  @override
  String get remove2 => '해제';

  @override
  String p0NowAdmin(Object p0) => '${p0} 님을 관리자로 지정했습니다';

  @override
  String removedAdminRoleFromP0(Object p0) => '${p0} 님의 관리자 권한을 해제했습니다';

  @override
  String photosP02(Object p0) => '[사진 ${p0}장]';

  @override
  String get savedDownloads => '다운로드 폴더에 저장했습니다';

  @override
  String get couldNotSaveImage => '이미지를 저장할 수 없습니다';

  @override
  String savingImagesP0P1(Object p0, Object p1) => '이미지 저장 중 ${p0} / ${p1}';

  @override
  String get savingImage => '이미지 저장 중';

  @override
  String get passwordsCanOnlyContainEnglishLetters => '비밀번호에는 영문, 숫자, 반각 기호만 사용할 수 있습니다';

  @override
  String get aiSupport => 'AI 고객센터';

  @override
  String get howDoIListBook => '책은 어떻게 등록하나요?';

  @override
  String get howDoIPickUpFrom => '보관함에서 책을 수령하려면?';

  @override
  String get howDoIRequestRefund => '환불은 어떻게 신청하나요?';

  @override
  String get howDoWalletCoinsWork => '코인은 어떻게 사용하나요?';

  @override
  String get talkPerson => '상담원 연결';

  @override
  String get supportRequestCreatedFromConversationOur => '상담원에게 연결되며 현재 대화 내용이 전달됩니다';

  @override
  String get transfer4 => '연결';

  @override
  String get creatingSupportRequest => '상담원에게 연결하는 중';

  @override
  String get transferredSupportTeam => '상담원에게 연결되었습니다';

  @override
  String get newConversation => '새 대화';

  @override
  String get currentConversationEnd => '현재 대화가 종료됩니다';

  @override
  String get copied2 => '복사했습니다';

  @override
  String get howCanWeHelp => '무엇을 도와드릴까요?';

  @override
  String get failedSend => '전송 실패';

  @override
  String get ourSupportTeamCanHelpWith => '이 문의는 상담원의 도움을 받는 것이 좋습니다';

  @override
  String get contactSupport => '고객센터 문의';

  @override
  String get typeQuestion => '질문 입력';

  @override
  String get aiFeatures => 'AI 기능';

  @override
  String get aiSettingsNotSavedChangesLost => 'AI 설정이 저장되지 않았습니다. 나가면 변경 사항이 사라집니다';

  @override
  String get usage => '사용량';

  @override
  String reviewP0(Object p0) => '심사 ${p0}';

  @override
  String get dailyCost => '일별 비용';

  @override
  String get noCostPeriod => '이 기간에는 비용이 없습니다';

  @override
  String get peakDay => '일 최고';

  @override
  String p0Requests(Object p0) => '요청 ${p0}회';

  @override
  String get listingAssist => '등록 도우미';

  @override
  String get recommendations => '추천 도서';

  @override
  String get listingReview => '등록 심사';

  @override
  String get connectionTest => '연결 테스트';

  @override
  String get today2 => '오늘';

  @override
  String get k7Days => '7일';

  @override
  String get k30Days => '30일';

  @override
  String get notBookUnrelatedItem => '도서가 아니거나 무관한 상품';

  @override
  String get prohibitedPiratedContent => '금지 또는 불법 복제 콘텐츠';

  @override
  String get adultContent => '성인 콘텐츠';

  @override
  String get offPlatformDealContactInfo => '외부 거래 또는 연락처 정보';

  @override
  String get misleadingDescription => '허위 설명';

  @override
  String get unusualPrice => '비정상적인 가격';

  @override
  String get providerError => '서비스 제공자 오류';

  @override
  String get timedOut => '시간 초과';

  @override
  String get noApiKey => 'API 키 없음';

  @override
  String get rateLimited => '요청 제한';

  @override
  String get invalidApiKey => '유효하지 않은 API 키';

  @override
  String get invalidResponseFormat => '응답 형식 오류';

  @override
  String get rejectListing => '등록 거절';

  @override
  String get noteOptionalSentSeller => '메모 (선택, 판매자에게 전달)';

  @override
  String get reject => '거절';

  @override
  String get listingApproved => '등록을 승인했습니다';

  @override
  String get listingRejected => '등록을 거절했습니다';

  @override
  String get noListingsAwaitingReview => '심사 대기 중인 등록이 없습니다';

  @override
  String get likelyViolation => '위반 의심';

  @override
  String get needsReview => '확인 필요';

  @override
  String get rejected => '거절됨';

  @override
  String get approve => '승인';

  @override
  String get pleaseFixHighlightedFields => '오류가 표시된 항목을 수정하세요';

  @override
  String get aiSettingsSaved => 'AI 설정을 저장했습니다';

  @override
  String get invalidFormat => '형식이 올바르지 않습니다';

  @override
  String enter0P0(Object p0) => '0~${p0} 사이로 입력하세요';

  @override
  String get databaseNotBeenUpdatedAiYet => '데이터베이스의 AI 업데이트가 완료되지 않아 저장한 설정이 아직 적용되지 않습니다';

  @override
  String get defaultModel => '기본 모델';

  @override
  String get features => '기능';

  @override
  String get on => '사용 중';

  @override
  String get noProviderApiKeysSetSo => '서비스 제공자 API 키가 없어 AI 기능을 사용할 수 없습니다';

  @override
  String p0NoApiKeyCannotSelected(Object p0) => '${p0}에 API 키가 없어 선택할 수 없습니다';

  @override
  String get input => '입력';

  @override
  String get output => '출력';

  @override
  String get per1mTokens => '100만 토큰당';

  @override
  String get vision => '이미지 인식';

  @override
  String get webSearch => '웹 검색';

  @override
  String get testing => '테스트 중';

  @override
  String get test => '연결 테스트';

  @override
  String connectedP0Ms(Object p0) => '연결 성공・${p0} ms';

  @override
  String get connectionFailed => '연결 실패';

  @override
  String get keySet => '키 설정됨';

  @override
  String get noKey => '키 없음';

  @override
  String get model => '사용 모델';

  @override
  String defaultP0(Object p0) => '기본값 (${p0})';

  @override
  String p0NoApiKey(Object p0) => '${p0}에 API 키가 없습니다';

  @override
  String p0DoesNotSupportWebSearch(Object p0) => '${p0}은(는) 웹 검색을 지원하지 않습니다';

  @override
  String get searchNotBilledSeparately => '검색은 별도로 과금되지 않습니다';

  @override
  String firstP0SearchesFreeEachMonth(Object p0, Object p1) => '매월 ${p0}회까지 무료, 이후 1,000회당 ${p1}';

  @override
  String p0Per1000SearchesPlus(Object p0) => '검색 1,000회당 ${p0}, 검색 내용 토큰은 별도';

  @override
  String get suspiciousListings => '의심 상품 처리 방식';

  @override
  String get holdReview => '심사로 보내기';

  @override
  String get rejectClearViolations => '명백한 위반은 바로 거절';

  @override
  String get budgetLimits => '예산 및 한도';

  @override
  String get monthlyBudgetUsd => '월 예산 (USD)';

  @override
  String get k0MeansNoCap => '0은 한도 없음';

  @override
  String get dailyLimitPerMember => '회원당 일일 한도';

  @override
  String get k0MeansUnlimited => '0은 무제한';

  @override
  String get advanced => '고급 설정';

  @override
  String get resetDefault => '기본값으로 재설정';

  @override
  String get modelId => '모델 ID';

  @override
  String get priceUsPer1mTokens => '단가 (US\$ / 100만 토큰)';

  @override
  String get cachedInput => '캐시 입력';

  @override
  String get searchPriceUsPer1000 => '검색 단가 (US\$ / 1,000회)';

  @override
  String get freeSearchesPerMonth => '월 무료 검색 횟수';

  @override
  String p0FieldsInvalid(Object p0) => '${p0}개 항목의 형식이 올바르지 않습니다';

  @override
  String p0UnsavedChanges(Object p0) => '저장되지 않은 설정 ${p0}개';

  @override
  String get unsavedChanges => '저장되지 않은 변경 사항이 있습니다';

  @override
  String get month2 => '이번 달 비용';

  @override
  String budgetP0(Object p0) => '예산 ${p0}';

  @override
  String get noMonthlyBudget => '월 예산 없음';

  @override
  String projectedP0(Object p0) => '월말 예상 ${p0}';

  @override
  String get periodCost => '기간 비용';

  @override
  String get requests => '요청 수';

  @override
  String p0Searches(Object p0) => '검색 ${p0}회';

  @override
  String p0OutP1(Object p0, Object p1) => '입력 ${p0}・출력 ${p1}';

  @override
  String get errors => '오류';

  @override
  String errorRateP0(Object p0) => '오류율 ${p0}%';

  @override
  String p0ListingsAwaitingReview(Object p0) => '심사 대기 등록 ${p0}건';

  @override
  String get byFeature => '기능별';

  @override
  String get noDataYet => '데이터가 없습니다';

  @override
  String errorsP0(Object p0) => '오류 ${p0}';

  @override
  String p0Calls(Object p0) => '${p0}회';

  @override
  String get byModel => '모델별';

  @override
  String p0CallsP1Ms(Object p0, Object p1) => '${p0}회・${p1} ms';

  @override
  String get topMembers => '사용량 상위 회원';

  @override
  String p0Uses(Object p0) => '${p0}회 사용';

  @override
  String get recentErrors => '최근 오류';

  @override
  String get noErrors => '오류 없음';

  @override
  String get fillWithAi => 'AI로 채우기';

  @override
  String get summary => '소개';

  @override
  String get lookingUpBookDetails => '도서 정보 조회';

  @override
  String get searchingWeb => '웹에서 추가 정보 검색';

  @override
  String get analyzingPhotos => '사진 분석';

  @override
  String get suggestingCategoryConditionPrice => '카테고리, 상태, 가격 판단';

  @override
  String get couldNotGetAiSuggestions => 'AI 제안을 가져올 수 없습니다';

  @override
  String get done => '분석 완료';

  @override
  String get aiAnalyzing => 'AI 분석 중';

  @override
  String get aiSuggestions => 'AI 제안';

  @override
  String get noSuggestionsApply => '적용할 제안이 없습니다';

  @override
  String get bookDetails => '도서 정보';

  @override
  String get suggestedPrice => '추천 가격';

  @override
  String rangeP0P1(Object p0, Object p1) => '추천 범위 \$${p0}~\$${p1}';

  @override
  String listPriceP0(Object p0) => '정가 \$${p0}';

  @override
  String applyP0(Object p0) => '${p0}개 적용';

  @override
  String currentP0(Object p0) => '현재: ${p0}';

  @override
  String get sameAsCurrent => '현재와 같음';

  @override
  String get listingNotApproved => '등록 심사를 통과하지 못했습니다';

  @override
  String get editListing => '내용 수정';

  @override
  String get submittedReview => '심사 요청됨';

  @override
  String get goSaleOnceApprovedNotifiedResult => '승인 후 판매가 시작됩니다';

  @override
  String get got => '확인';

  @override
  String get aiFeaturesNotAvailableRightNow => 'AI 기능을 현재 사용할 수 없습니다';

  @override
  String get bookUnderReviewGoSaleOnce => '이 도서는 심사 중이며 승인되면 판매가 시작됩니다';

  @override
  String get notApproved => '심사 미통과';

  @override
  String get bookDidNotPassListingReview => '이 도서는 등록 심사를 통과하지 못했습니다';

  @override
  String get enterIsbnTitleFirst => '먼저 ISBN 또는 제목을 입력하세요';

  @override
  String appliedP0AiSuggestions(Object p0) => 'AI 제안 ${p0}개를 적용했습니다';

  @override
  String get addBookPhotosFirst => '먼저 도서 사진을 추가하세요';

  @override
  String get nothingFoundFillCheckIsbnTitle => '채울 수 있는 정보를 찾지 못했습니다. ISBN 또는 제목을 확인하세요';

  @override
  String appliedP0AiSuggestions2(Object p0) => 'AI 제안 ${p0}개를 적용했습니다';

  @override
  String get aiDataProcessingEnabled => 'AI 데이터 처리에 동의했습니다';

  @override
  String get aiDataProcessingTurnedOff => 'AI 데이터 처리를 중지했습니다';

  @override
  String get aiDataProcessing => 'AI 데이터 처리';

  @override
  String get messagesEnterStatusOrdersReservations => '입력한 메시지와 본인의 주문 및 예약 상태';

  @override
  String get isbnTitleConditionNotesPhotosSelect => 'ISBN, 도서명, 상태 설명 및 선택한 사진';

  @override
  String get bookDetailsFromFavoritesPurchaseHistory => '찜 목록과 구매 내역에 포함된 도서 정보';

  @override
  String get aiDataProcessing2 => 'AI 데이터 처리 안내';

  @override
  String get whenUseAiFeaturesWeShare => 'AI 기능을 사용할 때 아래 데이터를 제3자 AI 서비스 제공업체에 제공하여 처리합니다.';

  @override
  String get dataShared => '제공하는 데이터';

  @override
  String get recipients => '데이터 수신자';

  @override
  String get purpose => '이용 목적';

  @override
  String get usedOnlyGenerateSupportRepliesPrepare => '고객센터 답변 생성, 등록 정보 정리 및 도서 추천에만 사용하며 광고나 추적에는 사용하지 않습니다.';

  @override
  String get withdrawingConsent => '동의 철회';

  @override
  String get canTurnOffAiDataProcessing => '설정 › 계정 관리에서 언제든지 「AI 데이터 처리」를 끌 수 있으며, 끄면 위 데이터는 더 이상 제공되지 않습니다.';

  @override
  String get agreeContinue => '동의';

  @override
  String get insufficientQuotaPlanNotEnabled => '할당량 부족 또는 요금제 미사용';

  @override
  String get modelNotFound => '모델 이름이 없습니다';

  @override
  String get invalidRequestParameters => '요청 매개변수가 올바르지 않습니다';

  @override
  String get couldNotConnectService => '서비스에 연결할 수 없습니다';

  @override
  String get blockedByProviderSafetySystem => '서비스 안전 기능에 의해 거부됨';

  @override
  String get responseExceededOutputLimit => '응답이 출력 한도를 초과했습니다';

  @override
  String get serverProcessingError => '서버 처리 오류';

  @override
  String get aiBookAdvisor => 'AI 도서 어드바이저';

  @override
  String get requiresDatabaseUpdate013 => '데이터베이스 업데이트 013 필요';

  @override
  String get mysteryNovelMyCommute => '출퇴근길에 읽기 좋은 추리 소설';

  @override
  String get programmingBooksBeginners => '입문자를 위한 프로그래밍 책';

  @override
  String get booksUnder200Coins => '200 코인 이하의 책';

  @override
  String get popularLiteraryFictionRightNow => '요즘 인기 있는 문학 소설';

  @override
  String get tellMeWhatBookLooking => '찾으시는 책을 설명해 주세요';

  @override
  String get describeBookLooking => '찾으시는 책을 설명해 주세요';

  @override
  String get tellMeWhatWantReadI => '원하시는 조건에 맞춰 책을 추천합니다';

  @override
  String get subtitle => '부제';

  @override
  String get monthOnly => '월까지만 확인';

  @override
  String get yearOnly => '연도까지만 확인';

  @override
  String get msg => '繁體中文';

  @override
  String get additionalInformation => '추가 정보';

  @override
  String get readFull => '전문 보기';

  @override
  String get pages => '페이지 수';

  @override
  String get simplifiedChinese => '중국어 간체';

  @override
  String get chinese => '중국어';

  @override
  String get english => '영어';

  @override
  String get japanese => '일본어';

  @override
  String get korean => '한국어';

  @override
  String p0Pages(Object p0) => '${p0} 페이지';

  @override
  String get collapse => '접기';

  @override
  String get setPasswordFirst => '먼저 비밀번호를 설정하세요';

  @override
  String get setPassword => '비밀번호 설정';

  @override
  String get signMethodSettingsSaved => '로그인 방식 설정을 저장했습니다';

  @override
  String get signMethodSettingsUnsavedLeavingDiscards => '로그인 방식 설정이 저장되지 않았습니다. 나가면 변경 내용이 사라집니다.';

  @override
  String get serverNotRunDatabaseUpdate014 => '서버에서 데이터베이스 업데이트 014를 실행하지 않아 설정이 아직 적용되지 않습니다.';

  @override
  String get signChannels => '로그인 방식 목록';

  @override
  String get socialSmsSign => '소셜 및 SMS 로그인';

  @override
  String get whenOffSignPageHidesThese => '끄면 로그인 화면에 표시되지 않으며, 연결된 계정은 비밀번호로 로그인할 수 있습니다.';

  @override
  String get notConfigured => '미설정';

  @override
  String get allowCreatingNewAccountsWithMethod => '이 방식으로 신규 가입 허용';

  @override
  String get unsavedChanges2 => '저장하지 않은 변경';

  @override
  String get taiwan => '중화민국(대만)';

  @override
  String get hongKong => '홍콩';

  @override
  String get macau => '마카오';

  @override
  String get china => '중화인민공화국';

  @override
  String get japan => '일본';

  @override
  String get southKorea => '대한민국';

  @override
  String get singapore => '싱가포르';

  @override
  String get malaysia => '말레이시아';

  @override
  String get unitedStatesCanada => '미국／캐나다';

  @override
  String get unitedKingdom => '영국';

  @override
  String get australia => '호주';

  @override
  String get countryCode => '국가 번호';

  @override
  String get enterValidMobileNumber => '올바른 휴대전화 번호를 입력하세요';

  @override
  String get couldNotSendCodePleaseTry => '인증번호를 보내지 못했습니다. 잠시 후 다시 시도하세요.';

  @override
  String get linkMobileNumber => '휴대전화 번호 연결';

  @override
  String get signWithMobileNumber => '휴대전화 번호로 로그인';

  @override
  String get k6DigitCodeSentNumberMessage => '이 번호로 6자리 인증번호를 보냅니다.';

  @override
  String get mobileNumber => '휴대전화 번호';

  @override
  String get sendCode => '인증번호 보내기';

  @override
  String get codeIncorrectPleaseEnterAgain => '인증번호가 올바르지 않습니다. 다시 입력하세요.';

  @override
  String get codeBeenSentAgain => '인증번호를 다시 보냈습니다';

  @override
  String get enterCode => '인증번호 입력';

  @override
  String get enterSmsCode => 'SMS 인증번호 입력';

  @override
  String codeWasSentP0(Object p0) => '인증번호를 ${p0} 으로 보냈습니다';

  @override
  String canResendP0S(Object p0) => '${p0} 초 후 다시 보낼 수 있습니다';

  @override
  String get resendCode => '인증번호 다시 보내기';

  @override
  String get completeAccountDetails => '계정 정보 입력';

  @override
  String get p0DidNotProvideEmailAddress => '가입을 완료하려면 이메일을 입력하세요.';

  @override
  String signWithP0(Object p0) => '${p0} (으)로 로그인';

  @override
  String get signWith2 => '또는 다음 방법으로 로그인';

  @override
  String get creatingAccountWithMethodsAboveMeans => '위 방법으로 계정을 만들면 서비스 약관과 개인정보 처리방침에 동의한 것으로 간주됩니다.';

  @override
  String get emailAlreadyRegistered => '이미 등록된 이메일입니다';

  @override
  String get signWithPasswordThenLinkMethod => '비밀번호로 로그인한 뒤 계정 보안 › 로그인 방식에서 연결하세요.';

  @override
  String get signWithPassword => '비밀번호로 로그인';

  @override
  String get accountNoPasswordYet => '이 계정은 아직 비밀번호가 없습니다';

  @override
  String get passwordSet => '비밀번호를 설정했습니다';

  @override
  String get canNowSignWithEmailPassword => '다른 기기는 다시 로그인해야 합니다.';

  @override
  String get passwordRequiredBeforeCanUnlinkSign => '영문과 숫자를 포함해 8자 이상 입력하세요.';

  @override
  String get changingSignMethodsRequiresIdentityVerification => '로그인 방식을 변경하기 전에 비밀번호를 설정하세요.';

  @override
  String get later => '나중에 설정';

  @override
  String p0Linked(Object p0) => '${p0} 을(를) 연결했습니다';

  @override
  String unlinkP0(Object p0) => '${p0} 연결 해제';

  @override
  String get noLongerAbleSignWayCan => '연결을 해제하면 이 방식으로 로그인할 수 없습니다.';

  @override
  String get unlink => '연결 해제';

  @override
  String p0Unlinked(Object p0) => '${p0} 연결을 해제했습니다';

  @override
  String get socialSmsSignNotAvailableRight => '소셜 및 SMS 로그인은 현재 이용할 수 없습니다.';

  @override
  String get noSignMethodAvailableLink => '연결할 수 있는 로그인 방식이 없습니다.';

  @override
  String get noPasswordSet => '비밀번호 미설정';

  @override
  String linkedP0(Object p0) => '${p0} 연결';

  @override
  String get link => '연결';

  @override
  String get emailAlreadyRegisteredSignWithPassword => '이미 등록된 이메일입니다. 비밀번호로 로그인한 뒤 계정 보안에서 연결하세요.';

  @override
  String get provideEmailAddressCreateAccount => '계정을 만들려면 이메일 주소가 필요합니다';

  @override
  String get signMethodOnlyExistingAccounts => '이 로그인 방식은 기존 계정 전용입니다';

  @override
  String get signMethodNotAvailableRightNow => '이 로그인 방식은 현재 이용할 수 없습니다';

  @override
  String get credentialDoesNotMatchSelectedSign => '로그인에 실패했습니다. 다시 시도하세요.';

  @override
  String get signMethodLinkedAnotherAccount => '이 로그인 방식은 다른 계정에 연결되어 있습니다';

  @override
  String get accountAlreadyLinkedSignMethod => '이 계정은 이미 이 로그인 방식과 연결되어 있습니다';

  @override
  String get onlySignMethodAccountSetPassword => '이 계정의 유일한 로그인 방식입니다. 먼저 비밀번호를 설정하거나 다른 방식을 연결하세요.';

  @override
  String get socialSignUnavailableServerNotFinished => '소셜 로그인을 일시적으로 사용할 수 없습니다. 잠시 후 다시 시도하세요.';

  @override
  String get credentialInvalidExpiredPleaseTryAgain => '로그인 시간이 초과되었습니다. 다시 시도하세요.';

  @override
  String get accountAlreadyPasswordUseChangePassword => '이 계정에는 이미 비밀번호가 있습니다. 비밀번호 변경을 이용하세요.';

  @override
  String get signLinkExpiredPleaseTryAgain => '로그인 링크가 만료되었습니다. 다시 시도하세요.';

  @override
  String get signResultExpiredPleaseTryAgain => '로그인 시간이 초과되었습니다. 다시 시도하세요.';

  @override
  String get thirdPartySignServiceUnavailablePlease => '외부 로그인 서비스를 이용할 수 없습니다. 잠시 후 다시 시도하세요.';

  @override
  String get couldNotCompleteSignPleaseTry => '로그인을 완료하지 못했습니다. 다시 시도하세요.';

  @override
  String get accountNotLinkedSignMethod => '이 계정은 이 로그인 방식과 연결되어 있지 않습니다';

  @override
  String get mobileNumberFormatNotValid => '휴대전화 번호 형식이 올바르지 않습니다';

  @override
  String get verificationTimedOutRequestNewCode => '인증이 만료되었습니다. 인증번호를 다시 받으세요.';

  @override
  String get codeExpiredRequestNewOne => '인증번호가 만료되었습니다. 다시 받으세요.';

  @override
  String get tooManyAttemptsPleaseTryAgain => '시도 횟수가 너무 많습니다. 잠시 후 다시 시도하세요.';

  @override
  String get smsSendingLimitBeenReachedPlease => 'SMS 발송 횟수가 한도에 도달했습니다. 잠시 후 다시 시도하세요.';

  @override
  String get smsVerificationNotSetUpDevice => '이 기기에서는 SMS 인증을 사용할 수 없습니다. 다른 로그인 방식을 이용하세요.';

  @override
  String get couldNotCompleteSmsVerificationPlease => 'SMS 인증을 완료하지 못했습니다. 잠시 후 다시 시도하세요.';

  @override
  String get allowSigningLinkingWithMethod => '이 방식으로 로그인 및 연결 허용';

  @override
  String get appNeverStoresPasswordUsedOnly => '이 앱은 비밀번호를 저장하지 않으며 이번 인증에만 사용합니다。';

  @override
  String get verifyWithBiometricsInstead => '생체 인증으로 확인';

  @override
  String get accountWasCreatedWithSocialPhone => '이 계정은 로그인 비밀번호가 없습니다. 먼저 설정하세요.';

  @override
  String get setSignPassword => '로그인 비밀번호 설정';

  @override
  String get enterSignPasswordRunAdminAction => '관리자 작업을 실행하려면 로그인 비밀번호 또는 패스키로 본인 인증을 진행하세요';

  @override
  String p1P0MethodsEnabled(Object p0, Object p1) => '전체 ${p0}개 중 ${p1}개 사용 중';

  @override
  String get masterSwitchOffSoEveryMethod => '전체 스위치가 꺼져 있어 모든 방식이 비활성화됩니다';

  @override
  String get signLinkingDirectSignUpAllowed => '로그인, 연결, 신규 가입 가능';

  @override
  String credentialsNotSetPleaseConfigureP0(Object p0) => '자격 증명이 설정되지 않았습니다. 서버에서 ${p0} 을(를) 설정하세요';

  @override
  String get whenOffMethodHiddenFromSign => '끄면 로그인 화면과 계정 보안에 표시되지 않습니다';

  @override
  String get whenOffOnlyAccountsAlreadyLinked => '끄면 이미 연결된 계정만 사용할 수 있습니다';

  @override
  String get signMethodNotLinkedAccount => '이 로그인 방식은 계정에 연결되어 있지 않습니다';

  @override
  String p0AccountNotLinkedAnySavemybook(Object p0) => '이 ${p0} 계정은 SaveMyBook 계정과 연결되어 있지 않습니다.';

  @override
  String get iAlreadyAccountSignFirst => '기존 계정에 로그인하여 연결';

  @override
  String get createNewAccountWithIdentity => '새 계정 만들기';

  @override
  String signExistingAccountFirstThenLink(Object p0) => '기존 계정으로 먼저 로그인한 뒤 계정 보안 › 로그인 방식에서 ${p0}을(를) 연결하세요.';

  @override
  String get signMethodNotLinkedAnyAccount => '이 로그인 방식은 어떤 계정과도 연결되어 있지 않습니다';

  @override
  String get verifyIdentityWithPasskeyContinue => '계속하려면 패스키로 본인 인증을 진행하세요';

  @override
  String get verifyWithPasskeyInstead => '패스키로 인증';

  @override
  String get passkeys => '패스키';

  @override
  String get verifyWithFaceIdFingerprintScreen => '이 기기의 Face ID, 지문 또는 화면 잠금으로 인증합니다. 비밀번호가 필요하지 않습니다.';

  @override
  String get verifyWithPasskey => '패스키로 인증';

  @override
  String get useSignPasswordInstead => '로그인 비밀번호로 인증';

  @override
  String get signWithPasskey => '패스키로 로그인';

  @override
  String get passkeyAdded => '패스키가 추가되었습니다';

  @override
  String get screenLock => '화면 잠금';

  @override
  String fromNowCanSignVerifyIdentity(Object p0) => '이제 비밀번호를 입력하지 않고 ${p0}(으)로 로그인하고 본인 인증을 할 수 있습니다.';

  @override
  String get deletePasskey => '패스키 삭제';

  @override
  String get noLongerAbleSignVerifyIdentity => '삭제하면 이 패스키로 로그인하거나 본인 인증을 할 수 없습니다. 기기에 저장된 패스키는 함께 삭제되지 않으며 시스템 비밀번호 설정에서 삭제할 수 있습니다.';

  @override
  String get passkeyDeleted => '패스키가 삭제되었습니다';

  @override
  String get signVerifyIdentityWithFaceId => '비밀번호 대신 Face ID, 지문 또는 화면 잠금으로 로그인하고 본인 인증을 할 수 있습니다. 패스키는 사용자의 기기와 비밀번호 관리자에만 저장됩니다.';

  @override
  String get addPasskey => '패스키 추가';

  @override
  String get notUsedYet => '아직 사용하지 않음';

  @override
  String lastUsedFormatdateItemLastusedat(Object p0) => '마지막 사용 ${p0}';

  @override
  String createdCreated(Object p0) => '생성일 ${p0}';

  @override
  String get noPasskeyAvailableDeviceUsePassword => '이 기기에서 사용할 수 있는 패스키가 없습니다. 비밀번호를 사용해 주세요.';

  @override
  String get passkeyAlreadyRegisteredDevice => '이 기기에는 이미 패스키가 등록되어 있습니다.';

  @override
  String get signGoogleAccountTurnPasswordManager => '이 기기에서 Google 계정에 로그인하고 비밀번호 관리자를 켜거나 비밀번호를 사용해 주세요.';

  @override
  String get setUpScreenLockPasswordManager => '패스키를 만들려면 이 기기에서 화면 잠금 또는 비밀번호 관리자를 설정하세요.';

  @override
  String get deviceDoesNotSupportPasskeysUse => '이 기기는 패스키를 지원하지 않습니다. 비밀번호를 사용해 주세요.';

  @override
  String get passkeysTemporarilyUnavailableBecauseAppWebsite => '현재 패스키를 사용할 수 없습니다. 비밀번호를 사용하세요.';

  @override
  String get requestTimedOutPleaseTryAgain => '작업 시간이 초과되었습니다. 다시 시도해 주세요.';

  @override
  String get passkeyRequestFailedUsePasswordInstead => '패스키 작업에 실패했습니다. 비밀번호를 사용해 주세요.';

  @override
  String get verifyIdentityBeforeAddingPasskey => '패스키를 추가하기 전에 본인 인증을 진행해 주세요';

  @override
  String get couldNotListPleaseTryAgain => '등록에 실패했습니다. 잠시 후 다시 시도하세요.';

  @override
  String downloadLinkValidOnceP0P1(Object p0, Object p1) => '이 다운로드 링크는 5분 동안 유효하며 한 번만 사용할 수 있습니다. 공유하지 마세요.\n\n${p0}\n\n파일 크기: ${p1}';

  @override
  String get sources => '출처';

  @override
  String get unableOpenLink => '링크를 열 수 없습니다.';

  @override
  String get helpCentre2 => '고객센터';

  @override
  String get preferences => '환경설정';

  @override
  String get privacy => '개인정보';

  @override
  String get about2 => '정보';

  @override
  String clearP0Notifications(Object p0) => '${p0} 알림 지우기';

  @override
  String p1NotificationsP0DeletedCannotUndone(Object p0, Object p1) => '${p0} 알림 ${p1}개가 삭제됩니다. 이 작업은 되돌릴 수 없습니다.';

  @override
  String p0NotificationsCleared(Object p0) => '${p0} 알림을 지웠습니다';

  @override
  String markAllP1UnreadNotificationsP0(Object p0, Object p1) => '${p0}의 읽지 않은 알림 ${p1}개를 모두 읽음으로 표시할까요?';

  @override
  String get offers => '혜택';

  @override
  String get noTransactionNotifications => '거래 알림이 없습니다';

  @override
  String get noChatNotifications => '채팅 알림이 없습니다';

  @override
  String get noAccountNotifications => '계정 알림이 없습니다';

  @override
  String get noSupportNotifications => '고객지원 알림이 없습니다';

  @override
  String get noOfferNotifications => '혜택 알림이 없습니다';

  @override
  String get images => '이미지';

  @override
  String get imagesStillUploadingPleaseWaitBefore => '이미지를 업로드하는 중입니다. 완료 후 보내 주세요.';

  @override
  String get someImagesFailedUploadRetryRemove => '일부 이미지 업로드에 실패했습니다. 다시 시도하거나 삭제한 후 보내 주세요.';

  @override
  String get attachImages => '이미지 첨부';

  @override
  String get imageCouldNotRead => '이 이미지를 읽을 수 없습니다';

  @override
  String get up4ImagesPerMessage => '메시지당 이미지는 최대 4장까지 첨부할 수 있습니다';

  @override
  String retryUploadingImageP0(Object p0) => '이미지 ${p0} 다시 업로드';

  @override
  String removeImageP0(Object p0) => '이미지 ${p0} 삭제';

  @override
  String get addImages => '이미지 추가';

  @override
  String viewImageP0(Object p0) => '이미지 ${p0} 보기';

  @override
  String get eGGoldMember => '예: 골드 회원';

  @override
  String get pointsThreshold => '기준 포인트';

  @override
  String get pts => '포인트';

  @override
  String get tierBenefits => '등급 혜택';

  @override
  String get oneBenefitPerLine => '한 줄에 혜택 하나씩';

  @override
  String get newTier2 => '새 등급';

  @override
  String get whatMembersSee => '회원에게 표시되는 모습';

  @override
  String get noThresholdSet => '기준이 설정되지 않았습니다';

  @override
  String get tierOrder => '등급 순서';

  @override
  String get noBenefitsSet => '혜택이 설정되지 않았습니다';

  @override
  String p0CurrentlyP1MembersAfterDeletion(Object p0, Object p1, Object p2) => '“${p0}”에는 현재 회원 ${p1}명이 있습니다. 삭제하면 “${p2}”(으)로 이동합니다.';

  @override
  String noMembersCurrentlyP0OtherTiers(Object p0) => '현재 “${p0}”에 속한 회원이 없습니다. 삭제해도 다른 등급에는 영향이 없습니다.';

  @override
  String tierDeletedP0MembersMovedP1(Object p0, Object p1) => '등급을 삭제했습니다. 회원 ${p0}명이 “${p1}”(으)로 이동했습니다';

  @override
  String get changeTierOrder => '등급 순서 변경';

  @override
  String get thresholdsStayWithTheirPositionThese => '기준 포인트는 위치에 따라 유지됩니다. 다음 등급의 기준이 변경됩니다:';

  @override
  String p0P1P2Pts(Object p0, Object p1, Object p2) => '“${p0}” ${p1} → ${p2}포인트';

  @override
  String get tierOrderUpdated => '등급 순서를 업데이트했습니다';

  @override
  String p0Members(Object p0) => '회원 ${p0}명';

  @override
  String get tiers => '개 등급';

  @override
  String get members4 => '명의 회원';

  @override
  String get memberDistribution => '회원 분포';

  @override
  String get moreActions => '더 보기';

  @override
  String get dragReorder => '드래그하여 순서 변경';

  @override
  String p0Pts(Object p0) => '${p0}포인트 이상';

  @override
  String p0P1Pts(Object p0, Object p1) => '${p0}–${p1}포인트';

  @override
  String tierNamedP0AlreadyExists(Object p0) => '“${p0}” 이름의 등급이 이미 있습니다';

  @override
  String get enterPointsThreshold => '기준 포인트를 입력하세요';

  @override
  String get thresholdMustWholeNumber0More => '기준 포인트는 0 이상의 정수여야 합니다';

  @override
  String thresholdCannotExceedP0(Object p0) => '기준 포인트는 ${p0}을(를) 초과할 수 없습니다';

  @override
  String p0AlreadyUsesP1PtsEach(Object p0, Object p1) => '“${p0}”이(가) 이미 ${p1}포인트를 사용합니다. 등급마다 기준이 달라야 합니다';

  @override
  String get startingTierMustBegin0Pts => '시작 등급의 기준은 0포인트여야 합니다';

  @override
  String get startingTierCannotDeletedSetAnother => '시작 등급은 삭제할 수 없습니다. 먼저 다른 등급의 기준을 0포인트로 변경하세요';

  @override
  String get signLink => '로그인 후 연결';

  @override
  String get signAccount => '기존 계정에 로그인';

  @override
  String emailAlreadyRegisteredSignLinkName(Object p0) => '이미 등록된 이메일입니다. 로그인하면 ${p0}이(가) 연결됩니다.';

  @override
  String signLinkNameCanThenSign(Object p0, Object p1) => '로그인하면 ${p0}이(가) 연결되며 이후 ${p1}(으)로 바로 로그인할 수 있습니다.';

  @override
  String get noPasskeyDevice => '이 기기에 사용할 수 있는 패스키가 없습니다';

  @override
  String get signWithPasskeyAnotherDeviceSecurity => '다른 기기의 패스키 또는 보안 키로 로그인하거나 비밀번호를 사용하세요.';

  @override
  String get useAnotherDevice => '다른 기기 사용';

  @override
  String get usePassword => '비밀번호 사용';

  @override
  String get icloudKeychain => 'iCloud 키체인';

  @override
  String get googlePasswordManager => 'Google 비밀번호 관리자';

  @override
  String get synced => '동기화됨';

  @override
  String get notSynced => '동기화되지 않음';

  @override
  String get alreadyPasskey => '사용 가능한 패스키가 이미 있습니다';

  @override
  String get enterName => '이름을 입력하세요';

  @override
  String get passkeySavedIcloudKeychainWorksEvery => '패스키가 iCloud 키체인에 저장되어 있어 같은 Apple 계정으로 로그인한 모든 기기에서 사용할 수 있으므로 다시 추가할 필요가 없습니다. 별도로 만들려면 "다시 추가"를 누른 후 시스템 창에서 다른 비밀번호 관리자나 보안 키를 선택하세요.';

  @override
  String get passkeySavedGooglePasswordManagerWorks => '패스키가 Google 비밀번호 관리자에 저장되어 있어 같은 Google 계정으로 로그인한 모든 기기에서 사용할 수 있으므로 다시 추가할 필요가 없습니다. 별도로 만들려면 "다시 추가"를 누른 후 시스템 창에서 다른 비밀번호 관리자나 보안 키를 선택하세요.';

  @override
  String get passkeySavedDeviceSPasswordManager => '패스키가 이 기기의 비밀번호 관리자에 저장되어 있어 같은 계정으로 로그인한 모든 기기에서 사용할 수 있으므로 다시 추가할 필요가 없습니다. 별도로 만들려면 "다시 추가"를 누른 후 시스템 창에서 다른 비밀번호 관리자나 보안 키를 선택하세요.';

  @override
  String get addAgain => '다시 추가';

  @override
  String get codeExpiredPleaseRequestNewOne => '인증 코드가 만료되었습니다. 다시 요청해 주세요.';

  @override
  String codeValidP0(Object p0) => '인증 코드 유효 시간 ${p0}';

  @override
  String get basicSettings => '기본 설정';

  @override
  String get eGBirthdayVoucher => '예: 생일 쿠폰';

  @override
  String get benefitDetails => '혜택 내용';

  @override
  String get addBenefit => '혜택 추가';

  @override
  String get bookNoLongerExistsBeenRemoved => '이 도서는 존재하지 않거나 판매가 중지되었습니다.';

  @override
  String get myNicknameGroup => '이 그룹에서의 내 닉네임';

  @override
  String get setGroupNickname => '그룹 닉네임 설정';

  @override
  String get allGroupMembersSeeNickname => '그룹의 모든 멤버에게 이 닉네임이 표시됩니다.';

  @override
  String get markLockerMaintenance => '점검 중으로 설정';

  @override
  String get endLockerMaintenance => '점검 종료';

  @override
  String maintenanceHidesP0FromSellers(Object p0) => '점검 중에는 "${p0}"이(가) 판매자의 보관 위치 목록에 표시되지 않습니다. 기존 주문에는 영향이 없습니다.';

  @override
  String endingMaintenanceP0AvailableAgain(Object p0) => '점검을 종료하면 "${p0}"을(를) 판매자가 다시 선택할 수 있습니다.';

  @override
  String get lockerMarkedMaintenance => '보관함을 점검 중으로 설정했습니다';

  @override
  String get lockerMaintenanceEnded => '보관함 점검을 종료했습니다';

  @override
  String get semanticIndex => '의미 색인';

  @override
  String get semanticSearch => '의미 검색';

  @override
  String p0BooksP1HelpArticlesIndexed(Object p0, Object p1) => '도서 ${p0}건, 고객지원 정보 ${p1}건 색인됨';

  @override
  String get noOpenaiGeminiKeyConfiguredOnly => 'OpenAI 또는 Gemini 키가 설정되지 않아 키워드 검색만 사용합니다.';

  @override
  String get databaseNotBeenUpdated020Only => '데이터베이스가 업데이트되지 않아(020) 키워드 검색만 사용합니다.';

  @override
  String get hybridSearchKeywordSemantic => '하이브리드 검색(키워드 + 의미)';

  @override
  String get keywordSearchOnly => '키워드 검색만 사용';

  @override
  String get paymentReleasedWalletWhenBuyerCompletes => '구매자가 주문을 완료하거나 수령 후 24시간이 지나면 대금이 지갑에 입금됩니다';

  @override
  String get completeOrderAfterCheckingBookCompletes => '도서 상태를 확인한 후 주문을 완료해 주세요. 수령 후 24시간 내 분쟁이 없으면 자동으로 완료됩니다';

  @override
  String get completeOrder => '주문 완료';

  @override
  String get onceCompleteOrderPaymentReleasedSeller => '주문을 완료하면 대금이 판매자에게 지급되며 이후에는 분쟁을 신청할 수 없습니다.';

  @override
  String get orderCompleted2 => '주문이 완료되었습니다';

  @override
  String get noReservedBooks => '예약한 도서가 없습니다';

  @override
  String heldUntilP02(Object p0) => '${p0}까지 보류';

  @override
  String heldUntilP03(Object p0) => '${p0}까지 보류';

  @override
  String get awaitingBuyerConfirmation => '구매자 확인 대기';

  @override
  String get awaitingCompletion => '완료 대기';

  @override
  String get libraryCopyUnofficialSource => '도서관 소장본 또는 비정상 출처';

  @override
  String p0CannotEdit(Object p0) => '${p0} · 편집 불가';

  @override
  String get buyNow2 => '바로 구매';

  @override
  String get suggestRefund => '환불 권장';

  @override
  String get suggestDismissal => '기각 권장';

  @override
  String get needsMoreInformation => '추가 정보 필요';

  @override
  String get aiAnalysis => 'AI 분석';

  @override
  String get analyze => '분석하기';

  @override
  String get analyzeAgain => '다시 분석';

  @override
  String get aiAnalysisReferenceOnlyDecideBased => 'AI 분석은 참고용입니다. 실제 증거를 바탕으로 판단해 주세요.';

  @override
  String p0P1Confidence(Object p0, Object p1) => '${p0} · 신뢰도 ${p1}%';

  @override
  String get aiSummary => 'AI 정리';

  @override
  String get autoFilled => '자동 입력';

  @override
  String get similarBooks => '비슷한 도서';

  @override
  String get doNotPayTransferMoneyOutside => '앱 밖에서 송금하지 마세요. 플랫폼 외 결제는 보호되지 않습니다.';

  @override
  String get pleaseCompleteDealAppWeCannot => '앱에서 거래해 주세요. 앱 밖의 거래 분쟁은 도와드릴 수 없습니다.';

  @override
  String get personSharedOutsideContactDetailsWatch => '상대방이 외부 연락처를 공유했습니다. 사기에 주의하고 앱에서 거래를 완료하세요.';

  @override
  String get mostRelevant => '관련도순';

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
  String get orderRefunding => '審核中';

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
  String get orderFlowPickup => '買家已取書';

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
  String get language => '語言';

  @override
  String get languageSystem => '跟隨系統';

  @override
  String get verifySignSavemybook => '驗證身分以登入救「舊」我的書';

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
  String get mySavemybookData => '救「舊」我的書帳號資料';

  @override
  String get exportedChooseWhereSave => '已匯出，請選擇儲存位置';

  @override
  String get exportedButSharingCouldNotOpen => '匯出完成，但無法開啟分享';

  @override
  String get regenerateShareLink => '重新產生分享連結';

  @override
  String get oldLinkQrCodeStopWorking => '舊的連結與 QR Code 將立即失效，已分享的連結將無法開啟。確定要重新產生嗎？';

  @override
  String get regenerate => '重新產生';

  @override
  String get newLinkCreatedOldOneNo => '已產生新連結，舊連結已失效';

  @override
  String get deleteAccount => '刪除帳號';

  @override
  String get accountPermanentlyDisabled30DaysSign => '帳號將於 30 天後刪除，期間內重新登入即可取消。刪除後將清除個人資料，已完成的訂單與交易紀錄將予以保留。';

  @override
  String get actionContinue => '繼續';

  @override
  String get verify => '確認身分';

  @override
  String get enterPasswordConfirm => '請輸入密碼以確認身分。';

  @override
  String get password => '密碼';

  @override
  String get requestDeletion => '申請刪除';

  @override
  String get receivedSignAgainWithin30Days => '已受理，30 天內重新登入即可取消';

  @override
  String get deletionCancelledAccountActiveAgain => '已取消刪除，帳號已恢復';

  @override
  String get account => '帳號管理';

  @override
  String get data => '個人資料';

  @override
  String get exportMyData => '匯出我的資料';

  @override
  String get cancelAccountDeletion => '取消刪除帳號';

  @override
  String get deletionPending => '待刪除';

  @override
  String daysLeftCanCancelAnyTime(Object p0) => '剩餘 ${p0} 天。期限內可隨時取消，逾期後個人資料將被清除且無法復原。';

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
  String bookCannotPurchased(Object p0) => '此書籍目前${p0}，無法購買';

  @override
  String get addedCart => '已加入購物車';

  @override
  String get sellerInformationNotFound => '找不到賣家資訊';

  @override
  String get signContactSeller => '請先登入才能聯絡賣家';

  @override
  String get signStartChat => '請先登入才能聯絡賣家';

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
  String get reportSubmittedWeLookInto => '檢舉已送出';

  @override
  String get publisher => '出版社：';

  @override
  String get author => '作者：';

  @override
  String get listed => '上架日期：';

  @override
  String get searchTitleAuthorPublisher => '搜尋書名、作者或出版社';

  @override
  String get share => '分享';

  @override
  String get report => '檢舉';

  @override
  String get about => '簡介：';

  @override
  String get messageSeller => '聯絡賣家';

  @override
  String get listing => '您上架的書籍';

  @override
  String get addCart => '加入購物車';

  @override
  String get bookBeenReportedUnderReviewStays => '此書籍已遭檢舉，審核中。';

  @override
  String get violationWasConfirmedBookPleaseCheck => '此書籍經審核確認違規，請修改商品內容。';

  @override
  String get delist => '取消上架';

  @override
  String removedFromShopBuyersNoLonger(Object p0) => '《${p0}》將從商城下架，買家將無法瀏覽。';

  @override
  String get delist2 => '下架';

  @override
  String get couldNotDelistPleaseTryAgain => '下架失敗，請稍後再試';

  @override
  String listedAgain(Object p0) => '《${p0}》已重新上架';

  @override
  String get notListedAnyBooksYet => '尚未上架任何書籍';

  @override
  String get noBooksCategory => '此分類目前沒有書籍';

  @override
  String get relist => '重新上架';

  @override
  String get remove => '移除';

  @override
  String get couldNotRemoveRestored => '移除失敗，已還原';

  @override
  String get selectBooksWantCheckOut => '請先選擇要結帳的書籍';

  @override
  String notEnoughCoinsOrderNeedsBut(Object p0, Object p1) => '代幣不足，此訂單需 ${p0}，目前餘額 ${p1}';

  @override
  String booksTotal(Object p0, Object p1) => '共 ${p0} 本書，總金額 \$${p1}。\n';

  @override
  String balanceAfterPaymentCoins(Object p0) => '扣款後餘額為 ${p0} 代幣。';

  @override
  String get orderPlacedSellerDropBookOff => '結帳成功，請等待賣家存書';

  @override
  String get cart => '購物車';

  @override
  String get cartEmpty => '購物車內沒有商品';

  @override
  String get selectAll => '全選';

  @override
  String items(Object p0) => '${p0} 件商品';

  @override
  String get deselect => '取消選取';

  @override
  String get select => '選取';

  @override
  String coinsShort(Object p0) => '尚差 ${p0} 代幣';

  @override
  String get total => '合計';

  @override
  String selected(Object p0) => '${p0} 件';

  @override
  String balance2(Object p0) => '餘額 ${p0}';

  @override
  String get selectBookFirst => '請選擇書籍';

  @override
  String get checkOut => '結帳';

  @override
  String get notEnoughCoins => '代幣不足';

  @override
  String get weak => '弱';

  @override
  String get fair => '普通';

  @override
  String get strong => '強';

  @override
  String get enterCurrentPassword => '請輸入目前密碼';

  @override
  String get enterNewPassword => '請輸入新密碼';

  @override
  String get newPasswordMustDifferent => '新密碼不可與目前密碼相同';

  @override
  String get enterNewPasswordAgain => '請再次輸入新密碼';

  @override
  String get passwordsDoNotMatch => '兩次輸入的新密碼不一致';

  @override
  String get passwordUpdated => '密碼已更新';

  @override
  String get changePassword => '更改密碼';

  @override
  String get useLeast8CharactersWithBoth => '密碼須至少 8 碼，且同時包含英文與數字。';

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
  String allMessagesWithDeletedBothCannot(Object p0) => '將一併刪除與 ${p0} 的所有訊息，雙方皆無法再查看。此操作無法復原。';

  @override
  String get chatDeleted => '已刪除聊天室';

  @override
  String get couldNotDeleteRestored => '刪除失敗，已還原';

  @override
  String get chatMuted => '已將此聊天室設為靜音';

  @override
  String get chatUnmuted => '已取消靜音';

  @override
  String get noUnreadMessages => '沒有未讀訊息';

  @override
  String get markAllAsRead => '全部標為已讀';

  @override
  String markAllUnreadMessagesAsRead(Object p0) => '確定要將 ${p0} 則未讀訊息全部標為已讀？';

  @override
  String get markAllRead => '全部已讀';

  @override
  String get allMarkedAsRead => '已全部標為已讀';

  @override
  String get somethingWentWrongPleaseTryAgain => '操作失敗，請稍後再試';

  @override
  String get chats => '聊天室';

  @override
  String get noConversationsYet => '尚無任何對話';

  @override
  String get unmute => '取消靜音';

  @override
  String get mute => '靜音';

  @override
  String get messageCouldNotSent => '訊息傳送失敗';

  @override
  String get chat => '聊天';

  @override
  String get sendFirstMessage => '傳送第一則訊息';

  @override
  String get messageCopied => '已複製訊息';

  @override
  String get iQuestionAboutBook => '詢問書籍';

  @override
  String get bookNoLongerListed => '此書籍已下架';

  @override
  String get writeMessage => '輸入訊息…';

  @override
  String get enterOrderNumberDisputing => '請填寫要申訴的訂單編號';

  @override
  String get describeDispute => '請填寫爭議說明';

  @override
  String get useLeast10CharactersSoSupport => '爭議說明至少需 10 個字';

  @override
  String get submitDispute => '送出爭議申請';

  @override
  String get orderEntersDisputeProcessPaymentSeller => '送出後此訂單將進入申訴流程，款項將暫停撥付給賣家，直至客服裁決。';

  @override
  String paymentHoldRequested(Object p0) => '[申請凍結款項] ${p0}';

  @override
  String get disputeSubmittedSupportContact => '爭議申請已送出，客服將盡快與您聯繫';

  @override
  String get dispute => '爭議處理';

  @override
  String get requestPaymentHold => '申請凍結款項';

  @override
  String get submitDispute2 => '提交爭議申請';

  @override
  String get orderNumber => '訂單編號';

  @override
  String get eGSmb20260910123456789 => '例如 SMB20260910123456789';

  @override
  String get whatHappened => '爭議說明';

  @override
  String get describeProblemEGConditionDoes => '請描述發生的問題';

  @override
  String get submit => '送出申請';

  @override
  String get uploadPhotos => '上傳圖片';

  @override
  String get canAttachUp6Photos => '最多可上傳 6 張佐證照片';

  @override
  String get keepLeastOnePhoto => '請至少保留一張照片';

  @override
  String get photoDeleted => '已刪除照片';

  @override
  String get couldNotDeletePhotoPleaseTry => '刪除圖片失敗，請稍後再試';

  @override
  String get canUp10Photos => '最多可上傳 10 張照片';

  @override
  String get deletePhoto => '刪除照片';

  @override
  String get cannotUndoneContinue => '刪除後無法復原，確定要刪除嗎？';

  @override
  String get photoMissingDataRefreshTryAgain => '無法處理此照片，請重新整理後再試';

  @override
  String get enterPrice => '請填寫價格';

  @override
  String get priceMustGreaterThan0 => '價格必須大於 0';

  @override
  String get chooseLockerLocation => '請選擇存放區域';

  @override
  String missingTheseThreeRequired(Object p0) => '尚缺：${p0}（以上三張為必填）';

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
  String get tapPickPublicationDate => '選擇出版日期';

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
  String get tellPeopleAboutYourself => '請輸入個人簡介';

  @override
  String get email => '電子郵件';

  @override
  String get emailCannotChanged => '電子郵件無法修改';

  @override
  String get dateBirth => '生日';

  @override
  String get tapPickDateBirth => '選擇生日';

  @override
  String get pickDateBirth => '選擇生日';

  @override
  String get savedBooks => '收藏書籍';

  @override
  String get notSavedAnyBooksYet => '尚未收藏任何書籍';

  @override
  String get helpCentre => '幫助中心';

  @override
  String get searchQuestions => '搜尋問題';

  @override
  String get noQuestionsYet => '目前尚無常見問題';

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
  String get reachedEnd => '已顯示全部內容';

  @override
  String get guest => '訪客';

  @override
  String hi(Object p0) => '您好，${p0}';

  @override
  String get noBooksMatchFilters => '目前沒有符合條件的書籍';

  @override
  String get couldNotReadPhoto => '無法讀取此照片';

  @override
  String get croppingFailedPleaseTryAgain => '裁切失敗，請重試';

  @override
  String get adjustPhoto => '調整照片';

  @override
  String get reset => '重設';

  @override
  String get documentNotBeenCreatedYet => '目前無內容';

  @override
  String lastUpdated(Object p0) => '最後更新：${p0}';

  @override
  String get biometrics => '生物辨識';

  @override
  String get sessionExpiredPleaseEnterPasswordAgain => '登入資訊已失效，請重新輸入密碼';

  @override
  String turnSign(Object p0) => '啟用 ${p0} 登入？';

  @override
  String nextTimeOpenAppCanUnlock(Object p0) => '下次開啟 App 時可使用 ${p0} 解鎖，無須輸入密碼。';

  @override
  String get notNow => '暫不啟用';

  @override
  String get enterEmail => '請輸入電子郵件';

  @override
  String get emailAddressNotValid => '電子郵件格式不正確';

  @override
  String get enterPassword => '請輸入密碼';

  @override
  String get noAccountWithEmail => '此帳號尚未註冊';

  @override
  String noAccountCreateOneNow(Object p0) => '找不到帳號「${p0}」，是否立即註冊？';

  @override
  String get signUp => '前往註冊';

  @override
  String get tryAgain => '重新輸入';

  @override
  String get sign => '登入';

  @override
  String signWith(Object p0) => '使用 ${p0} 登入';

  @override
  String get noAccountYetSignUp => '尚無帳號？立即註冊';

  @override
  String get membershipTiersNotSetUpYet => '目前未提供會員等級';

  @override
  String get currentTier => '目前等級';

  @override
  String get unlocked => '已解鎖';

  @override
  String get locked => '尚未解鎖';

  @override
  String get aboveTier => '已超過此等級';

  @override
  String get reachedTopTier => '已達最高等級';

  @override
  String unlocked2(Object p0) => '已解鎖「${p0}」';

  @override
  String morePointsUnlock(Object p0, Object p1) => '再 ${p0} 點即可解鎖「${p1}」';

  @override
  String benefits(Object p0) => '${p0}等級權益';

  @override
  String get noBenefitsBeenDescribedTierYet => '此等級目前無額外權益';

  @override
  String pointsFromCompletedOrders(Object p0, Object p1) => '目前累積 ${p0} 點，已完成 ${p1} 筆交易';

  @override
  String get noNotificationsClear => '目前沒有可清除的通知';

  @override
  String get clearAllNotifications => '清除全部通知';

  @override
  String notificationsDeletedCannotUndone(Object p0) => '將刪除 ${p0} 則通知，此操作無法復原。';

  @override
  String get clearAll => '全部清除';

  @override
  String get allNotificationsCleared => '已清除全部通知';

  @override
  String get couldNotClearPleaseTryAgain => '清除失敗，請稍後再試';

  @override
  String get noUnreadNotifications => '沒有未讀通知';

  @override
  String markAllUnreadNotificationsAsRead(Object p0) => '確定要將 ${p0} 則未讀通知全部標為已讀？';

  @override
  String get openChat => '前往聊天室';

  @override
  String get viewOrder => '查看訂單';

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
  String get orderNoItemDetails => '無商品明細';

  @override
  String msg4(Object p0, Object p1) => '單價 \$${p0} × ${p1}';

  @override
  String get orderTotal => '訂單金額';

  @override
  String get pickupDetails => '取書資訊';

  @override
  String get notAssigned => '尚未指定';

  @override
  String get slot => '櫃位';

  @override
  String get notAssignedYet => '尚未分配櫃位';

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
  String get pendingPayoutDisappearsBuyerNotified => '取消後此筆待定收益將一併取消，並通知買家。';

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
  String get coinsArriveOnceBuyerCollectsBook => '買家取書後自動撥款';

  @override
  String get scanned => '掃描成功';

  @override
  String get scanAgain => '繼續掃描';

  @override
  String get collectBook => '取書';

  @override
  String get pointPickupQrCode => '請對準取書 QR Code';

  @override
  String get holdSteady => '請保持裝置穩定';

  @override
  String get bookCollected => '取書完成';

  @override
  String collected(Object p0) => '《${p0}》已完成取書';

  @override
  String order2(Object p0) => '訂單編號：${p0}';

  @override
  String get signingOut => '登出中…';

  @override
  String get myAccount => '會員中心';

  @override
  String get personNotWrittenBioYet => '尚未填寫個人簡介';

  @override
  String get topTierReached => '已達最高等級';

  @override
  String morePointsReach(Object p0, Object p1) => '再 ${p0} 點升級為「${p1}」';

  @override
  String get purchases => '購買紀錄';

  @override
  String get sales => '銷售紀錄';

  @override
  String get settings => '設定';

  @override
  String get signOut2 => '確認登出';

  @override
  String cancelOrderBookReturnsShop(Object p0) => '確定要取消訂單 ${p0} 嗎？取消後書籍將重新於商城販售。';

  @override
  String get iCollected => '確認取書';

  @override
  String get noOrdersTab => '此分類目前沒有訂單';

  @override
  String get openDispute => '申請爭議';

  @override
  String get displayNameNeedsLeast2Characters => '暱稱至少 2 個字元';

  @override
  String get displayNameLimited50Characters => '暱稱不可超過 50 個字元';

  @override
  String get enterPasswordAgain => '請再次輸入密碼';

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
  String get joinSavemybook => '註冊帳號';

  @override
  String get displayName => '暱稱';

  @override
  String get emailSignWith => '電子郵件';

  @override
  String get least8CharactersWithLettersNumbers => '至少 8 碼，需含英文與數字';

  @override
  String get confirmPassword => '確認密碼';

  @override
  String get enterPasswordAgain2 => '請再次輸入密碼';

  @override
  String get alreadyAccountGoBackSign => '已有帳號？返回登入';

  @override
  String get markAsDroppedOff => '完成存書';

  @override
  String get droppedOff => '已放入書櫃';

  @override
  String get markedAsDroppedOff => '已標記為完成存書';

  @override
  String get buyerNotifiedBookReturnsShop => '取消後將通知買家，書籍將重新於商城販售。';

  @override
  String get noRecentSearches => '尚無搜尋紀錄';

  @override
  String get recentSearches => '最近搜尋';

  @override
  String get clearAll2 => '清除全部';

  @override
  String get searchTitleAuthorIsbn => '搜尋書名、作者或 ISBN';

  @override
  String get photoLimitReached => '照片已滿';

  @override
  String get canUploadUp10Photos => '最多可上傳 10 張照片。';

  @override
  String get photosMissing => '照片不足';

  @override
  String missingTheseThreeRequired2(Object p0) => '尚缺：${p0}。以上三張為必填。';

  @override
  String get missingInformation => '資料不齊全';

  @override
  String get enterOwnPrice => '請輸入自訂價格。';

  @override
  String get invalidPrice => '價格不正確';

  @override
  String get priceMustGreaterThan02 => '售價必須大於 0。';

  @override
  String get priceCannotExceed99999 => '售價不可超過 99,999 代幣。';

  @override
  String get chooseLockerLocation2 => '請選擇存放區域。';

  @override
  String get listed2 => '上架成功';

  @override
  String get unknownError => '未知錯誤';

  @override
  String get couldNotListBook => '上架失敗';

  @override
  String get listBook => '確認上架';

  @override
  String get detailsPhotos => '詳細資訊與照片';

  @override
  String get loading => '載入中…';

  @override
  String get unknownLocker => '未知書櫃';

  @override
  String get enterTitle2 => '請輸入書名';

  @override
  String get chooseCategory2 => '請選擇分類';

  @override
  String get bookDetailsFilledAutomatically => '已自動帶入書籍資訊';

  @override
  String get noSourceIsbnPleaseEnterDetails => '查無此 ISBN 的書籍資訊，請手動輸入';

  @override
  String get day => '日';

  @override
  String get tapIconRightScan => '請輸入 ISBN';

  @override
  String get description => '書籍簡介';

  @override
  String get sellBook => '上架書籍';

  @override
  String get myShop => '我的賣場';

  @override
  String get sellerNoBooksSale => '此賣家目前沒有販售中的書籍';

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
  String get aboutSavemybook => '關於救「舊」我的書';

  @override
  String sign3(Object p0) => '${p0} 登入';

  @override
  String get scanProfileQrCode => '掃描個人 QR Code';

  @override
  String get lineUpTheirQrCodeWith => '將對方的 QR Code 放入框內';

  @override
  String get notSavemybookProfileQrCode => '此 QR Code 並非救「舊」我的書的個人 QR Code';

  @override
  String get ownQrCode => '這是您的個人 QR Code';

  @override
  String get couldNotStartChatPleaseTry => '無法建立聊天室，請稍後再試';

  @override
  String get linkCopied => '已複製連結';

  @override
  String addMeSavemybook(Object p0) => '我的救「舊」我的書個人檔案：${p0}';

  @override
  String addMeSavemybook2(Object p0, Object p1) => '${p0} 的救「舊」我的書個人檔案：${p1}';

  @override
  String get sharingCouldNotOpenSoLink => '無法開啟分享，已複製連結';

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
  String get noEnquiriesYet => '尚無提問紀錄';

  @override
  String get enterSubject => '請填寫主旨';

  @override
  String get addMoreDetailSoSupportCan => '請補充問題描述';

  @override
  String get sentSupportReplySoon => '已送出，客服將盡快回覆';

  @override
  String get subject => '主旨';

  @override
  String get sumUpOneLine => '簡述問題';

  @override
  String get whatHappenedIncludeOrderNumberIf => '請描述問題，如有訂單編號請一併提供';

  @override
  String get close => '結案';

  @override
  String get notAbleReplyAfterClosing => '結案後將無法再回覆。';

  @override
  String get enquiryClosed => '問題已結案';

  @override
  String get changeStatus => '變更狀態';

  @override
  String get statusUpdated => '已更新狀態';

  @override
  String get enquiry => '提問紀錄';

  @override
  String get enquiryNotFound => '找不到此提問';

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
  String hold(Object p0) => '凍結中 \$${p0}';

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
  String get couldNotLoadPhoto => '無法載入此照片';

  @override
  String slot2(Object p0) => '櫃位：${p0}';

  @override
  String confirmPutLocker(Object p0) => '確認已將《${p0}》放入書櫃？';

  @override
  String get enterTitleContent => '請填寫標題與內容';

  @override
  String get titleCannotExceed255Characters => '標題不可超過 255 個字元';

  @override
  String get contentNeedsLeast5Characters => '內容至少 5 個字元';

  @override
  String get publishAnnouncement => '發布公告';

  @override
  String get everyUserSeeAnnouncementOncePublished => '發布後全體使用者皆可看到此公告，確定要發布嗎？';

  @override
  String get publish => '發布';

  @override
  String get announcementPublished => '公告已發布';

  @override
  String get draftSaved => '草稿已儲存';

  @override
  String get editAnnouncement => '編輯公告';

  @override
  String get newAnnouncement => '新增公告';

  @override
  String get title2 => '標題';

  @override
  String get announcementTitle => '公告標題';

  @override
  String get writeAnnouncement => '輸入公告內容';

  @override
  String get publishNow => '立即發布';

  @override
  String get leaveOffSaveAsDraft => '關閉時僅儲存為草稿';

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
  String get noAnnouncementsYetTapAddOne => '尚無公告';

  @override
  String get published => '已發布';

  @override
  String get draft => '草稿';

  @override
  String get audienceEveryone => '對象：全體使用者';

  @override
  String get backUpNow => '立即備份';

  @override
  String get wholeDatabaseExportedCompressedWithLot => '將匯出整個資料庫並壓縮保存。資料量大時可能需要數十秒，期間請勿離開此畫面。';

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
  String get olderBackupsBeyondCountRemovedAutomatically => '超出份數的舊備份將自動清除。備份檔含全站個人資料，下載後請妥善保管，每次下載皆會記錄於操作紀錄。';

  @override
  String get noBackupsYetSchedulerRunsOnce => '尚無備份紀錄';

  @override
  String get deleteBackup => '刪除備份';

  @override
  String p0NNtheFileItsRecord(Object p0) => '${p0}\n\n檔案與紀錄將一併移除，此操作無法復原。';

  @override
  String get manual => '手動';

  @override
  String get scheduled => '排程';

  @override
  String get download => '下載';

  @override
  String get downloadBackup => '下載備份';

  @override
  String get copyLink2 => '複製網址';

  @override
  String get downloadLinkCopied => '已複製下載網址';

  @override
  String get forceDelist => '強制下架';

  @override
  String get reasonDelistingSellerNotified => '下架原因（將通知賣家）';

  @override
  String get delist3 => '確認下架';

  @override
  String get relist2 => '恢復上架';

  @override
  String putP0BackStore(Object p0) => '確定要將《${p0}》恢復上架嗎？';

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
  String onceDisabledP0NoLongerAppears(Object p0) => '停用後「${p0}」將不再顯示於賣家的存放區域選單。';

  @override
  String onceEnabledP0AvailableSellersAgain(Object p0) => '啟用後「${p0}」將重新開放賣家選擇。';

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
  String deleteP0CannotUndone2(Object p0) => '確定要刪除「${p0}」嗎？此操作無法復原。';

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
  String get contentsSectionRemovedWith => '此章節內容將一併移除。';

  @override
  String p0ItsContentsRemoved(Object p0) => '「${p0}」及其內容將一併移除。';

  @override
  String get discardChanges => '捨棄變更？';

  @override
  String get documentUnsavedChangesTheyLostIf => '此文件有尚未儲存的變更，離開後將遺失。';

  @override
  String get discard => '捨棄';

  @override
  String get keepEditing => '繼續編輯';

  @override
  String sectionP0NoTitleYet(Object p0) => '第 ${p0} 章尚未填寫標題';

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
  String get unnumberedOpeningTextLeaveEmptyIf => '開頭不編號的說明文字，若無可留空。';

  @override
  String get articles => '條文';

  @override
  String get noArticlesYetAddFirstOne => '尚無條文';

  @override
  String get addSection => '新增章節';

  @override
  String get untitledSection => '未命名章節';

  @override
  String get sectionTitle => '章節標題';

  @override
  String get bodySectionSingleLineBreaksKept => '章節內容。單行換行將如實呈現，空一行代表另起一段。';

  @override
  String get howUsersSee => '使用者檢視畫面';

  @override
  String get noContentYet => '尚無內容';

  @override
  String get unsaved => '尚未儲存';

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
  String get bothQuestionAnswerRequired => '請填寫問題與答案';

  @override
  String get added => '已新增';

  @override
  String get updated => '已更新';

  @override
  String get deleteQuestion => '刪除問題';

  @override
  String deleteP0(Object p0) => '確定要刪除「${p0}」嗎？';

  @override
  String get deleted => '已刪除';

  @override
  String get faq => '常見問題';

  @override
  String get noQuestionsYet2 => '尚無常見問題';

  @override
  String get hidden => '已隱藏';

  @override
  String get cancelDeletionRequest => '取消刪除申請';

  @override
  String p0SAccountReturnsNormalCountdown(Object p0) => '${p0} 的帳號將恢復正常，並停止刪除程序。';

  @override
  String get cancelDeletion => '取消刪除';

  @override
  String get deletionRequestCancelled => '已取消該會員的刪除申請';

  @override
  String get anonymiseNow => '立即執行匿名化';

  @override
  String eraseP0SPersonalDataDisable(Object p0) => '不待緩衝期結束，立即清除 ${p0} 的個人資料並停用帳號。\n\n訂單與交易紀錄將予以保留，暱稱將顯示為「已刪除的使用者」。此操作無法復原。';

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
  String p0DaysLeft(Object p0) => '剩餘 ${p0} 天';

  @override
  String requestedP0ScheduledP1(Object p0, Object p1) => '申請於 ${p0}，預計 ${p1} 執行';

  @override
  String get disputeResolution => '交易仲裁';

  @override
  String orderP0P1(Object p0, Object p1) => '訂單 ${p0}｜\$${p1}';

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
  String get listings => '商品管理';

  @override
  String get moderation => '內容審核';

  @override
  String get handleListingReports => '商品檢舉處理';

  @override
  String get members => '會員管理';

  @override
  String get memberControls => '會員管控';

  @override
  String get membershipTiers => '會員等級管理';

  @override
  String get wallets => '錢包管理';

  @override
  String get hardwareOperations => '硬體與營運';

  @override
  String get maintenanceLog => '維修紀錄';

  @override
  String get reports => '營運報表';

  @override
  String get ordersRevenueMemberGrowth => '訂單、營收與會員成長';

  @override
  String get supportEnquiries => '客服工單';

  @override
  String get adminAuditLog => '管理操作紀錄';

  @override
  String get systemOperations => '系統維運';

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
  String get maximumPointsLeaveEmptyNoCap => '最高點數（留空表示無上限）';

  @override
  String get benefitsSeparatedByCommasLineBreaks => '權益（以頓號或換行分隔，將於會員等級頁逐條顯示）';

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
  String deleteP0MembersTierDropNext(Object p0) => '確定要刪除「${p0}」嗎？此等級的會員將調整至下一個符合的等級。';

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
  String p0SignedOutImmediatelyCanNo(Object p0) => '${p0} 將立即被登出，且無法使用 App 的任何功能。';

  @override
  String p0AbleSignAgain(Object p0) => '${p0} 將可重新登入使用。';

  @override
  String get accountStatusUpdated => '已更新帳號狀態';

  @override
  String get removeAdmin => '取消管理員';

  @override
  String get makeAdmin => '設為管理員';

  @override
  String p0LosesEveryAdminPermissionImmediately(Object p0) => '${p0} 將立即失去所有後台權限。';

  @override
  String p0GainsAccessAdminAreaWith(Object p0) => '${p0} 將可進入管理後台，預設擁有全部權限，並可逐項調整。';

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
  String p0AbleUseEveryAdminFeature(Object p0) => '${p0} 將可使用後台所有功能。';

  @override
  String p0ReachAdminAreaButUnable(Object p0) => '${p0} 進入後台後將無法使用任何功能。';

  @override
  String get allPermissionsGranted => '已開放全部權限';

  @override
  String get allPermissionsRevoked => '已收回全部權限';

  @override
  String get memberSettings => '會員設定';

  @override
  String get noDataMember => '找不到此會員的資料';

  @override
  String get listings2 => '上架書籍';

  @override
  String get completedTrades => '完成交易';

  @override
  String get joined => '加入日期';

  @override
  String get accountStatus => '帳號狀態';

  @override
  String get ownAccountStatusPermissionsCannotChanged => '此為您本人的帳號，無法於此調整狀態與權限。';

  @override
  String get accountEnabled => '啟用帳號';

  @override
  String get canSignUseAppNormally => '可正常登入使用';

  @override
  String get suspendedSignedOutImmediatelyAfterSigning => '已停權，登入後將立即登出';

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
  String get memberSTierBeenAdjustedBy => '此會員的等級經人工調整，不完全依交易自動計算。';

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
  String get searchDisplayNameEmail => '搜尋暱稱或電子郵件';

  @override
  String get noMembersMatch => '找不到符合條件的會員';

  @override
  String get sales2 => '銷售';

  @override
  String get created => '建立日期';

  @override
  String get noActivityYet => '尚無操作紀錄';

  @override
  String get changeOrderStatus => '調整訂單狀態';

  @override
  String orderP0(Object p0) => '訂單 ${p0}';

  @override
  String get reasonChange => '調整說明';

  @override
  String get sentBuyerAsWellOptional => '將一併通知買家（選填）';

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
  String get member2 => '此會員';

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
  String get orderPlaced => '成立訂單';

  @override
  String get paid => '付款';

  @override
  String get sellerDroppedOff => '賣家存書';

  @override
  String get buyerCollected => '買家取書';

  @override
  String get completed => '完成';

  @override
  String get editBookDetails => '編輯書籍資料';

  @override
  String sellerP0TheyNotifiedSave(Object p0) => '賣家 ${p0}・儲存後將通知賣家';

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
  String p0SCurrentPasswordStopsWorking(Object p0) => '${p0} 目前的密碼將立即失效，須改用系統產生的臨時密碼登入。\n\n臨時密碼由系統產生，無法自行指定。';

  @override
  String get generateTemporaryPassword => '產生臨時密碼';

  @override
  String get temporaryPassword => '臨時密碼';

  @override
  String p0SPasswordBeenResetPassword(Object p0) => '${p0} 的密碼已重設。此密碼僅顯示一次，關閉後將無法再查看。';

  @override
  String get remindThemChangeSettingsChangePassword => '請提醒對方登入後立即至「設定 › 更改密碼」變更密碼。';

  @override
  String get temporaryPasswordCopied => '已複製臨時密碼';

  @override
  String get copy => '複製';

  @override
  String get cannotResetAnotherAdminSPassword => '無法重設其他管理員的密碼';

  @override
  String get generateTemporaryPasswordHandOver => '產生一組臨時密碼交給使用者';

  @override
  String get orderNumberCopied => '已複製訂單編號';

  @override
  String get orderNotFound => '找不到此訂單';

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
  String get changeOwnPasswordGoSettingsChange => '如需變更本人密碼，請至「設定 › 更改密碼」';

  @override
  String get memberNotAdminSoThereNo => '此會員非管理員，無後台權限可設定。請先於上方將身分設為管理員。';

  @override
  String get you => '本人';

  @override
  String isbnMust1013DigitsOne(Object p0) => 'ISBN 應為 10 或 13 碼，目前為 ${p0} 碼';

  @override
  String get screenUnsavedChangesTheyLostIf => '此畫面有尚未儲存的變更，離開後將遺失。';

  @override
  String stillNeededP0(Object p0) => '尚缺：${p0}';

  @override
  String photosP0(Object p0) => '照片：${p0} 張';

  @override
  String get confirmListing => '確認上架';

  @override
  String get lookingUpBook => '正在查詢書籍資料';

  @override
  String get scan => '掃描';

  @override
  String get buyerSPaymentGoesBackTheir => '買家支付的款項將退回錢包；若賣家已收到貨款，將先行收回。';

  @override
  String get orderReturnsWhereWasBeforeDispute => '訂單將恢復至申訴前的狀態並繼續交易；若先前已完成取書，貨款將撥付給賣家。';

  @override
  String get orderWasAlreadyRefundedBuyerCannot => '此訂單款項已退回買家，無法改回進行中或已完成';

  @override
  String get completedOrderCanOnlyChangedRefund => '已完成的訂單只能改為「退款處理中」或「已退款」';

  @override
  String confirmingPaysP0TokensSellerMarks(Object p0) => '確認後將撥付 ${p0} 代幣給賣家，並將書籍標記為已售出。';

  @override
  String confirmingTakesP0TokensBackFrom(Object p0) => '確認後將向賣家收回 ${p0} 代幣並退還買家。賣家餘額不足時將顯示為負數。';

  @override
  String get ifBuyerNotBeenRefundedYet => '若先前尚未退款，將補退給買家。';

  @override
  String confirmingRefundsBuyerSP0Tokens(Object p0) => '確認後將退還買家支付的 ${p0} 代幣，保留中的書籍將重新上架。';

  @override
  String get donTPermissionYourselfSoCan => '您未擁有此權限，無法授予他人。';

  @override
  String get notificationsTurnedOff => '通知權限已關閉';

  @override
  String get openSettings => '前往設定';

  @override
  String get sendTestNotification => '傳送測試通知';

  @override
  String get arrives10SecondsGoHomeScreen => '將於 10 秒後送達，送出後請返回主畫面或鎖定手機';

  @override
  String get systemNotificationSettings => '系統通知設定';

  @override
  String get pushNotificationsNotSetUpBuild => '此版本的 App 尚未設定推播，請加入 Firebase 設定檔後重新編譯。';

  @override
  String get notificationsTurnedOffAllowAppSend => '通知權限已關閉，請至系統設定允許此 App 傳送通知。';

  @override
  String get restoreBackup => '確定要還原至此備份？';

  @override
  String wholeDatabaseGoBackP0Orders(Object p0) => '整個資料庫將還原至 ${p0} 的狀態，此時間點之後的訂單、訊息、會員資料與操作紀錄將全部清除。\n\n還原前系統將自動備份目前狀態，如有需要可再還原該備份。還原期間全站暫停服務，通常需要數十秒至數分鐘。\n\n請輸入您的登入密碼以確認：';

  @override
  String get password2 => '登入密碼';

  @override
  String get startRestore => '開始還原';

  @override
  String get backingUpCurrentState => '正在備份目前狀態…';

  @override
  String databaseRestoredPreviousStateWasBacked(Object p0) => '資料庫已還原。還原前的狀態已備份至 ${p0}';

  @override
  String restoreFailedDatabaseMayUnchangedPartly(Object p0) => '還原失敗，資料庫可能維持原狀或已部分還原，請查看操作紀錄並視需要還原 ${p0}';

  @override
  String get autoBackupBeforeRestore => '還原前自動備份';

  @override
  String get restoreBackup2 => '還原至此備份';

  @override
  String get restoringDatabase => '正在還原資料庫';

  @override
  String p0SecondsSoFarKeepApp(Object p0) => '已經過 ${p0} 秒。請勿關閉 App，完成後將自動恢復服務。';

  @override
  String get majorUpdate2 => '重大更新';

  @override
  String get minorEdit => '小幅修改';

  @override
  String get books => '書籍';

  @override
  String get orders2 => '訂單';

  @override
  String get wallets2 => '錢包';

  @override
  String get announcements3 => '公告';

  @override
  String get legal => '條款';

  @override
  String get backups => '備份';

  @override
  String get undoAction => '確定要還原此操作？';

  @override
  String p0NNtheDataGoesBack(Object p0) => '「${p0}」\n\n資料將恢復至操作前的狀態。已送出的通知不會收回；若資料之後曾再次修改，系統將拒絕還原。';

  @override
  String get undo => '還原';

  @override
  String get undone => '已還原';

  @override
  String get searchActionsEGNicknameBook => '搜尋操作內容，例如會員暱稱或書名';

  @override
  String viewP0Changes(Object p0) => '查看 ${p0} 項變更';

  @override
  String get undoAction2 => '還原此操作';

  @override
  String get noAnnouncements => '目前沒有公告';

  @override
  String get canTContinueWithoutAccepting => '未同意將無法繼續使用';

  @override
  String needAcceptLatestP0UseP1(Object p0) => '不同意「${p0}」將登出帳號。';

  @override
  String get goBack => '返回';

  @override
  String p0BeenUpdated(Object p0) => '「${p0}」已更新';

  @override
  String readLatestVersionUpdatedP0Accept(Object p0) => '${p0} 更新';

  @override
  String get scrollEndContinue => '請捲動至底部閱讀全文';

  @override
  String get iVeReadAccept => '我已閱讀並同意';

  @override
  String get decline => '不同意';

  @override
  String get viewDetails => '查看詳情';

  @override
  String get notFoundMayBeenDeletedRemoved => '此內容已不存在';

  @override
  String get chatMessages => '聊天訊息';

  @override
  String get promotions2 => '優惠活動';

  @override
  String get supportRepliesPasswordResetsPolicyUpdates => '客服回覆、帳號安全與系統公告通知無法關閉。';

  @override
  String get notFilled => '未填寫';

  @override
  String get canTChanged => '無法修改';

  @override
  String get voice => '[語音]';

  @override
  String get reservation => '預約';

  @override
  String get messageUnsent => '訊息已收回';

  @override
  String get confirmBeforeExportingData => '匯出個人資料前，請先驗證身分';

  @override
  String get exportFailedPleaseTryAgainLater => '匯出失敗，請稍後再試';

  @override
  String get refresh => '重新整理';

  @override
  String get clearFilters => '清除篩選';

  @override
  String get expired => '已過期';

  @override
  String get verificationCancelled => '已取消驗證';

  @override
  String get openingClosingTimesCanTSame => '開放與關閉時間不可相同';

  @override
  String slotCurrentlyP0MayOrderProgress(Object p0, Object p1) => '此櫃位目前為「${p0}」，可能有進行中的訂單。變更為「${p1}」後，買賣雙方可能無法正常存取書籍。';

  @override
  String get active => '啟用中';

  @override
  String get categoryWithNameAlreadyExists => '已有同名分類';

  @override
  String orderP0ClosedAsP1P2(Object p0, Object p1, Object p2) => '訂單 ${p0} 將以「${p1}」結案，${p2} 代幣將退回買家。送出後無法修改。';

  @override
  String orderP0ClosedAsP1Can(Object p0, Object p1) => '訂單 ${p0} 將以「${p1}」結案。送出後無法修改。';

  @override
  String get clearSearch => '清除搜尋';

  @override
  String get enterMinimumPoints => '請輸入最低點數';

  @override
  String pointsRangeOverlapsWithP0P1(Object p0, Object p1) => '點數範圍與「${p0}」（${p1}）重疊';

  @override
  String noTierCoversP0P1Points(Object p0, Object p1) => '${p0}–${p1} 點沒有對應的等級';

  @override
  String p0TakenDownRightAwayOther(Object p0) => '「${p0}」將立即下架，其他會員將無法瀏覽或購買。';

  @override
  String get searchReportedItemReporterReason => '搜尋被檢舉項目、檢舉人或原因';

  @override
  String get couldnTLoadStatisticsRightNow => '暫時無法取得統計資料';

  @override
  String get searchSubjectMemberMessage => '搜尋主旨、會員或訊息內容';

  @override
  String get balance3 => '有餘額';

  @override
  String get hold3 => '有凍結金額';

  @override
  String get zeroBalance => '餘額為 0';

  @override
  String get amountCanMost2DecimalPlaces => '金額最多可至小數點後兩位';

  @override
  String get singleAdjustmentCanTExceed1 => '單次調整不可超過 1,000,000';

  @override
  String wouldMakeBalanceNegativeCurrentBalance(Object p0) => '扣除後餘額將為負數，目前餘額 ${p0}';

  @override
  String get amountUp2Decimals => '金額（最多兩位小數）';

  @override
  String p0NbalanceAfterP1(Object p0, Object p1) => '${p0}\n調整後餘額 ${p1}';

  @override
  String get cameraAccessOff => '無法使用相機';

  @override
  String get couldNotStartCamera => '相機啟動失敗';

  @override
  String allowP0UseCameraSettingsThen(Object p0) => '請至系統設定允許 ${p0} 使用相機後再試。';

  @override
  String get closeScreenTryAgain => '請關閉此畫面後再試。';

  @override
  String get couldnTGetLocationCheckLocation => '無法取得目前位置，請確認已開啟定位服務與權限';

  @override
  String get bookReservedAnotherBuyerCanT => '此書籍已由其他買家預約，暫時無法加入購物車';

  @override
  String reservedAnotherBuyerUntilP0(Object p0) => '已由其他買家預約，保留至 ${p0}';

  @override
  String sellerHoldingUntilP0(Object p0) => '賣家已為您保留至 ${p0}';

  @override
  String get checkOutBeforeHoldEndsOther => '請於保留期限內完成結帳';

  @override
  String get copyAddress => '複製地址';

  @override
  String p0Away(Object p0) => '距離 ${p0}';

  @override
  String get locating => '定位中…';

  @override
  String get showDistance => '查看距離';

  @override
  String get reserved => '已預約';

  @override
  String get goCheckout => '前往結帳';

  @override
  String get cart2 => '已在購物車';

  @override
  String get buyNow => '立即購買';

  @override
  String p0Delisted(Object p0) => '《${p0}》已下架';

  @override
  String noBooksMatchP0(Object p0) => '找不到符合「${p0}」的書籍';

  @override
  String p0BooksP1Views(Object p0, Object p1) => '共 ${p0} 本 · 總瀏覽 ${p1} 次';

  @override
  String get searchTitleAuthorIsbn2 => '搜尋書名、作者或 ISBN';

  @override
  String removedP0(Object p0) => '已移除《${p0}》';

  @override
  String removedP0Items(Object p0) => '已移除 ${p0} 件商品';

  @override
  String get paymentSuccessful => '付款成功';

  @override
  String p0BooksSplitIntoP1Orders(Object p0, Object p1) => '共 ${p0} 本書，已依賣家拆分為 ${p1} 筆訂單';

  @override
  String get keepBrowsing => '繼續瀏覽';

  @override
  String get reload => '重新載入';

  @override
  String get browseBooks => '瀏覽書籍';

  @override
  String p0Sellers(Object p0) => '${p0} 位賣家';

  @override
  String unavailableP0(Object p0) => '無法購買（${p0}）';

  @override
  String get removeAll => '全部移除';

  @override
  String get goWallet => '前往錢包';

  @override
  String fromP0SellersCheckoutCreatesP1(Object p0, Object p1) => '來自 ${p0} 位賣家，結帳後將拆分為 ${p1} 筆訂單';

  @override
  String get otherDevicesNeedSignAgainWith => '其他裝置須使用新密碼重新登入。';

  @override
  String get searchChats => '搜尋聊天對象';

  @override
  String get noMatchingChats => '找不到符合的聊天對象';

  @override
  String get read => '已讀';

  @override
  String get chatNotFound => '找不到此聊天室';

  @override
  String get messagesCanUp2000Characters => '訊息最多 2000 字';

  @override
  String get canTSendRightNowPlease => '目前無法傳送，請稍後再試';

  @override
  String get reserveBook => '預約書籍';

  @override
  String get quickReplies => '快速回覆';

  @override
  String get imagesMust10MbSmaller => '圖片不可超過 10 MB';

  @override
  String get recordingFailedPleaseTryAgain => '錄音失敗，請重試';

  @override
  String get voiceMessageTooLargePleaseRecord => '語音檔案過大，請縮短錄音時間';

  @override
  String get microphoneAllowedPressHoldAgainRecord => '已允許使用麥克風，請再次按住按鈕開始錄音';

  @override
  String get microphoneAccessNeededRecordTurnSettings => '錄音需要麥克風權限，請至系統設定開啟';

  @override
  String get couldnTStartRecordingPleaseTry => '無法開始錄音，請稍後再試';

  @override
  String get selectText => '選取文字';

  @override
  String get unsend => '收回';

  @override
  String get resend => '重新傳送';

  @override
  String get unsendMessage => '確定要收回此訊息？';

  @override
  String get neitherAbleSeeMessageSContent => '收回後雙方皆無法查看此訊息內容。';

  @override
  String get reportMessage => '檢舉此訊息';

  @override
  String get reservationSentWaitingSeller => '已送出預約，等待賣家回覆';

  @override
  String get acceptReservation => '確定要接受預約？';

  @override
  String p0HeldThemP1HoursNo(Object p0, Object p1) => '《${p0}》將為對方保留 ${p1} 小時，期間其他人無法購買。';

  @override
  String get accept => '接受';

  @override
  String get reservationAccepted => '已接受預約';

  @override
  String get declineReservation => '確定要婉拒預約？';

  @override
  String get decline2 => '婉拒';

  @override
  String get reservationDeclined => '已婉拒預約';

  @override
  String get cancelReservation => '確定要取消預約？';

  @override
  String p0NoLongerHeld(Object p0) => '取消後《${p0}》將不再保留。';

  @override
  String get cancelReservation2 => '取消預約';

  @override
  String get reservationCanceled => '已取消預約';

  @override
  String get notNow2 => '返回';

  @override
  String get couldnTLoadConversationPleaseTry => '無法載入對話，請稍後再試';

  @override
  String get accountCanTReceiveMessagesRight => '對方帳號目前無法接收訊息';

  @override
  String get holdMicTalkReleaseSend => '錄音時間過短';

  @override
  String get startConversation => '對話開始';

  @override
  String p0New(Object p0) => '${p0} 則新訊息';

  @override
  String get connectionUnstableMessagesCanTSent => '連線不穩定，暫時無法傳送訊息';

  @override
  String get retry => '重試';

  @override
  String get stillAvailable => '請問此書籍仍可購買嗎？';

  @override
  String get couldLowerPriceBit => '請問是否可議價？';

  @override
  String get whenCanPutLocker => '請問預計何時存入書櫃？';

  @override
  String get unsentMessage => '您已收回訊息';

  @override
  String get theyUnsentMessage => '對方已收回訊息';

  @override
  String get reservationDetailsArenTAvailableRight => '預約資訊暫時無法顯示';

  @override
  String get sending => '傳送中';

  @override
  String get couldNotUploadPhotosPleaseTry => '證據照片上傳失敗，請稍後再試';

  @override
  String get bookDetailsUpdatedButPhotosCouldn => '書籍資料已更新，但照片上傳失敗，請稍後再試';

  @override
  String get sNotIsbnBarcodeScanOne => '掃描到的條碼非 ISBN，請掃描書背上 978 或 979 開頭的條碼';

  @override
  String get couldnTLoadCategoriesTapRetry => '分類載入失敗，請點此重試';

  @override
  String removedP0FromSaved(Object p0) => '已取消收藏《${p0}》';

  @override
  String get recentlyViewedCleared => '已清除最近瀏覽';

  @override
  String clearP0(Object p0) => '清除（${p0}）';

  @override
  String get picked => '為您推薦';

  @override
  String get recentlyViewed => '最近瀏覽';

  @override
  String get clear => '清除';

  @override
  String get notificationDeleted => '已刪除通知';

  @override
  String get pleasePutBookAssignedLockerSoon => '請盡快將書籍存入指定書櫃';

  @override
  String get weLlLetKnowWhenSeller => '賣家存書後將通知您前往取書';

  @override
  String get waitingBuyerCollect => '等待買家至書櫃取書';

  @override
  String get transactionCompleteThank => '交易完成';

  @override
  String get confirmVeTakenBookFromLocker => '請確認已從書櫃取出書籍。確認書況無誤後，請於購買紀錄完成訂單。';

  @override
  String p0Orders2(Object p0) => '共 ${p0} 筆訂單';

  @override
  String p0ReadyPickup(Object p0) => '可取書 ${p0} 筆';

  @override
  String get pickUp => '待取書';

  @override
  String get saved => '收藏';

  @override
  String get accountSecurity => '帳號安全';

  @override
  String get searchHistoryCleared => '已清除搜尋紀錄';

  @override
  String get trendingBooks => '熱門書籍';

  @override
  String get signOutDevice => '確定要登出此裝置？';

  @override
  String signOutP0(Object p0) => '確定要登出「${p0}」？';

  @override
  String get deviceSignedOutRightAwayStop => '該裝置將立即登出。';

  @override
  String get deviceSignedOut => '已登出裝置';

  @override
  String get signOutAllDevicesIncludingOne => '登出所有裝置（含本機）';

  @override
  String get signOutAllOtherDevices => '登出其他所有裝置';

  @override
  String get everyDeviceIncludingOneSignedOut => '包含本機在內的所有裝置將立即登出。';

  @override
  String get everyDeviceExceptOneSignedOut => '除本機外的所有裝置將立即登出。';

  @override
  String signedOutP0OtherDevices(Object p0) => '已登出其他 ${p0} 台裝置';

  @override
  String get unknownDevice => '未知裝置';

  @override
  String get couldnTLoadDevices => '無法載入登入裝置';

  @override
  String get device => '本機';

  @override
  String get otherDevices => '其他裝置';

  @override
  String otherDevicesP0(Object p0) => '其他裝置（${p0}）';

  @override
  String get noOtherDevicesSigned => '沒有其他裝置登入您的帳號';

  @override
  String get signedDevices => '登入裝置';

  @override
  String get activeNow => '目前使用中';

  @override
  String lastActiveP0(Object p0) => '最後使用 ${p0}';

  @override
  String signedP0(Object p0) => '${p0} 登入';

  @override
  String get biometricPayment => '已啟用生物辨識付款';

  @override
  String get paymentPinMust6Digits => '交易密碼必須是 6 位數字';

  @override
  String get pinTooEasyGuessTryAnother => '交易密碼過於簡單，請重新設定';

  @override
  String get enterPasswordResetPaymentPin => '輸入登入密碼後即可重新設定交易密碼';

  @override
  String get confirmSBeforeSettingPaymentPin => '設定交易密碼前，請先驗證身分';

  @override
  String get pinsDonTMatchStartAgain => '兩次輸入的交易密碼不一致，請重新設定';

  @override
  String get paymentPinReset => '交易密碼已重新設定';

  @override
  String get paymentPinSet => '交易密碼已設定';

  @override
  String get verifyingIdentity => '正在確認身分…';

  @override
  String get enterAgainConfirm => '請再次輸入以確認';

  @override
  String get set6DigitPaymentPin => '設定 6 位數交易密碼';

  @override
  String get enterSamePinAgain => '請再次輸入相同密碼';

  @override
  String get avoidRepeatedSequentialPatternedDigits => '不可使用相同、連續或重複的數字';

  @override
  String get resetPaymentPin => '重設交易密碼';

  @override
  String get paymentPin => '交易密碼';

  @override
  String stepP02(Object p0) => '步驟 ${p0} / 2';

  @override
  String get setPaymentPinFirst => '請先設定交易密碼';

  @override
  String get setPaymentPinFirstSoFallback => '請先設定交易密碼，作為辨識失敗時的替代驗證方式';

  @override
  String get setUpNow => '立即設定';

  @override
  String get biometricPaymentTurnedOff => '已關閉生物辨識付款';

  @override
  String get verifyTurnBiometricPayment => '驗證以啟用生物辨識付款';

  @override
  String p0PaymentsTurned(Object p0) => '已啟用 ${p0} 付款';

  @override
  String get securitySettingsUnavailableRightNowMay => '無法載入帳號安全設定';

  @override
  String payWithP0(Object p0) => '使用 ${p0} 付款';

  @override
  String get accountWellProtected => '帳號安全狀態良好';

  @override
  String get accountCouldSafer => '帳號安全性有待加強';

  @override
  String get setPaymentPinTurnBiometricPayment => '尚未設定交易密碼';

  @override
  String tooManyAttemptsLockedUntilP0(Object p0) => '錯誤次數過多，已鎖定至 ${p0}';

  @override
  String get notSetRequiredBeforeCheckout => '尚未設定';

  @override
  String get change => '變更';

  @override
  String get forgotPaymentPin => '忘記交易密碼';

  @override
  String p0Devices(Object p0) => '${p0} 台';

  @override
  String get restoredUnfinishedListing => '已帶入上次未完成的內容';

  @override
  String get isbnSCheckDigitInvalidPlease => '此 ISBN 檢查碼不正確，請再次確認';

  @override
  String get draftSavedAutomatically => '已自動儲存草稿';

  @override
  String get continueUnfinishedListing => '繼續上次未完成的刊登';

  @override
  String clearedP0MbCache(Object p0) => '已清除 ${p0} MB 快取';

  @override
  String get cacheCleared => '快取已清除';

  @override
  String get storage => '儲存空間';

  @override
  String get clearCache => '清除快取';

  @override
  String get couldNotLoadNotificationSettings => '無法載入通知設定';

  @override
  String get month => '本月';

  @override
  String p0P1(Object p0, Object p1) => '${p0} 年 ${p1} 月';

  @override
  String get noIncomeYet => '尚無收入紀錄';

  @override
  String get noSpendingYet => '尚無支出紀錄';

  @override
  String get income => '收入';

  @override
  String get spending => '支出';

  @override
  String get totalIncome => '累計收入';

  @override
  String get totalSpending => '累計支出';

  @override
  String get item3 => '項目';

  @override
  String get details => '說明';

  @override
  String get balanceAfter => '交易後餘額';

  @override
  String get transactionId => '交易編號';

  @override
  String get sessionExpiredPleaseSignAgain => '登入已過期，請重新登入';

  @override
  String get serviceTemporarilyUnavailableTryAgainLater => '服務暫時無法使用，請稍後再試';

  @override
  String get uploadFailedTryAgainLater => '上傳失敗，請稍後再試';

  @override
  String get nearby => '附近';

  @override
  String p0M(Object p0) => '${p0} 公尺';

  @override
  String p0Km(Object p0) => '${p0} 公里';

  @override
  String get iphoneDidnTReceiveApnsToken => '裝置未取得 Apple 推播憑證（APNs token）。請確認 Xcode 的 Signing & Capabilities 已加入 Push Notifications，並使用同一個 Apple 開發者帳號重新安裝 App。';

  @override
  String get firebaseDidnTIssuePushToken => 'Firebase 未核發推播 token，請確認 GoogleService-Info.plist 與 App 的 Bundle ID 一致';

  @override
  String couldnTGetPushTokenP0(Object p0) => '取得推播 token 失敗：${p0}';

  @override
  String couldnTRegisterPushTokenWith(Object p0) => '推播 token 上傳伺服器失敗：${p0}';

  @override
  String get protectCoinsCheckoutRequires6Digit => '結帳前請先設定 6 位數交易密碼。';

  @override
  String confirmPaymentP0Coins(Object p0) => '確認付款 ${p0} 代幣';

  @override
  String get enterPasswordContinue => '請輸入登入密碼以繼續';

  @override
  String get verifyS => '驗證身分';

  @override
  String get amount => '付款金額';

  @override
  String p0Coins(Object p0) => '${p0} 代幣';

  @override
  String get enterPaymentPin => '輸入交易密碼';

  @override
  String get enterPaymentPinContinue => '請輸入交易密碼以繼續';

  @override
  String get paymentPinResetEnterAgain => '交易密碼已重新設定，請再次輸入';

  @override
  String get usePasswordInstead => '改用登入密碼';

  @override
  String get couldnTGetLocationLockersShown => '無法取得目前位置';

  @override
  String p0SlotsFree(Object p0) => '空櫃 ${p0} 格';

  @override
  String openP0(Object p0) => '開放 ${p0}';

  @override
  String get nearest => '最近';

  @override
  String get noFreeSlots => '目前沒有空櫃';

  @override
  String get turnLocationSortByDistance => '開啟定位可依距離排序';

  @override
  String get lockerNoFreeSlotsRightNow => '此書櫃目前沒有空櫃';

  @override
  String get turn => '開啟定位';

  @override
  String get noLockersAvailable => '目前沒有可用的書櫃';

  @override
  String get noMatchingOptions => '沒有符合的選項';

  @override
  String get undo2 => '復原';

  @override
  String copiedP0(Object p0) => '已複製「${p0}」';

  @override
  String get typing => '對方正在輸入…';

  @override
  String get today => '今天';

  @override
  String get yesterday => '昨天';

  @override
  String p0P12(Object p0, Object p1) => '${p0}月${p1}日';

  @override
  String p1P2P0(Object p0, Object p1, Object p2) => '${p0}年${p1}月${p2}日';

  @override
  String get releaseCancel => '放開以取消';

  @override
  String get awaitingReply => '待回覆';

  @override
  String heldUntilP0(Object p0) => '已保留至 ${p0}';

  @override
  String get declined2 => '已婉拒';

  @override
  String get closed => '已結束';

  @override
  String get theyWantReserveBook => '對方申請預約您的書籍';

  @override
  String get sentReservationRequest => '您已送出預約';

  @override
  String holdP0H(Object p0) => '保留 ${p0} 小時';

  @override
  String get holdPeriod => '保留時間';

  @override
  String get messageSellerOptional => '給賣家的留言（選填）';

  @override
  String get sendRequest => '送出預約';

  @override
  String p0Hours(Object p0) => '${p0} 小時';

  @override
  String p0P1DigitsEntered(Object p0, Object p1) => '已輸入 ${p0} / ${p1} 位';

  @override
  String get buildSProvisioningProfileDoesnT => '此安裝版本的簽署描述檔未包含推播權限。請於 Xcode 的 Runner › Signing & Capabilities 確認已加入 Push Notifications，並刪除 App 後重新安裝。';

  @override
  String get checkPhoneOnlinePushNotificationsAdded => '請確認裝置已連上網路，並於 Xcode 的 Runner › Signing & Capabilities 確認已加入 Push Notifications。';

  @override
  String iphoneFailedRegisterPushNotificationsWith(Object p0, Object p1) => 'iPhone 向 Apple 註冊推播失敗：${p0}\n${p1}';

  @override
  String get serverNotBeenUpdatedSupportFeature => '此功能暫時無法使用，請稍後再試';

  @override
  String get someFeaturesTemporarilyUnavailableWhileServer => '部分功能暫時無法使用';

  @override
  String serverRunningOutdatedApiRevisionP0(Object p0, Object p1) => '伺服器執行的 API 版本過舊（目前 ${p0}，App 需要 ${p1}）。請在伺服器更新程式碼並重新啟動 API。';

  @override
  String databaseMigrationsNotYetRunP0(Object p0) => '資料庫尚未執行：${p0}';

  @override
  String serverVersionP0(Object p0) => '伺服器目前版本：${p0}';

  @override
  String get runNpmRunVerifyApiDirectory => '在伺服器的 API 目錄執行 npm run verify 可檢查完整的部署狀態。';

  @override
  String get serverUpdateRequired => '伺服器需要更新';

  @override
  String versionP0(Object p0) => '第 ${p0} 版';

  @override
  String get requiresUserConsent => '須經使用者同意';

  @override
  String get unsavedDraft => '有未儲存的草稿';

  @override
  String get allBooks => '全部書籍';

  @override
  String get results => '篩選結果';

  @override
  String get sortBy => '排序方式';

  @override
  String get themeColour => '主題色';

  @override
  String get forestGreen => '森林綠';

  @override
  String get oceanBlue => '海洋藍';

  @override
  String get lavender => '薰衣草紫';

  @override
  String get terracotta => '赤陶橘';

  @override
  String get amber => '琥珀金';

  @override
  String get rose => '玫瑰粉';

  @override
  String get graphite => '石墨灰';

  @override
  String get mistBlue => '霧藍';

  @override
  String get draftRestored => '已還原草稿';

  @override
  String get convertSections => '轉換為章節模式';

  @override
  String get currentContentDoesNotFullyMatch => '目前內容無法完整對應章節格式。轉換後，章節編號將依序重新產生並統一為「1. 標題」格式，未能辨識為標題的段落將併入前言或上一章內文。\n\n若需保留原始格式，請繼續以純文字模式編輯並儲存。';

  @override
  String get convert => '轉換';

  @override
  String get keepPlainText => '維持純文字';

  @override
  String get noSectionHeadingsDetectedFullText => '未偵測到章節標題，全文已置於前言';

  @override
  String deletedP0(Object p0) => '已刪除「${p0}」';

  @override
  String get renameSection => '重新命名章節';

  @override
  String get editContent => '編輯內容';

  @override
  String get rename => '重新命名';

  @override
  String get addSectionBelow => '在下方新增章節';

  @override
  String get moveUp => '上移';

  @override
  String get moveDown => '下移';

  @override
  String get enterDocumentTitle => '請填寫文件標題';

  @override
  String get enterDocumentContent => '請填寫文件內容';

  @override
  String p0NowVersionP1(Object p0, Object p1) => '${p0}，目前為第 ${p1} 版';

  @override
  String versionP0P1(Object p0, Object p1) => '第 ${p0} 版・${p1}';

  @override
  String unsavedDraftFromP0Found(Object p0) => '發現 ${p0} 未儲存的草稿';

  @override
  String get documentWasUpdatedAfterDraftWas => '文件已於草稿建立後更新，還原後將以草稿內容取代目前內容。';

  @override
  String get discardDraft => '捨棄草稿';

  @override
  String get restoreDraft => '還原草稿';

  @override
  String get sectionTitleRequired => '尚未填寫章節標題';

  @override
  String get documentSFormatDoesNotFully => '此文件的格式無法完整對應章節結構，已以純文字模式開啟，以保留原始格式。';

  @override
  String get enterPasteFullTextHere => '請於此輸入或貼上全文。';

  @override
  String get noSectionHeadingsDetected => '未偵測到章節標題';

  @override
  String p0SectionsDetected(Object p0) => '已偵測到 ${p0} 個章節';

  @override
  String get paragraphWhoseFirstLine1Title => '段落首行為「1. 標題」、「一、標題」或「第一條 標題」時，視為章節標題。';

  @override
  String get sectionNumbersMustStart1Increase => '章節編號須自 1 起依序遞增；不符合者視為上一章的內文。';

  @override
  String get blankLineStartsNewParagraphSingle => '空一行代表分段，單行換行將如實呈現。';

  @override
  String get whenSwitchingSectionsAskedConfirmAny => '切換至章節模式時，若格式需要調整，將先提示確認。';

  @override
  String get howSectionHeadingsDetected => '章節標題判定方式';

  @override
  String get titleEdited => '標題已修改';

  @override
  String p0Added(Object p0) => '新增 ${p0} 章';

  @override
  String p0Removed(Object p0) => '刪除 ${p0} 章';

  @override
  String p0Edited(Object p0) => '修改 ${p0} 章';

  @override
  String get sectionsReordered => '章節順序已調整';

  @override
  String get preambleEdited => '前言已修改';

  @override
  String get contentEdited => '內容已修改';

  @override
  String p0Characters2(Object p0) => '字數 +${p0}';

  @override
  String p0Characters3(Object p0) => '字數 ${p0}';

  @override
  String get formattingAdjusted => '排版調整';

  @override
  String get createdAsVersion1 => '建立為第 1 版';

  @override
  String staysVersionP0(Object p0) => '維持第 ${p0} 版';

  @override
  String versionP0P12(Object p0, Object p1) => '第 ${p0} 版 → 第 ${p1} 版';

  @override
  String get substantiveChangesRightsObligationsTermsAll => '適用於權利義務或條款內容的實質變更。將通知所有使用者，使用者下次開啟 App 時須重新閱讀並同意。';

  @override
  String get substantiveContentChangesAllUsersNotified => '適用於內容的實質變更。將通知所有使用者。';

  @override
  String saveP0(Object p0) => '儲存「${p0}」';

  @override
  String get summaryChanges => '變更摘要';

  @override
  String get updateType => '更新方式';

  @override
  String get fixingTyposFormattingUsersNotNotified => '適用於修正錯字或調整排版。不通知使用者。';

  @override
  String get contentUnchangedTitleOnlyChangeCannot => '內容未變更，僅修改標題時無法列為重大更新。';

  @override
  String get notificationsSentImmediatelyAfterSubmittingCannot => '送出後將立即發送通知，此操作無法撤回。';

  @override
  String get publishNotify => '發布並通知';

  @override
  String sectionP0(Object p0) => '第 ${p0} 章';

  @override
  String get goSection => '跳至章節';

  @override
  String get sectionContent => '章節內容';

  @override
  String get previous => '上一章';

  @override
  String get next2 => '下一章';

  @override
  String get unableGenerateProfileQrCodeTry => '無法產生個人 QR Code，請稍後再試';

  @override
  String get myQrCode => '我的 QR Code';

  @override
  String get markAsRead => '標為已讀';

  @override
  String get unblock => '解除封鎖';

  @override
  String afterUnblockingP0CanSendMessages(Object p0) => '解除封鎖後，您與「${p0}」可再次互相傳送訊息。';

  @override
  String get userUnblocked => '已解除封鎖';

  @override
  String get unableLoadBlockedUsers => '無法載入封鎖名單';

  @override
  String get notBlockedAnyUsers => '目前沒有封鎖任何使用者';

  @override
  String get blockedUsers => '封鎖名單';

  @override
  String get blockUser => '封鎖使用者';

  @override
  String afterBlockP0NeitherCanSend(Object p0) => '封鎖「${p0}」後，雙方將無法互相傳送訊息。';

  @override
  String get block => '封鎖';

  @override
  String get userBlocked => '已封鎖此使用者';

  @override
  String get moreOptions => '更多選項';

  @override
  String get blockedUser => '您已封鎖此使用者';

  @override
  String get originalMessageNotFound => '找不到原訊息';

  @override
  String get you2 => '您';

  @override
  String get viewProfile => '查看個人檔案';

  @override
  String get reply => '回覆';

  @override
  String get bookLockerScanQrCodeLocker => '書籍已存入書櫃，請至書櫃掃描機台上的 QR Code 取書';

  @override
  String get originalMessageUnavailable => '原訊息已無法顯示';

  @override
  String get cancelReply => '取消回覆';

  @override
  String get unreadMessages => '以下為未讀訊息';

  @override
  String get selectChat => '請選擇聊天室';

  @override
  String get appPermissions => 'App 權限';

  @override
  String get noPermissionsRequiredDevice => '此裝置沒有需要授權的項目';

  @override
  String get allowAll => '全部允許';

  @override
  String get camera => '相機';

  @override
  String get photosRead => '相簿（讀取）';

  @override
  String get photosSave => '相簿（寫入／儲存）';

  @override
  String get microphone => '麥克風';

  @override
  String get location => '定位';

  @override
  String get orderUpdatesChatMessagesAnnouncements => '訂單進度、聊天訊息與公告';

  @override
  String get scanBarcodesTakeBookPhotos => '掃描條碼與拍攝書籍照片';

  @override
  String get chooseBookPhotosProfilePicturesChat => '選取書籍照片、大頭貼與聊天圖片';

  @override
  String get saveQrCodesPhotos => '將 QR Code 儲存至相簿';

  @override
  String get recordVoiceMessagesChats => '錄製聊天語音訊息';

  @override
  String get showNearestSmartLockersTheirDistance => '顯示最近的智慧書櫃與距離';

  @override
  String get quickSignPaymentConfirmation => '快速登入與確認付款';

  @override
  String get allowed => '已允許';

  @override
  String get limited => '部分允許';

  @override
  String get notAllowed => '未允許';

  @override
  String get restricted => '受系統限制';

  @override
  String get denied => '已拒絕';

  @override
  String get allow => '允許';

  @override
  String get homeRecommendations => '首頁推薦區塊';

  @override
  String get leaveGroup => '退出群組';

  @override
  String leaveP0(Object p0) => '確定要退出「${p0}」？';

  @override
  String get leave => '退出';

  @override
  String get leftGroup => '已退出群組';

  @override
  String get unpin => '取消釘選';

  @override
  String get pin => '釘選';

  @override
  String get you3 => '您';

  @override
  String get canOnlyEditMessagesSentWithin => '僅能編輯 15 分鐘內傳送的訊息';

  @override
  String p0UnsentMessage(Object p0) => '${p0} 已收回一則訊息';

  @override
  String readByP0(Object p0) => '已讀 ${p0}';

  @override
  String get transferDetailsUnavailable => '無法顯示轉帳資訊';

  @override
  String get couldNotCreateGroup => '無法建立群組';

  @override
  String get groupDetails => '群組資料';

  @override
  String get selectMembers => '選擇成員';

  @override
  String get groupName => '群組名稱';

  @override
  String membersP0(Object p0) => '成員 ${p0}';

  @override
  String get createGroup => '建立群組';

  @override
  String get inviteMembers => '邀請成員';

  @override
  String get invite => '邀請';

  @override
  String canSelectUpP0People(Object p0) => '最多可選擇 ${p0} 人';

  @override
  String get noChatsChooseFrom => '沒有可選擇的聊天對象';

  @override
  String get noMatchingPeople => '找不到符合的對象';

  @override
  String get searchByName => '搜尋名稱';

  @override
  String get chatPinned => '已釘選聊天室';

  @override
  String get unpinned => '已取消釘選';

  @override
  String get setNickname => '設定暱稱';

  @override
  String get onlyVisible => '僅自己可見';

  @override
  String get nicknameRemoved => '已移除暱稱';

  @override
  String get nicknameUpdated => '已更新暱稱';

  @override
  String get enterGroupName => '請輸入群組名稱';

  @override
  String get groupNameUpdated => '已更新群組名稱';

  @override
  String get groupPhotoUpdated => '已更新群組頭貼';

  @override
  String get groupReachedMemberLimit => '群組成員已達上限';

  @override
  String invitedP0Members(Object p0) => '已邀請 ${p0} 位成員';

  @override
  String get removeMember => '移除成員';

  @override
  String removeP0FromGroup(Object p0) => '確定要將「${p0}」移出群組？';

  @override
  String get memberRemoved => '已移除成員';

  @override
  String get chatSettings => '聊天室設定';

  @override
  String get muteNotifications => '靜音通知';

  @override
  String get pinChat => '釘選聊天室';

  @override
  String get me => '我';

  @override
  String requestedFromP0(Object p0) => '向 ${p0} 請款';

  @override
  String p0RequestedPaymentFrom(Object p0) => '${p0} 向您請款';

  @override
  String p0RequestedPaymentFromP1(Object p0, Object p1) => '${p0} 向 ${p1} 請款';

  @override
  String sentP0(Object p0) => '轉帳給 ${p0}';

  @override
  String p0SentCoins(Object p0) => '${p0} 轉帳給您';

  @override
  String p0SentCoinsP1(Object p0, Object p1) => '${p0} 轉帳給 ${p1}';

  @override
  String get expired2 => '已逾期';

  @override
  String get payNow => '立即付款';

  @override
  String get cancelRequest => '取消請款';

  @override
  String get request => '請款';

  @override
  String get transfer => '轉帳';

  @override
  String dueP0(Object p0) => '期限 ${p0}';

  @override
  String transferP0(Object p0) => '轉帳給 ${p0}';

  @override
  String sentP0CoinsP1(Object p0, Object p1) => '已轉帳 ${p0} 代幣給 ${p1}';

  @override
  String get confirmPayment => '確認付款';

  @override
  String payP0CoinsP1(Object p0, Object p1) => '支付 ${p0} 代幣給 ${p1}';

  @override
  String get declineRequest => '婉拒請款';

  @override
  String declineP1CoinRequestFromP0(Object p0, Object p1) => '婉拒 ${p0} 的 ${p1} 代幣請款';

  @override
  String cancelRequestP0P1Coins(Object p0, Object p1) => '取消向 ${p0} 請款 ${p1} 代幣';

  @override
  String payRequestFromP0(Object p0) => '支付 ${p0} 的請款';

  @override
  String get paymentCompleted => '已完成付款';

  @override
  String get requestDeclined => '已婉拒請款';

  @override
  String get requestCanceled => '已取消請款';

  @override
  String get selectPayer => '請選擇付款人';

  @override
  String get selectRecipient => '請選擇收款人';

  @override
  String get sendRequest2 => '送出請款';

  @override
  String get confirmTransfer => '確認轉帳';

  @override
  String get payer => '付款人';

  @override
  String get recipient => '收款人';

  @override
  String limitPerTransferP0Coins(Object p0) => '單筆上限 ${p0} 代幣';

  @override
  String insufficientBalanceP0Coins(Object p0) => '餘額不足（${p0} 代幣）';

  @override
  String balanceP0Coins(Object p0) => '餘額 ${p0} 代幣';

  @override
  String get noteOptional => '備註（選填）';

  @override
  String get editMessage => '編輯訊息';

  @override
  String get cancelEditing => '取消編輯';

  @override
  String get send => '傳送';

  @override
  String get switchKeyboard => '切換至鍵盤';

  @override
  String get voiceMessage => '語音訊息';

  @override
  String get edited => '已編輯';

  @override
  String get maximumRecordingLengthReached => '已達錄音上限';

  @override
  String get recordingTooShort => '錄音時間過短';

  @override
  String p0SRemaining(Object p0) => '剩餘 ${p0} 秒';

  @override
  String get releaseSend => '放開即可傳送';

  @override
  String get recording => '錄音中';

  @override
  String get tapHoldRecord => '點按或按住以錄音';

  @override
  String get stopRecording => '停止錄音';

  @override
  String get preview2 => '試聽';

  @override
  String get startRecording => '開始錄音';

  @override
  String get microphoneUnavailable => '無法使用麥克風';

  @override
  String get paymentRequest => '[請款]';

  @override
  String get transfer2 => '[轉帳]';

  @override
  String get transfer3 => '轉入';

  @override
  String get transferOut => '轉出';

  @override
  String get deleteBook => '刪除書籍';

  @override
  String p0PermanentlyDeletedCannotRestoredSeller(Object p0) => '《${p0}》將永久刪除且無法復原，賣家將收到通知。';

  @override
  String get reasonDeletionOptional => '刪除原因（選填）';

  @override
  String get bookDeleted2 => '已刪除書籍';

  @override
  String get rotate => '旋轉';

  @override
  String get mentioned => '[提及您]';

  @override
  String get saveImage => '儲存圖片';

  @override
  String get everyone => '所有人';

  @override
  String get mentionMembers => '提及成員';

  @override
  String get removeAdminRole => '解除管理員身分';

  @override
  String makeP0Admin(Object p0) => '確定要將 ${p0} 設為管理員？';

  @override
  String removeAdminRoleFromP0(Object p0) => '確定要解除 ${p0} 的管理員身分？';

  @override
  String get remove2 => '解除';

  @override
  String p0NowAdmin(Object p0) => '已將 ${p0} 設為管理員';

  @override
  String removedAdminRoleFromP0(Object p0) => '已解除 ${p0} 的管理員身分';

  @override
  String photosP02(Object p0) => '[${p0} 張圖片]';

  @override
  String get savedDownloads => '已儲存至「下載項目」';

  @override
  String get couldNotSaveImage => '無法儲存圖片';

  @override
  String savingImagesP0P1(Object p0, Object p1) => '正在儲存圖片 ${p0} / ${p1}';

  @override
  String get savingImage => '正在儲存圖片';

  @override
  String get passwordsCanOnlyContainEnglishLetters => '密碼僅可使用英文字母、數字及半形符號';

  @override
  String get aiSupport => 'AI 客服';

  @override
  String get howDoIListBook => '如何上架書籍？';

  @override
  String get howDoIPickUpFrom => '如何至書櫃取書？';

  @override
  String get howDoIRequestRefund => '如何申請退款？';

  @override
  String get howDoWalletCoinsWork => '代幣如何使用？';

  @override
  String get talkPerson => '轉接客服人員';

  @override
  String get supportRequestCreatedFromConversationOur => '將轉接客服人員，並提供目前的對話內容';

  @override
  String get transfer4 => '轉接';

  @override
  String get creatingSupportRequest => '正在轉接客服';

  @override
  String get transferredSupportTeam => '已轉接客服人員';

  @override
  String get newConversation => '開始新對話';

  @override
  String get currentConversationEnd => '目前的對話將會結束';

  @override
  String get copied2 => '已複製';

  @override
  String get howCanWeHelp => '請問有什麼需要協助的地方？';

  @override
  String get failedSend => '傳送失敗';

  @override
  String get ourSupportTeamCanHelpWith => '此問題建議由客服人員協助處理';

  @override
  String get contactSupport => '聯絡客服';

  @override
  String get typeQuestion => '輸入問題';

  @override
  String get aiFeatures => 'AI 功能';

  @override
  String get aiSettingsNotSavedChangesLost => 'AI 設定尚未儲存，離開後變更將不會保留';

  @override
  String get usage => '用量';

  @override
  String reviewP0(Object p0) => '審核 ${p0}';

  @override
  String get dailyCost => '每日費用';

  @override
  String get noCostPeriod => '此期間尚無費用';

  @override
  String get peakDay => '單日最高';

  @override
  String p0Requests(Object p0) => '${p0} 次請求';

  @override
  String get listingAssist => '上架輔助';

  @override
  String get recommendations => '推薦書籍';

  @override
  String get listingReview => '上架審核';

  @override
  String get connectionTest => '連線測試';

  @override
  String get today2 => '今日';

  @override
  String get k7Days => '7 天';

  @override
  String get k30Days => '30 天';

  @override
  String get notBookUnrelatedItem => '非書籍或無關商品';

  @override
  String get prohibitedPiratedContent => '違禁或盜版內容';

  @override
  String get adultContent => '成人內容';

  @override
  String get offPlatformDealContactInfo => '站外交易或聯絡資訊';

  @override
  String get misleadingDescription => '不實描述';

  @override
  String get unusualPrice => '價格異常';

  @override
  String get providerError => '服務商錯誤';

  @override
  String get timedOut => '逾時';

  @override
  String get noApiKey => '未設定金鑰';

  @override
  String get rateLimited => '頻率受限';

  @override
  String get invalidApiKey => '金鑰無效';

  @override
  String get invalidResponseFormat => '回應格式錯誤';

  @override
  String get rejectListing => '拒絕上架';

  @override
  String get noteOptionalSentSeller => '說明（選填，將通知賣家）';

  @override
  String get reject => '拒絕';

  @override
  String get listingApproved => '已核准上架';

  @override
  String get listingRejected => '已拒絕上架';

  @override
  String get noListingsAwaitingReview => '目前沒有待審核的上架';

  @override
  String get likelyViolation => '疑似違規';

  @override
  String get needsReview => '需人工確認';

  @override
  String get rejected => '已拒絕';

  @override
  String get approve => '核准上架';

  @override
  String get pleaseFixHighlightedFields => '請修正標示錯誤的欄位';

  @override
  String get aiSettingsSaved => 'AI 設定已儲存';

  @override
  String get invalidFormat => '格式不正確';

  @override
  String enter0P0(Object p0) => '請輸入 0 至 ${p0}';

  @override
  String get databaseNotBeenUpdatedAiYet => '資料庫尚未完成 AI 相關更新，設定儲存後暫時不會生效';

  @override
  String get defaultModel => '預設模型';

  @override
  String get features => '功能';

  @override
  String get on => '已啟用';

  @override
  String get noProviderApiKeysSetSo => '尚未設定任何服務商金鑰，AI 功能無法使用';

  @override
  String p0NoApiKeyCannotSelected(Object p0) => '${p0} 尚未設定金鑰，無法選用';

  @override
  String get input => '輸入';

  @override
  String get output => '輸出';

  @override
  String get per1mTokens => '每百萬 tokens';

  @override
  String get vision => '圖片辨識';

  @override
  String get webSearch => '上網搜尋';

  @override
  String get testing => '測試中';

  @override
  String get test => '測試連線';

  @override
  String connectedP0Ms(Object p0) => '連線成功・${p0} ms';

  @override
  String get connectionFailed => '連線失敗';

  @override
  String get keySet => '金鑰已設定';

  @override
  String get noKey => '金鑰未設定';

  @override
  String get model => '使用模型';

  @override
  String defaultP0(Object p0) => '跟隨預設（${p0}）';

  @override
  String p0NoApiKey(Object p0) => '${p0} 尚未設定金鑰';

  @override
  String p0DoesNotSupportWebSearch(Object p0) => '${p0} 不支援上網搜尋';

  @override
  String get searchNotBilledSeparately => '搜尋不另計費';

  @override
  String firstP0SearchesFreeEachMonth(Object p0, Object p1) => '每月前 ${p0} 次免費，之後每千次 ${p1}';

  @override
  String p0Per1000SearchesPlus(Object p0) => '每千次搜尋 ${p0}，另計搜尋內容 tokens';

  @override
  String get suspiciousListings => '可疑商品處理方式';

  @override
  String get holdReview => '送交審核';

  @override
  String get rejectClearViolations => '直接拒絕明顯違規';

  @override
  String get budgetLimits => '預算與上限';

  @override
  String get monthlyBudgetUsd => '每月預算（USD）';

  @override
  String get k0MeansNoCap => '0 為不設上限';

  @override
  String get dailyLimitPerMember => '每位會員每日次數上限';

  @override
  String get k0MeansUnlimited => '0 為不限';

  @override
  String get advanced => '進階設定';

  @override
  String get resetDefault => '恢復預設';

  @override
  String get modelId => '模型 ID';

  @override
  String get priceUsPer1mTokens => '單價（US\$ / 每百萬 tokens）';

  @override
  String get cachedInput => '快取輸入';

  @override
  String get searchPriceUsPer1000 => '搜尋單價（US\$ / 千次）';

  @override
  String get freeSearchesPerMonth => '每月免費搜尋次數';

  @override
  String p0FieldsInvalid(Object p0) => '${p0} 個欄位格式不正確';

  @override
  String p0UnsavedChanges(Object p0) => '${p0} 項設定尚未儲存';

  @override
  String get unsavedChanges => '有未儲存的變更';

  @override
  String get month2 => '本月費用';

  @override
  String budgetP0(Object p0) => '預算 ${p0}';

  @override
  String get noMonthlyBudget => '未設定每月預算';

  @override
  String projectedP0(Object p0) => '預估月底 ${p0}';

  @override
  String get periodCost => '期間費用';

  @override
  String get requests => '請求次數';

  @override
  String p0Searches(Object p0) => '搜尋 ${p0} 次';

  @override
  String p0OutP1(Object p0, Object p1) => '輸入 ${p0}・輸出 ${p1}';

  @override
  String get errors => '錯誤';

  @override
  String errorRateP0(Object p0) => '錯誤率 ${p0}%';

  @override
  String p0ListingsAwaitingReview(Object p0) => '${p0} 筆上架待審核';

  @override
  String get byFeature => '依功能';

  @override
  String get noDataYet => '尚無資料';

  @override
  String errorsP0(Object p0) => '錯誤 ${p0}';

  @override
  String p0Calls(Object p0) => '${p0} 次';

  @override
  String get byModel => '依模型';

  @override
  String p0CallsP1Ms(Object p0, Object p1) => '${p0} 次・${p1} ms';

  @override
  String get topMembers => '用量最高的會員';

  @override
  String p0Uses(Object p0) => '${p0} 次';

  @override
  String get recentErrors => '最近錯誤';

  @override
  String get noErrors => '沒有錯誤';

  @override
  String get fillWithAi => 'AI 帶入';

  @override
  String get summary => '簡介';

  @override
  String get lookingUpBookDetails => '查詢書籍資料';

  @override
  String get searchingWeb => '上網搜尋補充資料';

  @override
  String get analyzingPhotos => '分析照片';

  @override
  String get suggestingCategoryConditionPrice => '判斷分類、書況與售價';

  @override
  String get couldNotGetAiSuggestions => '無法取得 AI 建議';

  @override
  String get done => '分析完成';

  @override
  String get aiAnalyzing => 'AI 分析中';

  @override
  String get aiSuggestions => 'AI 建議';

  @override
  String get noSuggestionsApply => '沒有可帶入的建議';

  @override
  String get bookDetails => '書籍資料';

  @override
  String get suggestedPrice => '建議售價';

  @override
  String rangeP0P1(Object p0, Object p1) => '建議區間 \$${p0}–\$${p1}';

  @override
  String listPriceP0(Object p0) => '定價 \$${p0}';

  @override
  String applyP0(Object p0) => '套用 ${p0} 項';

  @override
  String currentP0(Object p0) => '目前：${p0}';

  @override
  String get sameAsCurrent => '與目前相同';

  @override
  String get listingNotApproved => '未通過上架審核';

  @override
  String get editListing => '修改內容';

  @override
  String get submittedReview => '已送交審核';

  @override
  String get goSaleOnceApprovedNotifiedResult => '審核通過後將公開販售';

  @override
  String get got => '確定';

  @override
  String get aiFeaturesNotAvailableRightNow => 'AI 功能目前未開放';

  @override
  String get bookUnderReviewGoSaleOnce => '此書籍正在審核，通過後將公開販售';

  @override
  String get notApproved => '未通過審核';

  @override
  String get bookDidNotPassListingReview => '此書籍未通過上架審核';

  @override
  String get enterIsbnTitleFirst => '請先輸入 ISBN 或書名';

  @override
  String appliedP0AiSuggestions(Object p0) => '已套用 ${p0} 項 AI 建議';

  @override
  String get addBookPhotosFirst => '請先加入書籍照片';

  @override
  String get nothingFoundFillCheckIsbnTitle => '找不到可帶入的資料，請確認 ISBN 或書名';

  @override
  String appliedP0AiSuggestions2(Object p0) => '已套用 ${p0} 項 AI 建議';

  @override
  String get aiDataProcessingEnabled => '已同意 AI 資料處理';

  @override
  String get aiDataProcessingTurnedOff => '已停止 AI 資料處理';

  @override
  String get aiDataProcessing => 'AI 資料處理';

  @override
  String get messagesEnterStatusOrdersReservations => '您輸入的訊息與您的訂單、預約狀態';

  @override
  String get isbnTitleConditionNotesPhotosSelect => 'ISBN、書名、書況說明與您選擇的照片';

  @override
  String get bookDetailsFromFavoritesPurchaseHistory => '您的收藏與購買紀錄中的書籍資訊';

  @override
  String get aiDataProcessing2 => 'AI 資料處理說明';

  @override
  String get whenUseAiFeaturesWeShare => '使用 AI 功能時，我們會將下列資料提供給第三方 AI 服務商處理。';

  @override
  String get dataShared => '提供的資料';

  @override
  String get recipients => '資料接收者';

  @override
  String get purpose => '使用目的';

  @override
  String get usedOnlyGenerateSupportRepliesPrepare => '僅用於產生客服回覆、整理上架資料與推薦書籍，不會用於廣告或追蹤。';

  @override
  String get withdrawingConsent => '撤回同意';

  @override
  String get canTurnOffAiDataProcessing => '您可隨時於「設定 › 帳號管理」關閉「AI 資料處理」，關閉後將不再提供上述資料。';

  @override
  String get agreeContinue => '同意並繼續';

  @override
  String get insufficientQuotaPlanNotEnabled => '額度不足或方案未開通';

  @override
  String get modelNotFound => '模型名稱不存在';

  @override
  String get invalidRequestParameters => '請求參數不正確';

  @override
  String get couldNotConnectService => '無法連線至服務';

  @override
  String get blockedByProviderSafetySystem => '內容遭服務安全機制拒絕';

  @override
  String get responseExceededOutputLimit => '回應超過輸出長度上限';

  @override
  String get serverProcessingError => '伺服器處理錯誤';

  @override
  String get aiBookAdvisor => 'AI 書籍顧問';

  @override
  String get requiresDatabaseUpdate013 => '需先執行資料庫更新 013';

  @override
  String get mysteryNovelMyCommute => '適合通勤閱讀的推理小說';

  @override
  String get programmingBooksBeginners => '適合入門的程式設計書';

  @override
  String get booksUnder200Coins => '200 代幣以內的書籍';

  @override
  String get popularLiteraryFictionRightNow => '最近熱門的文學小說';

  @override
  String get tellMeWhatBookLooking => '請描述您想找的書籍';

  @override
  String get describeBookLooking => '描述您想找的書籍';

  @override
  String get tellMeWhatWantReadI => '依您的需求推薦書籍';

  @override
  String get subtitle => '副標題';

  @override
  String get monthOnly => '僅確認到月';

  @override
  String get yearOnly => '僅確認到年';

  @override
  String get msg => '繁體中文';

  @override
  String get additionalInformation => '其他資訊';

  @override
  String get readFull => '展開全文';

  @override
  String get pages => '頁數';

  @override
  String get simplifiedChinese => '簡體中文';

  @override
  String get chinese => '中文';

  @override
  String get english => '英文';

  @override
  String get japanese => '日文';

  @override
  String get korean => '韓文';

  @override
  String p0Pages(Object p0) => '${p0} 頁';

  @override
  String get collapse => '收合';

  @override
  String get setPasswordFirst => '請先設定密碼';

  @override
  String get setPassword => '設定密碼';

  @override
  String get signMethodSettingsSaved => '登入方式設定已儲存';

  @override
  String get signMethodSettingsUnsavedLeavingDiscards => '登入方式設定尚未儲存，離開後變更將遺失。';

  @override
  String get serverNotRunDatabaseUpdate014 => '伺服器尚未執行資料庫更新 014，設定暫時無法生效。';

  @override
  String get signChannels => '各項登入方式';

  @override
  String get socialSmsSign => '社群與簡訊登入';

  @override
  String get whenOffSignPageHidesThese => '關閉後登入頁不再顯示這些方式，已綁定的帳號仍可用密碼登入。';

  @override
  String get notConfigured => '未設定';

  @override
  String get allowCreatingNewAccountsWithMethod => '允許以此方式註冊新帳號';

  @override
  String get unsavedChanges2 => '尚未儲存的變更';

  @override
  String get taiwan => '中華民國';

  @override
  String get hongKong => '香港';

  @override
  String get macau => '澳門';

  @override
  String get china => '中華人民共和國';

  @override
  String get japan => '日本';

  @override
  String get southKorea => '韓國';

  @override
  String get singapore => '新加坡';

  @override
  String get malaysia => '馬來西亞';

  @override
  String get unitedStatesCanada => '美國／加拿大';

  @override
  String get unitedKingdom => '英國';

  @override
  String get australia => '澳洲';

  @override
  String get countryCode => '國碼';

  @override
  String get enterValidMobileNumber => '請輸入正確的手機號碼';

  @override
  String get couldNotSendCodePleaseTry => '無法傳送驗證碼，請稍後再試';

  @override
  String get linkMobileNumber => '綁定手機號碼';

  @override
  String get signWithMobileNumber => '手機號碼登入';

  @override
  String get k6DigitCodeSentNumberMessage => '將傳送 6 位數驗證碼至此手機號碼。';

  @override
  String get mobileNumber => '手機號碼';

  @override
  String get sendCode => '傳送驗證碼';

  @override
  String get codeIncorrectPleaseEnterAgain => '驗證碼不正確，請重新輸入';

  @override
  String get codeBeenSentAgain => '已重新傳送驗證碼';

  @override
  String get enterCode => '輸入驗證碼';

  @override
  String get enterSmsCode => '輸入簡訊驗證碼';

  @override
  String codeWasSentP0(Object p0) => '驗證碼已傳送至 ${p0}';

  @override
  String canResendP0S(Object p0) => '${p0} 秒後可重新傳送';

  @override
  String get resendCode => '重新傳送驗證碼';

  @override
  String get completeAccountDetails => '完成帳號資料';

  @override
  String get p0DidNotProvideEmailAddress => '請填寫電子郵件以完成註冊。';

  @override
  String signWithP0(Object p0) => '以 ${p0} 登入';

  @override
  String get signWith2 => '或使用以下方式登入';

  @override
  String get creatingAccountWithMethodsAboveMeans => '使用上述方式建立帳號即表示您同意服務條款與隱私權政策';

  @override
  String get emailAlreadyRegistered => '此電子郵件已註冊';

  @override
  String get signWithPasswordThenLinkMethod => '請以密碼登入後，至「帳號安全 › 登入方式」綁定。';

  @override
  String get signWithPassword => '以密碼登入';

  @override
  String get accountNoPasswordYet => '此帳號尚未設定密碼';

  @override
  String get passwordSet => '密碼已設定';

  @override
  String get canNowSignWithEmailPassword => '其他裝置須重新登入。';

  @override
  String get passwordRequiredBeforeCanUnlinkSign => '密碼須至少 8 碼，且包含英文與數字。';

  @override
  String get changingSignMethodsRequiresIdentityVerification => '變更登入方式前，請先設定密碼。';

  @override
  String get later => '暫不設定';

  @override
  String p0Linked(Object p0) => '已綁定 ${p0}';

  @override
  String unlinkP0(Object p0) => '解除綁定 ${p0}';

  @override
  String get noLongerAbleSignWayCan => '解除後將無法以此方式登入。';

  @override
  String get unlink => '解除綁定';

  @override
  String p0Unlinked(Object p0) => '已解除綁定 ${p0}';

  @override
  String get socialSmsSignNotAvailableRight => '目前未開放社群與簡訊登入方式。';

  @override
  String get noSignMethodAvailableLink => '目前沒有可綁定的登入方式。';

  @override
  String get noPasswordSet => '尚未設定密碼';

  @override
  String linkedP0(Object p0) => '${p0} 綁定';

  @override
  String get link => '綁定';

  @override
  String get emailAlreadyRegisteredSignWithPassword => '此電子郵件已註冊，請先以密碼登入後，於帳號安全綁定此登入方式';

  @override
  String get provideEmailAddressCreateAccount => '請提供電子郵件以建立帳號';

  @override
  String get signMethodOnlyExistingAccounts => '此登入方式僅供既有帳號使用';

  @override
  String get signMethodNotAvailableRightNow => '目前未開放此登入方式';

  @override
  String get credentialDoesNotMatchSelectedSign => '登入失敗，請重新操作';

  @override
  String get signMethodLinkedAnotherAccount => '此登入方式已綁定其他帳號';

  @override
  String get accountAlreadyLinkedSignMethod => '此帳號已綁定此登入方式';

  @override
  String get onlySignMethodAccountSetPassword => '這是此帳號唯一的登入方式，請先設定密碼或綁定其他登入方式';

  @override
  String get socialSignUnavailableServerNotFinished => '社群登入暫時無法使用，請稍後再試';

  @override
  String get credentialInvalidExpiredPleaseTryAgain => '登入逾時，請重新操作';

  @override
  String get accountAlreadyPasswordUseChangePassword => '此帳號已設定密碼，請改用變更密碼';

  @override
  String get signLinkExpiredPleaseTryAgain => '登入連結已失效，請重新操作';

  @override
  String get signResultExpiredPleaseTryAgain => '登入逾時，請重新操作';

  @override
  String get thirdPartySignServiceUnavailablePlease => '第三方登入服務目前無法使用，請稍後再試';

  @override
  String get couldNotCompleteSignPleaseTry => '無法完成登入，請重新操作';

  @override
  String get accountNotLinkedSignMethod => '此帳號未綁定此登入方式';

  @override
  String get mobileNumberFormatNotValid => '手機號碼格式不正確';

  @override
  String get verificationTimedOutRequestNewCode => '驗證已逾時，請重新取得驗證碼';

  @override
  String get codeExpiredRequestNewOne => '驗證碼已逾時，請重新取得驗證碼';

  @override
  String get tooManyAttemptsPleaseTryAgain => '嘗試次數過多，請稍後再試';

  @override
  String get smsSendingLimitBeenReachedPlease => '簡訊發送次數已達上限，請稍後再試';

  @override
  String get smsVerificationNotSetUpDevice => '此裝置目前無法使用簡訊驗證，請改用其他登入方式';

  @override
  String get couldNotCompleteSmsVerificationPlease => '無法完成簡訊驗證，請稍後再試';

  @override
  String get allowSigningLinkingWithMethod => '開放此方式登入與綁定';

  @override
  String get appNeverStoresPasswordUsedOnly => '本 App 不會儲存您的密碼，僅用於本次驗證。';

  @override
  String get verifyWithBiometricsInstead => '改用生物辨識驗證';

  @override
  String get accountWasCreatedWithSocialPhone => '此帳號尚未設定登入密碼，請先完成設定。';

  @override
  String get setSignPassword => '前往設定登入密碼';

  @override
  String get enterSignPasswordRunAdminAction => '請以登入密碼或通行密鑰驗證身分以執行此後台操作';

  @override
  String p1P0MethodsEnabled(Object p0, Object p1) => '共 ${p0} 種方式，目前啟用 ${p1} 種';

  @override
  String get masterSwitchOffSoEveryMethod => '總開關關閉，所有方式一律停用';

  @override
  String get signLinkingDirectSignUpAllowed => '可登入、綁定與直接註冊';

  @override
  String credentialsNotSetPleaseConfigureP0(Object p0) => '尚未設定憑證，請於伺服器設定 ${p0}';

  @override
  String get whenOffMethodHiddenFromSign => '關閉後登入頁與帳號安全將不顯示此方式';

  @override
  String get whenOffOnlyAccountsAlreadyLinked => '關閉後僅限已綁定的帳號使用此方式';

  @override
  String get signMethodNotLinkedAccount => '此登入方式尚未綁定帳號';

  @override
  String p0AccountNotLinkedAnySavemybook(Object p0) => '${p0} 帳號尚未綁定救「舊」我的書帳號。';

  @override
  String get iAlreadyAccountSignFirst => '登入既有帳號並綁定';

  @override
  String get createNewAccountWithIdentity => '建立新帳號';

  @override
  String signExistingAccountFirstThenLink(Object p0) => '請先登入原有帳號，再至「帳號安全 › 登入方式」綁定 ${p0}。';

  @override
  String get signMethodNotLinkedAnyAccount => '此登入方式尚未綁定任何帳號';

  @override
  String get verifyIdentityWithPasskeyContinue => '請使用通行密鑰驗證身分以繼續';

  @override
  String get verifyWithPasskeyInstead => '改用通行密鑰驗證';

  @override
  String get passkeys => '通行密鑰';

  @override
  String get verifyWithFaceIdFingerprintScreen => '以此裝置的 Face ID、指紋或螢幕鎖定完成驗證，不必輸入密碼。';

  @override
  String get verifyWithPasskey => '使用通行密鑰驗證';

  @override
  String get useSignPasswordInstead => '改用登入密碼驗證';

  @override
  String get signWithPasskey => '使用通行密鑰登入';

  @override
  String get passkeyAdded => '已新增通行密鑰';

  @override
  String get screenLock => '螢幕鎖定';

  @override
  String fromNowCanSignVerifyIdentity(Object p0) => '之後登入與驗證身分可改用 ${p0}，不必再輸入密碼。';

  @override
  String get deletePasskey => '刪除通行密鑰';

  @override
  String get noLongerAbleSignVerifyIdentity => '刪除後將無法以此通行密鑰登入或驗證身分。裝置中儲存的通行密鑰不會一併移除，可至系統的密碼設定中刪除。';

  @override
  String get passkeyDeleted => '已刪除通行密鑰';

  @override
  String get signVerifyIdentityWithFaceId => '以 Face ID、指紋或螢幕鎖定登入與驗證身分，不必輸入密碼。通行密鑰只儲存在您的裝置與密碼管理工具中。';

  @override
  String get addPasskey => '新增通行密鑰';

  @override
  String get notUsedYet => '尚未使用';

  @override
  String lastUsedFormatdateItemLastusedat(Object p0) => '最後使用 ${p0}';

  @override
  String createdCreated(Object p0) => '建立於 ${p0}';

  @override
  String get noPasskeyAvailableDeviceUsePassword => '此裝置沒有可用的通行密鑰，請改用密碼';

  @override
  String get passkeyAlreadyRegisteredDevice => '此裝置已經註冊過通行密鑰';

  @override
  String get signGoogleAccountTurnPasswordManager => '請先在裝置上登入 Google 帳號並開啟密碼管理工具，或改用密碼';

  @override
  String get setUpScreenLockPasswordManager => '此裝置尚未設定螢幕鎖定或密碼管理工具，無法建立通行密鑰';

  @override
  String get deviceDoesNotSupportPasskeysUse => '此裝置不支援通行密鑰，請改用密碼';

  @override
  String get passkeysTemporarilyUnavailableBecauseAppWebsite => '目前無法使用通行密鑰，請改用密碼';

  @override
  String get requestTimedOutPleaseTryAgain => '操作逾時，請再試一次';

  @override
  String get passkeyRequestFailedUsePasswordInstead => '通行密鑰操作失敗，請改用密碼';

  @override
  String get verifyIdentityBeforeAddingPasskey => '新增通行密鑰前，請先驗證身分';

  @override
  String get couldNotListPleaseTryAgain => '上架失敗，請稍後再試';

  @override
  String downloadLinkValidOnceP0P1(Object p0, Object p1) => '此下載網址 5 分鐘內有效，且僅能使用一次，請勿分享。\n\n${p0}\n\n檔案大小：${p1}';

  @override
  String get sources => '資料來源';

  @override
  String get unableOpenLink => '無法開啟連結';

  @override
  String get helpCentre2 => '客服中心';

  @override
  String get preferences => '偏好設定';

  @override
  String get privacy => '隱私';

  @override
  String get about2 => '關於';

  @override
  String clearP0Notifications(Object p0) => '清除${p0}通知';

  @override
  String p1NotificationsP0DeletedCannotUndone(Object p0, Object p1) => '將刪除${p0}類的 ${p1} 則通知，此操作無法復原。';

  @override
  String p0NotificationsCleared(Object p0) => '已清除${p0}通知';

  @override
  String markAllP1UnreadNotificationsP0(Object p0, Object p1) => '確定要將${p0}類的 ${p1} 則未讀通知全部標為已讀？';

  @override
  String get offers => '優惠';

  @override
  String get noTransactionNotifications => '沒有交易通知';

  @override
  String get noChatNotifications => '沒有聊天通知';

  @override
  String get noAccountNotifications => '沒有帳號通知';

  @override
  String get noSupportNotifications => '沒有客服通知';

  @override
  String get noOfferNotifications => '沒有優惠通知';

  @override
  String get images => '圖片';

  @override
  String get imagesStillUploadingPleaseWaitBefore => '圖片上傳中，請稍候再送出';

  @override
  String get someImagesFailedUploadRetryRemove => '部分圖片上傳失敗，請重試或移除後再送出';

  @override
  String get attachImages => '附加圖片';

  @override
  String get imageCouldNotRead => '無法讀取這張圖片';

  @override
  String get up4ImagesPerMessage => '每則訊息最多附加 4 張圖片';

  @override
  String retryUploadingImageP0(Object p0) => '重試上傳圖片 ${p0}';

  @override
  String removeImageP0(Object p0) => '移除圖片 ${p0}';

  @override
  String get addImages => '新增圖片';

  @override
  String viewImageP0(Object p0) => '檢視圖片 ${p0}';

  @override
  String get eGGoldMember => '例如：黃金會員';

  @override
  String get pointsThreshold => '門檻點數';

  @override
  String get pts => '點';

  @override
  String get tierBenefits => '等級福利';

  @override
  String get oneBenefitPerLine => '每行一項福利';

  @override
  String get newTier2 => '新等級';

  @override
  String get whatMembersSee => '會員看到的樣式';

  @override
  String get noThresholdSet => '尚未設定門檻';

  @override
  String get tierOrder => '等級順序';

  @override
  String get noBenefitsSet => '尚未設定福利';

  @override
  String p0CurrentlyP1MembersAfterDeletion(Object p0, Object p1, Object p2) => '「${p0}」目前有 ${p1} 位會員，刪除後將改列「${p2}」。';

  @override
  String noMembersCurrentlyP0OtherTiers(Object p0) => '目前沒有會員屬於「${p0}」，刪除後其他等級不受影響。';

  @override
  String tierDeletedP0MembersMovedP1(Object p0, Object p1) => '已刪除等級，${p0} 位會員改列「${p1}」';

  @override
  String get changeTierOrder => '調整等級順序';

  @override
  String get thresholdsStayWithTheirPositionThese => '門檻點數依位置保留，以下等級的門檻將變更：';

  @override
  String p0P1P2Pts(Object p0, Object p1, Object p2) => '「${p0}」${p1} → ${p2} 點';

  @override
  String get tierOrderUpdated => '已更新等級順序';

  @override
  String p0Members(Object p0) => '${p0} 位會員';

  @override
  String get tiers => '個等級';

  @override
  String get members4 => '位會員';

  @override
  String get memberDistribution => '會員分布';

  @override
  String get moreActions => '更多操作';

  @override
  String get dragReorder => '拖曳調整順序';

  @override
  String p0Pts(Object p0) => '${p0} 點以上';

  @override
  String p0P1Pts(Object p0, Object p1) => '${p0}–${p1} 點';

  @override
  String tierNamedP0AlreadyExists(Object p0) => '已有名為「${p0}」的等級';

  @override
  String get enterPointsThreshold => '請輸入門檻點數';

  @override
  String get thresholdMustWholeNumber0More => '門檻點數須為 0 以上的整數';

  @override
  String thresholdCannotExceedP0(Object p0) => '門檻點數不可超過 ${p0}';

  @override
  String p0AlreadyUsesP1PtsEach(Object p0, Object p1) => '「${p0}」已使用 ${p1} 點，每個等級的門檻須不同';

  @override
  String get startingTierMustBegin0Pts => '起始等級的門檻須為 0 點';

  @override
  String get startingTierCannotDeletedSetAnother => '起始等級無法刪除，請先將其他等級的門檻調整為 0 點';

  @override
  String get signLink => '登入並綁定';

  @override
  String get signAccount => '登入既有帳號';

  @override
  String emailAlreadyRegisteredSignLinkName(Object p0) => '此電子郵件已註冊，登入後即綁定 ${p0}。';

  @override
  String signLinkNameCanThenSign(Object p0, Object p1) => '登入後即綁定 ${p0}，之後可直接使用 ${p1} 登入。';

  @override
  String get noPasskeyDevice => '此裝置沒有可用的通行密鑰';

  @override
  String get signWithPasskeyAnotherDeviceSecurity => '可使用其他裝置上的通行密鑰或安全金鑰登入，或改用密碼。';

  @override
  String get useAnotherDevice => '使用其他裝置';

  @override
  String get usePassword => '改用密碼';

  @override
  String get icloudKeychain => 'iCloud 鑰匙圈';

  @override
  String get googlePasswordManager => 'Google 密碼管理工具';

  @override
  String get synced => '已同步';

  @override
  String get notSynced => '未同步';

  @override
  String get alreadyPasskey => '已有可用的通行密鑰';

  @override
  String get enterName => '請輸入名稱';

  @override
  String get passkeySavedIcloudKeychainWorksEvery => '通行密鑰已儲存在 iCloud 鑰匙圈，登入同一 Apple 帳號的裝置皆可使用，無須重複新增。如需另外建立，請按「再次新增」並在系統視窗改選其他密碼管理工具或安全金鑰。';

  @override
  String get passkeySavedGooglePasswordManagerWorks => '通行密鑰已儲存在 Google 密碼管理工具，登入同一 Google 帳號的裝置皆可使用，無須重複新增。如需另外建立，請按「再次新增」並在系統視窗改選其他密碼管理工具或安全金鑰。';

  @override
  String get passkeySavedDeviceSPasswordManager => '通行密鑰已儲存在此裝置的密碼管理工具，登入同一帳號的裝置皆可使用，無須重複新增。如需另外建立，請按「再次新增」並在系統視窗改選其他密碼管理工具或安全金鑰。';

  @override
  String get addAgain => '再次新增';

  @override
  String get codeExpiredPleaseRequestNewOne => '驗證碼已失效，請重新傳送';

  @override
  String codeValidP0(Object p0) => '驗證碼有效時間 ${p0}';

  @override
  String get basicSettings => '基本設定';

  @override
  String get eGBirthdayVoucher => '例如：生日禮券';

  @override
  String get benefitDetails => '福利內容';

  @override
  String get addBenefit => '新增福利';

  @override
  String get bookNoLongerExistsBeenRemoved => '此書籍已不存在或已下架';

  @override
  String get myNicknameGroup => '我在群組的暱稱';

  @override
  String get setGroupNickname => '設定群組暱稱';

  @override
  String get allGroupMembersSeeNickname => '群組內所有成員皆會看到此暱稱';

  @override
  String get markLockerMaintenance => '設為維修中';

  @override
  String get endLockerMaintenance => '結束維修';

  @override
  String maintenanceHidesP0FromSellers(Object p0) => '設為維修中後「${p0}」將不再顯示於賣家的存放區域選單，既有訂單不受影響。';

  @override
  String endingMaintenanceP0AvailableAgain(Object p0) => '結束維修後「${p0}」將重新開放賣家選擇。';

  @override
  String get lockerMarkedMaintenance => '書櫃已設為維修中';

  @override
  String get lockerMaintenanceEnded => '書櫃已結束維修';

  @override
  String get semanticIndex => '語意索引';

  @override
  String get semanticSearch => '語意檢索';

  @override
  String p0BooksP1HelpArticlesIndexed(Object p0, Object p1) => '已建立書籍 ${p0} 筆、客服知識 ${p1} 筆';

  @override
  String get noOpenaiGeminiKeyConfiguredOnly => '尚未設定 OpenAI 或 Gemini 金鑰，目前僅使用關鍵字檢索';

  @override
  String get databaseNotBeenUpdated020Only => '資料庫尚未更新（020），目前僅使用關鍵字檢索';

  @override
  String get hybridSearchKeywordSemantic => '混合檢索（關鍵字＋語意）';

  @override
  String get keywordSearchOnly => '僅關鍵字檢索';

  @override
  String get paymentReleasedWalletWhenBuyerCompletes => '買家完成訂單或取書滿 24 小時後，款項將撥入您的錢包';

  @override
  String get completeOrderAfterCheckingBookCompletes => '確認書況無誤後請完成訂單，取書滿 24 小時未申訴將自動完成';

  @override
  String get completeOrder => '完成訂單';

  @override
  String get onceCompleteOrderPaymentReleasedSeller => '完成訂單後，款項將撥給賣家，且無法再申請爭議。';

  @override
  String get orderCompleted2 => '訂單已完成';

  @override
  String get noReservedBooks => '目前沒有預訂的書籍';

  @override
  String heldUntilP02(Object p0) => '保留至 ${p0}';

  @override
  String heldUntilP03(Object p0) => '保留至 ${p0}';

  @override
  String get awaitingBuyerConfirmation => '待買家確認';

  @override
  String get awaitingCompletion => '待完成訂單';

  @override
  String get libraryCopyUnofficialSource => '館藏或非正規來源';

  @override
  String p0CannotEdit(Object p0) => '${p0}・無法編輯';

  @override
  String get buyNow2 => '直接購買';

  @override
  String get suggestRefund => '建議退款';

  @override
  String get suggestDismissal => '建議駁回';

  @override
  String get needsMoreInformation => '需要更多資訊';

  @override
  String get aiAnalysis => 'AI 分析';

  @override
  String get analyze => '開始分析';

  @override
  String get analyzeAgain => '重新分析';

  @override
  String get aiAnalysisReferenceOnlyDecideBased => 'AI 分析僅供參考，請依實際證據裁決。';

  @override
  String p0P1Confidence(Object p0, Object p1) => '${p0}・信心 ${p1}%';

  @override
  String get aiSummary => 'AI 整理';

  @override
  String get autoFilled => '自動補齊';

  @override
  String get similarBooks => '相似的書';

  @override
  String get doNotPayTransferMoneyOutside => '請勿私下匯款或轉帳，站外付款不受平台保障';

  @override
  String get pleaseCompleteDealAppWeCannot => '請透過平台交易，站外交易發生糾紛時平台無法協助';

  @override
  String get personSharedOutsideContactDetailsWatch => '對方提供了站外聯絡方式，請留意詐騙並透過平台完成交易';

  @override
  String get mostRelevant => '最相關';

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
  String get orderRefunding => '审核中';

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
  String get orderFlowPickup => '买家已取书';

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
  String get language => '语言';

  @override
  String get languageSystem => '跟随系统';

  @override
  String get verifySignSavemybook => '验证身分以登录救「舊」我的書';

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
  String get mySavemybookData => '救「舊」我的書账号数据';

  @override
  String get exportedChooseWhereSave => '已导出，请选择保存位置';

  @override
  String get exportedButSharingCouldNotOpen => '导出完成，但无法打开分享';

  @override
  String get regenerateShareLink => '重新生成分享链接';

  @override
  String get oldLinkQrCodeStopWorking => '旧的链接与二维码将立即失效，已分享的链接将无法打开。确定要重新生成吗？';

  @override
  String get regenerate => '重新生成';

  @override
  String get newLinkCreatedOldOneNo => '已生成新链接，旧链接已失效';

  @override
  String get deleteAccount => '删除账号';

  @override
  String get accountPermanentlyDisabled30DaysSign => '账号将于 30 天后删除，期间内重新登录即可取消。删除后将清除个人资料，已完成的订单与交易记录将予以保留。';

  @override
  String get actionContinue => '继续';

  @override
  String get verify => '确认身分';

  @override
  String get enterPasswordConfirm => '请输入密码以确认身份。';

  @override
  String get password => '密码';

  @override
  String get requestDeletion => '申请删除';

  @override
  String get receivedSignAgainWithin30Days => '已受理，30 天内重新登录即可取消';

  @override
  String get deletionCancelledAccountActiveAgain => '已取消删除，账号已恢复';

  @override
  String get account => '账号管理';

  @override
  String get data => '个人数据';

  @override
  String get exportMyData => '导出我的数据';

  @override
  String get cancelAccountDeletion => '取消删除账号';

  @override
  String get deletionPending => '待删除';

  @override
  String daysLeftCanCancelAnyTime(Object p0) => '剩余 ${p0} 天。期限内可随时取消，逾期后个人资料将被清除且无法恢复。';

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
  String bookCannotPurchased(Object p0) => '此书籍目前${p0}，无法购买';

  @override
  String get addedCart => '已加入购物车';

  @override
  String get sellerInformationNotFound => '找不到卖家信息';

  @override
  String get signContactSeller => '请先登录才能联系卖家';

  @override
  String get signStartChat => '请先登录才能联系卖家';

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
  String get reportSubmittedWeLookInto => '举报已提交';

  @override
  String get publisher => '出版社：';

  @override
  String get author => '作者：';

  @override
  String get listed => '上架日期：';

  @override
  String get searchTitleAuthorPublisher => '搜索书名、作者或出版社';

  @override
  String get share => '分享';

  @override
  String get report => '举报';

  @override
  String get about => '简介：';

  @override
  String get messageSeller => '联系卖家';

  @override
  String get listing => '您上架的书籍';

  @override
  String get addCart => '加入购物车';

  @override
  String get bookBeenReportedUnderReviewStays => '此书籍已被举报，审核中。';

  @override
  String get violationWasConfirmedBookPleaseCheck => '此书籍经审核确认违规，请修改商品内容。';

  @override
  String get delist => '取消上架';

  @override
  String removedFromShopBuyersNoLonger(Object p0) => '《${p0}》将从商城下架，买家将无法浏览。';

  @override
  String get delist2 => '下架';

  @override
  String get couldNotDelistPleaseTryAgain => '下架失败，请稍后再试';

  @override
  String listedAgain(Object p0) => '《${p0}》已重新上架';

  @override
  String get notListedAnyBooksYet => '尚未上架任何书籍';

  @override
  String get noBooksCategory => '此分类目前没有书籍';

  @override
  String get relist => '重新上架';

  @override
  String get remove => '移除';

  @override
  String get couldNotRemoveRestored => '移除失败，已还原';

  @override
  String get selectBooksWantCheckOut => '请先选择要结算的书籍';

  @override
  String notEnoughCoinsOrderNeedsBut(Object p0, Object p1) => '代币不足，此订单需 ${p0}，当前余额 ${p1}';

  @override
  String booksTotal(Object p0, Object p1) => '共 ${p0} 本书，总金额 ${p1}。\n';

  @override
  String balanceAfterPaymentCoins(Object p0) => '扣款后余额为 ${p0} 代币。';

  @override
  String get orderPlacedSellerDropBookOff => '结算成功，请等待卖家存书';

  @override
  String get cart => '购物车';

  @override
  String get cartEmpty => '购物车内没有商品';

  @override
  String get selectAll => '全选';

  @override
  String items(Object p0) => '${p0} 件商品';

  @override
  String get deselect => '取消选取';

  @override
  String get select => '选取';

  @override
  String coinsShort(Object p0) => '尚差 ${p0} 代币';

  @override
  String get total => '合计';

  @override
  String selected(Object p0) => '${p0} 件';

  @override
  String balance2(Object p0) => '余额 ${p0}';

  @override
  String get selectBookFirst => '请选择书籍';

  @override
  String get checkOut => '结算';

  @override
  String get notEnoughCoins => '代币不足';

  @override
  String get weak => '弱';

  @override
  String get fair => '普通';

  @override
  String get strong => '强';

  @override
  String get enterCurrentPassword => '请输入当前密码';

  @override
  String get enterNewPassword => '请输入新密码';

  @override
  String get newPasswordMustDifferent => '新密码不可与当前密码相同';

  @override
  String get enterNewPasswordAgain => '请再次输入新密码';

  @override
  String get passwordsDoNotMatch => '两次输入的新密码不一致';

  @override
  String get passwordUpdated => '密码已更新';

  @override
  String get changePassword => '更改密码';

  @override
  String get useLeast8CharactersWithBoth => '密码须至少 8 位，且同时包含英文与数字。';

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
  String allMessagesWithDeletedBothCannot(Object p0) => '将一并删除与 ${p0} 的所有消息，双方均无法再查看。此操作无法恢复。';

  @override
  String get chatDeleted => '已删除聊天室';

  @override
  String get couldNotDeleteRestored => '删除失败，已还原';

  @override
  String get chatMuted => '已将此聊天室设为静音';

  @override
  String get chatUnmuted => '已取消静音';

  @override
  String get noUnreadMessages => '没有未读消息';

  @override
  String get markAllAsRead => '全部标为已读';

  @override
  String markAllUnreadMessagesAsRead(Object p0) => '确定要将 ${p0} 条未读消息全部标为已读？';

  @override
  String get markAllRead => '全部已读';

  @override
  String get allMarkedAsRead => '已全部标为已读';

  @override
  String get somethingWentWrongPleaseTryAgain => '操作失败，请稍后再试';

  @override
  String get chats => '聊天室';

  @override
  String get noConversationsYet => '暂无任何对话';

  @override
  String get unmute => '取消静音';

  @override
  String get mute => '静音';

  @override
  String get messageCouldNotSent => '消息发送失败';

  @override
  String get chat => '聊天';

  @override
  String get sendFirstMessage => '发送第一条消息';

  @override
  String get messageCopied => '已复制消息';

  @override
  String get iQuestionAboutBook => '咨询书籍';

  @override
  String get bookNoLongerListed => '此书籍已下架';

  @override
  String get writeMessage => '输入消息…';

  @override
  String get enterOrderNumberDisputing => '请填写要申诉的订单编号';

  @override
  String get describeDispute => '请填写争议说明';

  @override
  String get useLeast10CharactersSoSupport => '争议说明至少需 10 个字';

  @override
  String get submitDispute => '提交争议申请';

  @override
  String get orderEntersDisputeProcessPaymentSeller => '提交后此订单将进入申诉流程，款项将暂停拨付给卖家，直至客服裁决。';

  @override
  String paymentHoldRequested(Object p0) => '[申请冻结款项] ${p0}';

  @override
  String get disputeSubmittedSupportContact => '争议申请已提交，客服将尽快与您联系';

  @override
  String get dispute => '争议处理';

  @override
  String get requestPaymentHold => '申请冻结款项';

  @override
  String get submitDispute2 => '提交争议申请';

  @override
  String get orderNumber => '订单编号';

  @override
  String get eGSmb20260910123456789 => '例如 SMB20260910123456789';

  @override
  String get whatHappened => '争议说明';

  @override
  String get describeProblemEGConditionDoes => '请描述发生的问题';

  @override
  String get submit => '提交申请';

  @override
  String get uploadPhotos => '上传图片';

  @override
  String get canAttachUp6Photos => '最多可上传 6 张佐证照片';

  @override
  String get keepLeastOnePhoto => '请至少保留一张照片';

  @override
  String get photoDeleted => '已删除照片';

  @override
  String get couldNotDeletePhotoPleaseTry => '删除图片失败，请稍后再试';

  @override
  String get canUp10Photos => '最多可上传 10 张照片';

  @override
  String get deletePhoto => '删除照片';

  @override
  String get cannotUndoneContinue => '删除后无法恢复，确定要删除吗？';

  @override
  String get photoMissingDataRefreshTryAgain => '无法处理此照片，请刷新后再试';

  @override
  String get enterPrice => '请填写价格';

  @override
  String get priceMustGreaterThan0 => '价格必须大于 0';

  @override
  String get chooseLockerLocation => '请选择存放区域';

  @override
  String missingTheseThreeRequired(Object p0) => '尚缺：${p0}（以上三张为必填）';

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
  String get tapPickPublicationDate => '选择出版日期';

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
  String get tellPeopleAboutYourself => '请输入个人简介';

  @override
  String get email => '电子邮件';

  @override
  String get emailCannotChanged => '电子邮件无法修改';

  @override
  String get dateBirth => '生日';

  @override
  String get tapPickDateBirth => '选择生日';

  @override
  String get pickDateBirth => '选择生日';

  @override
  String get savedBooks => '收藏书籍';

  @override
  String get notSavedAnyBooksYet => '尚未收藏任何书籍';

  @override
  String get helpCentre => '帮助中心';

  @override
  String get searchQuestions => '搜索问题';

  @override
  String get noQuestionsYet => '目前暂无常见问题';

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
  String get reachedEnd => '已显示全部内容';

  @override
  String get guest => '访客';

  @override
  String hi(Object p0) => '您好，${p0}';

  @override
  String get noBooksMatchFilters => '目前没有符合条件的书籍';

  @override
  String get couldNotReadPhoto => '无法读取此照片';

  @override
  String get croppingFailedPleaseTryAgain => '裁剪失败，请重试';

  @override
  String get adjustPhoto => '调整照片';

  @override
  String get reset => '重置';

  @override
  String get documentNotBeenCreatedYet => '目前无内容';

  @override
  String lastUpdated(Object p0) => '最后更新：${p0}';

  @override
  String get biometrics => '生物识别';

  @override
  String get sessionExpiredPleaseEnterPasswordAgain => '登录信息已失效，请重新输入密码';

  @override
  String turnSign(Object p0) => '启用 ${p0} 登录？';

  @override
  String nextTimeOpenAppCanUnlock(Object p0) => '下次打开 App 时可使用 ${p0} 解锁，无需输入密码。';

  @override
  String get notNow => '暂不开启';

  @override
  String get enterEmail => '请输入电子邮件';

  @override
  String get emailAddressNotValid => '电子邮件格式不正确';

  @override
  String get enterPassword => '请输入密码';

  @override
  String get noAccountWithEmail => '此账号尚未注册';

  @override
  String noAccountCreateOneNow(Object p0) => '找不到账号“${p0}”，是否立即注册？';

  @override
  String get signUp => '前往注册';

  @override
  String get tryAgain => '重新输入';

  @override
  String get sign => '登录';

  @override
  String signWith(Object p0) => '使用 ${p0} 登录';

  @override
  String get noAccountYetSignUp => '暂无账号？立即注册';

  @override
  String get membershipTiersNotSetUpYet => '目前未提供会员等级';

  @override
  String get currentTier => '当前等级';

  @override
  String get unlocked => '已解锁';

  @override
  String get locked => '尚未解锁';

  @override
  String get aboveTier => '已超过此等级';

  @override
  String get reachedTopTier => '已达最高等级';

  @override
  String unlocked2(Object p0) => '已解锁“${p0}”';

  @override
  String morePointsUnlock(Object p0, Object p1) => '再 ${p0} 点即可解锁“${p1}”';

  @override
  String benefits(Object p0) => '${p0}等级权益';

  @override
  String get noBenefitsBeenDescribedTierYet => '此等级目前无额外权益';

  @override
  String pointsFromCompletedOrders(Object p0, Object p1) => '目前累积 ${p0} 点，已完成 ${p1} 笔交易';

  @override
  String get noNotificationsClear => '目前没有可清除的通知';

  @override
  String get clearAllNotifications => '清除全部通知';

  @override
  String notificationsDeletedCannotUndone(Object p0) => '将删除 ${p0} 条通知，此操作无法恢复。';

  @override
  String get clearAll => '全部清除';

  @override
  String get allNotificationsCleared => '已清除全部通知';

  @override
  String get couldNotClearPleaseTryAgain => '清除失败，请稍后再试';

  @override
  String get noUnreadNotifications => '没有未读通知';

  @override
  String markAllUnreadNotificationsAsRead(Object p0) => '确定要将 ${p0} 条未读通知全部标为已读？';

  @override
  String get openChat => '前往聊天室';

  @override
  String get viewOrder => '查看订单';

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
  String get orderNoItemDetails => '无商品明细';

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
  String get notAssignedYet => '尚未分配柜位';

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
  String get pendingPayoutDisappearsBuyerNotified => '取消后此笔待定收益将一并取消，并通知买家。';

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
  String get coinsArriveOnceBuyerCollectsBook => '买家取书后自动拨款';

  @override
  String get scanned => '扫描成功';

  @override
  String get scanAgain => '继续扫描';

  @override
  String get collectBook => '取书';

  @override
  String get pointPickupQrCode => '请对准取书二维码';

  @override
  String get holdSteady => '请保持设备稳定';

  @override
  String get bookCollected => '取书完成';

  @override
  String collected(Object p0) => '《${p0}》已完成取书';

  @override
  String order2(Object p0) => '订单编号：${p0}';

  @override
  String get signingOut => '退出登录中…';

  @override
  String get myAccount => '会员中心';

  @override
  String get personNotWrittenBioYet => '尚未填写个人简介';

  @override
  String get topTierReached => '已达最高等级';

  @override
  String morePointsReach(Object p0, Object p1) => '再 ${p0} 点升级为“${p1}”';

  @override
  String get purchases => '购买记录';

  @override
  String get sales => '销售记录';

  @override
  String get settings => '设置';

  @override
  String get signOut2 => '确认退出登录';

  @override
  String cancelOrderBookReturnsShop(Object p0) => '确定要取消订单 ${p0} 吗？取消后书籍将重新在商城销售。';

  @override
  String get iCollected => '确认取书';

  @override
  String get noOrdersTab => '此分类目前没有订单';

  @override
  String get openDispute => '申请争议';

  @override
  String get displayNameNeedsLeast2Characters => '昵称至少 2 个字符';

  @override
  String get displayNameLimited50Characters => '昵称不可超过 50 个字符';

  @override
  String get enterPasswordAgain => '请再次输入密码';

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
  String get joinSavemybook => '注册账号';

  @override
  String get displayName => '昵称';

  @override
  String get emailSignWith => '电子邮件';

  @override
  String get least8CharactersWithLettersNumbers => '至少 8 位，需含英文与数字';

  @override
  String get confirmPassword => '确认密码';

  @override
  String get enterPasswordAgain2 => '请再次输入密码';

  @override
  String get alreadyAccountGoBackSign => '已有账号？返回登录';

  @override
  String get markAsDroppedOff => '完成存书';

  @override
  String get droppedOff => '已放入书柜';

  @override
  String get markedAsDroppedOff => '已标记为完成存书';

  @override
  String get buyerNotifiedBookReturnsShop => '取消后将通知买家，书籍将重新在商城销售。';

  @override
  String get noRecentSearches => '暂无搜索记录';

  @override
  String get recentSearches => '最近搜索';

  @override
  String get clearAll2 => '清除全部';

  @override
  String get searchTitleAuthorIsbn => '搜索书名、作者或 ISBN';

  @override
  String get photoLimitReached => '照片已满';

  @override
  String get canUploadUp10Photos => '最多可上传 10 张照片。';

  @override
  String get photosMissing => '照片不足';

  @override
  String missingTheseThreeRequired2(Object p0) => '尚缺：${p0}。以上三张为必填。';

  @override
  String get missingInformation => '资料不齐全';

  @override
  String get enterOwnPrice => '请输入自定价格。';

  @override
  String get invalidPrice => '价格不正确';

  @override
  String get priceMustGreaterThan02 => '售价必须大于 0。';

  @override
  String get priceCannotExceed99999 => '售价不可超过 99,999 代币。';

  @override
  String get chooseLockerLocation2 => '请选择存放区域。';

  @override
  String get listed2 => '上架成功';

  @override
  String get unknownError => '未知错误';

  @override
  String get couldNotListBook => '上架失败';

  @override
  String get listBook => '确认上架';

  @override
  String get detailsPhotos => '详细信息与照片';

  @override
  String get loading => '加载中…';

  @override
  String get unknownLocker => '未知书柜';

  @override
  String get enterTitle2 => '请输入书名';

  @override
  String get chooseCategory2 => '请选择分类';

  @override
  String get bookDetailsFilledAutomatically => '已自动带入书籍信息';

  @override
  String get noSourceIsbnPleaseEnterDetails => '未查到此 ISBN 的书籍信息，请手动输入';

  @override
  String get day => '日';

  @override
  String get tapIconRightScan => '请输入 ISBN';

  @override
  String get description => '书籍简介';

  @override
  String get sellBook => '上架书籍';

  @override
  String get myShop => '我的卖场';

  @override
  String get sellerNoBooksSale => '此卖家目前没有销售中的书籍';

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
  String get aboutSavemybook => '关于救「舊」我的書';

  @override
  String sign3(Object p0) => '${p0} 登录';

  @override
  String get scanProfileQrCode => '扫描个人二维码';

  @override
  String get lineUpTheirQrCodeWith => '将对方的二维码放入框内';

  @override
  String get notSavemybookProfileQrCode => '此二维码并非救「舊」我的書的个人二维码';

  @override
  String get ownQrCode => '这是您的个人二维码';

  @override
  String get couldNotStartChatPleaseTry => '无法创建聊天室，请稍后再试';

  @override
  String get linkCopied => '已复制链接';

  @override
  String addMeSavemybook(Object p0) => '我的救「舊」我的書个人档案：${p0}';

  @override
  String addMeSavemybook2(Object p0, Object p1) => '${p0} 的救「舊」我的書个人档案：${p1}';

  @override
  String get sharingCouldNotOpenSoLink => '无法打开分享，已复制链接';

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
  String get noEnquiriesYet => '暂无提问记录';

  @override
  String get enterSubject => '请填写主旨';

  @override
  String get addMoreDetailSoSupportCan => '请补充问题描述';

  @override
  String get sentSupportReplySoon => '已提交，客服将尽快回复';

  @override
  String get subject => '主旨';

  @override
  String get sumUpOneLine => '简述问题';

  @override
  String get whatHappenedIncludeOrderNumberIf => '请描述问题，如有订单编号请一并提供';

  @override
  String get close => '结案';

  @override
  String get notAbleReplyAfterClosing => '结案后将无法再回复。';

  @override
  String get enquiryClosed => '问题已结案';

  @override
  String get changeStatus => '更改状态';

  @override
  String get statusUpdated => '已更新状态';

  @override
  String get enquiry => '提问记录';

  @override
  String get enquiryNotFound => '找不到此提问';

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
  String get couldNotLoadPhoto => '无法加载此照片';

  @override
  String slot2(Object p0) => '柜位：${p0}';

  @override
  String confirmPutLocker(Object p0) => '确认已将《${p0}》放入书柜？';

  @override
  String get enterTitleContent => '请填写标题与内容';

  @override
  String get titleCannotExceed255Characters => '标题不可超过 255 个字符';

  @override
  String get contentNeedsLeast5Characters => '内容至少 5 个字符';

  @override
  String get publishAnnouncement => '发布公告';

  @override
  String get everyUserSeeAnnouncementOncePublished => '发布后全体用户均可看到此公告，确定要发布吗？';

  @override
  String get publish => '发布';

  @override
  String get announcementPublished => '公告已发布';

  @override
  String get draftSaved => '草稿已保存';

  @override
  String get editAnnouncement => '编辑公告';

  @override
  String get newAnnouncement => '新增公告';

  @override
  String get title2 => '标题';

  @override
  String get announcementTitle => '公告标题';

  @override
  String get writeAnnouncement => '输入公告内容';

  @override
  String get publishNow => '立即发布';

  @override
  String get leaveOffSaveAsDraft => '关闭时仅保存为草稿';

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
  String get noAnnouncementsYetTapAddOne => '暂无公告';

  @override
  String get published => '已发布';

  @override
  String get draft => '草稿';

  @override
  String get audienceEveryone => '对象：全体用户';

  @override
  String get backUpNow => '立即备份';

  @override
  String get wholeDatabaseExportedCompressedWithLot => '将导出整个数据库并压缩保存。数据量大时可能需要数十秒，期间请勿离开此界面。';

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
  String get olderBackupsBeyondCountRemovedAutomatically => '超出份数的旧备份将自动清除。备份文件含全站个人资料，下载后请妥善保管，每次下载均会记入操作记录。';

  @override
  String get noBackupsYetSchedulerRunsOnce => '暂无备份记录';

  @override
  String get deleteBackup => '删除备份';

  @override
  String p0NNtheFileItsRecord(Object p0) => '${p0}\n\n文件与记录将一并移除，此操作无法恢复。';

  @override
  String get manual => '手动';

  @override
  String get scheduled => '排程';

  @override
  String get download => '下载';

  @override
  String get downloadBackup => '下载备份';

  @override
  String get copyLink2 => '复制网址';

  @override
  String get downloadLinkCopied => '已复制下载网址';

  @override
  String get forceDelist => '强制下架';

  @override
  String get reasonDelistingSellerNotified => '下架原因（将通知卖家）';

  @override
  String get delist3 => '确认下架';

  @override
  String get relist2 => '恢复上架';

  @override
  String putP0BackStore(Object p0) => '确定要将《${p0}》恢复上架吗？';

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
  String onceDisabledP0NoLongerAppears(Object p0) => '停用后“${p0}”将不再显示在卖家的存放区域菜单中。';

  @override
  String onceEnabledP0AvailableSellersAgain(Object p0) => '启用后“${p0}”将重新开放卖家选择。';

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
  String deleteP0CannotUndone2(Object p0) => '确定要删除“${p0}”吗？此操作无法撤销。';

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
  String get contentsSectionRemovedWith => '此章节内容将一并移除。';

  @override
  String p0ItsContentsRemoved(Object p0) => '“${p0}”及其内容将一并移除。';

  @override
  String get discardChanges => '舍弃更改？';

  @override
  String get documentUnsavedChangesTheyLostIf => '此文件有尚未保存的修改，离开后将丢失。';

  @override
  String get discard => '舍弃';

  @override
  String get keepEditing => '继续编辑';

  @override
  String sectionP0NoTitleYet(Object p0) => '第 ${p0} 章尚未填写标题';

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
  String get unnumberedOpeningTextLeaveEmptyIf => '开头不编号的说明文字，若无可留空。';

  @override
  String get articles => '条文';

  @override
  String get noArticlesYetAddFirstOne => '暂无条文';

  @override
  String get addSection => '新增章节';

  @override
  String get untitledSection => '未命名章节';

  @override
  String get sectionTitle => '章节标题';

  @override
  String get bodySectionSingleLineBreaksKept => '章节内容。单行换行将如实呈现，空一行代表另起一段。';

  @override
  String get howUsersSee => '用户查看效果';

  @override
  String get noContentYet => '尚无内容';

  @override
  String get unsaved => '尚未保存';

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
  String get bothQuestionAnswerRequired => '请填写问题与答案';

  @override
  String get added => '已新增';

  @override
  String get updated => '已更新';

  @override
  String get deleteQuestion => '删除问题';

  @override
  String deleteP0(Object p0) => '确定要删除“${p0}”吗？';

  @override
  String get deleted => '已删除';

  @override
  String get faq => '常见问题';

  @override
  String get noQuestionsYet2 => '尚无常见问题';

  @override
  String get hidden => '已隐藏';

  @override
  String get cancelDeletionRequest => '取消删除申请';

  @override
  String p0SAccountReturnsNormalCountdown(Object p0) => '${p0} 的账号将恢复正常，并停止删除流程。';

  @override
  String get cancelDeletion => '取消删除';

  @override
  String get deletionRequestCancelled => '已取消该会员的删除申请';

  @override
  String get anonymiseNow => '立即执行匿名化';

  @override
  String eraseP0SPersonalDataDisable(Object p0) => '不待缓冲期结束，立即清除 ${p0} 的个人资料并停用账号。\n\n订单与交易记录将予以保留，昵称将显示为“已删除的用户”。此操作无法撤销。';

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
  String p0DaysLeft(Object p0) => '剩余 ${p0} 天';

  @override
  String requestedP0ScheduledP1(Object p0, Object p1) => '申请于 ${p0}，预计 ${p1} 执行';

  @override
  String get disputeResolution => '交易仲裁';

  @override
  String orderP0P1(Object p0, Object p1) => '订单 ${p0}｜\$${p1}';

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
  String get listings => '商品管理';

  @override
  String get moderation => '内容审核';

  @override
  String get handleListingReports => '商品举报处理';

  @override
  String get members => '会员管理';

  @override
  String get memberControls => '会员管控';

  @override
  String get membershipTiers => '会员等级管理';

  @override
  String get wallets => '钱包管理';

  @override
  String get hardwareOperations => '硬件与运营';

  @override
  String get maintenanceLog => '维修记录';

  @override
  String get reports => '运营报表';

  @override
  String get ordersRevenueMemberGrowth => '订单、营收与会员增长';

  @override
  String get supportEnquiries => '客服工单';

  @override
  String get adminAuditLog => '管理操作记录';

  @override
  String get systemOperations => '系统运维';

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
  String get maximumPointsLeaveEmptyNoCap => '最高点数（留空表示无上限）';

  @override
  String get benefitsSeparatedByCommasLineBreaks => '权益（以顿号或换行分隔，将在会员等级页逐条显示）';

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
  String deleteP0MembersTierDropNext(Object p0) => '确定要删除“${p0}”吗？此等级的会员将调整至下一个符合的等级。';

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
  String p0SignedOutImmediatelyCanNo(Object p0) => '${p0} 将立即被登出，且无法使用 App 的任何功能。';

  @override
  String p0AbleSignAgain(Object p0) => '${p0} 将可重新登录使用。';

  @override
  String get accountStatusUpdated => '已更新账号状态';

  @override
  String get removeAdmin => '取消管理员';

  @override
  String get makeAdmin => '设为管理员';

  @override
  String p0LosesEveryAdminPermissionImmediately(Object p0) => '${p0} 将立即失去所有后台权限。';

  @override
  String p0GainsAccessAdminAreaWith(Object p0) => '${p0} 将可进入管理后台，默认拥有全部权限，并可逐项调整。';

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
  String p0AbleUseEveryAdminFeature(Object p0) => '${p0} 将可使用后台所有功能。';

  @override
  String p0ReachAdminAreaButUnable(Object p0) => '${p0} 进入后台后将无法使用任何功能。';

  @override
  String get allPermissionsGranted => '已开放全部权限';

  @override
  String get allPermissionsRevoked => '已收回全部权限';

  @override
  String get memberSettings => '会员设置';

  @override
  String get noDataMember => '找不到此会员的资料';

  @override
  String get listings2 => '上架图书';

  @override
  String get completedTrades => '完成交易';

  @override
  String get joined => '加入日期';

  @override
  String get accountStatus => '账号状态';

  @override
  String get ownAccountStatusPermissionsCannotChanged => '此为您本人的账号，无法在此调整状态与权限。';

  @override
  String get accountEnabled => '启用账号';

  @override
  String get canSignUseAppNormally => '可正常登录使用';

  @override
  String get suspendedSignedOutImmediatelyAfterSigning => '已停权，登录后将立即登出';

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
  String get memberSTierBeenAdjustedBy => '此会员的等级经人工调整，不完全按交易自动计算。';

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
  String get searchDisplayNameEmail => '搜索昵称或电子邮件';

  @override
  String get noMembersMatch => '找不到符合条件的会员';

  @override
  String get sales2 => '销售';

  @override
  String get created => '建立日期';

  @override
  String get noActivityYet => '尚无操作记录';

  @override
  String get changeOrderStatus => '调整订单状态';

  @override
  String orderP0(Object p0) => '订单 ${p0}';

  @override
  String get reasonChange => '调整说明';

  @override
  String get sentBuyerAsWellOptional => '将一并通知买家（选填）';

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
  String get member2 => '此会员';

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
  String get orderPlaced => '成立订单';

  @override
  String get paid => '付款';

  @override
  String get sellerDroppedOff => '卖家存书';

  @override
  String get buyerCollected => '买家取书';

  @override
  String get completed => '完成';

  @override
  String get editBookDetails => '编辑书籍资料';

  @override
  String sellerP0TheyNotifiedSave(Object p0) => '卖家 ${p0}・保存后将通知卖家';

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
  String p0SCurrentPasswordStopsWorking(Object p0) => '${p0} 当前的密码将立即失效，须改用系统生成的临时密码登录。\n\n临时密码由系统生成，无法自行指定。';

  @override
  String get generateTemporaryPassword => '生成临时密码';

  @override
  String get temporaryPassword => '临时密码';

  @override
  String p0SPasswordBeenResetPassword(Object p0) => '${p0} 的密码已重置。此密码仅显示一次，关闭后将无法再查看。';

  @override
  String get remindThemChangeSettingsChangePassword => '请提醒对方登录后立即至「设置 › 更改密码」修改密码。';

  @override
  String get temporaryPasswordCopied => '已复制临时密码';

  @override
  String get copy => '复制';

  @override
  String get cannotResetAnotherAdminSPassword => '无法重置其他管理员的密码';

  @override
  String get generateTemporaryPasswordHandOver => '生成一组临时密码交给用户';

  @override
  String get orderNumberCopied => '已复制订单编号';

  @override
  String get orderNotFound => '找不到此订单';

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
  String get changeOwnPasswordGoSettingsChange => '如需修改本人密码，请至「设置 › 更改密码」';

  @override
  String get memberNotAdminSoThereNo => '此会员非管理员，无后台权限可设置。请先在上方将身份设为管理员。';

  @override
  String get you => '本人';

  @override
  String isbnMust1013DigitsOne(Object p0) => 'ISBN 应为 10 或 13 位，当前为 ${p0} 位';

  @override
  String get screenUnsavedChangesTheyLostIf => '此界面有尚未保存的修改，离开后将丢失。';

  @override
  String stillNeededP0(Object p0) => '尚缺：${p0}';

  @override
  String photosP0(Object p0) => '照片：${p0} 张';

  @override
  String get confirmListing => '确认上架';

  @override
  String get lookingUpBook => '正在查询书籍资料';

  @override
  String get scan => '扫描';

  @override
  String get buyerSPaymentGoesBackTheir => '买家支付的款项将退回钱包；若卖家已收到货款，将先行收回。';

  @override
  String get orderReturnsWhereWasBeforeDispute => '订单将恢复至申诉前的状态并继续交易；若先前已完成取书，货款将拨付给卖家。';

  @override
  String get orderWasAlreadyRefundedBuyerCannot => '此订单款项已退回买家，无法改回进行中或已完成';

  @override
  String get completedOrderCanOnlyChangedRefund => '已完成的订单只能改为“退款处理中”或“已退款”';

  @override
  String confirmingPaysP0TokensSellerMarks(Object p0) => '确认后将拨付 ${p0} 代币给卖家，并将书籍标记为已售出。';

  @override
  String confirmingTakesP0TokensBackFrom(Object p0) => '确认后将向卖家收回 ${p0} 代币并退还买家。卖家余额不足时将显示为负数。';

  @override
  String get ifBuyerNotBeenRefundedYet => '若先前尚未退款，将补退给买家。';

  @override
  String confirmingRefundsBuyerSP0Tokens(Object p0) => '确认后将退还买家支付的 ${p0} 代币，保留中的书籍将重新上架。';

  @override
  String get donTPermissionYourselfSoCan => '您不具备此权限，无法授予他人。';

  @override
  String get notificationsTurnedOff => '通知权限已关闭';

  @override
  String get openSettings => '前往设置';

  @override
  String get sendTestNotification => '发送测试通知';

  @override
  String get arrives10SecondsGoHomeScreen => '将于 10 秒后送达，发送后请返回主屏幕或锁定手机';

  @override
  String get systemNotificationSettings => '系统通知设置';

  @override
  String get pushNotificationsNotSetUpBuild => '此版本的 App 尚未设置推送，请加入 Firebase 配置文件后重新编译。';

  @override
  String get notificationsTurnedOffAllowAppSend => '通知权限已关闭，请前往系统设置允许此 App 发送通知。';

  @override
  String get restoreBackup => '确定要还原至此备份？';

  @override
  String wholeDatabaseGoBackP0Orders(Object p0) => '整个数据库将还原至 ${p0} 的状态，此时间点之后的订单、消息、会员资料与操作记录将全部清除。\n\n还原前系统将自动备份当前状态，如有需要可再还原该备份。还原期间全站暂停服务，通常需要数十秒至数分钟。\n\n请输入您的登录密码以确认：';

  @override
  String get password2 => '登录密码';

  @override
  String get startRestore => '开始还原';

  @override
  String get backingUpCurrentState => '正在备份当前状态…';

  @override
  String databaseRestoredPreviousStateWasBacked(Object p0) => '数据库已还原。还原前的状态已备份至 ${p0}';

  @override
  String restoreFailedDatabaseMayUnchangedPartly(Object p0) => '还原失败，数据库可能维持原状或已部分还原，请查看操作记录并视需要还原 ${p0}';

  @override
  String get autoBackupBeforeRestore => '还原前自动备份';

  @override
  String get restoreBackup2 => '还原至此备份';

  @override
  String get restoringDatabase => '正在还原数据库';

  @override
  String p0SecondsSoFarKeepApp(Object p0) => '已经过 ${p0} 秒。请勿关闭 App，完成后将自动恢复服务。';

  @override
  String get majorUpdate2 => '重大更新';

  @override
  String get minorEdit => '小幅修改';

  @override
  String get books => '书籍';

  @override
  String get orders2 => '订单';

  @override
  String get wallets2 => '钱包';

  @override
  String get announcements3 => '公告';

  @override
  String get legal => '条款';

  @override
  String get backups => '备份';

  @override
  String get undoAction => '确定要还原此操作？';

  @override
  String p0NNtheDataGoesBack(Object p0) => '“${p0}”\n\n数据将恢复至操作前的状态。已发出的通知不会撤回；若数据之后曾再次修改，系统将拒绝还原。';

  @override
  String get undo => '还原';

  @override
  String get undone => '已还原';

  @override
  String get searchActionsEGNicknameBook => '搜索操作内容，例如会员昵称或书名';

  @override
  String viewP0Changes(Object p0) => '查看 ${p0} 项变更';

  @override
  String get undoAction2 => '还原此操作';

  @override
  String get noAnnouncements => '目前没有公告';

  @override
  String get canTContinueWithoutAccepting => '未同意将无法继续使用';

  @override
  String needAcceptLatestP0UseP1(Object p0) => '不同意「${p0}」将登出账号。';

  @override
  String get goBack => '返回';

  @override
  String p0BeenUpdated(Object p0) => '“${p0}”已更新';

  @override
  String readLatestVersionUpdatedP0Accept(Object p0) => '${p0} 更新';

  @override
  String get scrollEndContinue => '请滚动至底部阅读全文';

  @override
  String get iVeReadAccept => '我已阅读并同意';

  @override
  String get decline => '不同意';

  @override
  String get viewDetails => '查看详情';

  @override
  String get notFoundMayBeenDeletedRemoved => '此内容已不存在';

  @override
  String get chatMessages => '聊天消息';

  @override
  String get promotions2 => '优惠活动';

  @override
  String get supportRepliesPasswordResetsPolicyUpdates => '客服回复、账号安全与系统公告通知无法关闭。';

  @override
  String get notFilled => '未填写';

  @override
  String get canTChanged => '无法修改';

  @override
  String get voice => '[语音]';

  @override
  String get reservation => '预约';

  @override
  String get messageUnsent => '消息已撤回';

  @override
  String get confirmBeforeExportingData => '导出个人资料前，请先验证身份';

  @override
  String get exportFailedPleaseTryAgainLater => '导出失败，请稍后再试';

  @override
  String get refresh => '刷新';

  @override
  String get clearFilters => '清除筛选';

  @override
  String get expired => '已过期';

  @override
  String get verificationCancelled => '已取消验证';

  @override
  String get openingClosingTimesCanTSame => '开放与关闭时间不可相同';

  @override
  String slotCurrentlyP0MayOrderProgress(Object p0, Object p1) => '此柜位目前为「${p0}」，可能有进行中的订单。更改为「${p1}」后，买卖双方可能无法正常存取书籍。';

  @override
  String get active => '启用中';

  @override
  String get categoryWithNameAlreadyExists => '已有同名分类';

  @override
  String orderP0ClosedAsP1P2(Object p0, Object p1, Object p2) => '订单 ${p0} 将以「${p1}」结案，${p2} 代币将退回买家。提交后无法修改。';

  @override
  String orderP0ClosedAsP1Can(Object p0, Object p1) => '订单 ${p0} 将以「${p1}」结案。提交后无法修改。';

  @override
  String get clearSearch => '清除搜索';

  @override
  String get enterMinimumPoints => '请输入最低点数';

  @override
  String pointsRangeOverlapsWithP0P1(Object p0, Object p1) => '点数范围与「${p0}」（${p1}）重叠';

  @override
  String noTierCoversP0P1Points(Object p0, Object p1) => '${p0}–${p1} 点没有对应的等级';

  @override
  String p0TakenDownRightAwayOther(Object p0) => '「${p0}」将立即下架，其他会员将无法浏览或购买。';

  @override
  String get searchReportedItemReporterReason => '搜索被举报项目、举报人或原因';

  @override
  String get couldnTLoadStatisticsRightNow => '暂时无法获取统计数据';

  @override
  String get searchSubjectMemberMessage => '搜索主题、会员或消息内容';

  @override
  String get balance3 => '有余额';

  @override
  String get hold3 => '有冻结金额';

  @override
  String get zeroBalance => '余额为 0';

  @override
  String get amountCanMost2DecimalPlaces => '金额最多可至小数点后两位';

  @override
  String get singleAdjustmentCanTExceed1 => '单次调整不可超过 1,000,000';

  @override
  String wouldMakeBalanceNegativeCurrentBalance(Object p0) => '扣除后余额将为负数，当前余额 ${p0}';

  @override
  String get amountUp2Decimals => '金额（最多两位小数）';

  @override
  String p0NbalanceAfterP1(Object p0, Object p1) => '${p0}\n调整后余额 ${p1}';

  @override
  String get cameraAccessOff => '无法使用相机';

  @override
  String get couldNotStartCamera => '相机启动失败';

  @override
  String allowP0UseCameraSettingsThen(Object p0) => '请前往系统设置允许 ${p0} 使用相机后再试。';

  @override
  String get closeScreenTryAgain => '请关闭此画面后再试。';

  @override
  String get couldnTGetLocationCheckLocation => '无法获取当前位置，请确认已开启定位服务与权限';

  @override
  String get bookReservedAnotherBuyerCanT => '此书籍已由其他买家预约，暂时无法加入购物车';

  @override
  String reservedAnotherBuyerUntilP0(Object p0) => '已由其他买家预约，保留至 ${p0}';

  @override
  String sellerHoldingUntilP0(Object p0) => '卖家已为您保留至 ${p0}';

  @override
  String get checkOutBeforeHoldEndsOther => '请于保留期限内完成结账';

  @override
  String get copyAddress => '复制地址';

  @override
  String p0Away(Object p0) => '距离 ${p0}';

  @override
  String get locating => '定位中…';

  @override
  String get showDistance => '查看距离';

  @override
  String get reserved => '已预约';

  @override
  String get goCheckout => '前往结账';

  @override
  String get cart2 => '已在购物车';

  @override
  String get buyNow => '立即购买';

  @override
  String p0Delisted(Object p0) => '《${p0}》已下架';

  @override
  String noBooksMatchP0(Object p0) => '找不到符合“${p0}”的书籍';

  @override
  String p0BooksP1Views(Object p0, Object p1) => '共 ${p0} 本 · 总浏览 ${p1} 次';

  @override
  String get searchTitleAuthorIsbn2 => '搜索书名、作者或 ISBN';

  @override
  String removedP0(Object p0) => '已移除《${p0}》';

  @override
  String removedP0Items(Object p0) => '已移除 ${p0} 件商品';

  @override
  String get paymentSuccessful => '付款成功';

  @override
  String p0BooksSplitIntoP1Orders(Object p0, Object p1) => '共 ${p0} 本书，已按卖家拆分为 ${p1} 笔订单';

  @override
  String get keepBrowsing => '继续浏览';

  @override
  String get reload => '重新加载';

  @override
  String get browseBooks => '浏览书籍';

  @override
  String p0Sellers(Object p0) => '${p0} 位卖家';

  @override
  String unavailableP0(Object p0) => '无法购买（${p0}）';

  @override
  String get removeAll => '全部移除';

  @override
  String get goWallet => '前往钱包';

  @override
  String fromP0SellersCheckoutCreatesP1(Object p0, Object p1) => '来自 ${p0} 位卖家，结账后将拆分为 ${p1} 笔订单';

  @override
  String get otherDevicesNeedSignAgainWith => '其他设备须使用新密码重新登录。';

  @override
  String get searchChats => '搜索聊天对象';

  @override
  String get noMatchingChats => '找不到符合的聊天对象';

  @override
  String get read => '已读';

  @override
  String get chatNotFound => '找不到此聊天室';

  @override
  String get messagesCanUp2000Characters => '消息最多 2000 字';

  @override
  String get canTSendRightNowPlease => '目前无法发送，请稍后再试';

  @override
  String get reserveBook => '预约书籍';

  @override
  String get quickReplies => '快速回复';

  @override
  String get imagesMust10MbSmaller => '图片不可超过 10 MB';

  @override
  String get recordingFailedPleaseTryAgain => '录音失败，请重试';

  @override
  String get voiceMessageTooLargePleaseRecord => '语音文件过大，请缩短录音时长';

  @override
  String get microphoneAllowedPressHoldAgainRecord => '已允许使用麦克风，请再次按住按钮开始录音';

  @override
  String get microphoneAccessNeededRecordTurnSettings => '录音需要麦克风权限，请前往系统设置开启';

  @override
  String get couldnTStartRecordingPleaseTry => '无法开始录音，请稍后再试';

  @override
  String get selectText => '选择文字';

  @override
  String get unsend => '撤回';

  @override
  String get resend => '重新发送';

  @override
  String get unsendMessage => '确定要撤回此消息？';

  @override
  String get neitherAbleSeeMessageSContent => '撤回后双方均无法查看此消息内容。';

  @override
  String get reportMessage => '举报此消息';

  @override
  String get reservationSentWaitingSeller => '已发送预约，等待卖家回复';

  @override
  String get acceptReservation => '确定要接受预约？';

  @override
  String p0HeldThemP1HoursNo(Object p0, Object p1) => '《${p0}》将为对方保留 ${p1} 小时，期间其他人无法购买。';

  @override
  String get accept => '接受';

  @override
  String get reservationAccepted => '已接受预约';

  @override
  String get declineReservation => '确定要婉拒预约？';

  @override
  String get decline2 => '婉拒';

  @override
  String get reservationDeclined => '已婉拒预约';

  @override
  String get cancelReservation => '确定要取消预约？';

  @override
  String p0NoLongerHeld(Object p0) => '取消后《${p0}》将不再保留。';

  @override
  String get cancelReservation2 => '取消预约';

  @override
  String get reservationCanceled => '已取消预约';

  @override
  String get notNow2 => '返回';

  @override
  String get couldnTLoadConversationPleaseTry => '无法加载对话，请稍后再试';

  @override
  String get accountCanTReceiveMessagesRight => '对方账号目前无法接收消息';

  @override
  String get holdMicTalkReleaseSend => '录音时间过短';

  @override
  String get startConversation => '对话开始';

  @override
  String p0New(Object p0) => '${p0} 条新消息';

  @override
  String get connectionUnstableMessagesCanTSent => '连接不稳定，暂时无法发送消息';

  @override
  String get retry => '重试';

  @override
  String get stillAvailable => '请问此书籍仍可购买吗？';

  @override
  String get couldLowerPriceBit => '请问是否可议价？';

  @override
  String get whenCanPutLocker => '请问预计何时存入书柜？';

  @override
  String get unsentMessage => '您已撤回消息';

  @override
  String get theyUnsentMessage => '对方已撤回消息';

  @override
  String get reservationDetailsArenTAvailableRight => '预约信息暂时无法显示';

  @override
  String get sending => '发送中';

  @override
  String get couldNotUploadPhotosPleaseTry => '证据照片上传失败，请稍后再试';

  @override
  String get bookDetailsUpdatedButPhotosCouldn => '书籍资料已更新，但照片上传失败，请稍后再试';

  @override
  String get sNotIsbnBarcodeScanOne => '扫描到的条码并非 ISBN，请扫描书背上 978 或 979 开头的条码';

  @override
  String get couldnTLoadCategoriesTapRetry => '分类加载失败，请点此重试';

  @override
  String removedP0FromSaved(Object p0) => '已取消收藏《${p0}》';

  @override
  String get recentlyViewedCleared => '已清除最近浏览';

  @override
  String clearP0(Object p0) => '清除（${p0}）';

  @override
  String get picked => '为您推荐';

  @override
  String get recentlyViewed => '最近浏览';

  @override
  String get clear => '清除';

  @override
  String get notificationDeleted => '已删除通知';

  @override
  String get pleasePutBookAssignedLockerSoon => '请尽快将书籍存入指定书柜';

  @override
  String get weLlLetKnowWhenSeller => '卖家存书后将通知您前往取书';

  @override
  String get waitingBuyerCollect => '等待买家至书柜取书';

  @override
  String get transactionCompleteThank => '交易完成';

  @override
  String get confirmVeTakenBookFromLocker => '请确认已从书柜取出书籍。确认书况无误后，请在购买记录中完成订单。';

  @override
  String p0Orders2(Object p0) => '共 ${p0} 笔订单';

  @override
  String p0ReadyPickup(Object p0) => '可取书 ${p0} 笔';

  @override
  String get pickUp => '待取书';

  @override
  String get saved => '收藏';

  @override
  String get accountSecurity => '账号安全';

  @override
  String get searchHistoryCleared => '已清除搜索记录';

  @override
  String get trendingBooks => '热门书籍';

  @override
  String get signOutDevice => '确定要登出此设备？';

  @override
  String signOutP0(Object p0) => '确定要登出「${p0}」？';

  @override
  String get deviceSignedOutRightAwayStop => '该设备将立即登出。';

  @override
  String get deviceSignedOut => '已登出设备';

  @override
  String get signOutAllDevicesIncludingOne => '登出所有设备（含本机）';

  @override
  String get signOutAllOtherDevices => '登出其他所有设备';

  @override
  String get everyDeviceIncludingOneSignedOut => '包含本机在内的所有设备将立即登出。';

  @override
  String get everyDeviceExceptOneSignedOut => '除本机外的所有设备将立即登出。';

  @override
  String signedOutP0OtherDevices(Object p0) => '已登出其他 ${p0} 台设备';

  @override
  String get unknownDevice => '未知设备';

  @override
  String get couldnTLoadDevices => '无法加载登录设备';

  @override
  String get device => '本机';

  @override
  String get otherDevices => '其他设备';

  @override
  String otherDevicesP0(Object p0) => '其他设备（${p0}）';

  @override
  String get noOtherDevicesSigned => '没有其他设备登录您的账号';

  @override
  String get signedDevices => '登录设备';

  @override
  String get activeNow => '当前使用中';

  @override
  String lastActiveP0(Object p0) => '最后使用 ${p0}';

  @override
  String signedP0(Object p0) => '${p0} 登录';

  @override
  String get biometricPayment => '已启用生物识别付款';

  @override
  String get paymentPinMust6Digits => '交易密码必须是 6 位数字';

  @override
  String get pinTooEasyGuessTryAnother => '交易密码过于简单，请重新设置';

  @override
  String get enterPasswordResetPaymentPin => '输入登录密码后即可重新设置交易密码';

  @override
  String get confirmSBeforeSettingPaymentPin => '设置交易密码前，请先验证身份';

  @override
  String get pinsDonTMatchStartAgain => '两次输入的交易密码不一致，请重新设置';

  @override
  String get paymentPinReset => '交易密码已重新设置';

  @override
  String get paymentPinSet => '交易密码已设置';

  @override
  String get verifyingIdentity => '正在确认身份…';

  @override
  String get enterAgainConfirm => '请再次输入以确认';

  @override
  String get set6DigitPaymentPin => '设置 6 位数交易密码';

  @override
  String get enterSamePinAgain => '请再次输入相同密码';

  @override
  String get avoidRepeatedSequentialPatternedDigits => '不可使用相同、连续或重复的数字';

  @override
  String get resetPaymentPin => '重设交易密码';

  @override
  String get paymentPin => '交易密码';

  @override
  String stepP02(Object p0) => '步骤 ${p0} / 2';

  @override
  String get setPaymentPinFirst => '请先设置交易密码';

  @override
  String get setPaymentPinFirstSoFallback => '请先设置交易密码，作为识别失败时的备用验证方式';

  @override
  String get setUpNow => '立即设置';

  @override
  String get biometricPaymentTurnedOff => '已关闭生物识别付款';

  @override
  String get verifyTurnBiometricPayment => '验证以启用生物识别付款';

  @override
  String p0PaymentsTurned(Object p0) => '已启用 ${p0} 付款';

  @override
  String get securitySettingsUnavailableRightNowMay => '无法加载账号安全设置';

  @override
  String payWithP0(Object p0) => '使用 ${p0} 付款';

  @override
  String get accountWellProtected => '账号安全状态良好';

  @override
  String get accountCouldSafer => '账号安全性有待加强';

  @override
  String get setPaymentPinTurnBiometricPayment => '尚未设置交易密码';

  @override
  String tooManyAttemptsLockedUntilP0(Object p0) => '错误次数过多，已锁定至 ${p0}';

  @override
  String get notSetRequiredBeforeCheckout => '尚未设置';

  @override
  String get change => '更改';

  @override
  String get forgotPaymentPin => '忘记交易密码';

  @override
  String p0Devices(Object p0) => '${p0} 台';

  @override
  String get restoredUnfinishedListing => '已带入上次未完成的内容';

  @override
  String get isbnSCheckDigitInvalidPlease => '此 ISBN 校验码不正确，请再次确认';

  @override
  String get draftSavedAutomatically => '已自动保存草稿';

  @override
  String get continueUnfinishedListing => '继续上次未完成的刊登';

  @override
  String clearedP0MbCache(Object p0) => '已清除 ${p0} MB 缓存';

  @override
  String get cacheCleared => '缓存已清除';

  @override
  String get storage => '存储空间';

  @override
  String get clearCache => '清除缓存';

  @override
  String get couldNotLoadNotificationSettings => '无法加载通知设置';

  @override
  String get month => '本月';

  @override
  String p0P1(Object p0, Object p1) => '${p0} 年 ${p1} 月';

  @override
  String get noIncomeYet => '暂无收入记录';

  @override
  String get noSpendingYet => '暂无支出记录';

  @override
  String get income => '收入';

  @override
  String get spending => '支出';

  @override
  String get totalIncome => '累计收入';

  @override
  String get totalSpending => '累计支出';

  @override
  String get item3 => '项目';

  @override
  String get details => '说明';

  @override
  String get balanceAfter => '交易后余额';

  @override
  String get transactionId => '交易编号';

  @override
  String get sessionExpiredPleaseSignAgain => '登录已过期，请重新登录';

  @override
  String get serviceTemporarilyUnavailableTryAgainLater => '服务暂时无法使用，请稍后再试';

  @override
  String get uploadFailedTryAgainLater => '上传失败，请稍后再试';

  @override
  String get nearby => '附近';

  @override
  String p0M(Object p0) => '${p0} 米';

  @override
  String p0Km(Object p0) => '${p0} 公里';

  @override
  String get iphoneDidnTReceiveApnsToken => '设备未取得 Apple 推送凭证（APNs token）。请确认 Xcode 的 Signing & Capabilities 已加入 Push Notifications，并使用同一个 Apple 开发者账号重新安装 App。';

  @override
  String get firebaseDidnTIssuePushToken => 'Firebase 未签发推送 token，请确认 GoogleService-Info.plist 与 App 的 Bundle ID 一致';

  @override
  String couldnTGetPushTokenP0(Object p0) => '获取推送 token 失败：${p0}';

  @override
  String couldnTRegisterPushTokenWith(Object p0) => '推送 token 上传服务器失败：${p0}';

  @override
  String get protectCoinsCheckoutRequires6Digit => '结账前请先设置 6 位数交易密码。';

  @override
  String confirmPaymentP0Coins(Object p0) => '确认付款 ${p0} 代币';

  @override
  String get enterPasswordContinue => '请输入登录密码以继续';

  @override
  String get verifyS => '验证身份';

  @override
  String get amount => '付款金额';

  @override
  String p0Coins(Object p0) => '${p0} 代币';

  @override
  String get enterPaymentPin => '输入交易密码';

  @override
  String get enterPaymentPinContinue => '请输入交易密码以继续';

  @override
  String get paymentPinResetEnterAgain => '交易密码已重新设置，请再次输入';

  @override
  String get usePasswordInstead => '改用登录密码';

  @override
  String get couldnTGetLocationLockersShown => '无法获取当前位置';

  @override
  String p0SlotsFree(Object p0) => '空柜 ${p0} 格';

  @override
  String openP0(Object p0) => '开放 ${p0}';

  @override
  String get nearest => '最近';

  @override
  String get noFreeSlots => '目前没有空柜';

  @override
  String get turnLocationSortByDistance => '开启定位可按距离排序';

  @override
  String get lockerNoFreeSlotsRightNow => '此书柜目前没有空柜';

  @override
  String get turn => '开启定位';

  @override
  String get noLockersAvailable => '目前没有可用的书柜';

  @override
  String get noMatchingOptions => '没有符合的选项';

  @override
  String get undo2 => '撤销';

  @override
  String copiedP0(Object p0) => '已复制「${p0}」';

  @override
  String get typing => '对方正在输入…';

  @override
  String get today => '今天';

  @override
  String get yesterday => '昨天';

  @override
  String p0P12(Object p0, Object p1) => '${p0}月${p1}日';

  @override
  String p1P2P0(Object p0, Object p1, Object p2) => '${p0}年${p1}月${p2}日';

  @override
  String get releaseCancel => '松开以取消';

  @override
  String get awaitingReply => '待回复';

  @override
  String heldUntilP0(Object p0) => '已保留至 ${p0}';

  @override
  String get declined2 => '已婉拒';

  @override
  String get closed => '已结束';

  @override
  String get theyWantReserveBook => '对方申请预约您的书籍';

  @override
  String get sentReservationRequest => '您已发送预约';

  @override
  String holdP0H(Object p0) => '保留 ${p0} 小时';

  @override
  String get holdPeriod => '保留时间';

  @override
  String get messageSellerOptional => '给卖家的留言（选填）';

  @override
  String get sendRequest => '发送预约';

  @override
  String p0Hours(Object p0) => '${p0} 小时';

  @override
  String p0P1DigitsEntered(Object p0, Object p1) => '已输入 ${p0} / ${p1} 位';

  @override
  String get buildSProvisioningProfileDoesnT => '此安装版本的签名描述文件未包含推送权限。请在 Xcode 的 Runner › Signing & Capabilities 确认已加入 Push Notifications，并删除 App 后重新安装。';

  @override
  String get checkPhoneOnlinePushNotificationsAdded => '请确认设备已连接网络，并在 Xcode 的 Runner › Signing & Capabilities 确认已加入 Push Notifications。';

  @override
  String iphoneFailedRegisterPushNotificationsWith(Object p0, Object p1) => 'iPhone 向 Apple 注册推送失败：${p0}\n${p1}';

  @override
  String get serverNotBeenUpdatedSupportFeature => '此功能暂时无法使用，请稍后再试';

  @override
  String get someFeaturesTemporarilyUnavailableWhileServer => '部分功能暂时无法使用';

  @override
  String serverRunningOutdatedApiRevisionP0(Object p0, Object p1) => '服务器运行的 API 版本过旧（当前 ${p0}，App 需要 ${p1}）。请在服务器更新代码并重新启动 API。';

  @override
  String databaseMigrationsNotYetRunP0(Object p0) => '数据库尚未执行：${p0}';

  @override
  String serverVersionP0(Object p0) => '服务器当前版本：${p0}';

  @override
  String get runNpmRunVerifyApiDirectory => '在服务器的 API 目录执行 npm run verify 可检查完整的部署状态。';

  @override
  String get serverUpdateRequired => '服务器需要更新';

  @override
  String versionP0(Object p0) => '第 ${p0} 版';

  @override
  String get requiresUserConsent => '须经用户同意';

  @override
  String get unsavedDraft => '有未保存的草稿';

  @override
  String get allBooks => '全部书籍';

  @override
  String get results => '筛选结果';

  @override
  String get sortBy => '排序方式';

  @override
  String get themeColour => '主题色';

  @override
  String get forestGreen => '森林绿';

  @override
  String get oceanBlue => '海洋蓝';

  @override
  String get lavender => '薰衣草紫';

  @override
  String get terracotta => '赤陶橘';

  @override
  String get amber => '琥珀金';

  @override
  String get rose => '玫瑰粉';

  @override
  String get graphite => '石墨灰';

  @override
  String get mistBlue => '雾蓝';

  @override
  String get draftRestored => '已还原草稿';

  @override
  String get convertSections => '转换为章节模式';

  @override
  String get currentContentDoesNotFullyMatch => '目前内容无法完整对应章节格式。转换后，章节编号将依序重新生成并统一为「1. 标题」格式，未能识别为标题的段落将并入前言或上一章正文。\n\n若需保留原始格式，请继续以纯文本模式编辑并保存。';

  @override
  String get convert => '转换';

  @override
  String get keepPlainText => '维持纯文本';

  @override
  String get noSectionHeadingsDetectedFullText => '未检测到章节标题，全文已置于前言';

  @override
  String deletedP0(Object p0) => '已删除「${p0}」';

  @override
  String get renameSection => '重新命名章节';

  @override
  String get editContent => '编辑内容';

  @override
  String get rename => '重新命名';

  @override
  String get addSectionBelow => '在下方新增章节';

  @override
  String get moveUp => '上移';

  @override
  String get moveDown => '下移';

  @override
  String get enterDocumentTitle => '请填写文件标题';

  @override
  String get enterDocumentContent => '请填写文件内容';

  @override
  String p0NowVersionP1(Object p0, Object p1) => '${p0}，目前为第 ${p1} 版';

  @override
  String versionP0P1(Object p0, Object p1) => '第 ${p0} 版・${p1}';

  @override
  String unsavedDraftFromP0Found(Object p0) => '发现 ${p0} 未保存的草稿';

  @override
  String get documentWasUpdatedAfterDraftWas => '文件已于草稿创建后更新，还原后将以草稿内容取代目前内容。';

  @override
  String get discardDraft => '舍弃草稿';

  @override
  String get restoreDraft => '还原草稿';

  @override
  String get sectionTitleRequired => '尚未填写章节标题';

  @override
  String get documentSFormatDoesNotFully => '此文件的格式无法完整对应章节结构，已以纯文本模式打开，以保留原始格式。';

  @override
  String get enterPasteFullTextHere => '请在此输入或粘贴全文。';

  @override
  String get noSectionHeadingsDetected => '未检测到章节标题';

  @override
  String p0SectionsDetected(Object p0) => '已检测到 ${p0} 个章节';

  @override
  String get paragraphWhoseFirstLine1Title => '段落首行为「1. 标题」、「一、标题」或「第一条 标题」时，视为章节标题。';

  @override
  String get sectionNumbersMustStart1Increase => '章节编号须自 1 起依序递增；不符合者视为上一章的正文。';

  @override
  String get blankLineStartsNewParagraphSingle => '空一行代表分段，单行换行将如实呈现。';

  @override
  String get whenSwitchingSectionsAskedConfirmAny => '切换至章节模式时，若格式需要调整，将先提示确认。';

  @override
  String get howSectionHeadingsDetected => '章节标题判定方式';

  @override
  String get titleEdited => '标题已修改';

  @override
  String p0Added(Object p0) => '新增 ${p0} 章';

  @override
  String p0Removed(Object p0) => '删除 ${p0} 章';

  @override
  String p0Edited(Object p0) => '修改 ${p0} 章';

  @override
  String get sectionsReordered => '章节顺序已调整';

  @override
  String get preambleEdited => '前言已修改';

  @override
  String get contentEdited => '内容已修改';

  @override
  String p0Characters2(Object p0) => '字数 +${p0}';

  @override
  String p0Characters3(Object p0) => '字数 ${p0}';

  @override
  String get formattingAdjusted => '排版调整';

  @override
  String get createdAsVersion1 => '创建为第 1 版';

  @override
  String staysVersionP0(Object p0) => '维持第 ${p0} 版';

  @override
  String versionP0P12(Object p0, Object p1) => '第 ${p0} 版 → 第 ${p1} 版';

  @override
  String get substantiveChangesRightsObligationsTermsAll => '适用于权利义务或条款内容的实质变更。将通知所有用户，用户下次打开 App 时须重新阅读并同意。';

  @override
  String get substantiveContentChangesAllUsersNotified => '适用于内容的实质变更。将通知所有用户。';

  @override
  String saveP0(Object p0) => '保存「${p0}」';

  @override
  String get summaryChanges => '变更摘要';

  @override
  String get updateType => '更新方式';

  @override
  String get fixingTyposFormattingUsersNotNotified => '适用于修正错字或调整排版。不通知用户。';

  @override
  String get contentUnchangedTitleOnlyChangeCannot => '内容未变更，仅修改标题时无法列为重大更新。';

  @override
  String get notificationsSentImmediatelyAfterSubmittingCannot => '提交后将立即发送通知，此操作无法撤回。';

  @override
  String get publishNotify => '发布并通知';

  @override
  String sectionP0(Object p0) => '第 ${p0} 章';

  @override
  String get goSection => '跳至章节';

  @override
  String get sectionContent => '章节内容';

  @override
  String get previous => '上一章';

  @override
  String get next2 => '下一章';

  @override
  String get unableGenerateProfileQrCodeTry => '无法生成个人 QR Code，请稍后再试';

  @override
  String get myQrCode => '我的 QR Code';

  @override
  String get markAsRead => '标为已读';

  @override
  String get unblock => '解除屏蔽';

  @override
  String afterUnblockingP0CanSendMessages(Object p0) => '解除屏蔽后，您与「${p0}」可再次互相发送消息。';

  @override
  String get userUnblocked => '已解除屏蔽';

  @override
  String get unableLoadBlockedUsers => '无法加载屏蔽名单';

  @override
  String get notBlockedAnyUsers => '目前没有屏蔽任何用户';

  @override
  String get blockedUsers => '屏蔽名单';

  @override
  String get blockUser => '屏蔽用户';

  @override
  String afterBlockP0NeitherCanSend(Object p0) => '屏蔽「${p0}」后，双方将无法互相发送消息。';

  @override
  String get block => '屏蔽';

  @override
  String get userBlocked => '已屏蔽此用户';

  @override
  String get moreOptions => '更多选项';

  @override
  String get blockedUser => '您已屏蔽此用户';

  @override
  String get originalMessageNotFound => '找不到原消息';

  @override
  String get you2 => '您';

  @override
  String get viewProfile => '查看个人档案';

  @override
  String get reply => '回复';

  @override
  String get bookLockerScanQrCodeLocker => '书籍已存入书柜，请至书柜扫描机台上的 QR Code 取书';

  @override
  String get originalMessageUnavailable => '原消息已无法显示';

  @override
  String get cancelReply => '取消回复';

  @override
  String get unreadMessages => '以下为未读消息';

  @override
  String get selectChat => '请选择聊天室';

  @override
  String get appPermissions => 'App 权限';

  @override
  String get noPermissionsRequiredDevice => '此设备没有需要授权的项目';

  @override
  String get allowAll => '全部允许';

  @override
  String get camera => '相机';

  @override
  String get photosRead => '相册（读取）';

  @override
  String get photosSave => '相册（写入／保存）';

  @override
  String get microphone => '麦克风';

  @override
  String get location => '定位';

  @override
  String get orderUpdatesChatMessagesAnnouncements => '订单进度、聊天消息与公告';

  @override
  String get scanBarcodesTakeBookPhotos => '扫描条码与拍摄书籍照片';

  @override
  String get chooseBookPhotosProfilePicturesChat => '选取书籍照片、头像与聊天图片';

  @override
  String get saveQrCodesPhotos => '将 QR Code 保存至相册';

  @override
  String get recordVoiceMessagesChats => '录制聊天语音消息';

  @override
  String get showNearestSmartLockersTheirDistance => '显示最近的智能书柜与距离';

  @override
  String get quickSignPaymentConfirmation => '快速登录与确认付款';

  @override
  String get allowed => '已允许';

  @override
  String get limited => '部分允许';

  @override
  String get notAllowed => '未允许';

  @override
  String get restricted => '受系统限制';

  @override
  String get denied => '已拒绝';

  @override
  String get allow => '允许';

  @override
  String get homeRecommendations => '首页推荐区块';

  @override
  String get leaveGroup => '退出群组';

  @override
  String leaveP0(Object p0) => '确定要退出「${p0}」？';

  @override
  String get leave => '退出';

  @override
  String get leftGroup => '已退出群组';

  @override
  String get unpin => '取消置顶';

  @override
  String get pin => '置顶';

  @override
  String get you3 => '您';

  @override
  String get canOnlyEditMessagesSentWithin => '仅能编辑 15 分钟内发送的消息';

  @override
  String p0UnsentMessage(Object p0) => '${p0} 已撤回一条消息';

  @override
  String readByP0(Object p0) => '已读 ${p0}';

  @override
  String get transferDetailsUnavailable => '无法显示转账信息';

  @override
  String get couldNotCreateGroup => '无法创建群组';

  @override
  String get groupDetails => '群组资料';

  @override
  String get selectMembers => '选择成员';

  @override
  String get groupName => '群组名称';

  @override
  String membersP0(Object p0) => '成员 ${p0}';

  @override
  String get createGroup => '创建群组';

  @override
  String get inviteMembers => '邀请成员';

  @override
  String get invite => '邀请';

  @override
  String canSelectUpP0People(Object p0) => '最多可选择 ${p0} 人';

  @override
  String get noChatsChooseFrom => '没有可选择的聊天对象';

  @override
  String get noMatchingPeople => '找不到符合的对象';

  @override
  String get searchByName => '搜索名称';

  @override
  String get chatPinned => '已置顶聊天室';

  @override
  String get unpinned => '已取消置顶';

  @override
  String get setNickname => '设置昵称';

  @override
  String get onlyVisible => '仅自己可见';

  @override
  String get nicknameRemoved => '已移除昵称';

  @override
  String get nicknameUpdated => '已更新昵称';

  @override
  String get enterGroupName => '请输入群组名称';

  @override
  String get groupNameUpdated => '已更新群组名称';

  @override
  String get groupPhotoUpdated => '已更新群组头像';

  @override
  String get groupReachedMemberLimit => '群组成员已达上限';

  @override
  String invitedP0Members(Object p0) => '已邀请 ${p0} 位成员';

  @override
  String get removeMember => '移除成员';

  @override
  String removeP0FromGroup(Object p0) => '确定要将「${p0}」移出群组？';

  @override
  String get memberRemoved => '已移除成员';

  @override
  String get chatSettings => '聊天室设置';

  @override
  String get muteNotifications => '消息免打扰';

  @override
  String get pinChat => '置顶聊天室';

  @override
  String get me => '我';

  @override
  String requestedFromP0(Object p0) => '向 ${p0} 请款';

  @override
  String p0RequestedPaymentFrom(Object p0) => '${p0} 向您请款';

  @override
  String p0RequestedPaymentFromP1(Object p0, Object p1) => '${p0} 向 ${p1} 请款';

  @override
  String sentP0(Object p0) => '转账给 ${p0}';

  @override
  String p0SentCoins(Object p0) => '${p0} 转账给您';

  @override
  String p0SentCoinsP1(Object p0, Object p1) => '${p0} 转账给 ${p1}';

  @override
  String get expired2 => '已逾期';

  @override
  String get payNow => '立即付款';

  @override
  String get cancelRequest => '取消请款';

  @override
  String get request => '请款';

  @override
  String get transfer => '转账';

  @override
  String dueP0(Object p0) => '期限 ${p0}';

  @override
  String transferP0(Object p0) => '转账给 ${p0}';

  @override
  String sentP0CoinsP1(Object p0, Object p1) => '已转账 ${p0} 代币给 ${p1}';

  @override
  String get confirmPayment => '确认付款';

  @override
  String payP0CoinsP1(Object p0, Object p1) => '支付 ${p0} 代币给 ${p1}';

  @override
  String get declineRequest => '婉拒请款';

  @override
  String declineP1CoinRequestFromP0(Object p0, Object p1) => '婉拒 ${p0} 的 ${p1} 代币请款';

  @override
  String cancelRequestP0P1Coins(Object p0, Object p1) => '取消向 ${p0} 请款 ${p1} 代币';

  @override
  String payRequestFromP0(Object p0) => '支付 ${p0} 的请款';

  @override
  String get paymentCompleted => '已完成付款';

  @override
  String get requestDeclined => '已婉拒请款';

  @override
  String get requestCanceled => '已取消请款';

  @override
  String get selectPayer => '请选择付款人';

  @override
  String get selectRecipient => '请选择收款人';

  @override
  String get sendRequest2 => '发送请款';

  @override
  String get confirmTransfer => '确认转账';

  @override
  String get payer => '付款人';

  @override
  String get recipient => '收款人';

  @override
  String limitPerTransferP0Coins(Object p0) => '单笔上限 ${p0} 代币';

  @override
  String insufficientBalanceP0Coins(Object p0) => '余额不足（${p0} 代币）';

  @override
  String balanceP0Coins(Object p0) => '余额 ${p0} 代币';

  @override
  String get noteOptional => '备注（选填）';

  @override
  String get editMessage => '编辑消息';

  @override
  String get cancelEditing => '取消编辑';

  @override
  String get send => '发送';

  @override
  String get switchKeyboard => '切换至键盘';

  @override
  String get voiceMessage => '语音消息';

  @override
  String get edited => '已编辑';

  @override
  String get maximumRecordingLengthReached => '已达录音上限';

  @override
  String get recordingTooShort => '录音时间过短';

  @override
  String p0SRemaining(Object p0) => '剩余 ${p0} 秒';

  @override
  String get releaseSend => '松开即可发送';

  @override
  String get recording => '录音中';

  @override
  String get tapHoldRecord => '点按或按住以录音';

  @override
  String get stopRecording => '停止录音';

  @override
  String get preview2 => '试听';

  @override
  String get startRecording => '开始录音';

  @override
  String get microphoneUnavailable => '无法使用麦克风';

  @override
  String get paymentRequest => '[请款]';

  @override
  String get transfer2 => '[转账]';

  @override
  String get transfer3 => '转入';

  @override
  String get transferOut => '转出';

  @override
  String get deleteBook => '删除书籍';

  @override
  String p0PermanentlyDeletedCannotRestoredSeller(Object p0) => '《${p0}》将永久删除且无法恢复，卖家将收到通知。';

  @override
  String get reasonDeletionOptional => '删除原因（选填）';

  @override
  String get bookDeleted2 => '已删除书籍';

  @override
  String get rotate => '旋转';

  @override
  String get mentioned => '[提及您]';

  @override
  String get saveImage => '保存图片';

  @override
  String get everyone => '所有人';

  @override
  String get mentionMembers => '提及成员';

  @override
  String get removeAdminRole => '解除管理员身份';

  @override
  String makeP0Admin(Object p0) => '确定要将 ${p0} 设为管理员？';

  @override
  String removeAdminRoleFromP0(Object p0) => '确定要解除 ${p0} 的管理员身份？';

  @override
  String get remove2 => '解除';

  @override
  String p0NowAdmin(Object p0) => '已将 ${p0} 设为管理员';

  @override
  String removedAdminRoleFromP0(Object p0) => '已解除 ${p0} 的管理员身份';

  @override
  String photosP02(Object p0) => '[${p0} 张图片]';

  @override
  String get savedDownloads => '已保存至“下载”';

  @override
  String get couldNotSaveImage => '无法保存图片';

  @override
  String savingImagesP0P1(Object p0, Object p1) => '正在保存图片 ${p0} / ${p1}';

  @override
  String get savingImage => '正在保存图片';

  @override
  String get passwordsCanOnlyContainEnglishLetters => '密码仅可使用英文字母、数字及半角符号';

  @override
  String get aiSupport => 'AI 客服';

  @override
  String get howDoIListBook => '如何上架书籍？';

  @override
  String get howDoIPickUpFrom => '如何至书柜取书？';

  @override
  String get howDoIRequestRefund => '如何申请退款？';

  @override
  String get howDoWalletCoinsWork => '代币如何使用？';

  @override
  String get talkPerson => '转接客服人员';

  @override
  String get supportRequestCreatedFromConversationOur => '将转接客服人员，并提供当前的对话内容';

  @override
  String get transfer4 => '转接';

  @override
  String get creatingSupportRequest => '正在转接客服';

  @override
  String get transferredSupportTeam => '已转接客服人员';

  @override
  String get newConversation => '开始新对话';

  @override
  String get currentConversationEnd => '当前的对话将会结束';

  @override
  String get copied2 => '已复制';

  @override
  String get howCanWeHelp => '请问有什么需要协助的地方？';

  @override
  String get failedSend => '发送失败';

  @override
  String get ourSupportTeamCanHelpWith => '此问题建议由客服人员协助处理';

  @override
  String get contactSupport => '联系客服';

  @override
  String get typeQuestion => '输入问题';

  @override
  String get aiFeatures => 'AI 功能';

  @override
  String get aiSettingsNotSavedChangesLost => 'AI 设置尚未保存，离开后更改将不会保留';

  @override
  String get usage => '用量';

  @override
  String reviewP0(Object p0) => '审核 ${p0}';

  @override
  String get dailyCost => '每日费用';

  @override
  String get noCostPeriod => '此期间尚无费用';

  @override
  String get peakDay => '单日最高';

  @override
  String p0Requests(Object p0) => '${p0} 次请求';

  @override
  String get listingAssist => '上架辅助';

  @override
  String get recommendations => '推荐书籍';

  @override
  String get listingReview => '上架审核';

  @override
  String get connectionTest => '连接测试';

  @override
  String get today2 => '今日';

  @override
  String get k7Days => '7 天';

  @override
  String get k30Days => '30 天';

  @override
  String get notBookUnrelatedItem => '非书籍或无关商品';

  @override
  String get prohibitedPiratedContent => '违禁或盗版内容';

  @override
  String get adultContent => '成人内容';

  @override
  String get offPlatformDealContactInfo => '站外交易或联系信息';

  @override
  String get misleadingDescription => '不实描述';

  @override
  String get unusualPrice => '价格异常';

  @override
  String get providerError => '服务商错误';

  @override
  String get timedOut => '超时';

  @override
  String get noApiKey => '未设置密钥';

  @override
  String get rateLimited => '频率受限';

  @override
  String get invalidApiKey => '密钥无效';

  @override
  String get invalidResponseFormat => '响应格式错误';

  @override
  String get rejectListing => '拒绝上架';

  @override
  String get noteOptionalSentSeller => '说明（选填，将通知卖家）';

  @override
  String get reject => '拒绝';

  @override
  String get listingApproved => '已批准上架';

  @override
  String get listingRejected => '已拒绝上架';

  @override
  String get noListingsAwaitingReview => '目前没有待审核的上架';

  @override
  String get likelyViolation => '疑似违规';

  @override
  String get needsReview => '需人工确认';

  @override
  String get rejected => '已拒绝';

  @override
  String get approve => '批准上架';

  @override
  String get pleaseFixHighlightedFields => '请修正标示错误的字段';

  @override
  String get aiSettingsSaved => 'AI 设置已保存';

  @override
  String get invalidFormat => '格式不正确';

  @override
  String enter0P0(Object p0) => '请输入 0 至 ${p0}';

  @override
  String get databaseNotBeenUpdatedAiYet => '数据库尚未完成 AI 相关更新，设置保存后暂时不会生效';

  @override
  String get defaultModel => '默认模型';

  @override
  String get features => '功能';

  @override
  String get on => '已启用';

  @override
  String get noProviderApiKeysSetSo => '尚未设置任何服务商密钥，AI 功能无法使用';

  @override
  String p0NoApiKeyCannotSelected(Object p0) => '${p0} 尚未设置密钥，无法选用';

  @override
  String get input => '输入';

  @override
  String get output => '输出';

  @override
  String get per1mTokens => '每百万 tokens';

  @override
  String get vision => '图片识别';

  @override
  String get webSearch => '联网搜索';

  @override
  String get testing => '测试中';

  @override
  String get test => '测试连接';

  @override
  String connectedP0Ms(Object p0) => '连接成功・${p0} ms';

  @override
  String get connectionFailed => '连接失败';

  @override
  String get keySet => '密钥已设置';

  @override
  String get noKey => '密钥未设置';

  @override
  String get model => '使用模型';

  @override
  String defaultP0(Object p0) => '跟随默认（${p0}）';

  @override
  String p0NoApiKey(Object p0) => '${p0} 尚未设置密钥';

  @override
  String p0DoesNotSupportWebSearch(Object p0) => '${p0} 不支持联网搜索';

  @override
  String get searchNotBilledSeparately => '搜索不另计费';

  @override
  String firstP0SearchesFreeEachMonth(Object p0, Object p1) => '每月前 ${p0} 次免费，之后每千次 ${p1}';

  @override
  String p0Per1000SearchesPlus(Object p0) => '每千次搜索 ${p0}，另计搜索内容 tokens';

  @override
  String get suspiciousListings => '可疑商品处理方式';

  @override
  String get holdReview => '送交审核';

  @override
  String get rejectClearViolations => '直接拒绝明显违规';

  @override
  String get budgetLimits => '预算与上限';

  @override
  String get monthlyBudgetUsd => '每月预算（USD）';

  @override
  String get k0MeansNoCap => '0 为不设上限';

  @override
  String get dailyLimitPerMember => '每位会员每日次数上限';

  @override
  String get k0MeansUnlimited => '0 为不限';

  @override
  String get advanced => '高级设置';

  @override
  String get resetDefault => '恢复默认';

  @override
  String get modelId => '模型 ID';

  @override
  String get priceUsPer1mTokens => '单价（US\$ / 每百万 tokens）';

  @override
  String get cachedInput => '缓存输入';

  @override
  String get searchPriceUsPer1000 => '搜索单价（US\$ / 千次）';

  @override
  String get freeSearchesPerMonth => '每月免费搜索次数';

  @override
  String p0FieldsInvalid(Object p0) => '${p0} 个字段格式不正确';

  @override
  String p0UnsavedChanges(Object p0) => '${p0} 项设置尚未保存';

  @override
  String get unsavedChanges => '有未保存的更改';

  @override
  String get month2 => '本月费用';

  @override
  String budgetP0(Object p0) => '预算 ${p0}';

  @override
  String get noMonthlyBudget => '未设置每月预算';

  @override
  String projectedP0(Object p0) => '预估月底 ${p0}';

  @override
  String get periodCost => '期间费用';

  @override
  String get requests => '请求次数';

  @override
  String p0Searches(Object p0) => '搜索 ${p0} 次';

  @override
  String p0OutP1(Object p0, Object p1) => '输入 ${p0}・输出 ${p1}';

  @override
  String get errors => '错误';

  @override
  String errorRateP0(Object p0) => '错误率 ${p0}%';

  @override
  String p0ListingsAwaitingReview(Object p0) => '${p0} 笔上架待审核';

  @override
  String get byFeature => '按功能';

  @override
  String get noDataYet => '尚无数据';

  @override
  String errorsP0(Object p0) => '错误 ${p0}';

  @override
  String p0Calls(Object p0) => '${p0} 次';

  @override
  String get byModel => '按模型';

  @override
  String p0CallsP1Ms(Object p0, Object p1) => '${p0} 次・${p1} ms';

  @override
  String get topMembers => '用量最高的会员';

  @override
  String p0Uses(Object p0) => '${p0} 次使用';

  @override
  String get recentErrors => '最近错误';

  @override
  String get noErrors => '没有错误';

  @override
  String get fillWithAi => 'AI 带入';

  @override
  String get summary => '简介';

  @override
  String get lookingUpBookDetails => '查询书籍资料';

  @override
  String get searchingWeb => '联网搜索补充资料';

  @override
  String get analyzingPhotos => '分析照片';

  @override
  String get suggestingCategoryConditionPrice => '判断分类、书况与售价';

  @override
  String get couldNotGetAiSuggestions => '无法获取 AI 建议';

  @override
  String get done => '分析完成';

  @override
  String get aiAnalyzing => 'AI 分析中';

  @override
  String get aiSuggestions => 'AI 建议';

  @override
  String get noSuggestionsApply => '没有可带入的建议';

  @override
  String get bookDetails => '书籍资料';

  @override
  String get suggestedPrice => '建议售价';

  @override
  String rangeP0P1(Object p0, Object p1) => '建议区间 \$${p0}–\$${p1}';

  @override
  String listPriceP0(Object p0) => '定价 \$${p0}';

  @override
  String applyP0(Object p0) => '应用 ${p0} 项';

  @override
  String currentP0(Object p0) => '当前：${p0}';

  @override
  String get sameAsCurrent => '与当前相同';

  @override
  String get listingNotApproved => '未通过上架审核';

  @override
  String get editListing => '修改内容';

  @override
  String get submittedReview => '已提交审核';

  @override
  String get goSaleOnceApprovedNotifiedResult => '审核通过后将公开销售';

  @override
  String get got => '确定';

  @override
  String get aiFeaturesNotAvailableRightNow => 'AI 功能目前未开放';

  @override
  String get bookUnderReviewGoSaleOnce => '此书籍正在审核，通过后将公开销售';

  @override
  String get notApproved => '未通过审核';

  @override
  String get bookDidNotPassListingReview => '此书籍未通过上架审核';

  @override
  String get enterIsbnTitleFirst => '请先输入 ISBN 或书名';

  @override
  String appliedP0AiSuggestions(Object p0) => '已应用 ${p0} 项 AI 建议';

  @override
  String get addBookPhotosFirst => '请先添加书籍照片';

  @override
  String get nothingFoundFillCheckIsbnTitle => '找不到可带入的资料，请确认 ISBN 或书名';

  @override
  String appliedP0AiSuggestions2(Object p0) => '已应用 ${p0} 项 AI 建议';

  @override
  String get aiDataProcessingEnabled => '已同意 AI 数据处理';

  @override
  String get aiDataProcessingTurnedOff => '已停止 AI 数据处理';

  @override
  String get aiDataProcessing => 'AI 数据处理';

  @override
  String get messagesEnterStatusOrdersReservations => '您输入的消息与您的订单、预约状态';

  @override
  String get isbnTitleConditionNotesPhotosSelect => 'ISBN、书名、书况说明与您选择的照片';

  @override
  String get bookDetailsFromFavoritesPurchaseHistory => '您的收藏与购买记录中的书籍信息';

  @override
  String get aiDataProcessing2 => 'AI 数据处理说明';

  @override
  String get whenUseAiFeaturesWeShare => '使用 AI 功能时，我们会将下列数据提供给第三方 AI 服务商处理。';

  @override
  String get dataShared => '提供的数据';

  @override
  String get recipients => '数据接收方';

  @override
  String get purpose => '使用目的';

  @override
  String get usedOnlyGenerateSupportRepliesPrepare => '仅用于生成客服回复、整理上架数据与推荐书籍，不会用于广告或追踪。';

  @override
  String get withdrawingConsent => '撤回同意';

  @override
  String get canTurnOffAiDataProcessing => '您可随时于「设置 › 账号管理」关闭「AI 数据处理」，关闭后将不再提供上述数据。';

  @override
  String get agreeContinue => '同意并继续';

  @override
  String get insufficientQuotaPlanNotEnabled => '额度不足或方案未开通';

  @override
  String get modelNotFound => '模型名称不存在';

  @override
  String get invalidRequestParameters => '请求参数不正确';

  @override
  String get couldNotConnectService => '无法连接至服务';

  @override
  String get blockedByProviderSafetySystem => '内容遭服务安全机制拒绝';

  @override
  String get responseExceededOutputLimit => '回应超过输出长度上限';

  @override
  String get serverProcessingError => '服务器处理错误';

  @override
  String get aiBookAdvisor => 'AI 书籍顾问';

  @override
  String get requiresDatabaseUpdate013 => '需先执行数据库更新 013';

  @override
  String get mysteryNovelMyCommute => '适合通勤阅读的推理小说';

  @override
  String get programmingBooksBeginners => '适合入门的程序设计书';

  @override
  String get booksUnder200Coins => '200 代币以内的书籍';

  @override
  String get popularLiteraryFictionRightNow => '最近热门的文学小说';

  @override
  String get tellMeWhatBookLooking => '请描述您想找的书籍';

  @override
  String get describeBookLooking => '描述您想找的书籍';

  @override
  String get tellMeWhatWantReadI => '依您的需求推荐书籍';

  @override
  String get subtitle => '副标题';

  @override
  String get monthOnly => '仅确认到月';

  @override
  String get yearOnly => '仅确认到年';

  @override
  String get msg => '繁體中文';

  @override
  String get additionalInformation => '其他信息';

  @override
  String get readFull => '展开全文';

  @override
  String get pages => '页数';

  @override
  String get simplifiedChinese => '简体中文';

  @override
  String get chinese => '中文';

  @override
  String get english => '英文';

  @override
  String get japanese => '日文';

  @override
  String get korean => '韩文';

  @override
  String p0Pages(Object p0) => '${p0} 页';

  @override
  String get collapse => '收合';

  @override
  String get setPasswordFirst => '请先设置密码';

  @override
  String get setPassword => '设置密码';

  @override
  String get signMethodSettingsSaved => '登录方式设置已保存';

  @override
  String get signMethodSettingsUnsavedLeavingDiscards => '登录方式设置尚未保存，离开后更改将丢失。';

  @override
  String get serverNotRunDatabaseUpdate014 => '服务器尚未执行数据库更新 014，设置暂时无法生效。';

  @override
  String get signChannels => '各项登录方式';

  @override
  String get socialSmsSign => '社交与短信登录';

  @override
  String get whenOffSignPageHidesThese => '关闭后登录页不再显示这些方式，已绑定的账号仍可用密码登录。';

  @override
  String get notConfigured => '未设置';

  @override
  String get allowCreatingNewAccountsWithMethod => '允许以此方式注册新账号';

  @override
  String get unsavedChanges2 => '尚未保存的更改';

  @override
  String get taiwan => '中华民国';

  @override
  String get hongKong => '香港';

  @override
  String get macau => '澳门';

  @override
  String get china => '中华人民共和国';

  @override
  String get japan => '日本';

  @override
  String get southKorea => '韩国';

  @override
  String get singapore => '新加坡';

  @override
  String get malaysia => '马来西亚';

  @override
  String get unitedStatesCanada => '美国／加拿大';

  @override
  String get unitedKingdom => '英国';

  @override
  String get australia => '澳大利亚';

  @override
  String get countryCode => '国码';

  @override
  String get enterValidMobileNumber => '请输入正确的手机号码';

  @override
  String get couldNotSendCodePleaseTry => '无法发送验证码，请稍后再试';

  @override
  String get linkMobileNumber => '绑定手机号码';

  @override
  String get signWithMobileNumber => '手机号码登录';

  @override
  String get k6DigitCodeSentNumberMessage => '将发送 6 位数验证码至此手机号码。';

  @override
  String get mobileNumber => '手机号码';

  @override
  String get sendCode => '发送验证码';

  @override
  String get codeIncorrectPleaseEnterAgain => '验证码不正确，请重新输入';

  @override
  String get codeBeenSentAgain => '已重新发送验证码';

  @override
  String get enterCode => '输入验证码';

  @override
  String get enterSmsCode => '输入短信验证码';

  @override
  String codeWasSentP0(Object p0) => '验证码已发送至 ${p0}';

  @override
  String canResendP0S(Object p0) => '${p0} 秒后可重新发送';

  @override
  String get resendCode => '重新发送验证码';

  @override
  String get completeAccountDetails => '完成账号资料';

  @override
  String get p0DidNotProvideEmailAddress => '请填写电子邮件以完成注册。';

  @override
  String signWithP0(Object p0) => '以 ${p0} 登录';

  @override
  String get signWith2 => '或使用以下方式登录';

  @override
  String get creatingAccountWithMethodsAboveMeans => '使用上述方式创建账号即表示您同意服务条款与隐私政策';

  @override
  String get emailAlreadyRegistered => '此电子邮件已注册';

  @override
  String get signWithPasswordThenLinkMethod => '请以密码登录后，至「账号安全 › 登录方式」绑定。';

  @override
  String get signWithPassword => '以密码登录';

  @override
  String get accountNoPasswordYet => '此账号尚未设置密码';

  @override
  String get passwordSet => '密码已设置';

  @override
  String get canNowSignWithEmailPassword => '其他设备须重新登录。';

  @override
  String get passwordRequiredBeforeCanUnlinkSign => '密码须至少 8 位，且包含英文与数字。';

  @override
  String get changingSignMethodsRequiresIdentityVerification => '更改登录方式前，请先设置密码。';

  @override
  String get later => '暂不设置';

  @override
  String p0Linked(Object p0) => '已绑定 ${p0}';

  @override
  String unlinkP0(Object p0) => '解除绑定 ${p0}';

  @override
  String get noLongerAbleSignWayCan => '解除后将无法以此方式登录。';

  @override
  String get unlink => '解除绑定';

  @override
  String p0Unlinked(Object p0) => '已解除绑定 ${p0}';

  @override
  String get socialSmsSignNotAvailableRight => '目前未开放社交与短信登录方式。';

  @override
  String get noSignMethodAvailableLink => '目前没有可绑定的登录方式。';

  @override
  String get noPasswordSet => '尚未设置密码';

  @override
  String linkedP0(Object p0) => '${p0} 绑定';

  @override
  String get link => '绑定';

  @override
  String get emailAlreadyRegisteredSignWithPassword => '此电子邮件已注册，请先以密码登录后，于账号安全绑定此登录方式';

  @override
  String get provideEmailAddressCreateAccount => '请提供电子邮件以创建账号';

  @override
  String get signMethodOnlyExistingAccounts => '此登录方式仅供既有账号使用';

  @override
  String get signMethodNotAvailableRightNow => '目前未开放此登录方式';

  @override
  String get credentialDoesNotMatchSelectedSign => '登录失败，请重新操作';

  @override
  String get signMethodLinkedAnotherAccount => '此登录方式已绑定其他账号';

  @override
  String get accountAlreadyLinkedSignMethod => '此账号已绑定此登录方式';

  @override
  String get onlySignMethodAccountSetPassword => '这是此账号唯一的登录方式，请先设置密码或绑定其他登录方式';

  @override
  String get socialSignUnavailableServerNotFinished => '社交登录暂时无法使用，请稍后再试';

  @override
  String get credentialInvalidExpiredPleaseTryAgain => '登录超时，请重新操作';

  @override
  String get accountAlreadyPasswordUseChangePassword => '此账号已设置密码，请改用更改密码';

  @override
  String get signLinkExpiredPleaseTryAgain => '登录链接已失效，请重新操作';

  @override
  String get signResultExpiredPleaseTryAgain => '登录超时，请重新操作';

  @override
  String get thirdPartySignServiceUnavailablePlease => '第三方登录服务目前无法使用，请稍后再试';

  @override
  String get couldNotCompleteSignPleaseTry => '无法完成登录，请重新操作';

  @override
  String get accountNotLinkedSignMethod => '此账号未绑定此登录方式';

  @override
  String get mobileNumberFormatNotValid => '手机号码格式不正确';

  @override
  String get verificationTimedOutRequestNewCode => '验证已超时，请重新获取验证码';

  @override
  String get codeExpiredRequestNewOne => '验证码已超时，请重新获取验证码';

  @override
  String get tooManyAttemptsPleaseTryAgain => '尝试次数过多，请稍后再试';

  @override
  String get smsSendingLimitBeenReachedPlease => '短信发送次数已达上限，请稍后再试';

  @override
  String get smsVerificationNotSetUpDevice => '此设备目前无法使用短信验证，请改用其他登录方式';

  @override
  String get couldNotCompleteSmsVerificationPlease => '无法完成短信验证，请稍后再试';

  @override
  String get allowSigningLinkingWithMethod => '开放此方式登录与绑定';

  @override
  String get appNeverStoresPasswordUsedOnly => '本 App 不会储存您的密码，仅用于本次验证。';

  @override
  String get verifyWithBiometricsInstead => '改用生物识别验证';

  @override
  String get accountWasCreatedWithSocialPhone => '此账号尚未设置登录密码，请先完成设置。';

  @override
  String get setSignPassword => '前往设定登入密码';

  @override
  String get enterSignPasswordRunAdminAction => '请以登入密码或通行密钥验证身分以执行此后台操作';

  @override
  String p1P0MethodsEnabled(Object p0, Object p1) => '共 ${p0} 种方式，目前启用 ${p1} 种';

  @override
  String get masterSwitchOffSoEveryMethod => '总开关关闭，所有方式一律停用';

  @override
  String get signLinkingDirectSignUpAllowed => '可登录、绑定与直接注册';

  @override
  String credentialsNotSetPleaseConfigureP0(Object p0) => '尚未设置凭证，请于服务器设置 ${p0}';

  @override
  String get whenOffMethodHiddenFromSign => '关闭后登录页与账号安全将不显示此方式';

  @override
  String get whenOffOnlyAccountsAlreadyLinked => '关闭后仅限已绑定的账号使用此方式';

  @override
  String get signMethodNotLinkedAccount => '此登录方式尚未绑定账号';

  @override
  String p0AccountNotLinkedAnySavemybook(Object p0) => '${p0} 账号尚未绑定救「舊」我的書账号。';

  @override
  String get iAlreadyAccountSignFirst => '登录已有账号并绑定';

  @override
  String get createNewAccountWithIdentity => '创建新账号';

  @override
  String signExistingAccountFirstThenLink(Object p0) => '请先登录原有账号，再至「账号安全 › 登录方式」绑定 ${p0}。';

  @override
  String get signMethodNotLinkedAnyAccount => '此登录方式尚未绑定任何账号';

  @override
  String get verifyIdentityWithPasskeyContinue => '请使用通行密钥验证身分以继续';

  @override
  String get verifyWithPasskeyInstead => '改用通行密钥验证';

  @override
  String get passkeys => '通行密钥';

  @override
  String get verifyWithFaceIdFingerprintScreen => '以此装置的 Face ID、指纹或屏幕锁定完成验证，不必输入密码。';

  @override
  String get verifyWithPasskey => '使用通行密钥验证';

  @override
  String get useSignPasswordInstead => '改用登入密码验证';

  @override
  String get signWithPasskey => '使用通行密钥登入';

  @override
  String get passkeyAdded => '已新增通行密钥';

  @override
  String get screenLock => '屏幕锁定';

  @override
  String fromNowCanSignVerifyIdentity(Object p0) => '之后登入与验证身分可改用 ${p0}，不必再输入密码。';

  @override
  String get deletePasskey => '删除通行密钥';

  @override
  String get noLongerAbleSignVerifyIdentity => '删除后将无法以此通行密钥登入或验证身分。装置中储存的通行密钥不会一并移除，可至系统的密码设定中删除。';

  @override
  String get passkeyDeleted => '已删除通行密钥';

  @override
  String get signVerifyIdentityWithFaceId => '以 Face ID、指纹或屏幕锁定登入与验证身分，不必输入密码。通行密钥只储存在您的装置与密码管理工具中。';

  @override
  String get addPasskey => '新增通行密钥';

  @override
  String get notUsedYet => '尚未使用';

  @override
  String lastUsedFormatdateItemLastusedat(Object p0) => '最后使用 ${p0}';

  @override
  String createdCreated(Object p0) => '建立于 ${p0}';

  @override
  String get noPasskeyAvailableDeviceUsePassword => '此装置没有可用的通行密钥，请改用密码';

  @override
  String get passkeyAlreadyRegisteredDevice => '此装置已经注册过通行密钥';

  @override
  String get signGoogleAccountTurnPasswordManager => '请先在装置上登入 Google 账号并开启密码管理工具，或改用密码';

  @override
  String get setUpScreenLockPasswordManager => '此装置尚未设定屏幕锁定或密码管理工具，无法建立通行密钥';

  @override
  String get deviceDoesNotSupportPasskeysUse => '此装置不支持通行密钥，请改用密码';

  @override
  String get passkeysTemporarilyUnavailableBecauseAppWebsite => '目前无法使用通行密钥，请改用密码';

  @override
  String get requestTimedOutPleaseTryAgain => '操作超时，请再试一次';

  @override
  String get passkeyRequestFailedUsePasswordInstead => '通行密钥操作失败，请改用密码';

  @override
  String get verifyIdentityBeforeAddingPasskey => '新增通行密钥前，请先验证身分';

  @override
  String get couldNotListPleaseTryAgain => '上架失败，请稍后再试';

  @override
  String downloadLinkValidOnceP0P1(Object p0, Object p1) => '此下载网址 5 分钟内有效，且仅能使用一次，请勿分享。\n\n${p0}\n\n文件大小：${p1}';

  @override
  String get sources => '资料来源';

  @override
  String get unableOpenLink => '无法打开链接';

  @override
  String get helpCentre2 => '客服中心';

  @override
  String get preferences => '偏好设置';

  @override
  String get privacy => '隐私';

  @override
  String get about2 => '关于';

  @override
  String clearP0Notifications(Object p0) => '清除${p0}通知';

  @override
  String p1NotificationsP0DeletedCannotUndone(Object p0, Object p1) => '将删除${p0}类的 ${p1} 条通知，此操作无法复原。';

  @override
  String p0NotificationsCleared(Object p0) => '已清除${p0}通知';

  @override
  String markAllP1UnreadNotificationsP0(Object p0, Object p1) => '确定要将${p0}类的 ${p1} 条未读通知全部标为已读？';

  @override
  String get offers => '优惠';

  @override
  String get noTransactionNotifications => '没有交易通知';

  @override
  String get noChatNotifications => '没有聊天通知';

  @override
  String get noAccountNotifications => '没有账号通知';

  @override
  String get noSupportNotifications => '没有客服通知';

  @override
  String get noOfferNotifications => '没有优惠通知';

  @override
  String get images => '图片';

  @override
  String get imagesStillUploadingPleaseWaitBefore => '图片上传中，请稍候再发送';

  @override
  String get someImagesFailedUploadRetryRemove => '部分图片上传失败，请重试或移除后再发送';

  @override
  String get attachImages => '附加图片';

  @override
  String get imageCouldNotRead => '无法读取这张图片';

  @override
  String get up4ImagesPerMessage => '每条消息最多附加 4 张图片';

  @override
  String retryUploadingImageP0(Object p0) => '重试上传图片 ${p0}';

  @override
  String removeImageP0(Object p0) => '移除图片 ${p0}';

  @override
  String get addImages => '添加图片';

  @override
  String viewImageP0(Object p0) => '查看图片 ${p0}';

  @override
  String get eGGoldMember => '例如：黄金会员';

  @override
  String get pointsThreshold => '门槛点数';

  @override
  String get pts => '点';

  @override
  String get tierBenefits => '等级福利';

  @override
  String get oneBenefitPerLine => '每行一项福利';

  @override
  String get newTier2 => '新等级';

  @override
  String get whatMembersSee => '会员看到的样式';

  @override
  String get noThresholdSet => '尚未设置门槛';

  @override
  String get tierOrder => '等级顺序';

  @override
  String get noBenefitsSet => '尚未设置福利';

  @override
  String p0CurrentlyP1MembersAfterDeletion(Object p0, Object p1, Object p2) => '“${p0}”目前有 ${p1} 位会员，删除后将改列“${p2}”。';

  @override
  String noMembersCurrentlyP0OtherTiers(Object p0) => '目前没有会员属于“${p0}”，删除后其他等级不受影响。';

  @override
  String tierDeletedP0MembersMovedP1(Object p0, Object p1) => '已删除等级，${p0} 位会员改列“${p1}”';

  @override
  String get changeTierOrder => '调整等级顺序';

  @override
  String get thresholdsStayWithTheirPositionThese => '门槛点数按位置保留，以下等级的门槛将变更：';

  @override
  String p0P1P2Pts(Object p0, Object p1, Object p2) => '“${p0}”${p1} → ${p2} 点';

  @override
  String get tierOrderUpdated => '已更新等级顺序';

  @override
  String p0Members(Object p0) => '${p0} 位会员';

  @override
  String get tiers => '个等级';

  @override
  String get members4 => '位会员';

  @override
  String get memberDistribution => '会员分布';

  @override
  String get moreActions => '更多操作';

  @override
  String get dragReorder => '拖动调整顺序';

  @override
  String p0Pts(Object p0) => '${p0} 点以上';

  @override
  String p0P1Pts(Object p0, Object p1) => '${p0}–${p1} 点';

  @override
  String tierNamedP0AlreadyExists(Object p0) => '已有名为“${p0}”的等级';

  @override
  String get enterPointsThreshold => '请输入门槛点数';

  @override
  String get thresholdMustWholeNumber0More => '门槛点数须为 0 以上的整数';

  @override
  String thresholdCannotExceedP0(Object p0) => '门槛点数不可超过 ${p0}';

  @override
  String p0AlreadyUsesP1PtsEach(Object p0, Object p1) => '“${p0}”已使用 ${p1} 点，每个等级的门槛须不同';

  @override
  String get startingTierMustBegin0Pts => '起始等级的门槛须为 0 点';

  @override
  String get startingTierCannotDeletedSetAnother => '起始等级无法删除，请先将其他等级的门槛调整为 0 点';

  @override
  String get signLink => '登入并绑定';

  @override
  String get signAccount => '登入既有账号';

  @override
  String emailAlreadyRegisteredSignLinkName(Object p0) => '此电子邮件已注册，登入后即绑定 ${p0}。';

  @override
  String signLinkNameCanThenSign(Object p0, Object p1) => '登入后即绑定 ${p0}，之后可直接使用 ${p1} 登入。';

  @override
  String get noPasskeyDevice => '此装置没有可用的通行密钥';

  @override
  String get signWithPasskeyAnotherDeviceSecurity => '可使用其他装置上的通行密钥或安全密钥登入，或改用密码。';

  @override
  String get useAnotherDevice => '使用其他装置';

  @override
  String get usePassword => '改用密码';

  @override
  String get icloudKeychain => 'iCloud 钥匙串';

  @override
  String get googlePasswordManager => 'Google 密码管理工具';

  @override
  String get synced => '已同步';

  @override
  String get notSynced => '未同步';

  @override
  String get alreadyPasskey => '已有可用的通行密钥';

  @override
  String get enterName => '请输入名称';

  @override
  String get passkeySavedIcloudKeychainWorksEvery => '通行密钥已储存在 iCloud 钥匙串，登入同一 Apple 账号的装置皆可使用，无须重复新增。如需另外建立，请按「再次新增」并在系统窗口改选其他密码管理工具或安全密钥。';

  @override
  String get passkeySavedGooglePasswordManagerWorks => '通行密钥已储存在 Google 密码管理工具，登入同一 Google 账号的装置皆可使用，无须重复新增。如需另外建立，请按「再次新增」并在系统窗口改选其他密码管理工具或安全密钥。';

  @override
  String get passkeySavedDeviceSPasswordManager => '通行密钥已储存在此装置的密码管理工具，登入同一账号的装置皆可使用，无须重复新增。如需另外建立，请按「再次新增」并在系统窗口改选其他密码管理工具或安全密钥。';

  @override
  String get addAgain => '再次新增';

  @override
  String get codeExpiredPleaseRequestNewOne => '验证码已失效，请重新发送';

  @override
  String codeValidP0(Object p0) => '验证码有效时间 ${p0}';

  @override
  String get basicSettings => '基本设置';

  @override
  String get eGBirthdayVoucher => '例如：生日礼券';

  @override
  String get benefitDetails => '福利内容';

  @override
  String get addBenefit => '新增福利';

  @override
  String get bookNoLongerExistsBeenRemoved => '此书籍已不存在或已下架';

  @override
  String get myNicknameGroup => '我在群组的昵称';

  @override
  String get setGroupNickname => '设置群组昵称';

  @override
  String get allGroupMembersSeeNickname => '群组内所有成员都会看到此昵称';

  @override
  String get markLockerMaintenance => '设为维修中';

  @override
  String get endLockerMaintenance => '结束维修';

  @override
  String maintenanceHidesP0FromSellers(Object p0) => '设为维修中后“${p0}”将不再显示在卖家的存放区域菜单中，现有订单不受影响。';

  @override
  String endingMaintenanceP0AvailableAgain(Object p0) => '结束维修后“${p0}”将重新开放卖家选择。';

  @override
  String get lockerMarkedMaintenance => '书柜已设为维修中';

  @override
  String get lockerMaintenanceEnded => '书柜已结束维修';

  @override
  String get semanticIndex => '语义索引';

  @override
  String get semanticSearch => '语义检索';

  @override
  String p0BooksP1HelpArticlesIndexed(Object p0, Object p1) => '已建立书籍 ${p0} 笔、客服知识 ${p1} 笔';

  @override
  String get noOpenaiGeminiKeyConfiguredOnly => '尚未设置 OpenAI 或 Gemini 密钥，目前仅使用关键词检索';

  @override
  String get databaseNotBeenUpdated020Only => '数据库尚未更新（020），目前仅使用关键词检索';

  @override
  String get hybridSearchKeywordSemantic => '混合检索（关键词＋语义）';

  @override
  String get keywordSearchOnly => '仅关键词检索';

  @override
  String get paymentReleasedWalletWhenBuyerCompletes => '买家完成订单或取书满 24 小时后，款项将拨入您的钱包';

  @override
  String get completeOrderAfterCheckingBookCompletes => '确认书况无误后请完成订单，取书满 24 小时未申诉将自动完成';

  @override
  String get completeOrder => '完成订单';

  @override
  String get onceCompleteOrderPaymentReleasedSeller => '完成订单后，款项将拨给卖家，且无法再申请争议。';

  @override
  String get orderCompleted2 => '订单已完成';

  @override
  String get noReservedBooks => '目前没有预订的书籍';

  @override
  String heldUntilP02(Object p0) => '保留至 ${p0}';

  @override
  String heldUntilP03(Object p0) => '保留至 ${p0}';

  @override
  String get awaitingBuyerConfirmation => '待买家确认';

  @override
  String get awaitingCompletion => '待完成订单';

  @override
  String get libraryCopyUnofficialSource => '馆藏或非正规来源';

  @override
  String p0CannotEdit(Object p0) => '${p0}・无法编辑';

  @override
  String get buyNow2 => '直接购买';

  @override
  String get suggestRefund => '建议退款';

  @override
  String get suggestDismissal => '建议驳回';

  @override
  String get needsMoreInformation => '需要更多信息';

  @override
  String get aiAnalysis => 'AI 分析';

  @override
  String get analyze => '开始分析';

  @override
  String get analyzeAgain => '重新分析';

  @override
  String get aiAnalysisReferenceOnlyDecideBased => 'AI 分析仅供参考，请依实际证据裁决。';

  @override
  String p0P1Confidence(Object p0, Object p1) => '${p0}・置信度 ${p1}%';

  @override
  String get aiSummary => 'AI 整理';

  @override
  String get autoFilled => '自动补齐';

  @override
  String get similarBooks => '相似的书';

  @override
  String get doNotPayTransferMoneyOutside => '请勿私下汇款或转账，站外付款不受平台保障';

  @override
  String get pleaseCompleteDealAppWeCannot => '请通过平台交易，站外交易发生纠纷时平台无法协助';

  @override
  String get personSharedOutsideContactDetailsWatch => '对方提供了站外联系方式，请留意诈骗并通过平台完成交易';

  @override
  String get mostRelevant => '最相关';

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
  String get orderRefunding => '審核中';

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
  String get orderFlowPickup => '買家已取書';

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
  String get language => '語言';

  @override
  String get languageSystem => '跟隨系統';

  @override
  String get verifySignSavemybook => '驗證身分以登入救「舊」我的書';

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
  String get mySavemybookData => '救「舊」我的書帳號資料';

  @override
  String get exportedChooseWhereSave => '已匯出，請選擇儲存位置';

  @override
  String get exportedButSharingCouldNotOpen => '匯出完成，但無法開啟分享';

  @override
  String get regenerateShareLink => '重新產生分享連結';

  @override
  String get oldLinkQrCodeStopWorking => '舊的連結與 QR Code 將立即失效，已分享的連結將無法開啟。確定要重新產生嗎？';

  @override
  String get regenerate => '重新產生';

  @override
  String get newLinkCreatedOldOneNo => '已產生新連結，舊連結已失效';

  @override
  String get deleteAccount => '刪除帳號';

  @override
  String get accountPermanentlyDisabled30DaysSign => '帳號將於 30 天後刪除，期間內重新登入即可取消。刪除後將清除個人資料，已完成的訂單與交易紀錄將予以保留。';

  @override
  String get actionContinue => '繼續';

  @override
  String get verify => '確認身分';

  @override
  String get enterPasswordConfirm => '請輸入密碼以確認身分。';

  @override
  String get password => '密碼';

  @override
  String get requestDeletion => '申請刪除';

  @override
  String get receivedSignAgainWithin30Days => '已受理，30 天內重新登入即可取消';

  @override
  String get deletionCancelledAccountActiveAgain => '已取消刪除，帳號已恢復';

  @override
  String get account => '帳號管理';

  @override
  String get data => '個人資料';

  @override
  String get exportMyData => '匯出我的資料';

  @override
  String get cancelAccountDeletion => '取消刪除帳號';

  @override
  String get deletionPending => '待刪除';

  @override
  String daysLeftCanCancelAnyTime(Object p0) => '剩餘 ${p0} 天。期限內可隨時取消，逾期後個人資料將被清除且無法復原。';

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
  String bookCannotPurchased(Object p0) => '此書籍目前${p0}，無法購買';

  @override
  String get addedCart => '已加入購物車';

  @override
  String get sellerInformationNotFound => '找不到賣家資訊';

  @override
  String get signContactSeller => '請先登入才能聯絡賣家';

  @override
  String get signStartChat => '請先登入才能聯絡賣家';

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
  String get reportSubmittedWeLookInto => '檢舉已送出';

  @override
  String get publisher => '出版社：';

  @override
  String get author => '作者：';

  @override
  String get listed => '上架日期：';

  @override
  String get searchTitleAuthorPublisher => '搜尋書名、作者或出版社';

  @override
  String get share => '分享';

  @override
  String get report => '檢舉';

  @override
  String get about => '簡介：';

  @override
  String get messageSeller => '聯絡賣家';

  @override
  String get listing => '您上架的書籍';

  @override
  String get addCart => '加入購物車';

  @override
  String get bookBeenReportedUnderReviewStays => '此書籍已遭檢舉，審核中。';

  @override
  String get violationWasConfirmedBookPleaseCheck => '此書籍經審核確認違規，請修改商品內容。';

  @override
  String get delist => '取消上架';

  @override
  String removedFromShopBuyersNoLonger(Object p0) => '《${p0}》將從商城下架，買家將無法瀏覽。';

  @override
  String get delist2 => '下架';

  @override
  String get couldNotDelistPleaseTryAgain => '下架失敗，請稍後再試';

  @override
  String listedAgain(Object p0) => '《${p0}》已重新上架';

  @override
  String get notListedAnyBooksYet => '尚未上架任何書籍';

  @override
  String get noBooksCategory => '此分類目前沒有書籍';

  @override
  String get relist => '重新上架';

  @override
  String get remove => '移除';

  @override
  String get couldNotRemoveRestored => '移除失敗，已還原';

  @override
  String get selectBooksWantCheckOut => '請先選擇要結帳的書籍';

  @override
  String notEnoughCoinsOrderNeedsBut(Object p0, Object p1) => '代幣不足，此訂單需 ${p0}，目前餘額 ${p1}';

  @override
  String booksTotal(Object p0, Object p1) => '共 ${p0} 本書，總金額 \$${p1}。\n';

  @override
  String balanceAfterPaymentCoins(Object p0) => '扣款後餘額為 ${p0} 代幣。';

  @override
  String get orderPlacedSellerDropBookOff => '結帳成功，請等待賣家存書';

  @override
  String get cart => '購物車';

  @override
  String get cartEmpty => '購物車內沒有商品';

  @override
  String get selectAll => '全選';

  @override
  String items(Object p0) => '${p0} 件商品';

  @override
  String get deselect => '取消選取';

  @override
  String get select => '選取';

  @override
  String coinsShort(Object p0) => '尚差 ${p0} 代幣';

  @override
  String get total => '合計';

  @override
  String selected(Object p0) => '${p0} 件';

  @override
  String balance2(Object p0) => '餘額 ${p0}';

  @override
  String get selectBookFirst => '請選擇書籍';

  @override
  String get checkOut => '結帳';

  @override
  String get notEnoughCoins => '代幣不足';

  @override
  String get weak => '弱';

  @override
  String get fair => '普通';

  @override
  String get strong => '強';

  @override
  String get enterCurrentPassword => '請輸入目前密碼';

  @override
  String get enterNewPassword => '請輸入新密碼';

  @override
  String get newPasswordMustDifferent => '新密碼不可與目前密碼相同';

  @override
  String get enterNewPasswordAgain => '請再次輸入新密碼';

  @override
  String get passwordsDoNotMatch => '兩次輸入的新密碼不一致';

  @override
  String get passwordUpdated => '密碼已更新';

  @override
  String get changePassword => '更改密碼';

  @override
  String get useLeast8CharactersWithBoth => '密碼須至少 8 碼，且同時包含英文與數字。';

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
  String allMessagesWithDeletedBothCannot(Object p0) => '將一併刪除與 ${p0} 的所有訊息，雙方皆無法再查看。此操作無法復原。';

  @override
  String get chatDeleted => '已刪除聊天室';

  @override
  String get couldNotDeleteRestored => '刪除失敗，已還原';

  @override
  String get chatMuted => '已將此聊天室設為靜音';

  @override
  String get chatUnmuted => '已取消靜音';

  @override
  String get noUnreadMessages => '沒有未讀訊息';

  @override
  String get markAllAsRead => '全部標為已讀';

  @override
  String markAllUnreadMessagesAsRead(Object p0) => '確定要將 ${p0} 則未讀訊息全部標為已讀？';

  @override
  String get markAllRead => '全部已讀';

  @override
  String get allMarkedAsRead => '已全部標為已讀';

  @override
  String get somethingWentWrongPleaseTryAgain => '操作失敗，請稍後再試';

  @override
  String get chats => '聊天室';

  @override
  String get noConversationsYet => '尚無任何對話';

  @override
  String get unmute => '取消靜音';

  @override
  String get mute => '靜音';

  @override
  String get messageCouldNotSent => '訊息傳送失敗';

  @override
  String get chat => '聊天';

  @override
  String get sendFirstMessage => '傳送第一則訊息';

  @override
  String get messageCopied => '已複製訊息';

  @override
  String get iQuestionAboutBook => '詢問書籍';

  @override
  String get bookNoLongerListed => '此書籍已下架';

  @override
  String get writeMessage => '輸入訊息…';

  @override
  String get enterOrderNumberDisputing => '請填寫要申訴的訂單編號';

  @override
  String get describeDispute => '請填寫爭議說明';

  @override
  String get useLeast10CharactersSoSupport => '爭議說明至少需 10 個字';

  @override
  String get submitDispute => '送出爭議申請';

  @override
  String get orderEntersDisputeProcessPaymentSeller => '送出後此訂單將進入申訴流程，款項將暫停撥付給賣家，直至客服裁決。';

  @override
  String paymentHoldRequested(Object p0) => '[申請凍結款項] ${p0}';

  @override
  String get disputeSubmittedSupportContact => '爭議申請已送出，客服將盡快與您聯繫';

  @override
  String get dispute => '爭議處理';

  @override
  String get requestPaymentHold => '申請凍結款項';

  @override
  String get submitDispute2 => '提交爭議申請';

  @override
  String get orderNumber => '訂單編號';

  @override
  String get eGSmb20260910123456789 => '例如 SMB20260910123456789';

  @override
  String get whatHappened => '爭議說明';

  @override
  String get describeProblemEGConditionDoes => '請描述發生的問題';

  @override
  String get submit => '送出申請';

  @override
  String get uploadPhotos => '上傳圖片';

  @override
  String get canAttachUp6Photos => '最多可上傳 6 張佐證照片';

  @override
  String get keepLeastOnePhoto => '請至少保留一張照片';

  @override
  String get photoDeleted => '已刪除照片';

  @override
  String get couldNotDeletePhotoPleaseTry => '刪除圖片失敗，請稍後再試';

  @override
  String get canUp10Photos => '最多可上傳 10 張照片';

  @override
  String get deletePhoto => '刪除照片';

  @override
  String get cannotUndoneContinue => '刪除後無法復原，確定要刪除嗎？';

  @override
  String get photoMissingDataRefreshTryAgain => '無法處理此照片，請重新整理後再試';

  @override
  String get enterPrice => '請填寫價格';

  @override
  String get priceMustGreaterThan0 => '價格必須大於 0';

  @override
  String get chooseLockerLocation => '請選擇存放區域';

  @override
  String missingTheseThreeRequired(Object p0) => '尚缺：${p0}（以上三張為必填）';

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
  String get tapPickPublicationDate => '選擇出版日期';

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
  String get tellPeopleAboutYourself => '請輸入個人簡介';

  @override
  String get email => '電子郵件';

  @override
  String get emailCannotChanged => '電子郵件無法修改';

  @override
  String get dateBirth => '生日';

  @override
  String get tapPickDateBirth => '選擇生日';

  @override
  String get pickDateBirth => '選擇生日';

  @override
  String get savedBooks => '收藏書籍';

  @override
  String get notSavedAnyBooksYet => '尚未收藏任何書籍';

  @override
  String get helpCentre => '幫助中心';

  @override
  String get searchQuestions => '搜尋問題';

  @override
  String get noQuestionsYet => '目前尚無常見問題';

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
  String get reachedEnd => '已顯示全部內容';

  @override
  String get guest => '訪客';

  @override
  String hi(Object p0) => '您好，${p0}';

  @override
  String get noBooksMatchFilters => '目前沒有符合條件的書籍';

  @override
  String get couldNotReadPhoto => '無法讀取此照片';

  @override
  String get croppingFailedPleaseTryAgain => '裁切失敗，請重試';

  @override
  String get adjustPhoto => '調整照片';

  @override
  String get reset => '重設';

  @override
  String get documentNotBeenCreatedYet => '目前無內容';

  @override
  String lastUpdated(Object p0) => '最後更新：${p0}';

  @override
  String get biometrics => '生物辨識';

  @override
  String get sessionExpiredPleaseEnterPasswordAgain => '登入資訊已失效，請重新輸入密碼';

  @override
  String turnSign(Object p0) => '啟用 ${p0} 登入？';

  @override
  String nextTimeOpenAppCanUnlock(Object p0) => '下次開啟 App 時可使用 ${p0} 解鎖，無須輸入密碼。';

  @override
  String get notNow => '暫不啟用';

  @override
  String get enterEmail => '請輸入電子郵件';

  @override
  String get emailAddressNotValid => '電子郵件格式不正確';

  @override
  String get enterPassword => '請輸入密碼';

  @override
  String get noAccountWithEmail => '此帳號尚未註冊';

  @override
  String noAccountCreateOneNow(Object p0) => '找不到帳號「${p0}」，是否立即註冊？';

  @override
  String get signUp => '前往註冊';

  @override
  String get tryAgain => '重新輸入';

  @override
  String get sign => '登入';

  @override
  String signWith(Object p0) => '使用 ${p0} 登入';

  @override
  String get noAccountYetSignUp => '尚無帳號？立即註冊';

  @override
  String get membershipTiersNotSetUpYet => '目前未提供會員等級';

  @override
  String get currentTier => '目前等級';

  @override
  String get unlocked => '已解鎖';

  @override
  String get locked => '尚未解鎖';

  @override
  String get aboveTier => '已超過此等級';

  @override
  String get reachedTopTier => '已達最高等級';

  @override
  String unlocked2(Object p0) => '已解鎖「${p0}」';

  @override
  String morePointsUnlock(Object p0, Object p1) => '再 ${p0} 點即可解鎖「${p1}」';

  @override
  String benefits(Object p0) => '${p0}等級權益';

  @override
  String get noBenefitsBeenDescribedTierYet => '此等級目前無額外權益';

  @override
  String pointsFromCompletedOrders(Object p0, Object p1) => '目前累積 ${p0} 點，已完成 ${p1} 筆交易';

  @override
  String get noNotificationsClear => '目前沒有可清除的通知';

  @override
  String get clearAllNotifications => '清除全部通知';

  @override
  String notificationsDeletedCannotUndone(Object p0) => '將刪除 ${p0} 則通知，此操作無法復原。';

  @override
  String get clearAll => '全部清除';

  @override
  String get allNotificationsCleared => '已清除全部通知';

  @override
  String get couldNotClearPleaseTryAgain => '清除失敗，請稍後再試';

  @override
  String get noUnreadNotifications => '沒有未讀通知';

  @override
  String markAllUnreadNotificationsAsRead(Object p0) => '確定要將 ${p0} 則未讀通知全部標為已讀？';

  @override
  String get openChat => '前往聊天室';

  @override
  String get viewOrder => '查看訂單';

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
  String get orderNoItemDetails => '無商品明細';

  @override
  String msg4(Object p0, Object p1) => '單價 \$${p0} × ${p1}';

  @override
  String get orderTotal => '訂單金額';

  @override
  String get pickupDetails => '取書資訊';

  @override
  String get notAssigned => '尚未指定';

  @override
  String get slot => '櫃位';

  @override
  String get notAssignedYet => '尚未分配櫃位';

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
  String get pendingPayoutDisappearsBuyerNotified => '取消後此筆待定收益將一併取消，並通知買家。';

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
  String get coinsArriveOnceBuyerCollectsBook => '買家取書後自動撥款';

  @override
  String get scanned => '掃描成功';

  @override
  String get scanAgain => '繼續掃描';

  @override
  String get collectBook => '取書';

  @override
  String get pointPickupQrCode => '請對準取書 QR Code';

  @override
  String get holdSteady => '請保持裝置穩定';

  @override
  String get bookCollected => '取書完成';

  @override
  String collected(Object p0) => '《${p0}》已完成取書';

  @override
  String order2(Object p0) => '訂單編號：${p0}';

  @override
  String get signingOut => '登出中…';

  @override
  String get myAccount => '會員中心';

  @override
  String get personNotWrittenBioYet => '尚未填寫個人簡介';

  @override
  String get topTierReached => '已達最高等級';

  @override
  String morePointsReach(Object p0, Object p1) => '再 ${p0} 點升級為「${p1}」';

  @override
  String get purchases => '購買紀錄';

  @override
  String get sales => '銷售紀錄';

  @override
  String get settings => '設定';

  @override
  String get signOut2 => '確認登出';

  @override
  String cancelOrderBookReturnsShop(Object p0) => '確定要取消訂單 ${p0} 嗎？取消後書籍將重新於商城販售。';

  @override
  String get iCollected => '確認取書';

  @override
  String get noOrdersTab => '此分類目前沒有訂單';

  @override
  String get openDispute => '申請爭議';

  @override
  String get displayNameNeedsLeast2Characters => '暱稱至少 2 個字元';

  @override
  String get displayNameLimited50Characters => '暱稱不可超過 50 個字元';

  @override
  String get enterPasswordAgain => '請再次輸入密碼';

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
  String get joinSavemybook => '註冊帳號';

  @override
  String get displayName => '暱稱';

  @override
  String get emailSignWith => '電子郵件';

  @override
  String get least8CharactersWithLettersNumbers => '至少 8 碼，需含英文與數字';

  @override
  String get confirmPassword => '確認密碼';

  @override
  String get enterPasswordAgain2 => '請再次輸入密碼';

  @override
  String get alreadyAccountGoBackSign => '已有帳號？返回登入';

  @override
  String get markAsDroppedOff => '完成存書';

  @override
  String get droppedOff => '已放入書櫃';

  @override
  String get markedAsDroppedOff => '已標記為完成存書';

  @override
  String get buyerNotifiedBookReturnsShop => '取消後將通知買家，書籍將重新於商城販售。';

  @override
  String get noRecentSearches => '尚無搜尋紀錄';

  @override
  String get recentSearches => '最近搜尋';

  @override
  String get clearAll2 => '清除全部';

  @override
  String get searchTitleAuthorIsbn => '搜尋書名、作者或 ISBN';

  @override
  String get photoLimitReached => '照片已滿';

  @override
  String get canUploadUp10Photos => '最多可上傳 10 張照片。';

  @override
  String get photosMissing => '照片不足';

  @override
  String missingTheseThreeRequired2(Object p0) => '尚缺：${p0}。以上三張為必填。';

  @override
  String get missingInformation => '資料不齊全';

  @override
  String get enterOwnPrice => '請輸入自訂價格。';

  @override
  String get invalidPrice => '價格不正確';

  @override
  String get priceMustGreaterThan02 => '售價必須大於 0。';

  @override
  String get priceCannotExceed99999 => '售價不可超過 99,999 代幣。';

  @override
  String get chooseLockerLocation2 => '請選擇存放區域。';

  @override
  String get listed2 => '上架成功';

  @override
  String get unknownError => '未知錯誤';

  @override
  String get couldNotListBook => '上架失敗';

  @override
  String get listBook => '確認上架';

  @override
  String get detailsPhotos => '詳細資訊與照片';

  @override
  String get loading => '載入中…';

  @override
  String get unknownLocker => '未知書櫃';

  @override
  String get enterTitle2 => '請輸入書名';

  @override
  String get chooseCategory2 => '請選擇分類';

  @override
  String get bookDetailsFilledAutomatically => '已自動帶入書籍資訊';

  @override
  String get noSourceIsbnPleaseEnterDetails => '查無此 ISBN 的書籍資訊，請手動輸入';

  @override
  String get day => '日';

  @override
  String get tapIconRightScan => '請輸入 ISBN';

  @override
  String get description => '書籍簡介';

  @override
  String get sellBook => '上架書籍';

  @override
  String get myShop => '我的賣場';

  @override
  String get sellerNoBooksSale => '此賣家目前沒有販售中的書籍';

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
  String get aboutSavemybook => '關於救「舊」我的書';

  @override
  String sign3(Object p0) => '${p0} 登入';

  @override
  String get scanProfileQrCode => '掃描個人 QR Code';

  @override
  String get lineUpTheirQrCodeWith => '將對方的 QR Code 放入框內';

  @override
  String get notSavemybookProfileQrCode => '此 QR Code 並非救「舊」我的書的個人 QR Code';

  @override
  String get ownQrCode => '這是您的個人 QR Code';

  @override
  String get couldNotStartChatPleaseTry => '無法建立聊天室，請稍後再試';

  @override
  String get linkCopied => '已複製連結';

  @override
  String addMeSavemybook(Object p0) => '我的救「舊」我的書個人檔案：${p0}';

  @override
  String addMeSavemybook2(Object p0, Object p1) => '${p0} 的救「舊」我的書個人檔案：${p1}';

  @override
  String get sharingCouldNotOpenSoLink => '無法開啟分享，已複製連結';

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
  String get noEnquiriesYet => '尚無提問紀錄';

  @override
  String get enterSubject => '請填寫主旨';

  @override
  String get addMoreDetailSoSupportCan => '請補充問題描述';

  @override
  String get sentSupportReplySoon => '已送出，客服將盡快回覆';

  @override
  String get subject => '主旨';

  @override
  String get sumUpOneLine => '簡述問題';

  @override
  String get whatHappenedIncludeOrderNumberIf => '請描述問題，如有訂單編號請一併提供';

  @override
  String get close => '結案';

  @override
  String get notAbleReplyAfterClosing => '結案後將無法再回覆。';

  @override
  String get enquiryClosed => '問題已結案';

  @override
  String get changeStatus => '變更狀態';

  @override
  String get statusUpdated => '已更新狀態';

  @override
  String get enquiry => '提問紀錄';

  @override
  String get enquiryNotFound => '找不到此提問';

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
  String hold(Object p0) => '凍結中 \$${p0}';

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
  String get couldNotLoadPhoto => '無法載入此照片';

  @override
  String slot2(Object p0) => '櫃位：${p0}';

  @override
  String confirmPutLocker(Object p0) => '確認已將《${p0}》放入書櫃？';

  @override
  String get enterTitleContent => '請填寫標題與內容';

  @override
  String get titleCannotExceed255Characters => '標題不可超過 255 個字元';

  @override
  String get contentNeedsLeast5Characters => '內容至少 5 個字元';

  @override
  String get publishAnnouncement => '發布公告';

  @override
  String get everyUserSeeAnnouncementOncePublished => '發布後全體使用者皆可看到此公告，確定要發布嗎？';

  @override
  String get publish => '發布';

  @override
  String get announcementPublished => '公告已發布';

  @override
  String get draftSaved => '草稿已儲存';

  @override
  String get editAnnouncement => '編輯公告';

  @override
  String get newAnnouncement => '新增公告';

  @override
  String get title2 => '標題';

  @override
  String get announcementTitle => '公告標題';

  @override
  String get writeAnnouncement => '輸入公告內容';

  @override
  String get publishNow => '立即發布';

  @override
  String get leaveOffSaveAsDraft => '關閉時僅儲存為草稿';

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
  String get noAnnouncementsYetTapAddOne => '尚無公告';

  @override
  String get published => '已發布';

  @override
  String get draft => '草稿';

  @override
  String get audienceEveryone => '對象：全體使用者';

  @override
  String get backUpNow => '立即備份';

  @override
  String get wholeDatabaseExportedCompressedWithLot => '將匯出整個資料庫並壓縮保存。資料量大時可能需要數十秒，期間請勿離開此畫面。';

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
  String get olderBackupsBeyondCountRemovedAutomatically => '超出份數的舊備份將自動清除。備份檔含全站個人資料，下載後請妥善保管，每次下載皆會記錄於操作紀錄。';

  @override
  String get noBackupsYetSchedulerRunsOnce => '尚無備份紀錄';

  @override
  String get deleteBackup => '刪除備份';

  @override
  String p0NNtheFileItsRecord(Object p0) => '${p0}\n\n檔案與紀錄將一併移除，此操作無法復原。';

  @override
  String get manual => '手動';

  @override
  String get scheduled => '排程';

  @override
  String get download => '下載';

  @override
  String get downloadBackup => '下載備份';

  @override
  String get copyLink2 => '複製網址';

  @override
  String get downloadLinkCopied => '已複製下載網址';

  @override
  String get forceDelist => '強制下架';

  @override
  String get reasonDelistingSellerNotified => '下架原因（將通知賣家）';

  @override
  String get delist3 => '確認下架';

  @override
  String get relist2 => '恢復上架';

  @override
  String putP0BackStore(Object p0) => '確定要將《${p0}》恢復上架嗎？';

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
  String onceDisabledP0NoLongerAppears(Object p0) => '停用後「${p0}」將不再顯示於賣家的存放區域選單。';

  @override
  String onceEnabledP0AvailableSellersAgain(Object p0) => '啟用後「${p0}」將重新開放賣家選擇。';

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
  String deleteP0CannotUndone2(Object p0) => '確定要刪除「${p0}」嗎？此操作無法復原。';

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
  String get contentsSectionRemovedWith => '此章節內容將一併移除。';

  @override
  String p0ItsContentsRemoved(Object p0) => '「${p0}」及其內容將一併移除。';

  @override
  String get discardChanges => '捨棄變更？';

  @override
  String get documentUnsavedChangesTheyLostIf => '此文件有尚未儲存的變更，離開後將遺失。';

  @override
  String get discard => '捨棄';

  @override
  String get keepEditing => '繼續編輯';

  @override
  String sectionP0NoTitleYet(Object p0) => '第 ${p0} 章尚未填寫標題';

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
  String get unnumberedOpeningTextLeaveEmptyIf => '開頭不編號的說明文字，若無可留空。';

  @override
  String get articles => '條文';

  @override
  String get noArticlesYetAddFirstOne => '尚無條文';

  @override
  String get addSection => '新增章節';

  @override
  String get untitledSection => '未命名章節';

  @override
  String get sectionTitle => '章節標題';

  @override
  String get bodySectionSingleLineBreaksKept => '章節內容。單行換行將如實呈現，空一行代表另起一段。';

  @override
  String get howUsersSee => '使用者檢視畫面';

  @override
  String get noContentYet => '尚無內容';

  @override
  String get unsaved => '尚未儲存';

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
  String get bothQuestionAnswerRequired => '請填寫問題與答案';

  @override
  String get added => '已新增';

  @override
  String get updated => '已更新';

  @override
  String get deleteQuestion => '刪除問題';

  @override
  String deleteP0(Object p0) => '確定要刪除「${p0}」嗎？';

  @override
  String get deleted => '已刪除';

  @override
  String get faq => '常見問題';

  @override
  String get noQuestionsYet2 => '尚無常見問題';

  @override
  String get hidden => '已隱藏';

  @override
  String get cancelDeletionRequest => '取消刪除申請';

  @override
  String p0SAccountReturnsNormalCountdown(Object p0) => '${p0} 的帳號將恢復正常，並停止刪除程序。';

  @override
  String get cancelDeletion => '取消刪除';

  @override
  String get deletionRequestCancelled => '已取消該會員的刪除申請';

  @override
  String get anonymiseNow => '立即執行匿名化';

  @override
  String eraseP0SPersonalDataDisable(Object p0) => '不待緩衝期結束，立即清除 ${p0} 的個人資料並停用帳號。\n\n訂單與交易紀錄將予以保留，暱稱將顯示為「已刪除的使用者」。此操作無法復原。';

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
  String p0DaysLeft(Object p0) => '剩餘 ${p0} 天';

  @override
  String requestedP0ScheduledP1(Object p0, Object p1) => '申請於 ${p0}，預計 ${p1} 執行';

  @override
  String get disputeResolution => '交易仲裁';

  @override
  String orderP0P1(Object p0, Object p1) => '訂單 ${p0}｜\$${p1}';

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
  String get listings => '商品管理';

  @override
  String get moderation => '內容審核';

  @override
  String get handleListingReports => '商品檢舉處理';

  @override
  String get members => '會員管理';

  @override
  String get memberControls => '會員管控';

  @override
  String get membershipTiers => '會員等級管理';

  @override
  String get wallets => '錢包管理';

  @override
  String get hardwareOperations => '硬體與營運';

  @override
  String get maintenanceLog => '維修紀錄';

  @override
  String get reports => '營運報表';

  @override
  String get ordersRevenueMemberGrowth => '訂單、營收與會員成長';

  @override
  String get supportEnquiries => '客服工單';

  @override
  String get adminAuditLog => '管理操作紀錄';

  @override
  String get systemOperations => '系統維運';

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
  String get maximumPointsLeaveEmptyNoCap => '最高點數（留空表示無上限）';

  @override
  String get benefitsSeparatedByCommasLineBreaks => '權益（以頓號或換行分隔，將於會員等級頁逐條顯示）';

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
  String deleteP0MembersTierDropNext(Object p0) => '確定要刪除「${p0}」嗎？此等級的會員將調整至下一個符合的等級。';

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
  String p0SignedOutImmediatelyCanNo(Object p0) => '${p0} 將立即被登出，且無法使用 App 的任何功能。';

  @override
  String p0AbleSignAgain(Object p0) => '${p0} 將可重新登入使用。';

  @override
  String get accountStatusUpdated => '已更新帳號狀態';

  @override
  String get removeAdmin => '取消管理員';

  @override
  String get makeAdmin => '設為管理員';

  @override
  String p0LosesEveryAdminPermissionImmediately(Object p0) => '${p0} 將立即失去所有後台權限。';

  @override
  String p0GainsAccessAdminAreaWith(Object p0) => '${p0} 將可進入管理後台，預設擁有全部權限，並可逐項調整。';

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
  String p0AbleUseEveryAdminFeature(Object p0) => '${p0} 將可使用後台所有功能。';

  @override
  String p0ReachAdminAreaButUnable(Object p0) => '${p0} 進入後台後將無法使用任何功能。';

  @override
  String get allPermissionsGranted => '已開放全部權限';

  @override
  String get allPermissionsRevoked => '已收回全部權限';

  @override
  String get memberSettings => '會員設定';

  @override
  String get noDataMember => '找不到此會員的資料';

  @override
  String get listings2 => '上架書籍';

  @override
  String get completedTrades => '完成交易';

  @override
  String get joined => '加入日期';

  @override
  String get accountStatus => '帳號狀態';

  @override
  String get ownAccountStatusPermissionsCannotChanged => '此為您本人的帳號，無法於此調整狀態與權限。';

  @override
  String get accountEnabled => '啟用帳號';

  @override
  String get canSignUseAppNormally => '可正常登入使用';

  @override
  String get suspendedSignedOutImmediatelyAfterSigning => '已停權，登入後將立即登出';

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
  String get memberSTierBeenAdjustedBy => '此會員的等級經人工調整，不完全依交易自動計算。';

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
  String get searchDisplayNameEmail => '搜尋暱稱或電子郵件';

  @override
  String get noMembersMatch => '找不到符合條件的會員';

  @override
  String get sales2 => '銷售';

  @override
  String get created => '建立日期';

  @override
  String get noActivityYet => '尚無操作紀錄';

  @override
  String get changeOrderStatus => '調整訂單狀態';

  @override
  String orderP0(Object p0) => '訂單 ${p0}';

  @override
  String get reasonChange => '調整說明';

  @override
  String get sentBuyerAsWellOptional => '將一併通知買家（選填）';

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
  String get member2 => '此會員';

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
  String get orderPlaced => '成立訂單';

  @override
  String get paid => '付款';

  @override
  String get sellerDroppedOff => '賣家存書';

  @override
  String get buyerCollected => '買家取書';

  @override
  String get completed => '完成';

  @override
  String get editBookDetails => '編輯書籍資料';

  @override
  String sellerP0TheyNotifiedSave(Object p0) => '賣家 ${p0}・儲存後將通知賣家';

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
  String p0SCurrentPasswordStopsWorking(Object p0) => '${p0} 目前的密碼將立即失效，須改用系統產生的臨時密碼登入。\n\n臨時密碼由系統產生，無法自行指定。';

  @override
  String get generateTemporaryPassword => '產生臨時密碼';

  @override
  String get temporaryPassword => '臨時密碼';

  @override
  String p0SPasswordBeenResetPassword(Object p0) => '${p0} 的密碼已重設。此密碼僅顯示一次，關閉後將無法再查看。';

  @override
  String get remindThemChangeSettingsChangePassword => '請提醒對方登入後立即至「設定 › 更改密碼」變更密碼。';

  @override
  String get temporaryPasswordCopied => '已複製臨時密碼';

  @override
  String get copy => '複製';

  @override
  String get cannotResetAnotherAdminSPassword => '無法重設其他管理員的密碼';

  @override
  String get generateTemporaryPasswordHandOver => '產生一組臨時密碼交給使用者';

  @override
  String get orderNumberCopied => '已複製訂單編號';

  @override
  String get orderNotFound => '找不到此訂單';

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
  String get changeOwnPasswordGoSettingsChange => '如需變更本人密碼，請至「設定 › 更改密碼」';

  @override
  String get memberNotAdminSoThereNo => '此會員非管理員，無後台權限可設定。請先於上方將身分設為管理員。';

  @override
  String get you => '本人';

  @override
  String isbnMust1013DigitsOne(Object p0) => 'ISBN 應為 10 或 13 碼，目前為 ${p0} 碼';

  @override
  String get screenUnsavedChangesTheyLostIf => '此畫面有尚未儲存的變更，離開後將遺失。';

  @override
  String stillNeededP0(Object p0) => '尚缺：${p0}';

  @override
  String photosP0(Object p0) => '照片：${p0} 張';

  @override
  String get confirmListing => '確認上架';

  @override
  String get lookingUpBook => '正在查詢書籍資料';

  @override
  String get scan => '掃描';

  @override
  String get buyerSPaymentGoesBackTheir => '買家支付的款項將退回錢包；若賣家已收到貨款，將先行收回。';

  @override
  String get orderReturnsWhereWasBeforeDispute => '訂單將恢復至申訴前的狀態並繼續交易；若先前已完成取書，貨款將撥付給賣家。';

  @override
  String get orderWasAlreadyRefundedBuyerCannot => '此訂單款項已退回買家，無法改回進行中或已完成';

  @override
  String get completedOrderCanOnlyChangedRefund => '已完成的訂單只能改為「退款處理中」或「已退款」';

  @override
  String confirmingPaysP0TokensSellerMarks(Object p0) => '確認後將撥付 ${p0} 代幣給賣家，並將書籍標記為已售出。';

  @override
  String confirmingTakesP0TokensBackFrom(Object p0) => '確認後將向賣家收回 ${p0} 代幣並退還買家。賣家餘額不足時將顯示為負數。';

  @override
  String get ifBuyerNotBeenRefundedYet => '若先前尚未退款，將補退給買家。';

  @override
  String confirmingRefundsBuyerSP0Tokens(Object p0) => '確認後將退還買家支付的 ${p0} 代幣，保留中的書籍將重新上架。';

  @override
  String get donTPermissionYourselfSoCan => '您未擁有此權限，無法授予他人。';

  @override
  String get notificationsTurnedOff => '通知權限已關閉';

  @override
  String get openSettings => '前往設定';

  @override
  String get sendTestNotification => '傳送測試通知';

  @override
  String get arrives10SecondsGoHomeScreen => '將於 10 秒後送達，送出後請返回主畫面或鎖定手機';

  @override
  String get systemNotificationSettings => '系統通知設定';

  @override
  String get pushNotificationsNotSetUpBuild => '此版本的 App 尚未設定推播，請加入 Firebase 設定檔後重新編譯。';

  @override
  String get notificationsTurnedOffAllowAppSend => '通知權限已關閉，請至系統設定允許此 App 傳送通知。';

  @override
  String get restoreBackup => '確定要還原至此備份？';

  @override
  String wholeDatabaseGoBackP0Orders(Object p0) => '整個資料庫將還原至 ${p0} 的狀態，此時間點之後的訂單、訊息、會員資料與操作紀錄將全部清除。\n\n還原前系統將自動備份目前狀態，如有需要可再還原該備份。還原期間全站暫停服務，通常需要數十秒至數分鐘。\n\n請輸入您的登入密碼以確認：';

  @override
  String get password2 => '登入密碼';

  @override
  String get startRestore => '開始還原';

  @override
  String get backingUpCurrentState => '正在備份目前狀態…';

  @override
  String databaseRestoredPreviousStateWasBacked(Object p0) => '資料庫已還原。還原前的狀態已備份至 ${p0}';

  @override
  String restoreFailedDatabaseMayUnchangedPartly(Object p0) => '還原失敗，資料庫可能維持原狀或已部分還原，請查看操作紀錄並視需要還原 ${p0}';

  @override
  String get autoBackupBeforeRestore => '還原前自動備份';

  @override
  String get restoreBackup2 => '還原至此備份';

  @override
  String get restoringDatabase => '正在還原資料庫';

  @override
  String p0SecondsSoFarKeepApp(Object p0) => '已經過 ${p0} 秒。請勿關閉 App，完成後將自動恢復服務。';

  @override
  String get majorUpdate2 => '重大更新';

  @override
  String get minorEdit => '小幅修改';

  @override
  String get books => '書籍';

  @override
  String get orders2 => '訂單';

  @override
  String get wallets2 => '錢包';

  @override
  String get announcements3 => '公告';

  @override
  String get legal => '條款';

  @override
  String get backups => '備份';

  @override
  String get undoAction => '確定要還原此操作？';

  @override
  String p0NNtheDataGoesBack(Object p0) => '「${p0}」\n\n資料將恢復至操作前的狀態。已送出的通知不會收回；若資料之後曾再次修改，系統將拒絕還原。';

  @override
  String get undo => '還原';

  @override
  String get undone => '已還原';

  @override
  String get searchActionsEGNicknameBook => '搜尋操作內容，例如會員暱稱或書名';

  @override
  String viewP0Changes(Object p0) => '查看 ${p0} 項變更';

  @override
  String get undoAction2 => '還原此操作';

  @override
  String get noAnnouncements => '目前沒有公告';

  @override
  String get canTContinueWithoutAccepting => '未同意將無法繼續使用';

  @override
  String needAcceptLatestP0UseP1(Object p0) => '不同意「${p0}」將登出帳號。';

  @override
  String get goBack => '返回';

  @override
  String p0BeenUpdated(Object p0) => '「${p0}」已更新';

  @override
  String readLatestVersionUpdatedP0Accept(Object p0) => '${p0} 更新';

  @override
  String get scrollEndContinue => '請捲動至底部閱讀全文';

  @override
  String get iVeReadAccept => '我已閱讀並同意';

  @override
  String get decline => '不同意';

  @override
  String get viewDetails => '查看詳情';

  @override
  String get notFoundMayBeenDeletedRemoved => '此內容已不存在';

  @override
  String get chatMessages => '聊天訊息';

  @override
  String get promotions2 => '優惠活動';

  @override
  String get supportRepliesPasswordResetsPolicyUpdates => '客服回覆、帳號安全與系統公告通知無法關閉。';

  @override
  String get notFilled => '未填寫';

  @override
  String get canTChanged => '無法修改';

  @override
  String get voice => '[語音]';

  @override
  String get reservation => '預約';

  @override
  String get messageUnsent => '訊息已收回';

  @override
  String get confirmBeforeExportingData => '匯出個人資料前，請先驗證身分';

  @override
  String get exportFailedPleaseTryAgainLater => '匯出失敗，請稍後再試';

  @override
  String get refresh => '重新整理';

  @override
  String get clearFilters => '清除篩選';

  @override
  String get expired => '已過期';

  @override
  String get verificationCancelled => '已取消驗證';

  @override
  String get openingClosingTimesCanTSame => '開放與關閉時間不可相同';

  @override
  String slotCurrentlyP0MayOrderProgress(Object p0, Object p1) => '此櫃位目前為「${p0}」，可能有進行中的訂單。變更為「${p1}」後，買賣雙方可能無法正常存取書籍。';

  @override
  String get active => '啟用中';

  @override
  String get categoryWithNameAlreadyExists => '已有同名分類';

  @override
  String orderP0ClosedAsP1P2(Object p0, Object p1, Object p2) => '訂單 ${p0} 將以「${p1}」結案，${p2} 代幣將退回買家。送出後無法修改。';

  @override
  String orderP0ClosedAsP1Can(Object p0, Object p1) => '訂單 ${p0} 將以「${p1}」結案。送出後無法修改。';

  @override
  String get clearSearch => '清除搜尋';

  @override
  String get enterMinimumPoints => '請輸入最低點數';

  @override
  String pointsRangeOverlapsWithP0P1(Object p0, Object p1) => '點數範圍與「${p0}」（${p1}）重疊';

  @override
  String noTierCoversP0P1Points(Object p0, Object p1) => '${p0}–${p1} 點沒有對應的等級';

  @override
  String p0TakenDownRightAwayOther(Object p0) => '「${p0}」將立即下架，其他會員將無法瀏覽或購買。';

  @override
  String get searchReportedItemReporterReason => '搜尋被檢舉項目、檢舉人或原因';

  @override
  String get couldnTLoadStatisticsRightNow => '暫時無法取得統計資料';

  @override
  String get searchSubjectMemberMessage => '搜尋主旨、會員或訊息內容';

  @override
  String get balance3 => '有餘額';

  @override
  String get hold3 => '有凍結金額';

  @override
  String get zeroBalance => '餘額為 0';

  @override
  String get amountCanMost2DecimalPlaces => '金額最多可至小數點後兩位';

  @override
  String get singleAdjustmentCanTExceed1 => '單次調整不可超過 1,000,000';

  @override
  String wouldMakeBalanceNegativeCurrentBalance(Object p0) => '扣除後餘額將為負數，目前餘額 ${p0}';

  @override
  String get amountUp2Decimals => '金額（最多兩位小數）';

  @override
  String p0NbalanceAfterP1(Object p0, Object p1) => '${p0}\n調整後餘額 ${p1}';

  @override
  String get cameraAccessOff => '無法使用相機';

  @override
  String get couldNotStartCamera => '相機啟動失敗';

  @override
  String allowP0UseCameraSettingsThen(Object p0) => '請至系統設定允許 ${p0} 使用相機後再試。';

  @override
  String get closeScreenTryAgain => '請關閉此畫面後再試。';

  @override
  String get couldnTGetLocationCheckLocation => '無法取得目前位置，請確認已開啟定位服務與權限';

  @override
  String get bookReservedAnotherBuyerCanT => '此書籍已由其他買家預約，暫時無法加入購物車';

  @override
  String reservedAnotherBuyerUntilP0(Object p0) => '已由其他買家預約，保留至 ${p0}';

  @override
  String sellerHoldingUntilP0(Object p0) => '賣家已為您保留至 ${p0}';

  @override
  String get checkOutBeforeHoldEndsOther => '請於保留期限內完成結帳';

  @override
  String get copyAddress => '複製地址';

  @override
  String p0Away(Object p0) => '距離 ${p0}';

  @override
  String get locating => '定位中…';

  @override
  String get showDistance => '查看距離';

  @override
  String get reserved => '已預約';

  @override
  String get goCheckout => '前往結帳';

  @override
  String get cart2 => '已在購物車';

  @override
  String get buyNow => '立即購買';

  @override
  String p0Delisted(Object p0) => '《${p0}》已下架';

  @override
  String noBooksMatchP0(Object p0) => '找不到符合「${p0}」的書籍';

  @override
  String p0BooksP1Views(Object p0, Object p1) => '共 ${p0} 本 · 總瀏覽 ${p1} 次';

  @override
  String get searchTitleAuthorIsbn2 => '搜尋書名、作者或 ISBN';

  @override
  String removedP0(Object p0) => '已移除《${p0}》';

  @override
  String removedP0Items(Object p0) => '已移除 ${p0} 件商品';

  @override
  String get paymentSuccessful => '付款成功';

  @override
  String p0BooksSplitIntoP1Orders(Object p0, Object p1) => '共 ${p0} 本書，已依賣家拆分為 ${p1} 筆訂單';

  @override
  String get keepBrowsing => '繼續瀏覽';

  @override
  String get reload => '重新載入';

  @override
  String get browseBooks => '瀏覽書籍';

  @override
  String p0Sellers(Object p0) => '${p0} 位賣家';

  @override
  String unavailableP0(Object p0) => '無法購買（${p0}）';

  @override
  String get removeAll => '全部移除';

  @override
  String get goWallet => '前往錢包';

  @override
  String fromP0SellersCheckoutCreatesP1(Object p0, Object p1) => '來自 ${p0} 位賣家，結帳後將拆分為 ${p1} 筆訂單';

  @override
  String get otherDevicesNeedSignAgainWith => '其他裝置須使用新密碼重新登入。';

  @override
  String get searchChats => '搜尋聊天對象';

  @override
  String get noMatchingChats => '找不到符合的聊天對象';

  @override
  String get read => '已讀';

  @override
  String get chatNotFound => '找不到此聊天室';

  @override
  String get messagesCanUp2000Characters => '訊息最多 2000 字';

  @override
  String get canTSendRightNowPlease => '目前無法傳送，請稍後再試';

  @override
  String get reserveBook => '預約書籍';

  @override
  String get quickReplies => '快速回覆';

  @override
  String get imagesMust10MbSmaller => '圖片不可超過 10 MB';

  @override
  String get recordingFailedPleaseTryAgain => '錄音失敗，請重試';

  @override
  String get voiceMessageTooLargePleaseRecord => '語音檔案過大，請縮短錄音時間';

  @override
  String get microphoneAllowedPressHoldAgainRecord => '已允許使用麥克風，請再次按住按鈕開始錄音';

  @override
  String get microphoneAccessNeededRecordTurnSettings => '錄音需要麥克風權限，請至系統設定開啟';

  @override
  String get couldnTStartRecordingPleaseTry => '無法開始錄音，請稍後再試';

  @override
  String get selectText => '選取文字';

  @override
  String get unsend => '收回';

  @override
  String get resend => '重新傳送';

  @override
  String get unsendMessage => '確定要收回此訊息？';

  @override
  String get neitherAbleSeeMessageSContent => '收回後雙方皆無法查看此訊息內容。';

  @override
  String get reportMessage => '檢舉此訊息';

  @override
  String get reservationSentWaitingSeller => '已送出預約，等待賣家回覆';

  @override
  String get acceptReservation => '確定要接受預約？';

  @override
  String p0HeldThemP1HoursNo(Object p0, Object p1) => '《${p0}》將為對方保留 ${p1} 小時，期間其他人無法購買。';

  @override
  String get accept => '接受';

  @override
  String get reservationAccepted => '已接受預約';

  @override
  String get declineReservation => '確定要婉拒預約？';

  @override
  String get decline2 => '婉拒';

  @override
  String get reservationDeclined => '已婉拒預約';

  @override
  String get cancelReservation => '確定要取消預約？';

  @override
  String p0NoLongerHeld(Object p0) => '取消後《${p0}》將不再保留。';

  @override
  String get cancelReservation2 => '取消預約';

  @override
  String get reservationCanceled => '已取消預約';

  @override
  String get notNow2 => '返回';

  @override
  String get couldnTLoadConversationPleaseTry => '無法載入對話，請稍後再試';

  @override
  String get accountCanTReceiveMessagesRight => '對方帳號目前無法接收訊息';

  @override
  String get holdMicTalkReleaseSend => '錄音時間過短';

  @override
  String get startConversation => '對話開始';

  @override
  String p0New(Object p0) => '${p0} 則新訊息';

  @override
  String get connectionUnstableMessagesCanTSent => '連線不穩定，暫時無法傳送訊息';

  @override
  String get retry => '重試';

  @override
  String get stillAvailable => '請問此書籍仍可購買嗎？';

  @override
  String get couldLowerPriceBit => '請問是否可議價？';

  @override
  String get whenCanPutLocker => '請問預計何時存入書櫃？';

  @override
  String get unsentMessage => '您已收回訊息';

  @override
  String get theyUnsentMessage => '對方已收回訊息';

  @override
  String get reservationDetailsArenTAvailableRight => '預約資訊暫時無法顯示';

  @override
  String get sending => '傳送中';

  @override
  String get couldNotUploadPhotosPleaseTry => '證據照片上傳失敗，請稍後再試';

  @override
  String get bookDetailsUpdatedButPhotosCouldn => '書籍資料已更新，但照片上傳失敗，請稍後再試';

  @override
  String get sNotIsbnBarcodeScanOne => '掃描到的條碼非 ISBN，請掃描書背上 978 或 979 開頭的條碼';

  @override
  String get couldnTLoadCategoriesTapRetry => '分類載入失敗，請點此重試';

  @override
  String removedP0FromSaved(Object p0) => '已取消收藏《${p0}》';

  @override
  String get recentlyViewedCleared => '已清除最近瀏覽';

  @override
  String clearP0(Object p0) => '清除（${p0}）';

  @override
  String get picked => '為您推薦';

  @override
  String get recentlyViewed => '最近瀏覽';

  @override
  String get clear => '清除';

  @override
  String get notificationDeleted => '已刪除通知';

  @override
  String get pleasePutBookAssignedLockerSoon => '請盡快將書籍存入指定書櫃';

  @override
  String get weLlLetKnowWhenSeller => '賣家存書後將通知您前往取書';

  @override
  String get waitingBuyerCollect => '等待買家至書櫃取書';

  @override
  String get transactionCompleteThank => '交易完成';

  @override
  String get confirmVeTakenBookFromLocker => '請確認已從書櫃取出書籍。確認書況無誤後，請於購買紀錄完成訂單。';

  @override
  String p0Orders2(Object p0) => '共 ${p0} 筆訂單';

  @override
  String p0ReadyPickup(Object p0) => '可取書 ${p0} 筆';

  @override
  String get pickUp => '待取書';

  @override
  String get saved => '收藏';

  @override
  String get accountSecurity => '帳號安全';

  @override
  String get searchHistoryCleared => '已清除搜尋紀錄';

  @override
  String get trendingBooks => '熱門書籍';

  @override
  String get signOutDevice => '確定要登出此裝置？';

  @override
  String signOutP0(Object p0) => '確定要登出「${p0}」？';

  @override
  String get deviceSignedOutRightAwayStop => '該裝置將立即登出。';

  @override
  String get deviceSignedOut => '已登出裝置';

  @override
  String get signOutAllDevicesIncludingOne => '登出所有裝置（含本機）';

  @override
  String get signOutAllOtherDevices => '登出其他所有裝置';

  @override
  String get everyDeviceIncludingOneSignedOut => '包含本機在內的所有裝置將立即登出。';

  @override
  String get everyDeviceExceptOneSignedOut => '除本機外的所有裝置將立即登出。';

  @override
  String signedOutP0OtherDevices(Object p0) => '已登出其他 ${p0} 台裝置';

  @override
  String get unknownDevice => '未知裝置';

  @override
  String get couldnTLoadDevices => '無法載入登入裝置';

  @override
  String get device => '本機';

  @override
  String get otherDevices => '其他裝置';

  @override
  String otherDevicesP0(Object p0) => '其他裝置（${p0}）';

  @override
  String get noOtherDevicesSigned => '沒有其他裝置登入您的帳號';

  @override
  String get signedDevices => '登入裝置';

  @override
  String get activeNow => '目前使用中';

  @override
  String lastActiveP0(Object p0) => '最後使用 ${p0}';

  @override
  String signedP0(Object p0) => '${p0} 登入';

  @override
  String get biometricPayment => '已啟用生物辨識付款';

  @override
  String get paymentPinMust6Digits => '交易密碼必須是 6 位數字';

  @override
  String get pinTooEasyGuessTryAnother => '交易密碼過於簡單，請重新設定';

  @override
  String get enterPasswordResetPaymentPin => '輸入登入密碼後即可重新設定交易密碼';

  @override
  String get confirmSBeforeSettingPaymentPin => '設定交易密碼前，請先驗證身分';

  @override
  String get pinsDonTMatchStartAgain => '兩次輸入的交易密碼不一致，請重新設定';

  @override
  String get paymentPinReset => '交易密碼已重新設定';

  @override
  String get paymentPinSet => '交易密碼已設定';

  @override
  String get verifyingIdentity => '正在確認身分…';

  @override
  String get enterAgainConfirm => '請再次輸入以確認';

  @override
  String get set6DigitPaymentPin => '設定 6 位數交易密碼';

  @override
  String get enterSamePinAgain => '請再次輸入相同密碼';

  @override
  String get avoidRepeatedSequentialPatternedDigits => '不可使用相同、連續或重複的數字';

  @override
  String get resetPaymentPin => '重設交易密碼';

  @override
  String get paymentPin => '交易密碼';

  @override
  String stepP02(Object p0) => '步驟 ${p0} / 2';

  @override
  String get setPaymentPinFirst => '請先設定交易密碼';

  @override
  String get setPaymentPinFirstSoFallback => '請先設定交易密碼，作為辨識失敗時的替代驗證方式';

  @override
  String get setUpNow => '立即設定';

  @override
  String get biometricPaymentTurnedOff => '已關閉生物辨識付款';

  @override
  String get verifyTurnBiometricPayment => '驗證以啟用生物辨識付款';

  @override
  String p0PaymentsTurned(Object p0) => '已啟用 ${p0} 付款';

  @override
  String get securitySettingsUnavailableRightNowMay => '無法載入帳號安全設定';

  @override
  String payWithP0(Object p0) => '使用 ${p0} 付款';

  @override
  String get accountWellProtected => '帳號安全狀態良好';

  @override
  String get accountCouldSafer => '帳號安全性有待加強';

  @override
  String get setPaymentPinTurnBiometricPayment => '尚未設定交易密碼';

  @override
  String tooManyAttemptsLockedUntilP0(Object p0) => '錯誤次數過多，已鎖定至 ${p0}';

  @override
  String get notSetRequiredBeforeCheckout => '尚未設定';

  @override
  String get change => '變更';

  @override
  String get forgotPaymentPin => '忘記交易密碼';

  @override
  String p0Devices(Object p0) => '${p0} 台';

  @override
  String get restoredUnfinishedListing => '已帶入上次未完成的內容';

  @override
  String get isbnSCheckDigitInvalidPlease => '此 ISBN 檢查碼不正確，請再次確認';

  @override
  String get draftSavedAutomatically => '已自動儲存草稿';

  @override
  String get continueUnfinishedListing => '繼續上次未完成的刊登';

  @override
  String clearedP0MbCache(Object p0) => '已清除 ${p0} MB 快取';

  @override
  String get cacheCleared => '快取已清除';

  @override
  String get storage => '儲存空間';

  @override
  String get clearCache => '清除快取';

  @override
  String get couldNotLoadNotificationSettings => '無法載入通知設定';

  @override
  String get month => '本月';

  @override
  String p0P1(Object p0, Object p1) => '${p0} 年 ${p1} 月';

  @override
  String get noIncomeYet => '尚無收入紀錄';

  @override
  String get noSpendingYet => '尚無支出紀錄';

  @override
  String get income => '收入';

  @override
  String get spending => '支出';

  @override
  String get totalIncome => '累計收入';

  @override
  String get totalSpending => '累計支出';

  @override
  String get item3 => '項目';

  @override
  String get details => '說明';

  @override
  String get balanceAfter => '交易後餘額';

  @override
  String get transactionId => '交易編號';

  @override
  String get sessionExpiredPleaseSignAgain => '登入已過期，請重新登入';

  @override
  String get serviceTemporarilyUnavailableTryAgainLater => '服務暫時無法使用，請稍後再試';

  @override
  String get uploadFailedTryAgainLater => '上傳失敗，請稍後再試';

  @override
  String get nearby => '附近';

  @override
  String p0M(Object p0) => '${p0} 公尺';

  @override
  String p0Km(Object p0) => '${p0} 公里';

  @override
  String get iphoneDidnTReceiveApnsToken => '裝置未取得 Apple 推播憑證（APNs token）。請確認 Xcode 的 Signing & Capabilities 已加入 Push Notifications，並使用同一個 Apple 開發者帳號重新安裝 App。';

  @override
  String get firebaseDidnTIssuePushToken => 'Firebase 未核發推播 token，請確認 GoogleService-Info.plist 與 App 的 Bundle ID 一致';

  @override
  String couldnTGetPushTokenP0(Object p0) => '取得推播 token 失敗：${p0}';

  @override
  String couldnTRegisterPushTokenWith(Object p0) => '推播 token 上傳伺服器失敗：${p0}';

  @override
  String get protectCoinsCheckoutRequires6Digit => '結帳前請先設定 6 位數交易密碼。';

  @override
  String confirmPaymentP0Coins(Object p0) => '確認付款 ${p0} 代幣';

  @override
  String get enterPasswordContinue => '請輸入登入密碼以繼續';

  @override
  String get verifyS => '驗證身分';

  @override
  String get amount => '付款金額';

  @override
  String p0Coins(Object p0) => '${p0} 代幣';

  @override
  String get enterPaymentPin => '輸入交易密碼';

  @override
  String get enterPaymentPinContinue => '請輸入交易密碼以繼續';

  @override
  String get paymentPinResetEnterAgain => '交易密碼已重新設定，請再次輸入';

  @override
  String get usePasswordInstead => '改用登入密碼';

  @override
  String get couldnTGetLocationLockersShown => '無法取得目前位置';

  @override
  String p0SlotsFree(Object p0) => '空櫃 ${p0} 格';

  @override
  String openP0(Object p0) => '開放 ${p0}';

  @override
  String get nearest => '最近';

  @override
  String get noFreeSlots => '目前沒有空櫃';

  @override
  String get turnLocationSortByDistance => '開啟定位可依距離排序';

  @override
  String get lockerNoFreeSlotsRightNow => '此書櫃目前沒有空櫃';

  @override
  String get turn => '開啟定位';

  @override
  String get noLockersAvailable => '目前沒有可用的書櫃';

  @override
  String get noMatchingOptions => '沒有符合的選項';

  @override
  String get undo2 => '復原';

  @override
  String copiedP0(Object p0) => '已複製「${p0}」';

  @override
  String get typing => '對方正在輸入…';

  @override
  String get today => '今天';

  @override
  String get yesterday => '昨天';

  @override
  String p0P12(Object p0, Object p1) => '${p0}月${p1}日';

  @override
  String p1P2P0(Object p0, Object p1, Object p2) => '${p0}年${p1}月${p2}日';

  @override
  String get releaseCancel => '放開以取消';

  @override
  String get awaitingReply => '待回覆';

  @override
  String heldUntilP0(Object p0) => '已保留至 ${p0}';

  @override
  String get declined2 => '已婉拒';

  @override
  String get closed => '已結束';

  @override
  String get theyWantReserveBook => '對方申請預約您的書籍';

  @override
  String get sentReservationRequest => '您已送出預約';

  @override
  String holdP0H(Object p0) => '保留 ${p0} 小時';

  @override
  String get holdPeriod => '保留時間';

  @override
  String get messageSellerOptional => '給賣家的留言（選填）';

  @override
  String get sendRequest => '送出預約';

  @override
  String p0Hours(Object p0) => '${p0} 小時';

  @override
  String p0P1DigitsEntered(Object p0, Object p1) => '已輸入 ${p0} / ${p1} 位';

  @override
  String get buildSProvisioningProfileDoesnT => '此安裝版本的簽署描述檔未包含推播權限。請於 Xcode 的 Runner › Signing & Capabilities 確認已加入 Push Notifications，並刪除 App 後重新安裝。';

  @override
  String get checkPhoneOnlinePushNotificationsAdded => '請確認裝置已連上網路，並於 Xcode 的 Runner › Signing & Capabilities 確認已加入 Push Notifications。';

  @override
  String iphoneFailedRegisterPushNotificationsWith(Object p0, Object p1) => 'iPhone 向 Apple 註冊推播失敗：${p0}\n${p1}';

  @override
  String get serverNotBeenUpdatedSupportFeature => '此功能暫時無法使用，請稍後再試';

  @override
  String get someFeaturesTemporarilyUnavailableWhileServer => '部分功能暫時無法使用';

  @override
  String serverRunningOutdatedApiRevisionP0(Object p0, Object p1) => '伺服器執行的 API 版本過舊（目前 ${p0}，App 需要 ${p1}）。請在伺服器更新程式碼並重新啟動 API。';

  @override
  String databaseMigrationsNotYetRunP0(Object p0) => '資料庫尚未執行：${p0}';

  @override
  String serverVersionP0(Object p0) => '伺服器目前版本：${p0}';

  @override
  String get runNpmRunVerifyApiDirectory => '在伺服器的 API 目錄執行 npm run verify 可檢查完整的部署狀態。';

  @override
  String get serverUpdateRequired => '伺服器需要更新';

  @override
  String versionP0(Object p0) => '第 ${p0} 版';

  @override
  String get requiresUserConsent => '須經使用者同意';

  @override
  String get unsavedDraft => '有未儲存的草稿';

  @override
  String get allBooks => '全部書籍';

  @override
  String get results => '篩選結果';

  @override
  String get sortBy => '排序方式';

  @override
  String get themeColour => '主題色';

  @override
  String get forestGreen => '森林綠';

  @override
  String get oceanBlue => '海洋藍';

  @override
  String get lavender => '薰衣草紫';

  @override
  String get terracotta => '赤陶橘';

  @override
  String get amber => '琥珀金';

  @override
  String get rose => '玫瑰粉';

  @override
  String get graphite => '石墨灰';

  @override
  String get mistBlue => '霧藍';

  @override
  String get draftRestored => '已還原草稿';

  @override
  String get convertSections => '轉換為章節模式';

  @override
  String get currentContentDoesNotFullyMatch => '目前內容無法完整對應章節格式。轉換後，章節編號將依序重新產生並統一為「1. 標題」格式，未能辨識為標題的段落將併入前言或上一章內文。\n\n若需保留原始格式，請繼續以純文字模式編輯並儲存。';

  @override
  String get convert => '轉換';

  @override
  String get keepPlainText => '維持純文字';

  @override
  String get noSectionHeadingsDetectedFullText => '未偵測到章節標題，全文已置於前言';

  @override
  String deletedP0(Object p0) => '已刪除「${p0}」';

  @override
  String get renameSection => '重新命名章節';

  @override
  String get editContent => '編輯內容';

  @override
  String get rename => '重新命名';

  @override
  String get addSectionBelow => '在下方新增章節';

  @override
  String get moveUp => '上移';

  @override
  String get moveDown => '下移';

  @override
  String get enterDocumentTitle => '請填寫文件標題';

  @override
  String get enterDocumentContent => '請填寫文件內容';

  @override
  String p0NowVersionP1(Object p0, Object p1) => '${p0}，目前為第 ${p1} 版';

  @override
  String versionP0P1(Object p0, Object p1) => '第 ${p0} 版・${p1}';

  @override
  String unsavedDraftFromP0Found(Object p0) => '發現 ${p0} 未儲存的草稿';

  @override
  String get documentWasUpdatedAfterDraftWas => '文件已於草稿建立後更新，還原後將以草稿內容取代目前內容。';

  @override
  String get discardDraft => '捨棄草稿';

  @override
  String get restoreDraft => '還原草稿';

  @override
  String get sectionTitleRequired => '尚未填寫章節標題';

  @override
  String get documentSFormatDoesNotFully => '此文件的格式無法完整對應章節結構，已以純文字模式開啟，以保留原始格式。';

  @override
  String get enterPasteFullTextHere => '請於此輸入或貼上全文。';

  @override
  String get noSectionHeadingsDetected => '未偵測到章節標題';

  @override
  String p0SectionsDetected(Object p0) => '已偵測到 ${p0} 個章節';

  @override
  String get paragraphWhoseFirstLine1Title => '段落首行為「1. 標題」、「一、標題」或「第一條 標題」時，視為章節標題。';

  @override
  String get sectionNumbersMustStart1Increase => '章節編號須自 1 起依序遞增；不符合者視為上一章的內文。';

  @override
  String get blankLineStartsNewParagraphSingle => '空一行代表分段，單行換行將如實呈現。';

  @override
  String get whenSwitchingSectionsAskedConfirmAny => '切換至章節模式時，若格式需要調整，將先提示確認。';

  @override
  String get howSectionHeadingsDetected => '章節標題判定方式';

  @override
  String get titleEdited => '標題已修改';

  @override
  String p0Added(Object p0) => '新增 ${p0} 章';

  @override
  String p0Removed(Object p0) => '刪除 ${p0} 章';

  @override
  String p0Edited(Object p0) => '修改 ${p0} 章';

  @override
  String get sectionsReordered => '章節順序已調整';

  @override
  String get preambleEdited => '前言已修改';

  @override
  String get contentEdited => '內容已修改';

  @override
  String p0Characters2(Object p0) => '字數 +${p0}';

  @override
  String p0Characters3(Object p0) => '字數 ${p0}';

  @override
  String get formattingAdjusted => '排版調整';

  @override
  String get createdAsVersion1 => '建立為第 1 版';

  @override
  String staysVersionP0(Object p0) => '維持第 ${p0} 版';

  @override
  String versionP0P12(Object p0, Object p1) => '第 ${p0} 版 → 第 ${p1} 版';

  @override
  String get substantiveChangesRightsObligationsTermsAll => '適用於權利義務或條款內容的實質變更。將通知所有使用者，使用者下次開啟 App 時須重新閱讀並同意。';

  @override
  String get substantiveContentChangesAllUsersNotified => '適用於內容的實質變更。將通知所有使用者。';

  @override
  String saveP0(Object p0) => '儲存「${p0}」';

  @override
  String get summaryChanges => '變更摘要';

  @override
  String get updateType => '更新方式';

  @override
  String get fixingTyposFormattingUsersNotNotified => '適用於修正錯字或調整排版。不通知使用者。';

  @override
  String get contentUnchangedTitleOnlyChangeCannot => '內容未變更，僅修改標題時無法列為重大更新。';

  @override
  String get notificationsSentImmediatelyAfterSubmittingCannot => '送出後將立即發送通知，此操作無法撤回。';

  @override
  String get publishNotify => '發布並通知';

  @override
  String sectionP0(Object p0) => '第 ${p0} 章';

  @override
  String get goSection => '跳至章節';

  @override
  String get sectionContent => '章節內容';

  @override
  String get previous => '上一章';

  @override
  String get next2 => '下一章';

  @override
  String get unableGenerateProfileQrCodeTry => '無法產生個人 QR Code，請稍後再試';

  @override
  String get myQrCode => '我的 QR Code';

  @override
  String get markAsRead => '標為已讀';

  @override
  String get unblock => '解除封鎖';

  @override
  String afterUnblockingP0CanSendMessages(Object p0) => '解除封鎖後，您與「${p0}」可再次互相傳送訊息。';

  @override
  String get userUnblocked => '已解除封鎖';

  @override
  String get unableLoadBlockedUsers => '無法載入封鎖名單';

  @override
  String get notBlockedAnyUsers => '目前沒有封鎖任何使用者';

  @override
  String get blockedUsers => '封鎖名單';

  @override
  String get blockUser => '封鎖使用者';

  @override
  String afterBlockP0NeitherCanSend(Object p0) => '封鎖「${p0}」後，雙方將無法互相傳送訊息。';

  @override
  String get block => '封鎖';

  @override
  String get userBlocked => '已封鎖此使用者';

  @override
  String get moreOptions => '更多選項';

  @override
  String get blockedUser => '您已封鎖此使用者';

  @override
  String get originalMessageNotFound => '找不到原訊息';

  @override
  String get you2 => '您';

  @override
  String get viewProfile => '查看個人檔案';

  @override
  String get reply => '回覆';

  @override
  String get bookLockerScanQrCodeLocker => '書籍已存入書櫃，請至書櫃掃描機台上的 QR Code 取書';

  @override
  String get originalMessageUnavailable => '原訊息已無法顯示';

  @override
  String get cancelReply => '取消回覆';

  @override
  String get unreadMessages => '以下為未讀訊息';

  @override
  String get selectChat => '請選擇聊天室';

  @override
  String get appPermissions => 'App 權限';

  @override
  String get noPermissionsRequiredDevice => '此裝置沒有需要授權的項目';

  @override
  String get allowAll => '全部允許';

  @override
  String get camera => '相機';

  @override
  String get photosRead => '相簿（讀取）';

  @override
  String get photosSave => '相簿（寫入／儲存）';

  @override
  String get microphone => '麥克風';

  @override
  String get location => '定位';

  @override
  String get orderUpdatesChatMessagesAnnouncements => '訂單進度、聊天訊息與公告';

  @override
  String get scanBarcodesTakeBookPhotos => '掃描條碼與拍攝書籍照片';

  @override
  String get chooseBookPhotosProfilePicturesChat => '選取書籍照片、大頭貼與聊天圖片';

  @override
  String get saveQrCodesPhotos => '將 QR Code 儲存至相簿';

  @override
  String get recordVoiceMessagesChats => '錄製聊天語音訊息';

  @override
  String get showNearestSmartLockersTheirDistance => '顯示最近的智慧書櫃與距離';

  @override
  String get quickSignPaymentConfirmation => '快速登入與確認付款';

  @override
  String get allowed => '已允許';

  @override
  String get limited => '部分允許';

  @override
  String get notAllowed => '未允許';

  @override
  String get restricted => '受系統限制';

  @override
  String get denied => '已拒絕';

  @override
  String get allow => '允許';

  @override
  String get homeRecommendations => '首頁推薦區塊';

  @override
  String get leaveGroup => '退出群組';

  @override
  String leaveP0(Object p0) => '確定要退出「${p0}」？';

  @override
  String get leave => '退出';

  @override
  String get leftGroup => '已退出群組';

  @override
  String get unpin => '取消釘選';

  @override
  String get pin => '釘選';

  @override
  String get you3 => '您';

  @override
  String get canOnlyEditMessagesSentWithin => '僅能編輯 15 分鐘內傳送的訊息';

  @override
  String p0UnsentMessage(Object p0) => '${p0} 已收回一則訊息';

  @override
  String readByP0(Object p0) => '已讀 ${p0}';

  @override
  String get transferDetailsUnavailable => '無法顯示轉帳資訊';

  @override
  String get couldNotCreateGroup => '無法建立群組';

  @override
  String get groupDetails => '群組資料';

  @override
  String get selectMembers => '選擇成員';

  @override
  String get groupName => '群組名稱';

  @override
  String membersP0(Object p0) => '成員 ${p0}';

  @override
  String get createGroup => '建立群組';

  @override
  String get inviteMembers => '邀請成員';

  @override
  String get invite => '邀請';

  @override
  String canSelectUpP0People(Object p0) => '最多可選擇 ${p0} 人';

  @override
  String get noChatsChooseFrom => '沒有可選擇的聊天對象';

  @override
  String get noMatchingPeople => '找不到符合的對象';

  @override
  String get searchByName => '搜尋名稱';

  @override
  String get chatPinned => '已釘選聊天室';

  @override
  String get unpinned => '已取消釘選';

  @override
  String get setNickname => '設定暱稱';

  @override
  String get onlyVisible => '僅自己可見';

  @override
  String get nicknameRemoved => '已移除暱稱';

  @override
  String get nicknameUpdated => '已更新暱稱';

  @override
  String get enterGroupName => '請輸入群組名稱';

  @override
  String get groupNameUpdated => '已更新群組名稱';

  @override
  String get groupPhotoUpdated => '已更新群組頭貼';

  @override
  String get groupReachedMemberLimit => '群組成員已達上限';

  @override
  String invitedP0Members(Object p0) => '已邀請 ${p0} 位成員';

  @override
  String get removeMember => '移除成員';

  @override
  String removeP0FromGroup(Object p0) => '確定要將「${p0}」移出群組？';

  @override
  String get memberRemoved => '已移除成員';

  @override
  String get chatSettings => '聊天室設定';

  @override
  String get muteNotifications => '靜音通知';

  @override
  String get pinChat => '釘選聊天室';

  @override
  String get me => '我';

  @override
  String requestedFromP0(Object p0) => '向 ${p0} 請款';

  @override
  String p0RequestedPaymentFrom(Object p0) => '${p0} 向您請款';

  @override
  String p0RequestedPaymentFromP1(Object p0, Object p1) => '${p0} 向 ${p1} 請款';

  @override
  String sentP0(Object p0) => '轉帳給 ${p0}';

  @override
  String p0SentCoins(Object p0) => '${p0} 轉帳給您';

  @override
  String p0SentCoinsP1(Object p0, Object p1) => '${p0} 轉帳給 ${p1}';

  @override
  String get expired2 => '已逾期';

  @override
  String get payNow => '立即付款';

  @override
  String get cancelRequest => '取消請款';

  @override
  String get request => '請款';

  @override
  String get transfer => '轉帳';

  @override
  String dueP0(Object p0) => '期限 ${p0}';

  @override
  String transferP0(Object p0) => '轉帳給 ${p0}';

  @override
  String sentP0CoinsP1(Object p0, Object p1) => '已轉帳 ${p0} 代幣給 ${p1}';

  @override
  String get confirmPayment => '確認付款';

  @override
  String payP0CoinsP1(Object p0, Object p1) => '支付 ${p0} 代幣給 ${p1}';

  @override
  String get declineRequest => '婉拒請款';

  @override
  String declineP1CoinRequestFromP0(Object p0, Object p1) => '婉拒 ${p0} 的 ${p1} 代幣請款';

  @override
  String cancelRequestP0P1Coins(Object p0, Object p1) => '取消向 ${p0} 請款 ${p1} 代幣';

  @override
  String payRequestFromP0(Object p0) => '支付 ${p0} 的請款';

  @override
  String get paymentCompleted => '已完成付款';

  @override
  String get requestDeclined => '已婉拒請款';

  @override
  String get requestCanceled => '已取消請款';

  @override
  String get selectPayer => '請選擇付款人';

  @override
  String get selectRecipient => '請選擇收款人';

  @override
  String get sendRequest2 => '送出請款';

  @override
  String get confirmTransfer => '確認轉帳';

  @override
  String get payer => '付款人';

  @override
  String get recipient => '收款人';

  @override
  String limitPerTransferP0Coins(Object p0) => '單筆上限 ${p0} 代幣';

  @override
  String insufficientBalanceP0Coins(Object p0) => '餘額不足（${p0} 代幣）';

  @override
  String balanceP0Coins(Object p0) => '餘額 ${p0} 代幣';

  @override
  String get noteOptional => '備註（選填）';

  @override
  String get editMessage => '編輯訊息';

  @override
  String get cancelEditing => '取消編輯';

  @override
  String get send => '傳送';

  @override
  String get switchKeyboard => '切換至鍵盤';

  @override
  String get voiceMessage => '語音訊息';

  @override
  String get edited => '已編輯';

  @override
  String get maximumRecordingLengthReached => '已達錄音上限';

  @override
  String get recordingTooShort => '錄音時間過短';

  @override
  String p0SRemaining(Object p0) => '剩餘 ${p0} 秒';

  @override
  String get releaseSend => '放開即可傳送';

  @override
  String get recording => '錄音中';

  @override
  String get tapHoldRecord => '點按或按住以錄音';

  @override
  String get stopRecording => '停止錄音';

  @override
  String get preview2 => '試聽';

  @override
  String get startRecording => '開始錄音';

  @override
  String get microphoneUnavailable => '無法使用麥克風';

  @override
  String get paymentRequest => '[請款]';

  @override
  String get transfer2 => '[轉帳]';

  @override
  String get transfer3 => '轉入';

  @override
  String get transferOut => '轉出';

  @override
  String get deleteBook => '刪除書籍';

  @override
  String p0PermanentlyDeletedCannotRestoredSeller(Object p0) => '《${p0}》將永久刪除且無法復原，賣家將收到通知。';

  @override
  String get reasonDeletionOptional => '刪除原因（選填）';

  @override
  String get bookDeleted2 => '已刪除書籍';

  @override
  String get rotate => '旋轉';

  @override
  String get mentioned => '[提及您]';

  @override
  String get saveImage => '儲存圖片';

  @override
  String get everyone => '所有人';

  @override
  String get mentionMembers => '提及成員';

  @override
  String get removeAdminRole => '解除管理員身分';

  @override
  String makeP0Admin(Object p0) => '確定要將 ${p0} 設為管理員？';

  @override
  String removeAdminRoleFromP0(Object p0) => '確定要解除 ${p0} 的管理員身分？';

  @override
  String get remove2 => '解除';

  @override
  String p0NowAdmin(Object p0) => '已將 ${p0} 設為管理員';

  @override
  String removedAdminRoleFromP0(Object p0) => '已解除 ${p0} 的管理員身分';

  @override
  String photosP02(Object p0) => '[${p0} 張圖片]';

  @override
  String get savedDownloads => '已儲存至「下載項目」';

  @override
  String get couldNotSaveImage => '無法儲存圖片';

  @override
  String savingImagesP0P1(Object p0, Object p1) => '正在儲存圖片 ${p0} / ${p1}';

  @override
  String get savingImage => '正在儲存圖片';

  @override
  String get passwordsCanOnlyContainEnglishLetters => '密碼僅可使用英文字母、數字及半形符號';

  @override
  String get aiSupport => 'AI 客服';

  @override
  String get howDoIListBook => '如何上架書籍？';

  @override
  String get howDoIPickUpFrom => '如何至書櫃取書？';

  @override
  String get howDoIRequestRefund => '如何申請退款？';

  @override
  String get howDoWalletCoinsWork => '代幣如何使用？';

  @override
  String get talkPerson => '轉接客服人員';

  @override
  String get supportRequestCreatedFromConversationOur => '將轉接客服人員，並提供目前的對話內容';

  @override
  String get transfer4 => '轉接';

  @override
  String get creatingSupportRequest => '正在轉接客服';

  @override
  String get transferredSupportTeam => '已轉接客服人員';

  @override
  String get newConversation => '開始新對話';

  @override
  String get currentConversationEnd => '目前的對話將會結束';

  @override
  String get copied2 => '已複製';

  @override
  String get howCanWeHelp => '請問有什麼需要協助的地方？';

  @override
  String get failedSend => '傳送失敗';

  @override
  String get ourSupportTeamCanHelpWith => '此問題建議由客服人員協助處理';

  @override
  String get contactSupport => '聯絡客服';

  @override
  String get typeQuestion => '輸入問題';

  @override
  String get aiFeatures => 'AI 功能';

  @override
  String get aiSettingsNotSavedChangesLost => 'AI 設定尚未儲存，離開後變更將不會保留';

  @override
  String get usage => '用量';

  @override
  String reviewP0(Object p0) => '審核 ${p0}';

  @override
  String get dailyCost => '每日費用';

  @override
  String get noCostPeriod => '此期間尚無費用';

  @override
  String get peakDay => '單日最高';

  @override
  String p0Requests(Object p0) => '${p0} 次請求';

  @override
  String get listingAssist => '上架輔助';

  @override
  String get recommendations => '推薦書籍';

  @override
  String get listingReview => '上架審核';

  @override
  String get connectionTest => '連線測試';

  @override
  String get today2 => '今日';

  @override
  String get k7Days => '7 天';

  @override
  String get k30Days => '30 天';

  @override
  String get notBookUnrelatedItem => '非書籍或無關商品';

  @override
  String get prohibitedPiratedContent => '違禁或盜版內容';

  @override
  String get adultContent => '成人內容';

  @override
  String get offPlatformDealContactInfo => '站外交易或聯絡資訊';

  @override
  String get misleadingDescription => '不實描述';

  @override
  String get unusualPrice => '價格異常';

  @override
  String get providerError => '服務商錯誤';

  @override
  String get timedOut => '逾時';

  @override
  String get noApiKey => '未設定金鑰';

  @override
  String get rateLimited => '頻率受限';

  @override
  String get invalidApiKey => '金鑰無效';

  @override
  String get invalidResponseFormat => '回應格式錯誤';

  @override
  String get rejectListing => '拒絕上架';

  @override
  String get noteOptionalSentSeller => '說明（選填，將通知賣家）';

  @override
  String get reject => '拒絕';

  @override
  String get listingApproved => '已核准上架';

  @override
  String get listingRejected => '已拒絕上架';

  @override
  String get noListingsAwaitingReview => '目前沒有待審核的上架';

  @override
  String get likelyViolation => '疑似違規';

  @override
  String get needsReview => '需人工確認';

  @override
  String get rejected => '已拒絕';

  @override
  String get approve => '核准上架';

  @override
  String get pleaseFixHighlightedFields => '請修正標示錯誤的欄位';

  @override
  String get aiSettingsSaved => 'AI 設定已儲存';

  @override
  String get invalidFormat => '格式不正確';

  @override
  String enter0P0(Object p0) => '請輸入 0 至 ${p0}';

  @override
  String get databaseNotBeenUpdatedAiYet => '資料庫尚未完成 AI 相關更新，設定儲存後暫時不會生效';

  @override
  String get defaultModel => '預設模型';

  @override
  String get features => '功能';

  @override
  String get on => '已啟用';

  @override
  String get noProviderApiKeysSetSo => '尚未設定任何服務商金鑰，AI 功能無法使用';

  @override
  String p0NoApiKeyCannotSelected(Object p0) => '${p0} 尚未設定金鑰，無法選用';

  @override
  String get input => '輸入';

  @override
  String get output => '輸出';

  @override
  String get per1mTokens => '每百萬 tokens';

  @override
  String get vision => '圖片辨識';

  @override
  String get webSearch => '上網搜尋';

  @override
  String get testing => '測試中';

  @override
  String get test => '測試連線';

  @override
  String connectedP0Ms(Object p0) => '連線成功・${p0} ms';

  @override
  String get connectionFailed => '連線失敗';

  @override
  String get keySet => '金鑰已設定';

  @override
  String get noKey => '金鑰未設定';

  @override
  String get model => '使用模型';

  @override
  String defaultP0(Object p0) => '跟隨預設（${p0}）';

  @override
  String p0NoApiKey(Object p0) => '${p0} 尚未設定金鑰';

  @override
  String p0DoesNotSupportWebSearch(Object p0) => '${p0} 不支援上網搜尋';

  @override
  String get searchNotBilledSeparately => '搜尋不另計費';

  @override
  String firstP0SearchesFreeEachMonth(Object p0, Object p1) => '每月前 ${p0} 次免費，之後每千次 ${p1}';

  @override
  String p0Per1000SearchesPlus(Object p0) => '每千次搜尋 ${p0}，另計搜尋內容 tokens';

  @override
  String get suspiciousListings => '可疑商品處理方式';

  @override
  String get holdReview => '送交審核';

  @override
  String get rejectClearViolations => '直接拒絕明顯違規';

  @override
  String get budgetLimits => '預算與上限';

  @override
  String get monthlyBudgetUsd => '每月預算（USD）';

  @override
  String get k0MeansNoCap => '0 為不設上限';

  @override
  String get dailyLimitPerMember => '每位會員每日次數上限';

  @override
  String get k0MeansUnlimited => '0 為不限';

  @override
  String get advanced => '進階設定';

  @override
  String get resetDefault => '恢復預設';

  @override
  String get modelId => '模型 ID';

  @override
  String get priceUsPer1mTokens => '單價（US\$ / 每百萬 tokens）';

  @override
  String get cachedInput => '快取輸入';

  @override
  String get searchPriceUsPer1000 => '搜尋單價（US\$ / 千次）';

  @override
  String get freeSearchesPerMonth => '每月免費搜尋次數';

  @override
  String p0FieldsInvalid(Object p0) => '${p0} 個欄位格式不正確';

  @override
  String p0UnsavedChanges(Object p0) => '${p0} 項設定尚未儲存';

  @override
  String get unsavedChanges => '有未儲存的變更';

  @override
  String get month2 => '本月費用';

  @override
  String budgetP0(Object p0) => '預算 ${p0}';

  @override
  String get noMonthlyBudget => '未設定每月預算';

  @override
  String projectedP0(Object p0) => '預估月底 ${p0}';

  @override
  String get periodCost => '期間費用';

  @override
  String get requests => '請求次數';

  @override
  String p0Searches(Object p0) => '搜尋 ${p0} 次';

  @override
  String p0OutP1(Object p0, Object p1) => '輸入 ${p0}・輸出 ${p1}';

  @override
  String get errors => '錯誤';

  @override
  String errorRateP0(Object p0) => '錯誤率 ${p0}%';

  @override
  String p0ListingsAwaitingReview(Object p0) => '${p0} 筆上架待審核';

  @override
  String get byFeature => '依功能';

  @override
  String get noDataYet => '尚無資料';

  @override
  String errorsP0(Object p0) => '錯誤 ${p0}';

  @override
  String p0Calls(Object p0) => '${p0} 次';

  @override
  String get byModel => '依模型';

  @override
  String p0CallsP1Ms(Object p0, Object p1) => '${p0} 次・${p1} ms';

  @override
  String get topMembers => '用量最高的會員';

  @override
  String p0Uses(Object p0) => '${p0} 次';

  @override
  String get recentErrors => '最近錯誤';

  @override
  String get noErrors => '沒有錯誤';

  @override
  String get fillWithAi => 'AI 帶入';

  @override
  String get summary => '簡介';

  @override
  String get lookingUpBookDetails => '查詢書籍資料';

  @override
  String get searchingWeb => '上網搜尋補充資料';

  @override
  String get analyzingPhotos => '分析照片';

  @override
  String get suggestingCategoryConditionPrice => '判斷分類、書況與售價';

  @override
  String get couldNotGetAiSuggestions => '無法取得 AI 建議';

  @override
  String get done => '分析完成';

  @override
  String get aiAnalyzing => 'AI 分析中';

  @override
  String get aiSuggestions => 'AI 建議';

  @override
  String get noSuggestionsApply => '沒有可帶入的建議';

  @override
  String get bookDetails => '書籍資料';

  @override
  String get suggestedPrice => '建議售價';

  @override
  String rangeP0P1(Object p0, Object p1) => '建議區間 \$${p0}–\$${p1}';

  @override
  String listPriceP0(Object p0) => '定價 \$${p0}';

  @override
  String applyP0(Object p0) => '套用 ${p0} 項';

  @override
  String currentP0(Object p0) => '目前：${p0}';

  @override
  String get sameAsCurrent => '與目前相同';

  @override
  String get listingNotApproved => '未通過上架審核';

  @override
  String get editListing => '修改內容';

  @override
  String get submittedReview => '已送交審核';

  @override
  String get goSaleOnceApprovedNotifiedResult => '審核通過後將公開販售';

  @override
  String get got => '確定';

  @override
  String get aiFeaturesNotAvailableRightNow => 'AI 功能目前未開放';

  @override
  String get bookUnderReviewGoSaleOnce => '此書籍正在審核，通過後將公開販售';

  @override
  String get notApproved => '未通過審核';

  @override
  String get bookDidNotPassListingReview => '此書籍未通過上架審核';

  @override
  String get enterIsbnTitleFirst => '請先輸入 ISBN 或書名';

  @override
  String appliedP0AiSuggestions(Object p0) => '已套用 ${p0} 項 AI 建議';

  @override
  String get addBookPhotosFirst => '請先加入書籍照片';

  @override
  String get nothingFoundFillCheckIsbnTitle => '找不到可帶入的資料，請確認 ISBN 或書名';

  @override
  String appliedP0AiSuggestions2(Object p0) => '已套用 ${p0} 項 AI 建議';

  @override
  String get aiDataProcessingEnabled => '已同意 AI 資料處理';

  @override
  String get aiDataProcessingTurnedOff => '已停止 AI 資料處理';

  @override
  String get aiDataProcessing => 'AI 資料處理';

  @override
  String get messagesEnterStatusOrdersReservations => '您輸入的訊息與您的訂單、預約狀態';

  @override
  String get isbnTitleConditionNotesPhotosSelect => 'ISBN、書名、書況說明與您選擇的照片';

  @override
  String get bookDetailsFromFavoritesPurchaseHistory => '您的收藏與購買紀錄中的書籍資訊';

  @override
  String get aiDataProcessing2 => 'AI 資料處理說明';

  @override
  String get whenUseAiFeaturesWeShare => '使用 AI 功能時，我們會將下列資料提供給第三方 AI 服務商處理。';

  @override
  String get dataShared => '提供的資料';

  @override
  String get recipients => '資料接收者';

  @override
  String get purpose => '使用目的';

  @override
  String get usedOnlyGenerateSupportRepliesPrepare => '僅用於產生客服回覆、整理上架資料與推薦書籍，不會用於廣告或追蹤。';

  @override
  String get withdrawingConsent => '撤回同意';

  @override
  String get canTurnOffAiDataProcessing => '您可隨時於「設定 › 帳號管理」關閉「AI 資料處理」，關閉後將不再提供上述資料。';

  @override
  String get agreeContinue => '同意並繼續';

  @override
  String get insufficientQuotaPlanNotEnabled => '額度不足或方案未開通';

  @override
  String get modelNotFound => '模型名稱不存在';

  @override
  String get invalidRequestParameters => '請求參數不正確';

  @override
  String get couldNotConnectService => '無法連線至服務';

  @override
  String get blockedByProviderSafetySystem => '內容遭服務安全機制拒絕';

  @override
  String get responseExceededOutputLimit => '回應超過輸出長度上限';

  @override
  String get serverProcessingError => '伺服器處理錯誤';

  @override
  String get aiBookAdvisor => 'AI 書籍顧問';

  @override
  String get requiresDatabaseUpdate013 => '需先執行資料庫更新 013';

  @override
  String get mysteryNovelMyCommute => '適合通勤閱讀的推理小說';

  @override
  String get programmingBooksBeginners => '適合入門的程式設計書';

  @override
  String get booksUnder200Coins => '200 代幣以內的書籍';

  @override
  String get popularLiteraryFictionRightNow => '最近熱門的文學小說';

  @override
  String get tellMeWhatBookLooking => '請描述您想找的書籍';

  @override
  String get describeBookLooking => '描述您想找的書籍';

  @override
  String get tellMeWhatWantReadI => '依您的需求推薦書籍';

  @override
  String get subtitle => '副標題';

  @override
  String get monthOnly => '僅確認到月';

  @override
  String get yearOnly => '僅確認到年';

  @override
  String get msg => '繁體中文';

  @override
  String get additionalInformation => '其他資訊';

  @override
  String get readFull => '展開全文';

  @override
  String get pages => '頁數';

  @override
  String get simplifiedChinese => '簡體中文';

  @override
  String get chinese => '中文';

  @override
  String get english => '英文';

  @override
  String get japanese => '日文';

  @override
  String get korean => '韓文';

  @override
  String p0Pages(Object p0) => '${p0} 頁';

  @override
  String get collapse => '收合';

  @override
  String get setPasswordFirst => '請先設定密碼';

  @override
  String get setPassword => '設定密碼';

  @override
  String get signMethodSettingsSaved => '登入方式設定已儲存';

  @override
  String get signMethodSettingsUnsavedLeavingDiscards => '登入方式設定尚未儲存，離開後變更將遺失。';

  @override
  String get serverNotRunDatabaseUpdate014 => '伺服器尚未執行資料庫更新 014，設定暫時無法生效。';

  @override
  String get signChannels => '各項登入方式';

  @override
  String get socialSmsSign => '社群與簡訊登入';

  @override
  String get whenOffSignPageHidesThese => '關閉後登入頁不再顯示這些方式，已綁定的帳號仍可用密碼登入。';

  @override
  String get notConfigured => '未設定';

  @override
  String get allowCreatingNewAccountsWithMethod => '允許以此方式註冊新帳號';

  @override
  String get unsavedChanges2 => '尚未儲存的變更';

  @override
  String get taiwan => '中華民國';

  @override
  String get hongKong => '香港';

  @override
  String get macau => '澳門';

  @override
  String get china => '中華人民共和國';

  @override
  String get japan => '日本';

  @override
  String get southKorea => '韓國';

  @override
  String get singapore => '新加坡';

  @override
  String get malaysia => '馬來西亞';

  @override
  String get unitedStatesCanada => '美國／加拿大';

  @override
  String get unitedKingdom => '英國';

  @override
  String get australia => '澳洲';

  @override
  String get countryCode => '國碼';

  @override
  String get enterValidMobileNumber => '請輸入正確的手機號碼';

  @override
  String get couldNotSendCodePleaseTry => '無法傳送驗證碼，請稍後再試';

  @override
  String get linkMobileNumber => '綁定手機號碼';

  @override
  String get signWithMobileNumber => '手機號碼登入';

  @override
  String get k6DigitCodeSentNumberMessage => '將傳送 6 位數驗證碼至此手機號碼。';

  @override
  String get mobileNumber => '手機號碼';

  @override
  String get sendCode => '傳送驗證碼';

  @override
  String get codeIncorrectPleaseEnterAgain => '驗證碼不正確，請重新輸入';

  @override
  String get codeBeenSentAgain => '已重新傳送驗證碼';

  @override
  String get enterCode => '輸入驗證碼';

  @override
  String get enterSmsCode => '輸入簡訊驗證碼';

  @override
  String codeWasSentP0(Object p0) => '驗證碼已傳送至 ${p0}';

  @override
  String canResendP0S(Object p0) => '${p0} 秒後可重新傳送';

  @override
  String get resendCode => '重新傳送驗證碼';

  @override
  String get completeAccountDetails => '完成帳號資料';

  @override
  String get p0DidNotProvideEmailAddress => '請填寫電子郵件以完成註冊。';

  @override
  String signWithP0(Object p0) => '以 ${p0} 登入';

  @override
  String get signWith2 => '或使用以下方式登入';

  @override
  String get creatingAccountWithMethodsAboveMeans => '使用上述方式建立帳號即表示您同意服務條款與隱私權政策';

  @override
  String get emailAlreadyRegistered => '此電子郵件已註冊';

  @override
  String get signWithPasswordThenLinkMethod => '請以密碼登入後，至「帳號安全 › 登入方式」綁定。';

  @override
  String get signWithPassword => '以密碼登入';

  @override
  String get accountNoPasswordYet => '此帳號尚未設定密碼';

  @override
  String get passwordSet => '密碼已設定';

  @override
  String get canNowSignWithEmailPassword => '其他裝置須重新登入。';

  @override
  String get passwordRequiredBeforeCanUnlinkSign => '密碼須至少 8 碼，且包含英文與數字。';

  @override
  String get changingSignMethodsRequiresIdentityVerification => '變更登入方式前，請先設定密碼。';

  @override
  String get later => '暫不設定';

  @override
  String p0Linked(Object p0) => '已綁定 ${p0}';

  @override
  String unlinkP0(Object p0) => '解除綁定 ${p0}';

  @override
  String get noLongerAbleSignWayCan => '解除後將無法以此方式登入。';

  @override
  String get unlink => '解除綁定';

  @override
  String p0Unlinked(Object p0) => '已解除綁定 ${p0}';

  @override
  String get socialSmsSignNotAvailableRight => '目前未開放社群與簡訊登入方式。';

  @override
  String get noSignMethodAvailableLink => '目前沒有可綁定的登入方式。';

  @override
  String get noPasswordSet => '尚未設定密碼';

  @override
  String linkedP0(Object p0) => '${p0} 綁定';

  @override
  String get link => '綁定';

  @override
  String get emailAlreadyRegisteredSignWithPassword => '此電子郵件已註冊，請先以密碼登入後，於帳號安全綁定此登入方式';

  @override
  String get provideEmailAddressCreateAccount => '請提供電子郵件以建立帳號';

  @override
  String get signMethodOnlyExistingAccounts => '此登入方式僅供既有帳號使用';

  @override
  String get signMethodNotAvailableRightNow => '目前未開放此登入方式';

  @override
  String get credentialDoesNotMatchSelectedSign => '登入失敗，請重新操作';

  @override
  String get signMethodLinkedAnotherAccount => '此登入方式已綁定其他帳號';

  @override
  String get accountAlreadyLinkedSignMethod => '此帳號已綁定此登入方式';

  @override
  String get onlySignMethodAccountSetPassword => '這是此帳號唯一的登入方式，請先設定密碼或綁定其他登入方式';

  @override
  String get socialSignUnavailableServerNotFinished => '社群登入暫時無法使用，請稍後再試';

  @override
  String get credentialInvalidExpiredPleaseTryAgain => '登入逾時，請重新操作';

  @override
  String get accountAlreadyPasswordUseChangePassword => '此帳號已設定密碼，請改用變更密碼';

  @override
  String get signLinkExpiredPleaseTryAgain => '登入連結已失效，請重新操作';

  @override
  String get signResultExpiredPleaseTryAgain => '登入逾時，請重新操作';

  @override
  String get thirdPartySignServiceUnavailablePlease => '第三方登入服務目前無法使用，請稍後再試';

  @override
  String get couldNotCompleteSignPleaseTry => '無法完成登入，請重新操作';

  @override
  String get accountNotLinkedSignMethod => '此帳號未綁定此登入方式';

  @override
  String get mobileNumberFormatNotValid => '手機號碼格式不正確';

  @override
  String get verificationTimedOutRequestNewCode => '驗證已逾時，請重新取得驗證碼';

  @override
  String get codeExpiredRequestNewOne => '驗證碼已逾時，請重新取得驗證碼';

  @override
  String get tooManyAttemptsPleaseTryAgain => '嘗試次數過多，請稍後再試';

  @override
  String get smsSendingLimitBeenReachedPlease => '簡訊發送次數已達上限，請稍後再試';

  @override
  String get smsVerificationNotSetUpDevice => '此裝置目前無法使用簡訊驗證，請改用其他登入方式';

  @override
  String get couldNotCompleteSmsVerificationPlease => '無法完成簡訊驗證，請稍後再試';

  @override
  String get allowSigningLinkingWithMethod => '開放此方式登入與綁定';

  @override
  String get appNeverStoresPasswordUsedOnly => '本 App 不會儲存您的密碼，僅用於本次驗證。';

  @override
  String get verifyWithBiometricsInstead => '改用生物辨識驗證';

  @override
  String get accountWasCreatedWithSocialPhone => '此帳號尚未設定登入密碼，請先完成設定。';

  @override
  String get setSignPassword => '前往設定登入密碼';

  @override
  String get enterSignPasswordRunAdminAction => '請以登入密碼或通行密鑰驗證身分以執行此後台操作';

  @override
  String p1P0MethodsEnabled(Object p0, Object p1) => '共 ${p0} 種方式，目前啟用 ${p1} 種';

  @override
  String get masterSwitchOffSoEveryMethod => '總開關關閉，所有方式一律停用';

  @override
  String get signLinkingDirectSignUpAllowed => '可登入、綁定與直接註冊';

  @override
  String credentialsNotSetPleaseConfigureP0(Object p0) => '尚未設定憑證，請於伺服器設定 ${p0}';

  @override
  String get whenOffMethodHiddenFromSign => '關閉後登入頁與帳號安全將不顯示此方式';

  @override
  String get whenOffOnlyAccountsAlreadyLinked => '關閉後僅限已綁定的帳號使用此方式';

  @override
  String get signMethodNotLinkedAccount => '此登入方式尚未綁定帳號';

  @override
  String p0AccountNotLinkedAnySavemybook(Object p0) => '${p0} 帳號尚未綁定救「舊」我的書帳號。';

  @override
  String get iAlreadyAccountSignFirst => '登入既有帳號並綁定';

  @override
  String get createNewAccountWithIdentity => '建立新帳號';

  @override
  String signExistingAccountFirstThenLink(Object p0) => '請先登入原有帳號，再至「帳號安全 › 登入方式」綁定 ${p0}。';

  @override
  String get signMethodNotLinkedAnyAccount => '此登入方式尚未綁定任何帳號';

  @override
  String get verifyIdentityWithPasskeyContinue => '請使用通行密鑰驗證身分以繼續';

  @override
  String get verifyWithPasskeyInstead => '改用通行密鑰驗證';

  @override
  String get passkeys => '通行密鑰';

  @override
  String get verifyWithFaceIdFingerprintScreen => '以此裝置的 Face ID、指紋或螢幕鎖定完成驗證，不必輸入密碼。';

  @override
  String get verifyWithPasskey => '使用通行密鑰驗證';

  @override
  String get useSignPasswordInstead => '改用登入密碼驗證';

  @override
  String get signWithPasskey => '使用通行密鑰登入';

  @override
  String get passkeyAdded => '已新增通行密鑰';

  @override
  String get screenLock => '螢幕鎖定';

  @override
  String fromNowCanSignVerifyIdentity(Object p0) => '之後登入與驗證身分可改用 ${p0}，不必再輸入密碼。';

  @override
  String get deletePasskey => '刪除通行密鑰';

  @override
  String get noLongerAbleSignVerifyIdentity => '刪除後將無法以此通行密鑰登入或驗證身分。裝置中儲存的通行密鑰不會一併移除，可至系統的密碼設定中刪除。';

  @override
  String get passkeyDeleted => '已刪除通行密鑰';

  @override
  String get signVerifyIdentityWithFaceId => '以 Face ID、指紋或螢幕鎖定登入與驗證身分，不必輸入密碼。通行密鑰只儲存在您的裝置與密碼管理工具中。';

  @override
  String get addPasskey => '新增通行密鑰';

  @override
  String get notUsedYet => '尚未使用';

  @override
  String lastUsedFormatdateItemLastusedat(Object p0) => '最後使用 ${p0}';

  @override
  String createdCreated(Object p0) => '建立於 ${p0}';

  @override
  String get noPasskeyAvailableDeviceUsePassword => '此裝置沒有可用的通行密鑰，請改用密碼';

  @override
  String get passkeyAlreadyRegisteredDevice => '此裝置已經註冊過通行密鑰';

  @override
  String get signGoogleAccountTurnPasswordManager => '請先在裝置上登入 Google 帳號並開啟密碼管理工具，或改用密碼';

  @override
  String get setUpScreenLockPasswordManager => '此裝置尚未設定螢幕鎖定或密碼管理工具，無法建立通行密鑰';

  @override
  String get deviceDoesNotSupportPasskeysUse => '此裝置不支援通行密鑰，請改用密碼';

  @override
  String get passkeysTemporarilyUnavailableBecauseAppWebsite => '目前無法使用通行密鑰，請改用密碼';

  @override
  String get requestTimedOutPleaseTryAgain => '操作逾時，請再試一次';

  @override
  String get passkeyRequestFailedUsePasswordInstead => '通行密鑰操作失敗，請改用密碼';

  @override
  String get verifyIdentityBeforeAddingPasskey => '新增通行密鑰前，請先驗證身分';

  @override
  String get couldNotListPleaseTryAgain => '上架失敗，請稍後再試';

  @override
  String downloadLinkValidOnceP0P1(Object p0, Object p1) => '此下載網址 5 分鐘內有效，且僅能使用一次，請勿分享。\n\n${p0}\n\n檔案大小：${p1}';

  @override
  String get sources => '資料來源';

  @override
  String get unableOpenLink => '無法開啟連結';

  @override
  String get helpCentre2 => '客服中心';

  @override
  String get preferences => '偏好設定';

  @override
  String get privacy => '隱私';

  @override
  String get about2 => '關於';

  @override
  String clearP0Notifications(Object p0) => '清除${p0}通知';

  @override
  String p1NotificationsP0DeletedCannotUndone(Object p0, Object p1) => '將刪除${p0}類的 ${p1} 則通知，此操作無法復原。';

  @override
  String p0NotificationsCleared(Object p0) => '已清除${p0}通知';

  @override
  String markAllP1UnreadNotificationsP0(Object p0, Object p1) => '確定要將${p0}類的 ${p1} 則未讀通知全部標為已讀？';

  @override
  String get offers => '優惠';

  @override
  String get noTransactionNotifications => '沒有交易通知';

  @override
  String get noChatNotifications => '沒有聊天通知';

  @override
  String get noAccountNotifications => '沒有帳號通知';

  @override
  String get noSupportNotifications => '沒有客服通知';

  @override
  String get noOfferNotifications => '沒有優惠通知';

  @override
  String get images => '圖片';

  @override
  String get imagesStillUploadingPleaseWaitBefore => '圖片上傳中，請稍候再送出';

  @override
  String get someImagesFailedUploadRetryRemove => '部分圖片上傳失敗，請重試或移除後再送出';

  @override
  String get attachImages => '附加圖片';

  @override
  String get imageCouldNotRead => '無法讀取這張圖片';

  @override
  String get up4ImagesPerMessage => '每則訊息最多附加 4 張圖片';

  @override
  String retryUploadingImageP0(Object p0) => '重試上傳圖片 ${p0}';

  @override
  String removeImageP0(Object p0) => '移除圖片 ${p0}';

  @override
  String get addImages => '新增圖片';

  @override
  String viewImageP0(Object p0) => '檢視圖片 ${p0}';

  @override
  String get eGGoldMember => '例如：黃金會員';

  @override
  String get pointsThreshold => '門檻點數';

  @override
  String get pts => '點';

  @override
  String get tierBenefits => '等級福利';

  @override
  String get oneBenefitPerLine => '每行一項福利';

  @override
  String get newTier2 => '新等級';

  @override
  String get whatMembersSee => '會員看到的樣式';

  @override
  String get noThresholdSet => '尚未設定門檻';

  @override
  String get tierOrder => '等級順序';

  @override
  String get noBenefitsSet => '尚未設定福利';

  @override
  String p0CurrentlyP1MembersAfterDeletion(Object p0, Object p1, Object p2) => '「${p0}」目前有 ${p1} 位會員，刪除後將改列「${p2}」。';

  @override
  String noMembersCurrentlyP0OtherTiers(Object p0) => '目前沒有會員屬於「${p0}」，刪除後其他等級不受影響。';

  @override
  String tierDeletedP0MembersMovedP1(Object p0, Object p1) => '已刪除等級，${p0} 位會員改列「${p1}」';

  @override
  String get changeTierOrder => '調整等級順序';

  @override
  String get thresholdsStayWithTheirPositionThese => '門檻點數依位置保留，以下等級的門檻將變更：';

  @override
  String p0P1P2Pts(Object p0, Object p1, Object p2) => '「${p0}」${p1} → ${p2} 點';

  @override
  String get tierOrderUpdated => '已更新等級順序';

  @override
  String p0Members(Object p0) => '${p0} 位會員';

  @override
  String get tiers => '個等級';

  @override
  String get members4 => '位會員';

  @override
  String get memberDistribution => '會員分布';

  @override
  String get moreActions => '更多操作';

  @override
  String get dragReorder => '拖曳調整順序';

  @override
  String p0Pts(Object p0) => '${p0} 點以上';

  @override
  String p0P1Pts(Object p0, Object p1) => '${p0}–${p1} 點';

  @override
  String tierNamedP0AlreadyExists(Object p0) => '已有名為「${p0}」的等級';

  @override
  String get enterPointsThreshold => '請輸入門檻點數';

  @override
  String get thresholdMustWholeNumber0More => '門檻點數須為 0 以上的整數';

  @override
  String thresholdCannotExceedP0(Object p0) => '門檻點數不可超過 ${p0}';

  @override
  String p0AlreadyUsesP1PtsEach(Object p0, Object p1) => '「${p0}」已使用 ${p1} 點，每個等級的門檻須不同';

  @override
  String get startingTierMustBegin0Pts => '起始等級的門檻須為 0 點';

  @override
  String get startingTierCannotDeletedSetAnother => '起始等級無法刪除，請先將其他等級的門檻調整為 0 點';

  @override
  String get signLink => '登入並綁定';

  @override
  String get signAccount => '登入既有帳號';

  @override
  String emailAlreadyRegisteredSignLinkName(Object p0) => '此電子郵件已註冊，登入後即綁定 ${p0}。';

  @override
  String signLinkNameCanThenSign(Object p0, Object p1) => '登入後即綁定 ${p0}，之後可直接使用 ${p1} 登入。';

  @override
  String get noPasskeyDevice => '此裝置沒有可用的通行密鑰';

  @override
  String get signWithPasskeyAnotherDeviceSecurity => '可使用其他裝置上的通行密鑰或安全金鑰登入，或改用密碼。';

  @override
  String get useAnotherDevice => '使用其他裝置';

  @override
  String get usePassword => '改用密碼';

  @override
  String get icloudKeychain => 'iCloud 鑰匙圈';

  @override
  String get googlePasswordManager => 'Google 密碼管理工具';

  @override
  String get synced => '已同步';

  @override
  String get notSynced => '未同步';

  @override
  String get alreadyPasskey => '已有可用的通行密鑰';

  @override
  String get enterName => '請輸入名稱';

  @override
  String get passkeySavedIcloudKeychainWorksEvery => '通行密鑰已儲存在 iCloud 鑰匙圈，登入同一 Apple 帳號的裝置皆可使用，無須重複新增。如需另外建立，請按「再次新增」並在系統視窗改選其他密碼管理工具或安全金鑰。';

  @override
  String get passkeySavedGooglePasswordManagerWorks => '通行密鑰已儲存在 Google 密碼管理工具，登入同一 Google 帳號的裝置皆可使用，無須重複新增。如需另外建立，請按「再次新增」並在系統視窗改選其他密碼管理工具或安全金鑰。';

  @override
  String get passkeySavedDeviceSPasswordManager => '通行密鑰已儲存在此裝置的密碼管理工具，登入同一帳號的裝置皆可使用，無須重複新增。如需另外建立，請按「再次新增」並在系統視窗改選其他密碼管理工具或安全金鑰。';

  @override
  String get addAgain => '再次新增';

  @override
  String get codeExpiredPleaseRequestNewOne => '驗證碼已失效，請重新傳送';

  @override
  String codeValidP0(Object p0) => '驗證碼有效時間 ${p0}';

  @override
  String get basicSettings => '基本設定';

  @override
  String get eGBirthdayVoucher => '例如：生日禮券';

  @override
  String get benefitDetails => '福利內容';

  @override
  String get addBenefit => '新增福利';

  @override
  String get bookNoLongerExistsBeenRemoved => '此書籍已不存在或已下架';

  @override
  String get myNicknameGroup => '我在群組的暱稱';

  @override
  String get setGroupNickname => '設定群組暱稱';

  @override
  String get allGroupMembersSeeNickname => '群組內所有成員皆會看到此暱稱';

  @override
  String get markLockerMaintenance => '設為維修中';

  @override
  String get endLockerMaintenance => '結束維修';

  @override
  String maintenanceHidesP0FromSellers(Object p0) => '設為維修中後「${p0}」將不再顯示於賣家的存放區域選單，既有訂單不受影響。';

  @override
  String endingMaintenanceP0AvailableAgain(Object p0) => '結束維修後「${p0}」將重新開放賣家選擇。';

  @override
  String get lockerMarkedMaintenance => '書櫃已設為維修中';

  @override
  String get lockerMaintenanceEnded => '書櫃已結束維修';

  @override
  String get semanticIndex => '語意索引';

  @override
  String get semanticSearch => '語意檢索';

  @override
  String p0BooksP1HelpArticlesIndexed(Object p0, Object p1) => '已建立書籍 ${p0} 筆、客服知識 ${p1} 筆';

  @override
  String get noOpenaiGeminiKeyConfiguredOnly => '尚未設定 OpenAI 或 Gemini 金鑰，目前僅使用關鍵字檢索';

  @override
  String get databaseNotBeenUpdated020Only => '資料庫尚未更新（020），目前僅使用關鍵字檢索';

  @override
  String get hybridSearchKeywordSemantic => '混合檢索（關鍵字＋語意）';

  @override
  String get keywordSearchOnly => '僅關鍵字檢索';

  @override
  String get paymentReleasedWalletWhenBuyerCompletes => '買家完成訂單或取書滿 24 小時後，款項將撥入您的錢包';

  @override
  String get completeOrderAfterCheckingBookCompletes => '確認書況無誤後請完成訂單，取書滿 24 小時未申訴將自動完成';

  @override
  String get completeOrder => '完成訂單';

  @override
  String get onceCompleteOrderPaymentReleasedSeller => '完成訂單後，款項將撥給賣家，且無法再申請爭議。';

  @override
  String get orderCompleted2 => '訂單已完成';

  @override
  String get noReservedBooks => '目前沒有預訂的書籍';

  @override
  String heldUntilP02(Object p0) => '保留至 ${p0}';

  @override
  String heldUntilP03(Object p0) => '保留至 ${p0}';

  @override
  String get awaitingBuyerConfirmation => '待買家確認';

  @override
  String get awaitingCompletion => '待完成訂單';

  @override
  String get libraryCopyUnofficialSource => '館藏或非正規來源';

  @override
  String p0CannotEdit(Object p0) => '${p0}・無法編輯';

  @override
  String get buyNow2 => '直接購買';

  @override
  String get suggestRefund => '建議退款';

  @override
  String get suggestDismissal => '建議駁回';

  @override
  String get needsMoreInformation => '需要更多資訊';

  @override
  String get aiAnalysis => 'AI 分析';

  @override
  String get analyze => '開始分析';

  @override
  String get analyzeAgain => '重新分析';

  @override
  String get aiAnalysisReferenceOnlyDecideBased => 'AI 分析僅供參考，請依實際證據裁決。';

  @override
  String p0P1Confidence(Object p0, Object p1) => '${p0}・信心 ${p1}%';

  @override
  String get aiSummary => 'AI 整理';

  @override
  String get autoFilled => '自動補齊';

  @override
  String get similarBooks => '相似的書';

  @override
  String get doNotPayTransferMoneyOutside => '請勿私下匯款或轉帳，站外付款不受平台保障';

  @override
  String get pleaseCompleteDealAppWeCannot => '請透過平台交易，站外交易發生糾紛時平台無法協助';

  @override
  String get personSharedOutsideContactDetailsWatch => '對方提供了站外聯絡方式，請留意詐騙並透過平台完成交易';

  @override
  String get mostRelevant => '最相關';

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
