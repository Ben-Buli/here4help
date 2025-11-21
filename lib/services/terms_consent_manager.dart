import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:here4help/services/terms_service.dart';
import 'package:here4help/auth/services/auth_service.dart';
import 'package:here4help/widgets/terms_consent_dialog.dart';
import 'package:here4help/utils/platform_info_helper.dart';
import 'package:here4help/account/pages/terms_of_use_page.dart';

class TermsConsentManager {
  static const _ttl = Duration(hours: 24);
  static bool _isDialogOpen = false;
  static Future<bool>? _ongoingCheck;

  static String _lastCheckKey(int userId) => 'terms_last_check_ts_$userId';
  static String _lastVersionKey(int userId) => 'terms_last_version_$userId';

  static Future<bool> ensureAccepted(BuildContext context,
      {bool force = false}) async {
    final userData = await AuthService.getUserData();
    if (userData == null) {
      return true;
    }
    final userId = userData['id'];
    if (userId is! int) {
      return true;
    }

    if (_ongoingCheck != null) {
      return _ongoingCheck!;
    }

    final completer = Completer<bool>();
    _ongoingCheck = completer.future;

    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;
      final lastCheck = prefs.getInt(_lastCheckKey(userId));
      if (!force &&
          lastCheck != null &&
          now - lastCheck < _ttl.inMilliseconds) {
        completer.complete(true);
        _ongoingCheck = null;
        return completer.future;
      }

      final status = await TermsService.fetchStatus();
      final terms = status.terms;
      if (!status.requiresAcceptance || terms == null) {
        await _recordCheck(prefs, userId, terms?.id);
        completer.complete(true);
        _ongoingCheck = null;
        return completer.future;
      }

      if (!context.mounted) {
        completer.complete(false);
        _ongoingCheck = null;
        return completer.future;
      }

      if (_isDialogOpen) {
        completer.complete(false);
        _ongoingCheck = null;
        return completer.future;
      }

      _isDialogOpen = true;
      final platform = PlatformInfoHelper.detectPlatform();
      final deviceInfo = await PlatformInfoHelper.buildDeviceDescription();
      final userAgent = await PlatformInfoHelper.userAgent();

      final result = await TermsConsentDialog.show(
        context,
        terms: terms,
        onAccept: () async {
          await TermsService.acceptTerms(
            versionId: terms.id,
            platform: platform,
            deviceInfo: deviceInfo,
            userAgent: userAgent,
          );
        },
        onViewFullTerms: () {
          if (context.mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const TermsOfUsePage(),
                fullscreenDialog: true,
              ),
            );
          }
        },
      );

      _isDialogOpen = false;

      if (result == true) {
        await _recordAcceptance(prefs, userId, terms.id);
        completer.complete(true);
      } else {
        await _handleRejection(
          context,
          platform: platform,
          deviceInfo: deviceInfo,
        );
        completer.complete(false);
      }
    } catch (e) {
      debugPrint('⚠️ [Terms] ensureAccepted failed: $e');
      completer.complete(true);
    } finally {
      _ongoingCheck = null;
      _isDialogOpen = false;
    }

    return completer.future;
  }

  static Future<void> _recordCheck(
      SharedPreferences prefs, int userId, int? versionId) async {
    await prefs.setInt(_lastCheckKey(userId),
        DateTime.now().millisecondsSinceEpoch);
    if (versionId != null) {
      await prefs.setInt(_lastVersionKey(userId), versionId);
    }
  }

  static Future<void> _recordAcceptance(
      SharedPreferences prefs, int userId, int versionId) async {
    await prefs.setInt(_lastVersionKey(userId), versionId);
    await prefs.setInt(_lastCheckKey(userId),
        DateTime.now().millisecondsSinceEpoch);
  }

  static Future<void> _handleRejection(
    BuildContext context, {
    String? platform,
    String? deviceInfo,
  }) async {
    try {
      await TermsService.rejectTerms(
        platform: platform,
        deviceInfo: deviceInfo,
      );
    } catch (e) {
      debugPrint('⚠️ [Terms] reject call failed: $e');
    }

    await AuthService.logout();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_email');
    await prefs.remove('user_json');
    await prefs.remove('remember_email');
    await prefs.remove('remember_password');
    await prefs.remove('remember_me');

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('You must agree to the Terms of Use to continue.'),
      ),
    );
    context.go('/login');
  }
}
