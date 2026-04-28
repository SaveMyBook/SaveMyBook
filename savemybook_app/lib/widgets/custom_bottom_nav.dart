import 'dart:ui';
import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

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
                BoxShadow(color: c.shadow.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2)),
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
                      _buildNavItem(Icons.notifications_rounded, Icons.notifications_none_rounded, '通知', 1, c),
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

  Widget _buildNavItem(IconData solidIcon, IconData outlinedIcon, String label, int index, AppColors c) {
    final isSelected = selectedIndex == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onItemSelected(index),
      child: SizedBox(
        width: 52, height: 60,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? solidIcon : outlinedIcon,
                size: 22,
                color: isSelected ? AppColors.primary : c.iconInactive,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? AppColors.primary : c.iconInactive,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCenterButton() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onItemSelected(2),
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(color: AppColors.primary.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
      ),
    );
  }
}