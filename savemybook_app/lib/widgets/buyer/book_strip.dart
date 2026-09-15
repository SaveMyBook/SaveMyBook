import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../models/book.dart';
import '../../features/books/book_detail_screen.dart';
import '../../utils/app_colors.dart';
import '../../utils/motion.dart';
import '../animations.dart';
import '../state_views.dart';

class BookStrip extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Book> books;
  final String heroPrefix;
  final bool loading;
  final String? actionLabel;
  final VoidCallback? onAction;
  final ValueChanged<Book>? onLongPress;

  const BookStrip({
    super.key,
    required this.title,
    required this.icon,
    required this.books,
    required this.heroPrefix,
    this.loading = false,
    this.actionLabel,
    this.onAction,
    this.onLongPress,
    this.showHeader = true,
  });

  final bool showHeader;

  static const double _tileWidth = 120;
  static const double _imageHeight = 140;
  static const double _height = 226;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showHeader) Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 8, 10),
          child: Row(
            children: [
              Icon(icon, size: 18, color: c.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary),
                ),
              ),
              if (actionLabel != null)
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    foregroundColor: c.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 120),
                        child: Text(
                          actionLabel!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, size: 18),
                    ],
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: _height,
          child: loading && books.isEmpty
              ? Shimmer(
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                    itemCount: 4,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (_, _) => const SizedBox(
                      width: _tileWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox(height: _imageHeight, radius: 16),
                          SizedBox(height: 8),
                          SkeletonBox(height: 12),
                          SizedBox(height: 8),
                          SkeletonBox(width: 50, height: 14),
                        ],
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                  itemCount: books.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, i) => FadeSlideIn(
                    index: i,
                    offsetY: 10,
                    child: _tile(context, c, books[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _tile(BuildContext context, AppColors c, Book book) {
    final heroTag = '${heroPrefix}_${book.bookId}';
    final unavailable = book.status != 'on_sale';

    return PressableScale(
      scale: 0.95,
      onTap: () => Navigator.push(
        context,
        CupertinoPageRoute(builder: (_) => BookDetailScreen(book: book, heroTag: heroTag)),
      ),
      onLongPress: onLongPress == null ? null : () => onLongPress!(book),
      child: Container(
        width: _tileWidth,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: c.shadow.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Hero(
                  tag: heroTag,
                  child: AppNetworkImage(
                    url: book.hasImage ? book.imageUrl : null,
                    width: _tileWidth,
                    height: _imageHeight,
                    fallbackIconSize: 30,
                  ),
                ),
                if (unavailable)
                  Positioned(
                    left: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        book.statusText,
                        style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, height: 1.3, fontWeight: FontWeight.w600, color: c.textPrimary),
                    ),
                    const Spacer(),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '\$${book.price.toInt()}',
                        maxLines: 1,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c.accent),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class DiscoveryTab {
  final String id;
  final String title;
  final IconData icon;
  final List<Book> books;
  final String? actionLabel;
  final VoidCallback? onAction;

  const DiscoveryTab({
    required this.id,
    required this.title,
    required this.icon,
    required this.books,
    this.actionLabel,
    this.onAction,
  });
}

class DiscoveryPanel extends StatefulWidget {
  final List<DiscoveryTab> tabs;

  const DiscoveryPanel({super.key, required this.tabs});

  @override
  State<DiscoveryPanel> createState() => _DiscoveryPanelState();
}

class _DiscoveryPanelState extends State<DiscoveryPanel> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final tabs = widget.tabs;
    if (tabs.isEmpty) return const SizedBox(width: double.infinity);
    final current = tabs.firstWhere((t) => t.id == _selected, orElse: () => tabs.first);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 8, 12),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final tab in tabs) ...[
                        _tabButton(c, tab, tab.id == current.id),
                        if (tab != tabs.last) const SizedBox(width: 6),
                      ],
                    ],
                  ),
                ),
              ),
              if (current.actionLabel != null)
                TextButton(
                  onPressed: current.onAction,
                  style: TextButton.styleFrom(
                    foregroundColor: c.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 110),
                        child: Text(
                          current.actionLabel!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, size: 18),
                    ],
                  ),
                ),
            ],
          ),
        ),
        AnimatedSwitcher(
          duration: Motion.base,
          switchInCurve: Motion.enterCurve,
          switchOutCurve: Motion.exitCurve,
          child: BookStrip(
            key: ValueKey(current.id),
            title: current.title,
            icon: current.icon,
            books: current.books,
            heroPrefix: current.id,
            showHeader: false,
          ),
        ),
      ],
    );
  }

  Widget _tabButton(AppColors c, DiscoveryTab tab, bool active) {
    return PressableScale(
      scale: 0.95,
      onTap: active ? null : () => setState(() => _selected = tab.id),
      child: AnimatedContainer(
        duration: Motion.base,
        curve: Motion.standard,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? c.accent.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(tab.icon, size: 16, color: active ? c.accent : c.textSecondary),
            const SizedBox(width: 6),
            Text(
              tab.title,
              maxLines: 1,
              style: TextStyle(
                fontSize: 15,
                fontWeight: active ? FontWeight.bold : FontWeight.w500,
                color: active ? c.textPrimary : c.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
