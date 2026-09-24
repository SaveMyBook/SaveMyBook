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
    AiFeatures.embedding => S.semanticIndex,
    AiFeatures.test => S.connectionTest,
    _ => S.ticketCatOther,
  };

  static IconData featureIcon(String id) => switch (id) {
    AiFeatures.support => Icons.support_agent_rounded,
    AiFeatures.listingAssist => Icons.auto_fix_high_rounded,
    AiFeatures.recommend => Icons.recommend_rounded,
    AiFeatures.moderation => Icons.policy_outlined,
    AiFeatures.bookChat => Icons.auto_stories_rounded,
    AiFeatures.embedding => Icons.hub_outlined,
    AiFeatures.test => Icons.network_check_rounded,
    _ => Icons.more_horiz_rounded,
  };

  static Color featureColor(AppColors c, String id) => switch (id) {
    AiFeatures.support => c.isDark ? const Color(0xFF7FA6FF) : const Color(0xFF3F6FE0),
    AiFeatures.listingAssist => c.isDark ? const Color(0xFF4DD0B8) : const Color(0xFF14A38B),
    AiFeatures.recommend => c.isDark ? const Color(0xFFFFB85C) : const Color(0xFFE38A12),
    AiFeatures.moderation => c.isDark ? const Color(0xFFB79CFF) : const Color(0xFF8157E8),
    AiFeatures.bookChat => c.isDark ? const Color(0xFFFF9AA8) : const Color(0xFFD4536A),
    AiFeatures.embedding => c.isDark ? const Color(0xFF7FD4E8) : const Color(0xFF1B8FA8),
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
    _ => id,
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
    'BLOCKED' => S.blockedByProviderSafetySystem,
    'INCOMPLETE' => S.responseExceededOutputLimit,
    'INTERNAL' => S.serverProcessingError,
    _ => code.isEmpty ? S.unknownError : code,
  };
}
