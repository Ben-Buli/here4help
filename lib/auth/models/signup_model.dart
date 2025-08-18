class SignupModel {
  final String? fullName;
  final String? nickname;
  final String? gender;
  final String? email;
  final String? phone;
  final String? country;
  final String? address;
  final String? password;
  final String? dateOfBirth;
  final String? paymentPassword;
  final List<String>? selectedLanguages;
  final bool? isPermanentAddress;
  final String? school;
  final String? referralCode;
  final String? provider;
  final String? providerUserId;
  final String? avatarUrl;

  SignupModel({
    this.fullName,
    this.nickname,
    this.gender,
    this.email,
    this.phone,
    this.country,
    this.address,
    this.password,
    this.dateOfBirth,
    this.paymentPassword,
    this.selectedLanguages,
    this.isPermanentAddress,
    this.school,
    this.referralCode,
    this.provider,
    this.providerUserId,
    this.avatarUrl,
  });

  // 從 Map 創建實例
  factory SignupModel.fromMap(Map<String, dynamic> map) {
    return SignupModel(
      fullName: map['full_name'],
      nickname: map['nickname'],
      gender: map['gender'],
      email: map['email'],
      phone: map['phone'],
      country: map['country'],
      address: map['address'],
      password: map['password'],
      dateOfBirth: map['date_of_birth'],
      paymentPassword: map['payment_password'],
      selectedLanguages: map['selected_languages'] != null
          ? List<String>.from(map['selected_languages'])
          : null,
      isPermanentAddress: map['is_permanent_address'],
      school: map['school'],
      referralCode: map['referral_code'],
      provider: map['provider'],
      providerUserId: map['provider_user_id'],
      avatarUrl: map['avatar_url'],
    );
  }

  // 轉換為 Map（用於 API 請求）
  Map<String, dynamic> toMap() {
    return {
      'full_name': fullName,
      'nickname': nickname,
      'gender': gender,
      'email': email,
      'phone': phone,
      'country': country,
      'address': address,
      'password': password,
      'date_of_birth': dateOfBirth,
      'payment_password': paymentPassword,
      'selected_languages': selectedLanguages?.join(','),
      'is_permanent_address': isPermanentAddress,
      'school': school,
      'referral_code': referralCode,
      'provider': provider,
      'provider_user_id': providerUserId,
      'avatar_url': avatarUrl,
    };
  }

  // 複製並更新部分欄位
  SignupModel copyWith({
    String? fullName,
    String? nickname,
    String? gender,
    String? email,
    String? phone,
    String? country,
    String? address,
    String? password,
    String? dateOfBirth,
    String? paymentPassword,
    List<String>? selectedLanguages,
    bool? isPermanentAddress,
    String? school,
    String? referralCode,
    String? provider,
    String? providerUserId,
    String? avatarUrl,
  }) {
    return SignupModel(
      fullName: fullName ?? this.fullName,
      nickname: nickname ?? this.nickname,
      gender: gender ?? this.gender,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      country: country ?? this.country,
      address: address ?? this.address,
      password: password ?? this.password,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      paymentPassword: paymentPassword ?? this.paymentPassword,
      selectedLanguages: selectedLanguages ?? this.selectedLanguages,
      isPermanentAddress: isPermanentAddress ?? this.isPermanentAddress,
      school: school ?? this.school,
      referralCode: referralCode ?? this.referralCode,
      provider: provider ?? this.provider,
      providerUserId: providerUserId ?? this.providerUserId,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  // 檢查是否為第三方登入
  bool get isThirdPartyLogin => provider != null && providerUserId != null;

  // 檢查必要欄位是否完整
  bool get isComplete {
    return fullName != null &&
        fullName!.isNotEmpty &&
        email != null &&
        email!.isNotEmpty &&
        password != null &&
        password!.isNotEmpty;
  }

  // 檢查第三方登入必要欄位
  bool get isThirdPartyComplete {
    return provider != null &&
        providerUserId != null &&
        email != null &&
        email!.isNotEmpty;
  }

  @override
  String toString() {
    return 'SignupModel('
        'fullName: $fullName, '
        'nickname: $nickname, '
        'gender: $gender, '
        'email: $email, '
        'phone: $phone, '
        'country: $country, '
        'address: $address, '
        'password: ${password != null ? '***' : null}, '
        'dateOfBirth: $dateOfBirth, '
        'paymentPassword: ${paymentPassword != null ? '***' : null}, '
        'selectedLanguages: $selectedLanguages, '
        'isPermanentAddress: $isPermanentAddress, '
        'school: $school, '
        'referralCode: $referralCode, '
        'provider: $provider, '
        'providerUserId: $providerUserId, '
        'avatarUrl: $avatarUrl)';
  }
}

