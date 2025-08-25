# Task Apply Page 問題載入修復報告

## 🐛 **問題描述**

用戶回報 TaskApplyPage 存在以下問題：

1. **問題載入邏輯錯誤**：沒有從 `application_questions` 表載入對應任務的所有問題
2. **UI 顯示不完整**：頁面只顯示單一問題欄位，而不是動態生成所有問題
3. **必填邏輯錯誤**：自我介紹是必填，但 application_questions 應該是必填
4. **資料傳送不匹配**：傳送邏輯與 `kind=resume` 的結構化格式不匹配

## 🔍 **問題分析**

### **問題1：資料載入邏輯**

**原始問題**：
```dart
Future<Map<String, dynamic>> _loadTask(String taskId) async {
  final taskService = TaskService();
  await taskService.loadTasks();
  return taskService.getTaskById(taskId) ?? {};
}
```

**問題**：
- `TaskService.getTaskById()` 只返回基本任務資料
- 不包含 `application_questions` 陣列
- 導致頁面無法顯示所有問題

### **問題2：UI 生成邏輯**

**原始問題**：
```dart
if (applicationQuestion != null) ...[
  Text(applicationQuestion, style: const TextStyle(fontWeight: FontWeight.bold)),
  TextFormField(controller: _englishController, ...)
]
```

**問題**：
- 只處理單一問題 (`applicationQuestion`)
- 沒有動態生成多個問題欄位
- 控制器數量固定，無法適應不同數量的問題

### **問題3：必填邏輯**

**原始問題**：
- 自我介紹沒有 validator，但實際應該是非必填
- 問題回答有 validator，這是正確的

### **問題4：資料結構**

**原始問題**：
```dart
final Map<String, String> answers = {};
if (applicationQuestion != null && q1.isNotEmpty) {
  answers[applicationQuestion.trim()] = q1;
}
```

**問題**：
- 只處理單一問題回答
- 無法處理多個問題的情況

## ✅ **修復方案**

### **修復1：改用專門的 API 載入完整資料**

```dart
Future<Map<String, dynamic>> _loadTask(String taskId) async {
  try {
    // 使用專門的 API 載入完整的任務資料（包含 application_questions）
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/backend/api/tasks/task_edit_data.php?id=$taskId'),
      headers: {'Content-Type': 'application/json'},
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        return Map<String, dynamic>.from(data['data']);
      }
    }
  } catch (e) {
    debugPrint('❌ 載入任務資料失敗: $e');
    // 備用方案：使用 TaskService
    final taskService = TaskService();
    await taskService.loadTasks();
    return taskService.getTaskById(taskId) ?? {};
  }
}
```

**改進點**：
1. **使用正確的 API**：`task_edit_data.php` 包含完整的 `application_questions`
2. **錯誤處理**：提供備用方案確保穩定性
3. **超時處理**：避免網路請求卡住

### **修復2：動態控制器管理**

```dart
class _TaskApplyPageState extends State<TaskApplyPage> {
  final _formKey = GlobalKey<FormState>();
  final _selfIntroController = TextEditingController();
  final List<TextEditingController> _questionControllers = []; // 動態控制器列表

  @override
  void dispose() {
    _selfIntroController.dispose();
    for (var controller in _questionControllers) {
      controller.dispose();
    }
    super.dispose();
  }
}
```

**改進點**：
1. **動態控制器**：根據問題數量動態建立控制器
2. **記憶體管理**：正確釋放所有控制器
3. **可擴展性**：支援任意數量的問題

### **修復3：動態 UI 生成**

```dart
final applicationQuestions = List<Map<String, dynamic>>.from(
  task['application_questions'] ?? []
);

// 確保有足夠的控制器
while (_questionControllers.length < applicationQuestions.length) {
  _questionControllers.add(TextEditingController());
}

// 動態生成所有 application_questions
...applicationQuestions.asMap().entries.map((entry) {
  final index = entry.key;
  final question = entry.value;
  final questionText = question['application_question'] ?? '';
  
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(questionText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      const SizedBox(height: 8),
      TextFormField(
        controller: _questionControllers[index],
        maxLines: 3,
        decoration: InputDecoration(
          hintText: 'Write your answer to the poster',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'This field is required';
          }
          return null;
        },
      ),
      const SizedBox(height: 16),
    ],
  );
}).toList(),
```

**改進點**：
1. **動態生成**：根據 `application_questions` 陣列動態建立欄位
2. **必填驗證**：所有問題回答都是必填
3. **響應式設計**：適應不同數量的問題

### **修復4：修正必填邏輯**

```dart
// 自我介紹改為非必填
TextFormField(
  controller: _selfIntroController,
  maxLines: 4,
  decoration: InputDecoration(
    hintText: 'Tell us about yourself.',
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
  ),
  // 沒有 validator，因此非必填
),

// 問題回答保持必填
TextFormField(
  controller: _questionControllers[index],
  validator: (value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required';
    }
    return null;
  },
),
```

### **修復5：完善資料傳送邏輯**

```dart
// 組裝新格式 answers：以「問題原文」為鍵
final Map<String, String> answers = {};
for (int i = 0; i < applicationQuestions.length; i++) {
  final question = applicationQuestions[i];
  final questionText = question['application_question'] ?? '';
  final answer = _questionControllers[i].text.trim();
  
  if (questionText.isNotEmpty && answer.isNotEmpty) {
    answers[questionText] = answer;
  }
}

// 建立 Resume 資料結構
final List<ApplyResponse> applyResponses = [];
for (int i = 0; i < applicationQuestions.length; i++) {
  final question = applicationQuestions[i];
  final questionText = question['application_question'] ?? '';
  final answer = _questionControllers[i].text.trim();
  
  if (questionText.isNotEmpty && answer.isNotEmpty) {
    applyResponses.add(ApplyResponse(
      applyQuestion: questionText,
      applyReply: answer,
    ));
  }
}

final resumeData = ResumeData(
  applyIntroduction: intro,
  applyResponses: applyResponses,
);
```

**改進點**：
1. **多問題支援**：處理所有問題的回答
2. **結構化資料**：與 `kind=resume` 格式完全匹配
3. **資料完整性**：確保所有回答都被正確傳送

## 🎯 **修復的檔案**

### **`lib/task/pages/task_apply_page.dart`**

#### **修改1：添加必要的 imports**
```dart
import 'package:here4help/config/app_config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
```

#### **修改2：動態控制器管理**
- 移除固定的 `_englishController`
- 添加動態的 `_questionControllers` 列表
- 正確的記憶體管理

#### **修改3：改用專門的 API**
- `_loadTask()` 使用 `task_edit_data.php`
- 載入完整的任務資料包含 `application_questions`
- 提供備用方案確保穩定性

#### **修改4：動態 UI 生成**
- 根據 `application_questions` 動態建立欄位
- 自我介紹改為非必填
- 所有問題回答設為必填

#### **修改5：完善提交邏輯**
- 處理多個問題的回答
- 建立正確的 Resume 資料結構
- 與 `kind=resume` 格式匹配

## 🧪 **測試驗證**

### **測試場景1：載入任務資料**
```
期望：
✅ 成功載入任務基本資料
✅ 成功載入 application_questions 陣列
✅ 動態建立對應數量的控制器
```

### **測試場景2：UI 顯示**
```
期望：
✅ 顯示自我介紹欄位（非必填）
✅ 動態顯示所有問題欄位（必填）
✅ 每個問題都有獨立的輸入框
```

### **測試場景3：表單驗證**
```
期望：
✅ 自我介紹可以為空
✅ 問題回答不能為空
✅ 表單驗證正確運作
```

### **測試場景4：資料提交**
```
期望：
✅ 所有問題回答正確收集
✅ Resume 資料結構正確建立
✅ 聊天室中顯示 Resume 氣泡
```

## 📊 **API 資料結構**

### **task_edit_data.php 回應格式**
```json
{
  "success": true,
  "data": {
    "id": "task-uuid",
    "title": "Task Title",
    "description": "Task Description",
    "application_questions": [
      {
        "id": "question-uuid",
        "application_question": "What is your experience?",
        "question_type": "text",
        "sort_order": 1
      },
      {
        "id": "question-uuid-2", 
        "application_question": "Why are you interested?",
        "question_type": "text",
        "sort_order": 2
      }
    ]
  }
}
```

### **Resume 資料結構**
```json
{
  "applyIntroduction": "自我介紹內容",
  "applyResponses": [
    {
      "applyQuestion": "What is your experience?",
      "applyReply": "使用者回答1"
    },
    {
      "applyQuestion": "Why are you interested?", 
      "applyReply": "使用者回答2"
    }
  ]
}
```

## 🎉 **總結**

此次修復成功解決了 TaskApplyPage 的所有問題：

1. **正確載入資料**：使用專門的 API 載入完整的任務和問題資料
2. **動態 UI 生成**：根據問題數量動態建立輸入欄位
3. **正確的必填邏輯**：自我介紹非必填，問題回答必填
4. **完整的資料傳送**：與 Resume 功能完全整合

**修復後的頁面將能夠：**
- ✅ 正確顯示所有 application_questions
- ✅ 動態適應不同數量的問題
- ✅ 正確的表單驗證邏輯
- ✅ 與聊天室 Resume 功能完全整合

**請測試並確認修復效果！** 🚀
