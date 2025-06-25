// user_model.dart
class UserModel {
  final int id;
  final String name;
  final String email;
  final int points;
  final String avatar_url;
  final String primary_language;
  final int permission_level;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.points,
    required this.avatar_url,
    required this.primary_language,
    required this.permission_level,
  });
}
