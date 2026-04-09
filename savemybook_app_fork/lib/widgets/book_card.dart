import 'package:flutter/material.dart';
import '../models/book.dart';
import '../screens/book_detail_screen.dart';

class BookCard extends StatefulWidget {
  final Book book;
  final void Function(String keyword)? onSearchFromDetail;

  const BookCard({super.key, required this.book, this.onSearchFromDetail});

  @override
  State<BookCard> createState() => _BookCardState();
}

class _BookCardState extends State<BookCard> {
  final PageController _pageController = PageController();
  int _currentImageIndex = 0;
  late List<String> _images;

  @override
  void initState() {
    super.initState();
    // 模擬多張圖片，實際開發時應從 widget.book 獲取圖片列表
    _images = [widget.book.imageUrl, widget.book.imageUrl, widget.book.imageUrl];
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 350),
            pageBuilder: (context, animation, secondaryAnimation) => BookDetailScreen(book: widget.book),
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
          widget.onSearchFromDetail?.call(result);
        }
      },
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
            Stack(
              alignment: Alignment.bottomCenter,
              children: [
                SizedBox(
                  height: 140,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _images.length,
                      onPageChanged: (index) {
                        setState(() => _currentImageIndex = index);
                      },
                      itemBuilder: (context, index) {
                        final imageWidget = Image.network(
                          _images[index],
                          height: 140,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: 140,
                            color: Colors.grey[300],
                            child: const Icon(Icons.image_not_supported, color: Colors.grey),
                          ),
                        );
                        // 只有第一張圖使用 Hero 以確保轉場正確
                        if (index == 0) {
                          return Hero(tag: 'book_image_${widget.book.bookId}', child: imageWidget);
                        }
                        return imageWidget;
                      },
                    ),
                  ),
                ),
                // 圖片指示器 (小點點)
                if (_images.length > 1)
                  Positioned(
                    bottom: 8,
                    child: Row(
                      children: List.generate(_images.length, (index) {
                        bool isActive = _currentImageIndex == index;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          width: isActive ? 12 : 5,
                          height: 5,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5),
                            color: isActive ? Colors.white : Colors.white.withOpacity(0.5),
                          ),
                        );
                      }),
                    ),
                  ),
              ],
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
                          child: Text(
                            widget.book.title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(left: 4.0),
                          child: Icon(Icons.favorite_border, size: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildTag(widget.book.categoryName, const Color(0xFF607D8B).withOpacity(0.1), const Color(0xFF607D8B)),
                        const SizedBox(width: 6),
                        _buildConditionTag(widget.book),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '\$${widget.book.price.toInt()}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF607D8B),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 20,
                            height: 20,
                            color: const Color(0xFF607D8B).withOpacity(0.1),
                            child: const Icon(Icons.person, size: 14, color: Color(0xFF607D8B)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            widget.book.location.replaceFirst('賣家：', ''),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black54,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
    );
  }

  Widget _buildTag(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
      child: Text(
        text,
        style: TextStyle(color: textColor, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildConditionTag(Book book) {
    Color borderColor = const Color(0xFF607D8B);

    if (book.conditionLevel == 'poor' || book.conditionLevel == 'fair') {
      borderColor = Colors.orange.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Text(
        book.conditionText,
        style: TextStyle(color: borderColor, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
