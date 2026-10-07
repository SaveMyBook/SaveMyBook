import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../models/book.dart';
import '../../utils/app_colors.dart';
import '../../utils/motion.dart';
import '../../widgets/animations.dart';
import '../../widgets/book_card.dart';
import '../../widgets/buyer/book_menu.dart';
import '../../widgets/buyer/book_strip.dart';
import '../../widgets/state_views.dart';
import '../books/book_detail_screen.dart';

class WideDiscoveryPanel extends StatelessWidget {
  final List<DiscoveryTab> tabs;
  final double inset;

  const WideDiscoveryPanel({super.key, required this.tabs, required this.inset});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    if (tabs.isEmpty) return const SizedBox(width: double.infinity);

    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = ShelfBookTile.widthFor(constraints.maxWidth - inset * 2);
        Widget shelf(DiscoveryTab tab, List<Book> books, String heroPrefix, Map<int, String> reasons) => _Shelf(
              key: ValueKey('shelf_$heroPrefix'),
              books: books,
              heroPrefix: heroPrefix,
              reasons: reasons,
              tileWidth: tileWidth,
              inset: inset,
              onOpen: tab.onOpen,
              onDismiss: tab.onDismiss,
            );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (t, tab) in tabs.indexed) ...[
              if (t > 0) const SizedBox(height: 24),
              _sectionHeader(c, tab),
              if (tab.groups.isEmpty)
                shelf(tab, tab.books, tab.id, const {})
              else
                for (final (i, group) in tab.groups.indexed) ...[
                  if (i > 0) const SizedBox(height: 14),
                  if (group.title != null)
                    Padding(
                      padding: EdgeInsets.fromLTRB(inset, 0, inset, 10),
                      child: Text(
                        group.title!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.textSecondary),
                      ),
                    ),
                  shelf(tab, group.books, '${tab.id}$i', group.reasons),
                ],
            ],
          ],
        );
      },
    );
  }

  Widget _sectionHeader(AppColors c, DiscoveryTab tab) {
    return Padding(
      padding: EdgeInsets.fromLTRB(inset, 0, inset - 8, 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 36),
        child: Row(
          children: [
            Icon(tab.icon, size: 20, color: c.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                tab.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: c.textPrimary),
              ),
            ),
            if (tab.actionLabel != null)
              TextButton(
                onPressed: tab.onAction,
                style: TextButton.styleFrom(
                  foregroundColor: c.accent,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(0, 34),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text(
                    tab.actionLabel!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Shelf extends StatefulWidget {
  final List<Book> books;
  final String heroPrefix;
  final Map<int, String> reasons;
  final double tileWidth;
  final double inset;
  final ValueChanged<Book>? onOpen;
  final ValueChanged<Book>? onDismiss;

  const _Shelf({
    super.key,
    required this.books,
    required this.heroPrefix,
    required this.reasons,
    required this.tileWidth,
    required this.inset,
    this.onOpen,
    this.onDismiss,
  });

  @override
  State<_Shelf> createState() => _ShelfState();
}

class _ShelfState extends State<_Shelf> {
  static const double _shadowSpace = 10;

  final ScrollController _controller = ScrollController();
  bool _hovering = false;
  bool _canBack = false;
  bool _canForward = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_sync);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _sync() {
    if (!mounted || !_controller.hasClients) return;
    final p = _controller.position;
    if (!p.hasContentDimensions) return;
    final back = p.pixels > p.minScrollExtent + 1;
    final forward = p.pixels < p.maxScrollExtent - 1;
    if (back == _canBack && forward == _canForward) return;
    setState(() {
      _canBack = back;
      _canForward = forward;
    });
  }

  void _page(int direction) {
    if (!_controller.hasClients) return;
    final p = _controller.position;
    final stride = widget.tileWidth + ShelfBookTile.gap;
    final perPage = math.max(1, ((p.viewportDimension - widget.inset * 2 + ShelfBookTile.gap) / stride).floor());
    final target = (((p.pixels / stride).round() + direction * perPage) * stride).clamp(p.minScrollExtent, p.maxScrollExtent);
    _controller.animateTo(target.toDouble(), duration: Motion.large, curve: Motion.standard);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final books = widget.books;
    final height = ShelfBookTile.heightOf(context, withReasons: books.any((b) => widget.reasons.containsKey(b.bookId)));

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: SizedBox(
        height: height + _shadowSpace,
        child: Stack(
          children: [
            NotificationListener<ScrollMetricsNotification>(
              onNotification: (_) {
                _sync();
                return false;
              },
              // 預設只有觸控與觸控板可拖曳捲動，接滑鼠時也要能拖曳書架
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  dragDevices: PointerDeviceKind.values.toSet(),
                  scrollbars: false,
                ),
                child: ListView.separated(
                  controller: _controller,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(widget.inset, 0, widget.inset, _shadowSpace),
                  itemCount: books.length,
                  separatorBuilder: (_, _) => const SizedBox(width: ShelfBookTile.gap),
                  itemBuilder: (context, i) => FadeSlideIn(
                    index: i,
                    offsetY: 10,
                    child: ShelfBookTile(
                      book: books[i],
                      heroTag: '${widget.heroPrefix}_${books[i].bookId}',
                      reason: widget.reasons[books[i].bookId],
                      width: widget.tileWidth,
                      height: height,
                      onOpen: widget.onOpen,
                      onDismiss: widget.onDismiss,
                    ),
                  ),
                ),
              ),
            ),
            _arrow(c, back: true, bottom: _shadowSpace),
            _arrow(c, back: false, bottom: _shadowSpace),
          ],
        ),
      ),
    );
  }

  Widget _arrow(AppColors c, {required bool back, required double bottom}) {
    final visible = _hovering && (back ? _canBack : _canForward);
    final l = MaterialLocalizations.of(context);
    return Positioned(
      left: back ? 8 : null,
      right: back ? null : 8,
      top: 0,
      bottom: bottom,
      child: Center(
        child: IgnorePointer(
          ignoring: !visible,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: Motion.micro,
            child: Material(
              color: c.card,
              elevation: 4,
              shadowColor: c.shadow,
              shape: CircleBorder(side: BorderSide(color: c.border)),
              child: IconButton(
                tooltip: back ? l.previousPageTooltip : l.nextPageTooltip,
                icon: Icon(back ? Icons.chevron_left_rounded : Icons.chevron_right_rounded, color: c.textPrimary),
                onPressed: () => _page(back ? -1 : 1),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ShelfBookTile extends StatelessWidget {
  static const double gap = 16;
  static const double _peek = 40;
  static const double _minWidth = 256;
  static const double _maxWidth = 340;
  static const double _coverRatio = 1.42;
  static const double _titleFontSize = 15;
  static const double _titleLineHeight = 1.3;
  static const double _reasonFontSize = 12.5;
  static const double _reasonLineHeight = 1.4;
  static const int _reasonLines = 3;
  static const double _priceFontSize = 18;
  static const double _tagsHeight = 22;

  final Book book;
  final String heroTag;
  final String? reason;
  final double width;
  final double height;
  final ValueChanged<Book>? onOpen;
  final ValueChanged<Book>? onDismiss;

  const ShelfBookTile({
    super.key,
    required this.book,
    required this.heroTag,
    required this.width,
    required this.height,
    this.reason,
    this.onOpen,
    this.onDismiss,
  });

  // 右側刻意露出一小段下一張卡片，提示書架可以橫向捲動
  static double widthFor(double available) {
    final columns = math.max(1, ((available - _peek) / (_minWidth + gap)).floor());
    return ((available - _peek - columns * gap) / columns).clamp(_minWidth, _maxWidth).toDouble();
  }

  static double heightOf(BuildContext context, {required bool withReasons}) {
    final scaler = MediaQuery.textScalerOf(context);
    final title = scaler.scale(_titleFontSize) * _titleLineHeight * 2;
    final middle = withReasons ? scaler.scale(_reasonFontSize) * _reasonLineHeight * _reasonLines : _tagsHeight;
    final price = scaler.scale(_priceFontSize) * 1.3;
    return math.max(148.0, 12 + title + 6 + middle + 8 + price + 12);
  }

  void _open(BuildContext context) {
    onOpen?.call(book);
    Navigator.push(context, CupertinoPageRoute(builder: (_) => BookDetailScreen(book: book, heroTag: heroTag)));
  }

  void _menu(BuildContext context) => showBookMenu(
        context,
        book,
        heroTag: heroTag,
        onOpen: onOpen == null ? null : () => onOpen!(book),
        onNotInterested: onDismiss,
      );

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final radius = BorderRadius.circular(14);
    final coverWidth = (height / _coverRatio).roundToDouble();

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [BoxShadow(color: c.shadow.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Material(
        color: c.card,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _open(context),
          onLongPress: () => _menu(context),
          onSecondaryTapUp: (_) => _menu(context),
          hoverColor: c.accent.withValues(alpha: 0.06),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                children: [
                  Hero(
                    tag: heroTag,
                    child: AppNetworkImage(
                      url: book.hasImage ? book.imageUrl : null,
                      width: coverWidth,
                      height: height,
                      fallbackIconSize: 32,
                    ),
                  ),
                  if (book.status != 'on_sale')
                    Positioned(
                      left: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.62),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          book.statusText,
                          maxLines: 1,
                          style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: _titleFontSize,
                          height: _titleLineHeight,
                          fontWeight: FontWeight.w600,
                          color: c.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (reason != null)
                        Text(
                          reason!,
                          maxLines: _reasonLines,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: _reasonFontSize, height: _reasonLineHeight, color: c.textSecondary),
                        )
                      else
                        SizedBox(height: _tagsHeight, child: BookCard.tagsOf(c, book)),
                      const Spacer(),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '\$${book.price.toInt()}',
                          maxLines: 1,
                          style: TextStyle(fontSize: _priceFontSize, fontWeight: FontWeight.w800, color: c.accent),
                        ),
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
}
