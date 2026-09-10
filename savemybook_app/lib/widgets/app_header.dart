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

  const AppHeader({
    super.key,
    required this.title,
    this.icon,
    this.showBack = true,
    this.actions = const [],
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return LightStatusBar(
      child: Container(
        // 必須撐滿寬度：Column 預設的 crossAxisAlignment.center 會讓子項目收縮成
        // 內容寬度，header 會變成畫面中間一小塊，Positioned 的按鈕也會疊到標題上。
        width: double.infinity,
        decoration: BoxDecoration(
          color: c.headerBg,
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: 56,
            width: double.infinity,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 56),
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
      ),
    );
  }
}

class HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final int badgeCount;

  const HeaderIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(icon: Icon(icon, color: Colors.white, size: 22), onPressed: onTap),
        if (badgeCount > 0)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.of(context).danger,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                badgeCount > 99 ? '99+' : '$badgeCount',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ),
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
    return ValueListenableBuilder<int>(
      valueListenable: ApiService.cartCount,
      builder: (context, count, _) => Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            icon: Icon(Icons.shopping_cart_outlined, color: color, size: size),
            onPressed: onTap,
          ),
          if (count > 0)
            Positioned(
              right: 2,
              top: 4,
              child: PopIn(
                triggerKey: count,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.of(context).danger,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
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
