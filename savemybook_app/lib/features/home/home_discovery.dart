import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../models/book.dart';
import '../../utils/app_colors.dart';
import '../../utils/motion.dart';
import '../../widgets/animations.dart';
import '../../widgets/book_card.dart';
import '../../widgets/buyer/book_strip.dart';
import '../../widgets/state_views.dart';
import '../books/book_detail_screen.dart';

class WideDiscoveryPanel extends StatefulWidget {
  final List<DiscoveryTab> tabs;
  final double inset;

  const WideDiscoveryPanel({super.key, required this.tabs, required this.inset});

  @override
  State<WideDiscoveryPanel> createState() => _WideDiscoveryPanelState();
}

class _WideDiscoveryPanelState extends State<WideDiscoveryPanel> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final tabs = widget.tabs;
    if (tabs.isEmpty) return const SizedBox(width: double.infinity);
    final current = tabs.firstWhere((t) => t.id == _selected, orElse: () => tabs.first);
    final inset = widget.inset;

    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = BookCard.tileWidthFor(constraints.maxWidth - inset * 2);
        Widget row(List<Book> books, String heroPrefix, Map<int, String> reasons) => _BookRow(
              books: books,
              heroPrefix: heroPrefix,
              reasons: reasons,
              tileWidth: tileWidth,
              inset: inset,
              onOpen: current.onOpen,
              onLongPress: current.onLongPress,
            );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(inset, 0, inset - 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final tab in tabs) ...[
                            _tabButton(c, tab, tab.id == current.id),
                            if (tab != tabs.last) const SizedBox(width: 6),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (current.actionLabel != null)
                    TextButton(
                      onPressed: current.onAction,
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
                            constraints: const BoxConstraints(maxWidth: 160),
                            child: Text(
                              current.actionLabel!,
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
            AnimatedSwitcher(
              duration: Motion.base,
              switchInCurve: Motion.enterCurve,
              switchOutCurve: Motion.exitCurve,
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.topLeft,
                children: [...previous, ?current],
              ),
              child: current.groups.isEmpty
                  ? KeyedSubtree(key: ValueKey(current.id), child: row(current.books, current.id, const {}))
                  : Column(
                      key: ValueKey(current.id),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final (i, group) in current.groups.indexed) ...[
                          if (i > 0) const SizedBox(height: 18),
                          if (group.title != null)
                            Padding(
                              padding: EdgeInsets.fromLTRB(inset, 0, inset, 10),
                              child: Text(
                                group.title!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.textPrimary),
                              ),
                            ),
                          row(group.books, '${current.id}$i', group.reasons),
                        ],
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _tabButton(AppColors c, DiscoveryTab tab, bool active) {
    return PressableScale(
      scale: 0.95,
      onTap: active ? null : () => setState(() => _selected = tab.id),
      child: AnimatedContainer(
        duration: Motion.base,
        curve: Motion.standard,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? c.accent.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(tab.icon, size: 16, color: active ? c.accent : c.textSecondary),
            const SizedBox(width: 6),
            Text(
              tab.title,
              maxLines: 1,
              style: TextStyle(
                fontSize: 15,
                fontWeight: active ? FontWeight.bold : FontWeight.w500,
                color: active ? c.textPrimary : c.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookRow extends StatelessWidget {
  final List<Book> books;
  final String heroPrefix;
  final Map<int, String> reasons;
  final double tileWidth;
  final double inset;
  final ValueChanged<Book>? onOpen;
  final ValueChanged<Book>? onLongPress;

  const _BookRow({
    required this.books,
    required this.heroPrefix,
    required this.reasons,
    required this.tileWidth,
    required this.inset,
    this.onOpen,
    this.onLongPress,
  });

  static const double _coverRatio = 7 / 6;
  static const double _titleFontSize = 14;
  static const double _titleLineHeight = 1.3;
  static const double _priceFontSize = 16;
  static const double _reasonFontSize = 12;
  static const double _reasonLineHeight = 1.35;
  static const int _reasonLines = 3;
  static const double _reasonGap = 4;

  double _heightOf(BuildContext context, bool withReasons) {
    final scaler = MediaQuery.textScalerOf(context);
    final title = scaler.scale(_titleFontSize) * _titleLineHeight * 2;
    final price = scaler.scale(_priceFontSize) * 1.4;
    final reason = withReasons ? _reasonGap + scaler.scale(_reasonFontSize) * _reasonLineHeight * _reasonLines : 0.0;
    return tileWidth * _coverRatio + 8 + title + 8 + price + 12 + reason + 6;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return SizedBox(
      height: _heightOf(context, books.any((b) => reasons.containsKey(b.bookId))),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(inset, 0, inset, 6),
        itemCount: books.length,
        separatorBuilder: (_, _) => const SizedBox(width: BookCard.gridSpacing),
        itemBuilder: (context, i) => FadeSlideIn(
          index: i,
          offsetY: 10,
          child: _tile(context, c, books[i]),
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, AppColors c, Book book) {
    final heroTag = '${heroPrefix}_${book.bookId}';
    final reason = reasons[book.bookId];
    final coverHeight = tileWidth * _coverRatio;

    return PressableScale(
      scale: 0.96,
      onTap: () {
        onOpen?.call(book);
        Navigator.push(
          context,
          CupertinoPageRoute(builder: (_) => BookDetailScreen(book: book, heroTag: heroTag)),
        );
      },
      onLongPress: onLongPress == null ? null : () => onLongPress!(book),
      child: Container(
        width: tileWidth,
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
                    width: tileWidth,
                    height: coverHeight,
                    fallbackIconSize: 36,
                  ),
                ),
                if (book.status != 'on_sale')
                  Positioned(
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
                  ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
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
                    if (reason != null) ...[
                      const SizedBox(height: _reasonGap),
                      Text(
                        reason,
                        maxLines: _reasonLines,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: _reasonFontSize, height: _reasonLineHeight, color: c.textSecondary),
                      ),
                    ],
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
    );
  }
}
