import 'package:flutter/material.dart';
import '../../../i18n/strings.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/app_radius.dart';
import '../../../utils/motion.dart';
import '../../../widgets/animations.dart';

class LegalEditorHeaderBar extends StatelessWidget {
  final int selectedMode;
  final ValueChanged<int> onSelectMode;
  final bool dirty;
  final bool saving;
  final VoidCallback? onSave;

  const LegalEditorHeaderBar({
    super.key,
    required this.selectedMode,
    required this.onSelectMode,
    required this.dirty,
    required this.saving,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: _ModeSegments(
              labels: [S.sections, S.plainText, S.preview],
              selected: selectedMode,
              onSelect: onSelectMode,
            ),
          ),
          const SizedBox(width: 10),
          PressableScale(
            scale: 0.95,
            onTap: onSave,
            child: AnimatedContainer(
              duration: Motion.base,
              curve: Motion.standard,
              height: 36,
              constraints: const BoxConstraints(minWidth: 64),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: dirty ? Colors.white : Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              alignment: Alignment.center,
              child: saving
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: c.headerBg),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: Motion.base,
                          width: dirty ? 7 : 0,
                          height: 7,
                          margin: EdgeInsets.only(right: dirty ? 6 : 0),
                          decoration: BoxDecoration(color: c.warning, shape: BoxShape.circle),
                        ),
                        Text(
                          S.actionSave,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: dirty ? c.headerBg : Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeSegments extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  const _ModeSegments({required this.labels, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth / labels.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: Motion.base,
                curve: Motion.emphasized,
                left: width * selected,
                top: 0,
                bottom: 0,
                width: width,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.control - 3),
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < labels.length; i++)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: i == selected,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onSelect(i),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: AnimatedDefaultTextStyle(
                                  duration: Motion.base,
                                  style: DefaultTextStyle.of(context).style.copyWith(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: i == selected ? c.headerBg : Colors.white.withValues(alpha: 0.85),
                                  ),
                                  child: Text(labels[i], maxLines: 1),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
