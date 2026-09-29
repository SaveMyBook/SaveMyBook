import 'dart:convert';
import 'dart:math' as math;

import '../utils/api_helpers.dart';
import 'book.dart';

class AiProviders {
  const AiProviders._();

  static const deepseek = 'deepseek';
  static const gemini = 'gemini';
  static const openai = 'openai';

  static const ids = [deepseek, gemini, openai];

  static String nameOf(String id) => switch (id) {
    deepseek => 'DeepSeek',
    gemini => 'Gemini',
    openai => 'OpenAI',
    _ => id,
  };
}

class AiFeatures {
  const AiFeatures._();

  static const support = 'support';
  static const listingAssist = 'listing_assist';
  static const recommend = 'recommend';
  static const moderation = 'moderation';
  static const bookChat = 'book_chat';
  static const bookChatPick = 'book_chat_pick';
  static const embedding = 'embedding';
  static const enrich = 'enrich';
  static const adminAssist = 'admin_assist';
  static const test = 'test';

  static const configurable = [support, listingAssist, recommend, moderation, bookChat];

  static const limited = [support, listingAssist, recommend, bookChat];
}

double _clampNonNegative(dynamic value) => math.max(0, parseDouble(value));

class AiProviderPricing {
  final String model;
  final double inputPerM;
  final double cachedInputPerM;
  final double outputPerM;
  final double searchPricePerK;
  final int searchFreePerMonth;

  const AiProviderPricing({
    required this.model,
    required this.inputPerM,
    required this.cachedInputPerM,
    required this.outputPerM,
    this.searchPricePerK = 0,
    this.searchFreePerMonth = 0,
  });

  static const defaults = <String, AiProviderPricing>{
    AiProviders.deepseek: AiProviderPricing(
      model: 'deepseek-flash',
      inputPerM: 0.14,
      cachedInputPerM: 0.0028,
      outputPerM: 0.28,
    ),
    AiProviders.gemini: AiProviderPricing(
      model: 'gemini-3.1-flash-lite',
      inputPerM: 0.25,
      cachedInputPerM: 0.025,
      outputPerM: 1.5,
      searchPricePerK: 14,
      searchFreePerMonth: 5000,
    ),
    AiProviders.openai: AiProviderPricing(
      model: 'gpt-5-nano',
      inputPerM: 0.05,
      cachedInputPerM: 0.005,
      outputPerM: 0.4,
      searchPricePerK: 10,
    ),
  };

  factory AiProviderPricing.fromJson(Map<String, dynamic>? json, AiProviderPricing fallback) {
    if (json == null) return fallback;
    final model = (json['model'] as String?)?.trim();
    return AiProviderPricing(
      model: model == null || model.isEmpty ? fallback.model : model,
      inputPerM: json.containsKey('input_per_m') ? _clampNonNegative(json['input_per_m']) : fallback.inputPerM,
      cachedInputPerM: json.containsKey('cached_input_per_m')
          ? _clampNonNegative(json['cached_input_per_m'])
          : fallback.cachedInputPerM,
      outputPerM: json.containsKey('output_per_m') ? _clampNonNegative(json['output_per_m']) : fallback.outputPerM,
      searchPricePerK: json.containsKey('search_price_per_k')
          ? _clampNonNegative(json['search_price_per_k'])
          : fallback.searchPricePerK,
      searchFreePerMonth: json.containsKey('search_free_per_month')
          ? math.max(0, parseInt(json['search_free_per_month']))
          : fallback.searchFreePerMonth,
    );
  }

  Map<String, dynamic> toJson() => {
    'model': model,
    'input_per_m': inputPerM,
    'cached_input_per_m': cachedInputPerM,
    'output_per_m': outputPerM,
    'search_price_per_k': searchPricePerK,
    'search_free_per_month': searchFreePerMonth,
  };

  AiProviderPricing copyWith({
    String? model,
    double? inputPerM,
    double? cachedInputPerM,
    double? outputPerM,
    double? searchPricePerK,
    int? searchFreePerMonth,
  }) => AiProviderPricing(
    model: model ?? this.model,
    inputPerM: inputPerM ?? this.inputPerM,
    cachedInputPerM: cachedInputPerM ?? this.cachedInputPerM,
    outputPerM: outputPerM ?? this.outputPerM,
    searchPricePerK: searchPricePerK ?? this.searchPricePerK,
    searchFreePerMonth: searchFreePerMonth ?? this.searchFreePerMonth,
  );
}

class AiFeatureConfig {
  final bool enabled;
  final String? provider;
  final String? fallbackProvider;
  final bool webSearch;
  final String action;

  const AiFeatureConfig({
    this.enabled = true,
    this.provider,
    this.fallbackProvider,
    this.webSearch = false,
    this.action = 'review',
  });

  static const defaults = <String, AiFeatureConfig>{
    AiFeatures.support: AiFeatureConfig(),
    AiFeatures.listingAssist: AiFeatureConfig(provider: AiProviders.gemini, webSearch: true),
    AiFeatures.recommend: AiFeatureConfig(),
    AiFeatures.moderation: AiFeatureConfig(),
    AiFeatures.bookChat: AiFeatureConfig(),
  };

  factory AiFeatureConfig.fromJson(Map<String, dynamic>? json, AiFeatureConfig fallback) {
    if (json == null) return fallback;
    final provider = json['provider'];
    final backup = json['fallback_provider'];
    return AiFeatureConfig(
      enabled: json.containsKey('enabled') ? json['enabled'] == true : fallback.enabled,
      provider: provider is String && AiProviders.ids.contains(provider)
          ? provider
          : (json.containsKey('provider') ? null : fallback.provider),
      fallbackProvider: backup is String && AiProviders.ids.contains(backup) ? backup : null,
      webSearch: json.containsKey('web_search') ? json['web_search'] == true : fallback.webSearch,
      action: json['action'] == 'block' ? 'block' : (json['action'] == 'review' ? 'review' : fallback.action),
    );
  }

  Map<String, dynamic> toJson(String feature) => {
    'enabled': enabled,
    'provider': provider,
    'fallback_provider': fallbackProvider,
    if (feature == AiFeatures.listingAssist) 'web_search': webSearch,
    if (feature == AiFeatures.moderation) 'action': action,
  };

  AiFeatureConfig copyWith({
    bool? enabled,
    String? Function()? provider,
    String? Function()? fallbackProvider,
    bool? webSearch,
    String? action,
  }) =>
      AiFeatureConfig(
        enabled: enabled ?? this.enabled,
        provider: provider == null ? this.provider : provider(),
        fallbackProvider: fallbackProvider == null ? this.fallbackProvider : fallbackProvider(),
        webSearch: webSearch ?? this.webSearch,
        action: action ?? this.action,
      );
}

class AiSettings {
  final bool enabled;
  final String defaultProvider;
  final Map<String, AiProviderPricing> providers;
  final Map<String, AiFeatureConfig> features;
  final double monthlyBudgetUsd;
  final double reserveRatio;
  final Map<String, int> dailyPerUser;

  const AiSettings({
    required this.enabled,
    required this.defaultProvider,
    required this.providers,
    required this.features,
    required this.monthlyBudgetUsd,
    this.reserveRatio = defaultReserveRatio,
    required this.dailyPerUser,
  });

  static const defaultReserveRatio = 0.2;
  static const maxReserveRatio = 0.9;

  static const _defaultLimits = {
    AiFeatures.support: 30,
    AiFeatures.listingAssist: 15,
    AiFeatures.recommend: 5,
    AiFeatures.bookChat: 20,
  };

  static final AiSettings defaults = AiSettings.fromJson(const {});

  factory AiSettings.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? section(Object? raw, String key) {
      final map = raw is Map ? raw[key] : null;
      return map is Map ? Map<String, dynamic>.from(map) : null;
    }

    final limits = json['limits'] is Map ? Map<String, dynamic>.from(json['limits']) : const <String, dynamic>{};
    final daily = limits['daily_per_user'];
    final defaultProvider = json['default_provider'];

    return AiSettings(
      enabled: json['enabled'] == true,
      defaultProvider: defaultProvider is String && AiProviders.ids.contains(defaultProvider)
          ? defaultProvider
          : AiProviders.deepseek,
      providers: {
        for (final id in AiProviders.ids)
          id: AiProviderPricing.fromJson(section(json['providers'], id), AiProviderPricing.defaults[id]!),
      },
      features: {
        for (final f in AiFeatures.configurable)
          f: AiFeatureConfig.fromJson(section(json['features'], f), AiFeatureConfig.defaults[f]!),
      },
      monthlyBudgetUsd: limits.containsKey('monthly_budget_usd') ? _clampNonNegative(limits['monthly_budget_usd']) : 10,
      reserveRatio: limits.containsKey('reserve_ratio')
          ? math.min(maxReserveRatio, _clampNonNegative(limits['reserve_ratio']))
          : defaultReserveRatio,
      dailyPerUser: {
        for (final entry in _defaultLimits.entries)
          entry.key: daily is Map && daily.containsKey(entry.key)
              ? math.max(0, parseInt(daily[entry.key]))
              : entry.value,
      },
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'default_provider': defaultProvider,
    'providers': {for (final id in AiProviders.ids) id: providers[id]!.toJson()},
    'features': {for (final f in AiFeatures.configurable) f: features[f]!.toJson(f)},
    'limits': {
      'monthly_budget_usd': monthlyBudgetUsd,
      'reserve_ratio': reserveRatio,
      'daily_per_user': {for (final f in AiFeatures.limited) f: dailyPerUser[f] ?? 0},
    },
  };

  String get fingerprint => jsonEncode(toJson());

  String effectiveProvider(String feature) => features[feature]?.provider ?? defaultProvider;

  AiSettings copyWith({
    bool? enabled,
    String? defaultProvider,
    Map<String, AiProviderPricing>? providers,
    Map<String, AiFeatureConfig>? features,
    double? monthlyBudgetUsd,
    double? reserveRatio,
    Map<String, int>? dailyPerUser,
  }) => AiSettings(
    enabled: enabled ?? this.enabled,
    defaultProvider: defaultProvider ?? this.defaultProvider,
    providers: providers ?? this.providers,
    features: features ?? this.features,
    monthlyBudgetUsd: monthlyBudgetUsd ?? this.monthlyBudgetUsd,
    reserveRatio: reserveRatio ?? this.reserveRatio,
    dailyPerUser: dailyPerUser ?? this.dailyPerUser,
  );

  AiSettings withProvider(String id, AiProviderPricing pricing) => copyWith(providers: {...providers, id: pricing});

  AiSettings withFeature(String feature, AiFeatureConfig config) => copyWith(features: {...features, feature: config});

  AiSettings withDailyLimit(String feature, int value) => copyWith(dailyPerUser: {...dailyPerUser, feature: value});

  List<String> changedSections(AiSettings other) {
    final a = toJson();
    final b = other.toJson();
    return [
      if (a['enabled'] != b['enabled']) 'enabled',
      if (a['default_provider'] != b['default_provider']) 'default_provider',
      for (final f in AiFeatures.configurable)
        if (jsonEncode(a['features'][f]) != jsonEncode(b['features'][f])) 'features.$f',
      for (final id in AiProviders.ids)
        if (jsonEncode(a['providers'][id]) != jsonEncode(b['providers'][id])) 'providers.$id',
      if (jsonEncode(a['limits']) != jsonEncode(b['limits'])) 'limits',
    ];
  }
}

class AiProviderInfo {
  final String id;
  final String name;
  final bool keyConfigured;
  final bool vision;
  final bool webSearch;
  final String defaultModel;
  final String? docsUrl;

  const AiProviderInfo({
    required this.id,
    required this.name,
    required this.keyConfigured,
    required this.vision,
    required this.webSearch,
    required this.defaultModel,
    this.docsUrl,
  });

  factory AiProviderInfo.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? '';
    return AiProviderInfo(
      id: id,
      name: (json['name'] as String?)?.trim().isNotEmpty == true ? json['name'] as String : AiProviders.nameOf(id),
      keyConfigured: json['key_configured'] == true,
      vision: json['vision'] == true,
      webSearch: json['web_search'] == true,
      defaultModel: json['default_model'] as String? ?? AiProviderPricing.defaults[id]?.model ?? '',
      docsUrl: json['docs_url'] as String?,
    );
  }
}

class AiRetrievalCoverage {
  final int indexed;
  final int total;

  const AiRetrievalCoverage({this.indexed = 0, this.total = 0});

  double get ratio => total <= 0 ? 1 : (indexed / total).clamp(0.0, 1.0);

  static AiRetrievalCoverage? fromJson(Object? json) {
    if (json is! Map) return null;
    return AiRetrievalCoverage(indexed: parseInt(json['indexed']), total: parseInt(json['total']));
  }
}

class AiRetrievalError {
  final DateTime? at;
  final String purpose;
  final String code;
  final String? detail;

  const AiRetrievalError({this.at, this.purpose = '', this.code = '', this.detail});

  static AiRetrievalError? fromJson(Object? json) {
    if (json is! Map) return null;
    final detail = (json['detail'] as String?)?.trim();
    return AiRetrievalError(
      at: parseDate(json['at']),
      purpose: json['purpose'] as String? ?? '',
      code: json['code'] as String? ?? '',
      detail: detail == null || detail.isEmpty ? null : detail,
    );
  }
}

class AiRetrievalStatus {
  final bool ready;
  final String? provider;
  final String? model;
  final int books;
  final int knowledge;
  final AiRetrievalCoverage? bookCoverage;
  final AiRetrievalCoverage? knowledgeCoverage;
  final DateTime? lastSyncAt;
  final AiRetrievalError? lastError;
  final DateTime? syncPausedUntil;
  final DateTime? queryPausedUntil;

  const AiRetrievalStatus({
    this.ready = false,
    this.provider,
    this.model,
    this.books = 0,
    this.knowledge = 0,
    this.bookCoverage,
    this.knowledgeCoverage,
    this.lastSyncAt,
    this.lastError,
    this.syncPausedUntil,
    this.queryPausedUntil,
  });

  static const none = AiRetrievalStatus();

  factory AiRetrievalStatus.fromJson(Object? json) {
    if (json is! Map) return none;
    final counts = json['counts'] is Map ? json['counts'] as Map : const {};
    final coverage = json['coverage'] is Map ? json['coverage'] as Map : const {};
    final cooldown = json['cooldown_until'] is Map ? json['cooldown_until'] as Map : const {};
    return AiRetrievalStatus(
      ready: json['ready'] == true,
      provider: json['provider'] as String?,
      model: json['model'] as String?,
      books: parseInt(counts['book']),
      knowledge: parseInt(counts['knowledge']),
      bookCoverage: AiRetrievalCoverage.fromJson(coverage['book']),
      knowledgeCoverage: AiRetrievalCoverage.fromJson(coverage['knowledge']),
      lastSyncAt: parseDate(json['last_sync_at']),
      lastError: AiRetrievalError.fromJson(json['last_error']),
      syncPausedUntil: parseDate(cooldown['sync']),
      queryPausedUntil: parseDate(cooldown['query']),
    );
  }
}

class AiSettingsBundle {
  final AiSettings settings;
  final List<AiProviderInfo> providers;
  final AiRetrievalStatus retrieval;

  const AiSettingsBundle({
    required this.settings,
    required this.providers,
    this.retrieval = AiRetrievalStatus.none,
  });

  factory AiSettingsBundle.fromJson(Map<String, dynamic> json) {
    final raw = json['providers'];
    final list = <AiProviderInfo>[
      if (raw is List)
        for (final item in raw)
          if (item is Map) AiProviderInfo.fromJson(Map<String, dynamic>.from(item)),
    ];
    final settings = json['settings'];
    return AiSettingsBundle(
      settings: AiSettings.fromJson(settings is Map ? Map<String, dynamic>.from(settings) : const {}),
      providers: [
        for (final id in AiProviders.ids)
          list.firstWhere(
            (p) => p.id == id,
            orElse: () => AiProviderInfo(
              id: id,
              name: AiProviders.nameOf(id),
              keyConfigured: false,
              vision: id != AiProviders.deepseek,
              webSearch: id != AiProviders.deepseek,
              defaultModel: AiProviderPricing.defaults[id]!.model,
            ),
          ),
      ],
      retrieval: AiRetrievalStatus.fromJson(json['retrieval']),
    );
  }

  AiProviderInfo provider(String id) => providers.firstWhere((p) => p.id == id);
}

class AiTestCheck {
  static const text = 'text';
  static const json = 'json';
  static const image = 'image';

  final String name;
  final String status;
  final int latencyMs;
  final String? error;

  const AiTestCheck({required this.name, required this.status, this.latencyMs = 0, this.error});

  bool get ok => status == 'ok';

  bool get skipped => status == 'skipped';

  factory AiTestCheck.fromJson(Map<String, dynamic> json) => AiTestCheck(
    name: json['name'] as String? ?? '',
    status: json['status'] as String? ?? 'failed',
    latencyMs: parseInt(json['latency_ms']),
    error: (json['error'] as String?)?.trim().isEmpty ?? true ? null : (json['error'] as String).trim(),
  );
}

class AiTestResult {
  final bool ok;
  final String provider;
  final String model;
  final int latencyMs;
  final String? reply;
  final String? error;
  final List<AiTestCheck> checks;

  const AiTestResult({
    required this.ok,
    required this.provider,
    required this.model,
    required this.latencyMs,
    this.reply,
    this.error,
    this.checks = const [],
  });

  factory AiTestResult.fromJson(Map<String, dynamic> json) => AiTestResult(
    ok: json['ok'] == true,
    provider: json['provider'] as String? ?? '',
    model: json['model'] as String? ?? '',
    latencyMs: parseInt(json['latency_ms']),
    reply: json['reply'] as String?,
    error: json['error'] as String?,
    checks: [
      if (json['checks'] is List)
        for (final item in json['checks'] as List)
          if (item is Map) AiTestCheck.fromJson(Map<String, dynamic>.from(item)),
    ],
  );
}

class AiUsageSummary {
  final int requests;
  final int errors;
  final int inputTokens;
  final int outputTokens;
  final int searchCalls;
  final double costUsd;
  final double monthCostUsd;
  final double monthlyBudgetUsd;
  final double memberBudgetUsd;
  final double budgetUsedRatio;
  final double projectedMonthCostUsd;

  const AiUsageSummary({
    this.requests = 0,
    this.errors = 0,
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.searchCalls = 0,
    this.costUsd = 0,
    this.monthCostUsd = 0,
    this.monthlyBudgetUsd = 0,
    this.memberBudgetUsd = 0,
    this.budgetUsedRatio = 0,
    this.projectedMonthCostUsd = 0,
  });

  factory AiUsageSummary.fromJson(Map<String, dynamic> json) {
    final budget = parseDouble(json['monthly_budget_usd']);
    final month = parseDouble(json['month_cost_usd']);
    return AiUsageSummary(
      requests: parseInt(json['requests']),
      errors: parseInt(json['errors']),
      inputTokens: parseInt(json['input_tokens']),
      outputTokens: parseInt(json['output_tokens']),
      searchCalls: parseInt(json['search_calls']),
      costUsd: parseDouble(json['cost_usd']),
      monthCostUsd: month,
      monthlyBudgetUsd: budget,
      memberBudgetUsd: json['member_budget_usd'] != null ? parseDouble(json['member_budget_usd']) : budget,
      budgetUsedRatio: json['budget_used_ratio'] != null
          ? parseDouble(json['budget_used_ratio'])
          : (budget > 0 ? month / budget : 0),
      projectedMonthCostUsd: parseDouble(json['projected_month_cost_usd']),
    );
  }

  int get totalTokens => inputTokens + outputTokens;

  bool get hasReserve => monthlyBudgetUsd > 0 && memberBudgetUsd < monthlyBudgetUsd;

  double get errorRate => requests == 0 ? 0 : errors / requests;
}

class AiFeatureUsage {
  final String feature;
  final int requests;
  final double costUsd;
  final int inputTokens;
  final int outputTokens;
  final int errors;

  const AiFeatureUsage({
    required this.feature,
    this.requests = 0,
    this.costUsd = 0,
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.errors = 0,
  });

  factory AiFeatureUsage.fromJson(Map<String, dynamic> json) => AiFeatureUsage(
    feature: json['feature'] as String? ?? '',
    requests: parseInt(json['requests']),
    costUsd: parseDouble(json['cost_usd']),
    inputTokens: parseInt(json['input_tokens']),
    outputTokens: parseInt(json['output_tokens']),
    errors: parseInt(json['errors']),
  );
}

class AiProviderUsage {
  final String provider;
  final String model;
  final int requests;
  final double costUsd;
  final int? avgLatencyMs;
  final int? p95LatencyMs;

  const AiProviderUsage({
    required this.provider,
    required this.model,
    this.requests = 0,
    this.costUsd = 0,
    this.avgLatencyMs,
    this.p95LatencyMs,
  });

  factory AiProviderUsage.fromJson(Map<String, dynamic> json) => AiProviderUsage(
    provider: json['provider'] as String? ?? '',
    model: json['model'] as String? ?? '',
    requests: parseInt(json['requests']),
    costUsd: parseDouble(json['cost_usd']),
    avgLatencyMs: json['avg_latency_ms'] == null ? null : parseInt(json['avg_latency_ms']),
    p95LatencyMs: json['p95_latency_ms'] == null ? null : parseInt(json['p95_latency_ms']),
  );
}

class AiDailyUsage {
  final String date;
  final int requests;
  final double costUsd;
  final Map<String, double> byFeature;

  const AiDailyUsage({required this.date, this.requests = 0, this.costUsd = 0, this.byFeature = const {}});

  factory AiDailyUsage.fromJson(Map<String, dynamic> json) {
    final raw = json['by_feature'];
    return AiDailyUsage(
      date: json['date'] as String? ?? '',
      requests: parseInt(json['requests']),
      costUsd: parseDouble(json['cost_usd']),
      byFeature: raw is Map ? {for (final e in raw.entries) '${e.key}': parseDouble(e.value)} : const {},
    );
  }
}

class AiTopUser {
  final String publicId;
  final String nickname;
  final int requests;
  final double costUsd;

  const AiTopUser({required this.publicId, required this.nickname, this.requests = 0, this.costUsd = 0});

  factory AiTopUser.fromJson(Map<String, dynamic> json) => AiTopUser(
    publicId: json['user_public_id'] as String? ?? '',
    nickname: json['nickname'] as String? ?? '',
    requests: parseInt(json['requests']),
    costUsd: parseDouble(json['cost_usd']),
  );
}

class AiUsageError {
  final DateTime? createdAt;
  final String feature;
  final String provider;
  final String errorCode;
  final String? model;
  final String? errorDetail;

  const AiUsageError({
    this.createdAt,
    required this.feature,
    required this.provider,
    required this.errorCode,
    this.model,
    this.errorDetail,
  });

  factory AiUsageError.fromJson(Map<String, dynamic> json) => AiUsageError(
    createdAt: parseDate(json['created_at']),
    feature: json['feature'] as String? ?? '',
    provider: json['provider'] as String? ?? '',
    errorCode: json['error_code'] as String? ?? '',
    model: (json['model'] as String?)?.trim().isEmpty ?? true ? null : json['model'] as String,
    errorDetail: (json['error_detail'] as String?)?.trim().isEmpty ?? true
        ? null
        : (json['error_detail'] as String).trim(),
  );
}

class AiUsageReport {
  final String period;
  final AiUsageSummary summary;
  final List<AiFeatureUsage> byFeature;
  final List<AiProviderUsage> byProvider;
  final List<AiDailyUsage> daily;
  final List<AiTopUser> topUsers;
  final List<AiUsageError> recentErrors;
  final int pendingReviews;
  final int unreviewedListings;

  const AiUsageReport({
    required this.period,
    required this.summary,
    this.byFeature = const [],
    this.byProvider = const [],
    this.daily = const [],
    this.topUsers = const [],
    this.recentErrors = const [],
    this.pendingReviews = 0,
    this.unreviewedListings = 0,
  });

  static List<T> _list<T>(Object? raw, T Function(Map<String, dynamic>) build) => [
    if (raw is List)
      for (final item in raw)
        if (item is Map) build(Map<String, dynamic>.from(item)),
  ];

  factory AiUsageReport.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'];
    return AiUsageReport(
      period: json['period'] as String? ?? 'month',
      summary: summary is Map ? AiUsageSummary.fromJson(Map<String, dynamic>.from(summary)) : const AiUsageSummary(),
      byFeature: _list(json['by_feature'], AiFeatureUsage.fromJson)..sort((a, b) => b.costUsd.compareTo(a.costUsd)),
      byProvider: _list(json['by_provider'], AiProviderUsage.fromJson)..sort((a, b) => b.costUsd.compareTo(a.costUsd)),
      daily: _list(json['daily'], AiDailyUsage.fromJson),
      topUsers: _list(json['top_users'], AiTopUser.fromJson),
      recentErrors: _list(json['recent_errors'], AiUsageError.fromJson),
      pendingReviews: parseInt(json['pending_reviews']),
      unreviewedListings: parseInt(json['unreviewed_listings']),
    );
  }
}

class AiOutcomes {
  const AiOutcomes._();

  static const ok = 'ok';
  static const repaired = 'repaired';
  static const degraded = 'degraded';
  static const empty = 'empty';
  static const refused = 'refused';
  static const failed = 'failed';

  static const all = [ok, repaired, degraded, empty, refused, failed];
}

Map<String, int> _countMap(Object? raw, {bool keepZero = false}) => {
  if (raw is Map)
    for (final e in raw.entries)
      if (keepZero || parseInt(e.value) > 0) '${e.key}': parseInt(e.value),
};

class AiFeatureDecisions {
  final String feature;
  final int total;
  final Map<String, int> outcomes;
  final Map<String, int> paths;
  final Map<String, int> flags;
  final Map<String, double> averages;

  const AiFeatureDecisions({
    required this.feature,
    this.total = 0,
    this.outcomes = const {},
    this.paths = const {},
    this.flags = const {},
    this.averages = const {},
  });

  double rateOf(int count) => total > 0 ? count / total : 0;

  factory AiFeatureDecisions.fromJson(Map<String, dynamic> json) {
    final averages = json['averages'];
    return AiFeatureDecisions(
      feature: json['feature'] as String? ?? '',
      total: parseInt(json['total']),
      outcomes: _countMap(json['outcomes']),
      paths: _countMap(json['paths']),
      // 旗標為 0 次代表比例為 0%，仍要顯示；沒有這項統計時伺服器不會回傳該鍵。
      flags: _countMap(json['flags'], keepZero: true),
      averages: averages is Map ? {for (final e in averages.entries) '${e.key}': parseDouble(e.value)} : const {},
    );
  }
}

class AiPromptVersionStat {
  final String feature;
  final String version;
  final int requests;
  final int errors;
  final int degraded;
  final DateTime? lastAt;

  const AiPromptVersionStat({required this.feature, required this.version, this.requests = 0, this.errors = 0, this.degraded = 0, this.lastAt});

  double get errorRate => requests > 0 ? errors / requests : 0;

  factory AiPromptVersionStat.fromJson(Map<String, dynamic> json) => AiPromptVersionStat(
    feature: json['feature'] as String? ?? '',
    version: json['prompt_version'] as String? ?? '',
    requests: parseInt(json['requests']),
    errors: parseInt(json['errors']),
    degraded: parseInt(json['degraded']),
    lastAt: parseDate(json['last_at']),
  );
}

class AiEmbeddingOrigin {
  static const index = 'index';
  static const unknown = 'unknown';

  final String origin;
  final int requests;
  final double costUsd;

  const AiEmbeddingOrigin({required this.origin, this.requests = 0, this.costUsd = 0});

  factory AiEmbeddingOrigin.fromJson(Map<String, dynamic> json) => AiEmbeddingOrigin(
    origin: json['origin'] as String? ?? unknown,
    requests: parseInt(json['requests']),
    costUsd: parseDouble(json['cost_usd']),
  );
}

class AiFormatErrorStat {
  final String feature;
  final String provider;
  final int requests;
  final int invalidOutput;
  final int incomplete;
  final int repaired;
  final int dropped;
  final int defaulted;

  const AiFormatErrorStat({
    required this.feature,
    required this.provider,
    this.requests = 0,
    this.invalidOutput = 0,
    this.incomplete = 0,
    this.repaired = 0,
    this.dropped = 0,
    this.defaulted = 0,
  });

  int get errors => invalidOutput + incomplete;
  double get errorRate => requests > 0 ? errors / requests : 0;

  factory AiFormatErrorStat.fromJson(Map<String, dynamic> json) => AiFormatErrorStat(
    feature: json['feature'] as String? ?? '',
    provider: json['provider'] as String? ?? '',
    requests: parseInt(json['requests']),
    invalidOutput: parseInt(json['invalid_output']),
    incomplete: parseInt(json['incomplete']),
    repaired: parseInt(json['repaired']),
    dropped: parseInt(json['dropped']),
    defaulted: parseInt(json['defaulted']),
  );
}

class AiDecisionReport {
  final String period;
  final List<AiFeatureDecisions> features;
  final List<AiPromptVersionStat> promptVersions;
  final List<AiEmbeddingOrigin> embeddingByOrigin;
  final List<AiFormatErrorStat> formatErrors;

  const AiDecisionReport({
    required this.period,
    this.features = const [],
    this.promptVersions = const [],
    this.embeddingByOrigin = const [],
    this.formatErrors = const [],
  });

  factory AiDecisionReport.fromJson(Map<String, dynamic> json) => AiDecisionReport(
    period: json['period'] as String? ?? 'month',
    features: AiUsageReport._list(json['features'], AiFeatureDecisions.fromJson),
    promptVersions: AiUsageReport._list(json['prompt_versions'], AiPromptVersionStat.fromJson),
    embeddingByOrigin: AiUsageReport._list(json['embedding_by_origin'], AiEmbeddingOrigin.fromJson),
    formatErrors: AiUsageReport._list(json['format_errors'], AiFormatErrorStat.fromJson),
  );
}

class AiChartSegment {
  final String feature;
  final double value;

  const AiChartSegment(this.feature, this.value);
}

class AiChartColumn {
  final String date;
  final double total;
  final int requests;
  final List<AiChartSegment> segments;

  const AiChartColumn({required this.date, required this.total, required this.requests, required this.segments});
}

class AiCostChartData {
  final List<AiChartColumn> columns;
  final List<String> features;
  final double axisMax;
  final double peak;

  const AiCostChartData({required this.columns, required this.features, required this.axisMax, required this.peak});

  bool get isEmpty => peak <= 0;

  static const _featureOrder = [
    AiFeatures.support,
    AiFeatures.listingAssist,
    AiFeatures.recommend,
    AiFeatures.moderation,
    AiFeatures.bookChat,
    AiFeatures.bookChatPick,
    AiFeatures.embedding,
    AiFeatures.enrich,
    AiFeatures.adminAssist,
    AiFeatures.test,
  ];

  factory AiCostChartData.from(List<AiDailyUsage> daily) {
    final present = <String>{};
    final columns = <AiChartColumn>[];
    var peak = 0.0;
    for (final day in daily) {
      final parts = <String, double>{
        for (final e in day.byFeature.entries)
          if (e.value > 0) e.key: e.value,
      };
      final partsTotal = parts.values.fold<double>(0, (a, b) => a + b);
      final total = math.max(day.costUsd, partsTotal);
      // 各功能加總可能因四捨五入略低於 cost_usd，差額另列一段，柱高才會等於當日總額。
      final remainder = total - partsTotal;
      if (remainder > total * 0.001 && remainder > 0) parts['other'] = (parts['other'] ?? 0) + remainder;
      present.addAll(parts.keys);
      final ordered = [
        for (final f in _featureOrder)
          if (parts.containsKey(f)) AiChartSegment(f, parts[f]!),
        for (final e in parts.entries)
          if (!_featureOrder.contains(e.key)) AiChartSegment(e.key, e.value),
      ];
      peak = math.max(peak, total);
      columns.add(AiChartColumn(date: day.date, total: total, requests: day.requests, segments: ordered));
    }
    final features = [
      for (final f in _featureOrder)
        if (present.contains(f)) f,
      for (final f in present)
        if (!_featureOrder.contains(f)) f,
    ];
    return AiCostChartData(columns: columns, features: features, axisMax: niceCeiling(peak), peak: peak);
  }

  static double niceCeiling(double value) {
    if (value <= 0) return 1;
    final exponent = (math.log(value) / math.ln10).floor();
    final base = math.pow(10, exponent).toDouble();
    for (final step in const [1.0, 2.0, 2.5, 5.0, 10.0]) {
      final candidate = step * base;
      if (candidate >= value * 0.999999) return double.parse(candidate.toStringAsPrecision(6));
    }
    return 10 * base;
  }

  List<int> labelIndices({int maxLabels = 7}) {
    final n = columns.length;
    if (n == 0) return const [];
    if (n <= maxLabels) return List.generate(n, (i) => i);
    final step = ((n - 1) / (maxLabels - 1)).ceil();
    final result = <int>[for (var i = 0; i < n; i += step) i];
    if (result.last != n - 1) {
      if (n - 1 - result.last < step / 2) result.removeLast();
      result.add(n - 1);
    }
    return result;
  }
}

String formatUsd(double value, {bool compact = false}) {
  if (value.isNaN) return 'US\$0';
  final negative = value < 0;
  final v = value.abs();
  String body;
  if (v == 0) {
    body = '0';
  } else if (v < 0.0001) {
    return '<US\$0.0001';
  } else if (v < 0.01) {
    body = v.toStringAsFixed(4);
  } else if (v < 1) {
    body = _trimZeros(v.toStringAsFixed(3), keep: 2);
  } else if (v < 1000 || !compact) {
    body = _group(v.toStringAsFixed(v >= 1000 ? 0 : 2));
  } else {
    body = '${_trimZeros((v / 1000).toStringAsFixed(1), keep: 0)}k';
  }
  return '${negative ? '-' : ''}US\$$body';
}

String formatUsdPrice(double value) {
  if (value == 0) return 'US\$0';
  if (value < 0.01) return 'US\$${_trimZeros(value.toStringAsFixed(4), keep: 2)}';
  return 'US\$${_trimZeros(value.toStringAsFixed(3), keep: 2)}';
}

String _trimZeros(String fixed, {required int keep}) {
  final dot = fixed.indexOf('.');
  if (dot < 0) return fixed;
  var end = fixed.length;
  while (end > dot + 1 + keep && fixed[end - 1] == '0') {
    end--;
  }
  if (end == dot + 1) end = dot;
  return fixed.substring(0, end);
}

String _group(String fixed) {
  final dot = fixed.indexOf('.');
  final whole = dot < 0 ? fixed : fixed.substring(0, dot);
  final fraction = dot < 0 ? '' : fixed.substring(dot);
  final buffer = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) buffer.write(',');
    buffer.write(whole[i]);
  }
  return '$buffer$fraction';
}

String formatTokens(int value) {
  if (value >= 1000000000) return '${_trimZeros((value / 1000000000).toStringAsFixed(2), keep: 0)}B';
  if (value >= 1000000) return '${_trimZeros((value / 1000000).toStringAsFixed(2), keep: 0)}M';
  if (value >= 10000) return '${_trimZeros((value / 1000).toStringAsFixed(1), keep: 0)}K';
  return _group('$value');
}

String formatCount(int value) => _group('$value');

// 同意畫面的說明內容變更時加一，並與 API 的 NOTICE_VERSION 一致，否則伺服器會拒絕同意。
const aiConsentNoticeVersion = 4;

// 與 API 的 SESSION_WINDOW_HOURS 一致：閒置超過此時間的客服對話已由伺服器結束，畫面須重新載入。
const aiSupportIdleLimit = Duration(hours: 6);

class AiStatusInfo {
  final bool support;
  final bool listingAssist;
  final bool recommend;
  final bool bookChat;
  final bool webSearch;
  final bool consented;
  final bool consentOutdated;
  final List<String> providersInUse;
  final String? embeddingProvider;

  const AiStatusInfo({
    this.support = false,
    this.listingAssist = false,
    this.recommend = false,
    this.bookChat = false,
    this.webSearch = false,
    this.consented = false,
    this.consentOutdated = false,
    this.providersInUse = const [],
    this.embeddingProvider,
  });

  static const none = AiStatusInfo();

  factory AiStatusInfo.fromJson(Map<String, dynamic> json) {
    final embedding = json['embedding_provider'];
    return AiStatusInfo(
      support: json['support'] == true,
      listingAssist: json['listing_assist'] == true,
      recommend: json['recommend'] == true,
      bookChat: json['book_chat'] == true,
      webSearch: json['web_search'] == true,
      consented: json['consented'] == true,
      consentOutdated: json['consent_outdated'] == true,
      providersInUse: [
        for (final p in json['providers_in_use'] is List ? json['providers_in_use'] as List : const [])
          if (p is String && p.trim().isNotEmpty) p.trim(),
      ],
      embeddingProvider: embedding is String && embedding.trim().isNotEmpty ? embedding.trim() : null,
    );
  }

  bool get any => support || listingAssist || recommend || bookChat;

  AiStatusInfo copyWith({bool? consented, bool? consentOutdated}) => AiStatusInfo(
    support: support,
    listingAssist: listingAssist,
    recommend: recommend,
    bookChat: bookChat,
    webSearch: webSearch,
    consented: consented ?? this.consented,
    consentOutdated: consentOutdated ?? (consented == true ? false : this.consentOutdated),
    providersInUse: providersInUse,
    embeddingProvider: embeddingProvider,
  );
}

String newAiClientId() {
  final random = math.Random.secure();
  return List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

String? _clientId(Object? raw) => raw is String && raw.isNotEmpty ? raw : null;

class AiMessageFeedback {
  final String rating;
  final String? reason;

  const AiMessageFeedback({required this.rating, this.reason});

  bool get helpful => rating == 'helpful';

  static AiMessageFeedback? fromJson(Object? raw) {
    if (raw is! Map || (raw['rating'] != 'helpful' && raw['rating'] != 'unhelpful')) return null;
    final reason = raw['reason'];
    return AiMessageFeedback(rating: raw['rating'] as String, reason: reason is String && reason.isNotEmpty ? reason : null);
  }
}

class AiSupportMessage {
  final int messageId;
  final String role;
  final String content;
  final String? clientId;
  final bool suggestHandoff;
  final bool degraded;
  final List<String> suggestions;
  final DateTime? createdAt;
  final List<String> orderNos;
  final String? messageNo;
  final AiMessageFeedback? feedback;

  const AiSupportMessage({
    required this.messageId,
    required this.role,
    required this.content,
    this.clientId,
    this.suggestHandoff = false,
    this.degraded = false,
    this.suggestions = const [],
    this.createdAt,
    this.orderNos = const [],
    this.messageNo,
    this.feedback,
  });

  bool get isUser => role == 'user';

  static final _orderNo = RegExp(r'^SMB\d{17}(?:\d{3})?$');

  factory AiSupportMessage.fromJson(Map<String, dynamic> json) {
    final isUser = json['role'] == 'user';
    final raw = json['order_nos'];
    return AiSupportMessage(
      messageId: parseInt(json['message_id']),
      role: isUser ? 'user' : 'assistant',
      content: json['content'] as String? ?? '',
      clientId: _clientId(json['client_id']),
      suggestHandoff: json['suggest_handoff'] == true,
      degraded: json['degraded'] == true,
      suggestions: _strings(json['suggestions']),
      createdAt: parseDate(json['created_at']),
      orderNos: isUser || raw is! List
          ? const []
          : raw.map((e) => '$e'.trim().toUpperCase()).where(_orderNo.hasMatch).toSet().take(3).toList(),
      messageNo: isUser ? null : _messageNo(json['message_no']),
      feedback: isUser ? null : AiMessageFeedback.fromJson(json['feedback']),
    );
  }
}

class AiSupportSession {
  final int sessionId;
  final String status;
  final List<AiSupportMessage> messages;

  const AiSupportSession({required this.sessionId, required this.status, this.messages = const []});

  factory AiSupportSession.fromJson(Map<String, dynamic> json) => AiSupportSession(
    sessionId: parseInt(json['session_id']),
    status: json['status'] as String? ?? 'open',
    messages: AiUsageReport._list(json['messages'], AiSupportMessage.fromJson),
  );
}

class AiSupportReply {
  final AiSupportMessage? userMessage;
  final AiSupportMessage reply;
  final bool suggestHandoff;

  const AiSupportReply({this.userMessage, required this.reply, this.suggestHandoff = false});

  factory AiSupportReply.fromJson(Map<String, dynamic> json) {
    final user = json['user_message'];
    final reply = json['reply'];
    return AiSupportReply(
      userMessage: user is Map ? AiSupportMessage.fromJson({...Map<String, dynamic>.from(user), 'role': 'user'}) : null,
      reply: AiSupportMessage.fromJson({
        ...(reply is Map ? Map<String, dynamic>.from(reply) : const <String, dynamic>{}),
        'role': 'assistant',
      }),
      suggestHandoff: json['suggest_handoff'] == true || (reply is Map && reply['suggest_handoff'] == true),
    );
  }
}

class AiBookSuggestion {
  final Book book;
  final String? reason;

  const AiBookSuggestion({required this.book, this.reason});

  static List<AiBookSuggestion> listFrom(Object? raw) {
    final out = <AiBookSuggestion>[];
    if (raw is! List) return out;
    for (final item in raw) {
      if (item is! Map || item['book'] is! Map) continue;
      try {
        final reason = '${item['reason'] ?? ''}'.trim();
        out.add(
          AiBookSuggestion(
            book: Book.fromJson(Map<String, dynamic>.from(item['book'])),
            reason: reason.isEmpty ? null : reason,
          ),
        );
      } catch (_) {}
    }
    return out;
  }
}

class AiBookChatMessage {
  final int messageId;
  final String role;
  final String content;
  final String? clientId;
  final List<AiBookSuggestion> books;
  final List<String> suggestions;
  final bool degraded;
  final DateTime? createdAt;
  final String? messageNo;
  final AiMessageFeedback? feedback;

  const AiBookChatMessage({
    required this.messageId,
    required this.role,
    required this.content,
    this.clientId,
    this.books = const [],
    this.suggestions = const [],
    this.degraded = false,
    this.createdAt,
    this.messageNo,
    this.feedback,
  });

  bool get isUser => role == 'user';

  factory AiBookChatMessage.fromJson(Map<String, dynamic> json) => AiBookChatMessage(
    messageId: parseInt(json['message_id']),
    role: json['role'] == 'user' ? 'user' : 'assistant',
    content: json['content'] as String? ?? '',
    clientId: _clientId(json['client_id']),
    books: AiBookSuggestion.listFrom(json['books']),
    suggestions: _strings(json['suggestions']),
    degraded: json['degraded'] == true,
    createdAt: parseDate(json['created_at']),
    messageNo: json['role'] == 'user' ? null : _messageNo(json['message_no']),
    feedback: json['role'] == 'user' ? null : AiMessageFeedback.fromJson(json['feedback']),
  );
}

String? _messageNo(Object? raw) {
  final value = raw is String ? raw.trim() : '';
  return value.isEmpty ? null : value;
}

class AiBookChatSession {
  final int sessionId;
  final List<AiBookChatMessage> messages;

  const AiBookChatSession({required this.sessionId, this.messages = const []});

  factory AiBookChatSession.fromJson(Map<String, dynamic> json) => AiBookChatSession(
    sessionId: parseInt(json['session_id']),
    messages: AiUsageReport._list(json['messages'], AiBookChatMessage.fromJson),
  );
}

class AiBookChatReply {
  final int sessionId;
  final AiBookChatMessage? userMessage;
  final AiBookChatMessage reply;

  const AiBookChatReply({required this.sessionId, this.userMessage, required this.reply});

  factory AiBookChatReply.fromJson(Map<String, dynamic> json) {
    final user = json['user_message'];
    final reply = json['reply'];
    return AiBookChatReply(
      sessionId: parseInt(json['session_id']),
      userMessage: user is Map
          ? AiBookChatMessage.fromJson({...Map<String, dynamic>.from(user), 'role': 'user'})
          : null,
      reply: AiBookChatMessage.fromJson({
        ...(reply is Map ? Map<String, dynamic>.from(reply) : const <String, dynamic>{}),
        'role': 'assistant',
      }),
    );
  }
}

class AiResult<T> {
  final T? data;
  final String? error;
  final String? code;
  final bool timedOut;

  const AiResult.ok(this.data) : error = null, code = null, timedOut = false;

  const AiResult.fail(this.error, {this.code, this.timedOut = false}) : data = null;

  bool get isOk => error == null;

  bool get inProgress => code == 'AI_REQUEST_IN_PROGRESS';

  bool get needsConsent => code == 'AI_CONSENT_REQUIRED';

  bool get isQuotaOrDisabled =>
      code == 'AI_DAILY_LIMIT' ||
      code == 'AI_DISABLED' ||
      code == 'AI_BUDGET_EXCEEDED' ||
      code == 'AI_NOT_CONFIGURED' ||
      code == 'AI_UNAVAILABLE';

  bool get isContentBlocked => code == 'AI_CONTENT_BLOCKED';

  bool get canRetry => !isQuotaOrDisabled && !isContentBlocked;
}

class AiCategoryGuess {
  final int categoryId;
  final String name;
  final double confidence;

  const AiCategoryGuess({required this.categoryId, required this.name, required this.confidence});

  factory AiCategoryGuess.fromJson(Map<String, dynamic> json) => AiCategoryGuess(
    categoryId: parseInt(json['category_id']),
    name: json['name'] as String? ?? '',
    confidence: parseDouble(json['confidence']).clamp(0.0, 1.0),
  );
}

class AiConditionGuess {
  final String level;
  final double confidence;
  final List<String> reasons;

  const AiConditionGuess({required this.level, required this.confidence, this.reasons = const []});

  factory AiConditionGuess.fromJson(Map<String, dynamic> json) => AiConditionGuess(
    level: json['level'] as String? ?? '',
    confidence: parseDouble(json['confidence']).clamp(0.0, 1.0),
    reasons: _strings(json['reasons']),
  );
}

int? _positiveInt(Object? v) {
  if (v == null) return null;
  final n = parseDouble(v).round();
  return n > 0 ? n : null;
}

class AiPriceGuess {
  final int suggested;
  final int? min;
  final int? max;
  final int? originalPrice;
  final bool originalPriceVerified;
  final List<String> reasons;
  final Map<String, int> byCondition;

  const AiPriceGuess({
    required this.suggested,
    this.min,
    this.max,
    this.originalPrice,
    this.originalPriceVerified = false,
    this.reasons = const [],
    this.byCondition = const {},
  });

  int suggestedFor(String? condition) => (condition == null ? null : byCondition[condition]) ?? suggested;

  factory AiPriceGuess.fromJson(Map<String, dynamic> json) {
    final table = json['by_condition'];
    return AiPriceGuess(
      suggested: parseDouble(json['suggested']).round(),
      min: _positiveInt(json['min']),
      max: _positiveInt(json['max']),
      originalPrice: _positiveInt(json['original_price']),
      originalPriceVerified: json['original_price_verified'] == true,
      reasons: _strings(json['reasons']),
      byCondition: {
        if (table is Map)
          for (final entry in table.entries)
            if (entry.value is Map && _positiveInt((entry.value as Map)['suggested']) != null)
              '${entry.key}': _positiveInt((entry.value as Map)['suggested'])!,
      },
    );
  }
}

class AiConditionRequest {
  final String author;
  final String publisher;
  final String publishDate;
  final int? categoryId;
  final int? originalPrice;
  final String? followupToken;

  const AiConditionRequest({
    this.author = '',
    this.publisher = '',
    this.publishDate = '',
    this.categoryId,
    this.originalPrice,
    this.followupToken,
  });
}

class AiListingCarry {
  final int? originalPrice;
  final Map<String, int> priceTable;
  final String? followupToken;

  const AiListingCarry({this.originalPrice, this.priceTable = const {}, this.followupToken});

  // 未經查證的定價若當成已知定價帶入，第二步會直接依它換算且不再搜尋。
  factory AiListingCarry.applied(AiListingAssist result, {String? followupToken}) {
    final price = result.price;
    return AiListingCarry(
      originalPrice: !result.isbnMismatch && price != null && price.originalPriceVerified ? price.originalPrice : null,
      priceTable: price?.byCondition ?? const {},
      followupToken: followupToken,
    );
  }

  AiListingCarry renewed({required bool sameBook, String? followupToken}) => AiListingCarry(
        originalPrice: sameBook ? originalPrice : null,
        priceTable: sameBook ? priceTable : const {},
        followupToken: followupToken ?? this.followupToken,
      );

  AiListingCarry withoutBook() => AiListingCarry(followupToken: followupToken);
}

class AiSource {
  final String title;
  final String url;
  final String domain;

  const AiSource({required this.title, required this.url, this.domain = ''});

  String get host => domain.isNotEmpty ? domain : Uri.tryParse(url)?.host.replaceFirst('www.', '') ?? '';

  factory AiSource.fromJson(Map<String, dynamic> json) => AiSource(
        title: json['title'] as String? ?? '',
        url: json['url'] as String? ?? '',
        domain: '${json['domain'] ?? ''}'.trim(),
      );
}

List<String> _strings(Object? raw) => [
  if (raw is List)
    for (final item in raw)
      if ('$item'.trim().isNotEmpty) '$item'.trim(),
];

class AiListingAssist {
  static const fieldKeys = [
    'title',
    'subtitle',
    'author',
    'publisher',
    'publish_date',
    'isbn',
    'page_count',
    'language',
    'description',
  ];

  final String publishDatePrecision;
  final String descriptionSource;
  final bool isbnMismatch;
  final Map<String, String> fields;
  final AiCategoryGuess? category;
  final AiConditionGuess? condition;
  final AiPriceGuess? price;
  final List<AiSource> sources;
  final List<String> warnings;
  final String provider;
  final String model;
  final String mode;
  final String? followupToken;
  final String? suggestionToken;

  const AiListingAssist({
    this.mode = 'full',
    this.followupToken,
    this.fields = const {},
    this.publishDatePrecision = '',
    this.descriptionSource = '',
    this.isbnMismatch = false,
    this.category,
    this.condition,
    this.price,
    this.sources = const [],
    this.warnings = const [],
    this.provider = '',
    this.model = '',
    this.suggestionToken,
  });

  bool get publishDateIsApproximate => publishDatePrecision.isNotEmpty && publishDatePrecision != 'day';

  bool get descriptionWrittenByAi => descriptionSource == 'ai';

  factory AiListingAssist.fromJson(Map<String, dynamic> json) {
    final fields = json['fields'];
    final category = json['category'];
    final condition = json['condition'];
    final price = json['price'];
    final parsedCategory = category is Map ? AiCategoryGuess.fromJson(Map<String, dynamic>.from(category)) : null;
    final parsedCondition = condition is Map ? AiConditionGuess.fromJson(Map<String, dynamic>.from(condition)) : null;
    final parsedPrice = price is Map ? AiPriceGuess.fromJson(Map<String, dynamic>.from(price)) : null;
    final token = '${json['followup_token'] ?? ''}'.trim();
    return AiListingAssist(
      mode: '${json['mode'] ?? 'full'}',
      followupToken: token.isEmpty ? null : token,
      fields: {
        for (final key in fieldKeys)
          if (fields is Map && '${fields[key] ?? ''}'.trim().isNotEmpty) key: '${fields[key]}'.trim(),
      },
      publishDatePrecision: fields is Map ? '${fields['publish_date_precision'] ?? ''}'.trim() : '',
      descriptionSource: '${json['description_source'] ?? ''}'.trim(),
      isbnMismatch: json['isbn_mismatch'] == true,
      category: parsedCategory != null && parsedCategory.categoryId > 0 ? parsedCategory : null,
      condition: parsedCondition != null && parsedCondition.level.isNotEmpty ? parsedCondition : null,
      price: parsedPrice != null && parsedPrice.suggested > 0 ? parsedPrice : null,
      sources: [
        for (final s in AiUsageReport._list(json['sources'], AiSource.fromJson))
          if (s.url.startsWith('http')) s,
      ],
      warnings: _strings(json['warnings']),
      provider: json['provider'] as String? ?? '',
      model: json['model'] as String? ?? '',
      suggestionToken: _messageNo(json['suggestion_token']),
    );
  }

  bool get isEmpty => fields.isEmpty && category == null && condition == null && price == null;
}

class RecommendationGroup {
  final String kind;
  final String? relation;
  final String? title;
  final String? category;
  final List<Book> books;
  final Map<int, String> reasons;

  const RecommendationGroup({
    required this.kind,
    required this.books,
    this.relation,
    this.title,
    this.category,
    this.reasons = const {},
  });
}

class AiRecommendations {
  final List<Book> books;
  final List<RecommendationGroup> groups;
  final String source;
  final bool refreshing;

  const AiRecommendations({this.books = const [], this.groups = const [], this.source = 'fallback', this.refreshing = false});

  factory AiRecommendations.fromJson(Map<String, dynamic> payload) {
    final books = <Book>[];
    final reasons = <int, String>{};
    final data = payload['data'];
    if (data is List) {
      for (final item in data) {
        if (item is! Map || item['book'] is! Map) continue;
        try {
          final book = Book.fromJson(Map<String, dynamic>.from(item['book']));
          books.add(book);
          final reason = '${item['reason'] ?? ''}'.trim();
          if (reason.isNotEmpty) reasons[book.bookId] = reason;
        } catch (_) {}
      }
    }
    final byId = {for (final b in books) b.bookId: b};
    Map<int, String> reasonsOf(List<Book> members) => {
          for (final b in members)
            if (reasons.containsKey(b.bookId)) b.bookId: reasons[b.bookId]!,
        };
    final groups = <RecommendationGroup>[];
    final rawGroups = payload['groups'];
    if (rawGroups is List) {
      for (final g in rawGroups) {
        if (g is! Map) continue;
        final ids = g['book_ids'] is List ? (g['book_ids'] as List).map(parseInt) : const <int>[];
        final members = [for (final id in ids) ?byId[id]];
        if (members.isEmpty) continue;
        groups.add(RecommendationGroup(
          kind: '${g['kind'] ?? 'more'}',
          relation: g['relation'] as String?,
          title: g['title'] as String?,
          category: g['category'] as String?,
          books: members,
          reasons: reasonsOf(members),
        ));
      }
    }
    if (groups.isEmpty && books.isNotEmpty) groups.add(RecommendationGroup(kind: 'more', books: books, reasons: reasonsOf(books)));
    final meta = payload['meta'];
    return AiRecommendations(
      books: books,
      groups: groups,
      source: meta is Map && meta['source'] == 'ai' ? 'ai' : 'fallback',
      refreshing: meta is Map && meta['refreshing'] == true,
    );
  }
}

class AiReviewOpinion {
  final String verdict;
  final List<String> reasons;
  final List<String> categories;
  final double? confidence;

  const AiReviewOpinion({required this.verdict, this.reasons = const [], this.categories = const [], this.confidence});

  static AiReviewOpinion? fromJson(Object? raw) {
    if (raw is! Map || raw['verdict'] is! String) return null;
    final verdict = raw['verdict'] as String;
    if (!const ['allow', 'review', 'reject'].contains(verdict)) return null;
    return AiReviewOpinion(
      verdict: verdict,
      reasons: _strings(raw['reasons']),
      categories: _strings(raw['categories']),
      confidence: raw['confidence'] == null ? null : parseDouble(raw['confidence']).clamp(0.0, 1.0),
    );
  }
}

class AiReviewItem {
  final int bookId;
  final String title;
  final String? imageUrl;
  final double price;
  final String sellerName;
  final String verdict;
  final List<String> reasons;
  final List<String> categories;
  final String status;
  final DateTime? createdAt;
  final bool byRules;
  final AiReviewOpinion? aiOpinion;
  final List<String> imageUrls;
  final String description;
  final String conditionNote;
  final String conditionLevel;
  final double? confidence;

  const AiReviewItem({
    required this.bookId,
    required this.title,
    this.imageUrl,
    this.price = 0,
    this.sellerName = '',
    this.verdict = 'review',
    this.reasons = const [],
    this.categories = const [],
    this.status = 'pending',
    this.createdAt,
    this.byRules = false,
    this.aiOpinion,
    this.imageUrls = const [],
    this.description = '',
    this.conditionNote = '',
    this.conditionLevel = '',
    this.confidence,
  });

  factory AiReviewItem.fromJson(Map<String, dynamic> json) {
    final book = json['book'] is Map ? Map<String, dynamic>.from(json['book']) : json;
    final seller = json['seller'] is Map
        ? json['seller'] as Map
        : (book['seller'] is Map ? book['seller'] as Map : (book['users'] is Map ? book['users'] as Map : null));
    String? image = book['image_url'] as String? ?? book['cover_url'] as String?;
    final images = book['book_images'];
    final urls = <String>[
      if (images is List)
        for (final item in images)
          if ((item is Map ? item['image_url'] : item) case final String url when url.isNotEmpty) ?resolveAssetUrl(url),
    ];
    if (image == null && urls.isNotEmpty) image = urls.first;
    return AiReviewItem(
      bookId: parseInt(json['book_id'] ?? book['book_id']),
      title: book['title'] as String? ?? '',
      imageUrl: resolveAssetUrl(image),
      price: parseDouble(book['price']),
      sellerName: seller?['nickname'] as String? ?? '',
      verdict: json['verdict'] as String? ?? 'review',
      reasons: _decodeList(json['reasons']),
      categories: _decodeList(json['categories']),
      status: json['status'] as String? ?? 'pending',
      createdAt: parseDate(json['created_at']),
      byRules: json['origin'] == 'rules' || json['model'] == 'rules',
      aiOpinion: AiReviewOpinion.fromJson(json['ai_opinion']),
      imageUrls: urls,
      description: '${book['description'] ?? ''}'.trim(),
      conditionNote: '${book['condition_note'] ?? ''}'.trim(),
      conditionLevel: '${book['condition_level'] ?? ''}',
      confidence: json['confidence'] == null ? null : parseDouble(json['confidence']).clamp(0.0, 1.0),
    );
  }

  static List<String> _decodeList(Object? raw) {
    if (raw is String && raw.trim().startsWith('[')) {
      try {
        return _strings(jsonDecode(raw));
      } catch (_) {}
    }
    if (raw is String && raw.trim().isNotEmpty) return [raw.trim()];
    return _strings(raw);
  }
}

class ListingOutcome {
  final String? error;
  final String? code;
  final List<String> reasons;
  final bool pendingReview;

  const ListingOutcome({this.error, this.code, this.reasons = const [], this.pendingReview = false});

  bool get isOk => error == null;

  bool get isRejected => code == 'LISTING_REJECTED';

  factory ListingOutcome.fromResponse(Map<String, dynamic>? res, {required String fallbackError}) {
    if (res == null) return ListingOutcome(error: fallbackError);
    if (res['success'] != true) {
      final message = res['message'] as String? ?? fallbackError;
      final code = res['code'] as String?;
      var reasons = _strings(res['reasons']);
      final data = res['data'];
      if (reasons.isEmpty && data is Map) reasons = _strings(data['reasons']);
      if (reasons.isEmpty && code == 'LISTING_REJECTED') {
        final split = message.split(RegExp('[：:]'));
        if (split.length > 1) reasons = _strings(split.sublist(1).join('：').split('、'));
      }
      return ListingOutcome(error: message, code: code, reasons: reasons);
    }
    Object? moderation = res['moderation'];
    final data = res['data'];
    if (moderation is! Map && data is Map) moderation = data['moderation'];
    if (moderation is Map && moderation['status'] == 'pending_review') {
      return ListingOutcome(pendingReview: true, reasons: _strings(moderation['reasons']));
    }
    return const ListingOutcome();
  }
}
