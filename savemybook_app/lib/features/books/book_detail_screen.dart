import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../orders/direct_purchase.dart';
import '../orders/order_history_screen.dart';
import '../../models/book.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';
import '../../services/recently_viewed.dart';
import '../../services/share_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_labels.dart';
import '../../utils/motion.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_tiles.dart';
import '../../widgets/favorite_button.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_side_nav.dart';
import '../../widgets/responsive.dart';
import '../../widgets/search_bar_widget.dart';
import '../../widgets/state_views.dart';
import '../../widgets/buyer/book_strip.dart';
import '../../widgets/buyer/fly_to_cart.dart';
import '../orders/cart_screen.dart';
import '../orders/widgets/sticky_pane.dart';
import '../chat/chat_room_screen.dart';
import '../selling/book_deposit_actions.dart';
import '../cabinet/cabinet_entry.dart';
import '../cabinet/cabinet_guide_screen.dart';
import '../selling/edit_book_screen.dart';
import '../home/home_screen.dart';
import '../home/search_screen.dart';
import 'seller_screen.dart';
import '../../widgets/animations.dart';
import '../../i18n/strings.dart';

class BookDetailScreen extends StatefulWidget {
  final Book book;
  final String? heroTag;

  const BookDetailScreen({super.key, required this.book, this.heroTag});

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  final PageController _pageController = PageController();
  final ScrollController _scrollController = ScrollController();
  final ApiService _api = ApiService();
  final GlobalKey _cartIconKey = GlobalKey();
  final GlobalKey _addButtonKey = GlobalKey();
  final GlobalKey _actionsKey = GlobalKey();
  final GlobalKey _scrollKey = GlobalKey();

  late Book _book = widget.book;
  int _currentImageIndex = 0;
  bool _isAddingToCart = false;
  bool _isBuying = false;
  List<Book> _similar = const [];
  bool _isSharing = false;
  double? _distance;
  bool _locating = false;
  bool _gone = false;
  bool _depositing = false;
  bool _actionsScrolledAway = false;
  bool _actionsCheckPending = false;

  List<String> get _images => _book.imageUrls;

  String get _heroTag => widget.heroTag ?? 'book_image_${_book.bookId}';

  bool get _isOwnBook => _book.sellerId != 0 && _book.sellerId == ApiService.currentUser?.userId;

  bool get _hasCoordinates => _book.cabinetLatitude != null && _book.cabinetLongitude != null;

  @override
  void initState() {
    super.initState();
    if (ApiService.authToken != null) {
      _api.fetchFavoriteIds();
      _api.fetchCartBookIds();
    }
    RecentlyViewed.add(widget.book);
    _scrollController.addListener(_onTabletScroll);
    _loadDetail();
    _loadSimilar();
    _resolveDistance(request: false);
  }

  Future<void> _loadSimilar() async {
    final books = await _api.fetchSimilarBooks(widget.book.bookId);
    if (!mounted || books.isEmpty) return;
    setState(() => _similar = books);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    final result = await _api.fetchBookDetailState(widget.book.bookId);
    if (!mounted) return;
    if (result.gone) {
      setState(() => _gone = true);
      return;
    }
    final detail = result.book;
    if (detail == null) return;
    setState(() {
      _book = detail;
      if (_currentImageIndex >= _images.length) _currentImageIndex = 0;
    });
    RecentlyViewed.add(detail);
    if (_distance == null) _resolveDistance(request: false);
  }

  Future<void> _resolveDistance({required bool request}) async {
    if (!_hasCoordinates || _locating) return;
    _locating = true;
    if (request) setState(() {});
    final position = await LocationService.current(request: request);
    if (!mounted) return;
    final meters = position == null
        ? null
        : LocationService.distanceTo(_book.cabinetLatitude!, _book.cabinetLongitude!);
    setState(() {
      _locating = false;
      _distance = meters;
    });
    if (request && position == null) {
      showAppSnackBar(context, S.couldnTGetLocationCheckLocation, isError: true);
    }
  }

  void _openCart() {
    if (HomeScreen.showTab(AppSideNav.cartTab)) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen()));
  }

  Future<void> _openSearch() async {
    final navigator = Navigator.of(context);
    final keyword = await navigator.push<String>(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const SearchScreen(initialKeyword: ''),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
      ),
    );
    if (keyword == null || keyword.isEmpty || !mounted) return;
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => HomeScreen(initialKeyword: keyword)),
      (_) => false,
    );
  }

  Future<void> _addToCart() async {
    if (_isAddingToCart) return;
    if (ApiService.cartBookIds.value.contains(_book.bookId)) {
      _openCart();
      return;
    }
    if (ApiService.authToken == null) {
      showAppSnackBar(context, S.signAddItemsCart, isError: true);
      return;
    }
    if (_book.status != 'on_sale') {
      showAppSnackBar(context, S.bookCannotPurchased(_book.statusText), isError: true);
      return;
    }
    if (_book.isReservedByOthers) {
      showAppSnackBar(context, S.bookReservedAnotherBuyerCanT, isError: true);
      return;
    }

    HapticFeedback.lightImpact();
    setState(() => _isAddingToCart = true);
    final error = await _api.addToCart(_book.bookId);
    if (!mounted) return;
    setState(() => _isAddingToCart = false);

    if (error != null) {
      showAppSnackBar(context, error, isError: true);
      _loadDetail();
      return;
    }

    HapticFeedback.mediumImpact();
    flyToCart(
      context,
      from: _addButtonKey,
      to: _cartIconKey,
      imageUrl: _book.hasImage ? _book.imageUrl : null,
      onArrive: CartIconButton.bump,
    );
    showAppSnackBar(context, S.addedCart);
  }

  bool get _purchasable => _book.status == 'on_sale' && !_book.isReservedByOthers;

  Future<void> _buyNow() async {
    if (_isBuying || _isAddingToCart) return;
    final result = await purchaseBookDirectly(
      context,
      _book,
      onBusy: (busy) => setState(() => _isBuying = busy),
      onPaid: _loadDetail,
    );
    if (!mounted) return;
    if (result.outcome == DirectPurchaseOutcome.failed) _loadDetail();
    if (result.outcome != DirectPurchaseOutcome.viewOrders) return;
    await OrderHistoryScreen.open(context, filter: OrderHistoryScreen.purchaseFilterAfterPayment(result.readyForPickup));
  }

  Future<void> _chatWithSeller() async {
    if (_book.sellerId == 0) {
      showAppSnackBar(context, S.sellerInformationNotFound, isError: true);
      return;
    }
    if (ApiService.authToken == null) {
      showAppSnackBar(context, S.signContactSeller, isError: true);
      return;
    }

    final roomId = await runBusy(context, () => _api.openChatRoom(userId: _book.sellerId, bookId: _book.bookId));
    if (!mounted) return;
    if (roomId == null) {
      showAppSnackBar(context, S.couldNotOpenChatPleaseTry, isError: true);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatRoomScreen(roomId: roomId, partnerName: _book.sellerName),
      ),
    );
  }

  Future<void> _shareBook() async {
    if (_isSharing) return;
    _isSharing = true;
    try {
      final (url, error) = await runBusy(context, () => _api.fetchBookShareLink(_book.bookId)) ?? (null, null);
      if (!mounted) return;

      if (url == null) {
        showAppSnackBar(context, error ?? AppLabels.loadFailed, isError: true);
        return;
      }

      final action = await showOptionSheet<String>(
        context,
        title: S.shareBook,
        subtitle: _book.title,
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

      final ok = await ShareService.shareText('${_book.title}\n$url');
      if (!mounted || ok) return;
      await Clipboard.setData(ClipboardData(text: url));
      if (mounted) showAppSnackBar(context, S.sharingCouldNotOpenSoLink, isError: true);
    } finally {
      _isSharing = false;
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

    if (reason.trim().length < 5) {
      showAppSnackBar(context, S.reasonNeedsLeast5Characters, isError: true);
      return;
    }

    final error = await runBusy(
      context,
      () => _api.submitReport(targetType: 'book', targetId: _book.bookId, reason: reason.trim()),
    );
    if (!mounted) return;
    showAppSnackBar(context, error ?? S.reportSubmittedWeLookInto, isError: error != null);
  }

  Future<void> _copyAddress() async {
    final text = [_book.cabinetName, _book.cabinetAddress].where((s) => s.isNotEmpty).join(' ');
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.selectionClick();
    if (mounted) showAppSnackBar(context, S.copied(S.address));
  }

  static const double _wideGap = 32;
  static const double _wideTop = 24;
  static const double _wideBottom = 32;

  List<Widget> _buildDetails(AppColors c) {
    return [
      _buildAvailabilityBanner(c),
      _buildTitleRow(c),
      const SizedBox(height: 10),
      _buildPriceAndConditionRow(c),
      const SizedBox(height: 18),
      _buildInfoCard(c),
      if (_book.description.trim().isNotEmpty) ...[const SizedBox(height: 24), _buildDescription(c)],
      const SizedBox(height: 24),
      _buildPickupCard(c),
      if (!_isOwnBook) ...[const SizedBox(height: 20), _buildSellerInfo(c)],
    ];
  }

  List<Widget> _buildTabletSummary(AppColors c) {
    return [
      _buildAvailabilityBanner(c),
      _buildTitleRow(c),
      const SizedBox(height: 10),
      _buildPriceAndConditionRow(c),
      const SizedBox(height: 20),
      KeyedSubtree(key: _actionsKey, child: _buildTabletActions(c)),
    ];
  }

  // 捲動位置超出範圍時，版面會在下一次排版直接修正位置而不再通知監聽者，排版後要再判斷一次
  void _onTabletScroll() {
    _checkActionsScrolledAway();
    if (_actionsCheckPending) return;
    _actionsCheckPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _actionsCheckPending = false;
      if (mounted) _checkActionsScrolledAway();
    });
  }

  void _checkActionsScrolledAway() {
    final actions = _actionsKey.currentContext?.findRenderObject();
    final viewport = _scrollKey.currentContext?.findRenderObject();
    if (actions is! RenderBox || viewport is! RenderBox || !actions.attached || !viewport.attached) return;
    final away = actions.localToGlobal(Offset(0, actions.size.height)).dy < viewport.localToGlobal(Offset.zero).dy;
    if (away != _actionsScrolledAway) setState(() => _actionsScrolledAway = away);
  }

  List<Widget> _buildTabletBody(AppColors c, {bool withInfo = true}) {
    final description = _book.description.trim().isNotEmpty;
    return [
      if (withInfo) _buildInfoCard(c),
      if (description) ...[if (withInfo) const SizedBox(height: 24), _buildDescription(c)],
      if (withInfo || description) const SizedBox(height: 24),
      _buildPickupCard(c),
      if (!_isOwnBook) ...[const SizedBox(height: 12), _buildSellerInfo(c)],
    ];
  }

  Widget _buildSimilar({required bool inset}) {
    final books = _similar;
    return AnimatedSize(
      duration: Motion.base,
      curve: Motion.standard,
      alignment: Alignment.topCenter,
      child: books.isEmpty
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: EdgeInsets.only(top: inset ? 0 : 24, bottom: inset ? 20 : 0),
              child: BookStrip(
                title: S.similarBooks,
                icon: Icons.auto_awesome_motion_rounded,
                books: books,
                heroPrefix: 'similar_${_book.bookId}',
                inset: inset ? 16 : 0,
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final compact = context.isCompact;

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          compact ? _buildCustomAppBar(c) : _buildTabletToolbar(c),
          if (_gone)
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: EmptyView(
                    icon: Icons.menu_book_outlined,
                    message: S.bookNoLongerExistsBeenRemoved,
                    actionLabel: S.goBack,
                    actionIcon: Icons.arrow_back_rounded,
                    onAction: () => Navigator.maybePop(context),
                  ),
                ),
              ),
            )
          else if (compact)
            Expanded(
              child: RefreshIndicator(
                color: c.accent,
                onRefresh: _loadDetail,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildImageCarousel(c),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: _buildDetails(c)),
                      ),
                      _buildSimilar(inset: true),
                    ],
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => RefreshIndicator(
                  color: c.accent,
                  onRefresh: _loadDetail,
                  child: constraints.maxWidth >= 760 && constraints.maxWidth >= constraints.maxHeight
                      ? _buildLandscape(c, constraints)
                      : _buildPortrait(c, constraints),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _gone || !compact ? null : _buildBottomActionsContent(c, 16, 16),
    );
  }

  // StickyPane 只在所在的 Stack 範圍內固定，相似書籍要放在右欄內，封面才會一路固定
  Widget _buildLandscape(AppColors c, BoxConstraints constraints) {
    final side = responsiveListPadding(constraints, maxWidth: 1160, horizontal: 24).left;
    final content = constraints.maxWidth - side * 2;
    final maxHeight = math.max(320.0, constraints.maxHeight - _wideTop - _wideBottom);
    final gallery = math.min(content * 0.4, maxHeight * 3 / 4).clamp(240.0, 480.0);
    final galleryHeight = math.min(gallery * 4 / 3, maxHeight);
    return SingleChildScrollView(
      key: _scrollKey,
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(side, _wideTop, side, _wideBottom),
      child: Stack(
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: galleryHeight),
            child: Padding(
              padding: EdgeInsets.only(left: gallery + _wideGap),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ..._buildTabletSummary(c),
                  const SizedBox(height: 28),
                  ..._buildTabletBody(c),
                  _buildSimilar(inset: false),
                ],
              ),
            ),
          ),
          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            width: gallery,
            child: StickyPane(
              controller: _scrollController,
              child: _buildImageCarousel(c, height: galleryHeight, radius: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortrait(AppColors c, BoxConstraints constraints) {
    final padding = responsiveListPadding(constraints, maxWidth: 880, horizontal: 24, top: _wideTop, bottom: _wideBottom);
    final content = constraints.maxWidth - padding.horizontal;
    final gallery = (content * 0.4).clamp(180.0, 340.0);
    final infoBeside = content - gallery - 28 >= 380;
    return SingleChildScrollView(
      key: _scrollKey,
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: gallery, child: _buildImageCarousel(c, height: gallery * 4 / 3, radius: 20)),
              const SizedBox(width: 28),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ..._buildTabletSummary(c),
                    if (infoBeside) ...[const SizedBox(height: 24), _buildInfoCard(c)],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          ..._buildTabletBody(c, withInfo: !infoBeside),
          _buildSimilar(inset: false),
        ],
      ),
    );
  }

  Widget _buildTabletToolbar(AppColors c) {
    return LayoutBuilder(
      builder: (context, constraints) => TabletToolbar(
        showBack: Navigator.canPop(context),
        titleWidget: AnimatedOpacity(
          opacity: _actionsScrolledAway && !_gone ? 1 : 0,
          duration: Motion.base,
          child: Text(
            _book.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: c.textPrimary),
          ),
        ),
        actions: [
          SwitchIn(
            alignment: AlignmentDirectional.centerEnd,
            child: _actionsScrolledAway && _purchasable && !_isOwnBook && !_gone
                ? Padding(
                    key: const ValueKey('buy'),
                    padding: const EdgeInsets.only(right: 12),
                    child: FilledButton.icon(
                      onPressed: _isBuying || _isAddingToCart ? null : _buyNow,
                      icon: const Icon(Icons.bolt_rounded, size: 18),
                      label: Text(S.buyNow2, maxLines: 1),
                      style: _tabletButtonStyle(
                        background: c.accent,
                        foreground: Colors.white,
                        disabledBackground: c.accent.withValues(alpha: 0.6),
                        disabledForeground: Colors.white,
                      ).copyWith(
                        minimumSize: const WidgetStatePropertyAll(Size(0, 36)),
                        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16)),
                      ),
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('none')),
          ),
          SizedBox(
            width: (constraints.maxWidth * 0.4).clamp(240.0, 400.0),
            child: Semantics(
              button: true,
              label: S.actionSearch,
              child: SearchFieldFrame(
                onTap: _openSearch,
                child: Text(
                  S.searchTitleAuthorPublisher,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: c.textHint, fontSize: 14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          KeyedSubtree(key: _cartIconKey, child: CartIconButton(onTap: _openCart)),
        ],
      ),
    );
  }

  Widget _buildCustomAppBar(AppColors c) {
    return LightStatusBar(
      child: Container(
        decoration: BoxDecoration(color: c.headerBg),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.only(left: 12.0, right: 8.0, top: 8.0, bottom: 12.0),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 22),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _openSearch,
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              S.searchTitleAuthorPublisher,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: c.textHint, fontSize: 14),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.search, color: c.iconInactive, size: 20),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                KeyedSubtree(
                  key: _cartIconKey,
                  child: CartIconButton(size: 24, onTap: _openCart),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageCarousel(AppColors c, {double height = 360, double radius = 0}) {
    final menu = Positioned(
      top: 12,
      right: 8,
      child: PopupMenuButton<String>(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), shape: BoxShape.circle),
          child: const Icon(Icons.more_vert, color: Colors.white, size: 22),
        ),
        onSelected: (value) => value == 'report' ? _reportBook() : _shareBook(),
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'share',
            child: Row(children: [const Icon(Icons.ios_share, size: 20), const SizedBox(width: 8), Text(S.share)]),
          ),
          if (!_isOwnBook)
            PopupMenuItem(
              value: 'report',
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 20, color: c.danger),
                  const SizedBox(width: 8),
                  Text(S.report),
                ],
              ),
            ),
        ],
      ),
    );

    final framed = radius > 0;
    Widget clip(Widget child) => framed ? ClipRRect(borderRadius: BorderRadius.circular(radius), child: child) : child;

    if (_images.isEmpty) {
      return clip(
        Stack(
          children: [
            Hero(
              tag: _heroTag,
              child: Container(
                height: height,
                width: double.infinity,
                color: framed ? c.card : c.inputFill,
                child: Icon(Icons.menu_book_rounded, size: 72, color: c.iconInactive),
              ),
            ),
            menu,
          ],
        ),
      );
    }

    final multiple = _images.length > 1;

    return clip(
      SizedBox(
        height: height,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: _images.length,
              onPageChanged: (i) => setState(() => _currentImageIndex = i),
              itemBuilder: (context, index) {
                final image = AppNetworkImage(
                  url: _images[index],
                  width: double.infinity,
                  height: height,
                  fit: framed ? BoxFit.contain : BoxFit.cover,
                  background: framed ? c.card : null,
                  fallbackIconSize: 72,
                );
                return GestureDetector(
                  onTap: () => Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(
                      builder: (_) => FullScreenImageViewer(images: _images, initialIndex: index),
                    ),
                  ),
                  child: index == 0 ? Hero(tag: _heroTag, child: image) : image,
                );
              },
            ),
            if (multiple) ...[
              Positioned(
                left: 4,
                top: height / 2 - 24,
                child: _galleryArrow(Icons.arrow_back_ios_new_rounded, _currentImageIndex > 0, () {
                  _pageController.previousPage(duration: Motion.base, curve: Motion.standard);
                }),
              ),
              Positioned(
                right: 4,
                top: height / 2 - 24,
                child: _galleryArrow(Icons.arrow_forward_ios_rounded, _currentImageIndex < _images.length - 1, () {
                  _pageController.nextPage(duration: Motion.base, curve: Motion.standard);
                }),
              ),
              Positioned(
                bottom: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_images.length, (index) {
                    final isActive = _currentImageIndex == index;
                    return AnimatedContainer(
                      duration: Motion.base,
                      curve: Motion.enterCurve,
                      margin: const EdgeInsets.symmetric(horizontal: 4.0),
                      width: isActive ? 16.0 : 6.0,
                      height: 6.0,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.5),
                      ),
                    );
                  }),
                ),
              ),
            ],
            menu,
          ],
        ),
      ),
    );
  }

  Widget _galleryArrow(IconData icon, bool enabled, VoidCallback onTap) {
    return AnimatedOpacity(
      opacity: enabled ? 1 : 0,
      duration: Motion.micro,
      child: IgnorePointer(
        ignoring: !enabled,
        child: IconButton(
          onPressed: onTap,
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.25), shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
        ),
      ),
    );
  }

  String _formatDeadline(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.month)}/${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  Widget _buildAvailabilityBanner(AppColors c) {
    Widget? banner;
    final until = _book.reservedUntil;

    if (_isOwnBook && _book.isDepositPaused) {
      banner = _banner(
        c,
        key: 'deposit_paused',
        color: c.warning,
        icon: Icons.inventory_2_outlined,
        title: S.salesPausedPleaseRetrieveBookFrom,
      );
    } else if (_book.status != 'on_sale' && !_isOwnBook) {
      banner = _banner(
        c,
        key: 'status',
        color: c.neutral,
        icon: Icons.block_rounded,
        title: S.bookCannotPurchased(_book.statusText),
      );
    } else if (until != null && _book.isReservedByOthers) {
      banner = _banner(
        c,
        key: 'others',
        color: c.warning,
        icon: Icons.lock_clock_rounded,
        title: S.reservedAnotherBuyerUntilP0(_formatDeadline(until)),
      );
    } else if (until != null && _book.reservedForMe && until.isAfter(DateTime.now())) {
      banner = _banner(
        c,
        key: 'mine',
        color: c.success,
        icon: Icons.verified_rounded,
        title: S.sellerHoldingUntilP0(_formatDeadline(until)),
      );
    }

    return AnimatedSize(
      duration: Motion.base,
      curve: Motion.standard,
      alignment: Alignment.topCenter,
      child: SwitchIn(
        child: banner ?? const SizedBox(key: ValueKey('none'), width: double.infinity),
      ),
    );
  }

  Widget _banner(
    AppColors c, {
    required String key,
    required Color color,
    required IconData icon,
    required String title,
  }) {
    return Container(
      key: ValueKey(key),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: c.isDark ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c.textPrimary, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleRow(AppColors c) {
    const actionSize = 40.0;
    final lineH = MediaQuery.textScalerOf(context).scale(24) * 1.25;
    final topInset = math.max(0.0, (actionSize - lineH) / 2);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: topInset),
            child: Text(
              _book.title,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: c.textPrimary,
                height: 1.25,
                leadingDistribution: TextLeadingDistribution.even,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox.square(
          dimension: actionSize,
          child: IconButton(
            onPressed: _shareBook,
            tooltip: S.share,
            padding: EdgeInsets.zero,
            icon: Icon(Icons.ios_share_rounded, size: 22, color: c.iconInactive),
          ),
        ),
        SizedBox.square(
          dimension: actionSize,
          child: OverflowBox(maxWidth: 64, maxHeight: 64, child: FavoriteButton(bookId: _book.bookId, size: 24)),
        ),
      ],
    );
  }

  Widget _buildPriceAndConditionRow(AppColors c) {
    final badgeColor = c.conditionColor(_book.conditionLevel);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 6,
      children: [
        Text(
          '\$${_book.price.toInt()}',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: c.accent),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: badgeColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _book.conditionText,
            style: TextStyle(
              color: badgeColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 16 / 12,
              leadingDistribution: TextLeadingDistribution.even,
            ),
          ),
        ),
        if (_book.viewCount > 0)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.visibility_outlined, size: 16, color: c.textHint),
              const SizedBox(width: 4),
              Text(
                '${_book.viewCount}',
                style: TextStyle(
                  fontSize: 13,
                  height: 16 / 13,
                  leadingDistribution: TextLeadingDistribution.even,
                  color: c.textHint,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildInfoCard(AppColors c) {
    final publishDate = _book.publishDate.trim().replaceAll('-', '/');
    final rows = <(String, String, bool)>[
      (S.author2, _book.author.trim(), false),
      (S.publisher2, _book.publisher.trim(), false),
      (S.publicationDate, publishDate, false),
      ('ISBN', _book.isbn.trim(), true),
      (S.listed3, _book.createdAt.trim(), false),
    ].where((r) => r.$2.isNotEmpty).toList();
    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, (label, value, copyable)) in rows.indexed) ...[
            if (i > 0) const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 76,
                  child: Text(label, style: TextStyle(fontSize: 13.5, height: 1.45, color: c.textSecondary)),
                ),
                Expanded(
                  child: GestureDetector(
                    onLongPress: copyable ? () => _copyText(label, value) : null,
                    child: Text(value, style: TextStyle(fontSize: 14.5, height: 1.4, color: c.textPrimary)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _copyText(String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    HapticFeedback.selectionClick();
    if (mounted) showAppSnackBar(context, S.copied(label));
  }

  Widget _buildDescription(AppColors c) {
    final source = _book.autoFilledFields.contains('description') && _book.aiWrittenDescription
        ? S.summarizedByAiFromBookRecords
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(S.aboutBook, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary)),
            if (source != null) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  source,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(fontSize: 12, color: c.textHint),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        _CollapsibleText(text: _book.description.trim()),
      ],
    );
  }

  Widget _buildPickupCard(AppColors c) {
    if (_book.cabinetName.isEmpty && _book.cabinetAddress.isEmpty) return const SizedBox.shrink();

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(Icons.storage_rounded, size: 18, color: c.accent),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _book.cabinetName.isEmpty ? S.faqCatCabinet : _book.cabinetName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
              if (_hasCoordinates) ...[const SizedBox(width: 8), _buildDistanceChip(c)],
            ],
          ),
          if (_book.cabinetAddress.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Icon(Icons.location_on_outlined, size: 16, color: c.iconInactive),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _book.cabinetAddress,
                          style: TextStyle(fontSize: 13, height: 1.4, color: c.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Semantics(
                  button: true,
                  label: S.copyAddress,
                  child: InkResponse(
                    onTap: _copyAddress,
                    radius: 18,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 6, 8, 6),
                      child: Icon(Icons.copy_rounded, size: 16, color: c.accent),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (_book.cabinetOpenHours.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 16, color: c.iconInactive),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${S.openingHours} ${_book.cabinetOpenHours}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: c.textSecondary),
                  ),
                ),
              ],
            ),
          ],
          if (_book.cabinetId != null) ...[
            const SizedBox(height: 4),
            Transform.translate(
              offset: const Offset(-8, 0),
              child: CabinetGuideButton(
                cabinetId: _book.cabinetId!,
                name: _book.cabinetName,
                address: _book.cabinetAddress,
                openHours: _book.cabinetOpenHours,
              ),
            ),
          ],
          if (!_isOwnBook && _book.inCabinet) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(Icons.inventory_2_outlined, size: 16, color: c.success),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    S.bookLockerCanCollectedRightAfter,
                    style: TextStyle(fontSize: 13, height: 1.4, fontWeight: FontWeight.w600, color: c.success),
                  ),
                ),
              ],
            ),
          ],
          if (_isOwnBook && _book.depositKnown && (_book.isDeposited || _book.canRetrieve || _book.canRegisterDeposit)) _buildDepositRow(c),
        ],
      ),
    );
  }

  Widget _buildDepositRow(AppColors c) {
    final deposit = _book.deposit;
    final location = _book.cabinetLocation;
    final retrieving = _book.isDeposited || _book.canRetrieve;
    final pending = _book.hasPendingManualReport;
    final door = location != null && location.door.isNotEmpty ? location.door : deposit?.door;
    final stored = [
      if (deposit != null) storedDaysText(deposit.daysStored) else if (location != null && location.cabinetName.isNotEmpty) location.cabinetName,
      if (door != null && door.isNotEmpty) CabinetMessages.door(door),
    ].join('・');
    final text = pending ? S.manualReportAwaitingConfirmation : (stored.isNotEmpty ? stored : S.notYetLocker);
    final label = retrieving
        ? cabinetActionLabel(_book.retrievalAccess, CabinetAction.retrieve)
        : cabinetActionLabel(_book.cabinetAccess, CabinetAction.preDeposit);
    final button = SmallActionButton(label: label, filled: true, onTap: pending ? null : _depositAction);
    final info = [
      Icon(
        pending ? Icons.hourglass_top_rounded : Icons.inventory_2_outlined,
        size: 16,
        color: pending ? c.warning : (retrieving ? c.accent : c.iconInactive),
      ),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 13, height: 1.4, color: c.textSecondary),
        ),
      ),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          Divider(height: 1, color: c.divider),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              if (SmallActionButton.widthOf(context, label) <= constraints.maxWidth * 0.45) {
                return Row(children: [...info, const SizedBox(width: 8), button]);
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: info),
                  const SizedBox(height: 8),
                  Align(alignment: AlignmentDirectional.centerEnd, child: IntrinsicWidth(child: button)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _depositAction() async {
    if (_depositing) return;
    _depositing = true;
    final sent = _book.isDeposited || _book.canRetrieve
        ? await confirmBookRetrieval(context, _book)
        : await confirmBookDeposit(context, _book);
    _depositing = false;
    if (sent && mounted) _loadDetail();
  }

  Widget _buildDistanceChip(AppColors c) {
    final meters = _distance;
    final String label;
    final IconData icon;
    VoidCallback? onTap;

    if (meters != null) {
      label = S.p0Away(LocationService.formatDistance(meters));
      icon = Icons.near_me_rounded;
    } else if (_locating) {
      label = S.locating;
      icon = Icons.near_me_outlined;
    } else {
      label = S.showDistance;
      icon = Icons.my_location_rounded;
      onTap = () => _resolveDistance(request: true);
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 150),
      child: PressableScale(
        scale: 0.94,
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.base,
          curve: Motion.standard,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: c.accent.withValues(alpha: meters != null ? 0.12 : 0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.accent.withValues(alpha: onTap != null ? 0.5 : 0.0)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: c.accent),
              const SizedBox(width: 4),
              Flexible(
                child: SwitchIn(
                  duration: Motion.micro,
                  child: Text(
                    label,
                    key: ValueKey(label),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.accent),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSellerInfo(AppColors c) {
    final sellerName = _book.sellerName.isEmpty ? S.roleAdmin : _book.sellerName;
    final avatarUrl = _book.sellerAvatarUrl;
    final VoidCallback? openSeller = _book.sellerId == 0
        ? null
        : () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SellerScreen(sellerId: _book.sellerId, sellerName: sellerName, sellerAvatarUrl: avatarUrl),
            ),
          );

    if (context.isWide) {
      return Material(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: openSeller,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Row(
              children: [
                UserAvatar(imageUrl: avatarUrl, radius: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(S.seller, style: TextStyle(fontSize: 12, color: c.textSecondary)),
                      const SizedBox(height: 2),
                      Text(
                        sellerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.textPrimary),
                      ),
                    ],
                  ),
                ),
                if (openSeller != null) Icon(Icons.chevron_right_rounded, size: 20, color: c.iconInactive),
              ],
            ),
          ),
        ),
      );
    }

    return PressableScale(
      scale: 0.985,
      onTap: openSeller,
      child: Row(
        children: [
          UserAvatar(imageUrl: avatarUrl, radius: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              sellerName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: c.textPrimary),
            ),
          ),
          Icon(Icons.chevron_right_rounded, size: 20, color: c.iconInactive),
        ],
      ),
    );
  }

  Future<void> _openEdit() async {
    if (!_book.depositKnown) {
      await runBusy(context, _loadDetail);
      if (!mounted || _gone) return;
    }
    await Navigator.push(context, MaterialPageRoute(builder: (_) => EditBookScreen(book: _book)));
    if (mounted) _loadDetail();
  }

  Widget _buildBottomActionsContent(AppColors c, double left, double right) {
    final padding = EdgeInsets.only(
      left: left,
      right: right,
      top: 12,
      bottom: MediaQuery.of(context).padding.bottom + 12,
    );
    final decoration = BoxDecoration(
      color: c.card,
      border: Border(top: BorderSide(color: c.divider, width: 1)),
    );

    if (_isOwnBook) {
      final canEdit = !_book.isDeposited && (_book.status == 'removed' || (_book.status == 'on_sale' && !_book.isHeld));
      final lockedStatus = _book.isDeposited ? S.inLocker : _book.ownerStatusText;
      return Container(
        padding: padding,
        decoration: decoration,
        child: SizedBox(
          height: 48,
          child: FilledButton.icon(
            onPressed: canEdit ? _openEdit : null,
            icon: Icon(canEdit ? Icons.edit_outlined : Icons.lock_outline_rounded, size: 18),
            label: Text(
              canEdit ? S.editBook : S.p0CannotEdit(lockedStatus),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            style: FilledButton.styleFrom(
              backgroundColor: c.accent,
              foregroundColor: Colors.white,
              disabledBackgroundColor: c.inputFill,
              disabledForegroundColor: c.textHint,
              textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: padding,
      decoration: decoration,
      child: Row(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: Tooltip(
              message: S.messageSeller,
              child: OutlinedButton(
                onPressed: _chatWithSeller,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Semantics(label: S.messageSeller, child: const Icon(Icons.chat_bubble_outline, size: 20)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ValueListenableBuilder<Set<int>>(
              valueListenable: ApiService.cartBookIds,
              builder: (context, ids, _) => _buildCartButton(c, ids.contains(_book.bookId)),
            ),
          ),
          if (_purchasable) ...[const SizedBox(width: 10), Expanded(child: _buildBuyNowButton(c))],
        ],
      ),
    );
  }

  Widget _buildBuyNowButton(AppColors c) {
    final reservedForMe = _book.reservedForMe && (_book.reservedUntil?.isAfter(DateTime.now()) ?? false);
    return SizedBox(
      height: 48,
      child: FilledButton.icon(
        onPressed: _isBuying || _isAddingToCart ? null : _buyNow,
        icon: _isBuying
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.bolt_rounded, size: 19),
        label: Text(S.buyNow2, maxLines: 1, overflow: TextOverflow.ellipsis),
        style: FilledButton.styleFrom(
          backgroundColor: reservedForMe ? c.success : c.accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: (reservedForMe ? c.success : c.accent).withValues(alpha: 0.6),
          disabledForegroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Widget _buildCartButton(AppColors c, bool inCart) {
    final String key;
    final String label;
    final IconData icon;
    final bool strong;
    VoidCallback? onTap;

    if (_book.status != 'on_sale') {
      key = 'unavailable';
      label = _book.statusText;
      icon = Icons.block_rounded;
      strong = false;
    } else if (_book.isReservedByOthers) {
      key = 'reserved';
      label = S.reserved;
      icon = Icons.lock_clock_rounded;
      strong = false;
    } else if (inCart) {
      key = 'in_cart';
      label = S.cart2;
      icon = Icons.check_circle_rounded;
      strong = false;
      onTap = _openCart;
    } else {
      key = 'add';
      label = S.addCart;
      icon = Icons.add_shopping_cart_rounded;
      strong = false;
      onTap = _addToCart;
    }

    final enabled = onTap != null && !_isAddingToCart;
    final muted = !strong;
    final background = muted ? c.accent.withValues(alpha: c.isDark ? 0.16 : 0.1) : c.accent;
    final foreground = muted ? (onTap == null ? c.textHint : c.accent) : Colors.white;

    return PressableScale(
      key: _addButtonKey,
      scale: 0.96,
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: Motion.base,
        curve: Motion.standard,
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: onTap == null && muted ? c.inputFill : background,
          borderRadius: BorderRadius.circular(10),
        ),
        child: SwitchIn(
          duration: Motion.micro,
          child: _isAddingToCart
              ? SizedBox(
                  key: const ValueKey('busy'),
                  height: 48,
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
                    ),
                  ),
                )
              : SizedBox(
                  key: ValueKey(key),
                  height: 48,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TweenAnimationBuilder<double>(
                        key: ValueKey('icon_$key'),
                        tween: Tween(begin: key == 'in_cart' ? 0.4 : 1, end: 1),
                        duration: Motion.enter,
                        curve: Motion.pop,
                        builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
                        child: Icon(icon, size: 19, color: foreground),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: foreground),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  ButtonStyle _tabletButtonStyle({
    required Color background,
    required Color foreground,
    Color? disabledBackground,
    Color? disabledForeground,
  }) {
    return FilledButton.styleFrom(
      backgroundColor: background,
      foregroundColor: foreground,
      disabledBackgroundColor: disabledBackground,
      disabledForegroundColor: disabledForeground,
      minimumSize: const Size(0, 46),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _buildTabletActions(AppColors c) {
    if (_isOwnBook) {
      final canEdit = !_book.isDeposited && (_book.status == 'removed' || (_book.status == 'on_sale' && !_book.isHeld));
      final lockedStatus = _book.isDeposited ? S.inLocker : _book.ownerStatusText;
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: FilledButton.icon(
          onPressed: canEdit ? _openEdit : null,
          icon: Icon(canEdit ? Icons.edit_outlined : Icons.lock_outline_rounded, size: 18),
          label: Text(canEdit ? S.editBook : S.p0CannotEdit(lockedStatus), maxLines: 1, overflow: TextOverflow.ellipsis),
          style: _tabletButtonStyle(
            background: c.accent,
            foreground: Colors.white,
            disabledBackground: c.card,
            disabledForeground: c.textHint,
          ),
        ),
      );
    }

    final reservedForMe = _book.reservedForMe && (_book.reservedUntil?.isAfter(DateTime.now()) ?? false);
    final buyColor = reservedForMe ? c.success : c.accent;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        if (_purchasable)
          FilledButton.icon(
            onPressed: _isBuying || _isAddingToCart ? null : _buyNow,
            icon: _isBuying
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.bolt_rounded, size: 19),
            label: Text(S.buyNow2, maxLines: 1, overflow: TextOverflow.ellipsis),
            style: _tabletButtonStyle(
              background: buyColor,
              foreground: Colors.white,
              disabledBackground: buyColor.withValues(alpha: 0.6),
              disabledForeground: Colors.white,
            ),
          ),
        ValueListenableBuilder<Set<int>>(
          valueListenable: ApiService.cartBookIds,
          builder: (context, ids, _) => _buildTabletCartButton(c, ids.contains(_book.bookId)),
        ),
        OutlinedButton.icon(
          onPressed: _chatWithSeller,
          icon: const Icon(Icons.chat_bubble_outline, size: 19),
          label: Text(S.messageSeller, maxLines: 1, overflow: TextOverflow.ellipsis),
          style: OutlinedButton.styleFrom(
            foregroundColor: c.accent,
            side: BorderSide(color: c.accent.withValues(alpha: 0.55)),
            minimumSize: const Size(0, 46),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildTabletCartButton(AppColors c, bool inCart) {
    final (String label, IconData icon, VoidCallback? onTap) = _book.status != 'on_sale'
        ? (_book.statusText, Icons.block_rounded, null)
        : _book.isReservedByOthers
        ? (S.reserved, Icons.lock_clock_rounded, null)
        : inCart
        ? (S.cart2, Icons.check_circle_rounded, _openCart)
        : (S.addCart, Icons.add_shopping_cart_rounded, _addToCart);
    return KeyedSubtree(
      key: _addButtonKey,
      child: FilledButton.icon(
        onPressed: onTap == null ? null : (_isAddingToCart ? () {} : onTap),
        icon: _isAddingToCart
            ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: c.accent))
            : Icon(icon, size: 19),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        style: _tabletButtonStyle(
          background: c.accent.withValues(alpha: c.isDark ? 0.18 : 0.1),
          foreground: c.accent,
          disabledBackground: c.card,
          disabledForeground: c.textHint,
        ),
      ),
    );
  }
}

class FullScreenImageViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const FullScreenImageViewer({super.key, required this.images, required this.initialIndex});

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  late final PageController _pageController = PageController(initialPage: widget.initialIndex);
  late int _currentIndex = widget.initialIndex;

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
        systemOverlayStyle: SystemUiOverlayStyle.light,
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
            minScale: 1,
            maxScale: 4.0,
            child: Center(
              child: Image.network(
                widget.images[index],
                fit: BoxFit.contain,
                frameBuilder: (_, child, frame, wasSynchronouslyLoaded) => wasSynchronouslyLoaded
                    ? child
                    : AnimatedOpacity(
                        opacity: frame == null ? 0 : 1,
                        duration: Motion.base,
                        curve: Curves.easeOut,
                        child: child,
                      ),
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  final total = progress.expectedTotalBytes;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      child,
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(
                          value: total == null || total == 0 ? null : progress.cumulativeBytesLoaded / total,
                          strokeWidth: 3,
                          strokeCap: StrokeCap.round,
                          color: Colors.white70,
                          backgroundColor: Colors.white12,
                        ),
                      ),
                    ],
                  );
                },
                errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 72),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CollapsibleText extends StatefulWidget {
  final String text;

  const _CollapsibleText({required this.text});

  @override
  State<_CollapsibleText> createState() => _CollapsibleTextState();
}

class _CollapsibleTextState extends State<_CollapsibleText> {
  static const _collapsedLines = 4;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final style = TextStyle(fontSize: 15, height: 1.6, color: c.textPrimary);
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: _collapsedLines,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;
        painter.dispose();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedSize(
              duration: Motion.base,
              curve: Motion.enterCurve,
              alignment: Alignment.topCenter,
              child: Text(
                widget.text,
                style: style,
                maxLines: _expanded ? null : _collapsedLines,
                overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
              ),
            ),
            if (overflows)
              TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: c.accent,
                ),
                child: Text(_expanded ? S.collapse : S.readFull, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
          ],
        );
      },
    );
  }
}
