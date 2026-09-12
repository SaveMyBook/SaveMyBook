import 'package:flutter/material.dart';
import '../models/book.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/share_service.dart';
import '../utils/app_colors.dart';
import '../utils/app_labels.dart';
import '../widgets/app_tiles.dart';
import '../widgets/favorite_button.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/app_header.dart';
import '../widgets/state_views.dart';
import 'cart_screen.dart';
import 'chat_room_screen.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'seller_screen.dart';
import '../widgets/animations.dart';
import '../i18n/strings.dart';

class BookDetailScreen extends StatefulWidget {
  final Book book;
  const BookDetailScreen({super.key, required this.book});

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  final PageController _pageController = PageController();
  final ApiService _api = ApiService();
  int _currentImageIndex = 0;
  late List<String> _images;

  bool _isAddingToCart = false;

  bool get _isOwnBook =>
      widget.book.sellerId != 0 && widget.book.sellerId == ApiService.currentUser?.userId;

  @override
  void initState() {
    super.initState();
    _images = widget.book.imageUrls;
    if (ApiService.authToken != null) _api.fetchFavoriteIds();
  }

  Future<void> _addToCart() async {
    if (_isAddingToCart) return;
    if (ApiService.authToken == null) {
      showAppSnackBar(context, S.signAddItemsCart, isError: true);
      return;
    }
    if (widget.book.status != 'on_sale') {
      showAppSnackBar(context, S.bookCannotPurchased(widget.book.statusText), isError: true);
      return;
    }
    setState(() => _isAddingToCart = true);
    final error = await _api.addToCart(widget.book.bookId);
    if (!mounted) return;
    setState(() => _isAddingToCart = false);

    if (error != null) {
      showAppSnackBar(context, error, isError: true);
    } else {
      showAppSnackBar(context, S.addedCart);
    }
  }

  Future<void> _chatWithSeller() async {
    if (widget.book.sellerId == 0) {
      showAppSnackBar(context, S.sellerInformationNotFound, isError: true);
      return;
    }
    if (ApiService.authToken == null) {
      showAppSnackBar(context, S.signContactSeller, isError: true);
      return;
    }

    final roomId = await runBusy(
      context,
      () => _api.openChatRoom(userId: widget.book.sellerId, bookId: widget.book.bookId),
    );
    if (!mounted) return;
    if (roomId == null) {
      showAppSnackBar(context, S.signStartChat, isError: true);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatRoomScreen(roomId: roomId, partnerName: widget.book.sellerName),
      ),
    );
  }

  /// 分享連結由伺服器發，帶的是亂數權杖而不是書籍流水號——用流水號的話
  /// 任何人都能從 1 開始把全站書籍掃出來。連結是一般網址，沒裝 App 也打得開。
  Future<void> _shareBook() async {
    final (url, error) = await runBusy(
          context,
          () => _api.fetchBookShareLink(widget.book.bookId),
        ) ??
        (null, null);
    if (!mounted) return;

    if (url == null) {
      showAppSnackBar(context, error ?? AppLabels.loadFailed, isError: true);
      return;
    }

    final action = await showOptionSheet<String>(
      context,
      title: S.shareBook,
      subtitle: widget.book.title,
      options: [
        SheetOption(value: 'share', label: S.shareAnotherApp, icon: Icons.ios_share_rounded),
        SheetOption(value: 'copy', label: S.copyLink, icon: Icons.link_rounded),
      ],
    );
    if (action == null || !mounted) return;

    if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: url));
      if (mounted) showAppSnackBar(context, S.linkCopied);
      return;
    }

    final ok = await ShareService.shareText('${widget.book.title}\n$url');
    if (!mounted) return;
    // 系統分享頁叫不出來時不要讓使用者空手而回，直接退回複製。
    if (!ok) {
      await Clipboard.setData(ClipboardData(text: url));
      if (mounted) showAppSnackBar(context, S.sharingCouldNotOpenSoLink, isError: true);
    }
  }

  Future<void> _reportBook() async {
    if (ApiService.authToken == null) {
      showAppSnackBar(context, S.signReport, isError: true);
      return;
    }
    if (_isOwnBook) {
      showAppSnackBar(context, S.cannotReportOwnListing, isError: true);
      return;
    }

    final reason = await showTextInputDialog(
      context,
      title: S.reportListing,
      hint: S.describeProblemLeast5Characters,
      maxLines: 3,
      confirmLabel: S.actionSubmit,
    );

    if (reason == null || !mounted) return;

    if (reason.length < 5) {
      showAppSnackBar(context, S.reasonNeedsLeast5Characters, isError: true);
      return;
    }

    final error = await runBusy(
      context,
      () => _api.submitReport(
        targetType: 'book',
        targetId: widget.book.bookId,
        reason: reason,
      ),
    );
    if (!mounted) return;
    showAppSnackBar(context, error ?? S.reportSubmittedWeLookInto, isError: error != null);
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
                  _buildPriceAndConditionRow(c),
                  const SizedBox(height: 18),
                  _buildInfoRow(Icons.business_outlined, S.publisher, widget.book.publisher, c),
                  const SizedBox(height: 12),
                  _buildInfoRow(Icons.edit_outlined, S.author, widget.book.author, c),
                  const SizedBox(height: 12),
                  _buildInfoRow(Icons.qr_code, 'ISBN：', widget.book.isbn, c),
                  const SizedBox(height: 12),
                  _buildDescriptionRow(c),
                  const SizedBox(height: 12),
                  _buildInfoRow(Icons.calendar_today_outlined, S.listed, widget.book.createdAt, c),
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
                  final navigator = Navigator.of(context);
                  final keyword = await navigator.push<String>(PageRouteBuilder(
                    pageBuilder: (_, _, _) => const SearchScreen(initialKeyword: ''),
                    transitionsBuilder: (_, animation, _, child) =>
                        FadeTransition(opacity: animation, child: child),
                  ));
                  if (keyword == null || keyword.isEmpty || !mounted) return;
                  navigator.pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => HomeScreen(initialKeyword: keyword)),
                    (_) => false,
                  );
                },
                child: Container(
                  height: 40, padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    Expanded(child: Text(S.searchTitleAuthorPublisher, style: TextStyle(color: c.textHint, fontSize: 14))),
                    const SizedBox(width: 8),
                    Icon(Icons.search, color: c.iconInactive, size: 20),
                  ]),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CartIconButton(
              size: 24,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CartScreen()),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildImageCarousel(AppColors c) {
    if (_images.isEmpty) {
      return Container(
        height: 360,
        width: double.infinity,
        color: c.inputFill,
        child: Icon(Icons.menu_book_rounded, size: 72, color: c.iconInactive),
      );
    }

    return Stack(alignment: Alignment.bottomCenter, children: [
      SizedBox(
        height: 360,
        child: PageView.builder(
          controller: _pageController, itemCount: _images.length,
          onPageChanged: (i) => setState(() => _currentImageIndex = i),
          itemBuilder: (context, index) {
            final imageWidget = AppNetworkImage(
              url: _images[index],
              width: double.infinity,
              fallbackIconSize: 72,
            );
            final heroWidget = index == 0 ? Hero(tag: 'book_image_${widget.book.bookId}', child: imageWidget) : imageWidget;

            return GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => FullScreenImageViewer(
                    images: _images,
                    initialIndex: index,
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
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.5)),
          );
        }),
      )),
      Positioned(top: 16, right: 16, child: PopupMenuButton<String>(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), shape: BoxShape.circle),
          child: const Icon(Icons.more_vert, color: Colors.white, size: 24),
        ),
        onSelected: (value) {
          if (value == 'report') {
            _reportBook();
          } else {
            _shareBook();
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(value: 'share', child: Row(children: [Icon(Icons.ios_share, size: 20), SizedBox(width: 8), Text(S.share)])),
          if (!_isOwnBook)
            PopupMenuItem(
              value: 'report',
              child: Row(children: [
                Icon(Icons.warning_amber_rounded, size: 20, color: c.danger),
                const SizedBox(width: 8),
                Text(S.report),
              ]),
            ),
        ],
      )),
    ]);
  }

  Widget _buildTitleRow(AppColors c) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: Text(widget.book.title, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: c.textPrimary, height: 1.25))),
      Padding(
        padding: const EdgeInsets.only(top: 2.0),
        child: FavoriteButton(bookId: widget.book.bookId, size: 26),
      ),
    ]);
  }

  Widget _buildPriceAndConditionRow(AppColors c) {
    Color badgeColor = c.conditionColor(widget.book.conditionLevel);
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
      Text(S.about, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, height: 1.3, color: c.textPrimary)),
      Expanded(child: Text(widget.book.description, style: TextStyle(fontSize: 15, height: 1.3, color: c.textPrimary))),
    ]);
  }

  Widget _buildSellerInfo(AppColors c) {
    final sellerName = widget.book.sellerName.isEmpty ? S.roleAdmin : widget.book.sellerName;
    final avatarUrl = widget.book.sellerAvatarUrl;

    return PressableScale(
      scale: 0.985,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SellerScreen(
            sellerId: widget.book.sellerId,
            sellerName: sellerName,
            sellerAvatarUrl: avatarUrl,
          ),
        ),
      ),
      child: Row(children: [
        UserAvatar(imageUrl: avatarUrl, radius: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(sellerName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: c.textPrimary)),
            if (widget.book.cabinetName.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(S.pickup(widget.book.cabinetName), style: TextStyle(fontSize: 12, color: c.textSecondary)),
            ],
          ]),
        ),
        Icon(Icons.chevron_right_rounded, size: 20, color: c.iconInactive),
      ]),
    );
  }

  Widget _buildBottomActions(AppColors c) {
    return Container(
      padding: EdgeInsets.only(left: 20, right: 20, top: 12, bottom: MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(color: c.card, border: Border(top: BorderSide(color: c.divider, width: 1))),
      child: Row(children: [
        Expanded(child: ElevatedButton.icon(
          onPressed: _isOwnBook ? null : _chatWithSeller,
          icon: const Icon(Icons.chat_bubble_outline, size: 18, color: AppColors.primary),
          label: Text(S.messageSeller, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.primary)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent, side: const BorderSide(color: AppColors.primary),
            padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0, shadowColor: Colors.transparent,
          ),
        )),
        const SizedBox(width: 16),
        Expanded(child: ElevatedButton.icon(
          onPressed: _isOwnBook || _isAddingToCart ? null : _addToCart,
          icon: const Icon(Icons.shopping_cart_outlined, size: 18),
          label: Text(_isOwnBook ? S.listing : S.addCart, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: c.accent, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0,
          ),
        )),
      ]),
    );
  }
}

class FullScreenImageViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const FullScreenImageViewer({
    super.key,
    required this.images,
    required this.initialIndex,
  });

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${_currentIndex + 1} / ${widget.images.length}',
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      extendBodyBehindAppBar: true,
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.images.length,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemBuilder: (context, index) {
          return InteractiveViewer(
            panEnabled: true,
            minScale: 0.5,
            maxScale: 4.0,
            child: Image.network(
              widget.images[index],
              fit: BoxFit.contain,
              loadingBuilder: (_, child, progress) => progress == null
                  ? child
                  : const Center(child: CircularProgressIndicator(color: Colors.white54)),
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 72),
            ),
          );
        },
      ),
    );
  }
}