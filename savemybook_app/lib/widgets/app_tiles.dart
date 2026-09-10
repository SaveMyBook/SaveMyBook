import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

class UserAvatar extends StatefulWidget {
  final String? imageUrl;
  final double radius;
  final Color? background;

  const UserAvatar({super.key, required this.imageUrl, this.radius = 20, this.background});

  @override
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  bool _failed = false;

  @override
  void didUpdateWidget(covariant UserAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) _failed = false;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final url = widget.imageUrl;
    final showImage = !_failed && url != null && url.isNotEmpty;

    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: widget.background ?? c.inputFill,
      backgroundImage: showImage ? NetworkImage(url) : null,
      onBackgroundImageError: showImage
          ? (_, __) {
              if (mounted) setState(() => _failed = true);
            }
          : null,
      child: showImage
          ? null
          : Icon(Icons.person, size: widget.radius * 1.05, color: c.iconInactive),
    );
  }
}

class AppMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailingText;
  final int badge;
  final bool isLast;
  final VoidCallback? onTap;
  final Color? iconColor;

  const AppMenuItem({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailingText,
    this.badge = 0,
    this.isLast = false,
    this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Column(
      children: [
        ListTile(
          leading: Icon(icon, color: iconColor ?? c.iconInactive),
          title: Text(
            title,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: c.textPrimary),
          ),
          subtitle: subtitle == null
              ? null
              : Text(subtitle!, style: TextStyle(fontSize: 12, color: c.textSecondary)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (badge > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: c.danger,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badge > 99 ? '99+' : '$badge',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              if (trailingText != null)
                Text(trailingText!, style: TextStyle(color: c.textSecondary, fontSize: 14)),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios, size: 16, color: c.iconInactive),
            ],
          ),
          onTap: onTap,
        ),
        if (!isLast)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 1, color: c.divider),
          ),
      ],
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final double fontSize;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.fontSize = 11,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class InfoLine extends StatelessWidget {
  final IconData? icon;
  final String? label;
  final String value;
  final int maxLines;
  final double fontSize;

  const InfoLine({
    super.key,
    required this.value,
    this.icon,
    this.label,
    this.maxLines = 2,
    this.fontSize = 11,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Icon(icon, size: fontSize + 2, color: c.iconInactive),
          const SizedBox(width: 3),
        ],
        if (label != null)
          Text('$label：', style: TextStyle(fontSize: fontSize, color: c.textHint)),
        Expanded(
          child: Text(
            value,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: fontSize, color: c.textSecondary, height: 1.3),
          ),
        ),
      ],
    );
  }
}

class SectionHeading extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SectionHeading({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary),
            ),
            const Spacer(),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 6),
        Divider(color: c.divider),
      ],
    );
  }
}

class StatTile extends StatelessWidget {
  final String label;
  final Widget value;

  const StatTile({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Column(
      children: [
        Text(label, style: TextStyle(color: c.textSecondary, fontSize: 12)),
        const SizedBox(height: 6),
        value,
      ],
    );
  }
}

class VerticalDivider1 extends StatelessWidget {
  const VerticalDivider1({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(height: 30, width: 1, color: AppColors.of(context).divider);
  }
}
