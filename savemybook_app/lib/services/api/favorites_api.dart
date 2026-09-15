part of '../api_service.dart';

extension FavoritesApi on ApiService {
  Future<List<Book>> fetchFavorites() async {
    final res = await _send('GET', '/favorites');
    final books = _mapList(res, Book.fromJson);
    ApiService.favoriteBookIds.value = books.map((b) => b.bookId).toSet();
    return books;
  }

  Future<Set<int>> fetchFavoriteIds() async {
    final res = await _send('GET', '/favorites/ids');
    if (res == null || res['success'] != true || res['data'] is! List) return {};
    final ids = (res['data'] as List).map((e) => int.tryParse(e.toString()) ?? 0).toSet();
    ApiService.favoriteBookIds.value = ids;
    return ids;
  }

  static void _setFavorite(int bookId, bool value) {
    final next = Set<int>.from(ApiService.favoriteBookIds.value);
    value ? next.add(bookId) : next.remove(bookId);
    ApiService.favoriteBookIds.value = next;
  }

  Future<bool> addFavorite(int bookId) async {
    final res = await _send('POST', '/favorites', body: {'book_id': bookId});
    final ok = res != null && res['success'] == true;
    if (ok) _setFavorite(bookId, true);
    return ok;
  }

  Future<bool> removeFavorite(int bookId) async {
    final res = await _send('DELETE', '/favorites/$bookId');
    final ok = res != null && res['success'] == true;
    if (ok) _setFavorite(bookId, false);
    return ok;
  }

  Future<String?> toggleFavorite(int bookId) async {
    if (ApiService.authToken == null) return S.pleaseSignFirst;
    final wasFavorite = ApiService.favoriteBookIds.value.contains(bookId);
    _setFavorite(bookId, !wasFavorite);

    final ok = wasFavorite ? await removeFavorite(bookId) : await addFavorite(bookId);
    if (!ok) {
      _setFavorite(bookId, wasFavorite);
      return wasFavorite ? S.couldNotRemoveFromSaved : S.couldNotSave;
    }
    return null;
  }
}
