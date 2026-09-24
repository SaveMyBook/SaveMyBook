import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/motion.dart';
import 'animations.dart';
import 'app_asset_image.dart';
import 'state_views.dart';

class _BannerRequest {
  final OverlayState overlay;
  final String title;
  final String body;
  final IconData icon;
  final String? imageUrl;
  final VoidCallback? onTap;
  final String? groupKey;

  const _BannerRequest(this.overlay, this.title, this.body, this.icon, this.imageUrl, this.onTap, this.groupKey);
}

const _displayTime = Duration(seconds: 4);
const _queuedDisplayTime = Duration(milliseconds: 2500);
const _maxQueue = 5;

OverlayEntry? _current;
GlobalKey<_BannerState>? _currentKey;
_BannerRequest? _currentRequest;
DateTime? _shownAt;
Timer? _dismissTimer;
final List<_BannerRequest> _queue = [];

/// 同時收到多則通知時依序顯示，不會讓前一則瞬間被蓋掉；
/// 同一個對象（例如同一個聊天室）的新通知直接更新目前的橫幅，不重複排隊。
void showInAppBanner(
  OverlayState overlay, {
  required String title,
  required String body,
  IconData icon = Icons.notifications_rounded,
  String? imageUrl,
  VoidCallback? onTap,
  String? groupKey,
}) {
  final request = _BannerRequest(overlay, title, body, icon, imageUrl, onTap, groupKey);
  final showing = _currentRequest;
  if (showing == null) {
    _present(request);
    return;
  }
  if (groupKey != null && showing.groupKey == groupKey) {
    _present(request);
    return;
  }
  _queue.removeWhere((q) => groupKey != null && q.groupKey == groupKey);
  _queue.add(request);
  if (_queue.length > _maxQueue) _queue.removeAt(0);
  _scheduleClose();
}

void _present(_BannerRequest request) {
  _removeCurrent();
  final key = GlobalKey<_BannerState>();
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _Banner(
      key: key,
      title: request.title,
      body: request.body,
      icon: request.icon,
      imageUrl: request.imageUrl,
      onTap: () {
        _queue.clear();
        _removeCurrent();
        request.onTap?.call();
      },
      onDismiss: () {
        _removeCurrent();
        _showNext();
      },
    ),
  );
  _current = entry;
  _currentKey = key;
  _currentRequest = request;
  _shownAt = DateTime.now();
  request.overlay.insert(entry);
  _scheduleClose();
}

// 有排隊的通知時縮短停留時間（仍至少顯示 2.5 秒），沒有時顯示 4 秒。
void _scheduleClose() {
  final entry = _current;
  final shownAt = _shownAt;
  if (entry == null || shownAt == null) return;
  final wait = (_queue.isEmpty ? _displayTime : _queuedDisplayTime) - DateTime.now().difference(shownAt);
  _dismissTimer?.cancel();
  _dismissTimer = Timer(wait.isNegative ? Duration.zero : wait, () => _close(entry));
}

Future<void> _close(OverlayEntry entry) async {
  if (!identical(_current, entry)) return;
  await _currentKey?.currentState?.close();
  if (!identical(_current, entry)) return;
  _removeCurrent();
  _showNext();
}

void _showNext() {
  if (_queue.isEmpty) return;
  final next = _queue.removeAt(0);
  if (!next.overlay.mounted) {
    _showNext();
    return;
  }
  _present(next);
}

void _removeCurrent() {
  _dismissTimer?.cancel();
  _dismissTimer = null;
  _current?.remove();
  _current = null;
  _currentKey = null;
  _currentRequest = null;
  _shownAt = null;
}

@visibleForTesting
void resetInAppBanners() {
  _queue.clear();
  _removeCurrent();
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
      decoration: BoxDecoration(color: c.accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(11)),
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
            child: AppNetworkImage(
              url: url,
              width: 40,
              height: 40,
              cacheWidth: (40 * dpr).round(),
              errorWidget: iconTile,
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
              child: ClipOval(
                child: AppAssetImage(
                  asset: 'assets/images/logo.png',
                  fit: BoxFit.cover,
                  cacheWidth: (16 * dpr).round(),
                  fallbackIcon: Icons.menu_book_rounded,
                  fallbackIconSize: 12,
                ),
              ),
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
    final curved = CurvedAnimation(parent: _controller, curve: Motion.emphasized, reverseCurve: Motion.exitCurve);

    return Positioned(
      top: top,
      left: 12,
      right: 12,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, -1.2), end: Offset.zero).animate(curved),
        child: FadeTransition(
          opacity: _controller,
          child: Dismissible(
            key: ValueKey('in_app_banner_${identityHashCode(widget)}'),
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
