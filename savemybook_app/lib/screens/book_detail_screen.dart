import 'package:flutter/material.dart';
import '../models/book.dart';
import 'search_screen.dart';

class BookDetailScreen extends StatefulWidget {
  final Book book;

  const BookDetailScreen({super.key, required this.book});

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  final PageController _pageController = PageController();
  int _currentImageIndex = 0;
  late List<String> _images;

  @override
  void initState() {
    super.initState();
    _images = [widget.book.imageUrl, widget.book.imageUrl, widget.book.imageUrl];
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F7),
      body: Column(
        children: [
          _buildCustomAppBar(),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildImageCarousel(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTitleRow(),
                        const SizedBox(height: 10),
                        _buildPriceAndConditionRow(),
                        const SizedBox(height: 18),
                        _buildInfoRow(Icons.business_outlined, '出版社：', widget.book.publisher),
                        const SizedBox(height: 12),
                        _buildInfoRow(Icons.edit_outlined, '作者：', widget.book.author),
                        const SizedBox(height: 12),
                        _buildInfoRow(Icons.qr_code, 'ISBN：', widget.book.isbn),
                        const SizedBox(height: 12),
                        _buildDescriptionRow(),
                        const SizedBox(height: 12),
                        _buildInfoRow(Icons.calendar_today_outlined, '上架日期：', widget.book.createdAt),
                        const SizedBox(height: 28),
                        _buildSellerInfo(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomActions(),
    );
  }

  Widget _buildCustomAppBar() {
    return Container(
      decoration: const BoxDecoration(color: Color(0xFF627D8D)),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 8.0, bottom: 12.0),
          child: Row(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.pop(context),
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 22),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) => const SearchScreen(initialKeyword: ''),
                        transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
                      ),
                    );
                  },
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        Expanded(child: Text('搜尋書名、作者、出版社...', style: TextStyle(color: Colors.grey.shade400, fontSize: 14))),
                        const SizedBox(width: 8),
                        const Icon(Icons.search, color: Colors.grey, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.shopping_cart_outlined, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageCarousel() {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        SizedBox(
          height: 360,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _images.length,
            onPageChanged: (index) {
              setState(() => _currentImageIndex = index);
            },
            itemBuilder: (context, index) {
              final imageWidget = Image.network(_images[index], fit: BoxFit.cover, width: double.infinity);
              if (index == 0) {
                return Hero(tag: 'book_image_${widget.book.bookId}', child: imageWidget);
              }
              return imageWidget;
            },
          ),
        ),
        Positioned(
          left: 10, top: 170,
          child: GestureDetector(
            onTap: () {
              if (_currentImageIndex > 0) _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
            },
            child: const Icon(Icons.arrow_back_ios, color: Color(0xFF627D8D), size: 28),
          ),
        ),
        Positioned(
          right: 10, top: 170,
          child: GestureDetector(
            onTap: () {
              if (_currentImageIndex < _images.length - 1) _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
            },
            child: const Icon(Icons.arrow_forward_ios, color: Color(0xFF627D8D), size: 28),
          ),
        ),
        Positioned(
          bottom: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_images.length, (index) {
              bool isActive = _currentImageIndex == index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.symmetric(horizontal: 4.0),
                width: isActive ? 16.0 : 6.0,
                height: 6.0,
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: isActive ? Colors.white : Colors.white.withOpacity(0.5)
                ),
              );
            }),
          ),
        ),
        Positioned(
          top: 16,
          right: 16,
          child: PopupMenuButton<String>(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.more_vert, color: Colors.white, size: 24),
            ),
            onSelected: (value) {
              if (value == 'share') {
              } else if (value == 'report') {
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.ios_share, size: 20),
                    SizedBox(width: 8),
                    Text('分享'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 20, color: Colors.red),
                    SizedBox(width: 8),
                    Text('檢舉'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTitleRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            widget.book.title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF151E27), height: 1.25),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 4.0),
          child: Icon(Icons.favorite_border, size: 26, color: Colors.grey),
        )
      ],
    );
  }

  Widget _buildPriceAndConditionRow() {
    Color badgeColor = widget.book.conditionColor;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('\$${widget.book.price.toInt()}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF627D8D))),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: Colors.transparent, border: Border.all(color: badgeColor), borderRadius: BorderRadius.circular(12)),
          child: Text(widget.book.conditionText, style: TextStyle(color: badgeColor, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF555555)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 15)),
        ),
      ],
    );
  }

  Widget _buildDescriptionRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.notes, size: 20, color: const Color(0xFF555555)),
        const SizedBox(width: 8),
        const Text('簡介：', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, height: 1.3)),
        Expanded(
          child: Text(widget.book.description, style: const TextStyle(fontSize: 15, height: 1.3)),
        ),
      ],
    );
  }

  Widget _buildSellerInfo() {
    String sellerName = widget.book.location.replaceAll('賣家：', '');
    if (sellerName == '地點未提供') sellerName = '管理員';

    return Row(
      children: [
        const CircleAvatar(
          radius: 18,
          backgroundImage: NetworkImage('https://images.unsplash.com/photo-1599566150163-29194dcaad36?q=80&w=200&auto=format&fit=crop'),
        ),
        const SizedBox(width: 12),
        Text(sellerName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: EdgeInsets.only(left: 20, right: 20, top: 12, bottom: MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(color: const Color(0xFFF3F5F7), border: Border(top: BorderSide(color: Colors.grey.shade300, width: 1))),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.chat_bubble_outline, size: 18, color: Color(0xFF627D8D)),
              label: const Text('與賣家聊聊', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF627D8D))),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                side: const BorderSide(color: Color(0xFF627D8D)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
                shadowColor: Colors.transparent,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.shopping_cart_outlined, size: 18),
              label: const Text('加入購物車', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF627D8D),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}