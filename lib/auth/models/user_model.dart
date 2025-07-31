// user_model.dart
class UserModel {
  final int id;
  final String name;
  final String nickname;
  final String email;
  final String phone;
  final int points;
  final String avatar_url;
  final String status;
  final String provider;
  final String created_at;
  final String updated_at;
  final String? referral_code;
  final String? google_id;
  final String primary_language;
  final int permission_level;

  UserModel({
    required this.id,
    required this.name,
    required this.nickname,
    required this.email,
    required this.phone,
    required this.points,
    required this.avatar_url,
    required this.status,
    required this.provider,
    required this.created_at,
    required this.updated_at,
    this.referral_code,
    this.google_id,
    required this.primary_language,
    required this.permission_level,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      name: json['name'] ?? '',
      nickname: json['nickname'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      points: json['points'] ?? 0,
      avatar_url: json['avatar_url'] ?? '',
      status: json['status'] ?? 'active',
      provider: json['provider'] ?? 'email',
      created_at: json['created_at'] ?? '',
      updated_at: json['updated_at'] ?? '',
      referral_code: json['referral_code'],
      google_id: json['google_id'],
      primary_language: json['primary_language'] ?? 'English',
      permission_level: json['permission'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'nickname': nickname,
      'email': email,
      'phone': phone,
      'points': points,
      'avatar_url': avatar_url,
      'status': status,
      'provider': provider,
      'created_at': created_at,
      'updated_at': updated_at,
      'referral_code': referral_code,
      'google_id': google_id,
      'primary_language': primary_language,
      'permission': permission_level,
    };
  }
}
