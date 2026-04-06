import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';
import '../models/book.dart';
import '../screens/book_detail_screen.dart';

class BookCard extends StatelessWidget {
  final Book book;
  final void Function(String keyword)? onSearchFromDetail;

  const BookCard({super.key, required this.book, this.onSearchFromDetail});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 350),
            pageBuilder: (context, animation, secondaryAnimation) => BookDetailScreen(book: book),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              final curvedAnimation = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
              return FadeTransition(
                opacity: curvedAnimation,
                child: SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0.0, 0.05), end: Offset.zero).animate(curvedAnimation),
                  child: child,
                ),
              );
            },
          ),
        );
        if (result is String && result.isNotEmpty) {
          onSearchFromDetail?.call(result);
        }
      },
      child: SizedBox(
        height: 340,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Hero(
                tag: 'book_image_${book.bookId}',
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: Image.network(
                    book.imageUrl,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 140,
                      color: Colors.grey[300],
                      child: const Icon(Icons.image_not_supported, color: Colors.grey),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 20,
                              child: Marquee(
                                text: book.title,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                                scrollAxis: Axis.horizontal,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                blankSpace: 40.0,
                                velocity: 40.0,
                                pauseAfterRound: const Duration(seconds: 2),
                                startAfter: const Duration(seconds: 1),
                                fadingEdgeStartFraction: 0.1,
                                fadingEdgeEndFraction: 0.1,
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(left: 4.0),
                            child: Icon(Icons.bookmark_border, size: 18),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _buildTag(book.categoryName, const Color(0xFF8699A6)),
                          const SizedBox(width: 6),
                          _buildTag(book.conditionText, const Color(0xFF83A982)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        book.description,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black87,
                          height: 1.3,
                          leadingDistribution: TextLeadingDistribution.even,
                        ),
                        strutStyle: const StrutStyle(
                          fontSize: 12,
                          height: 1.3,
                          leading: 0,
                          forceStrutHeight: true,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2.0),
                            child: Icon(Icons.location_on_outlined, size: 13, color: Colors.black54),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              book.location,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black54,
                                height: 1.3,
                                leadingDistribution: TextLeadingDistribution.even,
                              ),
                              strutStyle: const StrutStyle(
                                fontSize: 11,
                                height: 1.3,
                                leading: 0,
                                forceStrutHeight: true,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '\$${book.price.toInt()}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6A828E),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              '查看詳情',
                              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500),
      ),
    );
  }
}