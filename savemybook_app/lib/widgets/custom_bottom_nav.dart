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
    final c = AppColors.of(context);

    return AnimatedSlide(
      duration: const Duration(milliseconds: 500),
      curve: isVisible ? Curves.easeOutCubic : Curves.easeInCubic,
      offset: isVisible ? Offset.zero : const Offset(0, 1.2),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        opacity: isVisible ? 1.0 : 0.0,
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
                      _buildNavItem(Icons.home_rounded, Icons.home_outlined, 0, c),
                      _buildNavItem(Icons.notifications_rounded, Icons.notifications_none_rounded, 1, c),
                      _buildCenterButton(),
                      _buildNavItem(Icons.inventory_2_rounded, Icons.inventory_2_outlined, 3, c),
                      _buildNavItem(Icons.person_rounded, Icons.person_outline_rounded, 4, c),
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

  Widget _buildNavItem(IconData solidIcon, IconData outlinedIcon, int index, AppColors c) {
    final isSelected = selectedIndex == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onItemSelected(index),
      child: SizedBox(
        width: 52, height: 60,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary.withOpacity(0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isSelected ? solidIcon : outlinedIcon,
              size: 24,
              color: isSelected ? AppColors.primary : c.iconInactive,
            ),
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