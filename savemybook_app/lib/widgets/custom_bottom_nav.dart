import 'dart:ui';
import 'package:flutter/material.dart';

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
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 32,
                  spreadRadius: 0,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 28.0, sigmaY: 28.0),
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.88),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.6),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildNavItem(Icons.home_rounded, Icons.home_outlined, 0),
                      _buildNavItem(Icons.notifications_rounded, Icons.notifications_none_rounded, 1),
                      _buildCenterButton(2),
                      _buildNavItem(Icons.inventory_2_rounded, Icons.inventory_2_outlined, 3),
                      _buildNavItem(Icons.person_rounded, Icons.person_outline_rounded, 4),
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

  Widget _buildNavItem(IconData solidIcon, IconData outlinedIcon, int index) {
    final isSelected = selectedIndex == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onItemSelected(index),
      child: SizedBox(
        width: 52,
        height: 60,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF627D8D).withOpacity(0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isSelected ? solidIcon : outlinedIcon,
              size: 24,
              color: isSelected ? const Color(0xFF627D8D) : Colors.grey.shade400,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCenterButton(int index) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onItemSelected(index),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFF627D8D),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF627D8D).withOpacity(0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
      ),
    );
  }
}