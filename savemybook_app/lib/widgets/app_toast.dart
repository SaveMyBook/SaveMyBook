import 'dart:async';

import 'package:flutter/material.dart';

import '../utils/app_colors.dart';
import '../utils/motion.dart';

bool kBottomNavVisible = false;

class ToastRouteTracker extends NavigatorObserver {
  static final ToastRouteTracker instance = ToastRouteTracker._();
  ToastRouteTracker._();

  static final ValueNotifier<int> changes = ValueNotifier<int>(0);
  final List<Route<dynamic>> _routes = [];

  bool get navOnScreen => kBottomNavVisible && _routes.whereType<PageRoute<dynamic>>().length <= 1;

  void _changed() => WidgetsBinding.instance.addPostFrameCallback((_) => changes.value++);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.add(route);
    _changed();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _changed();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _changed();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (index >= 0 && newRoute != null) {
      _routes[index] = newRoute;
    } else if (newRoute != null) {
      _routes.add(newRoute);
    }
    _changed();
  }

  static void notifyNavVisibility() => instance._changed();
}

enum ToastCloseReason { timeout, action, dismissed, replaced }

class _ActiveToast {
  final OverlayEntry entry;
  final GlobalKey<_ToastViewState> key;
  final Completer<ToastCloseReason> completer;

  _ActiveToast(this.entry, this.key, this.completer);
}

_ActiveToast? _current;

Future<ToastCloseReason> showToast(
  BuildContext context, {
  required Widget Function(BuildContext context, void Function(ToastCloseReason reason) close) builder,
  Duration duration = const Duration(milliseconds: 2600),
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return Future.value(ToastCloseReason.dismissed);

  _current?.key.currentState?.close(ToastCloseReason.replaced);

  final key = GlobalKey<_ToastViewState>();
  final completer = Completer<ToastCloseReason>();
  late final OverlayEntry entry;
  late final _ActiveToast active;
  entry = OverlayEntry(
    builder: (_) => _ToastView(
      key: key,
      duration: duration,
      builder: builder,
      onClosed: (reason) {
        entry.remove();
        if (identical(_current, active)) _current = null;
        if (!completer.isCompleted) completer.complete(reason);
      },
    ),
  );
  active = _ActiveToast(entry, key, completer);
  _current = active;
  overlay.insert(entry);
  return completer.future;
}

void hideCurrentToast() => _current?.key.currentState?.close(ToastCloseReason.dismissed);

class _ToastView extends StatefulWidget {
  final Duration duration;
  final Widget Function(BuildContext context, void Function(ToastCloseReason reason) close) builder;
  final ValueChanged<ToastCloseReason> onClosed;

  const _ToastView({super.key, required this.duration, required this.builder, required this.onClosed});

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: Motion.base);
  Timer? _timer;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _timer = Timer(widget.duration, () => close(ToastCloseReason.timeout));
  }

  Future<void> close(ToastCloseReason reason) async {
    if (_closing) return;
    _closing = true;
    _timer?.cancel();
    if (mounted && reason != ToastCloseReason.replaced) {
      await _controller.reverse();
    }
    widget.onClosed(reason);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return ValueListenableBuilder<int>(
      valueListenable: ToastRouteTracker.changes,
      builder: (context, _, child) {
        final keyboard = media.viewInsets.bottom;
        final nav = keyboard == 0 && ToastRouteTracker.instance.navOnScreen;
        final bottom = keyboard > 0 ? keyboard + 12 : media.padding.bottom + (nav ? 72 : 16);
        return AnimatedPositioned(
          duration: Motion.base,
          curve: Motion.standard,
          left: 16,
          right: 16,
          bottom: bottom,
          child: child!,
        );
      },
      child: SafeArea(
        top: false,
        bottom: false,
        child: FadeTransition(
          opacity: CurvedAnimation(parent: _controller, curve: Motion.enterCurve, reverseCurve: Motion.exitCurve),
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.4), end: Offset.zero)
                .animate(CurvedAnimation(parent: _controller, curve: Motion.emphasized, reverseCurve: Motion.exitCurve)),
            child: Dismissible(
              key: const ValueKey('toast'),
              direction: DismissDirection.down,
              onDismissed: (_) {
                _closing = true;
                _timer?.cancel();
                widget.onClosed(ToastCloseReason.dismissed);
              },
              child: Material(
                type: MaterialType.transparency,
                child: widget.builder(context, close),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ToastCard extends StatelessWidget {
  final IconData icon;
  final Color tint;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const ToastCard({super.key, required this.icon, required this.tint, required this.message, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(12, 10, actionLabel == null ? 16 : 6, 10),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tint.withValues(alpha: 0.35)),
        boxShadow: [BoxShadow(color: c.shadow, blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: tint.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 18, color: tint),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13.5, height: 1.4, fontWeight: FontWeight.w500, color: c.textPrimary),
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(width: 4),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: c.accent,
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(actionLabel!, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }
}
