import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';
import '../models/book.dart';
import '../screens/book_detail_screen.dart';
import '../utils/app_colors.dart';

class BookCard extends StatelessWidget {
  final Book book;
  const BookCard({super.key, required this.book});

  static const _titleStyle = TextStyle(fontSize: 15, fontWeight: FontWeight.bold, height: 1.2);

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    String sellerName = book.location.replaceAll('賣家：', '');
    if (sellerName == '地點未提供') sellerName = '管理員';

    return GestureDetector(
      onTap: () => Navigator.push(context, CupertinoPageRoute(builder: (_) => BookDetailScreen(book: book))),
      child: Container(
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: c.shadow.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Hero(
            tag: 'book_image_${book.bookId}',
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(book.imageUrl, height: 140, width: double.infinity, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(height: 140, color: c.inputFill, child: Icon(Icons.image_not_supported, color: c.iconInactive))),
            ),
          ),
          Expanded(child: LayoutBuilder(builder: (context, constraints) {
            final titleMaxWidth = constraints.maxWidth - 48.0;
            final painter = TextPainter(
              text: TextSpan(text: book.title, style: _titleStyle.copyWith(color: c.textPrimary)),
              maxLines: 1, textDirection: TextDirection.ltr,
            )..layout(maxWidth: titleMaxWidth.clamp(0.0, double.infinity));
            final overflows = painter.didExceedMaxLines;

            return Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    Expanded(child: overflows
                        ? SizedBox(height: 20, child: Marquee(text: book.title, style: _titleStyle.copyWith(color: c.textPrimary),
                        blankSpace: 40.0, velocity: 50.0, pauseAfterRound: const Duration(seconds: 2),
                        startAfter: const Duration(seconds: 1), fadingEdgeStartFraction: 0.0, fadingEdgeEndFraction: 0.15,
                        accelerationDuration: Duration.zero, decelerationDuration: Duration.zero))
                        : Text(book.title, style: _titleStyle.copyWith(color: c.textPrimary), maxLines: 1)),
                    Padding(padding: const EdgeInsets.only(left: 4.0), child: Icon(Icons.favorite_border, size: 20, color: c.iconInactive)),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    _buildTag(book.categoryName, c.categoryChip, AppColors.primary),
                    const SizedBox(width: 6),
                    _buildTag(book.conditionText, book.conditionColor.withOpacity(0.12), book.conditionColor),
                  ]),
                  const SizedBox(height: 8),
                  Text('\$${book.price.toInt()}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.primary)),
                ]),
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  const CircleAvatar(radius: 9, backgroundImage: NetworkImage('https://images.unsplash.com/photo-1599566150163-29194dcaad36?q=80&w=200&auto=format&fit=crop')),
                  const SizedBox(width: 6),
                  Expanded(child: Text(sellerName, locale: const Locale('en', 'US'), style: TextStyle(fontSize: 12, color: c.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),
              ]),
            );
          })),
        ]),
      ),
    );
  }

  Widget _buildTag(String text, Color bgColor, Color textColor) {
    return Container(
      height: 22, padding: const EdgeInsets.symmetric(horizontal: 8), alignment: Alignment.center,
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(16)),
      child: Text(text, style: TextStyle(color: textColor, fontSize: 10, fontWeight: FontWeight.w600, height: 1.0)),
    );
  }
}