import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import 'animations.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
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

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.onTap,
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
              onHighlightChanged: (value) {
                if (widget.onTap == null || _pressed == value) return;
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

  // 導覽列高 60 + 下方留白 12 + 安全區，再往上留一點空隙。
  final bottomMargin = bottomInset > 0
      ? 16.0
      : (overlapsNav ? MediaQuery.of(context).padding.bottom + 88 : 16.0);

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
