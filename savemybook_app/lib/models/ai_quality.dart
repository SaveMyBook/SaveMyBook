import '../utils/api_helpers.dart';

/// 比例在沒有樣本時為 null，畫面顯示為無資料而不是 0%。
double? _ratio(Object? raw) => raw == null ? null : parseDouble(raw).clamp(0.0, 1.0);

Map<String, dynamic> _map(Object? raw) => raw is Map ? Map<String, dynamic>.from(raw) : const {};

List<Map<String, dynamic>> _maps(Object? raw) => [
      if (raw is List)
        for (final item in raw)
          if (item is Map) Map<String, dynamic>.from(item),
    ];

class AiOverturnStat {
  final String key;
  final int decisions;
  final int overturned;
  final double? rate;

  const AiOverturnStat({required this.key, this.decisions = 0, this.overturned = 0, this.rate});

  factory AiOverturnStat.fromJson(Map<String, dynamic> json, String keyName) => AiOverturnStat(
        key: '${json[keyName] ?? ''}',
        decisions: parseInt(json['decisions']),
        overturned: parseInt(json['overturned']),
        rate: _ratio(json['rate']),
      );
}

class AiRatingStat {
  final int rated;
  final int unhelpful;
  final double? negativeRate;
  final Map<String, int> reasons;

  const AiRatingStat({this.rated = 0, this.unhelpful = 0, this.negativeRate, this.reasons = const {}});

  factory AiRatingStat.fromJson(Map<String, dynamic> json) => AiRatingStat(
        rated: parseInt(json['rated']),
        unhelpful: parseInt(json['unhelpful']),
        negativeRate: _ratio(json['negative_rate']),
        reasons: {for (final e in _map(json['reasons']).entries) e.key: parseInt(e.value)},
      );
}

class AiClickStat {
  final int impressions;
  final int clicks;
  final double? ctr;

  const AiClickStat({this.impressions = 0, this.clicks = 0, this.ctr});

  factory AiClickStat.fromJson(Map<String, dynamic> json) => AiClickStat(
        impressions: parseInt(json['impressions']),
        clicks: parseInt(json['clicks']),
        ctr: _ratio(json['ctr']),
      );
}

class AiAdoptionStat {
  final String field;
  final int suggested;
  final int adopted;
  final double? rate;

  const AiAdoptionStat({required this.field, this.suggested = 0, this.adopted = 0, this.rate});

  factory AiAdoptionStat.fromJson(Map<String, dynamic> json) => AiAdoptionStat(
        field: '${json['field'] ?? ''}',
        suggested: parseInt(json['suggested']),
        adopted: parseInt(json['adopted']),
        rate: _ratio(json['rate']),
      );
}

/// 後台 AI 品質報表：只有統計數字，不含使用者的對話內容。
class AiQualityReport {
  final AiOverturnStat moderation;
  final List<AiOverturnStat> moderationByCategory;
  final List<AiOverturnStat> moderationByOrigin;
  final int supportSessions;
  final int supportEscalated;
  final double? handoffRate;
  final AiRatingStat supportRatings;
  final int bookChatReplies;
  final int bookChatWithoutBooks;
  final double? noBooksRate;
  final AiRatingStat bookChatRatings;
  final int disputesResolved;
  final int disputeAgreed;
  final double? disputeAgreementRate;
  final int disputeRated;
  final int disputeHelpful;
  final double? disputeHelpfulRate;
  final AiClickStat aiRecommendations;
  final AiClickStat ruleRecommendations;
  final int notInterested;
  final int assistedListings;
  final List<AiAdoptionStat> adoption;
  final int faqsFromTickets;

  const AiQualityReport({
    this.moderation = const AiOverturnStat(key: ''),
    this.moderationByCategory = const [],
    this.moderationByOrigin = const [],
    this.supportSessions = 0,
    this.supportEscalated = 0,
    this.handoffRate,
    this.supportRatings = const AiRatingStat(),
    this.bookChatReplies = 0,
    this.bookChatWithoutBooks = 0,
    this.noBooksRate,
    this.bookChatRatings = const AiRatingStat(),
    this.disputesResolved = 0,
    this.disputeAgreed = 0,
    this.disputeAgreementRate,
    this.disputeRated = 0,
    this.disputeHelpful = 0,
    this.disputeHelpfulRate,
    this.aiRecommendations = const AiClickStat(),
    this.ruleRecommendations = const AiClickStat(),
    this.notInterested = 0,
    this.assistedListings = 0,
    this.adoption = const [],
    this.faqsFromTickets = 0,
  });

  factory AiQualityReport.fromJson(Map<String, dynamic> json) {
    final moderation = _map(json['moderation']);
    final support = _map(json['support']);
    final bookChat = _map(json['book_chat']);
    final disputes = _map(json['dispute_assist']);
    final recommendations = _map(json['recommendations']);
    final listing = _map(json['listing_assist']);
    return AiQualityReport(
      moderation: AiOverturnStat.fromJson(moderation, 'category'),
      moderationByCategory: [for (final m in _maps(moderation['by_category'])) AiOverturnStat.fromJson(m, 'category')],
      moderationByOrigin: [for (final m in _maps(moderation['by_origin'])) AiOverturnStat.fromJson(m, 'origin')],
      supportSessions: parseInt(support['sessions']),
      supportEscalated: parseInt(support['escalated']),
      handoffRate: _ratio(support['handoff_rate']),
      supportRatings: AiRatingStat.fromJson(support),
      bookChatReplies: parseInt(bookChat['replies']),
      bookChatWithoutBooks: parseInt(bookChat['without_books']),
      noBooksRate: _ratio(bookChat['no_books_rate']),
      bookChatRatings: AiRatingStat.fromJson(bookChat),
      disputesResolved: parseInt(disputes['resolved']),
      disputeAgreed: parseInt(disputes['agreed']),
      disputeAgreementRate: _ratio(disputes['agreement_rate']),
      disputeRated: parseInt(disputes['rated']),
      disputeHelpful: parseInt(disputes['helpful']),
      disputeHelpfulRate: _ratio(disputes['helpful_rate']),
      aiRecommendations: AiClickStat.fromJson(_map(recommendations['ai'])),
      ruleRecommendations: AiClickStat.fromJson(_map(recommendations['rules'])),
      notInterested: parseInt(recommendations['not_interested']),
      assistedListings: parseInt(listing['listings']),
      adoption: [for (final m in _maps(listing['fields'])) AiAdoptionStat.fromJson(m)],
      faqsFromTickets: parseInt(json['faqs_from_tickets']),
    );
  }
}
