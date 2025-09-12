# Posted Tasks 篩選與 My Works 實時訊息修復指南

## 🎯 **問題總結**

### **問題 1：Posted Tasks 應徵者篩選邏輯缺失**
- **現狀**：所有任務狀態都顯示所有應徵者
- **應該**：非 Open 狀態（status_id ≠ 1）時只顯示被接受的應徵者
- **影響**：用戶體驗困惑，顯示不相關的應徵者信息

### **問題 2：My Works 缺少實時訊息更新**
- **現狀**：只顯示靜態的 `latest_message_snippet`
- **應該**：像 Posted Tasks 一樣支持 Socket 實時訊息更新
- **影響**：訊息不及時，用戶無法看到最新對話

## 🛠️ **修復方案**

### **方案 1：Posted Tasks 應徵者篩選增強**

#### **步驟 1：添加增強邏輯文件**
```bash
# 複製增強邏輯文件到項目
cp lib/chat/widgets/posted_tasks_widget_enhanced.dart your_project/lib/chat/widgets/
```

#### **步驟 2：修改現有 PostedTasksWidget**

**在 `lib/chat/widgets/posted_tasks_widget.dart` 中：**

1. **添加 import**：
```dart
import 'package:here4help/chat/widgets/posted_tasks_widget_enhanced.dart';
```

2. **修改類聲明**：
```dart
class _PostedTasksWidgetState extends State<PostedTasksWidget>
    with AutomaticKeepAliveClientMixin, PostedTasksApplicantFilterMixin {
```

3. **修改 `_buildTaskCard` 方法（約第1113行）**：
```dart
Widget _buildTaskCard(Map<String, dynamic> task) {
  final taskId = task['id'].toString();
  
  // 🆕 根據任務狀態篩選應徵者
  final originalApplicants = _applicationsByTask[taskId] ?? [];
  final filteredApplicants = filterApplicantsForTask(task, _applicationsByTask);
  
  // 調試信息
  debugPrint('🔍 [Posted Tasks] 任務 $taskId 篩選結果: ${originalApplicants.length} -> ${filteredApplicants.length}');
  
  // 檢查是否應該顯示應徵者區塊
  if (!shouldShowApplicantsForTask(task)) {
    debugPrint('⚠️ [Posted Tasks] 任務 $taskId 不顯示應徵者區塊');
  }

  // 使用篩選後的應徵者數據
  final applierChatItems = filteredApplicants
      .map((applicant) => {
            // ... 現有的轉換邏輯保持不變
          })
      .toList();

  return _buildPostedTasksCardWithAccordion(
      task, applierChatItems.cast<Map<String, dynamic>>());
}
```

4. **增強應徵者區塊顯示（約第1388行）**：
```dart
// 在 _buildPostedTasksCardWithAccordion 方法中
if (shouldShowApplicantsForTask(task)) ...[
  // 🆕 動態標題
  Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Text(
      getApplicantsSectionTitle(task, visibleAppliers.length),
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.grey,
      ),
    ),
  ),
  if (visibleAppliers.isNotEmpty)
    ...visibleAppliers.map((applier) =>
        _buildApplierCard(applier, taskId, colorScheme))
  else
    const Padding(
      padding: EdgeInsets.all(16),
      child: Text(
        'No accepted applicant found',
        style: TextStyle(
          color: Colors.orange,
          fontSize: 12,
          fontStyle: FontStyle.italic,
        ),
        textAlign: TextAlign.center,
      ),
    ),
] else ...[
  const Padding(
    padding: EdgeInsets.all(16),
    child: Text(
      'Applicants section hidden for this task status',
      style: TextStyle(color: Colors.grey, fontSize: 12),
      textAlign: TextAlign.center,
    ),
  ),
],
```

### **方案 2：My Works 實時訊息更新增強**

#### **步驟 1：添加增強邏輯文件**
```bash
cp lib/chat/widgets/my_works_widget_enhanced.dart your_project/lib/chat/widgets/
```

#### **步驟 2：修改現有 MyWorksWidget**

**在 `lib/chat/widgets/my_works_widget.dart` 中：**

1. **添加 import**：
```dart
import 'package:here4help/chat/widgets/my_works_widget_enhanced.dart';
```

2. **修改類聲明**：
```dart
class _MyWorksWidgetState extends State<MyWorksWidget>
    with MyWorksRealtimeMessageMixin {
```

3. **實現 Mixin 要求的方法**：
```dart
/// 實現 Mixin 要求的頭像構建方法
@override
Widget buildAvatarWithFallback(
  String? avatarPath,
  String? name, {
  double radius = 16,
  double fontSize = 12,
}) {
  return _buildAvatarWithFallback(avatarPath, name, radius: radius, fontSize: fontSize);
}
```

4. **在 initState 中添加預載入（約第260行後）**：
```dart
// 🆕 預載入實時訊息連接
WidgetsBinding.instance.addPostFrameCallback((_) {
  if (mounted) {
    final chatProvider = _getChatProvider();
    if (chatProvider != null && chatProvider.myWorksApplications.isNotEmpty) {
      preloadRealtimeConnections(chatProvider.myWorksApplications);
      MyWorksMessageStats.printMessageStats(chatProvider.myWorksApplications);
    }
  }
});
```

5. **替換 `_buildChatPartnerSection` 方法**：
```dart
/// 構建聊天對象與最新訊息區塊 - 增強版（支持實時更新）
Widget _buildChatPartnerSection(Map<String, dynamic> task) {
  // 🆕 檢查是否支持實時訊息
  if (supportsRealtimeMessages(task)) {
    debugPrint('🔄 [My Works] 任務 ${task['id']} 使用實時訊息更新');
    return buildEnhancedChatPartnerSection(task);
  } else {
    debugPrint('⚠️ [My Works] 任務 ${task['id']} 使用靜態訊息（無房間ID）');
    return _buildStaticChatPartnerSection(task);
  }
}

/// 構建靜態版本的聊天對象區塊（備用方案）
Widget _buildStaticChatPartnerSection(Map<String, dynamic> task) {
  final creatorName = task['creator_name'] ?? 'Unknown';
  final creatorAvatar = task['creator_avatar'];
  final latestMessage = task['latest_message_snippet'] ?? 'No conversation yet';

  return Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: Colors.grey[50],
      borderRadius: BorderRadius.circular(8),
      // 🆕 添加邊框指示這是靜態版本
      border: Border.all(color: Colors.orange.withOpacity(0.3)),
    ),
    child: Row(
      children: [
        _buildAvatarWithFallback(
          creatorAvatar?.toString(),
          creatorName,
          radius: 16,
          fontSize: 12,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                creatorName,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                latestMessage,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
```

6. **在 dispose 中添加清理（約第403行前）**：
```dart
// 🆕 清理實時訊息監控
try {
  MyWorksSocketMonitor.clearAll();
  debugPrint('✅ [My Works] 已清理 Socket 監控');
} catch (e) {
  debugPrint('⚠️ [My Works] 清理 Socket 監控失敗: $e');
}
```

## 🧪 **測試驗證**

### **測試 1：Posted Tasks 應徵者篩選**

1. **創建測試任務**：
   - 狀態為 Open (status_id = 1) 的任務，有多個應徵者
   - 狀態為 In Progress (status_id = 2) 的任務，有一個 accepted 應徵者

2. **驗證顯示結果**：
   ```dart
   // 在 _buildTaskCard 中添加測試代碼
   debugPrint('🧪 [測試] 任務 $taskId 狀態: ${_getTaskStatusId(task)}');
   debugPrint('🧪 [測試] 原始應徵者: ${originalApplicants.length}');
   debugPrint('🧪 [測試] 篩選應徵者: ${filteredApplicants.length}');
   ```

3. **預期結果**：
   - Open 狀態：顯示所有應徵者
   - In Progress 狀態：只顯示 1 個被接受的應徵者

### **測試 2：My Works 實時訊息**

1. **檢查連接統計**：
   ```dart
   // 在 _refreshMyWorksData 中查看日誌
   MyWorksMessageStats.printMessageStats(processedData);
   ```

2. **測試實時更新**：
   - 在聊天室中發送新訊息
   - 觀察 My Works 分頁是否即時更新

3. **預期結果**：
   ```
   🔍 [MyWorksMessageStats] My Works 訊息統計:
     - 總任務數: 5
     - 支持實時更新: 4
     - 僅靜態訊息: 1
     - 實時更新覆蓋率: 80.0%
   ```

## 🚨 **注意事項**

### **性能考量**
1. **Socket 連接數量**：避免同時開啟過多房間連接
2. **篩選性能**：大量應徵者時篩選可能有延遲
3. **記憶體使用**：實時監聽會增加記憶體使用

### **錯誤處理**
1. **API 數據不完整**：graceful degradation 到靜態版本
2. **Socket 連接失敗**：自動回退到靜態訊息
3. **狀態數據異常**：預設顯示所有應徵者

### **調試工具**
```dart
// 開啟詳細調試日誌
const bool enableDetailedDebug = true; // 在 debug 環境中設為 true

// 使用調試方法
PostedTasksApplicantFilter.debugTaskApplicants(task, applicants);
MyWorksMessageStats.validateMessageData(tasks);
```

## 📊 **效果評估**

### **Posted Tasks 改進**
- ✅ 非 Open 狀態只顯示相關應徵者
- ✅ 提供清晰的狀態指示
- ✅ 改善用戶體驗和信息準確性

### **My Works 改進**
- ✅ 實時訊息更新
- ✅ 與 Posted Tasks 體驗一致
- ✅ 提供靜態訊息備用方案

這些修復解決了您提出的兩個核心問題，提供了完整的實施方案和測試指南！🎯
