import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../i18n/strings.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../utils/app_info.dart';
import '../utils/motion.dart';
import 'app_asset_image.dart';
import 'app_header.dart';

class AppSideNav extends StatelessWidget {
  static const int chatTab = 5;
  static const int cartTab = 6;

  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final bool extended;

  const AppSideNav({super.key, required this.selectedIndex, required this.onItemSelected, this.extended = false});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final padding = MediaQuery.paddingOf(context);
    final items = [
      (index: 0, icon: Icons.home_outlined, active: Icons.home_rounded, label: S.home, badge: null as ValueListenable<int>?),
      (index: 1, icon: Icons.notifications_none_rounded, active: Icons.notifications_rounded, label: S.alerts, badge: ApiService.unreadNotificationCount),
      (index: chatTab, icon: Icons.chat_bubble_outline_rounded, active: Icons.chat_bubble_rounded, label: S.chat, badge: ApiService.unreadChatCount),
      (index: cartTab, icon: Icons.shopping_cart_outlined, active: Icons.shopping_cart_rounded, label: S.cart, badge: ApiService.cartCount),
      (index: 3, icon: Icons.qr_code_scanner_rounded, active: Icons.qr_code_scanner_rounded, label: S.collect, badge: null),
      (index: 4, icon: Icons.person_outline_rounded, active: Icons.person_rounded, label: S.member, badge: null),
    ];

    Widget item(int index, IconData icon, IconData active, String label, ValueListenable<int>? badge, {bool prominent = false}) {
      return _SideNavItem(
        icon: selectedIndex == index ? active : icon,
        label: label,
        selected: selectedIndex == index,
        prominent: prominent,
        extended: extended,
        badge: badge,
        onTap: () {
          if (selectedIndex != index) HapticFeedback.selectionClick();
          onItemSelected(index);
        },
      );
    }

    return AnimatedContainer(
      duration: Motion.base,
      curve: Motion.standard,
      width: (extended ? 232 : 88) + padding.left,
      padding: EdgeInsets.fromLTRB(padding.left + 12, padding.top + 16, 12, 0),
      decoration: BoxDecoration(
        color: c.card,
        border: Border(right: BorderSide(color: c.divider)),
      ),
      child: Column(
        crossAxisAlignment: extended ? CrossAxisAlignment.stretch : CrossAxisAlignment.center,
        children: [
          Padding(
            padding: EdgeInsets.only(left: extended ? 8 : 0, bottom: 20),
            child: Row(
              mainAxisSize: extended ? MainAxisSize.max : MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: const AppAssetImage(asset: 'assets/images/logo.png', width: 40, height: 40, fallbackIcon: Icons.menu_book_rounded),
                ),
                if (extended) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      kAppName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.textPrimary),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(bottom: padding.bottom + 16),
              child: Column(
                crossAxisAlignment: extended ? CrossAxisAlignment.stretch : CrossAxisAlignment.center,
                children: [
                  item(2, Icons.add_rounded, Icons.add_rounded, S.sellBook, null, prominent: true),
                  SizedBox(height: extended ? 16 : 12),
                  for (final entry in items) ...[
                    item(entry.index, entry.icon, entry.active, entry.label, entry.badge),
                    SizedBox(height: extended ? 4 : 2),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SideNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool prominent;
  final bool extended;
  final ValueListenable<int>? badge;
  final VoidCallback onTap;

  const _SideNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.prominent,
    required this.extended,
    required this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final foreground = prominent ? Colors.white : (selected ? c.accent : c.textSecondary);
    final background = prominent
        ? AppColors.primary
        : (selected ? c.accent.withValues(alpha: c.isDark ? 0.22 : 0.12) : Colors.transparent);

    Widget glyph = Icon(icon, size: 24, color: foreground);
    final count = badge;
    if (count != null) {
      glyph = Stack(
        clipBehavior: Clip.none,
        children: [
          glyph,
          Positioned(
            right: -8,
            top: -4,
            child: ValueListenableBuilder<int>(
              valueListenable: count,
              builder: (_, value, _) => CountBadge(count: value),
            ),
          ),
        ],
      );
    }

    final text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: extended ? 14.5 : 11,
        fontWeight: selected || prominent ? FontWeight.w700 : FontWeight.w500,
        color: extended || !prominent ? foreground : c.textSecondary,
      ),
    );

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: extended
              ? AnimatedContainer(
                  duration: Motion.base,
                  curve: Motion.standard,
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(16)),
                  child: Row(children: [glyph, const SizedBox(width: 14), Expanded(child: text)]),
                )
              : SizedBox(
                  width: 64,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: Motion.base,
                          curve: Motion.standard,
                          width: 56,
                          height: 36,
                          decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(18)),
                          child: Center(child: glyph),
                        ),
                        const SizedBox(height: 4),
                        text,
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
