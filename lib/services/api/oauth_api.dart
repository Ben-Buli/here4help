import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:here4help/config/app_config.dart';

class OAuthApi {
  static Future<Map<String, dynamic>?> fetchTempUser(String token) async {
    final url =
        '${AppConfig.apiBaseUrl}/auth/oauth-temp.php?token=$token&peek=true';
    if (kDebugMode) debugPrint('🔍 [OAuthApi] GET $url');
    final resp = await http.get(Uri.parse(url), headers: {
      'Accept': 'application/json',
    });
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    if (kDebugMode) {
      debugPrint('❌ [OAuthApi] ${resp.statusCode} ${resp.body}');
    }
    return null;
  }
}
