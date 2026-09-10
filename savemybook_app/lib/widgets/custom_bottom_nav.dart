import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import 'animations.dart';
import 'app_header.dart';
import 'liquid_glass.dart';

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

  static const double _barHeight = 56;
  static const double _pillWidth = 52;
  static const double _pillHeight = 42;

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
          padding: EdgeInsets.only(left: 20, right: 20, bottom: bottomPadding + 4),
          child: LiquidGlass(
            borderRadius: BorderRadius.circular(_barHeight / 2),
            blur: 34,
            child: SizedBox(
              height: _barHeight,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // 五個等寬欄位，膠囊才能算出確定的位置滑過去。
                  final slot = constraints.maxWidth / 5;

                  return Stack(
                    children: [
                      if (selectedIndex != 2)
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 420),
                          curve: Curves.easeOutBack,
                          left: slot * selectedIndex + (slot - _pillWidth) / 2,
                          top: (_barHeight - _pillHeight) / 2,
                          child: _buildPill(c),
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: _buildNavItem(
                              Icons.home_rounded,
                              Icons.home_outlined,
                              '首頁',
                              0,
                              c,
                            ),
                          ),
                          Expanded(
                            child: _buildNavItem(
                              Icons.notifications_rounded,
                              Icons.notifications_none_rounded,
                              '通知',
                              1,
                              c,
                              badge: ApiService.unreadNotificationCount,
                            ),
                          ),
                          Expanded(child: Center(child: _buildCenterButton())),
                          Expanded(
                            child: _buildNavItem(
                              Icons.qr_code_scanner_rounded,
                              Icons.qr_code_scanner_rounded,
                              '取書',
                              3,
                              c,
                            ),
                          ),
                          Expanded(
                            child: _buildNavItem(
                              Icons.person_rounded,
                              Icons.person_outline_rounded,
                              '會員',
                              4,
                              c,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 選中的膠囊本身也是一小塊玻璃，會沿著導覽列滑到下一個分頁。
  Widget _buildPill(AppColors c) {
    return Container(
      width: _pillWidth,
      height: _pillHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_pillHeight / 2),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            c.accent.withValues(alpha: c.isDark ? 0.34 : 0.16),
            c.accent.withValues(alpha: c.isDark ? 0.18 : 0.08),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(
    IconData solidIcon,
    IconData outlinedIcon,
    String label,
    int index,
    AppColors c, {
    ValueListenable<int>? badge,
  }) {
    final isSelected = selectedIndex == index;
    final color = isSelected ? c.accent : c.iconInactive;

    Widget icon = AnimatedScale(
      scale: isSelected ? 1.12 : 1.0,
      duration: const Duration(milliseconds: 300),
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
      onTap: () {
        if (selectedIndex != index) HapticFeedback.selectionClick();
        onItemSelected(index);
      },
      child: SizedBox(
        height: _barHeight,
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
    );
  }

  Widget _buildCenterButton() {
    final isSelected = selectedIndex == 2;

    return PressableScale(
      scale: 0.9,
      onTap: () {
        HapticFeedback.mediumImpact();
        onItemSelected(2);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(isSelected ? 23 : 16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(AppColors.primary, Colors.white, 0.22)!,
              AppColors.primary,
            ],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 0.8),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: isSelected ? 0.5 : 0.34),
              blurRadius: isSelected ? 18 : 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: AnimatedRotation(
          turns: isSelected ? 0.125 : 0,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutBack,
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
        ),
      ),
    );
  }
}
