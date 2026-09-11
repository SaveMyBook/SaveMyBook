import 'package:flutter/material.dart';
import '../models/member_level.dart';

/// 會員等級的視覺定義：漸層底色、強調色、徽章圖示。
///
/// 會員中心的徽章和會員等級頁必須用同一套，否則同一個等級在兩頁會長得不一樣。
class LevelStyle {
  final List<Color> gradient;
  final Color accent;
  final IconData icon;

  const LevelStyle(this.gradient, this.accent, this.icon);

  static const _palette = <LevelStyle>[
    LevelStyle([Color(0xFF8D6E52), Color(0xFFC29B76)], Color(0xFF8D6E52), Icons.eco_rounded),
    LevelStyle([Color(0xFF7B8B97), Color(0xFFB6C4CE)], Color(0xFF5E6E7A), Icons.hexagon_rounded),
    LevelStyle([Color(0xFFB08427), Color(0xFFE7C46A)], Color(0xFF9A711A), Icons.workspace_premium_rounded),
    LevelStyle([Color(0xFF5C6BC0), Color(0xFF9FA8DA)], Color(0xFF4A57A8), Icons.auto_awesome_rounded),
    LevelStyle([Color(0xFF6A3FA0), Color(0xFFB388DD)], Color(0xFF57318A), Icons.diamond_rounded),
    LevelStyle([Color(0xFF23272E), Color(0xFF5A6270)], Color(0xFF23272E), Icons.stars_rounded),
  ];

  static LevelStyle at(int index) => _palette[index % _palette.length];

  static int count = _palette.length;
}

/// 目前等級的進度。重點是「在這一級裡走了多少」，
/// 而不是「總點數除以下一級門檻」—— 後者在高等級時會一直看起來快滿了。
class LevelProgress {
  final int points;
  final int floor;
  final int? target;
  final double ratio;
  final int remaining;
  final bool isMax;

  const LevelProgress({
    required this.points,
    required this.floor,
    required this.ratio,
    required this.remaining,
    required this.isMax,
    this.target,
  });

  factory LevelProgress.from(MemberLevelInfo info) {
    final floor = info.currentLevel?.minPoints ?? 0;
    final next = info.nextLevel;

    if (next == null) {
      return LevelProgress(
        points: info.points,
        floor: floor,
        ratio: 1,
        remaining: 0,
        isMax: true,
      );
    }

    final span = next.minPoints - floor;
    final walked = info.points - floor;
    final ratio = span <= 0 ? 1.0 : (walked / span).clamp(0.0, 1.0);

    return LevelProgress(
      points: info.points,
      floor: floor,
      target: next.minPoints,
      ratio: ratio.toDouble(),
      remaining: (next.minPoints - info.points).clamp(0, next.minPoints),
      isMax: false,
    );
  }

  int get percent => (ratio * 100).round();
}

/// 找出某個等級在清單中的索引，用來取對應的樣式。
int levelIndexOf(MemberLevelInfo info, MemberLevel? level) {
  if (level == null) return 0;
  final index = info.levels.indexWhere((l) => l.levelId == level.levelId);
  return index < 0 ? 0 : index;
}
