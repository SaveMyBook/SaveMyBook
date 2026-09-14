import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

class Motion {
  const Motion._();

  static const Duration instant = Duration(milliseconds: 90);

  static const Duration micro = Duration(milliseconds: 180);

  static const Duration base = Duration(milliseconds: 260);

  static const Duration enter = Duration(milliseconds: 380);

  static const Duration large = Duration(milliseconds: 520);

  static const Duration count = Duration(milliseconds: 900);

  static const Duration stagger = Duration(milliseconds: 45);

  static const Duration staggerCap = Duration(milliseconds: 260);

  static const Curve enterCurve = Curves.easeOutCubic;

  static const Curve exitCurve = Curves.easeInCubic;

  static const Curve emphasized = Cubic(0.2, 0.9, 0.1, 1.0);

  static const Curve standard = Curves.easeInOutCubic;

  static const Curve pop = Curves.easeOutBack;

  static const SpringDescription pressSpring =
      SpringDescription(mass: 1, stiffness: 520, damping: 24);

  static const SpringDescription glideSpring =
      SpringDescription(mass: 1, stiffness: 340, damping: 22);

  static Duration delayFor(int index, {Duration? step, Duration? cap}) {
    final ms = (step ?? stagger).inMilliseconds * index;
    final limit = (cap ?? staggerCap).inMilliseconds;
    return Duration(milliseconds: ms.clamp(0, limit));
  }
}
