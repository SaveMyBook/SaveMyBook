import 'package:flutter/material.dart';
import 'app_toast.dart';
export 'app_toast.dart' show kBottomNavVisible, hideCurrentToast;
import '../utils/app_colors.dart';
import '../utils/motion.dart';
import 'animations.dart';
import '../i18n/strings.dart';

enum LoadingStyle { spinner, list, grid, menu }

class LoadingView extends StatelessWidget {
  final LoadingStyle style;

  const LoadingView({super.key, this.style = LoadingStyle.spinner});

  const LoadingView.list({super.key}) : style = LoadingStyle.list;

  const LoadingView.grid({super.key}) : style = LoadingStyle.grid;

  const LoadingView.menu({super.key}) : style = LoadingStyle.menu;

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

      case LoadingStyle.menu:
        return Shimmer(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            physics: const NeverScrollableScrollPhysics(),
            children: const [
              SkeletonBox(height: 96, radius: 16),
              SizedBox(height: 24),
              _SkeletonSection(rows: 2),
              SizedBox(height: 24),
              _SkeletonSection(rows: 3),
              SizedBox(height: 24),
              _SkeletonSection(rows: 2),
            ],
          ),
        );

      case LoadingStyle.spinner:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(48),
            child: FadeSlideIn(
              offsetY: 0,
              child: CircularProgressIndicator(color: AppColors.of(context).accent),
            ),
          ),
        );
    }
  }
}

class _SkeletonSection extends StatelessWidget {
  final int rows;

  const _SkeletonSection({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 10),
          child: SkeletonBox(width: 72, height: 13),
        ),
        SkeletonBox(height: rows * 68.0, radius: 16),
      ],
    );
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
  final String? title;
  final IconData? actionIcon;

  const EmptyView({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.title,
    this.actionIcon,
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
              child: Breathe(
                child: AnimatedContainer(
                  duration: Motion.base,
                  curve: Motion.standard,
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        c.accent.withValues(alpha: c.isDark ? 0.14 : 0.09),
                        c.accent.withValues(alpha: 0),
                      ],
                    ),
                  ),
                  child: Icon(icon, size: 56, color: c.iconInactive),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (title != null) ...[
              FadeSlideIn(
                index: 1,
                stagger: const Duration(milliseconds: 90),
                offsetY: 12,
                child: Text(
                  title!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.textPrimary, fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 6),
            ],
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
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (actionIcon != null) ...[
                        Icon(actionIcon, size: 18),
                        const SizedBox(width: 6),
                      ],
                      Flexible(child: Text(actionLabel!, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: AppNetworkImage(
        url: imageUrl,
        width: width,
        height: height,
        fallbackIconSize: width * 0.4,
      ),
    );
  }
}

void showAppSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
  String? actionLabel,
  VoidCallback? onAction,
  Duration? duration,
}) {
  final c = AppColors.of(context);
  final hasAction = actionLabel != null && onAction != null;
  showToast(
    context,
    duration: duration ?? Duration(milliseconds: hasAction ? 4200 : 2600),
    builder: (context, close) => ToastCard(
      icon: isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
      tint: isError ? c.danger : c.success,
      message: message,
      actionLabel: hasAction ? actionLabel : null,
      onAction: hasAction
          ? () {
              close(ToastCloseReason.action);
              onAction();
            }
          : null,
    ),
  );
}

class AppNetworkImage extends StatelessWidget {
  final String? url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final IconData fallbackIcon;
  final double? fallbackIconSize;
  final Color? background;

  const AppNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.fallbackIcon = Icons.menu_book_rounded,
    this.fallbackIconSize,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final base = background ?? c.skeleton;

    Widget placeholder() => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                base,
                Color.lerp(base, c.isDark ? Colors.black : Colors.white, 0.45)!,
              ],
            ),
          ),
        );

    Widget fallback() => Container(
          width: width,
          height: height,
          color: base,
          alignment: Alignment.center,
          child: Icon(
            fallbackIcon,
            color: c.iconInactive.withValues(alpha: 0.55),
            size: fallbackIconSize ?? 30,
          ),
        );

    if (url == null || url!.isEmpty) return fallback();

    return Image.network(
      url!,
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (_, _, _) => fallback(),
      frameBuilder: (_, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        final loaded = frame != null;

        return Stack(
          fit: StackFit.passthrough,
          children: [
            placeholder(),
            AnimatedOpacity(
              opacity: loaded ? 1 : 0,
              duration: Motion.base,
              curve: Curves.easeOut,
              child: child,
            ),
          ],
        );
      },
    );
  }
}


class ErrorView extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;
  final IconData icon;
  final String? retryLabel;

  const ErrorView({
    super.key,
    this.message,
    this.onRetry,
    this.icon = Icons.cloud_off_rounded,
    this.retryLabel,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyView(
      icon: icon,
      message: message ?? S.loadFailed,
      actionLabel: onRetry == null ? null : (retryLabel ?? S.retry),
      actionIcon: Icons.refresh_rounded,
      onAction: onRetry,
    );
  }
}

class RefreshableCenter extends StatelessWidget {
  final Widget child;
  final Future<void> Function() onRefresh;

  const RefreshableCenter({super.key, required this.child, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return RefreshIndicator(
      color: c.accent,
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

class SuccessView extends StatelessWidget {
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onAnimationDone;

  const SuccessView({
    super.key,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.onAnimationDone,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DrawnCheck(color: c.success, size: 104, haptic: true, onCompleted: onAnimationDone),
            const SizedBox(height: 24),
            FadeSlideIn(
              index: 3,
              stagger: const Duration(milliseconds: 90),
              offsetY: 12,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: c.textPrimary),
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              FadeSlideIn(
                index: 4,
                stagger: const Duration(milliseconds: 90),
                offsetY: 12,
                child: Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, height: 1.6, color: c.textSecondary),
                ),
              ),
            ],
            if (actionLabel != null) ...[
              const SizedBox(height: 28),
              FadeSlideIn(
                index: 5,
                stagger: const Duration(milliseconds: 90),
                offsetY: 12,
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: onAction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(actionLabel!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class MonthHeader extends StatelessWidget {
  final String label;
  final String? trailing;

  const MonthHeader({super.key, required this.label, this.trailing});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Row(
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: c.textSecondary),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Divider(color: c.divider, height: 1)),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            Text(trailing!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.textHint)),
          ],
        ],
      ),
    );
  }
}
