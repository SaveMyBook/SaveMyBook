import 'package:flutter/material.dart';
import '../services/api_service.dart';

class SearchScreen extends StatefulWidget {
  final String initialKeyword;

  const SearchScreen({super.key, this.initialKeyword = ''});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late TextEditingController _searchController;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialKeyword);
    Future.delayed(Duration.zero, () => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submitSearch(String keyword) {
    final trimmed = keyword.trim();
    if (trimmed.isNotEmpty) {
      ApiService.addSearchHistory(trimmed);
    }
    Navigator.pop(context, trimmed);
  }

  void _removeHistory(String keyword) {
    setState(() {
      ApiService.removeSearchHistory(keyword);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F7),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10, bottom: 12),
            decoration: const BoxDecoration(color: Color(0xFF627D8D)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _focusNode,
                        style: const TextStyle(fontSize: 14),
                        textInputAction: TextInputAction.search,
                        onSubmitted: _submitSearch,
                        decoration: InputDecoration(
                          hintText: '搜尋書名、作者、ISBN...',
                          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          suffixIcon: GestureDetector(
                            onTap: () => _submitSearch(_searchController.text),
                            child: const Icon(Icons.search, color: Colors.grey, size: 20),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () => _submitSearch(_searchController.text),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                      child: const Text('搜尋', style: TextStyle(color: Color(0xFF627D8D), fontSize: 14, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: ApiService.searchHistory.length,
              itemBuilder: (context, index) {
                final keyword = ApiService.searchHistory[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _submitSearch(keyword),
                          child: Text(keyword, style: const TextStyle(fontSize: 16, color: Color(0xFF627D8D), fontWeight: FontWeight.w600)),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _removeHistory(keyword),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFF83A982), width: 1)),
                          child: const Icon(Icons.close, size: 14, color: Color(0xFF83A982)),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}