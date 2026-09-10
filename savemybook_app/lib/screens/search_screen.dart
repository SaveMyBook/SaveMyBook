import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../widgets/animations.dart';
import '../widgets/app_header.dart';
import '../widgets/state_views.dart';

/// 首頁搜尋框與這裡的搜尋框共用的 Hero tag，讓兩邊接得起來、不會跳一下。
const String kSearchBarHeroTag = 'home_search_bar';

class SearchScreen extends StatefulWidget {
  final String initialKeyword;
  const SearchScreen({super.key, this.initialKeyword = ''});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _searchController =
      TextEditingController(text: widget.initialKeyword);
  final FocusNode _focusNode = FocusNode();

  bool _ready = false;
  Animation<double>? _routeAnimation;

  @override
  void initState() {
    super.initState();
    // 等轉場動畫跑完再叫鍵盤。太早叫鍵盤會在動畫途中多觸發一次 relayout，
    // 畫面就會很明顯地抖一下。
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

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_onStatus);
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submitSearch(String keyword) {
    final trimmed = keyword.trim();
    if (trimmed.isNotEmpty) ApiService.addSearchHistory(trimmed);
    Navigator.pop(context, trimmed);
  }

  void _removeHistory(String keyword) => setState(() => ApiService.removeSearchHistory(keyword));

  void _clearHistory() {
    setState(() => ApiService.searchHistory.clear());
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final history = ApiService.searchHistory;

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          _buildHeader(c),
          Expanded(
            child: history.isEmpty
                ? const EmptyView(
                    icon: Icons.manage_search_rounded,
                    message: '還沒有搜尋紀錄\n輸入書名、作者或 ISBN 開始找書',
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    children: [
                      Row(
                        children: [
                          Text(
                            '最近搜尋',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: c.textSecondary,
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: _clearHistory,
                            behavior: HitTestBehavior.opaque,
                            child: Text(
                              '清除全部',
                              style: TextStyle(fontSize: 12, color: c.textHint),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (var i = 0; i < history.length; i++)
                            FadeSlideIn(
                              index: i,
                              offsetY: 8,
                              stagger: const Duration(milliseconds: 28),
                              child: _buildChip(c, history[i]),
                            ),
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
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
            child: Padding(
              // 高度刻意跟首頁 header 的搜尋列對齊，轉場才不會位移。
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 20),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Hero(
                      tag: kSearchBarHeroTag,
                      // Hero 飛行途中用 Material 包住，避免文字出現無父層 Material 的錯誤。
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
                              hintText: '搜尋書名、作者、ISBN...',
                              hintStyle: TextStyle(color: c.textHint, fontSize: 15),
                              contentPadding: EdgeInsets.zero,
                              // 四種狀態都要明確關掉，只設 border 的話
                              // 主題的 focusedBorder 還是會在聚焦時畫出一圈框。
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              focusedErrorBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
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
                      child: const Text(
                        '搜尋',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldShell(AppColors c, Widget child) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(Icons.search, color: c.iconInactive, size: 22),
          const SizedBox(width: 10),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildChip(AppColors c, String keyword) {
    return PressableScale(
      scale: 0.94,
      onTap: () => _submitSearch(keyword),
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
}
