import '../../../models/ai.dart';

enum AiFieldKind { decimal, integer, model }

class AiFieldSpec {
  final String key;
  final AiFieldKind kind;
  final double max;

  const AiFieldSpec(this.key, this.kind, this.max);
}

class AiSettingsForm {
  static final _modelPattern = RegExp(r'^[A-Za-z0-9._:\-/]{1,80}$');

  static const priceKeys = ['input_per_m', 'cached_input_per_m', 'output_per_m'];
  static const searchKeys = ['search_price_per_k', 'search_free_per_month'];

  static List<AiFieldSpec> get specs => [
        const AiFieldSpec('budget', AiFieldKind.decimal, 100000),
        for (final f in AiFeatures.limited) AiFieldSpec('limit.$f', AiFieldKind.integer, 10000),
        for (final id in AiProviders.ids) ...[
          AiFieldSpec('$id.model', AiFieldKind.model, 0),
          for (final k in priceKeys) AiFieldSpec('$id.$k', AiFieldKind.decimal, 1000),
          AiFieldSpec('$id.search_price_per_k', AiFieldKind.decimal, 1000),
          AiFieldSpec('$id.search_free_per_month', AiFieldKind.integer, 1000000),
        ],
      ];

  AiSettings _saved;
  AiSettings _draft;
  final Map<String, String> _invalid = {};

  AiSettingsForm(AiSettings settings)
      : _saved = settings,
        _draft = settings;

  AiSettings get saved => _saved;
  AiSettings get draft => _draft;

  bool get hasErrors => _invalid.isNotEmpty;
  int get errorCount => _invalid.length;
  bool isInvalid(String key) => _invalid.containsKey(key);

  bool get isDirty => hasErrors || _draft.fingerprint != _saved.fingerprint;

  List<String> get changedSections => _draft.changedSections(_saved);

  void update(AiSettings next) => _draft = next;

  void reset() {
    _draft = _saved;
    _invalid.clear();
  }

  void markSaved(AiSettings settings) {
    _saved = settings;
    _draft = settings;
    _invalid.clear();
  }

  static String formatNumber(num value) {
    if (value is int || value == value.roundToDouble()) return value.round().toString();
    var text = value.toStringAsFixed(6);
    text = text.replaceFirst(RegExp(r'0+$'), '');
    return text.endsWith('.') ? text.substring(0, text.length - 1) : text;
  }

  String textFor(String key) {
    final s = _draft;
    if (key == 'budget') return formatNumber(s.monthlyBudgetUsd);
    if (key.startsWith('limit.')) return '${s.dailyPerUser[key.substring(6)] ?? 0}';
    final dot = key.indexOf('.');
    final pricing = s.providers[key.substring(0, dot)]!;
    return switch (key.substring(dot + 1)) {
      'model' => pricing.model,
      'input_per_m' => formatNumber(pricing.inputPerM),
      'cached_input_per_m' => formatNumber(pricing.cachedInputPerM),
      'output_per_m' => formatNumber(pricing.outputPerM),
      'search_price_per_k' => formatNumber(pricing.searchPricePerK),
      'search_free_per_month' => '${pricing.searchFreePerMonth}',
      _ => '',
    };
  }

  static AiFieldSpec? specFor(String key) {
    for (final spec in specs) {
      if (spec.key == key) return spec;
    }
    return null;
  }

  String? setText(String key, String raw) {
    final spec = specFor(key);
    if (spec == null) return null;
    final text = raw.trim();
    String? problem;
    num? number;
    switch (spec.kind) {
      case AiFieldKind.model:
        if (text.isEmpty) {
          problem = 'required';
        } else if (!_modelPattern.hasMatch(text)) {
          problem = 'format';
        }
      case AiFieldKind.integer:
        number = int.tryParse(text);
        if (text.isEmpty) {
          problem = 'required';
        } else if (number == null) {
          problem = 'format';
        } else if (number < 0 || number > spec.max) {
          problem = 'range';
        }
      case AiFieldKind.decimal:
        number = double.tryParse(text);
        if (text.isEmpty) {
          problem = 'required';
        } else if (number == null || number.isNaN || number.isInfinite) {
          problem = 'format';
        } else if (number < 0 || number > spec.max) {
          problem = 'range';
        }
    }
    if (problem != null) {
      _invalid[key] = problem;
      return problem;
    }
    _invalid.remove(key);
    _apply(key, text, number);
    return null;
  }

  void _apply(String key, String text, num? number) {
    final s = _draft;
    if (key == 'budget') {
      _draft = s.copyWith(monthlyBudgetUsd: number!.toDouble());
      return;
    }
    if (key.startsWith('limit.')) {
      _draft = s.withDailyLimit(key.substring(6), number!.toInt());
      return;
    }
    final dot = key.indexOf('.');
    final id = key.substring(0, dot);
    final p = s.providers[id]!;
    final next = switch (key.substring(dot + 1)) {
      'model' => p.copyWith(model: text),
      'input_per_m' => p.copyWith(inputPerM: number!.toDouble()),
      'cached_input_per_m' => p.copyWith(cachedInputPerM: number!.toDouble()),
      'output_per_m' => p.copyWith(outputPerM: number!.toDouble()),
      'search_price_per_k' => p.copyWith(searchPricePerK: number!.toDouble()),
      'search_free_per_month' => p.copyWith(searchFreePerMonth: number!.toInt()),
      _ => p,
    };
    _draft = s.withProvider(id, next);
  }

  void resetProvider(String id) {
    final defaults = AiProviderPricing.defaults[id]!;
    _draft = _draft.withProvider(id, defaults);
    _invalid.removeWhere((key, _) => key.startsWith('$id.'));
  }
}
