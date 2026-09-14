import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import 'animations.dart';

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final bool expand;
  final double height;
  final Color? color;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.expand = true,
    this.height = 48,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final background = color ?? c.accent;
    final enabled = onPressed != null && !isLoading;

    final button = SizedBox(
      height: height,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: Colors.white,
          disabledBackgroundColor: background.withValues(alpha: 0.4),
          disabledForegroundColor: Colors.white70,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: SwitchIn(
          duration: const Duration(milliseconds: 200),
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 18),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  final Widget Function(Color color)? iconBuilder;
  final Color? color;
  final double height;
  final bool isLoading;

  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.iconBuilder,
    this.color,
    this.height = 48,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final tint = color ?? c.accent;

    return SizedBox(
      height: height,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: tint,
          disabledForegroundColor: tint.withValues(alpha: 0.45),
          side: BorderSide(color: onPressed == null ? tint.withValues(alpha: 0.35) : tint),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: SwitchIn(
          duration: const Duration(milliseconds: 200),
          child: isLoading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: tint),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (iconBuilder != null) ...[
                      iconBuilder!(onPressed == null ? tint.withValues(alpha: 0.45) : tint),
                      const SizedBox(width: 8),
                    ] else if (icon != null) ...[
                      Icon(icon, size: 18),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class SmallActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool filled;
  final bool isLoading;
  final Color? color;

  const SmallActionButton({
    super.key,
    required this.label,
    this.onTap,
    this.filled = false,
    this.isLoading = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final tint = color ?? c.accent;
    final enabled = onTap != null && !isLoading;

    return PressableScale(
      scale: 0.94,
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: filled
              ? (enabled ? tint : tint.withValues(alpha: 0.4))
              : c.categoryChip,
          borderRadius: BorderRadius.circular(8),
        ),
        child: isLoading
            ? SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.8,
                  color: filled ? Colors.white : tint,
                ),
              )
            : Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: filled ? Colors.white : (enabled ? tint : c.textHint),
                ),
              ),
      ),
    );
  }
}

class QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badge;
  final double size;
  final Color? badgeColor;
  final Color? tint;

  const QuickActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge = 0,
    this.size = 46,
    this.badgeColor,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final accent = tint ?? c.accent;

    return PressableScale(
      scale: 0.93,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: c.card,
                  shape: BoxShape.circle,
                  border: Border.all(color: accent.withValues(alpha: 0.28), width: 1.2),
                ),
                child: Icon(icon, size: size * 0.48, color: accent),
              ),
              if (badge > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: PopIn(
                    triggerKey: badge,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      constraints: const BoxConstraints(minWidth: 18),
                      decoration: BoxDecoration(
                        color: badgeColor ?? c.accent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: c.card, width: 1.5),
                      ),
                      child: Text(
                        badge > 99 ? '99+' : '$badge',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, height: 1.2, color: c.textPrimary),
          ),
        ],
      ),
    );
  }
}
