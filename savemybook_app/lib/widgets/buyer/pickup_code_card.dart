import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../i18n/strings.dart';
import '../../utils/app_colors.dart';
import '../animations.dart';
import '../state_views.dart';

class PickupCodeCard extends StatelessWidget {
  final String code;
  final String? caption;
  final String? slotNumber;

  const PickupCodeCard({super.key, required this.code, this.caption, this.slotNumber});

  static Future<void> copy(BuildContext context, String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    HapticFeedback.selectionClick();
    if (context.mounted) showAppSnackBar(context, S.pickupCodeCopied);
  }

  String get _spaced {
    if (code.length != 6) return code;
    return '${code.substring(0, 3)} ${code.substring(3)}';
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final surface = c.isDark ? Colors.white : const Color(0xFF111820);
    final ink = c.isDark ? const Color(0xFF111820) : Colors.white;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 10, 16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.pin_rounded, size: 14, color: ink.withValues(alpha: 0.7)),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        slotNumber == null || slotNumber!.isEmpty ? S.pickupCode : '${S.pickupCode} · ${S.slot2(slotNumber!)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ink.withValues(alpha: 0.7)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: SelectableText(
                    _spaced,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 40,
                      height: 1.1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                      color: ink,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                if (caption != null && caption!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    caption!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, height: 1.4, color: ink.withValues(alpha: 0.75)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          PressableScale(
            scale: 0.9,
            onTap: () => copy(context, code),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: ink.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.copy_rounded, size: 20, color: ink),
                  const SizedBox(height: 2),
                  Text(S.copy, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ink)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
