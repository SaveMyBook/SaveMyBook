import '../utils/api_helpers.dart';
import '../i18n/strings.dart';

class User {
  final int userId;
  final String email;
  final String nickname;
  final String role;
  final String? avatarUrl;
  final String bio;
  final String phone;
  final DateTime? birthday;
  final String gender;

  User({
    required this.userId,
    required this.email,
    required this.nickname,
    required this.role,
    this.avatarUrl,
    this.bio = '',
    this.phone = '',
    this.birthday,
    this.gender = 'undisclosed',
  });

  bool get isAdmin => role == 'admin';

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: parseInt(json['user_id']),
      email: json['email'] as String? ?? '',
      nickname: json['nickname'] as String? ?? S.user,
      role: json['role'] as String? ?? 'buyer_seller',
      avatarUrl: resolveAssetUrl(json['avatar_url']),
      bio: json['bio'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      birthday: parseDate(json['birthday']),
      gender: json['gender'] as String? ?? 'undisclosed',
    );
  }
}
