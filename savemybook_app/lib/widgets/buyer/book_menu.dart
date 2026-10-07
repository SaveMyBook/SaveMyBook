import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../features/books/book_detail_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/orders/cart_screen.dart';
import '../../i18n/strings.dart';
import '../../models/book.dart';
import '../../services/api_service.dart';
import '../app_dialogs.dart';
import '../app_header.dart';
import '../app_side_nav.dart';
import '../state_views.dart';

Future<void> showBookMenu(
  BuildContext context,
  Book book, {
  String? heroTag,
  VoidCallback? onOpen,
  ValueChanged<Book>? onNotInterested,
}) async {
  final favorite = ApiService.favoriteBookIds.value.contains(book.bookId);
  final inCart = ApiService.cartBookIds.value.contains(book.bookId);
  final own = book.sellerId != 0 && book.sellerId == ApiService.currentUser?.userId;
  HapticFeedback.mediumImpact();
  final action = await showOptionSheet<String>(
    context,
    title: book.title,
    options: [
      SheetOption(value: 'open', label: S.viewDetails, icon: Icons.menu_book_outlined),
      SheetOption(
        value: 'favorite',
        label: favorite ? S.removeFavorite : S.addFavorite,
        icon: favorite ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
      ),
      if (!own)
        SheetOption(
          value: 'cart',
          label: inCart ? S.cart2 : S.addCart,
          icon: inCart ? Icons.shopping_cart_outlined : Icons.add_shopping_cart_rounded,
        ),
      if (onNotInterested != null && ApiService.authToken != null)
        SheetOption(value: 'dismiss', label: S.notInterested, icon: Icons.visibility_off_outlined),
    ],
  );
  if (action == null || !context.mounted) return;
  switch (action) {
    case 'open':
      onOpen?.call();
      Navigator.push(
        context,
        CupertinoPageRoute(builder: (_) => BookDetailScreen(book: book, heroTag: heroTag ?? 'book_image_${book.bookId}')),
      );
    case 'favorite':
      await _toggleFavorite(context, book);
    case 'cart':
      await _addToCart(context, book);
    case 'dismiss':
      onNotInterested?.call(book);
  }
}

Future<void> _toggleFavorite(BuildContext context, Book book) async {
  if (ApiService.authToken == null) {
    showAppSnackBar(context, S.pleaseSignFirst, isError: true);
    return;
  }
  final error = await ApiService().toggleFavorite(book.bookId);
  if (error != null && context.mounted) showAppSnackBar(context, error, isError: true);
}

Future<void> _addToCart(BuildContext context, Book book) async {
  if (ApiService.cartBookIds.value.contains(book.bookId)) {
    if (!HomeScreen.showTab(AppSideNav.cartTab)) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen()));
    }
    return;
  }
  if (ApiService.authToken == null) {
    showAppSnackBar(context, S.signAddItemsCart, isError: true);
    return;
  }
  if (book.status != 'on_sale') {
    showAppSnackBar(context, S.bookCannotPurchased(book.statusText), isError: true);
    return;
  }
  if (book.isReservedByOthers) {
    showAppSnackBar(context, S.bookReservedAnotherBuyerCanT, isError: true);
    return;
  }
  final error = await ApiService().addToCart(book.bookId);
  if (!context.mounted) return;
  if (error != null) {
    showAppSnackBar(context, error, isError: true);
    return;
  }
  CartIconButton.bump();
  showAppSnackBar(context, S.addedCart);
}
