import 'dart:convert';
import 'package:here4help/services/http_client_service.dart';
import 'package:here4help/auth/services/auth_service.dart';
import 'package:here4help/config/app_config.dart';
import 'package:here4help/services/media/cross_platform_image_service.dart';

class ProfileApi {
  /// 獲取個人資料
  static Future<Map<String, dynamic>> getProfile() async {
    try {
      final response = await HttpClientService.get(
        '${AppConfig.apiBaseUrl}/backend/api/account/profile.php',
        useQueryParamToken: true, // MAMP 兼容
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to get profile');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// 更新個人資料
  static Future<Map<String, dynamic>> updateProfile({
    String? name,
    String? nickname,
    String? phone,
    String? dateOfBirth,
    String? gender,
    String? country,
    String? address,
    bool? isPermanentAddress,
    String? primaryLanguage,
    String? languageRequirement,
    String? school,
    String? aboutMe,
  }) async {
    try {
      final body = <String, dynamic>{};

      // 只添加非空的欄位
      if (name != null) body['name'] = name;
      if (nickname != null) body['nickname'] = nickname;
      if (phone != null) body['phone'] = phone;
      if (dateOfBirth != null) body['date_of_birth'] = dateOfBirth;
      if (gender != null) body['gender'] = gender;
      if (country != null) body['country'] = country;
      if (address != null) body['address'] = address;
      if (isPermanentAddress != null) {
        body['is_permanent_address'] = isPermanentAddress;
      }
      if (primaryLanguage != null) body['primary_language'] = primaryLanguage;
      if (languageRequirement != null) {
        body['language_requirement'] = languageRequirement;
      }
      if (school != null) body['school'] = school;
      if (aboutMe != null) body['about_me'] = aboutMe;

      final response = await HttpClientService.put(
        '${AppConfig.apiBaseUrl}/backend/api/account/profile.php',
        body: jsonEncode(body),
        useQueryParamToken: true, // MAMP 兼容
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to update profile');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// 上傳頭像（跨平台）
  static Future<Map<String, dynamic>> uploadAvatar(ImageResult image) async {
    try {
      // 獲取 token
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      // 使用跨平台圖片服務上傳
      final imageService = CrossPlatformImageService();
      return await imageService.uploadImage(
        image: image,
        uploadUrl: '${AppConfig.apiBaseUrl}/backend/api/account/avatar.php',
        token: token,
        fieldName: 'avatar',
        additionalFields: {
          'token': token, // MAMP 兼容
        },
      );
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// 刪除頭像
  static Future<Map<String, dynamic>> deleteAvatar() async {
    try {
      final response = await HttpClientService.delete(
        '${AppConfig.apiBaseUrl}/backend/api/account/avatar.php',
        useQueryParamToken: true, // MAMP 兼容
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to delete avatar');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}
