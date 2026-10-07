import 'package:flutter/material.dart';
import '../features/home/search_screen.dart';
import '../utils/app_colors.dart';
import '../i18n/strings.dart';
import 'responsive.dart';

class SearchBarWidget extends StatelessWidget {
  final String currentKeyword;
  final Function(String) onSearch;

  const SearchBarWidget({super.key, required this.currentKeyword, required this.onSearch});

  Future<void> _open(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SearchScreen(initialKeyword: currentKeyword)),
    );
    if (result != null) onSearch(result as String);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    if (context.isWide) return _buildToolbarField(context, c);

    return GestureDetector(
      onTap: () => _open(context),
      child: Hero(
        tag: kSearchBarHeroTag,
        flightShuttleBuilder: (_, _, _, _, _) => Material(
          color: Colors.transparent,
          child: _shell(c, const SizedBox.shrink()),
        ),
        child: Material(
          color: Colors.transparent,
          child: _shell(
            c,
            Row(
              children: [
                Expanded(
                  child: Text(
                    currentKeyword.isEmpty ? S.searchTitleAuthorIsbn : currentKeyword,
                    style: TextStyle(
                      color: currentKeyword.isEmpty ? c.textHint : c.textPrimary,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (currentKeyword.isNotEmpty)
                  GestureDetector(
                    onTap: () => onSearch(''),
                    child: Icon(Icons.cancel, color: c.iconInactive, size: 20),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolbarField(BuildContext context, AppColors c) {
    return Semantics(
      button: true,
      label: S.actionSearch,
      child: Hero(
        tag: kSearchBarHeroTag,
        flightShuttleBuilder: (_, _, _, _, _) => Material(
          color: Colors.transparent,
          child: SearchFieldFrame(child: const SizedBox.shrink()),
        ),
        child: SearchFieldFrame(
          onTap: () => _open(context),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  currentKeyword.isEmpty ? S.searchTitleAuthorIsbn : currentKeyword,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: currentKeyword.isEmpty ? c.textHint : c.textPrimary, fontSize: 14),
                ),
              ),
              if (currentKeyword.isNotEmpty)
                IconButton(
                  tooltip: MaterialLocalizations.of(context).clearButtonTooltip,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                  icon: Icon(Icons.cancel, color: c.iconInactive, size: 18),
                  onPressed: () => onSearch(''),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _shell(AppColors c, Widget child) {
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
}

// 首頁與搜尋頁的搜尋框外框必須一致，兩頁之間以 Hero 銜接
class SearchFieldFrame extends StatelessWidget {
  static const double height = 38;

  final Widget child;
  final VoidCallback? onTap;

  const SearchFieldFrame({super.key, required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final radius = BorderRadius.circular(10);
    return Material(
      color: c.card,
      shape: RoundedRectangleBorder(borderRadius: radius, side: BorderSide(color: c.border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: height,
          child: Row(
            children: [
              const SizedBox(width: 10),
              Icon(Icons.search_rounded, size: 20, color: c.textHint),
              const SizedBox(width: 8),
              Expanded(child: child),
              const SizedBox(width: 6),
            ],
          ),
        ),
      ),
    );
  }
}
