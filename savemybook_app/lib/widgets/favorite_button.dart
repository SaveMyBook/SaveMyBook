import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
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
    this.activeIcon = Icons.favorite_rounded,
    this.inactiveIcon = Icons.favorite_border_rounded,
  });

  @override
  State<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton> {
  final ApiService _api = ApiService();
  bool _isBusy = false;

  Future<void> _toggle() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    final error = await _api.toggleFavorite(widget.bookId);
    if (!mounted) return;
    setState(() => _isBusy = false);
    if (error != null) showAppSnackBar(context, error, isError: true);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return ValueListenableBuilder<Set<int>>(
      valueListenable: ApiService.favoriteBookIds,
      builder: (context, ids, _) {
        final isFavorite = ids.contains(widget.bookId);
        return PressableScale(
          scale: 0.8,
          onTap: _toggle,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: PopIn(
              triggerKey: isFavorite,
              child: Icon(
                isFavorite ? widget.activeIcon : widget.inactiveIcon,
                size: widget.size,
                color: isFavorite ? c.danger : (widget.inactiveColor ?? c.iconInactive),
              ),
            ),
          ),
        );
      },
    );
  }
}
