import 'package:flutter/material.dart';

import '../../../utils/app_colors.dart';
import '../../../widgets/responsive.dart';
import '../widgets/chat_format.dart';

Future<T?> openGroupFlow<T>(BuildContext context, Widget page) {
  if (!context.isWide) return Navigator.push<T>(context, MaterialPageRoute(builder: (_) => page));
  final c = AppColors.of(context);
  // 平板的頁面放在分頁各自的 Navigator 內，視窗開在最上層才會連側邊欄一起蓋住
  return showDialog<T>(
    context: context,
    useRootNavigator: true,
    barrierColor: c.scrim,
    builder: (ctx) => Dialog(
      backgroundColor: c.scaffold,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 600,
        height: 760,
        // 視窗內不再留狀態列與主畫面指示條的安全區域，否則頁首上方會多出一段空白
        child: MediaQuery.removePadding(
          context: ctx,
          removeTop: true,
          removeBottom: true,
          removeLeft: true,
          removeRight: true,
          child: _GroupFlowScope(child: page),
        ),
      ),
    ),
  );
}

class _GroupFlowScope extends InheritedWidget {
  const _GroupFlowScope({required super.child});

  @override
  bool updateShouldNotify(_GroupFlowScope oldWidget) => false;
}

bool isGroupFlowSheet(BuildContext context) => context.getInheritedWidgetOfExactType<_GroupFlowScope>() != null;

class GroupFlowCloseButton extends StatelessWidget {
  final VoidCallback onPressed;

  const GroupFlowCloseButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.close_rounded, color: AppColors.of(context).textPrimary),
      tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
      onPressed: onPressed,
    );
  }
}

class GroupToolbarButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const GroupToolbarButton({super.key, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: SizedBox(
        height: 36,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: chatMineBubble(c),
            foregroundColor: Colors.white,
            disabledBackgroundColor: c.inputFill,
            disabledForegroundColor: c.textHint,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(label, maxLines: 1, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}
