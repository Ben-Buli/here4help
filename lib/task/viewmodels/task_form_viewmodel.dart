import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';

class TaskFormViewModel extends ChangeNotifier {
  // TextEditingController
  final TextEditingController salaryController = TextEditingController();
  final TextEditingController titleController = TextEditingController();
  final TextEditingController taskDescriptionController =
      TextEditingController();
  final TextEditingController locationSearchController =
      TextEditingController();

  // 表單數據
  String languageRequirement = '';
  DateTime? taskDate;
  DateTime? periodStart;
  DateTime? periodEnd;
  LatLng? selectedLocation = const LatLng(25.0208, 121.5418);
  String locationLabel = 'NCCU';

  // 錯誤管理
  final Set<String> errorFields = {};

  // 列表數據
  List<String> selectedLanguages = [];
  final List<String> applicationQuestions = [''];
  List<Map<String, dynamic>> universities = [];
  List<Map<String, dynamic>> languages = [];

  // 初始化方法
  void initializeForm() {
    // 初始化表單欄位
    titleController.text = 'Opening Bank Account (Demo)';
    taskDescriptionController.text =
        'Need help with opening a bank account. Looking for someone who can guide me through the process and accompany me to the bank.';

    final formatter = NumberFormat('#,##0', 'en_US');
    salaryController.text = formatter.format(500);

    locationLabel = 'NCCU';
    locationSearchController.text = 'NCCU';

    final now = DateTime.now();
    taskDate = DateTime(now.year, now.month, now.day, now.hour, now.minute);
    periodStart = DateTime(2025, 9, 10, 12, 0);
    periodEnd = DateTime(2025, 9, 10, 13, 0);

    applicationQuestions[0] = 'Do you have relevant experience?';
    languageRequirement = 'English,Japanese';
    selectedLanguages = languageRequirement.split(',');

    notifyListeners();
  }

  // 錯誤管理方法
  void addError(String field) {
    errorFields.add(field);
    notifyListeners();
  }

  void removeError(String field) {
    errorFields.remove(field);
    notifyListeners();
  }

  void clearErrors() {
    errorFields.clear();
    notifyListeners();
  }

  bool hasError(String field) {
    return errorFields.contains(field);
  }

  // 語言管理方法
  void updateSelectedLanguages(List<String> languages) {
    selectedLanguages = languages;
    languageRequirement = languages.join(',');
    notifyListeners();
  }

  void addLanguage(String language) {
    if (!selectedLanguages.contains(language)) {
      selectedLanguages.add(language);
      languageRequirement = selectedLanguages.join(',');
      notifyListeners();
    }
  }

  void removeLanguage(String language) {
    selectedLanguages.remove(language);
    languageRequirement = selectedLanguages.join(',');
    notifyListeners();
  }

  // 申請問題管理方法
  void addApplicationQuestion() {
    if (applicationQuestions.isEmpty ||
        applicationQuestions.last.trim().isNotEmpty) {
      applicationQuestions.add('');
      notifyListeners();
    }
  }

  void removeApplicationQuestion(int index) {
    if (index >= 0 && index < applicationQuestions.length) {
      applicationQuestions.removeAt(index);
      notifyListeners();
    }
  }

  void updateApplicationQuestion(int index, String question) {
    if (index >= 0 && index < applicationQuestions.length) {
      applicationQuestions[index] = question;
      notifyListeners();
    }
  }

  // 時間管理方法
  void updateTaskDate(DateTime? date) {
    taskDate = date;
    notifyListeners();
  }

  void updatePeriodStart(DateTime? date) {
    periodStart = date;
    notifyListeners();
  }

  void updatePeriodEnd(DateTime? date) {
    periodEnd = date;
    notifyListeners();
  }

  // 位置管理方法
  void updateSelectedLocation(LatLng? location) {
    selectedLocation = location;
    notifyListeners();
  }

  void updateLocationLabel(String label) {
    locationLabel = label;
    notifyListeners();
  }

  // 數據載入方法
  void updateUniversities(List<Map<String, dynamic>> universities) {
    this.universities = universities;
    notifyListeners();
  }

  void updateLanguages(List<Map<String, dynamic>> languages) {
    this.languages = languages;
    notifyListeners();
  }

  // 表單驗證方法
  bool validateForm() {
    clearErrors();
    bool isValid = true;

    // 驗證標題
    if (titleController.text.trim().isEmpty) {
      addError('Task Title');
      isValid = false;
    }

    // 驗證薪資
    if (salaryController.text.trim().isEmpty) {
      addError('Salary');
      isValid = false;
    }

    // 驗證時間
    if (taskDate == null) {
      addError('Time');
      isValid = false;
    }

    // 驗證申請問題
    for (int i = 0; i < applicationQuestions.length; i++) {
      if (applicationQuestions[i].trim().isEmpty) {
        addError('Application Question ${i + 1}');
        isValid = false;
      }
    }

    return isValid;
  }

  // 獲取表單數據
  Map<String, dynamic> getFormData() {
    return {
      'title': titleController.text.trim(),
      'description': taskDescriptionController.text.trim(),
      'salary': salaryController.text.trim(),
      'location': locationLabel,
      'taskDate': taskDate?.toIso8601String(),
      'periodStart': periodStart?.toIso8601String(),
      'periodEnd': periodEnd?.toIso8601String(),
      'languageRequirement': languageRequirement,
      'applicationQuestions':
          applicationQuestions.where((q) => q.trim().isNotEmpty).toList(),
      'selectedLocation': selectedLocation,
    };
  }

  // 清理資源
  @override
  void dispose() {
    salaryController.dispose();
    titleController.dispose();
    taskDescriptionController.dispose();
    locationSearchController.dispose();
    super.dispose();
  }
}
