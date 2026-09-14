import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_colors.dart';

class SwipeAction {
  final IconData icon;
  final String label;
  final Color color;
  final Future<bool> Function() onTrigger;

  // dismisses 為 true 時必須在這裡同步把資料移出清單，否則 Dismissible 會丟例外。
  final VoidCallback? onDismissed;

  final bool dismisses;

  const SwipeAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTrigger,
    this.onDismissed,
    this.dismisses = false,
  });
}

class SwipeActionTile extends StatelessWidget {
  final Widget child;
  final Key itemKey;
  final SwipeAction? endToStart;
  final SwipeAction? startToEnd;
  final EdgeInsets backgroundMargin;

  const SwipeActionTile({
    super.key,
    required this.itemKey,
    required this.child,
    this.endToStart,
    this.startToEnd,
    this.backgroundMargin = const EdgeInsets.only(bottom: 12),
  });

  DismissDirection get _direction {
    if (endToStart != null && startToEnd != null) return DismissDirection.horizontal;
    if (endToStart != null) return DismissDirection.endToStart;
    if (startToEnd != null) return DismissDirection.startToEnd;
    return DismissDirection.none;
  }

  SwipeAction? _actionFor(DismissDirection direction) =>
      direction == DismissDirection.endToStart ? endToStart : startToEnd;

  Widget _background(BuildContext context, SwipeAction action, bool alignRight) {
    return Container(
      margin: backgroundMargin,
      padding: EdgeInsets.only(left: alignRight ? 0 : 22, right: alignRight ? 22 : 0),
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      decoration: BoxDecoration(
        color: action.color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(action.icon, color: Colors.white, size: 22),
          const SizedBox(height: 4),
          Text(
            action.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_direction == DismissDirection.none) return child;

    final c = AppColors.of(context);
    final fallback = Container(margin: backgroundMargin, color: c.scaffold);

    return Dismissible(
      key: itemKey,
      direction: _direction,
      dismissThresholds: const {
        DismissDirection.endToStart: 0.35,
        DismissDirection.startToEnd: 0.35,
      },
      background: startToEnd == null
          ? fallback
          : _background(context, startToEnd!, false),
      secondaryBackground: endToStart == null
          ? fallback
          : _background(context, endToStart!, true),
      onDismissed: (direction) => _actionFor(direction)?.onDismissed?.call(),
      confirmDismiss: (direction) async {
        final action = _actionFor(direction);
        if (action == null) return false;

        HapticFeedback.mediumImpact();
        final ok = await action.onTrigger();
        return ok && action.dismisses;
      },
      child: child,
    );
  }
}
