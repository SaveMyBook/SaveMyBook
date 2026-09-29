import 'package:flutter/material.dart';

import '../../../utils/app_colors.dart';
import '../../../utils/motion.dart';
import '../../../widgets/animations.dart';
import 'ai_labels.dart';

class AiPeriodPicker extends StatelessWidget {
  final String period;
  final ValueChanged<String> onChanged;

  const AiPeriodPicker({super.key, required this.period, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: c.categoryChip, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            for (final p in AiLabels.periods)
              Expanded(
                child: PressableScale(
                  scale: 0.95,
                  onTap: () {
                    if (p != period) onChanged(p);
                  },
                  child: AnimatedContainer(
                    duration: Motion.base,
                    curve: Motion.standard,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
                    decoration: BoxDecoration(
                      color: period == p ? c.card : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                      boxShadow: period == p ? [BoxShadow(color: c.shadow.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 1))] : null,
                    ),
                    alignment: Alignment.center,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        AiLabels.period(p),
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: period == p ? FontWeight.bold : FontWeight.w500,
                          color: period == p ? c.textPrimary : c.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
