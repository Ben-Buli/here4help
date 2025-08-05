import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:here4help/config/app_config.dart';

class LanguageService {
  static String get _baseUrl => AppConfig.apiBaseUrl;

  /// 獲取語言列表
  static Future<List<Map<String, dynamic>>> getLanguages() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/languages/list.php'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['data']);
        } else {
          throw Exception(data['message'] ?? 'Failed to load languages');
        }
      } else {
        throw Exception(
            'HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      throw Exception('Failed to load languages: $e');
    }
  }

  /// 根據代碼獲取語言資訊
  static Future<Map<String, dynamic>?> getLanguageByCode(String code) async {
    try {
      final languages = await getLanguages();
      return languages.firstWhere(
        (lang) => lang['code'] == code,
        orElse: () => <String, dynamic>{},
      );
    } catch (e) {
      return null;
    }
  }

  /// 根據代碼獲取語言名稱
  static Future<String> getLanguageNameByCode(String code) async {
    try {
      final language = await getLanguageByCode(code);
      return language?['native'] ?? language?['name'] ?? code;
    } catch (e) {
      return code;
    }
  }

  /// 搜尋語言
  static Future<List<Map<String, dynamic>>> searchLanguages(
      String query) async {
    try {
      final languages = await getLanguages();
      if (query.isEmpty) return languages;

      return languages.where((lang) {
        final name = lang['name']?.toString().toLowerCase() ?? '';
        final native = lang['native']?.toString().toLowerCase() ?? '';
        final code = lang['code']?.toString().toLowerCase() ?? '';
        final searchQuery = query.toLowerCase();

        return name.contains(searchQuery) ||
            native.contains(searchQuery) ||
            code.contains(searchQuery);
      }).toList();
    } catch (e) {
      return [];
    }
  }
}
