import 'package:flutter/material.dart';
import '../models/book.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../utils/app_radius.dart';
import '../widgets/animations.dart';
import '../widgets/app_header.dart';
import '../widgets/app_tiles.dart';
import '../widgets/book_card.dart';
import '../widgets/state_views.dart';

/// 別人的賣場。從書籍卡片、訂單、聊天室的頭像或暱稱點進來。
class SellerScreen extends StatefulWidget {
  final int sellerId;
  final String sellerName;
  final String? sellerAvatarUrl;

  const SellerScreen({
    super.key,
    required this.sellerId,
    required this.sellerName,
    this.sellerAvatarUrl,
  });

  @override
  State<SellerScreen> createState() => _SellerScreenState();
}

class _SellerScreenState extends State<SellerScreen> {
  final ApiService _api = ApiService();

  List<Book> _books = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final books = await _api.fetchSellerBooks(widget.sellerId);
    if (!mounted) return;
    setState(() {
      _books = books;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isSelf = ApiService.currentUser?.userId == widget.sellerId;

    return Scaffold(
      backgroundColor: c.scaffold,
      body: Column(
        children: [
          AppHeader(title: isSelf ? '我的賣場' : '賣家', icon: Icons.storefront_outlined),
          _buildProfile(c),
          Expanded(
            child: SwitchIn(
              child: _isLoading
                  ? const LoadingView.grid()
                  : RefreshIndicator(
                      color: c.accent,
                      onRefresh: _load,
                      child: SwitchIn(
                        child: _books.isEmpty
                            ? ListView(
                                key: const ValueKey('empty'),
                                children: const [
                                  SizedBox(height: 60),
                                  EmptyView(
                                    icon: Icons.storefront_outlined,
                                    message: '這位賣家目前沒有販售中的書籍',
                                  ),
                                ],
                              )
                            : GridView.builder(
                                key: const ValueKey('items'),
                                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 0.58,
                                ),
                                itemCount: _books.length,
                                itemBuilder: (_, i) => RevealOnScroll(
                                  index: i,
                                  child: BookCard(book: _books[i]),
                                ),
                              ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfile(AppColors c) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: [
          BoxShadow(color: c.shadow.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          UserAvatar(
            imageUrl: widget.sellerAvatarUrl,
            radius: 26,
            enablePreview: true,
            previewTitle: widget.sellerName,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.sellerName.isEmpty ? '未知使用者' : widget.sellerName,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: c.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                SwitchIn(
                  child: Text(
                    _isLoading ? '載入中…' : '販售中 ${_books.length} 本',
                    key: ValueKey(_isLoading ? -1 : _books.length),
                    style: TextStyle(fontSize: 13, color: c.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
