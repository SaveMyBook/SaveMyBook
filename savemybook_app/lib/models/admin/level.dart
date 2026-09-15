import '../../utils/api_helpers.dart';

class AdminLevel {
  final int levelId;
  final String name;
  final int minPoints;
  final int? maxPoints;
  final String benefits;

  AdminLevel({
    required this.levelId,
    required this.name,
    required this.minPoints,
    required this.benefits,
    this.maxPoints,
  });

  factory AdminLevel.fromJson(Map<String, dynamic> json) {
    return AdminLevel(
      levelId: parseInt(json['level_id']),
      name: json['level_name'] as String? ?? '',
      minPoints: parseInt(json['min_points']),
      maxPoints: json['max_points'] == null ? null : parseInt(json['max_points']),
      benefits: json['benefits'] as String? ?? '',
    );
  }
}
