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
import 'app_tiles.dart';

/// 平板的側邊欄。橫向為分組的完整側邊欄；直向為圖示列，可展開成完整側邊欄。
class AppSideNav extends StatelessWidget {
  static const int homeTab = 0;
  static const int alertsTab = 1;
  static const int sellTab = 2;
  static const int collectTab = 3;
  static const int memberTab = 4;
  static const int chatTab = 5;
  static const int cartTab = 6;
  static const int ordersTab = 7;
  static const int reservationsTab = 8;
  static const int savedTab = 9;
  static const int myBooksTab = 10;
  static const int coinsTab = 11;
  static const int settingsTab = 12;
  static const int tabCount = 13;

  static const double extendedWidth = 264;
  static const double railWidth = 88;

  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final bool extended;
  final VoidCallback? onSearch;

  /// 直向圖示列頂端的按鈕：展開完整側邊欄；完整側邊欄以浮層顯示時則為收合。
  final VoidCallback? onToggle;

  const AppSideNav({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    this.extended = false,
    this.onSearch,
    this.onToggle,
  });

  void _select(int index) {
    if (selectedIndex != index) HapticFeedback.selectionClick();
    onItemSelected(index);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final padding = MediaQuery.paddingOf(context);
    return AnimatedContainer(
      duration: Motion.base,
      curve: Motion.standard,
      width: (extended ? extendedWidth : railWidth) + padding.left,
      decoration: BoxDecoration(
        color: c.card,
        border: Border(right: BorderSide(color: c.divider)),
      ),
      child: extended ? _buildExtended(context, c, padding) : _buildRail(context, c, padding),
    );
  }

  Widget _buildExtended(BuildContext context, AppColors c, EdgeInsets padding) {
    Widget item(int index, IconData icon, IconData active, String label, [ValueListenable<int>? badge]) => _SideNavItem(
          icon: selectedIndex == index ? active : icon,
          label: label,
          selected: selectedIndex == index,
          badge: badge,
          onTap: () => _select(index),
        );

    return Padding(
      padding: EdgeInsets.only(left: padding.left),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: padding.top + 10),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: const AppAssetImage(asset: 'assets/images/logo.png', width: 34, height: 34, fallbackIcon: Icons.menu_book_rounded),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    kAppName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.textPrimary),
                  ),
                ),
                if (onToggle != null)
                  IconButton(
                    icon: Icon(Icons.menu_open_rounded, color: c.textSecondary),
                    tooltip: S.hideSidebar,
                    onPressed: onToggle,
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _SellButton(selected: selectedIndex == sellTab, onTap: () => _select(sellTab)),
          ),
          if (onSearch != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: _SearchField(onTap: onSearch!),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              children: [
                _SectionLabel(S.sideNavBrowse),
                item(homeTab, Icons.home_outlined, Icons.home_rounded, S.home),
                item(collectTab, Icons.qr_code_scanner_rounded, Icons.qr_code_scanner_rounded, S.collect),
                _SectionLabel(S.sideNavMessages),
                item(alertsTab, Icons.notifications_none_rounded, Icons.notifications_rounded, S.alerts, ApiService.unreadNotificationCount),
                item(chatTab, Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, S.chat, ApiService.unreadChatCount),
                _SectionLabel(S.sideNavTrade),
                item(cartTab, Icons.shopping_cart_outlined, Icons.shopping_cart_rounded, S.cart, ApiService.cartCount),
                item(ordersTab, Icons.receipt_long_outlined, Icons.receipt_long_rounded, S.orderHistory),
                item(reservationsTab, Icons.event_available_outlined, Icons.event_available_rounded, S.myReservations),
                item(savedTab, Icons.bookmark_border_rounded, Icons.bookmark_rounded, S.saved),
                item(coinsTab, Icons.monetization_on_outlined, Icons.monetization_on_rounded, S.coins),
                _SectionLabel(S.sideNavSelling),
                item(myBooksTab, Icons.library_books_outlined, Icons.library_books_rounded, S.myBooks),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: c.divider),
          Padding(
            padding: EdgeInsets.fromLTRB(12, 8, 8, padding.bottom + 8),
            child: _AccountTile(
              selected: selectedIndex == memberTab,
              settingsSelected: selectedIndex == settingsTab,
              onTap: () => _select(memberTab),
              onSettings: () => _select(settingsTab),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRail(BuildContext context, AppColors c, EdgeInsets padding) {
    final items = [
      (index: homeTab, icon: Icons.home_outlined, active: Icons.home_rounded, label: S.home, badge: null as ValueListenable<int>?),
      (index: alertsTab, icon: Icons.notifications_none_rounded, active: Icons.notifications_rounded, label: S.alerts, badge: ApiService.unreadNotificationCount),
      (index: chatTab, icon: Icons.chat_bubble_outline_rounded, active: Icons.chat_bubble_rounded, label: S.chat, badge: ApiService.unreadChatCount),
      (index: cartTab, icon: Icons.shopping_cart_outlined, active: Icons.shopping_cart_rounded, label: S.cart, badge: ApiService.cartCount),
      (index: collectTab, icon: Icons.qr_code_scanner_rounded, active: Icons.qr_code_scanner_rounded, label: S.collect, badge: null),
      (index: memberTab, icon: Icons.person_outline_rounded, active: Icons.person_rounded, label: S.member, badge: null),
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(padding.left + 12, padding.top + 12, 12, 0),
      child: Column(
        children: [
          if (onToggle != null)
            IconButton(
              icon: Icon(Icons.menu_rounded, color: c.textSecondary),
              tooltip: S.showSidebar,
              onPressed: onToggle,
            ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(bottom: padding.bottom + 16),
              child: Column(
                children: [
                  _RailItem(
                    icon: Icons.add_rounded,
                    label: S.sellBook,
                    selected: selectedIndex == sellTab,
                    prominent: true,
                    onTap: () => _select(sellTab),
                  ),
                  const SizedBox(height: 12),
                  for (final entry in items) ...[
                    _RailItem(
                      icon: selectedIndex == entry.index ? entry.active : entry.icon,
                      label: entry.label,
                      selected: selectedIndex == entry.index,
                      badge: entry.badge,
                      onTap: () => _select(entry.index),
                    ),
                    const SizedBox(height: 2),
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

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 4),
      child: Text(text, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c.textHint, letterSpacing: 0.3)),
    );
  }
}

Widget _badged(Widget glyph, ValueListenable<int>? badge) {
  if (badge == null) return glyph;
  return Stack(
    clipBehavior: Clip.none,
    children: [
      glyph,
      Positioned(
        right: -8,
        top: -4,
        child: ValueListenableBuilder<int>(valueListenable: badge, builder: (_, value, _) => CountBadge(count: value)),
      ),
    ],
  );
}

class _SideNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final ValueListenable<int>? badge;
  final VoidCallback onTap;

  const _SideNavItem({required this.icon, required this.label, required this.selected, required this.badge, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final foreground = selected ? c.accent : c.textPrimary;
    final count = badge;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Material(
          color: selected ? c.accent.withValues(alpha: c.isDark ? 0.22 : 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 40,
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Icon(icon, size: 22, color: selected ? c.accent : c.textSecondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: foreground),
                    ),
                  ),
                  if (count != null)
                    ValueListenableBuilder<int>(
                      valueListenable: count,
                      builder: (_, value, _) => value > 0 ? UnconstrainedBox(child: CountBadge(count: value)) : const SizedBox.shrink(),
                    ),
                  const SizedBox(width: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SellButton extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;

  const _SellButton({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 44,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                const SizedBox(width: 8),
                Text(S.sellBook, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final VoidCallback onTap;

  const _SearchField({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Semantics(
      button: true,
      label: S.actionSearch,
      child: Material(
        color: c.inputFill,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 38,
            child: Row(
              children: [
                const SizedBox(width: 10),
                Icon(Icons.search_rounded, size: 20, color: c.textHint),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    S.searchTitleAuthorIsbn,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, color: c.textHint),
                  ),
                ),
                const SizedBox(width: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  final bool selected;
  final bool settingsSelected;
  final VoidCallback onTap;
  final VoidCallback onSettings;

  const _AccountTile({required this.selected, required this.settingsSelected, required this.onTap, required this.onSettings});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final user = ApiService.currentUser;
    return Row(
      children: [
        Expanded(
          child: Material(
            color: selected ? c.accent.withValues(alpha: c.isDark ? 0.22 : 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    UserAvatar(imageUrl: user?.avatarUrl, radius: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            user?.nickname ?? S.member,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: selected ? c.accent : c.textPrimary),
                          ),
                          Text(
                            S.myAccount,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: c.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        IconButton(
          icon: Icon(settingsSelected ? Icons.settings_rounded : Icons.settings_outlined, color: settingsSelected ? c.accent : c.textSecondary),
          tooltip: S.settings,
          onPressed: onSettings,
        ),
      ],
    );
  }
}

class _RailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool prominent;
  final ValueListenable<int>? badge;
  final VoidCallback onTap;

  const _RailItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.prominent = false,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final foreground = prominent ? Colors.white : (selected ? c.accent : c.textSecondary);
    final background = prominent
        ? AppColors.primary
        : (selected ? c.accent.withValues(alpha: c.isDark ? 0.22 : 0.12) : Colors.transparent);

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
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
                    child: Center(child: _badged(Icon(icon, size: 24, color: foreground), badge)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: selected || prominent ? FontWeight.w700 : FontWeight.w500,
                      color: prominent ? c.textSecondary : foreground,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
