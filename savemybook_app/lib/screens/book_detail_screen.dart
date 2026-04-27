import 'package:flutter/material.dart';
import '../models/book.dart';
import '../utils/app_colors.dart';
import 'home_screen.dart';
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
    _images = widget.book.imageUrls.isNotEmpty ? widget.book.imageUrls : [widget.book.imageUrl];
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(children: [
        _buildCustomAppBar(c),
        Expanded(
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _buildImageCarousel(c),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _buildTitleRow(c),
                  const SizedBox(height: 10),
                  _buildPriceAndConditionRow(),
                  const SizedBox(height: 18),
                  _buildInfoRow(Icons.business_outlined, '出版社：', widget.book.publisher, c),
                  const SizedBox(height: 12),
                  _buildInfoRow(Icons.edit_outlined, '作者：', widget.book.author, c),
                  const SizedBox(height: 12),
                  _buildInfoRow(Icons.qr_code, 'ISBN：', widget.book.isbn, c),
                  const SizedBox(height: 12),
                  _buildDescriptionRow(c),
                  const SizedBox(height: 12),
                  _buildInfoRow(Icons.calendar_today_outlined, '上架日期：', widget.book.createdAt, c),
                  const SizedBox(height: 28),
                  _buildSellerInfo(c),
                ]),
              ),
            ]),
          ),
        ),
      ]),
      bottomNavigationBar: _buildBottomActions(c),
    );
  }

  Widget _buildCustomAppBar(AppColors c) {
    return Container(
      decoration: BoxDecoration(color: c.headerBg),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 8.0, bottom: 12.0),
          child: Row(children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque, onTap: () => Navigator.pop(context),
              child: const Padding(padding: EdgeInsets.all(4.0), child: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 22)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () async {
                  final keyword = await Navigator.push<String>(context, PageRouteBuilder(
                    pageBuilder: (_, __, ___) => const SearchScreen(initialKeyword: ''),
                    transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
                  ));
                  if (keyword != null && keyword.isNotEmpty && context.mounted) {
                    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => HomeScreen(initialKeyword: keyword)), (_) => false);
                  }
                },
                child: Container(
                  height: 40, padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    Expanded(child: Text('搜尋書名、作者、出版社...', style: TextStyle(color: c.textHint, fontSize: 14))),
                    const SizedBox(width: 8),
                    Icon(Icons.search, color: c.iconInactive, size: 20),
                  ]),
                ),
              ),
            ),
            const SizedBox(width: 16),
            const Icon(Icons.shopping_cart_outlined, color: Colors.white),
          ]),
        ),
      ),
    );
  }

  Widget _buildImageCarousel(AppColors c) {
    return Stack(alignment: Alignment.bottomCenter, children: [
      SizedBox(
        height: 360,
        child: PageView.builder(
          controller: _pageController, itemCount: _images.length,
          onPageChanged: (i) => setState(() => _currentImageIndex = i),
          itemBuilder: (context, index) {
            final imageWidget = Image.network(_images[index], fit: BoxFit.cover, width: double.infinity);
            final heroWidget = index == 0 ? Hero(tag: 'book_image_${widget.book.bookId}', child: imageWidget) : imageWidget;

            return GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => Scaffold(
                    backgroundColor: Colors.black,
                    appBar: AppBar(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      iconTheme: const IconThemeData(color: Colors.white),
                    ),
                    extendBodyBehindAppBar: true,
                    body: Center(
                      child: InteractiveViewer(
                        panEnabled: true,
                        minScale: 0.5,
                        maxScale: 4.0,
                        child: Image.network(_images[index]),
                      ),
                    ),
                  ),
                ));
              },
              child: heroWidget,
            );
          },
        ),
      ),
      Positioned(left: 10, top: 170, child: GestureDetector(
        onTap: () { if (_currentImageIndex > 0) _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut); },
        child: const Icon(Icons.arrow_back_ios, color: AppColors.primary, size: 28),
      )),
      Positioned(right: 10, top: 170, child: GestureDetector(
        onTap: () { if (_currentImageIndex < _images.length - 1) _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut); },
        child: const Icon(Icons.arrow_forward_ios, color: AppColors.primary, size: 28),
      )),
      Positioned(bottom: 16, child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_images.length, (index) {
          bool isActive = _currentImageIndex == index;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 4.0), width: isActive ? 16.0 : 6.0, height: 6.0,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), color: isActive ? Colors.white : Colors.white.withOpacity(0.5)),
          );
        }),
      )),
      Positioned(top: 16, right: 16, child: PopupMenuButton<String>(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), shape: BoxShape.circle),
          child: const Icon(Icons.more_vert, color: Colors.white, size: 24),
        ),
        onSelected: (value) {},
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'share', child: Row(children: [Icon(Icons.ios_share, size: 20), SizedBox(width: 8), Text('分享')])),
          const PopupMenuItem(value: 'report', child: Row(children: [Icon(Icons.warning_amber_rounded, size: 20, color: Colors.red), SizedBox(width: 8), Text('檢舉')])),
        ],
      )),
    ]);
  }

  Widget _buildTitleRow(AppColors c) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: Text(widget.book.title, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: c.textPrimary, height: 1.25))),
      Padding(padding: const EdgeInsets.only(top: 4.0), child: Icon(Icons.favorite_border, size: 26, color: c.iconInactive)),
    ]);
  }

  Widget _buildPriceAndConditionRow() {
    Color badgeColor = widget.book.conditionColor;
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Text('\$${widget.book.price.toInt()}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.primary)),
      const SizedBox(width: 12),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: Colors.transparent, border: Border.all(color: badgeColor), borderRadius: BorderRadius.circular(12)),
        child: Text(widget.book.conditionText, style: TextStyle(color: badgeColor, fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    ]);
  }

  Widget _buildInfoRow(IconData icon, String label, String value, AppColors c) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 20, color: c.textSecondary),
      const SizedBox(width: 8),
      Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: c.textPrimary)),
      Expanded(child: Text(value, style: TextStyle(fontSize: 15, color: c.textPrimary))),
    ]);
  }

  Widget _buildDescriptionRow(AppColors c) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(Icons.notes, size: 20, color: c.textSecondary),
      const SizedBox(width: 8),
      Text('簡介：', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, height: 1.3, color: c.textPrimary)),
      Expanded(child: Text(widget.book.description, style: TextStyle(fontSize: 15, height: 1.3, color: c.textPrimary))),
    ]);
  }

  Widget _buildSellerInfo(AppColors c) {
    String sellerName = widget.book.location.replaceAll('賣家：', '');
    if (sellerName == '地點未提供') sellerName = '管理員';
    return Row(children: [
      const CircleAvatar(radius: 18, backgroundImage: NetworkImage('https://images.unsplash.com/photo-1599566150163-29194dcaad36?q=80&w=200&auto=format&fit=crop')),
      const SizedBox(width: 12),
      Text(sellerName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: c.textPrimary)),
    ]);
  }

  Widget _buildBottomActions(AppColors c) {
    return Container(
      padding: EdgeInsets.only(left: 20, right: 20, top: 12, bottom: MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(color: c.card, border: Border(top: BorderSide(color: c.divider, width: 1))),
      child: Row(children: [
        Expanded(child: ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.chat_bubble_outline, size: 18, color: AppColors.primary),
          label: const Text('與賣家聊聊', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.primary)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent, side: const BorderSide(color: AppColors.primary),
            padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0, shadowColor: Colors.transparent,
          ),
        )),
        const SizedBox(width: 16),
        Expanded(child: ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.shopping_cart_outlined, size: 18),
          label: const Text('加入購物車', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0,
          ),
        )),
      ]),
    );
  }
}