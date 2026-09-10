import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

/// 全 App 共用的頁首：深色底、白字、左側返回鍵、中間 icon + 標題、右側動作鍵。
/// 與首頁／會員中心既有的圓角深色 header 視覺一致。
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

    return Container(
      // 必須撐滿寬度：AppHeader 通常放在 Column 裡，而 Column 預設的
      // crossAxisAlignment.center 會讓子項目收縮成內容寬度，造成 header
      // 變成畫面中間一小塊、Positioned 的返回鍵與動作鍵疊到標題上。
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
              // 左右各留出按鈕的位置，長標題才不會壓到返回鍵／動作鍵
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
    );
  }
}

/// header 右側的圖示按鈕，可帶未讀數角標。
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
                color: Colors.redAccent,
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

/// 內容區的分頁列（購買紀錄、銷售紀錄、檢舉審核、交易仲裁共用）。
/// 依 Figma 放在白色內容區、用主色底線；壓在深色 header 上時指示器會
/// 超出圓角，看起來像一塊白色突出物。
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
        indicatorColor: AppColors.primary,
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: AppColors.primary,
        unselectedLabelColor: c.textSecondary,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontSize: 14),
        tabs: tabs.map((t) => Tab(height: 46, text: t)).toList(),
      ),
    );
  }
}
