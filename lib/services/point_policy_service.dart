import 'package:flutter/foundation.dart';
import 'package:here4help/config/app_config.dart';
import 'package:here4help/services/http_client_service.dart';

class PointPolicyDocument {
  final int? id;
  final String title;
  final Map<String, dynamic> content;
  final DateTime updatedAt;

  PointPolicyDocument({
    required this.id,
    required this.title,
    required this.content,
    required this.updatedAt,
  });

  factory PointPolicyDocument.fromJson(Map<String, dynamic> json) {
    final rawContent = json['content'];
    if (rawContent is! Map<String, dynamic>) {
      throw ArgumentError('Invalid point policy content payload');
    }

    return PointPolicyDocument(
      id: json['id'] != null ? int.tryParse(json['id'].toString()) : null,
      title: json['title']?.toString() ?? 'Point Policy',
      content: rawContent,
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class PointPolicyService {
  static Future<PointPolicyDocument> fetchActiveDocument() async {
    try {
      final response = await HttpClientService.getJson(
        AppConfig.pointPolicyUrl,
        useQueryParamToken: false,
      );

      if (response['success'] == true && response['data'] is Map<String, dynamic>) {
        return PointPolicyDocument.fromJson(
            Map<String, dynamic>.from(response['data']));
      }

      // 某些情況資料可能直接在頂層
      if (response.containsKey('content')) {
        return PointPolicyDocument.fromJson(
            Map<String, dynamic>.from(response));
      }

      throw Exception(response['message'] ?? 'Unable to load point policy');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PointPolicyService.fetchActiveDocument error: $e');
      }
      rethrow;
    }
  }
}
