import 'package:flutter/material.dart';

/// 問題顯示輔助類
/// 統一處理 application_questions 的顯示邏輯
class QuestionDisplayHelper {
  /// 從任務數據中提取問題列表
  static List<String> extractQuestions(dynamic taskData) {
    if (taskData == null) return [];

    // 處理新的結構化格式
    if (taskData['application_questions'] != null) {
      final questions =
          taskData['application_questions'] as List<dynamic>? ?? [];
      return questions
          .map((q) =>
              (q as Map<String, dynamic>)['application_question']?.toString() ??
              '')
          .where((q) => q.trim().isNotEmpty)
          .toList();
    }

    // 處理舊的字符串格式（向後兼容）
    if (taskData['application_question'] != null) {
      final questionString = taskData['application_question'].toString();
      if (questionString.isNotEmpty) {
        return questionString
            .split('|')
            .map((q) => q.trim())
            .where((q) => q.isNotEmpty)
            .toList();
      }
    }

    return [];
  }

  /// 創建問題顯示的 Widget 列表
  static List<Widget> buildQuestionWidgets(
    dynamic taskData, {
    TextStyle? questionStyle,
    TextStyle? numberStyle,
    EdgeInsets? padding,
    bool showNumbers = true,
  }) {
    final questions = extractQuestions(taskData);

    if (questions.isEmpty) {
      return [
        Padding(
          padding: padding ?? const EdgeInsets.only(bottom: 4),
          child: Text(
            'No questions.',
            style: questionStyle ??
                const TextStyle(
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
          ),
        ),
      ];
    }

    return questions.asMap().entries.map((entry) {
      final index = entry.key;
      final question = entry.value;

      return Padding(
        padding: padding ?? const EdgeInsets.only(bottom: 4),
        child: Text(
          showNumbers ? '${index + 1}. $question' : question,
          style: questionStyle,
          overflow: TextOverflow.visible,
          maxLines: null,
        ),
      );
    }).toList();
  }

  /// 檢查是否有問題
  static bool hasQuestions(dynamic taskData) {
    return extractQuestions(taskData).isNotEmpty;
  }

  /// 獲取問題數量
  static int getQuestionCount(dynamic taskData) {
    return extractQuestions(taskData).length;
  }

  /// 格式化問題為 API 格式
  static List<String> formatForApi(dynamic taskData) {
    return extractQuestions(taskData);
  }

  /// 格式化問題為顯示格式
  static String formatForDisplay(dynamic taskData) {
    final questions = extractQuestions(taskData);
    if (questions.isEmpty) return 'No questions';
    return questions
        .asMap()
        .entries
        .map((entry) => '${entry.key + 1}. ${entry.value}')
        .join('\n');
  }
}
