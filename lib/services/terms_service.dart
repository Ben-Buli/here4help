import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:here4help/config/app_config.dart';
import 'package:here4help/services/http_client_service.dart';

class TermsContent {
  final int id;
  final String version;
  final String title;
  final String content;
  final DateTime? updatedAt;

  TermsContent({
    required this.id,
    required this.version,
    required this.title,
    required this.content,
    this.updatedAt,
  });

  factory TermsContent.fromJson(Map<String, dynamic> json) {
    return TermsContent(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse('${json['id']}') ?? 0,
      version: json['version']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }
}

class TermsAcceptance {
  final int acceptedVersionId;
  final DateTime? acceptedAt;

  TermsAcceptance({
    required this.acceptedVersionId,
    required this.acceptedAt,
  });

  factory TermsAcceptance.fromJson(Map<String, dynamic> json) {
    return TermsAcceptance(
      acceptedVersionId: json['accepted_version_id'] is int
          ? json['accepted_version_id'] as int
          : int.tryParse('${json['accepted_version_id']}') ?? 0,
      acceptedAt: json['accepted_at'] != null
          ? DateTime.tryParse(json['accepted_at'].toString())
          : null,
    );
  }
}

class TermsStatus {
  final bool requiresAcceptance;
  final TermsContent? terms;
  final TermsAcceptance? latestAcceptance;

  TermsStatus({
    required this.requiresAcceptance,
    required this.terms,
    required this.latestAcceptance,
  });
}

class TermsService {
  static Future<TermsContent?> fetchActiveTerms() async {
    final response = await http.get(Uri.parse(AppConfig.appTermsActiveUrl));
    if (response.statusCode != 200) {
      throw Exception('Failed to load terms: HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (decoded['success'] != true) {
      throw Exception(decoded['message'] ?? 'Failed to load terms');
    }

    final data = decoded['data'] as Map<String, dynamic>? ?? {};
    final termsJson = data['terms'];
    if (termsJson == null) {
      return null;
    }

    return TermsContent.fromJson(termsJson as Map<String, dynamic>);
  }

  static Future<TermsStatus> fetchStatus() async {
    final payload = await HttpClientService.getJson(
      AppConfig.appTermsStatusUrl,
      useQueryParamToken: true,
    );

    if (payload['success'] != true) {
      throw Exception(payload['message'] ?? 'Failed to fetch terms status');
    }

    final data = payload['data'] as Map<String, dynamic>? ?? {};
    final terms = data['terms'] != null
        ? TermsContent.fromJson(data['terms'] as Map<String, dynamic>)
        : null;
    final latestAcceptance = data['latest_acceptance'] != null
        ? TermsAcceptance.fromJson(
            data['latest_acceptance'] as Map<String, dynamic>)
        : null;

    return TermsStatus(
      requiresAcceptance: data['requires_acceptance'] == true,
      terms: terms,
      latestAcceptance: latestAcceptance,
    );
  }

  static Future<void> acceptTerms({
    required int versionId,
    String? platform,
    String? deviceInfo,
    String? userAgent,
  }) async {
    final payload = await HttpClientService.postJson(
      AppConfig.appTermsAcceptUrl,
      body: {
        'version_id': versionId,
        if (platform != null) 'platform': platform,
        if (deviceInfo != null) 'device_info': deviceInfo,
        if (userAgent != null) 'user_agent': userAgent,
      },
      useQueryParamToken: true,
    );

    if (payload['success'] != true) {
      throw Exception(payload['message'] ?? 'Failed to accept terms');
    }
  }
}
