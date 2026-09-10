import 'package:flutter/material.dart';
import '../utils/api_helpers.dart';

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
  });

  factory Book.fromJson(Map<String, dynamic> json) {
    final parsedPrice = parseDouble(json['price']);

    String parsedCategory = '一般書籍';
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
        parsedImages.add(BookImage(
          imageId: img is Map ? parseInt(img['image_id']) : 0,
          url: resolved,
          type: img is Map ? (img['image_type'] as String? ?? 'other') : 'other',
        ));
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
      title: json['title'] as String? ?? '無書名',
      price: parsedPrice,
      conditionLevel: json['condition_level'] as String? ?? 'good',
      description: json['description'] as String? ?? '暫無簡介',
      imageUrl: parsedImageUrl,
      imageUrls: parsedImageUrls,
      images: parsedImages,
      location: sellerName.isEmpty ? '地點未提供' : '賣家：$sellerName',
      categoryName: parsedCategory,
      author: json['author'] as String? ?? '未知作者',
      publisher: json['publisher'] as String? ?? '未知出版社',
      isbn: json['isbn'] as String? ?? '未提供 ISBN',
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
    );
  }

  String get conditionText {
    switch (conditionLevel) {
      case 'like_new': return '全新';
      case 'good': return '近全新';
      case 'fair': return '良好';
      case 'poor': return '尚可';
      default: return '未知書況';
    }
  }

  Color get conditionColor {
    switch (conditionLevel) {
      case 'like_new': return const Color(0xFF26A69A);
      case 'good':     return const Color(0xFF66BB6A);
      case 'fair':     return const Color(0xFFFFA726);
      case 'poor':     return const Color(0xFFEF5350);
      default:         return const Color(0xFF90A4AE);
    }
  }

  bool get hasImage => imageUrl.isNotEmpty;

  String get statusText {
    switch (status) {
      case 'on_sale': return '販售中';
      case 'reserved': return '已被預訂';
      case 'sold': return '已售出';
      case 'removed': return '已下架';
      default: return status;
    }
  }
}
