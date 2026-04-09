import 'package:flutter/material.dart';

class Book {
  final int bookId;
  final String title;
  final double price;
  final String conditionLevel;
  final String description;
  final String imageUrl;
  final String location;
  final String categoryName;
  final String author;
  final String publisher;
  final String isbn;
  final String createdAt;

  Book({
    required this.bookId,
    required this.title,
    required this.price,
    required this.conditionLevel,
    required this.description,
    required this.imageUrl,
    required this.location,
    required this.categoryName,
    required this.author,
    required this.publisher,
    required this.isbn,
    required this.createdAt,
  });

  factory Book.fromJson(Map<String, dynamic> json) {
    double parsedPrice = 0.0;
    if (json['price'] != null) {
      parsedPrice = double.tryParse(json['price'].toString()) ?? 0.0;
    }

    String parsedCategory = '一般書籍';
    if (json['book_categories'] != null && json['book_categories']['category_name'] != null) {
      parsedCategory = json['book_categories']['category_name'];
    }

    String parsedImageUrl = 'https://images.unsplash.com/photo-1544947950-fa07a98d237f?q=80&w=400&auto=format&fit=crop';
    if (json['book_images'] != null && (json['book_images'] as List).isNotEmpty) {
      parsedImageUrl = json['book_images'][0]['image_url'] ?? parsedImageUrl;
    }

    String parsedLocation = '地點未提供';
    if (json['users'] != null && json['users']['nickname'] != null) {
      parsedLocation = '賣家：${json['users']['nickname']}';
    }

    String parsedDate = '2026/03/30';
    if (json['created_at'] != null) {
      DateTime dt = DateTime.tryParse(json['created_at']) ?? DateTime.now();
      parsedDate = '${dt.year}/${dt.month}/${dt.day}';
    }

    return Book(
      bookId: json['book_id'] as int? ?? 0,
      title: json['title'] as String? ?? '無書名',
      price: parsedPrice,
      conditionLevel: json['condition_level'] as String? ?? 'good',
      description: json['description'] as String? ?? '暫無簡介',
      imageUrl: parsedImageUrl,
      location: parsedLocation,
      categoryName: parsedCategory,
      author: json['author'] as String? ?? '未知作者',
      publisher: json['publisher'] as String? ?? '未知出版社',
      isbn: json['isbn'] as String? ?? '未提供 ISBN',
      createdAt: parsedDate,
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
      case 'like_new': return const Color(0xFF627D8D);
      case 'good': return const Color(0xFF83A982);
      case 'fair': return const Color(0xFFD4A373);
      case 'poor': return const Color(0xFFC65D5D);
      default: return const Color(0xFF8699A6);
    }
  }
}