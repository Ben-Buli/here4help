import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../models/task_model.dart';

class ApplicationQuestionService extends ChangeNotifier {
  static final ApplicationQuestionService _instance =
      ApplicationQuestionService._internal();
  factory ApplicationQuestionService() => _instance;
  ApplicationQuestionService._internal();

  final List<ApplicationQuestionModel> _questions = [];
  bool _isLoading = false;
  String? _error;

  List<ApplicationQuestionModel> get questions => _questions;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// 從後端 API 載入應用問題
  Future<void> loadQuestions({String? taskId}) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      String url = '${AppConfig.apiBaseUrl}/backend/api/tasks/questions.php';
      if (taskId != null) {
        url += '?task_id=$taskId';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          _questions.clear();
          final questionsData = List<Map<String, dynamic>>.from(data['data']);
          _questions.addAll(questionsData.map((q) => ApplicationQuestionModel(
                id: q['id'] ?? '',
                taskId: q['task_id'] ?? '',
                applicationQuestion: q['application_question'] ?? '',
                applierReply: q['applier_reply'],
              )));
        } else {
          _error = data['message'] ?? 'Failed to load questions';
        }
      } else {
        _error = 'HTTP ${response.statusCode}: Failed to load questions';
      }
    } catch (e) {
      _error = 'Network error: $e';
      debugPrint('ApplicationQuestionService loadQuestions error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 創建新的應用問題
  Future<bool> createQuestion(Map<String, dynamic> questionData) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await http
          .post(
            Uri.parse(
                '${AppConfig.apiBaseUrl}/backend/api/tasks/questions.php'),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode(questionData),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          // 重新載入問題列表
          await loadQuestions(taskId: questionData['task_id']);
          return true;
        } else {
          _error = data['message'] ?? 'Failed to create question';
          return false;
        }
      } else {
        _error = 'HTTP ${response.statusCode}: Failed to create question';
        return false;
      }
    } catch (e) {
      _error = 'Network error: $e';
      debugPrint('ApplicationQuestionService createQuestion error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 更新應用問題的回覆
  Future<bool> updateQuestionReply(String questionId, String reply) async {
    try {
      final response = await http
          .put(
            Uri.parse(
                '${AppConfig.apiBaseUrl}/backend/api/tasks/questions.php/$questionId'),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'applier_reply': reply}),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          // 更新本地問題回覆
          final index = _questions.indexWhere((q) => q.id == questionId);
          if (index != -1) {
            _questions[index] = _questions[index].copyWith(applierReply: reply);
            notifyListeners();
          }
          return true;
        } else {
          _error = data['message'] ?? 'Failed to update question reply';
          return false;
        }
      } else {
        _error = 'HTTP ${response.statusCode}: Failed to update question reply';
        return false;
      }
    } catch (e) {
      _error = 'Network error: $e';
      debugPrint('ApplicationQuestionService updateQuestionReply error: $e');
      return false;
    }
  }

  /// 獲取特定任務的應用問題
  List<ApplicationQuestionModel> getQuestionsByTaskId(String taskId) {
    return _questions.where((q) => q.taskId == taskId).toList();
  }

  /// 清除錯誤
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// 強制重載問題列表
  Future<void> reloadQuestions({String? taskId}) async {
    await loadQuestions(taskId: taskId);
  }
}
