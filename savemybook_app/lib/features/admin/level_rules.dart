import '../../models/admin_models.dart';
import '../../i18n/strings.dart';

class LevelSlot {
  final int? levelId;
  final String name;
  final int minPoints;
  final int? maxPoints;
  final bool isDraft;

  const LevelSlot({
    required this.levelId,
    required this.name,
    required this.minPoints,
    required this.maxPoints,
    this.isDraft = false,
  });
}

class LevelThresholdChange {
  final AdminLevel level;
  final int from;
  final int to;

  const LevelThresholdChange(this.level, this.from, this.to);
}

class LevelRules {
  const LevelRules._();

  static const maxPoints = 100000000;
  static const nameMaxLength = 50;
  static const benefitsMaxLength = 2000;

  static List<AdminLevel> sorted(Iterable<AdminLevel> levels) =>
      [...levels]..sort((a, b) {
        final byPoints = a.minPoints.compareTo(b.minPoints);
        return byPoints != 0 ? byPoints : a.levelId.compareTo(b.levelId);
      });

  static List<String> benefitsOf(String raw) => raw
      .trim()
      .split(RegExp(r'[\n、;；,，]+'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  static String rangeLabel(int minPoints, int? maxPoints) =>
      maxPoints == null ? S.p0Pts(minPoints) : S.p0P1Pts(minPoints, maxPoints);

  static List<AdminLevel> _others(List<AdminLevel> levels, int? editingId) =>
      levels.where((l) => l.levelId != editingId).toList();

  /// 起始等級（唯一門檻為 0 點者）的門檻不可調整，否則會有會員沒有對應等級。
  static bool isThresholdLocked(List<AdminLevel> levels, {int? editingId}) {
    final others = _others(levels, editingId);
    if (others.isEmpty) return true;
    if (editingId == null) return false;
    final self = levels.where((l) => l.levelId == editingId).firstOrNull;
    return self != null && self.minPoints == 0 && !others.any((l) => l.minPoints == 0);
  }

  static String? nameError(String name, List<AdminLevel> levels, {int? editingId}) {
    final value = name.trim();
    if (value.isEmpty) return S.enterTierName;
    final clash = _others(levels, editingId).where((l) => l.name.trim().toLowerCase() == value.toLowerCase());
    if (clash.isNotEmpty) return S.tierNamedP0AlreadyExists(value);
    return null;
  }

  static String? pointsError(String text, List<AdminLevel> levels, {int? editingId}) {
    final value = text.trim();
    if (value.isEmpty) return S.enterPointsThreshold;
    final points = int.tryParse(value);
    if (points == null || points < 0) return S.thresholdMustWholeNumber0More;
    if (points > maxPoints) return S.thresholdCannotExceedP0(maxPoints);

    final others = _others(levels, editingId);
    final clash = others.where((l) => l.minPoints == points).firstOrNull;
    if (clash != null) return S.p0AlreadyUsesP1PtsEach(clash.name, points);
    final lowest = others.fold<int>(points, (low, l) => l.minPoints < low ? l.minPoints : low);
    if (lowest != 0) return S.startingTierMustBegin0Pts;
    return null;
  }

  /// 依門檻排序後的完整階梯，包含正在編輯的草稿，供預覽位置與點數區間。
  static List<LevelSlot> ladder(List<AdminLevel> levels, {int? editingId, required String name, int? points}) {
    final entries = [
      for (final l in _others(levels, editingId)) (id: l.levelId, name: l.name, points: l.minPoints, draft: false),
      if (points != null) (id: editingId, name: name, points: points, draft: true),
    ]..sort((a, b) => a.points.compareTo(b.points));

    return [
      for (var i = 0; i < entries.length; i++)
        LevelSlot(
          levelId: entries[i].id,
          name: entries[i].name,
          minPoints: entries[i].points,
          maxPoints: i + 1 < entries.length ? _maxBelow(entries[i].points, entries[i + 1].points) : null,
          isDraft: entries[i].draft,
        ),
    ];
  }

  static int _maxBelow(int min, int nextMin) => nextMin - 1 < min ? min : nextMin - 1;

  static int? maxPointsOf(List<AdminLevel> sortedLevels, int index) =>
      index + 1 < sortedLevels.length ? _maxBelow(sortedLevels[index].minPoints, sortedLevels[index + 1].minPoints) : null;

  static String? deleteBlockReason(AdminLevel level, List<AdminLevel> levels) {
    final others = _others(levels, level.levelId);
    if (level.minPoints == 0 && others.isNotEmpty && !others.any((l) => l.minPoints == 0)) {
      return S.startingTierCannotDeletedSetAnother;
    }
    return null;
  }

  /// 刪除後原屬此等級的會員會改列的等級。
  static AdminLevel? fallbackAfterDelete(AdminLevel level, List<AdminLevel> levels) {
    final others = sorted(_others(levels, level.levelId));
    if (others.isEmpty) return null;
    return others.lastWhere((l) => l.minPoints <= level.minPoints, orElse: () => others.first);
  }

  /// 門檻依位置保留：新順序中第 i 個等級取得原本由低到高第 i 個門檻。
  static List<LevelThresholdChange> reorderChanges(List<AdminLevel> current, List<AdminLevel> reordered) {
    final thresholds = sorted(current).map((l) => l.minPoints).toList();
    return [
      for (var i = 0; i < reordered.length && i < thresholds.length; i++)
        if (reordered[i].minPoints != thresholds[i]) LevelThresholdChange(reordered[i], reordered[i].minPoints, thresholds[i]),
    ];
  }
}
