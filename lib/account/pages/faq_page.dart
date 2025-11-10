import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:here4help/constants/app_colors.dart';
import 'package:here4help/services/http_client_service.dart';
import 'package:here4help/config/app_config.dart';

class FAQPage extends StatefulWidget {
  const FAQPage({super.key});

  @override
  State<FAQPage> createState() => _FAQPageState();
}

class _FAQPageState extends State<FAQPage> {
  List<Map<String, dynamic>> _faqs = [];
  bool _isLoading = true;
  String? _error;
  String? _errorCode;
  String? _traceId;
  int? _statusCode;

  @override
  void initState() {
    super.initState();
    _loadFAQs();
  }

  Future<void> _loadFAQs() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _errorCode = null;
      _traceId = null;
      _statusCode = null;
    });

    try {
      // 修正 API 路徑：apiPrefix 已經包含 /backend/api，所以只需要 /faqs/list.php
      final url = AppConfig.api('/faqs/list.php?language=en&is_active=1');

      // 記錄請求資訊
      developer.log(
        'Loading FAQs from: $url',
        name: 'FAQPage',
        level: 800,
      );

      final response = await HttpClientService.get(
        url,
        useQueryParamToken: false, // FAQ 不需要驗證
      );

      // 記錄回應狀態
      developer.log(
        'Response status: ${response.statusCode}',
        name: 'FAQPage',
        level: 800,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // 記錄回應資料結構
        developer.log(
          'Response data: ${data.keys.toList()}',
          name: 'FAQPage',
          level: 800,
        );

        if (data['success'] == true) {
          final faqList = data['data']['faqs'] ?? [];

          developer.log(
            'Loaded ${faqList.length} FAQs',
            name: 'FAQPage',
            level: 800,
          );

          setState(() {
            // API 返回的資料結構：{ success: true, data: { faqs: [...], categories: [...], pagination: {...} } }
            _faqs = List<Map<String, dynamic>>.from(faqList);
            _isLoading = false;
          });
        } else {
          final errorMsg = data['message'] ?? 'Failed to load FAQs';
          final errorCode = data['code'] ?? 'UNKNOWN';
          final traceId = data['traceId'];

          developer.log(
            'API returned error: $errorMsg (code: $errorCode, traceId: $traceId)',
            name: 'FAQPage',
            level: 1000,
            error: errorMsg,
          );

          throw _createApiException(
            message: errorMsg,
            code: errorCode,
            traceId: traceId,
            statusCode: response.statusCode,
          );
        }
      } else {
        // 處理非 200 狀態碼
        String errorMsg = 'Server error';
        String? errorCode;
        String? traceId;

        try {
          final data = jsonDecode(response.body);
          errorMsg = data['message'] ?? 'HTTP ${response.statusCode}';
          errorCode = data['code'];
          traceId = data['traceId'];
        } catch (e) {
          // 無法解析錯誤回應，使用原始回應
          final errorBody = response.body.length > 200
              ? '${response.body.substring(0, 200)}...'
              : response.body;
          errorMsg = 'HTTP ${response.statusCode}: $errorBody';
        }

        developer.log(
          'HTTP error: $errorMsg (code: $errorCode, traceId: $traceId)',
          name: 'FAQPage',
          level: 1000,
          error: errorMsg,
        );

        throw _createApiException(
          message: errorMsg,
          code: errorCode,
          traceId: traceId,
          statusCode: response.statusCode,
        );
      }
    } catch (e, stackTrace) {
      developer.log(
        'Failed to load FAQs',
        name: 'FAQPage',
        level: 1000,
        error: e,
        stackTrace: stackTrace,
      );

      setState(() {
        if (e is _ApiException) {
          _error = e.message;
          _errorCode = e.code;
          _traceId = e.traceId;
          _statusCode = e.statusCode;
        } else {
          _error = e.toString();
        }
        _isLoading = false;
      });
    }
  }

  _ApiException _createApiException({
    required String message,
    String? code,
    String? traceId,
    int? statusCode,
  }) {
    return _ApiException(
      message: message,
      code: code,
      traceId: traceId,
      statusCode: statusCode,
    );
  }

  Widget _buildErrorDetail(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.red[900],
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: Colors.red[800],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadFAQs,
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              Text(
                'Failed to load FAQs',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_statusCode != null) ...[
                      _buildErrorDetail('Status Code', _statusCode.toString()),
                      const SizedBox(height: 8),
                    ],
                    if (_errorCode != null) ...[
                      _buildErrorDetail('Error Code', _errorCode!),
                      const SizedBox(height: 8),
                    ],
                    _buildErrorDetail('Message', _error!),
                    if (_traceId != null) ...[
                      const SizedBox(height: 8),
                      _buildErrorDetail('Trace ID', _traceId!),
                      const SizedBox(height: 4),
                      Text(
                        '請將 Trace ID 提供給技術支援以便追蹤問題',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _loadFAQs,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_faqs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.help_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No FAQs available',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: _faqs.length,
      itemBuilder: (context, index) {
        final faq = _faqs[index];
        return Column(
          children: [
            ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 10),
              title: Text(
                faq['question'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 12.0),
                    child: Text(
                      faq['answer'] ?? '',
                      style: TextStyle(
                        color: Colors.grey[800],
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 1),
          ],
        );
      },
    );
  }
}

/// 自定義 API 異常類
class _ApiException implements Exception {
  final String message;
  final String? code;
  final String? traceId;
  final int? statusCode;

  _ApiException({
    required this.message,
    this.code,
    this.traceId,
    this.statusCode,
  });

  @override
  String toString() => message;
}
