import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

OverlayEntry? _current;
Timer? _dismissTimer;

/// App 開著時收到推播用的橫幅。
///
/// 系統在前景不會替 Android 顯示推播，iOS 也刻意關掉前景橫幅，
/// 兩邊統一由這裡顯示，才能在使用者正看著那個聊天室時略過。
void showInAppBanner(
  OverlayState overlay, {
  required String title,
  required String body,
  IconData icon = Icons.notifications_rounded,
  VoidCallback? onTap,
}) {
  _dismiss();

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _Banner(
      title: title,
      body: body,
      icon: icon,
      onTap: () {
        _dismiss();
        onTap?.call();
      },
      onDismiss: _dismiss,
    ),
  );
  _current = entry;
  overlay.insert(entry);
  _dismissTimer = Timer(const Duration(seconds: 4), _dismiss);
}

void _dismiss() {
  _dismissTimer?.cancel();
  _dismissTimer = null;
  _current?.remove();
  _current = null;
}

class _Banner extends StatefulWidget {
  final String title;
  final String body;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _Banner({
    required this.title,
    required this.body,
    required this.icon,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  State<_Banner> createState() => _BannerState();
}

class _BannerState extends State<_Banner> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final top = MediaQuery.of(context).padding.top + 8;

    return Positioned(
      top: top,
      left: 12,
      right: 12,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, -1.2), end: Offset.zero)
            .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic)),
        child: Dismissible(
          key: const ValueKey('in_app_banner'),
          direction: DismissDirection.up,
          onDismissed: (_) => widget.onDismiss(),
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: widget.onTap,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: c.card,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: c.shadow, blurRadius: 20, offset: const Offset(0, 6))],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: c.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(widget.icon, size: 20, color: c.accent),
                    ),
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
    );
  }
}
