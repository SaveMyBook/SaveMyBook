import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../utils/motion.dart';
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
                      Positioned.fill(
                        child: IgnorePointer(
                          child: _SlidingPill(
                            index: selectedIndex,
                            slot: slot,
                            colors: c,
                          ),
                        ),
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

    // 選中時圖示往上浮一點點，文字才有被「推開」的感覺。
    Widget icon = AnimatedSlide(
      offset: Offset(0, isSelected ? -0.06 : 0),
      duration: Motion.base,
      curve: Motion.emphasized,
      child: AnimatedScale(
        scale: isSelected ? 1.14 : 1.0,
        duration: Motion.base,
        curve: Motion.pop,
        child: AnimatedSwitcher(
          duration: Motion.micro,
          switchInCurve: Motion.enterCurve,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.82, end: 1).animate(animation),
              child: child,
            ),
          ),
          child: Icon(
            isSelected ? solidIcon : outlinedIcon,
            key: ValueKey(isSelected),
            size: 22,
            color: color,
          ),
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
              duration: Motion.base,
              curve: Motion.emphasized,
              style: TextStyle(
                fontSize: isSelected ? 10.5 : 10,
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
        duration: Motion.base,
        curve: Motion.emphasized,
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
          duration: Motion.enter,
          curve: Motion.pop,
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
        ),
      ),
    );
  }
}

/// 沿著導覽列滑動的膠囊。
///
/// 用彈簧而不是補間曲線：切分頁時膠囊會稍微衝過頭再收回來，
/// 而且移動中會依速度拉長、停下時彈回原比例。這個擠壓拉伸
/// 是讓它看起來有重量、不像貼圖平移的關鍵。
class _SlidingPill extends StatefulWidget {
  final int index;
  final double slot;
  final AppColors colors;

  const _SlidingPill({
    required this.index,
    required this.slot,
    required this.colors,
  });

  @override
  State<_SlidingPill> createState() => _SlidingPillState();
}

class _SlidingPillState extends State<_SlidingPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController.unbounded(vsync: this, value: widget.index.toDouble());

  @override
  void didUpdateWidget(covariant _SlidingPill old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) {
      _controller.animateWith(
        SpringSimulation(
          Motion.glideSpring,
          _controller.value,
          widget.index.toDouble(),
          _controller.velocity,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final pos = _controller.value;

        // 中央的加號有自己的樣式，膠囊滑到那一格時淡出讓位。
        final distanceToCentre = (pos - 2).abs();
        final opacity = distanceToCentre.clamp(0.0, 1.0);
        if (opacity == 0) return const SizedBox.shrink();

        // 速度換算成擠壓量。上限壓在 0.26，再多會變成橡皮筋。
        final speed = _controller.velocity.abs();
        final squash = (speed * 0.05).clamp(0.0, 0.26);

        return Stack(
          children: [
            Positioned(
              left: widget.slot * pos + (widget.slot - CustomBottomNav._pillWidth) / 2,
              top: (CustomBottomNav._barHeight - CustomBottomNav._pillHeight) / 2,
              child: Opacity(
                opacity: opacity,
                child: Transform.scale(
                  scaleX: 1 + squash,
                  scaleY: 1 - squash * 0.55,
                  child: Container(
                    width: CustomBottomNav._pillWidth,
                    height: CustomBottomNav._pillHeight,
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(CustomBottomNav._pillHeight / 2),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          c.accent.withValues(alpha: c.isDark ? 0.34 : 0.16),
                          c.accent.withValues(alpha: c.isDark ? 0.18 : 0.08),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
