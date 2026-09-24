import '../utils/app_labels.dart';
import '../utils/api_helpers.dart';
import '../i18n/strings.dart';

class BookImage {
  final int imageId;
  final String url;
  final String type;

  BookImage({required this.imageId, required this.url, required this.type});
}

class Book {
  final int bookId;
  final String title;
  final double price;
  final String conditionLevel;
  final String description;
  final String imageUrl;
  final List<String> imageUrls;
  final List<BookImage> images;
  final String location;
  final String categoryName;
  final String author;
  final String publisher;
  final String isbn;
  final String createdAt;

  final int sellerId;
  final String sellerName;
  final String? sellerAvatarUrl;
  final int? categoryId;
  final int? cabinetId;
  final String cabinetName;
  final String cabinetAddress;
  final String cabinetOpenHours;
  final String status;
  final String publishDate;
  final String conditionNote;
  final int viewCount;
  final double? cabinetLatitude;
  final double? cabinetLongitude;
  final DateTime? reservedUntil;
  final bool reservedForMe;
  final bool isApproved;
  final String? reviewStatus;

  Book({
    required this.bookId,
    required this.title,
    required this.price,
    required this.conditionLevel,
    required this.description,
    required this.imageUrl,
    required this.imageUrls,
    required this.location,
    this.images = const [],
    required this.categoryName,
    required this.author,
    required this.publisher,
    required this.isbn,
    required this.createdAt,
    this.sellerId = 0,
    this.sellerName = '',
    this.sellerAvatarUrl,
    this.categoryId,
    this.cabinetId,
    this.cabinetName = '',
    this.cabinetAddress = '',
    this.cabinetOpenHours = '',
    this.status = 'on_sale',
    this.publishDate = '',
    this.conditionNote = '',
    this.viewCount = 0,
    this.cabinetLatitude,
    this.cabinetLongitude,
    this.reservedUntil,
    this.reservedForMe = false,
    this.isApproved = true,
    this.reviewStatus,
  });

  factory Book.fromJson(Map<String, dynamic> json) {
    final parsedPrice = parseDouble(json['price']);

    String parsedCategory = S.general;
    if (json['book_categories'] != null && json['book_categories']['category_name'] != null) {
      parsedCategory = json['book_categories']['category_name'];
    }

    String parsedImageUrl = '';
    final List<String> parsedImageUrls = [];
    final List<BookImage> parsedImages = [];

    if (json['book_images'] != null && (json['book_images'] as List).isNotEmpty) {
      for (var img in json['book_images']) {
        final resolved = resolveAssetUrl(img is Map ? img['image_url'] : img);
        if (resolved == null) continue;
        parsedImageUrls.add(resolved);
        parsedImages.add(
          BookImage(
            imageId: img is Map ? parseInt(img['image_id']) : 0,
            url: resolved,
            type: img is Map ? (img['image_type'] as String? ?? 'other') : 'other',
          ),
        );
      }
      if (parsedImageUrls.isNotEmpty) {
        parsedImageUrl = parsedImageUrls.first;
      }
    }

    final seller = json['users'] as Map<String, dynamic>?;
    final sellerName = seller?['nickname'] as String? ?? '';

    final cabinet = json['smart_cabinets'] as Map<String, dynamic>?;

    String parsedDate = '';
    final createdAt = parseDate(json['created_at']);
    if (createdAt != null) parsedDate = formatDate(createdAt);

    return Book(
      bookId: parseInt(json['book_id']),
      title: json['title'] as String? ?? S.untitled,
      price: parsedPrice,
      conditionLevel: json['condition_level'] as String? ?? 'good',
      description: json['description'] as String? ?? S.noDescriptionYet,
      imageUrl: parsedImageUrl,
      imageUrls: parsedImageUrls,
      images: parsedImages,
      location: sellerName.isEmpty ? S.locationNotProvided : S.seller3(sellerName),
      categoryName: parsedCategory,
      author: json['author'] as String? ?? S.unknownAuthor,
      publisher: json['publisher'] as String? ?? S.unknownPublisher,
      isbn: json['isbn'] as String? ?? S.noIsbn,
      createdAt: parsedDate,
      sellerId: parseInt(json['seller_id'] ?? seller?['user_id']),
      sellerName: sellerName,
      sellerAvatarUrl: resolveAssetUrl(seller?['avatar_url']),
      categoryId: json['category_id'] == null ? null : parseInt(json['category_id']),
      cabinetId: json['cabinet_id'] == null ? null : parseInt(json['cabinet_id']),
      cabinetName: cabinet?['cabinet_name'] as String? ?? '',
      cabinetAddress: cabinet?['address'] as String? ?? '',
      cabinetOpenHours: formatTimeRange(cabinet?['open_time'], cabinet?['close_time']),
      status: json['status'] as String? ?? 'on_sale',
      publishDate: json['publish_date'] as String? ?? '',
      conditionNote: json['condition_note'] as String? ?? '',
      viewCount: parseInt(json['view_count']),
      cabinetLatitude: cabinet?['latitude'] == null ? null : parseDouble(cabinet!['latitude']),
      cabinetLongitude: cabinet?['longitude'] == null ? null : parseDouble(cabinet!['longitude']),
      reservedUntil: json['reservation'] is Map ? parseDate(json['reservation']['reserved_until'])?.toLocal() : null,
      reservedForMe: json['reservation'] is Map && json['reservation']['reserved_for_me'] == true,
      isApproved: json['is_approved'] != false,
      reviewStatus: json['review_status'] == 'pending' || json['review_status'] == 'rejected'
          ? json['review_status'] as String
          : null,
    );
  }

  String get conditionText => AppLabels.conditionOf(conditionLevel);

  bool get hasImage => imageUrl.isNotEmpty;

  bool get isReservedByOthers => reservedUntil != null && !reservedForMe && reservedUntil!.isAfter(DateTime.now());

  String get statusText => AppLabels.book(status);

  /// 賣家本人或後台查看時的狀態代碼；預約保留中的書另以 held 表示。
  String get ownerStatus => status == 'on_sale' && isHeld ? 'held' : status;

  String get ownerStatusText => AppLabels.ownerBook(ownerStatus);

  bool get isHeld => reservedUntil != null && reservedUntil!.isAfter(DateTime.now());

  bool get isPendingReview => reviewStatus == 'pending';

  bool get isReviewRejected => reviewStatus == 'rejected';

  String get sellerStatusText {
    if (isPendingReview) return S.reportReviewing;
    if (isReviewRejected) return S.notApproved;
    return ownerStatusText;
  }
}
