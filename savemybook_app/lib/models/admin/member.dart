import '../../utils/api_helpers.dart';
import '../../utils/app_labels.dart';
import 'level.dart';

class AdminMember {
  final int userId;
  final String email;
  final String nickname;
  final String? avatarUrl;
  final String phone;
  final String role;
  final bool isActive;
  final bool isBlacklisted;
  final DateTime? createdAt;
  final int bookCount;
  final int buyOrderCount;
  final int sellOrderCount;

  AdminMember({
    required this.userId,
    required this.email,
    required this.nickname,
    required this.role,
    required this.isActive,
    required this.isBlacklisted,
    this.avatarUrl,
    this.phone = '',
    this.createdAt,
    this.bookCount = 0,
    this.buyOrderCount = 0,
    this.sellOrderCount = 0,
  });

  String get statusText =>
      AppLabels.member(isActive: isActive, isBlacklisted: isBlacklisted);

  factory AdminMember.fromJson(Map<String, dynamic> json) {
    final counts = json['_count'] as Map<String, dynamic>?;
    return AdminMember(
      userId: parseInt(json['user_id']),
      email: json['email'] as String? ?? '',
      nickname: json['nickname'] as String? ?? '',
      avatarUrl: resolveAssetUrl(json['avatar_url']),
      phone: json['phone'] as String? ?? '',
      role: json['role'] as String? ?? 'buyer_seller',
      isActive: json['is_active'] != false,
      isBlacklisted: json['is_blacklisted'] == true,
      createdAt: parseDate(json['created_at']),
      bookCount: parseInt(counts?['books']),
      buyOrderCount: parseInt(counts?['orders_orders_buyer_idTousers']),
      sellOrderCount: parseInt(counts?['orders_orders_seller_idTousers']),
    );
  }
}

class AdminMemberDetail {
  final int userId;
  final String nickname;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final String role;
  final bool isActive;
  final bool isBlacklisted;
  final int bookCount;
  final int completedOrders;
  final int basePoints;
  final int bonusPoints;
  final int points;
  final AdminLevel? currentLevel;
  final List<AdminLevel> levels;
  final Map<String, bool> permissions;

  final Map<String, bool> grantable;
  final DateTime? createdAt;

  AdminMemberDetail({
    required this.userId,
    required this.nickname,
    required this.email,
    required this.role,
    required this.isActive,
    required this.isBlacklisted,
    required this.bookCount,
    required this.completedOrders,
    required this.basePoints,
    required this.bonusPoints,
    required this.points,
    required this.levels,
    required this.permissions,
    this.grantable = const {},
    this.phone,
    this.avatarUrl,
    this.currentLevel,
    this.createdAt,
  });

  bool get isAdmin => role == 'admin';

  factory AdminMemberDetail.fromJson(Map<String, dynamic> json) {
    Map<String, bool> flags(Object? raw) => {
          if (raw is Map)
            for (final entry in raw.entries) '${entry.key}': entry.value == true,
        };
    final perms = flags(json['permissions']);
    final grantable = flags(json['grantable']);

    return AdminMemberDetail(
      userId: parseInt(json['user_id']),
      nickname: json['nickname'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String?,
      avatarUrl: resolveAssetUrl(json['avatar_url']),
      role: json['role'] as String? ?? 'buyer_seller',
      isActive: json['is_active'] == true,
      isBlacklisted: json['is_blacklisted'] == true,
      bookCount: parseInt(json['book_count']),
      completedOrders: parseInt(json['completed_orders']),
      basePoints: parseInt(json['base_points']),
      bonusPoints: parseInt(json['bonus_points']),
      points: parseInt(json['points']),
      currentLevel: json['current_level'] == null
          ? null
          : AdminLevel.fromJson(Map<String, dynamic>.from(json['current_level'])),
      levels: ((json['levels'] as List?) ?? const [])
          .map((e) => AdminLevel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      permissions: perms,
      grantable: grantable,
      createdAt: parseDate(json['created_at']),
    );
  }
}

class PendingDeletion {
  final int userId;
  final String nickname;
  final String email;
  final String? avatarUrl;
  final DateTime? requestedAt;
  final DateTime? purgeAt;

  const PendingDeletion({
    required this.userId,
    required this.nickname,
    required this.email,
    this.avatarUrl,
    this.requestedAt,
    this.purgeAt,
  });

  int get daysLeft {
    if (purgeAt == null) return 0;
    return purgeAt!.difference(DateTime.now()).inDays.clamp(0, 3650);
  }

  factory PendingDeletion.fromJson(Map<String, dynamic> json) => PendingDeletion(
        userId: parseInt(json['user_id']),
        nickname: json['nickname'] as String? ?? '',
        email: json['email'] as String? ?? '',
        avatarUrl: resolveAssetUrl(json['avatar_url']),
        requestedAt: parseDate(json['deletion_requested_at']),
        purgeAt: parseDate(json['purge_at']),
      );
}
