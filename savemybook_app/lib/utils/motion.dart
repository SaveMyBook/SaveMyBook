import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// 全 App 共用的動態語彙。
///
/// 動畫要有「很用心」的感覺，靠的不是某一處做得炫，而是每一處的
/// 時間與曲線都出自同一套規則 —— 使用者說不出哪裡不一樣，但會覺得順。
/// 所以任何新的動畫都從這裡取值，不要現場寫 magic number。
class Motion {
  const Motion._();

  // ---------- 時間 ----------

  /// 按下去的即時回饋。要比人眼察覺極限再快一點。
  static const Duration instant = Duration(milliseconds: 90);

  /// 圖示切換、小標籤變色這種原地的小變化。
  static const Duration micro = Duration(milliseconds: 180);

  /// 一般的狀態轉換，是最常用的那一檔。
  static const Duration base = Duration(milliseconds: 260);

  /// 元素進場、展開收合。
  static const Duration enter = Duration(milliseconds: 380);

  /// 大面積的位移或跨頁元素。
  static const Duration large = Duration(milliseconds: 520);

  /// 數字滾動、進度條這類需要被看見過程的動畫。
  static const Duration count = Duration(milliseconds: 900);

  /// 列表逐項進場的間隔。45ms 是「看得出依序」又不會讓最後一項等太久的值。
  static const Duration stagger = Duration(milliseconds: 45);

  /// 逐項進場的延遲上限。超過這個值使用者會開始覺得在等。
  static const Duration staggerCap = Duration(milliseconds: 260);

  // ---------- 曲線 ----------

  /// 進場：起步快、收尾慢，看起來像是「飛進來剛好停住」。
  static const Curve enterCurve = Curves.easeOutCubic;

  /// 離場：起步慢、收尾快。離場比進場快，畫面才不會拖泥帶水。
  static const Curve exitCurve = Curves.easeInCubic;

  /// 強調用的收尾，末端有一點點過衝。用在需要被注意的元素。
  static const Curve emphasized = Cubic(0.2, 0.9, 0.1, 1.0);

  /// 位移類的標準曲線，兩端都平滑。
  static const Curve standard = Curves.easeInOutCubic;

  /// 彈跳。只用在很小的元素（徽章、勾選），大面積會顯得廉價。
  static const Curve pop = Curves.easeOutBack;

  // ---------- 彈簧 ----------

  /// 按壓放開後回彈。damping 調得偏高，只保留一點點餘韻，不會晃。
  static const SpringDescription pressSpring =
      SpringDescription(mass: 1, stiffness: 520, damping: 24);

  /// 位置滑移（導覽列膠囊之類）。比按壓軟一些，過衝看得出來。
  static const SpringDescription glideSpring =
      SpringDescription(mass: 1, stiffness: 340, damping: 22);

  /// 依索引算出進場延遲，並套用上限。
  static Duration delayFor(int index, {Duration? step, Duration? cap}) {
    final ms = (step ?? stagger).inMilliseconds * index;
    final limit = (cap ?? staggerCap).inMilliseconds;
    return Duration(milliseconds: ms.clamp(0, limit));
  }
}
