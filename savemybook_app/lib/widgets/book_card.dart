import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';
import 'app_tiles.dart';
import 'favorite_button.dart';
import 'state_views.dart';
import '../models/book.dart';
import '../screens/book_detail_screen.dart';
import '../utils/app_colors.dart';
import '../screens/seller_screen.dart';
import '../i18n/strings.dart';

class BookCard extends StatelessWidget {
  final Book book;
  final bool isListMode;
  final String? heroTag;

  const BookCard({super.key, required this.book, this.isListMode = false, this.heroTag});

  String get _heroTag => heroTag ?? 'book_image_${book.bookId}';

  static const _titleStyle = TextStyle(fontSize: 15, fontWeight: FontWeight.bold, height: 1.2);

  static const double gridHeight = 296;

  @override
  Widget build(BuildContext context) {
    return isListMode ? _buildListCard(context) : _buildGridCard(context);
  }

  Widget _buildGridCard(BuildContext context) {
    final c = AppColors.of(context);
    final sellerName = _sellerName();

    return GestureDetector(
      onTap: () => _navigateToDetail(context),
      child: Container(
        decoration: _cardDecoration(c),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(children: [
            Hero(
              tag: _heroTag,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: AppNetworkImage(
                  url: book.hasImage ? book.imageUrl : null,
                  height: 140,
                  width: double.infinity,
                  fallbackIconSize: 32,
                ),
              ),
            ),
            _statusOverlay(),
          ]),
          Expanded(child: LayoutBuilder(builder: (context, constraints) {
            final titleMaxWidth = constraints.maxWidth - 48.0;
            final painter = TextPainter(
              text: TextSpan(text: book.title, style: _titleStyle.copyWith(color: c.textPrimary)),
              maxLines: 1, textDirection: TextDirection.ltr,
            )..layout(maxWidth: titleMaxWidth.clamp(0.0, double.infinity));
            final overflows = painter.didExceedMaxLines;
            painter.dispose();

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
                    FavoriteButton(bookId: book.bookId, size: 20),
                  ]),
                  const SizedBox(height: 6),
                  _buildTags(c),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text('\$${book.price.toInt()}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.primary)),
                  ),
                ]),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _openSeller(context),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    _sellerAvatar(c, 9),
                    const SizedBox(width: 6),
                    Expanded(child: Text(sellerName, locale: const Locale('en', 'US'), style: TextStyle(fontSize: 12, color: c.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ]),
                ),
              ]),
            );
          })),
        ]),
      ),
    );
  }

  Widget _buildListCard(BuildContext context) {
    final c = AppColors.of(context);
    final sellerName = _sellerName();

    return GestureDetector(
      onTap: () => _navigateToDetail(context),
      child: Container(
        height: 140,
        decoration: _cardDecoration(c),
        child: Row(children: [
          Stack(children: [
            Hero(
              tag: _heroTag,
              child: ClipRRect(
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                child: AppNetworkImage(
                  url: book.hasImage ? book.imageUrl : null,
                  width: 110,
                  height: 140,
                  fallbackIconSize: 32,
                ),
              ),
            ),
            _statusOverlay(),
          ]),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    Expanded(child: Text(book.title, style: _titleStyle.copyWith(color: c.textPrimary), maxLines: 2, overflow: TextOverflow.ellipsis)),
                    FavoriteButton(bookId: book.bookId, size: 20),
                  ]),
                  const SizedBox(height: 8),
                  _buildTags(c),
                ]),

                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text('\$${book.price.toInt()}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.primary)),
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _openSeller(context),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      _sellerAvatar(c, 9),
                      const SizedBox(width: 5),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 80),
                        child: Text(sellerName, style: TextStyle(fontSize: 12, color: c.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ]),
                  ),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _sellerAvatar(AppColors c, double radius) {
    return UserAvatar(imageUrl: book.sellerAvatarUrl, radius: radius);
  }

  String _sellerName() {
    if (book.sellerName.isNotEmpty) return book.sellerName;
    final name = book.location.replaceAll(S.seller2, '');
    return name == S.locationNotProvided ? S.roleAdmin : name;
  }

  void _navigateToDetail(BuildContext context) {
    Navigator.push(context, CupertinoPageRoute(builder: (_) => BookDetailScreen(book: book, heroTag: _heroTag)));
  }

  Widget _statusOverlay() {
    if (book.status == 'on_sale') return const SizedBox.shrink();
    return Positioned(
      left: 8,
      top: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          book.statusText,
          maxLines: 1,
          style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration(AppColors c) {
    return BoxDecoration(
      color: c.card,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: c.shadow.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
    );
  }

  Widget _buildTags(AppColors c) {
    final conditionColor = c.conditionColor(book.conditionLevel);
    return Row(children: [
      Flexible(child: _buildTag(book.categoryName, c.categoryChip, c.accent)),
      const SizedBox(width: 6),
      Flexible(child: _buildTag(book.conditionText, conditionColor.withValues(alpha: 0.12), conditionColor)),
    ]);
  }

  Widget _buildTag(String text, Color bgColor, Color textColor) {
    return Container(
      height: 22, padding: const EdgeInsets.symmetric(horizontal: 8), alignment: Alignment.center,
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(16)),
      child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: textColor, fontSize: 10, fontWeight: FontWeight.w600, height: 1.0)),
    );
  }
  void _openSeller(BuildContext context) {
    if (book.sellerId == 0) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SellerScreen(
          sellerId: book.sellerId,
          sellerName: _sellerName(),
          sellerAvatarUrl: book.sellerAvatarUrl,
        ),
      ),
    );
  }

}