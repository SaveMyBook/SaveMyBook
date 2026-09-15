import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/motion.dart';
import 'animations.dart';

OverlayEntry? _current;
GlobalKey<_BannerState>? _currentKey;
Timer? _dismissTimer;

void showInAppBanner(
  OverlayState overlay, {
  required String title,
  required String body,
  IconData icon = Icons.notifications_rounded,
  String? imageUrl,
  VoidCallback? onTap,
}) {
  _dismiss();

  final key = GlobalKey<_BannerState>();
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _Banner(
      key: key,
      title: title,
      body: body,
      icon: icon,
      imageUrl: imageUrl,
      onTap: () {
        _dismiss();
        onTap?.call();
      },
      onDismiss: _dismiss,
    ),
  );
  _current = entry;
  _currentKey = key;
  overlay.insert(entry);
  _dismissTimer = Timer(const Duration(seconds: 4), () => _close(entry));
}

Future<void> _close(OverlayEntry entry) async {
  if (!identical(_current, entry)) return;
  await _currentKey?.currentState?.close();
  if (identical(_current, entry)) _dismiss();
}

void _dismiss() {
  _dismissTimer?.cancel();
  _dismissTimer = null;
  _current?.remove();
  _current = null;
  _currentKey = null;
}

class _Banner extends StatefulWidget {
  final String title;
  final String body;
  final IconData icon;
  final String? imageUrl;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _Banner({
    super.key,
    required this.title,
    required this.body,
    required this.icon,
    this.imageUrl,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  State<_Banner> createState() => _BannerState();
}

class _BannerState extends State<_Banner> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Motion.base,
    reverseDuration: Motion.micro,
  )..forward();

  Future<void> close() async {
    if (!mounted) return;
    await _controller.reverse();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _leading(AppColors c) {
    final iconTile = Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: c.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(widget.icon, size: 20, color: c.accent),
    );
    final url = widget.imageUrl;
    if (url == null || url.isEmpty) return iconTile;

    final dpr = MediaQuery.devicePixelRatioOf(context);
    return SizedBox(
      width: 42,
      height: 42,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipOval(
            child: Image.network(
              url,
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              cacheWidth: (40 * dpr).round(),
              errorBuilder: (_, _, _) => iconTile,
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 18,
              height: 18,
              padding: const EdgeInsets.all(1.5),
              decoration: BoxDecoration(color: c.card, shape: BoxShape.circle),
              child: ClipOval(child: Image.asset('assets/images/logo.png', fit: BoxFit.cover, cacheWidth: (16 * dpr).round())),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final top = MediaQuery.of(context).padding.top + 8;
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Motion.emphasized,
      reverseCurve: Motion.exitCurve,
    );

    return Positioned(
      top: top,
      left: 12,
      right: 12,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, -1.2), end: Offset.zero).animate(curved),
        child: FadeTransition(
          opacity: _controller,
          child: Dismissible(
            key: const ValueKey('in_app_banner'),
            direction: DismissDirection.up,
            onDismissed: (_) => widget.onDismiss(),
            child: Material(
              color: Colors.transparent,
              child: PressableScale(
                scale: 0.98,
                onTap: widget.onTap,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: c.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: c.divider.withValues(alpha: 0.6)),
                    boxShadow: [BoxShadow(color: c.shadow, blurRadius: 20, offset: const Offset(0, 6))],
                  ),
                  child: Row(
                    children: [
                      _leading(c),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c.textPrimary),
                            ),
                            if (widget.body.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                widget.body,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 13, height: 1.35, color: c.textSecondary),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
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
