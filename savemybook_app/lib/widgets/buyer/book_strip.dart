import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../models/book.dart';
import '../../screens/book_detail_screen.dart';
import '../../utils/app_colors.dart';
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
  });

  static const double _tileWidth = 128;
  static const double _imageHeight = 150;
  static const double _height = 236;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
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
