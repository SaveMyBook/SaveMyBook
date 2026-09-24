import '../../utils/api_helpers.dart';
import '../../utils/app_labels.dart';

class AdminBook {
  final int bookId;
  final String title;
  final String? isbn;
  final double price;
  final String status;
  final String conditionLevel;
  final int? categoryId;
  final String categoryName;
  final String sellerName;
  final int viewCount;
  final int pendingReportCount;
  final String? imageUrl;
  final DateTime? createdAt;

  final String? author;
  final String? publisher;
  final String? publishDate;
  final String? conditionNote;
  final String? description;

  AdminBook({
    required this.bookId,
    required this.title,
    required this.price,
    required this.status,
    required this.conditionLevel,
    required this.categoryName,
    required this.sellerName,
    required this.viewCount,
    required this.pendingReportCount,
    this.categoryId,
    this.isbn,
    this.imageUrl,
    this.createdAt,
    this.author,
    this.publisher,
    this.publishDate,
    this.conditionNote,
    this.description,
  });

  String get statusText => AppLabels.ownerBook(status);

  factory AdminBook.fromJson(Map<String, dynamic> json) {
    final seller = json['seller'] as Map<String, dynamic>?;

    return AdminBook(
      bookId: parseInt(json['book_id']),
      title: json['title'] as String? ?? '',
      isbn: json['isbn'] as String?,
      price: parseDouble(json['price']),
      status: json['status'] as String? ?? '',
      conditionLevel: json['condition_level'] as String? ?? 'good',
      categoryId: json['category_id'] == null ? null : parseInt(json['category_id']),
      categoryName: json['category_name'] as String? ?? '',
      sellerName: seller?['nickname'] as String? ?? '—',
      viewCount: parseInt(json['view_count']),
      pendingReportCount: parseInt(json['pending_report_count']),
      imageUrl: resolveAssetUrl(json['image_url']),
      createdAt: parseDate(json['created_at']),
      author: json['author'] as String?,
      publisher: json['publisher'] as String?,
      publishDate: json['publish_date'] as String?,
      conditionNote: json['condition_note'] as String?,
      description: json['description'] as String?,
    );
  }
}

class AdminCategory {
  final int categoryId;
  final String name;
  final int sortOrder;
  final int bookCount;

  AdminCategory({
    required this.categoryId,
    required this.name,
    required this.sortOrder,
    required this.bookCount,
  });

  factory AdminCategory.fromJson(Map<String, dynamic> json) {
    return AdminCategory(
      categoryId: parseInt(json['category_id']),
      name: json['category_name'] as String? ?? '',
      sortOrder: parseInt(json['sort_order']),
      bookCount: parseInt(json['book_count']),
    );
  }
}
