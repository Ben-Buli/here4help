import 'package:shared_preferences/shared_preferences.dart';

/// Utility helpers for managing cached signup draft data in SharedPreferences.
class SignupDraftService {
  static const List<String> _basicKeys = [
    'signup_full_name',
    'signup_nickname',
    'signup_gender',
    'signup_email',
    'signup_phone',
    'signup_country',
    'signup_address',
    'signup_password',
    'signup_date_of_birth',
    'signup_payment_code',
    'signup_is_permanent_address',
    'signup_languages',
    'signup_referral_code',
  ];

  static const List<String> _oauthKeys = [
    'signup_provider',
    'signup_provider_user_id',
    'signup_avatar_url',
    'signup_oauth_token',
    'signup_oauth_token_expires_at',
  ];

  static Future<void> clear({bool includeOAuth = true}) async {
    final prefs = await SharedPreferences.getInstance();
    await clearWithPrefs(prefs, includeOAuth: includeOAuth);
  }

  static Future<void> clearWithPrefs(
    SharedPreferences prefs, {
    bool includeOAuth = true,
  }) async {
    for (final key in _basicKeys) {
      await prefs.remove(key);
    }
    if (includeOAuth) {
      for (final key in _oauthKeys) {
        await prefs.remove(key);
      }
    }
  }
}
