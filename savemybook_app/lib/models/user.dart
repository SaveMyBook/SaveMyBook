class User {
  final int userId;
  final String email;
  final String nickname;
  final String role;

  User({
    required this.userId,
    required this.email,
    required this.nickname,
    required this.role,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['user_id'] as int? ?? 0,
      email: json['email'] as String? ?? '',
      nickname: json['nickname'] as String? ?? '使用者',
      role: json['role'] as String? ?? 'buyer_seller',
    );
  }
}