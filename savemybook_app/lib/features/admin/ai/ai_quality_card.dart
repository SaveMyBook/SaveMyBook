import 'package:flutter/material.dart';

import '../../../models/ai_quality.dart';
import '../../../utils/app_colors.dart';
import '../../../widgets/state_views.dart';
import '../../chat/ai/ai_feedback_bar.dart';
import 'ai_labels.dart';
import '../../../i18n/strings.dart';

class AiQualityCard extends StatelessWidget {
  final AiQualityReport report;

  const AiQualityCard({super.key, required this.report});

  static String _percent(double? rate) => rate == null ? S.noData : '${(rate * 100).toStringAsFixed(rate >= 0.1 || rate == 0 ? 0 : 1)}%';

  static String _fieldLabel(String field) => switch (field) {
        'title' => S.title,
        'author' => S.author2,
        'publisher' => S.publisher2,
        'publish_date' => S.publicationDate,
        'isbn' => 'ISBN',
        'description' => S.summary,
        'category_id' => S.category,
        'condition_level' => S.condition,
        'price' => S.sellingPrice,
        _ => field,
      };

  static String? _reasons(Map<String, int> reasons, String separator) {
    if (reasons.isEmpty) return null;
    final sorted = reasons.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.map((e) => '${AiFeedbackBar.reasonLabel(e.key)} ${e.value}').join(separator);
  }

  static String _separator(BuildContext context) => switch (Localizations.localeOf(context).languageCode) {
        'zh' || 'ja' => '、',
        _ => ', ',
      };

  Widget _heading(AppColors c, String text) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 4),
        child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: c.textPrimary)),
      );

  Widget _row(AppColors c, String label, String value, {String? detail, String? note}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: c.textPrimary))),
                if (detail != null) ...[
                  Text(detail, style: TextStyle(fontSize: 11.5, color: c.textHint)),
                  const SizedBox(width: 10),
                ],
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 52),
                  child: Text(value,
                      textAlign: TextAlign.end, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: c.textPrimary)),
                ),
              ],
            ),
            if (note != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(note, style: TextStyle(fontSize: 11.5, height: 1.4, color: c.textSecondary)),
              ),
          ],
        ),
      );

  static String _of(int part, int total) => '$part/$total';

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final r = report;
    final separator = _separator(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(S.aiQuality, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c.textPrimary)),
          _heading(c, S.listingReview),
          _row(c, S.overturnedByAdmins, _percent(r.moderation.rate), detail: _of(r.moderation.overturned, r.moderation.decisions)),
          for (final origin in r.moderationByOrigin)
            _row(c, origin.key == 'rules' ? S.flaggedByInstantRules : S.flaggedByAi, _percent(origin.rate), detail: _of(origin.overturned, origin.decisions)),
          for (final category in r.moderationByCategory)
            _row(c, category.key == 'unspecified' ? S.uncategorised : AiLabels.reviewCategory(category.key), _percent(category.rate),
                detail: _of(category.overturned, category.decisions)),
          _heading(c, S.aiSupport),
          _row(c, S.transferredSupportAgents, _percent(r.handoffRate), detail: _of(r.supportEscalated, r.supportSessions)),
          _row(c, S.ratedNotHelpful, _percent(r.supportRatings.negativeRate),
              detail: _of(r.supportRatings.unhelpful, r.supportRatings.rated), note: _reasons(r.supportRatings.reasons, separator)),
          _heading(c, S.aiBookAdvisor),
          _row(c, S.repliesWithoutBooks, _percent(r.noBooksRate), detail: _of(r.bookChatWithoutBooks, r.bookChatReplies)),
          _row(c, S.ratedNotHelpful, _percent(r.bookChatRatings.negativeRate),
              detail: _of(r.bookChatRatings.unhelpful, r.bookChatRatings.rated), note: _reasons(r.bookChatRatings.reasons, separator)),
          _heading(c, S.disputeAnalysis2),
          _row(c, S.suggestionMatchedDecision, _percent(r.disputeAgreementRate), detail: _of(r.disputeAgreed, r.disputesResolved)),
          _row(c, S.ratedHelpful, _percent(r.disputeHelpfulRate), detail: _of(r.disputeHelpful, r.disputeRated)),
          _heading(c, S.bookRecommendations),
          _row(c, S.aiRecommendationClickThroughRate, _percent(r.aiRecommendations.ctr), detail: _of(r.aiRecommendations.clicks, r.aiRecommendations.impressions)),
          _row(c, S.standardRecommendationClickThroughRate, _percent(r.ruleRecommendations.ctr),
              detail: _of(r.ruleRecommendations.clicks, r.ruleRecommendations.impressions)),
          _row(c, S.markedNotInterested, '${r.notInterested}'),
          _heading(c, S.listingAssistantAdoptionRate),
          if (r.adoption.isEmpty) _row(c, S.listingsUsingAssistant, '${r.assistedListings}'),
          for (final field in r.adoption) _row(c, _fieldLabel(field.field), _percent(field.rate), detail: _of(field.adopted, field.suggested)),
          _heading(c, S.faq),
          _row(c, S.createdFromSupportEnquiries, '${r.faqsFromTickets}'),
        ],
      ),
    );
  }
}
