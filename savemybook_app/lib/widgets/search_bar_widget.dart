import 'package:flutter/material.dart';
import '../screens/search_screen.dart';
import '../utils/app_colors.dart';
import '../i18n/strings.dart';

class SearchBarWidget extends StatelessWidget {
  final String currentKeyword;
  final Function(String) onSearch;

  const SearchBarWidget({super.key, required this.currentKeyword, required this.onSearch});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return GestureDetector(
      onTap: () async {
        // 用 MaterialPageRoute 才會有左滑返回；Hero 在任何 route 都能運作。
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SearchScreen(initialKeyword: currentKeyword)),
        );
        if (result != null) onSearch(result as String);
      },
      // 跟搜尋頁的輸入框共用 Hero，兩邊的外框尺寸一致，轉場就是平滑地飛過去。
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
