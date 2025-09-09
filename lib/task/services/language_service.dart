import 'package:here4help/constants/languages.dart';

class LanguageService {
  /// 獲取語言列表 - 使用硬編程資料
  static Future<List<Map<String, dynamic>>> getLanguages() async {
    // 直接返回硬編程的語言資料
    return Languages.all
        .map((lang) => Map<String, dynamic>.from(lang))
        .toList();
  }

  /// 清除緩存（保留以避免破壞現有代碼）
  static Future<void> clearCache() async {
    // 不再需要緩存，但保留方法以避免破壞現有代碼
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
