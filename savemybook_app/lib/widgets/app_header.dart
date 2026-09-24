import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import 'animations.dart';
import '../utils/motion.dart';

class LightStatusBar extends StatelessWidget {
  final Widget child;

  const LightStatusBar({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: child,
    );
  }
}

class AppHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  final bool showBack;
  final List<Widget> actions;
  final double? actionsWidth;
  final VoidCallback? onBack;

  final Widget? bottom;

  const AppHeader({
    super.key,
    required this.title,
    this.icon,
    this.showBack = true,
    this.actions = const [],
    this.actionsWidth,
    this.onBack,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    final radius = bottom == null
        ? const BorderRadius.only(
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24),
          )
        : BorderRadius.zero;

    return LightStatusBar(
      child: ClipRRect(
        borderRadius: radius,
        child: Container(
          width: double.infinity,
          color: c.headerBg,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SafeArea(
                bottom: false,
                child: SizedBox(
                  height: 56,
                  width: double.infinity,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: actionsWidth != null
                              ? math.max(56, actionsWidth! + 12)
                              : actions.isEmpty
                                  ? 56
                                  : 56 + (actions.length - 1) * 44.0,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (icon != null) ...[
                              Icon(icon, color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (showBack)
                        Positioned(
                          left: 4,
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                            onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                          ),
                        ),
                      if (actions.isNotEmpty)
                        Positioned(
                          right: 8,
                          child: Row(mainAxisSize: MainAxisSize.min, children: actions),
                        ),
                    ],
                  ),
                ),
              ),
              ?bottom,
            ],
          ),
        ),
      ),
    );
  }
}

class CountBadge extends StatelessWidget {
  final int count;
  final Color? color;

  const CountBadge({super.key, required this.count, this.color});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();

    return PopIn(
      triggerKey: count,
      child: AnimatedContainer(
        duration: Motion.base,
        curve: Motion.standard,

        constraints: const BoxConstraints(minWidth: 16),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: color ?? AppColors.of(context).danger,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.of(context).card, width: 1.4),
        ),
        alignment: Alignment.center,
        child: Text(
          count > 99 ? '99+' : '$count',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}

class HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final int badgeCount;
  final ValueListenable<int>? badgeListenable;
  final double size;
  final Color color;

  const HeaderIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.badgeCount = 0,
    this.badgeListenable,
    this.size = 22,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    Widget badge(int count) => Positioned(right: 2, top: 4, child: CountBadge(count: count));

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(icon: Icon(icon, color: color, size: size), onPressed: onTap),
        if (badgeListenable != null)
          ValueListenableBuilder<int>(
            valueListenable: badgeListenable!,
            builder: (context, count, _) => badge(count),
          )
        else
          badge(badgeCount),
      ],
    );
  }
}

class CartIconButton extends StatefulWidget {
  final VoidCallback onTap;
  final double size;
  final Color color;

  const CartIconButton({
    super.key,
    required this.onTap,
    this.size = 22,
    this.color = Colors.white,
  });

  static final ValueNotifier<int> _bumps = ValueNotifier<int>(0);

  static void bump() => _bumps.value++;

  @override
  State<CartIconButton> createState() => _CartIconButtonState();
}

class _CartIconButtonState extends State<CartIconButton> with SingleTickerProviderStateMixin {
  late final AnimationController _bounce = AnimationController(vsync: this, duration: const Duration(milliseconds: 560));
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3).chain(CurveTween(curve: Curves.easeOut)), weight: 30),
    TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)), weight: 70),
  ]).animate(_bounce);

  @override
  void initState() {
    super.initState();
    CartIconButton._bumps.addListener(_onBump);
  }

  @override
  void dispose() {
    CartIconButton._bumps.removeListener(_onBump);
    _bounce.dispose();
    super.dispose();
  }

  void _onBump() {
    if (mounted) _bounce.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: HeaderIconButton(
        icon: Icons.shopping_cart_outlined,
        onTap: widget.onTap,
        size: widget.size,
        color: widget.color,
        badgeListenable: ApiService.cartCount,
      ),
    );
  }
}

class ChatIconButton extends StatelessWidget {
  final VoidCallback onTap;
  final double size;
  final Color color;

  const ChatIconButton({
    super.key,
    required this.onTap,
    this.size = 22,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return HeaderIconButton(
      icon: Icons.chat_bubble_outline,
      onTap: onTap,
      size: size,
      color: color,
      badgeListenable: ApiService.unreadChatCount,
    );
  }
}

class AppTabBar extends StatelessWidget {
  final TabController controller;
  final List<String> tabs;

  const AppTabBar({super.key, required this.controller, required this.tabs});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    const labelStyle = TextStyle(fontSize: 14, fontWeight: FontWeight.bold);

    return Container(
      width: double.infinity,
      color: c.card,
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: LayoutBuilder(builder: (context, constraints) {
        final scaler = MediaQuery.textScalerOf(context);
        final perTab = constraints.maxWidth / tabs.length;
        // 以實際繪製的字型量測：Tab 預設左右各留 16，放不下時先縮成各 10，仍放不下才改為可橫向捲動。
        final style = DefaultTextStyle.of(context).style.merge(labelStyle);
        final widest = tabs.fold<double>(0, (max, t) {
          final painter = TextPainter(
            text: TextSpan(text: t, style: style),
            textDirection: Directionality.of(context),
            textScaler: scaler,
            maxLines: 1,
          )..layout();
          final w = painter.width;
          painter.dispose();
          return w > max ? w : max;
        });
        final compact = widest + 32 > perTab;
        final crowded = widest + 20 > perTab;
        final labelPadding = compact && !crowded ? const EdgeInsets.symmetric(horizontal: 10) : null;

        return TabBar(
        controller: controller,
        isScrollable: crowded,
        tabAlignment: crowded ? TabAlignment.start : null,
        indicatorColor: c.accent,
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: c.accent,
        unselectedLabelColor: c.textSecondary,
        labelStyle: labelStyle,
        labelPadding: labelPadding,
        unselectedLabelStyle: const TextStyle(fontSize: 14),
        tabs: tabs.map((t) => Tab(height: 46, text: t)).toList(),
        );
      }),
      ),
    );
  }
}

class SwipeTabs extends StatelessWidget {
  final TabController controller;
  final Widget child;

  const SwipeTabs({super.key, required this.controller, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity.abs() < 220) return;

        final next = velocity < 0 ? controller.index + 1 : controller.index - 1;
        if (next < 0 || next >= controller.length) return;

        HapticFeedback.selectionClick();
        controller.animateTo(next);
      },
      child: child,
    );
  }
}

