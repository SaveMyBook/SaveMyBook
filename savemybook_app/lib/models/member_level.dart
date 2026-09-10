import '../utils/api_helpers.dart';

class MemberLevel {
  final int levelId;
  final String levelName;
  final int minPoints;
  final int? maxPoints;
  final String benefits;

  MemberLevel({
    required this.levelId,
    required this.levelName,
    required this.minPoints,
    required this.benefits,
    this.maxPoints,
  });

  factory MemberLevel.fromJson(Map<String, dynamic> json) {
    return MemberLevel(
      levelId: parseInt(json['level_id']),
      levelName: json['level_name'] as String? ?? '',
      minPoints: parseInt(json['min_points']),
      maxPoints: json['max_points'] == null ? null : parseInt(json['max_points']),
      benefits: json['benefits'] as String? ?? '',
    );
  }
}

class MemberLevelInfo {
  final int points;
  final int completedOrders;
  final MemberLevel? currentLevel;
  final MemberLevel? nextLevel;
  final int pointsToNext;
  final List<MemberLevel> levels;

  MemberLevelInfo({
    required this.points,
    required this.completedOrders,
    required this.pointsToNext,
    required this.levels,
    this.currentLevel,
    this.nextLevel,
  });

  factory MemberLevelInfo.fromJson(Map<String, dynamic> json) {
    return MemberLevelInfo(
      points: parseInt(json['points']),
      completedOrders: parseInt(json['completed_orders']),
      currentLevel: json['current_level'] == null
          ? null
          : MemberLevel.fromJson(Map<String, dynamic>.from(json['current_level'])),
      nextLevel: json['next_level'] == null
          ? null
          : MemberLevel.fromJson(Map<String, dynamic>.from(json['next_level'])),
      pointsToNext: parseInt(json['points_to_next']),
      levels: ((json['levels'] as List?) ?? const [])
          .map((e) => MemberLevel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  static MemberLevelInfo get empty =>
      MemberLevelInfo(points: 0, completedOrders: 0, pointsToNext: 0, levels: const []);
}

class UserStats {
  final double balance;
  final int bookCount;
  final int favoriteCount;
  final int unreadNotificationCount;
  final int cartCount;

  UserStats({
    required this.balance,
    required this.bookCount,
    required this.favoriteCount,
    required this.unreadNotificationCount,
    required this.cartCount,
  });

  factory UserStats.fromJson(Map<String, dynamic> json) {
    return UserStats(
      balance: parseDouble(json['balance']),
      bookCount: parseInt(json['book_count']),
      favoriteCount: parseInt(json['favorite_count']),
      unreadNotificationCount: parseInt(json['unread_notification_count']),
      cartCount: parseInt(json['cart_count']),
    );
  }

  static UserStats get empty =>
      UserStats(balance: 0, bookCount: 0, favoriteCount: 0, unreadNotificationCount: 0, cartCount: 0);
}
