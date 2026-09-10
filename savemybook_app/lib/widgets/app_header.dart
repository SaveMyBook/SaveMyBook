import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

/// 全 App 共用的頁首：深色底、白字、左側返回鍵、中間 icon + 標題、右側動作鍵。
/// 與首頁／會員中心既有的圓角深色 header 視覺一致。
class AppHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  final bool showBack;
  final List<Widget> actions;
  final Widget? bottom;
  final VoidCallback? onBack;

  const AppHeader({
    super.key,
    required this.title,
    this.icon,
    this.showBack = true,
    this.actions = const [],
    this.bottom,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Container(
      decoration: BoxDecoration(
        color: c.headerBg,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SizedBox(
              height: 56,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
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
            if (bottom != null) bottom!,
          ],
        ),
      ),
    );
  }
}

/// header 右側的白色圓形圖示按鈕
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
