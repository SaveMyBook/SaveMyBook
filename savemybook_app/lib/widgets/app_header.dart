import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import 'animations.dart';

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
  final VoidCallback? onBack;

  /// 直接接在標題列下面的東西（頁籤、篩選列）。放進來才會跟 header 共用同一個
  /// 圓角容器，否則 header 的圓角會在下面那條列的左右各留一塊空白缺口。
  final Widget? bottom;

  const AppHeader({
    super.key,
    required this.title,
    this.icon,
    this.showBack = true,
    this.actions = const [],
    this.onBack,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    // 有頁籤／篩選列接在下面時整塊都不做圓角：圓角會把頁籤的底線指示器
    // 切掉，而且白色的列被削出圓弧會在下面露出底色。
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
          // 必須撐滿寬度：Column 預設的 crossAxisAlignment.center 會讓子項目收縮成
          // 內容寬度，header 會變成畫面中間一小塊，Positioned 的按鈕也會疊到標題上。
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
                        // 標題置中，所以兩側必須留一樣寬；右邊按鈕多的時候要一起加寬，
                        // 否則長標題會壓到 action 按鈕上。
                        padding: EdgeInsets.symmetric(
                          horizontal: actions.isEmpty ? 56 : 56 + (actions.length - 1) * 44.0,
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
      child: Container(
        constraints: const BoxConstraints(minWidth: 16),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: color ?? AppColors.of(context).danger,
          borderRadius: BorderRadius.circular(10),
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

class CartIconButton extends StatelessWidget {
  final VoidCallback onTap;
  final double size;
  final Color color;

  const CartIconButton({
    super.key,
    required this.onTap,
    this.size = 22,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return HeaderIconButton(
      icon: Icons.shopping_cart_outlined,
      onTap: onTap,
      size: size,
      color: color,
      badgeListenable: ApiService.cartCount,
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

    return Container(
      width: double.infinity,
      color: c.card,
      child: TabBar(
        controller: controller,
        indicatorColor: c.accent,
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: c.accent,
        unselectedLabelColor: c.textSecondary,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontSize: 14),
        tabs: tabs.map((t) => Tab(height: 46, text: t)).toList(),
      ),
    );
  }
}
