import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import 'animations.dart';
import '../utils/motion.dart';
import 'responsive.dart';

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
    // 平板左右並排時右側內容與分頁的第一頁沒有上一頁，不顯示返回鍵；
    // 以頁面本身底下有無頁面判斷，頁面上開著對話框時 Navigator.canPop 也為 true
    final back = showBack &&
        (onBack != null ||
            (ModalRoute.of(context)?.impliesAppBarDismissal ?? Navigator.maybeOf(context)?.canPop() ?? false));
    if (context.isWide) {
      return TabletToolbar(title: title, showBack: back, onBack: onBack, actions: actions, bottom: bottom);
    }

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
                      if (back)
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

/// 頁首按鈕的前景色：手機的品牌色頁首為白色，平板的工具列跟隨文字色。
class HeaderForeground extends InheritedWidget {
  final Color color;

  const HeaderForeground({super.key, required this.color, required super.child});

  static Color of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HeaderForeground>()?.color ?? Colors.white;

  @override
  bool updateShouldNotify(HeaderForeground oldWidget) => color != oldWidget.color;
}

/// 平板的頁首：與內容同底色、標題靠左、下方細分隔線，左右並排時兩欄頁首等高相連。
class TabletToolbar extends StatelessWidget {
  static const double height = 56;

  final String title;
  final Widget? titleWidget;
  final bool showBack;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final Widget? bottom;
  final Widget? leading;

  const TabletToolbar({
    super.key,
    this.title = '',
    this.titleWidget,
    this.showBack = false,
    this.onBack,
    this.actions = const [],
    this.bottom,
    this.leading,
  });

  static SystemUiOverlayStyle overlayStyle(AppColors c) => SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: c.isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: c.isDark ? Brightness.dark : Brightness.light,
      );

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle(c),
      child: Material(
        color: c.scaffold,
        child: HeaderForeground(
          color: c.textPrimary,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SafeArea(
                bottom: false,
                child: SizedBox(
                  height: height,
                  child: Row(
                    children: [
                      SizedBox(width: showBack || leading != null ? 6 : 20),
                      if (showBack)
                        IconButton(
                          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: c.accent),
                          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                          onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                        ),
                      ?leading,
                      if (showBack || leading != null) const SizedBox(width: 4),
                      Expanded(
                        child: titleWidget ??
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: c.textPrimary),
                            ),
                      ),
                      if (actions.isNotEmpty) Row(mainAxisSize: MainAxisSize.min, children: actions),
                      SizedBox(width: actions.isEmpty ? 20 : 8),
                    ],
                  ),
                ),
              ),
              ?bottom,
              Divider(height: 1, thickness: 1, color: c.divider),
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
  final Color? color;
  final String? tooltip;

  const HeaderIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.badgeCount = 0,
    this.badgeListenable,
    this.size = 22,
    this.color,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    Widget badge(int count) => Positioned(right: 2, top: 4, child: CountBadge(count: count));

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(icon: Icon(icon, color: color ?? HeaderForeground.of(context), size: size), tooltip: tooltip, onPressed: onTap),
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
  final Color? color;

  const CartIconButton({
    super.key,
    required this.onTap,
    this.size = 22,
    this.color,
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
  final Color? color;

  const ChatIconButton({
    super.key,
    required this.onTap,
    this.size = 22,
    this.color,
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
  final List<int> badges;

  const AppTabBar({super.key, required this.controller, required this.tabs, this.badges = const []});

  int _badgeAt(int i) => i < badges.length ? badges[i] : 0;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    const labelStyle = TextStyle(fontSize: 14, fontWeight: FontWeight.bold);
    if (context.isWide) return _buildTablet(c, labelStyle);

    return Container(
      width: double.infinity,
      color: c.card,
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: LayoutBuilder(builder: (context, constraints) {
        final scaler = MediaQuery.textScalerOf(context);
        final perTab = constraints.maxWidth / tabs.length;
        final style = DefaultTextStyle.of(context).style.merge(labelStyle);
        var widest = 0.0;
        for (var i = 0; i < tabs.length; i++) {
          final painter = TextPainter(
            text: TextSpan(text: tabs[i], style: style),
            textDirection: Directionality.of(context),
            textScaler: scaler,
            maxLines: 1,
          )..layout();
          final w = painter.width + (_badgeAt(i) > 0 ? 28 : 0);
          painter.dispose();
          if (w > widest) widest = w;
        }
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
        tabs: [
          for (var i = 0; i < tabs.length; i++)
            _badgeAt(i) > 0
                ? Tab(
                    height: 46,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(child: Text(tabs[i], maxLines: 1, overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 6),
                        UnconstrainedBox(child: CountBadge(count: _badgeAt(i))),
                      ],
                    ),
                  )
                : Tab(height: 46, text: tabs[i]),
        ],
        );
      }),
      ),
    );
  }
}

extension on AppTabBar {
  // 平板：分頁標籤靠左排列、與工具列同底色，不再撐滿整個寬度
  Widget _buildTablet(AppColors c, TextStyle labelStyle) {
    return Container(
      width: double.infinity,
      color: c.scaffold,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.centerLeft,
      child: TabBar(
        controller: controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicatorColor: c.accent,
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        labelColor: c.accent,
        unselectedLabelColor: c.textSecondary,
        labelStyle: labelStyle,
        labelPadding: const EdgeInsets.symmetric(horizontal: 14),
        unselectedLabelStyle: const TextStyle(fontSize: 14),
        tabs: [
          for (var i = 0; i < tabs.length; i++)
            Tab(
              height: 44,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(tabs[i], maxLines: 1),
                  if (_badgeAt(i) > 0) ...[const SizedBox(width: 6), UnconstrainedBox(child: CountBadge(count: _badgeAt(i)))],
                ],
              ),
            ),
        ],
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

