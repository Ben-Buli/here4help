import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:here4help/config/app_config.dart';

class LanguageService {
  static String get _baseUrl => AppConfig.apiBaseUrl;
  static const String _cacheKey = 'languages_cache';
  static const String _cacheTimestampKey = 'languages_cache_timestamp';
  static const Duration _cacheDuration = Duration(hours: 24);

  /// 獲取語言列表 - 支援本地緩存
  static Future<List<Map<String, dynamic>>> getLanguages() async {
    try {
      // 首先嘗試從緩存讀取
      final cachedData = await _getCachedLanguages();
      if (cachedData.isNotEmpty) {
        return cachedData;
      }

      // 如果緩存不存在或已過期，從API獲取
      final response = await http.get(
        Uri.parse('$_baseUrl/backend/api/languages/list.php'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final languages = List<Map<String, dynamic>>.from(data['data']);

          // 保存到緩存
          await _cacheLanguages(languages);

          return languages;
        } else {
          throw Exception(data['message'] ?? 'Failed to load languages');
        }
      } else {
        throw Exception(
            'HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      // 如果API調用失敗，返回默認數據
      return _getDefaultLanguages();
    }
  }

  /// 從緩存獲取語言數據
  static Future<List<Map<String, dynamic>>> _getCachedLanguages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_cacheTimestampKey);
      final cachedData = prefs.getString(_cacheKey);

      if (timestamp != null && cachedData != null) {
        final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        final now = DateTime.now();

        // 檢查緩存是否仍然有效
        if (now.difference(cacheTime) < _cacheDuration) {
          final languages = List<Map<String, dynamic>>.from(
            json.decode(cachedData),
          );
          return languages;
        }
      }
    } catch (e) {
      // 緩存讀取失敗，返回空列表
    }
    return [];
  }

  /// 緩存語言數據
  static Future<void> _cacheLanguages(
      List<Map<String, dynamic>> languages) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, json.encode(languages));
      await prefs.setInt(
          _cacheTimestampKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      // 緩存保存失敗，但不影響主要功能
    }
  }

  /// 獲取默認語言數據
  static List<Map<String, dynamic>> _getDefaultLanguages() {
    return [
      {'code': 'en', 'name': 'English', 'native': 'English'},
      {'code': 'zh', 'name': 'Chinese', 'native': '中文'},
      {'code': 'ja', 'name': 'Japanese', 'native': '日本語'},
      {'code': 'ko', 'name': 'Korean', 'native': '한국어'},
    ];
  }

  /// 清除緩存
  static Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_cacheTimestampKey);
    } catch (e) {
      // 清除緩存失敗，但不影響主要功能
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
