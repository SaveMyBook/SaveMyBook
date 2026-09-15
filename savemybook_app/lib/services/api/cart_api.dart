part of '../api_service.dart';

extension CartApi on ApiService {
  Future<List<CartItem>> fetchCart() async {
    final res = await _send('GET', '/cart');
    final items = _mapList(res, CartItem.fromJson);
    if (res != null && res['success'] == true) {
      ApiService._setCartCount(items.length);
      ApiService.cartBookIds.value = items.map((i) => i.book.bookId).toSet();
    }
    return items;
  }

  Future<void> refreshCartCount() async {
    if (ApiService.authToken == null) {
      ApiService._setCartCount(0);
      return;
    }
    final stats = await fetchUserStats();
    ApiService._setCartCount(stats.cartCount);
  }

  Future<String?> addToCart(int bookId, {int quantity = 1}) async {
    final res = await _send('POST', '/cart', body: {'book_id': bookId, 'quantity': quantity});
    if (res == null) return S.pleaseSignFirst;
    if (res['success'] != true) return res['message'] as String? ?? S.couldNotAddCart;
    if (!ApiService.cartBookIds.value.contains(bookId)) {
      ApiService.cartBookIds.value = {...ApiService.cartBookIds.value, bookId};
      if (res['already_in_cart'] != true) ApiService._setCartCount(ApiService.cartCount.value + 1);
    }
    return null;
  }

  Future<Set<int>> fetchCartBookIds() async {
    final res = await _send('GET', '/cart/book-ids');
    if (res == null || res['success'] != true || res['data'] is! List) return ApiService.cartBookIds.value;
    final ids = (res['data'] as List).map(parseInt).where((id) => id > 0).toSet();
    ApiService.cartBookIds.value = ids;
    ApiService._setCartCount(ids.length);
    return ids;
  }

  Future<bool> updateCartQuantity(int cartId, int quantity) async {
    final res = await _send('PATCH', '/cart/$cartId', body: {'quantity': quantity});
    return res != null && res['success'] == true;
  }

  Future<bool> removeCartItem(int cartId, {int? bookId}) async {
    final res = await _send('DELETE', '/cart/$cartId');
    final ok = res != null && res['success'] == true;
    if (ok) {
      ApiService._setCartCount(ApiService.cartCount.value - 1);
      if (bookId != null) ApiService.cartBookIds.value = {...ApiService.cartBookIds.value}..remove(bookId);
    }
    return ok;
  }
}
