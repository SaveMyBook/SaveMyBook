import 'dart:ui';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import 'animations.dart';
import 'app_header.dart';

class CustomBottomNav extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final bool isVisible;

  const CustomBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    this.isVisible = true,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    final actuallyVisible = isVisible && !isKeyboardOpen;

    final c = AppColors.of(context);

    return AnimatedSlide(
      duration: const Duration(milliseconds: 500),
      curve: actuallyVisible ? Curves.easeOutCubic : Curves.easeInCubic,
      offset: actuallyVisible ? Offset.zero : const Offset(0, 1.2),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        opacity: actuallyVisible ? 1.0 : 0.0,
        child: Padding(
          padding: EdgeInsets.only(left: 24, right: 24, bottom: bottomPadding + 12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(color: c.shadow, blurRadius: 32, offset: const Offset(0, 8)),
                BoxShadow(color: c.shadow.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 28.0, sigmaY: 28.0),
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: c.navBarBg,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: c.navBarBorder, width: 0.5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildNavItem(Icons.home_rounded, Icons.home_outlined, '首頁', 0, c),
                      _buildNavItem(Icons.notifications_rounded, Icons.notifications_none_rounded, '通知', 1, c,
                          badge: ApiService.unreadNotificationCount),
                      _buildCenterButton(),
                      _buildNavItem(Icons.qr_code_scanner_rounded, Icons.qr_code_scanner_rounded, '取書', 3, c),
                      _buildNavItem(Icons.person_rounded, Icons.person_outline_rounded, '會員', 4, c),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData solidIcon, IconData outlinedIcon, String label, int index, AppColors c,
      {ValueListenable<int>? badge}) {
    final isSelected = selectedIndex == index;
    final color = isSelected ? c.accent : c.iconInactive;

    Widget icon = AnimatedScale(
      scale: isSelected ? 1.15 : 1.0,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutBack,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        child: Icon(
          isSelected ? solidIcon : outlinedIcon,
          key: ValueKey(isSelected),
          size: 22,
          color: color,
        ),
      ),
    );

    if (badge != null) {
      icon = Stack(
        clipBehavior: Clip.none,
        children: [
          icon,
          Positioned(
            right: -8,
            top: -4,
            child: ValueListenableBuilder<int>(
              valueListenable: badge,
              builder: (context, count, _) => CountBadge(count: count),
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onItemSelected(index),
      child: SizedBox(
        width: 52, height: 60,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: color,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCenterButton() {
    final isSelected = selectedIndex == 2;

    return PressableScale(
      scale: 0.9,
      onTap: () => onItemSelected(2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(isSelected ? 22 : 15),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: isSelected ? 0.5 : 0.35),
              blurRadius: isSelected ? 16 : 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: AnimatedRotation(
          turns: isSelected ? 0.125 : 0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutBack,
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
        ),
      ),
    );
  }
}