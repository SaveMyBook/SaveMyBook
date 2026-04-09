class Category {
  final int categoryId;
  final String categoryName;
  final int? parentId;
  final int sortOrder;

  Category({
    required this.categoryId,
    required this.categoryName,
    this.parentId,
    required this.sortOrder,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      categoryId: json['category_id'] as int,
      categoryName: json['category_name'] as String,
      parentId: json['parent_id'] as int?,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }
}