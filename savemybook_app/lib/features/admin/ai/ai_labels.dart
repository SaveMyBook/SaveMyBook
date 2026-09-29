import 'package:flutter/material.dart';

import '../../../models/ai.dart';
import '../../../utils/app_colors.dart';
import '../../../i18n/strings.dart';

class AiLabels {
  const AiLabels._();

  static String feature(String id) => switch (id) {
    AiFeatures.support => S.aiSupport,
    AiFeatures.listingAssist => S.listingAssist,
    AiFeatures.recommend => S.recommendations,
    AiFeatures.moderation => S.listingReview,
    AiFeatures.bookChat => S.aiBookAdvisor,
    AiFeatures.bookChatPick => S.bookAdvisorSelection,
    AiFeatures.embedding => S.semanticIndex,
    AiFeatures.enrich => S.bookInfoAutoFill,
    AiFeatures.adminAssist => S.disputeAnalysis,
    AiFeatures.test => S.connectionTest,
    _ => S.ticketCatOther,
  };

  static IconData featureIcon(String id) => switch (id) {
    AiFeatures.support => Icons.support_agent_rounded,
    AiFeatures.listingAssist => Icons.auto_fix_high_rounded,
    AiFeatures.recommend => Icons.recommend_rounded,
    AiFeatures.moderation => Icons.policy_outlined,
    AiFeatures.bookChat => Icons.auto_stories_rounded,
    AiFeatures.bookChatPick => Icons.checklist_rounded,
    AiFeatures.embedding => Icons.hub_outlined,
    AiFeatures.enrich => Icons.library_add_check_outlined,
    AiFeatures.adminAssist => Icons.gavel_rounded,
    AiFeatures.test => Icons.network_check_rounded,
    _ => Icons.more_horiz_rounded,
  };

  static Color featureColor(AppColors c, String id) => switch (id) {
    AiFeatures.support => c.isDark ? const Color(0xFF7FA6FF) : const Color(0xFF3F6FE0),
    AiFeatures.listingAssist => c.isDark ? const Color(0xFF4DD0B8) : const Color(0xFF14A38B),
    AiFeatures.recommend => c.isDark ? const Color(0xFFFFB85C) : const Color(0xFFE38A12),
    AiFeatures.moderation => c.isDark ? const Color(0xFFB79CFF) : const Color(0xFF8157E8),
    AiFeatures.bookChat => c.isDark ? const Color(0xFFFF9AA8) : const Color(0xFFD4536A),
    AiFeatures.bookChatPick => c.isDark ? const Color(0xFFFFC2CB) : const Color(0xFFE88A9B),
    AiFeatures.embedding => c.isDark ? const Color(0xFF7FD4E8) : const Color(0xFF1B8FA8),
    AiFeatures.enrich => c.isDark ? const Color(0xFFB5D98A) : const Color(0xFF5E9A2C),
    AiFeatures.adminAssist => c.isDark ? const Color(0xFFE0B98A) : const Color(0xFFA86A2C),
    AiFeatures.test => c.isDark ? const Color(0xFF9AA5B1) : const Color(0xFF7D8894),
    _ => c.neutral,
  };

  static Color providerColor(AppColors c, String id) => switch (id) {
    AiProviders.deepseek => c.isDark ? const Color(0xFF8499FF) : const Color(0xFF4D6BFE),
    AiProviders.gemini => c.isDark ? const Color(0xFF6FC3FF) : const Color(0xFF1C7FD6),
    AiProviders.openai => c.isDark ? const Color(0xFF5DD6A8) : const Color(0xFF10A37F),
    _ => c.neutral,
  };

  static String period(String id) => switch (id) {
    'today' => S.today2,
    '7d' => S.k7Days,
    '30d' => S.k30Days,
    _ => S.month,
  };

  static const periods = ['today', '7d', '30d', 'month'];

  static String reviewCategory(String id) => switch (id) {
    'not_book' => S.notBookUnrelatedItem,
    'prohibited' => S.prohibitedPiratedContent,
    'adult' => S.adultContent,
    'contact' => S.offPlatformDealContactInfo,
    'misleading' => S.misleadingDescription,
    'price' => S.unusualPrice,
    'source' => S.libraryCopyUnofficialSource,
    _ => S.ticketCatOther,
  };

  static String opinion(String verdict) => switch (verdict) {
    'allow' => S.noObviousIssuesFound,
    'reject' => S.likelyViolation,
    _ => S.needsReview,
  };

  static String testCheck(String name) => switch (name) {
    AiTestCheck.text => S.plainText,
    AiTestCheck.json => 'JSON',
    AiTestCheck.image => S.vision,
    _ => name,
  };

  static String outcome(String id) => switch (id) {
    AiOutcomes.ok => S.succeeded,
    AiOutcomes.repaired => S.repaired,
    AiOutcomes.degraded => S.degraded,
    AiOutcomes.empty => S.emptyAfterCleanup,
    AiOutcomes.refused => S.refusedByProvider,
    _ => S.failed,
  };

  static Color outcomeColor(AppColors c, String id) => switch (id) {
    AiOutcomes.ok => c.success,
    AiOutcomes.repaired => c.isDark ? const Color(0xFF7FA6FF) : const Color(0xFF3F6FE0),
    AiOutcomes.degraded => c.warning,
    AiOutcomes.empty => c.neutral,
    AiOutcomes.refused => c.isDark ? const Color(0xFFB79CFF) : const Color(0xFF8157E8),
    _ => c.danger,
  };

  static String? path(String feature, String id) => switch ((feature, id)) {
    (AiFeatures.support, 'answer') => S.modelAnswer,
    (AiFeatures.support, 'guarded') => S.replacedWithStandardNotice,
    (AiFeatures.support, 'passage') => S.fellBackReferencePassage,
    (AiFeatures.bookChat, 'clarify') => S.clarifyingQuestion,
    (AiFeatures.bookChat, 'picked') => S.booksSelectedByModel,
    (AiFeatures.bookChat, 'declined') => S.noSuitableBooks,
    (AiFeatures.bookChat, 'retrieval') => S.fellBackSearchRanking,
    (AiFeatures.bookChat, 'popular') => S.fellBackPopularBooks,
    (AiFeatures.recommend, 'generated') => S.recommendationsGenerated,
    (AiFeatures.recommend, 'none') => S.noSuitableCandidates,
    (AiFeatures.recommend, 'no_candidates') => S.noCandidates,
    (AiFeatures.listingAssist, 'model') => S.modelSuggestionsUsed,
    (AiFeatures.listingAssist, 'bibliographic') => S.bibliographicDataOnly,
    (AiFeatures.listingAssist, 'condition') => S.assessConditionPrice,
    (AiFeatures.listingAssist, 'price') => S.lookUpListPrice,
    (AiFeatures.adminAssist, 'refund') => S.suggestRefund,
    (AiFeatures.adminAssist, 'dismiss') => S.suggestDismissal,
    (AiFeatures.adminAssist, 'mediate') => S.suggestMediation,
    (AiFeatures.adminAssist, 'need_more_info') => S.needsMoreInformation,
    _ => null,
  };

  static String? flag(String feature, String key) => switch ((feature, key)) {
    (AiFeatures.support, 'handoff') => S.handoffSuggested,
    (AiFeatures.support, 'handoff_forced') => S.handoffEnforcedBySystem,
    (AiFeatures.support, 'insufficient') => S.insufficientGrounding,
    (AiFeatures.support, 'follow_ups') => S.followUpSuggestionsProvided,
    (AiFeatures.bookChat, 'continued') => S.continuedPreviousCriteria,
    (AiFeatures.bookChat, 'inherited') => S.reusedPreviousTopic,
    (AiFeatures.bookChat, 'unmatched') => S.noSearchMatch,
    (AiFeatures.bookChat, 'invalid_picks') => S.invalidBookCodesReturned,
    (AiFeatures.bookChat, 'reply_unknown_title') => S.replyTitleNotBookCards,
    (AiFeatures.bookChat, 'reply_price') => S.replyMentionsPrice,
    (AiFeatures.bookChat, 'reply_denies_books') => S.replyDeniesResultsDespiteBookCards,
    (AiFeatures.recommend, 'salvaged') => S.completeItemsKeptAfterTruncation,
    (AiFeatures.adminAssist, 'photos_skipped') => S.somePhotosNotSent,
    (AiFeatures.adminAssist, 'evidence_unseen') => S.noEvidencePhotosSent,
    (AiFeatures.adminAssist, 'photo_refs') => S.findingsCitePhotos,
    (AiFeatures.listingAssist, 'used_search') => S.webSearchUsed,
    (AiFeatures.listingAssist, 'search_retry') => S.retriedWithoutSearch,
    (AiFeatures.listingAssist, 'backup') => S.backupProviderUsed,
    (AiFeatures.listingAssist, 'condition_adjusted') => S.conditionAdjustedFromNotes,
    (AiFeatures.listingAssist, 'cache_fields') => S.cachedBibliographicDataUsed,
    (AiFeatures.listingAssist, 'cache_description') => S.cachedDescriptionUsed,
    (AiFeatures.listingAssist, 'isbn_mismatch') => S.isbnTitleDoNotMatch,
    _ => null,
  };

  static String? average(String feature, String key) => switch ((feature, key)) {
    (AiFeatures.support, 'docs') => S.avgPassagesRetrieved,
    (AiFeatures.bookChat, 'candidates') || (AiFeatures.recommend, 'candidates') => S.avgCandidates,
    (AiFeatures.bookChat, 'fillers') || (AiFeatures.recommend, 'fillers') => S.avgFillerBooks,
    (AiFeatures.bookChat, 'books') => S.avgBooksRecommended,
    (AiFeatures.recommend, 'picked') => S.avgBooksSelected,
    (AiFeatures.recommend, 'invalid') => S.avgInvalidCodes,
    (AiFeatures.support, 'cited') => S.avgPassagesCited,
    (AiFeatures.recommend, 'basis_dropped') => S.avgInvalidRecommendationBases,
    (AiFeatures.recommend, 'templated') => S.avgSystemGeneratedReasons,
    (AiFeatures.adminAssist, 'invalid_photo_refs') => S.avgInvalidPhotoReferences,
    (AiFeatures.listingAssist, 'photos') => S.avgPhotos,
    (AiFeatures.listingAssist, 'sources') => S.avgSources,
    _ => null,
  };

  static String origin(String id) => switch (id) {
    'book_search' => S.bookSearch,
    'similar_books' => S.similarBooks,
    AiEmbeddingOrigin.index => S.indexUpdates,
    AiEmbeddingOrigin.unknown => S.sourceNotRecorded,
    _ => feature(id),
  };

  static String errorCode(String code) => switch (code) {
    'AI_PROVIDER_ERROR' || 'SERVER' => S.providerError,
    'AI_TIMEOUT' || 'TIMEOUT' => S.timedOut,
    'AI_NOT_CONFIGURED' || 'NOT_CONFIGURED' => S.noApiKey,
    'AI_RATE_LIMITED' || 'RATE_LIMITED' => S.rateLimited,
    'AI_INVALID_KEY' || 'INVALID_KEY' || 'AUTH' => S.invalidApiKey,
    'AI_BAD_RESPONSE' || 'BAD_RESPONSE' || 'INVALID_OUTPUT' => S.invalidResponseFormat,
    'QUOTA' => S.insufficientQuotaPlanNotEnabled,
    'MODEL_NOT_FOUND' => S.modelNotFound,
    'BAD_REQUEST' => S.invalidRequestParameters,
    'NETWORK' => S.couldNotConnectService,
    'AI_CONTENT_BLOCKED' || 'BLOCKED' => S.blockedByProviderSafetySystem,
    'BUDGET_EXCEEDED' => S.monthlyBudgetUsedUp,
    'INCOMPLETE' => S.responseExceededOutputLimit,
    'INTERNAL' => S.serverProcessingError,
    _ => code.isEmpty ? S.unknownError : code,
  };
}
