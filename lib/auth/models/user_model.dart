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
  final String? date_of_birth;
  final String? gender;
  final String? country;
  final String? address;
  final String? about_me;
  final String? school;
  final String? language_requirement;
  final bool? is_permanent_address;

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
    this.date_of_birth,
    this.gender,
    this.country,
    this.address,
    this.about_me,
    this.school,
    this.language_requirement,
    this.is_permanent_address,
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
      date_of_birth: json['date_of_birth'],
      gender: json['gender'],
      country: json['country'],
      address: json['address'],
      about_me: json['about_me'],
      school: json['school'],
      language_requirement: json['language_requirement'],
      is_permanent_address: json['is_permanent_address'] == 1 ||
          json['is_permanent_address'] == '1' ||
          json['is_permanent_address'] == true,
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
      'date_of_birth': date_of_birth,
      'gender': gender,
      'country': country,
      'address': address,
      'about_me': about_me,
      'school': school,
      'language_requirement': language_requirement,
      'is_permanent_address': is_permanent_address == true ? 1 : 0,
    };
  }

  UserModel copyWith({
    int? id,
    String? name,
    String? nickname,
    String? email,
    String? phone,
    int? points,
    String? avatar_url,
    String? status,
    String? provider,
    String? created_at,
    String? updated_at,
    String? referral_code,
    String? google_id,
    String? primary_language,
    int? permission_level,
    String? date_of_birth,
    String? gender,
    String? country,
    String? address,
    String? about_me,
    String? school,
    String? language_requirement,
    bool? is_permanent_address,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      nickname: nickname ?? this.nickname,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      points: points ?? this.points,
      avatar_url: avatar_url ?? this.avatar_url,
      status: status ?? this.status,
      provider: provider ?? this.provider,
      created_at: created_at ?? this.created_at,
      updated_at: updated_at ?? this.updated_at,
      referral_code: referral_code ?? this.referral_code,
      google_id: google_id ?? this.google_id,
      primary_language: primary_language ?? this.primary_language,
      permission_level: permission_level ?? this.permission_level,
      date_of_birth: date_of_birth ?? this.date_of_birth,
      gender: gender ?? this.gender,
      country: country ?? this.country,
      address: address ?? this.address,
      about_me: about_me ?? this.about_me,
      school: school ?? this.school,
      language_requirement: language_requirement ?? this.language_requirement,
      is_permanent_address: is_permanent_address ?? this.is_permanent_address,
    );
  }
}
