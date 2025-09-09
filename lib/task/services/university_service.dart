import 'package:here4help/constants/universities.dart';

class UniversityService {
  /// 獲取大學列表 - 使用硬編程資料
  static Future<List<Map<String, dynamic>>> getUniversities() async {
    // 直接返回硬編程的大學資料
    return Universities.all
        .map((uni) => Map<String, dynamic>.from(uni))
        .toList();
  }

  /// 清除緩存（保留以避免破壞現有代碼）
  static Future<void> clearCache() async {
    // 不再需要緩存，但保留方法以避免破壞現有代碼
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
