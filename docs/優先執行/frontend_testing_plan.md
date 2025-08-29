# Action Bar Logic 前端測試計劃

## 📊 測試概覽

**測試目標**: 驗證 Action Bar Logic 的前端功能完整性  
**測試環境**: Flutter Web/App  
**測試範圍**: Dialog、API 調用、用戶交互、錯誤處理  

## 🎯 測試階段

### 階段 1：Dialog 組件測試 ✅
**狀態**: 已完成實作，待測試  
**測試項目**:
- [ ] `ConfirmCompletionDialog` 顯示測試
- [ ] `DisagreeCompletionDialog` 顯示測試
- [ ] 費率預覽功能測試
- [ ] 輸入驗證測試
- [ ] 錯誤處理測試

### 階段 2：API 整合測試 🔄
**狀態**: 已實作，待測試  
**測試項目**:
- [ ] `TaskService.confirmCompletion()` 測試
- [ ] `TaskService.disagreeCompletion()` 測試
- [ ] `TaskService.acceptApplication()` 測試
- [ ] 錯誤響應處理測試

### 階段 3：端到端流程測試 ⏳
**狀態**: 待測試  
**測試項目**:
- [ ] 完整確認完成流程
- [ ] 完整不同意流程
- [ ] 接受應徵流程
- [ ] 狀態更新驗證

## 🛠️ 測試工具與方法

### 1. Flutter Widget 測試
```dart
// 測試 Dialog 顯示
testWidgets('ConfirmCompletionDialog shows correctly', (WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ConfirmCompletionDialog(
          taskId: 'test_task_123',
          taskTitle: 'Test Task',
          onPreview: () async => {'fee_rate': 0.02, 'fee': 20.0, 'net': 980.0},
          onConfirm: () async {},
        ),
      ),
    ),
  );
  
  expect(find.text('Confirm Task Completion'), findsOneWidget);
  expect(find.text('Task: Test Task'), findsOneWidget);
});
```

### 2. Mock API 測試
```dart
// 模擬 API 響應
class MockTaskService extends Mock implements TaskService {
  @override
  Future<Map<String, dynamic>> confirmCompletion({
    required String taskId,
    bool preview = false,
  }) async {
    if (preview) {
      return {
        'fee_rate': 0.02,
        'fee': 20.0,
        'net': 980.0,
        'preview': true,
      };
    } else {
      return {'success': true, 'message': 'Task confirmed'};
    }
  }
}
```

### 3. 手動測試清單
- [ ] 打開聊天詳情頁面
- [ ] 檢查 Action Bar 按鈕顯示
- [ ] 點擊確認完成按鈕
- [ ] 驗證 Dialog 內容
- [ ] 測試費率預覽
- [ ] 測試確認操作
- [ ] 驗證錯誤處理

## 📋 測試案例

### 測試案例 1：ConfirmCompletionDialog 基本功能
**前置條件**: 用戶已登入，任務狀態為 `pending_confirmation`  
**測試步驟**:
1. 打開聊天詳情頁面
2. 點擊 "Confirm Completion" 按鈕
3. 驗證 Dialog 正確顯示
4. 檢查費率預覽資訊
5. 點擊 "Confirm" 按鈕
6. 驗證成功訊息

**預期結果**: Dialog 正常顯示，費率計算正確，操作成功

### 測試案例 2：DisagreeCompletionDialog 基本功能
**前置條件**: 用戶已登入，任務狀態為 `pending_confirmation`  
**測試步驟**:
1. 打開聊天詳情頁面
2. 點擊 "Disagree" 按鈕
3. 驗證 Dialog 正確顯示
4. 輸入不同意理由
5. 點擊 "Submit" 按鈕
6. 驗證成功訊息

**預期結果**: Dialog 正常顯示，理由驗證正確，操作成功

### 測試案例 3：錯誤處理測試
**前置條件**: 模擬 API 錯誤  
**測試步驟**:
1. 模擬網路錯誤
2. 嘗試確認完成
3. 驗證錯誤訊息顯示
4. 測試重試功能

**預期結果**: 錯誤訊息正確顯示，重試功能正常

## 🔧 測試環境設置

### 1. 開發環境測試
```bash
# 啟動 Flutter 開發服務器
flutter run -d chrome --web-port=8080

# 或啟動 iOS 模擬器
flutter run -d ios
```

### 2. 測試數據準備
```dart
// 測試任務數據
final testTask = {
  'id': 'test_task_123',
  'title': 'Test Task for Action Bar Logic',
  'reward_point': '1000',
  'status': {'code': 'pending_confirmation'},
  'creator_id': 1,
  'participant_id': 2,
};
```

### 3. API 端點配置
```dart
// 確保 API 端點正確配置
class AppConfig {
  static String get taskConfirmCompletionUrl => 
    '$apiBaseUrl/backend/api/tasks/confirm_completion.php';
  static String get taskDisagreeCompletionUrl => 
    '$apiBaseUrl/backend/api/tasks/disagree_completion.php';
}
```

## 📊 測試檢查清單

### Dialog 組件檢查
- [ ] Dialog 正確顯示
- [ ] 標題和內容正確
- [ ] 按鈕功能正常
- [ ] 輸入驗證有效
- [ ] 錯誤訊息顯示正確

### API 調用檢查
- [ ] 請求格式正確
- [ ] 響應處理正確
- [ ] 錯誤處理完善
- [ ] 超時處理正常

### 用戶體驗檢查
- [ ] 載入狀態顯示
- [ ] 成功訊息顯示
- [ ] 錯誤訊息清晰
- [ ] 操作流程順暢

## 🚀 執行測試

### 1. 單元測試
```bash
flutter test test/widget_test.dart
```

### 2. Widget 測試
```bash
flutter test test/chat_widgets_test.dart
```

### 3. 整合測試
```bash
flutter test test/integration_test.dart
```

### 4. 手動測試
1. 啟動應用程式
2. 登入測試帳號
3. 找到測試任務
4. 執行測試案例
5. 記錄測試結果

## 📈 測試報告

### 成功指標
- Dialog 顯示正確率: 100%
- API 調用成功率: >95%
- 用戶操作完成率: >90%
- 錯誤處理正確率: 100%

### 問題追蹤
- [ ] 記錄發現的問題
- [ ] 分類問題嚴重程度
- [ ] 制定修復計劃
- [ ] 驗證修復效果

## 🎯 下一步行動

1. **設置測試環境**
2. **準備測試數據**
3. **執行 Dialog 測試**
4. **執行 API 整合測試**
5. **執行端到端測試**
6. **生成測試報告**

---

**測試狀態**: 🟡 準備中  
**預計完成時間**: 2-3 小時  
**測試負責人**: 開發團隊
