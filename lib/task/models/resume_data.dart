import 'dart:convert';

/// 應徵回覆資料模型
class ApplyResponse {
  final String applyQuestion;
  final String applyReply;

  const ApplyResponse({
    required this.applyQuestion,
    required this.applyReply,
  });

  Map<String, dynamic> toJson() => {
        'applyQuestion': applyQuestion,
        'applyReply': applyReply,
      };

  factory ApplyResponse.fromJson(Map<String, dynamic> json) => ApplyResponse(
        applyQuestion: json['applyQuestion'] ?? '',
        applyReply: json['applyReply'] ?? '',
      );

  @override
  String toString() =>
      'ApplyResponse(question: $applyQuestion, reply: $applyReply)';
}

/// Resume 資料模型
class ResumeData {
  final String applyIntroduction;
  final List<ApplyResponse> applyResponses;

  const ResumeData({
    required this.applyIntroduction,
    required this.applyResponses,
  });

  Map<String, dynamic> toJson() => {
        'applyIntroduction': applyIntroduction,
        'applyResponses': applyResponses.map((r) => r.toJson()).toList(),
      };

  factory ResumeData.fromJson(Map<String, dynamic> json) {
    final responses = json['applyResponses'] as List<dynamic>? ?? [];
    return ResumeData(
      applyIntroduction: json['applyIntroduction'] ?? '',
      applyResponses: responses
          .map((r) => ApplyResponse.fromJson(Map<String, dynamic>.from(r)))
          .toList(),
    );
  }

  /// 轉換為 JSON 字串
  String toJsonString() => jsonEncode(toJson());

  /// 從 JSON 字串建立
  factory ResumeData.fromJsonString(String jsonString) {
    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return ResumeData.fromJson(json);
    } catch (e) {
      // 如果解析失敗，返回空的 Resume
      return const ResumeData(
        applyIntroduction: '',
        applyResponses: [],
      );
    }
  }

  /// 檢查是否為空
  bool get isEmpty =>
      applyIntroduction.trim().isEmpty && applyResponses.isEmpty;

  /// 取得簡短摘要（用於氣泡顯示）
  String get summary {
    if (applyIntroduction.trim().isNotEmpty) {
      // 取前50個字符作為摘要
      final intro = applyIntroduction.trim();
      return intro.length > 50 ? '${intro.substring(0, 50)}...' : intro;
    }

    if (applyResponses.isNotEmpty) {
      final firstReply = applyResponses.first.applyReply.trim();
      return firstReply.length > 50
          ? '${firstReply.substring(0, 50)}...'
          : firstReply;
    }

    return 'Resume submitted';
  }

  @override
  String toString() =>
      'ResumeData(introduction: $applyIntroduction, responses: ${applyResponses.length})';
}
