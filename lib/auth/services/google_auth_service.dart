import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:here4help/config/app_config.dart';

class GoogleAuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
    ],
  );

  // Google 登入並與您的後端整合
  Future<Map<String, dynamic>?> signInWithGoogle() async {
    try {
      // 觸發 Google 登入流程
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // 用戶取消登入
        return null;
      }

      // 獲取 Google 認證資訊
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // 準備用戶資料
      final userData = {
        'google_id': googleUser.id,
        'name': googleUser.displayName ?? '',
        'email': googleUser.email,
        'avatar_url': googleUser.photoUrl ?? '',
        'access_token': googleAuth.accessToken,
        'id_token': googleAuth.idToken,
        'provider': 'google',
      };

      // 發送到您的後端 API
      final response = await _sendUserDataToBackend(userData);

      if (response != null) {
        return response;
      }

      return null;
    } catch (e) {
      print('Google 登入錯誤: $e');
      return null;
    }
  }

  // 登出
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      print('登出錯誤: $e');
    }
  }

  // 檢查是否已登入
  Future<bool> isSignedIn() async {
    return await _googleSignIn.isSignedIn();
  }

  // 獲取當前用戶
  Future<GoogleSignInAccount?> getCurrentUser() async {
    return _googleSignIn.currentUser;
  }

  // 發送用戶資料到您的後端
  Future<Map<String, dynamic>?> _sendUserDataToBackend(
      Map<String, dynamic> userData) async {
    try {
      final response = await http.post(
        Uri.parse(AppConfig.googleLoginUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(userData),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('後端回應: $data');
        return data;
      } else {
        print('後端回應錯誤: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('發送資料到後端錯誤: $e');
      return null;
    }
  }
}
