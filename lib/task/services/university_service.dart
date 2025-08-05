import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:here4help/config/app_config.dart';

class UniversityService {
  static String get _baseUrl => AppConfig.apiBaseUrl;

  /// 獲取大學列表
  static Future<List<Map<String, dynamic>>> getUniversities() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/universities/list.php'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['data']);
        } else {
          throw Exception(data['message'] ?? 'Failed to load universities');
        }
      } else {
        throw Exception(
            'HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      throw Exception('Failed to load universities: $e');
    }
  }

  /// 根據縮寫獲取大學資訊
  static Future<Map<String, dynamic>?> getUniversityByAbbr(String abbr) async {
    try {
      final universities = await getUniversities();
      return universities.firstWhere(
        (uni) => uni['abbr'] == abbr,
        orElse: () => <String, dynamic>{},
      );
    } catch (e) {
      return null;
    }
  }

  /// 根據縮寫獲取大學中文名稱
  static Future<String> getUniversityNameByAbbr(String abbr) async {
    try {
      final university = await getUniversityByAbbr(abbr);
      return university?['zh_name'] ?? abbr;
    } catch (e) {
      return abbr;
    }
  }
}
