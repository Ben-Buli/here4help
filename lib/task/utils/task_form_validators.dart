class TaskFormValidators {
  /// 驗證任務標題
  static String? validateTitle(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Task title is required';
    }
    if (value.trim().length < 3) {
      return 'Task title must be at least 3 characters';
    }
    if (value.trim().length > 100) {
      return 'Task title must be less than 100 characters';
    }
    return null;
  }

  /// 驗證薪資
  static String? validateSalary(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Salary is required';
    }

    // 移除所有非數字字符
    final digits = value.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) {
      return 'Please enter a valid salary';
    }

    final salary = int.tryParse(digits);
    if (salary == null || salary <= 0) {
      return 'Salary must be greater than 0';
    }

    if (salary > 10000) {
      return 'Salary cannot exceed 10,000';
    }

    return null;
  }

  /// 驗證任務描述
  static String? validateDescription(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Task description is required';
    }
    if (value.trim().length < 10) {
      return 'Task description must be at least 10 characters';
    }
    if (value.trim().length > 1000) {
      return 'Task description must be less than 1000 characters';
    }
    return null;
  }

  /// 驗證任務日期
  static String? validateTaskDate(DateTime? date) {
    if (date == null) {
      return 'Task date is required';
    }

    final now = DateTime.now();
    if (date.isBefore(now)) {
      return 'Task date cannot be in the past';
    }

    return null;
  }

  /// 驗證時間段
  static String? validateTimePeriod(DateTime? start, DateTime? end) {
    if (start == null || end == null) {
      return null; // 時間段是可選的
    }

    if (end.isBefore(start)) {
      return 'End time must be after start time';
    }

    return null;
  }

  /// 驗證語言要求
  static String? validateLanguageRequirement(List<String> languages) {
    if (languages.isEmpty) {
      return 'At least one language is required';
    }
    return null;
  }

  /// 驗證申請問題
  static String? validateApplicationQuestion(String? question, int index) {
    if (question == null || question.trim().isEmpty) {
      return 'Question ${index + 1} is required';
    }
    if (question.trim().length < 5) {
      return 'Question ${index + 1} must be at least 5 characters';
    }
    if (question.trim().length > 200) {
      return 'Question ${index + 1} must be less than 200 characters';
    }
    return null;
  }

  /// 驗證申請問題列表
  static List<String> validateApplicationQuestions(List<String> questions) {
    final errors = <String>[];

    for (int i = 0; i < questions.length; i++) {
      final error = validateApplicationQuestion(questions[i], i);
      if (error != null) {
        errors.add(error);
      }
    }

    return errors;
  }

  /// 驗證位置
  static String? validateLocation(String? location) {
    if (location == null || location.trim().isEmpty) {
      return 'Location is required';
    }
    return null;
  }

  /// 綜合驗證表單
  static Map<String, String> validateForm({
    required String title,
    required String salary,
    required String description,
    required DateTime? taskDate,
    required List<String> languages,
    required List<String> applicationQuestions,
    required String location,
    DateTime? periodStart,
    DateTime? periodEnd,
  }) {
    final errors = <String, String>{};

    // 驗證標題
    final titleError = validateTitle(title);
    if (titleError != null) {
      errors['Task Title'] = titleError;
    }

    // 驗證薪資
    final salaryError = validateSalary(salary);
    if (salaryError != null) {
      errors['Salary'] = salaryError;
    }

    // 驗證描述
    final descriptionError = validateDescription(description);
    if (descriptionError != null) {
      errors['Description'] = descriptionError;
    }

    // 驗證任務日期
    final dateError = validateTaskDate(taskDate);
    if (dateError != null) {
      errors['Time'] = dateError;
    }

    // 驗證時間段
    final periodError = validateTimePeriod(periodStart, periodEnd);
    if (periodError != null) {
      errors['Time Period'] = periodError;
    }

    // 驗證語言要求
    final languageError = validateLanguageRequirement(languages);
    if (languageError != null) {
      errors['Language Requirement'] = languageError;
    }

    // 驗證申請問題
    final questionErrors = validateApplicationQuestions(applicationQuestions);
    for (int i = 0; i < questionErrors.length; i++) {
      errors['Application Question ${i + 1}'] = questionErrors[i];
    }

    // 驗證位置
    final locationError = validateLocation(location);
    if (locationError != null) {
      errors['Location'] = locationError;
    }

    return errors;
  }
}
