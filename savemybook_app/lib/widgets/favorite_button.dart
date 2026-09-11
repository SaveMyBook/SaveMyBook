import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../utils/motion.dart';
import 'animations.dart';
import 'state_views.dart';

/// 收藏愛心。狀態統一綁在 ApiService.favoriteBookIds，
/// 首頁卡片、書籍詳情、收藏清單按下去會同步變動。
class FavoriteButton extends StatefulWidget {
  final int bookId;
  final double size;
  final Color? inactiveColor;
  final IconData activeIcon;
  final IconData inactiveIcon;

  const FavoriteButton({
    super.key,
    required this.bookId,
    this.size = 20,
    this.inactiveColor,
    this.activeIcon = Icons.bookmark_rounded,
    this.inactiveIcon = Icons.bookmark_border_rounded,
  });

  @override
  State<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton> {
  final ApiService _api = ApiService();
  final GlobalKey<BurstRingState> _burstKey = GlobalKey<BurstRingState>();
  bool _isBusy = false;

  Future<void> _toggle() async {
    if (_isBusy) return;

    // 收藏才放擴散圈，取消收藏不放 —— 慶祝的動作只該出現在正向的操作上。
    final willFavorite = !ApiService.favoriteBookIds.value.contains(widget.bookId);
    if (willFavorite) {
      HapticFeedback.mediumImpact();
      _burstKey.currentState?.fire();
    } else {
      HapticFeedback.selectionClick();
    }

    setState(() => _isBusy = true);
    final error = await _api.toggleFavorite(widget.bookId);
    if (!mounted) return;
    setState(() => _isBusy = false);
    if (error != null) showAppSnackBar(context, error, isError: true);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final burstSize = widget.size + 18;

    return ValueListenableBuilder<Set<int>>(
      valueListenable: ApiService.favoriteBookIds,
      builder: (context, ids, _) {
        final isFavorite = ids.contains(widget.bookId);
        return PressableScale(
          scale: 0.78,
          onTap: _toggle,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: SizedBox(
              width: burstSize,
              height: burstSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  BurstRing(key: _burstKey, color: c.accent, size: burstSize),
                  // 切換圖示時順帶轉一點角度，書籤是「翻進去」而不是硬換。
                  AnimatedSwitcher(
                    duration: Motion.base,
                    switchInCurve: Motion.pop,
                    switchOutCurve: Motion.exitCurve,
                    transitionBuilder: (child, animation) => ScaleTransition(
                      scale: animation,
                      child: RotationTransition(
                        turns: Tween<double>(begin: -0.14, end: 0).animate(animation),
                        child: FadeTransition(opacity: animation, child: child),
                      ),
                    ),
                    child: Icon(
                      isFavorite ? widget.activeIcon : widget.inactiveIcon,
                      key: ValueKey(isFavorite),
                      size: widget.size,
                      color: isFavorite ? c.accent : (widget.inactiveColor ?? c.iconInactive),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
