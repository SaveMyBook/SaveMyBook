import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import 'animations.dart';

enum LoadingStyle { spinner, list, grid }

class LoadingView extends StatelessWidget {
  final LoadingStyle style;

  const LoadingView({super.key, this.style = LoadingStyle.spinner});

  const LoadingView.list({super.key}) : style = LoadingStyle.list;

  const LoadingView.grid({super.key}) : style = LoadingStyle.grid;

  @override
  Widget build(BuildContext context) {
    switch (style) {
      case LoadingStyle.list:
        return Shimmer(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 5,
            itemBuilder: (_, _) => const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: _SkeletonRow(),
            ),
          ),
        );

      case LoadingStyle.grid:
        return Shimmer(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.58,
            ),
            itemCount: 4,
            itemBuilder: (_, _) => const _SkeletonCard(),
          ),
        );

      case LoadingStyle.spinner:
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(48),
            child: FadeSlideIn(
              offsetY: 0,
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          ),
        );
    }
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(16)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBox(width: 64, height: 86, radius: 10),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                const SkeletonBox(height: 14),
                const SizedBox(height: 10),
                const SkeletonBox(width: 120, height: 12),
                const SizedBox(height: 10),
                const SkeletonBox(width: 80, height: 12),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: const SkeletonBox(width: 60, height: 18, radius: 8),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Container(
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBox(height: 140, radius: 16),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonBox(height: 14),
                SizedBox(height: 10),
                SkeletonBox(width: 90, height: 12),
                SizedBox(height: 12),
                SkeletonBox(width: 60, height: 18, radius: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyView({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeSlideIn(
              offsetY: 14,
              child: Icon(icon, size: 56, color: c.iconInactive),
            ),
            const SizedBox(height: 16),
            FadeSlideIn(
              index: 1,
              stagger: const Duration(milliseconds: 90),
              offsetY: 12,
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textSecondary, fontSize: 15),
              ),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 20),
              FadeSlideIn(
                index: 2,
                stagger: const Duration(milliseconds: 90),
                offsetY: 12,
                child: ElevatedButton(
                  onPressed: onAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(actionLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AppCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.onLongPress,
  });

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    final radius = BorderRadius.circular(16);

    return Padding(
      padding: widget.margin,
      child: AnimatedScale(
        scale: _pressed ? 0.975 : 1.0,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOut,
        // 陰影必須畫在最外層：畫在 Material 內層時會在卡片邊緣內側描出一圈灰邊。
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: c.shadow.withValues(alpha: _pressed ? 0.02 : 0.05),
                blurRadius: _pressed ? 4 : 10,
                offset: Offset(0, _pressed ? 1 : 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: radius,
            elevation: 0,
            child: InkWell(
              borderRadius: radius,
              onTap: widget.onTap,
              onLongPress: widget.onLongPress,
              onHighlightChanged: (value) {
                if (widget.onTap == null && widget.onLongPress == null) return;
                if (_pressed == value) return;
                setState(() => _pressed = value);
              },
              child: Padding(padding: widget.padding, child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}

class BookThumbnail extends StatelessWidget {
  final String? imageUrl;
  final double width;
  final double height;
  final double radius;

  const BookThumbnail({
    super.key,
    required this.imageUrl,
    this.width = 72,
    this.height = 96,
    this.radius = 10,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final placeholder = Icon(Icons.menu_book_rounded, color: c.iconInactive, size: width * 0.4);

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: width,
        height: height,
        color: c.inputFill,
        child: imageUrl == null || imageUrl!.isEmpty
            ? placeholder
            : Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => placeholder,
                frameBuilder: (_, child, frame, wasSynchronouslyLoaded) {
                  if (wasSynchronouslyLoaded) return child;
                  return AnimatedOpacity(
                    opacity: frame == null ? 0 : 1,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    child: child,
                  );
                },
              ),
      ),
    );
  }
}

/// 首頁的浮動導覽列還在畫面上時為 true；由 HomeScreen 自己維護。
/// SnackBar 是掛在 app 層級的 ScaffoldMessenger，不會自己避開導覽列。
bool kBottomNavVisible = false;

void showAppSnackBar(BuildContext context, String message, {bool isError = false}) {
  final overlapsNav = kBottomNavVisible && (ModalRoute.of(context)?.isFirst ?? false);
  final bottomInset = MediaQuery.of(context).viewInsets.bottom;

  // 浮動 SnackBar 本身已經會避開下方安全區，這裡只要再補導覽列的高度
  // （60 高 + 12 下緣留白 + 8 空隙），多加安全區會整個浮太高。
  final bottomMargin = bottomInset > 0 ? 16.0 : (overlapsNav ? 80.0 : 16.0);

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.of(context).danger : AppColors.of(context).accent,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(16, 0, 16, bottomMargin),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
}
