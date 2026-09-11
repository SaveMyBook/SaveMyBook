import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// 全 App 共用的動態語彙。新增動畫一律從這裡取值，不要現場寫數字，
/// 否則各處的時間與曲線會散開，整體節奏就不一致。
class Motion {
  const Motion._();

  // ---------- 時間 ----------

  /// 按壓的即時回饋。
  static const Duration instant = Duration(milliseconds: 90);

  /// 圖示切換、標籤變色等原地的小變化。
  static const Duration micro = Duration(milliseconds: 180);

  /// 一般狀態轉換，最常用的一檔。
  static const Duration base = Duration(milliseconds: 260);

  /// 元素進場、展開收合。
  static const Duration enter = Duration(milliseconds: 380);

  /// 大面積位移或跨頁元素。
  static const Duration large = Duration(milliseconds: 520);

  /// 數字滾動、進度條等需要被看見過程的動畫。
  static const Duration count = Duration(milliseconds: 900);

  /// 列表逐項進場的間隔。45ms 是「看得出依序」又不會讓最後一項等太久的值。
  static const Duration stagger = Duration(milliseconds: 45);

  /// 逐項進場的延遲上限。
  static const Duration staggerCap = Duration(milliseconds: 260);

  // ---------- 曲線 ----------

  /// 進場：起步快、收尾慢。
  static const Curve enterCurve = Curves.easeOutCubic;

  /// 離場：起步慢、收尾快，整體比進場短。
  static const Curve exitCurve = Curves.easeInCubic;

  /// 強調用，末端有輕微過衝。
  static const Curve emphasized = Cubic(0.2, 0.9, 0.1, 1.0);

  /// 位移類的標準曲線。
  static const Curve standard = Curves.easeInOutCubic;

  /// 彈跳。僅用於徽章、勾選等小元素，大面積會過於誇張。
  static const Curve pop = Curves.easeOutBack;

  // ---------- 彈簧 ----------

  /// 按壓回彈。damping 偏高，只保留極短餘韻。
  static const SpringDescription pressSpring =
      SpringDescription(mass: 1, stiffness: 520, damping: 24);

  /// 位置滑移。比按壓軟，過衝明顯。
  static const SpringDescription glideSpring =
      SpringDescription(mass: 1, stiffness: 340, damping: 22);

  static Duration delayFor(int index, {Duration? step, Duration? cap}) {
    final ms = (step ?? stagger).inMilliseconds * index;
    final limit = (cap ?? staggerCap).inMilliseconds;
    return Duration(milliseconds: ms.clamp(0, limit));
  }
}
