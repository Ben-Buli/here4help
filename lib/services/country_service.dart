import 'package:http/http.dart' as http;
import 'dart:convert';

/// 國家資料模型
class Country {
  final String name;
  final String flagUrl;
  final List<String> languages;
  final String? capital;
  final String? region;
  final String? subregion;

  Country({
    required this.name,
    required this.flagUrl,
    required this.languages,
    this.capital,
    this.region,
    this.subregion,
  });

  /// 從 JSON 創建 Country 實例
  factory Country.fromJson(Map<String, dynamic> json) {
    final languagesMap = json['languages'] as Map<String, dynamic>? ?? {};
    return Country(
      name: json['name']?['common'] ?? '',
      flagUrl: json['flags']?['png'] ?? '',
      languages: languagesMap.values.map((e) => e.toString()).toList(),
      capital: json['capital']?.isNotEmpty == true ? json['capital'][0] : null,
      region: json['region'],
      subregion: json['subregion'],
    );
  }

  /// 轉換為 Map
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'flagUrl': flagUrl,
      'languages': languages,
      'capital': capital,
      'region': region,
      'subregion': subregion,
    };
  }

  @override
  String toString() {
    return 'Country(name: $name, languages: $languages)';
  }
}

/// 國家服務類
class CountryService {
  static const String _baseUrl = 'https://restcountries.com/v3.1';

  /// 獲取所有國家列表
  static Future<List<Country>> getAllCountries() async {
    try {
      print('🌍 開始獲取國家列表...');

      final response = await http
          .get(
            Uri.parse(
                '$_baseUrl/all?fields=name,flags,languages,capital,region,subregion'),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = jsonDecode(response.body);
        final countries = jsonData
            .map((json) => Country.fromJson(json))
            .where((country) =>
                country.name.isNotEmpty && country.flagUrl.isNotEmpty)
            .toList();

        // 按國家名稱排序
        countries.sort((a, b) => a.name.compareTo(b.name));

        print('✅ 成功獲取 ${countries.length} 個國家');
        return countries;
      } else {
        print('❌ 獲取國家列表失敗: HTTP ${response.statusCode}');
        throw Exception(
            'Failed to load countries: HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('❌ 獲取國家列表錯誤: $e');
      // 返回預設國家列表作為 fallback
      return getDefaultCountries();
    }
  }

  /// 根據語言獲取國家列表
  static Future<List<Country>> getCountriesByLanguage(
      String languageCode) async {
    try {
      print('🌍 根據語言獲取國家列表: $languageCode');

      final response = await http
          .get(
            Uri.parse(
                '$_baseUrl/lang/$languageCode?fields=name,flags,languages,capital,region,subregion'),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = jsonDecode(response.body);
        final countries = jsonData
            .map((json) => Country.fromJson(json))
            .where((country) =>
                country.name.isNotEmpty && country.flagUrl.isNotEmpty)
            .toList();

        countries.sort((a, b) => a.name.compareTo(b.name));

        print('✅ 成功獲取 ${countries.length} 個使用 $languageCode 語言的國家');
        return countries;
      } else {
        print('❌ 根據語言獲取國家列表失敗: HTTP ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ 根據語言獲取國家列表錯誤: $e');
      return [];
    }
  }

  /// 搜尋國家
  static Future<List<Country>> searchCountries(String query) async {
    try {
      if (query.length < 2) return [];

      print('🔍 搜尋國家: $query');

      final response = await http
          .get(
            Uri.parse(
                '$_baseUrl/name/$query?fields=name,flags,languages,capital,region,subregion'),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = jsonDecode(response.body);
        final countries = jsonData
            .map((json) => Country.fromJson(json))
            .where((country) =>
                country.name.isNotEmpty && country.flagUrl.isNotEmpty)
            .toList();

        countries.sort((a, b) => a.name.compareTo(b.name));

        print('✅ 搜尋結果: 找到 ${countries.length} 個國家');
        return countries;
      } else {
        print('❌ 搜尋國家失敗: HTTP ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ 搜尋國家錯誤: $e');
      return [];
    }
  }

  /// 獲取預設國家列表（當 API 失敗時使用）
  static List<Country> getDefaultCountries() {
    return [
      Country(
        name: 'United States',
        flagUrl: 'https://flagcdn.com/w320/us.png',
        languages: ['English'],
        capital: 'Washington, D.C.',
        region: 'Americas',
        subregion: 'North America',
      ),
      Country(
        name: 'United Kingdom',
        flagUrl: 'https://flagcdn.com/w320/gb.png',
        languages: ['English'],
        capital: 'London',
        region: 'Europe',
        subregion: 'Northern Europe',
      ),
      Country(
        name: 'Canada',
        flagUrl: 'https://flagcdn.com/w320/ca.png',
        languages: ['English', 'French'],
        capital: 'Ottawa',
        region: 'Americas',
        subregion: 'North America',
      ),
      Country(
        name: 'Australia',
        flagUrl: 'https://flagcdn.com/w320/au.png',
        languages: ['English'],
        capital: 'Canberra',
        region: 'Oceania',
        subregion: 'Australia and New Zealand',
      ),
      Country(
        name: 'Germany',
        flagUrl: 'https://flagcdn.com/w320/de.png',
        languages: ['German'],
        capital: 'Berlin',
        region: 'Europe',
        subregion: 'Western Europe',
      ),
      Country(
        name: 'France',
        flagUrl: 'https://flagcdn.com/w320/fr.png',
        languages: ['French'],
        capital: 'Paris',
        region: 'Europe',
        subregion: 'Western Europe',
      ),
      Country(
        name: 'Japan',
        flagUrl: 'https://flagcdn.com/w320/jp.png',
        languages: ['Japanese'],
        capital: 'Tokyo',
        region: 'Asia',
        subregion: 'Eastern Asia',
      ),
      Country(
        name: 'South Korea',
        flagUrl: 'https://flagcdn.com/w320/kr.png',
        languages: ['Korean'],
        capital: 'Seoul',
        region: 'Asia',
        subregion: 'Eastern Asia',
      ),
      Country(
        name: 'China',
        flagUrl: 'https://flagcdn.com/w320/cn.png',
        languages: ['Chinese'],
        capital: 'Beijing',
        region: 'Asia',
        subregion: 'Eastern Asia',
      ),
      Country(
        name: 'Taiwan',
        flagUrl: 'https://flagcdn.com/w320/tw.png',
        languages: ['Chinese'],
        capital: 'Taipei',
        region: 'Asia',
        subregion: 'Eastern Asia',
      ),
    ];
  }

  /// 獲取常用語言代碼對應的國家
  static Map<String, List<Country>> getCommonLanguageCountries() {
    return {
      'en': getDefaultCountries()
          .where((c) => c.languages.contains('English'))
          .toList(),
      'zh': getDefaultCountries()
          .where((c) => c.languages.contains('Chinese'))
          .toList(),
      'ja': getDefaultCountries()
          .where((c) => c.languages.contains('Japanese'))
          .toList(),
      'ko': getDefaultCountries()
          .where((c) => c.languages.contains('Korean'))
          .toList(),
      'de': getDefaultCountries()
          .where((c) => c.languages.contains('German'))
          .toList(),
      'fr': getDefaultCountries()
          .where((c) => c.languages.contains('French'))
          .toList(),
    };
  }
}
