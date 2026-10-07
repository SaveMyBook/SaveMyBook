import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../utils/app_colors.dart';
import '../../widgets/state_views.dart';

/// 平板的登入相關頁面：內容置中並以卡片呈現，比照登入頁的寬螢幕版面。
class AuthWideCard extends StatelessWidget {
  final List<Widget> children;
  final double maxWidth;

  const AuthWideCard({super.key, required this.children, this.maxWidth = 500});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(24, 24, 24, bottom + 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: math.max(0, constraints.maxHeight - 48 - bottom)),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Container(
                decoration: authCardDecoration(c),
                padding: const EdgeInsets.fromLTRB(32, 28, 32, 28),
                child: _AuthWideScope(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

BoxDecoration authCardDecoration(AppColors c) => BoxDecoration(
      color: c.card,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 40, offset: const Offset(0, 12))],
    );

class _AuthWideScope extends InheritedWidget {
  const _AuthWideScope({required super.child});

  @override
  bool updateShouldNotify(_AuthWideScope oldWidget) => false;
}

/// 表單區塊：手機為獨立卡片；放在 [AuthWideCard] 內時已有外框，改為一般區塊。
class AuthSection extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;

  const AuthSection({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (context.getInheritedWidgetOfExactType<_AuthWideScope>() == null) {
      return AppCard(margin: margin, padding: padding, onTap: onTap, child: child);
    }
    final body = Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: child);
    return Padding(
      padding: margin,
      child: onTap == null
          ? body
          : Material(
              color: Colors.transparent,
              child: InkWell(borderRadius: BorderRadius.circular(12), onTap: onTap, child: body),
            ),
    );
  }
}
