import 'package:flutter/material.dart';
import '../screens/search_screen.dart';
import '../utils/app_colors.dart';

class SearchBarWidget extends StatelessWidget {
  final String currentKeyword;
  final Function(String) onSearch;

  const SearchBarWidget({super.key, required this.currentKeyword, required this.onSearch});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(context, PageRouteBuilder(
          pageBuilder: (_, __, ___) => SearchScreen(initialKeyword: currentKeyword),
          transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
        ));
        if (result != null) onSearch(result as String);
      },
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Icon(Icons.search, color: c.iconInactive, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              currentKeyword.isEmpty ? '搜尋書名、作者、ISBN...' : currentKeyword,
              style: TextStyle(color: currentKeyword.isEmpty ? c.textHint : c.textPrimary, fontSize: 15),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
          ),
          if (currentKeyword.isNotEmpty)
            GestureDetector(onTap: () => onSearch(''), child: Icon(Icons.cancel, color: c.iconInactive, size: 20)),
        ]),
      ),
    );
  }
}