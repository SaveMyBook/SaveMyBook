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
  static const test = 'test';

  static const configurable = [support, listingAssist, recommend, moderation];

  static const limited = [support, listingAssist, recommend];
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
    AiProviders.deepseek: AiProviderPricing(model: 'deepseek-flash', inputPerM: 0.14, cachedInputPerM: 0.0028, outputPerM: 0.28),
    AiProviders.gemini: AiProviderPricing(
        model: 'gemini-3.1-flash-lite', inputPerM: 0.25, cachedInputPerM: 0.025, outputPerM: 1.5, searchPricePerK: 14, searchFreePerMonth: 5000),
    AiProviders.openai: AiProviderPricing(model: 'gpt-5-nano', inputPerM: 0.05, cachedInputPerM: 0.005, outputPerM: 0.4, searchPricePerK: 10),
  };

  factory AiProviderPricing.fromJson(Map<String, dynamic>? json, AiProviderPricing fallback) {
    if (json == null) return fallback;
    final model = (json['model'] as String?)?.trim();
    return AiProviderPricing(
      model: model == null || model.isEmpty ? fallback.model : model,
      inputPerM: json.containsKey('input_per_m') ? _clampNonNegative(json['input_per_m']) : fallback.inputPerM,
      cachedInputPerM: json.containsKey('cached_input_per_m') ? _clampNonNegative(json['cached_input_per_m']) : fallback.cachedInputPerM,
      outputPerM: json.containsKey('output_per_m') ? _clampNonNegative(json['output_per_m']) : fallback.outputPerM,
      searchPricePerK: json.containsKey('search_price_per_k') ? _clampNonNegative(json['search_price_per_k']) : fallback.searchPricePerK,
      searchFreePerMonth: json.containsKey('search_free_per_month') ? math.max(0, parseInt(json['search_free_per_month'])) : fallback.searchFreePerMonth,
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
  }) =>
      AiProviderPricing(
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
  final bool webSearch;
  final String action;

  const AiFeatureConfig({this.enabled = true, this.provider, this.webSearch = false, this.action = 'review'});

  static const defaults = <String, AiFeatureConfig>{
    AiFeatures.support: AiFeatureConfig(),
    AiFeatures.listingAssist: AiFeatureConfig(provider: AiProviders.gemini, webSearch: true),
    AiFeatures.recommend: AiFeatureConfig(),
    AiFeatures.moderation: AiFeatureConfig(),
  };

  factory AiFeatureConfig.fromJson(Map<String, dynamic>? json, AiFeatureConfig fallback) {
    if (json == null) return fallback;
    final provider = json['provider'];
    return AiFeatureConfig(
      enabled: json.containsKey('enabled') ? json['enabled'] == true : fallback.enabled,
      provider: provider is String && AiProviders.ids.contains(provider) ? provider : (json.containsKey('provider') ? null : fallback.provider),
      webSearch: json.containsKey('web_search') ? json['web_search'] == true : fallback.webSearch,
      action: json['action'] == 'block' ? 'block' : (json['action'] == 'review' ? 'review' : fallback.action),
    );
  }

  Map<String, dynamic> toJson(String feature) => {
        'enabled': enabled,
        'provider': provider,
        if (feature == AiFeatures.listingAssist) 'web_search': webSearch,
        if (feature == AiFeatures.moderation) 'action': action,
      };

  AiFeatureConfig copyWith({bool? enabled, String? Function()? provider, bool? webSearch, String? action}) => AiFeatureConfig(
        enabled: enabled ?? this.enabled,
        provider: provider == null ? this.provider : provider(),
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
  final Map<String, int> dailyPerUser;

  const AiSettings({
    required this.enabled,
    required this.defaultProvider,
    required this.providers,
    required this.features,
    required this.monthlyBudgetUsd,
    required this.dailyPerUser,
  });

  static const _defaultLimits = {AiFeatures.support: 30, AiFeatures.listingAssist: 15, AiFeatures.recommend: 5};

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
      defaultProvider: defaultProvider is String && AiProviders.ids.contains(defaultProvider) ? defaultProvider : AiProviders.deepseek,
      providers: {
        for (final id in AiProviders.ids)
          id: AiProviderPricing.fromJson(section(json['providers'], id), AiProviderPricing.defaults[id]!),
      },
      features: {
        for (final f in AiFeatures.configurable)
          f: AiFeatureConfig.fromJson(section(json['features'], f), AiFeatureConfig.defaults[f]!),
      },
      monthlyBudgetUsd: limits.containsKey('monthly_budget_usd') ? _clampNonNegative(limits['monthly_budget_usd']) : 10,
      dailyPerUser: {
        for (final entry in _defaultLimits.entries)
          entry.key: daily is Map && daily.containsKey(entry.key) ? math.max(0, parseInt(daily[entry.key])) : entry.value,
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
    Map<String, int>? dailyPerUser,
  }) =>
      AiSettings(
        enabled: enabled ?? this.enabled,
        defaultProvider: defaultProvider ?? this.defaultProvider,
        providers: providers ?? this.providers,
        features: features ?? this.features,
        monthlyBudgetUsd: monthlyBudgetUsd ?? this.monthlyBudgetUsd,
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

class AiSettingsBundle {
  final AiSettings settings;
  final List<AiProviderInfo> providers;
  final bool migrationReady;

  const AiSettingsBundle({required this.settings, required this.providers, required this.migrationReady});

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
      migrationReady: json['migration_ready'] != false,
    );
  }

  AiProviderInfo provider(String id) => providers.firstWhere((p) => p.id == id);
}

class AiTestResult {
  final bool ok;
  final String provider;
  final String model;
  final int latencyMs;
  final String? reply;
  final String? error;

  const AiTestResult({required this.ok, required this.provider, required this.model, required this.latencyMs, this.reply, this.error});

  factory AiTestResult.fromJson(Map<String, dynamic> json) => AiTestResult(
        ok: json['ok'] == true,
        provider: json['provider'] as String? ?? '',
        model: json['model'] as String? ?? '',
        latencyMs: parseInt(json['latency_ms']),
        reply: json['reply'] as String?,
        error: json['error'] as String?,
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
      budgetUsedRatio: json['budget_used_ratio'] != null ? parseDouble(json['budget_used_ratio']) : (budget > 0 ? month / budget : 0),
      projectedMonthCostUsd: parseDouble(json['projected_month_cost_usd']),
    );
  }

  int get totalTokens => inputTokens + outputTokens;

  double get errorRate => requests == 0 ? 0 : errors / requests;
}

class AiFeatureUsage {
  final String feature;
  final int requests;
  final double costUsd;
  final int inputTokens;
  final int outputTokens;
  final int errors;

  const AiFeatureUsage({required this.feature, this.requests = 0, this.costUsd = 0, this.inputTokens = 0, this.outputTokens = 0, this.errors = 0});

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
  final int avgLatencyMs;

  const AiProviderUsage({required this.provider, required this.model, this.requests = 0, this.costUsd = 0, this.avgLatencyMs = 0});

  factory AiProviderUsage.fromJson(Map<String, dynamic> json) => AiProviderUsage(
        provider: json['provider'] as String? ?? '',
        model: json['model'] as String? ?? '',
        requests: parseInt(json['requests']),
        costUsd: parseDouble(json['cost_usd']),
        avgLatencyMs: parseInt(json['avg_latency_ms']),
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

  const AiUsageError({this.createdAt, required this.feature, required this.provider, required this.errorCode});

  factory AiUsageError.fromJson(Map<String, dynamic> json) => AiUsageError(
        createdAt: parseDate(json['created_at']),
        feature: json['feature'] as String? ?? '',
        provider: json['provider'] as String? ?? '',
        errorCode: json['error_code'] as String? ?? '',
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

  const AiUsageReport({
    required this.period,
    required this.summary,
    this.byFeature = const [],
    this.byProvider = const [],
    this.daily = const [],
    this.topUsers = const [],
    this.recentErrors = const [],
    this.pendingReviews = 0,
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
    );
  }
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

  static const _featureOrder = [AiFeatures.support, AiFeatures.listingAssist, AiFeatures.recommend, AiFeatures.moderation, AiFeatures.test];

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

class AiStatusInfo {
  final bool support;
  final bool listingAssist;
  final bool recommend;
  final bool webSearch;
  final bool consented;
  final List<String> providersInUse;

  const AiStatusInfo({
    this.support = false,
    this.listingAssist = false,
    this.recommend = false,
    this.webSearch = false,
    this.consented = false,
    this.providersInUse = const [],
  });

  static const none = AiStatusInfo();

  factory AiStatusInfo.fromJson(Map<String, dynamic> json) => AiStatusInfo(
        support: json['support'] == true,
        listingAssist: json['listing_assist'] == true,
        recommend: json['recommend'] == true,
        webSearch: json['web_search'] == true,
        consented: json['consented'] == true,
        providersInUse: [
          for (final p in json['providers_in_use'] is List ? json['providers_in_use'] as List : const [])
            if (p is String && p.trim().isNotEmpty) p.trim(),
        ],
      );

  bool get any => support || listingAssist || recommend;

  AiStatusInfo copyWith({bool? consented}) => AiStatusInfo(
        support: support,
        listingAssist: listingAssist,
        recommend: recommend,
        webSearch: webSearch,
        consented: consented ?? this.consented,
        providersInUse: providersInUse,
      );
}

class AiSupportMessage {
  final int messageId;
  final String role;
  final String content;
  final DateTime? createdAt;

  const AiSupportMessage({required this.messageId, required this.role, required this.content, this.createdAt});

  bool get isUser => role == 'user';

  factory AiSupportMessage.fromJson(Map<String, dynamic> json) => AiSupportMessage(
        messageId: parseInt(json['message_id']),
        role: json['role'] == 'user' ? 'user' : 'assistant',
        content: json['content'] as String? ?? '',
        createdAt: parseDate(json['created_at']),
      );
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
      reply: AiSupportMessage.fromJson({...(reply is Map ? Map<String, dynamic>.from(reply) : const <String, dynamic>{}), 'role': 'assistant'}),
      suggestHandoff: json['suggest_handoff'] == true,
    );
  }
}

class AiResult<T> {
  final T? data;
  final String? error;
  final String? code;

  const AiResult.ok(this.data)
      : error = null,
        code = null;

  const AiResult.fail(this.error, {this.code}) : data = null;

  bool get isOk => error == null;

  bool get needsConsent => code == 'AI_CONSENT_REQUIRED';

  bool get isQuotaOrDisabled => code == 'AI_DAILY_LIMIT' || code == 'AI_DISABLED' || code == 'AI_BUDGET_EXCEEDED' || code == 'AI_NOT_CONFIGURED' || code == 'AI_UNAVAILABLE';
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

class AiPriceGuess {
  final int suggested;
  final int? min;
  final int? max;
  final int? originalPrice;
  final List<String> reasons;

  const AiPriceGuess({required this.suggested, this.min, this.max, this.originalPrice, this.reasons = const []});

  factory AiPriceGuess.fromJson(Map<String, dynamic> json) {
    int? optional(Object? v) {
      if (v == null) return null;
      final n = parseDouble(v).round();
      return n > 0 ? n : null;
    }

    return AiPriceGuess(
      suggested: parseDouble(json['suggested']).round(),
      min: optional(json['min']),
      max: optional(json['max']),
      originalPrice: optional(json['original_price']),
      reasons: _strings(json['reasons']),
    );
  }
}

class AiSource {
  final String title;
  final String url;

  const AiSource({required this.title, required this.url});

  String get host => Uri.tryParse(url)?.host.replaceFirst('www.', '') ?? '';

  factory AiSource.fromJson(Map<String, dynamic> json) => AiSource(title: json['title'] as String? ?? '', url: json['url'] as String? ?? '');
}

List<String> _strings(Object? raw) => [
      if (raw is List)
        for (final item in raw)
          if ('$item'.trim().isNotEmpty) '$item'.trim(),
    ];

class AiListingAssist {
  static const fieldKeys = ['title', 'author', 'publisher', 'publish_date', 'isbn', 'description'];

  final Map<String, String> fields;
  final AiCategoryGuess? category;
  final AiConditionGuess? condition;
  final AiPriceGuess? price;
  final List<AiSource> sources;
  final List<String> warnings;
  final String provider;
  final String model;

  const AiListingAssist({
    this.fields = const {},
    this.category,
    this.condition,
    this.price,
    this.sources = const [],
    this.warnings = const [],
    this.provider = '',
    this.model = '',
  });

  factory AiListingAssist.fromJson(Map<String, dynamic> json) {
    final fields = json['fields'];
    final category = json['category'];
    final condition = json['condition'];
    final price = json['price'];
    final parsedCategory = category is Map ? AiCategoryGuess.fromJson(Map<String, dynamic>.from(category)) : null;
    final parsedCondition = condition is Map ? AiConditionGuess.fromJson(Map<String, dynamic>.from(condition)) : null;
    final parsedPrice = price is Map ? AiPriceGuess.fromJson(Map<String, dynamic>.from(price)) : null;
    return AiListingAssist(
      fields: {
        for (final key in fieldKeys)
          if (fields is Map && '${fields[key] ?? ''}'.trim().isNotEmpty) key: '${fields[key]}'.trim(),
      },
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
    );
  }

  bool get isEmpty => fields.isEmpty && category == null && condition == null && price == null;
}

class AiRecommendations {
  final List<Book> books;
  final Map<int, String> reasons;
  final String source;

  const AiRecommendations({this.books = const [], this.reasons = const {}, this.source = 'fallback'});

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
    final meta = payload['meta'];
    return AiRecommendations(books: books, reasons: reasons, source: meta is Map && meta['source'] == 'ai' ? 'ai' : 'fallback');
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
  });

  factory AiReviewItem.fromJson(Map<String, dynamic> json) {
    final book = json['book'] is Map ? Map<String, dynamic>.from(json['book']) : json;
    final seller = json['seller'] is Map ? json['seller'] as Map : (book['seller'] is Map ? book['seller'] as Map : (book['users'] is Map ? book['users'] as Map : null));
    String? image = book['image_url'] as String? ?? book['cover_url'] as String?;
    final images = book['book_images'];
    if (image == null && images is List && images.isNotEmpty) {
      final first = images.first;
      image = first is Map ? first['image_url'] as String? : '$first';
    }
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
