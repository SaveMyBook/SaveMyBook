import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/book.dart';
import '../../services/api_service.dart';
import '../../services/search_history.dart';
import '../../utils/app_colors.dart';
import '../../utils/motion.dart';
import '../../widgets/responsive.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_header.dart';
import '../../widgets/buyer/undo_snackbar.dart';
import '../../widgets/search_bar_widget.dart';
import '../../widgets/state_views.dart';
import '../../i18n/strings.dart';

const String kSearchBarHeroTag = 'home_search_bar';

class SearchScreen extends StatefulWidget {
  final String initialKeyword;
  const SearchScreen({super.key, this.initialKeyword = ''});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _searchController = TextEditingController(text: widget.initialKeyword);
  final FocusNode _focusNode = FocusNode();
  final ApiService _api = ApiService();

  bool _ready = false;
  Animation<double>? _routeAnimation;
  List<Book> _trending = [];
  bool _trendingLoading = true;

  @override
  void initState() {
    super.initState();
    SearchHistory.load();
    _searchController.addListener(_onTextChanged);
    _loadTrending();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final animation = ModalRoute.of(context)?.animation;
      if (animation == null || animation.status == AnimationStatus.completed) {
        _onTransitionDone();
        return;
      }
      _routeAnimation = animation..addStatusListener(_onStatus);
    });
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _routeAnimation?.removeStatusListener(_onStatus);
    _routeAnimation = null;
    _onTransitionDone();
  }

  void _onTransitionDone() {
    if (!mounted) return;
    setState(() => _ready = true);
    _focusNode.requestFocus();
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_onStatus);
    _searchController.removeListener(_onTextChanged);
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadTrending() async {
    final books = await _api.fetchBooks(page: 1, limit: 10, sort: 'popular');
    if (!mounted) return;
    final seen = <String>{};
    setState(() {
      _trending = books.where((b) => b.title.trim().isNotEmpty && seen.add(b.title.trim())).take(8).toList();
      _trendingLoading = false;
    });
  }

  void _submitSearch(String keyword) {
    final trimmed = keyword.trim();
    if (trimmed.isNotEmpty) {
      HapticFeedback.selectionClick();
      SearchHistory.add(trimmed);
    }
    Navigator.pop(context, trimmed);
  }

  void _removeHistory(String keyword) {
    HapticFeedback.selectionClick();
    SearchHistory.remove(keyword);
  }

  Future<void> _clearHistory() async {
    final previous = SearchHistory.items.value;
    if (previous.isEmpty) return;
    await SearchHistory.clear();
    if (!mounted) return;
    final undo = await showUndoSnackBar(context, S.searchHistoryCleared, icon: Icons.history_rounded);
    if (undo) await SearchHistory.restore(previous);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final wide = context.isWide;

    final page = Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          wide ? _buildToolbar(c) : _buildHeader(c),
          Expanded(
            child: ValueListenableBuilder<List<String>>(
              valueListenable: SearchHistory.items,
              builder: (context, history, _) {
                final query = _searchController.text.trim().toLowerCase();
                final matches = query.isEmpty
                    ? history
                    : history.where((k) => k.toLowerCase().contains(query)).toList();
                final hasTrending = _trendingLoading || _trending.isNotEmpty;

                if (history.isEmpty && !hasTrending) {
                  return EmptyView(
                    key: const ValueKey('empty'),
                    icon: Icons.manage_search_rounded,
                    message: S.noRecentSearches,
                  );
                }

                return LayoutBuilder(builder: (context, constraints) => ListView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: wide
                      ? responsiveListPadding(constraints, horizontal: 24, top: 24, bottom: 32)
                      : responsiveListPadding(constraints, top: 20, bottom: 24),
                  children: [
                    AnimatedSize(
                      duration: Motion.base,
                      curve: Motion.standard,
                      alignment: Alignment.topCenter,
                      child: matches.isEmpty
                          ? const SizedBox(width: double.infinity)
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _sectionTitle(
                                  c,
                                  S.recentSearches,
                                  trailing: wide
                                      ? TextButton(
                                          onPressed: _clearHistory,
                                          style: TextButton.styleFrom(
                                            foregroundColor: c.accent,
                                            minimumSize: const Size(0, 32),
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          child: Text(S.clearAll2, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                        )
                                      : GestureDetector(
                                          onTap: _clearHistory,
                                          behavior: HitTestBehavior.opaque,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 4),
                                            child: Text(S.clearAll2, style: TextStyle(fontSize: 12, color: c.textHint)),
                                          ),
                                        ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    for (var i = 0; i < matches.length; i++)
                                      FadeSlideIn(
                                        key: ValueKey('history_${matches[i]}'),
                                        index: i,
                                        offsetY: 8,
                                        stagger: const Duration(milliseconds: 28),
                                        child: _buildHistoryChip(c, matches[i]),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 28),
                              ],
                            ),
                    ),
                    if (hasTrending && wide) ...[
                      _sectionTitle(c, S.trendingBooks, icon: Icons.local_fire_department_rounded),
                      const SizedBox(height: 8),
                      _buildTrendingColumns(c),
                    ] else if (hasTrending) ...[
                      _sectionTitle(c, S.trendingBooks, icon: Icons.local_fire_department_rounded),
                      const SizedBox(height: 8),
                      if (_trendingLoading)
                        Shimmer(
                          child: Column(
                            children: [
                              for (var i = 0; i < 5; i++)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 10),
                                  child: Row(children: [
                                    SkeletonBox(width: 22, height: 18, radius: 4),
                                    SizedBox(width: 12),
                                    Expanded(child: SkeletonBox(height: 14)),
                                  ]),
                                ),
                            ],
                          ),
                        )
                      else
                        for (var i = 0; i < _trending.length; i++)
                          FadeSlideIn(
                            index: i,
                            offsetY: 6,
                            stagger: const Duration(milliseconds: 30),
                            child: _buildTrendingRow(c, i, _trending[i]),
                          ),
                    ],
                  ],
                ));
              },
            ),
          ),
        ],
      ),
    );
    if (!wide) return page;
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.maybePop(context)},
      child: page,
    );
  }

  Widget _buildTrendingColumns(AppColors c) {
    final count = _trendingLoading ? 8 : _trending.length;
    final rows = (count + 1) ~/ 2;
    Widget column(int from) {
      final to = (from + rows).clamp(0, count);
      return Column(
        children: [
          for (var i = from; i < to; i++) ...[
            if (i > from) Divider(height: 1, thickness: 1, indent: 82, color: c.divider),
            _trendingLoading
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    child: Row(children: [
                      SkeletonBox(width: 22, height: 18, radius: 4),
                      SizedBox(width: 12),
                      SkeletonBox(width: 36, height: 50, radius: 6),
                      SizedBox(width: 12),
                      Expanded(child: SkeletonBox(height: 14)),
                    ]),
                  )
                : FadeSlideIn(
                    index: i,
                    offsetY: 6,
                    stagger: const Duration(milliseconds: 30),
                    child: _buildTrendingTile(c, i, _trending[i]),
                  ),
          ],
        ],
      );
    }

    final columns = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: column(0)),
        const SizedBox(width: 24),
        Expanded(child: column(rows)),
      ],
    );
    return _trendingLoading ? Shimmer(child: columns) : columns;
  }

  Widget _buildTrendingTile(AppColors c, int index, Book book) {
    final rankColor = index < 3 ? c.accent : c.textHint;
    final subtitle = book.author.trim().isNotEmpty ? book.author.trim() : book.categoryName;
    return InkWell(
      onTap: () => _submitSearch(book.title),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Text(
                '${index + 1}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: rankColor, fontStyle: FontStyle.italic),
              ),
            ),
            const SizedBox(width: 10),
            BookThumbnail(imageUrl: book.hasImage ? book.imageUrl : null, width: 36, height: 50, radius: 6),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.textPrimary),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: c.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.north_west_rounded, size: 16, color: c.iconInactive),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar(AppColors c) {
    return TabletToolbar(
      showBack: Navigator.canPop(context),
      titleWidget: Hero(
        tag: kSearchBarHeroTag,
        flightShuttleBuilder: (_, _, _, _, _) => const Material(
          color: Colors.transparent,
          child: SearchFieldFrame(child: SizedBox.shrink()),
        ),
        child: SearchFieldFrame(
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _focusNode,
                  style: TextStyle(fontSize: 15, color: c.textPrimary),
                  textInputAction: TextInputAction.search,
                  onSubmitted: _submitSearch,
                  cursorColor: c.accent,
                  decoration: InputDecoration(
                    isDense: true,
                    filled: false,
                    hintText: S.searchTitleAuthorIsbn,
                    hintStyle: TextStyle(color: c.textHint, fontSize: 15),
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                  ),
                ),
              ),
              if (_searchController.text.isNotEmpty)
                IconButton(
                  tooltip: MaterialLocalizations.of(context).clearButtonTooltip,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                  icon: Icon(Icons.cancel, color: c.iconInactive, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    _focusNode.requestFocus();
                  },
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => _submitSearch(_searchController.text),
          style: TextButton.styleFrom(foregroundColor: c.accent),
          child: Text(S.actionSearch, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  Widget _sectionTitle(AppColors c, String title, {IconData? icon, Widget? trailing}) {
    final wide = context.isWide;
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: wide ? 18 : 16, color: c.accent),
          SizedBox(width: wide ? 8 : 6),
        ],
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: wide
                ? TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: c.textPrimary)
                : TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: c.textSecondary),
          ),
        ),
        ?trailing,
      ],
    );
  }

  Widget _buildTrendingRow(AppColors c, int index, Book book) {
    final rankColor = index < 3 ? c.accent : c.textHint;
    return InkWell(
      onTap: () => _submitSearch(book.title),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Text(
                '${index + 1}',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: rankColor, fontStyle: FontStyle.italic),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                book.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, color: c.textPrimary),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.north_west_rounded, size: 16, color: c.iconInactive),
          ],
        ),
      ),
    );
  }

  EdgeInsets _headerPadding(BoxConstraints constraints) {
    final side = responsiveListPadding(constraints).left;
    if (side < 64) return const EdgeInsets.fromLTRB(4, 8, 16, 20);
    return EdgeInsets.fromLTRB(side - 56, 8, side, 20);
  }

  Widget _buildHeader(AppColors c) {
    return LightStatusBar(
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        child: Container(
          width: double.infinity,
          color: c.headerBg,
          child: SafeArea(
            bottom: false,
            child: LayoutBuilder(builder: (context, constraints) => Padding(
              padding: _headerPadding(constraints),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Hero(
                      tag: kSearchBarHeroTag,
                      flightShuttleBuilder: (_, _, _, _, _) => Material(
                        color: Colors.transparent,
                        child: _buildFieldShell(c, const SizedBox.shrink()),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: _buildFieldShell(
                          c,
                          TextField(
                            controller: _searchController,
                            focusNode: _focusNode,
                            style: TextStyle(fontSize: 15, color: c.textPrimary),
                            textInputAction: TextInputAction.search,
                            onSubmitted: _submitSearch,
                            cursorColor: c.accent,
                            decoration: InputDecoration(
                              isDense: true,
                              filled: false,
                              hintText: S.searchTitleAuthorIsbn,
                              hintStyle: TextStyle(color: c.textHint, fontSize: 15),
                              contentPadding: EdgeInsets.zero,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              focusedErrorBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                            ),
                          ),
                          trailing: _searchController.text.isEmpty
                              ? null
                              : GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    _searchController.clear();
                                    _focusNode.requestFocus();
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: Icon(Icons.cancel, color: c.iconInactive, size: 20),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 220),
                    opacity: _ready ? 1 : 0,
                    child: GestureDetector(
                      onTap: () => _submitSearch(_searchController.text),
                      behavior: HitTestBehavior.opaque,
                      child: Text(
                        S.actionSearch,
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldShell(AppColors c, Widget child, {Widget? trailing}) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(Icons.search, color: c.iconInactive, size: 22),
          const SizedBox(width: 10),
          Expanded(child: child),
          ?trailing,
        ],
      ),
    );
  }

  Widget _buildHistoryChip(AppColors c, String keyword) {
    if (context.isWide) return _buildWideHistoryChip(c, keyword);
    return PressableScale(
      scale: 0.94,
      onTap: () => _submitSearch(keyword),
      onLongPress: () => _removeHistory(keyword),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 9, 8, 9),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_rounded, size: 15, color: c.textHint),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: Text(
                keyword,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, color: c.textPrimary, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _removeHistory(keyword),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.close_rounded, size: 14, color: c.iconInactive),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWideHistoryChip(AppColors c, String keyword) {
    return Material(
      color: c.card,
      shape: StadiumBorder(side: BorderSide(color: c.border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _submitSearch(keyword),
        onLongPress: () => _removeHistory(keyword),
        onSecondaryTapUp: (_) => _removeHistory(keyword),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history_rounded, size: 15, color: c.textHint),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 240),
                child: Text(
                  keyword,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, color: c.textPrimary, fontWeight: FontWeight.w500),
                ),
              ),
              IconButton(
                tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(width: 30, height: 30),
                icon: Icon(Icons.close_rounded, size: 15, color: c.iconInactive),
                onPressed: () => _removeHistory(keyword),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
