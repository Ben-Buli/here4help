import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:here4help/config/app_config.dart';

class UniversityService {
  static String get _baseUrl => AppConfig.apiBaseUrl;
  static const String _cacheKey = 'universities_cache';
  static const String _cacheTimestampKey = 'universities_cache_timestamp';
  static const Duration _cacheDuration = Duration(hours: 24);

  /// 獲取大學列表 - 支援本地緩存
  static Future<List<Map<String, dynamic>>> getUniversities() async {
    try {
      // 首先嘗試從緩存讀取
      final cachedData = await _getCachedUniversities();
      if (cachedData.isNotEmpty) {
        return cachedData;
      }

      // 如果緩存不存在或已過期，從API獲取
      final response = await http.get(
        Uri.parse('$_baseUrl/backend/api/universities/list.php'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final universities = List<Map<String, dynamic>>.from(data['data']);

          // 保存到緩存
          await _cacheUniversities(universities);

          return universities;
        } else {
          throw Exception(data['message'] ?? 'Failed to load universities');
        }
      } else {
        throw Exception(
            'HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      // 如果API調用失敗，返回默認數據
      return _getDefaultUniversities();
    }
  }

  /// 從緩存獲取大學數據
  static Future<List<Map<String, dynamic>>> _getCachedUniversities() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_cacheTimestampKey);
      final cachedData = prefs.getString(_cacheKey);

      if (timestamp != null && cachedData != null) {
        final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        final now = DateTime.now();

        // 檢查緩存是否仍然有效
        if (now.difference(cacheTime) < _cacheDuration) {
          final universities = List<Map<String, dynamic>>.from(
            json.decode(cachedData),
          );
          return universities;
        }
      }
    } catch (e) {
      // 緩存讀取失敗，返回空列表
    }
    return [];
  }

  /// 緩存大學數據
  static Future<void> _cacheUniversities(
      List<Map<String, dynamic>> universities) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, json.encode(universities));
      await prefs.setInt(
          _cacheTimestampKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      // 緩存保存失敗，但不影響主要功能
    }
  }

  /// 獲取默認大學數據
  static List<Map<String, dynamic>> _getDefaultUniversities() {
    return [
      {
        'abbr': 'NTU',
        'zh_name': '國立台灣大學',
        'en_name': 'National Taiwan University'
      },
      {
        'abbr': 'NCCU',
        'zh_name': '國立政治大學',
        'en_name': 'National Chengchi University'
      },
      {
        'abbr': 'NTHU',
        'zh_name': '國立清華大學',
        'en_name': 'National Tsing Hua University'
      },
      {
        'abbr': 'NCKU',
        'zh_name': '國立成功大學',
        'en_name': 'National Cheng Kung University'
      },
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
